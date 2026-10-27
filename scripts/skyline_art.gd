extends RefCounted
## v0.19w MOCKUP (Hamza: "the background is just building silhouettes, make them more detailed while still
## looking good"): the city skyline behind the shop, for the sky strip above it. Two layers:
##   far  - paler, hazier towers (with the country's landmark) peeking over the top
##   near - proper buildings: glass offices with window grids, brick flats with sills, concrete blocks,
##          a shaded side on each, rooftop bits (water tanks, AC units, antennas with a red light at night,
##          a car-wash billboard), lit windows at night (warm + a few cool office blues).
## Drawn ONCE into a texture by the strip (it only changes with the hour / weather / city), so its many little
## shapes cost nothing per frame. Countries get their own flavour (Japan's lattice tower + curved eaves,
## Germany's TV tower + church spires, Australia's harbour sails + tower pod, UAE's needle + domes, USA's
## stepped art-deco spire + water tanks; the Hometown is a small town).

const INK := Color("1d1b2b")


## Draw into r (the bottom of r is the ground line). sky = Scenery.sky_colors(), nt = night 0..1.
static func draw(ci: CanvasItem, r: Rect2, country: String, nt: float, sky: Array, wet: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(country) + 77
	var top: Color = sky[0]
	var bot: Color = sky[1]
	var ground := r.end.y
	if country == "hometown":
		_town(ci, r, rng, nt, bot)
		return
	# ---- far layer: hazy, taller, the landmark
	var far := bot.lerp(Color("6f85ad"), 0.5).lerp(Color("232b55"), 0.75 * nt)
	if wet:
		far = far.lerp(Color("9aa3b3"), 0.4)
	var x := r.position.x - 6.0
	var k := 0
	var lm_x := r.position.x + r.size.x * 0.58
	while x < r.end.x:
		var bw := rng.randf_range(26.0, 46.0)
		var bh := rng.randf_range(r.size.y * 0.38, r.size.y * 0.66)
		if absf(x + bw * 0.5 - lm_x) < 40.0:
			x += bw + 2.0
			continue
		_far_tower(ci, Rect2(x, ground - bh, bw, bh), far, rng, nt, country)
		x += bw + rng.randf_range(0.0, 6.0)
		k += 1
	_landmark(ci, Vector2(lm_x, ground), r.size.y, far, nt, country)
	# ---- near layer
	x = r.position.x - 10.0
	k = 0
	var billboard_at := 2 + rng.randi() % 3
	while x < r.end.x:
		var kind := _pick(rng, country)
		var bw := rng.randf_range(36.0, 58.0)
		var bh := rng.randf_range(r.size.y * 0.2, r.size.y * 0.5)
		match kind:
			"glass":
				bh = rng.randf_range(r.size.y * 0.4, r.size.y * 0.58)
			"brick":
				bh = rng.randf_range(r.size.y * 0.22, r.size.y * 0.36)
		if absf(x + bw * 0.5 - lm_x) < 46.0:   # keep the landmark in view: only low shops in front of it
			bh = minf(bh, r.size.y * 0.16)
			kind = "gable" if country == "germany" else ("eaves" if country == "japan" else "concrete")
		var b := Rect2(x, ground - bh, bw, bh)
		_building(ci, b, kind, rng, nt, bot, country, k == billboard_at)
		x += bw + rng.randf_range(2.0, 7.0)
		k += 1
	if country == "australia":   # the harbour sails sit in front, by the water
		_sails(ci, Vector2(lm_x - 64.0, ground), nt, far)
	# a little haze at the very bottom so the strip joins the shop's roof
	for i in 6:
		ci.draw_rect(Rect2(r.position.x, ground - 3.0 * (i + 1), r.size.x, 3.0), Color(bot.r, bot.g, bot.b, 0.05 * (6 - i) * (1.0 - nt * 0.6)))


static func _pick(rng: RandomNumberGenerator, country: String) -> String:
	var opts := ["glass", "office", "brick", "concrete", "office"]
	match country:
		"japan":
			opts = ["glass", "office", "concrete", "eaves", "office", "glass"]
		"germany":
			opts = ["brick", "gable", "office", "concrete", "gable"]
		"australia":
			opts = ["glass", "office", "concrete", "glass", "brick"]
		"uae":
			opts = ["glass", "sand", "glass", "dome", "sand"]
	return opts[rng.randi() % opts.size()]


## The shade a building colour takes at this time of day: a touch of sky haze by day, deep blue at night.
static func _tint(c: Color, nt: float, bot: Color) -> Color:
	return c.lerp(bot, 0.18).lerp(Color("1c2348"), 0.72 * nt)


static func _lit(rng: RandomNumberGenerator, nt: float, cool := false) -> Color:
	if cool and rng.randf() < 0.4:
		return Color(0.74, 0.88, 1.0, 0.95 * nt)
	return Color(1.0, 0.85 + rng.randf() * 0.08, 0.52, 0.95 * nt)


static func _far_tower(ci: CanvasItem, b: Rect2, col: Color, rng: RandomNumberGenerator, nt: float, country: String) -> void:
	ci.draw_rect(b, col)
	var tops := ["flat", "step", "spire", "flat"]
	if country == "uae":
		tops = ["step", "spire", "dome", "step"]
	match tops[rng.randi() % tops.size()]:
		"step":
			ci.draw_rect(Rect2(b.position.x + b.size.x * 0.15, b.position.y - 7, b.size.x * 0.7, 7), col)
			ci.draw_rect(Rect2(b.position.x + b.size.x * 0.32, b.position.y - 13, b.size.x * 0.36, 6), col)
		"spire":
			ci.draw_colored_polygon(PackedVector2Array([b.position + Vector2(b.size.x * 0.3, 0), b.position + Vector2(b.size.x * 0.5, -18),
				b.position + Vector2(b.size.x * 0.7, 0)]), col)
		"dome":
			ci.draw_circle(b.position + Vector2(b.size.x * 0.5, 0), b.size.x * 0.32, col)
	# faint window stripes (and a few lights at night)
	var stripe := col.lightened(0.06)
	for wy in range(int(b.position.y + 5), int(b.end.y - 3), 6):
		ci.draw_rect(Rect2(b.position.x + 3, wy, b.size.x - 6, 2), stripe)
		if nt > 0.15:
			for wx in range(int(b.position.x + 4), int(b.end.x - 4), 5):
				if rng.randf() < 0.12:
					ci.draw_rect(Rect2(wx, wy, 3, 2), Color(1, 0.86, 0.55, 0.55 * nt))
	ci.draw_rect(Rect2(b.end.x - b.size.x * 0.28, b.position.y, b.size.x * 0.28, b.size.y), Color(0, 0, 0, 0.07))


static func _building(ci: CanvasItem, b: Rect2, kind: String, rng: RandomNumberGenerator, nt: float, bot: Color, country: String, billboard: bool) -> void:
	var base: Color
	match kind:
		"glass": base = Color("6f9fd0")
		"office": base = Color("93a4bb")
		"brick": base = Color("b9735a")
		"concrete": base = Color("c4bcae")
		"eaves": base = Color("d8cdb8")
		"gable": base = Color("d9c7a6")
		"sand": base = Color("dcc49a")
		"dome": base = Color("e6dccb")
		_: base = Color("a0a8b8")
	var c := _tint(base, nt, bot)
	var edge := c.darkened(0.42)
	ci.draw_rect(b, c)
	var L := b.position.x
	var R := b.end.x
	var T := b.position.y
	var B := b.end.y
	var w := b.size.x
	match kind:
		"glass":
			# tall glass panes in columns, a sheen streak, a stepped crown
			var cols := int(w / 7.0)
			for i in cols:
				var px := L + 3.0 + i * (w - 6.0) / cols
				var pane := c.lightened(0.14 if i % 2 == 0 else 0.05)
				ci.draw_rect(Rect2(px, T + 6, (w - 6.0) / cols - 1.5, b.size.y - 8), pane)
			for wy in range(int(T + 10), int(B - 2), 7):
				ci.draw_rect(Rect2(L + 2, wy, w - 4, 1.2), c.darkened(0.12))
				if nt > 0.1:
					for i in cols:
						if rng.randf() < 0.3:
							var px := L + 3.0 + i * (w - 6.0) / cols
							ci.draw_rect(Rect2(px, wy - 5.5, (w - 6.0) / cols - 1.5, 5), _lit(rng, nt, true))
			if nt < 0.6:   # the sheen (daylight only)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(L + w * 0.18, B), Vector2(L + w * 0.34, B), Vector2(L + w * 0.62, T + 6), Vector2(L + w * 0.46, T + 6)]),
					Color(1, 1, 1, 0.16 * (1.0 - nt)))
			ci.draw_rect(Rect2(L + w * 0.12, T - 6, w * 0.76, 6), c.darkened(0.08))
			ci.draw_rect(Rect2(L + w * 0.3, T - 11, w * 0.4, 5), c.darkened(0.12))
			_antenna(ci, Vector2(L + w * 0.5, T - 11), 16.0, edge, nt)
		"office", "concrete", "sand":
			# rows of square windows with a frame band between floors
			var ww := 5.0
			var gap := 4.0
			var n := int((w - 6.0) / (ww + gap))
			var x0 := L + (w - n * (ww + gap) + gap) * 0.5
			for wy in range(int(T + 6), int(B - 6), 9):
				ci.draw_rect(Rect2(L, wy + 6.5, w, 1.0), c.darkened(0.1))
				for i in n:
					var wc: Color = c.darkened(0.28) if nt < 0.1 else c.darkened(0.2)
					if nt < 0.5:
						wc = wc.lerp(Color("bfd9ee"), 0.35 * (1.0 - nt * 2.0))   # day: the windows catch the sky
					if nt > 0.1 and rng.randf() < 0.38:
						wc = _lit(rng, nt, kind == "office")
					ci.draw_rect(Rect2(x0 + i * (ww + gap), wy, ww, 6), wc)
			# roof bits
			ci.draw_rect(Rect2(L - 1, T - 3, w + 2, 3), c.darkened(0.15))
			if rng.randf() < 0.5:
				ci.draw_rect(Rect2(L + w * 0.2, T - 9, 10, 6), c.darkened(0.2))   # AC units
				ci.draw_rect(Rect2(L + w * 0.2 + 12, T - 7, 7, 4), c.darkened(0.2))
			elif country == "usa" and rng.randf() < 0.7:
				_water_tank(ci, Vector2(L + w * 0.65, T - 3), c.darkened(0.25).lerp(Color("8a5a3c"), 0.4), nt)
			else:
				_antenna(ci, Vector2(L + w * 0.75, T - 3), 10.0, edge, nt)
			if kind == "sand":   # UAE: a crenellated parapet + arched windows feel
				for i in int(w / 8.0):
					ci.draw_rect(Rect2(L + 2 + i * 8.0, T - 6, 4, 4), c.darkened(0.06))
		"brick":
			# warm brick with white-silled windows, a flat roof edge, maybe a fire escape
			for wy in range(int(T + 7), int(B - 6), 11):
				for i in int((w - 8.0) / 11.0):
					var wx := L + 6 + i * 11.0
					var wc := Color("3e3446").lerp(Color("1c2348"), 0.5 * nt)
					if nt > 0.1 and rng.randf() < 0.45:
						wc = _lit(rng, nt)
					ci.draw_rect(Rect2(wx, wy, 6, 7), wc)
					ci.draw_rect(Rect2(wx - 1, wy + 7, 8, 1.6), Color("efe6da").lerp(Color("39406a"), 0.7 * nt))
			ci.draw_rect(Rect2(L - 1, T - 3, w + 2, 4), c.darkened(0.2))
			if rng.randf() < 0.5:
				var fx := R - 12.0
				for wy in range(int(T + 14), int(B - 6), 11):
					ci.draw_line(Vector2(fx, wy), Vector2(fx + 9, wy), edge, 1.2)
					ci.draw_line(Vector2(fx, wy), Vector2(fx + 9, wy - 11), edge, 1.0)
		"eaves", "gable":
			# low homes / shops: a pitched roof (Japan: curved eaves in dark tile), two rows of windows
			var roof := Color("4f5a6e") if kind == "eaves" else Color("b5543c")
			roof = _tint(roof, nt, bot)
			if kind == "eaves":
				ci.draw_colored_polygon(PackedVector2Array([Vector2(L - 6, T + 2), Vector2(L + w * 0.2, T - 8), Vector2(R - w * 0.2, T - 8), Vector2(R + 6, T + 2),
					Vector2(R + 2, T + 4), Vector2(L - 2, T + 4)]), roof)
				ci.draw_line(Vector2(L - 6, T + 2), Vector2(L - 9, T - 2), roof, 2.5)
				ci.draw_line(Vector2(R + 6, T + 2), Vector2(R + 9, T - 2), roof, 2.5)
			else:
				ci.draw_colored_polygon(PackedVector2Array([Vector2(L - 3, T + 1), Vector2(L + w * 0.5, T - w * 0.42), Vector2(R + 3, T + 1)]), roof)
				ci.draw_rect(Rect2(L + w * 0.42, T - w * 0.3 - 8, 5, 10), roof.darkened(0.2))   # chimney
			for wy in range(int(T + 8), int(B - 6), 12):
				for i in int((w - 8.0) / 12.0):
					var wx := L + 7 + i * 12.0
					var wc := c.darkened(0.35)
					if nt > 0.1 and rng.randf() < 0.5:
						wc = _lit(rng, nt)
					ci.draw_rect(Rect2(wx, wy, 7, 7), wc)
					ci.draw_rect(Rect2(wx + 3, wy, 1, 7), c)
		"dome":
			ci.draw_circle(Vector2(L + w * 0.5, T), w * 0.36, c)
			ci.draw_rect(Rect2(L + w * 0.5 - 1, T - w * 0.36 - 8, 2, 8), Color("d7a93a"))
			for i in 3:
				var ax := L + w * (0.22 + 0.28 * i)
				var wc := c.darkened(0.3)
				if nt > 0.1:
					wc = _lit(rng, nt)
				ci.draw_rect(Rect2(ax - 3, T + 10, 6, 10), wc)
				ci.draw_circle(Vector2(ax, T + 10), 3.0, wc)
	# the shaded side + a thin crisp edge
	ci.draw_rect(Rect2(R - w * 0.22, T, w * 0.22, b.size.y), Color(0, 0, 0, 0.1 + 0.05 * nt))
	ci.draw_rect(Rect2(L, T, 2, b.size.y), Color(1, 1, 1, 0.12 * (1.0 - nt)))
	ci.draw_polyline(PackedVector2Array([Vector2(L, B), Vector2(L, T), Vector2(R, T), Vector2(R, B)]), Color(edge.r, edge.g, edge.b, 0.55), 1.2)
	if billboard:
		_billboard(ci, Vector2(L + w * 0.5, T - 4), nt)


static func _antenna(ci: CanvasItem, foot: Vector2, h: float, col: Color, nt: float) -> void:
	ci.draw_line(foot, foot + Vector2(0, -h), col, 1.5)
	ci.draw_line(foot + Vector2(-3, -h * 0.4), foot + Vector2(3, -h * 0.4), col, 1.0)
	if nt > 0.2:
		ci.draw_circle(foot + Vector2(0, -h), 4.5, Color(1, 0.2, 0.15, 0.25 * nt))
		ci.draw_circle(foot + Vector2(0, -h), 1.8, Color(1, 0.3, 0.25, nt))


static func _water_tank(ci: CanvasItem, foot: Vector2, col: Color, nt: float) -> void:
	ci.draw_line(foot + Vector2(-5, 0), foot + Vector2(-4, -6), col.darkened(0.3), 1.2)
	ci.draw_line(foot + Vector2(5, 0), foot + Vector2(4, -6), col.darkened(0.3), 1.2)
	ci.draw_rect(Rect2(foot + Vector2(-6, -15), Vector2(12, 9)), col)
	for i in 3:
		ci.draw_line(foot + Vector2(-6, -13 + i * 3), foot + Vector2(6, -13 + i * 3), col.darkened(0.15), 0.8)
	ci.draw_colored_polygon(PackedVector2Array([foot + Vector2(-7, -15), foot + Vector2(0, -21), foot + Vector2(7, -15)]), col.darkened(0.2))


## A little roadside-style billboard on a roof: a blue board with a soap-bubble + droplet ad (lit at night).
static func _billboard(ci: CanvasItem, foot: Vector2, nt: float) -> void:
	var leg := Color("5a6274").lerp(Color("1c2348"), 0.6 * nt)
	ci.draw_line(foot + Vector2(-12, 0), foot + Vector2(-12, -8), leg, 2.0)
	ci.draw_line(foot + Vector2(12, 0), foot + Vector2(12, -8), leg, 2.0)
	var r := Rect2(foot + Vector2(-22, -26), Vector2(44, 19))
	var board := Color("2f8ee0").lerp(Color("1a3d78"), 0.5 * nt)
	ci.draw_rect(r, board)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), Color("ffd23f").lerp(Color("8a7a30"), 0.4 * nt))
	ci.draw_circle(r.position + Vector2(10, 11), 4.0, Color(1, 1, 1, 0.85))
	ci.draw_circle(r.position + Vector2(16, 14), 2.5, Color(1, 1, 1, 0.7))
	var d := r.position + Vector2(31, 12)
	ci.draw_circle(d + Vector2(0, 2), 4.0, Color("8fe3ff"))
	ci.draw_colored_polygon(PackedVector2Array([d + Vector2(-3.5, 1), d + Vector2(0, -6), d + Vector2(3.5, 1)]), Color("8fe3ff"))
	ci.draw_polyline(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]), INK.lerp(leg, 0.3), 1.2)
	if nt > 0.2:   # two little lamps shining up onto it
		ci.draw_colored_polygon(PackedVector2Array([foot + Vector2(-14, -7), r.position + Vector2(2, 3), Vector2(r.position.x + 20, r.position.y + 3)]), Color(1, 0.95, 0.7, 0.18 * nt))
		ci.draw_colored_polygon(PackedVector2Array([foot + Vector2(14, -7), Vector2(r.end.x - 20, r.position.y + 3), Vector2(r.end.x - 2, r.position.y + 3)]), Color(1, 0.95, 0.7, 0.18 * nt))


## Each country's landmark, standing in the far layer.
static func _landmark(ci: CanvasItem, foot: Vector2, h: float, col: Color, nt: float, country: String) -> void:
	var c := col.darkened(0.04)
	match country:
		"usa":   # a stepped art-deco tower with a needle
			ci.draw_rect(Rect2(foot.x - 20, foot.y - h * 0.62, 40, h * 0.62), c)
			ci.draw_rect(Rect2(foot.x - 14, foot.y - h * 0.72, 28, h * 0.1 + 1), c)
			ci.draw_rect(Rect2(foot.x - 9, foot.y - h * 0.8, 18, h * 0.08 + 1), c)
			ci.draw_rect(Rect2(foot.x - 5, foot.y - h * 0.86, 10, h * 0.06 + 1), c)
			ci.draw_line(Vector2(foot.x, foot.y - h * 0.86), Vector2(foot.x, foot.y - h * 0.99), c, 2.0)
			for wy in range(int(foot.y - h * 0.6), int(foot.y - 4), 6):
				ci.draw_rect(Rect2(foot.x - 16, wy, 32, 2), c.lightened(0.06))
			_antenna(ci, Vector2(foot.x, foot.y - h * 0.99), 1.0, c, nt)
		"japan":   # a red + white lattice tower
			var red := Color("e0553d").lerp(col, 0.45).lerp(Color("5a2a3a"), 0.5 * nt)
			var white := Color("f2efe8").lerp(col, 0.45).lerp(Color("3a4170"), 0.5 * nt)
			var top := foot + Vector2(0, -h * 0.95)
			for side in [-1.0, 1.0]:
				ci.draw_line(foot + Vector2(side * 22, 0), top + Vector2(side * 2, h * 0.18), red, 3.0)
			for i in 6:
				var t := float(i + 1) / 7.0
				var y := lerpf(foot.y, top.y + h * 0.18, t)
				var hw := lerpf(22.0, 2.0, t)
				ci.draw_line(Vector2(foot.x - hw, y), Vector2(foot.x + hw, y), white if i % 2 == 0 else red, 2.0)
				ci.draw_line(Vector2(foot.x - hw, y), Vector2(foot.x + lerpf(22.0, 2.0, t - 1.0 / 7.0), y + (foot.y - top.y - h * 0.18) / 7.0), red, 1.0)
			ci.draw_rect(Rect2(foot.x - 9, foot.y - h * 0.42, 18, 6), white)
			ci.draw_line(top + Vector2(0, h * 0.18), top, red, 2.0)
			_antenna(ci, top, 1.0, red, nt)
		"germany":   # the TV tower: a thin shaft, a ball, a needle (and twin church spires beside it)
			ci.draw_rect(Rect2(foot.x - 3, foot.y - h * 0.7, 6, h * 0.7), c)
			ci.draw_circle(Vector2(foot.x, foot.y - h * 0.72), 10.0, c)
			ci.draw_rect(Rect2(foot.x - 11, foot.y - h * 0.725, 22, 2), c.lightened(0.12))
			ci.draw_line(Vector2(foot.x, foot.y - h * 0.8), Vector2(foot.x, foot.y - h * 0.98), c, 2.0)
			_antenna(ci, Vector2(foot.x, foot.y - h * 0.98), 1.0, c, nt)
			for sx in [-46.0, -32.0]:
				ci.draw_rect(Rect2(foot.x + sx - 5, foot.y - h * 0.42, 10, h * 0.42), c)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(foot.x + sx - 6, foot.y - h * 0.42), Vector2(foot.x + sx, foot.y - h * 0.7),
					Vector2(foot.x + sx + 6, foot.y - h * 0.42)]), c)
		"australia":   # the harbour sails + a tower with a golden pod
			ci.draw_rect(Rect2(foot.x - 2.5, foot.y - h * 0.78, 5, h * 0.78), c)
			ci.draw_rect(Rect2(foot.x - 9, foot.y - h * 0.82, 18, 10), Color("d9a640").lerp(col, 0.5).lerp(Color("3a4170"), 0.5 * nt))
			ci.draw_line(Vector2(foot.x, foot.y - h * 0.82), Vector2(foot.x, foot.y - h * 0.98), c, 2.0)
			_antenna(ci, Vector2(foot.x, foot.y - h * 0.98), 1.0, c, nt)
		"uae":   # a needle super-tower in setbacks
			var steps := 6
			for i in steps:
				var t := float(i) / steps
				var hw := lerpf(18.0, 3.0, t)
				ci.draw_rect(Rect2(foot.x - hw, foot.y - h * (0.16 + 0.13 * i), hw * 2.0, h * 0.16 + 1), c)
			ci.draw_line(Vector2(foot.x, foot.y - h * 0.9), Vector2(foot.x, foot.y - h * 1.02), c, 2.0)
			_antenna(ci, Vector2(foot.x, foot.y - h * 1.02), 1.0, c, nt)
			if nt > 0.15:
				for i in 10:
					ci.draw_rect(Rect2(foot.x - 1, foot.y - h * (0.1 + 0.08 * i), 2, 3), Color(1, 0.86, 0.55, 0.6 * nt))


## The Hometown: a small town (houses, trees, a water tower), no towers.
static func _town(ci: CanvasItem, r: Rect2, rng: RandomNumberGenerator, nt: float, bot: Color) -> void:
	var ground := r.end.y
	var x := r.position.x - 6.0
	var k := 0
	while x < r.end.x:
		if k % 3 == 2:
			var tc := _tint(Color("5f9e57"), nt, bot)
			ci.draw_rect(Rect2(x + 9, ground - 10, 3, 10), _tint(Color("7a5236"), nt, bot))
			ci.draw_circle(Vector2(x + 10, ground - 18), 11.0, tc)
			ci.draw_circle(Vector2(x + 4, ground - 13), 7.0, tc.darkened(0.08))
			x += 22.0
		else:
			var bw := rng.randf_range(30.0, 42.0)
			var hh := rng.randf_range(20.0, 30.0)
			_building(ci, Rect2(x, ground - hh, bw, hh), "gable", rng, nt, bot, "hometown", false)
			x += bw + 6.0
		k += 1
	_water_tank(ci, Vector2(r.position.x + r.size.x * 0.62, ground - 30), _tint(Color("9aa6b8"), nt, bot), nt)
	ci.draw_line(Vector2(r.position.x + r.size.x * 0.62 - 5, ground), Vector2(r.position.x + r.size.x * 0.62 - 5, ground - 30), _tint(Color("6b7385"), nt, bot), 2.0)
	ci.draw_line(Vector2(r.position.x + r.size.x * 0.62 + 5, ground), Vector2(r.position.x + r.size.x * 0.62 + 5, ground - 30), _tint(Color("6b7385"), nt, bot), 2.0)


static func _sails(ci: CanvasItem, foot: Vector2, nt: float, col: Color) -> void:
	var sail := Color("f7f4ee").lerp(col, 0.15).lerp(Color("4a5080"), 0.55 * nt)
	ci.draw_rect(Rect2(foot.x - 4, foot.y - 5, 70, 5), Color("c9b48f").lerp(Color("2a3158"), 0.6 * nt))
	for i in 5:
		var sx := foot.x + i * 12.0
		var sh := 14.0 + float(2 - absi(i - 2)) * 6.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(sx, foot.y - 5), Vector2(sx + 3, foot.y - 5 - sh), Vector2(sx + 16, foot.y - 5)]), sail)
		ci.draw_line(Vector2(sx + 3, foot.y - 5 - sh), Vector2(sx + 16, foot.y - 5), sail.darkened(0.18), 1.2)
		ci.draw_line(Vector2(sx, foot.y - 5), Vector2(sx + 3, foot.y - 5 - sh), sail.darkened(0.3), 1.0)
