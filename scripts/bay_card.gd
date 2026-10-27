extends Control
## One wash bay as an Idle Miner style strip (v0.19c zoom: about 1.35x bigger than before):
## a concrete SLAB band on top (ability button over the manager, car name + service), then the room:
## [valet lane | key cabinet (finished cars) | manager | detailers + car | Level button]

signal level_pressed(key: String)
signal manager_pressed(key: String)

const Art = preload("res://scripts/car_view.gd")
const Data = preload("res://scripts/game_data.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")
const Portrait = preload("res://scripts/station_manager.gd")   # standing manager (v0.17d)
const LevelButton = preload("res://scripts/level_button.gd")
const AbilityIcon = preload("res://scripts/ability_icon.gd")
const Scenery = preload("res://scripts/scenery.gd")
const KitArt = preload("res://scripts/kit_art.gd")     # v0.19v: the detailed service kit pictures
const CarCache = preload("res://scripts/car_cache.gd")   # v0.19v perf: bay cars from pictures
const AnimClock = preload("res://scripts/anim_clock.gd")   # v0.19w perf: characters at 30 updates a second
const Crew = preload("res://scripts/bay_crew.gd")     # v0.18: the rigged detailers + foam / polish on the car

const HEIGHT := 185.0
const BAND_H := 44.0          # the slab band on top (v0.19c)
const LANE_W := 96.0
const WALL_H := 142.0
const FLOOR_Y := 178.0
const CAR_X := 258.0
const CAR_MAX_W := 272.0      # was 210
const CAR_NUDGE := 14.0       # the car sits a touch right of centre so the left detailer clears the manager
const MGR_X := 208.0          # centre of the manager (and of the ability button above them)

var index := 0
var key := ""

var _portrait: Control
var _ability: Control
var _level_btn: Control
var _car_color := Color.RED
var _specks: Array = []
var _specks_id := 0   # v0.19v: which set of mud spots (part of the dirty picture's key)
var _clock := AnimClock.new()   # v0.19w
var _press_pos := Vector2.ZERO
var _pressing := false
var _crew: RefCounted
var _vip_was := false
var _arrive_at := -10.0       # v0.17g: when the current car started rolling in
var _arrive_dur := 0.0
var fresh := false            # v0.17g: set by main for a bay that was just built (it drops in)
var _born_at := -10.0


func _ready() -> void:
	key = "bay%d" % index
	custom_minimum_size = Vector2(0, HEIGHT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS   # detailer part textures (v0.18)
	_crew = Crew.new(index)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_make_bg()

	_portrait = Portrait.new()
	_portrait.station_key = key
	_portrait.show_state = false   # the ability icon above shows the ability state
	_portrait.position = Vector2(MGR_X - 42, BAND_H + 8)
	_portrait.size = Vector2(84, FLOOR_Y - BAND_H - 8 + 2)
	_portrait.pressed.connect(func(): manager_pressed.emit(key))
	add_child(_portrait)

	# ability button above the portrait (tap = use it); the portrait opens the manager panel
	_ability = AbilityIcon.new()
	_ability.station_key = key
	_ability.position = Vector2(MGR_X - 23, 1)
	_ability.size = Vector2(46, 42)
	add_child(_ability)

	_level_btn = LevelButton.new()
	_level_btn.station_key = key
	_level_btn.size = Vector2(96, 112)
	_level_btn.pressed.connect(func(): level_pressed.emit(key))
	add_child(_level_btn)
	resized.connect(func(): _level_btn.position = Vector2(size.x - 104, BAND_H + (HEIGHT - BAND_H - 112) * 0.5))

	GameState.job_completed.connect(_on_job_completed)
	GameState.tip_jar_paid.connect(_on_tip_jar)
	GameState.signature_popped.connect(_on_sig_pop)
	_new_car(false)
	if fresh:
		_drop_in()


## v0.19v perf: the parts of the bay that don't move, on their own layer behind the card. Redrawn only when
## they change (premises, service tier, width), not every frame.
var _bg: Control
var _bg_sig := ""


func _make_bg() -> void:
	_bg = Control.new()
	_bg.show_behind_parent = true
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.draw.connect(func(): _draw_static(_bg))
	add_child(_bg)
	move_child(_bg, 0)


func _draw_static(ci: CanvasItem) -> void:
	if index >= GameState.bays.size():
		return
	var w := size.x
	var th := Scenery.theme()
	Scenery.lane(ci, LANE_W, HEIGHT)
	Scenery.bay_room(ci, LANE_W, w, WALL_H, FLOOR_Y, HEIGHT, th, BAND_H)
	Scenery.slab_band(ci, LANE_W, w, BAND_H)
	Scenery.number_badge(ci, Vector2(LANE_W * 0.5 - 4, BAND_H + (HEIGHT - BAND_H) * 0.5), index + 1)
	_draw_service_kit(ci, w)
	_draw_wall_shelf(ci, w)


func _check_bg() -> void:
	var s := "%d|%d|%d|%s" % [GameState.prestige, int(size.x), index, str(GameState.current_boost(key).get("level", 0))]
	if s != _bg_sig:
		_bg_sig = s
		_bg.queue_redraw()


func _process(delta: float) -> void:
	if index >= GameState.bays.size():
		return  # row is about to be removed (save was reset)
	# v0.18 perf: a bay scrolled off screen doesn't animate or redraw (all 20 used to redraw every frame)
	if not _on_screen():
		return
	_check_bg()
	# v0.19w perf: the crew, car and foam move + redraw AnimClock.HZ times a second (scrolling stays smooth)
	var dt := _clock.tick(delta)
	if dt <= 0.0:
		return
	var bay: Dictionary = GameState.bays[index]
	var vip_here := GameState.vip_in_bay(index)
	# v0.18: drive the detailers from the job's progress (they only read it)
	var running: bool = GameState.vip["running"] if vip_here else bay["running"]
	var p: float = (float(GameState.vip["progress"]) if vip_here else float(bay["progress"])) if running else 0.0
	var cyc := Data.VIP_JOB_TIME / maxf(0.01, GameState.ability_mult(key, "speed")) if vip_here else GameState.bay_cycle_time(index)
	if _vip_was and not vip_here:
		_crew.job_done(GameState.is_automated(key), cyc)   # the rare car just went: celebrate
	_vip_was = vip_here
	var car_id: String = GameState.vip["id"] if vip_here else bay["car"]
	_crew.update(dt, running, p, cyc, Crew.tier_for(int(bay["level"])), int(GameState.current_boost(key)["crew"]),
		vip_here, _car_rect(), GameState.car_def(car_id))
	queue_redraw()


func _on_screen() -> bool:
	if not is_visible_in_tree():
		return false
	return get_global_rect().intersects(get_viewport_rect().grow(60.0))


## Where the car sits in the strip (before any roll-in offset).
func _car_rect() -> Rect2:
	var area_w := size.x - 108 - CAR_X
	var cw := minf(CAR_MAX_W, area_w * 0.78)
	return Rect2(CAR_X + (area_w - cw) * 0.5 + CAR_NUDGE, FLOOR_Y - cw * 0.45, cw, cw * 0.45)


func _gui_input(event: InputEvent) -> void:
	if index >= GameState.bays.size():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_press_pos = event.position
		elif _pressing:
			_pressing = false
			if event.position.distance_to(_press_pos) < 16.0 and event.position.x < LANE_W:
				# v0.17h: the lane belongs to the valet: a tap runs it, or opens its upgrades once it has a manager
				if GameState.is_automated("valet"):
					level_pressed.emit("valet")
				else:
					if GameState.valet["phase"] == "idle":
						Sfx.play("tap")
					GameState.tap_valet()
				return
			if event.position.distance_to(_press_pos) < 16.0 and event.position.x > CAR_X - 10 and event.position.x < size.x - 108:
				var was_idle: bool = not GameState.bays[index]["running"] and not GameState.is_automated(key)
				GameState.tap_bay(index)
				if was_idle:
					Sfx.play("tap")
					Sfx.buzz(10)


func _draw() -> void:
	if index >= GameState.bays.size():
		return
	var w := size.x
	var bay: Dictionary = GameState.bays[index]

	# (v0.19v perf: the lane, room, slab band, number, service kit + shelf are the _bg layer, drawn only
	# when they change: see _draw_static)
	_draw_key_cabinet(bay["ready"])
	_draw_tip_jar()

	var vip_here := GameState.vip_in_bay(index)
	var car_id: String = GameState.vip["id"] if vip_here else bay["car"]
	var cdef: Dictionary = GameState.car_def(car_id)
	var running: bool = GameState.vip["running"] if vip_here else bay["running"]

	if vip_here:
		# VIP: gold spotlight on the bay
		var rc := Color(Data.VIP_RARITIES[int(cdef["rarity"])]["color"])
		var glow := 0.25 + 0.12 * sin(Time.get_ticks_msec() * 0.005)
		draw_rect(Rect2(LANE_W, BAND_H, w - LANE_W, HEIGHT - BAND_H), Color(rc.r, rc.g, rc.b, glow))
		draw_rect(Rect2(LANE_W, BAND_H, w - LANE_W, 4), rc)
		draw_rect(Rect2(LANE_W, HEIGHT - 4, w - LANE_W, 4), rc)

	# detailers + car (v0.18: the rigged crew; see bay_crew.gd)
	var car := _car_rect()
	var cw := car.size.x
	var col: Color = Color(cdef["color"]) if vip_here else _car_color
	_crew.draw_behind(self, car, FLOOR_Y)
	if vip_here:
		_draw_red_carpet(car)
	# v0.17g: the next car rolls in from the right (skipped when the bay is too quick for it)
	var cd := car
	var nowt := Time.get_ticks_msec() * 0.001
	if _arrive_dur > 0.0 and nowt - _arrive_at < _arrive_dur:
		var k := clampf((nowt - _arrive_at) / _arrive_dur, 0.0, 1.0)
		var eb := 1.0 + 2.70158 * pow(k - 1.0, 3) + 1.70158 * pow(k - 1.0, 2)   # ease-out-back
		cd.position.x += (1.0 - eb) * 300.0
		for d in 3:   # little dust puffs off the back wheel
			var dk := clampf(k * 1.5 - d * 0.15, 0.0, 1.0)
			draw_circle(Vector2(cd.end.x - 6 + d * 14 + dk * 20, FLOOR_Y - 6 - dk * 10), 7.0 * (1.0 - dk) + 2.0, Color(1, 1, 1, 0.5 * (1.0 - dk)))
	var pv: float = _crew.p_vis
	# v0.19v perf: from a picture drawn once per car (CarCache), not shape by shape every frame
	CarCache.draw(self, cd, cdef, col, _crew.dirt(), _specks, clampf((pv - 0.8) * 5.0, 0.0, 1.0) if not vip_here else 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.01), _specks_id)
	# soap bubbles for the plain hand wash (Quick Wash / very fast bays); the foam cannon tiers draw real foam
	if running and pv < 0.85 and (_crew.tier == 0 or _crew.fast):
		_draw_foam(cd, 1.0 - clampf((pv - 0.6) / 0.25, 0.0, 1.0))
	_crew.draw_on_car(self, cd, cdef)
	if running and pv > 0.7:
		_draw_sparkles(cd, clampf((pv - 0.7) / 0.3, 0.0, 1.0))
	if vip_here:
		_draw_flashes(cd)
	_crew.draw_front(self, car)

	# car name (+ class, + specialist bonus) and the bay's service on the slab band (v0.19c): one line,
	# name on the left, service (or the rare car's pay) on the right
	var svc: Dictionary = GameState.current_boost(key)
	var cls_col := GameState.class_color(cdef["class"])
	var tx := MGR_X + 34.0
	draw_rect(Rect2(tx, 12, 6, 18), cls_col)
	var title: String = cdef["name"]
	if GameState.specialist_mult(index, car_id) > 1.0:
		title += "  x" + str(Data.CREW_SPECIALIST_BONUS)
	var right_txt: String = svc["name"]
	var cotw := not vip_here and car_id == GameState.car_of_week()
	if cotw:
		right_txt = "CAR OF THE WEEK x%d" % int(Data.COTW_PAY_MULT)
	if vip_here:
		right_txt = "%s · pays %s" % [Data.VIP_RARITIES[int(cdef["rarity"])]["name"].to_upper(), GameState.money(GameState.vip_pay())]
	var rfs := 20 if vip_here else 18
	var rw := UiTheme.BODY_FONT.get_string_size(right_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, rfs).x + 8.0
	UiTheme.text(self, Vector2(w - 12 - rw, 30), right_txt, rfs, UiTheme.CASH if vip_here or cotw else Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_RIGHT, rw, 4, UiTheme.DISPLAY_FONT if vip_here or cotw else null)
	UiTheme.text(self, Vector2(tx + 12, 30), title, 20, Color("ffe082") if vip_here else Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, maxf(60.0, w - 12 - rw - tx - 22), 5, UiTheme.DISPLAY_FONT if vip_here else null)


	# hints for the player before they have a manager
	if not GameState.is_automated(key) and not running:
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)
		UiTheme.text(self, Vector2(car.position.x, car.position.y + 4), "TAP!", 30, Color(1, 0.85, 0.2, pulse), HORIZONTAL_ALIGNMENT_CENTER, cw, 6)

	# crew chain bonus badge
	var bonus := GameState.bay_crew_bonus(index)
	if bonus > 1.0:
		Scenery.rr(self, Rect2(LANE_W + 6, 9, MGR_X - 23 - LANE_W - 12, 26), Color("a259ff"), 12, 2)
		UiTheme.text(self, Vector2(LANE_W + 6, 28), "CREW x%s" % str(bonus), 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, MGR_X - 23 - LANE_W - 12, 4)


## v0.17g: a freshly built bay drops in with a squash and a puff of dust.
func _drop_in() -> void:
	_born_at = Time.get_ticks_msec() * 0.001
	pivot_offset = Vector2(size.x * 0.5 if size.x > 0.0 else 360.0, HEIGHT)
	scale = Vector2(1.0, 0.15)
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(self, "scale", Vector2(1.0, 1.08), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(1.0, 0.96), 0.08)
	tw.tween_property(self, "scale", Vector2.ONE, 0.12)


## Rare car in the bay: a red carpet under it (v0.17g).
func _draw_red_carpet(car: Rect2) -> void:
	var r := Rect2(car.position.x - 30, FLOOR_Y - 8, car.size.x + 60, 12)
	Scenery.rr(self, Rect2(r.position + Vector2(0, 2), r.size), Color(0, 0, 0, 0.25), 4)
	Scenery.rr(self, r, Color("d32f2f"), 4, 2)
	draw_rect(Rect2(r.position.x + 4, r.position.y + 2, r.size.x - 8, 2), Color("ffd54f"))
	draw_rect(Rect2(r.position.x + 4, r.end.y - 4, r.size.x - 8, 2), Color("ffd54f"))


## ... and the odd camera flash going off (paparazzi for the rare car).
func _draw_flashes(car: Rect2) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for k in 2:
		var ph := fposmod(t * 0.9 + k * 0.47 + index * 0.21, 1.0)
		if ph < 0.12:
			var a := 1.0 - ph / 0.12
			var pos := car.position + Vector2(car.size.x * (0.2 + 0.6 * fposmod(floor(t * 0.9 + k * 0.47) * 0.37 + k * 0.5, 1.0)), car.size.y * 0.3)
			draw_circle(pos, 22.0 * a + 6.0, Color(1, 1, 1, 0.35 * a))
			UiTheme.sparkle(self, pos, 16.0 * a + 4.0, Color(1, 1, 0.9, 0.9 * a))


## Soap bubbles drifting up from the bottom of the car (strength 0..1 fades them out).
func _draw_foam(car: Rect2, strength: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for k in 18:   # v0.19u: smaller bubbles, twice as many
		var sd := float(k) * 0.618 + float(index) * 0.37
		var ph := fposmod(t * (0.35 + 0.08 * (k % 3)) + sd, 1.0)
		var x := car.position.x + car.size.x * (0.08 + 0.84 * fposmod(sd * 1.7, 1.0)) + sin(t * 2.0 + k) * 4.0
		var y := car.end.y - 8.0 - ph * car.size.y * 0.75
		var r := (2.8 + float(k % 3) * 1.6) * (0.75 + 0.5 * ph)
		var a := strength * (1.0 - ph * ph)
		if a <= 0.02:
			continue
		draw_circle(Vector2(x, y), r + 1.5, Color(0.45, 0.72, 0.95, a * 0.9))
		draw_circle(Vector2(x, y), r, Color(0.93, 0.98, 1.0, a * 0.85))
		draw_circle(Vector2(x - r * 0.35, y - r * 0.35), r * 0.32, Color(1, 1, 1, a))
	# a fluffy suds line along the sills
	for k in 14:
		var sx := car.position.x + car.size.x * (0.08 + 0.065 * k)
		var sr := 5.0 + 1.8 * sin(t * 3.0 + k * 1.3)
		draw_circle(Vector2(sx, car.end.y - 11 - (k % 2) * 3), sr + 1.2, Color(0.45, 0.72, 0.95, 0.5 * strength))
	for k in 14:
		var sx := car.position.x + car.size.x * (0.08 + 0.065 * k)
		var sr := 5.0 + 1.8 * sin(t * 3.0 + k * 1.3)
		draw_circle(Vector2(sx, car.end.y - 11 - (k % 2) * 3), sr, Color(1, 1, 1, 0.75 * strength))
		draw_circle(Vector2(sx - sr * 0.35, car.end.y - 11 - (k % 2) * 3 - sr * 0.35), sr * 0.28, Color(1, 1, 1, 0.9 * strength))


## Little twinkles on the paint as it gets clean (and a couple more when it's done).
func _draw_sparkles(car: Rect2, amount: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for k in 4:
		var ph := fposmod(t * 1.3 + k * 0.29 + index * 0.13, 1.0)
		var tw := sin(ph * PI)
		var pos := car.position + Vector2(car.size.x * (0.18 + 0.2 * k), car.size.y * (0.25 + 0.18 * (k % 2)))
		UiTheme.sparkle(self, pos, (5.0 + 4.0 * tw) * amount, Color(1, 1, 1, 0.95 * tw * amount))


## v0.19m polish: a small wooden shelf high on the back wall with the bay's products (bottles, a spray
## bottle, a stack of towels), mixed up per bay so the strips don't all look the same. Up high so the car
## and the crew stay clear.
## v0.19u (Hamza: bays all looked the same, but keep it uncluttered): ONE piece of kit on the wall shows the
## bay's current service, toned towards the wall colour so it stays in the background behind the crew + car.
## From Paint Correction on, a soft LED strip runs along the top of the wall too.
func _draw_service_kit(ci: CanvasItem, w: float) -> void:
	var tier := 0
	var lvl := GameState.level_of(key)
	for k in Data.BAY_BOOSTS.size():
		if lvl >= int(Data.BAY_BOOSTS[k]["level"]):
			tier = k
	var th := Scenery.theme()
	var wall := Color(th["wall"])
	if tier >= 4:   # LED strip
		ci.draw_rect(Rect2(LANE_W + 80, BAND_H + 2, w - LANE_W - 200, 3), Color(th["lamp"]).lerp(Color.WHITE, 0.4))
		ci.draw_rect(Rect2(LANE_W + 80, BAND_H + 5, w - LANE_W - 200, 6), Color(Color(th["lamp"]), 0.18))
	# it stands in the middle of the bottle shelf (v0.19v: both ends get covered by the crew / the car).
	# v0.19v (Hamza: "more detailed"): a baked picture per service (scripts/kit_art.gd), toned a touch
	# towards the wall so it stays background
	var sy := BAND_H + 34.0
	var o := Vector2(kit_x(w), sy - KitArt.ART_H * KitArt.GAME_SCALE)   # the middle of the shelf
	var t := KitArt.tex(tier)
	var tone := Color.WHITE.lerp(wall, 0.12)
	if t != null:
		var pad := 4.0 * KitArt.GAME_SCALE   # the bake has a 4 px margin
		ci.draw_texture_rect(t, Rect2(o - Vector2(pad, pad), Vector2(t.get_size()) * KitArt.GAME_SCALE), false, tone)
	else:
		KitArt.draw(ci, tier, o, KitArt.GAME_SCALE)


## v0.19v: where the service kit stands on the shelf (its left edge).
static func kit_x(w: float) -> float:
	return w - 120.0 - 132.0 + 38.0


## Width (px) the service kit takes on the shelf (the bottles go either side of it).
static func kit_width(tier: int) -> float:
	return KitArt.game_width(tier)


func _draw_wall_shelf(ci: CanvasItem, w: float) -> void:
	var ink := UiTheme.INK
	var x1 := w - 120.0
	var x0 := x1 - 132.0
	var sy := BAND_H + 34.0
	UiTheme.rounded(ci, Rect2(x0, sy, x1 - x0, 7), Color("a06a46"), 3, 2, ink)
	for bx in [x0 + 14.0, x1 - 18.0]:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(bx, sy + 7), Vector2(bx + 6, sy + 7), Vector2(bx + 2, sy + 15)]), Color("8a5a3b"))
	var cols := [Color("ff6fa5"), Color("2f9bff"), Color("3ccf5a"), Color("ffd23f"), Color("b07cff"), Color("ff8a3d")]
	var tier := 0
	for k in Data.BAY_BOOSTS.size():
		if GameState.level_of(key) >= int(Data.BAY_BOOSTS[k]["level"]):
			tier = k
	# v0.19v: the service kit stands in the MIDDLE of the shelf now (the right end sat behind the second
	# detailer's head from Full Detail on, the left end behind the car roof + the one wiping it); the
	# products stand either side of it
	var kx := kit_x(w)
	var kw := kit_width(tier)
	var x := x0 + 6.0
	for k in 6:
		if x + 22.0 > kx and x < kx + kw:
			x = kx + kw + 4.0
		var kind := (index * 3 + k * 7) % 4
		var c: Color = cols[(index + k * 2) % cols.size()]
		match kind:
			0, 1:   # bottle
				var bh := 20.0 if kind == 0 else 16.0
				UiTheme.rounded(ci, Rect2(x, sy - bh, 14, bh), c, 4, 2, ink)
				ci.draw_rect(Rect2(x + 4, sy - bh - 5, 6, 6), ink)
				ci.draw_rect(Rect2(x + 3, sy - bh + 5, 8, 5), Color(1, 1, 1, 0.75))
				x += 20.0
			2:      # spray bottle
				UiTheme.rounded(ci, Rect2(x, sy - 17, 13, 17), c, 4, 2, ink)
				UiTheme.rounded(ci, Rect2(x + 2, sy - 25, 14, 8), Color("ececec"), 2, 2, ink)
				ci.draw_line(Vector2(x + 16, sy - 22), Vector2(x + 21, sy - 22), ink, 2.0)
				x += 26.0
			3:      # folded towels
				for t in 3:
					UiTheme.rounded(ci, Rect2(x, sy - 7 - t * 6, 22, 7), c.lightened(0.2 * t), 3, 2, ink)
				x += 28.0
		if x > x1 - 16.0:
			break


func _draw_key_cabinet(ready: float) -> void:
	# v0.19f (Hamza: "you can't tell what it is"): same board, now 3 proper car keys hanging on hooks
	# (split ring, fob with lock/unlock buttons, notched metal blade). More cash waiting = more keys.
	var r := Rect2(LANE_W + 8, BAND_H + 14, 64, 52)
	Scenery.rr(self, Rect2(r.position + Vector2(0, 4), r.size), Color(0, 0, 0, 0.25), 10)
	Scenery.rr(self, r, Color("a86b3c"), 10, 3)
	Scenery.rr(self, r.grow(-6), Color("8a5530"), 6)
	var keys := 0 if ready <= 0.0 else clampi(int(log(ready + 1.0) / log(100.0)) + 1, 1, 3)
	for k in 3:
		var hook := Vector2(r.position.x + 14 + k * 18, r.position.y + 9)
		if k < keys:
			_draw_car_key(hook, KEY_TAGS[k], k)
		draw_circle(hook, 3.2, Scenery.INK)
		draw_circle(hook, 2.0, Color("e8d3b0"))
	UiTheme.text(self, Vector2(LANE_W - 2, BAND_H + 96), GameState.money(ready), 20,
		UiTheme.CASH if ready > 0.0 else Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 84, 6)
	if GameState.shortcut_active():
		# v0.19o Kev's Shortcut: the keys skip the cabinet, a green "TO LOT" tag with an arrow pointing up
		var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.008)
		var tg := Rect2(r.position.x - 4, r.position.y + 18, r.size.x + 8, 24)
		UiTheme.rounded(self, tg, Color(0.24, 0.81, 0.35, pulse), 8, 2, UiTheme.INK)
		UiTheme.text(self, Vector2(tg.position.x, tg.position.y + 18), "TO LOT", 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, tg.size.x, 4, UiTheme.DISPLAY_FONT)
		var ax := r.position.x - 2.0
		var ay := r.position.y + 4.0 - fposmod(Time.get_ticks_msec() * 0.06, 14.0)
		draw_colored_polygon(PackedVector2Array([Vector2(ax, ay), Vector2(ax + 7, ay + 9), Vector2(ax - 7, ay + 9)]), Color("3ccf5a"))


const KEY_TAGS := [Color("ffd23f"), Color("4fc3f7"), Color("ff7a85")]
const KEY_METAL := Color("cfd8dc")
const KEY_FOB := Color("2f3242")


## One car key hanging from a hook: ring, fob (coloured shell, lock/unlock/panic buttons), notched blade (~20 x 40 px).
func _draw_car_key(hook: Vector2, tag: Color, k: int) -> void:
	var ink := Scenery.INK
	var sway := sin(Time.get_ticks_msec() * 0.0012 + k * 1.7) * 0.6
	var top := hook + Vector2(sway, 0)
	# split ring
	var ring := top + Vector2(0, 5)
	draw_arc(ring, 4.6, 0, TAU, 16, ink, 3.6, true)
	draw_arc(ring, 4.6, 0, TAU, 16, KEY_METAL, 1.8, true)
	# fob: dark face in a coloured rubber shell (one colour per key so the three read apart)
	var fob := Rect2(top.x - 7, top.y + 10, 14, 18)
	Scenery.rr(self, fob.grow(3.0), ink, 7)
	Scenery.rr(self, fob.grow(1.6), tag, 6)
	Scenery.rr(self, fob, KEY_FOB, 5)
	draw_rect(Rect2(fob.position.x + 3, fob.position.y + 1.5, fob.size.x - 6, 2), Color(1, 1, 1, 0.22))
	draw_circle(Vector2(fob.position.x + 5, fob.position.y + 7.5), 2.2, Color("8a90a6"))    # lock
	draw_circle(Vector2(fob.end.x - 5, fob.position.y + 7.5), 2.2, Color("8a90a6"))         # unlock
	draw_circle(Vector2(fob.get_center().x, fob.end.y - 5), 2.0, Color("e53935"))           # panic
	# metal blade with a notched edge
	var bx := top.x - 2.5
	var by := fob.end.y + 1.5
	var blade := PackedVector2Array([Vector2(bx, by), Vector2(bx + 5, by), Vector2(bx + 5, by + 11), Vector2(bx + 2.5, by + 13),
		Vector2(bx, by + 11), Vector2(bx, by + 9), Vector2(bx + 1.6, by + 8), Vector2(bx, by + 6), Vector2(bx + 1.6, by + 4.5), Vector2(bx, by + 3)])
	draw_colored_polygon(_grown(blade, 1.3), ink)
	draw_colored_polygon(blade, KEY_METAL)
	draw_line(Vector2(bx + 3.4, by + 1), Vector2(bx + 3.4, by + 10), Color("90a4ae"), 1.0)


## A polygon pushed out from its centre (cheap ink outline for small shapes).
static func _grown(pts: PackedVector2Array, d: float) -> PackedVector2Array:
	var c := Vector2.ZERO
	for q in pts:
		c += q
	c /= pts.size()
	var out := PackedVector2Array()
	for q in pts:
		out.append(q + (q - c).normalized() * d)
	return out


## Wall decoration: a hose reel.
func _draw_hose_reel(c: Vector2) -> void:
	draw_circle(c, 17, Scenery.INK)
	draw_circle(c, 15, Color("ffb74d"))
	draw_arc(c, 10, 0, TAU, 20, Color("2e7d32"), 6, true)
	draw_circle(c, 4, Scenery.INK)
	draw_line(c + Vector2(8, 10), c + Vector2(14, 34), Color("2e7d32"), 4, true)


## Dazza's tip jar next to him (fills up while Tip Jar runs).
func _draw_tip_jar() -> void:
	var m := GameState.manager_at(key)
	if m.is_empty() or str(m.get("ability", "")) != "tip_jar":
		return
	# fills up over the ability's time (empty when it's not running)
	var fill := 0.0
	if GameState.ability_active(m):
		var left := float(m["active_until"]) - GameState.now
		fill = clampf(1.0 - left / maxf(1.0, GameState.ability_duration(m) * (1.0 + GameState.skill("ability_duration"))), 0.05, 1.0)
	var r := Rect2(MGR_X + 30, FLOOR_Y - 42, 30, 38)
	Scenery.rr(self, Rect2(r.position + Vector2(0, 3), r.size), Color(0, 0, 0, 0.25), 9)
	Scenery.rr(self, r, Color(0.85, 0.95, 1.0, 0.45), 9, 2)
	if fill > 0.0:
		var fh := (r.size.y - 8) * fill
		Scenery.rr(self, Rect2(r.position.x + 4, r.end.y - 4 - fh, r.size.x - 8, fh), Color("6fd16a"), 5)
		for k in int(fill * 4.0):
			draw_circle(Vector2(r.position.x + 9 + (k % 2) * 12, r.end.y - 8 - k * 6), 4, Color("ffd23f"))
	draw_rect(Rect2(r.position.x + 3, r.position.y - 5, r.size.x - 6, 7), Color("8d6e63"))
	draw_rect(Rect2(r.position.x + 6, r.position.y + 5, 4, r.size.y - 14), Color(1, 1, 1, 0.45))
	UiTheme.text(self, Vector2(r.position.x - 10, r.position.y - 9), "TIPS", 15, Color("ffd23f"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 20, 4)


## Dazza cashed his jar: a big "+$X TIPS x3!" pops over the bay.
func _on_tip_jar(station: String, amount: float, mult: float) -> void:
	if station != key:
		return
	var l := UiTheme.display_label("+%s  TIPS x%s!" % [GameState.money(amount), str(snappedf(mult, 0.1)).trim_suffix(".0")], 30, Color("ffd23f"))
	l.add_theme_color_override("font_outline_color", UiTheme.INK)
	l.add_theme_constant_override("outline_size", 9)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	l.position = Vector2(220, BAND_H + 20)
	l.pivot_offset = Vector2(120, 20)
	l.scale = Vector2(0.4, 0.4)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2(1.1, 1.1), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.15)
	tw.tween_interval(1.0)
	tw.tween_property(l, "position:y", 0.0, 0.6)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func _on_job_completed(bay_index: int, amount: float) -> void:
	if bay_index != index:
		return
	_crew.job_done(GameState.is_automated(key), GameState.bay_cycle_time(index))
	if GameState.is_automated(key):
		_new_car()
		return   # no floating numbers once it runs itself (keeps the screen calm)
	var l := UiTheme.label("+" + GameState.money(amount), 22, Color("b9f6ca"))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	l.position = Vector2(LANE_W + 10, BAND_H + 50)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", BAND_H + 10.0, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)
	_new_car()


func _new_car(roll_in: bool = true) -> void:
	_car_color = Color(Data.CAR_COLORS.pick_random())
	_specks = Art.new_specks()
	_specks_id += 1
	if roll_in and index < GameState.bays.size():
		var cyc := GameState.bay_cycle_time(index)
		_arrive_dur = 0.0 if cyc < 0.9 else minf(0.45, cyc * 0.3)
		_arrive_at = Time.get_ticks_msec() * 0.001


## v0.19r: a signature's payoff popped over this station.
func _on_sig_pop(st: String, t: String) -> void:
	if st == key:
		UiTheme.pop_text(self, t, Vector2(120, BAND_H + 18), Color("ffd23f"), 26)
