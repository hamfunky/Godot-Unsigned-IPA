extends "res://scripts/sheet.gd"
## What came out of a Wardrobe crate.

const Data = preload("res://scripts/game_data.gd")
const UniformIcon = preload("res://scripts/uniform_icon.gd")


func setup(res: Array) -> void:
	set_finish("carbon")   # v0.19u
	set_title("Crate opened")
	for item in res:
		var u := GameState.uniform_def(item["id"])
		var rd: Dictionary = Data.UNIFORM_RARITIES[int(u["rarity"])]
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UiTheme.card(UiTheme.CARD, 12, 8))
		p.mouse_filter = Control.MOUSE_FILTER_PASS
		body.add_child(p)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		p.add_child(h)
		var ic := UniformIcon.new()
		ic.uniform_id = item["id"]
		ic.custom_minimum_size = Vector2(72, 72)
		h.add_child(ic)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(v)
		v.add_child(UiTheme.label("%s  ·  %s" % [u["name"], rd["name"]], 20, Color(rd["color"]).lightened(0.2)))
		var t: String
		if item["new"]:
			t = "NEW!  " + str(Data.UNIFORM_AREAS[u["area"]])
			if GameState.worn.get(u["area"], "") == item["id"]:
				t += "  ·  now wearing it"
		elif item["leveled"]:
			t = "LEVEL UP!  Now Lv %d" % int(item["level"])
		else:
			t = "Duplicate: +1 copy toward Lv %d" % (int(item["level"]) + 1)
		v.add_child(UiTheme.label(t, 16, UiTheme.CASH if (item["new"] or item["leveled"]) else UiTheme.MUTED))
	var ok := UiTheme.button("NICE", 26, UiTheme.GOOD)
	ok.custom_minimum_size = Vector2(0, 76)
	ok.pressed.connect(close)
	body.add_child(ok)
