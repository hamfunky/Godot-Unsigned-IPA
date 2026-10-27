extends Control
## v0.19j (playtest round 2: "the top was cluttered, I could barely see the idle income / second"):
## top-LEFT of the HUD = two chunky pills in the same style as the Shine Bucks / Rating ones on the right.
## Top = CASH (bigger: still the number your eye goes to first), a gold coin badge. The number is a real Label
## (main.gd sets its text, pops it and flies coins to it). Bottom = IDLE income per second, a clock badge;
## tapping it opens the Overview (every city's income, so "other cities +$X/s" doesn't clutter the bar).
## The city name moved under the prestige trophy; followers live in the Rating card; the old
## "Tap to work · hire managers" line is gone.

signal rate_pressed

const UiTheme = preload("res://scripts/ui_theme.gd")

const PILL_W := 222.0
const CASH_H := 52.0
const RATE_H := 44.0
const BADGE := 34.0   # the badge sticks out past the left end of each pill (like HudMeta)

var cash_label: Label
var rate_text := "$0/s"
var _press_pos := Vector2.ZERO
var _pressing := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(PILL_W + BADGE + 2, CASH_H + RATE_H + 26)
	cash_label = UiTheme.display_label("$0", 32, UiTheme.CASH)
	cash_label.add_theme_color_override("font_outline_color", UiTheme.INK)
	cash_label.add_theme_constant_override("outline_size", 9)
	cash_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cash_label.position = Vector2(BADGE + 30, 2)
	cash_label.size = Vector2(PILL_W - 40, CASH_H - 4)
	add_child(cash_label)


var _sig := ""


func _process(_delta: float) -> void:
	# v0.19v perf: redraw when the text / press changes, and the clock hand ~10 times a second (not every frame)
	var s := "%s|%s|%d" % [rate_text, _pressing, int(Time.get_ticks_msec() / 100)]
	if s != _sig:
		_sig = s
		queue_redraw()


func cash_rect() -> Rect2:
	return Rect2(BADGE, 4, PILL_W, CASH_H)


func rate_rect() -> Rect2:
	return Rect2(BADGE, 4 + CASH_H + 14, PILL_W, RATE_H)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := rate_rect().grow(6)
		hit.position.x -= BADGE
		hit.size.x += BADGE
		if event.pressed:
			_pressing = hit.has_point(event.position)
			_press_pos = event.position
		elif _pressing:
			_pressing = false
			if event.position.distance_to(_press_pos) < 20.0:
				Sfx.play("click")
				rate_pressed.emit()


func _draw() -> void:
	# --- cash
	var a := cash_rect()
	_lip(a, Color("2e9e5b"), 0.0)
	var cc := a.position + Vector2(0, a.size.y * 0.5 - 2)
	draw_circle(cc, 29.0, UiTheme.INK)
	draw_circle(cc, 26.0, Color("d99a00"))
	draw_circle(cc + Vector2(0, -2), 22.0, UiTheme.CASH)
	draw_arc(cc + Vector2(0, -2), 17.0, 0.0, TAU, 28, Color("d99a00"), 2.5, true)
	UiTheme.text(self, cc + Vector2(-20, 8), "$", 26, Color("b36b00"), HORIZONTAL_ALIGNMENT_CENTER, 40, 0, UiTheme.DISPLAY_FONT)
	draw_arc(cc + Vector2(-2, -4), 13.0, PI * 1.1, PI * 1.55, 6, Color(1, 1, 1, 0.7), 3.0, true)
	# --- idle income per second (tap = Overview)
	var b := rate_rect()
	var down := 3.0 if _pressing else 0.0
	_lip(b, Color("1e88a8"), down)
	var kc := b.position + Vector2(0, 21 + down)
	draw_circle(kc, 27.0, UiTheme.INK)
	draw_circle(kc, 24.0, Color("1565c0"))
	draw_circle(kc, 17.0, Color.WHITE)
	draw_arc(kc, 17.0, 0.0, TAU, 24, UiTheme.INK, 2.0, true)
	var t := Time.get_ticks_msec() * 0.001
	draw_line(kc, kc + Vector2(0, -11), UiTheme.INK, 3.0, true)
	draw_line(kc, kc + Vector2(cos(t * 1.5), sin(t * 1.5)) * 13.0, Color("e53935"), 2.0, true)
	draw_circle(kc, 2.5, UiTheme.INK)
	UiTheme.text(self, b.position + Vector2(34, 32 + down), rate_text, 26, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiTheme.DISPLAY_FONT)
	var w := UiTheme.DISPLAY_FONT.get_string_size(rate_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	if 34.0 + w + 10.0 + 44.0 < b.size.x - 22.0:
		UiTheme.text(self, b.position + Vector2(34 + w + 10, 30 + down), "IDLE", 19, Color("d6f3ff"), HORIZONTAL_ALIGNMENT_LEFT, -1, 5, UiTheme.DISPLAY_FONT)
	var ch := Vector2(b.end.x - 18, b.position.y + 20 + down)
	draw_polyline(PackedVector2Array([ch + Vector2(-4, -7), ch + Vector2(3, 0), ch + Vector2(-4, 7)]), Color.WHITE, 3.0, true)


## Same chunky pill as HudMeta._lip: ink outline, darker lip at the bottom, shine strip.
func _lip(r: Rect2, c: Color, down: float) -> void:
	var body := Rect2(r.position + Vector2(0, down), r.size - Vector2(0, down))
	UiTheme.rounded(self, Rect2(r.position + Vector2(0, 5), r.size), c.darkened(0.42), 18, 3, UiTheme.INK)
	UiTheme.rounded(self, Rect2(body.position, body.size - Vector2(0, 5)), c, 18, 3, UiTheme.INK)
	UiTheme.rounded(self, Rect2(body.position + Vector2(14, 5), Vector2(r.size.x - 28, 6)), Color(1, 1, 1, 0.25), 3)
