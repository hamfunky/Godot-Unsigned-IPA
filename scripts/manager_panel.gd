extends "res://scripts/sheet.gd"
## Managers for one station. Whoever works here sits on top, then HIRE (cash, random
## ability and tier), then tabs (v0.17d):
##   PREMIUM  - gold tab with a star. Every premium manager you own for this station type:
##              free, working elsewhere or in another city. Assigning a busy one asks first.
##   SPEED / DISCOUNT / INCOME - your FREE cash managers in this city with that ability,
##              best tier first. Assigning never pulls one off another station (Remove it
##              there first).
## HIRE rolls any ability: the panel jumps to the new manager's tab and highlights them.

const Data = preload("res://scripts/game_data.gd")
const Portrait = preload("res://scripts/portrait.gd")
const DossierPanel = preload("res://scripts/dossier_panel.gd")

const TABS := ["premium", "speed", "discount", "income"]
const TAB_NAMES := {"premium": "PREMIUM", "speed": "SPEED", "discount": "DISCOUNT", "income": "INCOME"}
const KIND_INFO := {
	"speed": "Speed: the station works faster while the ability runs (speed abilities last twice as long).",
	"discount": "Discount: this station's level-ups cost less while the ability runs. Save up, then use it and upgrade.",
	"income": "Income: the station earns or carries more while the ability runs.",
}
const PREMIUM_GOLD := Color("d4a017")
const PREMIUM_FADED := Color("ead9a0")

static var tab := "speed"   # remembered between openings

var key := ""
var _state_label: Label
var _activate: Button
var _hire: Button
var _confirm: Control
var _new_id := -1             # the manager just hired (highlighted)
var _scroll_to: Control
var _cooldowns := []          # [label, dim nodes, manager] for list cards (live "Recharging" text)

# fixed layout (v0.17d): every block keeps its height, so HIRE and the tabs never move
const TOP_H := 176.0          # the manager working here (or the "nobody here" card)
const INFO_H := 54.0          # the tab's one-line explanation (2 lines max)
const LIST_H := 3 * 128.0     # the list box (3 cards, scrolls)
const NOTE_H := 28.0          # "N more working at other stations"


func setup(station_key: String) -> void:
	set_finish("gloss")   # v0.19u
	key = station_key
	set_title("%s Manager" % GameState.station_name(key))
	GameState.state_changed.connect(_rebuild)
	if not TABS.has(tab):
		tab = "speed"
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree() and body == null:
		return
	clear_body()
	_state_label = null
	_activate = null
	_hire = null
	_scroll_to = null
	_cooldowns = []
	var area := GameState.area_of(key)
	var m := GameState.manager_at(key)

	if m.is_empty():
		var empty := PanelContainer.new()
		empty.add_theme_stylebox_override("panel", UiTheme.card(Color("27489a"), 18, 14))
		empty.custom_minimum_size = Vector2(0, TOP_H)
		var l := UiTheme.label("Nobody is running this station, so it only works while you tap it. Hire a manager to automate it, even while you're away.", 19, UiTheme.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.add_child(l)
		body.add_child(empty)
	else:
		var top := _manager_card(m, true)
		top.custom_minimum_size = Vector2(0, TOP_H)
		body.add_child(top)

	# hire: a random ability and tier, whichever tab is open
	_hire = UiTheme.button("", 26, UiTheme.GOOD)
	_hire.custom_minimum_size = Vector2(0, 84)
	_hire.pressed.connect(_on_hire)
	body.add_child(_hire)
	var odds := []
	for r in Data.RARITIES:
		odds.append("%s %d%%" % [r["name"], int(r["odds"])])
	# v0.19j (playtest: "hire gets you a random one" read oddly): say what's random
	var ol := UiTheme.label("Every hire is a surprise: a speed, discount or income ability.\n" + "  ·  ".join(odds) + "   (they work in this city)", 16, UiTheme.MUTED)
	ol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(ol)

	# tabs
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	body.add_child(tabs)
	for t in TABS:
		tabs.add_child(_tab_button(t))

	if tab == "premium":
		_build_premium_tab(area)
	else:
		_build_kind_tab(area, tab)
	_crew_note(area)
	_refresh()
	if _scroll_to != null:
		_highlight.call_deferred(_scroll_to)


func _tab_button(t: String) -> Button:
	var on: bool = t == tab
	var prem: bool = t == "premium"
	var col: Color = (PREMIUM_FADED if on else PREMIUM_GOLD) if prem else (UiTheme.ACCENT if on else Color("3d4657"))
	var b := UiTheme.button(("    " if prem else "") + TAB_NAMES[t], 18, col)
	if not prem:
		UiTheme.set_tab_look(b, on)
	for st in (["normal", "hover", "pressed", "disabled"] if prem else []):
		var sb := UiTheme.lip_box(col if st == "normal" else col.lightened(0.08), st == "pressed")
		sb.border_color = Color("b8860b") if on else Color("c78400")
		b.add_theme_stylebox_override(st, sb)
	if prem:
		b.add_theme_color_override("font_color", Color("4a3500") if on else Color.WHITE)
		b.add_theme_color_override("font_hover_color", Color("4a3500") if on else Color.WHITE)
		b.add_theme_color_override("font_pressed_color", Color("4a3500"))
		var star := Control.new()
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star.position = Vector2(8, 14)
		star.size = Vector2(30, 30)
		star.draw.connect(func(): _draw_star(star, star.size * 0.5, 13.0))
		star.process_mode = Node.PROCESS_MODE_ALWAYS
		b.add_child(star)
		var tw := star.create_tween().set_loops()
		tw.tween_callback(star.queue_redraw).set_delay(0.05)
	b.custom_minimum_size = Vector2(0, 58)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func():
		tab = t
		_new_id = -1
		_rebuild())
	return b


## A shiny gold star with a glint that sweeps across now and then.
static func _draw_star(ci: CanvasItem, c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2 + k * PI / 5
		var rr := r if k % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, Color("fff176"))
	pts.append(pts[0])
	ci.draw_polyline(pts, Color("8d6e00"), 2.0, true)
	var t := fmod(Time.get_ticks_msec() * 0.001, 2.4)
	if t < 0.6:
		var k := t / 0.6
		var p := c + Vector2(-r + 2.0 * r * k, -r * 0.3 + 0.6 * r * k)
		ci.draw_circle(p, r * 0.28, Color(1, 1, 1, 0.9 * sin(k * PI)))
		ci.draw_line(p + Vector2(-r * 0.5, 0), p + Vector2(r * 0.5, 0), Color(1, 1, 1, 0.8 * sin(k * PI)), 2.0)
		ci.draw_line(p + Vector2(0, -r * 0.5), p + Vector2(0, r * 0.5), Color(1, 1, 1, 0.8 * sin(k * PI)), 2.0)


func _on_hire() -> void:
	var nm := GameState.hire_manager(key)
	if nm.is_empty():
		return
	# show where they went: their ability's tab, highlighted
	tab = str(GameState.ability_def(nm)["kind"])
	_new_id = int(nm["id"])
	_rebuild()


## Cash managers with one kind of ability (free ones, best tier first).
func _build_kind_tab(area: String, kind: String) -> void:
	var info := UiTheme.label(KIND_INFO[kind], 16, Color("90caf9"))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(0, INFO_H)
	body.add_child(info)
	var of_kind := func(x): return str(GameState.ability_def(x)["kind"]) == kind
	var idle := GameState.free_managers_in_area(area).filter(of_kind)
	idle.sort_custom(func(a, b): return int(a["rarity"]) * 100000 - int(a["id"]) > int(b["rarity"]) * 100000 - int(b["id"]))
	var here := GameState.manager_at(key)
	var busy := GameState.managers_in_area(area).filter(of_kind).size() - idle.size() \
		- (1 if not here.is_empty() and not GameState.is_premium(here) and of_kind.call(here) else 0)
	var hd := UiTheme.label("%s %s MANAGERS (%d)" % [kind.to_upper(), _area_name(area).to_upper(), idle.size()], 18, UiTheme.MUTED)
	hd.custom_minimum_size = Vector2(0, 28)
	body.add_child(hd)
	_list(idle, "No %s managers waiting here. Each hire is a surprise: speed, discount or income." % kind)
	var bl := UiTheme.label(("%d more working at other stations. To move one, Remove it there first." % busy) if busy > 0 else "", 16, UiTheme.MUTED)
	bl.custom_minimum_size = Vector2(0, NOTE_H)
	body.add_child(bl)


func _build_premium_tab(area: String) -> void:
	var mine := GameState.premium_in_area(area).filter(func(x): return not (x["city"] == GameState.active_city and x["assigned"] == key))
	var l := UiTheme.label("One of a kind. They work in any city, have a passive while working, and level up with Certs.", 16, Color("ffd54f"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(0, INFO_H)
	body.add_child(l)
	var hd := UiTheme.label("PREMIUM %s MANAGERS (%d)" % [_area_name(area).to_upper(), mine.size()], 18, Color("ffd54f"))
	hd.custom_minimum_size = Vector2(0, 28)
	body.add_child(hd)
	if mine.is_empty():
		var started := GameState.roster.values().filter(func(x): return x["area"] == area and not x["owned"] and int(x["clues"]) > 0).size()
		var t := "No Premium %s managers yet. Collect their clues from Case Files, earned in the Hometown Garage." % _area_name(area)
		if started > 0:
			t += "  You've got clues on %d of them." % started
		_list([], t)
	else:
		mine.sort_custom(func(a, b): return int(a["rarity"]) * 100 + int(a["level"]) > int(b["rarity"]) * 100 + int(b["level"]))
		_list(mine, "")
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, NOTE_H)
	body.add_child(pad)


## Scroll the new manager into view and flash them.
func _highlight(card: Control) -> void:
	if not is_instance_valid(card):
		return
	var sc := card.get_parent().get_parent() as ScrollContainer
	if sc != null:
		sc.ensure_control_visible(card)
	card.modulate = Color(1.6, 1.5, 0.8)
	var tw := card.create_tween()
	tw.tween_property(card, "modulate", Color.WHITE, 0.9).set_delay(0.15)


## The list box: always LIST_H tall (scrolls), with `empty_text` inside when nobody's in it.
func _list(people: Array, empty_text: String) -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, LIST_H)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	if people.is_empty():
		var e := UiTheme.label(empty_text, 18, UiTheme.MUTED)
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		e.custom_minimum_size = Vector2(0, 80)
		e.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(e)
	for o in people:
		var card := _manager_card(o, false)
		list.add_child(card)
		if not GameState.is_premium(o) and int(o["id"]) == _new_id:
			_scroll_to = card


func _crew_note(area: String) -> void:
	var crew_txt := ""
	if area == "bay":
		var on := GameState.bay_crew_bonus(GameState.bay_index(key)) > 1.0
		crew_txt = "Specialist: x%s on cars of the manager's crew.  Crew chain: same crew as the Valet AND Front Desk managers = this bay x%s.  %s" % [
			str(Data.CREW_SPECIALIST_BONUS), str(Data.CREW_CHAIN_BONUS), "ACTIVE" if on else "Not active"]
	else:
		var on := GameState.pair_crew_bonus() > 1.0
		crew_txt = "Crew pair: Valet and Front Desk managers in the same crew both work x%s harder.  %s" % [
			str(Data.CREW_PAIR_BONUS), "ACTIVE" if on else "Not active"]
	var cl := UiTheme.label(crew_txt, 17, Color("ce93d8"))
	cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(cl)


static func _area_name(area: String) -> String:
	return {"bay": "bay", "valet": "valet", "desk": "front desk"}[area]


func _manager_card(m: Dictionary, here: bool) -> Control:
	var prem := GameState.is_premium(m)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.card(UiTheme.CARD, 14, 10, UiTheme.CARD_GOLD if prem else Color(0, 0, 0, 0)))
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	panel.add_child(h)

	var p := Portrait.new()
	p.manager = m
	p.show_state = here
	p.show_level = prem
	p.custom_minimum_size = Vector2(88, 96)
	if prem:
		p.pressed.connect(func(): _open_dossier(str(m["id"])))
	h.add_child(p)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 1)
	h.add_child(v)
	var rarity := GameState.rarity_def(m)
	var crew := GameState.crew_def(m)
	var is_new: bool = not prem and int(m["id"]) == _new_id
	if is_new:
		panel.add_theme_stylebox_override("panel", UiTheme.card(UiTheme.CARD, 14, 10, Color("ffd54f")))
	v.add_child(UiTheme.label("%s%s  ·  %s%s" % ["NEW!  " if is_new else "", m["name"], rarity["name"], "  ·  PREMIUM" if prem else ""], 21, Color("ffd54f") if is_new else Color(rarity["color"]).lightened(0.15)))
	var sub: String = crew["name"]
	if prem:
		sub = "%s  Lv %d  ·  %s" % [GameState.promotion(m), int(m["level"]), crew["name"]]
	# v0.17g: say what the crew actually does (bay managers: bonus on their crew's cars)
	if GameState.area_of(key) == "bay" and Data.CLASS_NAMES.has(crew["id"]):
		sub += "  ·  x%s on %s cars" % [str(snappedf(GameState.specialist_bonus(crew["id"]), 0.01)), Data.CLASS_NAMES[crew["id"]]]
	v.add_child(UiTheme.label(sub, 16, Color(crew["color"]).lightened(0.35)))
	var al := UiTheme.label("%s  (%s, recharge %s)" % [GameState.ability_text(m), GameState.ability_length_text(m), GameState.fmt_time(GameState.ability_cooldown(m))], 16)
	al.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(al)
	if prem:
		v.add_child(UiTheme.label("Passive: " + GameState.passive_text(m), 16, UiTheme.GOOD))
		if m["gear"] != "":
			v.add_child(UiTheme.label("Gear: %s (%s)" % [GameState.equip_def(m["gear"])["name"], GameState.equip_text(m["gear"])], 15, Color("80deea")))

	var bv := VBoxContainer.new()
	bv.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(bv)
	var mid: Variant = str(m["id"]) if prem else int(m["id"])
	if here:
		_state_label = UiTheme.label("", 16, UiTheme.MUTED)
		v.add_child(_state_label)
		_activate = UiTheme.button("USE", 22, Color("ff9800"))
		_activate.custom_minimum_size = Vector2(124, 54)
		_activate.pressed.connect(func(): GameState.activate_ability(key))
		bv.add_child(_activate)
		var un := UiTheme.button("Remove", 18, Color("3d4657"))
		un.custom_minimum_size = Vector2(124, 44)
		un.pressed.connect(func(): GameState.unassign_manager(mid))
		bv.add_child(un)
	else:
		var busy: bool = m["assigned"] != ""
		if busy:   # (no "Free" line: the list only shows managers you can assign)
			v.add_child(UiTheme.label(GameState.manager_location(m), 15, Color("ffb74d")))
		# recharging: greyed out with the time left (can still be assigned)
		var cd := UiTheme.label("", 15, Color("ffcc80"))
		v.add_child(cd)
		_cooldowns.append([cd, [p, v], m])
		var assign := UiTheme.button("Assign", 22, UiTheme.ACCENT)
		assign.custom_minimum_size = Vector2(124, 54)
		if busy and prem:
			assign.pressed.connect(func(): _confirm_move(m))
		else:
			assign.pressed.connect(func(): GameState.assign_manager(mid, key))
		bv.add_child(assign)
	return panel


## A premium manager working somewhere else: ask before moving them here.
func _confirm_move(m: Dictionary) -> void:
	if _confirm != null and is_instance_valid(_confirm):
		_confirm.queue_free()
	var ov := ColorRect.new()
	ov.color = Color(0, 0, 0, 0.6)
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(ov)
	_confirm = ov
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(cc)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(580, 0)
	var st := UiTheme.box(UiTheme.PANEL, 20, 22)
	st.set_border_width_all(3)
	st.border_color = Color(GameState.rarity_def(m)["color"])
	panel.add_theme_stylebox_override("panel", st)
	cc.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	var t := UiTheme.label("%s is currently at %s." % [m["name"], GameState.manager_job_text(m)], 24)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := UiTheme.label("Assign them to %s instead? That station will have no manager." % GameState.station_name(key), 18, UiTheme.MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	var ok := UiTheme.button("ASSIGN", 24, UiTheme.GOOD)
	ok.custom_minimum_size = Vector2(0, 72)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(func():
		ov.queue_free()
		GameState.assign_manager(str(m["id"]), key))
	h.add_child(ok)
	var no := UiTheme.button("CANCEL", 24, Color("6b7280"))
	no.custom_minimum_size = Vector2(0, 72)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.pressed.connect(func(): ov.queue_free())
	h.add_child(no)


func _open_dossier(id: String) -> void:
	var d := DossierPanel.new()
	get_parent().add_child(d)
	d.setup(id)


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	for c in _cooldowns:
		var lm: Dictionary = c[2]
		var label: Label = c[0]
		if not is_instance_valid(label):
			continue
		var dim := false
		if GameState.ability_active(lm):
			label.text = "Ability running: %s left" % GameState.ability_left_text(lm)
			label.add_theme_color_override("font_color", UiTheme.GOOD)
		elif not GameState.ability_ready(lm):
			label.text = "Recharging: %s left" % GameState.fmt_time(float(lm["ready_at"]) - GameState.now)
			label.add_theme_color_override("font_color", Color("ffcc80"))
			dim = true
		else:
			label.text = ""
		label.visible = label.text != ""
		# grey the portrait + text, keep the "Recharging" line and the Assign button bright
		var grey := Color(0.5, 0.5, 0.55) if dim else Color.WHITE
		c[1][0].modulate = grey
		for ch in c[1][1].get_children():
			ch.modulate = Color.WHITE if ch == label else grey
	if _hire != null:
		var cost := GameState.hire_cost(GameState.area_of(key))
		_hire.text = "HIRE MANAGER   " + GameState.money(cost)
		_hire.disabled = GameState.cash < cost
	var m := GameState.manager_at(key)
	if _state_label == null or m.is_empty():
		return
	if GameState.ability_active(m):
		_state_label.text = "Ability running: %s left" % GameState.ability_left_text(m)
		_activate.disabled = true
		_activate.text = "ACTIVE"
	elif GameState.ability_ready(m):
		_state_label.text = "Ability ready!"
		_activate.disabled = false
		_activate.text = "USE"
	else:
		_state_label.text = "Recharging: %s" % GameState.fmt_time(float(m["ready_at"]) - GameState.now)
		_activate.disabled = true
		_activate.text = "WAIT"
