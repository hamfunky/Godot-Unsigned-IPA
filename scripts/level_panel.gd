extends "res://scripts/sheet.gd"
## Level-up panel for any station: buy x1 / x10 / x50 / to next boost / max.
## v0.19i (Hamza, Idle Miner style): a big stats card (icon, name, value, green "+what this upgrade adds")
## instead of the boost ladder; taller, big text, no scrolling. The next-boost line says what the boost gives.
## < > arrows in the title row step through the stations in order:
## Front Desk -> Valet -> Bay 1 -> ... -> last bay, wrapping round at both ends.

const Data = preload("res://scripts/game_data.gd")
const HudMeta = preload("res://scripts/hud_meta.gd")

const MODES := [1, 10, 50, "next", "max"]
const MODE_NAMES := ["x1", "x10", "x50", "NEXT\nBOOST", "MAX"]
const BODY_H := 900.0        # v0.19i: the panel always fills ~3/4 of the screen (Idle Miner)
const ROW_H := 122.0
const STAT_FONT := 30
const DELTA_FONT := 25
## The stat rows per area: [id, name, icon]
const STATS := {
	"bay": [["income", "Income", "money"], ["pay", "Pay per Car", "car"], ["time", "Time per Car", "clock"]],
	"valet": [["transport", "Total Transport", "money"], ["load", "Load per Trip", "ute"], ["loadspd", "Loading Speed", "load"],
		["drive", "Driving Speed", "speed"]],
	"desk": [["checkout", "Total Checkout", "money"], ["batch", "Cash per Checkout", "till"], ["ctime", "Checkout Time", "clock"]],
}

static var mode_index := 0   # remembered between openings

var key := ""
var _service: Label
var _next: Label
var _next_bar: ProgressBar
var _next_gloss: Label
var _next_drop: Control
var _stats_box: VBoxContainer
var _stats_area := ""
var _rows := {}               # stat id -> [value Label, delta Label]
var _hint: Label
var _mode_btns: Array = []
var _buy: Button
var _look_mode := -1
var _preview: Control
var _preview_to := 0.0   # bar fraction the selected upgrade would reach


func setup(station_key: String) -> void:
	set_finish("gloss")   # v0.19u
	key = station_key

	# station arrows either side of the title
	var head: HBoxContainer = _title.get_parent()
	var prev := UiTheme.button("<", 26, Color("2a63c4"))
	prev.custom_minimum_size = Vector2(56, 56)
	prev.pressed.connect(func(): step(-1))
	head.add_child(prev)
	head.move_child(prev, 0)
	var nxt := UiTheme.button(">", 26, Color("2a63c4"))
	nxt.custom_minimum_size = Vector2(56, 56)
	nxt.pressed.connect(func(): step(1))
	head.add_child(nxt)
	head.move_child(nxt, 2)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_service = UiTheme.label("", 22, UiTheme.MUTED)
	body.add_child(_service)

	var nb := PanelContainer.new()
	nb.add_theme_stylebox_override("panel", UiTheme.card(UiTheme.CARD, 14, 14))
	body.add_child(nb)
	var nv := VBoxContainer.new()
	nb.add_child(nv)
	_next = UiTheme.label("", 21, UiTheme.CASH)
	nv.add_child(_next)
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 8)
	nv.add_child(bar_row)
	_next_bar = ProgressBar.new()
	_next_bar.show_percentage = false
	_next_bar.custom_minimum_size = Vector2(0, 14)
	_next_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_next_bar.max_value = 1.0
	_next_bar.step = 0.0
	bar_row.add_child(_next_bar)
	# v0.17g (Hamza): a soft green "ghost" on the bar = how far the selected upgrade (x1 / x10 / x50 /
	# NEXT BOOST / MAX) would take it. The bright fill stays the real progress.
	_preview = Control.new()
	_preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.draw.connect(_draw_preview)
	_next_bar.add_child(_preview)
	# the boost's Gloss reward at the end of the bar: "+5" and a droplet
	_next_gloss = UiTheme.label("", 20, Color("81d4fa"))
	bar_row.add_child(_next_gloss)
	_next_drop = Control.new()
	_next_drop.custom_minimum_size = Vector2(32, 26)
	_next_drop.draw.connect(func(): HudMeta.draw_droplet(_next_drop, Vector2(16, 14), 10.0))
	bar_row.add_child(_next_drop)

	var sc := PanelContainer.new()
	sc.add_theme_stylebox_override("panel", UiTheme.card(UiTheme.PANEL_LIGHT, 16, 6))
	body.add_child(sc)
	_stats_box = VBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", 0)
	sc.add_child(_stats_box)
	_hint = UiTheme.label("", 21, Color("ffb74d"))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_hint)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	body.custom_minimum_size.y = BODY_H

	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 8)
	body.add_child(modes)
	for i in MODES.size():
		var b := UiTheme.button(MODE_NAMES[i], 20, Color("2a63c4"))
		b.custom_minimum_size = Vector2(0, 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): mode_index = i)
		modes.add_child(b)
		_mode_btns.append(b)

	_buy = UiTheme.button("", 28, UiTheme.GOOD)
	_buy.custom_minimum_size = Vector2(0, 92)
	_buy.pressed.connect(_on_buy)
	body.add_child(_buy)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


## Station order for the arrows: Front Desk, Valet, Bay 1 ... last bay.
func station_order() -> Array:
	var keys := ["desk", "valet"]
	for i in GameState.bays.size():
		keys.append("bay%d" % i)
	return keys


## Move to the previous (-1) or next (+1) station, wrapping at both ends.
func step(dir: int) -> void:
	var keys := station_order()
	var k := keys.find(key)
	key = keys[posmod((k if k >= 0 else 0) + dir, keys.size())]
	_refresh()


## v0.17h (playtest): swipe left / right on the panel = next / previous station.
var _swipe_from := Vector2(-1, -1)


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_swipe_from = event.position if _panel.get_global_rect().has_point(event.position) else Vector2(-1, -1)
	elif _swipe_from.x >= 0.0:
		var d: Vector2 = event.position - _swipe_from
		_swipe_from = Vector2(-1, -1)
		if absf(d.x) > 110.0 and absf(d.y) < absf(d.x) * 0.6:
			Sfx.play("click")
			step(-1 if d.x > 0.0 else 1)
			_sheet_scroll.modulate.a = 0.35
			create_tween().tween_property(_sheet_scroll, "modulate:a", 1.0, 0.18)


func _n() -> int:
	return GameState.levels_for_mode(key, MODES[mode_index])


func _draw_preview() -> void:
	var w := _preview.size.x - 4.0
	var x0 := 2.0 + w * float(_next_bar.value)
	var x1 := 2.0 + w * _preview_to
	if x1 - x0 < 1.0:
		return
	var pulse := 0.32 + 0.08 * sin(Time.get_ticks_msec() * 0.006)
	UiTheme.rounded(_preview, Rect2(x0, 2, x1 - x0, _preview.size.y - 4), Color(0.36, 0.89, 0.44, pulse), 7)


func _on_buy() -> void:
	var before := GameState.station_rate(key)
	var lv := GameState.level_of(key)
	GameState.buy_levels(key, _n())
	# v0.19t: what that bought, popped over the button ("+$1.2K/s")
	var gain := GameState.station_rate(key) - before
	if GameState.level_of(key) > lv and gain > 0.0:
		var unit := "/s"
		UiTheme.pop_text(self, "+%s%s" % [GameState.money(gain), unit], _buy.get_global_rect().position - get_global_rect().position + Vector2(_buy.size.x * 0.5 - 160.0, -46.0),
			Color("6fe3a0"), 26)


func _refresh() -> void:
	var lvl := GameState.level_of(key)
	set_title("%s  ·  Level %d" % [GameState.station_name(key), lvl])
	_service.text = "Now: " + GameState.current_boost(key)["name"]

	var nxt := GameState.next_boost(key)
	if nxt.is_empty():
		_next.text = "All boosts unlocked!"
		_next_bar.value = 1.0
		_preview_to = 1.0
		_next_gloss.visible = false
		_next_drop.visible = false
	else:
		var prev := int(GameState.current_boost(key)["level"])
		_next.text = "Next boost at Lv %d:  %s" % [int(nxt["level"]), _boost_gives(nxt)]
		_next_bar.value = float(lvl - prev) / float(int(nxt["level"]) - prev)
		var pn := _n()
		if MODES[mode_index] is String and MODES[mode_index] == "max" and GameState.levels_cost(key, pn) > GameState.cash:
			pn = 0   # MAX shows only what you can actually afford
		_preview_to = clampf(float(lvl + pn - prev) / float(int(nxt["level"]) - prev), 0.0, 1.0)
		var g := GameState.boost_gloss(key, nxt)
		_next_gloss.text = "+%d" % g
		_next_gloss.visible = g > 0
		_next_drop.visible = g > 0

	_preview.queue_redraw()
	var n := _n()
	_refresh_stats(lvl, lvl + n)

	if _look_mode != mode_index:
		_look_mode = mode_index
		for i in _mode_btns.size():
			UiTheme.set_tab_look(_mode_btns[i], i == mode_index)

	if n <= 0:
		_buy.text = "MAX LEVEL"
		_buy.disabled = true
	else:
		var cost := GameState.levels_cost(key, n)
		var off := GameState.ability_discount(key)
		_buy.text = "UPGRADE +%d   %s%s" % [n, GameState.money(cost), ("  (-%d%%)" % int(off * 100)) if off > 0.0 else ""]
		_buy.disabled = GameState.cash < cost



## What the next boost gives, in words ("x3 income").
func _boost_gives(b: Dictionary) -> String:
	var what := "income"
	match GameState.area_of(key):
		"valet":
			what = "load"
		"desk":
			what = "cash per checkout"
	return "x%s %s" % [_num(b["mult"]), what]


func _build_stats(area: String) -> void:
	_stats_area = area
	_rows.clear()
	for c in _stats_box.get_children():
		_stats_box.remove_child(c)
		c.queue_free()
	var list: Array = STATS[area]
	for k in list.size():
		var st: Array = list[k]
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, ROW_H)
		row.add_theme_constant_override("separation", 14)
		var ic := Control.new()
		ic.custom_minimum_size = Vector2(84, 84)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var kind: String = st[2]
		ic.draw.connect(func(): draw_stat_icon(ic, kind, Rect2(Vector2.ZERO, ic.size)))
		row.add_child(ic)
		var nm := UiTheme.display_label(st[1], STAT_FONT)
		nm.add_theme_color_override("font_outline_color", UiTheme.INK)
		nm.add_theme_constant_override("outline_size", 6)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(nm)
		var vb := PanelContainer.new()
		vb.add_theme_stylebox_override("panel", UiTheme.box(Color("1b2f63"), 10, 8))
		vb.custom_minimum_size = Vector2(230, 0)
		vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(vb)
		var vv := VBoxContainer.new()
		vv.add_theme_constant_override("separation", -4)
		vb.add_child(vv)
		var val := UiTheme.label("", STAT_FONT, Color.WHITE)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vv.add_child(val)
		var dl := UiTheme.label("", DELTA_FONT, UiTheme.GOOD)
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vv.add_child(dl)
		_rows[st[0]] = [val, dl]
		_stats_box.add_child(row)
		if k < list.size() - 1:
			var line := ColorRect.new()
			line.color = Color(1, 1, 1, 0.12)
			line.custom_minimum_size = Vector2(0, 2)
			_stats_box.add_child(line)


## Fill one row: value now, and the green "+change" the selected upgrade makes (lower is better for times).
func _set_row(id: String, now: String, delta: String, better: bool, zero: bool) -> void:
	var r: Array = _rows[id]
	r[0].text = now
	r[1].text = delta
	r[1].add_theme_color_override("font_color", UiTheme.MUTED if zero else (UiTheme.GOOD if better else Color("ffb74d")))


func _money_row(id: String, a: float, b: float, suffix := "") -> void:
	var d := b - a
	_set_row(id, GameState.money(a) + suffix, "+" + GameState.money(maxf(0.0, d)) + suffix, d >= 0.0, d <= a * 1e-6)


func _mult_row(id: String, a: float, b: float) -> void:
	var d := b - a
	_set_row(id, "x%.2f" % a, "+%.2f" % maxf(0.0, d), true, absf(d) < 0.005)


func _time_row(id: String, a: float, b: float) -> void:
	var d := b - a
	var zero := absf(d) < 0.05
	_set_row(id, "%.1fs" % a, ("+0s" if zero else ("%+.1fs" % d)), d < 0.0, zero)


func _refresh_stats(lvl: int, after: int) -> void:
	var area := GameState.area_of(key)
	if area != _stats_area:
		_build_stats(area)
	match area:
		"bay":
			var i := GameState.bay_index(key)
			_money_row("income", GameState.bay_income(i), GameState.bay_income(i, after), "/s")
			_money_row("pay", GameState.bay_pay_per_car(i), GameState.bay_pay_per_car(i, after))
			_time_row("time", GameState.bay_cycle_time(i), GameState.bay_cycle_time(i, after))
		"valet":
			_money_row("transport", GameState.valet_rate(), GameState.valet_rate(after), "/s")
			_money_row("load", GameState.valet_capacity(), GameState.valet_capacity(after))
			_mult_row("loadspd", GameState.valet_load_speed(), GameState.valet_load_speed(after))
			_mult_row("drive", GameState.valet_speed(), GameState.valet_speed(after))
		_:
			_money_row("checkout", GameState.desk_rate(), GameState.desk_rate(after), "/s")
			_money_row("batch", GameState.desk_capacity(), GameState.desk_capacity(after))
			_time_row("ctime", GameState.desk_cycle_time(), GameState.desk_cycle_time())
	# the one thing worth knowing before you spend: is this the station holding the shop back?
	var neck := GameState.bottleneck()
	var slow := GameState.bays_total_income() > 0.0 and ((neck == "bays" and area == "bay") or neck == area)
	_hint.text = ("Your slowest station: upgrading this raises your income the most." if area != "bay"
		else "Your bays are your slowest station: upgrading them raises your income the most.") if slow else ""


## Stat icons, drawn in code (cartoon tile, ink outline).
static func draw_stat_icon(ci: CanvasItem, kind: String, r: Rect2) -> void:
	var c := r.get_center()
	var s := minf(r.size.x, r.size.y)
	_tile(ci, r)
	var ink := UiTheme.INK
	match kind:
		"money":
			ci.draw_circle(c, s * 0.3 + 2.5, ink)
			ci.draw_circle(c, s * 0.3, Color("ffd23f"))
			ci.draw_circle(c, s * 0.22, Color("f5b70a"))
			_txt(ci, c, "$", int(s * 0.42), Color("fff6cf"))
		"car":
			var Art = load("res://scripts/car_view.gd")
			Art.draw_car(ci, Rect2(c.x - s * 0.38, c.y - s * 0.16, s * 0.76, s * 0.3), Color("4fc3f7"), 0.0, [])
		"clock":
			ci.draw_circle(c, s * 0.3 + 2.5, ink)
			ci.draw_circle(c, s * 0.3, Color.WHITE)
			ci.draw_line(c, c + Vector2(0, -s * 0.2), ink, 3.5)
			ci.draw_line(c, c + Vector2(s * 0.14, s * 0.05), ink, 3.5)
			ci.draw_circle(c, 3.5, Color("ff5a5f"))
		"ute":
			var Art2 = load("res://scripts/car_view.gd")
			Art2.draw_car(ci, Rect2(c.x - s * 0.4, c.y - s * 0.2, s * 0.8, s * 0.36), Color("ffc93c"), 0.0, [], 0.0, false, _ute_car())
		"load":
			for k in 3:
				var y := c.y + s * 0.18 - k * s * 0.13
				ci.draw_rect(Rect2(c.x - s * 0.24 - 2, y - 2, s * 0.48 + 4, s * 0.1 + 4), ink)
				ci.draw_rect(Rect2(c.x - s * 0.24, y, s * 0.48, s * 0.1), Color("6cc070") if k != 1 else Color("8fd694"))
			ci.draw_line(c + Vector2(s * 0.3, s * 0.05), c + Vector2(s * 0.3, -s * 0.3), Color("ffd23f"), 4.0)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.3, -s * 0.38), c + Vector2(s * 0.22, -s * 0.26), c + Vector2(s * 0.38, -s * 0.26)]), Color("ffd23f"))
		"speed":
			ci.draw_arc(c + Vector2(0, s * 0.08), s * 0.3, PI, TAU, 24, ink, 9.0, true)
			ci.draw_arc(c + Vector2(0, s * 0.08), s * 0.3, PI, TAU, 24, Color("4fc3f7"), 5.0, true)
			ci.draw_line(c + Vector2(0, s * 0.08), c + Vector2(s * 0.2, -s * 0.12), ink, 4.5)
			ci.draw_line(c + Vector2(0, s * 0.08), c + Vector2(s * 0.2, -s * 0.12), Color("ff5a5f"), 2.5)
			ci.draw_circle(c + Vector2(0, s * 0.08), 4.0, ink)
		"till":
			ci.draw_rect(Rect2(c.x - s * 0.3 - 2, c.y - 2, s * 0.6 + 4, s * 0.26 + 4), ink)
			ci.draw_rect(Rect2(c.x - s * 0.3, c.y, s * 0.6, s * 0.26), Color("62c7b8"))
			ci.draw_rect(Rect2(c.x - s * 0.18 - 2, c.y - s * 0.26 - 2, s * 0.36 + 4, s * 0.2 + 4), ink)
			ci.draw_rect(Rect2(c.x - s * 0.18, c.y - s * 0.26, s * 0.36, s * 0.2), Color("a5d6a7"))


static var _ute := {}


## A car def drawn in the "ute" style (the valet's ride) for the Load per Trip icon.
static func _ute_car() -> Dictionary:
	if _ute.is_empty():
		var CA = load("res://scripts/car_art.gd")
		for c in Data.CARS:
			if CA.style_of(c) == "ute":
				_ute = c
				break
		if _ute.is_empty():
			_ute = {"tier": 2, "class": "jdm"}
	return _ute


static func _tile(ci: CanvasItem, r: Rect2) -> void:
	var sb := UiTheme.box(Color("223a78"), 14, 0)
	sb.border_color = UiTheme.INK
	sb.set_border_width_all(3)
	ci.draw_style_box(sb, r)


static func _txt(ci: CanvasItem, c: Vector2, t: String, size: int, col: Color) -> void:
	var f: Font = UiTheme.DISPLAY_FONT
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string_outline(f, c + Vector2(-w * 0.5, size * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, UiTheme.INK)
	ci.draw_string(f, c + Vector2(-w * 0.5, size * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


static func _num(x: Variant) -> String:
	var f := float(x)
	return str(int(f)) if is_equal_approx(f, roundf(f)) else "%.1f" % f
