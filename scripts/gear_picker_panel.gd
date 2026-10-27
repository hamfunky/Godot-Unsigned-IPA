extends "res://scripts/sheet.gd"
## Pick who wears an item (item_id set) or what a manager wears (manager_id set).

const Data = preload("res://scripts/game_data.gd")
const Portrait = preload("res://scripts/portrait.gd")
const EquipIcon = preload("res://scripts/equip_icon.gd")

var item_id := ""
var manager_id := ""


func setup_for_item(id: String) -> void:
	set_finish("gloss")   # v0.19u
	item_id = id
	set_title("Equip " + str(GameState.equip_def(id)["name"]))
	var people := GameState.owned_managers()
	if people.is_empty():
		_note("You don't own any Premium managers yet. Find them with Case Files from the Hometown Garage.")
		return
	_note("Gear only works on Premium managers. Station gear helps wherever they work.")
	people.sort_custom(func(a, b): return int(a["rarity"]) * 100 + int(a["level"]) > int(b["rarity"]) * 100 + int(b["level"]))
	var list := _list(people.size())
	for m in people:
		var row := _row(list)
		var p := Portrait.new()
		p.manager = m
		p.show_state = false
		p.show_level = true
		p.custom_minimum_size = Vector2(76, 82)
		row.add_child(p)
		var v := _texts(row, "%s  ·  %s" % [m["name"], GameState.rarity_def(m)["name"]],
			"%s  ·  wearing: %s" % [GameState.manager_location(m), _gear_name(m)], Color(GameState.rarity_def(m)["color"]).lightened(0.2))
		var mid: String = m["id"]
		var wearing: bool = m["gear"] == id
		var b := UiTheme.button("WEARING" if wearing else "EQUIP", 20, Color("3d4657") if wearing else UiTheme.ACCENT)
		b.disabled = wearing
		b.custom_minimum_size = Vector2(130, 60)
		b.pressed.connect(func():
			GameState.equip_item(id, mid)
			Sfx.play("level_up")
			close())
		row.add_child(b)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func setup_for_manager(id: String) -> void:
	set_finish("gloss")   # v0.19u
	manager_id = id
	var m := GameState.manager(id)
	set_title("Gear for " + str(m["name"]))
	var items := Data.EQUIPMENT.filter(func(e): return GameState.equip_tier(e["id"]) >= 0)
	if items.is_empty():
		_note("You haven't crafted any equipment yet. Craft it in MAP > Equip.")
		return
	if m["gear"] != "":
		var off := UiTheme.button("TAKE OFF " + str(GameState.equip_def(m["gear"])["name"]).to_upper(), 19, Color("3d4657"))
		off.custom_minimum_size = Vector2(0, 60)
		off.pressed.connect(func():
			GameState.unequip(id)
			close())
		body.add_child(off)
	var list := _list(items.size())
	for e in items:
		var row := _row(list)
		var ic := EquipIcon.new()
		ic.item = e["id"]
		ic.tier = GameState.equip_tier(e["id"])
		ic.custom_minimum_size = Vector2(76, 76)
		row.add_child(ic)
		var w := GameState.wearer_of(e["id"])
		_texts(row, "%s  ·  %s" % [e["name"], Data.EQUIP_TIERS[ic.tier]["name"]],
			GameState.equip_text(e["id"]) + ("" if w.is_empty() else "\nWorn by " + str(w["name"])), Color(Data.EQUIP_TIERS[ic.tier]["color"]).lightened(0.2))
		var eid: String = e["id"]
		var mine: bool = m["gear"] == eid
		var b := UiTheme.button("WEARING" if mine else "EQUIP", 20, Color("3d4657") if mine else UiTheme.ACCENT)
		b.disabled = mine
		b.custom_minimum_size = Vector2(130, 60)
		b.pressed.connect(func():
			GameState.equip_item(eid, id)
			Sfx.play("level_up")
			close())
		row.add_child(b)


func _gear_name(m: Dictionary) -> String:
	return "nothing" if m["gear"] == "" else str(GameState.equip_def(m["gear"])["name"])


func _note(t: String) -> void:
	var l := UiTheme.label(t, 18, UiTheme.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(l)


func _list(_n: int) -> VBoxContainer:
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	body.add_child(list)
	return list


func _row(list: VBoxContainer) -> HBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.card(UiTheme.CARD, 12, 10))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	list.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	return h


func _texts(h: HBoxContainer, title: String, sub: String, color: Color) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	v.add_child(UiTheme.label(title, 20, color))
	var l := UiTheme.label(sub, 16, UiTheme.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	return v
