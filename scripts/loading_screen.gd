extends Control
## v0.19w (Hamza: a loading bar between BIG changes only: launch + going to another city; never the map, shop...).
## A full-screen card: the sky at the real time of day, a road of city lights, the place you're going in big
## letters, and a bar with the valet ute driving along it. run(work) shows the card FIRST, does the work (the
## city switch: building the new shop, its car pictures) underneath it a couple of frames later, fills the bar
## while the new shop warms up (car pictures rendered), then fades away. At least MIN_TIME on screen so it
## never just flashes.

signal finished

const UiTheme = preload("res://scripts/ui_theme.gd")
const Scenery = preload("res://scripts/scenery.gd")
const CarView = preload("res://scripts/car_view.gd")
const CarCache = preload("res://scripts/car_cache.gd")
const SkylineArt = preload("res://scripts/skyline_art.gd")
const Data = preload("res://scripts/game_data.gd")

const MIN_TIME := 0.7
const MAX_WAIT := 2.5   # (never stuck: whatever is still warming up after this just finishes in game)

var title := ""
var sub := ""
var progress := 0.0     # what the bar shows (eases towards _target)
var _target := 0.0
var _t := 0.0
var country := ""      # whose skyline (defaults to where you are now)
var _bg: Control       # sky + skyline: drawn ONCE
var _car: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # (taps don't reach the shop while it's changing)
	z_index = 100
	if country == "":
		country = "hometown" if GameState.is_hometown() else str(GameState.country)
	var ev := Data.CARS.filter(func(c): return int(c["tier"]) <= 2)
	_car = GameState.car_def((ev.pick_random() if not ev.is_empty() else Data.CARS[0])["id"])
	_bg = Control.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.show_behind_parent = true
	_bg.draw.connect(_draw_bg)
	add_child(_bg)


## Show the card, do work() under it, wait for the new shop to warm up, fade out. Await-able.
func run(work: Callable) -> void:
	_target = 0.15
	await _frames(2)        # the card is on screen before the heavy frame
	if work.is_valid():
		work.call()
	_target = 0.55
	await _frames(2)
	var t0 := _t
	while _t - t0 < MAX_WAIT and (CarCache.pending() > 0 or _t < MIN_TIME):
		_target = clampf(0.55 + 0.4 * (_t / MIN_TIME), 0.55, 0.95)
		await get_tree().process_frame
	_target = 1.0
	while progress < 0.995:
		await get_tree().process_frame
	await get_tree().create_timer(0.12).timeout
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.22)
	await tw.finished
	finished.emit()
	queue_free()


func _frames(n: int) -> void:
	for k in n:
		await get_tree().process_frame


func _process(delta: float) -> void:
	_t += delta
	var p := move_toward(progress, _target, delta * 2.2)
	if p != progress:
		progress = p
		queue_redraw()


## The still part: the sky at the real time of day, the city's skyline on the horizon, the road.
func _draw_bg() -> void:
	var s := _bg.size
	var nt := Scenery.night_amount()
	var wet := GameState.raining()
	var sky := Scenery.sky_colors(-1.0, wet)
	var base := s.y * 0.66
	Scenery.vgrad(_bg, Rect2(0, 0, s.x, base), (sky[0] as Color).darkened(0.1), sky[1])
	Scenery.night_sky(_bg, Rect2(0, 0, s.x, s.y * 0.45), nt)
	if nt < 0.6 and not wet:
		Scenery.cloud(_bg, Vector2(s.x * 0.25, s.y * 0.12), 30, 0.85 * (1.0 - nt))
		Scenery.cloud(_bg, Vector2(s.x * 0.72, s.y * 0.2), 24, 0.75 * (1.0 - nt))
	# the skyline, drawn twice as big as in the shop's sky strip
	_bg.draw_set_transform(Vector2(0, base - 128.0 * 2.0), 0.0, Vector2(2.0, 2.0))
	SkylineArt.draw(_bg, Rect2(0, 0, s.x * 0.5, 128.0), country, nt, [sky[1], sky[1]], wet)
	_bg.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	Scenery.vgrad(_bg, Rect2(0, base, s.x, s.y - base), Color("4b505c"), Color("2c2f37"))
	for x in range(0, int(s.x), 90):
		_bg.draw_rect(Rect2(x + 20, s.y * 0.735, 46, 7), Color(1, 1, 1, 0.45))
	if wet:
		Scenery.rain(_bg, Rect2(Vector2.ZERO, s), 0.0, 1.0)


func _draw() -> void:
	var s := size
	# the name, on a soft dark band so it reads over any sky
	var ty := s.y * 0.3
	draw_rect(Rect2(0, ty - 62, s.x, 128), Color(0.05, 0.07, 0.18, 0.28))
	UiTheme.text(self, Vector2(0, ty + 10), title, 64, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, s.x, 16, UiTheme.DISPLAY_FONT)
	if sub != "":
		UiTheme.text(self, Vector2(0, ty + 52), sub, 28, Color("ffe07a"), HORIZONTAL_ALIGNMENT_CENTER, s.x, 8, UiTheme.DISPLAY_FONT)
	# the bar, with a freshly washed car driving along on top of it
	var bar := Rect2(s.x * 0.12, s.y * 0.86, s.x * 0.76, 34)
	UiTheme.rounded(self, Rect2(bar.position - Vector2(4, 4), bar.size + Vector2(8, 8)), Color(1, 1, 1, 0.9), 21, 0)
	UiTheme.rounded(self, bar, UiTheme.INK, 17, 0)
	var fill := Rect2(bar.position + Vector2(5, 5), Vector2(maxf(24.0, (bar.size.x - 10.0) * progress), bar.size.y - 10.0))
	UiTheme.rounded(self, fill, UiTheme.GOOD, 12, 0)
	draw_rect(Rect2(fill.position + Vector2(8, 3), Vector2(maxf(0.0, fill.size.x - 16.0), 5)), Color(1, 1, 1, 0.3))
	var cw := 120.0
	var cr := Rect2(fill.end.x - cw * 0.75, bar.position.y - 4.0 - cw * 0.45, cw, cw * 0.45)
	CarView.draw_car(self, cr, CarView.book_color(_car), 0.0, [], 0.0, false, _car)
	UiTheme.text(self, Vector2(0, bar.end.y + 44), "%d%%" % int(round(progress * 100.0)), 24, Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_CENTER, s.x, 6, UiTheme.DISPLAY_FONT)
