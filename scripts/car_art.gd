extends RefCounted
## Cartoon side-view cars (v0.17d art pass), drawn in code: bubbly rounded bodies, thick dark
## outlines, glossy gradient paint, glass with glare, big shiny wheels. All original shapes:
## body STYLES hint at a kind of car (hatch, sedan, muscle, hypercar...) without copying any.
## Each car id picks a style in BODY (unknown ids fall back by class + tier). Rare cars (VIP)
## get extras: wings, racing stripes, light bars.
##   draw(ci, rect, car, color, dirt, specks, shine, silhouette)
## rect: the car fills its width and stands on its bottom edge.

const OUTLINE := Color("1d1b2b")
const GLASS_TOP := Color("d9f3ff")
const GLASS_BOT := Color("4f8fc9")
const TIRE := Color("26252f")
const RIM := Color("dfe5ee")

# body outline: points (x from rear 0 to front 1, height above ground), clockwise from rear-bottom.
# window: the side glass. pillars: x of the posts between windows. wheels: [rear x, front x, radius].
const STYLES := {
	"hatch": {"body": [[0.02, 0.08], [0.0, 0.20], [0.03, 0.31], [0.10, 0.42], [0.50, 0.43], [0.66, 0.29], [0.90, 0.255], [1.0, 0.20], [1.0, 0.10], [0.97, 0.08]],
		"window": [[0.12, 0.29], [0.155, 0.39], [0.48, 0.395], [0.61, 0.29]], "pillars": [0.37], "wheels": [0.18, 0.81, 0.105]},
	"sedan": {"body": [[0.01, 0.08], [0.0, 0.21], [0.02, 0.27], [0.20, 0.29], [0.30, 0.41], [0.58, 0.415], [0.72, 0.29], [0.93, 0.26], [1.0, 0.21], [1.0, 0.10], [0.98, 0.08]],
		"window": [[0.24, 0.285], [0.32, 0.385], [0.56, 0.39], [0.67, 0.285]], "pillars": [0.45], "wheels": [0.19, 0.80, 0.105]},
	"wagon": {"body": [[0.01, 0.08], [0.0, 0.22], [0.02, 0.35], [0.06, 0.41], [0.58, 0.41], [0.72, 0.29], [0.93, 0.26], [1.0, 0.21], [1.0, 0.10], [0.98, 0.08]],
		"window": [[0.07, 0.29], [0.09, 0.385], [0.56, 0.385], [0.67, 0.285]], "pillars": [0.28, 0.47], "wheels": [0.18, 0.80, 0.105]},
	"coupe": {"body": [[0.01, 0.08], [0.0, 0.20], [0.03, 0.25], [0.18, 0.27], [0.36, 0.37], [0.55, 0.375], [0.70, 0.26], [0.93, 0.215], [1.0, 0.17], [1.0, 0.09], [0.97, 0.08]],
		"window": [[0.24, 0.265], [0.37, 0.35], [0.53, 0.352], [0.65, 0.26]], "pillars": [], "wheels": [0.19, 0.80, 0.108]},
	"muscle": {"body": [[0.01, 0.08], [0.0, 0.22], [0.02, 0.27], [0.14, 0.285], [0.32, 0.39], [0.50, 0.395], [0.62, 0.28], [0.95, 0.26], [1.0, 0.22], [1.0, 0.10], [0.98, 0.08]],
		"window": [[0.20, 0.28], [0.33, 0.37], [0.49, 0.372], [0.58, 0.275]], "pillars": [], "wheels": [0.19, 0.79, 0.11]},
	"gt": {"body": [[0.01, 0.08], [0.0, 0.20], [0.04, 0.255], [0.16, 0.28], [0.33, 0.375], [0.50, 0.38], [0.62, 0.27], [0.93, 0.225], [1.0, 0.18], [1.0, 0.09], [0.97, 0.08]],
		"window": [[0.21, 0.275], [0.34, 0.36], [0.49, 0.362], [0.58, 0.27]], "pillars": [], "wheels": [0.19, 0.80, 0.108]},
	"hyper": {"body": [[0.01, 0.075], [0.0, 0.17], [0.03, 0.245], [0.28, 0.275], [0.46, 0.335], [0.57, 0.335], [0.75, 0.215], [0.95, 0.15], [1.0, 0.12], [1.0, 0.075], [0.97, 0.07]],
		"window": [[0.41, 0.29], [0.475, 0.318], [0.56, 0.318], [0.71, 0.218]], "pillars": [], "wheels": [0.19, 0.80, 0.112]},
	"suv": {"body": [[0.01, 0.10], [0.0, 0.30], [0.02, 0.46], [0.07, 0.50], [0.62, 0.50], [0.74, 0.36], [0.94, 0.33], [1.0, 0.28], [1.0, 0.12], [0.98, 0.10]],
		"window": [[0.06, 0.36], [0.085, 0.47], [0.60, 0.47], [0.69, 0.36]], "pillars": [0.27, 0.46], "wheels": [0.19, 0.80, 0.125]},
	"boxy": {"body": [[0.01, 0.10], [0.0, 0.30], [0.0, 0.50], [0.03, 0.53], [0.66, 0.53], [0.72, 0.38], [0.97, 0.36], [1.0, 0.33], [1.0, 0.12], [0.98, 0.10]],
		"window": [[0.05, 0.38], [0.05, 0.50], [0.64, 0.50], [0.69, 0.38]], "pillars": [0.25, 0.45], "wheels": [0.18, 0.81, 0.128]},
	"ute": {"body": [[0.01, 0.10], [0.0, 0.31], [0.40, 0.31], [0.42, 0.49], [0.64, 0.49], [0.75, 0.35], [0.95, 0.32], [1.0, 0.27], [1.0, 0.12], [0.98, 0.10]],
		"window": [[0.45, 0.35], [0.46, 0.46], [0.62, 0.46], [0.70, 0.35]], "pillars": [], "wheels": [0.19, 0.80, 0.125]},
	"limo": {"body": [[0.01, 0.09], [0.0, 0.24], [0.02, 0.30], [0.16, 0.32], [0.24, 0.44], [0.62, 0.445], [0.73, 0.31], [0.93, 0.29], [1.0, 0.24], [1.0, 0.11], [0.98, 0.09]],
		"window": [[0.20, 0.31], [0.26, 0.42], [0.60, 0.42], [0.69, 0.31]], "pillars": [0.37, 0.50], "wheels": [0.17, 0.82, 0.11]},
}
const TALL := ["suv", "boxy", "ute"]

const BODY := {
	"swiff": "hatch", "corollo98": "sedan", "lanzer": "sedan", "pollo": "hatch", "fiestah": "hatch",
	"commodoor_vt": "sedan", "falcone_el": "sedan", "hilox04": "ute", "trighton": "ute",
	"cammy": "sedan", "mazdo3": "hatch", "civvic": "sedan", "gulf": "hatch", "audee_a3": "hatch",
	"commodoor_ss": "sedan", "rangah": "ute", "rav5": "suv",
	"wrz": "sedan", "civvic_z": "hatch", "nizzan_370": "coupe", "gulf_r": "hatch", "mustank": "muscle",
	"camero": "muscle", "landcrusher": "boxy", "raptoar": "ute",
	"n3_comp": "sedan", "ang_c63": "sedan", "rz6": "wagon", "gtz": "gt", "soupra": "coupe", "hellkat": "muscle",
	"rangey": "suv", "g_wagan": "boxy",
	"gt3rz": "coupe", "hurrycane": "hyper", "mcc_702": "hyper", "ferrori_roamer": "gt", "skyliner": "coupe",
	"nzx": "coupe", "corvetta": "gt", "ewrus": "suv", "cullinin": "suv",
	# rare visitors
	"demon": "muscle", "dune_king": "ute", "interceptor": "muscle", "cobrah": "gt", "gt41": "hyper", "thunderhawk": "muscle",
	"nzx_z": "coupe", "rz7": "coupe", "kaminari": "sedan", "toyoter_2000": "gt", "lancet_final": "sedan", "z_toon": "coupe",
	"kaiser_csl": "coupe", "ringmeister": "wagon", "hatch_club": "hatch", "wagan6x6": "boxy", "kestrel_rs": "coupe", "silberpfeil": "hyper",
	"hilox_rally": "ute", "larrikin_gtsr": "sedan", "fairway_p4": "sedan", "boomerang": "muscle", "trailblazer": "suv", "mountain_king": "muscle",
	"phantum": "limo", "continentil": "gt", "adventurdor": "hyper", "mcc_q1": "hyper", "laferrori": "hyper", "chiroon": "hyper", "jesco": "hyper",
}

static var _cache := {}


static func style_of(car: Dictionary) -> String:
	var id := str(car.get("id", ""))
	if BODY.has(id):
		return BODY[id]
	match str(car.get("class", "")):
		"offroad":
			return "suv"
		"muscle":
			return "muscle"
		_:
			return ["hatch", "hatch", "sedan", "sedan", "coupe", "hyper"][clampi(int(car.get("tier", 1)), 0, 5)]


## Rounds a polygon (Chaikin corner cutting): the bubbly look.
static func _smooth(pts: PackedVector2Array, passes: int = 3) -> PackedVector2Array:
	var p := pts
	for _k in passes:
		var q := PackedVector2Array()
		var n := p.size()
		for i in n:
			var a := p[i]
			var b := p[(i + 1) % n]
			q.append(a.lerp(b, 0.25))
			q.append(a.lerp(b, 0.75))
		p = q
	return p


static func _shape(style: String, key: String) -> PackedVector2Array:
	var ck := style + "|" + key
	if _cache.has(ck):
		return _cache[ck]
	var src: Array = STYLES[style][key]
	var p := PackedVector2Array()
	for v in src:
		p.append(Vector2(v[0], v[1]))
	var out := _smooth(p, 3 if key == "body" else 2)
	_cache[ck] = out
	return out


## unit point (x along the car, h above ground) -> screen
static func _tx(v: Vector2, o: Vector2, L: float) -> Vector2:
	return Vector2(o.x + v.x * L, o.y - v.y * L)


static func _txa(pts: PackedVector2Array, o: Vector2, L: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = _tx(pts[i], o, L)
	return out


static func _vgrad(pts: PackedVector2Array, top: Color, bot: Color) -> PackedColorArray:
	var y0 := 1e9
	var y1 := -1e9
	for p in pts:
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	var cols := PackedColorArray()
	cols.resize(pts.size())
	for i in pts.size():
		cols[i] = top.lerp(bot, (pts[i].y - y0) / maxf(1.0, y1 - y0))
	return cols


## v0.18: the car's body outline in screen space, placed exactly like draw() places it (the foam layer
## uses it so foam covers the whole car and nothing outside it).
static func body_outline(rect: Rect2, car: Dictionary) -> PackedVector2Array:
	var style := style_of(car)
	var L := rect.size.x * (0.9 if TALL.has(style) else 1.0)
	var o := Vector2(rect.position.x + (rect.size.x - L) * 0.5, rect.end.y)
	return _txa(_shape(style, "body"), o, L)


static func draw(ci: CanvasItem, rect: Rect2, car: Dictionary, color: Color, dirt: float = 0.0, specks: Array = [],
		shine: float = 0.0, silhouette: bool = false) -> void:
	var style := style_of(car)
	var st: Dictionary = STYLES[style]
	var L := rect.size.x * (0.9 if TALL.has(style) else 1.0)
	var o := Vector2(rect.position.x + (rect.size.x - L) * 0.5, rect.end.y)
	var lw := maxf(1.5, L * 0.013)   # outline width
	var vip := car.has("rarity") and car.has("country")
	var rare := int(car.get("rarity", -1))
	var body := _txa(_shape(style, "body"), o, L)

	# dirt dulls the paint towards a muddy brown
	var paint := color
	if not silhouette and dirt > 0.0:
		paint = color.lerp(Color("8a7356"), 0.28 * dirt)
	var w: Array = st["wheels"]
	var wr: float = float(w[2]) * L
	var wheels: Array = [float(w[0]), float(w[1])]
	if str(car.get("id", "")) == "wagan6x6":
		wheels = [float(w[0]), float(w[0]) + 0.22, float(w[1])]

	# ground shadow
	ci.draw_set_transform(Vector2(o.x + L * 0.5, o.y - 1.0), 0.0, Vector2(1.0, 0.11))
	ci.draw_circle(Vector2.ZERO, L * 0.52, Color(0, 0, 0, 0.28))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if silhouette:
		ci.draw_colored_polygon(body, color)
		for wx in wheels:
			ci.draw_circle(Vector2(o.x + wx * L, o.y - wr), wr, color)
		var bl := body.duplicate()
		bl.append(body[0])
		ci.draw_polyline(bl, color.lightened(0.12), lw, true)
		return

	# extras that sit behind the body
	if vip and (style in ["hyper", "coupe"] or (style == "sedan" and rare >= 1)):
		_wing(ci, o, L, lw, style, paint)

	# body: outline first (fat), then the gradient paint
	var bl := body.duplicate()
	bl.append(body[0])
	ci.draw_polyline(bl, OUTLINE, lw * 2.2, true)
	ci.draw_polygon(body, _vgrad(body, paint.lightened(0.28), paint.darkened(0.32)))
	# darker skirt between the wheels
	var sk0 := _tx(Vector2(float(wheels[0]) + float(w[2]) * 1.05, 0.11), o, L)
	var sk1 := _tx(Vector2(float(wheels[-1]) - float(w[2]) * 1.05, 0.08), o, L)
	UiThemeLite.rounded(ci, Rect2(sk0.x, sk0.y, sk1.x - sk0.x, sk1.y - sk0.y), paint.darkened(0.45), int(L * 0.012))
	# racing stripes on rare muscle cars / rally stripe on rare 4x4s
	if vip and (style == "muscle" or style == "ute" or style == "suv"):
		var y := 0.17 if style == "muscle" else 0.22
		var s0 := _tx(Vector2(0.07, y + 0.025), o, L)
		var s1 := _tx(Vector2(0.93, y), o, L)
		var sc := Color.WHITE if paint.get_luminance() < 0.6 else Color("212121")
		ci.draw_rect(Rect2(s0.x, s0.y, s1.x - s0.x, L * 0.014), sc)
		ci.draw_rect(Rect2(s0.x, s0.y + L * 0.022, s1.x - s0.x, L * 0.008), sc)

	# style details
	match style:
		"hyper":
			# side air intake behind the door
			var ip := PackedVector2Array([_tx(Vector2(0.27, 0.205), o, L), _tx(Vector2(0.39, 0.235), o, L), _tx(Vector2(0.37, 0.14), o, L), _tx(Vector2(0.29, 0.13), o, L)])
			ci.draw_colored_polygon(_smooth(ip, 2), OUTLINE.lightened(0.08))
		"muscle":
			# bonnet scoop
			var sc0 := _tx(Vector2(0.74, 0.285), o, L)
			UiThemeLite.rounded(ci, Rect2(sc0.x, sc0.y - L * 0.012, L * 0.11, L * 0.03), paint.darkened(0.2), int(L * 0.012), maxi(1, int(lw)), OUTLINE)
		"ute":
			# tray: rail + split from the cab
			ci.draw_line(_tx(Vector2(0.02, 0.305), o, L), _tx(Vector2(0.40, 0.305), o, L), paint.lightened(0.35), lw * 1.4)
			ci.draw_line(_tx(Vector2(0.405, 0.30), o, L), _tx(Vector2(0.405, 0.12), o, L), Color(OUTLINE.r, OUTLINE.g, OUTLINE.b, 0.7), lw)
			ci.draw_line(_tx(Vector2(0.03, 0.26), o, L), _tx(Vector2(0.37, 0.26), o, L), Color(OUTLINE.r, OUTLINE.g, OUTLINE.b, 0.35), lw * 0.7)
		"boxy":
			# spare wheel on the back door
			var sp := _tx(Vector2(-0.015, 0.30), o, L)
			ci.draw_circle(sp, L * 0.075 + lw, OUTLINE)
			ci.draw_circle(sp, L * 0.075, TIRE)
			ci.draw_circle(sp, L * 0.04, paint.darkened(0.15))

	# glass
	var win := _txa(_shape(style, "window"), o, L)
	ci.draw_polygon(win, _vgrad(win, GLASS_TOP.lerp(Color("8d7a60"), 0.5 * dirt), GLASS_BOT.lerp(Color("5a4a36"), 0.5 * dirt)))
	# glare: a white slash across the glass
	var wb := _bbox(win)
	var gx := wb.position.x + wb.size.x * 0.55
	var glare := PackedVector2Array([Vector2(gx, wb.position.y + 2), Vector2(gx + wb.size.x * 0.14, wb.position.y + 2),
		Vector2(gx - wb.size.x * 0.05, wb.end.y - 2), Vector2(gx - wb.size.x * 0.19, wb.end.y - 2)])
	if Geometry2D.intersect_polygons(glare, win).size() > 0:
		for g in Geometry2D.intersect_polygons(glare, win):
			ci.draw_colored_polygon(g, Color(1, 1, 1, 0.35))
	var wl := win.duplicate()
	wl.append(win[0])
	ci.draw_polyline(wl, OUTLINE, lw * 1.1, true)
	# pillars between the windows (body colour, outlined)
	for px in st["pillars"]:
		var a := _tx(Vector2(float(px), 0.0), o, L)
		var top := wb.position.y
		var bot := wb.end.y
		ci.draw_line(Vector2(a.x, top), Vector2(a.x - L * 0.006, bot), OUTLINE, L * 0.03)
		ci.draw_line(Vector2(a.x, top + 1), Vector2(a.x - L * 0.006, bot - 1), paint.darkened(0.08), L * 0.018)

	# door seams + handles
	var doors: Array = []
	var win_src: Array = st["window"]
	var front_door := float(win_src[-1][0]) - 0.01
	doors.append(front_door)
	if st["pillars"].size() > 0:
		doors.append(float(st["pillars"][-1]) - 0.005)
	var belt := float(win_src[0][1])
	for dx in doors:
		var t0 := _tx(Vector2(dx, belt), o, L)
		var t1 := _tx(Vector2(dx + 0.005, 0.11), o, L)
		ci.draw_line(t0, t1, Color(OUTLINE.r, OUTLINE.g, OUTLINE.b, 0.55), maxf(1.0, lw * 0.7))
		var hp := _tx(Vector2(dx - 0.06, belt - 0.035), o, L)
		UiThemeLite.rounded(ci, Rect2(hp.x, hp.y, L * 0.04, L * 0.012), paint.darkened(0.35), int(L * 0.006))

	# gloss: a long highlight along the shoulder + a soft one on the bonnet
	var h0 := _tx(Vector2(0.06, belt - 0.03), o, L)
	var h1 := _tx(Vector2(0.92, belt - 0.045), o, L)
	ci.draw_line(h0, h1, Color(1, 1, 1, 0.32), maxf(1.5, L * 0.012), true)
	var hb := _tx(Vector2(0.84, belt - 0.005), o, L)
	ci.draw_set_transform(hb, -0.08, Vector2(1.0, 0.28))
	ci.draw_circle(Vector2.ZERO, L * 0.06, Color(1, 1, 1, 0.16))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# lights: headlight at the front, tail light at the back
	var nose := _nose_y(style)
	var hl := _tx(Vector2(0.955, nose), o, L)
	UiThemeLite.rounded(ci, Rect2(hl.x - L * 0.035, hl.y - L * 0.018, L * 0.05, L * 0.034), Color("fff6c8"), int(L * 0.014), maxi(1, int(lw * 0.7)), OUTLINE)
	var tl := _tx(Vector2(0.012, nose + 0.01), o, L)
	UiThemeLite.rounded(ci, Rect2(tl.x - L * 0.006, tl.y - L * 0.016, L * 0.03, L * 0.03), Color("ff4f5e"), int(L * 0.01), maxi(1, int(lw * 0.7)), OUTLINE)

	# extras on top
	if vip and style in ["ute", "suv", "boxy"]:
		_light_bar(ci, o, L, lw, style)

	# wheels (arch shadow first)
	for wx in wheels:
		var wc := Vector2(o.x + float(wx) * L, o.y - wr)
		_arch(ci, wc, wr * 1.16, paint.darkened(0.7))
		_wheel(ci, wc, wr, lw, TALL.has(style), dirt, vip)

	# dirt: muddy blobs over the body and glass
	if dirt > 0.01:
		var bb := _bbox(body)
		for s: Vector3 in specks:
			var p := bb.position + Vector2(s.x, s.y) * bb.size
			if not Geometry2D.is_point_in_polygon(p, body):
				continue
			var r := L * 0.018 * s.z
			var mc := Color(0.40, 0.29, 0.17, 0.82 * dirt)
			ci.draw_circle(p, r, mc)
			ci.draw_circle(p + Vector2(r * 0.8, r * 0.3), r * 0.7, mc)
			ci.draw_circle(p + Vector2(-r * 0.5, r * 0.6), r * 0.55, mc)

	# sparkle when it comes up clean
	if shine > 0.0:
		var bb2 := _bbox(body)
		for sp: Vector2 in [Vector2(0.28, 0.15), Vector2(0.6, 0.05), Vector2(0.86, 0.45)]:
			_sparkle(ci, bb2.position + sp * bb2.size, L * 0.045, Color(1, 1, 1, shine))


## v0.19v: just the "comes up clean" sparkles (CarCache draws the car itself from a picture).
static func draw_shine(ci: CanvasItem, rect: Rect2, car: Dictionary, shine: float) -> void:
	var style := style_of(car)
	var L := rect.size.x * (0.9 if TALL.has(style) else 1.0)
	var o := Vector2(rect.position.x + (rect.size.x - L) * 0.5, rect.end.y)
	var bb2 := _bbox(_txa(_shape(style, "body"), o, L))
	for sp: Vector2 in [Vector2(0.28, 0.15), Vector2(0.6, 0.05), Vector2(0.86, 0.45)]:
		_sparkle(ci, bb2.position + sp * bb2.size, L * 0.045, Color(1, 1, 1, shine))


static func _nose_y(style: String) -> float:
	match style:
		"hyper":
			return 0.13
		"coupe", "gt":
			return 0.16
		"suv", "boxy", "ute":
			return 0.27
		_:
			return 0.19


static func _bbox(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r


static func _arch(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 17:
		var a := PI + PI * k / 16.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(pts, col)


static func _wheel(ci: CanvasItem, c: Vector2, r: float, lw: float, chunky: bool, dirt: float, vip: bool) -> void:
	ci.draw_circle(c, r + lw * 0.9, OUTLINE)
	ci.draw_circle(c, r, TIRE)
	if chunky:
		# off-road tread blocks
		for k in 14:
			var a := TAU * k / 14.0
			var p := c + Vector2(cos(a), sin(a)) * (r - r * 0.04)
			ci.draw_circle(p, r * 0.11, TIRE.lightened(0.08))
	ci.draw_arc(c, r * 0.82, 0, TAU, 28, Color(1, 1, 1, 0.08), maxf(1.0, r * 0.06), true)
	var rim_r := r * (0.58 if chunky else 0.66)
	ci.draw_circle(c, rim_r + lw * 0.5, OUTLINE)
	var rim := RIM.lerp(Color("8a7356"), 0.45 * dirt)
	if vip:
		rim = rim.lerp(Color("ffd54f"), 0.35)
	ci.draw_circle(c, rim_r, rim.darkened(0.25))
	ci.draw_circle(c + Vector2(-rim_r * 0.08, -rim_r * 0.08), rim_r * 0.86, rim)
	# brake calliper peeking through
	ci.draw_arc(c, rim_r * 0.62, -2.4, -1.4, 6, Color("e53935"), rim_r * 0.22)
	# spokes
	for k in 5:
		var a := TAU * k / 5.0 - PI / 2
		ci.draw_line(c + Vector2(cos(a), sin(a)) * rim_r * 0.22, c + Vector2(cos(a), sin(a)) * rim_r * 0.9, rim.darkened(0.35), rim_r * 0.2, true)
	ci.draw_circle(c, rim_r * 0.24, rim.darkened(0.15))
	ci.draw_circle(c, rim_r * 0.1, OUTLINE)
	# a little shine on the tyre
	ci.draw_arc(c, r * 0.93, -2.6, -1.9, 6, Color(1, 1, 1, 0.22), maxf(1.0, r * 0.08), true)


static func _wing(ci: CanvasItem, o: Vector2, L: float, lw: float, style: String, paint: Color) -> void:
	var h := 0.33 if style == "hyper" else (0.37 if style == "sedan" else 0.32)
	var base := _tx(Vector2(0.07, h - 0.07), o, L)
	var top := _tx(Vector2(0.04, h + 0.01), o, L)
	ci.draw_line(base, top, OUTLINE, L * 0.02)
	ci.draw_line(_tx(Vector2(0.11, h - 0.08), o, L), _tx(Vector2(0.09, h + 0.005), o, L), OUTLINE, L * 0.02)
	var plate := PackedVector2Array([_tx(Vector2(-0.03, h + 0.035), o, L), _tx(Vector2(0.16, h + 0.02), o, L),
		_tx(Vector2(0.16, h - 0.0), o, L), _tx(Vector2(-0.03, h + 0.005), o, L)])
	var pl := plate.duplicate()
	pl.append(plate[0])
	ci.draw_polyline(pl, OUTLINE, lw * 2.0, true)
	ci.draw_colored_polygon(plate, paint.darkened(0.25))


static func _light_bar(ci: CanvasItem, o: Vector2, L: float, lw: float, style: String) -> void:
	var roof := 0.53 if style == "boxy" else (0.50 if style == "suv" else 0.49)
	var x0 := 0.30 if style != "ute" else 0.46
	var a := _tx(Vector2(x0, roof + 0.045), o, L)
	var b := _tx(Vector2(x0 + 0.17, roof + 0.005), o, L)
	var r := Rect2(a, b - a)
	UiThemeLite.rounded(ci, r, Color("37474f"), int(L * 0.008), maxi(1, int(lw)), OUTLINE)
	for k in 4:
		ci.draw_circle(Vector2(r.position.x + r.size.x * (0.14 + 0.24 * k), r.get_center().y), r.size.y * 0.3, Color("fff59d"))


static func _sparkle(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.22, -r * 0.22), c + Vector2(r, 0), c + Vector2(r * 0.22, r * 0.22),
		c + Vector2(0, r), c + Vector2(-r * 0.22, r * 0.22), c + Vector2(-r, 0), c + Vector2(-r * 0.22, -r * 0.22)])
	ci.draw_colored_polygon(pts, col)


## Minimal rounded-rect helper (car_art is used from static contexts too).
class UiThemeLite:
	static func rounded(ci: CanvasItem, r: Rect2, c: Color, radius: int, border: int = 0, border_color: Color = Color.BLACK) -> void:
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			return
		ci.draw_style_box(load("res://scripts/ui_theme.gd").flat(c, maxi(0, radius), border, border_color), r)   # v0.19v: cached
