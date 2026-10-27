extends VBoxContainer
## HQ > EQUIP. Two tabs on top:
##   EQUIPMENT - every item: craft the Common, upgrade to Rare / Epic, choose who wears it
##   MATERIALS - what you've got to craft with

const Data = preload("res://scripts/game_data.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")
const EquipIcon = preload("res://scripts/equip_icon.gd")
const GearPicker = preload("res://scripts/gear_picker_panel.gd")

static var tab := 0

var _tab_btns: Array = []
var _scroll: ScrollContainer
var _list: VBoxContainer
var _sig := ""


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top"]:
		pad.add_theme_constant_override("margin_" + side, 16)
	add_child(pad)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	pad.add_child(tabs)
	for k in 2:
		var b := UiTheme.button(["EQUIPMENT", "MATERIALS"][k], 20, Color("2a63c4"))
		b.custom_minimum_size = Vector2(0, 58)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			tab = k
			_build())
		tabs.add_child(b)
		_tab_btns.append(b)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 16)
	_scroll.add_child(m)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	m.add_child(_list)


func _process(_delta: float) -> void:
	var sig := _signature()
	if sig != _sig:
		_build()


func _signature() -> String:
	var s := "%d|%s|%s|" % [tab, str(GameState.materials), str(GameState.equipment)]
	for m in GameState.roster.values():
		if m["owned"]:
			s += "%s:%s," % [m["id"], m["gear"]]
	return s


func _build() -> void:
	_sig = _signature()
	for k in _tab_btns.size():
		UiTheme.set_tab_look(_tab_btns[k], k == tab)
	var keep := _scroll.scroll_vertical
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	if tab == 0:
		_build_equipment()
	else:
		_build_materials()
	_scroll.set_deferred("scroll_vertical", keep)


# ---------------------------------------------------------------- equipment

func _build_equipment() -> void:
	var l := UiTheme.outlined(UiTheme.label("Gear for Premium managers, one item each. Craft the Common, then upgrade it to Rare and Epic. You can only own one of each.", 17, Color.WHITE), 4)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(l)
	for e in Data.EQUIPMENT:
		_list.add_child(_item_card(e))


func _item_card(e: Dictionary) -> Control:
	var id: String = e["id"]
	var tier := GameState.equip_tier(id)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.card(UiTheme.CARD, 14, 12))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var ic := EquipIcon.new()
	ic.item = id
	ic.tier = tier
	ic.custom_minimum_size = Vector2(96, 96)
	h.add_child(ic)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	var tname: String = Data.EQUIP_TIERS[tier]["name"] if tier >= 0 else "Not crafted"
	var tcol := Color(Data.EQUIP_TIERS[tier]["color"]).lightened(0.2) if tier >= 0 else UiTheme.MUTED
	_wrap(v, "%s  ·  %s" % [e["name"], tname], 20, tcol)
	var scope := "  (everywhere)" if e["scope"] == "global" else ""
	if tier >= 0:
		_wrap(v, GameState.equip_text(id) + scope, 17, UiTheme.GOOD)
	var recipe := GameState.next_recipe(id)
	if not recipe.is_empty():
		var nt := tier + 1
		_wrap(v, "%s: %s" % ["Craft" if tier < 0 else "Upgrade to " + str(Data.EQUIP_TIERS[nt]["name"]), GameState.equip_text(id, nt)] + scope,
			16, Color(1, 1, 1, 0.7))
		v.add_child(_recipe_row(recipe))
	var w := GameState.wearer_of(id)
	if tier >= 0:
		_wrap(v, "Worn by " + str(w["name"]) if not w.is_empty() else "Not worn", 16, Color("ffd54f") if not w.is_empty() else UiTheme.MUTED)

	var bv := VBoxContainer.new()
	bv.alignment = BoxContainer.ALIGNMENT_CENTER
	bv.add_theme_constant_override("separation", 6)
	h.add_child(bv)
	if not recipe.is_empty():
		var craft := UiTheme.button("CRAFT" if tier < 0 else "UPGRADE", 19, UiTheme.GOOD)
		craft.custom_minimum_size = Vector2(130, 56)
		craft.disabled = not GameState.can_craft(id)
		craft.pressed.connect(func():
			if GameState.craft(id):
				Sfx.play("big_win"))
		bv.add_child(craft)
	else:
		bv.add_child(UiTheme.label("MAX", 20, Color(Data.EQUIP_TIERS[2]["color"]).lightened(0.3)))
	if tier >= 0:
		var eq := UiTheme.button("EQUIP", 19, UiTheme.ACCENT)
		eq.custom_minimum_size = Vector2(130, 50)
		eq.pressed.connect(func(): _pick_wearer(id))
		bv.add_child(eq)
	return p


## Label that wraps instead of pushing the card wider than the screen.
func _wrap(parent: Control, t: String, font_size: int, color: Color) -> void:
	var l := UiTheme.label(t, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(120, 0)
	parent.add_child(l)


func _recipe_row(recipe: Dictionary) -> Control:
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 10)
	h.custom_minimum_size = Vector2(120, 0)
	for mat in recipe.keys():
		var have := int(GameState.materials.get(mat, 0))
		var need := int(recipe[mat])
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 2)
		var ic := EquipIcon.new()
		ic.mat_id = mat
		ic.custom_minimum_size = Vector2(28, 28)
		chip.add_child(ic)
		chip.add_child(UiTheme.label("%d/%d" % [have, need], 16, UiTheme.GOOD if have >= need else UiTheme.WARN))
		h.add_child(chip)
	return h


func _pick_wearer(id: String) -> void:
	var p := GearPicker.new()
	get_tree().current_scene.add_child(p)
	p.setup_for_item(id)


# ---------------------------------------------------------------- materials

func _build_materials() -> void:
	var l := UiTheme.outlined(UiTheme.label("Crafting materials. You'll get them from the " + Data.MATERIAL_SOURCE + ".", 17, Color.WHITE), 4)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(l)
	for t in Data.EQUIP_TIERS.size():
		_list.add_child(UiTheme.ribbon(str(Data.EQUIP_TIERS[t]["name"]).to_upper(), 19, Color(Data.EQUIP_TIERS[t]["color"])))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		_list.add_child(grid)
		for m in Data.MATERIALS:
			if int(m["tier"]) != t:
				continue
			var p := PanelContainer.new()
			p.add_theme_stylebox_override("panel", UiTheme.card(UiTheme.CARD, 12, 10))
			p.custom_minimum_size = Vector2(330, 0)
			grid.add_child(p)
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 10)
			p.add_child(h)
			var ic := EquipIcon.new()
			ic.mat_id = m["id"]
			ic.custom_minimum_size = Vector2(56, 56)
			h.add_child(ic)
			var v := VBoxContainer.new()
			v.alignment = BoxContainer.ALIGNMENT_CENTER
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(v)
			v.add_child(UiTheme.label(m["name"], 18))
			v.add_child(UiTheme.label("x%d" % int(GameState.materials.get(m["id"], 0)), 22, UiTheme.CASH))
	if OS.is_debug_build():
		var b := UiTheme.button("Give 100 of each (debug only)", 19, Color("b23b3b"))
		b.custom_minimum_size = Vector2(0, 60)
		b.pressed.connect(func(): GameState.grant_test_materials(100))
		_list.add_child(b)
