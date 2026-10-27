extends RefCounted
## v0.19v: small code-drawn icons used next to text (prices, shop buttons) and in the sky strip.
## Drawn here once and baked to PNGs by tools/bake_icons.gd (assets/game/ui/icon_*.png) so Buttons and
## RichTextLabels can show them as plain textures (a Button can't call a draw function).
##   sb        the Shine Bucks banknote (same drawing as the HUD pill: HudMeta.draw_droplet)
##   wheel     the Lucky Wheel with its pointer (shop button / sky strip still image)
##   wheel_face  the wheel without the pointer (spun in the sky strip)
##   booster   a booster gem with a lightning bolt
##   wardrobe  a crew tee on a hanger
## tex(name) loads the baked texture.

const UiTheme = preload("res://scripts/ui_theme.gd")
const HudMeta = preload("res://scripts/hud_meta.gd")
const INK := Color("1d1b2b")
const WHEEL_COLS := [Color("4fc3f7"), Color("ff6fa5"), Color("ffd23f"), Color("6fe36a"), Color("b07cff"), Color("ff8a3d")]

static var _tex := {}


static func tex(n: String) -> Texture2D:
	if not _tex.has(n):
		var p := "res://assets/game/ui/icon_%s.png" % n
		_tex[n] = load(p) if ResourceLoader.exists(p) else null
	return _tex[n]


## Draw one icon by name, centred at c, about s px tall.
static func draw(ci: CanvasItem, n: String, c: Vector2, s: float) -> void:
	match n:
		"sb":
			HudMeta.draw_droplet(ci, c, s * 0.36)
		"wheel":
			wheel(ci, c + Vector2(0, s * 0.05), s * 0.42, 0.0, true)
		"wheel_face":
			wheel(ci, c, s * 0.48, 0.0, false)
		"booster":
			booster(ci, c, s * 0.5)
		"wardrobe":
			wardrobe(ci, c, s)
		"ad":
			ad(ci, c, s)


## v0.19w: "watch an ad" (Idle Miner's little screen with a play button), on ad buttons.
static func ad(ci: CanvasItem, c: Vector2, s: float) -> void:
	var r := Rect2(c - Vector2(s * 0.5, s * 0.38), Vector2(s, s * 0.76))
	UiTheme.rounded(ci, r, Color.WHITE, int(s * 0.16), int(maxf(2.0, s * 0.07)), INK)
	var p := c + Vector2(s * 0.04, 0)
	var tri := PackedVector2Array([p + Vector2(-s * 0.16, -s * 0.22), p + Vector2(s * 0.22, 0), p + Vector2(-s * 0.16, s * 0.22)])
	ci.draw_colored_polygon(tri, Color("ff7a1a"))
	tri.append(tri[0])
	ci.draw_polyline(tri, INK, maxf(1.2, s * 0.05), true)


## The Lucky Wheel: 12 bright slices, a gold rim with bulbs, a hub with the banknote.
static func wheel(ci: CanvasItem, c: Vector2, r: float, rot: float, pointer: bool) -> void:
	var n := 12
	var step := TAU / n
	ci.draw_circle(c, r + maxf(2.0, r * 0.12), INK)
	ci.draw_circle(c, r + maxf(1.0, r * 0.08), Color("ffcf4a"))
	ci.draw_circle(c, r * 0.9 + 1.0, INK)
	for i in n:
		var a0 := -PI / 2.0 + rot + (i - 0.5) * step
		var pts := PackedVector2Array([c])
		for k in 7:
			var a := a0 + step * k / 6.0
			pts.append(c + Vector2(cos(a), sin(a)) * r * 0.9)
		var col: Color = WHEEL_COLS[i % WHEEL_COLS.size()]
		ci.draw_colored_polygon(pts, col if i % 2 == 0 else col.darkened(0.1))
	for i in n:
		var a := -PI / 2.0 + rot + (i - 0.5) * step
		ci.draw_line(c, c + Vector2(cos(a), sin(a)) * r * 0.9, INK, maxf(1.0, r * 0.03), true)
		ci.draw_circle(c + Vector2(cos(a), sin(a)) * (r * 0.96), maxf(1.2, r * 0.045), Color("fff6d6"))
	# gloss across the top half
	ci.draw_arc(c, r * 0.62, PI * 1.12, PI * 1.6, 10, Color(1, 1, 1, 0.35), r * 0.12, true)
	ci.draw_circle(c, r * 0.3, INK)
	ci.draw_circle(c, r * 0.26, Color("ffcf4a"))
	ci.draw_circle(c, r * 0.19, Color("ff9a2e"))
	ci.draw_circle(c + Vector2(-r * 0.06, -r * 0.06), r * 0.07, Color(1, 1, 1, 0.7))
	if pointer:
		var tip := c + Vector2(0, -r * 0.72)
		var top := c + Vector2(0, -r * 1.2)
		var w := r * 0.3
		var pp := PackedVector2Array([tip, top + Vector2(-w, 0), top + Vector2(w, 0)])
		ci.draw_colored_polygon(pp, Color("e8553d"))
		pp.append(pp[0])
		ci.draw_polyline(pp, INK, maxf(1.5, r * 0.06), true)
		ci.draw_circle(top, r * 0.14, INK)
		ci.draw_circle(top, r * 0.09, Color("fff6d6"))


## A booster: a purple octagon gem with a white lightning bolt.
static func booster(ci: CanvasItem, c: Vector2, r: float) -> void:
	var oct := func(rr: float, o: Vector2) -> PackedVector2Array:
		var p := PackedVector2Array()
		for i in 8:
			var t := PI / 8.0 + i * PI / 4.0
			p.append(c + o + Vector2(cos(t), sin(t)) * rr)
		return p
	ci.draw_colored_polygon(oct.call(r * 0.98, Vector2(0, r * 0.1)), INK)
	var rim: PackedVector2Array = oct.call(r * 0.98, Vector2.ZERO)
	ci.draw_colored_polygon(rim, Color("9b34c9"))
	var inner: PackedVector2Array = oct.call(r * 0.76, Vector2.ZERO)
	var shade := PackedColorArray()
	for v in inner:
		shade.append(Color("f0a0ff").lerp(Color("a63ad4"), clampf((v.y - (c.y - r * 0.76)) / (r * 1.52), 0.0, 1.0)))
	ci.draw_polygon(inner, shade)
	var out := rim.duplicate()
	out.append(rim[0])
	ci.draw_polyline(out, INK, maxf(1.5, r * 0.08), true)
	var s := r * 1.15
	var bolt := PackedVector2Array([c + Vector2(s * 0.08, -s * 0.5), c + Vector2(-s * 0.32, s * 0.08), c + Vector2(-s * 0.02, s * 0.08),
		c + Vector2(-s * 0.12, s * 0.5), c + Vector2(s * 0.32, -s * 0.1), c + Vector2(s * 0.02, -s * 0.1), c + Vector2(s * 0.16, -s * 0.5)])
	ci.draw_colored_polygon(bolt, Color.WHITE)
	bolt.append(bolt[0])
	ci.draw_polyline(bolt, INK, maxf(1.2, r * 0.06), true)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.42, -r * 0.55), c + Vector2(-r * 0.05, -r * 0.6), c + Vector2(-r * 0.3, -r * 0.3)]),
		Color(1, 1, 1, 0.5))


## The crew tee (orange with the white droplet logo) on a wooden hanger.
static func wardrobe(ci: CanvasItem, c: Vector2, s: float) -> void:
	var lw := maxf(1.5, s * 0.04)
	# hanger hook + bar
	ci.draw_arc(c + Vector2(0, -s * 0.38), s * 0.07, PI * 1.0, PI * 2.3, 10, INK, lw, true)
	ci.draw_polyline(PackedVector2Array([c + Vector2(0, -s * 0.3), c + Vector2(-s * 0.38, -s * 0.14), c + Vector2(s * 0.38, -s * 0.14), c + Vector2(0, -s * 0.3)]),
		Color("c98b4f"), lw * 1.4, true)
	# the tee
	var tee := PackedVector2Array([
		c + Vector2(-s * 0.14, -s * 0.2), c + Vector2(-s * 0.44, -s * 0.08), c + Vector2(-s * 0.36, s * 0.1),
		c + Vector2(-s * 0.24, s * 0.06), c + Vector2(-s * 0.24, s * 0.44), c + Vector2(s * 0.24, s * 0.44),
		c + Vector2(s * 0.24, s * 0.06), c + Vector2(s * 0.36, s * 0.1), c + Vector2(s * 0.44, -s * 0.08),
		c + Vector2(s * 0.14, -s * 0.2), c + Vector2(0, -s * 0.12)])
	ci.draw_colored_polygon(tee, Color("ff8a2e"))
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.08, -s * 0.16), c + Vector2(s * 0.24, s * 0.06), c + Vector2(s * 0.24, s * 0.44),
		c + Vector2(s * 0.1, s * 0.44)]), Color(0, 0, 0, 0.12))
	var o := tee.duplicate()
	o.append(tee[0])
	ci.draw_polyline(o, INK, lw, true)
	# the white droplet logo
	var d := c + Vector2(0, s * 0.12)
	ci.draw_circle(d + Vector2(0, s * 0.03), s * 0.07, Color.WHITE)
	ci.draw_colored_polygon(PackedVector2Array([d + Vector2(-s * 0.06, s * 0.0), d + Vector2(0, -s * 0.12), d + Vector2(s * 0.06, s * 0.0)]), Color.WHITE)
