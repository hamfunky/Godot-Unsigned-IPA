extends RefCounted
## Foam on a car (v0.18b, 19 Oct: rebuilt so the car gets COMPLETELY buried, Hamza's note).
## Foam "slots" sit in an overlapping honeycomb over the car's real body outline (roof + windows
## included, taken from CarArt), in coordinates relative to the car's rect (0..1) so the same layer draws
## in a bay or blown up in the Character Lab. The cannon's spray is a soft brush that fills the slots it
## passes over, and foam spreads into any empty slot next to a full one, so no gaps survive the foam pass.
## During the scrub the foam comes off from the detailers' end(s) of the car towards the middle, patch by
## patch (with some randomness), so the car is clean exactly when its job ends.
## Also draws the cannon's spray stream. Purely visual: nothing here touches the economy.

const CarArt = preload("res://scripts/car_art.gd")

# v0.19u (Hamza: "smaller so there's more of them"): smaller bubbles, about 2.4x as many, a little see-through,
# with a sparkle of tiny bubble rims on top and drips running down as it's wiped off.
const SPACING := 0.034        # slot spacing, in car widths (was 0.052)
const RADIUS := 0.033         # foam blob radius, in car widths (> spacing / 2 so blobs overlap; was 0.050)
const OUTLINE := Color(0.50, 0.76, 0.95)
const FOAM := Color(0.97, 0.99, 1.0)
const SHADE := Color(0.84, 0.92, 0.99)

var slots: Array = []         # {p: Vector2, r: float, fill: float, wipe_at: float, gone: float, nb: Array}
var body: PackedVector2Array  # car-relative body outline
var aspect := 0.45            # rect height / width
var _x0 := 0.0                # body's x range (car-relative)
var _x1 := 1.0
var rng := RandomNumberGenerator.new()
var _ready_for := ""


func _init(seed_value: int = 0) -> void:
	rng.seed = seed_value * 104729 + 7


## Lay out the foam slots for a car. ends = 1: one detailer working from the left end; 2: one at each end.
## Cheap to call every frame: it only rebuilds when the car / rect shape changes.
static var _layouts := {}     # v0.19u: slot layouts per body shape (built once, copied per car)


func setup(rect: Rect2, car: Dictionary, ends: int = 1) -> void:
	var key := "%s|%d|%.3f" % [CarArt.style_of(car), ends, rect.size.y / rect.size.x]
	if key == _ready_for:
		return
	_ready_for = key
	if _layouts.has(key):
		var L: Array = _layouts[key]
		aspect = L[0]
		body = L[1]
		_x0 = L[2]
		_x1 = L[3]
		slots = L[4].duplicate(true)
		for sl in slots:   # each bay gets its own wobble of when patches come off
			sl["wipe_at"] = clampf(float(sl["wipe_at"]) + rng.randf_range(-0.04, 0.04), 0.02, 0.92)
		return
	aspect = rect.size.y / rect.size.x
	body = PackedVector2Array()
	_x0 = 1.0
	_x1 = 0.0
	for v in CarArt.body_outline(rect, car):
		var q := (v - rect.position) / rect.size
		body.append(q)
		_x0 = minf(_x0, q.x)
		_x1 = maxf(_x1, q.x)
	slots.clear()
	var dy := SPACING * 0.87 / aspect           # honeycomb rows, in rect-height units
	var row := 0
	var y := 0.0
	while y <= 1.0:
		var x := (SPACING * 0.5) if row % 2 == 1 else 0.0
		while x <= 1.0:
			var pt := Vector2(x, y)
			if Geometry2D.is_point_in_polygon(pt, body) or _edge_dist(pt) < SPACING * 0.45:
				# when the foam comes off: from the working end(s) towards the middle, with some noise
				var dist := x if ends == 1 else minf(x, 1.0 - x) * 2.0
				slots.append({"p": pt, "r": RADIUS * rng.randf_range(0.9, 1.15), "fill": 0.0,
					"wipe_at": clampf(0.04 + 0.80 * dist + rng.randf_range(-0.10, 0.10), 0.02, 0.92),
					"gone": 0.0, "nb": []})
			x += SPACING
		y += dy
		row += 1
	# neighbours (for foam spreading into gaps), via a grid so it stays quick with the smaller bubbles
	var grid := {}
	for i in slots.size():
		var c := _cell(slots[i]["p"])
		if not grid.has(c):
			grid[c] = []
		grid[c].append(i)
	for i in slots.size():
		var a: Vector2 = slots[i]["p"]
		var c := _cell(a)
		for gx in range(c.x - 1, c.x + 2):
			for gy in range(c.y - 1, c.y + 2):
				for j in grid.get(Vector2i(gx, gy), []):
					if i != j and _dist(a, slots[j]["p"]) < SPACING * 1.25:
						slots[i]["nb"].append(j)
	_layouts[key] = [aspect, body, _x0, _x1, slots.duplicate(true)]


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / (SPACING * 1.3))), int(floor(p.y * aspect / (SPACING * 1.3))))


## Distance (in car widths) from a point to the body outline.
func _edge_dist(pt: Vector2) -> float:
	var best := 1e9
	for i in body.size():
		var a := body[i]
		var b := body[(i + 1) % body.size()]
		var c := Geometry2D.get_closest_point_to_segment(pt, a, b)
		best = minf(best, _dist(pt, c))
	return best


func clear() -> void:
	for s in slots:
		s["fill"] = 0.0
		s["gone"] = 0.0


func _dist(a: Vector2, b: Vector2) -> float:
	return Vector2(a.x - b.x, (a.y - b.y) * aspect).length()


## A point on the car near (x, y): moved down until it's on the body (so the spray never aims at air above
## a low bonnet).
func on_car(x: float, y: float) -> Vector2:
	var p := Vector2(clampf(x, _x0 + 0.05, _x1 - 0.05), clampf(y, 0.0, 0.95))
	if body.is_empty() or Geometry2D.is_point_in_polygon(p, body):
		return p
	for i in range(1, 40):          # look down first (low bonnet / boot), then up
		var q := p + Vector2(0, 0.025 * i)
		if Geometry2D.is_point_in_polygon(q, body):
			return q
		q = p - Vector2(0, 0.025 * i)
		if Geometry2D.is_point_in_polygon(q, body):
			return q
	return p


## Spray lands at `at` (car-relative): fills the slots under a soft brush.
func spray(at: Vector2, delta: float, brush: float = 0.14, rate: float = 12.0) -> void:
	for s in slots:
		var d := _dist(at, s["p"])
		if d < brush:
			s["fill"] = minf(1.0, float(s["fill"]) + rate * delta * (1.0 - d / brush * 0.6))


## spread = foam still being applied (fills gaps next to foam); wipe = 0..1 how far the scrub has got.
func update(delta: float, wipe: float, spread: bool) -> void:
	if spread:
		for s in slots:
			if float(s["fill"]) < 1.0 and not s["nb"].is_empty():
				var best := 0.0
				for j in s["nb"]:
					best = maxf(best, float(slots[j]["fill"]))
				if best > 0.6:
					s["fill"] = minf(1.0, float(s["fill"]) + delta * 3.5 * best)
	for s in slots:
		if wipe > float(s["wipe_at"]):
			s["gone"] = minf(1.0, float(s["gone"]) + delta / 0.35)


## How much of the car is covered (0..1).
func coverage() -> float:
	if slots.is_empty():
		return 0.0
	var c := 0.0
	for s in slots:
		c += float(s["fill"]) * (1.0 - float(s["gone"]))
	return c / slots.size()


func draw(ci: CanvasItem, car: Rect2, t: float = 0.0) -> void:
	if slots.is_empty():
		return
	var w := car.size.x
	var pts := []
	for i in slots.size():
		var s: Dictionary = slots[i]
		var f := float(s["fill"])
		if f <= 0.01:
			continue
		f = 1.0 - pow(1.0 - f, 3.0)                              # swells in fast, eases out
		var k := f * (1.0 - float(s["gone"]))
		if k <= 0.01:
			continue
		# a gentle wobble so the blanket looks alive, and a slow sag as it sits
		var wob := Vector2(sin(t * 1.7 + i * 0.9), cos(t * 1.3 + i * 1.7)) * 0.004
		var c: Vector2 = car.position + (s["p"] + wob + Vector2(0, 0.012 * f)) * car.size
		pts.append([c, float(s["r"]) * w * (0.4 + 0.6 * k), k])
	# two passes so neighbouring blobs merge into one blanket with a single soft-blue edge.
	# v0.18 perf: each blob is 2 pre-baked textures (batched) instead of 4 tessellated circles.
	_blob_textures()
	var edge := maxf(1.2, w * 0.006)
	for q in pts:
		var re: float = q[1] + edge
		ci.draw_texture_rect(_edge_tex, Rect2(q[0] - Vector2(re, re), Vector2(re, re) * 2.0), false, Color(1, 1, 1, 0.7 * q[2]))
	for q in pts:
		var rf: float = q[1] * FILL_SCALE
		ci.draw_texture_rect(_fill_tex, Rect2(q[0] - Vector2(rf, rf), Vector2(rf, rf) * 2.0), false, Color(1, 1, 1, 0.9 * q[2]))
	# v0.19u: tiny bubble rims catching the light on top of the foam (every 3rd slot)
	for k in range(0, pts.size(), 3):
		var q: Array = pts[k]
		var rb: float = q[1] * (0.55 + 0.25 * float(k % 2))
		ci.draw_texture_rect(_bubble_tex, Rect2(q[0] + Vector2(rb * 0.3, -rb * 0.4) - Vector2(rb, rb), Vector2(rb, rb) * 2.0), false, Color(1, 1, 1, 0.85 * q[2]))
	# v0.19u: drips running down where the foam's just been wiped off
	for i in slots.size():
		var g := float(slots[i]["gone"])
		if g <= 0.0 or g >= 1.0 or i % 2 == 1:
			continue
		var c0: Vector2 = car.position + slots[i]["p"] * car.size
		var dy := g * car.size.y * 0.35
		var dr := maxf(1.2, w * 0.007) * (1.0 - g * 0.5)
		ci.draw_line(c0, c0 + Vector2(0, dy), Color(0.82, 0.93, 1.0, 0.5 * (1.0 - g)), dr, true)
		ci.draw_circle(c0 + Vector2(0, dy), dr * 1.1, Color(0.9, 0.97, 1.0, 0.75 * (1.0 - g)))


## Blob textures, made once: a soft-blue disc (the blanket's edge) and the foam fill (shade below, white
## foam, a little highlight), anti-aliased, with mipmaps.
const TEX := 64
const FILL_SCALE := 1.2        # the fill texture's radius in blob radii (its shade reaches below the blob)
static var _edge_tex: Texture2D
static var _fill_tex: Texture2D
static var _bubble_tex: Texture2D


static func _blob_textures() -> void:
	if _edge_tex != null:
		return
	# v0.19u: a single soap bubble: thin bright rim, see-through middle, a highlight
	var bub := Image.create(TEX, TEX, false, Image.FORMAT_RGBA8)
	var hb := TEX * 0.5
	for y in TEX:
		for x in TEX:
			var d := Vector2(x + 0.5 - hb, y + 0.5 - hb).length() / (hb - 1.0)
			var rim := clampf(1.0 - absf(d - 0.86) / 0.12, 0.0, 1.0)
			var inside := 0.12 if d < 0.86 else 0.0
			var hl := clampf(1.0 - (Vector2(x + 0.5 - hb, y + 0.5 - hb) / (hb - 1.0) - Vector2(-0.35, -0.38)).length() / 0.2, 0.0, 1.0)
			bub.set_pixel(x, y, Color(1, 1, 1, clampf(maxf(rim * 0.9, inside) + hl, 0.0, 1.0)))
	bub.generate_mipmaps()
	_bubble_tex = ImageTexture.create_from_image(bub)
	var edge := Image.create(TEX, TEX, false, Image.FORMAT_RGBA8)
	var fill := Image.create(TEX, TEX, false, Image.FORMAT_RGBA8)
	var half := TEX * 0.5
	var R := half - 1.0
	for y in TEX:
		for x in TEX:
			var p := Vector2(x + 0.5 - half, y + 0.5 - half)
			var a := clampf(R - p.length(), 0.0, 1.0)
			edge.set_pixel(x, y, Color(OUTLINE, a))
			var q := p / (R / FILL_SCALE)                    # in blob radii
			var px := R / FILL_SCALE                          # pixels per blob radius
			var a_sh := clampf((1.0 - (q - Vector2(0, 0.16)).length()) * px, 0.0, 1.0)
			var a_fo := clampf((0.88 - (q - Vector2(-0.06, -0.10)).length()) * px, 0.0, 1.0)
			var a_hi := clampf((0.20 - (q - Vector2(-0.32, -0.36)).length()) * px, 0.0, 1.0)
			var col := Color(SHADE, a_sh)
			col = col.blend(Color(FOAM, a_fo * 0.86))   # v0.19u: a touch see-through
			col = col.blend(Color(1, 1, 1, a_hi))
			fill.set_pixel(x, y, col)
	edge.generate_mipmaps()
	fill.generate_mipmaps()
	_edge_tex = ImageTexture.create_from_image(edge)
	_fill_tex = ImageTexture.create_from_image(fill)


## The cannon's spray: a widening fan of foam from the nozzle to where it lands, pulsing with the pump.
## `size` scales the foam blobs (1 = bay size), strength 0..1.
static func draw_spray(ci: CanvasItem, from: Vector2, to: Vector2, t: float, strength: float, size: float) -> void:
	if strength <= 0.02:
		return
	var d := to - from
	var L := d.length()
	if L < 2.0:
		return
	var u := d / L
	var n := Vector2(-u.y, u.x)
	var pulse := 0.85 + 0.15 * sin(t * TAU * 3.0)
	# solid jet near the nozzle
	ci.draw_line(from, from + d * 0.22, Color(OUTLINE, 0.8 * strength), size * 5.0, true)
	ci.draw_line(from, from + d * 0.22, Color(FOAM, 0.95 * strength), size * 3.4, true)
	# foam travelling along a widening cone (two layers: a soft blue edge, then the white foam)
	var parts := []
	for i in 34:
		var ph := fposmod(t * 1.9 + float(i) * 0.618034, 1.0)
		var jit := sin(float(i) * 12.9898 + floor(t * 1.9 + float(i) * 0.618034) * 3.1) * 0.5
		var c := from + d * ph + n * (L * 0.26 * ph * jit)
		var r := size * (2.4 + 8.0 * ph) * pulse
		parts.append([c, r, strength * (1.0 - pow(ph, 5.0))])
	_blob_textures()
	for q in parts:
		var re: float = q[1] + size * 1.0
		ci.draw_texture_rect(_edge_tex, Rect2(q[0] - Vector2(re, re), Vector2(re, re) * 2.0), false, Color(1, 1, 1, 0.7 * q[2]))
	for q in parts:
		var rf: float = q[1] * FILL_SCALE
		ci.draw_texture_rect(_fill_tex, Rect2(q[0] - Vector2(rf, rf), Vector2(rf, rf) * 2.0), false, Color(1, 1, 1, 0.95 * q[2]))
	# splat where it lands
	for i in 5:
		var ang := float(i) * TAU / 5.0 + t * 2.0
		var c := to + Vector2(cos(ang), sin(ang)) * size * 7.0 * pulse
		ci.draw_circle(c, size * 4.5, Color(FOAM, 0.85 * strength))
