extends Control
## v0.17g title screen: shows once when the game starts. Big bubbly logo, a shiny car with soap bubbles
## drifting past, "TAP TO PLAY". Tap anywhere and it pops away to the shop (the Welcome back popup, if
## any, is already waiting underneath). Skipped by the autotest.

const UiTheme = preload("res://scripts/ui_theme.gd")
const Data = preload("res://scripts/game_data.gd")
const CarView = preload("res://scripts/car_view.gd")
const CarArt = preload("res://scripts/car_art.gd")
const Scenery = preload("res://scripts/scenery.gd")
const CarCache = preload("res://scripts/car_cache.gd")
const MapPanel = preload("res://scripts/map_panel.gd")

var _car: Dictionary = {}
var _bay_car: Dictionary = {}   # v0.19u: the one being washed inside
var _leaving := false
var _t0 := 0.0
# v0.19w (Hamza): a loading bar first (the shop builds + its car pictures + the world map bake while it fills),
# THEN "TAP TO PLAY"
var _progress := 0.0
var _target := 0.0
var _step := "Opening the shop"
var _loaded := false
var _ready_at := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var best := Data.CARS.filter(func(c): return int(c["tier"]) == 5 and CarArt.BODY.get(c["id"], "") in ["hyper", "gt", "coupe"])
	if best.is_empty():
		best = Data.CARS.filter(func(c): return int(c["tier"]) == 5)
	_car = GameState.car_def((best.pick_random() if not best.is_empty() else Data.CARS[0])["id"])
	_t0 = Time.get_ticks_msec() * 0.001
	var ev := Data.CARS.filter(func(c): return int(c["tier"]) == 2)
	_bay_car = GameState.car_def((ev.pick_random() if not ev.is_empty() else Data.CARS[0])["id"])
	_load.call_deferred()


func _load() -> void:
	var tree := get_tree()
	_target = 0.25
	for k in 3:
		await tree.process_frame
	_step = "Washing the cars"
	var t0 := Time.get_ticks_msec()
	while CarCache.pending() > 0 and Time.get_ticks_msec() - t0 < 3000:
		_target = minf(_target + 0.02, 0.6)
		await tree.process_frame
	_target = 0.65
	_step = "Drawing the map"
	await tree.process_frame
	await MapPanel.prebake(self)
	_target = 1.0
	_step = "Ready!"
	while _progress < 0.995:
		await tree.process_frame
	_loaded = true
	_ready_at = Time.get_ticks_msec() * 0.001


func _process(delta: float) -> void:
	_progress = move_toward(_progress, _target, delta * 1.6)
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if _leaving or not _loaded:
		return
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
		_leaving = true
		Sfx.play("click")
		Sfx.buzz(15)
		pivot_offset = size * 0.5
		var tw := create_tween().set_parallel()
		tw.tween_property(self, "modulate:a", 0.0, 0.3)
		tw.tween_property(self, "scale", Vector2(1.08, 1.08), 0.3).set_ease(Tween.EASE_OUT)
		tw.chain().tween_callback(queue_free)


## v0.19u (Hamza: make it a scene): the sky at the real time of day, your shop from the street (with your shop
## name on the sign and a car being washed inside), the hero car on the forecourt, the logo on top.
func _draw() -> void:
	var s := size
	var t := Time.get_ticks_msec() * 0.001
	var intro := clampf((t - _t0) / 0.6, 0.0, 1.0)
	var nt := Scenery.night_amount()
	var wet := GameState.raining()
	var sky := Scenery.sky_colors(-1.0, wet)
	Scenery.vgrad(self, Rect2(Vector2.ZERO, s), sky[0], sky[1])
	if nt > 0.02:
		for k in 40:
			var p := Vector2(fmod(k * 97.3 + 13.0, s.x), fmod(k * 53.7, s.y * 0.5))
			draw_circle(p, 1.2 + float(k % 3) * 0.6, Color(1, 1, 0.92, nt * 0.8))
		draw_circle(Vector2(s.x * 0.84, s.y * 0.1), 30.0, Color(1, 0.97, 0.82, nt))
		draw_circle(Vector2(s.x * 0.84 + 12, s.y * 0.1 - 8), 26.0, sky[0])
	else:
		draw_circle(Vector2(s.x * 0.84, s.y * 0.1), 46.0, Color(1, 0.95, 0.6, 0.35))
		draw_circle(Vector2(s.x * 0.84, s.y * 0.1), 34.0, Color("ffe066"))
	# slow clouds
	for k in 4:
		var cx := fposmod(k * 260.0 + t * (8.0 + k * 3.0), s.x + 300.0) - 150.0
		Scenery.cloud(self, Vector2(cx, s.y * (0.06 + 0.07 * k)), 26.0 + k * 6.0, 0.8 * (1.0 - nt * 0.6), Color("7d879a") if wet else Color.WHITE)
	# the shop from across the street
	var ground := s.y * 0.7
	var fr := Rect2(s.x * 0.06, s.y * 0.4, s.x * 0.88, ground - s.y * 0.4)
	var wall := Color(GameState.premises_def()["color"]).lerp(Color("cfd8e3"), 0.55)
	Scenery.shop_front(self, fr, GameState.sign_text(), wall, nt, t, _bay_car)
	# street + forecourt
	Scenery.vgrad(self, Rect2(0, ground + 6, s.x, s.y - ground), Color("5b606c"), Color("3e424c"))
	for x in range(0, int(s.x), 90):
		draw_rect(Rect2(x + 20, s.y * 0.9, 46, 8), Color(1, 1, 1, 0.5))
	if nt > 0.0:
		draw_rect(Rect2(0, s.y * 0.38, s.x, s.y), Color(0.05, 0.07, 0.22, 0.3 * nt))
		for lx in [fr.position.x - 4.0, fr.end.x + 4.0]:
			for k in 4:
				draw_circle(Vector2(lx, ground - 120), 80.0 * (1.0 - k * 0.2), Color(1, 0.9, 0.6, 0.06 * nt))
	for lx in [fr.position.x - 4.0, fr.end.x + 4.0]:   # lamp posts either side
		draw_rect(Rect2(lx - 4, ground - 150, 8, 150), UiTheme.INK)
		UiTheme.rounded(self, Rect2(lx - 14, ground - 168, 28, 22), Color("ffe9a8").lerp(Color("fff6d0"), nt), 8, 3, UiTheme.INK)
	if wet:
		Scenery.rain(self, Rect2(Vector2.ZERO, s), t, 1.2)
	# the hero car on the forecourt, freshly washed
	var cw := minf(s.x * 0.56, 400.0)
	var cr := Rect2((s.x - cw) * 0.5, s.y * 0.835 - cw * 0.45, cw, cw * 0.45)
	draw_set_transform(Vector2(cr.get_center().x, cr.end.y - 4), 0.0, Vector2(1.0, 0.16))
	draw_circle(Vector2.ZERO, cw * 0.56, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	CarView.draw_car(self, cr, CarView.book_color(_car), 0.0, [], 0.5 + 0.5 * sin(t * 2.0), false, _car)
	for k in 5:
		var ph := fposmod(t * 0.7 + k * 0.21, 1.0)
		var sp := cr.position + Vector2(cr.size.x * (0.15 + 0.17 * k), cr.size.y * (0.2 + 0.25 * (k % 2)))
		UiTheme.sparkle(self, sp, 16.0 * sin(ph * PI), Color(1, 1, 1, 0.95 * sin(ph * PI)))
	# soap bubbles drifting up
	for k in 12:
		var ph := fposmod(t * (0.06 + 0.015 * (k % 4)) + k * 0.137, 1.0)
		var bx := fposmod(k * 157.0 + 40.0, s.x) + sin(t * 1.5 + k) * 18.0
		var by := s.y * (1.05 - ph * 1.1)
		var r := 8.0 + float(k % 4) * 5.0
		draw_circle(Vector2(bx, by), r + 2.0, Color(1, 1, 1, 0.3))
		draw_circle(Vector2(bx, by), r, Color(0.85, 0.95, 1.0, 0.15))
		draw_circle(Vector2(bx - r * 0.35, by - r * 0.35), r * 0.25, Color(1, 1, 1, 0.8))
	# logo (pops in, bobs gently)
	var bob := sin(t * 2.0) * 5.0
	var pop := 0.6 + 0.4 * (1.0 + 2.70158 * pow(intro - 1.0, 3) + 1.70158 * pow(intro - 1.0, 2))
	var lk := minf(1.0, s.x / 760.0)
	draw_set_transform(Vector2(s.x * 0.5, s.y * 0.2 + bob), sin(t * 1.3) * 0.02, Vector2(pop, pop) * lk)
	var pill := Rect2(-90, -150, 180, 50)
	UiTheme.rounded(self, Rect2(pill.position + Vector2(0, 6), pill.size), Color("b35f00"), 25, 4, UiTheme.INK)
	UiTheme.rounded(self, pill, Color("ff9a2e"), 25, 4, UiTheme.INK)
	UiTheme.text(self, Vector2(-90, -113), "IDLE", 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 180, 8, UiTheme.DISPLAY_FONT)
	UiTheme.text(self, Vector2(-360, -30), "DETAILING", 92, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 720, 22, UiTheme.DISPLAY_FONT)
	UiTheme.text(self, Vector2(-360, 70), "TYCOON", 100, UiTheme.CASH, HORIZONTAL_ALIGNMENT_CENTER, 720, 24, UiTheme.DISPLAY_FONT)
	UiTheme.sparkle(self, Vector2(250, -60 + sin(t * 3.0) * 4.0), 20.0 + 6.0 * sin(t * 4.0), Color(1, 1, 1, 0.9))
	UiTheme.sparkle(self, Vector2(-260, 60), 14.0 + 5.0 * sin(t * 3.3 + 1.0), Color(1, 1, 1, 0.8))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not _loaded:
		_draw_bar(s)
		UiTheme.text(self, Vector2(0, s.y - 18), "playtest build v0.19w", 16, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, s.x, 4)
		return
	# tap to play (pops in once loaded)
	var a := 0.55 + 0.45 * sin(t * 4.0)
	var tp := Rect2(s.x * 0.5 - 200, s.y * 0.865, 400, 84)
	var pressed_scale := (1.0 + 0.04 * sin(t * 4.0)) * clampf((t - _ready_at) / 0.25, 0.0, 1.0)
	draw_set_transform(tp.get_center(), 0.0, Vector2(pressed_scale, pressed_scale))
	var local := Rect2(-tp.size * 0.5, tp.size)
	draw_style_box(UiTheme.lip_box(UiTheme.GOOD), local)
	UiTheme.text(self, Vector2(local.position.x, local.position.y + 50), "TAP TO PLAY", 36, Color(1, 1, 1, 0.75 + 0.25 * a), HORIZONTAL_ALIGNMENT_CENTER, local.size.x, 8, UiTheme.DISPLAY_FONT)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	UiTheme.text(self, Vector2(0, s.y - 18), "playtest build v0.19w", 16, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, s.x, 4)


## The loading bar where TAP TO PLAY will be: green fill on a dark track, what it's doing underneath.
func _draw_bar(s: Vector2) -> void:
	var bar := Rect2(s.x * 0.5 - 220, s.y * 0.88, 440, 36)
	UiTheme.rounded(self, Rect2(bar.position - Vector2(4, 4), bar.size + Vector2(8, 8)), Color(1, 1, 1, 0.9), 22, 0)
	UiTheme.rounded(self, bar, UiTheme.INK, 18, 0)
	var fill := Rect2(bar.position + Vector2(5, 5), Vector2(maxf(26.0, (bar.size.x - 10.0) * _progress), bar.size.y - 10.0))
	UiTheme.rounded(self, fill, UiTheme.GOOD, 13, 0)
	draw_rect(Rect2(fill.position + Vector2(9, 3), Vector2(maxf(0.0, fill.size.x - 18.0), 5)), Color(1, 1, 1, 0.3))
	UiTheme.text(self, Vector2(0, bar.end.y + 34), "%s...  %d%%" % [_step, int(round(_progress * 100.0))] if _step != "Ready!" else "Ready!",
		22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, s.x, 6, UiTheme.DISPLAY_FONT)
