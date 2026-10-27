extends Control
## The "Level 56" button on the right of each station. Turns green with a
## bouncing arrow when you can afford the next level. Tap = open level panel.

signal pressed

const UiTheme = preload("res://scripts/ui_theme.gd")
const Data = preload("res://scripts/game_data.gd")

var station_key := ""
var _press_pos := Vector2.ZERO
var _pressing := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	# v0.19v perf: the tag only redraws when it changes; the glow + bobbing arrow (when you can afford a level)
	# are their own little nodes moved by tweens, so nothing is redrawn every frame
	_glow = Control.new()
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.show_behind_parent = true
	_glow.draw.connect(func():
		UiTheme.rounded(_glow, _tag_rect().grow(6.0), Color(0.35, 1.0, 0.45, 0.28), 18))
	add_child(_glow)
	_arrow = Control.new()
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.draw.connect(func():
		var c := Vector2(size.x * 0.5, _tag_rect().position.y - 6)
		var arrow := PackedVector2Array([c + Vector2(0, -11), c + Vector2(12, 3), c + Vector2(4, 3),
			c + Vector2(4, 12), c + Vector2(-4, 12), c + Vector2(-4, 3), c + Vector2(-12, 3)])
		var outline := PackedVector2Array(arrow)
		outline.append(arrow[0])
		_arrow.draw_colored_polygon(arrow, Color("ffd43b"))
		_arrow.draw_polyline(outline, UiTheme.INK, 3.0, true))
	add_child(_arrow)
	resized.connect(func():
		_glow.size = size
		_arrow.size = size
		_glow.pivot_offset = size * 0.5
		_glow.queue_redraw()
		_arrow.queue_redraw())
	var tw := create_tween().set_loops()
	tw.tween_property(_arrow, "position:y", -3.0, 0.52).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_arrow, "position:y", 3.0, 0.52).set_trans(Tween.TRANS_SINE)
	var tg := create_tween().set_loops()
	tg.tween_property(_glow, "modulate:a", 1.0, 1.05).set_trans(Tween.TRANS_SINE)
	tg.tween_property(_glow, "modulate:a", 0.35, 1.05).set_trans(Tween.TRANS_SINE)


var _last_level := -1
var _sig := ""
var _glow: Control
var _arrow: Control


func _tag_rect() -> Rect2:
	return Rect2(Vector2((size.x - 74.0) * 0.5, size.y - 80.0 - 6.0), Vector2(74.0, 80.0))


func _can() -> bool:
	return GameState.level_of(station_key) < GameState.station_max_level(station_key) and GameState.cash >= GameState.levels_cost(station_key, 1)


func _process(_delta: float) -> void:
	if station_key.begins_with("bay") and GameState.bay_index(station_key) >= GameState.bays.size():
		return
	var lvl := GameState.level_of(station_key)
	if _last_level > 0 and lvl > _last_level:   # bounce when it levels up
		pivot_offset = size * 0.5
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(1.15, 1.15), 0.08)
		tw.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_last_level = lvl
	var can := _can()
	_glow.visible = can
	_arrow.visible = can
	var fl := GameState.finish_line()
	var s := "%d|%s|%s|%s|%d" % [lvl, can, lvl >= GameState.station_max_level(station_key), str(fl.get("levels", 0)), int(size.x)]
	if s != _sig:
		_sig = s
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_press_pos = event.position
		elif _pressing:
			_pressing = false
			if event.position.distance_to(_press_pos) < 16.0:
				pressed.emit()


func _draw() -> void:
	if station_key.begins_with("bay") and GameState.bay_index(station_key) >= GameState.bays.size():
		return
	var lvl := GameState.level_of(station_key)
	var maxed := lvl >= GameState.station_max_level(station_key)
	var can := not maxed and GameState.cash >= GameState.levels_cost(station_key, 1)
	# v0.19u (Hamza: the big green blocks down the side looked generic): a slimmer level TAG. Dark gloss with a
	# chrome rim while you can't afford a level (it sits back), bright green and glowing when you can (it's the
	# thing to tap), gold when maxed. The tap area stays the full control.
	var pw := 74.0
	var ph := 80.0
	var r := Rect2(Vector2((size.x - pw) * 0.5, size.y - ph - 6.0), Vector2(pw, ph))
	var ink := UiTheme.INK
	var top: Color
	var bot: Color
	if maxed:
		top = Color("ffe082"); bot = Color("e0a000")
	elif can:
		top = Color("6fe37a"); bot = Color("2fa84a")
	else:
		top = Color("3b4766"); bot = Color("1f2740")
	# lip + body + gloss
	UiTheme.rounded(self, Rect2(r.position + Vector2(0, 5), r.size), bot.darkened(0.45), 14, 3, ink)
	UiTheme.rounded(self, r, bot, 14, 3, ink)
	UiTheme.rounded(self, Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, r.size.y * 0.55)), top, 11)
	if not can and not maxed:   # chrome rim on the dark tag
		UiTheme.rounded(self, r.grow(-3.0), Color(0, 0, 0, 0), 12, 2, Color(0.82, 0.86, 0.93, 0.55))
	UiTheme.rounded(self, Rect2(r.position + Vector2(8, 5), Vector2(r.size.x - 16, 6)), Color(1, 1, 1, 0.3), 3)
	var tc := Color.WHITE if (can or maxed) else Color(0.86, 0.9, 0.98)
	UiTheme.text(self, Vector2(r.position.x, r.position.y + 25), "MAX" if maxed else "LEVEL", 14, tc, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 4, UiTheme.DISPLAY_FONT)
	UiTheme.text(self, Vector2(r.position.x, r.position.y + 60), str(lvl), 30 if lvl < 100 else (26 if lvl < 1000 else 22), tc, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 6, UiTheme.DISPLAY_FONT)
	var fl := GameState.finish_line()
	if not fl.is_empty() and not maxed:
		# v0.19o Priya's Finish Line: this station's next levels are in the cheap window before its boost
		var nb := GameState.next_boost(station_key)
		if not nb.is_empty() and lvl + 1 > int(nb["level"]) - int(fl["levels"]):
			var tg := Rect2(-6, size.y - 26, size.x + 12, 26)
			UiTheme.rounded(self, tg, Color("ef6c00"), 9, 2, UiTheme.INK)
			UiTheme.text(self, Vector2(tg.position.x, tg.position.y + 19), "-%d%%" % int(round(float(fl["off"]) * 100.0)), 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, tg.size.x, 4, UiTheme.DISPLAY_FONT)
