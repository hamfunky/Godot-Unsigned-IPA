extends "res://scripts/sheet.gd"
## Overview of the city you're in (like Idle Miner's Mine Overview): what each
## station moves per second, who runs it and their boost, every bay's share,
## and a red "!" on the slowest part of the chain. Activate all boosts at the bottom.

const Data = preload("res://scripts/game_data.gd")
const Portrait = preload("res://scripts/portrait.gd")
const AbilityIcon = preload("res://scripts/ability_icon.gd")

var _scroll: ScrollContainer
var _list: VBoxContainer
var _total: Label
var _activate: Button
var _timer := 0.0
var _sig := ""
var _rows: Dictionary = {}      # station key -> {title, extra, state} labels
var _sections: Array = []       # the three section $/s labels


func setup() -> void:
	set_finish("gloss")   # v0.19u
	set_title("Overview")
	_total = UiTheme.label("", 20, UiTheme.CASH)
	body.add_child(_total)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, 760)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	_scroll.add_child(_list)
	_activate = UiTheme.button("", 22, Color("ffb300"))
	_activate.custom_minimum_size = Vector2(0, 72)
	_activate.pressed.connect(func(): GameState.activate_all_ready())
	body.add_child(_activate)
	_rebuild()


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= 0.5:
		_timer = 0.0
		_rebuild()


## Rows are only rebuilt when the shop changes (bays, managers); otherwise just their numbers update,
## so the ability buttons on each row keep working while you tap them (v0.17g).
func _signature() -> String:
	var s := "%s|%d|%s|" % [GameState.active_city, GameState.bays.size(), GameState.bottleneck() if GameState.bays_total_income() > 0.0 else ""]
	for k in _keys():
		s += str(GameState.manager_at(k).get("id", "")) + ","
	return s


func _keys() -> Array:
	var a := ["desk", "valet"]
	for i in GameState.bays.size():
		a.append("bay%d" % i)
	return a


func _rebuild() -> void:
	set_title("Overview  ·  " + str(GameState.city_def(GameState.active_city)["name"]).split(",")[0])
	_total.text = "Earning %s/s while you're away" % GameState.money(GameState.idle_income())
	var sig := _signature()
	if sig != _sig:
		_sig = sig
		var keep := _scroll.scroll_vertical
		for c in _list.get_children():
			_list.remove_child(c)
			c.queue_free()
		_rows = {}
		var neck := GameState.bottleneck() if GameState.bays_total_income() > 0.0 else ""
		_sections = [_section("FRONT DESK  ·  checkout", neck == "desk")]
		_manager_row("desk")
		_sections.append(_section("VALET  ·  transport", neck == "valet"))
		_manager_row("valet")
		_sections.append(_section("BAYS  ·  detailing", neck == "bays"))
		for i in GameState.bays.size():
			_manager_row("bay%d" % i)
		_scroll.set_deferred("scroll_vertical", keep)
	_update_numbers()

	var ready := GameState.any_ability_ready()
	_activate.disabled = not ready
	_activate.text = "ACTIVATE ALL MANAGER ABILITIES" if ready else "All abilities used or recharging"


func _update_numbers() -> void:
	var total := GameState.bays_total_income()
	if _sections.size() == 3:
		_sections[0].text = GameState.money(GameState.desk_rate()) + "/s"
		_sections[1].text = GameState.money(GameState.valet_rate()) + "/s"
		_sections[2].text = GameState.money(total) + "/s"
	for key in _rows.keys():
		var r: Dictionary = _rows[key]
		var title: String
		match key:
			"desk":
				title = "Front Desk  Lv %d" % GameState.level_of("desk")
			"valet":
				title = "Valet  Lv %d" % GameState.level_of("valet")
			_:
				var i := GameState.bay_index(key)
				var inc := GameState.bay_income(i)
				title = "Bay %d  Lv %d" % [i + 1, GameState.level_of(key)]
				r["extra"].text = "%s/s  ·  %d%%" % [GameState.money(inc), int(round(inc / total * 100.0)) if total > 0.0 else 0]
		r["title"].text = title
		var m := GameState.manager_at(key)
		if m.is_empty():
			continue
		var state: String
		if GameState.ability_active(m):
			state = "ACTIVE · %s left" % GameState.ability_left_text(m)
		elif GameState.ability_ready(m):
			state = "ready - tap the button"
		else:
			state = "recharging · %s" % GameState.fmt_time(float(m["ready_at"]) - GameState.now)
		r["state"].text = "%s  (%s)" % [GameState.ability_text(m), state]
		r["state"].add_theme_color_override("font_color", UiTheme.GOOD if GameState.ability_active(m) else Color(1, 1, 1, 0.85))


## Section header ribbon; returns the label that shows its $/s.
func _section(title: String, slow: bool) -> Label:
	var p := PanelContainer.new()
	var st := UiTheme.card(Color("2f9bff"), 16, 10, UiTheme.WARN if slow else Color(0, 0, 0, 0))   # v0.17f ribbon header
	p.add_theme_stylebox_override("panel", st)
	_list.add_child(p)
	var h := HBoxContainer.new()
	p.add_child(h)
	var l := UiTheme.outlined(UiTheme.display_label(title, 22), 6)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	if slow:
		var mark := Control.new()   # just the red "!" (no text)
		mark.custom_minimum_size = Vector2(40, 30)
		mark.draw.connect(func(): UiTheme.alert_mark(mark, Vector2(18, 15), 12.0))
		mark.process_mode = Node.PROCESS_MODE_ALWAYS
		h.add_child(mark)
	var rate := UiTheme.outlined(UiTheme.display_label("", 22, UiTheme.CASH), 6)
	h.add_child(rate)
	return rate


## One station: a big portrait, who runs it and their ability, and (v0.17g) the same ability button as
## at the station, so you can fire abilities from here. About 3-4 rows fit on screen.
func _manager_row(key: String) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.card(UiTheme.CARD, 16, 10))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	_list.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var m := GameState.manager_at(key)
	var por := Portrait.new()
	por.manager = m
	por.station_key = key
	por.custom_minimum_size = Vector2(112, 124)
	h.add_child(por)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var tl := UiTheme.outlined(UiTheme.display_label("", 23), 5)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tl)
	var ex := UiTheme.outlined(UiTheme.label("", 19, UiTheme.CASH), 4)
	top.add_child(ex)
	var row := {"title": tl, "extra": ex}
	_rows[key] = row
	if m.is_empty():
		var nl := UiTheme.label("No manager: only works when you tap it", 19, Color("e3ecff"))
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(nl)
		return
	var r := GameState.rarity_def(m)
	var who := "%s  ·  %s" % [m["name"], r["name"]]
	if GameState.is_premium(m):
		who = "%s  ·  %s  Lv %d" % [m["name"], r["name"], int(m["level"])]
	v.add_child(UiTheme.outlined(UiTheme.label(who, 20, Color(r["color"]).lightened(0.25)), 4))
	if GameState.is_premium(m):
		var pl := UiTheme.label(GameState.passive_text(m), 17, Color("b9f6ca"))
		pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(pl)
	var stl := UiTheme.label("", 18)
	stl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(stl)
	row["state"] = stl
	var ab := AbilityIcon.new()
	ab.station_key = key
	ab.custom_minimum_size = Vector2(76, 72)
	ab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ab)
