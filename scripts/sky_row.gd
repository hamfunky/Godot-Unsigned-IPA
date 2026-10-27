extends Control
## v0.19v (Hamza): a taller strip of sky above the shop, for things you tap straight from the main screen.
## First: the LUCKY WHEEL (it used to live only in the Shop). The sky matches the shop's own sky strip
## (real clock: day, sunset, stars + moon at night, rain), with a soft skyline behind the shop.
## Perf: the sky + skyline are drawn only when the time of day / weather changes; the wheel turns by
## rotating a texture node (no redraw per frame).

signal wheel_pressed

const Scenery = preload("res://scripts/scenery.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")
const GameIcons = preload("res://scripts/game_icons.gd")
const Data = preload("res://scripts/game_data.gd")
const SkylineArt = preload("res://scripts/skyline_art.gd")
const SKY_X := 160.0   # where the skyline starts (the wheel stands left of it)


## v0.19w (Hamza OK'd the mockup): the detailed skyline, drawn ONCE into a little SubViewport picture
## (re-rendered only when the hour bucket / weather / city changes), so its ~1000 shapes cost nothing per frame.
class SkyPic extends Control:
	const SkylineArt = preload("res://scripts/skyline_art.gd")
	var country := "usa"
	var nt := 0.0
	var sky := []
	var wet := false
	func _draw() -> void:
		if not sky.is_empty():
			SkylineArt.draw(self, Rect2(Vector2.ZERO, size), country, nt, sky, wet)

const HEIGHT := 128.0
const WHEEL_R := 42.0   # v0.19w: a bit smaller + higher so the FREE SPIN tag stays inside the strip
const WHEEL_C := Vector2(84, 52)

var _wheel: TextureRect
var _pointer: Control
var _tag: Label
var _sig := ""
var _check := 0.0
var _spin_speed := 0.35
var _sky_vp: SubViewport = null
var _sky_pic: SkyPic = null


func _ready() -> void:
	custom_minimum_size = Vector2(0, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	# the wheel: a texture turned by rotation (pivot = its centre)
	_wheel = TextureRect.new()
	_wheel.texture = GameIcons.tex("wheel_face")
	_wheel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_wheel.stretch_mode = TextureRect.STRETCH_SCALE
	_wheel.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_wheel.size = Vector2(WHEEL_R * 2.0, WHEEL_R * 2.0)
	_wheel.position = WHEEL_C - _wheel.size * 0.5
	_wheel.pivot_offset = _wheel.size * 0.5
	_wheel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wheel)
	_pointer = Control.new()
	_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pointer.draw.connect(_draw_pointer)
	_pointer.size = size
	add_child(_pointer)
	_tag = UiTheme.display_label("", 17, Color.WHITE)
	UiTheme.outlined(_tag, 5)
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.size = Vector2(150, 26)
	_tag.position = Vector2(WHEEL_C.x - 75, WHEEL_C.y + WHEEL_R - 4)
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tag)
	resized.connect(func():
		_pointer.size = size
		queue_redraw())


func _process(delta: float) -> void:
	var free := GameState.wheel_free_ready()
	# a free spin waiting = the wheel turns faster and the tag pulses green
	_spin_speed = lerpf(_spin_speed, 1.6 if free else 0.3, minf(1.0, delta * 2.0))
	_wheel.rotation = fmod(_wheel.rotation + delta * _spin_speed, TAU)
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.5
	var t := "FREE SPIN!" if free else "LUCKY WHEEL"
	if _tag.text != t:
		_tag.text = t
		var bs := UiTheme.box(Color("2fb457") if free else Color("ff9a2e"), 11, 0)
		bs.set_border_width_all(3)
		bs.border_color = UiTheme.INK
		_tag.add_theme_stylebox_override("normal", bs)
	var s := "%d|%d|%s|%s" % [int(size.x), int(Scenery.local_hour() * 12.0), str(GameState.raining()), _country()]
	if s != _sig:
		_sig = s
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if event.position.distance_to(WHEEL_C) < WHEEL_R + 26.0:
			Sfx.play("tap")
			wheel_pressed.emit()


func _draw() -> void:
	var w := size.x
	var wet := GameState.raining()
	var sky := Scenery.sky_colors(-1.0, wet)
	var nt := Scenery.night_amount()
	# deeper at the top, the shop's own sky colour at the bottom (so the two strips join without a seam)
	var top: Color = (sky[0] as Color).darkened(0.18).lerp(Color("0d1233"), 0.35 * nt)
	Scenery.vgrad(self, Rect2(0, 0, w, HEIGHT), top, sky[0])
	Scenery.night_sky(self, Rect2(0, 0, w, HEIGHT - 30), nt)   # (the moon lives up here now)
	if nt < 0.95 and not wet:
		Scenery.cloud(self, Vector2(w * 0.42, 34), 18, 0.8 * (1.0 - nt * 0.8))
		Scenery.cloud(self, Vector2(w * 0.78, 62), 14, 0.7 * (1.0 - nt * 0.8))
		if nt < 0.5:   # the sun, high on the right
			draw_circle(Vector2(w - 70, 40), 30, Color(1, 0.95, 0.6, 0.25 * (1.0 - nt * 2.0)))
			draw_circle(Vector2(w - 70, 40), 20, Color(1, 0.93, 0.55, 1.0 - nt * 2.0))
	elif wet:
		for k in 6:
			Scenery.cloud(self, Vector2(30 + k * w / 5.0, 22 + (k % 2) * 14), 22, 0.9 * (1.0 - nt * 0.5), Color("7d879a"))
	# v0.19w: the detailed skyline (two layers, the country's landmark, lit windows at night)
	var sky_args := [sky[0], sky[0]]   # (its haze matches the strip's bottom colour, where the shop's roof joins)
	if _picture_ok():
		_bake_sky(Vector2i(int(w - SKY_X), int(HEIGHT)), nt, sky_args, wet)
		draw_texture(_sky_vp.get_texture(), Vector2(SKY_X, 0))
	else:
		SkylineArt.draw(self, Rect2(SKY_X, 0, w - SKY_X, HEIGHT), _country(), nt, sky_args, wet)
	if wet:
		Scenery.rain(self, Rect2(0, 0, w, HEIGHT), 0.0, 1.0)
	# the wheel's stand: a post down to the roof + a little base
	var post := Rect2(WHEEL_C.x - 6, WHEEL_C.y, 12, HEIGHT - WHEEL_C.y)
	Scenery.rr(self, post, Color("9aa6b8"), 3, 2)
	Scenery.rr(self, Rect2(WHEEL_C.x - 34, HEIGHT - 10, 68, 12), Color("7a8699"), 4, 2)
	draw_circle(WHEEL_C, WHEEL_R + 14, Color(1, 0.95, 0.6, 0.12 + 0.1 * nt))


func _country() -> String:
	return "hometown" if GameState.is_hometown() else str(GameState.country)


func _picture_ok() -> bool:
	return DisplayServer.get_name() != "headless" and is_inside_tree()


func _bake_sky(sz: Vector2i, nt: float, sky: Array, wet: bool) -> void:
	if _sky_vp == null:
		_sky_vp = SubViewport.new()
		_sky_vp.transparent_bg = true
		_sky_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_sky_pic = SkyPic.new()
		_sky_vp.add_child(_sky_pic)
		add_child.call_deferred(_sky_vp)   # (never add nodes while drawing)
	_sky_vp.size = sz
	_sky_pic.size = Vector2(sz)
	_sky_pic.country = _country()
	_sky_pic.nt = nt
	_sky_pic.sky = sky
	_sky_pic.wet = wet
	_sky_pic.queue_redraw()
	_sky_vp.render_target_update_mode = SubViewport.UPDATE_ONCE   # renders once, then keeps the picture


func _draw_pointer() -> void:
	# the pointer at the top of the wheel (doesn't turn)
	var tip := WHEEL_C + Vector2(0, -WHEEL_R + 12)
	var top := WHEEL_C + Vector2(0, -WHEEL_R - 10)
	var pp := PackedVector2Array([tip, top + Vector2(-13, 0), top + Vector2(13, 0)])
	_pointer.draw_colored_polygon(pp, Color("e8553d"))
	pp.append(pp[0])
	_pointer.draw_polyline(pp, UiTheme.INK, 3.0, true)
	_pointer.draw_circle(top, 7, UiTheme.INK)
	_pointer.draw_circle(top, 4.5, Color("fff6d6"))
