extends RefCounted
## Code-drawn named managers (placeholder art, swap for sprites later).
## Every part can be hidden: a dossier only shows the clues you've found,
## the rest stays a dark silhouette.
##   mask = bit mask of Data.CLUES found (shirt, pants, shoes, hair, face, tool), 63 = all.

const Data = preload("res://scripts/game_data.gd")

const SKINS := [Color("f1c27d"), Color("e0ac69"), Color("c68642"), Color("8d5524"), Color("ffdbac")]
const SIL := Color("2a3140")          # silhouette
const SIL_EDGE := Color("3a4357")
const ALL := 63

const C_SHIRT := 0
const C_PANTS := 1
const C_SHOES := 2
const C_HAIR := 3
const C_FACE := 4
const C_TOOL := 5


static func _on(mask: int, clue: int) -> bool:
	return (mask & (1 << clue)) != 0


static func _col(m: Dictionary, field: String, mask: int, clue: int) -> Color:
	if not _on(mask, clue):
		return SIL
	if field == "skin":
		return SKINS[int(m["look"]["skin"]) % SKINS.size()]
	return Color(m["look"][field])


## Head and shoulders, filling `r`.
static func draw_bust(ci: CanvasItem, r: Rect2, m: Dictionary, mask: int = ALL) -> void:
	var s := minf(r.size.x, r.size.y)
	var cx := r.position.x + r.size.x * 0.5
	var head_c := Vector2(cx, r.position.y + r.size.y * 0.40)
	var hr := s * 0.21
	var skin := _col(m, "skin", mask, C_FACE)
	var hair := _col(m, "hair", mask, C_HAIR)
	var shirt := _col(m, "shirt", mask, C_SHIRT)
	var style := int(m["look"]["style"]) if _on(mask, C_HAIR) else 0
	# long hair goes behind everything
	if style == 1:
		ci.draw_rect(Rect2(head_c.x - hr * 1.05, head_c.y - hr * 0.2, hr * 2.1, hr * 1.7), hair)
	# shoulders
	var top := r.position.y + r.size.y * 0.70
	var bottom := r.end.y
	ci.draw_circle(Vector2(cx - s * 0.26, top + s * 0.10), s * 0.12, shirt)
	ci.draw_circle(Vector2(cx + s * 0.26, top + s * 0.10), s * 0.12, shirt)
	ci.draw_rect(Rect2(cx - s * 0.38, top + s * 0.10, s * 0.76, bottom - top - s * 0.10), shirt)
	ci.draw_rect(Rect2(cx - s * 0.26, top - s * 0.02, s * 0.52, s * 0.14), shirt)
	# neck + collar
	ci.draw_rect(Rect2(cx - hr * 0.42, head_c.y + hr * 0.6, hr * 0.84, top - head_c.y - hr * 0.5), skin)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(cx - hr * 0.5, top - s * 0.02), Vector2(cx, top + s * 0.08),
		Vector2(cx + hr * 0.5, top - s * 0.02)]), skin)
	_head(ci, head_c, hr, m, mask, skin, hair, style)
	_tool_badge(ci, Vector2(r.end.x - s * 0.17, r.end.y - s * 0.17), s * 0.15, m, mask)


## Full body for the dossier, filling `r` (taller than wide works best).
static func draw_body(ci: CanvasItem, r: Rect2, m: Dictionary, mask: int = ALL) -> void:
	var h := r.size.y
	var cx := r.position.x + r.size.x * 0.5
	var u := h / 10.0   # body unit
	var skin := _col(m, "skin", mask, C_FACE)
	var hair := _col(m, "hair", mask, C_HAIR)
	var shirt := _col(m, "shirt", mask, C_SHIRT)
	var pants := _col(m, "pants", mask, C_PANTS)
	var shoes := _col(m, "shoes", mask, C_SHOES)
	var style := int(m["look"]["style"]) if _on(mask, C_HAIR) else 0
	var head_c := Vector2(cx, r.position.y + u * 1.25)
	var hr := u * 0.95
	if style == 1:
		ci.draw_rect(Rect2(head_c.x - hr * 1.05, head_c.y - hr * 0.2, hr * 2.1, hr * 2.0), hair)
	var y0 := r.position.y + u * 2.3   # shoulders
	# legs + shoes
	ci.draw_rect(Rect2(cx - u * 1.0, y0 + u * 3.6, u * 0.9, u * 3.4), pants)
	ci.draw_rect(Rect2(cx + u * 0.1, y0 + u * 3.6, u * 0.9, u * 3.4), pants)
	_rounded(ci, Rect2(cx - u * 1.25, y0 + u * 6.95, u * 1.2, u * 0.55), shoes)
	_rounded(ci, Rect2(cx + u * 0.05, y0 + u * 6.95, u * 1.2, u * 0.55), shoes)
	# arms (sleeves + hands)
	ci.draw_rect(Rect2(cx - u * 2.0, y0 + u * 0.2, u * 0.65, u * 2.0), shirt)
	ci.draw_rect(Rect2(cx + u * 1.35, y0 + u * 0.2, u * 0.65, u * 2.0), shirt)
	ci.draw_rect(Rect2(cx - u * 1.95, y0 + u * 2.2, u * 0.55, u * 1.3), skin)
	ci.draw_rect(Rect2(cx + u * 1.4, y0 + u * 2.2, u * 0.55, u * 1.3), skin)
	ci.draw_circle(Vector2(cx - u * 1.67, y0 + u * 3.55), u * 0.32, skin)
	ci.draw_circle(Vector2(cx + u * 1.67, y0 + u * 3.55), u * 0.32, skin)
	# torso
	_rounded(ci, Rect2(cx - u * 1.4, y0, u * 2.8, u * 3.9), shirt)
	ci.draw_rect(Rect2(cx - u * 1.05, y0 + u * 3.4, u * 2.1, u * 0.35), pants.darkened(0.25))   # belt
	# neck + head
	ci.draw_rect(Rect2(cx - hr * 0.4, head_c.y + hr * 0.6, hr * 0.8, y0 - head_c.y - hr * 0.5), skin)
	_head(ci, head_c, hr, m, mask, skin, hair, style)
	# signature tool in the right hand
	var tc := Vector2(cx + u * 2.25, y0 + u * 3.6)
	if _on(mask, C_TOOL):
		draw_tool(ci, tc, u * 1.1, str(m["look"]["tool"]))
	else:
		_unknown(ci, tc, u * 0.55)


static func _head(ci: CanvasItem, c: Vector2, hr: float, m: Dictionary, mask: int, skin: Color, hair: Color, style: int) -> void:
	ci.draw_circle(c, hr, skin)
	# hair on top
	if style == 3:
		# cap in a darker shade of the shirt
		var cap := _col(m, "shirt", mask, C_SHIRT).darkened(0.35) if _on(mask, C_HAIR) else SIL_EDGE
		ci.draw_colored_polygon(_half_circle(c + Vector2(0, -hr * 0.15), hr * 1.02, true), cap)
		ci.draw_rect(Rect2(c.x - hr * 0.2, c.y - hr * 0.22, hr * 1.35, hr * 0.22), cap)
	else:
		ci.draw_colored_polygon(_half_circle(c + Vector2(0, -hr * 0.12), hr * 1.04, true), hair)
		ci.draw_rect(Rect2(c.x - hr * 1.0, c.y - hr * 0.2, hr * 0.28, hr * 0.55), hair)
		ci.draw_rect(Rect2(c.x + hr * 0.72, c.y - hr * 0.2, hr * 0.28, hr * 0.55), hair)
		if style == 2:
			ci.draw_circle(c + Vector2(0, -hr * 1.15), hr * 0.42, hair)
	if _on(mask, C_FACE):
		var eye := Color("2b2b2b")
		ci.draw_circle(c + Vector2(-hr * 0.36, hr * 0.12), hr * 0.11, eye)
		ci.draw_circle(c + Vector2(hr * 0.36, hr * 0.12), hr * 0.11, eye)
		ci.draw_arc(c + Vector2(0, hr * 0.32), hr * 0.32, 0.35, PI - 0.35, 10, eye, maxf(1.5, hr * 0.08))
	else:
		_unknown(ci, c + Vector2(0, hr * 0.2), hr * 0.42)


static func _half_circle(c: Vector2, r: float, top: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 13:
		var a := PI + PI * k / 12.0 if top else PI * k / 12.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


static func _rounded(ci: CanvasItem, r: Rect2, c: Color) -> void:
	var rad := minf(r.size.x, r.size.y) * 0.45
	ci.draw_rect(Rect2(r.position.x + rad, r.position.y, r.size.x - rad * 2.0, r.size.y), c)
	ci.draw_rect(Rect2(r.position.x, r.position.y + rad, r.size.x, r.size.y - rad * 2.0), c)
	for p in [r.position + Vector2(rad, rad), Vector2(r.end.x - rad, r.position.y + rad),
			Vector2(r.position.x + rad, r.end.y - rad), r.end - Vector2(rad, rad)]:
		ci.draw_circle(p, rad, c)


static func _unknown(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c, r, SIL_EDGE)
	var font := ThemeDB.fallback_font
	var fs := int(r * 1.5)
	ci.draw_string(font, c + Vector2(-r, fs * 0.36), "?", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color(1, 1, 1, 0.6))


static func _tool_badge(ci: CanvasItem, c: Vector2, r: float, m: Dictionary, mask: int) -> void:
	if not _on(mask, C_TOOL):
		return
	ci.draw_circle(c, r, Color(1, 1, 1, 0.92))
	draw_tool(ci, c, r * 1.5, str(m["look"]["tool"]))


## Small icon of a signature tool, about `s` pixels big, centred on c.
static func draw_tool(ci: CanvasItem, c: Vector2, s: float, tool: String) -> void:
	var dark := Color("37474f")
	match tool:
		"sponge":
			_rounded(ci, Rect2(c - Vector2(s * 0.45, s * 0.28), Vector2(s * 0.9, s * 0.56)), Color("ffd54f"))
			for p in [Vector2(-0.2, -0.05), Vector2(0.1, 0.08), Vector2(0.22, -0.1)]:
				ci.draw_circle(c + p * s, s * 0.05, Color("f9a825"))
		"spray":
			_rounded(ci, Rect2(c + Vector2(-s * 0.2, -s * 0.15), Vector2(s * 0.4, s * 0.6)), Color("29b6f6"))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.12, -s * 0.38), Vector2(s * 0.34, s * 0.24)), dark)
			ci.draw_rect(Rect2(c + Vector2(s * 0.2, -s * 0.36), Vector2(s * 0.18, s * 0.08)), dark)
		"foam":
			_rounded(ci, Rect2(c + Vector2(-s * 0.18, -s * 0.05), Vector2(s * 0.36, s * 0.5)), Color("e53935"))
			for p in [Vector2(-0.18, -0.25), Vector2(0.05, -0.35), Vector2(0.25, -0.22)]:
				ci.draw_circle(c + p * s, s * 0.16, Color.WHITE)
		"keys":
			ci.draw_arc(c + Vector2(-s * 0.18, -s * 0.12), s * 0.2, 0, TAU, 16, Color("ffca28"), maxf(2.0, s * 0.08))
			ci.draw_line(c + Vector2(-s * 0.02, 0), c + Vector2(s * 0.4, s * 0.3), Color("bdbdbd"), maxf(2.0, s * 0.12))
			ci.draw_line(c + Vector2(s * 0.28, s * 0.22), c + Vector2(s * 0.2, s * 0.34), Color("bdbdbd"), maxf(2.0, s * 0.08))
		"clipboard":
			_rounded(ci, Rect2(c - Vector2(s * 0.3, s * 0.4), Vector2(s * 0.6, s * 0.8)), Color("8d6e63"))
			ci.draw_rect(Rect2(c - Vector2(s * 0.22, s * 0.28), Vector2(s * 0.44, s * 0.6)), Color.WHITE)
			ci.draw_rect(Rect2(c - Vector2(s * 0.12, s * 0.46), Vector2(s * 0.24, s * 0.12)), dark)
		"polisher":
			ci.draw_circle(c + Vector2(0, s * 0.15), s * 0.3, Color("ff7043"))
			ci.draw_circle(c + Vector2(0, s * 0.15), s * 0.16, Color("ffccbc"))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.08, -s * 0.45), Vector2(s * 0.16, s * 0.4)), dark)
		"wrench":
			ci.draw_line(c + Vector2(-s * 0.3, s * 0.3), c + Vector2(s * 0.2, -s * 0.2), Color("9e9e9e"), maxf(2.0, s * 0.16))
			ci.draw_arc(c + Vector2(s * 0.25, -s * 0.25), s * 0.15, 0, TAU, 12, Color("9e9e9e"), maxf(2.0, s * 0.1))
		"coffee":
			_rounded(ci, Rect2(c - Vector2(s * 0.25, s * 0.25), Vector2(s * 0.45, s * 0.55)), Color.WHITE)
			ci.draw_arc(c + Vector2(s * 0.22, 0), s * 0.13, -PI / 2, PI / 2, 8, Color.WHITE, maxf(2.0, s * 0.07))
			ci.draw_rect(Rect2(c - Vector2(s * 0.25, s * 0.25), Vector2(s * 0.45, s * 0.12)), Color("6d4c41"))
		"card":
			_rounded(ci, Rect2(c - Vector2(s * 0.25, s * 0.4), Vector2(s * 0.5, s * 0.8)), Color("263238"))
			ci.draw_rect(Rect2(c - Vector2(s * 0.17, s * 0.3), Vector2(s * 0.34, s * 0.22)), Color("80deea"))
			for k in 3:
				ci.draw_rect(Rect2(c + Vector2(-s * 0.17 + k * s * 0.12, s * 0.02), Vector2(s * 0.08, s * 0.08)), Color("b0bec5"))
		"radio":
			_rounded(ci, Rect2(c - Vector2(s * 0.2, s * 0.3), Vector2(s * 0.4, s * 0.7)), Color("212121"))
			ci.draw_line(c + Vector2(s * 0.1, -s * 0.3), c + Vector2(s * 0.1, -s * 0.55), Color("212121"), maxf(2.0, s * 0.07))
			ci.draw_rect(Rect2(c - Vector2(s * 0.12, s * 0.18), Vector2(s * 0.24, s * 0.16)), Color("aed581"))
		_:
			ci.draw_circle(c, s * 0.3, dark)
