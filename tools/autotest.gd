extends Node
## Automated playtest: drives the game, checks the economy chain, saves screenshots.

const Data = preload("res://scripts/game_data.gd")

var fails := 0
var shots_dir := ""


func _ready() -> void:
	shots_dir = OS.get_environment("SHOTS")
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		fails += 1
		print("  FAIL ", msg)


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func shot(name: String) -> void:
	if shots_dir == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shots_dir + "/" + name + ".png")
	print("  shot ", name, " ", img.get_size())


func close_sheets() -> void:
	for c in main_node().get_children():
		if c.has_method("clear_body"):
			c.close()


## Hand over a premium manager's whole dossier and sign them (test shortcut).
func own(id: String) -> Dictionary:
	var m: Dictionary = GameState.roster[id]
	m["clues"] = 63
	m["owned"] = true
	return m


## Build every bay the city allows, finishing renovations instantly (test shortcut).
func build_all() -> void:
	var gs = GameState
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


func main_node() -> Node:
	return get_tree().current_scene


func _run() -> void:
	var gs = GameState
	gs.tips_enabled = false   # v0.17h one-time tips stay out of the way (tested in _v17h_checks)
	gs.popups_need_ok = false   # v0.19j: messages fade by themselves like before (OK buttons tested in _v19j_checks)
	gs.rain_override = 0        # v0.19t: no rainy days (they change bay pay) unless a check asks for one
	gs.cotw_enabled = false     # v0.19t: nor a Car of the Week
	preload("res://scripts/scenery.gd").hour_override = 13.0   # v0.19t: screenshots in daylight unless a check asks
	gs.reset_save()
	await wait(0.6)

	print("tutorial")
	check(gs.tutorial_step == 0, "new game starts tutorial")
	await shot("t1_wash")
	gs.tap_bay(0)
	await wait(4.4)
	check(gs.tutorial_step == 1, "after wash -> valet step")
	await shot("t2_valet")
	gs.tap_valet()
	await wait(0.2)
	check(gs.tutorial_step == 2, "after valet -> desk step")
	await wait(5.5)   # v0.17g: calmer valet (+ v0.19p visible loading)
	await shot("t3_desk")
	var tf_done := [false]
	var tcb_done := func(): tf_done[0] = true
	gs.tutorial_finished.connect(tcb_done)
	gs.tap_desk()
	await wait(3.3)
	check(gs.tutorial_step == gs.TUT_DONE and tf_done[0], "v0.17g: first cash ends the tutorial (good to go!)")
	gs.tutorial_finished.disconnect(tcb_done)
	await wait(0.3)
	await shot("t4_good_to_go")
	gs.tutorial_step = gs.TUT_HIRE_VALET   # an old save sitting on a removed step just finishes
	await wait(0.2)
	check(gs.tutorial_step == gs.TUT_DONE, "old saves on the removed hiring steps finish quietly")
	await wait(2.0)
	gs.reset_save()
	gs.tutorial_step = gs.TUT_DONE
	await wait(0.3)
	await shot("01_new_game")

	print("manual chain")
	gs.tap_bay(0)
	gs.tap_bay(0)
	await wait(4.4)
	check(gs.bays[0]["ready"] > 0.0, "bay 0 produced cars by tapping (ready=%s)" % gs.bays[0]["ready"])
	gs.tap_valet()
	await wait(0.3)
	gs.tap_valet()   # a 2nd tap while it's out must not queue another run
	check(not gs.valet["requested"], "tap while the valet is out is ignored")
	await wait(5.3)   # v0.17g: the valet drives calmer (1.8s per bay); v0.19p: loading takes 0.9s
	check(gs.desk["lot"] > 0.0, "valet delivered to lot (lot=%s)" % gs.desk["lot"])
	gs.tap_bay(0)
	await wait(4.4)
	check(gs.valet["phase"] == "idle" and gs.bays[0]["ready"] > 0.0, "valet did one run per tap (waits for the next tap)")
	await shot("02_manual_lot")
	gs.tap_desk()
	await wait(3.3)
	check(gs.cash > 0.0, "desk turned lot into cash (cash=%s)" % gs.cash)
	# v0.17c: valet + desk always do their run, even with nothing to carry / count
	for b in gs.bays:
		b["ready"] = 0.0
	gs.desk["lot"] = 0.0
	var cash_e: float = gs.cash
	gs.tap_valet()
	await wait(0.2)
	check(gs.valet["phase"] != "idle", "valet drives even when nothing is ready (phase %s)" % gs.valet["phase"])
	gs.tap_desk()
	await wait(0.2)
	check(gs.desk["running"], "desk counts even an empty lot")
	await wait(3.5)
	check(not gs.desk["running"] and gs.cash == cash_e, "empty count pays $0")

	print("managers + levels")
	gs.cash = 5000.0
	var m = gs.hire_manager("bay0")
	check(not m.is_empty() and gs.is_automated("bay0"), "hired bay manager auto-assigned")
	gs.hire_manager("valet")
	gs.hire_manager("desk")
	check(gs.is_automated("valet") and gs.is_automated("desk"), "valet + desk automated")
	gs.cash = 1e6
	gs.buy_bay(); gs.buy_bay(); gs.buy_bay()
	check(gs.bays.size() == 4, "built bays (now %d)" % gs.bays.size())
	gs.hire_manager("bay1"); gs.hire_manager("bay2"); gs.hire_manager("bay3")
	var n := gs.levels_for_mode("bay0", "next")
	check(n == 9, "next boost from lv1 is 9 levels (got %d)" % n)
	var c10 := gs.levels_cost("bay0", 10)
	var manual := 0.0
	for k in 10:
		manual += 12.0 * pow(1.10, k)
	check(absf(c10 - manual) < 0.01, "x10 cost matches sum (%.2f vs %.2f)" % [c10, manual])
	gs.buy_levels("bay0", n)
	check(gs.level_of("bay0") == 10, "bay0 reached lv10")
	check(gs.current_boost("bay0")["name"] == "Foam Cannon", "boost name at lv10")
	var nmax := gs.levels_for_mode("valet", "max")
	var cmax := gs.levels_cost("valet", nmax)
	check(cmax <= gs.cash and gs.levels_cost("valet", nmax + 1) > gs.cash, "max mode buys as many as affordable (%d)" % nmax)
	gs.buy_levels("valet", 40)
	gs.buy_levels("desk", 40)
	for i in 4:
		gs.buy_levels("bay%d" % i, 20)
	var cash_before: float = gs.cash
	await wait(25.0)   # v0.17c: the first loops can be empty runs
	check(gs.cash > cash_before, "automated chain earns (+%s)" % gs.fmt(gs.cash - cash_before))
	check(gs.idle_income() > 0.0, "idle income %s/s, bottleneck %s" % [gs.fmt(gs.idle_income()), gs.bottleneck()])
	await shot("03_automated")

	print("abilities")
	var mb = gs.manager_at("bay0")
	var before_inc: float = gs.bay_income(0)
	gs.activate_ability("bay0")
	check(gs.ability_active(mb), "ability active")
	var kind: String = gs.ability_def(mb)["kind"]
	if kind == "income" or kind == "speed":
		check(gs.bay_income(0) > before_inc, "%s ability raises bay income" % kind)
	else:
		check(gs.ability_discount("bay0") > 0.0, "discount ability lowers costs")
	check(not gs.ability_ready(mb), "ability on cooldown after use")

	print("crew chain")
	var mv = gs.manager_at("valet")
	var md = gs.manager_at("desk")
	mb["crew"] = "euro"; mv["crew"] = "euro"; md["crew"] = "euro"
	check(gs.bay_crew_bonus(0) == 1.5, "bay crew chain x1.5")
	check(gs.pair_crew_bonus() == 1.25, "valet/desk pair x1.25")
	md["crew"] = "jdm"
	check(gs.bay_crew_bonus(0) == 1.0, "chain breaks when desk differs")
	md["crew"] = "euro"

	print("assign/swap")
	gs.cash = 1e9
	var extra = gs.hire_manager("bay0")
	check(extra["assigned"] == "", "second bay hire is free (not replacing)")
	gs.assign_manager(extra["id"], "bay0")
	check(gs.manager_at("bay0")["id"] == extra["id"], "swap assigned new manager")
	check(mb["assigned"] == "", "old manager freed")

	print("ui panels")
	var main := main_node()
	main._open_level_panel("bay0")
	await wait(0.3)
	await shot("04_level_panel")
	close_sheets()
	main._open_manager_panel("bay0")
	await wait(0.3)
	await shot("05_manager_panel")
	close_sheets()
	main._open_manager_panel("valet")
	await wait(0.3)
	await shot("06_manager_valet")
	close_sheets()
	main._open_shop()
	await wait(0.3)
	await shot("07_shop")
	for c in main.get_children():
		if c.has_method("clear_body"):
			var xr: Rect2 = c._title.get_parent().get_child(1).get_global_rect()
			check(xr.position.y >= 0.0 and c._panel.get_global_rect().end.y <= 1281.0, "shop fits on screen, X visible (y=%d)" % xr.position.y)
			c._sheet_scroll.scroll_vertical = 100000
	await wait(0.3)
	await shot("07b_shop_scrolled")
	close_sheets()
	await wait(0.2)

	print("save/load")
	gs.save_game()
	var lv: int = gs.level_of("bay2")
	var nm: int = gs.managers.size()
	var lot: float = gs.desk["lot"] + gs.desk["batch"] + gs.valet["carried"]
	gs.bays[2]["level"] = 1
	gs.load_game()
	check(gs.level_of("bay2") == lv, "bay level restored")
	check(gs.managers.size() == nm, "managers restored (%d)" % nm)
	check(gs.manager_at("bay0")["id"] == extra["id"], "assignment restored")
	check(absf(gs.desk["lot"] - lot) < 1.0, "carried value kept in lot")

	print("v1 migration")
	var f := FileAccess.open("user://save.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "saved_at": Time.get_unix_time_from_system(), "cash": 1234.0,
		"bays": [{"service": 1, "staffed": true}, {"service": 0, "staffed": false}],
		"unlocked_services": [true, true, false, false], "upgrade_levels": {"speed": 3}}))
	f.close()
	gs._reset_state()
	gs.load_game()
	check(gs.cash == 1234.0 and gs.bays.size() == 2, "v1 cash + bays kept")
	check(gs.is_automated("bay0") and not gs.is_automated("bay1"), "v1 staffed bay -> manager")
	check(gs.is_automated("valet") and gs.is_automated("desk"), "v1 staffed -> valet/desk managers")
	gs.state_changed.emit()

	print("v0.3: cars, book, reputation, VIP, premium")
	gs.reset_save()
	gs.tutorial_step = gs.TUT_DONE
	await wait(0.2)
	check(gs.cars_by_id.has(gs.bays[0]["car"]), "bay 0 has a real car (%s)" % gs.bays[0]["car"])
	check(gs.car_def(gs.bays[0]["car"])["tier"] == 1, "bay 0 gets tier-1 bombs")
	check(gs.gloss == 25, "start gloss 25")
	gs.cash = 1e7
	gs.hire_manager("bay0"); gs.hire_manager("valet"); gs.hire_manager("desk")
	gs.cash = 1e9
	gs.buy_bay(); gs.buy_bay(); gs.buy_bay(); gs.buy_bay()
	check(gs.car_def(gs.bays[4]["car"])["tier"] == 2, "bay 5 gets tier-2 daily drivers")
	gs.cash = 1e7
	var first_car: String = gs.bays[0]["car"]
	gs.tap_bay(0)
	await wait(4.4)
	check(gs.book.has(first_car), "finished car logged in Book")
	check(gs.followers >= 1.0 and gs.followers < 5.0, "new car gave a few followers (%s)" % gs.followers)
	# customer mix
	var jdm = gs.cars_by_id.values().filter(func(c): return c["class"] == "jdm" and not c.get("vip", false)).slice(0, 3)
	for c in jdm:
		gs.book[c["id"]] = 1
		gs.toggle_display(c["id"])
	check(gs.display.size() == 3, "3 cars on display")
	check(absf(gs.class_share("jdm") - 4.0 / 10.0) < 0.001, "JDM share 4/10 in the USA (muscle-loving) (%.3f)" % gs.class_share("jdm"))
	var extra_id: String = gs.cars_by_id.values().filter(func(c): return c["class"] == "euro")[0]["id"]
	gs.book[extra_id] = 1
	gs.toggle_display(extra_id)
	check(gs.display.size() == 3, "can't exceed display slots")
	var picks = {}
	for k in 700:
		var cl: String = gs.car_def(gs._pick_car(0))["class"]
		picks[cl] = picks.get(cl, 0) + 1
	check(picks.get("jdm", 0) > 230, "display steers customers to JDM (%d/700, base would be 100)" % picks.get("jdm", 0))
	# specialist
	var mb3: Dictionary = gs.manager_at("bay0")
	gs.manager_at("valet")["crew"] = "muscle"   # keep the crew chain bonus out of this test
	gs.manager_at("desk")["crew"] = "offroad"
	gs.bays[0]["car"] = jdm[0]["id"]
	mb3["crew"] = "euro"
	var p_off: float = gs.bay_pay_per_car(0)
	mb3["crew"] = "jdm"
	check(absf(gs.bay_pay_per_car(0) / p_off - 1.5) < 0.001, "JDM specialist x1.5 on JDM car")
	# premium
	gs.gloss = 900
	gs.buy_display_slot()
	check(gs.display_slots() == 4 and gs.gloss == 750, "bought a display slot")
	# stars
	var g0: int = gs.gloss
	gs.add_followers(700.0)
	check(gs.stars() >= 3 and gs.gloss > g0, "stars up + gloss (%d stars)" % gs.stars())
	check(gs.reputation_mult() > 1.0, "stars boost income x%.2f" % gs.reputation_mult())
	# tier set (v0.19k: only once the Book has been opened)
	var g1: int = gs.gloss
	for c in gs.cars_by_id.values():
		if c["tier"] == 1:
			gs.log_car(c["id"])
	check(not gs.tiers_done.has(1) and gs.gloss == g1, "tier-1 set waits until the Book has been opened")
	gs.open_book_first()
	check(gs.tiers_done.has(1) and gs.gloss >= g1 + 50, "tier-1 set complete gives gloss")
	check(gs.book_set_mult() > 1.0, "set gives income bonus")
	# VIP
	for i in gs.bays.size():
		if not gs.is_automated("bay%d" % i):
			gs.hire_manager("bay%d" % i)
	check(gs.vip_pool().all(func(c): return c.get("country", "usa") == "usa") and gs.vip_pool().size() == 6, "USA has its own 6 rare cars")
	var countries := {}
	for c in Data.VIP_CARS:
		countries[c.get("country", "")] = int(countries.get(c.get("country", ""), 0)) + 1
	check(countries.size() == 5 and not countries.has(""), "every rare car belongs to one of the 5 countries %s" % str(countries))
	gs.spawn_vip(false, 0)
	check(gs.car_def(gs.vip["id"])["rarity"] == 0 and gs.car_def(gs.vip["id"]).get("country", "") == "usa", "first VIP can be forced to a plain USA Rare")
	gs.vip = {}
	gs.spawn_vip()
	check(not gs.vip.is_empty() and gs.vip["phase"] == "lot", "VIP waiting in lot")
	await wait(0.6)
	await shot("12_vip_alert")
	main_node()._scroll.scroll_vertical = 600
	for b in main_node()._banner.find_children("*", "Button", true, false):
		if b.text == "GO TO CAR":
			b.pressed.emit()
	await wait(0.6)
	check(main_node()._scroll.scroll_vertical == 0 and not main_node()._banner.visible, "GO TO CAR scrolls to the top while the car waits in the lot")
	await wait(0.2)
	await shot("13_vip_lot")
	var vb = int(gs.vip["bay"])
	gs.send_vip()
	check(gs.vip_in_bay(vb), "VIP moved to bay %d" % (vb + 1))
	main_node()._scroll_to_bay(vb)
	await wait(1.5)
	await shot("14_vip_bay")
	var vid: String = gs.vip["id"]
	var pay_before: float = gs.vip_pay()
	var mvv: Dictionary = gs.manager_at("bay%d" % vb)
	mvv["ability"] = "foam_party"; mvv["ready_at"] = 0.0
	gs.activate_ability("bay%d" % vb)
	check(gs.vip_pay() > pay_before * 1.9, "income boost raises VIP pay ($%s -> $%s)" % [gs.fmt(pay_before), gs.fmt(gs.vip_pay())])
	var c0: float = gs.cash
	var f0: float = gs.followers
	var expect: float = gs.vip_pay()
	gs.vip["progress"] = 0.97
	await wait(1.0)
	check(gs.vip.is_empty(), "VIP finished")
	check(gs.cash - c0 >= expect * 0.99, "VIP paid out ($%s)" % gs.fmt(gs.cash - c0))
	check(gs.followers > f0 and gs.book.has(vid), "VIP gave followers + logged")
	gs.spawn_vip()
	var v2: String = gs.vip["id"]
	gs.vip = {}
	gs.book[v2] = 1
	var alerted = [false]
	var cb = func(car, alert): alerted[0] = alert
	gs.vip_arrived.connect(cb)
	for k in 50:
		gs.vip = {}
		gs.spawn_vip()
		if gs.vip["id"] == v2:
			break
	if gs.vip["id"] == v2:
		check(alerted[0] == false, "no banner for a VIP already in your Book")
	gs.vip_arrived.disconnect(cb)
	gs.vip = {}
	# save/load v3
	gs.spawn_vip()
	gs.save_game()
	var snap = [gs.followers, gs.gloss, gs.book.size(), gs.display.duplicate(), gs.vip["id"], gs.tiers_done.duplicate()]
	gs._reset_state()
	gs.load_game()
	check(absf(gs.followers - snap[0]) < 0.01 and gs.gloss == snap[1], "followers + gloss saved")
	check(gs.book.size() == snap[2] and gs.display == snap[3], "book + display saved")
	check(gs.vip.get("id", "") == snap[4] and gs.tiers_done == snap[5], "VIP + sets saved")
	# v2 save with old stance crew
	var f2 = FileAccess.open("user://save.json", FileAccess.WRITE)
	f2.store_string(JSON.stringify({"version": 2, "saved_at": Time.get_unix_time_from_system(), "cash": 5.0,
		"bays": [{"level": 3}], "managers": [{"id": 1, "name": "Kev", "area": "bay", "rarity": 0, "ability": "foam_party", "crew": "stance", "assigned": "bay0"}]}))
	f2.close()
	gs._reset_state()
	gs.load_game()
	check(gs.manager_at("bay0")["crew"] == "offroad", "old stance crew -> 4x4 crew")
	check(gs.gloss == 25 and gs.cars_by_id.has(gs.bays[0]["car"]), "v2 save gets gloss + cars")
	gs.state_changed.emit()
	gs.cash = 1e9
	gs.gloss = 800
	await wait(0.3)
	var logged = 0
	for c in gs.cars_by_id.values():
		if c["tier"] <= 2 and logged < 13:
			gs.book[c["id"]] = 2
			logged += 1
	gs.book["adventurdor"] = 1
	gs.toggle_display("adventurdor")
	for id in gs.book.keys():
		if gs.display.size() < 3:
			gs.toggle_display(id)
	gs.add_followers(1500.0)
	main_node()._open_book()
	await wait(0.4)
	await shot("15_book")
	var bp = null
	for c in main_node().get_children():
		if c.has_method("_show_page"):
			bp = c
	check(bp != null and bp._tiles.size() == 6, "v0.17g: Book front page = 6 category tiles")
	bp._show_page(1)
	await wait(0.4)
	await shot("15a_book_bombs")
	bp._show_page(6)
	await wait(0.4)
	await shot("15b_book_rare")
	close_sheets()
	main_node()._open_shop()
	await wait(0.3)
	await shot("16_shop")
	close_sheets()
	await wait(0.2)

	print("v0.5: no tap rush, valet speed, ute, till, workshops")
	gs.reset_save()
	gs.tutorial_step = gs.TUT_DONE
	await wait(0.2)
	gs.tap_bay(0)
	for k in 10:
		gs.tap_bay(0)
	await wait(1.0)
	check(gs.bays[0]["progress"] < 0.35, "extra taps don't speed up the wash (progress %.2f after 1s of 4s)" % gs.bays[0]["progress"])
	check(absf(gs.valet_speed(1) - 1.0) < 0.001 and absf(gs.valet_speed(49) - gs.valet_speed(25)) < 0.001 and absf(gs.valet_speed(50) - 1.98) < 0.001,
		"v0.17g: valet driving speed only steps up at boost levels (Lv 25-49 same, Lv 50 = x1.98)")
	check(absf(gs.valet_load_speed(51) - 2.0) < 0.001, "loading still gets +2% every level (x2 at Lv51)")
	var worst := 1e9
	var best := 0.0
	for vl in [1, 9, 10, 24, 25, 49, 50, 99, 149, 249, 399]:
		for nb in [1, 5, 20]:
			var old_trip: float = (2.0 * nb * 1.2 + nb * 0.25 + 0.5) / (1.0 + 0.02 * (vl - 1))
			var old_rate: float = gs.valet_capacity(vl) / gs.valet_cap_comp(vl) / old_trip
			var new_trip: float = 2.0 * nb * Data.VALET_FLOOR_TIME / gs.valet_curve(gs.valet_step_level(vl)) + (nb * Data.VALET_LOAD_TIME + 0.5) / gs.valet_curve(vl)
			var ratio: float = gs.valet_capacity(vl) / new_trip / old_rate
			worst = minf(worst, ratio)
			best = maxf(best, ratio)
	check(worst >= 0.999 and best < 1.21, "calmer valet (+ v0.19p visible loading) moves the same money or a little more (x%.3f .. x%.3f of v0.17f)" % [worst, best])
	gs.cash = 1e6
	gs.hire_manager("valet"); gs.hire_manager("desk"); gs.hire_manager("bay0")
	gs.buy_bay(); gs.buy_bay()
	var ute_shots = [[0.0, "u0_empty"], [0.2, "u1_quarter"], [0.5, "u2_half"], [0.7, "u3_almost"], [1.0, "u4_overflow"]]
	gs.valet["phase"] = "down"
	gs.valet["pos"] = 1.0
	for us in ute_shots:
		gs.valet["carried"] = us[0] * gs.valet_capacity()
		await wait(0.1)
		var img = get_viewport().get_texture().get_image()
		if shots_dir != "":
			await RenderingServer.frame_post_draw
			img = get_viewport().get_texture().get_image()
			img.get_region(Rect2i(0, 300, 330, 300)).save_png(shots_dir + "/" + us[1] + ".png")
	gs.valet["carried"] = 0.0
	gs.valet["phase"] = "idle"
	gs.valet["pos"] = 0.0
	gs.desk["lot"] = 0.0
	gs.desk["running"] = true
	gs.desk["batch"] = 100.0
	for pr in [[0.5, "d1_counting"], [0.93, "d2_till_open"]]:
		gs.desk["progress"] = pr[0]
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		if shots_dir != "":
			get_viewport().get_texture().get_image().get_region(Rect2i(0, 120, 720, 210)).save_png(shots_dir + "/" + pr[1] + ".png")
	gs.desk["progress"] = 0.0
	# ---- v0.6 world: cities, countries, prestige, background earning
	print("v0.6 world")
	gs.reset_save()
	gs.tutorial_step = gs.TUT_DONE
	await wait(0.2)
	check(gs.active_city == "lima" and gs.country == "usa" and gs.money(5.0) == "$5", "start in Lima, USD")
	gs.cash = 1e9
	gs.hire_manager("bay0"); gs.hire_manager("valet"); gs.hire_manager("desk")
	gs.buy_bay()
	gs.buy_levels("bay0", 30); gs.buy_levels("valet", 30); gs.buy_levels("desk", 30)
	var lima_rate = gs.idle_income()
	check(lima_rate > 0.0, "Lima earns idle %s/s" % gs.money(lima_rate))
	gs.followers = 600.0
	gs.book["corollo98"] = 3
	# v0.17g: no city needed; the 1st prestige costs the same as the next city
	var pc = gs.prestige_cost("lima")
	check(absf(pc - float(Data.CITY_UNLOCK_OVERRIDE["detroit"])) < 1.0, "Lima prestige 1 costs %s (= Detroit)" % gs.money(pc))
	check(gs.prestige_needs("lima") == "", "prestige needs no other city")
	# unlock Detroit
	var dc = gs.city_unlock_cost("detroit")
	check(absf(dc - 4.0e9) < 1.0, "Detroit unlock costs %s (fixed price)" % gs.money(dc))
	check(absf(gs.city_unlock_cost("miami") + 1.0) < 0.01, "only the next city has a price")
	check(gs.city_unlock_cost("miami") < 0.0, "can't skip to Miami")
	gs.cash = dc * 4.0
	gs.unlock_city("detroit")
	await wait(0.3)
	check(gs.active_city == "detroit" and gs.bays.size() == 1, "now in Detroit, fresh shop")
	check(gs.managers_in_area("bay").is_empty(), "Lima's cash managers not usable in Detroit")
	check(absf(gs.hire_cost("bay") - 100.0) < 0.01, "Detroit hire costs x10 ($100)")
	gs.tutorial_step = gs.TUT_DONE
	await shot("c1_detroit")
	var usd0 = gs.cash
	await wait(2.5)
	# v0.19v: a city you're not in saves what it makes in its own stash (COLLECT on the map)
	check(gs.stash_of("lima") > lima_rate * 1.5 and gs.cash < usd0 + lima_rate * 0.5, "Lima earns into its own stash while you're in Detroit (+%s)" % gs.money(gs.stash_of("lima")))
	var st0: float = gs.stash_of("lima")
	var got_all: Dictionary = gs.collect_all()
	check(gs.stash_of("lima") == 0.0 and float(got_all.get("usa", 0.0)) >= st0 and gs.cash >= usd0 + st0, "COLLECT ALL puts it in the wallet")
	# premium managers work anywhere (one station at a time)
	own("hana")
	gs.assign_manager("hana", "bay0")
	check(gs.manager_at("bay0").get("id", "") == "hana" and gs.roster["hana"]["city"] == "detroit", "Premium Hana works in Detroit")
	gs.cash = 1e6
	gs.hire_manager("valet")
	var det_mgrs: int = gs.managers.filter(func(x): return x["home"] == "detroit").size()
	# unlock LA (the 3rd city): now Lima can prestige
	var lac = gs.city_unlock_cost("los_angeles")
	check(absf(lac - 5.0e12) < 1.0, "LA unlock costs %s (fixed price)" % gs.money(lac))
	gs.cash = lac * 2.0
	gs.unlock_city("los_angeles")
	gs.tutorial_step = gs.TUT_DONE
	gs.go_to_city("lima")
	await wait(0.2)
	check(gs.prestige_needs("lima") == "", "LA unlocked: Lima may prestige")
	own("tony")
	gs.assign_manager("tony", "bay1")
	var lima_cash_mgrs: int = gs.managers.filter(func(x): return x["home"] == "lima").size()
	check(lima_cash_mgrs == 3, "Lima has 3 cash managers before prestige")
	gs.cash = pc * 2.0
	var g6 = gs.gloss
	gs.prestige_city("lima")
	await wait(0.3)
	check(gs.prestige == 1 and gs.bays.size() == 1 and gs.bays[0]["level"] == 1, "Lima prestiged: shop reset")
	check(gs.cash < pc * 2.0, "prestige paid from USD wallet (left %s)" % gs.money(gs.cash))
	check(absf(gs.city_mult() - Data.PRESTIGE_MULT) < 0.001, "Lima now x%s" % str(Data.PRESTIGE_MULT))
	check(gs.managers.filter(func(x): return x["home"] == "lima").is_empty() and not gs.is_automated("bay0"), "full reset: Lima's cash managers are gone")
	check(gs.managers.filter(func(x): return x["home"] == "detroit").size() == det_mgrs, "Detroit's cash managers kept")
	check(gs.roster["tony"]["owned"] and gs.roster["tony"]["assigned"] == "" and gs.roster["hana"]["city"] == "detroit", "premium managers kept: Tony freed, Hana still in Detroit")
	check(gs.gloss == g6 + 50 and gs.followers >= 600.0 and gs.book.has("corollo98"), "gloss, followers, Book kept")
	check(gs.car_def(gs.bays[0]["car"])["tier"] == 2, "Detailing Studio gets daily drivers")
	check(gs.tutorial_step == gs.TUT_WASH, "tutorial restarts after prestige (from the first tap)")
	check(absf(gs.hire_cost("bay") - 10.0) < 0.01, "hiring starts cheap again ($10)")
	gs.tutorial_step = gs.TUT_DONE
	gs.cash = 1e9
	gs.hire_manager("bay0"); gs.hire_manager("valet"); gs.hire_manager("desk")
	check(gs.is_automated("bay0") and gs.is_automated("valet") and gs.is_automated("desk"), "re-staffed Lima with new hires")
	gs.go_to_city("detroit")
	# open the rest of the USA and buy Japan
	gs.cash = 1e17
	for cid in ["miami", "houston"]:
		gs.unlock_city(cid)
	check(gs.cities.size() == 5 and gs.active_city == "houston", "all 5 US cities")
	gs.tutorial_step = gs.TUT_DONE
	check(gs.country_unlock_cost("germany") < 0.0, "Germany locked until Japan is done")
	gs.cash = float(Data.COUNTRIES[1]["unlock_cost"]) * 1.5
	gs.unlock_country("japan")
	await wait(0.3)
	check(gs.country == "japan" and gs.active_city == "shibukawa" and gs.money(5.0) == "¥5", "now in Japan with yen")
	check(gs.unlocked_countries() == ["usa", "japan"], "own USA + Japan")
	gs.tutorial_step = gs.TUT_DONE
	gs.cash = 1e8
	gs.hire_manager("bay0"); gs.hire_manager("valet"); gs.hire_manager("desk")
	await wait(0.3)
	await shot("c2_japan")
	main_node()._open_map()
	await wait(0.5)
	await shot("c3_map")
	for c in main_node().get_children():
		if c.has_method("_set_tab"):
			c.select("lima")   # v0.19u: the world map: tap Lima's patch
	await wait(0.4)
	await shot("c4_map_usa")
	for c in main_node().get_children():
		if c.has_method("_set_tab"):
			c.queue_free()
	main_node()._open_workshops()
	await wait(0.4)
	await shot("c5_premises")
	close_sheets()
	# offline across countries
	gs.pending_offline = {}
	gs._grant_offline(3600.0)
	var us_stash := 0.0
	for sid in gs.stash.keys():
		if gs.country_of(sid) == "usa":
			us_stash += gs.stash_of(sid)
	check(gs.pending_offline.has("japan") and not gs.pending_offline.has("usa") and us_stash > 0.0,
		"offline: the shop you're in (yen) -> Welcome back, the US shops -> their stashes in dollars (v0.19v)")
	await wait(0.3)
	await shot("c6_welcome")
	gs.collect_offline()
	main_node()._popup.visible = false
	# save/load v5
	gs.save_game()
	var snap6 = [gs.cities.size(), gs.wallets.size(), gs.active_city, int(gs.cities["lima"]["prestige"]), "hana"]
	gs._reset_state()
	gs.load_game()
	check(gs.cities.size() == snap6[0] and gs.wallets.size() == snap6[1] and gs.active_city == snap6[2], "cities + wallets + active city saved")
	check(int(gs.cities["lima"]["prestige"]) == 1, "Lima prestige saved")
	check(gs.roster["hana"]["city"] == "detroit" and gs.roster["hana"]["assigned"] == "bay0", "Hana's Detroit job saved")
	# v4 save -> Lima
	var f6 = FileAccess.open("user://save.json", FileAccess.WRITE)
	f6.store_string(JSON.stringify({"version": 4, "saved_at": Time.get_unix_time_from_system(), "cash": 123.0, "workshop": 2,
		"bays": [{"level": 7}, {"level": 3}], "valet": {"level": 5}, "desk": {"level": 4, "lot": 9.0},
		"managers": [{"id": 1, "name": "Kev", "area": "bay", "rarity": 1, "ability": "foam_party", "crew": "jdm", "assigned": "bay1"}],
		"gloss": 77, "followers": 900.0, "tutorial_step": 7}))
	f6.close()
	gs._reset_state()
	gs.load_game()
	check(gs.active_city == "lima" and gs.prestige == 2 and gs.bays.size() == 2 and gs.bays[0]["level"] == 7, "v4 save becomes Lima at prestige 2")
	check(absf(gs.wallets["usa"] - 123.0) < 0.01 and gs.gloss == 77, "v4 cash -> USD, gloss kept")
	check(gs.manager_at("bay1").get("name", "") == "Kev", "v4 manager still working in Lima")
	gs.state_changed.emit()
	gs.city_changed.emit()
	gs.tutorial_step = gs.TUT_DONE
	await wait(0.2)
	print("v0.7 skill tree")
	gs.reset_save()
	gs.tutorial_step = gs.TUT_DONE
	await wait(0.2)
	gs.cash = 1e6
	gs.hire_manager("bay0"); gs.hire_manager("valet"); gs.hire_manager("desk")
	check(absf(gs.token_price("usa") - 1000.0) < 0.01, "first USA token costs $1K")
	gs.buy_token("usa")
	check(gs.tokens["usa"] == 1 and absf(gs.token_price("usa") - 10000.0) < 0.01, "bought 1 token, next costs $10K")
	check(not gs.skill_open("usa_hot_rods"), "Hot Rod Valets locked until Main Street")
	var m0 = gs.city_mult()
	gs.upgrade_skill("usa_main_street")
	check(gs.skill_level("usa_main_street") == 1 and gs.tokens["usa"] == 0, "Main Street Lv1")
	check(absf(gs.city_mult() / m0 - 1.1) < 0.001, "USA cities +10%")
	check(gs.skill_open("usa_hot_rods"), "Hot Rod Valets now open")
	gs.buy_token("usa"); gs.buy_token("usa")
	var vs0 = gs.valet_speed()
	gs.upgrade_skill("usa_hot_rods")
	check(absf(gs.valet_speed() / vs0 - 1.05) < 0.001, "valets +5% speed")
	check(gs.skill_cost("usa_hot_rods") == 2, "Lv2 costs 2 tokens")
	gs.buy_token("japan")
	check(not gs.tokens.has("japan"), "can't buy Japan tokens before Japan")
	gs.save_game()
	gs._reset_state()
	gs.load_game()
	check(gs.skill_level("usa_hot_rods") == 1 and gs.tokens_bought["usa"] == 3, "skills + tokens saved")
	check(absf(gs.valet_speed() / vs0 - 1.05) < 0.001, "skill effects restored after load")
	gs.state_changed.emit()
	gs.city_changed.emit()
	gs.skills["usa_drive_thru"] = 4
	gs.skills["usa_franchise"] = 2
	gs._rebuild_skill_cache()
	gs.tokens["usa"] = 5
	gs.cash = 5e5
	main_node()._open_map(1)
	await wait(0.5)
	for c in main_node().get_children():
		if c.has_method("_set_tab"):
			c._skills._selected = "usa_big_block"
	await wait(0.3)
	await shot("s1_skills")
	for c in main_node().get_children():
		if c.has_method("_set_tab"):
			c._skills._scroll.scroll_horizontal = 440
			c._skills._selected = "jp_tuner"
	await wait(0.3)
	await shot("s2_skills_japan")
	for c in main_node().get_children():
		if c.has_method("_set_tab"):
			c.queue_free()
	await wait(0.2)

	print("v0.8 feel")
	gs.reset_save()
	gs.tutorial_step = gs.TUT_DONE
	gs.cash = 1e6
	gs.hire_manager("bay0"); gs.hire_manager("valet"); gs.hire_manager("desk")
	gs.buy_bay()
	await wait(0.3)
	var got_boost = [false]
	var lcb = func(_k, _n, b): got_boost[0] = not b.is_empty()
	gs.leveled.connect(lcb)
	gs.buy_levels("bay0", 9)
	check(got_boost[0], "reaching Lv10 reports the Foam Cannon boost")
	gs.leveled.disconnect(lcb)
	await wait(0.25)
	await shot("f1_boost_banner")
	await wait(4.0)
	await shot("f2_working")
	gs._advance_vip(20000.0)
	check(not gs.first_vip_done and gs.vip.is_empty(), "no rare cars at all with 2 bays (even after a long time)")
	var welcome := false
	for k in 25:
		gs._grant_offline(1500.0)
		welcome = welcome or not gs.vip.is_empty()
	gs.collect_offline()
	main_node()._popup.visible = false
	check(not welcome, "no welcome-back rare car before the first one")
	gs.cash = 1e7
	gs.buy_bay()
	await wait(Data.FIRST_VIP_DELAY + 1.0)
	check(gs.first_vip_done and not gs.vip.is_empty(), "first rare car arrives when Bay 3 is built")
	gs.vip = {}
	await wait(0.2)

	print("v0.9 calm + overview + boost gloss")
	gs.reset_save()
	await wait(0.2)
	check(gs.tutorial_step == 0, "tutorial running on new game")
	var tf9 = [false]
	var tcb9 = func(): tf9[0] = true
	gs.tutorial_finished.connect(tcb9)
	main_node()._open_map()
	await wait(0.2)
	check(gs.tutorial_step == gs.TUT_DONE and not tf9[0], "opening the map ends the tutorial quietly")
	gs.tutorial_finished.disconnect(tcb9)
	for c in main_node().get_children():
		if c.has_method("_set_tab"):
			c.queue_free()
	gs.cash = 1e7
	gs.hire_manager("bay0"); gs.hire_manager("valet"); gs.hire_manager("desk")
	var g9 = gs.gloss
	gs.buy_levels("bay0", 9)
	check(gs.gloss == g9 + 5, "first boost (Lv10) gives 5 Gloss")
	gs.buy_levels("bay0", 15)
	check(gs.gloss == g9 + 8, "second boost (Lv25) gives 3 more")
	gs.buy_levels("bay0", 25)
	check(gs.gloss == g9 + 9, "later boosts give 1")
	gs.buy_bay(); gs.buy_bay()
	gs.buy_levels("valet", 5)
	await wait(1.5)
	await shot("o1_main_alert")
	main_node()._open_overview()
	await wait(0.8)
	await shot("o2_overview")
	close_sheets()
	main_node()._open_level_panel("bay1")
	await wait(0.4)
	await shot("o3_level_gloss")
	close_sheets()
	await wait(0.2)

	print("v0.10 boosts + 20 bays")
	gs.reset_save()
	gs.finish_tutorial(true)
	await wait(0.2)
	check(gs.boosters.get("x2_30m", 0) == 2 and gs.boosters.get("x5_15m", 0) == 1, "new game starts with 2x x2 and 1x x5 boosters")
	check(is_equal_approx(gs.total_boost(), 1.0), "no boost running -> x1")
	gs.cash = 1e6
	gs.hire_manager("bay0"); gs.hire_manager("valet"); gs.hire_manager("desk")
	var inc1: float = gs.bay_income(0)
	gs.watch_ad_boost()
	check(is_equal_approx(gs.base_boost(), 2.0) and gs.ad_boost_left() > 4.0 * 3600.0 - 5.0, "ad gives x2 base for 4h")
	gs.add_booster("x5_2h")
	gs.activate_booster("x5_15m")
	gs.activate_booster("x2_30m")
	check(is_equal_approx(gs.booster_sum(), 7.0), "x5 + x2 boosters add up to x7")
	check(is_equal_approx(gs.total_boost(), 14.0), "ad x2 * (x5 + x2) = x14")
	check(absf(gs.bay_income(0) / inc1 - 14.0) < 0.01, "bay income is x14")
	check(gs.boosters.get("x5_15m", 0) == 0 and gs.boosters.get("x2_30m", 0) == 1, "activating uses up boosters")
	main_node()._process(0.0)
	check(main_node()._boost_btn.text.begins_with("x14"), "centre button shows x14 (%s)" % main_node()._boost_btn.text.replace("\n", " "))
	await wait(0.3)
	await shot("b1_main_boosted")
	main_node()._open_boosts()
	await wait(0.6)
	await shot("b2_boost_panel")
	close_sheets()
	gs.active_boosters = []
	gs.perm_boost = 2.0
	gs.activate_booster("x5_2h")
	check(is_equal_approx(gs.total_boost(), 20.0), "lifetime x2 * ad x2 * x5 booster = x20")
	gs.perm_boost = 1.0
	gs.ad_boost_until = 0.0
	for k in 10:
		gs.watch_ad_boost()
	check(gs.ad_boost_left() <= 24.0 * 3600.0 + 1.0, "ad boost caps at 24h")
	gs.ad_boost_until = 0.0
	gs.active_boosters = [{"id": "x5_15m", "mult": 5.0, "until": gs.now + 600.0}]
	check(absf(gs.average_boost(gs.now, gs.now + 1200.0) - 3.0) < 0.001, "average boost over 20 min with 10 min of x5 = x3")
	# offline: 1h away while an x5 ran for the last 30 min of it -> average x3
	gs.active_boosters = [{"id": "x5_2h", "mult": 5.0, "until": gs.now + 7200.0}]
	gs.save_game()
	var bsnap = [gs.boosters.duplicate(), gs.active_boosters.size()]
	gs._reset_state()
	gs.load_game()
	check(str(gs.boosters) == str(bsnap[0]) and gs.active_boosters.size() == bsnap[1], "boosters + running boosters saved")
	gs.active_boosters = [{"id": "x5_15m", "mult": 5.0, "until": gs.now - 1800.0}]
	var plain = gs.idle_income()
	gs.pending_offline = {}
	gs._grant_offline(3600.0)
	var got = float(gs.pending_offline.get(gs.country, 0.0))
	check(absf(got / (plain * 3600.0) - 3.0) < 0.05, "offline 1h with x5 for the first 30 min pays x3 (%.2f)" % (got / maxf(plain * 3600.0, 1.0)))
	gs.pending_offline = {}
	gs._expire_boosters()
	check(gs.active_boosters.is_empty(), "finished boosters are removed")
	var gl = gs.gloss
	gs.gloss = 5000
	var deal0: String = gs.deals()[0]
	var dprice: int = int(gs.booster_def(deal0)["price"])
	var had0: int = int(gs.boosters.get(deal0, 0))
	gs.buy_booster(deal0)
	check(gs.gloss == 5000 - dprice and int(gs.boosters.get(deal0, 0)) == had0 + 1, "buy one of today's deals (%s) for %d Shine Bucks" % [deal0, dprice])
	gs.gloss = gl
	gs.cash = 1e40
	build_all()
	check(gs.bays.size() == 20, "20 bays max (%d)" % gs.bays.size())
	await wait(0.2)

	print("v0.11 premium managers: clues, case files, certs")
	gs.reset_save()
	await wait(0.2)
	main_node()._popup.visible = false
	check(gs.roster.size() == 25 and gs.owned_managers().is_empty(), "25 unique managers, none owned at start")
	check(gs.case_files.is_empty() and gs.certs == 0, "no case files or certs at start")
	gs.finish_tutorial(true)
	check(gs.roster["dazza"]["clues"] == 0 and gs.case_files.is_empty(), "tutorial end gives no dossier or Case File any more")
	var rw = gs.ht_reward("reno1")
	check(rw.get("starter", false) and gs.reward_text(rw).begins_with("Dazza"), "Hometown renovation 1 reward: Dazza's dossier")
	gs._grant_reward(rw)
	check(gs.roster["dazza"]["clues"] == 63 and gs.starter_given and not gs.ht_reward("reno1").get("starter", false), "starter given once")
	gs.cash = 50.0
	check(not gs.call_manager("dazza"), "can't call without the fee")
	check(not gs.call_manager("tony"), "can't call with an incomplete dossier")
	gs.cash = 1000.0
	check(gs.call_manager("dazza") and gs.roster["dazza"]["owned"] and absf(gs.cash - 900.0) < 0.01, "call Dazza for $100")
	check(not gs.call_manager("dazza"), "can't call the same manager twice")
	# open a few files for the screenshots, then check no clue ever repeats
	gs.case_files = {"basic": 1}
	var r1 = gs.open_case_file("basic")
	var r1_certs := 5
	for c in r1["cards"]:
		r1_certs += int(c["certs"])
	check(r1["cards"].size() == 2 and r1["cards"].all(func(c): return c["clues"].size() <= 2 and int(c["rolled"]) <= 2) and gs.certs == r1_certs,
		"basic Case File: 2 cards, 1-2 clues each, 5 Certs (+%d extra)" % (r1_certs - 5))
	var rolls := [0, 0, 0, 0, 0, 0]
	for k in 4000:
		rolls[gs._roll_rarity(Data.CLUE_ROLL_ODDS)] += 1
	check(rolls[0] > 1600 and rolls[0] < 2000 and rolls[5] < 60 and rolls[3] < rolls[2], "clue rolls: 1 clue ~45%%, 6 clues very rare %s" % str(rolls))
	gs.case_files = {"detailed": 2}
	gs.open_case_file("detailed")
	gs.cash = 1000.0
	var cash_m: Dictionary = gs.hire_manager("bay0")
	check(gs.manager_at("bay0").get("id", -1) == cash_m["id"], "cash manager still hired the old way")
	gs.assign_manager("dazza", "bay0")
	check(gs.manager_at("bay0").get("id", "") == "dazza" and cash_m["assigned"] == "", "Premium Dazza swaps in, cash manager freed")
	gs.assign_manager(cash_m["id"], "bay0")
	check(gs.manager_at("bay0").get("id", -1) == cash_m["id"] and gs.roster["dazza"]["assigned"] == "", "and back again")
	var inc_cash: float = gs.bay_income(0)
	gs.assign_manager("dazza", "bay0")
	check(gs.bay_income(0) > inc_cash, "Premium passive raises income (x%.2f)" % (gs.bay_income(0) / inc_cash))
	gs.roster["tash"]["clues"] = 1 | 4 | 32   # shirt, shoes, tool
	main_node()._open_map(2)
	await wait(0.6)
	await shot("m1_roster")
	main_node().get_children().filter(func(c): return c.has_method("_set_tab"))[0]._roster._open_dossier("tash")
	await wait(0.5)
	await shot("m2_dossier_partial")
	close_sheets()
	gs.roster["dazza"]["level"] = 20
	main_node().get_children().filter(func(c): return c.has_method("_set_tab"))[0]._roster._open_dossier("dazza")
	await wait(0.5)
	await shot("m3_dossier_owned")
	close_sheets()
	main_node().get_children().filter(func(c): return c.has_method("_set_tab"))[0]._roster._open_file("detailed")
	await wait(0.25)
	await shot("m4a_card_facedown")
	await wait(0.9)
	await shot("m4b_card_flipped")
	var crp = get_tree().root.find_children("*", "", true, false).filter(func(n): return n.get_script() == load("res://scripts/case_result_panel.gd"))
	check(crp.size() == 1 and crp[0].index == 0 and not crp[0]._busy, "Case File opens on card 1, flipped")
	if crp.size() == 1:
		crp[0].next()
		await wait(1.2)
		await shot("m4c_card2")
		while crp[0].index < crp[0].cards().size():
			crp[0].next()
			await wait(1.2)
		await shot("m4_case_result")
	close_sheets()
	for c in main_node().get_children():
		if c.has_method("_set_tab"):
			c.queue_free()
	main_node()._open_manager_panel("bay0")
	await wait(0.4)
	await shot("m5_manager_tab")
	close_sheets()
	gs.roster["yuki"]["clues"] = 63
	gs.roster["yuki"]["owned"] = true
	var MP = load("res://scripts/manager_panel.gd")
	MP.tab = "premium"
	main_node()._open_manager_panel("bay0")
	await wait(0.4)
	await shot("m5b_premium_tab")
	MP.tab = "speed"
	close_sheets()
	await wait(0.2)
	await shot("m6_main_staff")
	gs.case_files = {"classified": 80}
	var dupes := 0
	var total_clues := 0
	var extra_c := 0
	var twice := 0
	var cards_ok := true
	var certs0: int = gs.certs
	for k in 80:
		var before := {}
		for id in gs.roster:
			before[id] = int(gs.roster[id]["clues"])
		var res = gs.open_case_file("classified")
		var seen_ids := {}
		for cd in res["cards"]:
			cards_ok = cards_ok and cd["clues"].size() <= int(cd["rolled"]) and int(cd["rolled"]) >= 1 and int(cd["rolled"]) <= 6 \
				and int(cd["certs"]) == (int(cd["rolled"]) - cd["clues"].size()) * Data.LEFTOVER_CLUE_CERTS
			extra_c += int(cd["certs"])
			if cd["id"] != "" and seen_ids.has(cd["id"]):
				twice += 1
			seen_ids[cd["id"]] = true
		cards_ok = cards_ok and res["cards"].size() == 4
		for c in res["clues"]:
			if before[c[0]] & (1 << int(c[1])):
				dupes += 1
			before[c[0]] = before[c[0]] | (1 << int(c[1]))
		total_clues += res["clues"].size()
	check(cards_ok, "Classified: 4 cards, 1-6 clues each, extras -> Certs")
	check(dupes == 0, "Case Files never repeat a clue (%d clues, same manager twice in a file %d times)" % [total_clues, twice])
	check(gs.roster.values().all(func(m): return gs.dossier_done(m)), "every dossier complete after 80 Classified Files")
	check(gs.certs - certs0 == 80 * 40 + extra_c, "file Certs + leftover clue Certs add up")
	check(gs.open_case_file("classified").is_empty(), "can't open files you don't have")
	# levels + perks
	var dz: Dictionary = gs.roster["dazza"]
	dz["level"] = 1
	gs.certs = 2
	check(gs.level_cert_cost(dz) == 2 and gs.level_up_manager("dazza") and gs.certs == 0 and dz["level"] == 2, "level up costs Certs")
	check(not gs.level_up_manager("dazza"), "no Certs, no level")
	dz["level"] = 19
	var d19: float = gs.ability_duration(dz)
	dz["level"] = 20
	check(gs.promotion(dz) == "Lead" and absf(gs.ability_duration(dz) / d19 - 1.3 * 1.19 / 1.18) < 0.01, "Lv20 Lead: Stamina perk +30% ability time")
	dz["level"] = 50
	check(absf(gs.passive_value(dz) - 0.10 * (1.0 + 0.04 * 49) * 2.0) < 0.001, "Lv50 Veteran doubles the passive")
	check(gs.level_cert_cost(dz) == -1, "Lv50 is max")
	var ab0: String = dz["ability"]
	dz["ability"] = "foam_party"
	var d_inc: float = gs.ability_duration(dz)
	dz["ability"] = "elbow_grease"
	check(absf(gs.ability_duration(dz) / d_inc - 2.0) < 0.001, "speed abilities last twice as long as income ones")
	dz["ability"] = ab0
	# legendary passives
	gs.cash = 1e9
	gs.go_to_city("lima")
	var base_mult: float = gs.staff_city_mult("detroit")
	gs.roster["mori"]["owned"] = true
	gs.assign_manager("mori", "bay0")
	check(absf(gs.staff_city_mult("detroit") / base_mult - 1.25) < 0.001, "Mirror Mori: every city +25%")
	gs.roster["gaffer"]["owned"] = true
	gs.assign_manager("gaffer", "desk")
	gs.roster["mori"]["ready_at"] = 0.0
	await wait(2.5)
	check(gs.ability_active(gs.roster["mori"]), "The Gaffer's Autopilot uses abilities by itself")
	# old (v5) save: cash managers stay, crate managers -> Detailed Case Files
	var f11 = FileAccess.open("user://save.json", FileAccess.WRITE)
	f11.store_string(JSON.stringify({"version": 5, "saved_at": Time.get_unix_time_from_system(), "wallets": {"usa": 10.0},
		"active_city": "lima", "cities": {"lima": {"prestige": 0, "bays": [{"level": 4}, {"level": 2}], "valet": {"level": 3}, "desk": {"level": 2, "lot": 0.0}}},
		"managers": [{"id": 1, "name": "Kev", "area": "bay", "rarity": 0, "crew": "jdm", "home": "lima", "city": "lima", "assigned": "bay1"},
			{"id": 2, "name": "Bec", "area": "desk", "rarity": 2, "crew": "euro", "premium": true, "city": "lima", "assigned": "desk"},
			{"id": 3, "name": "Mo", "area": "valet", "rarity": 1, "crew": "euro", "premium": true}],
		"tutorial_step": 7}))
	f11.close()
	gs._reset_state()
	gs.load_game()
	check(gs.managers.size() == 1 and gs.manager_at("bay1").get("name", "") == "Kev", "v5 cash manager kept at bay 2")
	check(not gs.is_automated("desk"), "v5 crate manager's desk job gone")
	check(gs.case_files.get("detailed", 0) == 2 and not gs.case_files.has("basic"), "v5 crate managers -> Detailed Case Files")
	check(gs.roster["dazza"]["clues"] == 0 and not gs.starter_given, "v5 players get Dazza from Hometown like everyone")
	gs.save_game()
	gs._reset_state()
	gs.load_game()
	check(gs.manager_at("bay1").get("name", "") == "Kev" and gs.case_files.get("detailed", 0) == 2 and not gs.starter_given, "v7 save keeps managers, files")
	# v6 (the short-lived supervisor build): each supervisor becomes a Junior manager again
	var f12 = FileAccess.open("user://save.json", FileAccess.WRITE)
	f12.store_string(JSON.stringify({"version": 6, "saved_at": Time.get_unix_time_from_system(), "wallets": {"usa": 10.0},
		"active_city": "lima", "cities": {"lima": {"prestige": 0, "bays": [{"level": 4, "sup": true}, {"level": 2, "sup": true}],
		"valet": {"level": 3, "sup": true}, "desk": {"level": 2, "lot": 0.0}}},
		"roster": {"dazza": {"clues": 63, "owned": true, "level": 3, "city": "lima", "assigned": "bay0"}}, "starter_given": true, "tutorial_step": 7}))
	f12.close()
	gs._reset_state()
	gs.load_game()
	check(gs.managers.size() == 3 and gs.manager_at("bay1").get("rarity", -1) == 0 and gs.is_automated("valet"), "v6 supervisors -> Junior managers")
	check(gs.manager_at("bay0").get("id", "") == "dazza" and gs.managers.filter(func(x): return x["assigned"] == "").size() == 1, "v6 Dazza keeps bay 1, its supervisor waits free")
	check(not gs.bays[0].has("sup"), "supervisor flags cleaned up")
	await wait(0.2)

	print("v0.12 equipment + materials")
	gs.reset_save()
	await wait(0.2)
	main_node()._popup.visible = false
	gs.finish_tutorial(true)
	check(gs.materials.is_empty() and gs.equipment.is_empty(), "no materials or equipment at start")
	check(not gs.can_craft("stopwatch") and not gs.craft("stopwatch"), "can't craft without materials")
	gs.grant_test_materials(100)
	check(gs.craft("stopwatch") and gs.equip_tier("stopwatch") == 0, "crafted a Common Pro Stopwatch")
	check(gs.materials["steel"] == 80 and gs.materials["rubber"] == 90, "materials used (steel 80, rubber 90)")
	check(gs.craft("stopwatch") and gs.equip_tier("stopwatch") == 1, "upgraded to Rare (the Common is used up)")
	check(gs.craft("stopwatch") and gs.equip_tier("stopwatch") == 2 and not gs.craft("stopwatch"), "Epic is the max")
	var dz12 = own("dazza")
	gs.cash = 1000.0
	gs.assign_manager("dazza", "bay0")
	var cd012: float = gs.ability_cooldown(dz12)
	gs.equip_item("stopwatch", "dazza")
	check(dz12["gear"] == "stopwatch" and absf(gs.ability_cooldown(dz12) / cd012 - 0.7) < 0.001, "Epic Stopwatch: ability recharges 30% faster")
	var ty12 = own("tony")
	gs.equip_item("stopwatch", "tony")
	check(ty12["gear"] == "stopwatch" and dz12["gear"] == "", "only one Stopwatch exists: it moves to Tony")
	gs.craft("apron")
	var inc012: float = gs.bay_income(0)
	gs.equip_item("apron", "dazza")
	check(absf(gs.bay_income(0) / inc012 - 1.10) < 0.001, "Common Apron: bay earns +10%")
	gs.craft("gloves")
	var t012: float = gs.bay_cycle_time(0)
	gs.equip_item("gloves", "dazza")
	check(absf(t012 / gs.bay_cycle_time(0) - 1.10) < 0.001 and dz12["gear"] == "gloves", "Gloves replace the Apron: bay works 10% faster")
	gs.craft("night_lamp")
	gs.equip_item("night_lamp", "tony")
	check(gs.gear_global("offline") == 0.0, "Night Lamp does nothing while Tony isn't working")
	gs.assign_manager("tony", "valet")
	check(gs.gear_global("offline") == 0.0, "Tony is a bay manager: can't work the valet")
	gs.hire_manager("bay0")
	gs.buy_bay()
	gs.assign_manager("tony", "bay1")
	check(absf(gs.gear_global("offline") - 0.05) < 0.001, "Night Lamp counts once Tony is working (+5% offline)")
	gs.craft("air_freshener")
	var pv12: float = gs.passive_value(ty12)
	gs.equip_item("air_freshener", "tony")
	check(absf(gs.passive_value(ty12) / pv12 - 1.2) < 0.001, "Air Freshener: passive +20%")
	gs.save_game()
	var mat_snap12 = gs.materials.duplicate()
	gs._reset_state()
	gs.load_game()
	check(gs.equip_tier("stopwatch") == 2 and gs.roster["dazza"]["gear"] == "gloves" and gs.roster["tony"]["gear"] == "air_freshener", "equipment + gear saved")
	check(mat_snap12.keys().all(func(k): return int(gs.materials.get(k, -1)) == int(mat_snap12[k])) and gs.materials.size() == mat_snap12.size(), "materials saved")
	main_node()._open_map(3)
	await wait(0.6)
	await shot("e1_equipment")
	var EV12 = load("res://scripts/equip_view.gd")
	EV12.tab = 1
	await wait(0.4)
	await shot("e2_materials")
	EV12.tab = 0
	main_node().get_children().filter(func(c): return c.has_method("_set_tab"))[0]._roster._open_dossier("dazza")
	await wait(0.5)
	await shot("e3_dossier_gear")
	close_sheets()
	main_node().get_children().filter(func(c): return c.has_method("_set_tab"))[0]._equip._pick_wearer("stopwatch")
	await wait(0.5)
	await shot("e4_picker")
	close_sheets()
	for c in main_node().get_children():
		if c.has_method("_set_tab"):
			c.queue_free()
	await wait(0.2)

	print("v0.13 Hometown Garage")
	gs.reset_save()
	await wait(0.2)
	main_node()._popup.visible = false
	gs.finish_tutorial(true)
	check(not gs.hometown["unlocked"] and not gs.cities.has("hometown"), "Hometown locked at start")
	gs.cash = 1e12
	for k in 4:
		gs.buy_bay()
	check(gs.bays.size() == 5 and gs.hometown["unlocked"] and gs.cities.has("hometown") and gs.wallets.has("hometown"), "5 bays in Lima unlocks the Hometown Garage")
	check(gs.prestige_cost("hometown") < 0.0, "Hometown can't be prestiged")
	check(not gs.hometown["seen"], "Hometown not visited yet")
	await wait(0.7)
	check(main_node()._map_alert.visible, "MAP shows \"!\" until you visit the Hometown")
	main_node()._open_map(0)
	await wait(0.5)
	await shot("h0_map_nudge")
	close_sheets()
	for c in main_node().get_children():
		if c.has_method("_set_tab"):
			c.queue_free()
	gs.go_to_city("hometown")
	check(gs.hometown["seen"], "visiting marks it seen")
	await wait(0.2)
	check(gs.is_hometown() and gs.ht_cap() == 5 and gs.cash == 0.0, "run 1: 5 bays, own wallet starts empty")
	check(absf(gs.next_bay_cost() - Data.HOMETOWN_BUILD_BASE * Data.HOMETOWN_COST_MULT * Data.HOMETOWN_GROWTH) < 0.01, "Bay 2 costs %s" % gs.money(gs.next_bay_cost()))
	check(gs.station_max_level("bay0") == 50 and gs.station_max_level("valet") == 50, "run 1 targets: bays Lv50, valet/desk Lv50")
	check(str(gs.ht_reno_bays()) == "[3, 4, 5]", "renovations before bays 3, 4, 5 (got %s)" % str(gs.ht_reno_bays()))
	gs.cash = 1e15
	gs.buy_bay(); gs.buy_bay()
	check(gs.bays.size() == 2 and gs.ht_reno_needed() == 1 and gs.next_bay_cost() < 0.0, "renovation blocks bay 3")
	await wait(0.3)
	await shot("h1_reno_needed")
	check(gs.start_renovation() and gs.ht_reno_running() and absf(gs.reno_left() - 1800.0) < 2.0, "Hometown renovation 1 (run 1) takes 30 min")
	await wait(0.3)
	await shot("h2_renovating")
	check(gs.watch_reno_ad() and gs.reno_ready() and gs.ht_stage() == 0, "a skip (-30 min) runs the timer out: the lock waits for a tap")
	main_node()._scroll_to_bay(gs.bays.size() - 1)
	await wait(1.2)
	await shot("h2b_reno_lock")
	check(gs.unlock_renovation() and not gs.ht_reno_running() and gs.ht_stage() == 1, "tapping the lock finishes it: now a House Garage")
	check(not gs.unlock_renovation(), "nothing left to unlock")
	check(gs.reno_ads_left() == 1, "1 skip left this hour")
	gs.buy_bay()
	check(gs.bays.size() == 3 and gs.ht_reno_needed() == 2, "bay 3 built, next renovation waits")
	gs.start_renovation()
	gs.watch_reno_ad()
	check(gs.ht_stage() == 1 and gs.reno_running() and absf(gs.reno_left() - (4500.0 - 1800.0)) < 2.0, "renovation 2 takes 1h15m, the 2nd skip takes 30 min off")
	check(not gs.watch_reno_ad(), "a 3rd skip this hour doesn't work")
	gs._cstate("")["reno_until"] = gs.now - 1.0
	gs._reno_tick()
	check(gs.ht_stage() == 1 and gs.reno_ready(), "renovation 2 timer ran out: waits for the tap")
	gs.unlock_renovation()
	check(gs.ht_stage() == 2, "renovation 2 done")
	gs.buy_bay()
	gs.start_renovation()
	gs._cstate("")["reno_until"] = gs.now - 1.0
	await wait(0.1)
	check(gs.ht_stage() == 2 and gs.reno_ready() and gs.reno_left() == 0.0, "renovation doesn't finish on its own: the lock waits")
	gs.unlock_renovation()
	check(gs.ht_stage() == 3, "unlocked: stage 3")
	gs.buy_bay()
	check(gs.bays.size() == 5 and gs.next_bay_cost() < 0.0, "all 5 bays built")
	check(gs.bay_reno_tier(1) == 0 and gs.bay_reno_tier(2) == 1 and gs.bay_reno_tier(4) == 3, "run 1 tiers: bays 3 / 4 / 5 after each renovation")
	check(absf(gs.tier_income_mult(4) - pow(Data.HOMETOWN_TIER_INCOME, 3)) < 1e-6 and absf(gs.tier_cost_mult(2) - Data.HOMETOWN_TIER_COST) < 1e-6, "Hometown tier bays earn x%s, levels cost x%s per tier" % [str(Data.HOMETOWN_TIER_INCOME), str(Data.HOMETOWN_TIER_COST)])
	check(absf(gs.levels_cost("valet", 1) - Data.VALET_LEVEL_COST * Data.HOMETOWN_VD_COST_MULT * pow(Data.HOMETOWN_VD_LEVEL_GROWTH, gs.level_of("valet") - 1)) < 1.0, "Hometown valet levels use the Hometown prices")
	gs.buy_levels("bay0", 100)
	check(gs.level_of("bay0") == 50, "bay levels stop at the run target (50)")
	var ms13 = gs.ht_milestones()
	check(ms13[-1]["id"] == "run" and not ms13[-1]["done"], "run not finished yet")
	var c013: int = gs.certs
	var n_claim13: int = gs.claim_all_milestones()
	check(n_claim13 > 0 and gs.case_files.get("basic", 0) >= 3, "claimed %d goals (renovations give Case Files)" % n_claim13)
	check(gs.roster["dazza"]["clues"] == 63 and gs.starter_given, "run 1 renovation 1 gave Dazza's dossier")
	for i in gs.bays.size():
		gs.bays[i]["level"] = 50
	gs.valet["level"] = 50
	gs.desk["level"] = 50
	check(gs.ht_milestones()[-1]["done"] and gs.ht_claimable() > 0, "everything maxed: run can be finished")
	gs.claim_all_milestones()
	check(gs.ht_run_finished() and gs.certs > c013 + 40 and gs.case_files.get("detailed", 0) >= 1 and gs.materials.get("alcantara", 0) >= 2, "end-of-run reward: Certs, Detailed Case File, epic materials")
	main_node()._open_hometown()
	await wait(0.4)
	await shot("h3_run_done")
	close_sheets()
	check(gs.ht_start_next_run() and gs.ht_cap() == 10 and gs.bays.size() == 1 and gs.cash == 0.0 and gs.ht_stage() == 0, "run 2: back to a dirt lot with 10 bays")
	check(gs.station_max_level("valet") == 100, "run 2 valet target Lv100")
	gs.cash = 1e9
	gs.hire_manager("bay0")
	gs.buy_bay()
	gs.buy_levels("bay0", 20)
	main_node()._open_hometown()
	await wait(0.4)
	await shot("h4_run2_panel")
	close_sheets()
	gs.save_game()
	gs._reset_state()
	gs.load_game()
	check(gs.is_hometown() and gs.ht_run() == 2 and gs.bays.size() == 2 and gs.hometown["unlocked"], "Hometown saved")
	gs.go_to_city("lima")
	main_node()._open_map()
	await wait(0.5)
	for c in main_node().get_children():
		if c.has_method("_set_tab"):
			c.center_on_here()
	await wait(0.3)
	await shot("h5_map")
	for c in main_node().get_children():
		if c.has_method("_set_tab"):
			c.queue_free()
	await wait(0.2)

	print("v0.14 Wardrobe")
	gs.reset_save()
	await wait(0.2)
	main_node()._popup.visible = false
	gs.finish_tutorial(true)
	check(gs.wardrobe.is_empty() and gs.wardrobe_mult("bay") == 1.0, "no uniforms at start")
	gs.gloss = 50
	check(gs.open_wardrobe_crate("wardrobe").is_empty() and gs.gloss == 50, "can't open a crate without the Gloss")
	var inc14: float = gs.bay_income(0)
	var r14 = gs._add_uniform("bay_tee")
	check(r14["new"] and gs.worn["bay"] == "bay_tee" and absf(gs.bay_income(0) / inc14 - 1.10) < 0.001, "first uniform worn: Plain Tee = bays x1.10")
	gs._add_uniform("bay_tee")
	check(gs.uniform_level("bay_tee") == 2, "a duplicate levels it to Lv2")
	gs._add_uniform("bay_tee"); gs._add_uniform("bay_tee")
	check(gs.uniform_level("bay_tee") == 3 and int(gs.wardrobe["bay_tee"]["copies"]) == 0, "Lv3 needs 2 more copies")
	gs._add_uniform("bay_gold")
	check(gs.worn["bay"] == "bay_gold" and absf(gs.wardrobe_mult("bay") - 2.5) < 0.001, "Legendary is worn straight away (x2.50)")
	gs._add_uniform("bay_polo")
	check(gs.worn["bay"] == "bay_gold", "a weaker new uniform doesn't replace it")
	gs.wear_uniform("bay_polo")
	check(gs.worn["bay"] == "bay_polo", "you can still pick what they wear")
	gs.wear_uniform("bay_gold")
	gs.gloss = 100000
	var ok14 := true
	for k in 15:
		var res = gs.open_wardrobe_crate("big_wardrobe")
		if res.size() != 5 or not res.any(func(x): return int(gs.uniform_def(x["id"])["rarity"]) >= 2):
			ok14 = false
	check(ok14, "Big Wardrobe Crate: 5 uniforms, always one Rare or better")
	gs.wardrobe_pity = 39
	var rp = gs.open_wardrobe_crate("wardrobe")
	check(int(gs.uniform_def(rp[0]["id"])["rarity"]) == 4 and gs.wardrobe_pity == 0, "pity: Legendary guaranteed")
	var d14 = gs.open_wardrobe_crate("designer")
	check(int(gs.uniform_def(d14[0]["id"])["rarity"]) >= 3, "Designer Crate: Epic or better")
	var snap14 = [gs.wardrobe.size(), gs.uniform_level("bay_tee"), gs.wardrobe_pity]
	gs.save_game()
	gs._reset_state()
	gs.load_game()
	check(gs.wardrobe.size() == snap14[0] and gs.worn["bay"] == "bay_gold" and gs.wardrobe_pity == snap14[2] and gs.uniform_level("bay_tee") == snap14[1], "wardrobe saved")
	var WP = load("res://scripts/wardrobe_panel.gd")
	var wp = WP.new()
	main_node().add_child(wp)
	wp.setup()
	await wait(0.5)
	await shot("w1_wardrobe")
	wp._open("big_wardrobe")
	await wait(0.5)
	await shot("w2_crate_result")
	close_sheets()
	await wait(0.2)

	print("v0.15 prestige screen + shine")
	gs.reset_save()
	await wait(0.2)
	main_node()._popup.visible = false
	gs.finish_tutorial(true)
	gs.cash = 1e8
	gs.hire_manager("bay0"); gs.hire_manager("valet"); gs.hire_manager("desk")
	gs.buy_bay(); gs.buy_bay()
	await wait(0.2)
	check(not gs.prestige_ready(), "not ready: can't afford it yet")
	check(main_node()._prestige_badge.visible, "the prestige trophy is always in the top bar")
	check(absf(gs.prestige_cost("lima") - gs.city_list_price("detroit")) < 1.0, "v0.17g: Lima's 1st prestige costs the same as Detroit (%s)" % gs.money(gs.prestige_cost("lima")))
	check(gs.prestige_needs("lima") == "", "v0.17g: prestige needs no other city")
	gs.cash = gs.prestige_cost("lima") * 1.5
	await wait(0.3)
	check(gs.prestige_ready(), "can afford it: ready without unlocking Detroit or LA")
	main_node()._open_workshops()
	await wait(0.4)
	await shot("p0_prestige_ready_no_city")
	close_sheets()
	gs.cash = 1e13
	gs.unlock_city("detroit")
	gs.cash = 1e14
	gs.unlock_city("los_angeles")
	gs.go_to_city("lima")
	gs.tutorial_step = gs.TUT_DONE
	gs.cash = gs.prestige_cost("lima") * 1.5
	await wait(0.3)
	check(gs.prestige_ready() and main_node()._prestige_badge.visible, "can afford it: the HUD trophy shines")
	await shot("p1_badge")
	main_node()._open_workshops()
	await wait(0.4)
	await shot("p2_prestige_screen")
	var pp15 = null
	for c in main_node().get_children():
		if c.has_method("_on_prestige") and c.has_method("clear_body"):
			pp15 = c
	check(pp15 != null and not pp15._btn.disabled, "prestige screen open, button ready")
	pp15._on_prestige()
	check(gs.prestige == 0, "first tap only arms it")
	pp15._on_prestige()
	await wait(0.3)
	check(gs.prestige == 1 and not gs.prestige_ready(), "second tap prestiges Lima")
	gs.tutorial_step = gs.TUT_DONE
	# map: another city ready to prestige shines
	gs.go_to_city("detroit")
	await wait(0.2)
	gs.tutorial_step = gs.TUT_DONE
	gs.cash = gs.prestige_cost("lima") * 1.5
	check(gs.prestige_ready("lima"), "Lima ready again (from Detroit)")
	main_node()._open_map()
	await wait(0.6)
	await shot("p3_map_shine")
	for c in main_node().get_children():
		if c.has_method("_set_tab"):
			c._on_prestige("lima")
	await wait(0.4)
	await shot("p4_map_prestige_screen")
	close_sheets()
	for c in main_node().get_children():
		if c.has_method("_set_tab"):
			c.queue_free()
	await wait(0.2)

	print("v0.16 renovations in every city + balance tools")
	gs.reset_save()
	await wait(0.2)
	main_node()._popup.visible = false
	gs.finish_tutorial(true)
	gs.cash = 1e12
	gs.hire_manager("bay0"); gs.hire_manager("valet"); gs.hire_manager("desk")
	for k in 4:
		gs.buy_bay()
	check(gs.bays.size() == 5 and gs.reno_needed() == 1 and gs.next_bay_cost() < 0.0, "Lima: renovation before bay 6")
	check(str(gs.reno_bays()) == "[6, 11, 16]", "city renovations at bays 6, 11, 16")
	check(absf(gs.reno_seconds(1) - 3600.0) < 0.1 and absf(gs.reno_seconds(2) - 28800.0) < 0.1 and absf(gs.reno_seconds(3) - 172800.0) < 0.1, "city timers 1h / 8h / 48h")
	check(absf(gs.reno_cost() - Data.RENO_FIRST_COST_BUILDS * float(Data.BAY_BUILD_COSTS[5])) < 1.0, "1st renovation costs 1x the next bay (v0.19k)")
	await wait(0.3)
	await shot("r1_city_reno")
	var g16: int = gs.gloss
	gs.start_renovation()
	main_node()._toggle_balance_overlay()
	await wait(0.6)
	await shot("r2_city_renovating_overlay")
	main_node()._toggle_balance_overlay()
	gs.watch_reno_ad()
	check(absf(gs.reno_left() - 1800.0) < 2.0, "skip takes 30 min off")
	gs.watch_reno_ad()
	check(gs.reno_ready() and gs.reno_done() == 0, "2nd skip runs the timer out: lock")
	main_node()._scroll_to_bay(gs.bays.size() - 1)
	await wait(1.2)
	await shot("r3_city_reno_lock")
	var brow = main_node().find_children("*", "", true, false).filter(func(n): return n.get_script() == load("res://scripts/build_row.gd"))
	check(brow.size() == 1, "found the build strip")
	brow[0]._tap(Vector2(brow[0].size.x * 0.5, 60))
	check(not gs.reno_running() and gs.reno_done() == 1 and gs.gloss == g16 + 10, "tapping the lock finishes it: +10 Gloss")
	await wait(0.25)
	await shot("r4_lock_opening")
	gs.buy_bay()
	check(gs.bays.size() == 6, "bay 6 can be built now")
	gs.cash = 1e17
	for k in 4:
		gs.buy_bay()
	check(gs.bays.size() == 10 and gs.reno_needed() == 2, "renovation 2 before bay 11")
	gs.start_renovation()
	var c16: float = gs.cash
	gs.debug_skip(8.0 * 3600.0)
	check(gs.reno_done() == 1 and gs.reno_ready(), "debug skip 8h runs the timer down (lock waits)")
	gs.unlock_renovation()
	check(gs.reno_done() == 2, "unlocked renovation 2")
	check(gs.cash > c16, "debug skip also pays the idle earnings (+%s)" % gs.money(gs.cash - c16))
	check(FileAccess.file_exists(gs.BALANCE_LOG_PATH), "milestone log written")
	# prestige brings renovations back (needs the 3rd city)
	gs.cash = 1e14
	gs.unlock_city("detroit")
	gs.cash = 1e14
	gs.unlock_city("los_angeles")
	gs.go_to_city("lima")
	gs.cash = gs.prestige_cost("lima") * 1.5
	gs.prestige_city("lima")
	await wait(0.2)
	gs.tutorial_step = gs.TUT_DONE
	check(gs.reno_done() == 0 and gs.bays.size() == 1, "prestige: renovations start over")
	# old saves: renovations already passed count as done
	var f16 = FileAccess.open("user://save.json", FileAccess.WRITE)
	f16.store_string(JSON.stringify({"version": 7, "saved_at": Time.get_unix_time_from_system(), "wallets": {"usa": 10.0}, "active_city": "lima",
		"cities": {"lima": {"prestige": 0, "bays": [{"level": 1}, {"level": 1}, {"level": 1}, {"level": 1}, {"level": 1}, {"level": 1},
			{"level": 1}, {"level": 1}, {"level": 1}, {"level": 1}, {"level": 1}, {"level": 1}], "valet": {"level": 1}, "desk": {"level": 1, "lot": 0.0}}},
		"tutorial_step": 7}))
	f16.close()
	gs._reset_state()
	gs.load_game()
	check(gs.reno_done() == 2 and gs.reno_needed() == 0, "old save with 12 bays: renovations 1 + 2 count as done")
	check(gs.ad_free(), "no-ads pack placeholder on by default")
	await wait(0.2)

	print("v0.17 playtest changes")
	gs.reset_save()
	await wait(0.2)
	main_node()._popup.visible = false
	gs.finish_tutorial(true)
	var main17 = main_node()
	# item 10: valet + desk start just ahead of the first bay
	var vr: float = gs.valet_rate() / gs.bay_income(0)
	var dr: float = gs.desk_rate() / gs.bay_income(0)
	check(vr > 1.6 and vr < 2.3 and dr > 1.6 and dr < 2.3, "valet / desk start at x%.2f / x%.2f of bay 1" % [vr, dr])
	check(absf(gs.levels_cost("valet", 1) - Data.VALET_LEVEL_COST) < 0.01, "valet Lv2 costs %s" % gs.money(Data.VALET_LEVEL_COST))
	gs.cash = 1e6
	gs.hire_manager("bay0"); gs.hire_manager("valet"); gs.hire_manager("desk")
	gs.buy_bay()
	gs.buy_levels("bay0", 12)
	await wait(0.3)
	# item 1: level panel arrows Desk -> Valet -> Bay 1 -> Bay 2 -> (wrap) Desk
	main17._open_level_panel("desk")
	await wait(0.3)
	var lp = main17.open_sheet("level", "desk")
	check(lp != null, "level panel open on the Front Desk")
	lp.step(1)
	check(lp.key == "valet", "> goes Front Desk -> Valet")
	lp.step(1)
	lp.step(1)
	check(lp.key == "bay1", "> then Bay 1 -> Bay 2")
	lp.step(1)
	check(lp.key == "desk", "> on the last bay wraps to the Front Desk")
	lp.step(-1)
	check(lp.key == "bay1", "< on the Front Desk wraps to the last bay")
	lp.step(-1)
	await wait(0.3)
	# item 4: just "Next boost at Lv 10", the bar, "+5" and a Gloss droplet
	check(lp.key == "bay0" and lp._next.text.begins_with("Next boost at Lv 25:") and lp._next_gloss.text == "+3" and lp._next_drop.visible,
		"next boost line: '%s' + '%s' + droplet" % [lp._next.text, lp._next_gloss.text])
	lp.step(1)
	await wait(0.2)
	check(lp._next.text.begins_with("Next boost at Lv 10:") and lp._next_gloss.text == "+5", "Bay 2: 'Next boost at Lv 10' +5")
	await shot("v17_01_level_panel_arrows")
	close_sheets()
	# item 2: "!" only on Valet / Front Desk
	gs.bays[0]["level"] = 1
	gs.bays[1]["level"] = 1
	gs.valet["level"] = 1
	await wait(0.4)
	check(gs.bottleneck() == "valet", "valet is the slowest station now (gets the '!')")
	# item 8: ability icon above every manager portrait
	var row0 = main17._bay_rows[0]
	var ab = row0._ability
	check(ab != null and ab.visible and ab.position.y < row0._portrait.position.y, "bay 1 has an ability icon above its portrait")
	var mb17: Dictionary = gs.manager_at("bay0")
	mb17["ready_at"] = 0.0
	mb17["active_until"] = 0.0
	row0._portrait.pressed.emit()
	await wait(0.3)
	check(main17.open_sheet("manager", "bay0") != null and gs.ability_ready(mb17), "tapping the portrait opens the manager panel (ability not used)")
	close_sheets()
	ab.use()
	check(gs.ability_active(mb17), "tapping the icon uses the ability")
	var mv17: Dictionary = gs.manager_at("valet")
	mv17["active_until"] = 0.0
	mv17["ready_at"] = gs.now + 1500.0
	main17._big_queue = []
	main17._toast_queue = []
	await wait(2.6)
	await shot("v17_02_main_icons")   # bay 1 active (glow), valet recharging (dim + countdown), desk + bay 2 ready
	# item 5: no "added to your Book" toast, a "!" on BOOK until it's opened
	gs.book_unseen = false
	main17._toast_queue = []
	var new_car := ""
	for c in Data.CARS:
		if not gs.book.has(c["id"]):
			new_car = c["id"]
			break
	gs.log_car(new_car)
	await wait(0.2)
	check(gs.book_unseen and main17._book_alert.visible, "new car in the Book: '!' on the BOOK button")
	check(not main17._toast.text.contains("Book") and main17._toast_queue.all(func(t): return not t.contains("Book")), "no 'added to your Book' toast")
	await shot("v17_03_book_alert")
	main17._open_book()
	await wait(0.7)   # the "!" refreshes every 0.5s
	check(gs.book_unseen and main17._book_alert.visible, "v0.17g: just opening the Book keeps the '!' (the car isn't on screen yet)")
	var bk = null
	for c in main17.get_children():
		if c.has_method("_show_page"):
			bk = c
	check(gs.book_new_count(int(gs.car_def(new_car)["tier"])) >= 1, "its category tile shows it as NEW")
	await shot("v17g_book_new_tile")
	bk._show_page(int(gs.car_def(new_car)["tier"]))
	await wait(0.3)
	await shot("v17g_book_new_sticker")
	check(not gs.book_unseen and not gs.book_new.has(new_car), "seeing its category page clears it (no tap on the car needed)")
	await wait(0.6)
	# (the bays keep washing: a brand-new car can land in the Book again meanwhile, so the dot must just match)
	await get_tree().process_frame   # (the dot follows on the main screen's next frame)
	check(main17._book_alert.visible == gs.book_unseen, "... and the dot on BOOK (now %s, unseen %s)" % [main17._book_alert.visible, gs.book_unseen])
	gs.log_car(Data.VIP_CARS[1]["id"])
	await wait(0.6)
	check(gs.book_new_rare() and main17._book_alert.visible and main17._book_alert.get_meta("rare", false), "a new rare car: gold badge on BOOK")
	close_sheets()
	# item 3: rare car payout = one clean message
	gs.cash = 1e9
	gs.buy_bay()
	gs.first_vip_done = true
	gs.vip = {}
	gs.spawn_vip(false)
	main17._banner.visible = false
	gs.send_vip()
	var vbay := int(gs.vip["bay"])
	if not gs.is_automated("bay%d" % vbay):
		gs.hire_manager("bay%d" % vbay)
	main17._toast_queue = []
	await wait(2.5)   # let earlier banners finish
	gs.followers = maxf(gs.followers, Data.STAR_THRESHOLDS[1])   # v0.19l: past the first reviews
	gs.followers = gs.next_star_followers() - 1.0   # this payout's followers will add a star
	var stars0: int = gs.stars()
	gs.vip["progress"] = 0.995
	await wait(0.5)
	var paid := 0
	var star_line := false
	var other := 0
	for c in main17.get_children():
		if c.has_method("clear_body") or not (c is PanelContainer or c is VBoxContainer):
			continue
		for l in c.find_children("*", "Label", true, false):
			if l.text.begins_with("RARE CAR PAID"):
				paid += 1
			elif l.text.contains("STARS!") and l.get_parent().get_child(0).text.begins_with("RARE CAR PAID"):
				star_line = true
			elif l.text.ends_with("STARS!"):
				other += 1
	check(gs.vip.is_empty() and paid == 1 and other == 0, "rare car payout shows one message (%d payout, %d other)" % [paid, other])
	check(gs.stars() == stars0 + 1 and star_line, "the star it earned is in the same message")
	check(main17._toast_queue.all(func(t): return not t.contains("paid")) and not main17._toast.text.contains("paid"), "and no second payout toast")
	await shot("v17_04_vip_payout")
	await wait(2.5)
	# item 9: random rare cars only after the first one, rising with stars
	var vip_r1: float = 1.0 / Data.VIP_MEAN_INTERVAL
	check(absf(Data.VIP_MEAN_INTERVAL - 1200.0) < 0.1 and Data.STAR_VIP_BONUS > 0.15, "random rare cars: ~1 per %d min at 1 star, +%d%% per star" % [int(1.0 / vip_r1 / 60.0), int(Data.STAR_VIP_BONUS * 100)])
	# item 7: MANAGERS tab = free managers only; never pull one off another station
	gs.cash = 1e9
	if not gs.is_automated("bay1"):
		gs.hire_manager("bay1")
	var spare: Dictionary = gs.hire_manager("bay0")   # bay 1 is taken: this one waits free
	var busy: Dictionary = gs.manager_at("bay1")
	var nfree: int = gs.free_managers_in_area("bay").size()
	check(spare["assigned"] == "" and nfree >= 1 and gs.managers_in_area("bay").size() > nfree, "%d free bay manager(s), the rest are working" % nfree)
	var MP17 = load("res://scripts/manager_panel.gd")
	var listed := 0
	var heads := []
	var mp = null
	for kt in ["speed", "discount", "income"]:
		MP17.tab = kt
		main17._open_manager_panel("bay2")
		await wait(0.3)
		mp = main17.open_sheet("manager", "bay2")
		for l in mp.body.find_children("*", "Label", true, false):
			if l.text.begins_with("%s BAY MANAGERS (" % kt.to_upper()):
				heads.append(l.text)
				listed += int(l.text.get_slice("(", 1).get_slice(")", 0))
		if kt == "discount":
			await shot("v17_05_managers_free_only")
		close_sheets()
		await wait(0.1)
	check(listed == nfree, "the ability tabs list only free managers, %d in all %s" % [listed, str(heads)])
	# v0.17d: cash manager tiers + hire jumps to the new manager's tab
	check(str(Data.RARITIES.map(func(r): return r["discount"])) == "[0.3, 0.5, 0.8]" and str(Data.RARITIES.map(func(r): return r["odds"])) == "[70.0, 25.0, 5.0]",
		"cash tiers: 30% / 50% / 80% off, odds 70 / 25 / 5")
	var exec_m := {"id": 999, "area": "bay", "rarity": 2, "ability": "trade_prices", "crew": "jdm"}
	var jun_m := {"id": 998, "area": "bay", "rarity": 0, "ability": "foam_party", "crew": "jdm"}
	check(absf(gs.ability_duration(exec_m) - 600.0) < 0.01 and absf(gs.ability_cooldown(exec_m) - 1200.0) < 0.01, "Executive discount: 10 min, recharge 20 min")
	check(absf(gs.ability_duration(jun_m) - 60.0) < 0.01 and absf(gs.ability_cooldown(jun_m) - 240.0) < 0.01, "Junior: 1 min, recharge 4 min")
	var hc0: float = gs.hire_cost("bay")
	gs.hires["bay"] += 1
	check(absf(gs.hire_cost("bay") / hc0 - 3.0) < 0.001, "each hire costs x3 more (was x8)")
	gs.hires["bay"] -= 1
	gs.cash = 1e30
	MP17.tab = "premium"
	main17._open_manager_panel("bay2")
	await wait(0.3)
	mp = main17.open_sheet("manager", "bay2")
	mp._on_hire()
	var hired_last: Dictionary = gs.managers[-1]
	check(MP17.tab == str(gs.ability_def(hired_last)["kind"]) and mp._new_id == int(hired_last["id"]), "HIRE jumps to the new manager's tab (%s)" % MP17.tab)
	await wait(0.2)
	await shot("v17d_hire_jump")
	MP17.tab = "premium"
	mp._rebuild()
	await wait(0.2)
	await shot("v17d_premium_tab_gold")
	close_sheets()
	# v0.17d-2: fixed layout, greyed recharging managers, even ability spread, jump buttons
	var free_one: Dictionary = gs.free_managers_in_area("bay")[0]
	free_one["ready_at"] = gs.now + 200.0
	MP17.tab = str(gs.ability_def(free_one)["kind"])
	main17._open_manager_panel("bay2")
	await wait(0.4)
	mp = main17.open_sheet("manager", "bay2")
	var hire_y: float = mp._hire.global_position.y
	var recharge_txt := ""
	for c in mp._cooldowns:
		if c[2] == free_one:
			recharge_txt = c[0].text
	check(recharge_txt.begins_with("Recharging: 3m"), "recharging manager greyed out with time left ('%s')" % recharge_txt)
	check(mp.body.find_children("*", "Label", true, false).all(func(l): return l.text != "Free"), "no 'Free' label on cards")
	await shot("v17d2_recharging_grey")
	var ys := []
	for t2 in ["premium", "speed", "discount", "income"]:
		MP17.tab = t2
		mp._rebuild()
		await wait(0.15)
		ys.append(mp._hire.global_position.y)
	gs.unassign_manager(gs.manager_at("bay2")["id"])
	await wait(0.2)
	ys.append(mp._hire.global_position.y)
	check(ys.all(func(y): return absf(y - hire_y) < 1.0), "HIRE stays put across tabs and with nobody at the station (%s)" % str(ys))
	await shot("v17d2_empty_station_panel")
	close_sheets()
	gs.go_to_city("lima")
	gs.cash = 1e40
	var before := {}
	for a in Data.ABILITIES["desk"]:
		before[a["id"]] = gs.managers.filter(func(x): return x["area"] == "desk" and x["home"] == "lima" and x["ability"] == a["id"]).size()
	for k in 30:
		gs.hire_manager("desk")
	var spread := []
	for a in Data.ABILITIES["desk"]:
		spread.append(gs.managers.filter(func(x): return x["area"] == "desk" and x["home"] == "lima" and x["ability"] == a["id"]).size())
	check(spread.max() - spread.min() <= 1, "hires even out across speed / discount / income %s (before %s)" % [str(spread), str(before.values())])
	build_all()
	await wait(0.6)
	var jumps = main17._jump_down
	main17._scroll_to_bottom()
	await wait(0.6)
	check(main17._scroll.scroll_vertical > 200 and jumps.visible, "down button: bottom of the shop (%d)" % main17._scroll.scroll_vertical)
	await shot("v17d2_jump_buttons")
	main17._scroll_to_top()
	await wait(0.6)
	check(main17._scroll.scroll_vertical == 0, "up button: top")
	# Dazza's signature ability: Tip Jar
	var dzm: Dictionary = own("dazza")
	gs.assign_manager("dazza", "bay0")
	dzm["ready_at"] = 0.0
	check(gs.ability_def(dzm)["kind"] == "signature" and absf(gs.ability_duration(dzm) / (1.0 + Data.DURATION_PER_LEVEL * (int(dzm["level"]) - 1)) - 30.0) < 0.5,
		"Dazza's Tip Jar lasts 30s (%.1fs)" % gs.ability_duration(dzm))
	gs.bays[0]["ready"] = 0.0
	gs.activate_ability("bay0")
	await wait(5.0)
	var jar0: float = float(dzm.get("jar", 0.0))
	check(jar0 > 0.0, "his bay's cars go into the tip jar (%s)" % gs.money(jar0))
	await shot("v17d_tip_jar_filling")
	gs.cash = 0.0
	var cash_tj: float = gs.cash
	var jar1: float = float(dzm["jar"])
	dzm["active_until"] = gs.now - 0.1
	await wait(0.4)
	check(float(dzm["jar"]) == 0.0 and gs.cash - cash_tj >= jar1 * gs.tip_jar_mult(dzm) * 0.99, "time's up: he cashes it x%s straight to you (+%s)" % [str(gs.tip_jar_mult(dzm)), gs.money(gs.cash - cash_tj)])
	await shot("v17d_tip_jar_payout")
	dzm["level"] = 50
	check(absf(gs.tip_jar_mult(dzm) - 5.0) < 0.001, "Tip Jar pays x5 at Lv 50")
	gs.assign_manager(busy["id"], "bay2")
	check(gs.manager_at("bay1").get("id", -1) == busy["id"] and busy["assigned"] == "bay1", "a busy cash manager can't be pulled to another bay")
	gs.unassign_manager(busy["id"])
	gs.assign_manager(busy["id"], "bay2")
	check(gs.manager_at("bay2").get("id", -1) == busy["id"], "after Remove it can be assigned")
	# PREMIUM tab: every owned premium manager, assigning a busy one asks first
	own("hana"); own("yuki")
	gs.assign_manager("hana", "bay0")
	MP17.tab = "premium"
	main17._open_manager_panel("bay1")
	await wait(0.4)
	mp = main17.open_sheet("manager", "bay1")
	var names := []
	for l in mp.body.find_children("*", "Label", true, false):
		if l.text.begins_with("Hana") or l.text.begins_with("Yuki") or l.text.begins_with("Dazza"):
			names.append(l.text.split("  ")[0])
	check(names.has("Hana") and names.has("Yuki"), "PREMIUM tab lists free and working premium managers (%s)" % str(names))
	await shot("v17_06_premium_tab")
	var hana_btn: Button = null
	for b in mp.body.find_children("*", "Button", true, false):
		if b.text == "Assign":
			var card: Node = b.get_parent().get_parent()
			for l in card.find_children("*", "Label", true, false):
				if l.text.begins_with("Hana"):
					hana_btn = b
	check(hana_btn != null, "Hana has an Assign button")
	hana_btn.pressed.emit()
	await wait(0.4)
	check(mp._confirm != null and is_instance_valid(mp._confirm) and gs.manager_at("bay0").get("id", "") == "hana", "assigning busy Hana asks first (she's still at Bay 1)")
	var pop_text := ""
	for l in mp._confirm.find_children("*", "Label", true, false):
		pop_text += l.text + " "
	check(pop_text.contains("Hana is currently at Bay 1 in Lima"), "popup: '%s'" % pop_text.left(60))
	await shot("v17_07_premium_confirm")
	for b in mp._confirm.find_children("*", "Button", true, false):
		if b.text == "ASSIGN":
			b.pressed.emit()
	await wait(0.3)
	check(gs.manager_at("bay1").get("id", "") == "hana" and gs.manager_at("bay0").is_empty(), "ASSIGN moves Hana to Bay 2")
	MP17.tab = "speed"
	close_sheets()
	# item 13: renovation tiers
	check(gs.bay_reno_tier(4) == 0 and gs.bay_reno_tier(5) == 1 and gs.bay_reno_tier(10) == 2 and gs.bay_reno_tier(15) == 3, "city tiers: bays 6-10 / 11-15 / 16-20")
	check(absf(gs.tier_income_mult(5) - Data.RENO_TIER_INCOME) < 1e-6 and absf(gs.tier_cost_mult(15) - pow(Data.RENO_TIER_COST, 3)) < 1e-3, "tier bays earn x%s, their levels cost x%s per tier" % [str(Data.RENO_TIER_INCOME), str(Data.RENO_TIER_COST)])
	gs.cash = 1e15
	build_all()
	check(gs.bays.size() >= 6, "built past the 1st renovation (%d bays)" % gs.bays.size())
	var c5: float = gs.levels_cost("bay5", 1)
	var c4: float = gs.levels_cost("bay4", 1) * pow(Data.BAY_LEVEL_GROWTH, gs.level_of("bay5") - gs.level_of("bay4"))
	check(absf(c5 / c4 / (Data.BAY_LEVEL_COST_GROWTH * Data.RENO_TIER_COST) - 1.0) < 1e-3, "bay 6 levels cost x%s more than bay 5's" % str(Data.BAY_LEVEL_COST_GROWTH * Data.RENO_TIER_COST))
	check(gs.bay_income(5, 1) / gs.bay_income(4, 1) > Data.BAY_IPS_GROWTH * Data.RENO_TIER_INCOME * 0.99, "bay 6 earns x%s more than bay 5 at the same level" % str(Data.BAY_IPS_GROWTH * Data.RENO_TIER_INCOME))
	# item 12 + 6: prestige rule
	check(gs.prestige_needs("lima") == "" and gs.prestige_cost("hometown") < 0.0, "prestige needs no city; Hometown has no prestige")
	# item 11: renovation strip shot (the next renovation)
	gs.cash = 0.0
	while gs.bays.size() > 10:
		gs.bays.pop_back()
	gs.cities["lima"]["renos"] = 1
	gs.state_changed.emit()
	main17._toast_queue = []
	await wait(2.0)
	main17._scroll.scroll_vertical = 100000
	await wait(0.6)
	await shot("v17_08_begin_renovation")
	main17._scroll.scroll_vertical = 0
	await wait(0.2)

	print("late game look")
	gs.cash = 1e40
	build_all()
	gs.cash = 1e16
	for i in gs.bays.size():
		gs.buy_levels("bay%d" % i, 30 + i * 13)
		if not gs.is_automated("bay%d" % i):
			gs.hire_manager("bay%d" % i)
	for k in ["valet", "desk"]:
		if not gs.is_automated(k):
			gs.hire_manager(k)
	gs.buy_levels("valet", 150)
	gs.buy_levels("desk", 150)
	gs.activate_ability("valet")
	await wait(3.0)
	await shot("08_late_top")
	var scroll: ScrollContainer = main.find_children("*", "ScrollContainer", true, false)[0]
	scroll.scroll_vertical = 700
	await wait(1.0)
	await shot("09_late_scrolled")
	scroll.scroll_vertical = 100000
	await wait(0.5)
	await shot("10_late_bottom")

	print("offline")
	gs.pending_offline = {}
	gs._grant_offline(3600.0)
	check(gs.pending_offline_earnings > 0.0, "offline earnings %s for 1h" % gs.fmt(gs.pending_offline_earnings))
	await wait(0.3)
	await shot("11_welcome_back")

	await _v17g_checks()
	await _v17h_checks()
	await _v17h3_checks()
	await _v18_checks()
	await _v19_checks()
	await _v19e_checks()
	await _v19f_checks()
	await _v19g_checks()
	await _v19h_checks()
	await _v19i_checks()
	await _v19j_checks()
	await _v19j2_checks()
	await _v19j3_checks()
	await _v19j4_checks()
	await _v19k_checks()
	await _v19m_checks()
	await _v19n_checks()
	await _v19o_checks()
	await _v19r_checks()
	await _v19t_checks()
	await _v19u_checks()
	await _v19v_checks()
	await _v19w_checks()

	gs.reset_save()
	print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails else 0)


## v0.17g: Hamza's 17 Oct playtest list (polish for the girlfriend playtest)
func _v17g_checks() -> void:
	print("v0.17g polish")
	var gs = GameState
	var m = main_node()
	gs.reset_save()
	await wait(0.3)
	gs.finish_tutorial(true)
	close_sheets()
	m._popup.visible = false
	# music + sound board
	check(Sfx._tracks.size() >= 3, "music: %d tracks found in assets/game/music" % Sfx._tracks.size())
	check(Sfx.pick("click") == 0 and Sfx.SOUNDS["click"][0][1][0] == "pop_click", "soft pop is the default click")
	Sfx.set_pick("cash", 1)
	check(Sfx.pick("cash") == 1 and gs.settings["sfx_pick"]["cash"] == 1, "sound board pick is saved")
	Sfx.set_pick("cash", 0)
	gs.set_setting("music", false)
	Sfx.refresh_music()
	check(not Sfx._music.playing, "music off stops it")
	gs.set_setting("music", true)
	Sfx.refresh_music()
	m._open_shop()
	await wait(0.3)
	var sb = null
	for c in m.get_children():
		if c.has_method("setup") and c.get_script() == load("res://scripts/shop_panel.gd"):
			for b in c.find_children("*", "Button", true, false):
				if b.text.begins_with("SOUND BOARD"):
					sb = b
	check(sb != null, "Shop has the Sound board button")
	if sb != null:
		sb.pressed.emit()
	await wait(0.4)
	await shot("g1_sound_board")
	close_sheets()
	# scroll past your bays: the ground goes down to bay 20, renovation bands shown
	gs.cash = 1e6
	gs.buy_bay()
	gs.buy_bay()
	await wait(0.3)
	var depth = null
	for c in m._rows.get_children():
		if c.get_script() == load("res://scripts/depth_row.gd"):
			depth = c
	check(depth != null and absf(depth.custom_minimum_size.y - (20 - 3 - 1) * load("res://scripts/bay_card.gd").HEIGHT) < 1.0, "the ground below shows the %d bay slots still to come" % (20 - 3 - 1))
	m._scroll.scroll_vertical = 100000
	await wait(0.4)
	await shot("g2_depth")
	m._scroll_to_bottom()
	await wait(0.6)
	check(m._scroll.scroll_vertical < m._build_row.position.y + 10, "jump-down stops at the Build Bay strip, not the bottom of the dirt")
	m._scroll.scroll_vertical = 0
	# level panel preview ghost
	gs.cash = 1e5
	m._open_level_panel("bay0")
	await wait(0.3)
	var lp = null
	for c in m.get_children():
		if c.has_method("_draw_preview"):
			lp = c
	lp.mode_index = 1   # x10
	await wait(0.2)
	check(lp._preview_to > lp._next_bar.value + 0.05, "x10 shows a ghost further along the bar (%.2f -> %.2f)" % [lp._next_bar.value, lp._preview_to])
	lp.mode_index = 3   # next boost
	await wait(0.2)
	check(absf(lp._preview_to - 1.0) < 0.001, "NEXT BOOST fills the whole bar")
	await shot("g3_level_preview")
	gs.cash = 0.0
	lp.mode_index = 4   # max, can't afford anything
	await wait(0.2)
	check(absf(lp._preview_to - lp._next_bar.value) < 0.001, "MAX with no money shows no ghost")
	lp.mode_index = 0
	close_sheets()
	# overview: big rows + ability buttons
	gs.cash = 1e6
	gs.hire_manager("bay0"); gs.hire_manager("valet"); gs.hire_manager("desk")
	m._open_overview()
	await wait(0.6)
	var ov = null
	for c in m.get_children():
		if c.has_method("_manager_row"):
			ov = c
	var icons = ov.find_children("*", "", true, false).filter(func(n): return n.get_script() == load("res://scripts/ability_icon.gd"))
	check(icons.size() >= 3, "Overview rows have ability buttons (%d)" % icons.size())
	var mgr = gs.manager_at("bay0")
	icons.filter(func(n): return n.station_key == "bay0")[0].use()
	check(gs.ability_active(gs.manager_at("bay0")), "tapping it in the Overview fires that manager's ability")
	await wait(0.6)
	await shot("g4_overview")
	close_sheets()
	# title screen
	var ts = load("res://scripts/title_screen.gd").new()
	m.add_child(ts)
	await wait(1.0)
	await shot("g5_title")
	check(ts.is_inside_tree(), "title screen shows")
	var ev := InputEventMouseButton.new()
	ev.pressed = true
	ev.button_index = MOUSE_BUTTON_LEFT
	ts._gui_input(ev)
	await wait(0.5)
	check(not is_instance_valid(ts) or not ts.is_inside_tree(), "tapping the title screen goes to the shop")
	# a fresh bay drops in, the next car rolls in, renovation scaffolding, rare car red carpet
	gs.cash = 1e12
	gs.buy_bay()
	await wait(0.08)
	await shot("g6_bay_drop_in")
	await wait(0.6)
	while gs.reno_needed() == 0 and gs.bays.size() < 20:
		gs.buy_bay()
	gs.start_renovation()
	await wait(0.3)
	m._scroll_to_bottom()
	await wait(0.7)
	await shot("g7_renovating")
	m._scroll.scroll_vertical = 0
	# coins don't fly over full screens
	check(m._fx.get_index() < m.get_child_count() - 1, "flying coins sit on a layer under popups")


## v0.17h: the girlfriend playtest notes (text, top bar, tips, Book show strip, swipe, ute tap)
func _v17h_checks() -> void:
	print("v0.17h playtest notes")
	var gs = GameState
	var m = main_node()
	gs.reset_save()
	await wait(0.3)
	gs.finish_tutorial(true)
	close_sheets()
	m._popup.visible = false
	check(Data.PREMIUM_NAME == "Shine Bucks", "premium currency is called Shine Bucks")
	# top bar buttons -> info cards
	m._meta.premium_pressed.emit()
	await wait(0.4)
	await shot("h1_premium_card")
	var found := false
	for c in m.get_children():
		if c.has_method("setup_premium"):
			found = true
	check(found, "Shine Bucks button opens its explainer card")
	close_sheets()
	gs.add_followers(150.0)
	m._meta.rep_pressed.emit()
	await wait(0.4)
	await shot("h2_reputation_card")
	close_sheets()
	await wait(0.2)
	await shot("h3_top_bar")
	var bad_tips := []
	for id in m.TIPS.keys():
		var t: String = m.tip_text(id, 3 if id == "vip" else null)
		if t.contains("%s") or t.contains("%d") or t.contains("%%"):
			bad_tips.append(id)
	check(bad_tips.is_empty(), "every tip's text is filled in (%s)" % str(bad_tips))
	# tips: a first-time screen tip, shown once
	gs.tips_enabled = true
	gs.reset_tips()
	m._open_book()
	await wait(0.4)
	check(m._tips.busy() and m._tips.visible, "first time in the Book: a tip explains it")
	await shot("h4_book_tip")
	m._tips._dismiss()
	close_sheets()
	m._open_book()
	await wait(0.3)
	check(not m._tips.busy() and gs.tip_seen("book"), "... only once")
	# the Book category page shows what's on show
	var bp = null
	for c in m.get_children():
		if c.has_method("_show_page"):
			bp = c
	gs.book["corollo98"] = 1
	gs.toggle_display("corollo98")
	bp._show_page(1)
	await wait(0.4)
	check(bp._slots != null and bp._slots.get_child_count() == gs.display_slots(), "category page has the ON SHOW strip")
	await shot("h5_book_category_show")
	close_sheets()
	# first rare car: OK on the banner -> tip pointing at the car
	gs.cash = 1e6
	gs.buy_bay(); gs.buy_bay(); gs.buy_bay()
	await wait(0.2)
	gs.spawn_vip()
	await wait(0.6)
	if not gs.vip.is_empty():
		m._banner.visible = false   # (what OK on the banner does: hide it, then the tip)
		m._vip_tip()
		await wait(0.7)
		check(m._tips.busy() and m._tips._has_target, "first rare car: the tip points at it")
		await shot("h6_vip_tip")
		m._tips._dismiss()
	else:
		check(false, "could not spawn a rare car for the tip test")
	gs.tips_enabled = false
	# swipe in the level panel
	m._open_level_panel("desk")
	await wait(0.3)
	var lp = null
	for c in m.get_children():
		if c.has_method("_draw_preview"):
			lp = c
	var r: Rect2 = lp._panel.get_global_rect()
	var a := InputEventMouseButton.new()
	a.button_index = MOUSE_BUTTON_LEFT
	a.pressed = true
	a.position = r.get_center() + Vector2(150, 0)
	lp._input(a)
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = false
	b.position = r.get_center() + Vector2(-150, 10)
	lp._input(b)
	check(lp.key == "valet", "swiping left in the level panel goes to the next station (%s)" % lp.key)
	close_sheets()
	# tapping the ute (valet has a manager) opens its upgrades
	gs.hire_manager("valet")
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(40, 60)
	m._valet_row._gui_input(ev)
	var ev2 := ev.duplicate()
	ev2.pressed = false
	m._valet_row._gui_input(ev2)
	await wait(0.3)
	var opened := false
	for c in m.get_children():
		if c.has_method("_draw_preview") and c.key == "valet":
			opened = true
	check(opened, "tapping the ute opens the valet's upgrades")
	close_sheets()
	await shot("h7_main")
	# tutorial bubble hides behind the title screen
	gs.reset_save()
	await wait(0.3)
	var ts = load("res://scripts/title_screen.gd").new()
	m._title = ts
	m.add_child(ts)
	await wait(0.4)
	var tut = null
	for c in m.get_children():
		if c.get_script() == load("res://scripts/tutorial_overlay.gd"):
			tut = c
	check(tut != null and not tut.visible, "the tutorial bubble waits behind the title screen")
	ts.queue_free()
	await wait(0.3)
	check(tut.visible, "... and shows once the title is gone")
	gs.finish_tutorial(true)


## v0.17h-3 (Hamza: "too many stars"): prestige is a trophy by the city name, reputation is a review rating.
func _v17h3_checks() -> void:
	print("v0.17h-3 trophy + rating")
	var gs = GameState
	var m = main_node()
	gs.reset_save()
	await wait(0.3)
	gs.finish_tutorial(true)
	close_sheets()
	m._popup.visible = false
	check(is_equal_approx(gs.rating(1), 0.0) and is_equal_approx(gs.rating(2), 1.0) and is_equal_approx(gs.rating(Data.STAR_THRESHOLDS.size()), 5.0) and gs.rating_text(9) == "4.5",
		"No reviews + 9 rated steps = 1.0 to 5.0 (9 -> %s)" % gs.rating_text(9))
	check(gs.rating_text() == "NEW" and gs.rating_line() == "No reviews yet", "a new shop has no reviews yet (v0.19l)")
	var tb: Rect2 = m._prestige_badge.get_global_rect()
	var vw: float = m.get_viewport_rect().size.x
	check(absf(tb.get_center().x - vw * 0.5) < 2.0 and tb.position.y >= 30.0 and tb.end.y < 190.0,
		"the prestige trophy sits in the top middle of the HUD (%s)" % tb)
	check(not tb.intersects(m._meta.get_global_rect()), "the trophy doesn't overlap the gems / reputation pills")
	await shot("h3_hud_new")
	gs.followers = Data.STAR_THRESHOLDS[8] + 1.0
	gs.prestige = 2
	gs.cities[gs.active_city]["prestige"] = 2
	await wait(0.4)
	check(gs.rating_text() == "4.5", "rating follows followers (%s)" % gs.rating_text())
	await shot("h3_hud_trophy")
	m._meta.rep_pressed.emit()
	await wait(0.4)
	await shot("h3_rating_card")
	close_sheets()
	await wait(0.2)


## v0.18: from Paint Correction (Lv 100) cars take at least PC_MIN_CAR_TIME; income per second must not move,
## rare-car pay must not move, and crossing Lv 100 mid-car must not hand out a windfall.
func _v18_checks() -> void:
	print("v0.18 Lv100 car time")
	var gs = GameState
	gs.reset_save()
	await wait(0.3)
	gs.finish_tutorial(true)
	close_sheets()
	check(is_equal_approx(gs.bay_base_time(0, 99), 4.0) and is_equal_approx(gs.bay_base_time(0, 100), Data.PC_MIN_CAR_TIME),
		"Bay 1: 4s per car until Lv 100, then %ss" % str(Data.PC_MIN_CAR_TIME))
	check(is_equal_approx(gs.bay_base_time(12, 100), 4.0 + 0.5 * 12), "deep bays already over the minimum keep their time")
	var r: float = gs.bay_income(0, 100) / gs.bay_income(0, 99)
	var want: float = (100.0 * gs.boost_mult("bay0", 100)) / (99.0 * gs.boost_mult("bay0", 99))
	check(absf(r / want - 1.0) < 1e-6, "the Lv 100 car time doesn't change income per second (x%.3f, boosts say x%.3f)" % [r, want])
	gs.bays[0]["level"] = 120
	check(is_equal_approx(gs.bay_cycle_time(0), Data.PC_MIN_CAR_TIME), "Lv 120 bay: %.1fs per car" % gs.bay_cycle_time(0))
	var car_id: String = gs.bays[0]["car"]
	check(absf(gs.bay_pay_per_car(0) / gs.vip_base_pay(0, car_id) - Data.PC_MIN_CAR_TIME / 4.0) < 1e-6,
		"a car pays more for the longer time, rare-car pay doesn't")
	gs.bays[0]["level"] = 99
	gs.cash = 1e30
	gs.bays[0]["progress"] = 0.9
	gs.buy_levels("bay0", 1)
	check(gs.bays[0]["level"] == 100 and absf(float(gs.bays[0]["progress"]) - 0.9 * 4.0 / Data.PC_MIN_CAR_TIME) < 1e-6,
		"crossing Lv 100 mid-car keeps the seconds already worked (progress %.3f)" % float(gs.bays[0]["progress"]))


## v0.19 step 3: the posh cash managers in the stations + list portraits (ManagerRig / ManagerAnim / ManagerAura)
func _v19_checks() -> void:
	print("v0.19 posh managers in the stations")
	var gs = GameState
	var SM = load("res://scripts/station_manager.gd")
	var Rig = load("res://scripts/manager_rig.gd")
	gs.reset_save()
	await wait(0.3)
	gs.finish_tutorial(true)
	gs.first_vip_done = true
	gs._first_vip_timer = -1e9
	close_sheets()
	gs.cash = 1e15
	gs.buy_bay()
	gs.buy_bay()
	# one of each tier, a mix of abilities (kind decides the aura colour)
	var plan := [["desk", "desk", 2, "upsell"], ["valet", "valet", 1, "lead_foot"], ["bay0", "bay", 0, "trade_prices"],
		["bay1", "bay", 1, "foam_party"], ["bay2", "bay", 2, "elbow_grease"]]
	var men := {}
	for p in plan:
		var m: Dictionary = gs._make_manager(p[1], p[2], gs.active_city)
		m["ability"] = p[3]
		m["city"] = gs.active_city
		m["assigned"] = p[0]
		gs.managers.append(m)
		men[p[0]] = m
	gs._rebuild_assigned()
	var main := main_node()
	main._scroll.scroll_vertical = 0
	await wait(0.6)
	var ports := {"desk": main._desk_row.portrait, "valet": main._valet_row.portrait}
	for i in 3:
		ports["bay%d" % i] = main._bay_rows[i]._portrait
	for key in ports:
		var por = ports[key]
		var m: Dictionary = men[key]
		check(por._anim != null and por._anim.look in Rig.looks_of_tier(int(m["rarity"])),
			"%s: posh %s look %d" % [key, ["Junior", "Senior", "Executive"][int(m["rarity"])], por._anim.look if por._anim != null else -1])
		check(por._anim != null and por._anim.idle == SM.pose_of(m), "%s: idle loop = pose_of (%d)" % [key, SM.pose_of(m)])
		check(por._anim != null and is_equal_approx(por._anim.point_dir, -1.0 if key == "valet" else 1.0),
			"%s faces %s" % [key, "left (the ute)" if key == "valet" else "right"])
		check(not por.clip_contents, "%s: the portrait doesn't clip (aura + arm reach outside it)" % key)
	# same person = same look, every time; every tier draws from its own pool
	var ok_tier := true
	for i in 60:
		var fake := {"id": 1000 + i, "rarity": i % 3, "name": "X"}
		var li: int = SM.look_of(fake)
		ok_tier = ok_tier and li in Rig.looks_of_tier(i % 3) and li == SM.look_of(fake.duplicate())
	check(ok_tier, "look_of: always the same look for the same manager, from their tier's pool")
	var used := {}
	for i in 60:
		used[SM.look_of({"id": 2000 + i, "rarity": i % 3})] = true
	check(used.size() >= 14, "60 hires use %d of the 17 looks" % used.size())
	check(ports["bay0"]._aura < 0.01 and ports["bay0"]._anim.blend < 0.01, "idle: no aura, no instructing")
	await shot("v19_01_managers_idle")
	# abilities on: instruct + suds aura in the ability's colour
	for key in ports:
		gs.activate_ability(key)
	await wait(0.35)
	await shot("v19_02_managers_starting")
	await wait(1.0)
	var all_on := true
	for key in ports:
		var por = ports[key]
		all_on = all_on and por._aura > 0.99 and por._anim.blend > 0.99 and por._kind == str(gs.ability_def(men[key])["kind"])
	check(all_on, "ability running: every manager instructs with the aura in their ability's colour")
	await shot("v19_03_managers_instruct")
	# the old 2x idle is gone: the anim clock runs at normal speed while the ability runs
	var t0: float = ports["desk"]._anim.t
	await wait(0.5)
	var dt: float = ports["desk"]._anim.t - t0
	check(dt > 0.3 and dt < 0.8, "no 2x speed-up while instructing (clock moved %.2fs in 0.5s)" % dt)
	# list portraits: the same person, head to chest
	main._open_manager_panel("bay2")
	await wait(0.5)
	var busts := main.find_children("*", "Control", true, false).filter(func(n): return n.get_script() == load("res://scripts/portrait.gd") and n._bust != null)
	check(busts.size() >= 1 and busts[0]._bust.look == ports["bay2"]._anim.look, "manager panel shows the same posh manager as the station")
	await shot("v19_04_manager_panel")
	close_sheets()
	main._open_overview()
	await wait(0.5)
	await shot("v19_05_overview")
	close_sheets()
	# ability over: the aura fades and they settle back into their idle loop
	for key in men:
		men[key]["active_until"] = gs.now - 1.0
	await wait(1.7)
	var all_off := true
	for key in ports:
		all_off = all_off and ports[key]._aura < 0.01 and ports[key]._anim.blend < 0.01
	check(all_off, "ability over: aura gone, back to the idle loop")
	# swapping who works there rebuilds the animation for the new person
	var old_look: int = ports["bay1"]._anim.look
	var m2: Dictionary = gs._make_manager("bay", 2, gs.active_city)
	m2["city"] = gs.active_city
	gs.managers.append(m2)
	gs.assign_manager(m2["id"], "bay1")
	await wait(0.3)
	check(ports["bay1"]._anim_id.begins_with(str(m2["id"]) + "|") and ports["bay1"]._anim.look in Rig.looks_of_tier(2),
		"a new manager at Bay 2 gets their own look (was %d, now %d)" % [old_look, ports["bay1"]._anim.look])


## v0.19e: the front desk cashier (prototype v4) replaces the Kenney cashier; at most 2 drawn
func _v19e_checks() -> void:
	print("v0.19e front desk cashier")
	var gs = GameState
	gs.reset_save()
	await wait(0.3)
	gs.finish_tutorial(true)
	gs.first_vip_done = true
	gs._first_vip_timer = -1e9
	close_sheets()
	var main := main_node()
	main._scroll.scroll_vertical = 0
	var desk = main._desk_row
	check(desk.cashier_count() == 1, "Lv 1: one cashier at the desk")
	gs.desk["lot"] = 50.0
	gs.tap_desk()
	await wait(0.6)
	check(desk._cashiers[0].working > 0.9, "tapping the desk: she counts the notes")
	await shot("v19e_01_counting")
	await wait(3.0)
	check(desk._cashiers[0]._cheer_t > 0.0, "a payout you tapped for: she cheers")
	gs.desk["level"] = 30
	await wait(0.2)
	check(desk.cashier_count() == 2, "Lv 30 (Second Cashier): two cashiers")
	gs.desk["level"] = 400
	await wait(0.1)
	check(desk.cashier_count() == 2, "Lv 400 (crew %d): still only two drawn" % int(gs.current_boost("desk")["crew"]))
	gs.desk["level"] = 30
	check(desk.cashier_x(1, 2) - desk.cashier_x(0, 2) >= 70.0 and desk.cashier_x(1, 2) < 316.0 + (desk.size.x - 112.0 - 316.0) - 130.0,
		"the two stand apart and clear of the till")
	var m: Dictionary = gs._make_manager("desk", 1, gs.active_city)
	m["city"] = gs.active_city
	m["assigned"] = "desk"
	gs.managers.append(m)
	gs._rebuild_assigned()
	gs.desk["lot"] = 1e6
	var c0: float = desk._cashiers[0]._cheer_t
	await wait(3.5)
	check(desk._cashiers[0]._smile_t > 0.0 and is_equal_approx(desk._cashiers[0]._cheer_t, c0),
		"a manager runs the desk: just a happy face per payout, no arm pump (calm screen)")
	await shot("v19e_02_two_cashiers")


## v0.19f: the key board shows 0..3 proper car keys by how much cash is waiting in the bay.
func _v19f_checks() -> void:
	print("v0.19f desk + keys + trophy")
	var gs = GameState
	var m = main_node()
	gs.reset_save()
	await wait(0.3)
	gs.finish_tutorial(true)
	close_sheets()
	m._popup.visible = false
	m._scroll.scroll_vertical = 0
	for v in [0.0, 5.0, 500.0, 50000.0]:
		gs.bays[0]["ready"] = v
		await wait(0.25)
		await shot("v19f_keys_%d" % int(v))
	check(true, "the key board draws 0..3 car keys")


## v0.19g: the new front desk art: the register grows with the desk, and the showroom window behind the
## cashiers shows the Book showcase (slots 1-3 in front, 4-10 on the back shelf).
func _v19g_checks() -> void:
	print("v0.19g desk art + showroom")
	var gs = GameState
	var m = main_node()
	var desk = m._desk_row
	var DR = load("res://scripts/desk_row.gd")
	var BD = load("res://scripts/desk_backdrop.gd")
	check(DR.register_stage(1) == "tin" and DR.register_stage(10) == "card" and DR.register_stage(49) == "card"
		and DR.register_stage(50) == "retro" and DR.register_stage(200) == "pos" and DR.register_stage(400) == "pos",
		"the register: cash tin, + card reader (Lv 10), cash register (Lv 50), touchscreen (Lv 200)")
	check(desk.backdrop != null and desk.backdrop.show_behind_parent and desk.backdrop.get_index() == 0,
		"the wall + showroom are drawn behind the desk")
	gs.reset_save()
	await wait(0.3)
	gs.finish_tutorial(true)
	close_sheets()
	m._popup.visible = false
	m._scroll.scroll_vertical = 0
	check(BD.showroom_cars()[0].is_empty(), "a new shop: empty showroom (pale mystery cars)")
	var ids: Array = []
	for car in Data.CARS.slice(-12):
		ids.append(car["id"])
		gs.book[car["id"]] = 1
	gs.display = ids.slice(0, 2)
	await wait(0.6)
	var sig0: String = desk.backdrop._sig
	await shot("v19g_01_showroom_2")
	gs.display = ids.slice(0, 10)
	await wait(0.6)
	var sc: Array = BD.showroom_cars()
	check(sc[0].size() == 3 and sc[1].size() == 7 and sc[0][0] == ids[0], "10 in the showcase: the first 3 in front, 7 on the back shelf")
	check(desk.backdrop._sig != sig0, "changing the showcase redraws the showroom")
	for lv in [1, 12, 60, 220]:
		gs.desk["level"] = lv
		gs.desk["lot"] = 1e6
		gs.desk["running"] = true
		gs.desk["progress"] = 0.5
		await wait(0.05)
		await shot("v19g_reg_%d" % lv)
		gs.desk["progress"] = 0.93
		await wait(0.02)
		await shot("v19g_reg_%d_open" % lv)
	gs.display = []


## v0.19h: one-time tips + music settings survive closing and reopening the game.
func _v19h_checks() -> void:
	print("v0.19h settings survive a restart")
	var gs = GameState
	gs.reset_save()
	await wait(0.2)
	gs.mark_tip("star")
	gs.mark_tip("desk_slow")
	gs.set_setting("music", false)
	gs.set_setting("music_volume", 0.25)
	gs.save_game()
	gs.settings = {"rare_alerts": true, "sound": true, "vibration": true, "ad_free": true, "music": true, "music_volume": 0.6}
	check(not gs.tip_seen("star"), "(wiped in memory)")
	gs.load_game()
	check(gs.tip_seen("star") and gs.tip_seen("desk_slow") and not gs.tip_seen("vip"), "seen tips stay seen after reopening the game")
	check(gs.settings["music"] == false and is_equal_approx(float(gs.settings["music_volume"]), 0.25), "music on/off + volume survive reopening")
	gs.reset_save()


## v0.19i: level panel stats (Idle Miner style), Shine Bucks for bays + finishing renovations, bay-sized build strip.
func _v19i_checks() -> void:
	print("v0.19i level panel stats + shine bucks + build strip")
	var gs = GameState
	var m = main_node()
	gs.reset_save()
	await wait(0.3)
	gs.finish_tutorial(true)
	close_sheets()
	m._popup.visible = false
	gs.cash = 1e4
	m._open_level_panel("bay0")
	await wait(0.4)
	var lp = null
	for c in m.get_children():
		if c.has_method("_draw_preview"):
			lp = c
	check(lp != null and lp._rows.size() == 3 and lp._rows.has("income") and lp._rows["income"][0].text.ends_with("/s"),
		"bay level panel: Income / Pay per Car / Time per Car rows")
	check(lp._rows["income"][1].text.begins_with("+$"), "a green '+' shows what the upgrade adds (%s)" % lp._rows["income"][1].text)
	var ph: float = lp._panel.size.y
	var vh: float = m.get_viewport_rect().size.y
	check(ph > vh * 0.68 and lp._sheet_scroll.get_v_scroll_bar().max_value <= lp._sheet_scroll.size.y + 1.0,
		"the panel fills ~3/4 of the screen and nothing scrolls (%d of %d px)" % [int(ph), int(vh)])
	check(lp._next.text.contains("x2 income"), "the next boost says what it gives: '%s'" % lp._next.text)
	await shot("v19i_01_level_bay")
	lp.step(-1)
	await wait(0.2)
	check(lp.key == "valet" and lp._rows.size() == 4 and lp._rows.has("drive"), "valet: Total Transport / Load / Loading Speed / Driving Speed")
	await shot("v19i_02_level_valet")
	lp.step(-1)
	await wait(0.2)
	check(lp.key == "desk" and lp._rows.size() == 3 and lp._rows.has("batch"), "front desk: Total Checkout / Cash per Checkout / Checkout Time")
	await shot("v19i_03_level_desk")
	lp.close()
	await wait(0.2)
	# Shine Bucks for a bay you can't afford yet
	gs.cash = 0.0
	gs.tutorial_step = 0
	check(not m._build_row._show_gloss_buy(), "no Shine Bucks bay button during the tutorial")
	gs.finish_tutorial(true)
	close_sheets()
	m._popup.visible = false
	gs.cash = 0.0
	check(m._build_row._show_gloss_buy(), "after the tutorial it shows")
	var g1: int = gs.bay_gloss_cost()
	check(g1 >= Data.BAY_GLOSS_MIN and g1 <= Data.BAY_GLOSS_MAX, "a bay out of reach has a Shine Bucks price (%d)" % g1)
	gs.cash = gs.next_bay_cost() * 0.999
	check(gs.bay_gloss_cost() == Data.BAY_GLOSS_MIN, "almost affordable: the minimum %d" % Data.BAY_GLOSS_MIN)
	gs.cash = 0.0
	var rows_y: float = m._build_row.position.y
	var content_h: float = m._rows.get_combined_minimum_size().y
	check(is_equal_approx(m._build_row.size.y, load("res://scripts/bay_card.gd").HEIGHT), "the Build Bay strip is exactly one bay tall")
	m._scroll_to_bay(gs.bays.size() - 1)
	await wait(0.8)
	await shot("v19i_04_build_strip_sb")
	gs.gloss = 1000
	var n0: int = gs.bays.size()
	var gb: int = gs.bay_gloss_cost()
	m._build_row._tap(m._build_row._sb_rect().get_center())
	check(gs.bays.size() == n0 and m._build_row.confirming(), "first tap on the Shine Bucks button only asks to confirm")
	await wait(0.1)
	await shot("v19i_05_confirm")
	m._build_row._tap(m._build_row._sb_rect().get_center())
	await wait(0.3)
	check(gs.bays.size() == n0 + 1 and gs.gloss == 1000 - gb and gs.cash == 0.0, "second tap: bay built for %d Shine Bucks, no cash spent" % gb)
	check(absf(m._build_row.position.y - (rows_y + load("res://scripts/bay_card.gd").HEIGHT)) < 1.0
		and absf(m._rows.get_combined_minimum_size().y - content_h) < 1.0,
		"the new bay takes the strip's place exactly: nothing below jumps")
	# finish a renovation with Shine Bucks
	gs.cash = 1e17
	for k in 10:
		if gs.reno_needed() > 0:
			break
		gs.buy_bay()
	check(gs.reno_needed() > 0, "reached a renovation")
	gs.start_renovation()
	var fc: int = gs.reno_finish_cost()
	check(fc == maxi(Data.RENO_FINISH_MIN, int(ceil(gs.reno_left() / 60.0 / Data.RENO_GLOSS_MINUTES))) and fc >= 30,
		"finishing costs 1 per 2 min left (%d for %s)" % [fc, gs.fmt_time(gs.reno_left())])
	await wait(0.3)
	m._scroll.scroll_vertical = int(m._build_row.position.y - 500.0)
	await wait(0.5)
	await shot("v19i_06_reno_finish")
	var done0: int = gs.reno_done()
	gs.gloss = 5
	check(not gs.finish_reno_gloss() and gs.reno_running(), "not enough Shine Bucks: nothing happens")
	gs.gloss = 2000
	check(gs.finish_reno_gloss() and not gs.reno_running() and gs.reno_done() == done0 + 1,
		"Shine Bucks finish the WHOLE renovation at once")
	gs.reset_save()


## v0.19j: girlfriend's playtest round 2: "you're good to go didn't last long enough to read" ->
## every big message and toast stays until you tap OK.
func _big_title(m) -> String:
	if not m.big_showing():
		return ""
	var ls: Array = m._big_node.find_children("*", "Label", true, false)
	return ls[0].text if not ls.is_empty() else ""


func _big_ok(m) -> Button:
	if not m.big_showing():
		return null
	var bs: Array = m._big_node.find_children("*", "Button", true, false)
	return bs[0] if not bs.is_empty() else null


func _v19j_checks() -> void:
	print("v0.19j popups wait for OK")
	var gs = GameState
	var m = main_node()
	gs.reset_save()
	await wait(0.3)
	gs.finish_tutorial(true)
	close_sheets()
	m._popup.visible = false
	await wait(2.6)   # old-style messages from earlier fade away
	m._big_queue = []
	m._toast_queue = []
	gs.popups_need_ok = true
	# the tutorial's last message
	gs.tutorial_finished.emit()
	await wait(3.5)
	check(_big_title(m) == "YOU'RE GOOD TO GO!", "'YOU'RE GOOD TO GO!' is still up after 3.5 s (%s)" % _big_title(m))
	var ok := _big_ok(m)
	check(ok != null and ok.text == "OK" and ok.is_visible_in_tree(), "... with an OK button")
	check(m._big_node.mouse_filter == Control.MOUSE_FILTER_STOP and m.is_blocking_popup_open(), "... and taps don't go through to the shop while it's up")
	await shot("v19j_01_good_to_go_ok")
	m._big_banner("PRESTIGE!", Color("ce93d8"), "Second message")
	await wait(0.3)
	var cards := 0
	for c in m.get_children():
		if c is ColorRect and c == m._big_node:
			cards += 1
	check(cards == 1 and m._big_queue.size() == 1 and _big_title(m) == "YOU'RE GOOD TO GO!", "a second message waits its turn (never two cards)")
	ok.pressed.emit()
	await wait(0.5)
	check(_big_title(m) == "PRESTIGE!", "OK: the next waiting message comes in (%s)" % _big_title(m))
	m._big_at = Time.get_ticks_msec()
	_big_ok(m).pressed.emit()
	await wait(0.3)
	check(_big_title(m) == "PRESTIGE!", "a tap in the first moment doesn't close it (stray taps while playing)")
	m._big_at -= 1000
	_big_ok(m).pressed.emit()
	await wait(0.4)
	check(not m.big_showing() and m._big_queue.is_empty() and not m._big_busy, "OK on the last one: all clear")
	# a new star: one message with what it gives, no second toast
	m._toast_queue = []
	gs.followers = maxf(gs.followers, Data.STAR_THRESHOLDS[1])   # v0.19l: past the first reviews
	gs.add_followers(gs.next_star_followers() - gs.followers + 1.0)
	await wait(0.5)
	var star_sub := ""
	if m.big_showing():
		var ls: Array = m._big_node.find_children("*", "Label", true, false)
		star_sub = ls[1].text if ls.size() > 1 else ""
		for rl in m._big_node.find_children("*", "RichTextLabel", true, false):   # v0.19v: rich when it has an icon
			star_sub = rl.get_parsed_text()
	check(_big_title(m).ends_with("STARS!") and star_sub.contains("Booster"), "new star: one message with its rewards (%s / %s)" % [_big_title(m), star_sub])
	check(not m._toast_busy and m._toast_queue.is_empty(), "... and no extra toast for it")
	await shot("v19j_02_star_ok")
	m._big_at -= 1000
	_big_ok(m).pressed.emit()
	await wait(0.4)
	# toasts: stay until OK, the next one takes its place
	m._show_toast("Lima: renovation done (Car Wash). +25 Shine Bucks, +5 Certs")
	await wait(3.0)
	check(m._toast_box.visible and m._toast_box.modulate.a > 0.99 and m._toast_ok.is_visible_in_tree() and m._toast.text.begins_with("Lima"),
		"a toast is still up after 3 s, with an OK button")
	check(m._toast_box.get_global_rect().end.y <= m.get_viewport_rect().size.y - 140.0, "... sitting above the bottom bar")
	var jump_tall: bool = m._rows.size.y > m._scroll.size.y + 60.0
	check(not m._jump_up.visible and not m._jump_down.visible, "... and the up / down jump buttons step aside under it")
	await shot("v19j_03_toast_ok")
	m._show_toast("Second toast")
	m._toast_at -= 1000
	m._toast_ok.pressed.emit()
	m._toast_ok.pressed.emit()   # a double tap only closes one
	await wait(0.4)
	check(m._toast_box.visible and m._toast.text == "Second toast", "OK: the next toast takes its place (%s)" % m._toast.text)
	m._toast_at -= 1000
	m._toast_ok.pressed.emit()
	await wait(0.4)
	check(not m._toast_box.visible and not m._toast_busy, "OK on the last toast: gone")
	check(m._jump_up.visible == jump_tall, "... and the jump buttons are back")
	# tips and big messages never stack: each waits for the other
	gs.tips_enabled = true
	gs.reset_tips()
	m._big_banner("SET COMPLETE!", Color("ce93d8"), "Book set complete: Daily Drivers!")
	await wait(0.3)
	m._open_book()
	await wait(0.5)
	check(not m._tips._queue.is_empty() and not m._tips.visible and m.big_showing(), "a tip waits while a big message is up")
	m._big_at -= 1000
	_big_ok(m).pressed.emit()
	await wait(0.5)
	check(m._tips.visible, "... and shows once it's OK'd")
	m._big_banner("RATED 2.0 STARS!", Color("ffca28"))
	await wait(0.4)
	check(not m.big_showing() and m._big_queue.size() == 1, "a big message waits while a tip is up")
	m._tips._dismiss()
	await wait(0.4)
	check(_big_title(m) == "RATED 2.0 STARS!", "... and comes in after GOT IT")
	m._big_at -= 1000
	_big_ok(m).pressed.emit()
	await wait(0.4)
	close_sheets()
	gs.tips_enabled = false
	gs.popups_need_ok = false
	gs.reset_save()


## v0.19j part 2 (girlfriend's playtest points 2-4 + Hamza: "not everything should need OK")
func _v19j2_checks() -> void:
	print("v0.19j-2 routine messages close themselves, tips wait for panels, hire wording, Book live strip")
	var gs = GameState
	var m = main_node()
	gs.reset_save()
	await wait(0.3)
	gs.finish_tutorial(true)
	close_sheets()
	m._popup.visible = false
	await wait(2.6)
	m._big_queue = []
	m._toast_queue = []
	gs.popups_need_ok = true
	# routine toasts close by themselves (dev cheats, VIP note with alerts off)
	m._show_toast("Skipped 1 hour", false)
	await wait(0.5)
	check(m._toast_box.visible and not m._toast_ok.visible, "a routine toast has no OK button")
	await wait(m.read_time("Skipped 1 hour") + 0.3)
	check(not m._toast_box.visible, "... and closes by itself after its reading time (%.1f s)" % m.read_time("Skipped 1 hour"))
	check(m.read_time("a b c") == 3.0 and m.read_time("one two three four five six seven eight nine ten eleven twelve") > 4.0
		and m.read_time(" ".join(range(60).map(func(i): return "w"))) == 6.0, "reading time: 3 s for short text, more per word, max 6 s")
	m._show_toast("Tap me away", false)
	await wait(0.5)
	m._dismiss_toast()
	await wait(0.3)
	check(not m._toast_box.visible, "a tap closes a routine toast early")
	# renovations finishing together -> one toast
	gs.renovation_done.emit("lima", 1)
	gs.renovation_done.emit("lima", 2)
	await wait(0.3)
	check(m._toast_box.visible and m._toast.text.begins_with("2 renovations done") and m._toast_queue.is_empty() and m._toast_ok.visible,
		"two renovations at once: one toast with OK (%s)" % m._toast.text)
	await shot("v19j2_01_reno_merged")
	m._toast_at -= 1000
	m._toast_ok.pressed.emit()
	await wait(0.3)
	# rare car payout: OK the first time, then it closes by itself
	var car: Dictionary = Data.VIP_CARS[0]
	var res := {"pay": 5000.0, "car": car, "followers": 20.0, "gloss": 5}
	gs.reset_tips()
	m._on_vip_finished(res)
	await wait(0.4)
	check(m.big_showing() and _big_ok(m) != null, "first rare car payout waits for OK")
	m._big_at -= 1000
	_big_ok(m).pressed.emit()
	await wait(0.4)
	m._on_vip_finished(res)
	await wait(0.4)
	check(m.big_showing() and _big_ok(m) == null and m._big_node.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"later payouts: no OK and no dim (the shop stays tappable)")
	await shot("v19j2_02_payout_quiet")
	await wait(6.3)
	check(not m.big_showing(), "... and they close by themselves")
	# tips that point into the shop wait while a panel is open (playtest: valet tip popped up at a bad time)
	gs.tips_enabled = true
	gs.reset_tips()
	gs.mark_tip("levels")
	m._open_level_panel("bay0")
	await wait(0.4)
	m._tip("valet_slow", func(): return m._valet_row.level_btn.get_global_rect())
	await wait(0.4)
	check(not m._tips.busy() and m._tips._queue.size() == 1, "'valet too slow' waits while a level panel is open")
	m._tip("managers")
	await wait(0.4)
	check(m._tips.busy() and m._tips._cur[0] == "managers", "... a tip about the panel itself still shows")
	m._tips._dismiss()
	close_sheets()
	await wait(0.8)
	check(m._tips.busy() and m._tips._cur[0] == "valet_slow" and m._tips._has_target, "... and the shop tip comes once the panel is closed")
	m._tips._dismiss()
	m._open_map(0)
	await wait(0.4)
	if m._tips.busy():
		m._tips._dismiss()
	await wait(0.2)
	m._tip("desk_slow", func(): return m._desk_row.level_btn.get_global_rect())
	await wait(0.4)
	check(not m._tips.busy() and m.sheet_open(), "... also while the map / HQ screen is open")
	for c in m.get_children():
		if c.get_script() == load("res://scripts/map_panel.gd"):
			c.queue_free()
	await wait(0.6)
	check(m._tips.busy() and m._tips._cur[0] == "desk_slow", "... and shows once you leave the map")
	m._tips._dismiss()
	gs.vip = {}
	gs.spawn_vip(true)
	m._banner.visible = true
	m._tip("star", func(): return m._meta.get_global_rect())
	await wait(0.4)
	check(not m._tips.busy() and m._banner.visible, "... and while the rare car banner is up")
	m._banner.visible = false
	gs.vip = {}
	await wait(0.4)
	check(m._tips.busy(), "... then it shows")
	m._tips._dismiss()
	gs.tips_enabled = false
	# hire wording
	var tt: String = m.tip_text("managers")
	check(tt.contains("Every hire is a surprise") and not tt.contains("random one"), "manager tip says what a hire gives")
	gs.cash = 1e6
	m._open_manager_panel("bay0")
	await wait(0.4)
	var surprise := false
	for c in m.get_children():
		if c.has_method("clear_body"):
			for l in c.find_children("*", "Label", true, false):
				if l.text.begins_with("Every hire is a surprise"):
					surprise = true
	check(surprise, "manager panel: 'Every hire is a surprise: a speed, discount or income ability'")
	await shot("v19j2_03_hire_wording")
	close_sheets()
	await wait(0.4)
	# Book: live effect of what's on show
	gs.book["corollo98"] = 1
	gs.display = []
	m._open_book()
	await wait(0.3)
	var bp = null
	for c in m.get_children():
		if c.has_method("_show_page"):
			bp = c
	var t: int = int(gs.car_def("corollo98")["tier"])
	bp._show_page(t)
	await wait(0.3)
	var empty_txt: String = bp._live_sig
	check(bp._live_box != null and bp._live_box.get_child_count() >= 2 and empty_txt.contains("followers/hour") and empty_txt.contains("bay income"), "category page: live strip under ON SHOW (%s)" % empty_txt.replace("\n", " | "))
	gs.toggle_display("corollo98")
	await wait(0.3)
	var cl: String = Data.CLASS_NAMES[gs.car_def("corollo98")["class"]]
	check(bp._live_sig != empty_txt and bp._live_sig.contains(cl + " ") and bp._live_sig.contains("(+"),
		"putting a car on show updates it right away: followers/hour + more %s customers" % cl)
	check(bp._live_sig.contains("first review in") if not gs.has_reviews() else bp._live_sig.contains("next half star in"), "... and says when that brings the next half star")
	await shot("v19j2_04_book_live")
	close_sheets()
	gs.popups_need_ok = false
	gs.reset_save()


## v0.19j part 3: Boosts as badges + today's deals, Book crew tags + chains
func _v19j3_checks() -> void:
	print("v0.19j-3 boosts as badges, today's deals, Book crew tags")
	var gs = GameState
	var m = main_node()
	gs.reset_save()
	await wait(0.3)
	gs.finish_tutorial(true)
	close_sheets()
	m._popup.visible = false
	await wait(0.3)
	# deals: 3 different boosters, the same all window long, each once
	var d1: Array = gs.deals()
	check(d1.size() == 3 and d1[0] != d1[1] and d1[1] != d1[2] and d1[0] != d1[2], "today's deals: 3 different boosters %s" % str(d1))
	check(str(gs.deals()) == str(d1) and str(gs.deals(gs.deal_window())) == str(d1), "... the same every time you look (no reroll by reopening)")
	var differ := 0
	var big := 0
	for w in 200:
		var dw: Array = gs.deals(1000 + w)
		if str(dw) != str(d1):
			differ += 1
		if dw.has("x4_7d"):
			big += 1
	check(differ > 150 and big > 5 and big < 100, "... new picks every 12 h; the week pass turns up less often (%d of 200)" % big)
	check(gs.deals_refresh_in() > 0.0 and gs.deals_refresh_in() <= Data.DEAL_HOURS * 3600.0, "next deals in %s" % gs.fmt_time(gs.deals_refresh_in()))
	gs.gloss = 100000
	var g0: int = gs.gloss
	gs.buy_booster(d1[0])
	var g1: int = gs.gloss
	gs.buy_booster(d1[0])
	check(g1 < g0 and gs.gloss == g1 and gs.deal_sold(d1[0]), "a deal can be bought once (then SOLD)")
	var off := ""
	for b in Data.BOOSTERS:
		if not d1.has(b["id"]):
			off = b["id"]
	gs.buy_booster(off)
	check(gs.gloss == g1, "a booster that isn't on offer can't be bought (%s)" % off)
	gs.save_game()
	gs._reset_state()
	gs.load_game()
	check(gs.deal_sold(d1[0]) and not gs.deal_sold(d1[1]), "what you bought today is saved")
	gs.deals_bought["window"] = gs.deal_window() - 1
	check(not gs.deal_sold(d1[0]), "... and a new window starts fresh")
	gs.buy_booster(d1[0])
	# running boosters: grouped, newest on the right
	gs.active_boosters = []
	gs.ad_boost_until = gs.now + 3600.0
	gs.boosters = {"x2_30m": 3, "x5_15m": 1, "x3_1h": 1, "x5_2h": 1, "x2_24h": 1}
	gs.activate_booster("x5_15m")
	gs.activate_booster("x2_30m")
	gs.activate_booster("x2_30m")
	var gr: Array = gs.booster_groups()
	check(gr.size() == 2 and gr[0]["id"] == "x5_15m" and gr[1]["id"] == "x2_30m" and int(gr[1]["count"]) == 2 and is_equal_approx(float(gr[1]["total"]), 4.0),
		"the same booster twice = one badge with a count (x2 + x2 = x4)")
	check(is_equal_approx(gs.total_boost(), 2.0 * 9.0), "the value is unchanged: x2 ad x (x5 + x2 + x2) = x18 (%s)" % gs.total_boost())
	m._open_boosts()
	await wait(0.6)
	var bp = null
	for c in m.get_children():
		if c.has_method("open_info"):
			bp = c
	check(bp != null and bp._run_row.get_child_count() == 3, "RUNNING NOW: ad badge + one badge per booster (%d)" % (bp._run_row.get_child_count() if bp else -1))
	check(bp._formula.get_child_count() >= 7, "the total card draws the sum as gems: base x ( x5 + x2 )")
	await shot("v19j3_01_boosts_badges")
	gs.activate_booster("x3_1h")
	gs.activate_booster("x5_2h")
	gs.activate_booster("x2_24h")
	await wait(0.6)
	var row: HBoxContainer = bp._run_row
	var last: Control = row.get_child(row.get_child_count() - 1)
	check(row.get_child_count() == 6 and row.get_child(0).position.x < last.position.x, "new boosters go on the right of the row (%d badges)" % row.get_child_count())
	check(bp._run_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and row.get_combined_minimum_size().x > bp._run_scroll.size.x,
		"... the row scrolls sideways (no stacking downwards)")
	check(bp._run_scroll.scroll_horizontal > 0, "... and it scrolls to the one you just added")
	bp._run_scroll.scroll_horizontal = 0
	await wait(0.2)
	check(bp._more.modulate.a > 0.9 and bp._more.text.contains("more"), "a '%s' bubble says some are off screen" % bp._more.text.strip_edges())
	await shot("v19j3_02_boosts_row_more")
	bp.open_info()
	await wait(0.3)
	check(bp._info != null and bp._info_label.text.contains("BASE") and bp._info_label.text.contains("Ad boost") and bp._info_label.text.contains("(2 running)"),
		"'i' opens the whole breakdown in words")
	await shot("v19j3_03_boosts_info")
	bp.close_info()
	await wait(0.2)
	check(bp._info == null, "... GOT IT closes it")
	bp._sheet_scroll.scroll_vertical = 100000
	await wait(0.3)
	var sold_btn := false
	for pair in bp._buy_btns:
		if str(pair[1]) == str(d1[0]) and (pair[0] as Button).text == "SOLD" and (pair[0] as Button).disabled:
			sold_btn = true
	check(sold_btn and bp._deals.get_child_count() == 3 and bp._deals_head.text.begins_with("TODAY'S DEALS"), "TODAY'S DEALS: 3 tiles, the one you bought says SOLD")
	await shot("v19j3_04_boosts_deals")
	close_sheets()
	await wait(0.3)
	# nothing at all: the base doesn't pretend
	gs.active_boosters = []
	gs.ad_boost_until = 0.0
	m._open_boosts()
	await wait(0.5)
	for c in m.get_children():
		if c.has_method("open_info"):
			bp = c
	var nothing := false
	for l in bp._formula.find_children("*", "Label", true, false):
		if l.text == "Nothing running yet":
			nothing = true
	check(nothing and bp.info_text().contains("Watch an ad"), "nothing running: says so (no 'x1' gems)")
	close_sheets()
	await wait(0.3)
	# Shop: boosters are bought from today's deals now
	m._open_shop()
	await wait(0.4)
	var link: Button = null
	for c in m.get_children():
		if c.has_method("clear_body"):
			for b in c.find_children("*", "Button", true, false):
				if str(b.get_meta("rich_src", b.text)).contains("TODAY'S BOOSTER DEALS"):
					link = b
	check(link != null, "Shop: one 'today's booster deals' button instead of an endless list")
	if link != null:
		link.pressed.emit()
		await wait(0.5)
		var opened := false
		for c in m.get_children():
			if c.has_method("open_info") and not c.is_queued_for_deletion():
				opened = true
		check(opened, "... it opens the Boosts screen")
	close_sheets()
	await wait(0.3)
	# Book: CREW tags + the customer chain names your crews
	gs.cash = 1e9
	var mb: Dictionary = gs.hire_manager("bay0")
	mb["crew"] = "jdm"
	gs.book["corollo98"] = 1
	gs.display = []
	gs.toggle_display("corollo98")
	m._open_book()
	await wait(0.3)
	var bk = null
	for c in m.get_children():
		if c.has_method("_show_page"):
			bk = c
	bk._show_page(1)
	await wait(0.4)
	check(gs.crew_bays("jdm") == [0], "a JDM Crew manager in Bay 1")
	check(bk._live_sig.contains("your 1 JDM Crew manager (Bay 1) earn x1.5 on them"), "the chain names your crew: '%s'" % bk._live_sig.split("\n")[1] if bk._live_sig.split("\n").size() > 1 else bk._live_sig)
	await shot("v19j3_05_book_crew")
	mb["crew"] = "euro"
	bk._show_page(1)
	await wait(0.4)
	check(bk._live_sig.contains("hire a JDM Crew manager"), "no matching crew: it says which manager to hire")
	close_sheets()
	gs.reset_save()


## v0.19j part 4: cleaner top bar (playtest: "too cluttered, could barely see the idle income / second")
func _v19j4_checks() -> void:
	print("v0.19j-4 top bar: cash + idle pills, city under the trophy")
	var gs = GameState
	var m = main_node()
	gs.reset_save()
	await wait(0.3)
	gs.finish_tutorial(true)
	close_sheets()
	m._popup.visible = false
	await wait(0.4)
	var money: Control = m._money
	var tb: Rect2 = m._prestige_badge.get_global_rect()
	var cl: Rect2 = m._city_label.get_global_rect()
	var mr: Rect2 = money.get_global_rect()
	check(money.rate_text == "$0/s" and m._cash_label.get_parent() == money, "left pills: cash + '$0/s' idle (no 'tap to work' line)")
	# v0.19w (Hamza): no city name under the trophy; the trophy sits low, level with the idle / rating pills
	check(not m._city_label.visible, "no 'Lima, USA' under the trophy (the banner says it)")
	check(tb.get_center().y > mr.get_center().y + 8.0 and tb.position.y > 40.0, "the trophy sits low, clear of the camera notch (%s)" % tb)
	check(not mr.intersects(tb) and not tb.intersects(m._meta.get_global_rect()), "pills and trophy don't overlap")
	var texts := []
	for l in m.find_children("*", "Label", true, false):
		if l.is_visible_in_tree() and (l.text.contains("followers") or l.text.contains("Tap to work")) and l.get_global_rect().position.y < 170.0:
			texts.append(l.text)
	check(texts.is_empty(), "no followers / 'tap to work' lines in the top bar %s" % str(texts))
	gs.cash = 1e6
	gs.hire_manager("bay0")
	gs.hire_manager("valet")
	gs.hire_manager("desk")
	await wait(0.6)
	check(money.rate_text.ends_with("/s") and money.rate_text != "$0/s", "with managers the idle pill shows income per second (%s)" % money.rate_text)
	await shot("v19j4_01_top_bar")
	money.rate_pressed.emit()
	await wait(0.4)
	var ov := false
	for c in m.get_children():
		if c.has_method("clear_body") and c.get_script() == load("res://scripts/overview_panel.gd"):
			ov = true
	check(ov, "tapping the idle pill opens the Overview (every city's income)")
	close_sheets()
	m._set_city_text("Wagga Wagga, Australia", "Wagga Wagga")
	check(m._city_label.text == "Wagga Wagga", "a long name drops the country so it fits")
	gs.cash = 1e15
	await wait(0.4)
	check(m._cash_label.get_global_rect().end.x <= mr.end.x, "a big cash number still fits its pill (%s)" % m._cash_label.text)
	await shot("v19j4_02_top_bar_big")
	gs.reset_save()


## v0.19k: the agreed pacing fixes after the fresh-player pass (teaching renovation + ad tip, first
## rating step at 40 followers, Book sets wait for the first Book visit)
func _v19k_checks() -> void:
	print("v0.19k pacing: teaching renovation, quicker first half star, sets after the Book")
	var gs = GameState
	var m = main_node()
	gs.reset_save()
	await wait(0.3)
	gs.finish_tutorial(true)
	close_sheets()
	m._popup.visible = false
	# --- 1. teaching renovation: 1x the bay, later ones 3x
	_clear_popups(m)
	gs.cash = 1e15
	gs.hire_manager("bay0"); gs.hire_manager("valet"); gs.hire_manager("desk")
	for k in 4:
		gs.buy_bay()
	var bay6 := float(Data.BAY_BUILD_COSTS[5]) * gs.city_scale(gs.active_city)
	check(gs.reno_needed() == 1 and absf(gs.reno_cost() - bay6) < 1.0, "1st renovation = 1x bay 6 (%s)" % gs.money(gs.reno_cost()))
	check(absf(gs.reno_seconds(1) - 3600.0) < 0.1, "... still takes 1h")
	gs.tips_enabled = true
	gs.popups_need_ok = true
	gs.reset_tips()
	m._scroll_to_bottom()
	await wait(0.5)
	check(gs.start_renovation(), "renovation started")
	await wait(0.6)
	var t: Array = m._tips._cur
	check(not t.is_empty() and t[0] == "reno" and m._tips.visible, "a tip shows when the 1st renovation starts")
	var txt: String = m._tips._text.text if not t.is_empty() else ""
	check(txt.begins_with("1h to go") and txt.contains("SKIP") and txt.contains("30 min off") and txt.contains("tap it twice")
		and txt.contains("FINISH NOW for 30 Shine Bucks"), "tip text (no-ads pack): %s" % txt)
	var ar: Rect2 = m._build_row._ad_rect()
	ar.position += m._build_row.global_position
	check(m._tips._has_target and m._tips._target.is_equal_approx(ar), "... and it rings the SKIP / WATCH AD button")
	m._scroll_to_bottom()
	await wait(1.2)
	await shot("v19k_01_reno_tip")
	gs.settings["ad_free"] = false
	var txt2: String = m.reno_tip_text()
	check(txt2.contains("Each ad you watch here takes 30 min off (2 per hour), so watch 2 and it's finished now"), "with ads: %s" % txt2)
	gs.settings["ad_free"] = true
	m._tips._dismiss()
	await wait(0.3)
	check(gs.tip_seen("reno") and not m._tips.busy(), "GOT IT: seen once")
	# two skips finish it (as the tip says)
	check(gs.watch_reno_ad() and gs.watch_reno_ad() and gs.reno_ready(), "2 skips = done")
	check(gs.unlock_renovation() and gs.reno_needed() == 0, "tap the lock: bay 6 can be built")
	for k in 5:
		gs.buy_bay()
	check(gs.reno_needed() == 2 and absf(gs.reno_cost() - 3.0 * float(Data.BAY_BUILD_COSTS[10]) * gs.city_scale(gs.active_city)) < 1.0,
		"2nd renovation still 3x the next bay")
	gs.mark_tip("delivery")   # v0.19t: (the Daily Delivery parcel turns up at Bay 6: its own tip, tested in _v19t_checks)
	gs.mark_tip("cat")
	m._tips._queue.clear()
	m._tips._cur = []
	gs.start_renovation()
	await wait(0.5)
	check(not m._tips.busy(), "no tip for the 2nd renovation (one time)")
	# --- 3. Book sets wait for the first Book visit, then come right after the Book tip
	gs.reset_save()
	await wait(0.3)
	gs.finish_tutorial(true)
	close_sheets()
	_clear_popups(m)
	gs.reset_tips()
	var g0: int = gs.gloss
	for c in gs.cars_by_id.values():
		if c["tier"] == 1:
			gs.log_car(c["id"])
	await wait(0.4)
	check(not gs.book_opened and gs.tiers_done.is_empty() and gs.gloss == g0 and not m.big_showing() and m._big_queue.is_empty(),
		"every Bomb washed, Book never opened: no SET COMPLETE yet")
	m._open_book()
	await wait(0.6)
	check(gs.book_opened and gs.tiers_done.has(1) and gs.gloss == g0 + Data.TIER_SET_GLOSS, "opening the Book completes the set")
	check(m._tips.visible and m._tips._cur[0] == "book" and not m.big_showing() and m._big_queue.size() == 1, "... the Book tip first, SET COMPLETE waits")
	await shot("v19k_02_book_tip_first")
	m._tips._dismiss()
	await wait(0.5)
	check(m.big_showing() and _big_title(m) == "SET COMPLETE!", "... then SET COMPLETE after GOT IT")
	await shot("v19k_03_set_complete")
	m._big_at -= 1000
	_big_ok(m).pressed.emit()
	await wait(0.4)
	close_sheets()
	gs.save_game()
	gs.book_opened = false
	gs.load_game()
	check(gs.book_opened, "Book opened flag is saved")
	gs.tips_enabled = false
	gs.popups_need_ok = false
	gs.reset_save()
	await wait(0.3)
	_clear_popups(m)
	# --- 2. rating (v0.19l): No reviews yet, then 1.0 .. 5.0; the first review is guaranteed by the first rare car
	check(Data.STAR_THRESHOLDS.size() == 10 and is_equal_approx(Data.STAR_THRESHOLDS[1], 15.0), "10 steps: No reviews yet + 1.0 .. 5.0, first review at 15")
	check(is_equal_approx(pow(Data.STAR_INCOME_BONUS, 9), pow(1.18, 9)) and pow(Data.STAR_INCOME_BONUS, 9) > 4.3,
		"5.0 stars still about x4.4 bay income (%.2f)" % pow(Data.STAR_INCOME_BONUS, 9))
	check(gs.stars() == 1 and not gs.has_reviews() and is_equal_approx(gs.reputation_mult(), 1.0), "new shop: no reviews, x1")
	gs.add_followers(14.0)
	check(not gs.has_reviews(), "14 followers: still no reviews")
	gs.add_followers(1.0)
	check(gs.rating_text() == "1.0" and is_equal_approx(gs.next_star_followers(), 150.0) and is_equal_approx(gs.reputation_mult(), 1.18),
		"15 followers: rated 1.0 (x1.18, next at 150)")
	check(m.star_title(2) == "FIRST REVIEWS ARE IN!" and m.star_title(3) == "RATED 1.5 STARS!", "banner titles: first reviews, then RATED X STARS")
	check(gs.display_slots() == Data.BASE_DISPLAY_SLOTS, "display slots unchanged at 1.0")
	gs.followers = Data.STAR_THRESHOLDS[4]
	check(gs.rating_text() == "2.5" and gs.display_slots() == Data.BASE_DISPLAY_SLOTS + 1, "+1 display slot at 2.5 stars (as before)")
	# a rare car payout always brings the first review
	gs.reset_save()
	await wait(0.3)
	gs.finish_tutorial(true)
	_clear_popups(m)
	await wait(0.4)
	await shot("v19l_01_hud_new_shop")
	gs.spawn_vip(true, 0)
	gs.send_vip()
	gs._finish_vip()
	check(gs.has_reviews() and gs.rating_text() == "1.0", "first rare car paid: first reviews are in (%s followers)" % gs.fmt(gs.followers))
	await wait(0.5)
	await shot("v19l_02_first_reviews")
	await wait(0.3)
	_clear_popups(m)
	gs.reset_save()


## v0.19m polish: pickup lot / hire ghosts / valet forecourt / wall shelves (looked at in screenshots),
## time-to-afford hints, a reset save clears an old Welcome back.
func _v19m_checks() -> void:
	print("v0.19m polish: time-to-afford hints, reset clears Welcome back")
	var gs = GameState
	var m = main_node()
	gs.reset_save()
	await wait(0.3)
	gs.finish_tutorial(true)
	_clear_popups(m)
	gs.cash = 0.0
	check(gs.eta_text(61.0) == "", "nothing runs by itself yet: no time hint")
	gs.cash = 1e6
	gs.hire_manager("bay0"); gs.hire_manager("valet"); gs.hire_manager("desk")
	gs.cash = 0.0
	await wait(0.5)
	var e: String = gs.eta_text(gs.idle_income() * 150.0)
	check(e.begins_with("in ~") and e.contains("m"), "with managers: the next bay says when you'll afford it (%s)" % e)
	gs.cash = 1e9
	check(gs.eta_text(61.0) == "", "affordable now: no time hint")
	await shot("v19m_01_shop_polish")
	m._show_offline_popup()
	await wait(0.2)
	gs.reset_save()
	await wait(0.3)
	check(not m._popup.visible, "a reset save closes an old Welcome back")
	gs.reset_save()


## v0.19n Lucky Wheel (Hamza 26 Oct).
func _v19n_checks() -> void:
	print("v0.19n Lucky Wheel")
	var gs = GameState
	var m = main_node()
	gs.reset_save()
	await wait(0.3)
	gs.finish_tutorial(true)
	_clear_popups(m)
	var total := 0.0
	for i in Data.WHEEL_PRIZES.size():
		total += gs.wheel_chance(i)
	check(Data.WHEEL_PRIZES.size() == 12 and absf(total - 100.0) < 0.001, "12 prizes, odds add up to 100%% (%.3f)" % total)
	check(is_equal_approx(gs.wheel_chance(0), 0.25) and is_equal_approx(gs.wheel_chance(4), 1.0), "Legendary prizes 0.25% each, Epic 1% each")
	check(gs.wheel_free_ready(), "a new game has its free spin ready")
	var r: Dictionary = gs.spin_wheel(true)
	check(not r.is_empty() and not gs.wheel_free_ready() and absf(gs.wheel_free_in() - Data.WHEEL_FREE_HOURS * 3600.0) < 5.0, "free spin used: next one in 8h")
	check(gs.spin_wheel(true).is_empty(), "no second free spin")
	gs.gloss = 49
	check(gs.spin_wheel(false).is_empty(), "49 Shine Bucks: can't spin")
	gs.gloss = 120
	var idx := Data.WHEEL_PRIZES.map(func(p): return p["id"]).find("x20_5m")
	var b20: int = int(gs.boosters.get("x20_5m", 0))
	r = gs.spin_wheel(false, idx)
	check(gs.gloss == 70 and int(gs.boosters.get("x20_5m", 0)) == b20 + 1, "paid spin: -50, the x20 booster is in YOUR BOOSTERS")
	gs.cash = 0.0
	gs.cash = 1e6
	gs.hire_manager("bay0"); gs.hire_manager("valet"); gs.hire_manager("desk")
	gs.cash = 0.0
	await wait(0.4)
	gs.gloss = 1000
	r = gs.spin_wheel(false, Data.WHEEL_PRIZES.map(func(p): return p["id"]).find("cash_4h"))
	check(gs.cash > 0.0 and str(r["text"]).ends_with("cash!"), "instant cash prize pays now (%s)" % r["text"])
	var f0: int = int(gs.case_files.get("detailed", 0))
	gs.spin_wheel(false, Data.WHEEL_PRIZES.map(func(p): return p["id"]).find("case_detailed"))
	check(int(gs.case_files.get("detailed", 0)) == f0 + 1, "Case File prize")
	r = gs.spin_wheel(false, 0)
	check(r.has("manager") and gs.roster[r["manager"]]["owned"] and int(gs.roster[r["manager"]]["rarity"]) == 4, "LEGEND: a whole Legendary manager joins (%s)" % r["text"])
	for id in gs.roster:
		if int(gs.roster[id]["rarity"]) == 4:
			gs.roster[id]["owned"] = true
	var c0: int = int(gs.case_files.get("classified", 0))
	r = gs.spin_wheel(false, 0)
	check(int(gs.case_files.get("classified", 0)) == c0 + Data.WHEEL_LEGEND_FALLBACK, "all Legendaries owned: 3 Classified Files instead")
	gs.save_game()
	var at: float = gs.wheel_free_at
	gs.wheel_free_at = 0.0
	gs.load_game()
	check(absf(gs.wheel_free_at - at) < 0.01, "free spin timer is saved")
	# the screen
	gs.wheel_free_at = 0.0
	await wait(0.6)
	check(m._shop_alert.visible == (gs.bays.size() >= 2), "SHOP '!' when a free spin is ready (from Bay 2)")
	var wp = load("res://scripts/wheel_panel.gd").new()
	m.add_child(wp)
	wp.setup()
	await wait(0.5)
	check(wp._spin_btn.text == "FREE SPIN!", "wheel screen: FREE SPIN!")
	await shot("v19n_01_wheel")
	wp._on_spin()
	await wait(SPIN_WAIT)
	check(wp._result.visible and wp._res_text.text != "" and not wp._spinning, "it spins round and says what you won (%s)" % wp._res_text.text)
	await shot("v19n_02_wheel_won")
	wp.close()
	var op = load("res://scripts/wheel_panel.gd").new()
	m.add_child(op)
	op.setup_odds()
	await wait(0.5)
	await shot("v19n_03_wheel_odds")
	op.close()
	gs.reset_save()


## v0.19o premium signatures from PREMIUM_PROPOSAL.md: Kev's Shortcut, Priya's Finish Line.
func _v19o_checks() -> void:
	print("v0.19o Kev's Shortcut + Priya's Finish Line")
	var gs = GameState
	var m = main_node()
	gs.reset_save()
	await wait(0.3)
	gs.finish_tutorial(true)
	_clear_popups(m)
	gs.cash = 1e6
	gs.hire_manager("bay0"); gs.hire_manager("desk")
	var kev: Dictionary = own("kev")
	gs.assign_manager("kev", "valet")
	check(gs.ability_def(kev)["kind"] == "signature" and gs.ability_def(kev)["id"] == "shortcut", "Kev's ability is Shortcut")
	check(absf(gs.ability_duration(kev) - 30.0) < 0.6 and absf(gs.ability_cooldown(kev) - 1800.0) < 1.0, "Shortcut: 30s at Lv1, 30 min recharge")
	kev["level"] = 50
	check(absf(gs.ability_duration(kev) / (1.0 + (float(Data.PERKS["duration"]["value"]) if gs.has_perk(kev, "duration") else 0.0)) - 60.0) < 1.5,
		"... 60s at Lv50 before his Lv20 perk (%.1fs with it)" % gs.ability_duration(kev))
	kev["level"] = 1
	kev["ready_at"] = 0.0
	gs.bays[0]["ready"] = 0.0
	var moved0: float = gs.shortcut_moved
	gs.activate_ability("valet")
	check(gs.shortcut_active(), "Shortcut running")
	var t0 := Time.get_ticks_msec()
	while gs.shortcut_moved <= moved0 and Time.get_ticks_msec() - t0 < 8000:
		await wait(0.2)
	check(gs.shortcut_moved > moved0 and gs.bays[0]["ready"] <= 0.0, "finished cars go straight to the pickup lot, not the key cabinet")
	await shot("v19o_01_shortcut")
	kev["active_until"] = 0.0
	var moved1: float = gs.shortcut_moved
	await wait(5.0)
	check(not gs.shortcut_active() and is_equal_approx(gs.shortcut_moved, moved1), "after it: back to the key cabinet")
	# Priya
	var pr: Dictionary = own("priya")
	gs.assign_manager("priya", "desk")
	check(gs.ability_def(pr)["id"] == "finish_line" and absf(gs.ability_cooldown(pr) - 2700.0) < 1.0, "Priya's ability is Finish Line (45 min recharge)")
	check(gs.ability_text(pr).contains("10 levels") and gs.ability_text(pr).contains("50%"), "Lv1: last 10 levels, 50%% off (%s)" % gs.ability_text(pr))
	gs.bays[0]["level"] = 20   # next boost Lv 25: levels 21..25 are inside the window
	var c1: float = gs.levels_cost("bay0", 1)
	var c10: float = gs.levels_cost("bay0", 10)
	pr["ready_at"] = 0.0
	gs.activate_ability("desk")
	check(not gs.finish_line().is_empty(), "Finish Line running")
	check(absf(gs.levels_cost("bay0", 1) / c1 - 0.5) < 0.01, "a level just before the boost costs half (%.3f)" % (gs.levels_cost("bay0", 1) / c1))
	check(gs.levels_cost("bay0", 10) > c10 * 0.5 and gs.levels_cost("bay0", 10) < c10, "10 levels across the boost: only the ones before it are cheaper")
	gs.bays[0]["level"] = 26   # next boost Lv 50: 27 is far from it
	var far: float = gs.levels_cost("bay0", 1)
	pr["active_until"] = 0.0
	check(is_equal_approx(gs.levels_cost("bay0", 1), far), "far from a boost: full price")
	pr["active_until"] = gs.now + 60.0
	pr["level"] = 50
	check(int(gs.finish_line()["levels"]) == 20 and is_equal_approx(float(gs.finish_line()["off"]), 0.7), "Lv50: last 20 levels, 70% off")
	gs.bays[0]["level"] = 40
	await wait(0.4)
	await shot("v19o_02_finish_line")
	pr["active_until"] = 0.0
	# v0.19q Marco's Convoy + the signature pictures
	gs.cash = 1e6
	var mc: Dictionary = own("marco")
	gs.assign_manager("marco", "valet")
	check(gs.ability_def(mc)["id"] == "convoy" and gs.convoy_trips(mc) == 5 and absf(gs.ability_cooldown(mc) - 2400.0) < 1.0, "Marco's Convoy: 5 trips at Lv1, 40 min recharge")
	mc["level"] = 50
	check(gs.convoy_trips(mc) >= 8, "... 8 at Lv50 (%d with perks)" % gs.convoy_trips(mc))
	mc["level"] = 1
	var cap0: float = gs.valet_capacity()
	mc["ready_at"] = 0.0
	gs.activate_ability("valet")
	check(not gs.convoy().is_empty() and absf(gs.valet_capacity() / cap0 - Data.CONVOY_MULT) < 0.01, "Convoy running: the valet carries x10")
	check(gs.ability_left_text(mc) == "5 trips" and gs.ability_length_text(mc) == "5 trips", "shown in trips, not time")
	await wait(0.4)
	await shot("v19q_01_convoy")
	for k in 5:
		gs.valet["phase"] = "unload"
		gs.valet["timer"] = 0.0
		gs._advance_valet(0.01)
	check(gs.convoy().is_empty() and not gs.ability_active(mc) and absf(gs.ability_cooldown(mc) - (float(mc["ready_at"]) - gs.now)) < 2.0,
		"after 5 trips it ends and starts recharging")
	check(absf(gs.valet_capacity() - cap0) < 0.01, "... and the valet carries normal loads again")
	var AbilityIconS = load("res://scripts/ability_icon.gd")
	check(AbilityIconS._pic_name(mc, "signature") == "icon_convoy" and AbilityIconS._pic_name(gs.manager("kev"), "signature") == "icon_shortcut"
		and AbilityIconS._pic_name(gs.manager("priya"), "signature") == "icon_finish_line" and AbilityIconS._pic_name(gs.manager("dazza"), "signature") == "icon_signature",
		"Kev, Priya and Marco have their own ability pictures (Dazza keeps the tip jar)")
	gs.reset_save()


## v0.19r the early Commons' signatures (Hamza OK'd 26 Oct).
func _v19r_checks() -> void:
	print("v0.19r Common signatures: Shazza, Tash, Jono, Bec, Mick")
	var gs = GameState
	var m = main_node()
	gs.reset_save()
	await wait(0.3)
	gs.finish_tutorial(true)
	_clear_popups(m)
	gs.cash = 1e6
	gs.hire_manager("bay0")
	var AbilityIconS = load("res://scripts/ability_icon.gd")
	# Shazza: Clear the Lot
	var sh: Dictionary = own("shazza")
	gs.assign_manager("shazza", "desk")
	gs.desk["lot"] = 1000.0
	var c0: float = gs.cash
	sh["ready_at"] = 0.0
	gs.activate_ability("desk")
	check(is_equal_approx(gs.desk["lot"], 0.0) and absf(gs.cash - c0 - 1500.0) < 0.01, "Shazza's Clear the Lot: the whole lot checked out now, x1.5")
	check(not gs.ability_ready(sh) and absf(gs.ability_cooldown(sh) - 1800.0) < 1.0, "... then 30 min recharge")
	await wait(0.3)
	await shot("v19r_01_clear_lot")
	# Bec: Loyalty Card
	var bc: Dictionary = own("bec")
	gs.assign_manager("bec", "desk")
	bc["ready_at"] = 0.0
	gs.activate_ability("desk")
	var f0: float = gs.followers
	gs.desk["lot"] = 50.0
	var t0 := Time.get_ticks_msec()
	while gs.followers <= f0 and Time.get_ticks_msec() - t0 < 8000:
		await wait(0.2)
	check(gs.followers >= f0 + 0.99, "Bec's Loyalty Card: a checkout brings a follower (%.1f -> %.1f)" % [f0, gs.followers])
	# Tash: Showstopper
	var ta: Dictionary = own("tash")
	gs.assign_manager("tash", "bay0")
	ta["ready_at"] = 0.0
	gs.activate_ability("bay0")
	check(gs.ability_active(ta) and gs.ability_left_text(ta) == "next car", "Tash's Showstopper waits for her bay's next car")
	var r0: float = gs.bays[0]["ready"]
	var f1: float = gs.followers
	var normal: float = gs.bay_pay_per_car(0)
	gs.bays[0]["running"] = true
	gs.bays[0]["progress"] = 0.999
	gs._advance_bay(0, 0.5)
	check(gs.bays[0]["ready"] - r0 >= normal * 24.9 and gs.followers >= f1 + 4.99 and not gs.ability_active(ta), "show car: x25 pay + 5 followers, then it recharges")
	await wait(0.3)
	await shot("v19r_02_showstopper")
	# Jono: Mate's Rates
	var jo: Dictionary = own("jono")
	gs.assign_manager("jono", "bay0")
	jo["ready_at"] = 0.0
	gs.activate_ability("bay0")
	check(gs.free_levels("bay0") == 5 and is_equal_approx(gs.levels_cost("bay0", 5), 0.0) and gs.levels_cost("bay0", 6) > 0.0, "Jono's Mate's Rates: the next 5 levels cost nothing")
	var l0: int = gs.bays[0]["level"]
	var cash1: float = gs.cash
	gs.buy_levels("bay0", 3)
	check(gs.bays[0]["level"] == l0 + 3 and is_equal_approx(gs.cash, cash1) and gs.free_levels("bay0") == 2, "3 free levels bought: 2 left")
	gs.buy_levels("bay0", 2)
	check(gs.free_levels("bay0") == 0 and not gs.ability_active(jo), "all used: it ends and recharges")
	# Mick: Tow Truck
	gs.cash = 1e9
	for k in 3:
		gs.buy_bay()
	var mk: Dictionary = own("mick")
	gs.assign_manager("mick", "valet")
	await wait(0.2)
	for i in gs.bays.size():
		gs.bays[i]["ready"] = gs.valet_capacity() * 3.0
	var total: float = 0.0
	for i in gs.bays.size():
		total += gs.bays[i]["ready"]
	gs.valet["phase"] = "idle"
	gs.valet["pos"] = 0.0
	gs.valet["carried"] = 0.0
	mk["ready_at"] = 0.0
	gs.activate_ability("valet")
	var lot0: float = gs.desk["lot"]
	gs.desk["level"] = gs.desk["level"]
	for k in 4000:
		gs._advance_valet(0.05)
		if gs.valet["phase"] == "idle" and not gs.ability_active(mk):
			break
	var moved: float = gs.desk["lot"] - lot0
	check(moved >= total * 0.999 and not gs.ability_active(mk), "Mick's Tow Truck: one trip empties every cabinet (%s of %s), then recharges" % [gs.money(moved), gs.money(total)])
	check(AbilityIconS._pic_name(sh, "signature") == "icon_clear_lot" and AbilityIconS._pic_name(ta, "signature") == "icon_showstopper"
		and AbilityIconS._pic_name(jo, "signature") == "icon_mates_rates" and AbilityIconS._pic_name(bc, "signature") == "icon_loyalty_card"
		and AbilityIconS._pic_name(mk, "signature") == "icon_tow_truck", "all five have their own ability pictures")
	check(gs.ability_text(mk) == "Tow Truck: the next trip has no carry limit: it empties every key cabinet", "texts read right (%s)" % gs.ability_text(mk))
	gs.reset_save()


## v0.19t: pacing (Night Shift in Shine Bucks, prestige x3), the Uncommon signatures, day + night, Daily Delivery,
## Suds the shop cat, shop decor.
func _v19t_checks() -> void:
	print("v0.19t pacing, Uncommon signatures, day/night, delivery, cat, decor")
	var gs = GameState
	var m = main_node()
	var Sc = load("res://scripts/scenery.gd")
	gs.reset_save()
	await wait(0.3)
	gs.finish_tutorial(true)
	_clear_popups(m)
	# --- pacing
	check(is_equal_approx(Data.PRESTIGE_MULT, 3.0) and m.tip_text("prestige").contains("x3"), "prestige is x3 now (tip says so)")
	gs.gloss = 100
	# v0.19v (Hamza): Night Shift is gone, time away is never capped (checked in _v19v_checks)
	# --- Uncommon signatures
	gs.cash = 1e9
	for k in 4:
		gs.buy_bay()
	for i in gs.bays.size():
		gs.hire_manager("bay%d" % i)
	gs.hire_manager("desk"); gs.hire_manager("valet")
	var AbilityIconS = load("res://scripts/ability_icon.gd")
	# Gazza: Foam Cannon on bay 2 -> bays 1-3 x3
	var gz: Dictionary = own("gazza")
	gs.assign_manager("gazza", "bay1")
	var before := []
	for i in gs.bays.size():
		before.append(gs.bay_income(i))
	gz["ready_at"] = 0.0
	gs.activate_ability("bay1")
	var x0: float = gs.bay_income(0) / before[0]
	var x2: float = gs.bay_income(2) / before[2]
	var x3: float = gs.bay_income(3) / before[3]
	check(absf(x0 - 3.0) < 0.01 and absf(x2 - 3.0) < 0.01 and absf(x3 - 1.0) < 0.01, "Gazza's Foam Cannon: his bay + both neighbours x3, the next one along not (%.2f %.2f %.2f)" % [x0, x2, x3])
	check(gs.ability_text(gz) == "Foam Cannon: for 45s his bay and the bays either side earn x3", "text: %s" % gs.ability_text(gz))
	gz["active_until"] = 0.0
	await wait(0.3)
	# Lukas: Training Day
	var lk: Dictionary = own("lukas")
	gs.assign_manager("lukas", "bay3")
	gs.bays[0]["level"] = 1
	var b0: float = gs.bay_income(0)
	lk["ready_at"] = 0.0
	gs.activate_ability("bay3")
	check(gs.training_bonus() == 10 and gs.bay_income(0) > b0 * 10.0, "Lukas's Training Day: bays work like +10 levels (Lv1 -> like Lv11 with its Lv10 boost: x%.1f)" % (gs.bay_income(0) / b0))
	lk["active_until"] = 0.0
	check(gs.training_bonus() == 0 and is_equal_approx(gs.bay_income(0), b0), "... and back to normal after")
	# Yuki: Flash Polish
	var yk: Dictionary = own("yuki")
	gs.assign_manager("yuki", "bay2")
	yk["ready_at"] = 0.0
	gs.activate_ability("bay2")
	check(gs.ability_left_text(yk) == "10 cars" and is_equal_approx(gs.bay_cycle_time(2), Data.FLASH_POLISH_TIME), "Yuki's Flash Polish: 10 cars at %.1fs each" % Data.FLASH_POLISH_TIME)
	var r0: float = gs.bays[2]["ready"]
	var per: float = gs.bay_pay_per_car(2)
	for k in 40:
		gs._advance_bay(2, 0.1)
	check(not gs.ability_active(yk) and gs.bays[2]["ready"] - r0 >= per * 9.9, "10 cars polished in ~3s, then it recharges (%s paid)" % gs.money(gs.bays[2]["ready"] - r0))
	check(gs.bay_cycle_time(2) > Data.FLASH_POLISH_TIME * 2.0, "the bay is back to its normal speed")
	# Rosa: Referral
	var ro: Dictionary = own("rosa")
	gs.assign_manager("rosa", "desk")
	gs.vip = {}
	ro["ready_at"] = 0.0
	gs.activate_ability("desk")
	check(not gs.vip.is_empty() and gs.vip["phase"] == "lot", "Rosa's Referral: a rare car rolls into the lot now")
	gs.vip["timer"] = 0.0
	ro["ready_at"] = 0.0
	ro["active_until"] = 0.0
	gs.activate_ability("desk")
	check(bool(ro.get("referral_wait", false)) and gs.ability_left_text(ro) == "next rare car", "used while one is here: the next one comes right after")
	gs._finish_vip()
	await wait(0.1)
	check(not gs.vip.is_empty() and not bool(ro.get("referral_wait", false)) and not gs.ability_active(ro), "... it rolls in as soon as that one's done, then Rosa recharges")
	gs.vip = {}
	check(AbilityIconS._pic_name(gz, "signature") == "icon_foam_cannon" and AbilityIconS._pic_name(yk, "signature") == "icon_flash_polish"
		and AbilityIconS._pic_name(lk, "signature") == "icon_training_day" and AbilityIconS._pic_name(ro, "signature") == "icon_referral", "all four have their own pictures")
	gz["ready_at"] = 0.0
	gs.activate_ability("bay1")
	await wait(0.4)
	await shot("v19t_01_foam_cannon")
	# --- day + night
	check(Sc.night_amount(13.0) == 0.0 and Sc.night_amount(23.0) == 1.0 and Sc.night_amount(3.0) == 1.0 and Sc.night_amount(19.5) > 0.2 and Sc.night_amount(19.5) < 0.8,
		"day / dusk / night follow the clock")
	check(Sc.golden_amount(19.0) > 0.9 and Sc.golden_amount(13.0) == 0.0, "golden light at sunset")
	Sc.hour_override = 22.5
	await wait(0.6)
	await shot("v19t_02_night")
	Sc.hour_override = 19.0
	await wait(0.6)
	await shot("v19t_03_sunset")
	Sc.hour_override = 13.0
	# --- rainy days
	var dry: float = gs.bay_income(0)
	gs.rain_override = 1
	check(absf(gs.bay_income(0) / dry - Data.RAIN_PAY_MULT) < 0.001 and m._boost_info_has_rain(), "rainy day: muddy cars pay x%s (and the Boosts breakdown says so)" % str(Data.RAIN_PAY_MULT))
	await wait(0.6)
	await shot("v19t_03b_rain")
	gs.rain_override = -1
	gs.play_time = 0.0
	check(not gs.raining(), "never rains in a new game's first hour")
	gs.play_time = 7200.0
	var wet := 0
	for k in 400:
		if gs.raining(1.9e9 + k * Data.RAIN_WINDOW_H * 3600.0):
			wet += 1
	check(wet > 40 and wet < 110, "about 1 window in 5 is rainy (%d of 400)" % wet)
	gs.rain_override = 0
	# --- Daily Delivery
	gs.reset_save()
	await wait(0.3)
	gs.finish_tutorial(true)
	_clear_popups(m)
	gs.cash = 1e12
	for k in 4:
		gs.buy_bay()
	check(gs.bays.size() == 5 and not gs.delivery_ready(), "no parcel during the first session's early bays (5 bays)")
	gs.start_renovation()
	gs._cstate("")["reno_until"] = gs.now - 1.0
	gs.unlock_renovation()
	gs.buy_bay()
	check(gs.bays.size() == 6 and gs.delivery_ready() and m._desk_row.parcel_showing() and gs.delivery_slot() == 0, "a parcel waits once Bay 6 is built")
	var bo: int = int(gs.boosters.get("x2_30m", 0))
	var res: Dictionary = gs.open_delivery()
	check(int(res.get("slot", -1)) == 0 and int(gs.boosters.get("x2_30m", 0)) == bo + 2 and not gs.delivery_ready(), "day 1: 2 x2 boosters, then none until tomorrow")
	check(gs.open_delivery().is_empty(), "can't open twice in a day")
	check(gs.delivery_in() > 0.0 and gs.delivery_in() <= 86400.0, "next parcel in %s" % gs.fmt_time(gs.delivery_in()))
	gs.delivery_day = gs.local_day() - 3   # skipped two days: no reset
	var g0: int = gs.gloss
	res = gs.open_delivery()
	check(int(res["slot"]) == 1 and gs.gloss == g0 + 15, "missing days doesn't reset the week: day 2 = 15 Shine Bucks")
	for k in 5:
		gs.delivery_day = gs.local_day() - 1
		res = gs.open_delivery()
	check(int(res["slot"]) == 6 and gs.case_files.get("classified", 0) >= 1, "day 7: a Classified File + 50")
	gs.delivery_day = gs.local_day() - 1
	check(gs.delivery_slot() == 0, "then the week starts again")
	m._open_delivery()
	await wait(0.6)
	var dp = null
	for c in m.get_children():
		if c.get_script() == load("res://scripts/delivery_panel.gd"):
			dp = c
	check(dp != null and dp._open_btn.text == "OPEN TODAY'S PARCEL", "tapping the parcel opens the Daily Delivery card")
	await shot("v19t_04_delivery")
	dp._on_open()
	await wait(0.3)
	check(dp._open_btn.disabled and dp._result.visible, "OPEN gives it and says what it was")
	close_sheets()
	# --- Suds the shop cat
	gs.cat_treat_day = -1
	g0 = gs.gloss
	check(m._valet_row.cat_showing(), "Suds is on the forecourt")
	m._valet_row._pet_cat()
	check(gs.gloss == g0 + Data.CAT_TREAT_GLOSS and not gs.cat_treat_ready(), "first pet of the day: +%d Shine Bucks" % Data.CAT_TREAT_GLOSS)
	m._valet_row._pet_cat()
	check(gs.gloss == g0 + Data.CAT_TREAT_GLOSS and m._valet_row.cat.awake(Time.get_ticks_msec()), "more pets: just hearts (she sits up)")
	await wait(0.3)
	await shot("v19t_05_cat")
	# --- decor
	gs.gloss = 1000
	check(gs.buy_decor("fountain") and gs.has_decor("fountain") and gs.gloss == 820 and not gs.buy_decor("fountain"), "decor bought once with Shine Bucks")
	check(is_equal_approx(gs.decor_followers_per_hour(), 1.0), "+1 follower an hour per piece")
	for d in Data.DECOR:
		gs.buy_decor(d["id"])
	check(gs.decor.size() == Data.DECOR.size(), "all %d pieces" % Data.DECOR.size())
	var f0: float = gs.followers
	gs._grant_offline(3600.0 * 2)
	check(gs.followers >= f0 + 2.0 * Data.DECOR.size() - 0.01, "decor followers come in while away too")
	gs.pending_offline = {}
	var save_txt := JSON.stringify(gs.decor)
	gs.save_game()
	gs.load_game()
	check(JSON.stringify(gs.decor) == save_txt and gs.delivery_count == 8 and gs.cat_treat_day == gs.local_day(), "decor, deliveries and the cat's treat day are saved")
	_clear_popups(m)
	await wait(0.5)
	await shot("v19t_06_decor")
	Sc.hour_override = 22.5
	await wait(0.6)
	await shot("v19t_07_decor_night")
	Sc.hour_override = 13.0
	m._open_shop()
	await wait(0.5)
	var sp = _find_panel(m, "res://scripts/shop_panel.gd")
	var found := false
	for l in sp.body.find_children("*", "Label", true, false):
		if l.text == "SHOP DECOR":
			found = true
	check(found and sp._decor_btns.size() == Data.DECOR.size() and sp._decor_btns[0][0].text == "IN YOUR SHOP", "Shop has the SHOP DECOR list")
	close_sheets()
	# --- car of the week
	gs.cotw_enabled = true
	var cw: String = gs.car_of_week()
	check(cw != "" and int(gs.car_def(cw)["tier"]) == gs.bay_tier(0) and gs.car_of_week() == cw, "Car of the Week: an everyday model of this city's first-bay tier (%s)" % gs.car_def(cw)["name"])
	gs.bays[0]["car"] = cw
	gs.bays[0]["running"] = true
	gs.bays[0]["progress"] = 0.999
	var rd0: float = gs.bays[0]["ready"]
	var pay1: float = gs.bay_pay_per_car(0)
	var fo0: float = gs.followers
	gs._advance_bay(0, 0.05)
	check(absf(gs.bays[0]["ready"] - rd0 - pay1 * Data.COTW_PAY_MULT) < pay1 * 0.01 and gs.followers >= fo0 + Data.COTW_FOLLOWERS - 0.01, "washing it pays x%d and brings %d followers" % [int(Data.COTW_PAY_MULT), int(Data.COTW_FOLLOWERS)])
	gs.bays[0]["car"] = cw
	await wait(0.3)
	await shot("v19t_07b_car_of_week")
	gs.cotw_enabled = false
	# --- shop name, reviews, level-up pop
	check(gs.sign_text() == "Lima  ·  Suburban Car Wash", "the sign reads as before until you name the shop")
	gs.set_shop_name("  Hamza's Super Long Detailing Empire  ")
	check(gs.shop_name.length() == Data.SHOP_NAME_MAX and gs.sign_text().begins_with("Hamza's") and gs.sign_text().ends_with("Lima"), "named shop on the sign (trimmed to %d letters): %s" % [Data.SHOP_NAME_MAX, gs.sign_text()])
	gs.set_shop_name("Hamza's Detailing")
	m._open_workshops()
	await wait(0.5)
	var wp = _find_panel(m, "res://scripts/workshop_panel.gd")
	var le: LineEdit = wp.body.find_child("ShopName", true, false)
	check(le != null and le.text == "Hamza's Detailing", "the prestige panel (tap the sign) has the shop name box")
	await shot("v19t_08_shop_name")
	close_sheets()
	gs.followers = Data.STAR_THRESHOLDS[4] + 1.0
	var rv: Array = gs.todays_reviews()
	check(rv.size() == 3 and str(rv[0][1]) != str(rv[1][1]) and float(rv[0][0]) >= 1.0 and float(rv[0][0]) <= 5.0 and gs.todays_reviews() == rv, "3 customer reviews a day (the same all day)")
	m._open_reputation()
	await wait(0.5)
	await shot("v19t_09_reviews")
	close_sheets()
	gs.cash = 1e9
	m._open_level_panel("bay0")
	await wait(0.4)
	var lp = _find_panel(m, "res://scripts/level_panel.gd")
	var kids0: int = lp.get_child_count()
	lp._on_buy()
	check(lp.get_child_count() > kids0, "buying levels pops what it added (+$/s)")
	await wait(0.4)
	await shot("v19t_10_level_pop")
	close_sheets()
	gs.reset_save()



## v0.19u visual pass: smaller foam, service kit on the shelf, slim level tags, alert dots, back lot, panel
## finishes, the world map, title + Welcome back scenes.
func _v19u_checks() -> void:
	print("v0.19u visual pass + world map")
	var gs = GameState
	var m = main_node()
	gs.reset_save()
	await wait(0.3)
	gs.finish_tutorial(true)
	_clear_popups(m)
	# foam: smaller bubbles, many more of them, laid out once per body shape
	var Foam = load("res://scripts/foam_layer.gd")
	var f1 = Foam.new(1)
	var car := gs.car_def(Data.CARS[0]["id"])
	f1.setup(Rect2(0, 0, 270, 120), car, 2)
	var n1: int = f1.slots.size()
	var f2 = Foam.new(2)
	f2.setup(Rect2(0, 0, 270, 120), car, 2)
	check(n1 > 250 and f2.slots.size() == n1 and not f1.slots[0]["nb"].is_empty(), "foam: %d small bubbles, the layout is shared by both bays" % n1)
	f1.spray(Vector2(0.5, 0.5), 1.0, 0.5)
	check(f1.coverage() > 0.1 and f2.coverage() == 0.0, "... but each bay foams its own car")
	# service kit + level tag + alert dots
	var BC = load("res://scripts/bay_card.gd")
	check(BC.kit_width(0) > 0.0 and BC.kit_width(10) > 0.0, "every service has its kit on the shelf")
	check(m._shop_alert.text == "" and m._map_alert.text == "", "alerts are small dots, not \"!\" badges")
	gs.cash = 1e40
	for k in 25:
		if gs.bays.size() >= Data.MAX_BAYS:
			break
		if gs.reno_needed() > 0:
			gs.start_renovation()
			gs._cstate("")["reno_until"] = gs.now - 1.0
			gs.unlock_renovation()
			continue
		gs.buy_bay()
	check(gs.bays.size() == Data.MAX_BAYS and gs.next_bay_cost() < 0.0, "all %d bays built" % Data.MAX_BAYS)
	await wait(0.4)
	m._scroll.scroll_vertical = 100000
	await wait(0.6)
	await shot("v19u_01_back_lot")
	m._scroll.scroll_vertical = 0
	# panel finishes
	m._open_level_panel("bay0")
	await wait(0.3)
	var lp = _find_panel(m, "res://scripts/level_panel.gd")
	check(lp != null and lp._finish == "gloss" and lp._panel.get_theme_stylebox("panel") is StyleBoxTexture, "level panel: black gloss rim")
	close_sheets()
	m._open_book()
	await wait(0.3)
	var bp = _find_panel(m, "res://scripts/book_panel.gd")
	check(bp != null and bp._finish == "carbon", "Book: carbon fibre rim")
	close_sheets()
	m._open_shop()
	await wait(0.25)
	var sp = _find_panel(m, "res://scripts/shop_panel.gd")
	check(sp != null and sp._finish == "chrome", "Shop: chrome rim (with a shine sweeping across it)")
	await shot("v19u_02_chrome_shop")
	close_sheets()
	# --- the world map
	gs.reset_save()
	await wait(0.3)
	gs.finish_tutorial(true)
	_clear_popups(m)
	gs.cash = 1e40
	m._open_map(0)
	await wait(0.6)
	var mp = null
	for c in m.get_children():
		if c.has_method("_set_tab"):
			mp = c
	check(mp != null and mp._view.visible and mp._canvas.geo.size() == Data.COUNTRIES.size(), "the world map: %d islands" % mp._canvas.geo.size())
	var lima_at: Vector2 = Vector2.ZERO
	for r in mp._canvas.geo["usa"]["regions"]:
		if r["city"] == "lima":
			lima_at = r["label"]
	check(mp._canvas.hit(lima_at) == "lima", "Lima's patch is where its label is")
	var jp: Vector2 = mp._canvas.geo["japan"]["center"]
	check(mp._canvas.hit(jp) == "country:japan", "a locked country is one tap target")
	check(mp._canvas.hit(Vector2(5, 5)) == "", "the sea is nothing")
	var inside := 0
	for cid in mp._canvas.geo.keys():
		for r in mp._canvas.geo[cid]["regions"]:
			if Geometry2D.is_point_in_polygon(r["label"], r["poly"]):
				inside += 1
	check(inside == 25, "all 25 cities have their own tappable patch, label inside it (%d)" % inside)
	await shot("v19u_03_map")
	# tap Lima on screen -> its card
	var sp_l: Vector2 = mp._canvas.position + lima_at * mp._zoom
	mp.tap(sp_l)
	await wait(0.3)
	check(mp._selected == "lima" and mp._card.visible and not mp._locate.visible, "tapping Lima opens its card")
	await shot("v19u_04_map_card")
	# zoom: wheel / pinch go through zoom_at, clamped
	var z0: float = mp._zoom
	mp.zoom_at(mp._view.size * 0.5, 1.5)
	check(mp._zoom > z0, "zoom in")
	for k in 20:
		mp.zoom_at(mp._view.size * 0.5, 0.7)
	check(is_equal_approx(mp._zoom, mp.ZOOM_MIN), "zoom out stops at %.2f" % mp.ZOOM_MIN)
	await wait(0.3)
	await shot("v19u_05_map_whole")
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP
	ev.pressed = true
	ev.position = mp._view.size * 0.5
	mp._on_view_input(ev)
	check(mp._zoom > mp.ZOOM_MIN, "the mouse wheel zooms")
	var p0: Vector2 = mp._canvas.position
	var dr := InputEventScreenDrag.new()
	dr.index = 0
	dr.position = Vector2(300, 400)
	dr.relative = Vector2(-60, -40)
	mp._touches = {0: Vector2(360, 440)}
	mp._on_view_input(dr)
	check(mp._canvas.position != p0, "dragging pans the map")
	mp._touches = {}
	# accessories: Managers opens over the map, < MAP comes back
	mp.select("lm:managers")
	check(mp._roster.visible and not mp._view.visible and mp._back.visible, "the Managers islet opens Managers (with < MAP)")
	mp._set_tab(0)
	check(mp._view.visible and not mp._roster.visible, "< MAP goes back")
	mp.select("lm:hometown")
	check(mp._card.visible, "the Hometown islet has its card")
	# unlock Detroit from its card
	mp.select("detroit")
	await wait(0.2)
	var ub: Button = null
	for b in mp._card_box.find_children("*", "Button", true, false):
		if b.text.begins_with("UNLOCK"):
			ub = b
	check(ub != null and not ub.disabled, "Detroit's card: UNLOCK")
	ub.pressed.emit()
	await wait(0.3)
	check(gs.city_unlocked("detroit"), "... unlocks it")
	for c in m.get_children():
		if c.has_method("_set_tab"):
			c.queue_free()
	await wait(0.2)
	# title + Welcome back scenes
	gs.set_shop_name("Test Shop")
	var ts = load("res://scripts/title_screen.gd").new()
	m.add_child(ts)
	await wait(0.6)
	await shot("v19u_06_title")
	ts.queue_free()
	gs.hire_manager("desk"); gs.hire_manager("valet"); gs.hire_manager("bay0")
	gs._grant_offline(3 * 3600.0)
	m._show_offline_popup()
	await wait(0.4)
	check(m._popup.visible and m._popup_pic != null and m._popup_pic.is_visible_in_tree(), "Welcome back has its little scene")
	await shot("v19u_07_welcome")
	m._popup.visible = false
	gs.pending_offline = {}
	gs.reset_save()


func _find_panel(m, path: String):
	for c in m.get_children():
		if c.get_script() == load(path):
			return c
	return null

const SPIN_WAIT := 4.8


## Drop any tip / big message still queued from an earlier check (test shortcut).
func _clear_popups(m) -> void:
	m._tips._queue.clear()
	m._tips._cur = []
	m._big_queue.clear()
	if m.big_showing():
		m._big_at -= 5000
		m._dismiss_big()


## v0.19v: per-city ad boost + BOOST ALL, city stashes + COLLECT, no Night Shift (offline never capped),
## the AD BOOST button + the sky strip with the Lucky Wheel, icons in prices, map corner panels, big map words.
func _v19v_checks() -> void:
	print("v0.19v ad boost per city, stashes, offline, main screen, map panels")
	var gs = GameState
	var m = main_node()
	gs.reset_save()
	await wait(0.3)
	gs.finish_tutorial(true)
	_clear_popups(m)
	# --- the ad boost is per city
	gs.watch_ad_boost()
	check(absf(gs.ad_boost_left() - Data.AD_BOOST_HOURS * 3600.0) < 5.0 and gs.ad_boost_left("detroit") == 0.0, "an ad boosts the city you're in only (Lima +4h, Detroit nothing)")
	for k in 8:
		gs.watch_ad_boost()
	check(gs.ad_boost_full() and absf(gs.ad_boost_left() - Data.AD_BOOST_MAX_HOURS * 3600.0) < 5.0, "banked up to 24h, then FULL")
	# the Boosts card's timer follows (it used to keep the time it was built with)
	gs.ad_until["lima"] = gs.now + 3600.0
	m._open_boosts()
	await wait(0.3)
	var bp = _find_panel(m, "res://scripts/boost_panel.gd")
	gs.watch_ad_boost()
	await wait(0.3)
	check(bp != null and bp._ad_pill.text == gs.fmt_time(gs.ad_boost_left()) and gs.ad_boost_left() > 4.5 * 3600.0,
		"the AD BOOST card shows the new time after another ad (%s)" % (bp._ad_pill.text if bp else "?"))
	close_sheets()
	# BOOST ALL needs every city of the country open
	check(not gs.boost_all_ready("usa"), "BOOST ALL: not until all 5 US cities are open")
	gs.cash = 1e40
	for c in Data.COUNTRIES[0]["cities"]:
		if not gs.city_unlocked(c["id"]):
			gs.cash = 1e40
			gs.unlock_city(c["id"])
	gs.go_to_city("lima")
	await wait(0.2)
	check(gs.boost_all_ready("usa") and gs.boost_all_wanted("usa"), "... then it's ready")
	gs.ad_until = {}
	gs.boost_all("usa")
	var all4 := true
	for c in Data.COUNTRIES[0]["cities"]:
		all4 = all4 and absf(gs.ad_boost_left(c["id"]) - Data.AD_BOOST_MAX_HOURS * 3600.0) < 5.0
	check(all4, "BOOST ALL: one ad = the full 24h in every US city (v0.19w)")
	check(gs.boost_all_block("usa") != "" and gs.boost_all_block("usa").contains("already"), "... then it says they're all full (%s)" % gs.boost_all_block("usa"))
	# --- stashes: another city saves up, travelling there (or COLLECT ALL) collects it
	gs.hire_manager("desk"); gs.hire_manager("valet"); gs.hire_manager("bay0")
	gs.go_to_city("detroit")
	await wait(0.3)
	gs._refresh_bg_rates()
	await wait(1.5)
	var st: float = gs.stash_of("lima")
	check(st > 0.0, "Lima saves into its stash while you're in Detroit (%s)" % gs.money(st))
	var w0: float = gs.wallets.get("usa", 0.0) if gs.active_city != "lima" else 0.0
	gs.go_to_city("lima")
	await wait(0.2)
	check(gs.stash_of("lima") == 0.0 and gs.cash >= w0 + st * 0.99, "going to Lima collects it")
	# --- no Night Shift: 3 days away = 3 days of money
	gs.pending_offline = {}
	gs.ad_until = {}
	gs._boost_override = 1.0
	var rate: float = gs.idle_income()
	gs._boost_override = -1.0
	gs._grant_offline(3 * 86400.0)
	var got: float = gs.pending_offline.get("usa", 0.0)
	check(rate > 0.0 and absf(got - rate * 3 * 86400.0 * (1.0 + gs.gear_global("offline"))) < got * 0.02 + 1.0, "3 days away pays 3 days (%s at %s/s)" % [gs.money(got), gs.money(rate)])
	gs.collect_offline()
	m._popup.visible = false
	check(not gs.has_method("buy_night_shift") and not gs.has_method("offline_cap_seconds"), "Night Shift is gone")
	# an old save with Night Shift levels gets its Shine Bucks back
	gs.save_game()
	var f := FileAccess.open(gs.SAVE_PATH, FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	d["night_shift"] = 2
	var g0 := int(d["gloss"])
	f = FileAccess.open(gs.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	gs._reset_state()
	gs.load_game()
	check(gs.gloss == g0 + 30 + 55, "an old save's 2 Night Shift levels come back as 85 Shine Bucks")
	# --- shop: no ability recharge, prices show the banknote icon
	m._open_shop()
	await wait(0.3)
	var sp = _find_panel(m, "res://scripts/shop_panel.gd")
	var texts := []
	for b in sp.find_children("*", "Button", true, false):
		texts.append(str(b.get_meta("rich_src", b.text)))
	check(not str(texts).contains("Recharge") and not str(texts).contains("Night Shift"), "Shop: no ability recharge, no Night Shift")
	var wheel_ok := false
	for t in texts:
		if t.contains("{wheel}") and t.contains("LUCKY WHEEL"):
			wheel_ok = true
	check(wheel_ok and str(texts).contains("{booster}") and str(texts).contains("{wardrobe}"), "Shop: wheel / booster / wardrobe icons on their buttons")
	gs.wheel_free_at = gs.now + 3600.0
	await wait(0.3)
	var spin_ok := false
	for b in sp.find_children("*", "Button", true, false):
		if str(b.get_meta("rich_src", "")).contains("spin for %d {sb}" % Data.WHEEL_SPIN_COST):
			spin_ok = b.get_node_or_null("RichRow") != null and b.text == ""
	check(spin_ok, "\"spin for 50 [banknote]\": the icon, not the words")
	await shot("v19v_01_shop_icons")
	close_sheets()
	# --- the main screen: sky strip with the wheel, the big AD BOOST in the bar
	check(m._sky_row != null and m._rows.get_child(0) == m._sky_row, "a strip of sky above the shop")
	m._sky_row.wheel_pressed.emit()
	await wait(0.3)
	check(_find_panel(m, "res://scripts/wheel_panel.gd") != null, "tapping the wheel in the sky opens the Lucky Wheel")
	close_sheets()
	gs.ad_until = {}
	m._on_ad_boost()
	check(absf(gs.ad_boost_left() - Data.AD_BOOST_HOURS * 3600.0) < 5.0, "the AD BOOST button: one tap = +4h here")
	gs.ad_until["lima"] = gs.now + 24 * 3600.0
	m._on_ad_boost()
	await wait(0.3)
	check(_find_panel(m, "res://scripts/boost_panel.gd") != null, "... when it's full it opens Boosts instead")
	close_sheets()
	gs.ad_until = {}
	await wait(0.6)
	await shot("v19v_02_main")
	# --- bays: the detailed kit pictures
	var KitArt = load("res://scripts/kit_art.gd")
	var baked := 0
	for t in KitArt.WIDTHS.size():
		if KitArt.tex(t) != null:
			baked += 1
	check(baked == KitArt.WIDTHS.size(), "every service has its kit picture (%d)" % baked)
	# --- the map: corner panels + words that stay big when zoomed out
	gs.cities["detroit"]["prestige"] = 1
	gs.go_to_city("detroit")
	await wait(0.2)
	gs._refresh_bg_rates()
	await wait(0.8)
	m._open_map(0)
	await wait(0.6)
	var mp = null
	for c in m.get_children():
		if c.has_method("_set_tab"):
			mp = c
	check(mp != null and mp._collect_btn.visible and mp._prestige_btn.visible, "map: COLLECT and PRESTIGE in the top corners")
	mp._open_side("collect")
	await wait(0.4)
	var side = mp._side
	check(side != null and side._rows.size() == 5 and side._boost_btns.has("usa"), "COLLECT: every US city listed, BOOST ALL for the USA")
	var vw: float = m.get_viewport_rect().size.x
	var pr: Rect2 = side._panel.get_global_rect()
	check(pr.position.x < 20.0 and pr.end.x < vw - 40.0 and pr.size.y > 900.0, "COLLECT covers the LEFT side, full height (%s)" % pr)
	await shot("v19v_03_collect")
	# v0.19w: BOOST ALL is never greyed out; when it can't go it says why
	gs.ad_until = {}
	for c in Data.COUNTRIES[0]["cities"]:
		gs.ad_until[c["id"]] = gs.now + Data.AD_BOOST_MAX_HOURS * 3600.0
	check(not side._boost_btns["usa"].disabled, "BOOST ALL isn't greyed out")
	side._boost_btns["usa"].pressed.emit()
	await wait(0.3)
	check(side._note.modulate.a > 0.3 and side._note.text.contains("already"), "... tapping it when everything's full says so (%s)" % side._note.text)
	gs.ad_until = {}
	side._boost_btns["usa"].pressed.emit()
	var full := true
	for c in Data.COUNTRIES[0]["cities"]:
		full = full and gs.ad_boost_full(c["id"])
	check(full, "... and with room, one tap tops every US city up to 24h")
	await wait(0.4)
	await shot("v19w_01_collect_note")
	gs.wallets["usa"] = 0.0   # (a 1e40 wallet would swallow the amount)
	var stash0: float = gs.stash_total()
	var wal0: float = gs.wallets.get("usa", 0.0)
	side._collect_btns["usa"].pressed.emit()
	check(stash0 > 0.0 and gs.stash_total() == 0.0, "COLLECT x2 empties the US stashes")
	check(absf(gs.wallets.get("usa", 0.0) - wal0 - stash0 * Data.COLLECT_AD_MULT) < maxf(1.0, stash0 * 0.01),
		"... and pays them x%d (ad only)" % int(Data.COLLECT_AD_MULT))
	side.close()
	await wait(0.2)
	mp._open_side("prestige")
	await wait(0.4)
	side = mp._side
	check(side != null and side._prestige_btns.has("lima"), "PRESTIGE: a button per city")
	await wait(0.3)
	pr = side._panel.get_global_rect()
	check(pr.position.x > 40.0 and pr.end.x > vw - 20.0, "PRESTIGE covers the RIGHT side (%s)" % pr)
	var tc = side.find_child("TrophyCount", true, false)
	check(tc != null and tc.text.ends_with("/ %d" % (25 * Data.MAX_PRESTIGE)), "PRESTIGE: your trophies out of all of them (%s)" % (tc.text if tc else "?"))
	for r in side._rows:
		if r["id"] == "detroit":
			r["detail"].visible = true
	await wait(0.3)
	await shot("v19v_04_prestige")
	side._prestige_btns["lima"].pressed.emit()
	await wait(0.3)
	check(_find_panel(m, "res://scripts/workshop_panel.gd") != null, "... which opens that city's prestige screen")
	close_sheets()
	side.close()
	await wait(0.2)
	for k in 20:
		mp.zoom_at(mp._view.size * 0.5, 0.7)
	await wait(0.8)
	check(mp._canvas.labels.lk > 2.0, "zoomed right out, the words are drawn %.1fx bigger" % mp._canvas.labels.lk)
	await shot("v19v_05_map_zoomed_out")
	for c in m.get_children():
		if c.has_method("_set_tab"):
			c.queue_free()
	await wait(0.2)
	gs.reset_save()


func _v19w_checks() -> void:
	print("v0.19w FREE SPIN tag, trophy, loading card + launch bar")
	var gs = GameState
	var m = main_node()
	gs.reset_save()
	await wait(0.3)
	gs.finish_tutorial(true)
	_clear_popups(m)
	close_sheets()
	m._scroll.scroll_vertical = 0
	# --- the FREE SPIN tag stays inside the sky strip (it ran into the shop's banner)
	gs.wheel_free_at = 0.0
	await wait(0.8)
	var tag: Rect2 = m._sky_row._tag.get_global_rect()
	var sky: Rect2 = m._sky_row.get_global_rect()
	check(m._sky_row._tag.text == "FREE SPIN!" and tag.end.y <= sky.end.y + 0.5, "FREE SPIN! fits inside the sky strip (%s in %s)" % [tag, sky])
	# --- the trophy: plain gold, low, no city name; shines when a prestige is ready
	check(not m._city_label.visible, "no city name under the trophy")
	await shot("v19w_02_top")
	gs.cash = 1e40
	for c in Data.COUNTRIES[0]["cities"].slice(1, 3):
		gs.cash = 1e40
		gs.unlock_city(c["id"])
	gs.go_to_city("lima")
	gs.finish_tutorial(true)   # (opening a city starts its tutorial)
	_clear_popups(m)
	close_sheets()
	gs.wallets["usa"] = 1e40
	await wait(0.6)
	check(m._prestige_ready_now(), "a prestige is ready in Lima")
	await wait(0.9)
	await shot("v19w_03_trophy_ready")
	# --- the loading card: up first, the change under it, then gone
	m.loading_in_tests = true
	m.with_loading(gs.go_to_city.bind("detroit"), "detroit")
	await get_tree().process_frame
	check(m.loading_showing() and gs.active_city == "lima", "the loading card goes up BEFORE the city changes")
	await wait(0.3)
	await shot("v19w_04_loading")
	var t0 := Time.get_ticks_msec()
	while m.loading_showing() and Time.get_ticks_msec() - t0 < 6000:
		await get_tree().process_frame
	check(not m.loading_showing() and gs.active_city == "detroit", "... then you're in Detroit and it's gone (%d ms)" % (Time.get_ticks_msec() - t0))
	m.loading_in_tests = false
	# --- launch: a loading bar first, TAP TO PLAY once it's done
	gs.finish_tutorial(true)
	_clear_popups(m)
	var ts = load("res://scripts/title_screen.gd").new()
	m.add_child(ts)
	await wait(0.15)
	check(not ts._loaded, "the title screen starts with its loading bar")
	await shot("v19w_05_title_loading")
	t0 = Time.get_ticks_msec()
	while not ts._loaded and Time.get_ticks_msec() - t0 < 10000:
		await get_tree().process_frame
	check(ts._loaded, "... and gets to TAP TO PLAY (%d ms)" % (Time.get_ticks_msec() - t0))
	await wait(0.5)
	await shot("v19w_06_title_ready")
	ts.queue_free()
	await wait(0.2)
