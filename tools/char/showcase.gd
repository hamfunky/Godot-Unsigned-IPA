extends Node
## Showcase recording (not shipped): a few bays at different services, Bay 1 manual (tapped), the rest run by managers.

func _ready() -> void:
	_run.call_deferred()

func _close() -> void:
	var main := get_tree().current_scene
	for c in main.get_children():
		if c.has_method("clear_body"):
			c.close()
	if "_popup" in main:
		main._popup.visible = false
	GameState.vip = {}
	for l in main.find_children("*", "Label", true, false):
		if l.text.begins_with("RARE CAR") or l.text.begins_with("Detroit is open"):
			var n: Node = l
			while n.get_parent() != main and n.get_parent() != null:
				n = n.get_parent()
			if n is CanvasItem:
				n.visible = false

func _run() -> void:
	var gs = GameState
	gs.tips_enabled = false
	await get_tree().create_timer(0.3).timeout
	var main := get_tree().current_scene
	if main.has_method("_on_title_done"):
		pass
	for t in main.find_children("*", "", true, false):
		if t.get_script() != null and str(t.get_script().resource_path).ends_with("title_screen.gd"):
			t.queue_free()
	gs.finish_tutorial(true)
	gs.first_vip_done = true
	gs._first_vip_timer = -1e9
	gs.cash = 1e40
	for k in 6:
		if gs.reno_needed() > 0:
			if not gs.reno_running():
				gs.start_renovation()
			gs._cstate("")["reno_until"] = gs.now - 1.0
			gs.unlock_renovation()
		gs.buy_bay()
	var lv := [5, 12, 45, 120, 160, 260]
	for i in gs.bays.size():
		gs.bays[i]["level"] = lv[mini(i, lv.size() - 1)]
		if i > 0:
			gs.hire_manager("bay%d" % i)
	gs.hire_manager("valet")
	gs.hire_manager("desk")
	gs.cash = 1e40
	await get_tree().create_timer(0.5).timeout
	_close()
	var scroll: ScrollContainer = main.find_children("*", "ScrollContainer", true, false)[0]
	scroll.scroll_vertical = 330
	while true:
		await get_tree().create_timer(0.1).timeout
		_close()
		if not gs.bays[0]["running"]:
			gs.tap_bay(0)
