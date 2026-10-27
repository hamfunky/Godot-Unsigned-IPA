extends RefCounted
## Colours, the Godot Theme, and small drawing helpers shared by the UI scripts.

# v0.17d art pass: brighter, friendlier blues (bubbly cartoon look)
const BG := Color("1f3560")
const HUD := Color("3a8fd9")
const PANEL := Color("3559a6")          # popup sheets
const PANEL_LIGHT := Color("26407f")    # cards / rows inside a sheet (inset, darker)
const PANEL_EDGE := Color("7db3ff")     # light rim on sheets
const CARD := Color("2c51a3")           # v0.17f: raised bubbly tile inside sheets / HQ (see card())
const CARD_GOLD := Color("ffc93c")      # rim of a highlighted tile (claimable / wearing / premium)
const HQ_BG := Color("3a7bd5")          # Headquarters background
const ACCENT := Color("2f9bff")
const GOOD := Color("3ccf5a")
const WARN := Color("ff5a5f")
const CASH := Color("ffd23f")
const MUTED := Color("bcd0f0")
const TEXT := Color("ffffff")
const INK := Color("1d1b2b")            # cartoon outline colour

# station art
const WALL := Color("dfe9f2")
const WALL_TILE := Color("c9dbea")
const FLOOR := Color("8b97a8")
const FLOOR_LINE := Color("ffcc33")
const SLAB := Color("2a3550")
const LANE := Color("3a3f4a")
const LANE_LINE := Color("ffd23f")
const OFFICE_WALL := Color("2b5d8a")
const OFFICE_FLOOR := Color("e3b878")

## Fredoka (SIL OFL, free for commercial use): rounded, bubbly. Bold for titles + big numbers.
const DISPLAY_FONT = preload("res://assets/game/fonts/fredoka_700.ttf")
const BODY_FONT = preload("res://assets/game/fonts/fredoka_600.ttf")
const BTN_TEX := {
	"blue": preload("res://assets/game/ui/btn_blue.png"),
	"green": preload("res://assets/game/ui/btn_green.png"),
	"yellow": preload("res://assets/game/ui/btn_yellow.png"),
	"red": preload("res://assets/game/ui/btn_red.png"),
	"grey": preload("res://assets/game/ui/btn_grey.png"),
}


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 24
	t.default_font = BODY_FONT

	t.set_stylebox("panel", "PanelContainer", card(CARD, 18, 14))
	t.set_color("font_color", "Label", TEXT)

	t.set_stylebox("normal", "Button", box(ACCENT, 14, 10))
	t.set_stylebox("hover", "Button", box(ACCENT.lightened(0.12), 14, 10))
	t.set_stylebox("pressed", "Button", box(ACCENT.darkened(0.2), 14, 10))
	t.set_stylebox("disabled", "Button", box(Color("2b303c"), 14, 10))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("6b7280"))

	var pb := box(Color("1d2f63"), 9, 0)
	pb.set_border_width_all(2)
	pb.border_color = INK
	t.set_stylebox("background", "ProgressBar", pb)
	var pf := box(Color("5be36f"), 9, 0)
	pf.set_border_width_all(2)
	pf.border_color = INK
	t.set_stylebox("fill", "ProgressBar", pf)
	return t


static func box(c: Color, radius: int, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s


## Big title/number label in the game font.
static func display_label(text: String, font_size: int, color: Color = TEXT) -> Label:
	var l := label(text, font_size, color)
	l.add_theme_font_override("font", DISPLAY_FONT)
	return l


## v0.17h (playtest: "some text is tiny"): nothing smaller than MIN_FONT on a 720-wide screen.
const MIN_FONT := 18


static func label(text: String, font_size: int, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", maxi(font_size, MIN_FONT))
	l.add_theme_color_override("font_color", color)
	return l


## Chunky cartoon button (v0.17d): rounded, dark outline, a thick darker "lip" at the bottom
## that squashes when pressed, and a light shine along the top. Plays a click and bounces.
static func button(text: String, font_size: int, color: Color = ACCENT) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", maxi(font_size, MIN_FONT))
	b.add_theme_font_override("font", DISPLAY_FONT)
	var col := _btn_colour(color)
	b.add_theme_stylebox_override("normal", lip_box(col))
	b.add_theme_stylebox_override("hover", lip_box(col.lightened(0.07)))
	b.add_theme_stylebox_override("pressed", lip_box(col.darkened(0.06), true))
	b.add_theme_stylebox_override("disabled", lip_box(Color("8792a6")))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var dark := col.get_luminance() > 0.62
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, Color("3b2a00") if dark else Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color("e4e8f0"))
	if not dark:
		b.add_theme_color_override("font_outline_color", col.darkened(0.55))
		b.add_theme_constant_override("outline_size", maxi(4, font_size / 5))
	b.mouse_filter = Control.MOUSE_FILTER_PASS  # lets drags scroll lists
	b.pressed.connect(func():
		Sfx.play("click")
		Sfx.buzz(12)
		b.pivot_offset = b.size * 0.5
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(0.94, 0.94), 0.05)
		tw.tween_property(b, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	# shine strip along the top (drawn over the stylebox)
	b.draw.connect(func():
		if b.disabled:
			return
		var r := Rect2(Vector2(10, 5), Vector2(b.size.x - 20, maxf(4.0, b.size.y * 0.16)))
		b.draw_style_box(flat(Color(1, 1, 1, 0.22), int(r.size.y * 0.5)), r))
	return b


## The game's button palette: any colour passed in snaps to a bright cartoon version.
static func _btn_colour(c: Color) -> Color:
	if c.s < 0.25:
		return Color("8a94ab") if c.v > 0.3 else Color("5d6a85")
	var h := c.h
	if h < 0.04 or h > 0.92:
		return Color("ff5a5f")
	if h < 0.11:
		return Color("ff9a2e")
	if h < 0.17:
		return Color("ffc93c")
	if h < 0.45:
		return Color("3ccf5a")
	if h < 0.72:
		return Color("2f9bff")
	return Color("a259ff")


## Rounded box with an ink outline and a deep bottom lip (squashed when pressed).
static func lip_box(c: Color, pressed: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(16)
	s.set_border_width_all(3)
	s.border_width_bottom = 4 if pressed else 9
	s.border_color = c.darkened(0.42)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 9 if pressed else 6
	s.content_margin_bottom = 5 if pressed else 10
	s.anti_aliasing = true
	return s


## v0.17f bubbly tile: rounded, outlined, with a chunky darker lip along the bottom (like the
## buttons, but flatter). rim = a coloured outline for highlighted tiles (gold = claim / wearing).
static func card(c: Color = CARD, radius: int = 18, pad: int = 12, rim: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(radius)
	s.anti_aliasing = true
	var lit := rim.a > 0.0
	s.border_color = rim if lit else c.darkened(0.4)
	var side := 4 if lit else 2
	s.border_width_left = side
	s.border_width_right = side
	s.border_width_top = side
	s.border_width_bottom = 8 if lit else 7
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad + 5
	return s


## Give a label a dark outline so it reads on the bright backgrounds.
static func outlined(l: Label, size: int = 5) -> Label:
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", size)
	return l


## Section heading as a little rounded ribbon (v0.17f): white text on a coloured pill.
static func ribbon(text: String, font_size: int, c: Color) -> Label:
	var l := display_label(text, font_size, Color.WHITE)
	var col := c
	if col.get_luminance() > 0.6:
		col = col.darkened(0.25)
	var s := card(col, 14, 0)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 3
	s.content_margin_bottom = 7
	l.add_theme_stylebox_override("normal", s)
	l.add_theme_color_override("font_outline_color", col.darkened(0.55))
	l.add_theme_constant_override("outline_size", maxi(4, font_size / 4))
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return l


## Tab button look: the open tab is a bright yellow lip button, the others a calm blue.
static func set_tab_look(b: Button, active: bool) -> void:
	var col := Color("ffc93c") if active else Color("2a63c4")
	b.add_theme_stylebox_override("normal", lip_box(col))
	b.add_theme_stylebox_override("hover", lip_box(col.lightened(0.07)))
	b.add_theme_stylebox_override("pressed", lip_box(col.darkened(0.06), true))
	var fc := Color("3b2a00") if active else Color.WHITE
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, fc)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0) if active else col.darkened(0.55))
	b.queue_redraw()


## Soft bright background for full screens (HQ): blue with faint diagonal stripes + sparkles.
static func draw_pattern_bg(ci: CanvasItem, size: Vector2, base: Color = HQ_BG) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, size), base)
	var stripe := base.lightened(0.07)
	var step := 90.0
	var x := -size.y
	while x < size.x:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x, size.y), Vector2(x + 40, size.y),
			Vector2(x + 40 + size.y, 0), Vector2(x + size.y, 0)]), stripe)
		x += step
	for k in 14:
		var p := Vector2(fposmod(k * 233.0, size.x), fposmod(k * 157.0 + 60.0, size.y))
		sparkle(ci, p, 5.0 + (k % 3) * 2.0, Color(1, 1, 1, 0.16))


## Four-point twinkle star (sparkles on clean cars, backgrounds).
static func sparkle(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	if r < 0.6 or col.a <= 0.01:
		return   # v0.18: a near-zero star is a degenerate polygon (printed "triangulation failed")
	var t := r * 0.28
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(t, -t), c + Vector2(r, 0), c + Vector2(t, t),
		c + Vector2(0, r), c + Vector2(-t, t), c + Vector2(-r, 0), c + Vector2(-t, -t)]), col)


## Old Kenney texture boxes (kept for anything that still asks for one).
static func tex_box(set_name: String, tint: Color = Color.WHITE) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load("res://assets/game/ui/btn_%s.png" % set_name)
	s.texture_margin_left = 12
	s.texture_margin_right = 12
	s.texture_margin_top = 12
	s.texture_margin_bottom = 16
	s.modulate_color = tint
	return s


## Little red "!" badge (used to show the slowest part of the chain).
static func alert_mark(ci: CanvasItem, c: Vector2, r: float = 13.0) -> void:
	var pulse := 1.0 + 0.08 * sin(Time.get_ticks_msec() * 0.008)
	ci.draw_circle(c, r * pulse + 2, Color(0, 0, 0, 0.5))
	ci.draw_circle(c, r * pulse, WARN)
	ci.draw_rect(Rect2(c.x - r * 0.13, c.y - r * 0.6, r * 0.26, r * 0.72), Color.WHITE)
	ci.draw_circle(c + Vector2(0, r * 0.42), r * 0.15, Color.WHITE)


## Text with a dark outline so it reads on top of art.
static func text(ci: CanvasItem, pos: Vector2, s: String, font_size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := 6, font: Font = null) -> void:
	if font == null:
		font = BODY_FONT
	if outline > 0:
		ci.draw_string_outline(font, pos, s, align, width, font_size, outline, Color(INK.r, INK.g, INK.b, 0.9 * color.a))
	ci.draw_string(font, pos, s, align, width, font_size, color)


static func rounded(ci: CanvasItem, r: Rect2, c: Color, radius: int, border := 0, border_color := Color.BLACK) -> void:
	ci.draw_style_box(flat(c, radius, border, border_color), r)


## v0.19v perf: rounded boxes drawn every frame used to build a brand-new StyleBoxFlat each time (hundreds a
## frame). Now one is made per look and reused. Don't change a box you get from here.
static var _flat_cache := {}

static func flat(c: Color, radius: int, border := 0, border_color := Color.BLACK) -> StyleBoxFlat:
	var key := [c, radius, border, border_color if border > 0 else Color.BLACK]
	var s: StyleBoxFlat = _flat_cache.get(key)
	if s != null:
		return s
	if _flat_cache.size() > 3000:
		_flat_cache.clear()   # (fading colours make new looks every frame: start again now and then)
	s = StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(radius)
	s.anti_aliasing = true
	if border > 0:
		s.set_border_width_all(border)
		s.border_color = border_color
	_flat_cache[key] = s
	return s


## v0.19r: a signature's payoff ("+$5K  LOT CLEARED x1.5!") pops up over a station, grows, holds, floats off.
static func pop_text(parent: Control, text: String, pos: Vector2, col: Color = Color("ffd23f"), size: int = 28) -> void:
	var l: Control
	if text.contains("{"):   # v0.19v: "+5 {sb}" pops with the banknote icon
		l = rich_row(text, size, col, 9)
		l.alignment = BoxContainer.ALIGNMENT_BEGIN
	else:
		l = display_label(text, size, col)
		l.add_theme_color_override("font_outline_color", INK)
		l.add_theme_constant_override("outline_size", 9)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	l.position = pos
	l.pivot_offset = Vector2(160, 20)
	l.scale = Vector2(0.4, 0.4)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2(1.1, 1.1), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.15)
	tw.tween_interval(1.4)
	tw.tween_property(l, "position:y", pos.y - 40.0, 0.6)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


# ---------------------------------------------------------------- v0.19v: icons inside text
## Write "{sb}" in a string where a price's currency goes: "30 {sb}" shows as 30 + the Shine Bucks banknote.
## Other tokens: {wheel} {booster} {wardrobe}. Buttons: set_rich(b, s). Wrapped sentences: rich_label() /
## set_bb() (a RichTextLabel with inline images). plain(s) gives the words back where only text works.
const ICON_TOKENS := ["sb", "wheel", "booster", "wardrobe", "ad"]   # v0.19w: {ad} = watch-an-ad screen


static func plain(s: String) -> String:
	return s.replace("{sb}", "Shine Bucks").replace("{wheel}", "").replace("{booster}", "").replace("{wardrobe}", "").replace("{ad}", "").strip_edges()


static func _icon_path(n: String) -> String:
	return "res://assets/game/ui/icon_%s.png" % n


static func _icon_w(n: String, h: float) -> float:
	return h * (1.33 if n == "sb" else 1.0)


## BBCode for a RichTextLabel: tokens become inline images sized to the font.
static func bb(s: String, font_size: int) -> String:
	for n in ICON_TOKENS:
		var h := int(font_size * (1.0 if n == "sb" else 1.25))
		s = s.replace("{%s}" % n, "[img=%dx%d]%s[/img]" % [int(_icon_w(n, h)), h, _icon_path(n)])
	return s


## A wrapped, centred line of text with icons in it (RichTextLabel). Read back the words with .get_parsed_text().
static func rich_label(s: String, font_size: int, color: Color = TEXT, outline := 0, display := false, center := true) -> RichTextLabel:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fs := maxi(font_size, MIN_FONT)
	l.add_theme_font_size_override("normal_font_size", fs)
	l.add_theme_font_override("normal_font", DISPLAY_FONT if display else BODY_FONT)
	l.add_theme_color_override("default_color", color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", INK)
		l.add_theme_constant_override("outline_size", outline)
	l.set_meta("rich_center", center)
	set_bb(l, s)
	return l


static func set_bb(l: RichTextLabel, s: String) -> void:
	if l.has_meta("rich_src") and l.get_meta("rich_src") == s:
		return
	l.set_meta("rich_src", s)
	var fs := l.get_theme_font_size("normal_font_size")
	var t := bb(s, fs)
	l.text = ("[center]%s[/center]" % t) if l.get_meta("rich_center", true) else t


## A Button whose text has icons in it: the button's own text is emptied and a centred row of
## labels + icons is laid over it (same font, colours and outline as the button).
static func set_rich(b: Button, s: String) -> void:
	var dis := b.disabled
	if b.has_meta("rich_src") and b.get_meta("rich_src") == s and b.get_meta("rich_dis", false) == dis:
		return
	b.set_meta("rich_src", s)
	b.set_meta("rich_dis", dis)
	var old := b.get_node_or_null("RichRow")
	if old != null:
		old.free()
	var has_icon := false
	for n in ICON_TOKENS:
		if s.contains("{%s}" % n):
			has_icon = true
	if not has_icon:
		b.text = s
		return
	b.text = ""
	var fs := b.get_theme_font_size("font_size")
	var col := b.get_theme_color("font_disabled_color" if dis else "font_color")
	var oc := b.get_theme_color("font_outline_color")
	var os := b.get_theme_constant("outline_size")
	var cc := CenterContainer.new()
	cc.name = "RichRow"
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := b.get_theme_stylebox("normal")
	if sb != null:
		cc.offset_top = sb.content_margin_top
		cc.offset_bottom = -sb.content_margin_bottom
		cc.offset_left = sb.content_margin_left
		cc.offset_right = -sb.content_margin_right
	b.add_child(cc)
	cc.add_child(rich_row(s, fs, col, os, true, oc, 0.5 if dis else 1.0))


## An HBox of labels + icon textures for one line ("SPIN  ·  50 {sb}").
static func rich_row(s: String, font_size: int, color: Color, outline := 0, display := true, outline_color := INK, icon_alpha := 1.0) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var parts: Array = [s]
	for n in ICON_TOKENS:
		var nxt: Array = []
		for p in parts:
			if p is String:
				var bits: PackedStringArray = (p as String).split("{%s}" % n)
				for i in bits.size():
					if bits[i] != "":
						nxt.append(bits[i])
					if i < bits.size() - 1:
						nxt.append({"icon": n})
			else:
				nxt.append(p)
		parts = nxt
	for p in parts:
		if p is String:
			var l := Label.new()
			l.text = p
			l.add_theme_font_size_override("font_size", font_size)
			l.add_theme_font_override("font", DISPLAY_FONT if display else BODY_FONT)
			l.add_theme_color_override("font_color", color)
			if outline > 0:
				l.add_theme_color_override("font_outline_color", outline_color)
				l.add_theme_constant_override("outline_size", outline)
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h.add_child(l)
		else:
			var n: String = p["icon"]
			var ih := font_size * (1.0 if n == "sb" else 1.3)
			var tr := TextureRect.new()
			tr.texture = load(_icon_path(n))
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.custom_minimum_size = Vector2(_icon_w(n, ih) + 6.0, ih)
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			tr.modulate.a = icon_alpha
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h.add_child(tr)
	return h
