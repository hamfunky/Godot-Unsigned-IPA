extends Control
## A uniform drawn as a shirt in its colour, framed in its rarity colour.
## Not owned = dark silhouette.

const UiTheme = preload("res://scripts/ui_theme.gd")
const Data = preload("res://scripts/game_data.gd")

var uniform_id := ""
var owned := true


func _draw() -> void:
	var u: Dictionary = {}
	for x in Data.UNIFORMS:
		if x["id"] == uniform_id:
			u = x
	if u.is_empty():
		return
	var rc := Color(Data.UNIFORM_RARITIES[int(u["rarity"])]["color"])
	var r := Rect2(Vector2.ZERO, size)
	# v0.17f: pale bubbly tile with a rarity-coloured lip
	var frame := rc if owned else Color("8796b5")
	var inner := Rect2(r.position, r.size - Vector2(0, 5))
	UiTheme.rounded(self, r, frame.darkened(0.2), 14, 3, UiTheme.INK)
	UiTheme.rounded(self, inner, Color("eef4ff") if owned else Color("b8c3da"), 14, 3, UiTheme.INK)
	var c := r.get_center()
	var s := minf(size.x, size.y) * 0.8
	var col := Color(u["color"]) if owned else Color("7d89a3")
	var pts := PackedVector2Array([
		c + Vector2(-0.16, -0.36) * s, c + Vector2(0.16, -0.36) * s, c + Vector2(0.42, -0.2) * s, c + Vector2(0.34, -0.02) * s,
		c + Vector2(0.24, -0.08) * s, c + Vector2(0.24, 0.38) * s, c + Vector2(-0.24, 0.38) * s, c + Vector2(-0.24, -0.08) * s,
		c + Vector2(-0.34, -0.02) * s, c + Vector2(-0.42, -0.2) * s])
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_colored_polygon(pts, col)
	draw_polyline(outline, UiTheme.INK, 2.5, true)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-0.1, -0.36) * s, c + Vector2(0.1, -0.36) * s, c + Vector2(0, -0.24) * s]),
		UiTheme.INK if owned else Color("5d6a85"))
	if owned:
		# crew letter on the chest (D detailers, V valets, F front desk)
		var mark: String = {"bay": "D", "valet": "V", "desk": "F"}[u["area"]]
		UiTheme.text(self, c + Vector2(-s * 0.2, s * 0.14), mark, int(s * 0.26), Color(0, 0, 0, 0.45), HORIZONTAL_ALIGNMENT_CENTER, s * 0.4, 0)
		if int(u["rarity"]) == 4:
			draw_circle(c + Vector2(s * 0.12, -s * 0.12), s * 0.05, Color.WHITE)
