extends "res://scripts/sheet.gd"
## Hometown Garage run: stage, goals and their rewards (claim them here), and
## START NEXT RUN once the run is finished. Opened by tapping the shop sign.

const Data = preload("res://scripts/game_data.gd")

var _sig := ""


func setup() -> void:
	_build()


func _process(_delta: float) -> void:
	var sig := _signature()
	if sig != _sig:
		_build()


func _signature() -> String:
	return "%d|%d|%d|%d|%s|%d|%d" % [GameState.ht_run(), GameState.ht_stage(), GameState.ht_bays_built(), GameState.ht_claimable(),
		str(GameState.hometown.get("claimed", [])).length(), GameState.level_of("valet"), GameState.level_of("desk")]


func _build() -> void:
	_sig = _signature()
	clear_body()
	set_title("Hometown Garage  ·  Run %d" % GameState.ht_run())
	var stage: Dictionary = Data.HOMETOWN_STAGES[GameState.ht_stage()]
	var info := UiTheme.label("%s  ·  %d / %d bays  ·  Max every bay (Lv %d), the Valet and Front Desk (Lv %d) to finish the run." % [
		stage["name"], GameState.ht_bays_built(), GameState.ht_cap(), Data.HOMETOWN_BAY_TARGET, GameState.ht_vd_target()], 18, UiTheme.MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(info)

	var ms := GameState.ht_milestones()
	var claimable := ms.filter(func(m): return m["done"] and not m["claimed"])
	if GameState.ht_run_finished():
		var nxt := GameState.ht_run() + 1
		var cap: int = Data.HOMETOWN_RUN_BAYS[mini(nxt - 1, Data.HOMETOWN_RUN_BAYS.size() - 1)]
		var l := UiTheme.label("Run %d finished! The next run starts again from a dirt lot, with %d bays and bigger rewards." % [nxt - 1, cap], 19, UiTheme.GOOD)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(l)
		var b := UiTheme.button("START RUN %d" % nxt, 26, UiTheme.GOOD)
		b.custom_minimum_size = Vector2(0, 84)
		b.pressed.connect(func():
			if not GameState.ht_run_finished():
				return
			Sfx.play("big_win")
			var main := get_tree().current_scene
			if main.has_method("with_loading"):   # v0.19w: a new run is a big change: under the loading card
				main.with_loading(GameState.ht_start_next_run, Data.HOMETOWN_ID, "Run %d" % nxt)
			else:
				GameState.ht_start_next_run()
			close())
		body.add_child(b)
		return
	if claimable.size() > 1:
		var all := UiTheme.button("CLAIM ALL  (%d)" % claimable.size(), 24, Color("ffb300"))
		all.custom_minimum_size = Vector2(0, 72)
		all.pressed.connect(func():
			if GameState.claim_all_milestones() > 0:
				Sfx.play("big_win"))
		body.add_child(all)
	for m in claimable:
		_row(m, true)
	# the next few goals, then the big one at the end
	var todo := ms.filter(func(m): return not m["done"] and m["id"] != "run")
	if not todo.is_empty():
		body.add_child(UiTheme.ribbon("NEXT GOALS", 16, Color("2f9bff")))
	for m in todo.slice(0, 4):
		_row(m, false)
	var fin: Dictionary = ms[-1]
	if not fin["done"]:
		body.add_child(UiTheme.ribbon("END OF RUN", 16, Color("e0a000")))
		_row(fin, false)


func _row(m: Dictionary, can_claim: bool) -> void:
	var big: bool = m["id"] == "run"
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.card(UiTheme.CARD, 12, 10, UiTheme.CARD_GOLD if (can_claim or big) else Color(0, 0, 0, 0)))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	body.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 1)
	h.add_child(v)
	v.add_child(UiTheme.label(m["name"], 21 if big else 19, UiTheme.CASH if big else UiTheme.TEXT))
	if not can_claim and m["progress"] != "":
		v.add_child(UiTheme.label(m["progress"], 16, UiTheme.MUTED))
	var r := UiTheme.label(GameState.reward_text(m["reward"]), 16, Color("80deea"))
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(r)
	if can_claim:
		var b := UiTheme.button("CLAIM", 20, UiTheme.GOOD)
		b.custom_minimum_size = Vector2(130, 60)
		var id: String = m["id"]
		b.pressed.connect(func():
			if GameState.claim_milestone(id):
				Sfx.play("big_win"))
		h.add_child(b)
