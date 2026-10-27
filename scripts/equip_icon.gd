extends Control
## Draws one equipment item (with a tier-coloured frame) or one crafting material.

const Art = preload("res://scripts/equipment_art.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")
const Data = preload("res://scripts/game_data.gd")

var item := ""
var mat_id := ""
var tier := -1          # item tier; -1 = not crafted yet (drawn dim)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var s := minf(size.x, size.y)
	if item != "":
		# v0.17f: pale bubbly tile with a tier-coloured lip, so the item pops
		var frame := Color(Data.EQUIP_TIERS[tier]["color"]) if tier >= 0 else Color("8796b5")
		var inner := Rect2(r.position, r.size - Vector2(0, 6))
		UiTheme.rounded(self, r, frame.darkened(0.25), 16, 3, UiTheme.INK)
		UiTheme.rounded(self, inner, Color("eef4ff") if tier >= 0 else Color("b8c3da"), 16, 3, UiTheme.INK)
		UiTheme.rounded(self, Rect2(inner.position + Vector2(6, 5), Vector2(inner.size.x - 12, 7)), Color(1, 1, 1, 0.7), 4)
		Art.draw_item(self, r.get_center(), s * 0.78, item, tier < 0)
	elif mat_id != "":
		Art.draw_material(self, r.get_center(), s * 0.85, mat_id)
