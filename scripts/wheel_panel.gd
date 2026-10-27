extends "res://scripts/sheet.gd"
## v0.19n LUCKY WHEEL (Hamza 26 Oct): the early Shine Bucks sink. A free spin every WHEEL_FREE_HOURS, more for
## WHEEL_SPIN_COST Shine Bucks. 12 prizes in 4 tiers (Common / Rare / Epic / Legendary, odds in
## Data.WHEEL_TIERS); the "i" next to the title lists every prize's chance. The prize is given the moment you
## spin (GameState.spin_wheel); the wheel just spins round to it and then says what you won.
## setup() = the wheel, setup_odds() = the odds card (opened by the "i").

const Data = preload("res://scripts/game_data.gd")
const HudMeta = preload("res://scripts/hud_meta.gd")

const SPIN_TIME := 4.2

var _wheel: Control
var _spin_btn: Button
var _status: RichTextLabel   # v0.19v: rich (the Shine Bucks icon)
var _result: PanelContainer
var _res_title: Label
var _res_text: Label
var _res_detail: Label
var _spinning := false
var _pending: Dictionary = {}
var _tick := 0.0


class WheelView extends Control:
	const UiTheme = preload("res://scripts/ui_theme.gd")
	const Data = preload("res://scripts/game_data.gd")
	const HudMeta = preload("res://scripts/hud_meta.gd")
	var rot := 0.0          # radians, clockwise
	var glow := -1          # slice that won (lit up after the spin)
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var n: int = Data.WHEEL_PRIZES.size()
		var step := TAU / float(n)
		var c := Vector2(size.x * 0.5, size.y * 0.5 + 10)
		var r := minf(size.x, size.y - 20) * 0.5 - 10
		var ink := UiTheme.INK
		draw_circle(c + Vector2(0, 8), r + 12, Color(0, 0, 0, 0.35))
		draw_circle(c, r + 12, ink)
		draw_circle(c, r + 9, Color("ffcf4a"))
		draw_circle(c, r + 1, ink)
		for i in n:
			var p: Dictionary = Data.WHEEL_PRIZES[i]
			var tier: int = int(p["tier"])
			var col := Color(Data.WHEEL_TIERS[tier]["color"])
			if i % 2 == 1:
				col = col.darkened(0.12)
			if glow == i:
				col = col.lightened(0.25 + 0.15 * sin(_t * 8.0))
			var a0 := -PI / 2.0 + rot + (i - 0.5) * step
			var pts := PackedVector2Array([c])
			for k in 13:
				var a := a0 + step * k / 12.0
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(pts, col)
			# the outer band of each slice a touch lighter (reads like a gloss rim)
			var band := PackedVector2Array()
			for k in 13:
				var a := a0 + step * k / 12.0
				band.append(c + Vector2(cos(a), sin(a)) * r)
			for k in range(12, -1, -1):
				var a := a0 + step * k / 12.0
				band.append(c + Vector2(cos(a), sin(a)) * (r - 16))
			draw_colored_polygon(band, col.lightened(0.18))
		for i in n:
			var a := -PI / 2.0 + rot + (i - 0.5) * step
			draw_line(c, c + Vector2(cos(a), sin(a)) * r, ink, 3.0, true)
			draw_circle(c + Vector2(cos(a), sin(a)) * (r + 5), 4.5, Color("fff6d6"))
		# labels, reading outwards
		for i in n:
			var p: Dictionary = Data.WHEEL_PRIZES[i]
			var tier: int = int(p["tier"])
			var a := -PI / 2.0 + rot + i * step
			var t: Array = GameState.wheel_slice_text(i)
			draw_set_transform(c + Vector2(cos(a), sin(a)) * r * 0.64, a + PI / 2.0, Vector2.ONE)
			var big: String = t[0]
			var fs := 30 if big.length() <= 4 else (24 if big.length() <= 6 else 20)
			if str(p["kind"]) == "legend":
				HudMeta.draw_star(self, Vector2(0, -24), 17.0, true)
				fs = 20
			elif str(p["kind"]) == "case":
				_file_icon(Vector2(0, -30), Color(_file_color(str(p["file"]))))
				fs = 20
			elif str(p["kind"]) == "cash":
				_cash_icon(Vector2(0, -30))
				fs = 24
			UiTheme.text(self, Vector2(-60, 10), big, fs, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 120, 6, UiTheme.DISPLAY_FONT)
			UiTheme.text(self, Vector2(-60, 32), str(t[1]), 18 if tier < 3 else 18, Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 120, 4)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# hub
		draw_circle(c, 46, ink)
		draw_circle(c, 43, Color("ffcf4a"))
		draw_circle(c, 33, Color("ff9a2e"))
		HudMeta.draw_droplet(self, c, 16.0)
		# pointer at the top (doesn't spin)
		var tip := c + Vector2(0, -r + 14)
		var top := c + Vector2(0, -r - 26)
		var pp := PackedVector2Array([tip, top + Vector2(-22, 0), top + Vector2(22, 0)])
		draw_colored_polygon(PackedVector2Array([tip + Vector2(0, 4), top + Vector2(-22, 4), top + Vector2(22, 4)]), Color(0, 0, 0, 0.3))
		draw_colored_polygon(pp, Color("e8553d"))
		pp.append(pp[0])
		draw_polyline(pp, ink, 3.0, true)
		draw_circle(top + Vector2(0, -2), 10, ink)
		draw_circle(top + Vector2(0, -2), 7, Color("fff6d6"))

	func _file_color(id: String) -> String:
		for f in Data.CASE_FILES:
			if f["id"] == id:
				return str(f["color"])
		return "8d6e63"

	func _file_icon(at: Vector2, col: Color) -> void:
		var ink := UiTheme.INK
		UiTheme.rounded(self, Rect2(at + Vector2(-16, -11), Vector2(14, 6)), col.darkened(0.2), 2, 2, ink)
		UiTheme.rounded(self, Rect2(at + Vector2(-16, -7), Vector2(32, 22)), col, 3, 2, ink)
		draw_rect(Rect2(at + Vector2(-10, 0), Vector2(20, 3)), Color(1, 1, 1, 0.6))

	func _cash_icon(at: Vector2) -> void:
		var ink := UiTheme.INK
		for k in 3:
			UiTheme.rounded(self, Rect2(at + Vector2(-17, -4 - k * 5), Vector2(34, 10)), Color("6fd36a").darkened(0.12 * k), 3, 2, ink)
		draw_circle(at + Vector2(0, -9), 4, Color("2e7d32"))


func setup() -> void:
	set_title("Lucky Wheel")
	_add_info_button()
	var intro := UiTheme.label("Spin for boosters, instant cash, Case Files... or a Legendary manager!", 19, UiTheme.MUTED)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(intro)
	_wheel = WheelView.new()
	_wheel.custom_minimum_size = Vector2(0, 600)
	_wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_wheel)
	_result = PanelContainer.new()
	_result.add_theme_stylebox_override("panel", UiTheme.card(Color("3a2c7a"), 18, 16, UiTheme.CARD_GOLD))
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 6)
	_result.add_child(rv)
	_res_title = UiTheme.display_label("YOU WON!", 28, UiTheme.CASH)
	_res_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(_res_title)
	_res_text = UiTheme.display_label("", 26, Color.WHITE)
	_res_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_res_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rv.add_child(_res_text)
	_res_detail = UiTheme.label("", 19, UiTheme.MUTED)
	_res_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_res_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rv.add_child(_res_detail)
	_result.visible = false
	body.add_child(_result)
	_spin_btn = UiTheme.button("", 26, UiTheme.GOOD)
	_spin_btn.custom_minimum_size = Vector2(0, 84)
	_spin_btn.pressed.connect(_on_spin)
	body.add_child(_spin_btn)
	_status = UiTheme.rich_label("", 19, UiTheme.MUTED)
	body.add_child(_status)
	_refresh()


## The "i" next to the title: every prize's chance.
func _add_info_button() -> void:
	var head: Control = _title.get_parent()
	var ib := UiTheme.button("i", 26, Color("2f9bff"))
	ib.custom_minimum_size = Vector2(56, 56)
	ib.pressed.connect(func():
		var p = load("res://scripts/wheel_panel.gd").new()
		get_parent().add_child(p)
		p.setup_odds())
	head.add_child(ib)
	head.move_child(ib, 1)


func setup_odds() -> void:
	set_title("Wheel odds")
	var intro := UiTheme.label("Every spin lands on one of 12 prizes. The chance of each:", 19, UiTheme.MUTED)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(intro)
	for t in range(Data.WHEEL_TIERS.size() - 1, -1, -1):
		var tier: Dictionary = Data.WHEEL_TIERS[t]
		body.add_child(UiTheme.ribbon("%s  ·  %s%%" % [str(tier["name"]).to_upper(), _pct(float(tier["chance"]))], 18, Color(tier["color"])))
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", UiTheme.card(UiTheme.CARD, 14, 12))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		box.add_child(v)
		for i in Data.WHEEL_PRIZES.size():
			if int(Data.WHEEL_PRIZES[i]["tier"]) != t:
				continue
			var h := HBoxContainer.new()
			var a := UiTheme.label(GameState.wheel_prize_name(i), 20)
			a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(a)
			h.add_child(UiTheme.label("%s%%" % _pct(GameState.wheel_chance(i)), 20, UiTheme.CASH))
			v.add_child(h)
		body.add_child(box)
	var note := UiTheme.rich_label("Boosters go to YOUR BOOSTERS (use them when you like). Instant cash = that long of what your shop makes right now. Free spin every %dh, or %d {sb} a spin." % [
		int(Data.WHEEL_FREE_HOURS), Data.WHEEL_SPIN_COST], 18, UiTheme.MUTED, 0, false, false)
	body.add_child(note)


static func _pct(x: float) -> String:
	if is_equal_approx(x, round(x)):
		return str(int(round(x)))
	if is_equal_approx(x * 10.0, round(x * 10.0)):
		return "%.1f" % x
	return "%.2f" % x


func _process(delta: float) -> void:
	if _spin_btn == null:
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		_refresh()


func _refresh() -> void:
	if _spin_btn == null:
		return
	var free := GameState.wheel_free_ready()
	if _spinning:
		_spin_btn.disabled = true
		UiTheme.set_rich(_spin_btn, "SPINNING...")
	elif free:
		_spin_btn.disabled = false
		UiTheme.set_rich(_spin_btn, "FREE SPIN!")
	else:
		_spin_btn.disabled = GameState.gloss < Data.WHEEL_SPIN_COST
		UiTheme.set_rich(_spin_btn, "SPIN  ·  %d {sb}" % Data.WHEEL_SPIN_COST)   # v0.19v: icon, not the words
	if free:
		UiTheme.set_bb(_status, "Your free spin is ready.")
	else:
		UiTheme.set_bb(_status, "Next free spin in %s  ·  you have %s {sb}" % [GameState.fmt_time(GameState.wheel_free_in()), GameState.fmt(GameState.gloss)])


func _on_spin() -> void:
	if _spinning:
		return
	var res := GameState.spin_wheel(GameState.wheel_free_ready())
	if res.is_empty():
		Sfx.play("error")
		return
	Sfx.play("click")
	Sfx.buzz(20)
	_spinning = true
	_pending = res
	_result.visible = false
	_wheel.glow = -1
	var n: int = Data.WHEEL_PRIZES.size()
	var step := TAU / float(n)
	var idx: int = int(res["index"])
	# land slice idx under the pointer: rot = -idx*step (mod TAU), plus 5 full turns, a little off-centre
	var target := -float(idx) * step + randf_range(-0.32, 0.32) * step
	var cur: float = _wheel.rot
	var delta := fposmod(target - cur, TAU)
	var tw := create_tween()
	tw.tween_property(_wheel, "rot", cur + delta + TAU * 5.0, SPIN_TIME).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_reveal)
	_refresh()


func _reveal() -> void:
	_spinning = false
	var res := _pending
	_wheel.glow = int(res["index"])
	var tier: int = int(Data.WHEEL_PRIZES[int(res["index"])]["tier"])
	_res_title.text = ["YOU WON!", "NICE ONE!", "EPIC WIN!", "JACKPOT!"][tier]
	_res_text.text = str(res["text"])
	_res_detail.text = str(res["detail"])
	_result.visible = true
	Sfx.play("big_win" if tier >= 2 else "boost")
	Sfx.buzz(60 if tier >= 2 else 30)
	_refresh()


## Test shortcut: skip the animation.
func finish_now() -> void:
	if _spinning:
		for tw in get_tree().get_processed_tweens():
			tw.custom_step(SPIN_TIME + 0.1)
