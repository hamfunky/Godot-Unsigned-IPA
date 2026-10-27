extends RefCounted
## Code-drawn icons for equipment and crafting materials (placeholder art).

const ToolArt = preload("res://scripts/manager_art.gd")
const Data = preload("res://scripts/game_data.gd")


static func _rr(ci: CanvasItem, r: Rect2, c: Color) -> void:
	ToolArt._rounded(ci, r, c)


## Item icon about `s` pixels big, centred on c.
static func draw_item(ci: CanvasItem, c: Vector2, s: float, id: String, dim := false) -> void:
	var k := 0.35 if dim else 1.0
	var w := Color(1, 1, 1, k)
	var dark := Color(0.15, 0.17, 0.2, k)
	match id:
		"stopwatch":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.06, -s * 0.48), Vector2(s * 0.12, s * 0.12)), Color(0.75, 0.75, 0.8, k))
			ci.draw_circle(c + Vector2(0, s * 0.05), s * 0.38, Color(0.75, 0.78, 0.82, k))
			ci.draw_circle(c + Vector2(0, s * 0.05), s * 0.31, w)
			ci.draw_line(c + Vector2(0, s * 0.05), c + Vector2(s * 0.14, -s * 0.12), dark, maxf(2.0, s * 0.05))
			ci.draw_line(c + Vector2(0, s * 0.05), c + Vector2(0, -s * 0.18), Color(0.9, 0.2, 0.2, k), maxf(2.0, s * 0.04))
		"fridge":
			_rr(ci, Rect2(c - Vector2(s * 0.28, s * 0.45), Vector2(s * 0.56, s * 0.9)), Color(0.85, 0.15, 0.2, k))
			ci.draw_rect(Rect2(c - Vector2(s * 0.2, s * 0.35), Vector2(s * 0.4, s * 0.55)), Color(0.7, 0.9, 1.0, k))
			for x in 3:
				ci.draw_rect(Rect2(c + Vector2(-s * 0.16 + x * s * 0.12, -s * 0.12), Vector2(s * 0.08, s * 0.18)), Color(0.2, 0.8, 0.3, k))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.2, s * 0.26), Vector2(s * 0.4, s * 0.06)), dark)
		"air_freshener":
			ci.draw_line(c + Vector2(0, -s * 0.5), c + Vector2(0, -s * 0.32), dark, maxf(2.0, s * 0.03))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.34), c + Vector2(-s * 0.22, -s * 0.02), c + Vector2(s * 0.22, -s * 0.02)]), Color(0.2, 0.7, 0.3, k))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.14), c + Vector2(-s * 0.3, s * 0.24), c + Vector2(s * 0.3, s * 0.24)]), Color(0.2, 0.7, 0.3, k))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, s * 0.06), c + Vector2(-s * 0.36, s * 0.44), c + Vector2(s * 0.36, s * 0.44)]), Color(0.15, 0.6, 0.25, k))
		"gloves":
			_rr(ci, Rect2(c + Vector2(-s * 0.26, -s * 0.05), Vector2(s * 0.5, s * 0.45)), Color(0.25, 0.6, 0.95, k))
			for x in 4:
				_rr(ci, Rect2(c + Vector2(-s * 0.25 + x * s * 0.125, -s * 0.38), Vector2(s * 0.1, s * 0.4)), Color(0.25, 0.6, 0.95, k))
			_rr(ci, Rect2(c + Vector2(s * 0.18, -s * 0.05), Vector2(s * 0.2, s * 0.12)), Color(0.25, 0.6, 0.95, k))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.26, s * 0.32), Vector2(s * 0.5, s * 0.08)), Color(0.1, 0.3, 0.6, k))
		"apron":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.18, -s * 0.38), c + Vector2(s * 0.18, -s * 0.38), c + Vector2(s * 0.18, -s * 0.12),
				c + Vector2(s * 0.34, -s * 0.05), c + Vector2(s * 0.3, s * 0.46), c + Vector2(-s * 0.3, s * 0.46), c + Vector2(-s * 0.34, -s * 0.05),
				c + Vector2(-s * 0.18, -s * 0.12)]), Color(0.2, 0.25, 0.3, k))
			_rr(ci, Rect2(c + Vector2(-s * 0.16, s * 0.08), Vector2(s * 0.32, s * 0.18)), Color(1.0, 0.7, 0.15, k))
			ci.draw_arc(c + Vector2(0, -s * 0.42), s * 0.18, PI, TAU, 8, Color(0.2, 0.25, 0.3, k), maxf(2.0, s * 0.04))
		"crew_jacket":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.14, -s * 0.4), c + Vector2(s * 0.14, -s * 0.4), c + Vector2(s * 0.42, -s * 0.22),
				c + Vector2(s * 0.42, s * 0.12), c + Vector2(s * 0.3, s * 0.12), c + Vector2(s * 0.3, s * 0.44), c + Vector2(-s * 0.3, s * 0.44),
				c + Vector2(-s * 0.3, s * 0.12), c + Vector2(-s * 0.42, s * 0.12), c + Vector2(-s * 0.42, -s * 0.22)]), Color(0.1, 0.1, 0.12, k))
			ci.draw_line(c + Vector2(0, -s * 0.32), c + Vector2(0, s * 0.44), Color(0.6, 0.6, 0.6, k), maxf(2.0, s * 0.03))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.14, -s * 0.4), c + Vector2(0, -s * 0.2), c + Vector2(s * 0.14, -s * 0.4)]), Color(0.9, 0.2, 0.2, k))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.42, s * 0.0), Vector2(s * 0.12, s * 0.06)), Color(0.9, 0.2, 0.2, k))
			ci.draw_rect(Rect2(c + Vector2(s * 0.3, s * 0.0), Vector2(s * 0.12, s * 0.06)), Color(0.9, 0.2, 0.2, k))
		"clipboard":
			ToolArt.draw_tool(ci, c, s * 1.1, "clipboard")
			ci.draw_string(ThemeDB.fallback_font, c + Vector2(-s * 0.2, s * 0.15), "%", HORIZONTAL_ALIGNMENT_CENTER, s * 0.4, int(s * 0.4), Color(0.1, 0.6, 0.2))
		"lanyard":
			ci.draw_arc(c + Vector2(0, -s * 0.2), s * 0.3, PI, TAU, 12, Color(1.0, 0.7, 0.1, k), maxf(3.0, s * 0.07))
			ci.draw_line(c + Vector2(-s * 0.3, -s * 0.2), c + Vector2(-s * 0.05, s * 0.05), Color(1.0, 0.7, 0.1, k), maxf(3.0, s * 0.07))
			ci.draw_line(c + Vector2(s * 0.3, -s * 0.2), c + Vector2(s * 0.05, s * 0.05), Color(1.0, 0.7, 0.1, k), maxf(3.0, s * 0.07))
			_rr(ci, Rect2(c + Vector2(-s * 0.22, s * 0.02), Vector2(s * 0.44, s * 0.42)), w)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.22, s * 0.02), Vector2(s * 0.44, s * 0.1)), Color(0.1, 0.1, 0.1, k))
			ci.draw_string(ThemeDB.fallback_font, c + Vector2(-s * 0.22, s * 0.36), "VIP", HORIZONTAL_ALIGNMENT_CENTER, s * 0.44, int(s * 0.2), Color(0.8, 0.6, 0.0, k))
		"night_lamp":
			ci.draw_circle(c + Vector2(0, -s * 0.08), s * 0.4, Color(1.0, 0.85, 0.3, 0.25 * k))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.12, -s * 0.38), c + Vector2(s * 0.12, -s * 0.38), c + Vector2(s * 0.3, -s * 0.05), c + Vector2(-s * 0.3, -s * 0.05)]), Color(1.0, 0.85, 0.3, k))
			ci.draw_line(c + Vector2(0, -s * 0.05), c + Vector2(0, s * 0.35), dark, maxf(2.0, s * 0.06))
			_rr(ci, Rect2(c + Vector2(-s * 0.22, s * 0.32), Vector2(s * 0.44, s * 0.12)), dark)
		"blueprints":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.4, s * 0.25), c + Vector2(s * 0.25, -s * 0.4), c + Vector2(s * 0.4, -s * 0.25), c + Vector2(-s * 0.25, s * 0.4)]), Color(0.1, 0.35, 0.8, k))
			ci.draw_circle(c + Vector2(s * 0.32, -s * 0.32), s * 0.11, Color(0.85, 0.9, 1.0, k))
			ci.draw_circle(c + Vector2(-s * 0.32, s * 0.32), s * 0.11, Color(0.05, 0.2, 0.5, k))
		_:
			ci.draw_circle(c, s * 0.3, dark)


## Material icon about `s` pixels big, centred on c.
static func draw_material(ci: CanvasItem, c: Vector2, s: float, id: String) -> void:
	var col := Color("9e9e9e")
	for m in Data.MATERIALS:
		if m["id"] == id:
			col = Color(m["color"])
	match id:
		"microfibre":
			_rr(ci, Rect2(c - Vector2(s * 0.4, s * 0.3), Vector2(s * 0.8, s * 0.6)), col)
			for y in 3:
				ci.draw_line(c + Vector2(-s * 0.3, -s * 0.15 + y * s * 0.15), c + Vector2(s * 0.3, -s * 0.15 + y * s * 0.15), col.darkened(0.3), maxf(1.5, s * 0.04))
		"rubber":
			ci.draw_arc(c, s * 0.3, 0, TAU, 20, col, maxf(4.0, s * 0.18))
			ci.draw_arc(c, s * 0.39, 0, TAU, 20, col.darkened(0.3), maxf(1.5, s * 0.04))
		"steel":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.3, -s * 0.15), c + Vector2(s * 0.3, -s * 0.15), c + Vector2(s * 0.42, s * 0.22), c + Vector2(-s * 0.42, s * 0.22)]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.3, -s * 0.15), c + Vector2(s * 0.3, -s * 0.15), c + Vector2(s * 0.22, -s * 0.24), c + Vector2(-s * 0.22, -s * 0.24)]), col.lightened(0.3))
		"chrome":
			ci.draw_circle(c, s * 0.36, Color("90a4ae"))
			ci.draw_circle(c + Vector2(-s * 0.06, -s * 0.06), s * 0.26, col)
			ci.draw_circle(c + Vector2(-s * 0.14, -s * 0.14), s * 0.08, Color.WHITE)
		"compound":
			_rr(ci, Rect2(c + Vector2(-s * 0.32, -s * 0.12), Vector2(s * 0.64, s * 0.42)), col)
			_rr(ci, Rect2(c + Vector2(-s * 0.36, -s * 0.24), Vector2(s * 0.72, s * 0.14)), col.darkened(0.3))
		"carbon":
			var r := Rect2(c - Vector2(s * 0.36, s * 0.36), Vector2(s * 0.72, s * 0.72))
			ci.draw_rect(r, col)
			var n := 4
			for x in n:
				for y in n:
					if (x + y) % 2 == 0:
						ci.draw_rect(Rect2(r.position + Vector2(x, y) * r.size.x / n, Vector2.ONE * r.size.x / n), col.lightened(0.18))
		"ceramic":
			_rr(ci, Rect2(c + Vector2(-s * 0.18, -s * 0.18), Vector2(s * 0.36, s * 0.56)), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.08, -s * 0.36), Vector2(s * 0.16, s * 0.2)), Color("263238"))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.18, s * 0.02), Vector2(s * 0.36, s * 0.12)), Color("ffb300"))
		"alcantara":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.38, -s * 0.28), c + Vector2(s * 0.38, -s * 0.34), c + Vector2(s * 0.34, s * 0.3), c + Vector2(-s * 0.34, s * 0.34)]), col)
			for k in 3:
				ci.draw_line(c + Vector2(-s * 0.3 + k * s * 0.22, -s * 0.25), c + Vector2(-s * 0.2 + k * s * 0.22, s * 0.25), col.lightened(0.2), maxf(1.5, s * 0.03))
		_:
			ci.draw_circle(c, s * 0.3, col)
