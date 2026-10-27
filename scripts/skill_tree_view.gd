extends Control
## THE skill tree: one screen with every country's branch side by side, joined by
## one trunk. You buy tokens for a branch with that country's cash, then spend them
## on that branch's nodes. Branches of countries you haven't unlocked are greyed out.
## Tap a node to see it in the panel at the bottom and upgrade it.

const Data = preload("res://scripts/game_data.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")

const BRANCH_W := 420.0
const GAP := 30.0
const TOP := 180.0          # space for the branch header above the nodes
const ROW_H := 150.0
const NODE := Vector2(124, 104)
const WOOD := Color("a86b3c")

var _scroll: ScrollContainer
var _canvas: Control
var _token_btns: Dictionary = {}   # country id -> Button
var _selected := ""
var _detail_title: Label
var _detail_text: Label
var _upgrade: Button
var _press_pos := Vector2.ZERO
var _pressing := false


func _ready() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 0)
	add_child(v)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_scroll)
	_canvas = Control.new()
	var n := Data.COUNTRIES.size()
	_canvas.custom_minimum_size = Vector2(GAP + n * (BRANCH_W + GAP), TOP + 4 * ROW_H + 40)
	_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	_canvas.draw.connect(_draw_tree)
	_canvas.gui_input.connect(_canvas_input)
	_scroll.add_child(_canvas)
	for k in n:
		var cid: String = Data.COUNTRIES[k]["id"]
		var b := UiTheme.button("", 17, UiTheme.GOOD)
		b.position = Vector2(_branch_x(k) + 20, 114)
		b.size = Vector2(BRANCH_W - 40, 50)
		b.pressed.connect(func():
			GameState.buy_token(cid)
			Sfx.play("cash"))
		_canvas.add_child(b)
		_token_btns[cid] = b

	# detail panel for the selected node
	var panel := PanelContainer.new()
	var st := UiTheme.box(UiTheme.PANEL, 0, 16)
	st.border_width_top = 5
	st.border_color = UiTheme.INK
	st.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel", st)
	v.add_child(panel)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 8)
	panel.add_child(dv)
	_detail_title = UiTheme.label("Tap a skill", 24)
	dv.add_child(_detail_title)
	_detail_text = UiTheme.label("Buy tokens for a branch with that country's cash (each token costs x10 more), then spend them on that branch's skills. Skills can boost every city in the world.", 18, UiTheme.MUTED)
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(_detail_text)
	_upgrade = UiTheme.button("", 24, UiTheme.GOOD)
	_upgrade.custom_minimum_size = Vector2(0, 76)
	_upgrade.visible = false
	_upgrade.pressed.connect(func():
		GameState.upgrade_skill(_selected)
		Sfx.play("level_up")
		Sfx.buzz(30))
	dv.add_child(_upgrade)

	# open on the branch of the country you're in
	var k0 := GameState.country_index(GameState.country)
	_scroll.set_deferred("scroll_horizontal", int(maxf(0.0, _branch_x(k0) - GAP)))


func _process(_delta: float) -> void:
	for cid in _token_btns.keys():
		var b: Button = _token_btns[cid]
		if GameState.country_unlocked(cid):
			var price := GameState.token_price(cid)
			b.visible = true
			b.text = "BUY TOKEN   " + GameState.money(price, cid)
			b.disabled = GameState.wallets.get(cid, 0.0) < price
		else:
			b.visible = false
	_refresh_detail()
	_canvas.queue_redraw()


func _branch_x(k: int) -> float:
	return GAP + k * (BRANCH_W + GAP)


func _node_rect(k: int, n: Dictionary) -> Rect2:
	var cols: Array[float] = [0.18, 0.5, 0.82]
	var cx: float = _branch_x(k) + BRANCH_W * cols[int(n["col"])]
	var cy := TOP + 20 + int(n["row"]) * ROW_H + NODE.y * 0.5
	return Rect2(Vector2(cx, cy) - NODE * 0.5, NODE)


func _canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_press_pos = event.position
		elif _pressing:
			_pressing = false
			if event.position.distance_to(_press_pos) > 16.0:
				return
			for k in Data.COUNTRIES.size():
				var cid: String = Data.COUNTRIES[k]["id"]
				for n in Data.SKILL_BRANCHES.get(cid, []):
					if _node_rect(k, n).has_point(event.position):
						_selected = n["id"]
						return


func _draw_tree() -> void:
	var c := _canvas
	var w := c.custom_minimum_size.x
	# the trunk joining every branch
	UiTheme.rounded(c, Rect2(GAP - 4, 12, w - GAP * 2 + 8, 20), WOOD, 10, 3, UiTheme.INK)
	UiTheme.rounded(c, Rect2(GAP + 6, 16, w - GAP * 2 - 12, 5), Color(1, 1, 1, 0.25), 3)
	for k in Data.COUNTRIES.size():
		var cdef: Dictionary = Data.COUNTRIES[k]
		var cid: String = cdef["id"]
		var owned := GameState.country_unlocked(cid)
		var col := Color(cdef["color"])
		var bx := _branch_x(k)
		# branch background + stem from the trunk
		UiTheme.rounded(c, Rect2(bx + BRANCH_W * 0.5 - 8, 26, 16, 46), WOOD, 6, 3, UiTheme.INK)
		var panel_col := col.lightened(0.25) if owned else Color("6b7a99")
		var br := Rect2(bx, 66, BRANCH_W, c.custom_minimum_size.y - 80)
		UiTheme.rounded(c, Rect2(br.position + Vector2(0, 8), br.size), Color(0, 0, 0, 0.18), 26)
		UiTheme.rounded(c, br, Color(panel_col.r, panel_col.g, panel_col.b, 0.42 if owned else 0.3), 26, 4, UiTheme.INK)
		var title := "%s  ·  %d token%s" % [cdef["name"], int(GameState.tokens.get(cid, 0)), "" if int(GameState.tokens.get(cid, 0)) == 1 else "s"]
		UiTheme.text(c, Vector2(bx, 100), title if owned else cdef["name"], 22, Color.WHITE if owned else UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, BRANCH_W, 5)
		if not owned:
			UiTheme.text(c, Vector2(bx, 140), "Unlock %s on the map to grow this branch" % cdef["name"], 16, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, BRANCH_W, 3)
		var nodes: Array = Data.SKILL_BRANCHES.get(cid, [])
		# connections first
		for n in nodes:
			var r := _node_rect(k, n)
			for pid in n["parents"]:
				var pn := GameState.skill_node(pid)
				var pr := _node_rect(k, pn)
				var lit := GameState.skill_level(pid) > 0
				var a := Vector2(pr.get_center().x, pr.end.y)
				var b := Vector2(r.get_center().x, r.position.y)
				c.draw_line(a, b, UiTheme.INK if lit else Color(0.1, 0.1, 0.2, 0.25), 11.0 if lit else 7.0)
				c.draw_line(a, b, Color("ffca28") if lit else Color(1, 1, 1, 0.35), 6.0 if lit else 3.0)
		for n in nodes:
			_draw_node(k, n, owned, col)


func _draw_node(k: int, n: Dictionary, owned: bool, col: Color) -> void:
	var c := _canvas
	var id: String = n["id"]
	var r := _node_rect(k, n)
	var lvl := GameState.skill_level(id)
	var maxed := lvl >= int(n["max"])
	var open := owned and GameState.skill_open(id)
	var can := GameState.can_upgrade_skill(id)
	var bg := Color("5d6a85")
	if maxed:
		bg = Color("f0a020")
	elif lvl > 0:
		bg = col.lightened(0.05)
	elif open:
		bg = Color("3d68c4")
	if can:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
		UiTheme.rounded(c, r.grow(5), Color(0.2, 0.9, 0.4, 0.35 + 0.35 * pulse), 18)
	if id == _selected:
		UiTheme.rounded(c, r.grow(8), Color(1, 1, 1, 0.5), 20)
	UiTheme.rounded(c, Rect2(r.position + Vector2(0, 7), r.size), bg.darkened(0.45), 18, 3, UiTheme.INK)   # chunky lip
	UiTheme.rounded(c, r, bg, 18, 3, UiTheme.INK)
	UiTheme.rounded(c, Rect2(r.position + Vector2(10, 6), Vector2(r.size.x - 20, 8)), Color(1, 1, 1, 0.22), 4)
	var a := 1.0 if open or lvl > 0 else 0.4
	UiTheme.text(c, Vector2(r.position.x + 4, r.position.y + 28), n["name"], 15, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 8, 3)
	UiTheme.text(c, Vector2(r.position.x, r.position.y + 62), "+" + GameState.skill_effect_text(id, maxi(lvl, 1)), 22,
		Color(1, 0.88, 0.5, a) if lvl > 0 else Color(1, 1, 1, 0.35 * a + 0.2), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 4)
	UiTheme.text(c, Vector2(r.position.x, r.position.y + 92), "MAX" if maxed else "Lv %d/%d" % [lvl, int(n["max"])], 15, Color(1, 1, 1, 0.75 * a), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 3)


func _refresh_detail() -> void:
	if _selected == "":
		return
	var n := GameState.skill_node(_selected)
	var lvl := GameState.skill_level(_selected)
	var cdef := GameState.country_def(n["country"])
	_detail_title.text = "%s  (%s branch)  ·  Lv %d/%d" % [n["name"], cdef["name"], lvl, int(n["max"])]
	var now_txt: String = n["desc"] % GameState.skill_effect_text(_selected, lvl)
	var txt := "Now: " + now_txt
	var cost := GameState.skill_cost(_selected)
	if cost > 0:
		txt += "\nNext: " + str(n["desc"]) % GameState.skill_effect_text(_selected, lvl + 1)
	if not GameState.country_unlocked(n["country"]):
		txt += "\nUnlock %s on the map to use this branch." % cdef["name"]
	elif not GameState.skill_open(_selected):
		var names := []
		for p in n["parents"]:
			names.append(GameState.skill_node(p)["name"])
		txt += "\nNeeds Lv 1 in: " + ", ".join(names)
	_detail_text.text = txt
	_upgrade.visible = true
	if cost < 0:
		_upgrade.text = "MAXED"
		_upgrade.disabled = true
	else:
		_upgrade.text = "UPGRADE   %d %s token%s" % [cost, cdef["name"], "" if cost == 1 else "s"]
		_upgrade.disabled = not GameState.can_upgrade_skill(_selected)
