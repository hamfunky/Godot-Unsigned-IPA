extends Node
## Perf probe (not shipped): late-game city, every bay built with a manager, mixed service tiers.
const BayCard = preload("res://scripts/bay_card.gd")
const Crew = preload("res://scripts/bay_crew.gd")

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(1.5).timeout
	var gs = GameState
	gs.tips_enabled = false
	gs.finish_tutorial(true)
	gs.cash = 1e300
	for k in 40:
		if gs.reno_needed() > 0:
			if not gs.reno_running():
				gs.start_renovation()
			gs._cstate("")["reno_until"] = gs.now - 1.0
			gs.unlock_renovation()
		elif gs.next_bay_cost() > 0.0 and gs.cash >= gs.next_bay_cost():
			gs.buy_bay()
		else:
			break
	var lv := [5, 30, 60, 120, 200, 300]
	for i in gs.bays.size():
		gs.bays[i]["level"] = lv[i % lv.size()]
		gs.hire_manager("bay%d" % i)
	gs.hire_manager("valet")
	gs.hire_manager("desk")
	await get_tree().create_timer(2.0).timeout
	var main := get_tree().current_scene
	for sc in main.find_children("*", "Sheet", true, false):
		sc.visible = false
	var scroll: ScrollContainer = main.find_children("*", "ScrollContainer", true, false)[0]
	for pos in [700, 1600]:
		scroll.scroll_vertical = pos
		await get_tree().create_timer(1.0).timeout
		BayCard.prof_draw_us = 0
		BayCard.prof_proc_us = 0
		BayCard.prof_draws = 0
		Crew.prof.clear()
		var t0 := Time.get_ticks_usec()
		var frames := 0
		while Time.get_ticks_usec() - t0 < 6_000_000:
			await get_tree().process_frame
			frames += 1
		var cards := main.find_children("*", "", true, false).filter(func(n): return n.get_script() == BayCard).size()
		print("PERF scroll=%d bays=%d cards=%d frames=%d  draw %.2f ms/frame (%d draws, %.3f ms each)  process %.2f ms/frame" % [
			pos, gs.bays.size(), cards, frames, BayCard.prof_draw_us / 1000.0 / frames, BayCard.prof_draws,
			BayCard.prof_draw_us / 1000.0 / maxf(1, BayCard.prof_draws), BayCard.prof_proc_us / 1000.0 / frames])
	var frames := 30
	for k in Crew.prof:
		print("  %s %.2f ms/frame" % [k, Crew.prof[k] / 1000.0 / float(frames)])
	get_tree().quit()
