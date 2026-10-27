extends Node
## v0.19v dev: screenshots of bays at every service tier (the kit pictures + cached cars). Autoload AS AutoTest, SHOTS=/dir.
const Data = preload("res://scripts/game_data.gd")
const Scenery = preload("res://scripts/scenery.gd")


func _ready() -> void:
	_run.call_deferred()


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOTS") + "/" + n + ".png")
	print("shot ", n)


func _run() -> void:
	var gs = GameState
	var m = get_tree().current_scene
	gs.tips_enabled = false
	gs.popups_need_ok = false
	gs.rain_override = 0
	gs.cotw_enabled = false
	Scenery.hour_override = 13.0
	gs.reset_save()
	await wait(0.5)
	gs.finish_tutorial(true)
	gs.cash = 1e40
	for k in 30:
		if gs.bays.size() >= 11:
			break
		if gs.reno_needed() > 0:
			gs.start_renovation()
			gs._cstate("")["reno_until"] = gs.now - 1.0
			gs.unlock_renovation()
			continue
		gs.buy_bay()
	var lv := [1, 10, 25, 50, 100, 150, 200, 250, 300, 350, 400]
	for i in gs.bays.size():
		gs.buy_levels("bay%d" % i, lv[i] - int(gs.bays[i]["level"]))
		gs.hire_manager("bay%d" % i)
	gs.hire_manager("desk")
	gs.hire_manager("valet")
	for c in m.get_children():
		if c.has_method("clear_body"):
			c.close()
	m._popup.visible = false
	await wait(1.5)
	var sc: ScrollContainer = m._scroll
	for k in 4:
		sc.scroll_vertical = 520 + k * 560
		await wait(1.2)
		await shot("bays_%d" % k)
	get_tree().quit()
