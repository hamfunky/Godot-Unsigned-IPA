extends Control
## The front desk at the top of the shop. Cars the valet brings up wait in the
## pickup lot; cashiers hand keys back and take payment. Only this makes cash.

signal level_pressed(key: String)
signal manager_pressed(key: String)
signal sign_pressed   # tap the shop sign = premises / prestige panel
signal parcel_pressed  # v0.19t: tap today's Daily Delivery parcel in the pickup lot

const PARCEL := Rect2(138, 160, 62, 56)   # v0.19t: where the parcel sits (and its tap area), row coords

const Art = preload("res://scripts/car_view.gd")
const Data = preload("res://scripts/game_data.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")
const Portrait = preload("res://scripts/station_manager.gd")   # standing manager (v0.17d)
const LevelButton = preload("res://scripts/level_button.gd")
const AbilityIcon = preload("res://scripts/ability_icon.gd")
const Scenery = preload("res://scripts/scenery.gd")
const CashierRig = preload("res://scripts/cashier_rig.gd")    # v0.19e: the front desk cashier (prototype v4)
const CashierAnim = preload("res://scripts/cashier_anim.gd")
const DP = preload("res://scripts/desk_parts.gd")            # v0.19g: the desk art (tools/char/desk_art.py)
const Backdrop = preload("res://scripts/desk_backdrop.gd")   # v0.19g: wall + the showroom window behind her

const HEIGHT := 250.0          # v0.19c zoom (was 196)
const FLOOR_Y := 230.0         # was 178
const COUNTER_H := 44.0
const MAX_CASHIERS := 2        # Hamza 19 Oct: at most 2 drawn (the crew number is only visual), no clutter
const CASHIER_H := 140.0       # px, top of the bun .. soles (she stands behind the counter)

var portrait: Control
var level_btn: Control   # (v0.17h: tips point at it)
var _press_pos := Vector2.ZERO
var _pressing := false
var _lot_colors: Array = []
var _cashiers: Array = []     # CashierAnim per cashier slot
var backdrop: Control         # v0.19g: sky, wall, showroom window (redraws only when the showcase changes)
static var _dtex := {}


const AnimClock = preload("res://scripts/anim_clock.gd")
var _clock := AnimClock.new()   # v0.19w

func _ready() -> void:
	custom_minimum_size = Vector2(0, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS   # cashier part textures
	for k in MAX_CASHIERS:
		_cashiers.append(CashierAnim.new(0.37 + k * 1.71))
	for k in 3:
		_lot_colors.append(Color(Data.CAR_COLORS.pick_random()))

	GameState.signature_popped.connect(_on_sig_pop)
	backdrop = Backdrop.new()
	backdrop.floor_y = FLOOR_Y
	add_child(backdrop)

	portrait = Portrait.new()
	portrait.station_key = "desk"
	portrait.show_state = false   # the ability icon above shows the ability state
	portrait.position = Vector2(222, 98)
	portrait.size = Vector2(84, FLOOR_Y - 98 + 2)
	portrait.pressed.connect(func(): manager_pressed.emit("desk"))
	add_child(portrait)

	var ab := AbilityIcon.new()
	ab.station_key = "desk"
	ab.position = Vector2(241, 48)     # on the shop wall under the roof trim, above the manager
	ab.size = Vector2(46, 42)
	add_child(ab)

	var lb := LevelButton.new()
	lb.station_key = "desk"
	lb.size = Vector2(96, 112)
	lb.pressed.connect(func(): level_pressed.emit("desk"))
	add_child(lb)
	level_btn = lb
	resized.connect(func(): lb.position = Vector2(size.x - 104, 62))

	GameState.cash_earned.connect(_on_cash)


func _process(delta: float) -> void:
	# v0.19w perf: the cashier moves + the row redraws AnimClock.HZ times a second
	var dt := _clock.tick(delta)
	if dt <= 0.0:
		return
	var cyc := GameState.desk_cycle_time()
	for a in _cashiers:
		a.update(dt, GameState.desk["running"], cyc)
	# v0.19v perf: only while it's on screen
	if is_visible_in_tree() and get_global_rect().intersects(get_viewport_rect().grow(40.0)):
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_press_pos = event.position
		elif _pressing:
			_pressing = false
			var x: float = event.position.x
			if event.position.distance_to(_press_pos) >= 16.0:
				return
			if event.position.y < 52:
				sign_pressed.emit()
			elif PARCEL.grow(8).has_point(event.position) and parcel_showing():
				Sfx.play("tap")
				parcel_pressed.emit()
			elif x < 216 and _vip_waiting():
				GameState.send_vip()
			elif x < 216 or (x > 306 and x < size.x - 108):
				if not GameState.desk["running"] and not GameState.is_automated("desk"):
					Sfx.play("tap")
					Sfx.buzz(10)
				GameState.tap_desk()


## v0.19t: the Daily Delivery parcel is in the lot (not while a rare car's card covers it).
func parcel_showing() -> bool:
	return GameState.delivery_ready() and not _vip_waiting() and GameState.tutorial_step == GameState.TUT_DONE


func _vip_waiting() -> bool:
	return not GameState.vip.is_empty() and GameState.vip["phase"] == "lot"


func _draw() -> void:
	var w := size.x
	var d := GameState.desk
	# (v0.19g: sky, wall, roof trim, floor + the showroom window are the backdrop child, drawn behind this)
	# shop sign board
	var sign := GameState.sign_text()   # v0.19t: the player's own shop name once they've set one
	var nt := Scenery.night_amount()
	if GameState.raining():   # v0.19t rainy day: streaks across the sky strip + a RAINY DAY tag
		Scenery.rain(self, Rect2(0, 0, w, 44), Time.get_ticks_msec() * 0.001, 1.4)
		UiTheme.rounded(self, Rect2(w - 106, 8, 100, 26), Color("4f6f9a"), 10, 2, UiTheme.INK)
		UiTheme.text(self, Vector2(w - 106, 27), "RAIN x%s" % str(Data.RAIN_PAY_MULT), 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 100, 0, UiTheme.DISPLAY_FONT)
	if nt > 0.0:   # v0.19t: at night the sign glows and a row of warm bulbs lights up round it
		Scenery.rr(self, Rect2(w * 0.5 - 258, -1, 516, 42), Color(1, 0.85, 0.45, 0.22 * nt), 16)
	if GameState.has_decor("gold_sign"):   # v0.19t decor: gold trim
		Scenery.rr(self, Rect2(w * 0.5 - 255, 0, 510, 40), Color("ffcf4a"), 14, 3)
		Scenery.rr(self, Rect2(w * 0.5 - 255, 0, 510, 6), Color(1, 1, 1, 0.35), 3)
	Scenery.rr(self, Rect2(w * 0.5 - 250, 3, 500, 34), Color("fff4d6"), 12, 3)
	if nt > 0.0:
		for k in 21:
			var bx := w * 0.5 - 240.0 + k * 24.0
			draw_circle(Vector2(bx, 3), 2.6, Color(1, 0.93, 0.6, nt))
			draw_circle(Vector2(bx, 37), 2.6, Color(1, 0.93, 0.6, nt))
	UiTheme.text(self, Vector2(0, 28), sign, 21, Color("e8553d"), HORIZONTAL_ALIGNMENT_CENTER, w, 0, UiTheme.DISPLAY_FONT)
	if GameState.prestige_ready():
		# a band of light sweeps across the sign: this city can prestige (tap the sign)
		var t := fposmod(Time.get_ticks_msec() * 0.0006, 1.6) - 0.3
		var bx := t * w
		draw_colored_polygon(PackedVector2Array([Vector2(bx - 40, 4), Vector2(bx + 10, 4), Vector2(bx - 20, 50), Vector2(bx - 70, 50)]), Color(1, 1, 0.8, 0.35))
	# (v0.17g: the little prestige stars on the sign are gone; the trophy in the top bar shows it)

	# pickup lot (left): cars the valet brought up, waiting for checkout
	_draw_lot(d)
	if GameState.has_decor("balloons"):
		_draw_balloons()

	if _vip_waiting():
		_draw_vip_card()
	elif parcel_showing():
		_draw_parcel()
	if GameState.has_decor("palms"):
		_draw_palm(Vector2(304, FLOOR_Y - 2), 0.85)

	# counter + cashiers
	var cx0 := 316.0
	var cx1 := w - 112.0
	var working: bool = d["running"]
	# v0.19e: the cashiers (1, then 2 from "Second Cashier"), standing behind the counter, the second one mirrored
	var n := cashier_count()
	for k in n:
		CashierRig.draw(self, Vector2(cashier_x(k, n), FLOOR_Y - 6), CASHIER_H, _cashiers[k].pose(), _cashiers[k].mem,
			1.0 if k == 0 else -1.0)
	# v0.19g: wooden front desk with a marble top; "FRONT DESK" on its brass plate (v0.19f, Hamza: the upgrade
	# tier's name, e.g. "Loyalty Program", meant nothing there)
	_part("counter", Vector2(cx0 - 8, FLOOR_Y - COUNTER_H - 3))
	UiTheme.text(self, Vector2(cx0 - 8 + DP.PLATE.position.x, FLOOR_Y - 13.5), "FRONT DESK", 19, Color("ffe7c2"),
		HORIZONTAL_ALIGNMENT_CENTER, DP.PLATE.size.x, 0, UiTheme.DISPLAY_FONT)
	_draw_checkout(cx0, cx1, d["progress"] if working else 0.0, working)

	if GameState.bottleneck() == "desk" and GameState.bays_total_income() > 0.0:
		UiTheme.alert_mark(self, Vector2(cx1 - 70, 94))     # over the till
	if not GameState.is_automated("desk") and not working and d["lot"] > 0.0:
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)
		UiTheme.text(self, Vector2(cx1 - 160, FLOOR_Y - 52), "TAP!", 30, Color(1, 0.85, 0.2, pulse), HORIZONTAL_ALIGNMENT_CENTER, 160, 6)


## The register on the counter grows with the desk (v0.19g, the old desk tier names made visible):
##   Lv 1 cash tin  ·  Lv 10 + card reader  ·  Lv 50 mint retro cash register  ·  Lv 200 touchscreen POS
static func register_stage(level: int) -> String:
	if level >= 200:
		return "pos"
	if level >= 50:
		return "retro"
	if level >= 10:
		return "card"
	return "tin"


## No progress bar: banded stacks of notes pile up on the counter while she counts, then they slide into
## the register, which opens (tin lid lifts / drawer slides out) and swallows them: that's when you get paid.
func _draw_checkout(x0: float, x1: float, p: float, working: bool) -> void:
	var base := FLOOR_Y - COUNTER_H + 1.0
	var stage := register_stage(int(GameState.desk["level"]))
	var rx := x1 - 50.0
	var closing := working and p > 0.85
	var q := clampf((p - 0.85) / 0.15, 0.0, 1.0)
	var stacks := 0 if not working else mini(int(p / 0.85 * 4.0) + 1, 4)
	for k in stacks:
		var sx := x0 + 30 + k * 38
		var sy := base
		if closing:
			sx = lerpf(sx, rx - 10, q)
			sy -= 10.0 * sin(q * PI)
		_part("cash_stack", Vector2(sx, sy))
	if working and not closing:
		_part("coin_stack", Vector2(x0 + 34 + stacks * 38, base))
	var open := sin(q * PI) if closing else 0.0
	match stage:
		"tin", "card":
			var tx := rx + (-14.0 if stage == "card" else 0.0)
			_part("reg_tin", Vector2(tx, base))
			_part("reg_tin_lid", Vector2(tx, base - 24.0 - 10.0 * open))
			if stage == "card":
				_part("reg_terminal", Vector2(rx + 34, base))
		_:
			if open > 0.0:   # the cash drawer slides out over the counter's side panel
				_part("reg_drawer", Vector2(rx, base - 6.0 + 9.0 * open))
			_part("reg_retro" if stage == "retro" else "reg_pos", Vector2(rx, base))


static func _dt(n: String) -> Texture2D:
	if not _dtex.has(n):
		_dtex[n] = load("res://assets/game/sprites/desk/%s.png" % n)
	return _dtex[n]


func _part(n: String, at: Vector2) -> void:
	var k := 1.0 / DP.RES
	draw_set_transform(at, 0.0, Vector2(k, k))
	draw_texture(_dt(n), -DP.PARTS[n])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## v0.19m polish (was a plain grey box): a little car park. Asphalt with a painted border, 3 marked bays
## with wheel stops (a parked car per bay as money piles up), a blue "P" sign on a post, the name on a
## street-sign plate and what's waiting on a cash tag.
func _draw_lot(d: Dictionary) -> void:
	var r := Rect2(0, 76, 214, FLOOR_Y - 72)
	UiTheme.rounded(self, Rect2(r.position + Vector2(0, 4), r.size), Color("2a2e37"), 12, 3, UiTheme.INK)
	UiTheme.rounded(self, r, Color("4d5360"), 12, 3, UiTheme.INK)
	Scenery.vgrad(self, Rect2(r.position.x + 4, r.position.y + 4, r.size.x - 8, r.size.y - 8), Color("5a6170"), Color("464b57"))
	# speckles in the asphalt (fixed pattern)
	for k in 26:
		var px := 10.0 + fmod(k * 37.3, 196.0)
		var py := 86.0 + fmod(k * 53.7, 140.0)
		draw_circle(Vector2(px, py), 1.4 + fmod(k, 3) * 0.5, Color(1, 1, 1, 0.07) if k % 2 == 0 else Color(0, 0, 0, 0.12))
	# painted border + bay lines + wheel stops
	var by := 156.0
	draw_rect(Rect2(8, by - 4, 198, 3), Color(1, 1, 1, 0.55))
	for x in [8.0, 76.0, 144.0, 205.0]:
		draw_rect(Rect2(x, by - 4, 3, FLOOR_Y - by + 4), Color(1, 1, 1, 0.55))
	var lot: float = d["lot"] + d["batch"]
	var shown := 0 if lot <= 0.0 else clampi(int(log(lot + 1.0) / log(100.0)) + 1, 1, 3)
	for k in 3:
		var bx := 12.0 + k * 68.0
		UiTheme.rounded(self, Rect2(bx + 10, FLOOR_Y - 9, 40, 6), Color("ffd23f"), 3, 2, UiTheme.INK)
		if k < shown:
			draw_set_transform(Vector2(bx + 30, FLOOR_Y - 6), 0.0, Vector2(1.0, 0.22))
			draw_circle(Vector2.ZERO, 30.0, Color(0, 0, 0, 0.28))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			Art.draw_car(self, Rect2(bx - 2, FLOOR_Y - 40, 64, 32), _lot_colors[k], 0.0, [])
	# "P" sign on a post (top right)
	var pc := Vector2(184, 100)
	draw_rect(Rect2(pc.x - 3, pc.y + 14, 6, by - pc.y - 18), Color("9aa3b2"))
	draw_rect(Rect2(pc.x - 3, pc.y + 14, 2, by - pc.y - 18), Color(1, 1, 1, 0.35))
	UiTheme.rounded(self, Rect2(pc.x - 17, pc.y - 15 + 3, 34, 34), Color("174a9c"), 7, 2, UiTheme.INK)
	UiTheme.rounded(self, Rect2(pc.x - 17, pc.y - 17, 34, 34), Color("2f7bf0"), 7, 2, UiTheme.INK)
	UiTheme.rounded(self, Rect2(pc.x - 13, pc.y - 13, 26, 26), Color(1, 1, 1, 0.0), 5, 2, Color.WHITE)
	UiTheme.text(self, Vector2(pc.x - 17, pc.y + 9), "P", 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 34, 0, UiTheme.DISPLAY_FONT)
	# name plate + cash tag
	UiTheme.rounded(self, Rect2(10, 86, 146, 28), Color("1f6f4a"), 8, 2, UiTheme.INK)
	UiTheme.rounded(self, Rect2(13, 89, 140, 22), Color(1, 1, 1, 0.0), 6, 2, Color(1, 1, 1, 0.7))
	UiTheme.text(self, Vector2(10, 107), "PICKUP LOT", 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 146, 0, UiTheme.DISPLAY_FONT)
	var has: bool = float(d["lot"]) > 0.0
	var cash := GameState.money(d["lot"])
	var cw := UiTheme.DISPLAY_FONT.get_string_size(cash, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 22.0
	UiTheme.rounded(self, Rect2(10, 120, cw, 30), Color("2a2e37") if not has else Color("3a3420"), 10, 2, UiTheme.INK)
	UiTheme.text(self, Vector2(10, 143), cash, 22, UiTheme.CASH if has else Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_CENTER, cw, 5, UiTheme.DISPLAY_FONT)
	if GameState.shortcut_active():
		# v0.19o Kev's Shortcut: cars arrive here straight from the bays
		var pulse := 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.008)
		UiTheme.rounded(self, Rect2(r.position + Vector2(0, -2), r.size + Vector2(0, 4)), Color(0, 0, 0, 0.0), 12, 4, Color(0.24, 0.81, 0.35, pulse))
		UiTheme.rounded(self, Rect2(cw + 16, 122, 196 - cw - 10, 26), Color("3ccf5a"), 8, 2, UiTheme.INK)
		UiTheme.text(self, Vector2(cw + 16, 141), "SHORTCUT", 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 196 - cw - 10, 4, UiTheme.DISPLAY_FONT)


## v0.19t: today's Daily Delivery: a taped cardboard box with a red bow; it gives a little hop every few
## seconds so it's noticed, and a gold sparkle twinkles on it (calm, silent).
func _draw_parcel() -> void:
	var ink := UiTheme.INK
	var t := Time.get_ticks_msec() * 0.001
	var ph := fmod(t, 4.0)
	var hop := -10.0 * sin(clampf(ph / 0.45, 0.0, 1.0) * PI) if ph < 0.45 else 0.0
	var c := PARCEL.get_center() + Vector2(0, 10)
	draw_set_transform(Vector2(c.x, PARCEL.end.y - 6), 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, 30.0 + hop * 0.6, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var r := Rect2(c.x - 27, c.y - 18 + hop, 54, 36)
	UiTheme.rounded(self, Rect2(r.position + Vector2(0, 4), r.size), Color("8a5a3b"), 5, 2, ink)
	UiTheme.rounded(self, r, Color("d39a5e"), 5, 2, ink)
	draw_rect(Rect2(r.position.x + 3, r.position.y + 3, r.size.x - 6, 6), Color(1, 1, 1, 0.2))
	draw_rect(Rect2(c.x - 5, r.position.y + 1, 10, r.size.y - 2), Color("e8553d"))
	draw_rect(Rect2(r.position.x + 1, r.get_center().y - 4, r.size.x - 2, 8), Color("e8553d"))
	for sx in [-1.0, 1.0]:   # bow loops
		var lp := PackedVector2Array([Vector2(c.x, r.position.y), Vector2(c.x + sx * 16, r.position.y - 12), Vector2(c.x + sx * 18, r.position.y - 2)])
		draw_colored_polygon(lp, Color("ff6f61"))
		lp.append(lp[0])
		draw_polyline(lp, ink, 2.0, true)
	draw_circle(Vector2(c.x, r.position.y - 1), 4.5, Color("c62828"))
	var tw := 0.5 + 0.5 * sin(t * 3.0)
	UiTheme.sparkle(self, Vector2(r.end.x - 4, r.position.y - 6), 7.0 * tw + 2.0, Color(1, 0.95, 0.6, tw))
	UiTheme.text(self, Vector2(PARCEL.position.x - 20, PARCEL.position.y - 2), "DELIVERY!", 15, Color("ffd23f"), HORIZONTAL_ALIGNMENT_CENTER, PARCEL.size.x + 40, 4)


## v0.19t decor: a potted palm (k = scale, flip = leaning the other way).
func _draw_palm(base: Vector2, k: float, flip := false) -> void:
	var ink := UiTheme.INK
	var sx := -1.0 if flip else 1.0
	var top := base + Vector2(4 * sx, -88) * k
	draw_line(base + Vector2(0, -22) * k, top, ink, 9.0 * k, true)
	draw_line(base + Vector2(0, -22) * k, top, Color("8d6e63"), 5.0 * k, true)
	for a in [-2.6, -2.0, -1.2, -0.6, -0.1]:
		var ang: float = a if not flip else -PI - a
		var tip := top + Vector2(cos(ang), sin(ang) + 0.55) * 40.0 * k
		var mid := top + (tip - top) * 0.5 + Vector2(0, -10) * k
		var leaf := PackedVector2Array([top, mid + Vector2(0, -6) * k, tip, mid + Vector2(0, 5) * k])
		draw_colored_polygon(leaf, Color("43a047"))
		leaf.append(leaf[0])
		draw_polyline(leaf, ink, 2.0, true)
	UiTheme.rounded(self, Rect2(base.x - 15 * k, base.y - 26 * k, 30 * k, 26 * k), Color("e07a3f"), 4, 2, ink)
	draw_rect(Rect2(base.x - 17 * k, base.y - 28 * k, 34 * k, 7 * k), Color("c7642c"))


## v0.19t decor: a bunch of balloons tied to the "P" sign.
func _draw_balloons() -> void:
	var ink := UiTheme.INK
	var t := Time.get_ticks_msec() * 0.001
	var tie := Vector2(196, 96)
	var cols := [Color("ff5a7a"), Color("ffd23f"), Color("4fc3f7"), Color("b07cff")]
	for k in 4:
		var sway := sin(t * 0.9 + k * 1.7) * 3.0
		var bc := tie + Vector2(-14 + k * 10 + sway, -44 - (k % 2) * 12)
		draw_line(tie, bc + Vector2(0, 12), Color(1, 1, 1, 0.7), 1.2, true)
		draw_set_transform(bc, 0.0, Vector2(1.0, 1.2))
		draw_circle(Vector2.ZERO, 10.5, ink)
		draw_circle(Vector2.ZERO, 9.0, cols[k])
		draw_circle(Vector2(-3, -3), 2.6, Color(1, 1, 1, 0.55))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A VIP car waiting in the pickup lot, counting down to its bay.
func _draw_vip_card() -> void:
	var v := GameState.vip
	var car := GameState.car_def(v["id"])
	var rc := Color(Data.VIP_RARITIES[int(car["rarity"])]["color"])
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
	var r := Rect2(4, 72, 206, FLOOR_Y - 76)
	UiTheme.rounded(self, r.grow(3), Color(rc.r, rc.g, rc.b, 0.5 + 0.5 * pulse), 12)
	# v0.17f: bubbly rarity-coloured card with a lip, a pale spotlight behind the car and a ribbon title
	UiTheme.rounded(self, Rect2(r.position + Vector2(0, 5), r.size), rc.darkened(0.55), 12, 3, UiTheme.INK)
	UiTheme.rounded(self, r, rc.darkened(0.2), 12, 3, UiTheme.INK)
	UiTheme.rounded(self, Rect2(r.position.x + 22, r.position.y + 30, r.size.x - 44, 60), Color(1, 1, 1, 0.28), 30)
	var tag: String = "VIP " + Data.VIP_RARITIES[int(car["rarity"])]["name"].to_upper()
	UiTheme.rounded(self, Rect2(r.position.x + 44, r.position.y + 4, r.size.x - 88, 22), UiTheme.CASH, 10, 2, UiTheme.INK)
	UiTheme.text(self, Vector2(r.position.x, r.position.y + 21), tag, 15, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 0)
	Art.draw_car(self, Rect2(r.position.x + 38, r.position.y + 32, 130, 54), Color(car["color"]), 0.0, [], pulse, false, car)
	UiTheme.text(self, Vector2(r.position.x + 4, r.position.y + 112), car["name"], 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 8, 4)
	UiTheme.text(self, Vector2(r.position.x, r.position.y + 138), "Bay %d in %s" % [int(v["bay"]) + 1, GameState.fmt_time(v["timer"])], 17, UiTheme.CASH, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 3)


## How many cashiers are drawn (the desk's crew number, capped at MAX_CASHIERS).
func cashier_count() -> int:
	return clampi(int(GameState.current_boost("desk")["crew"]), 1, MAX_CASHIERS)


## Where cashier k of n stands (x, row coords): behind the counter, clear of the till.
static func cashier_x(k: int, n: int) -> float:
	return 316.0 + (109.0 if n == 1 else [58.0, 138.0][k])


func _on_cash(amount: float) -> void:
	if amount <= 0.0:
		return   # counted an empty lot: nothing to cheer about
	if GameState.is_automated("desk"):
		for a in _cashiers:
			a.smile()   # calm once a manager runs it: just a happy face, no arm pump
		return
	for a in _cashiers:
		a.cheer()
	var l := UiTheme.label("+" + GameState.money(amount), 30, UiTheme.CASH)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	l.position = Vector2(size.x * 0.5 - 20, 140)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", 76.0, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.35)
	tw.chain().tween_callback(l.queue_free)


## v0.19r: a signature's payoff popped over this station.
func _on_sig_pop(st: String, t: String) -> void:
	if st == "desk":
		UiTheme.pop_text(self, t, Vector2(20, 60), Color("ffd23f"), 26)
