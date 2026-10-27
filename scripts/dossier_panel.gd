extends "res://scripts/sheet.gd"
## A named manager's dossier: their silhouette with the clues you've found,
## what they do, and CALL (dossier complete) or LEVEL UP (with Certs).

const Data = preload("res://scripts/game_data.gd")
const Art = preload("res://scripts/manager_art.gd")
const EquipIcon = preload("res://scripts/equip_icon.gd")
const GearPicker = preload("res://scripts/gear_picker_panel.gd")

var id := ""
var _action: Button
var _status: Label
var _sig := ""


class Figure extends Control:
	const UT = preload("res://scripts/ui_theme.gd")
	const AR = preload("res://scripts/manager_art.gd")
	const DA = preload("res://scripts/game_data.gd")
	var m: Dictionary
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var rc := Color(DA.PREMIUM_RARITIES[int(m["rarity"])]["color"])
		var r := Rect2(Vector2.ZERO, size)
		UT.rounded(self, r, rc.darkened(0.3), 16, 3, UT.INK)   # v0.17f pale tile with a rarity lip
		UT.rounded(self, Rect2(r.position, r.size - Vector2(0, 8)), Color("e3ecfa"), 16, 4, rc)
		var mask: int = 63 if m["owned"] else int(m["clues"])
		AR.draw_body(self, Rect2(Vector2(20, 18), size - Vector2(40, 40)), m, mask)
		UT.text(self, Vector2(0, size.y - 10), DA.PREMIUM_RARITIES[int(m["rarity"])]["name"].to_upper(), 15, rc, HORIZONTAL_ALIGNMENT_CENTER, size.x, 3)


func setup(manager_id: String) -> void:
	set_finish("carbon")   # v0.19u
	id = manager_id
	_build()


func _process(_delta: float) -> void:
	var sig := _signature()
	if sig != _sig:
		_build()
	_refresh()


func _signature() -> String:
	var m := GameState.manager(id)
	return "%d|%s|%d|%s|%s" % [int(m["clues"]), m["owned"], int(m["level"]), m["gear"], str(GameState.equipment.get(m["gear"], -1))]


func _build() -> void:
	_sig = _signature()
	clear_body()
	var m := GameState.manager(id)
	var rarity := GameState.rarity_def(m)
	var known: bool = int(m["clues"]) != 0 or m["owned"]
	set_title(str(m["name"]) if known else "Unknown")

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	body.add_child(h)
	var fig := Figure.new()
	fig.m = m
	fig.custom_minimum_size = Vector2(230, 360)
	h.add_child(fig)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	h.add_child(v)
	var area_name: String = {"bay": "Bay", "valet": "Valet", "desk": "Front Desk"}[m["area"]]
	v.add_child(UiTheme.label("%s  ·  %s manager" % [rarity["name"], area_name], 20, Color(rarity["color"]).lightened(0.2)))
	var crew := GameState.crew_def(m)
	v.add_child(UiTheme.label(crew["name"], 18, Color(crew["color"]).lightened(0.35)))
	if m["owned"]:
		v.add_child(UiTheme.label("%s  ·  Lv %d / %d" % [GameState.promotion(m), int(m["level"]), Data.MAX_MANAGER_LEVEL], 20, UiTheme.CASH))
		v.add_child(UiTheme.label(GameState.manager_location(m), 17, UiTheme.MUTED))
	else:
		v.add_child(UiTheme.label("CLUES  %d / %d" % [GameState.clue_count(m), Data.CLUES.size()], 20, UiTheme.CASH))
		for k in Data.CLUES.size():
			var have := GameState.has_clue(m, k)
			var row := UiTheme.label(("FOUND   " if have else "missing   ") + str(Data.CLUE_NAMES[Data.CLUES[k]]), 18,
				UiTheme.GOOD if have else Color(1, 1, 1, 0.4))
			v.add_child(row)

	# what they do
	var info := PanelContainer.new()
	info.add_theme_stylebox_override("panel", UiTheme.card(UiTheme.CARD, 14, 12))
	body.add_child(info)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 4)
	info.add_child(iv)
	_info_line(iv, "ABILITY", "%s  (%s, then %s recharge)" % [GameState.ability_text(m), GameState.ability_length_text(m),
		GameState.fmt_time(GameState.ability_cooldown(m))], UiTheme.TEXT)
	var pas := GameState.passive_text(m)
	if m["owned"] and int(m["level"]) < Data.MAX_MANAGER_LEVEL:
		pas += "   (next level: %d%%)" % int(round(GameState.passive_value(m, int(m["level"]) + 1) * 100.0))
	_info_line(iv, "PASSIVE  ·  while seated", pas, UiTheme.GOOD)
	for pk in [["perk20", 20], ["perk50", 50]]:
		var p: Dictionary = Data.PERKS[m[pk[0]]]
		var on: bool = m["owned"] and int(m["level"]) >= int(pk[1])
		_info_line(iv, "LV %d PERK%s" % [pk[1], "" if on else "  ·  locked"], "%s: %s" % [p["name"], p["desc"]],
			Color("ce93d8") if on else Color(1, 1, 1, 0.45))
	if m.has("legend"):
		var lg: Dictionary = Data.LEGEND_PASSIVES[m["legend"]]
		_info_line(iv, "LEGENDARY  ·  while seated anywhere", "%s: %s" % [lg["name"], lg["desc"]], Color("ffca28"))

	if m["owned"]:
		body.add_child(_gear_row(m))

	_status = UiTheme.label("", 18, UiTheme.MUTED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_status)
	_action = UiTheme.button("", 26, UiTheme.GOOD)
	_action.custom_minimum_size = Vector2(0, 84)
	_action.pressed.connect(_on_action)
	body.add_child(_action)
	_refresh()


func _gear_row(m: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.card(UiTheme.CARD, 14, 10))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var g: String = m["gear"]
	if g != "":
		var ic := EquipIcon.new()
		ic.item = g
		ic.tier = GameState.equip_tier(g)
		ic.custom_minimum_size = Vector2(64, 64)
		h.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	v.add_child(UiTheme.label("GEAR", 15, UiTheme.MUTED))
	if g == "":
		v.add_child(UiTheme.label("Nothing equipped", 18, Color(1, 1, 1, 0.5)))
	else:
		var d := GameState.equip_def(g)
		v.add_child(UiTheme.label("%s  ·  %s" % [d["name"], Data.EQUIP_TIERS[GameState.equip_tier(g)]["name"]], 18, Color(Data.EQUIP_TIERS[GameState.equip_tier(g)]["color"]).lightened(0.2)))
		var t := UiTheme.label(GameState.equip_text(g), 16, UiTheme.GOOD)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(t)
	var b := UiTheme.button("CHANGE" if g != "" else "EQUIP", 19, UiTheme.ACCENT)
	b.custom_minimum_size = Vector2(130, 56)
	var mid: String = m["id"]
	b.pressed.connect(func():
		var pk := GearPicker.new()
		get_parent().add_child(pk)
		pk.setup_for_manager(mid))
	h.add_child(b)
	return p


func _info_line(parent: Control, head: String, text: String, color: Color) -> void:
	parent.add_child(UiTheme.label(head, 15, UiTheme.MUTED))
	var l := UiTheme.label(text, 18, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)


func _on_action() -> void:
	var m := GameState.manager(id)
	if m["owned"]:
		if GameState.level_up_manager(id):
			Sfx.play("level_up")
	elif GameState.call_manager(id):
		Sfx.play("hire")
		Sfx.buzz(40)


func _refresh() -> void:
	if _action == null:
		return
	var m := GameState.manager(id)
	if m["owned"]:
		var cost := GameState.level_cert_cost(m)
		_status.text = "Certs: %d" % GameState.certs
		if cost < 0:
			_action.text = "MAX LEVEL"
			_action.disabled = true
		else:
			_action.text = "LEVEL UP   %d Certs" % cost
			_action.disabled = GameState.certs < cost
	elif GameState.dossier_done(m):
		_status.text = "Dossier complete. Give them a call!"
		_action.text = "CALL %s   %s" % [str(m["name"]).to_upper(), GameState.money(GameState.call_fee())]
		_action.disabled = GameState.cash < GameState.call_fee()
	else:
		_status.text = "Find the missing clues in Case Files. They never repeat a clue you have."
		_action.text = "%d CLUES TO GO" % (Data.CLUES.size() - GameState.clue_count(m))
		_action.disabled = true
