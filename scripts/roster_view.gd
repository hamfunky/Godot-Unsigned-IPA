extends VBoxContainer
## HQ > MANAGERS: every named manager (one of each), grouped by rarity.
## Ones you own show their level; the rest are silhouettes showing the clues you've
## found. Case Files to open and your Certs sit on top.

const Data = preload("res://scripts/game_data.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")
const Portrait = preload("res://scripts/portrait.gd")
const DossierPanel = preload("res://scripts/dossier_panel.gd")
const CaseResultPanel = preload("res://scripts/case_result_panel.gd")

var _top: HBoxContainer
var _files: HBoxContainer
var _certs: Label
var _scroll: ScrollContainer
var _list: VBoxContainer
var _sig := ""


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top"]:
		pad.add_theme_constant_override("margin_" + side, 16)
	add_child(pad)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 8)
	pad.add_child(tv)
	_top = HBoxContainer.new()
	tv.add_child(_top)
	_certs = UiTheme.outlined(UiTheme.display_label("", 24, Color("9ff3ff")), 6)
	_certs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top.add_child(_certs)
	var owned := UiTheme.outlined(UiTheme.label("", 20, Color.WHITE))
	owned.name = "Owned"
	_top.add_child(owned)
	_files = HBoxContainer.new()
	_files.add_theme_constant_override("separation", 8)
	tv.add_child(_files)

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
	var s := "%d|%s|" % [GameState.certs, str(GameState.case_files)]
	for m in GameState.roster.values():
		s += "%d%s%d," % [int(m["clues"]), "o" if m["owned"] else "", int(m["level"])]
	return s


func _build() -> void:
	_sig = _signature()
	_certs.text = "Certs: %d" % GameState.certs
	(_top.get_node("Owned") as Label).text = "%d / %d managers" % [GameState.owned_managers().size(), GameState.roster.size()]
	for c in _files.get_children():
		c.queue_free()
	var any := false
	for d in Data.CASE_FILES:
		var n := int(GameState.case_files.get(d["id"], 0))
		if n <= 0:
			continue
		any = true
		var id: String = d["id"]
		var b := UiTheme.button("%s  x%d\nOPEN" % [d["name"], n], 17, Color(d["color"]))
		b.custom_minimum_size = Vector2(0, 74)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): _open_file(id))
		_files.add_child(b)
	if not any:
		var l := UiTheme.outlined(UiTheme.label("No Case Files right now. You earn them in the Hometown Garage (renovations and finished runs).", 17, Color.WHITE), 4)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_files.add_child(l)

	var keep := _scroll.scroll_vertical
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	for r in range(Data.PREMIUM_RARITIES.size() - 1, -1, -1):
		var rd: Dictionary = Data.PREMIUM_RARITIES[r]
		var people := GameState.roster.values().filter(func(m): return int(m["rarity"]) == r)
		var have := people.filter(func(m): return m["owned"]).size()
		_list.add_child(UiTheme.ribbon("%s   %d / %d" % [str(rd["name"]).to_upper(), have, people.size()], 19, Color(rd["color"])))
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		_list.add_child(grid)
		for m in people:
			grid.add_child(_card(m))
	_scroll.set_deferred("scroll_vertical", keep)


func _card(m: Dictionary) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.custom_minimum_size = Vector2(158, 0)
	var p := Portrait.new()
	p.manager = m
	p.show_state = false
	p.show_level = true
	p.custom_minimum_size = Vector2(158, 150)
	p.pressed.connect(func(): _open_dossier(str(m["id"])))
	v.add_child(p)
	var known: bool = int(m["clues"]) != 0 or m["owned"]
	var name_l := UiTheme.outlined(UiTheme.label(str(m["name"]) if known else "???", 17, UiTheme.TEXT if known else Color(1, 1, 1, 0.75)))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.clip_text = true
	v.add_child(name_l)
	var sub: Label
	if m["owned"]:
		sub = UiTheme.label(GameState.manager_location(m), 14, Color("e3ecff"))
	elif GameState.dossier_done(m):
		sub = UiTheme.label("CALL THEM!", 16, UiTheme.CASH)
	else:
		sub = UiTheme.label("%d / %d clues" % [GameState.clue_count(m), Data.CLUES.size()], 15, Color("e3ecff"))
	UiTheme.outlined(sub, 4)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.clip_text = true
	v.add_child(sub)
	return v


func _open_dossier(id: String) -> void:
	var d := DossierPanel.new()
	get_tree().current_scene.add_child(d)
	d.setup(id)


func _open_file(id: String) -> void:
	var res := GameState.open_case_file(id)
	if res.is_empty():
		return
	Sfx.play("big_win")
	var p := CaseResultPanel.new()
	get_tree().current_scene.add_child(p)
	p.setup(res)
