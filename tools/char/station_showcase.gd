extends Node
## Station showcase (not shipped, v0.19): the posh cash managers in the real stations. Front desk Executive,
## valet Senior (faces left), Bays 1-3 Junior / Senior / Executive. Idle 2.5 s -> every ability on (instruct +
## suds aura) 6 s -> abilities end, they settle back 3.5 s. Record with:
##   godot --path <p> --resolution 720x1280 --write-movie out.avi --fixed-fps 30 --quit-after 400
## (copy to tests/ and add it as an autoload first, like the autotest).

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
	gs.cash = 1e15
	gs.buy_bay()
	gs.buy_bay()
	var plan := [["desk", "desk", 2, "upsell"], ["valet", "valet", 1, "lead_foot"], ["bay0", "bay", 0, "trade_prices"],
		["bay1", "bay", 1, "foam_party"], ["bay2", "bay", 2, "elbow_grease"]]
	var men := []
	for p in plan:
		var m: Dictionary = gs._make_manager(p[1], p[2], gs.active_city)
		m["ability"] = p[3]
		m["city"] = gs.active_city
		m["assigned"] = p[0]
		gs.managers.append(m)
		men.append(m)
	gs._rebuild_assigned()
	main._scroll.scroll_vertical = 0
	await get_tree().create_timer(2.5).timeout
	# tap each soap-bubble ability button (v0.19d), one after the other, so the pop shows
	var icons := main.find_children("*", "Control", true, false).filter(func(n): return n.get_script() == load("res://scripts/ability_icon.gd"))
	for ic in icons:
		ic.use()
		await get_tree().create_timer(0.25).timeout
	await get_tree().create_timer(6.0).timeout
	for m in men:
		m["active_until"] = gs.now - 1.0      # over: the bubbles go small + grey while they recharge
	await get_tree().create_timer(3.5).timeout
	get_tree().quit()
