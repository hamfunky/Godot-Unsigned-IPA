extends "res://scripts/sheet.gd"
## Wardrobe: crates (Gloss) on top, then each crew's uniforms. The worn one boosts
## that station type in every city; duplicates level a uniform up.

const Data = preload("res://scripts/game_data.gd")
const UniformIcon = preload("res://scripts/uniform_icon.gd")
const ResultPanel = preload("res://scripts/wardrobe_result_panel.gd")

var _sig := ""
var _crate_btns: Array = []   # [Button, cost]


func setup() -> void:
	set_title("Wardrobe")
	_build()


func _process(_delta: float) -> void:
	var sig := "%s|%s" % [str(GameState.wardrobe), str(GameState.worn)]
	if sig != _sig:
		_build()
	for pair in _crate_btns:
		pair[0].disabled = GameState.gloss < int(pair[1])
		UiTheme.set_rich(pair[0], "%d {sb}" % int(pair[1]))


func _build() -> void:
	_sig = "%s|%s" % [str(GameState.wardrobe), str(GameState.worn)]
	clear_body()
	_crate_btns.clear()
	var intro := UiTheme.label("Uniforms boost a crew in every city. Duplicates level them up. Legendary within %d uniforms guaranteed (%d to go)." % [
		Data.WARDROBE_PITY, Data.WARDROBE_PITY - GameState.wardrobe_pity], 17, UiTheme.MUTED)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(intro)
	for c in Data.WARDROBE_CRATES:
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UiTheme.card(Color("2a74b5"), 14, 10))
		body.add_child(row)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		row.add_child(h)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(UiTheme.label(c["name"], 21))
		v.add_child(UiTheme.label(c["desc"], 16, UiTheme.MUTED))
		var id: String = c["id"]
		var b := UiTheme.button("", 19, Color("0277bd"))
		b.custom_minimum_size = Vector2(170, 60)
		b.disabled = GameState.gloss < int(c["cost"])
		UiTheme.set_rich(b, "%d {sb}" % int(c["cost"]))   # v0.19v: the banknote icon, not the words
		b.pressed.connect(func(): _open(id))
		h.add_child(b)
		_crate_btns.append([b, int(c["cost"])])

	for area in Data.MANAGER_AREAS:
		var wid: String = GameState.worn.get(area, "")
		var head := "%s  ·  %s" % [str(Data.UNIFORM_AREAS[area]).to_upper(), Data.UNIFORM_EFFECT[area] % _x(GameState.wardrobe_mult(area))]
		body.add_child(UiTheme.ribbon(head, 18, Color("e0a000") if wid != "" else Color("5d6a85")))
		for u in Data.UNIFORMS:
			if u["area"] == area:
				body.add_child(_uniform_row(u, u["id"] == wid))


func _uniform_row(u: Dictionary, wearing: bool) -> Control:
	var id: String = u["id"]
	var lvl := GameState.uniform_level(id)
	var rd: Dictionary = Data.UNIFORM_RARITIES[int(u["rarity"])]
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.card(UiTheme.CARD, 12, 8, UiTheme.CARD_GOLD if wearing else Color(0, 0, 0, 0)))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var ic := UniformIcon.new()
	ic.uniform_id = id
	ic.owned = lvl > 0
	ic.custom_minimum_size = Vector2(64, 64)
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	if lvl <= 0:
		v.add_child(UiTheme.label("%s  ·  not found yet" % rd["name"], 18, Color(rd["color"]).darkened(0.2)))
		return p
	v.add_child(UiTheme.label("%s  ·  %s  Lv %d" % [u["name"], rd["name"], lvl], 18, Color(rd["color"]).lightened(0.2)))
	var need := GameState.uniform_copies_needed(lvl)
	var copies := int(GameState.wardrobe[id]["copies"])
	var sub := "x%s  ·  " % _x(GameState.uniform_mult(id))
	sub += "MAX" if need < 0 else "next level: %d / %d copies (x%s)" % [copies, need, _x(GameState.uniform_mult(id, lvl + 1))]
	v.add_child(UiTheme.label(sub, 15, UiTheme.MUTED))
	if wearing:
		h.add_child(UiTheme.label("WEARING  ", 16, Color("ffd54f")))
	else:
		var b := UiTheme.button("WEAR", 18, UiTheme.ACCENT)
		b.custom_minimum_size = Vector2(110, 52)
		b.pressed.connect(func():
			GameState.wear_uniform(id)
			Sfx.play("level_up"))
		h.add_child(b)
	return p


func _open(id: String) -> void:
	var res := GameState.open_wardrobe_crate(id)
	if res.is_empty():
		return
	Sfx.play("big_win")
	var r := ResultPanel.new()
	get_parent().add_child(r)
	r.setup(res)


static func _x(m: float) -> String:
	return "%.2f" % m if m < 10.0 else "%.1f" % m
