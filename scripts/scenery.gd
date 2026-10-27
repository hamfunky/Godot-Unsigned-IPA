extends RefCounted
## Cartoon scenery for the station rows (v0.17d art pass): soft gradients, rounded shapes, ink
## outlines. The bay interiors change with the city's premises level (prestige).

const INK := Color("1d1b2b")
const UiTheme = preload("res://scripts/ui_theme.gd")

# per premises level: wall, tile, skirting accent, floor
const THEMES := [
	{"wall": Color("bfe3f2"), "tile": Color("d8f0fa"), "accent": Color("2f9bff"), "floor": Color("9aa7b8"), "lamp": Color("ffe9a8")},   # Suburban Car Wash
	{"wall": Color("f3ede2"), "tile": Color("fffaf1"), "accent": Color("c98b4f"), "floor": Color("a99a8a"), "lamp": Color("fff1c4")},   # Detailing Studio
	{"wall": Color("c9cfd8"), "tile": Color("dfe3ea"), "accent": Color("e53935"), "floor": Color("7d8796"), "lamp": Color("ffe0a0")},   # Performance Garage
	{"wall": Color("8a5a3b"), "tile": Color("a06a46"), "accent": Color("ffcf4a"), "floor": Color("6b4a35"), "lamp": Color("ffdd88")},   # Prestige Atelier
	{"wall": Color("3d4a63"), "tile": Color("4b5a78"), "accent": Color("29e0ff"), "floor": Color("2e3648"), "lamp": Color("b8f6ff")},   # Hypercar Hangar
	{"wall": Color("efeef3"), "tile": Color("ffffff"), "accent": Color("d4a017"), "floor": Color("cfcbd6"), "lamp": Color("fff6d6")},   # Concours Pavilion
]


static func theme() -> Dictionary:
	return THEMES[clampi(GameState.prestige, 0, THEMES.size() - 1)]


static func rr(ci: CanvasItem, r: Rect2, c: Color, radius: float, border: int = 0, bc: Color = INK) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	ci.draw_style_box(UiTheme.flat(c, int(radius), border, bc), r)   # v0.19v: cached boxes


## Vertical gradient rectangle.
static func vgrad(ci: CanvasItem, r: Rect2, top: Color, bot: Color) -> void:
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bot, bot]))


## The valet's driveway down the left of the rows (asphalt, dashes, curb).
static func lane(ci: CanvasItem, w: float, h: float, dash_offset: float = 0.0) -> void:
	vgrad(ci, Rect2(0, 0, w, h), Color("454b57"), Color("3a3f4a"))
	for y in range(int(-36 + fposmod(dash_offset, 36.0)), int(h), 36):
		# v0.19v: dashes stay inside the strip (the one above y=0 used to poke into the pickup lot over the valet)
		var top := maxf(float(y + 6), 0.0)
		var bot := minf(float(y + 24), h)
		if bot - top >= 6.0:
			rr(ci, Rect2(w * 0.5 - 3, top, 6, bot - top), Color("ffd23f"), 3)
	# curb on the right
	ci.draw_rect(Rect2(w - 9, 0, 9, h), Color("c3c9d4"))
	ci.draw_rect(Rect2(w - 9, 0, 2, h), Color("e9edf3"))
	ci.draw_rect(Rect2(w - 2, 0, 2, h), INK)


## Bay interior: tiled back wall, skirting, hanging lamp, floor with a safety line.
static func bay_room(ci: CanvasItem, x0: float, w: float, wall_h: float, floor_y: float, h: float, t: Dictionary, top := 0.0) -> void:
	vgrad(ci, Rect2(x0, top, w - x0, wall_h - top), Color(t["wall"]).lightened(0.08), Color(t["wall"]))
	var tile: Color = t["tile"]
	for row in 2:
		for tx in range(int(x0) + 10 - (row * 22), int(w), 46):
			var r := Rect2(maxf(tx, x0 + 4), top + 10 + row * 34, 40, 28)
			if r.end.x > w - 4:
				r.size.x = w - 4 - r.position.x
			if r.size.x > 8:
				rr(ci, r, tile, 7)
				ci.draw_rect(Rect2(r.position.x + 4, r.position.y + 3, r.size.x - 8, 3), Color(1, 1, 1, 0.35))
	# skirting stripe in the premises accent colour
	ci.draw_rect(Rect2(x0, wall_h - 12, w - x0, 12), Color(t["accent"]))
	ci.draw_rect(Rect2(x0, wall_h - 12, w - x0, 3), Color(t["accent"]).lightened(0.3))
	# floor
	vgrad(ci, Rect2(x0, wall_h, w - x0, floor_y - wall_h + 6), Color(t["floor"]).lightened(0.12), Color(t["floor"]).darkened(0.05))
	ci.draw_rect(Rect2(x0, wall_h, w - x0, 4), Color("ffcc33"))
	# floor shine + drain
	ci.draw_rect(Rect2(x0 + 40, floor_y - 6, w - x0 - 160, 2), Color(1, 1, 1, 0.12))
	# concrete slab between floors (v0.19c: the thick slab band on top of the next strip does this now)
	if top <= 0.0:
		ci.draw_rect(Rect2(0, h - 10, w, 10), Color("2a3550"))
		ci.draw_rect(Rect2(0, h - 10, w, 2), Color("44527a"))


## v0.19c (Idle Miner style zoom): the thick concrete slab across the top of a strip, between floors. It carries
## the station's name line and the manager's ability button, so the room below is left for the characters.
static func slab_band(ci: CanvasItem, x0: float, w: float, h: float) -> void:
	vgrad(ci, Rect2(x0, 0, w - x0, h), Color("33406a"), Color("26304f"))
	ci.draw_rect(Rect2(x0, 0, w - x0, 3), Color("4a5a8c"))
	ci.draw_rect(Rect2(x0, h - 4, w - x0, 4), INK)
	for x in range(int(x0) + 18, int(w), 64):
		ci.draw_circle(Vector2(x, h - 11), 2.6, Color("1d2440"))
		ci.draw_circle(Vector2(x - 0.6, h - 11.6), 1.6, Color("53638f"))


## A lamp hanging from the ceiling with a soft cone of light.
static func lamp(ci: CanvasItem, x: float, y: float, glow_to: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 12, y + 12), Vector2(x + 12, y + 12), Vector2(x + 56, glow_to), Vector2(x - 56, glow_to)]),
		Color(col.r, col.g, col.b, 0.13))
	ci.draw_line(Vector2(x, 0), Vector2(x, y), INK, 2)
	var shade := PackedVector2Array([Vector2(x - 15, y + 12), Vector2(x - 8, y), Vector2(x + 8, y), Vector2(x + 15, y + 12)])
	ci.draw_colored_polygon(shade, Color("37474f"))
	var sl := shade.duplicate()
	sl.append(shade[0])
	ci.draw_polyline(sl, INK, 2.0, true)
	ci.draw_circle(Vector2(x, y + 13), 5, col)


## Round road-sign style badge with the bay number.
static func number_badge(ci: CanvasItem, c: Vector2, n: int) -> void:
	ci.draw_circle(c + Vector2(0, 3), 24, Color(0, 0, 0, 0.3))
	ci.draw_circle(c, 24, INK)
	ci.draw_circle(c, 21, Color("ffffff"))
	ci.draw_circle(c, 17, Color("2f9bff"))
	var f := preload("res://assets/game/fonts/fredoka_700.ttf")
	var s := str(n)
	var fs := 24 if n < 10 else 20
	var tw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string_outline(f, c + Vector2(-tw * 0.5, fs * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, INK)
	ci.draw_string(f, c + Vector2(-tw * 0.5, fs * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


## Fluffy cartoon bush (for the forecourt).
static func bush(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	for p in [Vector2(-r * 0.8, 0), Vector2(0, -r * 0.45), Vector2(r * 0.8, 0)]:
		ci.draw_circle(c + p, r * 0.75 + 2.5, INK)
	for p in [Vector2(-r * 0.8, 0), Vector2(0, -r * 0.45), Vector2(r * 0.8, 0)]:
		ci.draw_circle(c + p, r * 0.75, col)
	ci.draw_circle(c + Vector2(-r * 0.15, -r * 0.7), r * 0.22, col.lightened(0.25))


## Scalloped shop awning (stripes with rounded bottoms).
static func awning(ci: CanvasItem, y: float, w: float, h: float, a: Color, b: Color) -> void:
	var sw := 40.0
	ci.draw_rect(Rect2(0, y - 2, w, h * 0.55 + 2), INK)
	var x := 0.0
	var k := 0
	while x < w:
		var col := a if k % 2 == 0 else b
		ci.draw_rect(Rect2(x, y, sw, h * 0.55), col)
		ci.draw_circle(Vector2(x + sw * 0.5, y + h * 0.55), sw * 0.5 + 2, INK)
		ci.draw_circle(Vector2(x + sw * 0.5, y + h * 0.55), sw * 0.5, col)
		x += sw
		k += 1
	ci.draw_rect(Rect2(0, y, w, 4), Color(1, 1, 1, 0.3))


## Puffy cloud.
static func cloud(ci: CanvasItem, c: Vector2, s: float, a: float = 0.85, col := Color(1, 1, 1)) -> void:
	for p in [Vector2(-s, 0), Vector2(-s * 0.3, -s * 0.5), Vector2(s * 0.4, -s * 0.3), Vector2(s, 0)]:
		ci.draw_circle(c + p, s * 0.55, Color(col.r, col.g, col.b, a))
	ci.draw_rect(Rect2(c.x - s, c.y - s * 0.1, s * 2.0, s * 0.55), Color(col.r, col.g, col.b, a))


# ---------------------------------------------------------------- v0.19t day + night (the phone's own clock)
static var hour_override := -1.0   # dev / tests: >= 0 forces the hour (0 .. 24)


## Local hour as a float (14.5 = 2:30 pm).
static var _hour_cache := 0.0
static var _hour_at := -100000


static func local_hour() -> float:
	if hour_override >= 0.0:
		return hour_override
	var ms := Time.get_ticks_msec()
	if ms - _hour_at > 5000:   # once every 5 s is plenty
		_hour_at = ms
		var d := Time.get_datetime_dict_from_system()
		_hour_cache = float(d["hour"]) + float(d["minute"]) / 60.0
	return _hour_cache


## 0 = day, 1 = full night: dark 20:30 .. 5:00, fading over dusk (18:30 .. 20:30) and dawn (5:00 .. 7:00).
static func night_amount(h: float = -1.0) -> float:
	if h < 0.0:
		h = local_hour()
	if h >= 20.5 or h < 5.0:
		return 1.0
	if h >= 18.5:
		return smoothstep(18.5, 20.5, h)
	if h < 7.0:
		return 1.0 - smoothstep(5.0, 7.0, h)
	return 0.0


## How golden the light is: peaks at sunrise (~6:00) and sunset (~19:00).
static func golden_amount(h: float = -1.0) -> float:
	if h < 0.0:
		h = local_hour()
	return maxf(clampf(1.0 - absf(h - 19.0) / 1.6, 0.0, 1.0), clampf(1.0 - absf(h - 6.0) / 1.3, 0.0, 1.0))


## [top, bottom] sky colours for now (greyer when it rains).
static func sky_colors(h: float = -1.0, rain := false) -> Array:
	var n := night_amount(h)
	var g := golden_amount(h) * (0.3 if rain else 1.0)
	var top := Color("7fd0ff").lerp(Color("8f9bb0"), 0.7 if rain else 0.0).lerp(Color("ff9e6e"), g * 0.55).lerp(Color("1b2350"), n)
	var bot := Color("b5e6ff").lerp(Color("b9c2d0"), 0.7 if rain else 0.0).lerp(Color("ffd08a"), g * 0.8).lerp(Color("3a3f7a"), n)
	return [top, bot]


## v0.19t rain: slanted streaks falling through r (t = seconds, so they move), plus a faint grey wash.
static func rain(ci: CanvasItem, r: Rect2, t: float, density := 1.0) -> void:
	ci.draw_rect(r, Color(0.45, 0.5, 0.6, 0.12))
	var n := int(r.size.x * r.size.y / 1900.0 * density)
	for k in n:
		var x0 := fmod(k * 73.1 + 11.0, r.size.x)
		var sp := 260.0 + fmod(k * 37.0, 90.0)
		var y := fposmod(k * 51.3 + t * sp, r.size.y + 30.0) - 15.0
		var p := r.position + Vector2(fposmod(x0 - y * 0.25, r.size.x), y)
		if p.y < r.position.y or p.y > r.end.y - 6.0:
			continue
		ci.draw_line(p, p + Vector2(-3, 12), Color(0.62, 0.74, 0.92, 0.85), 1.8, true)


## A little night sky: crescent moon + twinkle-free stars (calm), drawn into r (stars fade in with n).
static func night_sky(ci: CanvasItem, r: Rect2, n: float, moon := true) -> void:
	if n <= 0.02:
		return
	for k in 18:
		var p := Vector2(r.position.x + fmod(k * 97.3 + 13.0, r.size.x), r.position.y + 4.0 + fmod(k * 31.7, r.size.y - 8.0))
		ci.draw_circle(p, 1.1 + float(k % 3) * 0.45, Color(1, 1, 0.92, n * (0.55 + 0.15 * float(k % 3))))
	if not moon:
		return
	var mc := Vector2(r.end.x - 52.0, r.position.y + 21.0)
	ci.draw_circle(mc, 11.0, Color(1, 0.97, 0.82, n))
	ci.draw_circle(mc + Vector2(5, -3), 9.5, Color("1b2350").lerp(Color("3a3f7a"), 0.3))
	ci.draw_circle(mc, 18.0, Color(1, 0.97, 0.82, 0.08 * n))


## Outdoor ground at night: a blue dusk wash over r.
static func night_wash(ci: CanvasItem, r: Rect2, n: float) -> void:
	if n > 0.0:
		ci.draw_rect(r, Color(0.06, 0.08, 0.26, 0.34 * n))


## Warm pool of light from a lamp at night (draw after night_wash).
static func lamp_glow(ci: CanvasItem, c: Vector2, rad: float, n: float, col := Color(1, 0.92, 0.6)) -> void:
	if n <= 0.0:
		return
	for k in 4:
		ci.draw_circle(c, rad * (1.0 - k * 0.2), Color(col.r, col.g, col.b, 0.07 * n))


# ---------------------------------------------------------------- v0.19u the shop from the street (title screen, Welcome back)
## The front of your shop in rect r: wall in the premises colour, a sign with your shop's name, three roller
## door bays (the middle one open with a car being foamed inside), a lamp post and a palm. nt = night 0..1.
static func shop_front(ci: CanvasItem, r: Rect2, sign: String, wall: Color, nt: float, t: float, car: Dictionary = {}) -> void:
	var UiTheme = load("res://scripts/ui_theme.gd")
	var CarView = load("res://scripts/car_view.gd")
	var ink := INK
	var x0 := r.position.x
	var w := r.size.x
	var h := r.size.y
	var ground := r.end.y
	# body + flat roof with a parapet
	rr(ci, Rect2(x0 + 4, r.position.y + 10, w - 8, h - 10), Color(0, 0, 0, 0.25), 10)
	rr(ci, Rect2(x0, r.position.y, w, h), wall.lightened(0.12), 10, 4)
	ci.draw_rect(Rect2(x0 + 4, r.position.y + 4, w - 8, h * 0.06), Color(1, 1, 1, 0.18))
	var roof := Rect2(x0 - 10, r.position.y - 16, w + 20, 22)
	rr(ci, roof, wall.darkened(0.35), 6, 4)
	# sign board across the top
	var sr := Rect2(x0 + w * 0.12, r.position.y + h * 0.07, w * 0.76, h * 0.2)
	if nt > 0.0:
		rr(ci, sr.grow(8), Color(1, 0.85, 0.45, 0.25 * nt), 16)
	rr(ci, sr, Color("fff4d6"), 12, 4)
	var fs := int(clampf(sr.size.y * 0.5, 14.0, 40.0))
	UiTheme.text(ci, Vector2(sr.position.x, sr.get_center().y + fs * 0.36), sign, fs, Color("e8553d"), HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 0, UiTheme.DISPLAY_FONT)
	if nt > 0.0:
		for k in 15:
			var bx := sr.position.x + 8.0 + k * (sr.size.x - 16.0) / 14.0
			ci.draw_circle(Vector2(bx, sr.position.y), 3.0, Color(1, 0.93, 0.6, nt))
			ci.draw_circle(Vector2(bx, sr.end.y), 3.0, Color(1, 0.93, 0.6, nt))
	# three bays
	var by := r.position.y + h * 0.36
	var bh := ground - by - 6.0
	var bw := (w - 40.0) / 3.0
	for k in 3:
		var b := Rect2(x0 + 10 + k * (bw + 10), by, bw, bh)
		rr(ci, b, Color("2c3550"), 6, 4)
		if k == 1:   # open: lit inside, a car being washed
			vgrad(ci, b.grow(-5), Color("cfe8f7"), Color("9fb8cc"))
			ci.draw_rect(Rect2(b.position.x + 5, b.end.y - bh * 0.18, b.size.x - 10, bh * 0.18 - 5), Color("8f9cad"))
			if not car.is_empty():
				var cw := b.size.x * 0.86
				var cr := Rect2(b.get_center().x - cw * 0.5, b.end.y - 8 - cw * 0.42, cw, cw * 0.42)
				CarView.draw_car(ci, cr, CarView.book_color(car), 0.0, [], 0.5 + 0.5 * sin(t * 2.0), false, car)
				for q in 7:   # a few suds
					var ph := fposmod(t * 0.5 + q * 0.17, 1.0)
					var bp := Vector2(cr.position.x + cr.size.x * (0.1 + 0.12 * q), cr.end.y - 6 - ph * cr.size.y)
					ci.draw_circle(bp, 4.0 + q % 3, Color(1, 1, 1, 0.7 * (1.0 - ph)))
			# the roller door rolled up at the top
			rr(ci, Rect2(b.position.x + 2, b.position.y + 2, b.size.x - 4, 14), Color("b0bec5"), 4, 2)
		else:   # closed roller door
			for s in int(bh / 9.0):
				ci.draw_rect(Rect2(b.position.x + 5, b.position.y + 5 + s * 9, b.size.x - 10, 7), Color("9fb0c4").lerp(Color("5d6b80"), 0.4 * nt))
			if nt > 0.3:   # a warm light leaking under the door at night
				ci.draw_rect(Rect2(b.position.x + 6, b.end.y - 8, b.size.x - 12, 4), Color(1, 0.85, 0.5, 0.7 * nt))
	# pavement
	ci.draw_rect(Rect2(x0 - 30, ground - 4, w + 60, 10), Color("d9d4c7"))
	ci.draw_rect(Rect2(x0 - 30, ground - 4, w + 60, 3), Color(1, 1, 1, 0.4))


## A fat canvas money bag with a "$" (Welcome back).
static func money_bag(ci: CanvasItem, c: Vector2, s: float) -> void:
	var UiTheme = load("res://scripts/ui_theme.gd")
	var ink := INK
	var body := PackedVector2Array()
	for k in 28:
		var a := TAU * k / 28.0
		body.append(c + Vector2(cos(a) * s * (1.0 + 0.08 * sin(a * 2.0)), sin(a) * s * 0.9 + s * 0.1))
	ci.draw_colored_polygon(body, Color("c9a26b"))
	body.append(body[0])
	ci.draw_polyline(body, ink, 4.0, true)
	var neck := PackedVector2Array([c + Vector2(-s * 0.32, -s * 0.72), c + Vector2(s * 0.32, -s * 0.72), c + Vector2(s * 0.5, -s * 1.15), c + Vector2(-s * 0.5, -s * 1.15)])
	ci.draw_colored_polygon(neck, Color("b58b55"))
	neck.append(neck[0])
	ci.draw_polyline(neck, ink, 4.0, true)
	ci.draw_line(c + Vector2(-s * 0.42, -s * 0.74), c + Vector2(s * 0.42, -s * 0.74), Color("e8553d"), s * 0.12)
	UiTheme.text(ci, Vector2(c.x - s, c.y + s * 0.45), "$", int(s * 1.1), Color("2e7d32"), HORIZONTAL_ALIGNMENT_CENTER, s * 2.0, 0, UiTheme.DISPLAY_FONT)
	ci.draw_circle(c + Vector2(-s * 0.45, -s * 0.25), s * 0.14, Color(1, 1, 1, 0.3))
