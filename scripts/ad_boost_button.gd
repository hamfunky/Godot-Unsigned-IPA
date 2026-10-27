extends Control
## v0.19v (Hamza, like Idle Miner / AdVenture Capitalist): the AD BOOST as a big round button in the middle
## of the bottom bar, so new players see it instead of hunting for it in Boosts. One tap = watch an ad =
## x2 here for +4h (banked up to 24h). The gold ring round the rim shows how much of the 24h is banked.
## Not running: it breathes (scale tween, no redraw). Redraws at most twice a second.

signal boost_pressed

const UiTheme = preload("res://scripts/ui_theme.gd")
const Data = preload("res://scripts/game_data.gd")

const D := 132.0               # the circle's diameter

var _down := false
var _sig := ""
var _check := 0.0
var _pulse: Tween = null
var _face: Control


func _ready() -> void:
	custom_minimum_size = Vector2(D + 24, D + 34)
	size = custom_minimum_size
	pivot_offset = Vector2(size.x * 0.5, D * 0.5 + 6)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_face = Control.new()
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.size = size
	_face.draw.connect(func(): _paint(_face))
	add_child(_face)


func _left() -> float:
	return GameState.ad_boost_left()


func _full() -> bool:
	return _left() >= Data.AD_BOOST_MAX_HOURS * 3600.0 - 60.0


func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.5
	var on := _left() > 0.0
	var s := "%s|%s|%s|%d" % [on, _full(), GameState.ad_free(), int(_left() / 60.0)]
	if s != _sig:
		_sig = s
		_face.queue_redraw()
	# breathe while it's not running (an invitation), sit still while it is
	if not on and _pulse == null:
		_pulse = create_tween().set_loops()
		_pulse.tween_property(self, "scale", Vector2(1.06, 1.06), 0.7).set_trans(Tween.TRANS_SINE)
		_pulse.tween_property(self, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)
	elif on and _pulse != null:
		_pulse.kill()
		_pulse = null
		scale = Vector2.ONE


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
			_face.queue_redraw()
		elif _down:
			_down = false
			_face.queue_redraw()
			if Rect2(Vector2.ZERO, size).has_point(event.position):
				boost_pressed.emit()


## v0.19w perf: the picture lives on a child (_face). Godot redraws a Control whenever its scale changes, and
## the breathing is a scale tween, so drawing on the button itself redrew it every frame.
func _paint(ci: Control) -> void:
	var ink := UiTheme.INK
	var on := _left() > 0.0
	var full := _full()
	var c := Vector2(size.x * 0.5, D * 0.5 + 6 + (3.0 if _down else 0.0))
	var r := D * 0.5
	# drop shadow, ink rim, white ring, green face with a lighter top, gloss
	ci.draw_circle(c + Vector2(0, 7), r + 4, Color(0, 0, 0, 0.3))
	ci.draw_circle(c, r + 4, ink)
	ci.draw_circle(c, r, Color.WHITE)
	var face := Color("2fb457") if not full else Color("3a9b5a")
	ci.draw_circle(c, r - 7, face.darkened(0.25))
	ci.draw_circle(c + Vector2(0, -3), r - 10, face)
	ci.draw_circle(c + Vector2(0, -r * 0.28), r * 0.55, face.lightened(0.18))
	ci.draw_arc(c, r - 18, PI * 1.15, PI * 1.6, 14, Color(1, 1, 1, 0.45), 7.0, true)
	# banked time: a gold ring round the rim, clockwise from the top (full ring = 24h)
	var frac := clampf(_left() / (Data.AD_BOOST_MAX_HOURS * 3600.0), 0.0, 1.0)
	ci.draw_arc(c, r - 3.5, 0, TAU, 48, Color(0, 0, 0, 0.12), 6.0, true)
	if frac > 0.0:
		ci.draw_arc(c, r - 3.5, -PI / 2.0, -PI / 2.0 + TAU * frac, 48, Color("ffc93c"), 6.0, true)
	# x2
	UiTheme.text(ci, Vector2(0, c.y + 10), "x%s" % str(int(Data.AD_BOOST_MULT)), 54, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, size.x, 9, UiTheme.DISPLAY_FONT)
	UiTheme.text(ci, Vector2(0, c.y + 34), "BOOST", 18, Color("eaffd9"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 5, UiTheme.DISPLAY_FONT)
	# the "watch an ad" badge, top right (a little TV with a play triangle); FREE with the no-ads pack
	var bc := c + Vector2(r * 0.66, -r * 0.62)
	if GameState.ad_free():
		UiTheme.rounded(ci, Rect2(bc + Vector2(-30, -14), Vector2(60, 28)), Color("ffc93c"), 10, 3, ink)
		UiTheme.text(ci, bc + Vector2(-30, 7), "FREE", 16, ink, HORIZONTAL_ALIGNMENT_CENTER, 60, 0, UiTheme.DISPLAY_FONT)
	elif not full:
		UiTheme.rounded(ci, Rect2(bc + Vector2(-22, -16), Vector2(44, 32)), Color("ff5a5f"), 9, 3, ink)
		var tri := PackedVector2Array([bc + Vector2(-6, -8), bc + Vector2(-6, 8), bc + Vector2(9, 0)])
		ci.draw_colored_polygon(tri, Color.WHITE)
	# the pill underneath: time left / +4h / FULL
	var t := ""
	if full:
		t = "FULL  " + GameState.fmt_time(_left())
	elif on:
		t = GameState.fmt_time(_left()) + "  +%dh" % int(Data.AD_BOOST_HOURS)
	else:
		t = ("FREE  +%dh" if GameState.ad_free() else "WATCH AD  +%dh") % int(Data.AD_BOOST_HOURS)
	var pw := 150.0
	var pr := Rect2(Vector2(size.x * 0.5 - pw * 0.5, D + 2), Vector2(pw, 30))
	UiTheme.rounded(ci, pr, Color("14244d") if on else Color("ff5a5f"), 12, 3, ink)
	UiTheme.text(ci, Vector2(pr.position.x, pr.position.y + 22), t, 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, pw, 4, UiTheme.DISPLAY_FONT)
