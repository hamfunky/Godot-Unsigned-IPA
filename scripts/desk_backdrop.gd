extends Control
## v0.19g: everything behind the front desk that doesn't move: sky, shop wall, roof trim, floor, and the
## SHOWROOM WINDOW (Hamza) showing your Book showcase. Drawn behind the desk row (show_behind_parent) and
## only redrawn when something it shows changes, so the up-to-10 showroom cars cost nothing per frame.
##   front row  showcase slots 1-3, one per glass pane on a plinth, with the hexagon LED lights reflected in
##              the paint; an empty slot shows a pale "mystery car"
##   back row   showcase slots 4-10 on a raised gallery shelf, smaller and hazier (further away)
## Art: tools/char/desk_art.py (show_back = interior with the hex LED ceiling + its reflection in the floor,
## show_glass = frame + glass, drawn over the cars).

const DP = preload("res://scripts/desk_parts.gd")
const CarView = preload("res://scripts/car_view.gd")
const CarArt = preload("res://scripts/car_art.gd")
const Scenery = preload("res://scripts/scenery.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")

const FRONT := 3
const BACK_MAX := 7
const FRONT_W := 74.0
const FRONT_H := 27.0
const BACK_W := 34.0
const BACK_H := 12.5
const GALLERY_Y := 34.0        # top of the back shelf (window coords)
const MYSTERY := "swiff"       # the shape an empty front slot shows

var floor_y := 230.0
var _sig := ""
var _check := 0.0
static var _tex := {}


func _ready() -> void:
	show_behind_parent = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.4
	var s := signature()
	if s != _sig:
		_sig = s
		queue_redraw()


## What the backdrop shows: when this changes it redraws.
func signature() -> String:
	return "%s|%s|%d|%d|%s|%s" % [str(GameState.display), GameState.premises_def()["color"], int(size.x), int(Scenery.local_hour() * 12.0), str(GameState.decor), str(GameState.raining())]


## [front ids, back ids] from the Book showcase (in its order).
static func showroom_cars() -> Array:
	var ids: Array = GameState.display
	return [ids.slice(0, FRONT), ids.slice(FRONT, FRONT + BACK_MAX)]


static func _t(n: String) -> Texture2D:
	if not _tex.has(n):
		_tex[n] = load("res://assets/game/sprites/desk/%s.png" % n)
	return _tex[n]


func _part(n: String, at: Vector2) -> void:
	var k := 1.0 / DP.RES
	draw_set_transform(at, 0.0, Vector2(k, k))
	draw_texture(_t(n), -DP.PARTS[n])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw() -> void:
	var w := size.x
	var wet := GameState.raining()
	var sky := Scenery.sky_colors(-1.0, wet)   # v0.19t: follows the phone's clock (sunset, night) + rainy days
	var nt := Scenery.night_amount()
	Scenery.vgrad(self, Rect2(0, 0, w, 50), sky[0], sky[1])
	Scenery.night_sky(self, Rect2(0, 0, w, 44), nt, false)   # v0.19v: the moon is in the sky strip above now
	if nt < 0.95 and not wet:
		Scenery.cloud(self, Vector2(80, 22), 16, 0.85 * (1.0 - nt * 0.8))
		Scenery.cloud(self, Vector2(w - 200, 16), 12, 0.85 * (1.0 - nt * 0.8))
	elif wet:
		for k in 5:   # low grey rain clouds across the top
			Scenery.cloud(self, Vector2(40 + k * w / 4.5, 12 + (k % 2) * 6), 18, 0.9 * (1.0 - nt * 0.5), Color("7d879a"))
	var pc := Color(GameState.premises_def()["color"])
	Scenery.vgrad(self, Rect2(0, 44, w, floor_y - 44), pc.lightened(0.12), pc.darkened(0.08))
	# v0.19f: a clean roof trim where the wall meets the sky (the scalloped awning is gone)
	draw_rect(Rect2(0, 41, w, 10), Scenery.INK)
	draw_rect(Rect2(0, 43, w, 6), pc.darkened(0.3))
	draw_rect(Rect2(0, 43, w, 2), Color(1, 1, 1, 0.25))
	Scenery.vgrad(self, Rect2(0, floor_y, w, size.y - floor_y), Color("f0c789"), Color("d9a865"))
	draw_rect(Rect2(0, floor_y, w, 3), Color(1, 1, 1, 0.35))
	_draw_showroom()
	if GameState.has_decor("neon"):
		_draw_neon(nt)


## v0.19t decor: a pink neon OPEN sign hanging over the showroom window (glows harder at night).
func _draw_neon(nt: float) -> void:
	var c := Vector2(DP.WIN.position.x + DP.WIN.size.x * 0.5, DP.WIN.position.y - 1.0)
	var r := Rect2(c.x - 46, c.y - 17, 92, 30)
	Scenery.rr(self, r.grow(6), Color(1, 0.3, 0.6, 0.12 + 0.25 * nt), 14)
	Scenery.rr(self, r, Color("2b1d3a"), 9, 3)
	UiTheme.text(self, Vector2(r.position.x, r.position.y + 23), "OPEN", 22, Color("ff7ab8").lerp(Color("ffd1ea"), 0.4 * nt), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 0, UiTheme.DISPLAY_FONT)


func _draw_showroom() -> void:
	var o := DP.WIN.position
	_part("show_back", o)
	var cars := showroom_cars()
	var back: Array = cars[1]
	if not back.is_empty():
		# raised gallery shelf across the back, with an LED strip under its lip
		var gy := o.y + GALLERY_Y
		var x0 := o.x + 6.0
		var gw := DP.WIN.size.x - 12.0
		draw_rect(Rect2(x0, gy - 0.5, gw, 5.5), Scenery.INK)
		draw_rect(Rect2(x0, gy, gw, 3.0), Color("c9d1dc"))
		draw_rect(Rect2(x0, gy + 3.0, gw, 1.5), Color("eaf7ff"))
		var span := gw - 12.0
		var n := back.size()
		for k in n:
			var cx := x0 + 6.0 + span * (k + 0.5) / BACK_MAX + (BACK_MAX - n) * span / (2.0 * BACK_MAX)
			var car := GameState.car_def(back[k])
			CarView.draw_car(self, Rect2(cx - BACK_W * 0.5, gy - BACK_H, BACK_W, BACK_H),
				CarView.book_color(car).lerp(Color("dfe6ee"), 0.22), 0.0, [], 0.0, false, car)
		# a little haze: they're further back
		draw_rect(Rect2(x0, o.y + DP.CEIL, gw, gy - o.y - DP.CEIL), Color(0.92, 0.95, 0.99, 0.16))
	var front: Array = cars[0]
	for k in FRONT:
		var pr: Rect2 = DP.PANES[k]
		var cx := o.x + pr.position.x + pr.size.x * 0.5
		var r := Rect2(cx - FRONT_W * 0.5, o.y + DP.PLINTH_Y - FRONT_H, FRONT_W, FRONT_H)
		if k < front.size():
			var car := GameState.car_def(front[k])
			CarView.draw_car(self, r, CarView.book_color(car), 0.0, [], 0.0, false, car)
			_hex_glare(r, car)
		else:
			CarView.draw_car(self, r, Color(0.62, 0.67, 0.78, 0.5), 0.0, [], 0.0, true, GameState.car_def(MYSTERY))
	_part("show_glass", o)


## The hexagon LED ceiling reflected in a car's paint (Hamza: like a detailing studio): a small flattened
## honeycomb on the upper body, only where it fits inside the body outline.
func _hex_glare(r: Rect2, car: Dictionary) -> void:
	var body: PackedVector2Array = CarArt.body_outline(r, car)
	var bb := Rect2(body[0], Vector2.ZERO)
	for p in body:
		bb = bb.expand(p)
	var hr := r.size.x * 0.05
	var sy := 0.5
	var dx := hr * 1.5
	var dy := hr * sqrt(3.0) * sy
	var c0 := Vector2(bb.position.x + bb.size.x * 0.5, bb.position.y + bb.size.y * 0.5)
	for c in range(-3, 4):
		var a := 0.5 * (1.0 - absf(c) / 4.0)    # brightest in the middle, fading out to the ends
		var rows := 2 if absi(c) % 2 == 0 else 1
		for rw in rows:
			var cen := c0 + Vector2(c * dx, rw * dy + (dy * 0.5 if absi(c) % 2 == 1 else 0.0))
			var pts := PackedVector2Array()
			var inside := true
			for k in 7:
				var v := cen + Vector2(cos(k * PI / 3.0) * hr, sin(k * PI / 3.0) * hr * sy)
				if k < 6 and not Geometry2D.is_point_in_polygon(v, body):
					inside = false
					break
				pts.append(v)
			if inside:
				draw_polyline(pts, Color(1, 1, 1, a), 1.0, true)
