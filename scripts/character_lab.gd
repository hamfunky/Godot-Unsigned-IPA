extends Control
## Character Lab (v0.18): preview the detailer rig + animations. Open scenes/character_lab.tscn and press F6.
## Big view on top, the same guys at real size in a bay underneath.
##   IDLE / SCRUB  = the free-running states.
##   FOAM JOB      = real cars go through: foam cannon, then scrub; the foam builds on the car where it's
##                   sprayed and comes off as the scrub goes; the car is clean exactly when its time is up.
##   4s / 6s / 8s / 13.5s = seconds per car (Bay 1 = 4s, each deeper bay +0.5s, Bay 20 = 13.5s).
## Run with `-- preview [anim=idle|scrub|job] [car=6]` to hide the buttons (used to record the previews).

const Rig = preload("res://scripts/detailer_rig.gd")
const Anim = preload("res://scripts/detailer_anim.gd")
const Foam = preload("res://scripts/foam_layer.gd")
const Polish = preload("res://scripts/polish_layer.gd")
const Data = preload("res://scripts/game_data.gd")
const Art = preload("res://scripts/car_view.gd")
const Scenery = preload("res://scripts/scenery.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")

const BAY_H := 88.0
const CAR_COLORS := ["2e7d6b", "c62828", "1565c0", "f9a825", "6a1b9a", "455a64"]
const CAR := {"tier": 2, "class": "jdm"}          # what Art.draw_car draws when given no car

var big := Anim.new(1)
var left := Anim.new(2)
var right := Anim.new(3)
var mode := "job"
var car_time := 6.0
var speed := 1.0
var facing := 1.0
var preview := false
var p := 0.0                       # progress of the car in the job
var _car_i := 0
var _specks: Array = []
var _foam_big := Foam.new(1)
var _foam_bay := Foam.new(2)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var args := OS.get_cmdline_user_args()
	preview = "preview" in args
	_specks = Art.new_specks()
	for a in args:
		if a.begins_with("anim="):
			mode = a.substr(5)
		elif a.begins_with("car="):
			car_time = float(a.substr(4))
	_set_mode(mode)
	if "flexnow" in args:
		for a in [big, left, right]:
			a.celebrate()
	if preview:
		return
	var bar := HBoxContainer.new()
	bar.position = Vector2(12, 1080)
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)
	for m in [["IDLE", "idle"], ["SCRUB", "scrub"], ["FOAM JOB", "job"], ["POLISH JOB", "polish"]]:
		var b := UiTheme.button(m[0], 18, Color("4caf50"))
		b.custom_minimum_size = Vector2(120, 60)
		b.pressed.connect(func(): _set_mode(m[1]))
		bar.add_child(b)
	var fx := UiTheme.button("FLEX", 18, Color("e91e63"))
	fx.custom_minimum_size = Vector2(90, 60)
	fx.pressed.connect(func(): for a in [big, left, right]: a.celebrate())
	bar.add_child(fx)
	var row := HBoxContainer.new()
	row.position = Vector2(12, 1150)
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	for ct in [4.0, 6.0, 8.0, 13.5]:
		var b := UiTheme.button("%ss" % str(ct), 18, Color("7e57c2"))
		b.custom_minimum_size = Vector2(76, 54)
		b.pressed.connect(func(): car_time = ct)
		row.add_child(b)
	for v in [0.25, 1.0]:
		var b := UiTheme.button("x%s" % str(v), 18, Color("2196f3"))
		b.custom_minimum_size = Vector2(70, 54)
		b.pressed.connect(func(): speed = v)
		row.add_child(b)
	var fl := UiTheme.button("FLIP", 18, Color("ff9800"))
	fl.custom_minimum_size = Vector2(80, 54)
	fl.pressed.connect(func(): facing = -facing)
	row.add_child(fl)


func _jobby() -> bool:
	return mode == "job" or mode == "polish"


## Job tier (see DetailerAnim.phases) and the real seconds per car (Lv 100+ never under PC_MIN_CAR_TIME).
func _tier() -> int:
	return 2 if mode == "polish" else 1


func _ct() -> float:
	return maxf(car_time, Data.PC_MIN_CAR_TIME) if mode == "polish" else car_time


func _set_mode(m: String) -> void:
	mode = m
	if m != "job" and m != "polish":
		for a in [big, left, right]:
			a.state = m
	p = 0.0
	_foam_big.clear()
	_foam_bay.clear()


# ------------------------------------------------------------ layout (shared by _process + _draw)

func _stage() -> Rect2:
	return Rect2(16, 80, size.x - 32, 700)


func _big_zoom() -> float:
	return 3.0 if _jobby() else 560.0 / BAY_H


func _big_feet() -> Vector2:
	var st := _stage()
	if _jobby():
		return Vector2(st.position.x + 46, st.end.y - 60)
	return Vector2(190 if mode == "scrub" else 360, st.end.y - 50)


## The car next to a detailer whose feet are at `feet` (left end of the car), drawn at `zoom` x bay size.
func _car_for(feet: Vector2, zoom: float) -> Rect2:
	var cw := 210.0 * zoom
	return Rect2(feet.x + 4.0 * zoom, feet.y - 4.0 * zoom - cw * 0.45, cw, cw * 0.45)


func _bay_car() -> Rect2:
	var y0 := 830.0
	var cw := 210.0
	return Rect2((size.x - cw) * 0.5, y0 + 136 - cw * 0.45, cw, cw * 0.45)


## Where a detailer's spray lands on the car (car-relative), from its sweep position.
static func _spray_target(a, from_left: bool, span: float, foam) -> Vector2:
	var x := lerpf(0.06, 0.06 + span, a.spray_s)
	if not from_left:
		x = 1.0 - x
	return foam.on_car(x, lerpf(0.18, 0.80, a.spray_h))


static func _to_local(px: Vector2, feet: Vector2, height: float, facing_: float) -> Vector2:
	var k := height / Rig.HEIGHT_UNITS
	return Vector2((px.x - feet.x) / k * facing_, (px.y - feet.y) / k)


# ------------------------------------------------------------ frame

func _process(delta: float) -> void:
	var d := delta * speed
	if _jobby():
		if not big.flexing():
			p += d / _ct()
		if p >= 1.0:
			p = 0.0
			for a in [big, left, right]:
				a.celebrate()
			_car_i += 1
			_specks = Art.new_specks()
			_foam_big.clear()
			_foam_bay.clear()
		var ph := Anim.phases(_tier())
		var wipe := clampf((p - ph.x) / (ph.y - ph.x), 0.0, 1.0)
		# big view: one detailer does the whole car
		var bf := _big_feet()
		var bcar := _car_for(bf, _big_zoom())
		big.set_job(p, _ct(), _tier())
		_foam_big.setup(bcar, CAR, 1)
		var bt := _spray_target(big, true, 0.88, _foam_big)
		big.aim_local = _to_local(bcar.position + bt * bcar.size, bf, BAY_H * _big_zoom(), 1.0)
		# bay: two detailers, each foams its own half from its own end
		var car := _bay_car()
		_foam_bay.setup(car, CAR, 2)
		var lt := _spray_target(left, true, 0.50, _foam_bay)
		var rt := _spray_target(right, false, 0.50, _foam_bay)
		left.set_job(p, _ct(), _tier())
		right.set_job(p, _ct(), _tier())
		left.aim_local = _to_local(car.position + lt * car.size, Vector2(car.position.x - 4, car.end.y + 4), BAY_H, 1.0)
		right.aim_local = _to_local(car.position + rt * car.size, Vector2(car.end.x + 4, car.end.y + 4), BAY_H, -1.0)
		for a in [big, left, right]:
			a.update(d)
		if big.spray > 0.05:
			_foam_big.spray(bt, d * big.spray)
		if left.spray > 0.05:
			_foam_bay.spray(lt, d * left.spray)
		if right.spray > 0.05:
			_foam_bay.spray(rt, d * right.spray)
		var spreading := p < ph.x + 0.03
		_foam_big.update(d, wipe, spreading)
		_foam_bay.update(d, wipe, spreading)
	else:
		for a in [big, left, right]:
			a.update(d)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("f4f7fb"))
	var st := _stage()
	draw_rect(st, Color("cfe3f2"))
	draw_rect(Rect2(st.position.x, st.end.y - 110, st.size.x, 110), Color("b9c3cf"))
	draw_rect(Rect2(st.position.x, st.end.y - 110, st.size.x, 5), Color("ffcc33"))
	var col := Color(CAR_COLORS[_car_i % CAR_COLORS.size()])
	var dirt := 0.5
	var haze := 0.0
	var front := 0.0
	if _jobby():
		var ph := Anim.phases(_tier())
		var wipe := clampf((p - ph.x) / (ph.y - ph.x), 0.0, 1.0)
		dirt = 0.8 * (1.0 - wipe)
		if _tier() == 2:
			haze = wipe
			front = clampf((p - ph.y) / (1.0 - ph.y), 0.0, 1.0)
	var bf := _big_feet()
	var zoom := _big_zoom()
	if mode != "idle":
		var bcar := _car_for(bf, zoom)
		Art.draw_car(self, bcar, col, dirt, _specks)
		if _jobby():
			Polish.draw(self, bcar, CAR, haze, front, 1, big.t)
			_foam_big.draw(self, bcar, big.t)
	draw_set_transform(bf, 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 26.0 * zoom, Color(0, 0, 0, 0.12))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var info := Rig.draw(self, bf, BAY_H * zoom, facing, big.pose)
	if _jobby() and info.has("nozzle"):
		var bcar2 := _car_for(bf, zoom)
		Foam.draw_spray(self, info["nozzle"], bcar2.position + _spray_target(big, true, 0.88, _foam_big) * bcar2.size,
			big.t, big.spray, zoom * 0.9)
	# clip whatever spilled outside the stage
	draw_rect(Rect2(st.end.x, st.position.y, size.x - st.end.x, st.size.y), Color("f4f7fb"))
	draw_rect(Rect2(0, 0, size.x, st.position.y), Color("f4f7fb"))
	var title := ("%s JOB  ·  %ss per car" % ["POLISH" if mode == "polish" else "FOAM", str(_ct())]) if _jobby() else mode.to_upper()
	UiTheme.text(self, Vector2(0, 52), "CHARACTER LAB  ·  " + title, 28, Color("1d1b2b"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 0, UiTheme.DISPLAY_FONT)
	if _jobby():
		# car progress as a thin line under the stage (lab only, not game UI)
		draw_rect(Rect2(st.position.x, st.end.y + 6, st.size.x * p, 4), Color("7e57c2"))
	# the same guys at real size in a bay strip (150 px tall, like bay_card)
	var y0 := 830.0
	draw_set_transform(Vector2(0, y0), 0.0, Vector2.ONE)
	Scenery.bay_room(self, 0, size.x, 92, 136, 150, Scenery.theme())
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var car := _bay_car()
	Art.draw_car(self, car, col, dirt, _specks)
	if _jobby():
		Polish.draw(self, car, CAR, haze, front, 2, left.t)
		_foam_bay.draw(self, car, left.t)
	var lf := Vector2(car.position.x - 4, y0 + 140)
	var rf := Vector2(car.end.x + 4, y0 + 140)
	var li := Rig.draw(self, lf, BAY_H, 1.0, left.pose)
	var ri := Rig.draw(self, rf, BAY_H, -1.0, right.pose)
	if _jobby():
		if li.has("nozzle"):
			Foam.draw_spray(self, li["nozzle"], car.position + _spray_target(left, true, 0.50, _foam_bay) * car.size, left.t, left.spray, 0.9)
		if ri.has("nozzle"):
			Foam.draw_spray(self, ri["nozzle"], car.position + _spray_target(right, false, 0.50, _foam_bay) * car.size, right.t, right.spray, 0.9)
	UiTheme.text(self, Vector2(0, y0 + 182), "real size in a bay (88 px)", 18, Color("4a5568"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 0)
