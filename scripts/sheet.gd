extends Control
## Base for bottom-sheet popups (level panel, managers, shop).
## Dims the screen; tapping the dim area or X closes it. Subclasses fill `body`.
## If the body is taller than the screen allows, it scrolls (the title + X stay put).

const UiTheme = preload("res://scripts/ui_theme.gd")

var body: VBoxContainer
var _title: Label
var _panel: PanelContainer
var _sheet_scroll: ScrollContainer

const TOP_GAP := 90.0   # space kept free above the sheet


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.06, 0.15, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(dim)

	var panel := PanelContainer.new()
	_panel = panel
	panel.add_theme_stylebox_override("panel", finish_box("chrome"))   # v0.19u: material rim (set_finish to change)
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	var head := HBoxContainer.new()
	v.add_child(head)
	_title = UiTheme.display_label("", 30)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_color_override("font_outline_color", UiTheme.INK)
	_title.add_theme_constant_override("outline_size", 8)
	head.add_child(_title)
	var x := UiTheme.button("X", 26, Color("ff5a5f"))
	x.custom_minimum_size = Vector2(64, 56)
	x.pressed.connect(close)
	head.add_child(x)

	_sheet_scroll = ScrollContainer.new()
	_sheet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_sheet_scroll)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet_scroll.add_child(body)
	body.minimum_size_changed.connect(_fit)


func _ready() -> void:
	Sfx.play("open")
	_start_shine.call_deferred()
	# slide up from the bottom
	var panel: Control = get_child(1)
	panel.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(panel, "modulate:a", 1.0, 0.12)
	get_viewport().size_changed.connect(_fit)
	_fit.call_deferred()


## Body as tall as its contents, up to what fits on screen (then it scrolls).
func _fit() -> void:
	if not is_inside_tree():
		return
	var room := get_viewport_rect().size.y - TOP_GAP - 140.0   # title row + sheet margins
	_sheet_scroll.custom_minimum_size.y = minf(body.get_combined_minimum_size().y, maxf(200.0, room))
	_place.call_deferred()


## Pin the sheet to the bottom of the screen at its current height.
func _place() -> void:
	if not is_inside_tree():
		return
	var h := _panel.get_combined_minimum_size().y
	_panel.offset_bottom = 0.0
	_panel.offset_top = -h


func set_title(t: String) -> void:
	_title.text = t


## v0.19u (Hamza: panels shouldn't all be the same flat box; chrome, but some black gloss or carbon fibre):
## the sheet's rim material. "chrome" | "gloss" | "carbon".
func set_finish(kind: String) -> void:
	_panel.add_theme_stylebox_override("panel", finish_box(kind))
	_finish = kind


var _finish := "chrome"
var _shine: Control
var _shine_t := 0.0


## A band of light sweeps across the rim once when the sheet opens (like light running over chrome).
func _start_shine() -> void:
	_shine = Control.new()
	_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shine.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_shine)
	_shine.draw.connect(_draw_shine)
	var tw := create_tween()
	tw.tween_method(func(v: float):
		_shine_t = v
		if is_instance_valid(_shine):
			_shine.queue_redraw(), 0.0, 1.0, 0.75).set_delay(0.08)
	tw.tween_callback(func():
		if is_instance_valid(_shine):
			_shine.queue_free())


func _draw_shine() -> void:
	if _panel == null:
		return
	var r := _panel.get_rect()
	var k := _shine_t
	var x := r.position.x - 120.0 + (r.size.x + 240.0) * k
	var a := (0.6 if _finish != "carbon" else 0.35) * sin(k * PI)
	var top := r.position.y + 3.0
	_shine.draw_colored_polygon(PackedVector2Array([Vector2(x, top), Vector2(x + 40, top), Vector2(x + 30, top + RIM_TOP), Vector2(x - 10, top + RIM_TOP)]),
		Color(1, 1, 1, a))


func close() -> void:
	Sfx.play("close")
	queue_free()


func clear_body() -> void:
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()


const RIM_TOP := 11
const RIM_SIDE := 11
const _TEX_N := 96
const _MARGIN := 32
static var _finish_tex := {}


## A 9-patch StyleBoxTexture: rounded top corners, an ink outline, a material rim, the panel blue inside.
static func finish_box(kind: String) -> StyleBox:
	if not _finish_tex.has(kind):
		_finish_tex[kind] = _make_finish(kind)
	var s := StyleBoxTexture.new()
	s.texture = _finish_tex[kind]
	s.texture_margin_left = _MARGIN
	s.texture_margin_right = _MARGIN
	s.texture_margin_top = _MARGIN
	s.texture_margin_bottom = _MARGIN
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE if kind == "carbon" else StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE if kind == "carbon" else StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 22
	s.content_margin_bottom = 36
	return s


static func _make_finish(kind: String) -> Texture2D:
	var n := _TEX_N
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rad := 26.0
	var ink := UiTheme.INK
	for y in n:
		for x in n:
			var px := x + 0.5
			var py := y + 0.5
			# distance inside the outer shape (rounded top corners, square bottom, open bottom edge)
			var d := minf(px, n - px)
			d = minf(d, py)
			if py < rad and (px < rad or px > n - rad):
				var cx := rad if px < rad else n - rad
				d = rad - Vector2(px - cx, py - rad).length()
			if d < 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var a := clampf(d * 1.5, 0.0, 1.0)   # anti-aliased outer edge
			var thick := RIM_SIDE
			var col: Color
			if d < 3.0:
				col = ink
			elif d < 3.0 + thick:
				var u := (d - 3.0) / thick                 # 0 at the outside of the rim .. 1 at the inside
				col = _rim_color(kind, u, x, y)
			elif d < 4.5 + thick:
				col = ink.lerp(UiTheme.PANEL, 0.35)        # a thin dark line where the rim meets the panel
			else:
				col = UiTheme.PANEL
			img.set_pixel(x, y, Color(col, col.a * a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _rim_color(kind: String, u: float, x: int, y: int) -> Color:
	match kind:
		"gloss":   # black gloss: deep black with a crisp highlight near the top of the rim and a faint blue sheen
			var c := Color("101318").lerp(Color("2a3140"), u * 0.6)
			c = c.lerp(Color(1, 1, 1), clampf(1.0 - absf(u - 0.28) / 0.12, 0.0, 1.0) * 0.55)
			return c
		"carbon":  # carbon fibre: a woven 2x2 twill in two dark greys, with a soft glossy highlight
			var cell := (int(x / 4) + int(y / 4)) % 2
			var diag := float((x + y) % 8) / 8.0
			var c := Color("23262c") if cell == 0 else Color("33373f")
			c = c.lerp(Color("4a505b"), diag * 0.35 * float(cell))
			c = c.lerp(Color(1, 1, 1), clampf(1.0 - absf(u - 0.3) / 0.15, 0.0, 1.0) * 0.18)
			return c
	# chrome: bright top, a dark reflection band, bright again at the inner lip
	var stops := [[0.0, Color("ffffff")], [0.25, Color("d9dee6")], [0.5, Color("7e8796")], [0.7, Color("aeb6c3")], [1.0, Color("eef2f7")]]
	for k in range(1, stops.size()):
		if u <= stops[k][0]:
			var t: float = (u - stops[k - 1][0]) / (stops[k][0] - stops[k - 1][0])
			return (stops[k - 1][1] as Color).lerp(stops[k][1], t)
	return stops[-1][1]


static func _sheet_box() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = UiTheme.PANEL
	s.corner_radius_top_left = 26
	s.corner_radius_top_right = 26
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 20
	s.content_margin_bottom = 36
	s.border_width_top = 5
	s.border_width_left = 4
	s.border_width_right = 4
	s.border_color = UiTheme.INK   # v0.17f: ink outline like the buttons
	s.anti_aliasing = true
	return s
