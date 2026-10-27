extends Control
## Top-right of the HUD (v0.17h, playtest: "what is Gloss? make it look tappable"): two separate chunky
## buttons. Top = premium currency (Shine Bucks) with a "+": opens the "What are Shine Bucks?" card.
## Bottom = reputation, shown as a review rating (1.0 to 5.0 stars): opens the Reputation card.

signal premium_pressed
signal rep_pressed

const Data = preload("res://scripts/game_data.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")

const PILL_W := 230.0
const PILL_H := 44.0
const BADGE := 34.0   # v0.17h-2: the icons are big badges that stick out past the left end of each pill

var _press_pos := Vector2.ZERO
var _pressing := -1   # which pill is held down: 0 premium, 1 reputation, -1 none


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(PILL_W + BADGE + 6, 2 * PILL_H + 24)


var _sig := ""


func _process(_delta: float) -> void:
	# v0.19v perf: only when what it shows changes
	var s := "%d|%s|%s|%d" % [GameState.gloss, GameState.rating_text(), GameState.has_reviews(), _pressing]
	if s != _sig:
		_sig = s
		queue_redraw()


func _pill(k: int) -> Rect2:
	return Rect2(size.x - PILL_W - 2, 6 + k * (PILL_H + 12), PILL_W, PILL_H)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = -1
			for k in 2:
				var hit := _pill(k).grow(6)
				hit.position.x -= BADGE
				hit.size.x += BADGE
				if hit.has_point(event.position):
					_pressing = k
			_press_pos = event.position
		elif _pressing >= 0:
			var k := _pressing
			_pressing = -1
			if event.position.distance_to(_press_pos) < 20.0:
				Sfx.play("click")
				if k == 0:
					premium_pressed.emit()
				else:
					rep_pressed.emit()


func _draw() -> void:
	# --- premium currency button
	var a := _pill(0)
	var down := 3.0 if _pressing == 0 else 0.0
	_lip(a, Color("2a63c4"), down)
	draw_circle(a.position + Vector2(0, 21 + down), 27.0, UiTheme.INK)
	draw_circle(a.position + Vector2(0, 21 + down), 24.0, Color("1f8a63"))
	draw_droplet(self, a.position + Vector2(0, 21 + down), 14.0)
	UiTheme.text(self, a.position + Vector2(32, 31 + down), GameState.fmt(GameState.gloss), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiTheme.DISPLAY_FONT)
	var plus := Vector2(a.end.x - 22, a.position.y + 20 + down)
	draw_circle(plus, 13.0, UiTheme.INK)
	draw_circle(plus, 11.0, UiTheme.GOOD)
	draw_rect(Rect2(plus.x - 6, plus.y - 2, 12, 4), Color.WHITE)
	draw_rect(Rect2(plus.x - 2, plus.y - 6, 4, 12), Color.WHITE)
	# --- reputation button (v0.17h-3, Hamza: "too many stars"): your shop's review rating, like Google
	# reviews. One gold star + "4.5" + RATING. (Prestige is a trophy now, so this is the only star up here.)
	var b := _pill(1)
	down = 3.0 if _pressing == 1 else 0.0
	_lip(b, Color("7d4bd1"), down)
	var sc := b.position + Vector2(0, 22 + down)
	if GameState.has_reviews():
		draw_star(self, sc + Vector2(0, 2), 31.0, true)
		draw_star(self, sc, 30.0, true)
		UiTheme.text(self, b.position + Vector2(38, 33 + down), GameState.rating_text(), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiTheme.DISPLAY_FONT)
		UiTheme.text(self, b.position + Vector2(98, 30 + down), "RATING", 19, Color("e7d8ff"), HORIZONTAL_ALIGNMENT_LEFT, -1, 5, UiTheme.DISPLAY_FONT)
	else:
		# v0.19l: a brand-new shop has no reviews yet: an empty star + "NEW SHOP"
		draw_star(self, sc, 30.0, false)
		UiTheme.text(self, b.position + Vector2(38, 33 + down), "NEW", 28, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiTheme.DISPLAY_FONT)
		UiTheme.text(self, b.position + Vector2(110, 30 + down), "SHOP", 19, Color("e7d8ff"), HORIZONTAL_ALIGNMENT_LEFT, -1, 5, UiTheme.DISPLAY_FONT)
	# little chevron: "tap for more"
	var ch := Vector2(b.end.x - 18, b.position.y + 20 + down)
	draw_polyline(PackedVector2Array([ch + Vector2(-4, -7), ch + Vector2(3, 0), ch + Vector2(-4, 7)]), Color.WHITE, 3.0, true)


## Chunky little button: ink outline, darker lip at the bottom (squashes when held), shine strip.
func _lip(r: Rect2, c: Color, down: float) -> void:
	var body := Rect2(r.position + Vector2(0, down), r.size - Vector2(0, down))
	UiTheme.rounded(self, Rect2(r.position + Vector2(0, 5), r.size), c.darkened(0.42), 18, 3, UiTheme.INK)
	UiTheme.rounded(self, Rect2(body.position, body.size - Vector2(0, 5 - down * 0.0)), c, 18, 3, UiTheme.INK)
	UiTheme.rounded(self, Rect2(body.position + Vector2(14, 5), Vector2(r.size.x - 28, 6)), Color(1, 1, 1, 0.25), 3)


static func draw_star(ci: CanvasItem, c: Vector2, r: float, filled: bool) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2.0 + k * PI / 5.0
		var rr := r if k % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, Color("ffd23f") if filled else Color(0.1, 0.25, 0.45, 0.45))
	pts.append(pts[0])
	ci.draw_polyline(pts, UiTheme.INK if filled else Color(1, 1, 1, 0.35), 2.0, true)


## The premium currency icon (v0.17h: Shine Bucks = a mint banknote with a sparkle; the name of this
## function is from when it was a Gloss droplet). c = centre, r = about half its height.
static func draw_droplet(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_set_transform(c, -0.18, Vector2.ONE)
	var w := r * 2.3
	var h := r * 1.45
	var bill := Rect2(-w * 0.5, -h * 0.5, w, h)
	UiTheme.rounded(ci, Rect2(bill.position + Vector2(0, maxf(1.5, r * 0.15)), bill.size), Color("1f8a63"), int(r * 0.3), 2, UiTheme.INK)
	UiTheme.rounded(ci, bill, Color("3fd9a3"), int(r * 0.3), 2, UiTheme.INK)
	UiTheme.rounded(ci, Rect2(-w * 0.22, -h * 0.3, w * 0.44, h * 0.6), Color("a8f5d6"), int(r * 0.3))
	UiTheme.text(ci, Vector2(-w * 0.22, h * 0.22), "S", int(maxf(8.0, r * 1.0)), Color("1f8a63"), HORIZONTAL_ALIGNMENT_CENTER, w * 0.44, 0, UiTheme.DISPLAY_FONT)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	UiTheme.sparkle(ci, c + Vector2(w * 0.42, -h * 0.55), maxf(3.0, r * 0.55), Color(1, 1, 1, 0.95))


## v0.17h-3: a review-style rating row: 5 stars, filled up to `rating` (half stars allowed).
static func draw_rating(ci: CanvasItem, c: Vector2, r: float, rating: float) -> void:
	var gap := r * 2.3
	for k in 5:
		var sc := c + Vector2((k - 2) * gap, 0)
		draw_star(ci, sc, r, false)
		var fill := clampf(rating - k, 0.0, 1.0)
		if fill <= 0.0:
			continue
		var pts := _star_pts(sc, r)
		if fill < 1.0:   # left half only
			var half := PackedVector2Array([sc + Vector2(-r - 2, -r - 2), sc + Vector2(0, -r - 2), sc + Vector2(0, r + 2), sc + Vector2(-r - 2, r + 2)])
			var cut := Geometry2D.intersect_polygons(pts, half)
			if cut.is_empty():
				continue
			pts = cut[0]
		ci.draw_colored_polygon(pts, Color("ffd23f"))
		var o := _star_pts(sc, r)
		o.append(o[0])
		ci.draw_polyline(o, UiTheme.INK, 2.0, true)


static func _star_pts(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2.0 + k * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
	return pts


## v0.17h-3 prestige icon: a trophy (Hamza: the prestige star was one star too many). c = centre,
## h = total height. Gold when won (with an optional number on the cup), a faint outline when not yet.
## v0.19w: the trophy's cup outline (for the shine that sweeps across it when a prestige is ready).
static func trophy_cup(c: Vector2, s: float) -> PackedVector2Array:
	var cup := PackedVector2Array()
	for q in [Vector2(-0.33, -0.5), Vector2(0.33, -0.5), Vector2(0.31, -0.24), Vector2(0.24, -0.05), Vector2(0.12, 0.07),
			Vector2(-0.12, 0.07), Vector2(-0.24, -0.05), Vector2(-0.31, -0.24)]:
		cup.append(c + q * s)
	return cup


static func draw_trophy(ci: CanvasItem, c: Vector2, h: float, won: bool, num: String = "") -> void:
	var s := h
	var gold := Color("ffd23f")
	var dark := Color("d99a00")
	var ink := UiTheme.INK if won else Color(1, 1, 1, 0.75)
	var fill := gold if won else Color(1, 1, 1, 0.2)
	var fill2 := dark if won else Color(1, 1, 1, 0.12)
	var lw := maxf(1.5, s * 0.06)
	# handles (drawn first so the cup covers their inner ends)
	for sx in [-1.0, 1.0]:
		var hc := c + Vector2(sx * s * 0.3, -s * 0.27)
		var a0 := PI * 0.5 if sx < 0 else -PI * 0.5
		ci.draw_arc(hc, s * 0.13, a0, a0 + PI, 12, ink, lw + s * 0.07, true)
		ci.draw_arc(hc, s * 0.13, a0, a0 + PI, 12, fill, s * 0.07, true)
	# base: plinth + step + stem
	UiTheme.rounded(ci, Rect2(c + Vector2(-s * 0.3, s * 0.33), Vector2(s * 0.6, s * 0.17)), fill2, int(s * 0.05), int(lw), ink)
	UiTheme.rounded(ci, Rect2(c + Vector2(-s * 0.2, s * 0.22), Vector2(s * 0.4, s * 0.13)), fill, int(s * 0.04), int(lw), ink)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.06, s * 0.06), Vector2(s * 0.12, s * 0.17)), fill2)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.06, s * 0.06), Vector2(s * 0.12, s * 0.17)), ink, false, lw * 0.7)
	# the cup
	var cup := trophy_cup(c, s)
	ci.draw_colored_polygon(cup, fill)
	var o := cup.duplicate()
	o.append(cup[0])
	ci.draw_polyline(o, ink, lw, true)
	if won:
		ci.draw_line(c + Vector2(-s * 0.2, -s * 0.42), c + Vector2(-s * 0.16, -s * 0.12), Color(1, 1, 1, 0.65), maxf(1.5, s * 0.06))
		if num != "":
			UiTheme.text(ci, c + Vector2(-s * 0.33, -s * 0.12), num, int(maxf(10.0, s * 0.4)), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, s * 0.66, int(maxf(3.0, s * 0.12)), UiTheme.DISPLAY_FONT)
