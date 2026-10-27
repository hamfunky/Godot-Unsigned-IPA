extends "res://scripts/sheet.gd"
## Opening a Case File, one card at a time (v0.17c): each card arrives face-down (black),
## flips round to show whose dossier it is and the clues it gave, then NEXT moves on to the
## next card. The same manager can come up on two cards. After the last card: a summary.

const Data = preload("res://scripts/game_data.gd")
const Portrait = preload("res://scripts/portrait.gd")

const CARD_SIZE := Vector2(400, 470)

var res: Dictionary = {}
var index := -1               # card being shown
var _masks: Dictionary = {}   # manager id -> clue mask shown so far (grows card by card)
var _holder: CenterContainer
var _card: PanelContainer
var _count: Label
var _btn: Button
var _busy := false


func setup(result: Dictionary) -> void:
	set_finish("carbon")   # v0.19u
	res = result
	var d := GameState.case_def(res["file"])
	set_title("%s" % d.get("name", "Case File"))
	# what each dossier looked like BEFORE this file: take this file's clues back off
	for c in res.get("clues", []):
		var mid := str(c[0])
		if not _masks.has(mid):
			_masks[mid] = int(GameState.manager(mid).get("clues", 0))
		_masks[mid] = int(_masks[mid]) & ~(1 << int(c[1]))
	_count = UiTheme.label("", 19, UiTheme.MUTED)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_count)
	_holder = CenterContainer.new()
	_holder.custom_minimum_size = Vector2(0, CARD_SIZE.y + 20)
	body.add_child(_holder)
	_btn = UiTheme.button("", 26, UiTheme.GOOD)
	_btn.custom_minimum_size = Vector2(0, 80)
	_btn.pressed.connect(next)
	body.add_child(_btn)
	next()


func cards() -> Array:
	return res.get("cards", [])


## Show the next card (face-down, then it flips), or the summary after the last one.
func next() -> void:
	if _busy:
		return
	index += 1
	if index >= cards().size():
		if index == cards().size():
			_summary()
		else:
			close()
		return
	_count.text = "Card %d of %d" % [index + 1, cards().size()]
	_btn.text = "..."
	_btn.disabled = true
	_set_card(_back())
	_busy = true
	var tw := create_tween()
	tw.tween_interval(0.55)
	tw.tween_callback(_flip)


func _flip() -> void:
	_card.pivot_offset = CARD_SIZE * 0.5
	var tw := create_tween()
	tw.tween_property(_card, "scale:x", 0.0, 0.16).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		var c: Dictionary = cards()[index]
		var mid := str(c["id"])
		if mid != "":
			for k in c["clues"]:
				_masks[mid] = int(_masks.get(mid, 0)) | (1 << int(k))
		var front := _front(c)
		_set_card(front)
		front.pivot_offset = CARD_SIZE * 0.5
		front.scale.x = 0.0
		Sfx.play("new_car")
		var tw2 := create_tween()
		tw2.tween_property(front, "scale:x", 1.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw2.tween_callback(func():
			_busy = false
			_btn.disabled = false
			_btn.text = "NEXT CARD" if index < cards().size() - 1 else "SEE RESULTS"))


func _set_card(c: PanelContainer) -> void:
	if _card != null:
		_card.queue_free()
	_card = c
	_holder.add_child(c)


func _base(col: Color, border: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = CARD_SIZE
	var st := UiTheme.card(col, 24, 18, border)   # v0.17f chunky card
	st.border_width_bottom = 12
	st.shadow_color = Color(0, 0, 0, 0.5)
	st.shadow_size = 10
	p.add_theme_stylebox_override("panel", st)
	return p


## Face-down card: black with the file's colour and a big "?".
func _back() -> PanelContainer:
	var d := GameState.case_def(res["file"])
	var fc := Color(d.get("color", "8d6e63"))
	var p := _base(fc.darkened(0.45), UiTheme.INK)
	var draw := Control.new()
	draw.custom_minimum_size = CARD_SIZE - Vector2(46, 46)
	draw.draw.connect(func():
		var sz := draw.size
		for k in 6:
			draw.draw_line(Vector2(0, sz.y * k / 6.0), Vector2(sz.x, sz.y * k / 6.0 + 60), Color(1, 1, 1, 0.07), 18)
		UiTheme.rounded(draw, Rect2(sz.x * 0.5 - 70, sz.y * 0.5 - 90, 140, 150), fc.lightened(0.1), 70, 5, UiTheme.INK)
		UiTheme.text(draw, Vector2(0, sz.y * 0.5 + 40), "?", 130, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, sz.x, 12, UiTheme.DISPLAY_FONT)
		UiTheme.rounded(draw, Rect2(sz.x * 0.5 - 90, sz.y - 46, 180, 38), Color("ff5a5f"), 12, 3, UiTheme.INK)
		UiTheme.text(draw, Vector2(0, sz.y - 18), "CLASSIFIED", 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, sz.x, 5, UiTheme.DISPLAY_FONT))
	p.add_child(draw)
	return p


## Face-up card: the manager (silhouette filled in with the clues found so far), the clues
## this card gave, and the dossier progress.
func _front(c: Dictionary) -> PanelContainer:
	var mid := str(c["id"])
	if mid == "":
		var pc := _base(UiTheme.CARD, Color("80deea"))
		var l := UiTheme.label("Every dossier of that rarity is complete!\n\n+%d Certs" % int(c["certs"]), 24, Color("80deea"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pc.add_child(l)
		return pc
	var m := GameState.manager(mid)
	var rc := Color(GameState.rarity_def(m)["color"])
	var p := _base(rc.darkened(0.3), UiTheme.INK)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var head := UiTheme.ribbon(str(GameState.rarity_def(m)["name"]).to_upper(), 17, rc)
	head.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(head)
	var pc2 := CenterContainer.new()
	v.add_child(pc2)
	var por := Portrait.new()
	por.manager = m
	por.show_state = false
	por.mask = int(_masks.get(mid, 0))
	por.custom_minimum_size = Vector2(150, 164)
	pc2.add_child(por)
	var nm := UiTheme.outlined(UiTheme.display_label(str(m["name"]).to_upper(), 26, Color.WHITE), 7)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nm)
	var n: int = c["clues"].size()
	var big := UiTheme.outlined(UiTheme.display_label("+%d CLUE%s" % [n, "" if n == 1 else "S"], 30, UiTheme.CASH if n < 6 else Color("ffd54f")), 8)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(big)
	var names := []
	for k in c["clues"]:
		names.append(Data.CLUE_NAMES[Data.CLUES[int(k)]])
	var cl := UiTheme.outlined(UiTheme.label(", ".join(names), 18, Color.WHITE), 4)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(cl)
	var have := 0
	for k in Data.CLUES.size():
		if int(_masks.get(mid, 0)) & (1 << k):
			have += 1
	var full := have >= Data.CLUES.size()
	var prog := UiTheme.label("DOSSIER COMPLETE!" if full else "%d / %d clues" % [have, Data.CLUES.size()], 20, UiTheme.CASH if full else Color("e3ecff"))
	UiTheme.outlined(prog, 4)
	prog.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(prog)
	if int(c["certs"]) > 0:
		var ex := UiTheme.label("(+%d Certs for clues they already had)" % int(c["certs"]), 15, Color("80deea"))
		ex.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(ex)
	return p


## After the last card: everything at a glance + total Certs.
func _summary() -> void:
	_count.text = "All cards opened"
	if _card != null:
		_card.queue_free()
		_card = null
	var box := _base(UiTheme.CARD, Color(GameState.case_def(res["file"]).get("color", "8d6e63")))
	box.custom_minimum_size = Vector2(CARD_SIZE.x + 140, 0)
	_holder.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	box.add_child(v)
	var hd := UiTheme.display_label("YOU FOUND", 24, Color.WHITE)
	hd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hd)
	var done := {}
	var per := {}
	var order := []
	for c in cards():
		var mid := str(c["id"])
		if mid == "":
			continue
		if not per.has(mid):
			order.append(mid)
		per[mid] = int(per.get(mid, 0)) + c["clues"].size()
	for mid in order:
		var m := GameState.manager(mid)
		var full := GameState.dossier_done(m)
		if full and not m["owned"]:
			done[mid] = m["name"]
		var l := UiTheme.label("%s  +%d  ·  %s" % [m["name"], int(per[mid]), "DOSSIER COMPLETE!" if full else "%d / %d" % [GameState.clue_count(m), Data.CLUES.size()]],
			23, Color(GameState.rarity_def(m)["color"]).lightened(0.25))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	var ce := UiTheme.label("+%d Certs" % int(res["certs"]), 24, Color("80deea"))
	ce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ce)
	if not done.is_empty():
		var l2 := UiTheme.label("Call %s from their dossier to sign them up." % " and ".join(done.values()), 18, UiTheme.CASH)
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l2)
	_btn.text = "NICE"
	_btn.disabled = false
