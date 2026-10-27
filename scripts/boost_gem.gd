extends Control
## v0.19j (playtest: "I like boosters as a badge"): a cartoon octagon gem with "xN" on it, Idle Miner
## style. Colour = the multiplier (x2 purple, x3 teal, x4 blue, x5+ red), the ad boost is green, the
## total is gold, an empty base is grey. An optional count bubble ("x3") for grouped boosters.

const UiTheme = preload("res://scripts/ui_theme.gd")

var label := "x2"
var kind := ""        # "" (by multiplier), "ad", "gold", "grey"
var mult := 2.0
var count := 1        # > 1 draws a small count bubble on the corner
var px := 96.0


static func colors_for(m: float, k: String = "") -> Array:
	match k:
		"ad":
			return [Color("9cf07a"), Color("2e9a3a")]
		"gold":
			return [Color("ffe27a"), Color("ef8a00")]
		"grey":
			return [Color("c9d1e3"), Color("6f7a93")]
	if m >= 100.0:   # v0.19n: Lucky Wheel jackpots
		return [Color("ffe27a"), Color("ef8a00")]
	if m >= 50.0:
		return [Color("f59bff"), Color("b72fd6")]
	if m >= 10.0:
		return [Color("ffb35c"), Color("e0620f")]
	if m >= 5.0:
		return [Color("ff8a5c"), Color("d03a1f")]
	if m >= 4.0:
		return [Color("86ecff"), Color("1a8fc4")]
	if m >= 3.0:
		return [Color("6cf0d6"), Color("139a85")]
	return [Color("e98cff"), Color("9b34c9")]


static func make(text: String, m: float, size_px: float, k: String = "", n: int = 1) -> Control:
	var g := new()
	g.label = text
	g.mult = m
	g.kind = k
	g.count = n
	g.px = size_px
	g.custom_minimum_size = Vector2(size_px, size_px * 1.06)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


func _oct(c: Vector2, r: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 8:
		var t := PI / 8.0 + i * PI / 4.0
		p.append(c + Vector2(cos(t), sin(t)) * r)
	return p


func _draw() -> void:
	var s := minf(size.x, size.y / 1.06)
	var c := Vector2(size.x * 0.5, s * 0.5)
	var r := s * 0.5
	var cols := colors_for(mult, kind)
	var c1: Color = cols[0]
	var c2: Color = cols[1]
	# drop shadow, rim, faceted face with a top-to-bottom shade
	draw_colored_polygon(_oct(c + Vector2(0, s * 0.05), r * 0.98), UiTheme.INK)
	var rim := _oct(c, r * 0.98)
	draw_colored_polygon(rim, c2)
	var inner := _oct(c, r * 0.78)
	var shade := PackedColorArray()
	for v in inner:
		shade.append(c1.lerp(c2, clampf((v.y - (c.y - r * 0.78)) / (r * 1.56), 0.0, 1.0)))
	draw_polygon(inner, shade)
	var ring := inner.duplicate()
	ring.append(inner[0])
	draw_polyline(ring, Color(1, 1, 1, 0.55), maxf(1.5, s * 0.02), true)
	var out := rim.duplicate()
	out.append(rim[0])
	draw_polyline(out, UiTheme.INK, maxf(2.0, s * 0.035), true)
	# glints
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.40, -r * 0.60), c + Vector2(r * 0.10, -r * 0.60),
		c + Vector2(-r * 0.24, -r * 0.28)]), Color(1, 1, 1, 0.55))
	draw_circle(c + Vector2(r * 0.40, -r * 0.48), s * 0.035, Color(1, 1, 1, 0.8))
	# the label
	var fs := int(s * (0.30 if label.length() > 3 else 0.36))
	UiTheme.text(self, Vector2(0, c.y + fs * 0.36), label, fs, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, size.x,
		maxi(3, int(fs * 0.22)), UiTheme.DISPLAY_FONT)
	if count > 1:
		var br := maxf(13.0, s * 0.17)
		var bc := c + Vector2(r * 0.74, r * 0.66)
		draw_circle(bc + Vector2(0, 2), br + 2.0, UiTheme.INK)
		draw_circle(bc, br, Color("ffc93c"))
		draw_arc(bc, br, 0.0, TAU, 24, UiTheme.INK, 2.5, true)
		var cs := int(br * 1.05)
		UiTheme.text(self, Vector2(bc.x - br * 2.0, bc.y + cs * 0.36), "x%d" % count, cs, Color("3b2a00"),
			HORIZONTAL_ALIGNMENT_CENTER, br * 4.0, 0, UiTheme.DISPLAY_FONT)
