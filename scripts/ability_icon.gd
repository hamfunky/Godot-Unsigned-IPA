extends Control
## The ability button that sits ABOVE a station's manager (on the slab band). Tap = use the manager's ability;
## tapping the manager himself opens the manager panel. Hidden when nobody runs the station.
## v0.19d (Hamza 19 Oct): a SOAP BUBBLE with the ability's picture floating inside (textures baked by
## tools/char/ability_bubble.py into assets/game/sprites/ability/):
##   income = money bag (green), speed = stopwatch (blue), discount = price tag (orange), Tip Jar (gold)
##   ready      bobs gently, the film's colours swirl, a little wobble every few seconds (tap me)
##   active     soft glow in the ability colour + tiny bubbles fizzing up, time left in the pill
##   recharging smaller grey bubble, grey picture, countdown in the pill
##   tap        it squashes and pops a ring of tiny bubbles (and the ability starts)

const UiTheme = preload("res://scripts/ui_theme.gd")

const KIND_COLOR := {"income": Color("43a047"), "speed": Color("1e88e5"), "discount": Color("ef6c00"), "signature": Color("f9a825")}
const DIR := "res://assets/game/sprites/ability/%s.png"
const TEX_R := 68.0          # bubble radius inside the body / shine / glow textures (px)
const ICON_W := 1.65         # the picture's width, in bubble radii
const KINDS := ["income", "speed", "discount", "signature"]

static var _tex := {}

var _t := 0.0
var _pop_at := -10.0
var _seed := 0.0

var station_key := ""
var _press_pos := Vector2.ZERO
var _pressing := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_seed = float(absi(hash(station_key)) % 997) / 997.0 * TAU


static func tex(n: String) -> Texture2D:
	if not _tex.has(n):
		_tex[n] = load(DIR % n)
	return _tex[n]


func _manager() -> Dictionary:
	if station_key.begins_with("bay") and GameState.bay_index(station_key) >= GameState.bays.size():
		return {}
	return GameState.manager_at(station_key)


const AnimClock = preload("res://scripts/anim_clock.gd")
var _clock := AnimClock.new()

func _process(delta: float) -> void:
	var m := _manager()
	visible = not m.is_empty()
	mouse_filter = Control.MOUSE_FILTER_STOP if visible else Control.MOUSE_FILTER_IGNORE
	if visible and is_visible_in_tree() and get_global_rect().intersects(get_viewport_rect().grow(40.0)):
		var dt := _clock.tick(delta)   # v0.19w perf: its little glow / ring moves at 30 fps, like the characters
		if dt > 0.0:
			_t += dt
			queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_press_pos = event.position
			accept_event()
		elif _pressing:
			_pressing = false
			accept_event()
			if event.position.distance_to(_press_pos) < 16.0:
				use()


## Use the ability if it's ready (a tap on a recharging/active icon does nothing).
func use() -> void:
	var m := _manager()
	if m.is_empty() or not GameState.ability_ready(m):
		return
	GameState.activate_ability(station_key)
	_pop_at = _t
	Sfx.play("boost")
	Sfx.buzz(30)
	pivot_offset = size * 0.5
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.25, 1.25), 0.08)
	tw.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var m := _manager()
	if m.is_empty():
		return
	var kind: String = GameState.ability_def(m)["kind"]
	if not kind in KINDS:
		kind = "income"
	var active := GameState.ability_active(m)
	var ready := GameState.ability_ready(m)
	var R := minf(size.x, size.y) * 0.5 - 2.0
	var c := size * 0.5
	var sq := Vector2.ONE          # squash and stretch
	var rot := 0.0
	var tilt := 0.0
	if active or ready:
		c.y += sin(_t * 2.1 + _seed) * 1.4
		rot = _t * 0.35 + _seed          # the film's colours swirl round
		if ready and not active:
			var ph := fposmod(_t + _seed, 4.2)
			if ph < 0.55:                 # a little jelly wobble now and then: tap me
				var q := ph / 0.55
				var w := sin(q * PI * 3.0) * (1.0 - q) * 0.08
				sq = Vector2(1.0 + w, 1.0 - w)
			tilt = sin(_t * 1.3 + _seed) * 0.06
	else:
		R *= 0.86                         # recharging: a smaller grey bubble
	var pop := _t - _pop_at
	if pop < 0.18:
		var q := pop / 0.18
		sq *= Vector2(1.0 + 0.18 * sin(q * PI), 1.0 - 0.14 * sin(q * PI))
	var k := R / TEX_R
	if active:
		var pulse := 0.5 + 0.5 * sin(_t * 4.5)
		_tex_at("glow_" + kind, c, Vector2.ONE * k * (1.08 + 0.07 * pulse), 0.0, Color(1, 1, 1, 0.55 + 0.3 * pulse))
		for i in 3:   # tiny bubbles fizzing up off the top
			var u := fposmod(_t * 0.75 + i / 3.0 + _seed, 1.0)
			var p := c + Vector2((i - 1) * R * 0.5 + sin(_t * 3.0 + i * 2.0) * 2.0, -R * 0.55 - u * R * 1.1)
			_tex_at("mini_" + kind, p, Vector2.ONE * R * (0.011 - 0.004 * u), 0.0, Color(1, 1, 1, 1.0 - u))
	var grey := not (active or ready)
	_tex_at("body_grey" if grey else "body_" + kind, c, sq * k, rot)
	var pic := _pic_name(m, kind) + ("_grey" if grey else "")
	var icon := tex(pic)
	_tex_at(pic, c, sq * (ICON_W * R / float(icon.get_width())), tilt)
	_tex_at("shine", c, sq * k, 0.0, Color(1, 1, 1, 0.75 if grey else 1.0))
	if pop < 0.45:
		# pop: a ring + a burst of tiny bubbles
		var q := pop / 0.45
		draw_arc(c, R * (1.0 + 0.7 * q), 0, TAU, 32, Color(1, 1, 1, 0.8 * (1.0 - q)), 3.0 * (1.0 - q) + 1.0, true)
		for i in 7:
			var a := TAU * i / 7.0 + _seed
			_tex_at("mini_" + kind, c + Vector2.from_angle(a) * R * (1.0 + 1.1 * q), Vector2.ONE * R * 0.010 * (1.0 - 0.5 * q), 0.0, Color(1, 1, 1, 1.0 - q))
	if active:
		_badge(GameState.ability_left_text(m), Color(0.1, 0.45, 0.15, 0.95))
	elif not ready:
		_badge(_short(float(m["ready_at"]) - GameState.now), Color(0, 0, 0, 0.8))


## v0.19q: a signature's own picture (icon_shortcut, icon_finish_line, icon_convoy...) when one is baked,
## else the kind's (Dazza's tip jar for "signature").
static func _pic_name(m: Dictionary, kind: String) -> String:
	var own := "icon_" + str(m.get("ability", ""))
	if kind == "signature" and ResourceLoader.exists(DIR % own):
		return own
	return "icon_" + kind


## Draws a texture centred on `at`, scaled and rotated.
func _tex_at(n: String, at: Vector2, sc: Vector2, rot := 0.0, mod := Color.WHITE) -> void:
	var t := tex(n)
	draw_set_transform(at, rot, sc)
	draw_texture(t, -t.get_size() * 0.5, mod)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Little time pill under the icon.
func _badge(t: String, bg: Color) -> void:
	var w := 66.0
	var rr := Rect2(size.x * 0.5 - w * 0.5, size.y * 0.5 + minf(size.x, size.y) * 0.5 * 0.62, w, 20)   # v0.19d: under the bubble
	UiTheme.rounded(self, rr, bg, 8, 2, UiTheme.INK)
	UiTheme.text(self, Vector2(rr.position.x, rr.end.y - 4), t, 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, w, 0)


static func _short(secs: float) -> String:
	var s := int(maxf(secs, 0.0))
	if s >= 3600:
		return "%dh%02d" % [s / 3600, (s % 3600) / 60]
	if s >= 60:
		return "%dm" % ceili(s / 60.0)
	return "%ds" % s
