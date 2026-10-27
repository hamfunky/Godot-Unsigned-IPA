extends RefCounted
## Placeholder art drawn in code: cars and people.
## When real sprites arrive, swap these functions for texture draws and the
## rest of the UI keeps working (every row calls these with a rect/position).


# Kenney CC0 character + vehicle sprites
const DETAILER := [preload("res://assets/game/sprites/detailer_idle.png"),
	preload("res://assets/game/sprites/detailer_work.png"), preload("res://assets/game/sprites/detailer_cheer.png")]
const CASHIER := [preload("res://assets/game/sprites/cashier_idle.png"),
	preload("res://assets/game/sprites/cashier_work.png"), preload("res://assets/game/sprites/cashier_cheer.png")]
const FACES := [preload("res://assets/game/sprites/face_0.png"), preload("res://assets/game/sprites/face_1.png"),
	preload("res://assets/game/sprites/face_2.png"), preload("res://assets/game/sprites/face_3.png")]
const CarArt = preload("res://scripts/car_art.gd")
enum { POSE_IDLE, POSE_WORK, POSE_CHEER }


const CHAR_SRC := Rect2(0, 28, 96, 100)   # the figure inside the 96x128 Kenney frames (top is empty)


## Character sprite standing on `feet`, `height` px tall (visible figure). facing -1 = mirrored.
static func draw_character(ci: CanvasItem, frames: Array, pose: int, feet: Vector2, height: float, facing: float = 1.0) -> void:
	var tex: Texture2D = frames[pose]
	var w := CHAR_SRC.size.x * height / CHAR_SRC.size.y
	ci.draw_set_transform(feet, 0.0, Vector2(signf(facing), 1.0))
	ci.draw_texture_rect_region(tex, Rect2(-w * 0.5, -height, w, height), CHAR_SRC)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Head-and-shoulders crop of a character for manager portraits.
static func draw_face_sprite(ci: CanvasItem, rect: Rect2, variant: int) -> void:
	var tex: Texture2D = FACES[variant % FACES.size()]
	var src := Rect2(12, 26, 72, 72)   # head + shoulders
	ci.draw_texture_rect_region(tex, rect, src)


## The valet's ute from above (v0.17f: bubbly cartoon ute drawn in code, replaces the Kenney sprite),
## with the cash it's carrying in the tray: fill 0 = empty, 1/4, 1/2, 3/4, >= 1 overflowing.
## facing_down = driving down the lane. `width` = body width; it's ~1.9x as long.
static func draw_ute_sprite(ci: CanvasItem, center: Vector2, width: float, fill: float, facing_down: bool, paint: Color = Color("ffc93c")) -> void:
	var w := width
	var h := w * 1.9
	var t := Time.get_ticks_msec() * 0.001
	var ink := Color("1d1b2b")
	# a tiny bounce so it feels like it's rolling
	ci.draw_set_transform(center + Vector2(0, sin(t * 11.0) * 0.7), PI if facing_down else 0.0, Vector2.ONE)
	var body := Rect2(-w * 0.5, -h * 0.5, w, h)
	# soft shadow + chunky tyres poking out the sides
	_rr(ci, Rect2(body.position + Vector2(3, 6), body.size), Color(0, 0, 0, 0.22), int(w * 0.34))
	for ty: float in [-0.29, 0.27]:
		for sx: float in [-1.0, 1.0]:
			var tr := Rect2(sx * w * 0.5 - (7.0 if sx < 0 else 1.0), h * ty - h * 0.08, 8, h * 0.16)
			_rr(ci, tr, Color("2b2d3a"), 4, 2, ink)
	# body
	_rr(ci, body, paint, int(w * 0.34), 3, ink)
	# bonnet shine + headlights at the front (top)
	_rr(ci, Rect2(-w * 0.32, -h * 0.47, w * 0.64, h * 0.06), Color(1, 1, 1, 0.35), 4)
	for sx: float in [-1.0, 1.0]:
		ci.draw_circle(Vector2(sx * w * 0.3, -h * 0.43), w * 0.1 + 1.5, ink)
		ci.draw_circle(Vector2(sx * w * 0.3, -h * 0.43), w * 0.1, Color("fff6b8"))
	# cab roof with a windscreen (front) and a small back window
	var cab := Rect2(-w * 0.4, -h * 0.33, w * 0.8, h * 0.31)
	_rr(ci, cab, paint.lightened(0.12), int(w * 0.18), 3, ink)
	var ws := PackedVector2Array([Vector2(-w * 0.34, -h * 0.30), Vector2(w * 0.34, -h * 0.30), Vector2(w * 0.28, -h * 0.20), Vector2(-w * 0.28, -h * 0.20)])
	ci.draw_colored_polygon(ws, Color("8fe0ff"))
	var wso := ws.duplicate()
	wso.append(ws[0])
	ci.draw_polyline(wso, ink, 2.0, true)
	ci.draw_line(Vector2(-w * 0.18, -h * 0.29), Vector2(-w * 0.26, -h * 0.21), Color(1, 1, 1, 0.8), 3.0)
	_rr(ci, Rect2(-w * 0.28, -h * 0.09, w * 0.56, h * 0.05), Color("8fe0ff"), 3, 2, ink)
	_rr(ci, Rect2(-w * 0.26, -h * 0.17, w * 0.3, h * 0.04), Color(1, 1, 1, 0.3), 3)
	# tray (back half)
	var tray := Rect2(-w * 0.4, h * 0.0, w * 0.8, h * 0.45)
	_rr(ci, tray, paint.darkened(0.3), 6, 3, ink)
	var inner := tray.grow(-4)
	_rr(ci, inner, Color("6b4a33"), 4)
	for k in 3:
		ci.draw_line(Vector2(inner.position.x + 2, inner.position.y + inner.size.y * (k + 1) / 4.0),
			Vector2(inner.end.x - 2, inner.position.y + inner.size.y * (k + 1) / 4.0), Color(0, 0, 0, 0.18), 1.5)
	# tail lights
	for sx: float in [-1.0, 1.0]:
		_rr(ci, Rect2(sx * w * 0.3 - w * 0.08, h * 0.455, w * 0.16, 4), Color("ff5a5f"), 2, 1, ink)
	# cash bundles: 2 columns x 4 rows, filled from the cab end backwards
	var bundles := 0
	if fill > 0.0:
		bundles = 2 if fill <= 0.25 else (4 if fill <= 0.5 else (6 if fill <= 0.75 else 8))
	var bw := inner.size.x * 0.5 - 2
	var bh := inner.size.y * 0.25 - 2
	for k in bundles:
		var b := Rect2(inner.position.x + 1 + (k % 2) * (bw + 2), inner.position.y + (k / 2) * (bh + 2) + 1, bw, bh)
		_rr(ci, b, Color("4cc265"), 2, 1, Color("1f6b33"))
		ci.draw_rect(Rect2(b.position.x + b.size.x * 0.38, b.position.y, b.size.x * 0.24, b.size.y), Color("fff3c4"))
	# overflowing: notes flapping over the sides + one flying off the back
	if fill >= 0.999:
		var tt := t * 4.0
		for k in 6:
			var side := -1.0 if k % 2 == 0 else 1.0
			var py := inner.position.y + inner.size.y * (0.1 + 0.15 * k)
			var px := side * (inner.size.x * 0.5 + 6 + 3 * sin(tt + k))
			var note := PackedVector2Array([Vector2(px - 8, py - 4), Vector2(px + 8, py - 6 + 2 * sin(tt * 1.3 + k)),
				Vector2(px + 9, py + 5), Vector2(px - 7, py + 6)])
			ci.draw_colored_polygon(note, Color("66d17a"))
			var no := note.duplicate()
			no.append(note[0])
			ci.draw_polyline(no, Color("1f6b33"), 1.5, true)
		var fly := fposmod(tt * 6.0, 22.0)
		_rr(ci, Rect2(-7 + sin(tt * 2.0) * 8, tray.end.y + 4 + fly, 14, 8), Color("81d98f"), 2, 1, Color("1f6b33"))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _rr(ci: CanvasItem, r: Rect2, c: Color, radius: int, border: int = 0, border_color: Color = Color.BLACK) -> void:
	ci.draw_style_box(load("res://scripts/ui_theme.gd").flat(c, radius, border, border_color), r)   # v0.19v: cached


## Side-on car filling `rect` (v0.17d: the cartoon cars in car_art.gd). `car` = its Data entry
## (picks the body style); dirt 1 = filthy, 0 = clean; specks = Array[Vector3] of dirt spots;
## silhouette = one flat colour (undiscovered cars in the Book).
static func draw_car(ci: CanvasItem, rect: Rect2, color: Color, dirt: float, specks: Array, shine: float = 0.0, silhouette: bool = false, car: Dictionary = {}) -> void:
	CarArt.draw(ci, rect, car if not car.is_empty() else {"tier": 2, "class": "jdm"}, color, dirt, specks, shine, silhouette)


## A car's own paint colour in the Book (always the same for the same model).
static func book_color(car: Dictionary) -> Color:
	if car.has("color"):
		return Color(car["color"])
	var cols := ["e53935", "1e88e5", "43a047", "fdd835", "8e24aa", "fb8c00", "eceff1", "37474f", "00acc1", "d81b60", "6d4c41"]
	return Color(cols[absi(hash(str(car.get("id", "")))) % cols.size()])


static func new_specks() -> Array:
	var a := []
	for k in 26:
		a.append(Vector3(randf(), randf(), randf_range(0.5, 1.0)))
	return a


## Top-down car for the valet lane. center = middle of the car, facing down.
static func draw_car_top(ci: CanvasItem, center: Vector2, w: float, color: Color) -> void:
	var h := w * 1.7
	var r := Rect2(center - Vector2(w, h) * 0.5, Vector2(w, h))
	for wy: float in [0.18, 0.72]:
		ci.draw_rect(Rect2(r.position.x - 4, r.position.y + h * wy, 6, h * 0.14), Color("111111"))
		ci.draw_rect(Rect2(r.end.x - 2, r.position.y + h * wy, 6, h * 0.14), Color("111111"))
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(w * 0.3))
	ci.draw_style_box(sb, r)
	ci.draw_rect(Rect2(r.position.x + w * 0.15, r.position.y + h * 0.55, w * 0.7, h * 0.16), Color("9fd3ff"))
	ci.draw_rect(Rect2(r.position.x + w * 0.18, r.position.y + h * 0.25, w * 0.64, h * 0.1), Color("6fa3c8"))
	ci.draw_rect(Rect2(r.position.x + w * 0.1, r.end.y - 6, w * 0.22, 4), Color("ffe08a"))
	ci.draw_rect(Rect2(r.end.x - w * 0.32, r.end.y - 6, w * 0.22, 4), Color("ffe08a"))


## Simple worker figure standing on `feet`. Placeholder for real character sprites.
## work = 0..1 animation phase (arm scrubbing); facing = 1 right, -1 left.
static func draw_person(ci: CanvasItem, feet: Vector2, height: float, shirt: Color, cap: Color,
		work: float = 0.0, facing: float = 1.0, skin: Color = Color("e0ac69")) -> void:
	var head_r := height * 0.14
	var body_h := height * 0.42
	var leg_h := height * 0.3
	var body_w := height * 0.3
	var hip := feet - Vector2(0, leg_h)
	# legs
	ci.draw_line(feet + Vector2(-body_w * 0.22, 0), hip + Vector2(-body_w * 0.2, 0), Color("2d3a4f"), body_w * 0.32)
	ci.draw_line(feet + Vector2(body_w * 0.22, 0), hip + Vector2(body_w * 0.2, 0), Color("2d3a4f"), body_w * 0.32)
	# body
	var body := Rect2(hip.x - body_w * 0.5, hip.y - body_h, body_w, body_h + 2)
	var sb := StyleBoxFlat.new()
	sb.bg_color = shirt
	sb.set_corner_radius_all(int(body_w * 0.35))
	ci.draw_style_box(sb, body)
	# scrubbing arm
	var shoulder := Vector2(hip.x + facing * body_w * 0.3, body.position.y + body_h * 0.25)
	var reach := Vector2(facing * height * 0.28, -height * 0.05 + sin(work * TAU) * height * 0.1)
	ci.draw_line(shoulder, shoulder + reach, skin, body_w * 0.24)
	ci.draw_circle(shoulder + reach, body_w * 0.2, Color("ffeb3b"))  # sponge
	# head + cap
	var head := Vector2(hip.x, body.position.y - head_r * 0.9)
	ci.draw_circle(head, head_r, skin)
	ci.draw_circle(head + Vector2(facing * head_r * 0.4, -head_r * 0.1), head_r * 0.12, Color("222222"))
	var capr := Rect2(head.x - head_r, head.y - head_r * 1.05, head_r * 2.0, head_r * 0.75)
	sb = StyleBoxFlat.new()
	sb.bg_color = cap
	sb.corner_radius_top_left = int(head_r)
	sb.corner_radius_top_right = int(head_r)
	ci.draw_style_box(sb, capr)
	ci.draw_rect(Rect2(head.x + (0.0 if facing > 0 else -head_r * 1.5), head.y - head_r * 0.4, head_r * 1.5, head_r * 0.22), cap.darkened(0.25))


## Face for manager portraits: head + crew-coloured cap + shirt collar.
static func draw_face(ci: CanvasItem, rect: Rect2, cap: Color, skin: Color, hair: Color) -> void:
	var c := rect.get_center() + Vector2(0, rect.size.y * 0.06)
	var r := rect.size.x * 0.3
	# shoulders
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f4f6fa")
	sb.corner_radius_top_left = int(r)
	sb.corner_radius_top_right = int(r)
	ci.draw_style_box(sb, Rect2(c.x - r * 1.35, c.y + r * 0.8, r * 2.7, rect.end.y - (c.y + r * 0.8)))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(c.x - r * 0.25, c.y + r * 0.8),
		Vector2(c.x + r * 0.25, c.y + r * 0.8), Vector2(c.x, c.y + r * 1.4)]), cap)
	ci.draw_circle(c, r, skin)
	ci.draw_circle(c + Vector2(-r * 0.35, -r * 0.05), r * 0.11, Color("222222"))
	ci.draw_circle(c + Vector2(r * 0.35, -r * 0.05), r * 0.11, Color("222222"))
	ci.draw_arc(c + Vector2(0, r * 0.2), r * 0.35, 0.3, PI - 0.3, 10, Color("7a3e2b"), 2.5)
	ci.draw_rect(Rect2(c.x - r * 1.0, c.y - r * 0.75, r * 0.25, r * 0.6), hair)
	ci.draw_rect(Rect2(c.x + r * 0.75, c.y - r * 0.75, r * 0.25, r * 0.6), hair)
	sb = StyleBoxFlat.new()
	sb.bg_color = cap
	sb.corner_radius_top_left = int(r)
	sb.corner_radius_top_right = int(r)
	ci.draw_style_box(sb, Rect2(c.x - r * 1.05, c.y - r * 1.15, r * 2.1, r * 0.7))
	ci.draw_rect(Rect2(c.x - r * 1.05, c.y - r * 0.5, r * 2.4, r * 0.18), cap.darkened(0.25))


## Top-down ute for the valet lane. The tray shows the cash it's carrying:
## fill 0 = empty, then 1/4, 1/2, 3/4 full, and >= 1 = overflowing.
## facing_down = driving down the lane (front of the ute at the bottom).
static func draw_ute_top(ci: CanvasItem, center: Vector2, w: float, color: Color, fill: float, facing_down: bool) -> void:
	var h := w * 2.1
	var dir := 1.0 if facing_down else -1.0
	var r := Rect2(center - Vector2(w, h) * 0.5, Vector2(w, h))
	# wheels
	for wy: float in [0.16, 0.74]:
		ci.draw_rect(Rect2(r.position.x - 4, r.position.y + h * wy, 6, h * 0.13), Color("111111"))
		ci.draw_rect(Rect2(r.end.x - 2, r.position.y + h * wy, 6, h * 0.13), Color("111111"))
	# cab = front 42%, tray = back 58%
	var front_y := r.end.y if facing_down else r.position.y
	var cab_len := h * 0.42
	var cab := Rect2(r.position.x, front_y - (cab_len if facing_down else 0.0), w, cab_len)
	var tray := Rect2(r.position.x, (r.position.y if facing_down else r.position.y + cab_len), w, h - cab_len)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(w * 0.22))
	ci.draw_style_box(sb, cab)
	# windscreen + roof
	var ws_y := cab.position.y + (cab_len * 0.55 if facing_down else cab_len * 0.15)
	ci.draw_rect(Rect2(cab.position.x + w * 0.14, ws_y, w * 0.72, cab_len * 0.3), Color("9fd3ff"))
	# headlights at the very front
	var hl_y := (cab.end.y - 5) if facing_down else (cab.position.y + 1)
	ci.draw_rect(Rect2(cab.position.x + w * 0.08, hl_y, w * 0.22, 4), Color("ffe08a"))
	ci.draw_rect(Rect2(cab.end.x - w * 0.3, hl_y, w * 0.22, 4), Color("ffe08a"))
	# tray: sides + floor
	ci.draw_rect(tray, color.darkened(0.35))
	var inner := tray.grow(-4)
	ci.draw_rect(inner, Color("3e2f22"))
	# cash bundles: 2 columns x 4 rows; phases fill 0/2/4/6/8 bundles
	var bundles := 0
	if fill > 0.0:
		bundles = 2 if fill <= 0.25 else (4 if fill <= 0.5 else (6 if fill <= 0.75 else 8))
	var bw := inner.size.x * 0.5 - 2
	var bh := inner.size.y * 0.25 - 2
	for k in bundles:
		var col := k % 2
		var row := k / 2
		# stack from the cab end backwards
		var ry := (inner.end.y - (row + 1) * (bh + 2)) if facing_down else (inner.position.y + row * (bh + 2))
		var b := Rect2(inner.position.x + 1 + col * (bw + 2), ry + 1, bw, bh)
		ci.draw_rect(b, Color("43a047"))
		ci.draw_rect(Rect2(b.position.x, b.position.y + b.size.y * 0.4, b.size.x, b.size.y * 0.2), Color("e8f5e9"))
	# overflowing: notes spilling over the sides
	if fill >= 0.999:
		var t := Time.get_ticks_msec() * 0.004
		for k in 6:
			var side := -1.0 if k % 2 == 0 else 1.0
			var py := inner.position.y + inner.size.y * (0.15 + 0.14 * k)
			var px := center.x + side * (w * 0.5 + 2 + 3 * sin(t + k))
			var note := PackedVector2Array([
				Vector2(px - 7, py - 4), Vector2(px + 7, py - 6 + 2 * sin(t * 1.3 + k)),
				Vector2(px + 8, py + 4), Vector2(px - 6, py + 5)])
			ci.draw_colored_polygon(note, Color("66bb6a"))
		# a note flying off the back
		var back_y := (tray.position.y - 10) if facing_down else (tray.end.y + 10)
		var fly := fposmod(t * 6.0, 20.0)
		ci.draw_rect(Rect2(center.x - 6 + sin(t * 2.0) * 8, back_y - dir * fly, 12, 7), Color("81c784"))
