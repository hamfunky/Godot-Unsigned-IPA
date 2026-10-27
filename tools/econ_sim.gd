extends Node
## v0.19s DEV ECONOMY SIM: plays the whole game (every country) on the REAL game formulas, fast (~1-10 min for 60-120 days).
## No rendering, no UI: the main scene is dropped and GameState runs in sim_mode (no saves, no _process) on our clock.
## Every price, rate, timer and reward is the game's own code. The player (PLAYER env):
##   decent = 4 sessions a day (~80 min), keen = 6 (~2h50), casual = 2 (~30 min); day 1 starts with a 60 min session.
##   Between sessions: offline earnings (v0.19v: never capped), collected x2 (no-ads pack's free x2).
##   In a session: tops up the ad x2 boost, spins the free Lucky Wheel, uses its best booster, puts the best cars on
##   show, gets rare cars at the real rate, hires into every empty station, unlocks cities/countries, prestiges a
##   developed city earning < 30% of its country, builds bays, starts renovations + uses the 2 skips an hour, saves
##   for anything within reach, otherwise levels valet/desk to 1.1x the bays and the best-payback bay.
##   Cities without managers everywhere earn at half speed while the player sits in them (tapping).
## Not modelled: manager abilities, premium managers, skill tree, Hometown, equipment, wardrobe (all speed things up).
## CAL=1 checks the idle formula against the live per-frame station code (they match within ~5% when the bays are the
## bottleneck; live is FASTER when the valet is: the formula is the cautious one).
## Run: copy to <copy>/tests/econ_sim.gd, autoload it as AutoTest in <copy>/project.godot, then
##   PLAYER=decent DAYS=60 SEED=1 godot --headless --path <copy>
## Extra env: DAILY=1 (wallets/rates each day, unmanaged stations, STALL dumps), PROG=n (a line every n steps),
##   WATCH=<city id> (that city's levels every 5 steps). Each run differs a little (seed + RNG order): run 2-3 seeds.

const Data = preload("res://scripts/game_data.gd")
const T0 := 1900000000.0

var gs
var t := 0.0
var days := 60.0
var events: Array = []     # [t, text]
var _seen := {}
var vip_acc := 0.0
var last_print := -1
var _rates := {}   # city id -> idle $/s at the last refresh


func _ready() -> void:
	if OS.get_environment("DAYS") != "":
		days = float(OS.get_environment("DAYS"))
	_run.call_deferred()


func note(key: String, text: String) -> void:
	if _seen.has(key):
		return
	_seen[key] = true
	events.append([t, text])


func stamp(tt: float) -> String:
	if tt < 86400.0:
		return "%6.2fh" % (tt / 3600.0)
	return "day %5.1f" % (tt / 86400.0)


## Play sessions (hour of day, minutes). Day 1 starts with a long first session.
const PLAYERS := {
	"decent": [[8.0, 20.0], [12.5, 15.0], [18.0, 25.0], [21.5, 20.0]],              # ~80 min a day
	"keen": [[7.5, 30.0], [10.0, 15.0], [12.5, 30.0], [15.5, 15.0], [18.0, 40.0], [21.0, 40.0]],   # ~2h50 a day
	"casual": [[8.0, 10.0], [19.0, 20.0]],                                            # ~30 min a day
}
const FIRST_SESSION_MIN := 60.0
var sessions: Array = []
var steps := 0
var real0 := 0


func _run() -> void:
	gs = GameState
	var cs := get_tree().current_scene
	if cs != null:
		cs.queue_free()
	await get_tree().process_frame
	gs.sim_mode = true
	seed(int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 1)
	gs.tips_enabled = false
	gs.popups_need_ok = false
	gs.now = T0
	gs.reset_save()
	gs.finish_tutorial(true)
	gs.book_opened = true   # the player opens the Book when its tip comes (first minutes)
	gs.milestone.connect(_on_milestone)
	if gs.active_city != "lima" or gs.bays.size() != 1 or gs.cash > 100.0:
		printerr("SIM START STATE WRONG: %s bays %d cash %s" % [gs.active_city, gs.bays.size(), gs.fmt(gs.cash)])
		get_tree().quit(1)
		return
	if OS.get_environment("CAL") != "":
		_calibrate()
		get_tree().quit(0)
		return
	var who := OS.get_environment("PLAYER") if OS.get_environment("PLAYER") != "" else "decent"
	sessions = PLAYERS[who]
	print("player '%s': %s" % [who, str(sessions)])
	gs.star_up.connect(func(s): note("star%d" % s, "rating %s (%s followers)" % [gs.rating_text(s), gs.fmt(gs.followers)]))
	real0 = Time.get_ticks_msec()
	var active_total := 0.0
	var day := 0
	while day < int(days):
		for k in sessions.size():
			var start: float = day * 86400.0 + float(sessions[k][0]) * 3600.0
			var mins: float = float(sessions[k][1])
			if day == 0 and k == 0:
				mins = FIRST_SESSION_MIN
			# away until this session (offline earnings, the real cap, collected x2 with the no-ads pack)
			if start > t:
				var away := start - t
				t = start
				gs.now = T0 + t
				gs._grant_offline(away)
				gs.collect_offline(2.0 if gs.ad_free() else 1.0)
				gs.collect_all()   # v0.19v: the other cities' stashes (COLLECT ALL on the map each session)
			var end := t + mins * 60.0
			while t < end - 0.5:
				steps += 1
				_play()
				var dt := clampf(active_total * 0.01, 5.0, 300.0)
				dt = minf(dt, end - t)
				_earn(dt)
				t += dt
				active_total += dt
				gs.now = T0 + t
				gs.play_time += dt
				if OS.get_environment("PROG") != "" and steps % int(OS.get_environment("PROG")) == 0:
					_prog()
				if OS.get_environment("WATCH") != "" and gs.cities.has(OS.get_environment("WATCH")) and steps % 5 == 0:
					_watch(OS.get_environment("WATCH"))
			_play()
		day += 1
		await get_tree().process_frame   # lets Godot flush deferred calls / queued signals (memory stays flat)
		if OS.get_environment("DAILY") != "":
			var line := "  D%3d" % day
			for cid in gs.unlocked_countries():
				line += "  %s %s (+%s/s)" % [cid, gs.fmt(_wallet(cid)), gs.fmt(_country_rate(cid))]
			var back: String = gs.active_city
			for id in gs.cities.keys():
				if id == Data.HOMETOWN_ID:
					continue
				_goto(id)
				var miss := []
				for k in ["desk", "valet"] + range(gs.bays.size()).map(func(i): return "bay%d" % i):
					if not gs.is_automated(k):
						miss.append("%s(hire %s)" % [k, gs.fmt(gs.hire_cost(gs.area_of(k)))])
				if not miss.is_empty():
					line += "\n      %s UNMANAGED %s  cash %s" % [id, str(miss), gs.fmt(gs.cash)]
			for cid in gs.unlocked_countries():
				var r := _country_rate(cid)
				var key: String = "stall_" + cid
				var prev: Array = _seen.get(key + "_r", [0.0, 0])
				var same: int = int(prev[1]) + 1 if absf(r - float(prev[0])) <= 0.01 * r else 0
				_seen[key + "_r"] = [r, same]
				if same == 3:
					line += "\n   STALL %s:" % cid
					for id in _own_cities(cid):
						_goto(id)
						var lv := []
						for b in gs.bays:
							lv.append(b["level"])
						line += "\n      %s p%d V%d(%s) D%d(%s) bays %s  bay0 +1 costs %s  rates b/v/d %s %s %s" % [id, gs.prestige, gs.valet["level"], gs.fmt(gs.levels_cost("valet", 1)),
							gs.desk["level"], gs.fmt(gs.levels_cost("desk", 1)), str(lv), gs.fmt(gs.levels_cost("bay0", 1)),
							gs.fmt(gs.bays_total_income(false)), gs.fmt(gs.valet_rate()), gs.fmt(gs.desk_rate())]
			_goto(back)
			printerr(line)
		if day % 5 == 0:
			printerr("  sim day %d ... %d steps (%.1fs real, %d MB, %d managers, %d events)" % [day, steps, (Time.get_ticks_msec() - real0) / 1000.0,
				OS.get_static_memory_usage() / 1048576, gs.managers.size(), events.size()])
	_report((Time.get_ticks_msec() - real0) / 1000.0)
	get_tree().quit(0)


func _watch(id: String) -> void:
	var back: String = gs.active_city
	_goto(id)
	var lv := []
	for b in gs.bays:
		lv.append(b["level"])
	printerr("  W %s %s wallet=%s idle=%s bg=%s V%d D%d bays%s auto=%s active=%s" % [stamp(t), id, gs.fmt(gs.cash), gs.fmt(gs.idle_income()), gs.fmt(float(gs._bg_rates.get(id, -1.0))),
		gs.valet["level"], gs.desk["level"], str(lv), str(gs._assigned.keys().size()), back])
	printerr("     desk cost1=%s max=%d mode_max=%d desk_rate=%s valet_rate=%s bays=%s" % [gs.fmt(gs.levels_cost("desk", 1)), gs.station_max_level("desk"), gs.levels_for_mode("desk", "max"),
		gs.fmt(gs.desk_rate()), gs.fmt(gs.valet_rate()), gs.fmt(gs.bays_total_income(false))])
	_goto(back)


func _prog() -> void:
	printerr("  step %d %s cash=%s city=%s bays=%d idle=%s V%d D%d B0 %d boost %.1f real=%.1fs" % [steps, stamp(t), gs.fmt(gs.cash), gs.active_city, gs.bays.size(),
		gs.fmt(gs.idle_income()), gs.valet["level"], gs.desk["level"], gs.bays[0]["level"], gs.total_boost(), (Time.get_ticks_msec() - real0) / 1000.0])


func _on_milestone(kind: String, text: String) -> void:
	match kind:
		"city", "country", "prestige", "reno_start":
			note(kind + text, text)
		"bay":
			# only Lima's first bays + every city's bay 6/11/16/20
			note(kind + text, text)


## Income for dt seconds of play (every city, boosts included) + followers on show + rare cars + new cars.
func _earn(dt: float) -> void:
	gs._expire_boosters()
	for id in gs.cities.keys():
		var r: float = gs.idle_income() if id == gs.active_city else float(gs._bg_rates.get(id, 0.0))
		if id == gs.active_city:
			r = _active_rate()
		var cid: String = gs.country_of(id)
		gs.wallets[cid] = gs.wallets.get(cid, 0.0) + r * dt
		gs.lifetime_earned += r * dt
	if not gs.display.is_empty():
		gs.add_followers(gs.display_followers_per_hour() / 3600.0 * dt)
	# new cars into the Book (the bays keep washing: a few new picks per bay per step)
	for i in gs.bays.size():
		for k in clampi(int(dt / 20.0), 1, 15):
			gs.log_car(gs._pick_car(i))
	# rare cars at the game's rate (the guaranteed first one at Bay 3)
	if not gs.first_vip_done:
		if gs.bays.size() >= Data.FIRST_VIP_BAYS:
			gs.spawn_vip(false, 0)
			gs._finish_vip()
	elif gs.bays.size() >= 2:
		vip_acc += (1.0 + Data.STAR_VIP_BONUS * (gs.stars() - 1)) / Data.VIP_MEAN_INTERVAL * dt
		while vip_acc >= 1.0:
			vip_acc -= 1.0
			gs.spawn_vip(false)
			if not gs.vip.is_empty():
				gs._finish_vip()
	gs._reno_tick()


## The city on screen: stations without a manager still work while the player taps them, at about half speed.
func _active_rate() -> float:
	var b: float = 0.5 * (gs.bays_total_income(false) + gs.bays_total_income(true))
	var v: float = gs.valet_rate() * (1.0 if gs.is_automated("valet") else 0.5)
	var d: float = gs.desk_rate() * (1.0 if gs.is_automated("desk") else 0.5)
	return minf(b, minf(v, d))


func _top_up_ad() -> void:
	for k in 8:
		gs.watch_ad_boost()


## The player's turn (called every step while awake).
func _play() -> void:
	_top_up_ad()
	if gs.wheel_free_ready():
		var r: Dictionary = gs.spin_wheel(true)
		if r.has("manager"):
			note("wheel_legend", "WHEEL JACKPOT: " + str(r["text"]))
	gs.open_delivery()   # v0.19t: today's parcel (does nothing once it's opened)
	gs.pet_cat()
	_use_boosters()
	_show_best_cars()
	# (v0.19v: Night Shift is gone, time away is never capped)
	var countries: Array = gs.unlocked_countries()
	for cid in countries:
		_play_country(cid)
	# sit in a city that still needs tapping (no managers everywhere yet: newest first), else the best earner
	var best: String = gs.active_city
	var br := -1.0
	for id in gs.cities.keys():
		if id == Data.HOMETOWN_ID:
			continue
		var r := _city_r(id)
		if not _fully_automated(id):
			r = 1e300
		if r >= br:
			br = r
			best = id
	_goto(best)
	_refresh_rates()


func _fully_automated(id: String) -> bool:
	_goto(id)
	if not (gs.is_automated("desk") and gs.is_automated("valet")):
		return false
	for i in gs.bays.size():
		if not gs.is_automated("bay%d" % i):
			return false
	return true


## go_to_city without the background-rate refresh (done once per round instead).
func _goto(id: String) -> void:
	if id != gs.active_city and gs.cities.has(id):
		gs._store_city()
		gs._load_city(id)


func _use_boosters() -> void:
	if not gs.active_boosters.is_empty():
		return
	var best := ""
	var bm := 0.0
	for id in gs.boosters.keys():
		var d: Dictionary = gs.booster_def(id)
		if int(gs.boosters[id]) > 0 and float(d["mult"]) * float(d["minutes"]) > bm:
			bm = float(d["mult"]) * float(d["minutes"])
			best = id
	if best != "":
		gs.activate_booster(best)


func _show_best_cars() -> void:
	var slots: int = gs.display_slots()
	if gs.display.size() >= slots and gs.display.size() > 0:
		return
	var ids: Array = gs.book.keys()
	ids.sort_custom(func(a, b): return _fph(a) > _fph(b))
	for id in ids:
		if gs.display.size() >= slots:
			break
		if not gs.display.has(id):
			gs.toggle_display(id)


func _fph(id: String) -> float:
	var c: Dictionary = gs.car_def(id)
	if c.get("vip", false):
		return Data.VIP_DISPLAY_FPH[int(c["rarity"])]
	return Data.DISPLAY_FPH[int(c["tier"])]


func _own_cities(cid: String) -> Array:
	return gs.country_def(cid)["cities"].map(func(c): return c["id"]).filter(func(id): return gs.cities.has(id))


func _country_rate(cid: String) -> float:
	var tot := 0.0
	for id in _own_cities(cid):
		tot += _city_r(id)
	return maxf(tot, 1e-9)


func _wallet(cid: String) -> float:
	return float(gs.wallets.get(cid, 0.0))


func _play_country(cid: String) -> void:
	var own := _own_cities(cid)
	var inc := _country_rate(cid)
	var horizon := minf(maxf(60.0, 0.1 * t), 1800.0)   # saves for a goal that's within reach (like world2.py)
	var saving := false
	var list: Array = gs.country_def(cid)["cities"]
	# next city
	if own.size() < list.size():
		var nid: String = list[own.size()]["id"]
		var cost: float = gs.city_unlock_cost(nid)
		if cost > 0.0:
			if _wallet(cid) >= cost:
				gs.unlock_city(nid)
				gs.finish_tutorial(true)
				own = _own_cities(cid)
			elif cost <= _wallet(cid) + inc * horizon:
				saving = true
	# next country (from the last unlocked country, once its last city is open)
	var ci: int = gs.country_index(cid)
	if ci + 1 < Data.COUNTRIES.size() and own.size() == list.size():
		var nxt: String = Data.COUNTRIES[ci + 1]["id"]
		var cc: float = gs.country_unlock_cost(nxt)
		if cc > 0.0:
			if _wallet(cid) >= cc:
				gs.unlock_country(nxt)
				gs.finish_tutorial(true)
				return
			elif cc <= _wallet(cid) + inc * horizon:
				saving = true
	# prestige a developed city that isn't the main earner (oldest first)
	var tot := inc
	for id in own:
		var c: Dictionary = gs.cities[id]
		var r: float = _city_r(id)
		if int(c["prestige"]) >= Data.MAX_PRESTIGE or c["bays"].size() < 6 or r / tot >= 0.3:
			continue
		var pc: float = gs.prestige_cost(id)
		if pc < 0.0 or gs.prestige_needs(id) != "":
			continue
		if _wallet(cid) >= pc:
			gs.prestige_city(id)
			if id == gs.active_city:
				gs.finish_tutorial(true)
		elif pc <= _wallet(cid) + inc * horizon:
			saving = true
		break
	# goals in every city: hires, the next bay, renovations
	for id in own:
		_goto(id)
		_hire_all()
		while true:
			if gs.reno_needed() > 0:
				if gs.reno_ready():
					gs.unlock_renovation()
					continue
				if gs.reno_running():
					while gs.reno_ads_left() > 0 and gs.watch_reno_ad():
						pass
					if gs.reno_ready():
						gs.unlock_renovation()
						continue
					break
				var rc: float = gs.reno_cost()
				if gs.cash >= rc:
					gs.start_renovation()
					continue
				if rc <= gs.cash + inc * horizon:
					saving = true
				break
			var bc: float = gs.next_bay_cost()
			if bc < 0.0:
				break
			if gs.cash >= bc:
				gs.buy_bay()
				continue
			if bc <= gs.cash + inc * horizon:
				saving = true
			break
	if saving:
		return
	# level up: the best payback first, across this country's cities
	var order := own.duplicate()
	order.sort_custom(func(a, b): return _city_r(a) > _city_r(b))
	for id in order:
		_goto(id)
		_level_city()


## Each city's idle rate as of the last refresh (the active city included: _bg_rates leaves it out).
func _city_r(id: String) -> float:
	return float(_rates.get(id, 0.0))


func _refresh_rates() -> void:
	gs._refresh_bg_rates()
	_rates = gs._bg_rates.duplicate()
	_rates[gs.active_city] = gs.idle_income()


func _hire_all() -> void:
	var keys := ["desk", "valet"]
	for i in gs.bays.size():
		keys.append("bay%d" % i)
	for k in keys:
		if not gs.is_automated(k):
			var hc: float = gs.hire_cost(gs.area_of(k))
			if gs.cash >= hc:
				gs.hire_manager(k)


## Keeps valet + desk 10% ahead of the bays, then buys bay levels with the best income per $ (up to 10 at a time).
func _level_city() -> void:
	for n in 200:
		var bays_out: float = gs.bays_total_income(false)
		var key := ""
		if gs.valet_rate() < 1.1 * bays_out and gs.valet["level"] < gs.station_max_level("valet"):
			key = "valet"
		elif gs.desk_rate() < 1.1 * bays_out and gs.desk["level"] < gs.station_max_level("desk"):
			key = "desk"
		else:
			var best := 0.0
			for i in gs.bays.size():
				var k := "bay%d" % i
				var L: int = gs.bays[i]["level"]
				if L >= gs.station_max_level(k):
					continue
				var c: float = gs.levels_cost(k, 1)
				var g: float = gs.bay_income(i, L + 1) - gs.bay_income(i, L)
				if c > 0.0 and g / c > best:
					best = g / c
					key = k
		if key == "":
			return
		var k_n: int = mini(10, gs.levels_for_mode(key, "max"))
		while k_n > 1 and gs.levels_cost(key, k_n) > gs.cash:
			k_n -= 1
		if gs.levels_cost(key, k_n) > gs.cash:
			return
		gs.buy_levels(key, k_n)


func _report(real_s: float) -> void:
	print("\n==== ECON SIM (%d days, %.0fs real) ====" % [int(days), real_s])
	for e in events:
		print("  %s  %s" % [stamp(float(e[0])), e[1]])
	print("  end: rating %s (%s followers), %d Book cars, %d sets, %s Shine Bucks" % [gs.rating_text(), gs.fmt(gs.followers),
		gs.book.size(), gs.tiers_done.size(), gs.fmt(gs.gloss)])
	gs._refresh_bg_rates()
	for cid in gs.unlocked_countries():
		print("    wallet %s: %s" % [cid, gs.fmt(_wallet(cid))])
	for id in gs.cities.keys():
		var c: Dictionary = gs.cities[id]
		var auto := _fully_automated(id)
		print("    %-14s prestige %d  bays %2d  %s/s%s  reno %d/%s  next bay %s" % [id, int(c["prestige"]), gs.bays.size(), gs.fmt(gs.idle_income()),
			"" if auto else " (NOT all managed)", gs.reno_needed(), "running" if gs.reno_running() else "-", gs.fmt(gs.next_bay_cost())])


## CAL=1: is the idle formula (what this sim pays) the same as the live game (cars really moving)?
## Builds Lima to a few sizes, runs GameState's own per-frame station code for 10 game minutes, compares.
func _calibrate() -> void:
	for nb in [1, 3, 5, 8, 10]:
		for lv in [10, 50, 150]:
			gs.reset_save()
			gs.finish_tutorial(true)
			gs.now = T0
			gs.first_vip_done = true
			gs.active_boosters = []
			gs.boosters = {}
			gs.ad_boost_until = 0.0
			gs.wallets["usa"] = 1e30
			var guard := 0
			while gs.bays.size() < nb and guard < 50:
				guard += 1
				if gs.reno_needed() > 0:
					gs.start_renovation()
					gs._cstate("")["reno_until"] = gs.now - 1.0
					gs.unlock_renovation()
					continue
				gs.buy_bay()
			printerr("cal setup bays %d (want %d) cash %s reno %d" % [gs.bays.size(), nb, gs.fmt(gs.cash), gs.reno_needed()])
			_hire_all()
			for k in ["valet", "desk"] + range(nb).map(func(i): return "bay%d" % i):
				var want: int = lv
				var cur: int = gs.valet["level"] if k == "valet" else (gs.desk["level"] if k == "desk" else gs.bays[int(k.substr(3))]["level"])
				if want > cur:
					gs.buy_levels(k, mini(want - cur, gs.station_max_level(k) - cur))
			gs.wallets["usa"] = 0.0
			var formula: float = gs.idle_income()
			var dt := 0.05
			var secs := 600.0
			# warm-up 60s (cars in flight), then measure
			for pass_i in 2:
				var c0: float = gs.cash
				var n := int((60.0 if pass_i == 0 else secs) / dt)
				for k in n:
					gs.now += dt
					for i in gs.bays.size():
						gs._advance_bay(i, dt)
					gs._advance_valet(dt)
					gs._advance_desk(dt)
				if pass_i == 1:
					var live: float = (gs.cash - c0) / secs
					print("CAL bays %2d lv %3d  formula %s/s  live %s/s  live/formula %.2f   (bays %s valet %s desk %s)" % [nb, lv,
						gs.fmt(formula), gs.fmt(live), live / maxf(formula, 1e-9), gs.fmt(gs.bays_total_income(false)), gs.fmt(gs.valet_rate()), gs.fmt(gs.desk_rate())])
