extends Node
## Desk showcase (not shipped, v0.19e): the front desk cashier. Idle -> you tap the desk (she counts the notes,
## then cheers when the till takes them) -> desk Lv 30 (a second cashier) tapped again -> a manager runs it
## (they count non-stop, a happy face per payout, no arm pumps). Record with --write-movie (see station_showcase.gd).

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var gs = GameState
	gs.tips_enabled = false
	await get_tree().create_timer(0.2).timeout
	var main := get_tree().current_scene
	for t in main.find_children("*", "", true, false):
		if t.get_script() != null and str(t.get_script().resource_path).ends_with("title_screen.gd"):
			t.queue_free()
	gs.reset_save()
	await get_tree().create_timer(0.2).timeout
	gs.finish_tutorial(true)
	gs.first_vip_done = true
	gs._first_vip_timer = -1e9
	main._scroll.scroll_vertical = 0
	gs.desk["lot"] = 50.0
	await get_tree().create_timer(2.0).timeout
	gs.tap_desk()
	await get_tree().create_timer(4.0).timeout
	gs.desk["level"] = 30
	gs.desk["lot"] = 500.0
	await get_tree().create_timer(1.0).timeout
	gs.tap_desk()
	await get_tree().create_timer(4.0).timeout
	var m: Dictionary = gs._make_manager("desk", 1, gs.active_city)
	m["city"] = gs.active_city
	m["assigned"] = "desk"
	gs.managers.append(m)
	gs._rebuild_assigned()
	gs.desk["lot"] = 1e6
	await get_tree().create_timer(5.0).timeout
	get_tree().quit()
