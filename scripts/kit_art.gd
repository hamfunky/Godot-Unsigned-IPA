extends RefCounted
## v0.19v (Hamza: "more detailed, so they don't just look like little shapes"): the service kit on each bay's
## back wall, one piece per SERVICE (bay boost tier), drawn big and detailed here, baked to PNGs by
## tools/bake_kit.gd (assets/game/sprites/kit/kit_<tier>.png, mipmaps on) and drawn small in the bay.
## Art space: ART_H tall, WIDTHS[tier] wide, the shelf top is the bottom edge (y = ART_H). In the bay it's
## drawn at GAME_SCALE (so about 34 px tall, the wall above the shelf).
##   0 Quick Wash          bucket with suds + a chenille wash mitt on a hook
##   1 Foam Cannon         hose reel + foam cannon on a bracket
##   2 Full Detail         shop vac + a stack of folded microfibre towels
##   3 Clay Bar & Decon    pegboard with a clay bar, lube spray, iron remover
##   4 Paint Correction    dual-action polisher on a hook + foam pads on pegs
##   5 Interior Steam      steamer machine with its wand, steam rising
##   6 Ceramic Coating     open case of glowing coating bottles + applicator
##   7 Engine Bay Detail   spanner board + degreaser can
##   8 Graphene Coating    carbon-weave sample panel + the graphene bottle
##   9 Show Car Prep       trophy on a plinth + framed show photo with a rosette
##  10 PPF                 film rolls on a rack, squeegee, heat gun

const UiTheme = preload("res://scripts/ui_theme.gd")

const INK := Color("1d1b2b")
const ART_H := 136.0
const GAME_SCALE := 0.23
const WIDTHS := [204.0, 244.0, 244.0, 222.0, 244.0, 204.0, 214.0, 232.0, 222.0, 244.0, 244.0]
const NAMES := ["Quick Wash", "Foam Cannon", "Full Detail", "Clay Bar & Decon", "Paint Correction", "Interior Steam Clean",
	"Ceramic Coating", "Engine Bay Detail", "Graphene Coating", "Show Car Prep", "Paint Protection Film"]
const LW := 4.0   # outline width in art space (1 px in the bay)

static var _tex := {}


## The baked picture for a service tier (null if it hasn't been baked).
static func tex(tier: int) -> Texture2D:
	if not _tex.has(tier):
		var p := "res://assets/game/sprites/kit/kit_%d.png" % tier
		_tex[tier] = load(p) if ResourceLoader.exists(p) else null
	return _tex[tier]


## Width in the bay (px).
static func game_width(tier: int) -> float:
	return WIDTHS[clampi(tier, 0, WIDTHS.size() - 1)] * GAME_SCALE


## Draw tier's kit with its top-left at o, scaled by s (1 = art size).
static func draw(ci: CanvasItem, tier: int, o: Vector2, s: float) -> void:
	ci.draw_set_transform(o, 0.0, Vector2(s, s))
	match tier:
		0: _quick_wash(ci)
		1: _foam_cannon(ci)
		2: _full_detail(ci)
		3: _clay(ci)
		4: _polisher(ci)
		5: _steamer(ci)
		6: _ceramic(ci)
		7: _engine(ci)
		8: _graphene(ci)
		9: _show(ci)
		_: _ppf(ci)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- helpers

static func _box(ci: CanvasItem, r: Rect2, c: Color, rad := 8, w := LW) -> void:
	UiTheme.rounded(ci, r, c, rad, int(w), INK)


static func _shape(ci: CanvasItem, pts: PackedVector2Array, c: Color, w := LW) -> void:
	ci.draw_colored_polygon(pts, c)
	var o := pts.duplicate()
	o.append(pts[0])
	ci.draw_polyline(o, INK, w, true)


static func _disc(ci: CanvasItem, c: Vector2, r: float, col: Color, w := LW) -> void:
	ci.draw_circle(c, r + w * 0.5, INK)
	ci.draw_circle(c, r - w * 0.5, col)


## A soft white shine streak inside r (top-left), for gloss.
static func _shine(ci: CanvasItem, r: Rect2, a := 0.45) -> void:
	UiTheme.rounded(ci, Rect2(r.position + Vector2(r.size.x * 0.12, r.size.y * 0.1), Vector2(r.size.x * 0.16, r.size.y * 0.55)), Color(1, 1, 1, a), int(r.size.x * 0.08))


static func _hook(ci: CanvasItem, at: Vector2) -> void:
	_box(ci, Rect2(at + Vector2(-7, -4), Vector2(14, 10)), Color("90a4ae"), 3, 3)
	ci.draw_arc(at + Vector2(0, 12), 7.0, -PI * 0.1, PI * 1.05, 10, INK, 6.0, true)
	ci.draw_arc(at + Vector2(0, 12), 7.0, -PI * 0.1, PI * 1.05, 10, Color("cfd8dc"), 3.0, true)


static func _label(ci: CanvasItem, r: Rect2, c := Color.WHITE) -> void:
	_box(ci, r, c, 4, 3)


static func _spray_bottle(ci: CanvasItem, x: float, w: float, top: float, body: Color, head := Color("f5f5f5")) -> void:
	# trigger head + nozzle, neck, then the body down to the shelf
	var bt := top + 34.0
	_box(ci, Rect2(x + w * 0.25, bt - 8, w * 0.5, 12), Color("cfd8dc"), 3, 3)
	_shape(ci, PackedVector2Array([Vector2(x + w * 0.12, top + 6), Vector2(x + w * 0.88, top + 6), Vector2(x + w * 0.88, bt - 6),
		Vector2(x + w * 0.12, bt - 6)]), head)
	_box(ci, Rect2(x + w * 0.88 - 2, top + 8, 22, 10), head, 3, 3)                       # nozzle
	_shape(ci, PackedVector2Array([Vector2(x + w * 0.55, bt - 6), Vector2(x + w * 0.7, bt - 6), Vector2(x + w * 0.62, bt + 14),
		Vector2(x + w * 0.5, bt + 12)]), head.darkened(0.15), 3.0)                            # trigger
	var r := Rect2(x, bt, w, ART_H - bt - 2)
	_box(ci, r, body, 12)
	ci.draw_rect(Rect2(r.position.x + r.size.x * 0.62, r.position.y + 6, r.size.x * 0.28, r.size.y - 12), Color(0, 0, 0, 0.13))
	_shine(ci, r)


# ---------------------------------------------------------------- 0 Quick Wash

static func _quick_wash(ci: CanvasItem) -> void:
	# handle (behind)
	ci.draw_arc(Vector2(62, 46), 44.0, PI * 1.05, TAU - PI * 0.05, 24, INK, 8.0, true)
	ci.draw_arc(Vector2(62, 46), 44.0, PI * 1.05, TAU - PI * 0.05, 24, Color("b0bec5"), 4.0, true)
	# bucket
	var body := PackedVector2Array([Vector2(12, 46), Vector2(112, 46), Vector2(100, 134), Vector2(24, 134)])
	_shape(ci, body, Color("2f9bff"))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(82, 48), Vector2(110, 48), Vector2(99, 132), Vector2(76, 132)]), Color(0, 0, 0, 0.14))
	for y in [70.0, 118.0]:   # ribs
		var k: float = (y - 46.0) / 88.0
		ci.draw_line(Vector2(12 + 12 * k + 3, y), Vector2(112 - 12 * k - 3, y), Color("1d6fc4"), 4.0)
	_label(ci, Rect2(36, 78, 46, 32))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(59, 83), Vector2(66, 96), Vector2(52, 96)]), Color("2f9bff"))
	ci.draw_circle(Vector2(59, 98), 7.0, Color("2f9bff"))
	ci.draw_circle(Vector2(56, 96), 2.2, Color(1, 1, 1, 0.8))
	_box(ci, Rect2(6, 38, 112, 14), Color("62b4ff"), 6)    # rim
	ci.draw_rect(Rect2(14, 41, 60, 3), Color(1, 1, 1, 0.5))
	# suds piled up over the rim
	var sud := [[24, 32, 13], [42, 24, 16], [62, 20, 18], [82, 25, 15], [100, 32, 12], [52, 34, 12], [74, 34, 12]]
	for b in sud:
		ci.draw_circle(Vector2(b[0], b[1]), b[2] + 3.0, Color("9ccbe8"))
	for b in sud:
		ci.draw_circle(Vector2(b[0], b[1]), b[2], Color.WHITE)
		ci.draw_circle(Vector2(b[0] - b[2] * 0.35, b[1] - b[2] * 0.35), b[2] * 0.25, Color("e3f4ff"))
	# chenille wash mitt on a hook
	_hook(ci, Vector2(166, 6))
	# a blue microfibre chenille mitt: a mitten with its thumb out, covered in fat "noodles"
	_shape(ci, PackedVector2Array([Vector2(140, 66), Vector2(124, 70), Vector2(118, 86), Vector2(126, 100), Vector2(140, 98)]), Color("42a5f5"))  # thumb
	var mitt := Rect2(136, 30, 60, 94)
	_box(ci, mitt, Color("42a5f5"), 26)
	var jit := [0.0, 3.0, -2.0, 2.0, -3.0, 1.0, -1.0, 3.0]
	for row in 6:
		for col in 3:
			var p := mitt.position + Vector2(13 + col * 17 + (row % 2) * 7 + float(jit[(row * 3 + col) % 8]), 18 + row * 13)
			if p.x > mitt.end.x - 9 or p.y > mitt.end.y - 8:
				continue
			UiTheme.rounded(ci, Rect2(p - Vector2(6, 7), Vector2(12, 14)), Color("1e88e5"), 6)
			UiTheme.rounded(ci, Rect2(p - Vector2(5, 7), Vector2(9, 11)), Color("bbdefb"), 5)
	for p in [Vector2(126, 80), Vector2(130, 92)]:
		UiTheme.rounded(ci, Rect2(p - Vector2(5, 5), Vector2(10, 11)), Color("bbdefb"), 5)
	_box(ci, Rect2(138, 18, 56, 18), Color("546e7a"), 5)   # cuff
	for k in 5:
		ci.draw_line(Vector2(146 + k * 10, 22), Vector2(146 + k * 10, 32), Color("90a4ae"), 2.0)
	ci.draw_line(Vector2(166, 18), Vector2(166, 12), INK, 3.0)


# ---------------------------------------------------------------- 1 Foam Cannon

static func _foam_cannon(ci: CanvasItem) -> void:
	# hose reel: wall plate, red drum, green hose wound round it, crank
	_box(ci, Rect2(4, 18, 22, 104), Color("90a4ae"), 4)
	for y in [30.0, 108.0]:
		ci.draw_circle(Vector2(15, y), 4.0, INK)
	var c := Vector2(72, 70)
	_disc(ci, c, 58.0, Color("e8553d"))
	ci.draw_circle(c, 48.0, Color("b83b28"))
	for r in [44.0, 35.0, 26.0]:
		ci.draw_arc(c, r, 0, TAU, 40, INK, 11.0, true)
		ci.draw_arc(c, r, 0, TAU, 40, Color("3ccf5a"), 7.0, true)
		ci.draw_arc(c, r, PI * 1.1, PI * 1.5, 10, Color("8af08f"), 2.5, true)   # shine on each coil
	_disc(ci, c, 13.0, Color("cfd8dc"))
	ci.draw_circle(c, 4.0, INK)
	for k in 4:
		var a := k * PI / 2.0 + PI / 4.0
		ci.draw_circle(c + Vector2(cos(a), sin(a)) * 52.0, 3.0, Color("ffd6cc"))
	ci.draw_line(c, c + Vector2(40, -40), INK, 8.0)
	ci.draw_line(c, c + Vector2(40, -40), Color("cfd8dc"), 4.0)
	_disc(ci, c + Vector2(44, -44), 7.0, Color("2b2d42"))
	# the hose end trails off the drum, down to the shelf
	var hose := PackedVector2Array([Vector2(112, 104), Vector2(124, 118), Vector2(140, 126), Vector2(162, 128)])
	ci.draw_polyline(hose, INK, 11.0, true)
	ci.draw_polyline(hose, Color("3ccf5a"), 7.0, true)
	# foam cannon on a wall bracket
	_box(ci, Rect2(218, 8, 12, 60), Color("90a4ae"), 3)
	_box(ci, Rect2(200, 30, 30, 10), Color("90a4ae"), 3)
	var bottle := Rect2(156, 64, 56, 66)
	_box(ci, bottle, Color("cfeeff"), 14)
	UiTheme.rounded(ci, Rect2(bottle.position + Vector2(5, 26), bottle.size - Vector2(10, 31)), Color("ff6fa5"), 10)   # snow foam soap
	ci.draw_circle(Vector2(176, 104), 4.0, Color(1, 1, 1, 0.6))
	ci.draw_circle(Vector2(192, 116), 3.0, Color(1, 1, 1, 0.6))
	_shine(ci, bottle, 0.7)
	_box(ci, Rect2(150, 38, 68, 30), Color("ffb300"), 8)     # brass head
	ci.draw_rect(Rect2(156, 42, 56, 5), Color(1, 1, 1, 0.4))
	_disc(ci, Vector2(184, 30), 10.0, Color("2b2d42"))         # mix dial
	ci.draw_line(Vector2(184, 22), Vector2(184, 30), Color("ffb300"), 3.0)
	_shape(ci, PackedVector2Array([Vector2(150, 44), Vector2(126, 34), Vector2(126, 66), Vector2(150, 60)]), Color("2b2d42"))  # nozzle
	_box(ci, Rect2(216, 48, 22, 12), Color("cfd8dc"), 3, 3)  # quick connect
	for p in [Vector2(118, 40), Vector2(112, 52), Vector2(120, 62)]:   # a puff of foam out of the nozzle
		ci.draw_circle(p, 7.0, Color.WHITE)


# ---------------------------------------------------------------- 2 Full Detail

static func _full_detail(ci: CanvasItem) -> void:
	# shop vac: yellow drum, black lid with handle, hose looped over the top, castor wheels
	var hose := PackedVector2Array([Vector2(104, 74), Vector2(122, 60), Vector2(124, 30), Vector2(100, 12), Vector2(60, 10), Vector2(30, 22), Vector2(22, 40)])
	ci.draw_polyline(hose, INK, 15.0, true)
	ci.draw_polyline(hose, Color("607d8b"), 10.0, true)
	for k in range(1, hose.size() - 1):
		ci.draw_circle(hose[k], 3.0, Color("90a4ae"))
	_box(ci, Rect2(14, 56, 92, 68), Color("ffc93c"), 14)
	ci.draw_rect(Rect2(76, 62, 22, 56), Color(0, 0, 0, 0.12))
	ci.draw_rect(Rect2(18, 96, 84, 6), Color("e0a000"))
	_disc(ci, Vector2(44, 80), 9.0, Color("e53935"))
	ci.draw_circle(Vector2(41, 77), 2.5, Color(1, 1, 1, 0.7))
	_box(ci, Rect2(8, 44, 104, 18), Color("37474f"), 7)
	_box(ci, Rect2(44, 30, 32, 16), Color("37474f"), 6)
	_box(ci, Rect2(14, 34, 16, 14), Color("546e7a"), 4)   # hose cuff on the lid
	for x in [26.0, 94.0]:
		_disc(ci, Vector2(x, 128), 7.0, Color("2b2d42"))
	# folded microfibre towels
	var cols := [Color("4fc3f7"), Color("ff6fa5"), Color("ffd23f"), Color("b07cff"), Color("90a4ae")]
	for k in 5:
		var y := 112.0 - k * 19.0
		var x := 140.0 + (k % 2) * 6.0
		var r := Rect2(x, y, 96, 22)
		_box(ci, r, cols[k], 8)
		ci.draw_rect(Rect2(x + 4, y + 4, 22, 14), cols[k].lightened(0.25))       # the fold
		ci.draw_line(Vector2(x + 28, y + 4), Vector2(x + 28, y + 18), cols[k].darkened(0.25), 2.0)
		for d in 6:                                                             # plush edge
			ci.draw_circle(Vector2(x + 38 + d * 9.5, y + 18), 2.0, cols[k].darkened(0.15))
	_box(ci, Rect2(144, 14, 32, 10), Color.WHITE, 3, 3)   # the label tag on top


# ---------------------------------------------------------------- 3 Clay Bar & Decon

static func _clay(ci: CanvasItem) -> void:
	# pegboard
	var pb := Rect2(2, 6, 142, 110)
	_box(ci, pb, Color("d7b98e"), 8)
	for yy in 6:
		for xx in 8:
			ci.draw_circle(pb.position + Vector2(12 + xx * 17, 12 + yy * 17), 2.2, Color("8a6a4a"))
	# the clay bar in a little tray, + a spare one on a peg
	_box(ci, Rect2(14, 58, 66, 16), Color.WHITE, 4, 3)
	_box(ci, Rect2(20, 32, 54, 30), Color("4f7cff"), 12)
	ci.draw_circle(Vector2(47, 46), 9.0, Color("6f95ff"))                # thumb print
	ci.draw_arc(Vector2(47, 46), 9.0, PI * 0.2, PI * 0.9, 8, Color("3a5fd6"), 2.0, true)
	_box(ci, Rect2(92, 22, 40, 26), Color("ffd23f"), 10)
	ci.draw_line(Vector2(112, 22), Vector2(112, 12), INK, 4.0)
	ci.draw_circle(Vector2(112, 12), 3.0, Color("8a6a4a"))
	# clay lube (green) on the shelf, iron remover (purple, "bleeding") beside it
	_spray_bottle(ci, 92, 34, 58, Color("3ccf5a"))
	_label(ci, Rect2(98, 106, 22, 18))
	_spray_bottle(ci, 156, 52, 22, Color("8e44ad"))
	_label(ci, Rect2(164, 86, 36, 30))
	for k in 3:   # purple "bleed" drops on the label
		var p := Vector2(172 + k * 10, 96 + (k % 2) * 6)
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -6), p + Vector2(4, 1), p + Vector2(-4, 1)]), Color("b056d8"))
		ci.draw_circle(p + Vector2(0, 2), 4.0, Color("b056d8"))


# ---------------------------------------------------------------- 4 Paint Correction

static func _polisher(ci: CanvasItem) -> void:
	_hook(ci, Vector2(96, 4))
	# cord coiled under the hook
	for k in 3:
		ci.draw_arc(Vector2(150, 92), 14.0 + k * 6.0, PI * 0.1, PI * 1.6, 16, Color("2b2d42"), 4.0, true)
	ci.draw_line(Vector2(128, 58), Vector2(146, 84), Color("2b2d42"), 4.0)
	# dual-action polisher: motor body, rear handle, side grip, backing plate + orange pad underneath
	_box(ci, Rect2(20, 32, 112, 40), Color("37474f"), 16)
	_box(ci, Rect2(64, 36, 40, 32), Color("ff8a3d"), 8)
	for k in 4:
		ci.draw_line(Vector2(70 + k * 8, 40), Vector2(70 + k * 8, 64), Color("e0620f"), 2.5)   # vents
	ci.draw_rect(Rect2(28, 38, 30, 4), Color(1, 1, 1, 0.3))
	_box(ci, Rect2(120, 24, 26, 46), Color("263238"), 10)                  # rear handle
	_box(ci, Rect2(40, 12, 14, 26), Color("263238"), 6)                    # side grip
	ci.draw_line(Vector2(96, 18), Vector2(96, 34), INK, 4.0)               # hangs from the hook
	_box(ci, Rect2(12, 70, 58, 10), Color("90a4ae"), 4)                    # backing plate
	_box(ci, Rect2(6, 78, 70, 20), Color("ff8a3d"), 8)                     # pad
	ci.draw_rect(Rect2(10, 82, 62, 4), Color("ffb27a"))
	# spare pads on pegs: cutting (orange), polishing (white), finishing (black)
	var pads := [[Vector2(186, 28), Color("ff8a3d")], [Vector2(218, 70), Color("f5f5f5")], [Vector2(186, 108), Color("2b2d42")]]
	for p in pads:
		var c: Vector2 = p[0]
		_disc(ci, c, 22.0, p[1])
		ci.draw_circle(c, 13.0, Color(p[1]).darkened(0.12))
		ci.draw_circle(c, 5.0, Color("90a4ae"))
		ci.draw_circle(c, 2.0, INK)
		ci.draw_arc(c, 17.0, PI * 1.1, PI * 1.5, 8, Color(1, 1, 1, 0.5), 2.5, true)


# ---------------------------------------------------------------- 5 Interior Steam Clean

static func _steamer(ci: CanvasItem) -> void:
	# steam rising
	for p in [[Vector2(48, 30), 12.0], [Vector2(62, 16), 10.0], [Vector2(40, 10), 8.0], [Vector2(74, 30), 9.0]]:
		ci.draw_circle(p[0], p[1] + 2.0, Color(0.85, 0.9, 0.97, 0.6))
		ci.draw_circle(p[0], p[1], Color(1, 1, 1, 0.85))
	# the machine
	_box(ci, Rect2(40, 34, 40, 14), Color("cfd8dc"), 5)                     # carry handle
	var body := Rect2(14, 46, 112, 80)
	_box(ci, body, Color("eef4ff"), 16)
	_box(ci, Rect2(24, 56, 56, 40), Color("2f9bff"), 8)                     # front panel
	_disc(ci, Vector2(44, 76), 12.0, Color.WHITE)                            # gauge
	ci.draw_line(Vector2(44, 76), Vector2(51, 69), Color("e53935"), 3.0)
	_disc(ci, Vector2(68, 70), 6.0, Color("e53935"))                         # knob
	_disc(ci, Vector2(68, 88), 4.0, Color("3ccf5a"))                         # power light
	ci.draw_rect(Rect2(90, 56, 26, 50), Color(0, 0, 0, 0.06))
	_shine(ci, body, 0.6)
	for x in [30.0, 110.0]:
		_disc(ci, Vector2(x, 128), 6.0, Color("2b2d42"))
	# hose up to the wand on two wall clips
	var hose := PackedVector2Array([Vector2(122, 70), Vector2(140, 76), Vector2(150, 98), Vector2(164, 112), Vector2(176, 104)])
	ci.draw_polyline(hose, INK, 10.0, true)
	ci.draw_polyline(hose, Color("90a4ae"), 6.0, true)
	_box(ci, Rect2(170, 14, 14, 96), Color("b0bec5"), 6)                     # wand
	_box(ci, Rect2(164, 6, 26, 16), Color("37474f"), 5)                      # brush head
	for k in 4:
		ci.draw_line(Vector2(168 + k * 6, 6), Vector2(168 + k * 6, 0), Color("ffd23f"), 3.0)
	for y in [40.0, 84.0]:
		_box(ci, Rect2(184, y, 12, 10), Color("90a4ae"), 3, 3)


# ---------------------------------------------------------------- 6 Ceramic Coating

static func _ceramic(ci: CanvasItem) -> void:
	# open presentation case: lid behind, satin lining, three glowing coating bottles, applicator + cloth
	_box(ci, Rect2(14, 10, 160, 70), Color("2b2d42"), 10)
	_box(ci, Rect2(22, 18, 144, 56), Color("4a3a7a"), 8, 3)
	for k in 4:
		ci.draw_line(Vector2(30 + k * 36, 22), Vector2(46 + k * 36, 70), Color(1, 1, 1, 0.08), 6.0)   # satin sheen
	ci.draw_circle(Vector2(94, 70), 52.0, Color(0.4, 1.0, 0.9, 0.12))   # the glow
	ci.draw_circle(Vector2(94, 74), 34.0, Color(0.4, 1.0, 0.9, 0.16))
	for k in 3:
		var x := 56.0 + k * 30.0
		_box(ci, Rect2(x + 4, 40, 16, 14), Color("1d1b2b"), 3, 3)          # caps
		var b := Rect2(x, 52, 24, 52)
		_box(ci, b, Color("6cf0d6"), 8)
		UiTheme.rounded(ci, Rect2(b.position + Vector2(4, 22), Vector2(16, 26)), Color("1fb89a"), 5)   # the liquid
		_shine(ci, b, 0.75)
	_box(ci, Rect2(6, 86, 176, 46), Color("1d1b2b"), 10)                   # case front
	ci.draw_rect(Rect2(12, 92, 164, 4), Color(1, 1, 1, 0.15))
	_box(ci, Rect2(84, 100, 22, 12), Color("ffcf4a"), 3, 3)                # gold clasp
	_box(ci, Rect2(184, 92, 18, 40), Color("90a4ae"), 6)                    # applicator block
	_box(ci, Rect2(176, 112, 26, 20), Color("e0e0e0"), 4, 3)                # suede cloth
	UiTheme.sparkle(ci, Vector2(46, 34), 9.0, Color.WHITE)
	UiTheme.sparkle(ci, Vector2(148, 46), 7.0, Color.WHITE)


# ---------------------------------------------------------------- 7 Engine Bay Detail

static func _engine(ci: CanvasItem) -> void:
	# tool board with spanners hung smallest to biggest + a screwdriver
	var tb := Rect2(2, 8, 156, 114)
	_box(ci, tb, Color("455a64"), 8)
	ci.draw_rect(Rect2(tb.position.x + 8, tb.position.y + 8, tb.size.x - 16, 3), Color(1, 1, 1, 0.12))
	for k in 4:
		var x := 20.0 + k * 28.0
		var top := 20.0
		var length := 56.0 + k * 10.0
		_box(ci, Rect2(x - 5, top + 12, 10, length - 22), Color("cfd8dc"), 4, 3)        # handle
		_disc(ci, Vector2(x, top + 10), 10.0 + k, Color("cfd8dc"), 3.0)                   # open jaw
		ci.draw_rect(Rect2(x - 4, top - 2, 8, 12), Color("455a64"))
		_disc(ci, Vector2(x, top + length - 8), 9.0 + k, Color("cfd8dc"), 3.0)           # ring end
		ci.draw_circle(Vector2(x, top + length - 8), 4.0 + k * 0.5, Color("455a64"))
		ci.draw_line(Vector2(x - 2, top + 16), Vector2(x - 2, top + length - 20), Color(1, 1, 1, 0.6), 2.0)
	_box(ci, Rect2(132, 22, 14, 34), Color("e53935"), 5)                   # screwdriver handle
	_box(ci, Rect2(136, 56, 6, 44), Color("cfd8dc"), 2, 3)
	# degreaser can on the shelf
	var can := Rect2(168, 40, 50, 94)
	_box(ci, Rect2(178, 22, 30, 22), Color("cfd8dc"), 6)                    # cap
	_box(ci, Rect2(188, 14, 10, 12), Color("2b2d42"), 3, 3)                 # spray button
	_box(ci, can, Color("e53935"), 12)
	_label(ci, Rect2(174, 66, 38, 40))
	_shape(ci, PackedVector2Array([Vector2(184, 74), Vector2(202, 74), Vector2(196, 86), Vector2(204, 86), Vector2(186, 100), Vector2(190, 88), Vector2(182, 88)]),
		Color("ffb300"), 2.0)   # lightning-quick degreaser badge
	_shine(ci, can)


# ---------------------------------------------------------------- 8 Graphene Coating

static func _graphene(ci: CanvasItem) -> void:
	# carbon weave sample panel on a little easel
	var p := Rect2(8, 14, 126, 100)
	_box(ci, p, Color("1d1f27"), 10)
	for yy in 9:
		for xx in 11:
			if (xx + yy) % 2 == 0:
				ci.draw_rect(Rect2(p.position.x + 6 + xx * 10.5, p.position.y + 6 + yy * 10, 9.5, 4.5), Color("3b3f4c"))
			else:
				ci.draw_rect(Rect2(p.position.x + 8 + xx * 10.5, p.position.y + 6 + yy * 10, 4.5, 9), Color("2c2f3a"))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(24, 18), Vector2(60, 18), Vector2(28, 110), Vector2(12, 110)]), Color(1, 1, 1, 0.12))   # gloss
	_shape(ci, PackedVector2Array([Vector2(30, 114), Vector2(40, 114), Vector2(32, 134), Vector2(20, 134)]), Color("8a6a4a"), 3.0)
	_shape(ci, PackedVector2Array([Vector2(102, 114), Vector2(112, 114), Vector2(124, 134), Vector2(112, 134)]), Color("8a6a4a"), 3.0)
	# the hex badge on the panel
	var hc := Vector2(98, 44)
	var hex := PackedVector2Array()
	for k in 6:
		var a := PI / 6.0 + k * PI / 3.0
		hex.append(hc + Vector2(cos(a), sin(a)) * 16.0)
	_shape(ci, hex, Color("90a4ae"), 3.0)
	# the bottle: black, silver cap, a hexagon label
	_box(ci, Rect2(166, 10, 32, 26), Color("cfd8dc"), 6)
	ci.draw_rect(Rect2(172, 14, 4, 18), Color(1, 1, 1, 0.6))
	var b := Rect2(154, 34, 56, 100)
	_box(ci, b, Color("1d1f27"), 14)
	var lc := Vector2(182, 84)
	var lab := PackedVector2Array()
	for k in 6:
		var a := PI / 6.0 + k * PI / 3.0
		lab.append(lc + Vector2(cos(a), sin(a)) * 18.0)
	_shape(ci, lab, Color("b0bec5"), 3.0)
	ci.draw_circle(lc, 6.0, Color("1d1f27"))
	_shine(ci, b, 0.35)
	UiTheme.sparkle(ci, Vector2(206, 44), 8.0, Color.WHITE)


# ---------------------------------------------------------------- 9 Show Car Prep

static func _show(ci: CanvasItem) -> void:
	# trophy on a two-step plinth
	_box(ci, Rect2(8, 112, 92, 22), Color("8a5a3b"), 4)
	_box(ci, Rect2(20, 96, 68, 20), Color("a06a46"), 4)
	_box(ci, Rect2(40, 82, 28, 18), Color("ffb300"), 3)
	_shape(ci, PackedVector2Array([Vector2(48, 68), Vector2(60, 68), Vector2(62, 84), Vector2(46, 84)]), Color("ffb300"))
	ci.draw_arc(Vector2(20, 34), 14.0, PI * 0.5, PI * 1.5, 12, INK, 8.0, true)    # handles
	ci.draw_arc(Vector2(20, 34), 14.0, PI * 0.5, PI * 1.5, 12, Color("ffcf4a"), 4.0, true)
	ci.draw_arc(Vector2(88, 34), 14.0, -PI * 0.5, PI * 0.5, 12, INK, 8.0, true)
	ci.draw_arc(Vector2(88, 34), 14.0, -PI * 0.5, PI * 0.5, 12, Color("ffcf4a"), 4.0, true)
	var cup := PackedVector2Array([Vector2(18, 14), Vector2(90, 14), Vector2(84, 46), Vector2(70, 64), Vector2(38, 64), Vector2(24, 46)])
	_shape(ci, cup, Color("ffcf4a"))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(28, 18), Vector2(40, 18), Vector2(42, 52), Vector2(34, 46)]), Color(1, 1, 1, 0.45))
	_shape(ci, PackedVector2Array([Vector2(54, 24), Vector2(58, 34), Vector2(68, 34), Vector2(60, 40), Vector2(63, 50), Vector2(54, 44), Vector2(45, 50), Vector2(48, 40), Vector2(40, 34), Vector2(50, 34)]),
		Color("ffe680"), 2.0)
	# framed show photo: a red car on the podium under spotlights, a rosette pinned to the corner
	var fr := Rect2(112, 10, 124, 92)
	_box(ci, fr, Color("8a5a3b"), 6)
	_box(ci, fr.grow(-10), Color("f5ecd7"), 3, 3)
	var pic := fr.grow(-18)
	UiTheme.rounded(ci, pic, Color("2a3a6a"), 3)
	ci.draw_colored_polygon(PackedVector2Array([pic.position + Vector2(18, 0), pic.position + Vector2(34, 0), pic.position + Vector2(56, pic.size.y), pic.position + Vector2(10, pic.size.y)]), Color(1, 1, 0.8, 0.18))
	ci.draw_rect(Rect2(pic.position.x, pic.end.y - 12, pic.size.x, 12), Color("6b7a99"))
	var car := PackedVector2Array([Vector2(138, 72), Vector2(146, 60), Vector2(168, 56), Vector2(186, 60), Vector2(206, 64), Vector2(208, 72)])
	_shape(ci, car, Color("e53935"), 3.0)
	for x in [150.0, 196.0]:
		ci.draw_circle(Vector2(x, 72), 6.0, INK)
		ci.draw_circle(Vector2(x, 72), 3.0, Color("cfd8dc"))
	UiTheme.sparkle(ci, Vector2(200, 40), 6.0, Color.WHITE)
	# rosette
	_shape(ci, PackedVector2Array([Vector2(214, 108), Vector2(222, 108), Vector2(220, 132), Vector2(212, 126)]), Color("2f9bff"), 3.0)
	_shape(ci, PackedVector2Array([Vector2(226, 108), Vector2(234, 108), Vector2(238, 126), Vector2(230, 132)]), Color("2f9bff"), 3.0)
	for k in 10:
		var a := k * TAU / 10.0
		ci.draw_circle(Vector2(224, 100) + Vector2(cos(a), sin(a)) * 14.0, 6.0, Color("2f9bff"))
	_disc(ci, Vector2(224, 100), 11.0, Color("ffd23f"), 3.0)


# ---------------------------------------------------------------- 10 Paint Protection Film

static func _ppf(ci: CanvasItem) -> void:
	# rack with two film rolls lying on it, a third standing on the shelf
	_box(ci, Rect2(4, 20, 150, 8), Color("90a4ae"), 3, 3)
	_box(ci, Rect2(4, 70, 150, 8), Color("90a4ae"), 3, 3)
	for x in [10.0, 140.0]:
		_box(ci, Rect2(x, 8, 10, 76), Color("78909c"), 3, 3)
	for y in [30.0, 80.0]:
		var r := Rect2(20, y - 2, 110, 28)
		_box(ci, r, Color("dff3ff"), 12)
		ci.draw_rect(Rect2(r.position.x + 10, r.position.y + 6, r.size.x - 20, 5), Color(1, 1, 1, 0.8))
		ci.draw_line(Vector2(r.position.x + 18, r.end.y - 6), Vector2(r.end.x - 18, r.end.y - 6), Color("9ccbe8"), 2.0)
		_disc(ci, Vector2(r.end.x - 4, y + 12), 12.0, Color("bfe3f7"), 3.0)                 # roll end
		ci.draw_circle(Vector2(r.end.x - 4, y + 12), 5.0, Color("8a6a4a"))                 # cardboard core
	var stand := Rect2(14, 110, 64, 24)
	_box(ci, stand, Color("dff3ff"), 10)
	_disc(ci, Vector2(46, 110), 10.0, Color("bfe3f7"), 3.0)
	ci.draw_circle(Vector2(46, 110), 4.0, Color("8a6a4a"))
	# squeegee hanging on a hook
	_hook(ci, Vector2(178, 6))
	_box(ci, Rect2(164, 24, 30, 36), Color("2b2d42"), 6)
	_box(ci, Rect2(158, 58, 42, 12), Color("ff8a3d"), 4)
	ci.draw_rect(Rect2(160, 66, 38, 3), Color("ffd6b0"))
	# a strip of film peeling off the top roll
	ci.draw_colored_polygon(PackedVector2Array([Vector2(36, 54), Vector2(64, 54), Vector2(70, 70), Vector2(42, 72)]), Color(0.85, 0.95, 1.0, 0.7))
	# heat gun lying on the shelf
	_box(ci, Rect2(196, 112, 18, 22), Color("37474f"), 5)                  # grip
	_box(ci, Rect2(160, 92, 82, 26), Color("e53935"), 12)                  # body
	_box(ci, Rect2(140, 96, 24, 18), Color("546e7a"), 4)                   # nozzle
	for k in 3:
		ci.draw_line(Vector2(212 + k * 9, 96), Vector2(212 + k * 9, 114), Color("b71c1c"), 3.0)   # vents
	ci.draw_rect(Rect2(168, 96, 40, 4), Color(1, 1, 1, 0.35))
