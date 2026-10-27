extends RefCounted
## The detailers working one bay (v0.18, step 5): the rigged detailer (scripts/detailer_rig.gd) driven by
## DetailerAnim, plus the foam (foam_layer.gd) and paint-correction shine (polish_layer.gd) on the car.
## Purely visual: it only READS the bay's progress; job times, pay and income are untouched.
##
## Who stands where (bay strip, the car between them):
##   front pair: left end facing right (always), right end facing left (from crew 2, or a rare car)
##   one more (crew 3+, i.e. Lv 100+): behind the car, a bit smaller and raised so head + shoulders show over
##                      the roof. At most MAX_CREW are drawn, however big the bay's crew gets (v0.18c,
##                      Hamza 19 Oct: Lv 300 with 5 looked crowded; the crew number is only visual).
## What they do, by the bay's service (DetailerAnim.phases):
##   Lv 1-9 Quick Wash: mitt; Lv 10-99: foam cannon, then hand wash; Lv 100+: foam, hand wash, polisher.
##   The one behind: arms folded while the car is foamed, wipes the roof, then polishes the roof.
## When a car finishes they flex. The next car's routine starts after the flex (the share of its time the flex
## uses is skipped), so the car still comes up clean exactly when its job ends. No flex when the bay runs itself
## and a car takes under FLEX_MIN_CAR seconds. Under FAST_CAR seconds a car (speed boosts) the crew just
## keeps hand-washing on a loop, so nothing flickers.

const Rig = preload("res://scripts/detailer_rig.gd")
const Anim = preload("res://scripts/detailer_anim.gd")
const Foam = preload("res://scripts/foam_layer.gd")
const Polish = preload("res://scripts/polish_layer.gd")
const Data = preload("res://scripts/game_data.gd")

const FRONT_H := 118.0          # front detailers' height (px) (v0.19c zoom, was 88)
const BACK_H := 92.0            # extras behind the car (was 70)
const BACK_RAISE := 38.0        # extras' feet sit this far above the floor line (further back in the bay)
const MAX_CREW := 3            # most ever drawn: two at the ends + one behind
const FLEX_MIN_CAR := 5.0
const FAST_CAR := 2.5

var anims: Array = []
var foam := Foam.new()
var tier := 0
var crew_n := 1
var front_n := 1
var fast := false
var running := false
var p_vis := 0.0                # the car's progress as the routine sees it (after the flex)
var _flex_frac := 0.0
var _t := 0.0
var _targets: Array = [Vector2.ZERO, Vector2.ZERO]   # where each front detailer's spray lands (car-relative)


func _init(bay_index: int) -> void:
	for k in MAX_CREW:
		var a := Anim.new(bay_index * 10 + k + 1)
		if k >= 2:
			a.route = ["top"]
			a.roof = true
		anims.append(a)
	foam = Foam.new(bay_index + 1)


## Service tier of a bay level: 0 Quick Wash, 1 foam cannon, 2 paint correction (see DetailerAnim.phases).
static func tier_for(level: int) -> int:
	if level >= Data.PC_LEVEL:
		return 2
	if level >= int(Data.BAY_BOOSTS[1]["level"]):
		return 1
	return 0


func _active(k: int) -> bool:
	return k < front_n or (k >= 2 and k < crew_n)


## Where the front detailers stand / how big they are, for a car rect.
static func feet_left(car: Rect2) -> Vector2:
	return Vector2(car.position.x - 4, car.end.y + 4)


static func feet_right(car: Rect2) -> Vector2:
	return Vector2(car.end.x + 4, car.end.y + 4)


func update(delta: float, is_running: bool, p: float, cyc: float, new_tier: int, crew: int, rare: bool,
		car: Rect2, cdef: Dictionary) -> void:
	_t += delta
	running = is_running
	tier = new_tier
	crew_n = clampi(crew, 1, MAX_CREW)
	front_n = 2 if (crew_n >= 2 or rare) else 1
	fast = cyc < FAST_CAR
	var lead: Anim = anims[0]
	# the flex eats the start of the next car: its routine runs in what's left
	if running and lead.flexing() and p < 0.6:
		_flex_frac = clampf(p + lead.flex_left() / maxf(0.1, cyc), 0.0, 0.5)
	p_vis = clampf((p - _flex_frac) / (1.0 - _flex_frac), 0.0, 1.0) if running else 0.0
	var job_len := cyc * (1.0 - _flex_frac)
	var use_tier := 0 if fast else tier
	for k in MAX_CREW:
		if not _active(k):
			continue
		var a: Anim = anims[k]
		if not running:
			a.state = "idle"
		elif fast:
			a.state = "scrub"
		else:
			a.set_job(p_vis, job_len, use_tier)
	# foam cannon aim: where on the car each front detailer's spray lands
	var span := 0.50 if front_n == 2 else 0.88
	if use_tier >= 1:
		foam.setup(car, cdef, front_n)
		for k in front_n:
			var a: Anim = anims[k]
			var left := k == 0
			var tgt := _spray_target(a, left, span)
			_targets[k] = tgt
			var feet := feet_left(car) if left else feet_right(car)
			a.aim_local = _to_local(car.position + tgt * car.size, feet, FRONT_H, 1.0 if left else -1.0)
	for k in MAX_CREW:
		if _active(k):
			anims[k].update(delta)
	if use_tier >= 1 and running:
		var ph := Anim.phases(use_tier)
		for k in front_n:
			var a: Anim = anims[k]
			if a.spray > 0.05:
				foam.spray(_targets[k], delta * a.spray)
		var wipe := clampf((p_vis - ph.x) / (ph.y - ph.x), 0.0, 1.0)
		foam.update(delta, wipe, p_vis < ph.x + 0.03)
	elif not running:
		foam.clear()


## A car just finished: celebrate (if there's time) and clear the foam for the next one.
func job_done(automated: bool, cyc: float) -> void:
	_flex_frac = 0.0
	foam.clear()
	if fast or (automated and cyc < FLEX_MIN_CAR):
		return
	for k in MAX_CREW:
		if _active(k):
			anims[k].celebrate()


## How dirty the car looks (0 clean .. 1), and the paint-correction haze / polish front.
func dirt() -> float:
	if not running:
		return 1.0
	if tier == 0 or fast:
		return 1.0 - p_vis
	var ph := Anim.phases(tier)
	return 1.0 - clampf((p_vis - ph.x) / (ph.y - ph.x), 0.0, 1.0)


## Extras behind the car (draw BEFORE the car).
func draw_behind(ci: CanvasItem, car: Rect2, floor_y: float) -> void:
	var extras := crew_n - 2
	for k in range(2, crew_n):
		var i := k - 2
		var bx := car.position.x + car.size.x * (0.25 + 0.5 * float(i) / maxf(1.0, extras - 1)) if extras > 1 else car.position.x + car.size.x * 0.5
		Rig.draw(ci, Vector2(bx, floor_y - BACK_RAISE), BACK_H, 1.0 if i % 2 == 0 else -1.0, anims[k].pose, Color(0.94, 0.94, 0.97))


## Haze / polish shine and the foam (draw right AFTER the car).
func draw_on_car(ci: CanvasItem, car: Rect2, cdef: Dictionary) -> void:
	if fast or not running:
		return
	if tier == 2:
		var ph := Anim.phases(2)
		var haze := clampf((p_vis - ph.x) / (ph.y - ph.x), 0.0, 1.0)
		var front := clampf((p_vis - ph.y) / (1.0 - ph.y), 0.0, 1.0)
		Polish.draw(ci, car, cdef, haze, front, front_n, _t)
	if tier >= 1:
		foam.draw(ci, car, _t)


## The front detailers + the foam cannon spray (draw AFTER the car).
func draw_front(ci: CanvasItem, car: Rect2) -> void:
	for k in front_n:
		var left := k == 0
		var info := Rig.draw(ci, feet_left(car) if left else feet_right(car), FRONT_H, 1.0 if left else -1.0, anims[k].pose)
		if info.has("nozzle") and running and not fast:
			Foam.draw_spray(ci, info["nozzle"], car.position + _targets[k] * car.size,
				anims[k].t, anims[k].spray, 0.9)


func _spray_target(a: Anim, from_left: bool, span: float) -> Vector2:
	var x := lerpf(0.06, 0.06 + span, a.spray_s)
	if not from_left:
		x = 1.0 - x
	return foam.on_car(x, lerpf(0.18, 0.80, a.spray_h))


static func _to_local(px: Vector2, feet: Vector2, height: float, facing: float) -> Vector2:
	var k := height / Rig.HEIGHT_UNITS
	return Vector2((px.x - feet.x) / k * facing, (px.y - feet.y) / k)
