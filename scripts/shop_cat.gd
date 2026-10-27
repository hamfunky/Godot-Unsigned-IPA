extends RefCounted
## v0.19t SUDS, THE SHOP CAT (drawn in code, lives on the valet's forecourt). Mostly naps (curled up, a slow
## "z" drifting up), now and then sits up and swishes her tail. Tap her = a pet: she shuts her eyes happily
## and hearts float up; the first pet of a (local) day leaves a small treat (GameState.pet_cat). Silent apart
## from the tap itself (Hamza: sounds only for what the player does).

const UiTheme = preload("res://scripts/ui_theme.gd")

const FUR := Color("f4a24a")
const FUR_DARK := Color("d9822f")
const CHEST := Color("fff3e0")
const NOSE := Color("ff8fab")

var pos := Vector2.ZERO        # where her paws touch the ground (row coords)
var _happy_until := 0.0        # ms: eyes shut, purring
var _awake_until := 0.0        # ms: sitting up after a pet
var _hearts: Array = []        # [Vector2 start, float born_ms, float drift]


func rect() -> Rect2:
	return Rect2(pos.x - 30, pos.y - 52, 60, 56)


func awake(ms: float) -> bool:
	if ms < _awake_until:
		return true
	return fmod(ms * 0.001, 95.0) < 22.0   # sits up ~22 s out of every 95 s, naps the rest


func pet(ms: float) -> void:
	_happy_until = ms + 2200.0
	_awake_until = ms + 14000.0
	for k in 3:
		_hearts.append([pos + Vector2(-10 + k * 10, -44), ms + k * 160.0, randf_range(-12.0, 12.0)])


func draw(ci: CanvasItem, ms: float) -> void:
	var ink := UiTheme.INK
	# shadow
	ci.draw_set_transform(pos + Vector2(0, -1), 0.0, Vector2(1.0, 0.25))
	ci.draw_circle(Vector2.ZERO, 26.0, Color(0, 0, 0, 0.22))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if awake(ms):
		_draw_sitting(ci, ms, ms < _happy_until)
	else:
		_draw_sleeping(ci, ms)
	# hearts
	var keep: Array = []
	for h in _hearts:
		var age: float = (ms - float(h[1])) / 1000.0
		if age < 0.0:
			keep.append(h)
			continue
		if age > 1.4:
			continue
		keep.append(h)
		var p: Vector2 = h[0] + Vector2(float(h[2]) * age, -34.0 * age)
		_heart(ci, p, 7.0 + age * 2.0, 1.0 - age / 1.4)
	_hearts = keep


func _draw_sleeping(ci: CanvasItem, ms: float) -> void:
	var ink := UiTheme.INK
	var b := pos + Vector2(0, -12)
	var breathe := 1.0 + 0.03 * sin(ms * 0.0022)
	# tail wrapped round the front
	ci.draw_arc(b + Vector2(2, 4), 20.0, 0.1, 2.6, 16, ink, 9.0, true)
	ci.draw_arc(b + Vector2(2, 4), 20.0, 0.1, 2.6, 16, FUR_DARK, 5.0, true)
	ci.draw_set_transform(b, 0.0, Vector2(1.0, 0.62 * breathe))
	ci.draw_circle(Vector2.ZERO, 24.0, ink)
	ci.draw_circle(Vector2.ZERO, 21.5, FUR)
	ci.draw_circle(Vector2(4, -8), 9.0, FUR.lightened(0.15))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# stripes
	for k in 3:
		var sx := b.x - 6 + k * 8.0
		ci.draw_line(Vector2(sx, b.y - 13 * breathe), Vector2(sx + 3, b.y - 7 * breathe), FUR_DARK, 2.5, true)
	# head tucked in on the left
	var hc := b + Vector2(-15, 1)
	_ears(ci, hc, 11.0, 0.15)
	ci.draw_circle(hc, 12.5, ink)
	ci.draw_circle(hc, 10.5, FUR)
	ci.draw_circle(hc + Vector2(-2, 5), 5.0, CHEST)
	for sx in [-5.0, 3.0]:   # closed eyes
		ci.draw_arc(hc + Vector2(sx, -1), 3.0, 0.2, PI - 0.2, 6, ink, 2.0, true)
	# a slow "z" drifting up
	var zt := fmod(ms * 0.001, 3.0) / 3.0
	UiTheme.text(ci, hc + Vector2(-6 + 6 * zt, -16 - 22 * zt), "z", 14 + int(zt * 6.0), Color(1, 1, 1, 0.9 * (1.0 - zt)), HORIZONTAL_ALIGNMENT_LEFT, -1, 3)


func _draw_sitting(ci: CanvasItem, ms: float, happy: bool) -> void:
	var ink := UiTheme.INK
	var swish := sin(ms * 0.0035) * 0.35
	# tail curling up on the right
	var p0 := pos + Vector2(10, -5)
	var p1 := pos + Vector2(34, -2)
	var p2 := pos + Vector2(30 + swish * 14.0, -30)
	var pts := PackedVector2Array()
	for k in 11:
		var a := k / 10.0
		pts.append(p0.lerp(p1, a).lerp(p1.lerp(p2, a), a))
	ci.draw_polyline(pts, ink, 9.0, true)
	ci.draw_polyline(pts, FUR_DARK, 5.0, true)
	# body (a soft pear) + chest
	var body := PackedVector2Array()
	for k in 24:
		var a := TAU * k / 24.0
		var rx := 15.0 + 4.0 * maxf(0.0, sin(a))
		body.append(pos + Vector2(cos(a) * rx, -18 + sin(a) * 18.0))
	ci.draw_colored_polygon(body, FUR)
	body.append(body[0])
	ci.draw_polyline(body, ink, 2.5, true)
	ci.draw_set_transform(pos + Vector2(-3, -16), 0.0, Vector2(0.55, 1.0))
	ci.draw_circle(Vector2.ZERO, 10.0, CHEST)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# front paws
	for sx in [-7.0, 3.0]:
		UiTheme.rounded(ci, Rect2(pos.x + sx, pos.y - 7, 9, 7), CHEST, 3, 2, ink)
	# head
	var hc := pos + Vector2(-2, -40)
	_ears(ci, hc, 13.0, 0.0)
	ci.draw_circle(hc, 15.0, ink)
	ci.draw_circle(hc, 13.0, FUR)
	ci.draw_line(hc + Vector2(-3, -12), hc + Vector2(-2, -7), FUR_DARK, 2.5, true)
	ci.draw_line(hc + Vector2(3, -12), hc + Vector2(2, -7), FUR_DARK, 2.5, true)
	ci.draw_circle(hc + Vector2(0, 6), 6.5, CHEST)
	if happy:
		for sx in [-6.0, 6.0]:   # ^ ^
			ci.draw_arc(hc + Vector2(sx, 0), 3.5, PI + 0.3, TAU - 0.3, 6, ink, 2.2, true)
		ci.draw_circle(hc + Vector2(-9, 4), 3.0, Color(1, 0.5, 0.6, 0.45))
		ci.draw_circle(hc + Vector2(9, 4), 3.0, Color(1, 0.5, 0.6, 0.45))
	else:
		var blink := fmod(ms * 0.001, 4.2) < 0.12
		for sx in [-6.0, 6.0]:
			if blink:
				ci.draw_line(hc + Vector2(sx - 3, -1), hc + Vector2(sx + 3, -1), ink, 2.2, true)
			else:
				ci.draw_circle(hc + Vector2(sx, -1), 3.2, ink)
				ci.draw_circle(hc + Vector2(sx + 1, -2), 1.1, Color.WHITE)
	ci.draw_colored_polygon(PackedVector2Array([hc + Vector2(-2.5, 3), hc + Vector2(2.5, 3), hc + Vector2(0, 6)]), NOSE)
	for sy in [4.0, 7.0]:   # whiskers
		ci.draw_line(hc + Vector2(-5, sy), hc + Vector2(-17, sy - 2), Color(1, 1, 1, 0.8), 1.2, true)
		ci.draw_line(hc + Vector2(5, sy), hc + Vector2(17, sy - 2), Color(1, 1, 1, 0.8), 1.2, true)


func _ears(ci: CanvasItem, hc: Vector2, r: float, tilt: float) -> void:
	var ink := UiTheme.INK
	for sx in [-1.0, 1.0]:
		var e := PackedVector2Array([hc + Vector2(sx * r * 0.95, -r * 0.2), hc + Vector2(sx * r * 0.75, -r * 1.25), hc + Vector2(sx * r * 0.15, -r * 0.8)])
		for k in e.size():
			e[k] = hc + (e[k] - hc).rotated(tilt * sx)
		ci.draw_colored_polygon(e, FUR)
		var inner := PackedVector2Array([e[0].lerp(e[1], 0.3).lerp(e[2], 0.2), e[1].lerp(hc, 0.2), e[2].lerp(e[1], 0.3).lerp(e[0], 0.2)])
		ci.draw_colored_polygon(inner, NOSE)
		e.append(e[0])
		ci.draw_polyline(e, ink, 2.2, true)


static func _heart(ci: CanvasItem, c: Vector2, r: float, a: float) -> void:
	var ink := Color(UiTheme.INK.r, UiTheme.INK.g, UiTheme.INK.b, a)
	var col := Color(1.0, 0.42, 0.6, a)
	var pts := PackedVector2Array()
	for k in 24:
		var t := TAU * k / 24.0
		pts.append(c + Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))) * r / 16.0)
	ci.draw_colored_polygon(pts, col)
	pts.append(pts[0])
	ci.draw_polyline(pts, ink, 2.0, true)
