extends Control
## Side panels that slide over the world map, laid out like Idle Miner's (v0.19w, Hamza's photos 27 Oct).
##   COLLECT  (top-left corner, coins; covers the LEFT side). Every city you're not in with its little shop,
##            what it has made since (its stash) and its x2 time left. Per country: the total, COLLECT x2 (ad
##            only: the stashes x COLLECT_AD_MULT) and BOOST ALL (one ad = every city of that country to the
##            full 24h). BOOST ALL is never greyed out: until all 5 cities are open, tapping it says so.
##            At the bottom: ALL COUNTRIES, COLLECT ALL x2. (Going to a city still collects its stash, x1.)
##   PRESTIGE (top-right corner, trophy; covers the RIGHT side). Your trophies out of every one there is; a
##            row per city: its shop, $/s, a trophy badge with its prestige level, PRESTIGE (opens that city's
##            prestige screen), the income it'll make after, and a chevron that opens the price.
## kind = "collect" or "prestige". Tap the dim area or X to close.

signal prestige_city(id: String)
signal closed

const Data = preload("res://scripts/game_data.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")
const HudMeta = preload("res://scripts/hud_meta.gd")
const MapArt = preload("res://scripts/map_art.gd")

const PANEL_COL := Color("1b2a55")
const ROW_COL := Color("2a4486")
const HERE_COL := Color("5c4c1a")
const GREEN := Color("35b54a")
const BLUE := Color("2f8ee0")
const WIDTH_FRAC := 0.88

var kind := "collect"
var _panel: PanelContainer
var _list: VBoxContainer
var _footer: VBoxContainer
var _note: Label
var _note_tw: Tween
var _shown := false
var _rows := []              # [{id, stash: Label, boost: Label}]  /  [{id, btn, after, rate, detail}]
var _totals := {}            # country id -> Label ("= $1.2M")
var _boost_btns := {}        # country id -> Button
var _collect_btns := {}      # country id ("" = all) -> Button
var _prestige_btns := {}     # city id -> Button
var _tick := 0.0
var _sig := ""


func setup(k: String) -> void:
	kind = k
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.06, 0.15, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			close())
	add_child(dim)
	_panel = PanelContainer.new()
	var ps := UiTheme.card(PANEL_COL, 22, 12, UiTheme.INK)
	_panel.add_theme_stylebox_override("panel", ps)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_panel.add_child(v)
	v.add_child(_header())
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	sc.add_child(_list)
	_footer = VBoxContainer.new()
	_footer.add_theme_constant_override("separation", 6)
	v.add_child(_footer)
	# the little message (BOOST ALL before every city is open, nothing to collect...)
	_note = UiTheme.display_label("", 19, Color.WHITE)
	UiTheme.outlined(_note, 5)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var nb := UiTheme.box(Color("101a38"), 14, 0)
	nb.set_border_width_all(3)
	nb.border_color = Color("ffd23f")
	nb.content_margin_left = 14
	nb.content_margin_right = 14
	nb.content_margin_top = 8
	nb.content_margin_bottom = 8
	_note.add_theme_stylebox_override("normal", nb)
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note.modulate.a = 0.0
	add_child(_note)
	_build()
	resized.connect(_layout)
	_layout.call_deferred()


## Full height, WIDTH_FRAC of the width, on its own side (collect left, prestige right); slides in once.
func _layout() -> void:
	var par := get_parent() as Control
	if par != null and (size.x <= 1.0 or size != par.size):
		position = Vector2.ZERO
		size = par.size   # (a plain Control parent hasn't always sized us yet)
	if size.x <= 1.0:
		_layout.call_deferred()
		return
	var left := kind == "collect"
	var w := roundf(size.x * WIDTH_FRAC)
	_panel.size = Vector2(w, size.y - 16.0)
	var x := 8.0 if left else size.x - w - 8.0
	_panel.position.y = 8.0
	if not _shown:
		_shown = true
		_panel.position.x = -w - 20.0 if left else size.x + 20.0
		create_tween().tween_property(_panel, "position:x", x, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_panel.position.x = x
	_note.size = Vector2(w - 60.0, 0)
	_note.position = Vector2(x + 30.0, size.y * 0.42)


func _header() -> Control:
	var left := kind == "collect"
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var ic := Control.new()
	ic.custom_minimum_size = Vector2(54, 54)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.draw.connect(func():
		if left:
			MapArt.coins(ic, Vector2(27, 29), 46.0)
		else:
			HudMeta.draw_trophy(ic, Vector2(27, 27), 46.0, true))
	h.add_child(ic)
	var t := UiTheme.display_label("COLLECT" if left else "PRESTIGE", 30, Color.WHITE)
	UiTheme.outlined(t, 8)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	if not left:
		# your trophies out of every one there is (Idle Miner's "41 / 240")
		var got := 0
		var all := 0
		for c in Data.COUNTRIES:
			for ct in c["cities"]:
				all += Data.MAX_PRESTIGE
				if GameState.cities.has(ct["id"]):
					got += int(GameState.cities[ct["id"]]["prestige"])
		var tr := Control.new()
		tr.custom_minimum_size = Vector2(30, 40)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.draw.connect(func(): HudMeta.draw_trophy(tr, Vector2(15, 20), 30.0, true))
		h.add_child(tr)
		var n := UiTheme.display_label("%d / %d" % [got, all], 24, Color("ffe07a"))
		UiTheme.outlined(n, 6)
		n.name = "TrophyCount"
		h.add_child(n)
	var x := UiTheme.button("X", 24, Color("ff4d4d"))
	x.custom_minimum_size = Vector2(56, 54)
	x.pressed.connect(close)
	h.add_child(x)
	return h


func close() -> void:
	Sfx.play("close")
	closed.emit()
	queue_free()


## Countries you've opened (in order) + the Hometown, each with its open cities.
static func groups() -> Array:
	var out := []
	for c in Data.COUNTRIES:
		if not GameState.country_unlocked(c["id"]):
			continue
		var ids := []
		for ct in c["cities"]:
			if GameState.city_unlocked(ct["id"]):
				ids.append(ct["id"])
		out.append({"country": c["id"], "name": c["name"], "color": Color(c["color"]), "cities": ids})
	if GameState.city_unlocked(Data.HOMETOWN_ID):
		out.append({"country": Data.HOMETOWN_ID, "name": "Hometown", "color": Color("8d6e63"), "cities": [Data.HOMETOWN_ID]})
	return out


## "{ad} COLLECT x2" with the watch-an-ad screen, or just the words with the no-ads pack.
static func ad_text(s: String) -> String:
	return s if GameState.ad_free() else "{ad} " + s


func _build() -> void:
	for c in _list.get_children():
		c.queue_free()
	for c in _footer.get_children():
		c.queue_free()
	_rows = []
	_totals = {}
	_boost_btns = {}
	_collect_btns = {}
	_prestige_btns = {}
	var gs := groups()
	for g in gs:
		if kind == "prestige" and g["country"] == Data.HOMETOWN_ID:
			continue   # (the Hometown doesn't prestige)
		var gl := UiTheme.display_label(str(g["name"]).to_upper(), 22, Color.WHITE)
		gl.add_theme_color_override("font_outline_color", (g["color"] as Color).darkened(0.55))
		gl.add_theme_constant_override("outline_size", 7)
		_list.add_child(gl)
		for id in g["cities"]:
			_list.add_child(_collect_row(id) if kind == "collect" else _prestige_row(id))
		if kind == "collect":
			_list.add_child(_country_footer(g["country"]))
	if kind == "collect" and gs.size() > 1:
		var al := UiTheme.display_label("ALL COUNTRIES", 22, Color.WHITE)
		UiTheme.outlined(al, 7)
		_footer.add_child(al)
		var t := UiTheme.display_label("", 22, Color("8dff8a"))
		UiTheme.outlined(t, 5)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		t.clip_text = true
		_footer.add_child(t)
		_totals[""] = t
		var b := UiTheme.button("", 24, GREEN)
		b.custom_minimum_size = Vector2(0, 70)
		UiTheme.set_rich(b, ad_text("COLLECT ALL x%d" % int(Data.COLLECT_AD_MULT)))
		b.pressed.connect(_on_collect.bind(""))
		_footer.add_child(b)
		_collect_btns[""] = b
	_refresh()


func _logo(id: String) -> Control:
	var logo := Control.new()
	logo.custom_minimum_size = Vector2(66, 58)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.draw.connect(func():
		var p := int(GameState.cities[id]["prestige"])
		MapArt.shop(logo, Vector2(33, 53), p, false, Color(GameState.premises_def(p)["color"]), 0.78))
	return logo


func _row_box(here: bool) -> PanelContainer:
	var row := PanelContainer.new()
	var st := UiTheme.card(HERE_COL if here else ROW_COL, 14, 8)
	st.content_margin_left = 8
	st.content_margin_right = 12
	row.add_theme_stylebox_override("panel", st)
	return row


func _city_name(id: String) -> String:
	return str(GameState.city_def(id)["name"]).split(",")[0]


# ---------------------------------------------------------------- COLLECT

func _collect_row(id: String) -> Control:
	var here := id == GameState.active_city
	var row := _row_box(here)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	row.add_child(h)
	h.add_child(_logo(id))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	var n := UiTheme.display_label(_city_name(id) + ("  (here)" if here else ""), 20, Color.WHITE)
	n.clip_text = true
	v.add_child(n)
	var bl := UiTheme.label("", 16, UiTheme.MUTED)
	v.add_child(bl)
	var st := UiTheme.display_label("", 22, Color("8dff8a"))
	UiTheme.outlined(st, 5)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(st)
	_rows.append({"id": id, "stash": st, "boost": bl})
	return row


## "= $3.4M" + [COLLECT x2] [BOOST ALL] under each country.
func _country_footer(cid: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var t := UiTheme.display_label("", 22, Color.WHITE)
	UiTheme.outlined(t, 5)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(t)
	_totals[cid] = t
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	var cb := UiTheme.button("", 19, GREEN)
	cb.custom_minimum_size = Vector2(0, 58)
	cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.set_rich(cb, ad_text("COLLECT x%d" % int(Data.COLLECT_AD_MULT)))
	cb.pressed.connect(_on_collect.bind(cid))
	h.add_child(cb)
	_collect_btns[cid] = cb
	if cid != Data.HOMETOWN_ID:
		var bb := UiTheme.button("", 19, BLUE)
		bb.custom_minimum_size = Vector2(0, 58)
		bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiTheme.set_rich(bb, ad_text("BOOST ALL"))
		bb.pressed.connect(_on_boost_all.bind(cid))
		h.add_child(bb)
		_boost_btns[cid] = bb
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	v.add_child(gap)
	return v


func _on_collect(cid: String) -> void:
	if GameState.stash_of_country(cid).is_empty():
		Sfx.play("click")
		show_note("Nothing waiting yet" if cid == "" else "Nothing waiting in %s yet" % _country_name(cid))
		return
	var got := GameState.collect_ad(cid)
	Sfx.play("cash")
	Sfx.buzz(25)
	var parts := []
	for c in got.keys():
		parts.append(GameState.money(got[c], c))
	show_note("Collected %s" % "  +  ".join(parts))
	_refresh()


func _on_boost_all(cid: String) -> void:
	var why := GameState.boost_all_block(cid)
	if why != "":
		Sfx.play("click")
		show_note(why)
		return
	GameState.boost_all(cid)
	Sfx.play("boost")
	show_note("Every city in %s: x2 for %dh" % [_country_name(cid), int(Data.AD_BOOST_MAX_HOURS)])
	_refresh()


func _country_name(cid: String) -> String:
	return "the Hometown" if cid == Data.HOMETOWN_ID else str(GameState.country_def(cid)["name"])


## The little message over the panel: fades in, stays a moment, fades out.
func show_note(t: String) -> void:
	_note.text = t
	_note.reset_size()
	_note.size.x = maxf(_note.size.x, _panel.size.x - 60.0)
	if _note_tw != null:
		_note_tw.kill()
	_note.modulate.a = 0.0
	_note_tw = create_tween()
	_note_tw.tween_property(_note, "modulate:a", 1.0, 0.15)
	_note_tw.tween_interval(1.8)
	_note_tw.tween_property(_note, "modulate:a", 0.0, 0.35)


# ---------------------------------------------------------------- PRESTIGE

func _prestige_row(id: String) -> Control:
	var here := id == GameState.active_city
	var outer := _row_box(here)
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 4)
	outer.add_child(ov)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	ov.add_child(h)
	h.add_child(_logo(id))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	var n := UiTheme.display_label(_city_name(id) + ("  (here)" if here else ""), 20, Color.WHITE)
	n.clip_text = true
	v.add_child(n)
	var rate := UiTheme.display_label("", 17, UiTheme.CASH)
	UiTheme.outlined(rate, 4)
	v.add_child(rate)
	# the trophy badge with its prestige level
	var p := int(GameState.cities[id]["prestige"])
	var tro := Control.new()
	tro.custom_minimum_size = Vector2(46, 58)
	tro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tro.draw.connect(func(): HudMeta.draw_trophy(tro, Vector2(23, 30), 44.0, true, str(p)))
	h.add_child(tro)
	# PRESTIGE + the income after it
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 0)
	bv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(bv)
	var pc := GameState.prestige_cost(id)
	var pb := UiTheme.button("MAXED" if pc < 0.0 else "PRESTIGE", 17, BLUE)
	pb.custom_minimum_size = Vector2(132, 48)
	pb.disabled = pc < 0.0
	pb.pressed.connect(func(): prestige_city.emit(id))
	bv.add_child(pb)
	_prestige_btns[id] = pb
	var after := UiTheme.display_label("", 16, Color.WHITE)
	UiTheme.outlined(after, 4)
	after.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(after)
	# the chevron: opens the price + what it does
	var detail := UiTheme.label("", 16, Color("d6e2ff"))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.visible = false
	var chev := Button.new()
	chev.flat = true
	chev.custom_minimum_size = Vector2(30, 48)
	chev.focus_mode = Control.FOCUS_NONE
	chev.draw.connect(func():
		var c := chev.size * 0.5
		var d := -1.0 if detail.visible else 1.0
		var pts := PackedVector2Array([c + Vector2(-8, -4 * d), c + Vector2(0, 4 * d), c + Vector2(8, -4 * d)])
		chev.draw_polyline(pts, UiTheme.INK, 7.0, true)
		chev.draw_polyline(pts, Color.WHITE, 3.5, true))
	chev.pressed.connect(func():
		Sfx.play("click")
		detail.visible = not detail.visible
		chev.queue_redraw())
	h.add_child(chev)
	ov.add_child(detail)
	_rows.append({"id": id, "btn": pb, "after": after, "rate": rate, "detail": detail})
	return outer


# ---------------------------------------------------------------- refresh

func _process(delta: float) -> void:
	var par := get_parent() as Control
	if par != null and par.size != size:
		_layout()
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.25
	var s := str(GameState.cities.keys()) + str(GameState.active_city) + str(GameState.ad_free())
	for id in GameState.cities.keys():
		s += str(GameState.cities[id]["prestige"])
	if s != _sig:
		if _sig != "":
			_build()
		_sig = s
	_refresh()


func _refresh() -> void:
	for r in _rows:
		var id: String = r["id"]
		var cid := GameState.country_of(id)
		if kind == "collect":
			var here := id == GameState.active_city
			var st := GameState.stash_of(id)
			r["stash"].text = "pays your cash" if here else ("+" + GameState.money(st, cid) if st > 0.0 else "+" + GameState.money(0.0, cid))
			r["stash"].add_theme_color_override("font_color", Color("8dff8a") if st > 0.0 and not here else Color(1, 1, 1, 0.6))
			var left := GameState.ad_boost_left(id)
			r["boost"].text = ("Boost: %s" % GameState.fmt_time(left)) if left > 0.0 else "Boost: none"
			r["boost"].add_theme_color_override("font_color", Color("9cf07a") if left > 0.0 else UiTheme.MUTED)
		else:
			r["rate"].text = "%s/s" % GameState.money(GameState.city_idle_rate(id), cid)
			var pc := GameState.prestige_cost(id)
			var p := int(GameState.cities[id]["prestige"])
			var pb: Button = r["btn"]
			if pc < 0.0:
				r["after"].text = "x%s income" % GameState.fmt(pow(Data.PRESTIGE_MULT, p))
				r["detail"].text = "Fully prestiged: %d of %d trophies." % [p, Data.MAX_PRESTIGE]
				continue
			var ready := GameState.prestige_ready(id)
			pb.text = "PRESTIGE!" if ready else "PRESTIGE"
			pb.modulate = Color.WHITE if ready else Color(1, 1, 1, 0.8)
			r["after"].text = "x%s income" % GameState.fmt(pow(Data.PRESTIGE_MULT, p + 1))
			var need := GameState.prestige_needs(id)
			var d := "Prestige %d costs %s (you have %s). It rebuilds the shop fancier and its income goes x%s -> x%s." % [
				p + 1, GameState.money(pc, cid), GameState.money(GameState.wallets.get(cid, 0.0), cid),
				GameState.fmt(pow(Data.PRESTIGE_MULT, p)), GameState.fmt(pow(Data.PRESTIGE_MULT, p + 1))]
			if need != "":
				d += " First open %s." % _city_name(need)
			r["detail"].text = d
	if kind != "collect":
		return
	for cid in _totals.keys():
		var tot := GameState.stash_of_country(cid)
		var parts := []
		for c in tot.keys():
			parts.append(GameState.money(tot[c], c))
		if cid == "":
			_totals[cid].text = "= " + ("  +  ".join(parts) if not parts.is_empty() else "nothing yet")
		else:
			_totals[cid].text = "= " + GameState.money(float(tot.get(cid, 0.0)), cid)
	# (never greyed out: an empty COLLECT or a BOOST ALL that can't go yet just says why when tapped)
	for cid in _collect_btns.keys():
		_collect_btns[cid].modulate = Color.WHITE if not GameState.stash_of_country(cid).is_empty() else Color(1, 1, 1, 0.7)
	for cid in _boost_btns.keys():
		_boost_btns[cid].modulate = Color.WHITE if GameState.boost_all_wanted(cid) else Color(1, 1, 1, 0.7)
