extends Control
## v0.17h one-time tips (playtest: "a tutorial for everything the player needs to know"): the first time
## you open a screen or something new happens, a short bubble explains it, with a GOT IT button. It can
## point at something on screen (ring + bouncing arrow). Each tip shows once (GameState.settings
## "tips_seen"); Shop > Settings > "Show tips again" resets them. Only one at a time; they wait while the
## title screen, the first-loop tutorial, the Welcome back popup or a big message (v0.19j) is up.

const UiTheme = preload("res://scripts/ui_theme.gd")
const GS = preload("res://scripts/game_state.gd")

var main: Control
var _queue: Array = []       # [id, title, text, target Callable (returns Rect2 or null) or null]
var _cur: Array = []
var _dim: ColorRect
var _bubble: PanelContainer
var _title: Label
var _text: Label
var _target := Rect2()
var _has_target := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.05, 0.15, 0.45)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP   # read the tip first
	add_child(_dim)
	_bubble = PanelContainer.new()
	_bubble.add_theme_stylebox_override("panel", UiTheme.card(Color("fffbe6"), 22, 18, UiTheme.INK))
	add_child(_bubble)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_bubble.add_child(v)
	_title = UiTheme.ribbon("", 18, Color("ff9a2e"))
	v.add_child(_title)
	_text = UiTheme.label("", 22, Color("3e2c00"))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_text)
	var ok := UiTheme.button("GOT IT", 22, UiTheme.GOOD)
	ok.custom_minimum_size = Vector2(0, 64)
	ok.pressed.connect(_dismiss)
	v.add_child(ok)
	visible = false


## Queue a tip (ignored if it was already seen or is already waiting).
func show_tip(id: String, title: String, text: String, target: Variant = null) -> void:
	if not GameState.tips_enabled or GameState.tip_seen(id):
		return
	if (not _cur.is_empty() and _cur[0] == id) or _queue.any(func(q): return q[0] == id):
		return
	_queue.append([id, title, text, target])


func busy() -> bool:
	return not _cur.is_empty()


func _process(_delta: float) -> void:
	var blocked: bool = main.title_showing() or main._popup.visible or GameState.tutorial_step != GS.TUT_DONE \
		or main.big_showing() or main._banner.visible   # v0.19j: wait for OK on a big message / the rare car banner
	if _cur.is_empty() and not _queue.is_empty() and not blocked:
		# v0.19j (playtest: "the valet pop up was just bad timing"): a tip that points at something in the
		# shop (valet / desk too slow, rare car, new star) waits until no panel is open over it.
		var panel: bool = main.sheet_open()
		for k in _queue.size():
			if _queue[k][3] == null or not panel:
				_cur = _queue.pop_at(k)
				_title.text = str(_cur[1])
				_text.text = str(_cur[2])
				break
	visible = not _cur.is_empty() and not blocked
	if not visible:
		return
	if get_index() != get_parent().get_child_count() - 1:
		get_parent().move_child(self, -1)
	_has_target = false
	var t = _cur[3]
	if t is Callable and t.is_valid():
		var r = t.call()
		if r is Rect2:
			_target = r
			_has_target = true
	_place()
	queue_redraw()


func _dismiss() -> void:
	if _cur.is_empty():
		return
	GameState.mark_tip(str(_cur[0]))
	_cur = []
	visible = false


func _place() -> void:
	var scr := get_viewport_rect().size
	var w := scr.x - 48
	_text.custom_minimum_size = Vector2(w - 40, 0)
	_bubble.custom_minimum_size = Vector2(w, 0)
	_bubble.size = Vector2(w, 0)
	var bh := _bubble.get_combined_minimum_size().y
	_bubble.size = Vector2(w, bh)
	var y := scr.y * 0.22
	if _has_target:
		if _target.get_center().y < scr.y * 0.5:
			y = _target.end.y + 70
		else:
			y = _target.position.y - 70 - bh
	_bubble.position = Vector2(24, clampf(y, 100, scr.y - bh - 120))


func _draw() -> void:
	if not _has_target:
		return
	var t := Time.get_ticks_msec() * 0.001
	var pulse := 0.5 + 0.5 * sin(t * 6.0)
	var ring := _target.grow(8 + pulse * 4)
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_border_width_all(6)
	sb.border_color = Color(1.0, 0.82, 0.2, 0.95)
	sb.set_corner_radius_all(18)
	draw_style_box(sb, ring)
	# bouncing arrow from the bubble towards the target
	var below := _bubble.position.y > _target.get_center().y
	var tip := Vector2(_target.get_center().x, (_target.end.y + 10) if below else (_target.position.y - 10))
	var d := 1.0 if below else -1.0
	var bob := sin(t * 7.0) * 8.0 * d
	var base := tip + Vector2(0, d * (40 + bob))
	var pts := PackedVector2Array([tip + Vector2(0, d * bob * 0.3), tip + Vector2(-22, d * 26) + Vector2(0, d * bob * 0.3), tip + Vector2(22, d * 26) + Vector2(0, d * bob * 0.3)])
	draw_line(base, tip + Vector2(0, d * 20), UiTheme.INK, 16)
	draw_line(base, tip + Vector2(0, d * 20), Color("ffc93c"), 9)
	draw_colored_polygon(pts, Color("ffc93c"))
	var o := pts.duplicate()
	o.append(pts[0])
	draw_polyline(o, UiTheme.INK, 3.0, true)
