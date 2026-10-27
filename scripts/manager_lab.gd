extends Control
## Manager Lab (v0.19): preview the posh cash managers, their idle loops, the INSTRUCT animation and the
## suds-aura effect. Open scenes/manager_lab.tscn and press F6.
## Top: Junior / Senior / Executive big. Bottom: the same at real size in bays + one valet (points left).
## Buttons: ABILITY (toggle all), POSE (next idle loop), LOOKS (next people), KIND (income / speed / discount).
## `-- preview` hides the buttons and runs an automatic on / off schedule (used to record the video).

const Rig = preload("res://scripts/manager_rig.gd")
const Anim = preload("res://scripts/manager_anim.gd")
const Aura = preload("res://scripts/manager_aura.gd")
const Data = preload("res://scripts/game_data.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")

const KINDS := ["income", "speed", "discount"]
var men: Array = []        # {anim, feet, h, kind, crew, alpha, auto_off}
var preview := false
var _look_shift := 0
var _kind_shift := 0
var _clock := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	preview = "preview" in OS.get_cmdline_user_args()
	_build()
	if preview:
		return
	var bar := HBoxContainer.new()
	bar.position = Vector2(12, 1170)
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)
	for m in [["ABILITY", Color("ef6c00")], ["POSE", Color("4caf50")], ["LOOKS", Color("7e57c2")], ["KIND", Color("2196f3")]]:
		var b := UiTheme.button(m[0], 18, m[1])
		b.custom_minimum_size = Vector2(160, 70)
		b.pressed.connect(func(): _press(m[0]))
		bar.add_child(b)


func _build() -> void:
	men.clear()
	var jr := Rig.looks_of_tier(0)
	var sr := Rig.looks_of_tier(1)
	var ex := Rig.looks_of_tier(2)
	var crews := []
	for c in Data.CREWS:
		crews.append(Color(c["color"]))
	var big := [[jr, 120.0, 0], [sr, 360.0, 1], [ex, 600.0, 2]]
	for i in big.size():
		var pool: Array = big[i][0]
		var li: int = pool[(_look_shift + i) % pool.size()]
		men.append(_man(li, (i + _look_shift) % 4, Vector2(big[i][1], 560), 340.0, KINDS[(i + _kind_shift) % 3], crews[i % 4], 1.0, i * 0.37))
	# real size row (bays: point right) + a valet (points left)
	var row := [[jr, 1, 3], [sr, 2, 0], [ex, 3, 2], [jr, 4, 1], [sr, 5, 2], [ex, 6, 0]]
	for i in row.size():
		var pool: Array = row[i][0]
		var li: int = pool[(_look_shift + row[i][1]) % pool.size()]
		var feet := Vector2(70 + (i % 3) * 230, 820 + int(i / 3) * 170)
		men.append(_man(li, (row[i][2] + _look_shift) % 4, feet, 94.0 * (270.0 / 250.0), KINDS[(i + _kind_shift) % 3], crews[(i + 1) % 4], -1.0 if i == 5 else 1.0, 1.0 + i * 0.61))


func _man(li: int, pose: int, feet: Vector2, h: float, kind: String, crew: Color, dir: float, seed: float) -> Dictionary:
	var a := Anim.new(li, pose, seed)
	a.point_dir = dir
	return {"anim": a, "feet": feet, "h": h, "kind": kind, "crew": crew, "alpha": 0.0, "seed": seed}


func _press(what: String) -> void:
	match what:
		"ABILITY":
			var on: bool = not men[0]["anim"].active
			for m in men:
				m["anim"].active = on
		"POSE":
			for m in men:
				m["anim"].idle = (m["anim"].idle + 1) % 4
		"LOOKS":
			_look_shift += 1
			_build()
		"KIND":
			_kind_shift += 1
			for i in men.size():
				men[i]["kind"] = KINDS[(i + _kind_shift) % 3]


func _process(delta: float) -> void:
	_clock += delta
	if preview and int(floor((_clock - 1.6) / 9.0)) > _look_shift and _clock > 1.6:
		_look_shift += 1      # next people + next idle loops, while everyone is idle
		_build()
	for m in men:
		if preview:
			# idle 3 s, ability 6 s, staggered a little per manager
			var ph := fposmod(_clock - float(m["seed"]) * 0.35, 9.0)
			m["anim"].active = ph > 3.0
		m["anim"].update(delta)
		m["alpha"] = move_toward(m["alpha"], 1.0 if m["anim"].active else 0.0, delta / 0.55)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("f4f7fb"))
	# a bay-ish backdrop for the real-size rows
	for r in 2:
		var top := 700.0 + r * 170.0
		draw_rect(Rect2(0, top, size.x, 150), Color("d4ecfa"))
		for x in range(0, int(size.x), 60):
			draw_rect(Rect2(x + 2, top + 8, 56, 26), Color("e6f4fd"))
		draw_rect(Rect2(0, top + 92, size.x, 6), Color("29b6f6"))
		draw_rect(Rect2(0, top + 122, size.x, 28), Color("b0bec5"))
	draw_rect(Rect2(0, 0, size.x, 640), Color("cfe8f7"))
	UiTheme.text(self, Vector2(16, 40), "MANAGER LAB · idle loops / instruct / suds aura", 22, Color("1d1b2b"), HORIZONTAL_ALIGNMENT_LEFT, -1, 0)
	for m in men:
		var a = m["anim"]
		var t: float = a.t
		Aura.draw_back(self, m["feet"], m["h"], "suds", m["kind"], m["alpha"], t, m["seed"])
		Rig.draw(self, m["feet"], m["h"], a.look, a.pose(), m["crew"], a.mem, Aura.rim("suds", m["kind"], m["alpha"], t), a.point_dir)
		Aura.draw_front(self, m["feet"], m["h"], "suds", m["kind"], m["alpha"], t, m["seed"])
