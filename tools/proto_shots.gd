extends Node
## v0.19v dev: screenshots of the main screen for design prototypes (autoload AS AutoTest, SHOTS=/dir).
const Data = preload("res://scripts/game_data.gd")
const Scenery = preload("res://scripts/scenery.gd")


func _ready() -> void:
	_run.call_deferred()


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OS.get_environment("SHOTS") + "/" + n + ".png")
	print("shot ", n)


func _run() -> void:
	var gs = GameState
	var m = get_tree().current_scene
	gs.tips_enabled = false
	gs.popups_need_ok = false
	gs.rain_override = 0
	gs.cotw_enabled = false
	gs.reset_save()
	await wait(0.5)
	gs.finish_tutorial(true)
	gs.cash = 1e12
	for k in 6:
		if gs.reno_needed() > 0:
			gs.start_renovation()
			gs._cstate("")["reno_until"] = gs.now - 1.0
			gs.unlock_renovation()
			continue
		gs.buy_bay()
	for key in ["desk", "valet", "bay0", "bay1"]:
		gs.hire_manager(key)
	gs.cash = 4.2e6
	for c in m.get_children():
		if c.has_method("clear_body"):
			c.close()
	m._popup.visible = false
	gs.settings["ad_free"] = false   # what a normal player sees (the ad badge)
	for h in [22.5, 13.0]:
		Scenery.hour_override = h
		gs.ad_boost_until = 0.0
		await wait(1.6)
		await shot("proto_main_%d" % int(h))
	gs.ad_boost_until = gs.now + 15.5 * 3600.0
	gs.wheel_free_at = gs.now + 5 * 3600.0
	await wait(1.2)
	await shot("proto_main_running")
	get_tree().quit()
