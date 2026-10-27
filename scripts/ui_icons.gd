extends RefCounted
## v0.17f: small code-drawn icons (bottom bar). White shapes with a dark ink outline and one
## accent colour, so they read on any of the bright button colours. c = centre, s = size (px).

const INK := Color("1d1b2b")


static func draw(ci: CanvasItem, kind: String, c: Vector2, s: float) -> void:
	match kind:
		"shop":
			_shop(ci, c, s)
		"book":
			_book(ci, c, s)
		"boost":
			_boost(ci, c, s)
		"info":
			_info(ci, c, s)
		"map":
			_map(ci, c, s)


static func _rr(ci: CanvasItem, r: Rect2, col: Color, radius: float, border: int = 0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	if border > 0:
		sb.set_border_width_all(border)
		sb.border_color = INK
	ci.draw_style_box(sb, r)


static func _poly(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float = 2.5) -> void:
	ci.draw_colored_polygon(pts, col)
	var o := pts.duplicate()
	o.append(pts[0])
	ci.draw_polyline(o, INK, w, true)


## Shopping bag with a little gold coin on it.
static func _shop(ci: CanvasItem, c: Vector2, s: float) -> void:
	ci.draw_arc(c + Vector2(0, -s * 0.2), s * 0.2, PI, TAU, 16, INK, s * 0.14, true)
	ci.draw_arc(c + Vector2(0, -s * 0.2), s * 0.2, PI, TAU, 16, Color.WHITE, s * 0.06, true)
	_rr(ci, Rect2(c + Vector2(-s * 0.4, -s * 0.22), Vector2(s * 0.8, s * 0.68)), Color.WHITE, s * 0.12, 3)
	ci.draw_circle(c + Vector2(0, s * 0.12), s * 0.17, INK)
	ci.draw_circle(c + Vector2(0, s * 0.12), s * 0.13, Color("ffc93c"))
	ci.draw_circle(c + Vector2(-s * 0.04, s * 0.08), s * 0.04, Color(1, 1, 1, 0.8))


## Open book with a red bookmark.
static func _book(ci: CanvasItem, c: Vector2, s: float) -> void:
	var l := PackedVector2Array([c + Vector2(0, -s * 0.24), c + Vector2(-s * 0.48, -s * 0.34), c + Vector2(-s * 0.48, s * 0.3), c + Vector2(0, s * 0.4)])
	var r := PackedVector2Array([c + Vector2(0, -s * 0.24), c + Vector2(s * 0.48, -s * 0.34), c + Vector2(s * 0.48, s * 0.3), c + Vector2(0, s * 0.4)])
	_poly(ci, l, Color.WHITE)
	_poly(ci, r, Color("f1ecff"))
	for k in 3:
		var y := -s * 0.14 + k * s * 0.15
		ci.draw_line(c + Vector2(-s * 0.38, y - s * 0.03), c + Vector2(-s * 0.1, y + s * 0.02), Color(0.1, 0.1, 0.2, 0.35), 2.0)
		ci.draw_line(c + Vector2(s * 0.1, y + s * 0.02), c + Vector2(s * 0.38, y - s * 0.03), Color(0.1, 0.1, 0.2, 0.35), 2.0)
	_poly(ci, PackedVector2Array([c + Vector2(s * 0.22, -s * 0.3), c + Vector2(s * 0.34, -s * 0.32), c + Vector2(s * 0.34, s * 0.02),
		c + Vector2(s * 0.28, -s * 0.04), c + Vector2(s * 0.22, s * 0.02)]), Color("ff5a5f"), 2.0)


## Lightning bolt.
static func _boost(ci: CanvasItem, c: Vector2, s: float) -> void:
	_poly(ci, PackedVector2Array([c + Vector2(s * 0.08, -s * 0.5), c + Vector2(-s * 0.32, s * 0.08), c + Vector2(-s * 0.02, s * 0.08),
		c + Vector2(-s * 0.12, s * 0.5), c + Vector2(s * 0.32, -s * 0.1), c + Vector2(s * 0.02, -s * 0.1), c + Vector2(s * 0.16, -s * 0.5)]),
		Color.WHITE, 3.0)
	ci.draw_line(c + Vector2(s * 0.02, -s * 0.38), c + Vector2(-s * 0.14, -s * 0.06), Color("ffc93c"), 3.0)


## Clipboard with a tick list.
static func _info(ci: CanvasItem, c: Vector2, s: float) -> void:
	_rr(ci, Rect2(c + Vector2(-s * 0.36, -s * 0.42), Vector2(s * 0.72, s * 0.9)), Color("c98a4b"), s * 0.1, 3)
	_rr(ci, Rect2(c + Vector2(-s * 0.27, -s * 0.3), Vector2(s * 0.54, s * 0.7)), Color.WHITE, s * 0.05, 2)
	_rr(ci, Rect2(c + Vector2(-s * 0.16, -s * 0.5), Vector2(s * 0.32, s * 0.16)), Color("b0bccf"), s * 0.05, 2)
	for k in 3:
		var y := -s * 0.14 + k * s * 0.18
		ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.2, y), c + Vector2(-s * 0.14, y + s * 0.06), c + Vector2(-s * 0.05, y - s * 0.05)]),
			Color("2fb457"), 2.5, true)
		ci.draw_line(c + Vector2(0, y), c + Vector2(s * 0.18, y), Color(0.1, 0.1, 0.2, 0.4), 2.5)


## Little globe with green land.
static func _map(ci: CanvasItem, c: Vector2, s: float) -> void:
	var r := s * 0.44
	ci.draw_circle(c, r + 2.5, INK)
	ci.draw_circle(c, r, Color("5ec8ff"))
	_poly(ci, PackedVector2Array([c + Vector2(-r * 0.7, -r * 0.5), c + Vector2(-r * 0.1, -r * 0.75), c + Vector2(r * 0.1, -r * 0.3),
		c + Vector2(-r * 0.25, 0), c + Vector2(-r * 0.15, r * 0.4), c + Vector2(-r * 0.55, r * 0.35), c + Vector2(-r * 0.8, -r * 0.05)]), Color("5ad16a"), 2.0)
	_poly(ci, PackedVector2Array([c + Vector2(r * 0.35, -r * 0.1), c + Vector2(r * 0.8, r * 0.05), c + Vector2(r * 0.65, r * 0.55),
		c + Vector2(r * 0.25, r * 0.7), c + Vector2(r * 0.15, r * 0.3)]), Color("5ad16a"), 2.0)
	ci.draw_arc(c + Vector2(-r * 0.3, -r * 0.35), r * 0.35, PI * 1.05, PI * 1.45, 6, Color(1, 1, 1, 0.7), 3.0, true)
