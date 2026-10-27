extends Control
## First-time tutorial: a bouncing arrow + speech bubble showing exactly where to tap.
## Steps live in GameState (TUT_*); this only draws. Restart it with
## GameState.start_tutorial() (e.g. after a workshop prestige).

const UiTheme = preload("res://scripts/ui_theme.gd")
const Data = preload("res://scripts/game_data.gd")
const GS = preload("res://scripts/game_state.gd")  # for the TUT_* constants

var main: Control            # main.gd, used to find what to point at
var _bubble: PanelContainer
var _label: Label
var _target := Rect2()
var _has_target := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble = PanelContainer.new()
	var st := UiTheme.card(Color("fffbe6"), 20, 14, UiTheme.INK)   # v0.17f bubbly cream card
	_bubble.add_theme_stylebox_override("panel", st)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bubble)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 10)
	_bubble.add_child(h)
	_label = UiTheme.label("", 22, Color("3e2c00"))
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_label)
	var skip := UiTheme.button("Skip", 16, Color("8d6e63"))
	skip.mouse_filter = Control.MOUSE_FILTER_STOP
	skip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	skip.custom_minimum_size = Vector2(70, 40)
	skip.pressed.connect(GameState.finish_tutorial)
	h.add_child(skip)


func _process(_delta: float) -> void:
	var step := GameState.tutorial_step
	visible = step != GS.TUT_DONE and not main.is_blocking_popup_open()
	if not visible:
		return
	if get_index() != get_parent().get_child_count() - 1:
		get_parent().move_child(self, -1)
	var info := _step_info(step)
	_label.text = info[0]
	_has_target = info[1] != null
	if _has_target:
		_target = info[1]
	_place_bubble()
	queue_redraw()


## [text, target Rect2 in screen space or null]
func _step_info(step: int) -> Array:
	match step:
		GS.TUT_WASH:
			return ["Tap the car to start washing it!", main.tut_rect("bay_car")]
		GS.TUT_VALET:
			return ["Squeaky clean! Tap the valet to drive it up to the front desk.", main.tut_rect("valet")]
		GS.TUT_DESK:
			return ["Tap the front desk to hand the keys back and get paid.", main.tut_rect("desk")]
	return ["", null]


func _rect_of(c: Variant) -> Variant:
	if c == null or not (c is Control) or not c.is_visible_in_tree():
		return null
	return (c as Control).get_global_rect()


func _place_bubble() -> void:
	var scr := get_viewport_rect().size
	var w := scr.x - 40
	_label.custom_minimum_size = Vector2(w - 28 - 80, 0)   # room for padding + Skip button
	_bubble.custom_minimum_size = Vector2(w, 0)
	_bubble.size = Vector2(w, 0)
	var bh := _bubble.get_combined_minimum_size().y
	_bubble.size = Vector2(w, bh)
	var y: float
	if not _has_target:
		y = scr.y * 0.42
	elif _target.get_center().y < scr.y * 0.5:
		y = _target.end.y + 80
	else:
		y = _target.position.y - 80 - bh
	_bubble.position = Vector2(20, clampf(y, 120, scr.y - bh - 120))


func _draw() -> void:
	if not _has_target:
		return
	var t := Time.get_ticks_msec() * 0.001
	var pulse := 0.5 + 0.5 * sin(t * 6.0)
	# ring around the target
	var ring := _target.grow(6 + pulse * 4)
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_border_width_all(5)
	sb.border_color = Color(1, 0.75, 0.1, 0.6 + 0.4 * pulse)
	sb.set_corner_radius_all(16)
	draw_style_box(sb, ring)
	# arrow: above the target pointing down, or below pointing up near the top of the screen
	var down := _target.position.y > 200
	var tip := Vector2(_target.get_center().x, (_target.position.y - 8) if down else (_target.end.y + 8))
	var dir := 1.0 if down else -1.0
	tip.y -= dir * (sin(t * 6.0) * 10.0 + 10.0)
	var s := 26.0
	var pts := PackedVector2Array([
		tip, tip + Vector2(-s, -dir * s), tip + Vector2(-s * 0.45, -dir * s),
		tip + Vector2(-s * 0.45, -dir * s * 2.4), tip + Vector2(s * 0.45, -dir * s * 2.4),
		tip + Vector2(s * 0.45, -dir * s), tip + Vector2(s, -dir * s)])
	draw_colored_polygon(pts, Color("ffca28"))
	pts.append(pts[0])
	draw_polyline(pts, Color("7a4f00"), 3.0)
