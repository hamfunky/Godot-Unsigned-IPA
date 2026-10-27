extends RefCounted
## v0.19v: the world map's small drawings, shared by the map (labels layer) and its side panels
## (Collect / Prestige use the same little shop as a city's logo). ci = the CanvasItem to draw on.

const UiTheme = preload("res://scripts/ui_theme.gd")
const INK := Color("1d1b2b")


static func outline(ci: CanvasItem, poly: PackedVector2Array, col: Color, w: float) -> void:
	var p := PackedVector2Array(poly)
	p.append(poly[0])
	ci.draw_polyline(p, col, w, true)


## A name on a ribbon with tails, and an optional dark pill under it (income, price...).
## sub_col: the pill's text colour. Returns the rect it covered (for stacking).
static func ribbon(ci: CanvasItem, c: Vector2, t: String, col: Color, fs: int, sub: String = "", sub_col := Color("ffd23f")) -> Rect2:
	var f := UiTheme.DISPLAY_FONT
	var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 34.0
	var h := fs + 14.0
	var r := Rect2(c.x - tw * 0.5, c.y - h * 0.5, tw, h)
	var lw := maxf(2.0, fs * 0.12)
	for sx in [-1.0, 1.0]:   # tails
		var tx: float = c.x + sx * (tw * 0.5 + 4.0)
		var o8 := fs * 0.35
		var tail := PackedVector2Array([Vector2(tx - sx * fs * 0.8, r.position.y + o8), Vector2(tx + sx * fs * 0.6, r.position.y + o8),
			Vector2(tx + sx * fs * 0.18, r.position.y + h * 0.5 + o8), Vector2(tx + sx * fs * 0.6, r.end.y + o8), Vector2(tx - sx * fs * 0.8, r.end.y + o8)])
		ci.draw_colored_polygon(tail, col.darkened(0.35))
		var o := PackedVector2Array(tail)
		o.append(tail[0])
		ci.draw_polyline(o, INK, lw, true)
	UiTheme.rounded(ci, r, col, int(fs * 0.27), int(lw), INK)
	ci.draw_rect(Rect2(r.position + Vector2(4, 4), Vector2(r.size.x - 8, maxf(3.0, fs * 0.16))), Color(1, 1, 1, 0.25))
	UiTheme.text(ci, Vector2(r.position.x, r.position.y + h * 0.5 + fs * 0.36), t, fs, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(maxf(4.0, fs * 0.27)), f)
	var out := r
	if sub != "":
		var sfs := int(fs * 0.78)
		var sw := UiTheme.BODY_FONT.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x + 22.0
		var sr := Rect2(c.x - sw * 0.5, r.end.y - 2, sw, sfs + 8.0)
		UiTheme.rounded(ci, sr, Color(0.07, 0.1, 0.2, 0.85), int(sfs * 0.45), int(lw * 0.8), INK)
		UiTheme.text(ci, Vector2(sr.position.x, sr.position.y + sfs * 0.95), sub, sfs, sub_col, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, int(maxf(3.0, sfs * 0.22)))
		out = out.merge(sr)
	return out


static func padlock(ci: CanvasItem, c: Vector2, s: float) -> void:
	ci.draw_arc(c + Vector2(0, -s * 0.35), s * 0.42, PI, TAU, 16, INK, s * 0.26, true)
	ci.draw_arc(c + Vector2(0, -s * 0.35), s * 0.42, PI, TAU, 16, Color("cfd8dc"), s * 0.13, true)
	UiTheme.rounded(ci, Rect2(c + Vector2(-s * 0.62, -s * 0.38), Vector2(s * 1.24, s)), Color("ffcf4a"), int(s * 0.18), 3, INK)
	ci.draw_circle(c + Vector2(0, 0.08 * s), s * 0.14, INK)


static func pin(ci: CanvasItem, at: Vector2, k := 1.0) -> void:
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-12, 8) * k, at + Vector2(12, 8) * k, at + Vector2(0, 34) * k]), INK)
	ci.draw_circle(at, 19.0 * k, INK)
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-9, 9) * k, at + Vector2(9, 9) * k, at + Vector2(0, 30) * k]), Color("ff5a5f"))
	ci.draw_circle(at, 16.0 * k, Color("ff5a5f"))
	ci.draw_circle(at, 6.0 * k, Color.WHITE)
	ci.draw_circle(at + Vector2(-5, -6) * k, 4.0 * k, Color(1, 1, 1, 0.45))


## A city's "logo": a little shop that grows fancier with its premises (prestige) level. `at` = middle of
## its base; k = scale.
static func shop(ci: CanvasItem, at: Vector2, p: int, here: bool, pc: Color, k := 1.0) -> void:
	var w := (54.0 + p * 4.0) * k
	var h := (30.0 + p * 3.0) * k
	var base := at + Vector2(-w * 0.5, 0)
	ci.draw_set_transform(at + Vector2(0, 2 * k), 0.0, Vector2(1.0, 0.3))
	ci.draw_circle(Vector2.ZERO, w * 0.6, Color(0, 0, 0, 0.22))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var bw := maxi(2, int(3 * k))
	UiTheme.rounded(ci, Rect2(base + Vector2(0, -h), Vector2(w, h)), Color("f4f1ea"), int(4 * k), bw, INK)
	UiTheme.rounded(ci, Rect2(base + Vector2(-4 * k, -h - 12 * k), Vector2(w + 8 * k, 14 * k)), pc, int(4 * k), bw, INK)
	for d in 2:   # roller doors
		UiTheme.rounded(ci, Rect2(base + Vector2((6 + d * (w / k * 0.5 - 4)) * k, -h + 10 * k), Vector2(w * 0.5 - 12 * k, h - 10 * k)), Color("9fb0c4"), int(2 * k), maxi(1, int(2 * k)), INK)
	if p >= 3:   # a gold crest on the fancy ones
		ci.draw_circle(at + Vector2(0, -h - 18 * k), 7.0 * k, INK)
		ci.draw_circle(at + Vector2(0, -h - 18 * k), 5.5 * k, Color("ffcf4a"))
	if here:
		UiTheme.rounded(ci, Rect2(base + Vector2(-8, -h - 18) * Vector2(1, 1) * k, Vector2(w + 16 * k, h + 24 * k)), Color(0, 0, 0, 0), int(8 * k), bw, Color(1, 0.85, 0.2, 0.9))


## Gold coins + a dollar sign (the COLLECT corner button / collect rows).
static func coins(ci: CanvasItem, c: Vector2, s: float) -> void:
	for k in 3:
		var p := c + Vector2(-s * 0.18 + k * s * 0.02, s * 0.22 - k * s * 0.16)
		ci.draw_set_transform(p, 0.0, Vector2(1.0, 0.42))
		ci.draw_circle(Vector2.ZERO, s * 0.36, INK)
		ci.draw_circle(Vector2.ZERO, s * 0.31, Color("e0a000"))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	ci.draw_circle(c + Vector2(s * 0.14, -s * 0.06), s * 0.36, INK)
	ci.draw_circle(c + Vector2(s * 0.14, -s * 0.06), s * 0.31, Color("ffcf4a"))
	ci.draw_circle(c + Vector2(s * 0.14, -s * 0.06), s * 0.23, Color("ffe27a"))
	UiTheme.text(ci, c + Vector2(s * 0.14 - s * 0.4, s * 0.1), "$", int(s * 0.46), Color("b07800"), HORIZONTAL_ALIGNMENT_CENTER, s * 0.8, 0, UiTheme.DISPLAY_FONT)
