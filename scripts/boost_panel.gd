extends "res://scripts/sheet.gd"
## Boosts: TOTAL = BASE x BOOSTERS.
##   BASE     = permanent boosts x the ad x2 (multiplied together)
##   BOOSTERS = every running booster added together (x5 + x2 = x7)
## v0.19j (playtest: "I like boosters as a badge", Idle Miner style; mockup boosts_mockup_v1):
##   * TOTAL card: a big gold gem + the sum drawn as mini gems: base x (booster + booster). An "i" button opens
##     the full breakdown in words (instead of small print).
##   * RUNNING NOW: one row that scrolls sideways. The ad boost is pinned on the left; each new booster goes on
##     the right end. The same booster used twice shares one badge with a count bubble ("x2"), soonest timer.
##     A "N more >" bubble at the edge when some are off screen.
##   * YOUR BOOSTERS: a grid of tiles (duration, gem, N left, USE).
##   * TODAY'S DEALS: 3 boosters on offer, each buyable once, new ones every 12 h (GameState.deals()).

const Data = preload("res://scripts/game_data.gd")
const BoostGem = preload("res://scripts/boost_gem.gd")

const RUN_W := 156.0
const RUN_H := 236.0

var _total_box: HBoxContainer
var _formula: HBoxContainer
var _run_scroll: ScrollContainer
var _run_row: HBoxContainer
var _more: Label
var _inv: GridContainer
var _deals: GridContainer
var _deals_head: Label
var _ad_btn: Button
var _ad_pill: Label
var _timers: Array = []      # [Label, until]
var _buy_btns: Array = []    # [Button, id]
var _info: Control = null
var _info_label: Label = null
var _sig := ""
var _last_added := false     # scroll the running row to the end after a USE
var _prev_groups := -1
var _end_frames := 0         # keep scrolling to the end for a few frames (the row needs a layout pass first)


func setup() -> void:
	set_finish("gloss")   # v0.19u
	set_title("Boosts")
	# --- total
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", UiTheme.card(Color("ff9a2e"), 22, 12, UiTheme.INK))
	body.add_child(top)
	_total_box = HBoxContainer.new()
	_total_box.add_theme_constant_override("separation", 14)
	top.add_child(_total_box)
	# --- running
	var rh := HBoxContainer.new()
	body.add_child(rh)
	var rr := UiTheme.ribbon("RUNNING NOW", 17, Color("2f9bff"))
	rr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rh.add_child(rr)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rh.add_child(sp)
	var run_wrap := Control.new()
	run_wrap.custom_minimum_size = Vector2(0, RUN_H)
	body.add_child(run_wrap)
	_run_scroll = ScrollContainer.new()
	_run_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_run_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_run_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	run_wrap.add_child(_run_scroll)
	_run_row = HBoxContainer.new()
	_run_row.add_theme_constant_override("separation", 12)
	_run_scroll.add_child(_run_row)
	_more = UiTheme.label("", 18, Color("3b2a00"))
	_more.add_theme_font_override("font", UiTheme.DISPLAY_FONT)
	_more.add_theme_stylebox_override("normal", UiTheme.card(Color("ffc93c"), 14, 6, UiTheme.INK))
	_more.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_more.modulate.a = 0.0   # (keeps its place in the heading row; shown only when badges are off screen)
	rh.add_child(_more)
	# --- owned
	body.add_child(UiTheme.ribbon("YOUR BOOSTERS", 17, Color("2f9bff")))
	_inv = GridContainer.new()
	_inv.columns = 3
	_inv.add_theme_constant_override("h_separation", 12)
	_inv.add_theme_constant_override("v_separation", 12)
	body.add_child(_inv)
	# --- deals
	_deals_head = UiTheme.ribbon("", 17, Color("2f9bff"))
	body.add_child(_deals_head)
	_deals = GridContainer.new()
	_deals.columns = 3
	_deals.add_theme_constant_override("h_separation", 12)
	_deals.add_theme_constant_override("v_separation", 12)
	body.add_child(_deals)
	_rebuild()


func _process(_delta: float) -> void:
	var sig := _signature()
	if sig != _sig:
		_rebuild()
	_refresh()


func _signature() -> String:
	var ids: Array = []
	for b in GameState.active_boosters:
		if GameState.now < float(b["until"]):
			ids.append("%s@%d" % [b["id"], int(b["until"])])
	return "%s|%s|%s|%s|%d|%s" % [str(ids), str(GameState.boosters), GameState.ad_boost_left() > 0.0, GameState.perm_boost,
		GameState.deal_window(), str(GameState.deals_bought)]


# ---------------------------------------------------------------- build

func _rebuild() -> void:
	var ng := GameState.booster_groups().size()
	var grew: bool = _prev_groups >= 0 and ng > _prev_groups
	_prev_groups = ng
	_sig = _signature()
	_timers.clear()
	_buy_btns.clear()
	_build_total()
	_build_running()
	_build_inventory()
	_build_deals()
	if grew or _last_added:
		_last_added = false
		_end_frames = 3
	if _info != null and is_instance_valid(_info):
		_info_label.text = info_text()
	_refresh()


func _clear(c: Node) -> void:
	for k in c.get_children():
		c.remove_child(k)
		k.queue_free()


func _build_total() -> void:
	_clear(_total_box)
	_total_box.add_child(BoostGem.make("x" + num(GameState.total_boost()), GameState.total_boost(), 132, "gold"))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	_total_box.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := UiTheme.outlined(UiTheme.label("TOTAL INCOME BOOST", 21, Color("fff3c4")), 6)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var ib := UiTheme.button("i", 22, Color("2f9bff"))
	ib.custom_minimum_size = Vector2(46, 46)
	ib.pressed.connect(open_info)
	head.add_child(ib)
	_formula = HBoxContainer.new()
	_formula.add_theme_constant_override("separation", 2)
	v.add_child(_formula)
	var base := GameState.base_boost()
	var groups := GameState.booster_groups()
	var shown := 0
	if base > 1.0:
		_formula.add_child(BoostGem.make("x" + num(base), base, 56, "ad" if GameState.perm_boost <= 1.0 else "gold"))
		if not groups.is_empty():
			_formula.add_child(_sym("×"))
	if not groups.is_empty():
		_formula.add_child(_sym("("))
		for k in groups.size():
			if shown >= 3:
				_formula.add_child(_sym("+%d" % (groups.size() - shown)))
				break
			if k > 0:
				_formula.add_child(_sym("+"))
			var g: Dictionary = groups[k]
			_formula.add_child(BoostGem.make("x" + num(g["mult"]), float(g["mult"]), 56, "", int(g["count"])))
			shown += 1
		_formula.add_child(_sym(")"))
	if base <= 1.0 and groups.is_empty():
		_formula.add_child(UiTheme.outlined(UiTheme.label("Nothing running yet", 20, Color.WHITE), 5))
	var cap := UiTheme.outlined(UiTheme.label("base boost  x  boosters added together", 17, Color.WHITE), 5)
	v.add_child(cap)


func _sym(t: String) -> Label:
	var l := UiTheme.outlined(UiTheme.label(t, 26, Color.WHITE), 6)
	l.add_theme_font_override("font", UiTheme.DISPLAY_FONT)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


func _card(rim: Color) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.card(Color("24428a"), 18, 4, UiTheme.INK))
	p.custom_minimum_size = Vector2(RUN_W, RUN_H - 8)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	_run_row.add_child(p)
	var inner := PanelContainer.new()
	var ib := StyleBoxFlat.new()
	ib.draw_center = false
	ib.set_border_width_all(3)
	ib.border_color = rim
	ib.set_corner_radius_all(14)
	ib.content_margin_left = 6
	ib.content_margin_right = 6
	ib.content_margin_top = 6
	ib.content_margin_bottom = 6
	inner.add_theme_stylebox_override("panel", ib)
	inner.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_child(inner)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	inner.add_child(v)
	return v


func _pill(v: VBoxContainer, until: float) -> Label:
	var l := UiTheme.label("", 18, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_stylebox_override("normal", UiTheme.card(Color("14244d"), 12, 4, UiTheme.INK))
	v.add_child(l)
	if until > 0.0:
		_timers.append([l, until])
	return l


func _small(v: VBoxContainer, t: String) -> void:
	var l := UiTheme.outlined(UiTheme.label(t, 16, Color.WHITE), 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)


func _center(v: VBoxContainer, c: Control) -> void:
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_PASS
	cc.add_child(c)
	v.add_child(cc)


func _build_running() -> void:
	_clear(_run_row)
	# the ad boost: always first (pinned on the left)
	var ad_on := GameState.ad_boost_left() > 0.0
	var v := _card(UiTheme.GOOD if ad_on else Color(1, 1, 1, 0.25))
	_small(v, "AD BOOST · HERE")   # v0.19v: per city
	_center(v, BoostGem.make("x" + num(Data.AD_BOOST_MULT), Data.AD_BOOST_MULT, 86, "ad" if ad_on else "grey"))
	_ad_pill = _pill(v, 0.0)   # v0.19v: its time is read live in _refresh (it used to keep the end time it was built with)
	_ad_pill.text = GameState.fmt_time(GameState.ad_boost_left()) if ad_on else "not running"
	_ad_btn = UiTheme.button("", 16, Color("43a047"))
	_ad_btn.custom_minimum_size = Vector2(0, 50)
	_ad_btn.pressed.connect(func():
		GameState.watch_ad_boost()
		Sfx.play("boost"))
	v.add_child(_ad_btn)
	# boosters: same booster = one badge, newest on the right
	var groups := GameState.booster_groups()
	for g in groups:
		var d := GameState.booster_def(str(g["id"]))
		var bv := _card(UiTheme.CARD_GOLD)
		_small(bv, _dur(float(d.get("minutes", 0.0))).to_upper())
		_center(bv, BoostGem.make("x" + num(g["mult"]), float(g["mult"]), 96, "", int(g["count"])))
		_pill(bv, float(g["until"]))
		if int(g["count"]) > 1:
			_small(bv, "%d running = x%s" % [int(g["count"]), num(g["total"])])
	if groups.is_empty():
		var e := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.set_border_width_all(3)
		sb.border_color = Color(1, 1, 1, 0.35)
		sb.set_corner_radius_all(18)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		e.add_theme_stylebox_override("panel", sb)
		e.custom_minimum_size = Vector2(RUN_W, RUN_H - 8)
		var l := UiTheme.label("USE a booster below and it runs here", 17, Color(1, 1, 1, 0.65))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		e.add_child(l)
		_run_row.add_child(e)


func _tile(grid: GridContainer, head: String, gem: Control) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.card(Color("5b86d6"), 18, 8, UiTheme.INK))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	grid.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var h := UiTheme.outlined(UiTheme.label(head, 21, Color.WHITE), 6)
	h.add_theme_font_override("font", UiTheme.DISPLAY_FONT)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(h)
	var well := PanelContainer.new()
	well.add_theme_stylebox_override("panel", UiTheme.card(Color("2b4c95"), 14, 6))
	well.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(well)
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_PASS
	cc.add_child(gem)
	well.add_child(cc)
	return v


func _build_inventory() -> void:
	_clear(_inv)
	var owned := 0
	for d in Data.BOOSTERS:
		var n := int(GameState.boosters.get(d["id"], 0))
		if n <= 0:
			continue
		owned += n
		var v := _tile(_inv, _dur(float(d["minutes"])), BoostGem.make("x" + num(d["mult"]), float(d["mult"]), 96))
		var l := UiTheme.label("%d left" % n, 16, Color("d8e6ff"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		var id: String = d["id"]
		var b := UiTheme.button("USE", 22, Color("ffc93c"))
		b.custom_minimum_size = Vector2(0, 54)
		b.pressed.connect(func():
			_last_added = true
			GameState.activate_booster(id)
			Sfx.play("boost"))
		v.add_child(b)
	_inv.columns = 3 if owned > 0 else 1
	if owned == 0:
		var l := UiTheme.label("None yet. You get one every time your rating goes up, or grab one of today's deals.", 18, UiTheme.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_inv.add_child(l)


func _build_deals() -> void:
	_clear(_deals)
	for id in GameState.deals():
		var d := GameState.booster_def(id)
		var v := _tile(_deals, _dur(float(d["minutes"])), BoostGem.make("x" + num(d["mult"]), float(d["mult"]), 80))
		var b := UiTheme.button("", 18, Color("2f9bff"))
		b.custom_minimum_size = Vector2(0, 50)
		b.pressed.connect(func(): GameState.buy_booster(id))
		v.add_child(b)
		_buy_btns.append([b, id])


# ---------------------------------------------------------------- live bits

func _refresh() -> void:
	if is_instance_valid(_ad_pill) and GameState.ad_boost_left() > 0.0:
		_ad_pill.text = GameState.fmt_time(GameState.ad_boost_left())
	for t in _timers:
		var l: Label = t[0]
		if is_instance_valid(l):
			l.text = GameState.fmt_time(maxf(0.0, float(t[1]) - GameState.now))
	if is_instance_valid(_ad_btn):
		var full := GameState.ad_boost_left() >= Data.AD_BOOST_MAX_HOURS * 3600.0 - 60.0
		_ad_btn.disabled = full
		_ad_btn.text = "FULL (24h)" if full else ("FREE" if GameState.ad_free() else "WATCH AD") + "  +%dh" % int(Data.AD_BOOST_HOURS)
	for pair in _buy_btns:
		var b: Button = pair[0]
		if not is_instance_valid(b):
			continue
		var d := GameState.booster_def(str(pair[1]))
		var sold := GameState.deal_sold(str(pair[1]))
		b.disabled = sold or GameState.gloss < int(d["price"])
		UiTheme.set_rich(b, "SOLD" if sold else "%d {sb}" % int(d["price"]))   # v0.19v: icon (was "SB")
	_deals_head.text = "TODAY'S DEALS  ·  new in %s" % GameState.fmt_time(GameState.deals_refresh_in())
	if _end_frames > 0:
		_end_frames -= 1
		_scroll_run_to_end()
	# "N more >" when badges are off the right edge
	var hidden := 0
	var right := _run_scroll.scroll_horizontal + _run_scroll.size.x
	for c in _run_row.get_children():
		if (c as Control).position.x + 40.0 > right:
			hidden += 1
	_more.modulate.a = 1.0 if hidden > 0 else 0.0
	_more.text = "  %d more  >  " % maxi(hidden, 1)


func _scroll_run_to_end() -> void:
	if is_instance_valid(_run_scroll):
		_run_scroll.scroll_horizontal = int(maxf(0.0, _run_row.get_combined_minimum_size().x - _run_scroll.size.x))


# ---------------------------------------------------------------- "i": the breakdown in words

func open_info() -> void:
	if _info != null and is_instance_valid(_info):
		return
	_info = Control.new()
	_info.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_info.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_info)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.05, 0.15, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			close_info())
	_info.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_child(cc)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.card(Color("fffbe6"), 22, 18, UiTheme.INK))
	card.custom_minimum_size = Vector2(get_viewport_rect().size.x - 60.0, 0)
	cc.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	v.add_child(UiTheme.ribbon("YOUR BOOSTS", 18, Color("ff9a2e")))
	_info_label = UiTheme.label(info_text(), 21, Color("3e2c00"))
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_info_label)
	var ok := UiTheme.button("GOT IT", 22, UiTheme.GOOD)
	ok.custom_minimum_size = Vector2(0, 62)
	ok.pressed.connect(close_info)
	v.add_child(ok)


func close_info() -> void:
	if _info != null and is_instance_valid(_info):
		_info.queue_free()
	_info = null
	_info_label = null


## The whole breakdown, for the "i" card.
static func info_text() -> String:
	var gs = GameState
	var lines: Array = []
	var base: float = gs.base_boost()
	var bs: float = gs.booster_sum()
	lines.append("Total: x%s income  =  base x%s  x  boosters x%s" % [num(gs.total_boost()), num(base), num(bs)])
	lines.append("")
	lines.append("BASE (multiplied together)")
	if gs.perm_boost > 1.0:
		lines.append("  •  Permanent x%s: always on, forever" % num(gs.perm_boost))
	if gs.ad_boost_left() > 0.0:
		lines.append("  •  Ad boost x%s in this city: %s left (each ad adds %dh, up to %dh; BOOST ALL on the map's COLLECT does a whole country)" % [num(Data.AD_BOOST_MULT), gs.fmt_time(gs.ad_boost_left()),
			int(Data.AD_BOOST_HOURS), int(Data.AD_BOOST_MAX_HOURS)])
	if base <= 1.0:
		lines.append("  •  Nothing yet. Watch an ad for x%s in this city for %d hours." % [num(Data.AD_BOOST_MULT), int(Data.AD_BOOST_HOURS)])
	lines.append("")
	lines.append("BOOSTERS (added together)")
	var groups: Array = gs.booster_groups()
	if groups.is_empty():
		lines.append("  •  None running. Tap USE on one of yours.")
	for g in groups:
		var d: Dictionary = gs.booster_def(str(g["id"]))
		lines.append("  •  %s%s: x%s, %s left" % [d.get("name", "Booster"), (" (%d running)" % int(g["count"])) if int(g["count"]) > 1 else "",
			num(g["total"]), gs.fmt_time(float(g["until"]) - gs.now)])
	lines.append("")
	if gs.raining():
		lines.append("RAINY DAY: muddy cars pay x%s in every bay while it rains (%s more of this weather at least)." % [num(Data.RAIN_PAY_MULT), gs.fmt_time(gs.weather_left())])
		lines.append("")
	lines.append("Boosters add up (x5 + x2 = x7), then multiply your base. The boost works in every city, and on what you earn while you're away.")
	return "\n".join(lines)


static func _dur(minutes: float) -> String:
	if minutes >= 10080.0 and int(minutes) % 10080 == 0:
		var w := int(minutes / 10080.0)
		return "%d week%s" % [w, "" if w == 1 else "s"]
	if minutes >= 1440.0:
		var d := int(round(minutes / 1440.0))
		return "%d day%s" % [d, "" if d == 1 else "s"]
	if minutes >= 60.0:
		var h := int(round(minutes / 60.0))
		return "%d hour%s" % [h, "" if h == 1 else "s"]
	return "%d min" % int(minutes)


static func num(x: Variant) -> String:
	var f := float(x)
	return str(int(round(f))) if absf(f - roundf(f)) < 0.05 else "%.1f" % f
