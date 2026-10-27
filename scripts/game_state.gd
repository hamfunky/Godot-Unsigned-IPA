extends Node
## Autoload "GameState": owns all game data. UI scripts only read from here and
## call its methods.
##
## World: COUNTRIES (own currency wallet) -> CITIES (own shop). Every unlocked city
## earns at once: the city on screen ("active") runs live; the others earn their
## idle rate in the background. Each shop is a 3-station chain:
## bays -> valet -> front desk. Stations are keys: "bay0".."bay9", "valet", "desk".
##
## The active city's shop lives in the plain vars below (bays, valet, desk, hires,
## prestige, vip) so all the station code stays simple. Switching city stores them
## into `cities[id]` and loads the other one (see _store_city / _load_city).

signal state_changed                              # structure changed (bay built, manager moved...)
signal job_completed(bay_index: int, amount: float)
signal cash_earned(amount: float)                 # the front desk turned cars into cash
signal manager_hired(manager: Dictionary)           # cash hire
signal manager_called(manager: Dictionary)          # a named manager joined your roster
signal case_opened(result: Dictionary)               # {file, clues: [[manager id, clue index]], certs}
signal roster_changed                                # clues, case files, certs, levels
signal equipment_changed                             # crafted, upgraded, equipped, materials
signal hometown_changed                              # unlocked, renovation, milestone, new run
signal wardrobe_changed
signal renovation_done(city_id: String, k: int)
signal renovation_started(city_id: String, k: int)   # v0.19k: the one-time "watch an ad" tip
signal offline_earnings_ready
signal car_logged(car: Dictionary)                # first time a car model goes in the Book
signal tier_set_completed(tier: int)
signal star_up(stars: int)
signal vip_arrived(car: Dictionary, alert: bool)  # alert = show the big banner
signal vip_finished(result: Dictionary)           # {car, pay, followers, gloss}
signal tutorial_finished
signal city_changed                               # travelled, unlocked or prestiged the active city
signal prestiged(city_id: String)
signal leveled(key: String, levels: int, boosts: Array)   # boosts = boost ladder steps just reached
signal valet_unloaded(amount: float)
signal boosts_changed
signal delivery_opened(reward: Dictionary)   # v0.19t
signal cat_petted(treat: int)                 # v0.19t: treat = Shine Bucks she left (0 = just hearts)
signal milestone(kind: String, text: String)   # v0.19s: every balance-log milestone (the econ sim records them)
signal signature_popped(station_key: String, text: String)   # v0.19r: a signature's payoff, popped over its station
signal tip_jar_paid(station_key: String, amount: float, mult: float)   # Dazza cashed his tip jar
signal stash_collected(city_id: String, amount: float)   # v0.19v: a city's stash went into its wallet ("" = Collect all)

const Data = preload("res://scripts/game_data.gd")
const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 7
const AUTOSAVE_INTERVAL := 15.0
const MIN_OFFLINE_SECONDS := 30.0
const BG_RATE_INTERVAL := 2.0
# Tutorial steps (arrows show the player where to tap). Re-run on new cities and prestige.
enum { TUT_WASH, TUT_VALET, TUT_DESK, TUT_HIRE_BAY, TUT_HIRE_VALET, TUT_HIRE_DESK, TUT_LEVEL, TUT_DONE }
const SUFFIXES := ["", "K", "M", "B", "T"]   # then aa, ab, ... az, ba, ...

# ---------------------------------------------------------------- world
var wallets: Dictionary = {}  # country id -> cash in that country's currency
var cities: Dictionary = {}   # city id -> saved shop state (see _new_city_state)
var active_city: String = "lima"
var country: String = "usa"   # country of the active city

## Cash of the country you're in. Everything that spends or earns uses this.
var cash: float:
	get:
		return wallets.get(country, 0.0)
	set(v):
		wallets[country] = v

# ---------------------------------------------------------------- active city's shop
var bays: Array = []          # [{level, running, progress, ready, car}]
var valet: Dictionary = {}    # {level, phase, pos, stop, carried, timer, requested}
var desk: Dictionary = {}     # {level, lot, running, progress, batch, requested}
var hires: Dictionary = {}    # area -> cash managers hired in this city (drives hire cost)
var prestige: int = 0         # 0..MAX_PRESTIGE, index into Data.PREMISES
var vip: Dictionary = {}      # {} or {id, phase: "lot"|"bay", timer, bay, progress, running}

# ---------------------------------------------------------------- global
var lifetime_earned: float = 0.0
# managers: cash hires {id, name, area, rarity, ability, crew, home, city, assigned, active_until, ready_at}
#   home = the city they were hired in (they only work there). city + assigned = where they work now.
var managers: Array = []
var next_manager_id: int = 1
# roster: named (premium) manager id -> their def (from Data.NAMED_MANAGERS) + progress:
#   clues (bit mask of Data.CLUES found), owned, level, city + assigned (where they
#   work now, "" = free), active_until, ready_at (ability).
var roster: Dictionary = {}
var case_files: Dictionary = {}     # case file id -> how many unopened
var shortcut_moved := 0.0         # v0.19o: cash Kev's Shortcut has carried this run (for the screen)
var wheel_free_at := 0.0           # v0.19n: unix time the next free Lucky Wheel spin is ready (0 = now)
var delivery_day := -1             # v0.19t: local day number the last Daily Delivery was opened (-1 = never)
var delivery_count := 0            # v0.19t: parcels opened so far (the 7-day track position = count % 7)
var cat_treat_day := -1            # v0.19t: local day the shop cat last left a treat
var decor: Array = []              # v0.19t: decor ids bought
var shop_name := ""                # v0.19t: the player's name for their shop ("" = the premises name)
var last_away_seconds := 0.0       # v0.19t: how long the last time away was (not saved)
var last_away_followers := 0.0     # v0.19t: followers the showroom + decor brought in meanwhile
var certs: int = 0                  # levels up named managers
var city_nudges: Dictionary = {}    # city id -> "shown" / "seen": the one-time "next city is open" MAP nudge (v0.17d)
var starter_given := false          # the first manager's dossier (given when the tutorial ends)
var materials: Dictionary = {}      # crafting material id -> amount
var equipment: Dictionary = {}      # item id -> tier crafted (0 Common, 1 Rare, 2 Epic); missing = not crafted
# Hometown Garage: {unlocked, runs_done, renos (done this run), reno_until (0 = none running),
#   ad_log (unix times of renovation ads), claimed (milestone ids claimed this run)}
var hometown: Dictionary = {}
var wardrobe: Dictionary = {}       # uniform id -> {level, copies (toward the next level)}
var worn: Dictionary = {}           # "bay" / "valet" / "desk" -> uniform id being worn
var wardrobe_pity: int = 0          # uniforms opened since the last Legendary
var play_time: float = 0.0          # seconds played (incl. debug skips), for balancing
const BALANCE_LOG_PATH := "user://balance_log.csv"
var pending_offline: Dictionary = {}   # country id -> amount waiting to collect
var pending_offline_seconds: float = 0.0
var gloss: int = 0            # premium currency (name in Data.PREMIUM_NAME)
var followers: float = 0.0    # reputation
var book: Dictionary = {}     # car id -> times detailed
var display: Array = []       # car ids on display in the Book
var bought_slots: int = 0
var tiers_done: Array = []    # Book tiers fully collected
var settings: Dictionary = {"rare_alerts": true, "sound": true, "vibration": true}
var first_vip_done := false   # no rare cars at all until a guaranteed first one when Bay 3 is built (early wow moment)
var book_opened := false      # v0.19k: Book sets only complete once the Book has been opened (no SET COMPLETE out of nowhere)
var book_unseen := false      # some car in the Book hasn't been looked at yet ("!" on the BOOK button)
var book_new: Dictionary = {}  # v0.17g: car id -> true until you've seen it in its Book category
var _first_vip_timer := 0.0
var tutorial_step: int = 0
var _tut_base := 0.0   # lifetime_earned when this tutorial run started (0 = a brand-new game)
var _tut_paid := false  # the front desk here has paid out since this tutorial run started
var tips_enabled := true  # v0.17h one-time tips (the autotest turns them off; not saved)
var popups_need_ok := true  # v0.19j: big messages + toasts stay until OK (the autotest turns it off = old timed fade; not saved)
var boosters: Dictionary = {}       # booster id -> how many you own
var active_boosters: Array = []     # [{id, mult, until}] running now
var ad_until: Dictionary = {}       # v0.19v: city id -> unix time its ad x2 runs until (per city, Hamza 27 Oct)
var stash: Dictionary = {}          # v0.19v: city id -> money a city you're NOT in earned, waiting for COLLECT
## The ad x2 of the city you're in (kept as a plain var name for older code + tests).
var ad_boost_until: float:
	get:
		return float(ad_until.get(_ad_key(), 0.0))
	set(v):
		ad_until[_ad_key()] = v
var perm_boost: float = 1.0         # permanent multiplier (e.g. a lifetime x2 purchase later)
var deals_bought: Dictionary = {"window": -1, "ids": []}   # v0.19j: boosters bought in this 12h deals window
var tokens: Dictionary = {}         # country id -> unspent skill tokens
var tokens_bought: Dictionary = {}  # country id -> tokens bought so far (drives price)
var skills: Dictionary = {}         # skill node id -> level

var now: float = 0.0          # unix time, refreshed every frame
var sim_mode := false         # v0.19s dev: tools/econ_sim.gd runs the economy on its own clock (no saves, no ticking)
var cars_by_id: Dictionary = {}  # id -> car def (VIP defs get "vip": true, "tier": 6)
var _assigned: Dictionary = {}   # station key -> manager dict (active city only)
var _bg_rates: Dictionary = {}   # city id -> idle $/s while not on screen
var _bg_timer: float = 0.0
var _ignore_abilities := false
var _skill_nodes: Dictionary = {}   # node id -> node def (+ "country")
var _skill_cache: Dictionary = {}   # "type" / "type:key" -> total value
var _autosave_timer: float = 0.0
var _paused_at: float = 0.0


func _ready() -> void:
	now = Time.get_unix_time_from_system()
	for c in Data.CARS:
		cars_by_id[c["id"]] = c
	for c in Data.VIP_CARS:
		var v: Dictionary = c.duplicate()
		v["vip"] = true
		v["tier"] = 6
		cars_by_id[c["id"]] = v
	for cid in Data.SKILL_BRANCHES.keys():
		for n in Data.SKILL_BRANCHES[cid]:
			var nd: Dictionary = n.duplicate()
			nd["country"] = cid
			_skill_nodes[n["id"]] = nd
	_reset_state()
	var saved_at := load_game()
	_refresh_bg_rates()
	if saved_at > 0.0:
		_grant_offline(now - saved_at)


func _reset_state() -> void:
	wallets = {"usa": 0.0}
	cities = {}
	lifetime_earned = 0.0
	managers = []
	next_manager_id = 1
	_init_roster()
	case_files = {}
	certs = 0
	starter_given = false
	city_nudges = {}
	wheel_free_at = 0.0
	delivery_day = -1
	delivery_count = 0
	cat_treat_day = -1
	decor = []
	shop_name = ""
	materials = {}
	equipment = {}
	hometown = _new_hometown()
	wardrobe = {}
	worn = {}
	wardrobe_pity = 0
	pending_offline = {}
	pending_offline_seconds = 0.0
	gloss = Data.START_GLOSS
	followers = 0.0
	book = {}
	display = []
	bought_slots = 0
	tiers_done = []
	book_opened = false
	settings = {"rare_alerts": true, "sound": true, "vibration": true, "ad_free": true, "music": true, "music_volume": 0.6}
	play_time = 0.0
	first_vip_done = false
	_first_vip_timer = 0.0
	book_unseen = false
	book_new = {}
	tutorial_step = TUT_WASH
	_tut_base = 0.0
	_tut_paid = false
	tokens = {}
	tokens_bought = {}
	skills = {}
	boosters = Data.STARTER_BOOSTERS.duplicate()
	active_boosters = []
	deals_bought = {"window": -1, "ids": []}
	ad_until = {}
	stash = {}
	perm_boost = 1.0
	_rebuild_skill_cache()
	_bg_rates = {}
	cities["lima"] = _new_city_state()
	_load_city("lima")


func _new_bay(level: int = 1) -> Dictionary:
	return {"level": level, "running": false, "progress": 0.0, "ready": 0.0, "car": ""}


func _new_valet(level: int) -> Dictionary:
	return {"level": level, "phase": "idle", "pos": 0.0, "stop": 0, "carried": 0.0, "timer": 0.0, "requested": false}


func _new_desk(level: int, lot: float) -> Dictionary:
	return {"level": level, "lot": lot, "running": false, "progress": 0.0, "batch": 0.0, "requested": false}


func _new_city_state(p: int = 0) -> Dictionary:
	return {"prestige": p, "bays": [_new_bay()], "valet": _new_valet(1), "desk": _new_desk(1, 0.0),
		"hires": {"bay": 0, "valet": 0, "desk": 0}, "vip": {}, "renos": 0, "reno_until": 0.0, "ad_log": []}


# ================================================================ world: cities + countries

## Save the active shop's vars back into its city state.
func _store_city() -> void:
	if not cities.has(active_city):
		return
	var c: Dictionary = cities[active_city]
	c["bays"] = bays
	c["valet"] = valet
	c["desk"] = desk
	c["hires"] = hires
	c["prestige"] = prestige
	c["vip"] = vip


## Make city `id` the active shop.
func _load_city(id: String) -> void:
	var c: Dictionary = cities[id]
	active_city = id
	country = country_of(id)
	bays = c["bays"]
	valet = c["valet"]
	desk = c["desk"]
	hires = c["hires"]
	prestige = int(c["prestige"])
	vip = c["vip"]
	if not wallets.has(country):
		wallets[country] = 0.0
	_rebuild_assigned()
	for i in bays.size():
		if bays[i]["car"] == "" or not cars_by_id.has(bays[i]["car"]):
			bays[i]["car"] = _pick_car(i)


static func country_def(id: String) -> Dictionary:
	if id == Data.HOMETOWN_ID:
		return Data.HOMETOWN_COUNTRY
	for c in Data.COUNTRIES:
		if c["id"] == id:
			return c
	return Data.COUNTRIES[0]


static func city_def(id: String) -> Dictionary:
	if id == Data.HOMETOWN_ID:
		return Data.HOMETOWN_COUNTRY["cities"][0]
	for c in Data.COUNTRIES:
		for ct in c["cities"]:
			if ct["id"] == id:
				return ct
	return Data.COUNTRIES[0]["cities"][0]


static func country_of(city_id: String) -> String:
	if city_id == Data.HOMETOWN_ID:
		return Data.HOMETOWN_ID
	for c in Data.COUNTRIES:
		for ct in c["cities"]:
			if ct["id"] == city_id:
				return c["id"]
	return "usa"


## Position of a city in world order (0 = Lima ... 24 = Dubai).
static func city_index(city_id: String) -> int:
	var k := 0
	for c in Data.COUNTRIES:
		for ct in c["cities"]:
			if ct["id"] == city_id:
				return k
			k += 1
	return 0


static func city_scale(city_id: String) -> float:
	return pow(Data.CITY_SCALE_GROWTH, city_index(city_id))


## Everything the active city earns is multiplied by this (city size x prestige).
func city_mult() -> float:
	return city_scale(active_city) * pow(Data.PRESTIGE_MULT, prestige) * skill_income_mult(country) * total_boost() \
		* staff_city_mult(active_city)


func city_mult_of(city_id: String) -> float:
	var m := city_scale(city_id) * skill_income_mult(country_of(city_id)) * total_boost() * staff_city_mult(city_id)
	if not cities.has(city_id):
		return m
	return m * pow(Data.PRESTIGE_MULT, int(cities[city_id]["prestige"]))


## Skill tree income bonus for a country's cities (its own branch + "all cities" nodes).
func skill_income_mult(cid: String) -> float:
	return (1.0 + skill("country_income", cid)) * (1.0 + skill("all_income"))


func premises_def(p: int = -1) -> Dictionary:
	if p < 0 and is_hometown():
		return Data.HOMETOWN_STAGES[ht_stage()]
	if p < 0:
		p = prestige
	return Data.PREMISES[clampi(p, 0, Data.PREMISES.size() - 1)]


func city_unlocked(id: String) -> bool:
	return cities.has(id)


func country_unlocked(id: String) -> bool:
	return wallets.has(id)


func unlocked_countries() -> Array:
	return Data.COUNTRIES.filter(func(c): return wallets.has(c["id"])).map(func(c): return c["id"])


## Currency symbol of a country (default: the one you're in).
func sym(country_id: String = "") -> String:
	return country_def(country if country_id == "" else country_id)["symbol"]


## Money text in the right currency, e.g. "$1.23M" or "¥45.0B".
func money(n: float, country_id: String = "") -> String:
	return sym(country_id) + fmt(n)


## Price to unlock this city, or -1 if it isn't the next one available.
func city_unlock_cost(id: String) -> float:
	if city_unlocked(id):
		return -1.0
	var cid := country_of(id)
	if not country_unlocked(cid):
		return -1.0
	var list: Array = country_def(cid)["cities"]
	for k in list.size():
		if not city_unlocked(list[k]["id"]):
			# k = cities already open in this country: the 2nd city costs x GROWTH, the 3rd x GROWTH^2 ...
			if list[k]["id"] != id:
				return -1.0
			return city_list_price(id)
	return -1.0


## A city's unlock price on its own (whether or not it's open yet): override, or the formula
## for its position in the country (2nd city x GROWTH, 3rd x GROWTH^2 ...).
func city_list_price(id: String) -> float:
	if Data.CITY_UNLOCK_OVERRIDE.has(id):
		return float(Data.CITY_UNLOCK_OVERRIDE[id])
	var list: Array = country_def(country_of(id))["cities"]
	var k := 0
	for i in list.size():
		if list[i]["id"] == id:
			k = i
	return Data.CITY_UNLOCK_BASE * city_scale(id) * pow(Data.CITY_UNLOCK_GROWTH, k)


func unlock_city(id: String) -> void:
	var cost := city_unlock_cost(id)
	var cid := country_of(id)
	if cost < 0.0 or wallets.get(cid, 0.0) < cost:
		return
	wallets[cid] -= cost
	cities[id] = _new_city_state()
	_log_milestone("city", "unlocked " + id)
	go_to_city(id)
	start_tutorial()
	save_game()


## Price (in the previous country's currency) to open a new country, or -1.
func country_unlock_cost(id: String) -> float:
	if country_unlocked(id):
		return -1.0
	var k := country_index(id)
	if k <= 0:
		return -1.0
	var prev: Dictionary = Data.COUNTRIES[k - 1]
	if not country_unlocked(prev["id"]) or not city_unlocked(prev["cities"][-1]["id"]):
		return -1.0
	return float(country_def(id)["unlock_cost"])


func previous_country(id: String) -> String:
	return Data.COUNTRIES[maxi(country_index(id) - 1, 0)]["id"]


static func country_index(id: String) -> int:
	for k in Data.COUNTRIES.size():
		if Data.COUNTRIES[k]["id"] == id:
			return k
	return 0


func unlock_country(id: String) -> void:
	var cost := country_unlock_cost(id)
	var prev := previous_country(id)
	if cost < 0.0 or wallets.get(prev, 0.0) < cost:
		return
	wallets[prev] -= cost
	wallets[id] = 0.0
	_log_milestone("country", "unlocked " + id)
	var first: String = country_def(id)["cities"][0]["id"]
	cities[first] = _new_city_state()
	go_to_city(first)
	start_tutorial()
	save_game()


func go_to_city(id: String) -> void:
	if not cities.has(id):
		return
	if id != active_city:
		_store_city()
		_load_city(id)
		collect_city(id)   # v0.19v: arriving collects what it made while you were elsewhere
	if id == Data.HOMETOWN_ID:
		hometown["seen"] = true
	_refresh_bg_rates()
	city_changed.emit()
	state_changed.emit()


## Can this city prestige right now (allowed + affordable)? Drives the shine on the sign, HUD and map.
func prestige_ready(id: String = "") -> bool:
	if id == "":
		id = active_city
	var cost := prestige_cost(id)
	return cost >= 0.0 and prestige_needs(id) == "" and wallets.get(country_of(id), 0.0) >= cost


## Prestige needs your PRESTIGE_NEEDS_CITY-th city (3rd) unlocked in that country.
## Returns the id of the city you still need, or "" when prestige is allowed.
func prestige_needs(id: String) -> String:
	if id == Data.HOMETOWN_ID or Data.PRESTIGE_NEEDS_CITY <= 0:
		return ""
	var list: Array = country_def(country_of(id))["cities"]
	var need: String = list[mini(Data.PRESTIGE_NEEDS_CITY, list.size()) - 1]["id"]
	return "" if city_unlocked(need) else need


func prestige_cost(id: String) -> float:
	if not cities.has(id) or id == Data.HOMETOWN_ID:
		return -1.0
	var p := int(cities[id]["prestige"])
	if p >= Data.MAX_PRESTIGE:
		return -1.0
	if p == 0:
		# v0.17g: the 1st prestige costs the same as opening the next city in this country
		var list: Array = country_def(country_of(id))["cities"]
		for i in list.size() - 1:
			if list[i]["id"] == id:
				return city_list_price(list[i + 1]["id"])
	return float(Data.PRESTIGE_COSTS[p]) * city_scale(id)


## Upgrade a city's premises: a FULL reset of that city. Costs cash, resets its shop
## (bays, levels, renovations), and the cash managers hired there are let go (deleted).
## Multiplies its income by PRESTIGE_MULT forever. Premium managers working there are
## freed. Country cash, other cities, premium managers, gear, uniforms, boosters, Book,
## reputation, skills and Hometown are untouched.
func prestige_city(id: String) -> void:
	var cost := prestige_cost(id)
	var cid := country_of(id)
	if cost < 0.0 or prestige_needs(id) != "" or wallets.get(cid, 0.0) < cost:
		return
	wallets[cid] -= cost
	cities[id] = _new_city_state(int(cities[id]["prestige"]) + 1)
	managers = managers.filter(func(m): return m["home"] != id)
	for m in roster.values():
		if m["city"] == id:
			m["city"] = ""
			m["assigned"] = ""
	_rebuild_assigned()
	gloss += Data.PRESTIGE_GLOSS
	certs += Data.PRESTIGE_CERTS
	if id == active_city:
		_load_city(id)
		start_tutorial()
		city_changed.emit()
	_refresh_bg_rates()
	_log_milestone("prestige", "%s prestige %d" % [id, int(cities[id]["prestige"])])
	prestiged.emit(id)
	_after_purchase()


## Idle $/s of a city (no abilities). Works for the active city or any other.
func city_idle_rate(id: String) -> float:
	if id == active_city:
		return idle_income()
	return _bg_rates.get(id, 0.0)


func _compute_city_idle_rate(id: String) -> float:
	if id == active_city:
		return idle_income()
	var back := active_city
	_store_city()
	_load_city(id)
	_ignore_abilities = true
	var r := idle_income()
	_ignore_abilities = false
	_load_city(back)
	return r


func _refresh_bg_rates() -> void:
	_bg_rates = {}
	for id in cities.keys():
		if id != active_city:
			_bg_rates[id] = _compute_city_idle_rate(id) * (1.0 + skill("bg_income"))


## The unlocked city earning the most per second in a country (rates are in
## local currency, so cities are only compared within their own country).
func best_city(cid: String = "") -> String:
	if cid == "":
		cid = country
	var best := ""
	var best_r := 0.0
	for id in cities.keys():
		if country_of(id) != cid:
			continue
		var r := city_idle_rate(id)
		if r > best_r:
			best_r = r
			best = id
	return best


## The one-time MAP nudge (v0.17d): the next city in this country is affordable and costs less
## than the next bay here. Fires once per city, ever: returns that city's id the first time, else "".
func check_city_nudge() -> String:
	if is_hometown() or tutorial_step != TUT_DONE:
		return ""
	var nxt := ""
	for c in country_def(country)["cities"]:
		if not city_unlocked(c["id"]):
			nxt = c["id"]
			break
	if nxt == "" or city_nudges.has(nxt):
		return ""
	var cost := city_unlock_cost(nxt)
	var bay := next_bay_cost()
	if cost < 0.0 or wallets.get(country, 0.0) < cost or (bay >= 0.0 and bay <= cost):
		return ""
	city_nudges[nxt] = "shown"
	return nxt


func city_nudge_pending() -> bool:
	return city_nudges.values().has("shown")


func mark_city_nudges_seen() -> void:
	for k in city_nudges.keys():
		city_nudges[k] = "seen"


func country_income(cid: String) -> float:
	var t := 0.0
	for id in cities.keys():
		if country_of(id) == cid:
			t += city_idle_rate(id)
	return t


# ================================================================ game loop

func _process(delta: float) -> void:
	if sim_mode:
		return   # dev economy sim (tools/econ_sim.gd) drives the clock and the economy itself
	now = Time.get_unix_time_from_system()
	play_time += delta
	for i in bays.size():
		_advance_bay(i, delta)
	_advance_valet(delta)
	_advance_desk(delta)
	_advance_vip(delta)
	_tick_tip_jars()
	# every other city earns its idle rate in the background (v0.19v: into its stash, for COLLECT)
	for id in _bg_rates.keys():
		var amt: float = _bg_rates[id] * delta
		if amt > 0.0:
			stash[id] = float(stash.get(id, 0.0)) + amt
			lifetime_earned += amt
	_bg_timer += delta
	if _bg_timer >= BG_RATE_INTERVAL:
		_bg_timer = 0.0
		_expire_boosters()
		_refresh_bg_rates()
		if _legend_here("autopilot"):
			activate_all_ready()
	_reno_tick()
	if tutorial_step != TUT_DONE:
		_update_tutorial()
	var fph := display_followers_per_hour() + decor_followers_per_hour()
	if fph > 0.0:
		add_followers(fph / 3600.0 * delta)
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		save_game()


func _advance_bay(i: int, delta: float) -> void:
	var bay: Dictionary = bays[i]
	if vip_in_bay(i):
		return  # the VIP gets the bay to itself
	var auto := is_automated("bay%d" % i)
	if not bay["running"]:
		if not auto:
			return
		bay["running"] = true
		bay["progress"] = 0.0
	bay["progress"] += delta / bay_cycle_time(i)
	while bay["progress"] >= 1.0:
		var amount := bay_pay_per_car(i)
		var sm := manager_at("bay%d" % i)
		if not sm.is_empty() and str(sm.get("ability", "")) == "showstopper" and ability_active(sm) and bool(sm.get("show_next", false)):
			# v0.19r Tash: this one's a show car
			var smult := roundf(lerpf(Data.SHOW_CAR_MULT[0], Data.SHOW_CAR_MULT[1], _lvk(sm)))
			var sf := lerpf(Data.SHOW_CAR_FOLLOWERS[0], Data.SHOW_CAR_FOLLOWERS[1], _lvk(sm))
			amount *= smult
			sm["show_next"] = false
			_end_signature(sm)
			add_followers(sf)
			signature_popped.emit("bay%d" % i, "SHOW CAR! +%s x%d  +%d followers" % [money(amount), int(smult), int(round(sf))])
		if bay["car"] == car_of_week():   # v0.19t: Car of the Week pays x3 + a few followers
			amount *= Data.COTW_PAY_MULT
			add_followers(Data.COTW_FOLLOWERS)
		var fm := flash_polish_at(i)
		if not fm.is_empty():   # v0.19t Yuki: count the car, pop the total after the last one
			fm["flash_left"] = int(fm["flash_left"]) - 1
			fm["flash_paid"] = float(fm.get("flash_paid", 0.0)) + amount
			if int(fm["flash_left"]) <= 0:
				_end_signature(fm)
				signature_popped.emit("bay%d" % i, "FLASH POLISH!  +%s" % money(float(fm["flash_paid"])))
		var jar := _jar_manager(i)
		if jar.is_empty() and shortcut_active():
			desk["lot"] += amount   # v0.19o Kev's Shortcut: straight to the pickup lot
			shortcut_moved += amount
		elif jar.is_empty():
			bay["ready"] += amount
		else:
			jar["jar"] = float(jar.get("jar", 0.0)) + amount   # into Dazza's tip jar
			jar["jar_country"] = country
		log_car(bay["car"])
		bay["car"] = _pick_car(i)
		job_completed.emit(i, amount)
		if auto:
			bay["progress"] -= 1.0
		else:
			bay["progress"] = 0.0
			bay["running"] = false
			break


func _advance_valet(delta: float) -> void:
	var v := valet
	var spd := valet_load_speed()
	var floors_per_sec := valet_speed() / Data.VALET_FLOOR_TIME
	match v["phase"]:
		"idle":
			# with a manager it runs non-stop; a tap sends it once. Nothing ready = it drives
			# to the last bay and comes back empty-handed.
			if v["requested"] or is_automated("valet"):
				var tm := manager_at("valet")
				if not tm.is_empty() and str(tm.get("ability", "")) == "tow_truck" and ability_active(tm) and bool(tm.get("tow_wait", false)):
					tm["tow_wait"] = false
					v["tow"] = true   # v0.19r Mick: this trip has no carry limit
				var first := _next_ready_floor(0)
				v["requested"] = false
				v["stop"] = first if first > 0 else bays.size()
				v["phase"] = "down"
		"down":
			v["pos"] += floors_per_sec * delta
			if v["pos"] >= v["stop"]:
				v["pos"] = float(v["stop"])
				v["phase"] = "load"
				v["timer"] = Data.VALET_LOAD_TIME / spd
		"load":
			v["timer"] -= delta
			if v["timer"] <= 0.0:
				var bay: Dictionary = bays[v["stop"] - 1]
				var cap := INF if bool(v.get("tow", false)) else valet_capacity()
				var take: float = minf(bay["ready"], cap - v["carried"])
				bay["ready"] -= take
				v["carried"] += take
				var nxt := _next_ready_floor(v["stop"])
				if v["carried"] >= cap * 0.999 or nxt < 0:
					v["phase"] = "up"
				else:
					v["stop"] = nxt
					v["phase"] = "down"
		"up":
			v["pos"] -= floors_per_sec * delta
			if v["pos"] <= 0.0:
				v["pos"] = 0.0
				v["phase"] = "unload"
				v["timer"] = Data.VALET_UNLOAD_TIME / spd
		"unload":
			v["timer"] -= delta
			if v["timer"] <= 0.0:
				desk["lot"] += v["carried"]
				valet_unloaded.emit(v["carried"])
				if bool(v.get("tow", false)):
					v["tow"] = false
					var tm := manager_at("valet")
					if not tm.is_empty() and str(tm.get("ability", "")) == "tow_truck":
						_end_signature(tm)
					signature_popped.emit("valet", "TOW TRUCK! +%s in one trip" % money(v["carried"]))
				v["carried"] = 0.0
				v["phase"] = "idle"
				var cv := convoy()
				if not cv.is_empty():
					cv["convoy_left"] = int(cv["convoy_left"]) - 1
					if int(cv["convoy_left"]) <= 0:
						cv["active_until"] = now
						cv["ready_at"] = now + ability_cooldown(cv)


## First floor below `after` (floors are bay index + 1) that has finished cars, or -1.
func _next_ready_floor(after: int) -> int:
	for i in range(after, bays.size()):
		if bays[i]["ready"] > 0.0:
			return i + 1
	return -1


func _advance_desk(delta: float) -> void:
	var d := desk
	if not d["running"]:
		# with a manager it counts non-stop; a tap starts one count. An empty lot = $0.
		if not (d["requested"] or is_automated("desk")):
			return
		d["requested"] = false
		d["running"] = true
		d["progress"] = 0.0
		d["batch"] = minf(d["lot"], desk_capacity())
		d["lot"] -= d["batch"]
	d["progress"] += delta / desk_cycle_time()
	if d["progress"] >= 1.0:
		if d["batch"] > 0.0:
			_earn(d["batch"])
			var lm := manager_at("desk")
			if not lm.is_empty() and str(lm.get("ability", "")) == "loyalty_card" and ability_active(lm):
				add_followers(lerpf(Data.LOYALTY_FOLLOWERS[0], Data.LOYALTY_FOLLOWERS[1], _lvk(lm)))   # v0.19r Bec
			_tut_paid = true
		cash_earned.emit(d["batch"])
		d["batch"] = 0.0
		d["running"] = false
		d["progress"] = 0.0


func _earn(amount: float) -> void:
	cash += amount
	lifetime_earned += amount


# ================================================================ player taps
# Tapping only STARTS work (before a station has a manager). Jobs always take the
# same time; to go faster you level up and use manager boosts.

func tap_bay(i: int) -> void:
	if vip_in_bay(i):
		vip["running"] = true
		return
	var bay: Dictionary = bays[i]
	if not bay["running"]:
		bay["running"] = true
		bay["progress"] = 0.0


func tap_valet() -> void:
	# one run per tap: taps while the valet is already out are ignored
	if valet["phase"] == "idle":
		valet["requested"] = true


func tap_desk() -> void:
	if not desk["running"]:
		desk["requested"] = true


# ================================================================ station helpers

static func area_of(key: String) -> String:
	return "bay" if key.begins_with("bay") else key


static func bay_index(key: String) -> int:
	return int(key.substr(3))


func station_name(key: String) -> String:
	match area_of(key):
		"bay":
			return "Bay %d" % (bay_index(key) + 1)
		"valet":
			return "Valet"
	return "Front Desk"


func level_of(key: String) -> int:
	match area_of(key):
		"bay":
			return bays[bay_index(key)]["level"]
		"valet":
			return valet["level"]
	return desk["level"]


func boosts_of(key: String) -> Array:
	match area_of(key):
		"bay":
			return Data.BAY_BOOSTS
		"valet":
			return Data.VALET_BOOSTS
	return Data.DESK_BOOSTS


## Product of every boost reached at `level`.
func boost_mult(key: String, level: int) -> float:
	var m := 1.0
	for b in boosts_of(key):
		if level >= int(b["level"]):
			m *= float(b["mult"])
	return m


## The highest boost reached (its name is the station's current service/tool).
func current_boost(key: String, level: int = -1) -> Dictionary:
	if level < 0:
		level = level_of(key)
	var cur: Dictionary = boosts_of(key)[0]
	for b in boosts_of(key):
		if level >= int(b["level"]):
			cur = b
	return cur


## Premium currency for reaching this boost: 5 for the first, 3 for the second, then 1.
func boost_gloss(key: String, boost: Dictionary) -> int:
	var idx := boosts_of(key).find(boost)   # 0 is the starting level, so the first boost is 1
	if idx <= 0:
		return 0
	return Data.BOOST_GLOSS[idx - 1] if idx - 1 < Data.BOOST_GLOSS.size() else Data.BOOST_GLOSS_REST


func next_boost(key: String) -> Dictionary:
	var lvl := level_of(key)
	for b in boosts_of(key):
		if int(b["level"]) > lvl:
			return b
	return {}


# ---------------------------------------------------------------- level costs

func _cost_params(key: String) -> Array:
	match area_of(key):
		"bay":
			var i := bay_index(key)
			if is_hometown():
				return [Data.BAY_LEVEL_COST * Data.HOMETOWN_COST_MULT * pow(Data.HOMETOWN_GROWTH, i) * tier_cost_mult(i), Data.BAY_LEVEL_GROWTH]
			return [Data.BAY_LEVEL_COST * pow(Data.BAY_LEVEL_COST_GROWTH, i) * city_scale(active_city) * tier_cost_mult(i), Data.BAY_LEVEL_GROWTH]
		"valet":
			if is_hometown():
				return [Data.VALET_LEVEL_COST * Data.HOMETOWN_VD_COST_MULT, Data.HOMETOWN_VD_LEVEL_GROWTH]
			return [Data.VALET_LEVEL_COST * city_scale(active_city), Data.VALET_LEVEL_GROWTH]
	if is_hometown():
		return [Data.DESK_LEVEL_COST * Data.HOMETOWN_VD_COST_MULT, Data.HOMETOWN_VD_LEVEL_GROWTH]
	return [Data.DESK_LEVEL_COST * city_scale(active_city), Data.DESK_LEVEL_GROWTH]


## Cost to buy `n` levels on top of the current level (discount abilities applied).
func levels_cost(key: String, n: int) -> float:
	if n <= 0:
		return 0.0
	# v0.19r Jono's Mate's Rates: his bay's next levels are free
	var skip := mini(free_levels(key), n)
	n -= skip
	if n <= 0:
		return 0.0
	var lvl := level_of(key) + skip
	var p := _cost_params(key)
	var base: float = p[0]
	var g: float = p[1]
	var first := base * pow(g, lvl - 1)
	var disc := maxf(Data.DISCOUNT_FLOOR, (1.0 - ability_discount(key)) * level_cost_mult() * (1.0 - gear_at(key, "discount")))
	var fl := finish_line()
	if fl.is_empty():
		return first * (pow(g, n) - 1.0) / (g - 1.0) * disc
	# v0.19o Priya's Finish Line: the levels just before a boost are cheaper (sum level by level)
	var marks: Array = boosts_of(key).map(func(b): return int(b["level"]))
	var total := 0.0
	var c := first
	for k in n:
		var t := lvl + k + 1
		var m := 1.0
		for bl in marks:
			if t <= bl and t > bl - int(fl["levels"]):
				m = maxf(Data.DISCOUNT_FLOOR / maxf(disc, 0.0001), 1.0 - float(fl["off"]))
				break
		total += c * m
		c *= g
	return total * disc


## How many levels a buy-mode button buys. mode: 1, 10, 50, "next" or "max".
func levels_for_mode(key: String, mode: Variant) -> int:
	var lvl := level_of(key)
	var room := station_max_level(key) - lvl
	if room <= 0:
		return 0
	if mode is int:
		return mini(mode, room)
	if mode == "next":
		var nb := next_boost(key)
		return room if nb.is_empty() else int(nb["level"]) - lvl
	# "max": as many as we can afford, but always at least 1 so a price shows
	if not finish_line().is_empty() or free_levels(key) > 0:
		var k := 1
		while k < room and levels_cost(key, k + 1) <= cash:
			k += 1
		return k
	var p := _cost_params(key)
	var first: float = p[0] * pow(p[1], lvl - 1) * (1.0 - ability_discount(key)) * level_cost_mult()
	var n := int(floor(log(cash * (p[1] - 1.0) / first + 1.0) / log(p[1])))
	return clampi(n, 1, room)


func buy_levels(key: String, n: int) -> void:
	n = mini(n, station_max_level(key) - level_of(key))
	if n <= 0:
		return
	var cost := levels_cost(key, n)
	if cash < cost:
		return
	cash -= cost
	var free := free_levels(key)
	if free > 0:
		var mm := manager_at(key)
		mm["free_levels"] = free - mini(free, n)
		if int(mm["free_levels"]) <= 0:
			_end_signature(mm)
	var before := level_of(key)
	match area_of(key):
		"bay":
			var bi := bay_index(key)
			var t0 := bay_cycle_time(bi)
			bays[bi]["level"] += n
			# v0.18: crossing Lv 100 makes cars longer; keep the seconds already worked on this car so the
			# bigger Lv 100 payout isn't handed out for the old, shorter time
			var t1 := bay_cycle_time(bi)
			if absf(t1 - t0) > 0.0001:
				bays[bi]["progress"] = float(bays[bi]["progress"]) * t0 / t1
		"valet":
			valet["level"] += n
		_:
			desk["level"] += n
	var reached := []
	for b in boosts_of(key):
		if int(b["level"]) > before and int(b["level"]) <= before + n:
			reached.append(b)
			gloss += boost_gloss(key, b)
	leveled.emit(key, n, reached)
	_after_purchase()


# ---------------------------------------------------------------- station stats

## v0.18: seconds per car before speed boosts. From Paint Correction (Lv PC_LEVEL) never under
## PC_MIN_CAR_TIME, so the whole foam / hand wash / polish routine has time to play out. _bay_base_pay uses the
## same time, so a longer car pays more and income per second doesn't change.
func bay_base_time(i: int, level: int = -1) -> float:
	if level < 0:
		level = int(bays[i]["level"]) if i < bays.size() else 1
	var t := Data.BAY_BASE_TIME + Data.BAY_TIME_STEP * i
	if level >= Data.PC_LEVEL:
		t = maxf(t, Data.PC_MIN_CAR_TIME)
	return t


func bay_cycle_time(i: int, level: int = -1) -> float:
	var t := bay_base_time(i, level) / ability_mult("bay%d" % i, "speed") / (1.0 + skill("bay_speed")) \
		/ (1.0 + gear_at("bay%d" % i, "speed"))
	if i < bays.size() and not flash_polish_at(i).is_empty():
		t = minf(t, Data.FLASH_POLISH_TIME)   # v0.19t Yuki's Flash Polish
	return t


## $ per car before the car-specific crew specialist bonus.
## Speed abilities make cars faster, not bigger, so they're not in here.
func _bay_base_pay(i: int, level: int) -> float:
	var key := "bay%d" % i
	if level < 0:
		level = level_of(key)
	var time_level := level
	var tb := training_bonus()
	if tb > 0:   # v0.19t Lukas's Training Day: works like it's tb levels higher (services included)
		level = mini(level + tb, station_max_level(key))
	var ips := Data.BAY_BASE_IPS * pow(Data.HOMETOWN_GROWTH if is_hometown() else Data.BAY_IPS_GROWTH, i) * tier_income_mult(i) * level * boost_mult(key, level)
	ips *= bay_crew_bonus(i) * ability_mult(key, "income") * foam_cannon_mult(i) * weather_mult() * reputation_mult() * book_set_mult() * city_mult() \
		* (1.0 + manager_passive(key)) * (1.0 + gear_at(key, "income")) * wardrobe_mult("bay")
	return ips * bay_base_time(i, time_level)


## $ for one car (defaults to the car in the bay now).
func bay_pay_per_car(i: int, level: int = -1, car_id: String = "") -> float:
	if car_id == "":
		car_id = bays[i]["car"]
	return _bay_base_pay(i, level) * specialist_mult(i, car_id)


## v0.18: what rare-car payouts are based on: one car's pay at the bay's ORIGINAL car time (so the longer
## Lv 100+ cars don't quietly multiply rare-car pay; rare cars always take VIP_JOB_TIME).
func vip_base_pay(i: int, car_id: String) -> float:
	return bay_pay_per_car(i, -1, car_id) * (Data.BAY_BASE_TIME + Data.BAY_TIME_STEP * i) / bay_base_time(i)


## Average $/sec, counting how often the manager gets cars of their speciality.
func bay_income(i: int, level: int = -1) -> float:
	var spec := 1.0
	var m := manager_at("bay%d" % i)
	if not m.is_empty():
		for cl in crews_of(m):
			spec += (specialist_bonus(cl) - 1.0) * (1.0 + gear_value(m, "crew")) * class_share(cl)
	return _bay_base_pay(i, level) * spec / bay_cycle_time(i, level)


func valet_capacity(level: int = -1) -> float:
	if level < 0:
		level = valet["level"]
	return Data.VALET_BASE_CAP * level * pow(Data.VALET_CAP_GROWTH, level - 1) * city_mult() * valet_cap_comp(level) \
		* (Data.CONVOY_MULT if not convoy().is_empty() and not _ignore_abilities else 1.0) \
		* boost_mult("valet", level) * pair_crew_bonus() * ability_mult("valet", "income") * (1.0 + manager_passive("valet")) \
		* (1.0 + gear_at("valet", "income")) * wardrobe_mult("valet")


## The old +2%/level speed curve (v0.17g: loading follows it every level; driving only at boost levels).
static func valet_curve(level: int) -> float:
	return 1.0 + Data.VALET_SPEED_PER_LEVEL * (level - 1)


## Level of the last valet boost reached (driving speed steps up there).
static func valet_step_level(level: int) -> int:
	var lb := 1
	for b in Data.VALET_BOOSTS:
		if level >= int(b["level"]):
			lb = int(b["level"])
	return lb


## Extra capacity that keeps the money the same with the calmer, stepped driving (see VALET_CAP_COMP).
static func valet_cap_comp(level: int) -> float:
	return Data.VALET_CAP_COMP * valet_curve(level) / valet_curve(valet_step_level(level))


func _valet_speed_mults() -> float:
	return ability_mult("valet", "speed") * (1.0 + skill("valet_speed")) * (1.0 + gear_at("valet", "speed"))


## Driving speed multiplier (v0.17g): steps up at the valet's boost levels, plus abilities / skills / gear.
func valet_speed(level: int = -1) -> float:
	if level < 0:
		level = valet["level"]
	return valet_curve(valet_step_level(level)) * _valet_speed_mults()


## Loading / unloading speed (v0.17g): +2% every level, plus abilities / skills / gear.
func valet_load_speed(level: int = -1) -> float:
	if level < 0:
		level = valet["level"]
	return valet_curve(level) * _valet_speed_mults()


## Average $/sec the valet can move, for a full round trip to the deepest bay.
func valet_rate(level: int = -1) -> float:
	var floors := bays.size()
	var trip := 2.0 * floors * Data.VALET_FLOOR_TIME / valet_speed(level) \
		+ (floors * Data.VALET_LOAD_TIME + Data.VALET_UNLOAD_TIME) / valet_load_speed(level)
	return valet_capacity(level) / trip


func desk_capacity(level: int = -1) -> float:
	if level < 0:
		level = desk["level"]
	return Data.DESK_BASE_CAP * level * pow(Data.DESK_CAP_GROWTH, level - 1) * city_mult() \
		* boost_mult("desk", level) * pair_crew_bonus() * ability_mult("desk", "income") * (1.0 + manager_passive("desk")) \
		* (1.0 + gear_at("desk", "income")) * wardrobe_mult("desk")


func desk_cycle_time() -> float:
	return Data.DESK_CYCLE_TIME / ability_mult("desk", "speed") / (1.0 + skill("desk_speed")) / (1.0 + gear_at("desk", "speed"))


func desk_rate(level: int = -1) -> float:
	return desk_capacity(level) / desk_cycle_time()


func bays_total_income(automated_only: bool = false) -> float:
	var total := 0.0
	for i in bays.size():
		if automated_only and not is_automated("bay%d" % i):
			continue
		total += bay_income(i)
	return total


## The headline number for a station's level panel: what it does per second.
func station_rate(key: String, level: int = -1) -> float:
	match area_of(key):
		"bay":
			return bay_income(bay_index(key), level)
		"valet":
			return valet_rate(level)
	return desk_rate(level)


## Income while you're away (or not looking at this city): the chain only runs where there are managers,
## and it only goes as fast as its slowest station.
## v0.19m: "in ~2m 30s" until `cost` is affordable at the current idle income ("" when you can already
## afford it, nothing runs by itself yet, or it's more than a day away).
func eta_text(cost: float) -> String:
	if cost <= cash:
		return ""
	var r := idle_income()
	if r <= 0.0:
		return ""
	var secs := (cost - cash) / r
	if secs > 86400.0:
		return ""
	return "in ~" + fmt_time(maxf(secs, 1.0))


func idle_income() -> float:
	var r := bays_total_income(true)
	r = minf(r, valet_rate() if is_automated("valet") else 0.0)
	r = minf(r, desk_rate() if is_automated("desk") else 0.0)
	return r


## "bays", "valet" or "desk": whichever limits income right now.
func bottleneck() -> String:
	var b := bays_total_income()
	var v := valet_rate()
	var d := desk_rate()
	if v <= b and v <= d:
		return "valet"
	if d <= b and d <= v:
		return "desk"
	return "bays"


# ---------------------------------------------------------------- bays

## Renovation tier of a bay: 0 before the 1st renovation, 1 after it (bays 6-10 in
## cities), 2 (11-15), 3 (16-20). Hometown: by the run's renovation points.
func bay_reno_tier(i: int, id: String = "") -> int:
	var t := 0
	for b in reno_bays(id):
		if i + 1 >= int(b):
			t += 1
	return t


## Bays after each renovation earn more per level ...
func tier_income_mult(i: int) -> float:
	var t := bay_reno_tier(i)
	return pow(Data.HOMETOWN_TIER_INCOME if is_hometown() else Data.RENO_TIER_INCOME, t)


## ... but their levels cost even more, so their first levels are a worse deal than
## the older bays until they reach their 1st-2nd boost.
func tier_cost_mult(i: int) -> float:
	var t := bay_reno_tier(i)
	return pow(Data.HOMETOWN_TIER_COST if is_hometown() else Data.RENO_TIER_COST, t)


func next_bay_cost() -> float:
	if is_hometown():
		if bays.size() >= ht_cap() or ht_reno_needed() > 0:
			return -1.0
		return ht_build_cost(bays.size())
	if bays.size() >= Data.MAX_BAYS or reno_needed() > 0:
		return -1.0
	return Data.BAY_BUILD_COSTS[bays.size()] * city_scale(active_city)


func buy_bay() -> void:
	var cost := next_bay_cost()
	if cost < 0.0 or cash < cost:
		return
	cash -= cost
	bays.append(_new_bay())
	bays[-1]["car"] = _pick_car(bays.size() - 1)
	_log_milestone("bay", "%s bay %d" % [active_city, bays.size()])
	_check_hometown_unlock()
	if is_hometown():
		hometown_changed.emit()
	_after_purchase()



## What the shop earns per second while you play (the slowest of bays / valet / desk).
func play_income() -> float:
	return minf(bays_total_income(), minf(valet_rate(), desk_rate()))


## v0.19i (Hamza): Shine Bucks price of the next bay when you can't afford it with cash, from how long your
## income would take to earn the missing cash. -1 = no bay to buy (all built, or a renovation first).
func bay_gloss_cost() -> int:
	var cost := next_bay_cost()
	if cost < 0.0 or reno_needed() > 0:
		return -1
	var short := maxf(0.0, cost - cash)
	var inc := play_income()
	var minutes := 1e9 if inc <= 0.0 else short / inc / 60.0
	return clampi(Data.BAY_GLOSS_MIN + int(minf(minutes, 1e6) / Data.BAY_GLOSS_MINUTES), Data.BAY_GLOSS_MIN, Data.BAY_GLOSS_MAX)


func buy_bay_gloss() -> bool:
	var g := bay_gloss_cost()
	if g < 0 or gloss < g:
		return false
	gloss -= g
	bays.append(_new_bay())
	bays[-1]["car"] = _pick_car(bays.size() - 1)
	_log_milestone("bay", "%s bay %d (shine bucks)" % [active_city, bays.size()])
	_check_hometown_unlock()
	if is_hometown():
		hometown_changed.emit()
	_after_purchase()
	return true

# ================================================================ cars + customer mix

func car_def(id: String) -> Dictionary:
	return cars_by_id.get(id, Data.CARS[0])


func bay_tier(i: int) -> int:
	var tiers: Array = premises_def()["tiers"]
	return tiers[clampi(i, 0, tiers.size() - 1)]


## Weight of each car class among customers: base 1 each, + the country's taste
## (USA likes muscle, Japan JDM...), +1 per displayed car of that class.
func class_weights() -> Dictionary:
	var w := {}
	var bias: Dictionary = country_def(country)["bias"]
	for c in Data.CAR_CLASSES:
		w[c] = 1.0 + float(bias.get(c, 0.0))
	for id in display:
		var cl: String = car_def(id)["class"]
		w[cl] = w.get(cl, 0.0) + 1.0
	return w


func class_share(cl: String) -> float:
	var w := class_weights()
	var total := 0.0
	for v in w.values():
		total += v
	return w.get(cl, 0.0) / total


func _pick_car(i: int) -> String:
	var w := class_weights()
	var total := 0.0
	for v in w.values():
		total += v
	var roll := randf() * total
	var cl: String = Data.CAR_CLASSES[0]
	for c in Data.CAR_CLASSES:
		roll -= w[c]
		if roll <= 0.0:
			cl = c
			break
	var tier := bay_tier(i)
	var pool := Data.CARS.filter(func(c): return c["tier"] == tier and c["class"] == cl)
	if pool.is_empty():
		pool = Data.CARS.filter(func(c): return c["tier"] == tier)
	return pool.pick_random()["id"]


## Bay manager specialises in this car's class.
func specialist_mult(i: int, car_id: String) -> float:
	var m := manager_at("bay%d" % i)
	if m.is_empty() or car_id == "":
		return 1.0
	var cl: String = car_def(car_id)["class"]
	if not crews_of(m).has(cl):
		return 1.0
	return 1.0 + (specialist_bonus(cl) - 1.0) * (1.0 + gear_value(m, "crew"))


## x1.5 by default; skill tree nodes raise it per car class.
func specialist_bonus(cl: String) -> float:
	return Data.CREW_SPECIALIST_BONUS + skill("specialist", cl)


# ================================================================ the Book

func log_car(id: String) -> void:
	if id == "" or not cars_by_id.has(id):
		return
	var first := not book.has(id)
	book[id] = int(book.get(id, 0)) + 1
	if not first:
		return
	book_new[id] = true
	book_unseen = true
	var car := car_def(id)
	if not car.get("vip", false):
		add_followers(Data.NEW_CAR_FOLLOWERS * float(car["tier"]))
	car_logged.emit(car)
	_check_tier_sets()


func _check_tier_sets() -> void:
	if not book_opened:
		return   # v0.19k: the Bombs set used to pop at 2-4 min, before the player knew what the Book was
	for t in range(1, Data.TIER_NAMES.size()):
		if tiers_done.has(t):
			continue
		var all := true
		for c in Data.CARS:
			if c["tier"] == t and not book.has(c["id"]):
				all = false
				break
		if all:
			tiers_done.append(t)
			gloss += Data.TIER_SET_GLOSS
			tier_set_completed.emit(t)


## v0.19k: the first time the Book is opened, sets the player has already collected complete now
## (main calls this a moment after the Book tip shows, so SET COMPLETE comes right after its GOT IT).
func open_book_first() -> void:
	if book_opened:
		return
	book_opened = true
	_check_tier_sets()
	save_game()


## v0.17g: opening the Book no longer clears everything; cars count as seen once their category has
## been on screen (mark_cars_seen). Kept for old callers: just refreshes the flag.
func mark_book_seen() -> void:
	book_unseen = not book_new.is_empty()


## These cars have been looked at in their Book category: no more NEW sticker.
func mark_cars_seen(ids: Array) -> void:
	var changed := false
	for id in ids:
		if book_new.has(id):
			book_new.erase(id)
			changed = true
	if changed:
		book_unseen = not book_new.is_empty()
		save_game()


## A rare car that hasn't been looked at yet (BOOK gets a gold badge instead of the red "!").
func book_new_rare() -> bool:
	for id in book_new.keys():
		if car_def(id).get("vip", false):
			return true
	return false


## New (unseen) cars in a Book category: tier 1-5, or 6 = rare visitors (optionally one country).
func book_new_count(tier: int, cid: String = "") -> int:
	var n := 0
	for id in book_new.keys():
		var c := car_def(id)
		if tier == 6:
			if c.get("vip", false) and (cid == "" or c.get("country", "usa") == cid):
				n += 1
		elif not c.get("vip", false) and int(c["tier"]) == tier:
			n += 1
	return n


func book_count(tier: int, cid: String = "") -> Array:
	var have := 0
	var total := 0
	var list: Array = Data.VIP_CARS if tier == 6 else Data.CARS.filter(func(c): return c["tier"] == tier)
	if tier == 6 and cid != "":
		list = list.filter(func(c): return c.get("country", "usa") == cid)
	for c in list:
		total += 1
		if book.has(c["id"]):
			have += 1
	return [have, total]


func book_set_mult() -> float:
	return pow(Data.TIER_SET_INCOME_BONUS, tiers_done.size())


func display_slots() -> int:
	var n := Data.BASE_DISPLAY_SLOTS + bought_slots + int(skill("display_slot"))
	for s in Data.DISPLAY_SLOT_STARS:
		if stars() >= s:
			n += 1
	return n


func toggle_display(id: String) -> void:
	if display.has(id):
		display.erase(id)
	elif book.has(id) and display.size() < display_slots():
		display.append(id)
	else:
		return
	_after_purchase()


func display_followers_per_hour() -> float:
	var f := 0.0
	for id in display:
		var c := car_def(id)
		if c.get("vip", false):
			f += Data.VIP_DISPLAY_FPH[int(c["rarity"])]
		else:
			f += Data.DISPLAY_FPH[int(c["tier"])]
	return f


# ================================================================ reputation

func stars() -> int:
	var s := 0
	for t in Data.STAR_THRESHOLDS:
		if followers >= t:
			s += 1
	return s


## v0.17h-3 (Hamza: "too many stars"): reputation is shown as a review rating, like a shop's Google rating.
## v0.19l: step 1 = "No reviews yet" (rating 0), then 1.0, 1.5 ... 5.0 ("4.5").
func rating(s: int = -1) -> float:
	if s < 0:
		s = stars()
	return 0.0 if s <= 1 else 1.0 + 0.5 * float(s - 2)


func has_reviews(s: int = -1) -> bool:
	return (stars() if s < 0 else s) >= 2


## "4.5" (or "NEW" before the first review)
func rating_text(s: int = -1) -> String:
	return "%.1f" % rating(s) if has_reviews(s) else "NEW"


## "Rated 4.5 stars" / "No reviews yet"
func rating_line(s: int = -1) -> String:
	return "Rated %s stars" % rating_text(s) if has_reviews(s) else "No reviews yet"


func next_star_followers() -> float:
	var s := stars()
	return -1.0 if s >= Data.STAR_THRESHOLDS.size() else Data.STAR_THRESHOLDS[s]


func reputation_mult() -> float:
	return pow(Data.STAR_INCOME_BONUS, stars() - 1)


func add_followers(n: float) -> void:
	var before := stars()
	followers += n * (1.0 + skill("followers")) if n > 0.0 else n
	var after := stars()
	if after > before:
		gloss += Data.STAR_GLOSS * (after - before)
		boosters[Data.STAR_BOOSTER] = int(boosters.get(Data.STAR_BOOSTER, 0)) + (after - before)
		certs += Data.STAR_CERTS * (after - before)
		_log_milestone("star", "%d stars" % after)
		star_up.emit(after)


# ================================================================ VIP visits

func vip_in_bay(i: int) -> bool:
	return not vip.is_empty() and vip["phase"] == "bay" and int(vip["bay"]) == i


func _advance_vip(delta: float) -> void:
	if vip.is_empty():
		# no rare cars at all until the first one, guaranteed when you build Bay 3
		if not first_vip_done:
			if bays.size() >= Data.FIRST_VIP_BAYS:
				_first_vip_timer += delta
				if _first_vip_timer >= Data.FIRST_VIP_DELAY:
					spawn_vip(true, 0)
			return
		# then a random chance: low at first, rising with stars
		if bays.size() >= 2:
			var rate := (1.0 + Data.STAR_VIP_BONUS * (stars() - 1)) * (1.0 + skill("vip_rate")) / Data.VIP_MEAN_INTERVAL
			if _legend_anywhere("vip_magnet"):
				rate *= float(Data.LEGEND_PASSIVES["vip_magnet"]["value"])
			rate *= 1.0 + gear_global("vip_rate")
			if randf() < rate * delta:
				spawn_vip()
		return
	if vip["phase"] == "lot":
		vip["timer"] -= delta
		if vip["timer"] <= 0.0:
			send_vip()
		return
	var i := int(vip["bay"])
	if not vip["running"]:
		if not is_automated("bay%d" % i):
			return
		vip["running"] = true
	vip["progress"] += delta * ability_mult("bay%d" % i, "speed") / Data.VIP_JOB_TIME
	if vip["progress"] >= 1.0:
		_finish_vip()


## Rare cars that can visit a country (Hometown: every unlocked country's).
func vip_pool(cid: String = "") -> Array:
	if cid == "":
		cid = country
	if cid == Data.HOMETOWN_ID:
		var owned := unlocked_countries()
		return Data.VIP_CARS.filter(func(c): return owned.has(c.get("country", "usa")))
	return Data.VIP_CARS.filter(func(c): return c.get("country", "usa") == cid)


## force_rarity >= 0: that rarity only (the guaranteed first visit is a plain Rare).
func spawn_vip(alert_allowed: bool = true, force_rarity: int = -1) -> void:
	if not vip.is_empty():
		return
	var pool := vip_pool()
	if force_rarity >= 0 and pool.any(func(x): return int(x["rarity"]) == force_rarity):
		pool = pool.filter(func(x): return int(x["rarity"]) == force_rarity)
	if pool.is_empty():
		pool = Data.VIP_CARS
	var weights := []
	var total := 0.0
	for c in pool:
		var r: Dictionary = Data.VIP_RARITIES[int(c["rarity"])]
		var same := pool.filter(func(x): return x["rarity"] == c["rarity"]).size()
		var w: float = float(r["odds"]) / same * (Data.VIP_DISPLAY_WEIGHT if display.has(c["id"]) else 1.0)
		weights.append(w)
		total += w
	var roll := randf() * total
	var pick: Dictionary = pool[0]
	for k in pool.size():
		roll -= weights[k]
		if roll <= 0.0:
			pick = pool[k]
			break
	first_vip_done = true
	vip = {"id": pick["id"], "phase": "lot", "timer": Data.VIP_LOT_WAIT,
		"bay": randi() % bays.size(), "progress": 0.0, "running": false}
	# Big banner only for cars you haven't got in your Book yet (and only if enabled)
	var alert: bool = alert_allowed and settings.get("rare_alerts", true) and not book.has(pick["id"])
	vip_arrived.emit(car_def(pick["id"]), alert)


## Send the VIP from the pickup lot into its bay now.
func send_vip() -> void:
	if vip.is_empty() or vip["phase"] != "lot":
		return
	vip["phase"] = "bay"
	vip["progress"] = 0.0
	vip["running"] = false
	var bay: Dictionary = bays[int(vip["bay"])]
	bay["running"] = false   # normal car waits until the VIP leaves
	state_changed.emit()


## What the VIP will pay if it finished right now (boosts included).
func vip_pay() -> float:
	if vip.is_empty():
		return 0.0
	var car := car_def(vip["id"])
	var staff := 1.0
	for m in _assigned.values():
		if has_perk(m, "vip_pay"):
			staff += float(Data.PERKS["vip_pay"]["value"])
	if _legend_anywhere("vip_magnet"):
		staff *= float(Data.LEGEND_PASSIVES["vip_magnet"]["value"])
	return vip_base_pay(int(vip["bay"]), vip["id"]) * float(Data.VIP_RARITIES[int(car["rarity"])]["pay_mult"]) * (1.0 + skill("vip_pay")) * staff


## v0.19t Rosa's Referral was used while a rare car was here: the next one rolls in now.
func _referral_check() -> void:
	var m := manager_at("desk")
	if m.is_empty() or str(m.get("ability", "")) != "referral" or not bool(m.get("referral_wait", false)) or not vip.is_empty():
		return
	m["referral_wait"] = false
	_end_signature(m)
	if not bays.is_empty():
		spawn_vip()


func _finish_vip() -> void:
	var car := car_def(vip["id"])
	var r: Dictionary = Data.VIP_RARITIES[int(car["rarity"])]
	var pay := vip_pay()
	_earn(pay)   # VIPs pay you directly (plus a tip)
	var g := int(r["gloss"]) + int(skill("vip_gloss"))
	gloss += g
	log_car(vip["id"])
	add_followers(float(r["followers"]))
	if not has_reviews():
		add_followers(Data.STAR_THRESHOLDS[1] - followers)   # v0.19l: a rare car customer always leaves the first review
	certs += Data.VIP_CERTS
	vip = {}
	_referral_check.call_deferred()
	vip_finished.emit({"car": car, "pay": pay, "followers": float(r["followers"]) * (1.0 + skill("followers")), "gloss": g})
	state_changed.emit()


# ================================================================ boosts

var _boost_override := -1.0   # >= 0 forces total_boost() (used to work out offline earnings)


func base_boost(at: float = -1.0, city: String = "") -> float:
	if at < 0.0:
		at = now
	return perm_boost * (Data.AD_BOOST_MULT if at < float(ad_until.get(_ad_key(city), 0.0)) else 1.0)


## v0.19v: whose ad boost: the city (Hometown is one too); "" = the one you're in.
func _ad_key(city: String = "") -> String:
	return active_city if city == "" else city


## Active boosters add together (x5 + x2 = x7). 1 if none are running.
func booster_sum(at: float = -1.0) -> float:
	if at < 0.0:
		at = now
	var s := 0.0
	for b in active_boosters:
		if at < float(b["until"]):
			s += float(b["mult"])
	return maxf(1.0, s)


## TOTAL BOOST = base x boosters.
func total_boost(at: float = -1.0, city: String = "") -> float:
	if _boost_override >= 0.0:
		return _boost_override
	return base_boost(at, city) * booster_sum(at)


## Average boost between two times (for earnings while away): walks the moments
## where an ad boost or a booster runs out.
func average_boost(t0: float, t1: float, city: String = "") -> float:
	if t1 <= t0:
		return total_boost(t0, city)
	var cuts := [t0, t1]
	for b in active_boosters:
		var u := float(b["until"])
		if u > t0 and u < t1:
			cuts.append(u)
	var au := float(ad_until.get(_ad_key(city), 0.0))
	if au > t0 and au < t1:
		cuts.append(au)
	cuts.sort()
	var area := 0.0
	for k in range(cuts.size() - 1):
		var a: float = cuts[k]
		var b: float = cuts[k + 1]
		area += total_boost((a + b) * 0.5, city) * (b - a)
	return area / (t1 - t0)


# ================================================================ v0.19n Lucky Wheel

## "4h", "1h 30m", "10m", "45s" (no zero parts).
static func short_dur(secs: float) -> String:
	var t := int(round(secs))
	var h := t / 3600
	var m := (t % 3600) / 60
	if h > 0:
		return "%dh" % h if m == 0 else "%dh %dm" % [h, m]
	if m > 0:
		return "%dm" % m
	return "%ds" % t


func wheel_free_ready() -> bool:
	return now >= wheel_free_at


func wheel_free_in() -> float:
	return maxf(0.0, wheel_free_at - now)


## % chance of landing on prize i (its tier's chance shared by the prizes in that tier).
static func wheel_chance(i: int) -> float:
	var t: int = int(Data.WHEEL_PRIZES[i]["tier"])
	var n := 0
	for p in Data.WHEEL_PRIZES:
		if int(p["tier"]) == t:
			n += 1
	return float(Data.WHEEL_TIERS[t]["chance"]) / float(n)


## Short label for the wheel slice ("x20", "4h", "FILE", "LEGEND") and the line under it.
static func wheel_slice_text(i: int) -> Array:
	var p: Dictionary = Data.WHEEL_PRIZES[i]
	match str(p["kind"]):
		"booster":
			var b: Dictionary = {}
			for d in Data.BOOSTERS:
				if d["id"] == p["booster"]:
					b = d
			return ["x" + str(int(b["mult"])), short_dur(float(b["minutes"]) * 60.0)]
		"cash":
			return [short_dur(float(p["minutes"]) * 60.0), "cash"]
		"case":
			return ["FILE", {"basic": "case file", "detailed": "detailed", "classified": "classified"}[p["file"]]]
		"legend":
			return ["LEGEND", "manager"]
	return ["?", ""]


## What prize i gives, in words (odds card + the win message).
func wheel_prize_name(i: int) -> String:
	var p: Dictionary = Data.WHEEL_PRIZES[i]
	match str(p["kind"]):
		"booster":
			var b := booster_def(str(p["booster"]))
			return "x%d income for %s" % [int(b["mult"]), short_dur(float(b["minutes"]) * 60.0)]
		"cash":
			return "%s of instant cash" % short_dur(float(p["minutes"]) * 60.0)
		"case":
			for f in Data.CASE_FILES:
				if f["id"] == p["file"]:
					return str(f["name"])
		"legend":
			return "A Legendary manager (whole dossier)"
	return "?"


## Cash prize: `minutes` of what the shop makes now (its idle rate; before any manager, what the bays make;
## a brand-new shop gets at least the next bay's price).
func wheel_cash(minutes: float) -> float:
	var rate := maxf(idle_income(), bays_total_income(true))
	return maxf(rate * minutes * 60.0, maxf(100.0, next_bay_cost()))


## Spin: pays (free spin or Shine Bucks), rolls, gives the prize NOW (the wheel animation only shows it).
## Returns {} if you can't spin, else {"index", "text", "detail"}.
# ================================================================ v0.19t daily delivery, shop cat, decor

## v0.19t: is it raining right now? (3 h windows, seeded: the same for everyone; never in the first hour of a new game)
var rain_override := -1            # tests / dev: 0 = dry, 1 = rain, -1 = the real weather
var _rain_w := -1
var _rain_v := false


func raining(at: float = -1.0) -> bool:
	if rain_override >= 0:
		return rain_override == 1
	if at < 0.0:
		at = now
	if play_time < 3600.0:
		return false
	var w := int(floor(at / (Data.RAIN_WINDOW_H * 3600.0)))
	if w != _rain_w:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("rain_%d" % w)
		_rain_w = w
		_rain_v = rng.randf() < Data.RAIN_CHANCE
	return _rain_v


func weather_mult() -> float:
	return Data.RAIN_PAY_MULT if raining() else 1.0


## Seconds until the weather can next change (end of this 3 h window).
func weather_left() -> float:
	var span := Data.RAIN_WINDOW_H * 3600.0
	return span - fposmod(now, span)


## v0.19t: this city's Car of the Week (an everyday model of its first bay's tier; changes every Monday-ish week).
var _cotw_key := ""
var _cotw_id := ""


var cotw_enabled := true   # (tests switch it off so car payouts stay exact)


func car_of_week() -> String:
	if bays.is_empty() or is_hometown() or not cotw_enabled:
		return ""
	var week := int(floor(float(local_day() + 3) / 7.0))
	var tier := bay_tier(0)
	var k := "%d|%s|%d" % [week, active_city, tier]
	if k != _cotw_key:
		_cotw_key = k
		var pool: Array = Data.CARS.filter(func(c): return int(c["tier"]) == tier).map(func(c): return str(c["id"]))
		pool.sort()
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("cotw_" + k)
		_cotw_id = "" if pool.is_empty() else pool[rng.randi() % pool.size()]
	return _cotw_id


## Today's number on the phone's own clock (local midnight to midnight).
var _tz_bias := -1.0e9


## Seconds the phone's time zone is ahead of UTC (read once).
func tz_bias() -> float:
	if _tz_bias < -1.0e8:
		_tz_bias = float(Time.get_time_zone_from_system().get("bias", 0)) * 60.0
	return _tz_bias


func local_day(at: float = -1.0) -> int:
	if at < 0.0:
		at = now
	return int(floor((at + tz_bias()) / 86400.0))


func delivery_ready() -> bool:
	# (not during the first-session onboarding: from Bay 6, i.e. after the first renovation, or any later city)
	var more_cities := cities.keys().filter(func(id): return id != Data.HOMETOWN_ID).size() > 1
	return (bays.size() >= Data.DELIVERY_FROM_BAYS or prestige > 0 or more_cities) and local_day() > delivery_day and not is_hometown()


## Seconds until tomorrow's parcel.
func delivery_in() -> float:
	return maxf(0.0, (local_day() + 1) * 86400.0 - tz_bias() - now)


## Which day of the 7-day track the next parcel is (0 .. 6).
func delivery_slot() -> int:
	return delivery_count % Data.DELIVERY_REWARDS.size()


static func delivery_reward_text(slot: int) -> String:
	var r: Dictionary = Data.DELIVERY_REWARDS[slot]
	var t := ""
	match str(r["kind"]):
		"booster":
			var b: Dictionary = booster_def_static(str(r["booster"]))
			var bn: String = str(b.get("name", "Booster"))
			if int(r["n"]) > 1:
				bn = "%d %ss" % [int(r["n"]), bn]
			t = "%s %s" % [bn, short_dur(float(b.get("minutes", 0.0)) * 60.0)]
		"gloss":
			t = "%d {sb}" % int(r["n"])   # v0.19v: the banknote icon (UiTheme rich text)
		"case":
			t = "%s File" % str(r["file"]).capitalize()
	if r.has("gloss") and str(r["kind"]) != "gloss":
		t += " + %d {sb}" % int(r["gloss"])
	return t


static func booster_def_static(id: String) -> Dictionary:
	for b in Data.BOOSTERS:
		if b["id"] == id:
			return b
	return {}


## Open today's parcel. Returns {"slot", "text"} or {} if there's none today.
func open_delivery() -> Dictionary:
	if not delivery_ready():
		return {}
	var slot := delivery_slot()
	var r: Dictionary = Data.DELIVERY_REWARDS[slot]
	match str(r["kind"]):
		"booster":
			add_booster(str(r["booster"]), int(r["n"]))
		"gloss":
			gloss += int(r["n"])
		"case":
			add_case_file(str(r["file"]), int(r["n"]))
	if r.has("gloss") and str(r["kind"]) != "gloss":
		gloss += int(r["gloss"])
	delivery_day = local_day()
	delivery_count += 1
	var res := {"slot": slot, "text": delivery_reward_text(slot)}
	_log_milestone("delivery", "daily delivery %d: %s" % [delivery_count, res["text"]])
	delivery_opened.emit(res)
	boosts_changed.emit()
	state_changed.emit()
	_after_purchase()
	return res


## v0.19t: today's 3 reviews for the Reputation card: [stars (1..5, halves), text, name]. Same all day; their stars
## sit around your rating (no reviews yet = none).
func todays_reviews() -> Array:
	if not has_reviews():
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("reviews_%d_%s" % [local_day(), active_city])
	var out := []
	var used := {}
	var r := rating()
	for k in 3:
		var i := rng.randi() % Data.REVIEWS.size()
		while used.has(i):
			i = (i + 1) % Data.REVIEWS.size()
		used[i] = true
		var st := clampf(snappedf(r + rng.randf_range(-0.5, 1.0), 0.5), 1.0, 5.0)
		var city: String = str(city_def(active_city)["name"]).split(",")[0] if not is_hometown() else "Hometown"
		out.append([st, Data.REVIEWS[i], "%s, %s" % [Data.REVIEW_NAMES[rng.randi() % Data.REVIEW_NAMES.size()], city]])
	return out


## Pet the shop cat:## Pet the shop cat: hearts every time; the first pet of a (local) day leaves CAT_TREAT_GLOSS Shine Bucks.
func pet_cat() -> int:
	var treat := 0
	if local_day() > cat_treat_day:
		cat_treat_day = local_day()
		treat = Data.CAT_TREAT_GLOSS
		gloss += treat
		_after_purchase()
	cat_petted.emit(treat)
	return treat


func cat_treat_ready() -> bool:
	return local_day() > cat_treat_day


static func decor_def(id: String) -> Dictionary:
	for d in Data.DECOR:
		if d["id"] == id:
			return d
	return {}


func set_shop_name(t: String) -> void:
	shop_name = t.strip_edges().left(Data.SHOP_NAME_MAX)
	state_changed.emit()
	_after_purchase()


## What the sign over the desk says: "Lima · Suburban Car Wash", or "Hamza's Detailing · Lima" once named.
func sign_text() -> String:
	var city: String = str(city_def(active_city)["name"]).split(",")[0]
	if shop_name != "":
		return "%s  ·  %s" % [shop_name, city]
	return "%s  ·  %s" % [city, premises_def()["name"]]


func has_decor(id: String) -> bool:
	return decor.has(id)


func buy_decor(id: String) -> bool:
	var d := decor_def(id)
	if d.is_empty() or decor.has(id) or gloss < int(d["price"]):
		return false
	gloss -= int(d["price"])
	decor.append(id)
	_log_milestone("decor", "decor: " + id)
	state_changed.emit()
	_after_purchase()
	return true


## Curb appeal: followers an hour from decor (also while away).
func decor_followers_per_hour() -> float:
	return Data.DECOR_FOLLOWERS * decor.size()


func spin_wheel(free: bool, force: int = -1) -> Dictionary:
	if free:
		if not wheel_free_ready():
			return {}
		wheel_free_at = now + Data.WHEEL_FREE_HOURS * 3600.0
	else:
		if gloss < Data.WHEEL_SPIN_COST:
			return {}
		gloss -= Data.WHEEL_SPIN_COST
	var roll := randf() * 100.0
	var idx := Data.WHEEL_PRIZES.size() - 1
	for i in Data.WHEEL_PRIZES.size():
		roll -= wheel_chance(i)
		if roll <= 0.0:
			idx = i
			break
	if force >= 0:
		idx = force   # (tests)
	var res := {"index": idx, "text": wheel_prize_name(idx), "detail": ""}
	var p: Dictionary = Data.WHEEL_PRIZES[idx]
	match str(p["kind"]):
		"booster":
			add_booster(str(p["booster"]))
			res["detail"] = "It's in YOUR BOOSTERS (BOOST button): use it when you like."
		"cash":
			var amt := wheel_cash(float(p["minutes"]))
			_earn(amt)
			res["text"] = "%s cash!" % money(amt)
			res["detail"] = "%s of what your shop makes, paid right now." % short_dur(float(p["minutes"]) * 60.0)
		"case":
			add_case_file(str(p["file"]))
			res["detail"] = "Open it on the MAP > MANAGERS tab for premium manager clues."
		"legend":
			var free_ones: Array = roster.values().filter(func(m): return int(m["rarity"]) == 4 and not m["owned"])
			if free_ones.is_empty():
				add_case_file("classified", Data.WHEEL_LEGEND_FALLBACK)
				res["text"] = "%d Classified Files!" % Data.WHEEL_LEGEND_FALLBACK
				res["detail"] = "You already have every Legendary manager, so here are Classified Files instead."
			else:
				var m: Dictionary = free_ones.pick_random()
				m["clues"] = ALL_CLUES
				m["owned"] = true
				res["text"] = "%s joined your team!" % m["name"]
				res["detail"] = "A Legendary manager. Put them to work from any %s's manager panel (PREMIUM tab)." % {"bay": "bay", "valet": "valet", "desk": "front desk"}[m["area"]]
				res["manager"] = m["id"]
				roster_changed.emit()
	_log_milestone("wheel", "wheel: %s" % res["text"])
	boosts_changed.emit()
	state_changed.emit()
	_after_purchase()
	return res


func booster_def(id: String) -> Dictionary:
	for b in Data.BOOSTERS:
		if b["id"] == id:
			return b
	return {}


func activate_booster(id: String) -> void:
	var d := booster_def(id)
	if d.is_empty() or int(boosters.get(id, 0)) <= 0:
		return
	boosters[id] = int(boosters[id]) - 1
	if boosters[id] <= 0:
		boosters.erase(id)
	active_boosters.append({"id": id, "mult": float(d["mult"]), "until": now + float(d["minutes"]) * 60.0})
	_boost_changed()


func add_booster(id: String, n: int = 1) -> void:
	if booster_def(id).is_empty():
		return
	boosters[id] = int(boosters.get(id, 0)) + n
	boosts_changed.emit()


## v0.19j: only today's deals can be bought, each once per window.
func buy_booster(id: String) -> void:
	var d := booster_def(id)
	if d.is_empty() or gloss < int(d["price"]) or not deals().has(id) or deal_sold(id):
		return
	gloss -= int(d["price"])
	if int(deals_bought.get("window", -1)) != deal_window():
		deals_bought = {"window": deal_window(), "ids": []}
	deals_bought["ids"].append(id)
	add_booster(id)
	_after_purchase()


## v0.19j: which 12 h deals window we're in (real clock).
func deal_window(at: float = -1.0) -> int:
	return int(floor((now if at < 0.0 else at) / (Data.DEAL_HOURS * 3600.0)))


## Seconds until the next set of deals.
func deals_refresh_in() -> float:
	return float(deal_window() + 1) * Data.DEAL_HOURS * 3600.0 - now


## The DEAL_COUNT different boosters on offer in a window (seeded by the window: the same for everyone).
func deals(window: int = -999999) -> Array:
	if window == -999999:
		window = deal_window()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("deals_%d" % window)
	var pool: Array = []
	for b in Data.BOOSTERS:
		if Data.DEAL_WEIGHTS.has(b["id"]):
			pool.append(b["id"])
	var out: Array = []
	while out.size() < Data.DEAL_COUNT and not pool.is_empty():
		var total := 0.0
		for id in pool:
			total += float(Data.DEAL_WEIGHTS[id])
		var r := rng.randf() * total
		var pick: String = pool[pool.size() - 1]
		for id in pool:
			r -= float(Data.DEAL_WEIGHTS[id])
			if r <= 0.0:
				pick = id
				break
		out.append(pick)
		pool.erase(pick)
	return out


func deal_sold(id: String) -> bool:
	return int(deals_bought.get("window", -1)) == deal_window() and Array(deals_bought.get("ids", [])).has(id)


## v0.19j: running boosters grouped by booster (same id = one badge), in the order they were first used:
## [{id, mult, count, until (the soonest one), total (their x added up)}]
func booster_groups() -> Array:
	var out: Array = []
	var idx := {}
	for b in active_boosters:
		if now >= float(b["until"]):
			continue
		var id := str(b["id"])
		if not idx.has(id):
			idx[id] = out.size()
			out.append({"id": id, "mult": float(b["mult"]), "count": 0, "until": float(b["until"]), "total": 0.0})
		var g: Dictionary = out[idx[id]]
		g["count"] = int(g["count"]) + 1
		g["total"] = float(g["total"]) + float(b["mult"])
		g["until"] = minf(float(g["until"]), float(b["until"]))
	return out


## v0.19j (Book): bays in this city whose manager belongs to this crew (they earn x1.5 on these cars).
func crew_bays(cl: String) -> Array:
	var out: Array = []
	for i in bays.size():
		var m := manager_at("bay%d" % i)
		if not m.is_empty() and crews_of(m).has(cl):
			out.append(i)
	return out


## Placeholder until AdMob is in: grants the ad boost as if an ad was watched.
## v0.19v (Hamza): per city: +4h of x2 for this city (city "" = the one you're in), banked up to 24h.
func watch_ad_boost(city: String = "") -> void:
	var k := _ad_key(city)
	if ad_boost_left(k) >= Data.AD_BOOST_MAX_HOURS * 3600.0 - 60.0:
		return
	var u := maxf(float(ad_until.get(k, 0.0)), now) + Data.AD_BOOST_HOURS * 3600.0
	ad_until[k] = minf(u, now + Data.AD_BOOST_MAX_HOURS * 3600.0)
	if k != active_city:
		_refresh_bg_rates()
	_boost_changed()


func ad_boost_left(city: String = "") -> float:
	return maxf(0.0, float(ad_until.get(_ad_key(city), 0.0)) - now)


func ad_boost_full(city: String = "") -> bool:
	return ad_boost_left(city) >= Data.AD_BOOST_MAX_HOURS * 3600.0 - 60.0


## v0.19v BOOST ALL: one ad boosts every city in a country, once all of its cities are open.
func boost_all_ready(cid: String) -> bool:
	if cid == Data.HOMETOWN_ID or not country_unlocked(cid):
		return false
	for ct in country_def(cid)["cities"]:
		if not city_unlocked(ct["id"]):
			return false
	return true


## Every city in the country that still has room for more time.
func boost_all_wanted(cid: String) -> bool:
	if not boost_all_ready(cid):
		return false
	for ct in country_def(cid)["cities"]:
		if not ad_boost_full(ct["id"]):
			return true
	return false


## v0.19w (Hamza): one ad tops EVERY city of the country right up to the full 24h (not +4h each).
func boost_all(cid: String) -> void:
	if not boost_all_wanted(cid):
		return
	for ct in country_def(cid)["cities"]:
		ad_until[ct["id"]] = now + Data.AD_BOOST_MAX_HOURS * 3600.0
	_refresh_bg_rates()
	_boost_changed()


## Why BOOST ALL can't go yet ("" = it can). The button is never greyed out: tapping it says this.
func boost_all_block(cid: String) -> String:
	if not boost_all_ready(cid):
		return "Open all 5 cities in %s first" % country_def(cid)["name"]
	if not boost_all_wanted(cid):
		return "Every city in %s is already fully boosted" % country_def(cid)["name"]
	return ""


# ---------------------------------------------------------------- v0.19v city stashes (COLLECT on the map)
## A city you're not in keeps what it earns in its own stash until you collect it (Idle Miner style).
## The city you're in pays straight into your wallet. Travelling to a city collects its stash.

func stash_of(id: String) -> float:
	return float(stash.get(id, 0.0))


## Collect one city's stash into its country's wallet. Returns the amount.
func collect_city(id: String, quiet := false) -> float:
	var amt := stash_of(id)
	stash.erase(id)
	if amt <= 0.0:
		return 0.0
	var cid := country_of(id)
	wallets[cid] = wallets.get(cid, 0.0) + amt
	if not quiet:
		stash_collected.emit(id, amt)
		state_changed.emit()
	return amt


## Collect every stash. Returns country id -> amount collected.
func collect_all() -> Dictionary:
	var out := {}
	for id in stash.keys():
		var amt := stash_of(id)
		if amt <= 0.0:
			continue
		var cid := country_of(id)
		out[cid] = float(out.get(cid, 0.0)) + amt
		wallets[cid] = wallets.get(cid, 0.0) + amt
	stash = {}
	if not out.is_empty():
		stash_collected.emit("", 0.0)
		state_changed.emit()
	return out


## v0.19w: the map's COLLECT button (ad only, like Idle Miner): every stash of one country (cid) or of all
## countries (cid "") paid out x COLLECT_AD_MULT. Going to a city still collects its stash for free (x1).
## Returns country id -> amount paid (after the x2).
func collect_ad(cid: String = "") -> Dictionary:
	var out := {}
	for id in stash.keys():
		var c := country_of(id)
		if cid != "" and c != cid:
			continue
		var amt := stash_of(id) * Data.COLLECT_AD_MULT
		stash.erase(id)
		if amt <= 0.0:
			continue
		out[c] = float(out.get(c, 0.0)) + amt
		wallets[c] = wallets.get(c, 0.0) + amt
	if not out.is_empty():
		stash_collected.emit("", 0.0)
		state_changed.emit()
	return out


## What one country (or all, "") has waiting in its stashes.
func stash_of_country(cid: String = "") -> Dictionary:
	var out := {}
	for id in stash.keys():
		var c := country_of(id)
		if (cid == "" or c == cid) and stash_of(id) > 0.0:
			out[c] = float(out.get(c, 0.0)) + stash_of(id)
	return out


func stash_total() -> float:
	var t := 0.0
	for v in stash.values():
		t += float(v)
	return t


## Seconds until the boost next changes (the soonest thing to run out), or 0.
func boost_time_left() -> float:
	var t := 0.0
	for b in active_boosters:
		t = maxf(t, float(b["until"]) - now)
	return maxf(t, ad_boost_left())


func _boost_changed() -> void:
	_refresh_bg_rates()
	boosts_changed.emit()
	_after_purchase()


func _expire_boosters() -> void:
	var before := active_boosters.size()
	active_boosters = active_boosters.filter(func(b): return now < float(b["until"]))
	if active_boosters.size() != before:
		_refresh_bg_rates()
		boosts_changed.emit()


# ================================================================ skill tree

func skill_node(id: String) -> Dictionary:
	return _skill_nodes.get(id, {})


func skill_level(id: String) -> int:
	return int(skills.get(id, 0))


## Total effect of all bought nodes of a type (key = car class or country, if the type uses one).
func skill(type: String, key: String = "") -> float:
	return _skill_cache.get(type + (":" + key if key != "" else ""), 0.0)


func _rebuild_skill_cache() -> void:
	_skill_cache = {}
	for id in skills.keys():
		var n := skill_node(id)
		if n.is_empty():
			continue
		var v: float = float(n["value"]) * int(skills[id])
		var k: String = n["type"]
		if k == "specialist":
			k += ":" + str(n["class"])
		elif k == "country_income":
			k += ":" + str(n["country"])
		_skill_cache[k] = _skill_cache.get(k, 0.0) + v


func level_cost_mult() -> float:
	return maxf(0.5, 1.0 - skill("level_discount"))


func token_price(cid: String) -> float:
	var first: String = country_def(cid)["cities"][0]["id"]
	return Data.TOKEN_BASE * city_scale(first) * pow(Data.TOKEN_GROWTH, int(tokens_bought.get(cid, 0)))


func buy_token(cid: String) -> void:
	var price := token_price(cid)
	if not country_unlocked(cid) or wallets.get(cid, 0.0) < price:
		return
	wallets[cid] -= price
	tokens[cid] = int(tokens.get(cid, 0)) + 1
	tokens_bought[cid] = int(tokens_bought.get(cid, 0)) + 1
	_after_purchase()


## Tokens for the next level of a node (-1 if maxed).
func skill_cost(id: String) -> int:
	var n := skill_node(id)
	var lvl := skill_level(id)
	if n.is_empty() or lvl >= int(n["max"]):
		return -1
	return int(n["cost"]) * (lvl + 1)


## A node opens once every parent node has at least Lv 1.
func skill_open(id: String) -> bool:
	for p in skill_node(id).get("parents", []):
		if skill_level(p) < 1:
			return false
	return true


func can_upgrade_skill(id: String) -> bool:
	var cost := skill_cost(id)
	var n := skill_node(id)
	return cost > 0 and skill_open(id) and int(tokens.get(n["country"], 0)) >= cost


func upgrade_skill(id: String) -> void:
	if not can_upgrade_skill(id):
		return
	var n := skill_node(id)
	tokens[n["country"]] = int(tokens[n["country"]]) - skill_cost(id)
	skills[id] = skill_level(id) + 1
	_rebuild_skill_cache()
	_refresh_bg_rates()
	_after_purchase()


## "+30%" / "+2" text for a node at a level.
func skill_effect_text(id: String, lvl: int) -> String:
	var n := skill_node(id)
	var v: float = float(n["value"]) * lvl
	if Data.SKILL_FLAT_TYPES.has(n["type"]):
		return str(int(v))
	return "%d%%" % int(round(v * 100.0))


# ================================================================ tutorial

## Moves the tutorial on when the player has done the current step.
func _update_tutorial() -> void:
	# v0.17g (Hamza): the tutorial is just the first loop (car -> valet -> desk), then "You're good to go!".
	# The hiring / level steps are gone (old saves sitting on them just finish).
	var earned := _tut_paid
	match tutorial_step:
		TUT_WASH:
			if bays[0]["ready"] > 0.0 or earned or desk["lot"] > 0.0:
				tutorial_step = TUT_VALET
		TUT_VALET:
			if valet["phase"] != "idle" or desk["lot"] > 0.0 or earned:
				tutorial_step = TUT_DESK
		TUT_DESK:
			if earned:
				finish_tutorial(_tut_base > 0.0)   # the big message only on a brand-new game
		_:
			finish_tutorial(true)


func start_tutorial() -> void:
	tutorial_step = TUT_WASH
	_tut_base = lifetime_earned
	_tut_paid = false


## silent = player wandered off to another screen: just end it quietly.
func finish_tutorial(silent: bool = false) -> void:
	if tutorial_step == TUT_DONE:
		return
	tutorial_step = TUT_DONE
	if not silent:
		tutorial_finished.emit()
	save_game()


# ================================================================ premium

func buy_display_slot() -> void:
	if bought_slots >= Data.MAX_BOUGHT_SLOTS or gloss < Data.SLOT_COST:
		return
	gloss -= Data.SLOT_COST
	bought_slots += 1
	_after_purchase()


## v0.17h one-time tips: seen ones are kept in settings["tips_seen"].
func tip_seen(id: String) -> bool:
	return bool(settings.get("tips_seen", {}).get(id, false))


func mark_tip(id: String) -> void:
	var d: Dictionary = settings.get("tips_seen", {}).duplicate()
	d[id] = true
	set_setting("tips_seen", d)


func reset_tips() -> void:
	set_setting("tips_seen", {})


func set_setting(k: String, v: Variant) -> void:
	settings[k] = v
	_after_purchase()


# ================================================================ managers (cash hires)

## The state dict of a station in the active city ({} if that bay isn't built).
func _station(key: String) -> Dictionary:
	match area_of(key):
		"bay":
			var i := bay_index(key)
			return bays[i] if i < bays.size() else {}
		"valet":
			return valet
	return desk


func is_automated(key: String) -> bool:
	return _assigned.has(key)


static func is_premium(m: Dictionary) -> bool:
	return m.has("look")


## Cash managers you can use in the city you're in (they only work where they were hired).
func managers_in_area(area: String) -> Array:
	return managers.filter(func(m): return m["area"] == area and m["home"] == active_city)


## Cash managers hired in this city who aren't working anywhere (the MANAGERS tab list).
func free_managers_in_area(area: String) -> Array:
	return managers_in_area(area).filter(func(m): return m["assigned"] == "")


## "Bay 2 in Detroit" for a manager who is working somewhere ("" if free).
func manager_job_text(m: Dictionary) -> String:
	if m.is_empty() or m["assigned"] == "":
		return ""
	var where := str(city_def(m["city"])["name"]).split(",")[0]
	var stn: String = m["assigned"]
	var nm := "Front Desk" if stn == "desk" else ("Valet" if stn == "valet" else "Bay %d" % (bay_index(stn) + 1))
	return "%s in %s" % [nm, where]


func hire_cost(area: String) -> float:
	if is_hometown():
		return Data.MANAGER_HIRE_BASE[area] * Data.HOMETOWN_HIRE_MULT * pow(Data.HOMETOWN_HIRE_GROWTH, hires[area]) \
			* maxf(0.5, 1.0 - skill("hire_discount"))
	return Data.MANAGER_HIRE_BASE[area] * pow(Data.MANAGER_HIRE_GROWTH, hires[area]) * city_scale(active_city) \
		* maxf(0.5, 1.0 - skill("hire_discount"))


## Hire a random manager with cash. They belong to this city. If the station has
## nobody, they start working there straight away.
func hire_manager(key: String) -> Dictionary:
	var area := area_of(key)
	var cost := hire_cost(area)
	if cash < cost:
		return {}
	cash -= cost
	hires[area] += 1
	var m := _make_manager(area, _roll_cash_rarity(), active_city)
	m["ability"] = _even_ability(area)
	if not is_automated(key):
		m["city"] = active_city
		m["assigned"] = key
	managers.append(m)
	_rebuild_assigned()
	manager_hired.emit(m)
	_after_purchase()
	return m


func _make_manager(area: String, rarity: int, home: String) -> Dictionary:
	var abilities: Array = Data.ABILITIES[area]
	var m := {
		"id": next_manager_id,
		"name": Data.MANAGER_NAMES.pick_random(),
		"area": area,
		"rarity": rarity,
		"ability": abilities.pick_random()["id"],
		"crew": Data.CREWS.pick_random()["id"],
		"home": home,
		"city": "",
		"assigned": "",
		"active_until": 0.0,
		"ready_at": 0.0,
	}
	next_manager_id += 1
	return m


## The hire's ability, evened out (v0.17d), like a shuffled deck: it's picked at random from
## the types you have FEWEST of at that station type in this city, so every 3 hires bring one
## speed, one discount and one income (random order). The tier is rolled separately.
func _even_ability(area: String) -> String:
	var counts := {}
	for m in managers:
		if m["area"] == area and str(m.get("home", "")) == active_city:
			counts[m["ability"]] = int(counts.get(m["ability"], 0)) + 1
	var list: Array = Data.ABILITIES[area]
	var low := 1 << 30
	for a in list:
		low = mini(low, int(counts.get(a["id"], 0)))
	var pool := list.filter(func(a): return int(counts.get(a["id"], 0)) == low)
	return pool.pick_random()["id"]


static func _roll_cash_rarity() -> int:
	var odds := []
	for r in Data.RARITIES:
		odds.append(float(r["odds"]))
	return _roll_rarity(odds)


func _find_manager(id: int) -> Dictionary:
	for m in managers:
		if m["id"] == id:
			return m
	return {}


# ================================================================ named managers (unique roster)

const ALL_CLUES := 63   # 6 clue bits


func _init_roster() -> void:
	roster = {}
	for d in Data.NAMED_MANAGERS:
		var m: Dictionary = d.duplicate(true)
		m.merge({"clues": 0, "owned": false, "level": 1, "city": "", "assigned": "", "active_until": 0.0, "ready_at": 0.0, "gear": "", "jar": 0.0, "jar_country": ""})
		roster[d["id"]] = m
	_assigned = {}


func manager(id: String) -> Dictionary:
	return roster.get(id, {})


static func clue_count(m: Dictionary) -> int:
	var n := 0
	for k in Data.CLUES.size():
		if int(m["clues"]) & (1 << k):
			n += 1
	return n


static func has_clue(m: Dictionary, k: int) -> bool:
	return (int(m["clues"]) & (1 << k)) != 0


static func dossier_done(m: Dictionary) -> bool:
	return int(m["clues"]) == ALL_CLUES


func can_call(m: Dictionary) -> bool:
	return not m.is_empty() and dossier_done(m) and not m["owned"]


func call_fee() -> float:
	return Data.CALL_FEE


## Dossier complete: pay the flat signing fee and they join your roster.
func call_manager(id: String) -> bool:
	var m := manager(id)
	if not can_call(m) or cash < call_fee():
		return false
	cash -= call_fee()
	m["owned"] = true
	manager_called.emit(m)
	roster_changed.emit()
	_after_purchase()
	return true


func owned_managers() -> Array:
	return roster.values().filter(func(m): return m["owned"])


## Premium managers you own that can work this kind of station (bay / valet / desk).
func premium_in_area(area: String) -> Array:
	return roster.values().filter(func(m): return m["owned"] and m["area"] == area)


## Dossiers that are complete and waiting for a call (for the "!" marks).
func callable_count() -> int:
	return roster.values().filter(func(m): return dossier_done(m) and not m["owned"]).size()


func unopened_case_files() -> int:
	var n := 0
	for id in case_files:
		n += int(case_files[id])
	return n


## Your first premium manager: Dazza's whole dossier, a Hometown run 1 reward (v0.17c).
func _grant_starter() -> void:
	if starter_given:
		return
	starter_given = true
	var m := manager(Data.STARTER_MANAGER)
	if not m.is_empty() and not m["owned"]:
		m["clues"] = ALL_CLUES


# ---------------------------------------------------------------- case files + certs

func case_def(id: String) -> Dictionary:
	for c in Data.CASE_FILES:
		if c["id"] == id:
			return c
	return {}


func add_case_file(id: String, n: int = 1) -> void:
	if case_def(id).is_empty() or n <= 0:
		return
	case_files[id] = int(case_files.get(id, 0)) + n
	roster_changed.emit()


## Open one Case File: its cards, in order. Each card = one manager (the same one can
## come up twice) + 1-6 clues they're missing; extra clues become Certs.
## Returns {file, cards: [{id, clues: [clue index...], rolled, certs}], clues: [[id, clue]...], certs}.
func open_case_file(id: String) -> Dictionary:
	var d := case_def(id)
	if d.is_empty() or int(case_files.get(id, 0)) <= 0:
		return {}
	case_files[id] = int(case_files[id]) - 1
	if case_files[id] <= 0:
		case_files.erase(id)
	var cards := []
	var found := []
	var got := int(d["certs"])
	for k in int(d["cards"]):
		var rolled := mini(_roll_rarity(Data.CLUE_ROLL_ODDS) + 1, int(d["max_clues"]))
		var mid := _pick_manager(_roll_rarity(d["odds"]))
		var card := {"id": mid, "clues": [], "rolled": rolled, "certs": 0}
		if mid == "":
			card["certs"] = rolled * Data.LEFTOVER_CLUE_CERTS
		else:
			var m: Dictionary = roster[mid]
			var missing := []
			for c in Data.CLUES.size():
				if not has_clue(m, c):
					missing.append(c)
			missing.shuffle()
			for c in missing.slice(0, rolled):
				m["clues"] = int(m["clues"]) | (1 << int(c))
				card["clues"].append(c)
				found.append([mid, c])
			card["certs"] = (rolled - card["clues"].size()) * Data.LEFTOVER_CLUE_CERTS
		got += int(card["certs"])
		cards.append(card)
	certs += got
	var result := {"file": id, "cards": cards, "clues": found, "certs": got}
	case_opened.emit(result)
	roster_changed.emit()
	_after_purchase()
	return result


static func _roll_rarity(odds: Array) -> int:
	var total := 0.0
	for o in odds:
		total += float(o)
	var roll := randf() * total
	for i in odds.size():
		roll -= float(odds[i])
		if roll <= 0.0 and float(odds[i]) > 0.0:
			return i
	return 0


## A manager with clues still missing: from that rarity, else the nearest rarity below,
## else above ("" if every dossier is done). Prefers dossiers you've started.
func _pick_manager(rarity: int) -> String:
	var order := [rarity]
	for r in range(rarity - 1, -1, -1):
		order.append(r)
	for r in range(rarity + 1, Data.PREMIUM_RARITIES.size()):
		order.append(r)
	for r in order:
		var open := roster.values().filter(func(m): return int(m["rarity"]) == r and not dossier_done(m))
		if open.is_empty():
			continue
		var started := open.filter(func(m): return int(m["clues"]) != 0)
		var pool: Array = started if (not started.is_empty() and randf() < Data.CASE_STARTED_PREF) else open
		var m: Dictionary = pool.pick_random()
		return m["id"]
	return ""


## Certs needed for the next level (-1 at max).
func level_cert_cost(m: Dictionary) -> int:
	var lvl := int(m["level"])
	if lvl >= Data.MAX_MANAGER_LEVEL:
		return -1
	return int(ceil(float(rarity_def(m)["cert"]) * pow(Data.CERT_GROWTH, lvl - 1)))


func level_up_manager(id: String) -> bool:
	var m := manager(id)
	if m.is_empty() or not m["owned"]:
		return false
	var cost := level_cert_cost(m)
	if cost < 0 or certs < cost:
		return false
	certs -= cost
	m["level"] = int(m["level"]) + 1
	_refresh_bg_rates()
	roster_changed.emit()
	_after_purchase()
	return true


static func promotion(m: Dictionary) -> String:
	var t: String = Data.PROMOTIONS[0][1]
	for p in Data.PROMOTIONS:
		if int(m.get("level", 1)) >= int(p[0]):
			t = p[1]
	return t


static func has_perk(m: Dictionary, perk: String) -> bool:
	if m.is_empty() or not m.get("owned", false):
		return false
	var lvl := int(m["level"])
	return (m.get("perk20", "") == perk and lvl >= 20) or (m.get("perk50", "") == perk and lvl >= 50)


## Passive while seated, e.g. 0.25 = +25%.
func passive_value(m: Dictionary, level: int = -1) -> float:
	if level < 0:
		level = int(m["level"])
	var v: float = float(rarity_def(m)["passive"]) * (1.0 + Data.PASSIVE_PER_LEVEL * (level - 1))
	if has_perk(m, "passive_x2"):
		v *= 2.0
	return v * (1.0 + gear_value(m, "passive"))


func passive_text(m: Dictionary, level: int = -1) -> String:
	return Data.PASSIVE_TEXT[m["area"]] % ("%d%%" % int(round(passive_value(m, level) * 100.0)))


func manager_passive(key: String) -> float:
	var m := manager_at(key)
	return passive_value(m) if is_premium(m) else 0.0


# ---------------------------------------------------------------- seating

func _rebuild_assigned() -> void:
	_assigned = {}
	for m in managers:
		if m["city"] == active_city and m["assigned"] != "":
			_assigned[m["assigned"]] = m
	for m in roster.values():
		if m["owned"] and m["city"] == active_city and m["assigned"] != "":
			_assigned[m["assigned"]] = m


## The manager (cash or premium) working a station in this city ({} if none).
func manager_at(key: String) -> Dictionary:
	return _assigned.get(key, {})


## Put a manager to work at a station in this city (swapping out whoever was there).
## id = int for a cash manager (must be from this city), String for a premium one
## (they can work anywhere; if they were in another city they move here).
func assign_manager(id: Variant, key: String) -> void:
	var m := _any_manager(id)
	if m.is_empty() or m["area"] != area_of(key) or _station(key).is_empty():
		return
	if is_premium(m) and not m["owned"]:
		return
	if not is_premium(m) and m["home"] != active_city:
		return
	if not is_premium(m) and m["assigned"] != "" and not (m["city"] == active_city and m["assigned"] == key):
		return   # cash managers are never pulled off another station: Remove them there first
	var current := manager_at(key)
	if not current.is_empty():
		current["assigned"] = ""
		current["city"] = ""
	m["city"] = active_city
	m["assigned"] = key
	_rebuild_assigned()
	_refresh_bg_rates()
	_after_purchase()


func unassign_manager(id: Variant) -> void:
	var m := _any_manager(id)
	if m.is_empty():
		return
	m["assigned"] = ""
	m["city"] = ""
	_rebuild_assigned()
	_refresh_bg_rates()
	_after_purchase()


func _any_manager(id: Variant) -> Dictionary:
	if typeof(id) == TYPE_STRING:
		return manager(id)
	return _find_manager(int(id))


## "Free", "At Bay 2" or "Working in Detroit" for the manager lists.
func manager_location(m: Dictionary) -> String:
	if m["assigned"] == "":
		return "Free"
	if m["city"] != active_city:
		return "Working in " + str(city_def(m["city"])["name"]).split(",")[0]
	return "At " + station_name(m["assigned"])


static func ability_def(m: Dictionary) -> Dictionary:
	if Data.SIGNATURE_ABILITIES.has(str(m.get("ability", ""))):
		return Data.SIGNATURE_ABILITIES[m["ability"]]
	for a in Data.ABILITIES[m["area"]]:
		if a["id"] == m["ability"]:
			return a
	return Data.ABILITIES[m["area"]][0]


static func rarity_def(m: Dictionary) -> Dictionary:
	var t: Array = Data.PREMIUM_RARITIES if is_premium(m) else Data.RARITIES
	return t[clampi(int(m["rarity"]), 0, t.size() - 1)]


static func crew_def(m: Dictionary) -> Dictionary:
	for c in Data.CREWS:
		if c["id"] == m["crew"]:
			return c
	return Data.CREWS[0]


## The crews a manager counts as (All-Rounder perk = every crew).
static func crews_of(m: Dictionary) -> Array:
	if has_perk(m, "wildcard"):
		return Data.CREWS.map(func(c): return c["id"])
	return [m["crew"]]


static func _ability_strength(m: Dictionary) -> float:
	var r := rarity_def(m)
	var plus := has_perk(m, "ability_plus")
	if str(m.get("ability", "")) == "tip_jar":
		return tip_jar_mult(m)
	if str(m.get("ability", "")) == "convoy":
		return float(convoy_trips(m))
	match str(m.get("ability", "")):
		"clear_lot":
			return snappedf(lerpf(Data.CLEAR_LOT_MULT[0], Data.CLEAR_LOT_MULT[1], _lvk(m)), 0.1)
		"showstopper":
			return roundf(lerpf(Data.SHOW_CAR_MULT[0], Data.SHOW_CAR_MULT[1], _lvk(m)))
		"mates_rates":
			return float(mates_rates_levels(m))
		"loyalty_card":
			return snappedf(lerpf(Data.LOYALTY_FOLLOWERS[0], Data.LOYALTY_FOLLOWERS[1], _lvk(m)), 0.1)
		"tow_truck", "referral":
			return 0.0
		"foam_cannon":
			return roundf(lerpf(Data.FOAM_CANNON_MULT[0], Data.FOAM_CANNON_MULT[1], _lvk(m)))
		"flash_polish":
			return float(flash_polish_cars(m))
		"training_day":
			return float(training_day_levels(m))
	if str(m.get("ability", "")) == "shortcut":
		var k := (int(m.get("level", 1)) - 1) / float(maxi(1, Data.MAX_MANAGER_LEVEL - 1))
		return roundf(lerpf(float(ability_def(m)["duration"]), float(ability_def(m)["duration_max"]), k))
	if ability_def(m)["kind"] == "discount":
		return minf(0.8, float(r["discount"]) + (0.10 if plus else 0.0))
	return float(r["mult"]) + (1.0 if plus else 0.0)


## Dazza's Tip Jar payout multiplier: x3 at Lv1 up to x5 at Lv50 (+1 with the ability_plus perk).
static func tip_jar_mult(m: Dictionary) -> float:
	var k := (int(m.get("level", 1)) - 1) / float(maxi(1, Data.MAX_MANAGER_LEVEL - 1))
	return lerpf(Data.TIP_JAR_MULT, Data.TIP_JAR_MULT_MAX, k) + (1.0 if has_perk(m, "ability_plus") else 0.0)


func ability_duration(m: Dictionary) -> float:
	var base: float = float(ability_def(m).get("duration", rarity_def(m)["duration"]))
	var d: float = base * (1.0 + Data.DURATION_PER_LEVEL * (int(m.get("level", 1)) - 1))
	if ability_def(m).has("duration_max"):   # v0.19o: Shortcut 30s (Lv1) .. 60s (Lv50)
		d = lerpf(base, float(ability_def(m)["duration_max"]), (int(m.get("level", 1)) - 1) / float(maxi(1, Data.MAX_MANAGER_LEVEL - 1)))
	if ability_def(m)["kind"] == "speed":
		d *= Data.SPEED_DURATION_MULT
	if has_perk(m, "duration"):
		d *= 1.0 + float(Data.PERKS["duration"]["value"])
	return d * (1.0 + gear_value(m, "ability_time"))


func ability_cooldown(m: Dictionary) -> float:
	var c: float = float(ability_def(m).get("cooldown", rarity_def(m).get("cooldown", Data.ABILITY_COOLDOWN)))
	if has_perk(m, "cooldown"):
		c *= 1.0 - float(Data.PERKS["cooldown"]["value"])
	return c * (1.0 - gear_value(m, "cooldown"))


## Short text like "Foam Party: Bay income x3".
static func ability_text(m: Dictionary) -> String:
	var a := ability_def(m)
	if not str(a["desc"]).contains("%s"):
		return "%s: %s" % [a["name"], a["desc"]]
	if a["id"] == "foam_cannon" or a["id"] == "training_day":   # v0.19t: "for %ss ... x%s / %s levels"
		var secs := int(round(lerpf(float(a["duration"]), float(a["duration_max"]), _lvk(m))))
		return "%s: %s" % [a["name"], a["desc"] % [str(secs), str(int(_ability_strength(m)))]]
	if a["id"] == "finish_line":
		var fl := finish_line_of(m)
		return "%s: %s" % [a["name"], a["desc"] % [str(fl["levels"]), "%d%%" % int(round(float(fl["off"]) * 100.0))]]
	var v := _ability_strength(m)
	var val: String = ("%d%%" % int(round(v * 100.0))) if a["kind"] == "discount" else (str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v)
	return "%s: %s" % [a["name"], a["desc"] % val]


## Level progress 0 (Lv1) .. 1 (Lv50), for the Lv1 .. Lv50 signature ranges.
static func _lvk(m: Dictionary) -> float:
	return (int(m.get("level", 1)) - 1) / float(maxi(1, Data.MAX_MANAGER_LEVEL - 1))


## v0.19t Yuki's Flash Polish: cars it covers (10 at Lv1 .. 20 at Lv50, +2 with ability_plus).
static func flash_polish_cars(m: Dictionary) -> int:
	return int(round(lerpf(Data.FLASH_POLISH_CARS[0], Data.FLASH_POLISH_CARS[1], _lvk(m)))) + (2 if has_perk(m, "ability_plus") else 0)


## v0.19t Lukas's Training Day: extra levels every bay works at (10 at Lv1 .. 25 at Lv50).
static func training_day_levels(m: Dictionary) -> int:
	return int(round(lerpf(Data.TRAINING_DAY_LEVELS[0], Data.TRAINING_DAY_LEVELS[1], _lvk(m))))


## v0.19t Gazza's Foam Cannon: x3 .. x5 on his bay and the bays either side while it runs (1 = none).
func foam_cannon_mult(i: int) -> float:
	if _ignore_abilities:
		return 1.0
	var best := 1.0
	for j in [i - 1, i, i + 1]:
		if j < 0 or j >= bays.size():
			continue
		var m := manager_at("bay%d" % j)
		if not m.is_empty() and str(m.get("ability", "")) == "foam_cannon" and ability_active(m):
			best = maxf(best, _ability_strength(m))
	return best


## v0.19t Lukas's Training Day running anywhere in this city: extra levels for every bay (0 = none).
func training_bonus() -> int:
	if _ignore_abilities:
		return 0
	var best := 0
	for k in _assigned.keys():
		var m: Dictionary = _assigned[k]
		if str(m.get("ability", "")) == "training_day" and ability_active(m):
			best = maxi(best, training_day_levels(m))
	return best


## v0.19t Yuki's Flash Polish running at this bay (with cars left).
func flash_polish_at(i: int) -> Dictionary:
	if _ignore_abilities:
		return {}
	var m := manager_at("bay%d" % i)
	if m.is_empty() or str(m.get("ability", "")) != "flash_polish" or not ability_active(m) or int(m.get("flash_left", 0)) <= 0:
		return {}
	return m


static func mates_rates_levels(m: Dictionary) -> int:
	return int(round(lerpf(Data.MATES_RATES_LEVELS[0], Data.MATES_RATES_LEVELS[1], _lvk(m)))) + (2 if has_perk(m, "ability_plus") else 0)


## Free levels left on this station from Jono's Mate's Rates (0 = none).
func free_levels(key: String) -> int:
	var m := manager_at(key)
	if m.is_empty() or str(m.get("ability", "")) != "mates_rates" or not ability_active(m):
		return 0
	return int(m.get("free_levels", 0))


## A trip-, car- or level-counted signature is used up: it ends now and its recharge starts.
func _end_signature(m: Dictionary) -> void:
	m["active_until"] = now
	m["ready_at"] = now + ability_cooldown(m)


## v0.19q Marco's Convoy: trips it gives (5 at Lv1 .. 8 at Lv50, +1 with the ability_plus perk).
static func convoy_trips(m: Dictionary) -> int:
	var k := (int(m.get("level", 1)) - 1) / float(maxi(1, Data.MAX_MANAGER_LEVEL - 1))
	return int(round(lerpf(Data.CONVOY_TRIPS[0], Data.CONVOY_TRIPS[1], k))) + (1 if has_perk(m, "ability_plus") else 0)


## The Convoy manager at this city's valet while trips are left, else {}.
func convoy() -> Dictionary:
	var m := manager_at("valet")
	if m.is_empty() or str(m.get("ability", "")) != "convoy" or not ability_active(m) or int(m.get("convoy_left", 0)) <= 0:
		return {}
	return m


## What's left of a running ability: "5 trips" for a Convoy, else the time.
func ability_left_text(m: Dictionary) -> String:
	match str(m.get("ability", "")):
		"showstopper":
			return "next car"
		"mates_rates":
			return "%d free" % int(m.get("free_levels", 0))
		"tow_truck":
			return "next trip"
		"flash_polish":
			var fl := int(m.get("flash_left", 0))
			return "%d car%s" % [fl, "" if fl == 1 else "s"]
		"referral":
			return "next rare car"
	if str(m.get("ability", "")) == "convoy":
		var n := int(m.get("convoy_left", 0))
		return "%d trip%s" % [n, "" if n == 1 else "s"]
	return fmt_time(float(m["active_until"]) - now)


## How long an ability lasts, for the manager panels: "5 trips" or "1m 30s".
func ability_length_text(m: Dictionary) -> String:
	match str(m.get("ability", "")):
		"clear_lot":
			return "instant"
		"showstopper":
			return "1 car"
		"mates_rates":
			return "%d levels" % mates_rates_levels(m)
		"tow_truck":
			return "1 trip"
		"flash_polish":
			return "%d cars" % flash_polish_cars(m)
		"referral":
			return "instant"
	if str(m.get("ability", "")) == "convoy":
		return "%d trips" % convoy_trips(m)
	return fmt_time(ability_duration(m))


## v0.19o: Kev's Shortcut is running at this city's valet.
func shortcut_active() -> bool:
	var m := manager_at("valet")
	return not m.is_empty() and str(m.get("ability", "")) == "shortcut" and ability_active(m)


## v0.19o: Priya's Finish Line running at this city's desk: {"levels": window, "off": 0.5..0.7}, or {}.
func finish_line() -> Dictionary:
	if _ignore_abilities:
		return {}
	var m := manager_at("desk")
	if m.is_empty() or str(m.get("ability", "")) != "finish_line" or not ability_active(m):
		return {}
	return finish_line_of(m)


static func finish_line_of(m: Dictionary) -> Dictionary:
	var k := (int(m.get("level", 1)) - 1) / float(maxi(1, Data.MAX_MANAGER_LEVEL - 1))
	var off := lerpf(Data.FINISH_LINE_DISCOUNT[0], Data.FINISH_LINE_DISCOUNT[1], k) + (0.1 if has_perk(m, "ability_plus") else 0.0)
	return {"levels": int(round(lerpf(Data.FINISH_LINE_LEVELS[0], Data.FINISH_LINE_LEVELS[1], k))), "off": minf(0.9, off)}


## The manager whose Tip Jar is catching bay i's cars right now, or {}.
func _jar_manager(i: int) -> Dictionary:
	var m := manager_at("bay%d" % i)
	if not m.is_empty() and str(m.get("ability", "")) == "tip_jar" and ability_active(m):
		return m
	return {}


## When a Tip Jar's time is up: cash it in (x tip_jar_mult) straight to the wallet it was filled in.
func _tick_tip_jars() -> void:
	for m in roster.values():
		if float(m.get("jar", 0.0)) <= 0.0 or ability_active(m):
			continue
		var pay: float = float(m["jar"]) * tip_jar_mult(m)
		var wid: String = str(m.get("jar_country", ""))
		if wid == "":
			wid = country
		m["jar"] = 0.0
		if wid == country:
			_earn(pay)
		else:
			wallets[wid] = wallets.get(wid, 0.0) + pay
			lifetime_earned += pay
		tip_jar_paid.emit(str(m["assigned"]) if m["city"] == active_city else "", pay, tip_jar_mult(m))


func ability_active(m: Dictionary) -> bool:
	return not m.is_empty() and now < float(m["active_until"])


func ability_ready(m: Dictionary) -> bool:
	return not m.is_empty() and now >= float(m["ready_at"])


func activate_ability(key: String) -> void:
	var m := manager_at(key)
	if m.is_empty() or not ability_ready(m):
		return
	m["active_until"] = now + ability_duration(m) * (1.0 + skill("ability_duration"))
	var lk := _lvk(m)
	match str(m.get("ability", "")):
		"convoy":
			# v0.19q: counted in trips; it ends (and starts recharging) when the last convoy trip unloads
			m["convoy_left"] = convoy_trips(m)
			m["active_until"] = now + 3600.0
		"clear_lot":   # v0.19r Shazza: the whole pickup lot, checked out now
			var mult := lerpf(Data.CLEAR_LOT_MULT[0], Data.CLEAR_LOT_MULT[1], lk)
			var pay: float = float(desk["lot"]) * mult
			desk["lot"] = 0.0
			_earn(pay)
			signature_popped.emit(key, "+%s  LOT CLEARED x%s!" % [money(pay), str(snappedf(mult, 0.1)).trim_suffix(".0")])
		"showstopper":   # v0.19r Tash: until her bay's next car is done
			m["show_next"] = true
			m["active_until"] = now + 3600.0
		"mates_rates":   # v0.19r Jono: until the free levels are bought
			m["free_levels"] = mates_rates_levels(m)
			m["active_until"] = now + 3600.0
		"tow_truck":   # v0.19r Mick: until the next trip (one that starts now or later) unloads
			m["tow_wait"] = true
			m["active_until"] = now + 3600.0
		"flash_polish":   # v0.19t Yuki: counted in cars
			m["flash_left"] = flash_polish_cars(m)
			m["flash_paid"] = 0.0
			m["active_until"] = now + 3600.0
		"foam_cannon":   # v0.19t Gazza
			var bi := bay_index(key)
			var lo := maxi(0, bi - 1) + 1
			var hi := mini(bays.size() - 1, bi + 1) + 1
			signature_popped.emit(key, "FOAM CANNON!  Bays %d-%d x%d" % [lo, hi, int(_ability_strength(m))])
		"training_day":   # v0.19t Lukas
			signature_popped.emit(key, "TRAINING DAY!  Every bay +%d levels" % training_day_levels(m))
		"referral":   # v0.19t Rosa: a rare car now, or right after the one that's here
			if vip.is_empty() and not bays.is_empty():
				spawn_vip()
				m["active_until"] = now + 2.0
				signature_popped.emit(key, "REFERRAL!  A rare car is on its way")
			else:
				m["referral_wait"] = true
				m["active_until"] = now + 3600.0
				signature_popped.emit(key, "REFERRAL!  A rare car comes next")
	m["ready_at"] = float(m["active_until"]) + ability_cooldown(m)
	state_changed.emit()


func activate_all_ready() -> int:
	var n := 0
	for key in _assigned.keys():
		if ability_ready(_assigned[key]):
			activate_ability(key)
			n += 1
	return n


func any_ability_ready() -> bool:
	for m in _assigned.values():
		if ability_ready(m):
			return true
	return false


## Multiplier from the station manager's active ability of this kind ("income"/"speed").
func ability_mult(key: String, kind: String) -> float:
	if _ignore_abilities:
		return 1.0
	var m := manager_at(key)
	if not ability_active(m) or ability_def(m)["kind"] != kind:
		return 1.0
	return _ability_strength(m)


func ability_discount(key: String) -> float:
	if _ignore_abilities:
		return 0.0
	var m := manager_at(key)
	if not ability_active(m) or ability_def(m)["kind"] != "discount":
		return 0.0
	return _ability_strength(m)


static func _shared_crew(list: Array) -> bool:
	var common: Array = crews_of(list[0])
	for k in range(1, list.size()):
		var other := crews_of(list[k])
		common = common.filter(func(c): return other.has(c))
	return not common.is_empty()


## Bay manager in the same crew as BOTH the valet and front desk managers.
func bay_crew_bonus(i: int) -> float:
	var mb := manager_at("bay%d" % i)
	var mv := manager_at("valet")
	var md := manager_at("desk")
	if mb.is_empty() or mv.is_empty() or md.is_empty():
		return 1.0
	if not _shared_crew([mb, mv, md]):
		return 1.0
	return 1.0 + (Data.CREW_CHAIN_BONUS - 1.0) * (1.0 + gear_value(mb, "crew"))


## Valet and front desk managers in the same crew.
func pair_crew_bonus() -> float:
	var mv := manager_at("valet")
	var md := manager_at("desk")
	if mv.is_empty() or md.is_empty():
		return 1.0
	if not _shared_crew([mv, md]):
		return 1.0
	return 1.0 + (Data.CREW_PAIR_BONUS - 1.0) * (1.0 + maxf(gear_value(mv, "crew"), gear_value(md, "crew")))


## City-wide bonuses from the managers seated in a city (Shop Boss, Crew Regular)
## and Legendary passives that reach every city (Mirror Finish).
func staff_city_mult(city_id: String) -> float:
	var m := 1.0
	for s in roster.values():
		if not s["owned"] or s["assigned"] == "":
			continue
		if s.get("legend", "") == "mirror":
			m *= 1.0 + float(Data.LEGEND_PASSIVES["mirror"]["value"])
		if s["city"] != city_id:
			continue
		if has_perk(s, "city_income"):
			m *= 1.0 + float(Data.PERKS["city_income"]["value"])
		if has_perk(s, "crew_cars"):
			m *= 1.0 + float(Data.PERKS["crew_cars"]["value"]) * class_share(s["crew"])
	return m


## A Legendary passive of this kind is seated somewhere (any city).
func _legend_anywhere(kind: String) -> bool:
	for s in roster.values():
		if s["owned"] and s["assigned"] != "" and s.get("legend", "") == kind:
			return true
	return false


## A Legendary passive of this kind is seated in the city you're in.
func _legend_here(kind: String) -> bool:
	for s in _assigned.values():
		if s.get("legend", "") == kind:
			return true
	return false


# ================================================================ equipment (crafted)

func equip_def(id: String) -> Dictionary:
	for e in Data.EQUIPMENT:
		if e["id"] == id:
			return e
	return {}


func material_def(id: String) -> Dictionary:
	for m in Data.MATERIALS:
		if m["id"] == id:
			return m
	return {}


## -1 = not crafted yet, else 0 Common / 1 Rare / 2 Epic.
func equip_tier(id: String) -> int:
	return int(equipment.get(id, -1))


## Materials for the next craft/upgrade ({} when it's Epic already).
func next_recipe(id: String) -> Dictionary:
	var t := equip_tier(id) + 1
	var d := equip_def(id)
	if d.is_empty() or t >= Data.EQUIP_TIERS.size():
		return {}
	return d["recipes"][t]


func can_craft(id: String) -> bool:
	var r := next_recipe(id)
	if r.is_empty():
		return false
	for mat in r.keys():
		if int(materials.get(mat, 0)) < int(r[mat]):
			return false
	return true


## Craft the Common, or upgrade it (the item keeps its wearer). Instant.
func craft(id: String) -> bool:
	if not can_craft(id):
		return false
	var r := next_recipe(id)
	for mat in r.keys():
		materials[mat] = int(materials[mat]) - int(r[mat])
		if materials[mat] <= 0:
			materials.erase(mat)
	equipment[id] = equip_tier(id) + 1
	_refresh_bg_rates()
	equipment_changed.emit()
	_after_purchase()
	return true


## Effect of an item at a tier (current tier by default).
func equip_value(id: String, tier: int = -1) -> float:
	if tier < 0:
		tier = equip_tier(id)
	if tier < 0:
		return 0.0
	return float(equip_def(id)["values"][tier])


func equip_text(id: String, tier: int = -1) -> String:
	var d := equip_def(id)
	return str(d["desc"]) % ("%d%%" % int(round(equip_value(id, tier) * 100.0)))


func wearer_of(id: String) -> Dictionary:
	for m in roster.values():
		if m["gear"] == id:
			return m
	return {}


## Put an item on a premium manager you own (moving it off whoever had it).
func equip_item(item_id: String, manager_id: String) -> void:
	var m := manager(manager_id)
	if m.is_empty() or not m["owned"] or equip_tier(item_id) < 0:
		return
	var w := wearer_of(item_id)
	if not w.is_empty():
		w["gear"] = ""
	m["gear"] = item_id
	_refresh_bg_rates()
	equipment_changed.emit()
	_after_purchase()


func unequip(manager_id: String) -> void:
	var m := manager(manager_id)
	if m.is_empty():
		return
	m["gear"] = ""
	_refresh_bg_rates()
	equipment_changed.emit()
	_after_purchase()


## What a manager's gear adds for one effect (0 if none / not that effect).
func gear_value(m: Dictionary, effect: String) -> float:
	if m.is_empty() or not is_premium(m):
		return 0.0
	var g: String = m.get("gear", "")
	if g == "" or equip_tier(g) < 0 or equip_def(g)["effect"] != effect:
		return 0.0
	return equip_value(g)


func gear_at(key: String, effect: String) -> float:
	return gear_value(manager_at(key), effect)


## Global gear (Lanyard, Night Lamp, Blueprints) counts while the wearer works anywhere.
func gear_global(effect: String) -> float:
	var v := 0.0
	for m in roster.values():
		if m["owned"] and m["assigned"] != "":
			v += gear_value(m, effect)
	return v


func add_material(id: String, n: int) -> void:
	if material_def(id).is_empty() or n <= 0:
		return
	materials[id] = int(materials.get(id, 0)) + n
	equipment_changed.emit()


## Testing only (debug builds): materials have no source in the game yet.
func grant_test_materials(n: int = 100) -> void:
	for m in Data.MATERIALS:
		add_material(m["id"], n)
	_after_purchase()


# ================================================================ Hometown Garage

func _new_hometown() -> Dictionary:
	return {"unlocked": false, "runs_done": 0, "claimed": [], "seen": false}


func is_hometown(id: String = "") -> bool:
	return (active_city if id == "" else id) == Data.HOMETOWN_ID


## Unlocks once any city has HOMETOWN_UNLOCK_BAYS bays.
func _check_hometown_unlock() -> void:
	if hometown.get("unlocked", false):
		return
	var any := false
	for id in cities.keys():
		if id != Data.HOMETOWN_ID and cities[id]["bays"].size() >= Data.HOMETOWN_UNLOCK_BAYS:
			any = true
	if id_is_active_with_bays():
		any = true
	if not any:
		return
	hometown["unlocked"] = true
	if not cities.has(Data.HOMETOWN_ID):
		cities[Data.HOMETOWN_ID] = _new_city_state()
	if not wallets.has(Data.HOMETOWN_ID):
		wallets[Data.HOMETOWN_ID] = 0.0
	hometown_changed.emit()


## The active city's bays live in `bays` (its saved dict may be the same array).
func id_is_active_with_bays() -> bool:
	return not is_hometown() and bays.size() >= Data.HOMETOWN_UNLOCK_BAYS


## Bays in the current run (5 / 10 / 15 / 20).
func ht_cap() -> int:
	return Data.HOMETOWN_RUN_BAYS[mini(int(hometown.get("runs_done", 0)), Data.HOMETOWN_RUN_BAYS.size() - 1)]


func ht_run() -> int:
	return int(hometown.get("runs_done", 0)) + 1


func ht_vd_target() -> int:
	return ht_cap() * Data.HOMETOWN_VD_PER_BAY


func ht_stage() -> int:
	return clampi(reno_done(Data.HOMETOWN_ID), 0, Data.HOMETOWN_STAGES.size() - 1)


## Max level of a station (Hometown has run targets; cities go to MAX_LEVEL).
func station_max_level(key: String) -> int:
	if not is_hometown():
		return Data.MAX_LEVEL
	return Data.HOMETOWN_BAY_TARGET if area_of(key) == "bay" else ht_vd_target()


func ht_build_cost(n: int) -> float:
	return Data.HOMETOWN_BUILD_BASE * Data.HOMETOWN_COST_MULT * pow(Data.HOMETOWN_GROWTH, n)


func _ht_city() -> Dictionary:
	return cities.get(Data.HOMETOWN_ID, {})


func ht_bays_built() -> int:
	var c := _ht_city()
	return 0 if c.is_empty() else c["bays"].size()


func ht_reno_bays() -> Array:
	return reno_bays(Data.HOMETOWN_ID)


func ht_reno_needed() -> int:
	return reno_needed(Data.HOMETOWN_ID)


func ht_reno_running() -> bool:
	return reno_running(Data.HOMETOWN_ID)


# ================================================================ renovations (every city)

func _cstate(id: String) -> Dictionary:
	return cities.get(active_city if id == "" else id, {})


## Bay numbers (1-based) that need renovation 1, 2, 3 before they can be built:
## 6, 11, 16 in cities; 1/4, 2/4, 3/4 of the run in Hometown.
func reno_bays(id: String = "") -> Array:
	var cap := ht_cap() if is_hometown(id) else Data.MAX_BAYS
	var out := []
	for k in range(1, 4):
		out.append(int(ceil(cap * k / 4.0)) + 1)
	return out


func reno_done(id: String = "") -> int:
	return int(_cstate(id).get("renos", 0))


## Renovation (1-3) blocking the next bay in a city, or 0.
func reno_needed(id: String = "") -> int:
	var c := _cstate(id)
	if c.is_empty():
		return 0
	var cap := ht_cap() if is_hometown(id) else Data.MAX_BAYS
	var n: int = c["bays"].size() + 1
	if n > cap:
		return 0
	var rb := reno_bays(id)
	for k in rb.size():
		if n == rb[k] and int(c.get("renos", 0)) < k + 1:
			return k + 1
	return 0


func reno_running(id: String = "") -> bool:
	return float(_cstate(id).get("reno_until", 0.0)) > 0.0


## The timer has run out: a lock waits for the player to tap it (v0.17d). Also true for
## renovations that ran out while you were away or in another city.
func reno_ready(id: String = "") -> bool:
	var u := float(_cstate(id).get("reno_until", 0.0))
	return u > 0.0 and now >= u


## Tap the lock: finishes the renovation.
func unlock_renovation(id: String = "") -> bool:
	var cid := active_city if id == "" else id
	if not reno_ready(cid):
		return false
	_complete_reno(cid)
	_after_purchase()
	return true


func reno_left(id: String = "") -> float:
	return maxf(0.0, float(_cstate(id).get("reno_until", 0.0)) - now) if reno_running(id) else 0.0


func reno_name(k: int, id: String = "") -> String:
	if is_hometown(id):
		return str(Data.HOMETOWN_STAGES[clampi(k, 0, 3)]["name"])
	return str(Data.CITY_RENOS[clampi(k - 1, 0, Data.CITY_RENOS.size() - 1)])


## RENO_COST_BUILDS x what the next bay would cost to build there (v0.19k: a city's 1st renovation
## RENO_FIRST_COST_BUILDS x, the "teaching" one).
func reno_cost(id: String = "") -> float:
	var cid := active_city if id == "" else id
	var n: int = _cstate(cid)["bays"].size()
	if is_hometown(cid):
		return ht_build_cost(n) * Data.RENO_COST_BUILDS
	var mult: float = Data.RENO_FIRST_COST_BUILDS if reno_needed(cid) == 1 else Data.RENO_COST_BUILDS
	return float(Data.BAY_BUILD_COSTS[mini(n, Data.BAY_BUILD_COSTS.size() - 1)]) * city_scale(cid) * mult


## Same in every city; Hometown has its own (shorter) timers that grow with the run.
func reno_seconds(k: int, id: String = "") -> float:
	var h: float
	if is_hometown(id):
		h = float(Data.HOMETOWN_RENO_HOURS[k - 1]) * ht_cap() / 20.0
	else:
		h = float(Data.CITY_RENO_HOURS[k - 1])
	return h * 3600.0 * maxf(0.1, 1.0 - gear_global("renovation"))


## Pay for the renovation. When the timer runs out a lock appears; tapping it finishes it.
func start_renovation(id: String = "") -> bool:
	var cid := active_city if id == "" else id
	var c := _cstate(cid)
	var k := reno_needed(cid)
	if k == 0 or reno_running(cid):
		return false
	var cost := reno_cost(cid)
	var wid := country_of(cid)
	if wallets.get(wid, 0.0) < cost:
		return false
	wallets[wid] = wallets[wid] - cost
	c["reno_until"] = now + reno_seconds(k, cid)
	if is_hometown(cid):
		hometown_changed.emit()
	state_changed.emit()
	renovation_started.emit(cid, k)
	_log_milestone("reno_start", "%s renovation %d" % [cid, k])
	_after_purchase()
	return true


func reno_ads_left(id: String = "") -> int:
	var log: Array = _cstate(id).get("ad_log", [])
	return maxi(0, Data.RENO_ADS_PER_HOUR - log.filter(func(t): return now - float(t) < 3600.0).size())


## Ad placeholder (or the no-ads pack): takes RENO_AD_SECONDS off, RENO_ADS_PER_HOUR per hour.
func watch_reno_ad(id: String = "") -> bool:
	var cid := active_city if id == "" else id
	var c := _cstate(cid)
	if not reno_running(cid) or reno_ads_left(cid) <= 0:
		return false
	var log: Array = c.get("ad_log", [])
	log = log.filter(func(t): return now - float(t) < 3600.0)
	log.append(now)
	c["ad_log"] = log
	c["reno_until"] = float(c["reno_until"]) - Data.RENO_AD_SECONDS
	_reno_tick()
	_after_purchase()
	return true


## v0.19i (Hamza): Shine Bucks to finish a running renovation. Always the WHOLE thing (no partial skips), so
## it stays expensive: 1 per RENO_GLOSS_MINUTES left, at least RENO_FINISH_MIN. -1 = nothing running.
func reno_finish_cost(id: String = "") -> int:
	if not reno_running(id) or reno_ready(id):
		return -1
	return maxi(Data.RENO_FINISH_MIN, int(ceil(reno_left(id) / 60.0 / Data.RENO_GLOSS_MINUTES)))


func finish_reno_gloss(id: String = "") -> bool:
	var cid := active_city if id == "" else id
	var g := reno_finish_cost(cid)
	if g < 0 or gloss < g:
		return false
	gloss -= g
	_cstate(cid)["reno_until"] = now - 0.001
	return unlock_renovation(cid)


## Renovations no longer finish by themselves (v0.17d): the player taps the lock
## (unlock_renovation). This just lets the screens know one became ready.
func _reno_tick() -> void:
	for id in cities.keys():
		var c: Dictionary = cities[id]
		var ready := float(c.get("reno_until", 0.0)) > 0.0 and now >= float(c["reno_until"])
		if ready and not c.get("reno_ready_seen", false):
			c["reno_ready_seen"] = true
			if is_hometown(id):
				hometown_changed.emit()
			state_changed.emit()
		elif not ready:
			c["reno_ready_seen"] = false


func _complete_reno(id: String) -> void:
	var c: Dictionary = cities[id]
	c["reno_until"] = 0.0
	c["renos"] = int(c.get("renos", 0)) + 1
	var k: int = c["renos"]
	if is_hometown(id):
		if is_hometown():
			for i in bays.size():
				bays[i]["car"] = _pick_car(i)
		hometown_changed.emit()
	else:
		gloss += Data.RENO_GLOSS
		certs += Data.RENO_CERTS
	_log_milestone("reno_done", "%s renovation %d" % [id, k])
	renovation_done.emit(id, k)
	state_changed.emit()


# ---------------------------------------------------------------- run milestones + rewards

## Every goal of the current run: [{id, name, done, progress, reward}], in order.
func ht_milestones() -> Array:
	var c := _ht_city()
	if c.is_empty():
		return []
	var cap := ht_cap()
	var out := []
	var built: int = c["bays"].size()
	var stages: Array = Data.HOMETOWN_STAGES
	var rb := ht_reno_bays()
	for n in range(2, cap + 1):
		for k in rb.size():
			if rb[k] == n:
				out.append({"id": "reno%d" % (k + 1), "name": "Renovate: " + str(stages[k + 1]["name"]),
					"done": reno_done(Data.HOMETOWN_ID) >= k + 1, "progress": ""})
		out.append({"id": "bay%d" % n, "name": "Build Bay %d" % n, "done": built >= n, "progress": "%d / %d bays" % [built, n]})
	for i in cap:
		var lvl: int = int(c["bays"][i]["level"]) if i < built else 0
		out.append({"id": "max%d" % i, "name": "Bay %d to Lv %d" % [i + 1, Data.HOMETOWN_BAY_TARGET],
			"done": lvl >= Data.HOMETOWN_BAY_TARGET, "progress": ("Lv %d" % lvl) if i < built else "not built"})
	for st in ["valet", "desk"]:
		var lv: int = int(c[st]["level"])
		out.append({"id": st, "name": "%s to Lv %d" % ["Valet" if st == "valet" else "Front Desk", ht_vd_target()],
			"done": lv >= ht_vd_target(), "progress": "Lv %d" % lv})
	var all := out.all(func(m): return m["done"])
	out.append({"id": "run", "name": "FINISH RUN %d" % ht_run(), "done": all, "progress": "%d / %d goals" % [out.filter(func(m): return m["done"]).size(), out.size()]})
	for m in out:
		m["reward"] = ht_reward(m["id"])
		m["claimed"] = hometown["claimed"].has(m["id"])
	return out


func ht_claimable() -> int:
	if not hometown.get("unlocked", false):
		return 0
	return ht_milestones().filter(func(m): return m["done"] and not m["claimed"]).size()


## Rewards grow a little every run and are weighted to the end of the run.
func ht_reward(id: String) -> Dictionary:
	var rm := 1.0 + Data.HT_REWARD_GROWTH * int(hometown.get("runs_done", 0))
	var size := ht_cap() / 5.0
	var commons := ["microfibre", "rubber", "steel"]
	var rares := ["chrome", "compound"]
	if id == "run":
		return {"case": "classified" if ht_cap() >= 15 else "detailed", "certs": int(round(40 * rm * size)),
			"mats": {"chrome": int(round(5 * rm * size)), "compound": int(round(5 * rm * size)),
				"carbon": int(round(2 * rm * size)), "ceramic": int(round(2 * rm * size)), "alcantara": int(round(2 * rm * size))}}
	if id == "valet" or id == "desk":
		return {"certs": int(round(10 * rm)), "mats": {rares[0 if id == "valet" else 1]: int(round(4 * rm * size))}}
	if id.begins_with("reno"):
		var k := int(id.substr(4))
		var r := {"case": "basic", "mats": {rares[k % 2]: int(round(3 * rm))}}
		if k == 1 and not starter_given:
			r["starter"] = true   # your first premium manager (Dazza's dossier)
		return r
	if id.begins_with("max"):
		var i := int(id.substr(3))
		return {"certs": int(round(2 * rm)), "mats": {commons[i % 3]: int(round(3 * rm))}}
	if id.begins_with("bay"):
		var n := int(id.substr(3))
		return {"mats": {commons[n % 3]: int(round(4 * rm))}}
	return {}


static func reward_text(r: Dictionary) -> String:
	var parts := []
	if r.get("starter", false):
		parts.append("Dazza's dossier (your first Premium manager)")
	if r.has("case"):
		for c in Data.CASE_FILES:
			if c["id"] == r["case"]:
				parts.append(str(c["name"]))
	if int(r.get("certs", 0)) > 0:
		parts.append("%d Certs" % int(r["certs"]))
	var mats: Dictionary = r.get("mats", {})
	for id in mats.keys():
		for m in Data.MATERIALS:
			if m["id"] == id:
				parts.append("%d %s" % [int(mats[id]), m["name"]])
	return ", ".join(parts)


func claim_milestone(id: String) -> bool:
	for m in ht_milestones():
		if m["id"] == id and m["done"] and not m["claimed"]:
			_grant_reward(m["reward"])
			hometown["claimed"].append(id)
			hometown_changed.emit()
			_after_purchase()
			return true
	return false


func claim_all_milestones() -> int:
	var n := 0
	for m in ht_milestones():
		if m["done"] and not m["claimed"]:
			_grant_reward(m["reward"])
			hometown["claimed"].append(m["id"])
			n += 1
	if n > 0:
		hometown_changed.emit()
		_after_purchase()
	return n


func _grant_reward(r: Dictionary) -> void:
	if r.get("starter", false):
		_grant_starter()
	if r.has("case"):
		add_case_file(r["case"])
	certs += int(r.get("certs", 0))
	var mats: Dictionary = r.get("mats", {})
	for id in mats.keys():
		add_material(id, int(mats[id]))
	roster_changed.emit()


func ht_run_finished() -> bool:
	return hometown.get("claimed", []).has("run")


## Start the next run: the garage goes back to a dirt lot with more bays to build.
## Managers you hired there are kept (their jobs are freed), like a prestige.
func ht_start_next_run() -> bool:
	if not ht_run_finished():
		return false
	_log_milestone("hometown_run", "Hometown run %d finished" % ht_run())
	hometown["runs_done"] = int(hometown["runs_done"]) + 1
	hometown["claimed"] = []
	cities[Data.HOMETOWN_ID] = _new_city_state()
	wallets[Data.HOMETOWN_ID] = 0.0
	for m in managers + roster.values():
		if m["city"] == Data.HOMETOWN_ID:
			m["city"] = ""
			m["assigned"] = ""
	if is_hometown():
		_load_city(Data.HOMETOWN_ID)
		city_changed.emit()
	_refresh_bg_rates()
	hometown_changed.emit()
	_after_purchase()
	return true


# ================================================================ wardrobe (Gloss crates)

func uniform_def(id: String) -> Dictionary:
	for u in Data.UNIFORMS:
		if u["id"] == id:
			return u
	return {}


func wardrobe_crate_def(id: String) -> Dictionary:
	for c in Data.WARDROBE_CRATES:
		if c["id"] == id:
			return c
	return {}


## 0 = not owned.
func uniform_level(id: String) -> int:
	return int(wardrobe[id]["level"]) if wardrobe.has(id) else 0


func uniform_mult(id: String, level: int = -1) -> float:
	var u := uniform_def(id)
	if u.is_empty():
		return 1.0
	if level < 0:
		level = uniform_level(id)
	if level <= 0:
		return 1.0
	var base: float = Data.UNIFORM_RARITIES[int(u["rarity"])]["base"]
	return 1.0 + base * (1.0 + Data.UNIFORM_LEVEL_STEP * (level - 1))


## Copies needed to go from `level` to the next one (-1 at max).
static func uniform_copies_needed(level: int) -> int:
	return -1 if level >= Data.UNIFORM_MAX_LEVEL else level


## The worn uniform's boost for a station type (1 if none).
func wardrobe_mult(area: String) -> float:
	return uniform_mult(worn.get(area, ""))


func wear_uniform(id: String) -> void:
	if not wardrobe.has(id):
		return
	worn[uniform_def(id)["area"]] = id
	_refresh_bg_rates()
	wardrobe_changed.emit()
	_after_purchase()


## Buy and open a Wardrobe crate. Returns [{id, new, level, leveled}] or [].
func open_wardrobe_crate(id: String) -> Array:
	var c := wardrobe_crate_def(id)
	if c.is_empty() or gloss < int(c["cost"]):
		return []
	gloss -= int(c["cost"])
	var rarities := []
	for k in int(c["items"]):
		var r := _roll_rarity(c["odds"])
		wardrobe_pity += 1
		if wardrobe_pity >= Data.WARDROBE_PITY:
			r = Data.UNIFORM_RARITIES.size() - 1
		if r == Data.UNIFORM_RARITIES.size() - 1:
			wardrobe_pity = 0
		rarities.append(r)
	# guarantee: at least one item of min_rarity or better
	var best: int = rarities.max()
	if best < int(c["min_rarity"]):
		rarities[-1] = int(c["min_rarity"])
	var out := []
	for r in rarities:
		var pool := Data.UNIFORMS.filter(func(u): return int(u["rarity"]) == r)
		var u: Dictionary = pool.pick_random()
		out.append(_add_uniform(u["id"]))
	_refresh_bg_rates()
	wardrobe_changed.emit()
	_after_purchase()
	return out


## A new uniform (worn straight away if it beats what that crew wears) or a
## duplicate that levels the one you have.
func _add_uniform(id: String) -> Dictionary:
	var u := uniform_def(id)
	if not wardrobe.has(id):
		wardrobe[id] = {"level": 1, "copies": 0}
		var area: String = u["area"]
		if not worn.has(area) or uniform_mult(id) > uniform_mult(worn[area]):
			worn[area] = id
		return {"id": id, "new": true, "level": 1, "leveled": false}
	var w: Dictionary = wardrobe[id]
	var before := int(w["level"])
	w["copies"] = int(w["copies"]) + 1
	while int(w["level"]) < Data.UNIFORM_MAX_LEVEL and int(w["copies"]) >= uniform_copies_needed(int(w["level"])):
		w["copies"] = int(w["copies"]) - uniform_copies_needed(int(w["level"]))
		w["level"] = int(w["level"]) + 1
	return {"id": id, "new": false, "level": int(w["level"]), "leveled": int(w["level"]) > before}


# ================================================================ balancing tools (debug builds)

## Writes "play time, real time, kind, text" to user://balance_log.csv (debug builds),
## so a playtest can be compared against the pacing targets.
func _log_milestone(kind: String, text: String) -> void:
	milestone.emit(kind, text)
	if not OS.is_debug_build() or sim_mode:
		return
	var exists := FileAccess.file_exists(BALANCE_LOG_PATH)
	var f := FileAccess.open(BALANCE_LOG_PATH, FileAccess.READ_WRITE if exists else FileAccess.WRITE)
	if f == null:
		return
	if not exists:
		f.store_line("play_time_h,play_time,real_time,kind,what")
	f.seek_end()
	f.store_line("%.3f,%s,%s,%s,%s" % [play_time / 3600.0, fmt_time(play_time), Time.get_datetime_string_from_system(), kind, text])
	f.close()


func balance_log_file() -> String:
	return ProjectSettings.globalize_path(BALANCE_LOG_PATH)


## Fast-forward: as if you'd been away `secs` (timers run down, managers earn).
func debug_skip(secs: float) -> void:
	for id in cities.keys():
		var c: Dictionary = cities[id]
		if float(c.get("reno_until", 0.0)) > 0.0:
			c["reno_until"] = float(c["reno_until"]) - secs
	for b in active_boosters:
		b["until"] = float(b["until"]) - secs
	for k in ad_until.keys():
		ad_until[k] = float(ad_until[k]) - secs
	for m in managers + roster.values():
		m["active_until"] = float(m["active_until"]) - secs
		m["ready_at"] = float(m["ready_at"]) - secs
	_grant_offline(secs)
	collect_offline()
	play_time += secs
	_reno_tick()
	_expire_boosters()
	_log_milestone("skip", "debug skip %s" % fmt_time(secs))
	state_changed.emit()


## Seconds until `cost` is affordable at the current idle income (-1 = never / no income).
func eta(cost: float) -> float:
	if cost <= cash:
		return 0.0
	var inc := idle_income()
	return -1.0 if inc <= 0.0 else (cost - cash) / inc


## Ads aren't in yet. With the no-ads pack (placeholder setting, on by default)
## ad buttons are just free skips; otherwise they say WATCH AD. Both work instantly.
func ad_free() -> bool:
	return bool(settings.get("ad_free", true))


# ================================================================ shop

## Total waiting from time away, in the active country's currency (for quick checks).
var pending_offline_earnings: float:
	get:
		var t := 0.0
		for v in pending_offline.values():
			t += v
		return t


func collect_offline(multiplier: float = 1.0) -> void:
	for cid in pending_offline.keys():
		wallets[cid] = wallets.get(cid, 0.0) + pending_offline[cid] * multiplier
		lifetime_earned += pending_offline[cid] * multiplier
	pending_offline = {}
	pending_offline_seconds = 0.0
	save_game()


func _after_purchase() -> void:
	state_changed.emit()
	save_game()


# ================================================================ offline + lifecycle

func _grant_offline(elapsed: float) -> void:
	if elapsed < MIN_OFFLINE_SECONDS:
		return
	var secs := elapsed   # v0.19v (Hamza): no cap any more (Night Shift is gone): away 3 days = 3 days of money
	last_away_seconds = elapsed
	# your page keeps getting views while you're away
	var f0 := followers
	add_followers((display_followers_per_hour() + decor_followers_per_hour()) * secs / 3600.0)
	last_away_followers = followers - f0
	# sometimes a VIP is waiting in the lot when you come back
	if elapsed >= 1200.0 and first_vip_done and vip.is_empty() and bays.size() >= 2 and randf() < Data.VIP_WELCOME_CHANCE:
		spawn_vip()
	# every city with managers kept earning (at its own average boost over the time away).
	# v0.19v: the city you're in -> Welcome back (x2 with an ad); every other city -> its stash (COLLECT on the map)
	var any := false
	_boost_override = 1.0
	var rates := {}
	for id in cities.keys():
		rates[id] = idle_income() if id == active_city else _compute_city_idle_rate(id) * (1.0 + skill("bg_income"))
	_boost_override = -1.0
	for id in cities.keys():
		var r: float = rates[id] * average_boost(now - secs, now, id) * (1.0 + gear_global("offline"))
		if r <= 0.0:
			continue
		if id == active_city:
			var cid := country_of(id)
			pending_offline[cid] = pending_offline.get(cid, 0.0) + r * secs
			any = true
		else:
			stash[id] = stash_of(id) + r * secs
			lifetime_earned += r * secs
	if not any:
		return
	pending_offline_seconds = secs
	offline_earnings_ready.emit()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED:
			_paused_at = Time.get_unix_time_from_system()
			save_game()
		NOTIFICATION_APPLICATION_RESUMED:
			if _paused_at > 0.0:
				now = Time.get_unix_time_from_system()
				_grant_offline(now - _paused_at)
				_paused_at = 0.0


# ================================================================ save / load

func _city_to_save(c: Dictionary) -> Dictionary:
	var bay_saves := []
	for b in c["bays"]:
		bay_saves.append({"level": b["level"], "ready": b["ready"], "running": b["running"], "progress": b["progress"], "car": b["car"]})
	var v: Dictionary = c["valet"]
	var d: Dictionary = c["desk"]
	return {
		"prestige": c["prestige"],
		"bays": bay_saves,
		"valet": {"level": v["level"]},
		# cars the valet is carrying / desk is processing go back in the lot so nothing is lost
		"desk": {"level": d["level"], "lot": d["lot"] + d["batch"] + v["carried"]},
		"hires": c["hires"],
		"vip": c["vip"],
		"renos": c.get("renos", 0),
		"reno_until": c.get("reno_until", 0.0),
		"ad_log": c.get("ad_log", []),
	}


func _city_from_save(cs: Dictionary) -> Dictionary:
	var c := _new_city_state(clampi(int(cs.get("prestige", 0)), 0, Data.MAX_PRESTIGE))
	var saved_bays: Array = cs.get("bays", [])
	if not saved_bays.is_empty():
		c["bays"] = []
		for b in saved_bays.slice(0, Data.MAX_BAYS):
			var bay := _new_bay(clampi(int(b.get("level", 1)), 1, Data.MAX_LEVEL))
			bay["ready"] = maxf(0.0, float(b.get("ready", 0.0)))
			bay["running"] = bool(b.get("running", false))
			bay["progress"] = clampf(float(b.get("progress", 0.0)), 0.0, 0.999)
			var car := str(b.get("car", ""))
			bay["car"] = car if cars_by_id.has(car) else ""
			bay["sup"] = bool(b.get("sup", false))
			c["bays"].append(bay)
	var v: Dictionary = cs.get("valet", {})
	c["valet"] = _new_valet(clampi(int(v.get("level", 1)), 1, Data.MAX_LEVEL))
	c["valet"]["sup"] = bool(v.get("sup", false))
	var dk: Dictionary = cs.get("desk", {})
	c["desk"] = _new_desk(clampi(int(dk.get("level", 1)), 1, Data.MAX_LEVEL), maxf(0.0, float(dk.get("lot", 0.0))))
	c["desk"]["sup"] = bool(dk.get("sup", false))
	var h: Dictionary = cs.get("hires", {})
	for area in c["hires"].keys():
		c["hires"][area] = int(h.get(area, 0))
	# -1 = older save: worked out from the bays built once everything is loaded
	c["renos"] = clampi(int(cs.get("renos", -1)), -1, 3)
	c["reno_until"] = float(cs.get("reno_until", 0.0))
	c["ad_log"] = []
	for t in cs.get("ad_log", []):
		c["ad_log"].append(float(t))
	var vp: Dictionary = cs.get("vip", {})
	if cars_by_id.has(str(vp.get("id", ""))) and int(vp.get("bay", 99)) < c["bays"].size():
		c["vip"] = {"id": str(vp["id"]), "phase": "bay" if vp.get("phase") == "bay" else "lot",
			"timer": float(vp.get("timer", Data.VIP_LOT_WAIT)), "bay": int(vp["bay"]),
			"progress": clampf(float(vp.get("progress", 0.0)), 0.0, 0.999), "running": bool(vp.get("running", false))}
	return c


## Only the progress part of each named manager (their def comes from Data).
func _roster_to_save() -> Dictionary:
	var out := {}
	for id in roster.keys():
		var m: Dictionary = roster[id]
		if int(m["clues"]) == 0 and not m["owned"]:
			continue
		out[id] = {"clues": m["clues"], "owned": m["owned"], "level": m["level"], "city": m["city"],
			"assigned": m["assigned"], "active_until": m["active_until"], "ready_at": m["ready_at"], "gear": m["gear"],
			"jar": float(m.get("jar", 0.0)), "jar_country": str(m.get("jar_country", "")), "convoy_left": int(m.get("convoy_left", 0)),
			"show_next": bool(m.get("show_next", false)), "free_levels": int(m.get("free_levels", 0)), "tow_wait": bool(m.get("tow_wait", false)),
			"flash_left": int(m.get("flash_left", 0)), "flash_paid": float(m.get("flash_paid", 0.0)), "referral_wait": bool(m.get("referral_wait", false))}
	return out


func save_game() -> void:
	if sim_mode:
		return
	_store_city()
	var city_saves := {}
	for id in cities.keys():
		city_saves[id] = _city_to_save(cities[id])
	var data := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"wallets": wallets,
		"cities": city_saves,
		"active_city": active_city,
		"lifetime_earned": lifetime_earned,
		"pending_offline": pending_offline,
		"managers": managers,
		"next_manager_id": next_manager_id,
		"roster": _roster_to_save(),
		"materials": materials,
		"hometown": hometown,
		"wardrobe": wardrobe,
		"worn": worn,
		"wardrobe_pity": wardrobe_pity,
		"equipment": equipment,
		"case_files": case_files,
		"certs": certs,
		"starter_given": starter_given,
		"city_nudges": city_nudges,
		"wheel_free_at": wheel_free_at,
		"delivery_day": delivery_day, "delivery_count": delivery_count, "cat_treat_day": cat_treat_day, "decor": decor, "shop_name": shop_name,
		"gloss": gloss,
		"followers": followers,
		"book": book,
		"display": display,
		"bought_slots": bought_slots,
		"tiers_done": tiers_done,
		"book_opened": book_opened,
		"settings": settings,
		"play_time": play_time,
		"tutorial_step": tutorial_step,
		"first_vip_done": first_vip_done,
		"book_unseen": book_unseen,
		"book_new": book_new.keys(),
		"boosters": boosters,
		"active_boosters": active_boosters,
		"deals_bought": deals_bought,
		"ad_until": ad_until,
		"stash": stash,
		"perm_boost": perm_boost,
		"tokens": tokens,
		"tokens_bought": tokens_bought,
		"skills": skills,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write save: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data))


## Returns the save timestamp, or 0 if there was no usable save.
func load_game() -> float:
	if not FileAccess.file_exists(SAVE_PATH):
		return 0.0
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return 0.0
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return 0.0
	var d: Dictionary = parsed
	var version := int(d.get("version", 1))

	lifetime_earned = float(d.get("lifetime_earned", 0.0))
	gloss = int(d.get("gloss", Data.START_GLOSS))
	# v0.19v: Night Shift is gone (offline time is never capped now): give back the Shine Bucks it cost
	var ns := clampi(int(d.get("night_shift", 0)), 0, 10)
	for k in ns:
		gloss += int(round(30.0 * pow(1.8, k) / 5.0)) * 5
	followers = maxf(0.0, float(d.get("followers", 0.0)))
	book = {}
	var bk: Dictionary = d.get("book", {})
	for id in bk.keys():
		if cars_by_id.has(id):
			book[id] = int(bk[id])
	bought_slots = clampi(int(d.get("bought_slots", 0)), 0, Data.MAX_BOUGHT_SLOTS)
	tiers_done = []
	for t in d.get("tiers_done", []):
		tiers_done.append(int(t))
	book_opened = bool(d.get("book_opened", true))   # saves from before v0.19k: already playing, nothing changes
	var st: Dictionary = d.get("settings", {})
	for k in ["rare_alerts", "sound", "vibration", "ad_free", "music"]:
		settings[k] = bool(st.get(k, true))
	# v0.19h: these were saved but never loaded (tips came back + the music volume reset on every restart)
	settings["music_volume"] = clampf(float(st.get("music_volume", 0.6)), 0.0, 1.0)
	var seen := {}
	var ts = st.get("tips_seen", {})
	if ts is Dictionary:
		for id in ts:
			if bool(ts[id]):
				seen[str(id)] = true
	settings["tips_seen"] = seen
	play_time = maxf(0.0, float(d.get("play_time", 0.0)))
	first_vip_done = bool(d.get("first_vip_done", not book.is_empty() and Data.VIP_CARS.any(func(c): return book.has(c["id"]))))
	book_new = {}
	for id in d.get("book_new", []):
		if cars_by_id.has(str(id)):
			book_new[str(id)] = true
	book_unseen = not book_new.is_empty()
	display = []
	for id in d.get("display", []):
		if book.has(id) and not display.has(id):
			display.append(id)
	display = display.slice(0, display_slots())

	if version < 5:
		# everything before v0.6 was a single shop: it becomes Lima, Ohio
		wallets = {"usa": float(d.get("cash", 0.0))}
		var legacy := d.duplicate()
		legacy["prestige"] = clampi(int(d.get("workshop", 0)), 0, Data.MAX_PRESTIGE)
		cities = {"lima": _city_from_save(legacy)}
		if version < 2:
			_migrate_v1(d)
	else:
		wallets = {}
		var wl: Dictionary = d.get("wallets", {})
		for c in Data.COUNTRIES + [Data.HOMETOWN_COUNTRY]:
			if wl.has(c["id"]):
				wallets[c["id"]] = maxf(0.0, float(wl[c["id"]]))
		if wallets.is_empty():
			wallets = {"usa": 0.0}
		cities = {}
		var cs: Dictionary = d.get("cities", {})
		for c in Data.COUNTRIES + [Data.HOMETOWN_COUNTRY]:
			for ct in c["cities"]:
				if cs.has(ct["id"]) and wallets.has(c["id"]):
					cities[ct["id"]] = _city_from_save(cs[ct["id"]])
		if cities.is_empty():
			cities = {"lima": _new_city_state()}
		var po: Dictionary = d.get("pending_offline", {})
		for k in po.keys():
			if wallets.has(k):
				pending_offline[k] = float(po[k])

	wardrobe = {}
	var wd: Dictionary = d.get("wardrobe", {})
	for id in wd.keys():
		if not uniform_def(id).is_empty() and typeof(wd[id]) == TYPE_DICTIONARY:
			wardrobe[id] = {"level": clampi(int(wd[id].get("level", 1)), 1, Data.UNIFORM_MAX_LEVEL), "copies": maxi(0, int(wd[id].get("copies", 0)))}
	worn = {}
	var wn: Dictionary = d.get("worn", {})
	for area in Data.MANAGER_AREAS:
		var uid := str(wn.get(area, ""))
		if wardrobe.has(uid) and uniform_def(uid)["area"] == area:
			worn[area] = uid
	wardrobe_pity = maxi(0, int(d.get("wardrobe_pity", 0)))
	hometown = _new_hometown()
	var ht: Dictionary = d.get("hometown", {})
	hometown["unlocked"] = bool(ht.get("unlocked", false)) and cities.has(Data.HOMETOWN_ID)
	hometown["runs_done"] = maxi(0, int(ht.get("runs_done", 0)))
	hometown["seen"] = bool(ht.get("seen", hometown["unlocked"]))
	if cities.has(Data.HOMETOWN_ID) and ht.has("renos"):
		# v0.13 kept Hometown's renovation in the hometown dict
		var hc: Dictionary = cities[Data.HOMETOWN_ID]
		hc["renos"] = clampi(int(ht.get("renos", 0)), 0, 3)
		hc["reno_until"] = float(ht.get("reno_until", 0.0))
		for t in ht.get("ad_log", []):
			hc["ad_log"].append(float(t))
	for id in ht.get("claimed", []):
		hometown["claimed"].append(str(id))
	_init_roster()
	materials = {}
	var mt: Dictionary = d.get("materials", {})
	for id in mt.keys():
		if not material_def(id).is_empty() and int(mt[id]) > 0:
			materials[id] = int(mt[id])
	equipment = {}
	var eq: Dictionary = d.get("equipment", {})
	for id in eq.keys():
		if not equip_def(id).is_empty():
			equipment[id] = clampi(int(eq[id]), 0, Data.EQUIP_TIERS.size() - 1)
	certs = maxi(0, int(d.get("certs", 0)))
	starter_given = bool(d.get("starter_given", false))
	city_nudges = d.get("city_nudges", {})
	wheel_free_at = float(d.get("wheel_free_at", 0.0))
	delivery_day = int(d.get("delivery_day", -1))
	delivery_count = maxi(0, int(d.get("delivery_count", 0)))
	cat_treat_day = int(d.get("cat_treat_day", -1))
	shop_name = str(d.get("shop_name", "")).strip_edges().left(Data.SHOP_NAME_MAX)
	decor = []
	for id in d.get("decor", []):
		if decor_def(str(id)).size() > 0 and not decor.has(str(id)):
			decor.append(str(id))
	case_files = {}
	var cf: Dictionary = d.get("case_files", {})
	for id in cf.keys():
		if not case_def(id).is_empty() and int(cf[id]) > 0:
			case_files[id] = int(cf[id])
	var taken := {}
	if version >= 2:
		managers = []
		for m in d.get("managers", []):
			if typeof(m) != TYPE_DICTIONARY or not Data.MANAGER_AREAS.has(m.get("area", "")):
				continue
			if bool(m.get("premium", false)):
				# v0.10 Gloss-crate managers became Premium: each one is swapped for a Detailed Case File
				case_files["detailed"] = int(case_files.get("detailed", 0)) + 1
				continue
			var mm := {
				"id": int(m.get("id", 0)),
				"name": str(m.get("name", "Manager")),
				"area": m["area"],
				"rarity": clampi(int(m.get("rarity", 0)), 0, Data.RARITIES.size() - 1),
				"ability": str(m.get("ability", "")),
				"crew": _valid_crew(str(m.get("crew", "jdm"))),
				# older saves: every manager was hired in the one shop (Lima)
				"home": str(m.get("home", "lima")),
				"city": str(m.get("city", "lima" if str(m.get("assigned", "")) != "" else "")),
				"assigned": str(m.get("assigned", "")),
				"active_until": float(m.get("active_until", 0.0)),
				"ready_at": float(m.get("ready_at", 0.0)),
			}
			if mm["home"] == "" or not cities.has(mm["home"]):
				mm["home"] = mm["city"] if cities.has(mm["city"]) else "lima"
			_seat_from_save(mm, taken)
			managers.append(mm)
		next_manager_id = maxi(int(d.get("next_manager_id", 1)), managers.size() + 1)
		for mm in managers:
			next_manager_id = maxi(next_manager_id, int(mm["id"]) + 1)
	if version >= 6:
		var rs: Dictionary = d.get("roster", {})
		for id in rs.keys():
			if not roster.has(id) or typeof(rs[id]) != TYPE_DICTIONARY:
				continue
			var src: Dictionary = rs[id]
			var m: Dictionary = roster[id]
			m["clues"] = int(src.get("clues", 0)) & ALL_CLUES
			m["owned"] = bool(src.get("owned", false)) and int(m["clues"]) == ALL_CLUES
			m["level"] = clampi(int(src.get("level", 1)), 1, Data.MAX_MANAGER_LEVEL)
			m["active_until"] = float(src.get("active_until", 0.0))
			m["ready_at"] = float(src.get("ready_at", 0.0))
			m["gear"] = str(src.get("gear", ""))
			m["jar"] = float(src.get("jar", 0.0))
			m["jar_country"] = str(src.get("jar_country", ""))
			m["convoy_left"] = int(src.get("convoy_left", 0))
			m["show_next"] = bool(src.get("show_next", false))
			m["free_levels"] = int(src.get("free_levels", 0))
			m["tow_wait"] = bool(src.get("tow_wait", false))
			m["flash_left"] = int(src.get("flash_left", 0))
			m["flash_paid"] = float(src.get("flash_paid", 0.0))
			m["referral_wait"] = bool(src.get("referral_wait", false))
			m["city"] = str(src.get("city", ""))
			m["assigned"] = str(src.get("assigned", ""))
			if not m["owned"]:
				m["assigned"] = ""
			_seat_from_save(m, taken)
	var worn := {}
	for m in roster.values():
		var g: String = m["gear"]
		if g != "" and (not m["owned"] or not equipment.has(g) or worn.has(g)):
			m["gear"] = ""
		elif g != "":
			worn[g] = true
	# v0.11 briefly had "supervisors": each one becomes a Junior manager again
	for cid in cities.keys():
		var c: Dictionary = cities[cid]
		var stations := []
		for i in c["bays"].size():
			stations.append(["bay%d" % i, c["bays"][i]])
		stations.append(["valet", c["valet"]])
		stations.append(["desk", c["desk"]])
		for stn in stations:
			if bool(stn[1].get("sup", false)):
				var jm := _make_manager(area_of(stn[0]), 0, cid)
				if not taken.has(cid + ":" + stn[0]):
					jm["city"] = cid
					jm["assigned"] = stn[0]
					taken[cid + ":" + stn[0]] = true
				managers.append(jm)
			stn[1].erase("sup")
	if version >= 6:
		tutorial_step = clampi(int(d.get("tutorial_step", TUT_WASH)), 0, TUT_DONE)
	elif version >= 2:
		# older saves: anyone who already has managers has clearly learned the ropes
		tutorial_step = clampi(int(d.get("tutorial_step", TUT_DONE if not managers.is_empty() else TUT_WASH)), 0, TUT_DONE)
	_check_hometown_unlock()
	# older saves: renovations you'd already have passed count as done
	for cid in cities.keys():
		var cc: Dictionary = cities[cid]
		if int(cc.get("renos", 0)) < 0:
			var built: int = cc["bays"].size()
			cc["renos"] = reno_bays(cid).filter(func(b): return b <= built).size()

	boosters = {}
	var bs: Dictionary = d.get("boosters", Data.STARTER_BOOSTERS if version < 5 or not d.has("boosters") else {})
	for id in bs.keys():
		if not booster_def(id).is_empty() and int(bs[id]) > 0:
			boosters[id] = int(bs[id])
	active_boosters = []
	for b in d.get("active_boosters", []):
		if typeof(b) == TYPE_DICTIONARY and not booster_def(str(b.get("id", ""))).is_empty():
			active_boosters.append({"id": str(b["id"]), "mult": float(b.get("mult", 1.0)), "until": float(b.get("until", 0.0))})
	# v0.19v: the ad boost is per city; an older save's one timer carries over to every city
	ad_until = {}
	var au = d.get("ad_until", null)
	if typeof(au) == TYPE_DICTIONARY:
		for k in au.keys():
			ad_until[str(k)] = float(au[k])
	elif float(d.get("ad_boost_until", 0.0)) > 0.0:
		var cs = d.get("cities", {})
		for k in (cs.keys() if typeof(cs) == TYPE_DICTIONARY else [active_city]):
			ad_until[str(k)] = float(d["ad_boost_until"])
	stash = {}
	var stv = d.get("stash", {})
	if typeof(stv) == TYPE_DICTIONARY:
		for k in stv.keys():
			if float(stv[k]) > 0.0:
				stash[str(k)] = float(stv[k])
	var db: Dictionary = d.get("deals_bought", {}) if typeof(d.get("deals_bought", {})) == TYPE_DICTIONARY else {}
	deals_bought = {"window": int(db.get("window", -1)), "ids": Array(db.get("ids", [])).map(func(x): return str(x))}
	perm_boost = maxf(1.0, float(d.get("perm_boost", 1.0)))
	tokens = {}
	tokens_bought = {}
	skills = {}
	var tk: Dictionary = d.get("tokens", {})
	var tb: Dictionary = d.get("tokens_bought", {})
	for c in Data.COUNTRIES:
		if tk.has(c["id"]):
			tokens[c["id"]] = maxi(0, int(tk[c["id"]]))
		if tb.has(c["id"]):
			tokens_bought[c["id"]] = maxi(0, int(tb[c["id"]]))
	var sk: Dictionary = d.get("skills", {})
	for id in sk.keys():
		if _skill_nodes.has(id):
			skills[id] = clampi(int(sk[id]), 0, int(_skill_nodes[id]["max"]))
	_rebuild_skill_cache()
	display = display.slice(0, display_slots())

	var want := str(d.get("active_city", "lima"))
	_load_city(want if cities.has(want) else cities.keys()[0])
	return float(d.get("saved_at", 0.0))


## v0.2 had a "stance" crew; it became the 4x4 crew.
func _valid_crew(c: String) -> String:
	for cr in Data.CREWS:
		if cr["id"] == c:
			return c
	return "offroad"


## Keep a saved job only if that city/station exists and nobody else has it.
func _seat_from_save(m: Dictionary, taken: Dictionary) -> void:
	var city: String = m["city"]
	var key: String = m["assigned"]
	if key == "" or not cities.has(city) or taken.has(city + ":" + key) or area_of(key) != m["area"] \
			or (m["area"] == "bay" and bay_index(key) >= cities[city]["bays"].size()):
		m["assigned"] = ""
		m["city"] = ""
		return
	taken[city + ":" + key] = true


## v0.1 saves had service picks and "detailers". Keep cash and bay count;
## every bay that had a detailer gets a free Junior manager, plus valet + desk.
func _migrate_v1(d: Dictionary) -> void:
	var old_bays: Array = d.get("bays", [])
	var c := _new_city_state()
	c["bays"] = []
	managers = []
	var any_staffed := false
	for b in old_bays.slice(0, Data.MAX_BAYS):
		c["bays"].append(_new_bay())
		if bool(b.get("staffed", false)):
			var m := _make_manager("bay", 0, "lima")
			m["city"] = "lima"
			m["assigned"] = "bay%d" % (c["bays"].size() - 1)
			managers.append(m)
			any_staffed = true
	if c["bays"].is_empty():
		c["bays"] = [_new_bay()]
	cities = {"lima": c}
	tutorial_step = TUT_DONE if any_staffed else TUT_WASH
	if any_staffed:
		for area in ["valet", "desk"]:
			var m := _make_manager(area, 0, "lima")
			m["city"] = "lima"
			m["assigned"] = area
			managers.append(m)


func reset_save() -> void:
	_reset_state()
	save_game()
	city_changed.emit()
	state_changed.emit()


# ================================================================ formatting

## 1.23K, 4.5M, 6B, 7T, then aa, ab ... az, ba ... for really big numbers.
static func fmt(n: float) -> String:
	if n < 1000.0:
		if n < 10.0 and not is_equal_approx(n, floorf(n)):
			return "%.1f" % n
		return str(int(floorf(n)))
	var tier := 0
	while n >= 1000.0 and tier < 700:
		n /= 1000.0
		tier += 1
	var num: String
	if n < 10.0:
		num = "%.2f" % n
	elif n < 100.0:
		num = "%.1f" % n
	else:
		num = str(int(n))
	return num + suffix(tier)


static func suffix(tier: int) -> String:
	if tier < SUFFIXES.size():
		return SUFFIXES[tier]
	var k := tier - SUFFIXES.size()   # 0 -> aa, 1 -> ab, 26 -> ba
	return char(97 + (k / 26) % 26) + char(97 + k % 26)


static func fmt_time(seconds: float) -> String:
	var s := int(maxf(seconds, 0.0))
	if s < 60:
		return "%ds" % s
	if s < 3600:
		return "%dm %ds" % [s / 60, s % 60]
	return "%dh %dm" % [s / 3600, (s % 3600) / 60]


static func class_color(cl: String) -> Color:
	for c in Data.CREWS:
		if c["id"] == cl:
			return Color(c["color"])
	return Color.GRAY
