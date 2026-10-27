extends Control
## The valet station: top of the lane where the valet parks, plus its manager
## and Level button. The valet car itself is drawn by lane_overlay.gd.

signal level_pressed(key: String)
signal manager_pressed(key: String)

const UiTheme = preload("res://scripts/ui_theme.gd")
const Data = preload("res://scripts/game_data.gd")
const Portrait = preload("res://scripts/station_manager.gd")   # standing manager (v0.17d)
const LevelButton = preload("res://scripts/level_button.gd")
const AbilityIcon = preload("res://scripts/ability_icon.gd")
const Scenery = preload("res://scripts/scenery.gd")
const ShopCat = preload("res://scripts/shop_cat.gd")   # v0.19t

const HEIGHT := 185.0
const LANE_W := 96.0
const BAND_H := 44.0          # v0.19c: slab band on top (name line + ability button), like the bays
const MGR_X := 150.0          # centre of the manager

var portrait: Control
var level_btn: Control   # (v0.17h: tips point at it)
var _press_pos := Vector2.ZERO
var _pressing := false
var cat := ShopCat.new()      # v0.19t: Suds, the shop cat


const AnimClock = preload("res://scripts/anim_clock.gd")
var _clock := AnimClock.new()   # v0.19w

func _ready() -> void:
	custom_minimum_size = Vector2(0, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_make_bg()

	portrait = Portrait.new()
	portrait.station_key = "valet"
	portrait.show_state = false   # the ability icon above shows the ability state
	portrait.position = Vector2(MGR_X - 42, BAND_H + 8)
	portrait.size = Vector2(84, HEIGHT - BAND_H - 8 - 4)
	portrait.pressed.connect(func(): manager_pressed.emit("valet"))
	add_child(portrait)

	GameState.signature_popped.connect(_on_sig_pop)
	var ab := AbilityIcon.new()
	ab.station_key = "valet"
	ab.position = Vector2(MGR_X - 23, 1)
	ab.size = Vector2(46, 42)
	add_child(ab)

	var lb := LevelButton.new()
	lb.station_key = "valet"
	lb.size = Vector2(96, 112)
	lb.pressed.connect(func(): level_pressed.emit("valet"))
	add_child(lb)
	level_btn = lb
	resized.connect(func(): lb.position = Vector2(size.x - 104, BAND_H + (HEIGHT - BAND_H - 112) * 0.5))


func _process(_delta: float) -> void:
	# v0.19v perf: only while it's on screen (it used to redraw every frame wherever you'd scrolled)
	if not is_visible_in_tree() or not get_global_rect().intersects(get_viewport_rect().grow(40.0)):
		return
	_check_bg()
	if _clock.tick(_delta) > 0.0:   # v0.19w perf: AnimClock.HZ times a second
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_press_pos = event.position
		elif _pressing:
			_pressing = false
			var x: float = event.position.x
			if event.position.distance_to(_press_pos) < 16.0 and cat_showing() and cat.rect().grow(6).has_point(event.position):
				_pet_cat()
				return
			if event.position.distance_to(_press_pos) < 16.0 and x < LANE_W and GameState.is_automated("valet"):
				level_pressed.emit("valet")   # v0.17h: tapping the ute (once it runs itself) opens its upgrades
				return
			if event.position.distance_to(_press_pos) < 16.0 and (x < LANE_W or (x > 196 and x < size.x - 108)):
				if GameState.valet["phase"] == "idle" and not GameState.is_automated("valet"):
					Sfx.play("tap")
					Sfx.buzz(10)
				GameState.tap_valet()


## v0.19t: Suds sits on the footpath right of the bushes (only when there's room before the Level button).
func cat_showing() -> bool:
	return size.x - 112.0 - 48.0 >= MGR_X + 360.0


func _pet_cat() -> void:
	Sfx.play("cat")
	Sfx.buzz(15)
	cat.pet(Time.get_ticks_msec())
	var treat := GameState.pet_cat()
	if treat > 0:
		UiTheme.pop_text(self, "+%d {sb}" % treat, cat.pos + Vector2(-120, -96), Color("6fe3a0"), 22)


## v0.19v perf: the forecourt, lane and road don't move: their own layer behind the row, redrawn only when
## something they show changes (size, decor, time of day, rain). The row itself draws the moving bits.
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


func _check_bg() -> void:
	var s := "%d|%s|%d|%s" % [int(size.x), str(GameState.decor), int(Scenery.local_hour() * 12.0), GameState.raining()]
	if s != _bg_sig:
		_bg_sig = s
		_bg.queue_redraw()


func _draw_static(ci: CanvasItem) -> void:
	var w := size.x
	# lane start: a roller door the valet comes out of
	Scenery.lane(ci, LANE_W, HEIGHT)
	Scenery.rr(ci, Rect2(8, 4, LANE_W - 22, 30), Color("9fb0c4"), 6, 3)
	for k in 4:
		ci.draw_rect(Rect2(12, 9 + k * 6, LANE_W - 30, 2), Color("71839a"))
	# forecourt: lawn, hedge, a footpath and the driveway (v0.19c: under the slab band, 1.35x bigger)
	var g0 := BAND_H
	var road := HEIGHT - 32.0
	Scenery.vgrad(ci, Rect2(LANE_W, g0, w - LANE_W, road - g0), Color("8fdc6a"), Color("63c04f"))
	_draw_forecourt(ci, g0, road, w)
	ci.draw_rect(Rect2(LANE_W, road - 7, w - LANE_W, 7), Color("e9e2d0"))
	Scenery.vgrad(ci, Rect2(LANE_W, road, w - LANE_W, HEIGHT - road), Color("4a505c"), Color("3d424d"))
	for x in range(int(LANE_W) + 10, int(w), 70):
		Scenery.rr(ci, Rect2(x, road + 14, 36, 5), Color("f3f3f3"), 2)
	if GameState.raining():   # v0.19t: puddles on the footpath
		for px in [MGR_X + 120.0, MGR_X + 290.0]:
			if px < w - 150.0:
				ci.draw_set_transform(Vector2(px, road - 2.0), 0.0, Vector2(1.0, 0.22))
				ci.draw_circle(Vector2.ZERO, 26.0, Color(0.55, 0.7, 0.9, 0.45))
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# v0.19t: night falls on the forecourt (the phone's clock); the street lamp lights a warm pool
	var nt := Scenery.night_amount()
	if nt > 0.0:
		Scenery.night_wash(ci, Rect2(LANE_W, g0, w - LANE_W, HEIGHT - g0), nt)
		var lx := MGR_X + 160.0
		if lx < w - 132.0:
			Scenery.lamp_glow(ci, Vector2(lx, g0 + 28.0), 70.0, nt)
			Scenery.lamp_glow(ci, Vector2(lx, road + 4.0), 46.0, nt)
			UiTheme.rounded(ci, Rect2(lx - 11, g0 + 20.0, 22, 16), Color(1, 0.95, 0.7, nt), 6, 2, UiTheme.INK)
	Scenery.slab_band(ci, LANE_W, w, BAND_H)


func _draw() -> void:
	var w := size.x
	var g0 := BAND_H
	var road := HEIGHT - 32.0
	var nt := Scenery.night_amount()
	if GameState.has_decor("fountain") and MGR_X + 230.0 <= w - 112.0 - 30.0:
		_draw_fountain(Vector2(MGR_X + 230.0, road - 6))
	if cat_showing():   # v0.19t: Suds (in the dark too at night)
		cat.pos = Vector2(minf(w - 112.0 - 40.0, MGR_X + 410.0), road - 3.0)
		cat.draw(self, Time.get_ticks_msec())
		if nt > 0.0:
			Scenery.night_wash(self, cat.rect().grow(4.0), nt)
	if GameState.raining():
		Scenery.rain(self, Rect2(LANE_W, g0, w - LANE_W, HEIGHT - g0), Time.get_ticks_msec() * 0.001)

	var tool: Dictionary = GameState.current_boost("valet")
	var tx := MGR_X + 34.0
	var f := UiTheme.DISPLAY_FONT
	UiTheme.text(self, Vector2(tx, 31), "VALET", 24, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, f)
	var vw := f.get_string_size("VALET", HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var bad := GameState.bottleneck() == "valet" and GameState.bays_total_income() > 0.0
	var nx := tx + vw + (40.0 if bad else 12.0)
	UiTheme.text(self, Vector2(nx, 30), tool["name"], 20, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_LEFT, -1, 5)
	var cap := "Carries %s / trip" % GameState.money(GameState.valet_capacity())
	var cw := UiTheme.BODY_FONT.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 8.0
	UiTheme.text(self, Vector2(w - 12 - cw, 30), cap, 20, UiTheme.CASH, HORIZONTAL_ALIGNMENT_RIGHT, cw, 6)

	if bad:
		UiTheme.alert_mark(self, Vector2(tx + vw + 20, 22))
	var v := GameState.valet
	if not GameState.is_automated("valet") and v["phase"] == "idle" and GameState._next_ready_floor(0) > 0:
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)
		UiTheme.text(self, Vector2(0, HEIGHT - 16), "TAP!", 24, Color(1, 0.85, 0.2, pulse), HORIZONTAL_ALIGNMENT_CENTER, LANE_W, 5)


## v0.19m polish (was flat lawn + two floating bushes): a trimmed hedge along the back, the valet's key
## podium beside the manager, a street lamp, flower beds and bushes that sit on the ground.
func _draw_forecourt(ci: CanvasItem, g0: float, road: float, w: float) -> void:
	var ink := UiTheme.INK
	var right := w - 112.0   # the Level button lives right of this
	# white picket fence along the back
	var fy := g0 + 8.0
	var fb := g0 + 40.0
	ci.draw_rect(Rect2(LANE_W, fy + 9, w - LANE_W, 6), ink)
	ci.draw_rect(Rect2(LANE_W, fb - 12, w - LANE_W, 6), ink)
	ci.draw_rect(Rect2(LANE_W, fy + 10, w - LANE_W, 4), Color("f4f1ea"))
	ci.draw_rect(Rect2(LANE_W, fb - 11, w - LANE_W, 4), Color("f4f1ea"))
	for x in range(int(LANE_W) + 6, int(w), 22):
		var pk := PackedVector2Array([Vector2(x, fb), Vector2(x, fy + 5), Vector2(x + 6, fy), Vector2(x + 12, fy + 5), Vector2(x + 12, fb)])
		ci.draw_colored_polygon(pk, Color("ffffff"))
		ci.draw_rect(Rect2(x + 8, fy + 6, 3, fb - fy - 6), Color("dcd6cb"))
		pk.append(pk[0])
		ci.draw_polyline(pk, ink, 2.0, true)
	if GameState.has_decor("bunting"):
		_draw_bunting(ci, fy + 2.0, right)
	var hy := fb - 10.0
	# grass ticks
	for k in 8:
		var gx := LANE_W + 40 + k * 64.0
		if gx > right:
			break
		var gy := hy + 30 + (k % 3) * 16
		ci.draw_line(Vector2(gx, gy), Vector2(gx + 4, gy - 9), Color("4fa83f"), 2.5)
		ci.draw_line(Vector2(gx + 7, gy), Vector2(gx + 9, gy - 7), Color("4fa83f"), 2.5)
	# the valet's key podium (right of the manager)
	var px := MGR_X + 66.0
	var pt := road - 64.0
	UiTheme.rounded(ci, Rect2(px - 20, pt + 16, 40, road - pt - 14), Color("8a5a3b"), 4, 2, ink)
	ci.draw_rect(Rect2(px - 16, pt + 22, 4, road - pt - 26), Color(1, 1, 1, 0.15))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(px - 26, pt + 18), Vector2(px + 26, pt + 18), Vector2(px + 22, pt + 4), Vector2(px - 22, pt + 10)]), Color("a06a46"))
	ci.draw_polyline(PackedVector2Array([Vector2(px - 26, pt + 18), Vector2(px + 26, pt + 18), Vector2(px + 22, pt + 4), Vector2(px - 22, pt + 10), Vector2(px - 26, pt + 18)]), ink, 2.0, true)
	UiTheme.rounded(ci, Rect2(px - 14, pt + 28, 28, 20), Color("e8553d"), 4, 2, ink)
	for k in 3:   # little keys hanging on the front
		var kx := px - 8 + k * 8.0
		ci.draw_line(Vector2(kx, pt + 32), Vector2(kx, pt + 38), Color("ffd23f"), 2.0)
		ci.draw_circle(Vector2(kx, pt + 40), 2.6, Color("ffd23f"))
	# street lamp
	var lx := MGR_X + 160.0
	if lx < right - 20:
		var ly := g0 + 22.0
		ci.draw_rect(Rect2(lx - 3, ly + 8, 6, road - ly - 8), ink)
		ci.draw_rect(Rect2(lx - 2, ly + 8, 4, road - ly - 8), Color("4b5566"))
		UiTheme.rounded(ci, Rect2(lx - 9, road - 10, 18, 8), Color("4b5566"), 3, 2, ink)
		ci.draw_circle(Vector2(lx, ly + 6), 18.0, Color(1, 0.95, 0.7, 0.2))
		UiTheme.rounded(ci, Rect2(lx - 11, ly - 2, 22, 16), Color("ffe9a8"), 6, 2, ink)
		UiTheme.rounded(ci, Rect2(lx - 13, ly - 6, 26, 6), Color("4b5566"), 3, 2, ink)
	# flower beds + bushes, sitting on the footpath
	var beds := [MGR_X + 230.0, MGR_X + 330.0]
	for bx in beds:
		if bx > right - 30:
			continue
		if bx == beds[0] and GameState.has_decor("fountain"):
			continue   # (v0.19v: the fountain is drawn in front, it moves)
		ci.draw_set_transform(Vector2(bx, road - 8), 0.0, Vector2(1.0, 0.25))
		ci.draw_circle(Vector2.ZERO, 44.0, Color(0, 0, 0, 0.18))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		Scenery.bush(ci, Vector2(bx, road - 24), 24, Color("3f9e4a"))
		for f in 5:
			var fc := Vector2(bx - 30 + f * 15.0, road - 12 - (f % 2) * 6)
			var col: Color = [Color("ff6fa5"), Color("ffd23f"), Color("ffffff")][f % 3]
			ci.draw_circle(fc, 4.5, ink)
			ci.draw_circle(fc, 3.2, col)


## v0.19t decor: strings of little flags sagging between the fence posts.
func _draw_bunting(ci: CanvasItem, y: float, right: float) -> void:
	var cols := [Color("ff5a5f"), Color("ffd23f"), Color("3ccf5a"), Color("2f9bff"), Color("b07cff")]
	var span := 120.0
	var x0 := LANE_W + 4.0
	var n := 0
	while x0 < right:
		var x1 := minf(x0 + span, right)
		var pts := PackedVector2Array()
		for k in 13:
			var a := k / 12.0
			pts.append(Vector2(lerpf(x0, x1, a), y + sin(a * PI) * 10.0))
		ci.draw_polyline(pts, UiTheme.INK, 2.0, true)
		for k in range(1, 12, 2):
			var a := k / 12.0
			var p := Vector2(lerpf(x0, x1, a), y + sin(a * PI) * 10.0)
			var tri := PackedVector2Array([p + Vector2(-6, 0), p + Vector2(6, 0), p + Vector2(0, 13)])
			ci.draw_colored_polygon(tri, cols[n % cols.size()])
			tri.append(tri[0])
			ci.draw_polyline(tri, UiTheme.INK, 1.6, true)
			n += 1
		x0 = x1


## v0.19t decor: a little stone fountain (two bowls, water arcing gently into the basin).
func _draw_fountain(base: Vector2) -> void:
	var ink := UiTheme.INK
	var stone := Color("d7dde6")
	var water := Color("7fd3ff")
	var t := Time.get_ticks_msec() * 0.001
	draw_set_transform(base, 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, 48.0, Color(0, 0, 0, 0.2))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	UiTheme.rounded(self, Rect2(base.x - 40, base.y - 22, 80, 22), stone, 8, 2, ink)
	UiTheme.rounded(self, Rect2(base.x - 34, base.y - 26, 68, 8), water, 4, 2, ink)
	UiTheme.rounded(self, Rect2(base.x - 6, base.y - 58, 12, 34), stone.darkened(0.08), 3, 2, ink)
	UiTheme.rounded(self, Rect2(base.x - 20, base.y - 64, 40, 10), stone, 5, 2, ink)
	draw_rect(Rect2(base.x - 16, base.y - 64, 32, 3), water)
	# water: two arcs of drops falling from the top bowl, moving along slowly
	for sx in [-1.0, 1.0]:
		for k in 5:
			var a := fmod(t * 0.6 + k / 5.0, 1.0)
			var p := base + Vector2(sx * (12.0 + 22.0 * a), -66.0 - 10.0 * sin(a * PI) + 40.0 * a * a)
			draw_circle(p, 2.4, Color(water.r, water.g, water.b, 0.95))
	draw_circle(base + Vector2(0, -68 - 3.0 * absf(sin(t * 2.0))), 3.0, water)


func _tag(pos: Vector2, s: String, c: Color) -> void:
	UiTheme.rounded(self, Rect2(pos, Vector2(132, 24)), c, 8)
	UiTheme.text(self, pos + Vector2(0, 18), s, 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 132, 0)


## v0.19r: a signature's payoff popped over this station.
func _on_sig_pop(st: String, t: String) -> void:
	if st == "valet":
		UiTheme.pop_text(self, t, Vector2(110, BAND_H + 10), Color("ffd23f"), 26)
