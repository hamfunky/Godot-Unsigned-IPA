extends Node
## v0.19j fresh-player pass: plays a brand-new save like a first-time player (tips + OK popups ON),
## sped up SPEED x with the real-clock timers (abilities, boosters, renovations, ad boost) shifted to match,
## so 60 min of play takes ~60/SPEED min. Screenshots every tip / big message / toast / new screen the first
## time it shows, plus the shop every 5 min; prints a timeline of milestones at the end.
## Run like the autotest: copy to p/tests/playbot.gd, autoload it as AutoTest (so the title screen is skipped),
## PLAYMIN=60 SHOTS=/dir xvfb-run ... godot --path p --resolution 720x1280

const Data = preload("res://scripts/game_data.gd")

var SPEED := 6.0
var MINUTES := 60.0
var shots_dir := ""
var _think := 0.0
var _seen := {}          # popup text -> true (shot once)
var _log: Array = []     # [game seconds, text]
var _read_left := 0.0    # "reading" a popup before tapping OK / GOT IT
var _opened := {}        # screens opened once for a look
var _next_shot := 0.0
var _milestones := {}
var _busy := false
var _done := false
var _shot_n := 0


func _ready() -> void:
	shots_dir = OS.get_environment("SHOTS")
	if OS.get_environment("PLAYMIN") != "":
		MINUTES = float(OS.get_environment("PLAYMIN"))
	if OS.get_environment("SPEED") != "":
		SPEED = float(OS.get_environment("SPEED"))
	await get_tree().create_timer(0.5).timeout
	var gs = GameState
	gs.reset_save()
	gs.reset_tips()
	gs.tips_enabled = true
	gs.popups_need_ok = true
	await get_tree().create_timer(0.5).timeout
	Engine.time_scale = SPEED
	note("start: $%s, %d Shine Bucks" % [gs.fmt(gs.cash), gs.gloss])


func main_node() -> Node:
	return get_tree().current_scene


func t() -> float:
	return GameState.play_time


func clock() -> String:
	var s := int(t())
	return "%02d:%02d" % [s / 60, s % 60]


func note(s: String) -> void:
	_log.append([t(), s])
	print("[%s] %s" % [clock(), s])


func mile(id: String, s: String) -> void:
	if _milestones.has(id):
		return
	_milestones[id] = t()
	note("MILESTONE " + s)


func shot(name: String) -> void:
	if shots_dir == "" or _busy:
		return
	_busy = true
	await RenderingServer.frame_post_draw
	_shot_n += 1
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%03d_%s_%s.png" % [shots_dir, _shot_n, clock().replace(":", "m"), name])
	_busy = false


## Keep the real-clock timers in step with the sped-up game (like debug_skip, without the offline grant).
func _shift(secs: float) -> void:
	var gs = GameState
	for id in gs.cities.keys():
		var c: Dictionary = gs.cities[id]
		if float(c.get("reno_until", 0.0)) > 0.0:
			c["reno_until"] = float(c["reno_until"]) - secs
	for b in gs.active_boosters:
		b["until"] = float(b["until"]) - secs
	if gs.ad_boost_until > 0.0:
		gs.ad_boost_until -= secs
	for m in gs.managers + gs.roster.values():
		m["active_until"] = float(m["active_until"]) - secs
		m["ready_at"] = float(m["ready_at"]) - secs


func _process(delta: float) -> void:
	if _done or Engine.time_scale < 1.5:
		return
	_shift(delta - delta / SPEED)
	_think -= delta
	if _think > 0.0 or _busy:
		return
	_think = 0.5
	_step()


func _sheet() -> Control:
	for c in main_node().get_children():
		if c.has_method("clear_body") and not c.is_queued_for_deletion():
			return c
	return null


func _popup_text(m) -> String:
	if m._tips.busy() and m._tips.visible:
		return "TIP " + str(m._tips._cur[0]) + ": " + m._tips._text.text
	if m.big_showing():
		var parts := []
		for l in m._big_node.find_children("*", "Label", true, false):
			parts.append(l.text)
		return "BIG " + " / ".join(parts)
	if m._toast_box.visible and m._toast_box.modulate.a > 0.5:
		return ("TOAST " if m._toast_ok.visible else "NOTE ") + m._toast.text
	if m._popup.visible:
		return "WELCOME " + m._popup_label.text
	if m._banner.visible:
		return "BANNER " + m._banner_label.text.split(",")[0]   # (the countdown after the comma ticks every second)
	return ""


func _step() -> void:
	var gs = GameState
	var m = main_node()
	if t() >= MINUTES * 60.0:
		_finish()
		return
	# --- something on screen asking to be read?
	var pt := _popup_text(m)
	if pt != "":
		if not _seen.has(pt):
			_seen[pt] = true
			note(pt.replace("\n", " | "))
			shot(pt.split(" ")[0].to_lower() + "_" + pt.substr(pt.find(" ") + 1, 18).to_lower().validate_filename().replace(" ", "_"))
			_read_left = 2.5 * SPEED   # ~2.5 s of real reading
			return
		_read_left -= 0.5
		if _read_left > 0.0:
			return
		if pt.begins_with("TIP"):
			m._tips._dismiss()
		elif pt.begins_with("BIG"):
			m._big_at -= 5000
			m._dismiss_big()
		elif pt.begins_with("TOAST") or pt.begins_with("NOTE"):
			m._toast_at -= 5000
			m._dismiss_toast()
		elif pt.begins_with("WELCOME"):
			gs.collect_offline(1.0)
			m._popup.visible = false
		elif pt.begins_with("BANNER"):
			m._banner.visible = false
			m._vip_tip()
		return
	# --- a panel open from a look-around: close it
	var sh := _sheet()
	if sh != null:
		sh.close()
		return
	for c in m.get_children():
		if c.get_script() == preload("res://scripts/map_panel.gd") and not c.is_queued_for_deletion():
			c.queue_free()
			return
	# --- tutorial: do what the arrow says
	if gs.tutorial_step != gs.TUT_DONE:
		match gs.tutorial_step:
			0:
				gs.tap_bay(0)
			1:
				gs.tap_valet()
			2:
				gs.tap_desk()
		return
	mile("tut", "tutorial done")
	# --- tap whatever isn't automated (a new player taps everything)
	for i in gs.bays.size():
		if not gs.is_automated("bay%d" % i):
			gs.tap_bay(i)
	if not gs.is_automated("valet"):
		gs.tap_valet()
	if not gs.is_automated("desk"):
		gs.tap_desk()
	# --- use ready abilities (the bubbles bob for attention)
	for k in ["desk", "valet"] + range(gs.bays.size()).map(func(i): return "bay%d" % i):
		var mg: Dictionary = gs.manager_at(k)
		if not mg.is_empty() and gs.ability_ready(mg):
			gs.activate_ability(k)
			mile("ability", "first ability used (%s)" % k)
	# --- a rare car waiting in the lot: tap it in
	if not gs.vip.is_empty():
		mile("vip", "first rare car (%s)" % gs.car_def(gs.vip["id"])["name"])
		if gs.vip["phase"] == "lot" and randf() < 0.3:
			gs.send_vip()
	# --- look around once: the screens a curious player opens (tips show the first time)
	if _look(m):
		return
	# --- spend
	_spend()
	# --- milestones + the shop every 5 min
	if gs.stars() >= 2:
		mile("star", "first new star (rating %s)" % gs.rating_text())
	if gs.prestige_ready():
		mile("prestige", "prestige affordable (%s)" % gs.money(gs.prestige_cost(gs.active_city)))
	if t() >= _next_shot:
		_next_shot += 300.0
		note("STATUS cash %s  idle %s/s  bays %d  levels desk %d valet %d bay0 %d  bottleneck %s  rating %s  followers %s  SB %d" % [
			gs.money(gs.cash), gs.money(gs.idle_income()), gs.bays.size(), gs.desk["level"], gs.valet["level"], gs.bays[0]["level"],
			gs.bottleneck(), gs.rating_text(), gs.fmt(gs.followers), gs.gloss])
		shot("shop")


func _look(m) -> bool:
	var gs = GameState
	var plan := [
		["level", 30.0, func(): m._open_level_panel("bay0")],
		["managers", 60.0, func(): m._open_manager_panel("bay0")],
		["book", 120.0, func(): m._open_book()],
		["boosts", 240.0, func(): m._open_boosts()],
		["shop", 420.0, func(): m._open_shop()],
		["overview", 600.0, func(): m._open_overview()],
		["map", 900.0, func(): m._open_map(0)],
		["prestige", 1200.0, func(): m._open_workshops()],
	]
	if m._book_alert.visible and not _opened.has("book_alert") and t() > 200.0:
		_opened["book_alert"] = true
		m._open_book()
		note("opened the Book (red '!')")
		_after_open("book_alert")
		return true
	for p in plan:
		if not _opened.has(p[0]) and t() >= float(p[1]):
			_opened[p[0]] = true
			p[2].call()
			note("opened " + str(p[0]))
			_after_open(str(p[0]))
			return true
	return false


func _after_open(name: String) -> void:
	_busy = true
	await get_tree().create_timer(0.5 * SPEED).timeout
	_busy = false
	if _popup_text(main_node()) == "":
		shot("screen_" + name)
		_think = 1.0


func _spend() -> void:
	var gs = GameState
	# 1) hire for anything still manual (bay 1 first, then valet, desk, other bays)
	var order := ["bay0", "valet", "desk"]
	for i in range(1, gs.bays.size()):
		order.append("bay%d" % i)
	for k in order:
		if not gs.is_automated(k) and gs.cash >= gs.hire_cost(gs.area_of(k)):
			var mg: Dictionary = gs.hire_manager(k)
			if not mg.is_empty():
				note("hired a %s manager for %s (%s, %s)" % [gs.rarity_def(mg)["name"], k, str(mg.get("ability", "")), str(mg.get("crew", ""))])
				mile("hire1", "first manager")
				if gs.is_automated("bay0") and gs.is_automated("valet") and gs.is_automated("desk"):
					mile("auto", "bay 1 + valet + desk all automated")
				return
	# 2) a renovation that's needed
	if gs.reno_needed() > 0 and not gs.reno_running() and gs.cash >= gs.reno_cost():
		if gs.start_renovation():
			note("started renovation (%s, %s)" % [gs.reno_name(gs.reno_done() + 1), gs.fmt_time(gs.reno_left())])
			mile("reno", "first renovation started")
		return
	# 2b) v0.19k: once the renovation tip has been read, do what it says (SKIP / WATCH AD, 2 per hour)
	if gs.reno_running() and not gs.reno_ready() and gs.tip_seen("reno") and gs.reno_ads_left() > 0:
		if gs.watch_reno_ad():
			note("renovation: used a 30 min skip (%s left)" % gs.fmt_time(gs.reno_left()))
			mile("reno_skip", "first renovation skip")
		return
	if gs.reno_ready():
		if gs.unlock_renovation():
			note("renovation finished (tapped the lock)")
			mile("reno_done", "first renovation finished")
		return
	# 3) the next bay if it's affordable
	if gs.reno_needed() == 0 and gs.bays.size() < 20 and gs.cash >= gs.next_bay_cost():
		gs.buy_bay()
		note("built bay %d" % gs.bays.size())
		mile("bay%d" % gs.bays.size(), "bay %d built" % gs.bays.size())
		return
	# 4) level up whatever holds the shop back. v0.19k: SAVE for the next goal (bay or renovation) once it's
	# within ~3 min of income (the old bot kept 30% of next_bay_cost(), which is -1 while a renovation is
	# needed, so it never saved for the renovation and its "dead zone" was partly the bot)
	var key := gs.bottleneck()
	if key == "bays":
		var best := 0
		for i in gs.bays.size():
			if gs.levels_cost("bay%d" % i, 1) < gs.levels_cost("bay%d" % best, 1):
				best = i
		key = "bay%d" % best
	var c: float = gs.levels_cost(key, 1)
	var goal: float = -1.0
	if gs.reno_needed() > 0:
		if not gs.reno_running():
			goal = gs.reno_cost()
	elif gs.bays.size() < 20:
		goal = gs.next_bay_cost()
	var keep := goal if goal > 0.0 and goal <= gs.cash + gs.idle_income() * 180.0 else 0.0
	if gs.cash - c >= keep and c <= gs.cash:
		gs.buy_levels(key, 1)


func _finish() -> void:
	_done = true
	Engine.time_scale = 1.0
	var gs = GameState
	print("\n==== PLAYBOT REPORT (%d min) ====" % int(MINUTES))
	var ms: Array = _milestones.keys()
	ms.sort_custom(func(a, b): return _milestones[a] < _milestones[b])
	for k in ms:
		var s := int(_milestones[k])
		print("  %02d:%02d  %s" % [s / 60, s % 60, k])
	print("  end: cash %s, idle %s/s, %d bays, rating %s, %d Shine Bucks, prestige ready: %s" % [gs.money(gs.cash),
		gs.money(gs.idle_income()), gs.bays.size(), gs.rating_text(), gs.gloss, gs.prestige_ready()])
	print("  popups seen: %d" % _seen.size())
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(0)
