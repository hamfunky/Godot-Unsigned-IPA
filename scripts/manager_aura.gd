extends RefCounted
## Manager "active" effect layer (v0.19). Separate from the manager rig on purpose: the station draws
## draw_back() before the manager and draw_front() after, and rim() gives the rig its rim-light colour.
## Pick the effect with an id so premium managers can get their own later (add a branch per id).
##   "suds" (cash managers): soft rounded glow that breathes, three swaying tongues, a glowing puddle with a
##   ring of suds at the feet, soap bubbles rising and popping, twinkles. Colour = ability kind.
## `alpha` fades the whole effect in / out (the station eases it), `t` = running time in seconds.

const P = preload("res://scripts/manager_parts.gd")
const Rig = preload("res://scripts/manager_rig.gd")

const H := 270.0          # effect height in units (matches the rig's FIG_UNITS)


static func kind_colors(kind: String) -> Array:
	return P.KIND_COLORS.get(kind, P.KIND_COLORS["speed"])


static func rim(effect: String, kind: String, alpha: float, t: float) -> Color:
	var c: Color = kind_colors(kind)[3]
	c.a = alpha * (0.75 + 0.15 * sin(t * 3.1))
	return c


static func _pen(ci: CanvasItem, feet: Vector2, px_h: float) -> Rig.Pen:
	return Rig.Pen.new(ci, feet, px_h / Rig.FIG_UNITS)


static func _a(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * clampf(a, 0.0, 1.0))


static func draw_back(ci: CanvasItem, feet: Vector2, px_h: float, effect: String, kind: String, alpha: float, t: float, seed := 0.0) -> void:
	if alpha <= 0.01:
		return
	match effect:
		_:
			_suds_back(_pen(ci, feet, px_h), kind, alpha, t + seed * 5.0, seed)


static func draw_front(ci: CanvasItem, feet: Vector2, px_h: float, effect: String, kind: String, alpha: float, t: float, seed := 0.0) -> void:
	if alpha <= 0.01:
		return
	match effect:
		_:
			_suds_front(_pen(ci, feet, px_h), kind, alpha, t + seed * 5.0, seed)


static func _suds_back(pen: Rig.Pen, kind: String, al: float, t: float, seed: float) -> void:
	var g := P.GROUND
	var cols := kind_colors(kind)
	var grow := _ss(al)            # the aura swells up as it fades in
	# glowing puddle on the floor
	var pul := 1.0 + 0.05 * sin(t * 2.0)
	pen.part("aura_puddle_" + kind, Vector2(0, g), 0.0, Vector2(pul, pul) * (0.6 + 0.4 * grow), Color(1, 1, 1, al))
	# big soft glow, breathing
	var b1 := sin(t * 1.7)
	pen.part("aura_glow_" + kind, Vector2(0, g), 0.0, Vector2(1.0 + 0.035 * b1, (1.0 + 0.06 * sin(t * 1.7 + 0.6)) * grow),
		Color(1, 1, 1, al * (0.88 + 0.12 * b1)))
	# three soft tongues rising up the sides and over the top, swaying
	var tongues := [[-64.0, 0.92, 0.0], [66.0, 1.0, 2.1], [-6.0, 1.42, 4.2]]
	for tg in tongues:
		var ph: float = t * 1.25 + tg[2]
		var sx: float = tg[0] + sin(ph) * 5.0
		var sy := (float(tg[1]) + 0.12 * sin(ph * 1.3 + 0.7)) * grow
		pen.part("aura_tongue_" + kind, Vector2(sx, g - 10), sin(ph * 0.9) * 0.06, Vector2(1.0 + 0.08 * sin(ph * 1.7), sy),
			Color(1, 1, 1, al * (0.55 + 0.2 * sin(ph * 1.1 + 1.0))))
	# bright core
	var b2 := sin(t * 2.3 + 1.1)
	pen.part("aura_core_" + kind, Vector2(sin(t * 0.9) * 2.0, g), 0.0, Vector2(1.0 + 0.03 * b2, (1.0 + 0.05 * b2) * grow),
		Color(1, 1, 1, al * (0.8 + 0.15 * b2)))
	# bubbles rising behind, big low, smaller high, popping at the top
	for i in 9:
		_bubble(pen, kind, i, t, al, 9, true)
	# ring of suds round the feet (bobbing)
	var deep: Color = cols[2]
	var pale: Color = cols[0]
	for i in 15:
		var a := PI * float(i) / 14.0
		var bob := sin(t * 2.4 + i * 0.9) * 1.2
		var r := (7.5 + 2.5 * fposmod(sin(i * 12.9898) * 43758.5453, 1.0)) * (1.0 + 0.06 * sin(t * 3.0 + i))
		var c := Vector2(cos(a) * 62.0, g - 2.0 - sin(a) * 7.0 + bob)
		var s := r / 10.0 * (0.4 + 0.6 * grow)
		pen.part("aura_puff", c, 0.0, Vector2.ONE * s * 1.16, _a(deep, al * 0.55))
		pen.part("aura_puff", c, 0.0, Vector2.ONE * s, Color(1, 1, 1, al))
		pen.part("aura_puff", c + Vector2(-r * 0.15, r * 0.3), 0.0, Vector2.ONE * s * 0.72, _a(pale, al * 0.75))


static func _suds_front(pen: Rig.Pen, kind: String, al: float, t: float, seed: float) -> void:
	for i in 6:
		_bubble(pen, kind, i, t, al, 6, false)
	# twinkles: pop in, spin a little, fade
	var spots := [Vector2(58, 0.9), Vector2(-62, 0.45), Vector2(30, 1.08), Vector2(-40, 0.98)]
	for i in spots.size():
		var ph := fposmod(t * 0.55 + i * 0.37, 1.0)
		var k := sin(ph * PI)
		k = k * k
		if k < 0.02:
			continue
		var y := P.GROUND - H * float(spots[i].y)
		pen.part("aura_twinkle", Vector2(spots[i].x, y - ph * 10.0), ph * 1.2, Vector2.ONE * (0.5 + 0.5 * k), Color(1, 1, 1, al * k))


static func _bubble(pen: Rig.Pen, kind: String, i: int, t: float, al: float, n: int, back: bool) -> void:
	var g := P.GROUND
	var rnd := func(k: float) -> float: return fposmod(sin((i + 1) * 12.9898 + k * 78.233 + (0.0 if back else 3.7)) * 43758.5453, 1.0)
	var period: float = 2.6 + 1.6 * rnd.call(1.0)
	var u := fposmod(t / period + rnd.call(2.0), 1.0)
	var side := -1.0 if i % 2 == 0 else 1.0
	var x: float
	var y: float
	var r: float
	if back:
		x = side * (40.0 + 22.0 * rnd.call(3.0)) * (1.0 - 0.35 * u)
		y = g - 30.0 - u * (H + 10.0)
		r = (11.0 - 6.0 * u) * (0.8 + 0.4 * rnd.call(4.0))
	else:
		# small ones in front, kept off the face: low at the sides, or above the head
		x = side * (44.0 + 18.0 * rnd.call(3.0))
		y = g - 40.0 - u * (H + 40.0)
		if absf(x) < 50.0 and y > g - H + 20.0 and y < g - 120.0:
			x = side * 52.0
		r = (6.5 - 2.5 * u) * (0.8 + 0.4 * rnd.call(4.0))
	x += sin(t * 1.6 + i * 1.3) * 4.0
	var a := 1.0
	var sc := 1.0
	if u < 0.12:
		a = u / 0.12
		sc = 0.6 + 0.4 * u / 0.12
	elif u > 0.9:
		var q := (u - 0.9) / 0.1          # pop: swell a little and vanish
		a = 1.0 - q
		sc = 1.0 + 0.35 * q
	a *= (0.95 - 0.35 * u) if back else 0.9
	pen.part("aura_bubble_" + kind, Vector2(x, y), 0.0, Vector2.ONE * r / 12.0 * sc, Color(1, 1, 1, al * a))


static func _ss(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)
