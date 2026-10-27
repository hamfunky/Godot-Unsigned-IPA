extends RefCounted
## Drives one detailer's pose over time (v0.18). Each state builds a target pose; changing state
## crossfades from the pose on screen, so nothing ever snaps.
## States: "idle" (locked 19 Oct), "scrub" (wash mitt circles at three spots on the car: side panel,
## reach over the bonnet / wing top, crouch at the wheel; eased moves between spots; free hand on hip / knee),
## "foam", "polish", "wait" (arms folded, watching: the detailer behind the car while the front pair foam it).
## Usage: var a := DetailerAnim.new(seed); a.state = "scrub"; a.update(delta); Rig.draw(ci, feet, h, facing, a.pose)
## Units are the rig's (figure ~266 tall, origin between the feet, +x = towards the car). In a bay (88 px)
## the car's roof is ~240 units up, its beltline ~120, the wheel centres ~50.

const Rig = preload("res://scripts/detailer_rig.gd")

const XFADE := 0.45                 # seconds to blend into a new state
const TOOL_SWAP := 0.7              # blend time when the tool in his hands changes (cannon <-> mitt)
const FLEX_T := 1.7                 # the celebration: tool away, double-bicep flex x2 with a grin, back to work
const FOAM_P := 0.30                # share of a car's job spent foaming it (Foam Cannon service, Lv 10-99)

## Job tiers: 0 = Quick Wash (mitt only), 1 = Foam Cannon .. Clay Bar (foam, then hand wash),
## 2 = Paint Correction and up (foam, hand wash, then the polisher). Phase ends as shares of the car's time.
static func phases(tier: int) -> Vector2:
	match tier:
		2:
			return Vector2(0.22, 0.55)
		1:
			return Vector2(FOAM_P, 1.0)
	return Vector2(0.0, 1.0)
const MOVE := 0.8                   # seconds to move from one scrub spot to the next

## Scrub spots. hip = offset from the rest hip; hand_f = wash-mitt wrist; hand_n = the other hand;
## circ = scrub circle radii; rate = circles per second.
const SPOTS := {
	"side": {"hip": Vector2(4, 0), "torso_rot": 0.10, "head_rot": -0.04,
		"hand_f": Vector2(100, -125), "hand_n": Vector2(-36, -84), "fist_f": -0.5, "fist_n": 0.3,
		"circ": Vector2(15, 10), "rate": 1.25, "dwell": Vector2(2.6, 4.0)},
	"top": {"hip": Vector2(3, -6), "torso_rot": 0.05, "head_rot": -0.10,
		"hand_f": Vector2(104, -202), "hand_n": Vector2(-34, -90), "fist_f": -0.2, "fist_n": 0.3,
		"circ": Vector2(19, 6), "rate": 1.1, "dwell": Vector2(2.2, 3.2)},
	"low": {"hip": Vector2(6, 16), "torso_rot": 0.42, "head_rot": -0.22,
		"hand_f": Vector2(92, -50), "hand_n": Vector2(12, -58), "fist_f": -0.9, "fist_n": -0.6,
		"circ": Vector2(13, 9), "rate": 1.35, "dwell": Vector2(2.6, 3.8)},
}
## Order he works round the car (loops). Side in between so he never jumps top <-> wheel.
const ROUTE := ["side", "top", "side", "low"]
## This detailer's route (the extras behind the car only wipe the roof: ["top"]).
var route: Array = ROUTE
## The detailer behind the car (v0.18c, Hamza 19 Oct: he follows the routine too): waits with his arms folded
## while the car is foamed, wipes the roof, then polishes the roof.
var roof := false

var state := "idle":
	set(v):
		if v != state and _flex_t >= 0.0:
			state = v          # mid-flex: just remember it; we blend into it when the flex ends
			return
		if v != state:
			_from = pose.duplicate()
			_xfade = 0.0
			state = v
			if v == "scrub":
				_route_i = _rng.randi_range(0, route.size() - 1)
				_spot_from = SPOTS[route[_route_i]]
				_spot_to = _spot_from
				_spot_k = 1.0
				_dwell = _rng.randf_range(0.8, 2.0)
var t := 0.0
var pose := {}
## Foam cannon: whoever draws the car sets aim_local (rig units) to where the spray should land; the anim
## reports where along its stretch of the car it's aiming (spray_s 0..1, spray_h 0..1 height band) and
## how hard it's spraying (spray 0..1).
var aim_local := Vector2(200, -120)
var spray_s := 0.0
var spray_h := 0.5
var spray := 0.0
var polish_q := 0.0                 # 0..1 how far the polish has got (output, for the shine on the car)
var _job_p := 0.0
var _ph := Vector2(FOAM_P, 1.0)
var _flex_t := -1.0
var _flex_from := {}
var _swap_time := TOOL_SWAP
var _rng := RandomNumberGenerator.new()
var _phase := 0.0
var _next_blink := 1.5
var _blink_until := -1.0
var _from := {}
var _xfade := 1.0
# scrub
var _route_i := 0
var _spot_from: Dictionary = SPOTS["side"]
var _spot_to: Dictionary = SPOTS["side"]
var _spot_k := 1.0
var _dwell := 2.0
var _scrub_t := 0.0


func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value * 7919 + 17
	_phase = _rng.randf() * TAU
	t = _rng.randf() * 3.0
	_next_blink = t + _rng.randf_range(1.0, 4.0)
	pose = _idle_pose()


## Drive him from a car's job: p = 0..1 progress, job_len = seconds per car, tier = see phases().
func set_job(p: float, job_len: float, tier: int) -> void:
	_job_p = p
	_ph = phases(tier)
	_swap_time = clampf(job_len * 0.08, 0.25, TOOL_SWAP)
	if p < _ph.x:
		state = "wait" if roof else "foam"
	elif p < _ph.y:
		state = "scrub"
	else:
		state = "polish"


## Celebrate (a car just finished): puts the tool away and does a double-bicep flex with a grin, right where
## he stands (no turning: his working view already faces the player, Hamza 19 Oct), pumps twice. Takes FLEX_T
## seconds; whatever state he's in resumes afterwards with a blend.
func celebrate() -> void:
	if _flex_t >= 0.0:
		return
	_flex_t = 0.0
	_flex_from = pose.duplicate()
	_flex_from["bend_n"] = float(_flex_from.get("bend_n", 1.0))
	_flex_from["far_front"] = false


func flexing() -> bool:
	return _flex_t >= 0.0


## Seconds of the flex still to go (0 when not flexing).
func flex_left() -> float:
	return maxf(0.0, FLEX_T - _flex_t) if _flex_t >= 0.0 else 0.0


func update(delta: float) -> void:
	t += delta
	var target: Dictionary
	spray = 0.0
	if _flex_t >= 0.0:
		_flex_t += delta
		if _flex_t < FLEX_T:
			pose = _flex_pose(_flex_t)
			return
		# done: blend from the end of the flex into whatever he should be doing now
		_flex_t = -1.0
		_from = pose.duplicate()
		_xfade = 0.0
	match state:
		"scrub":
			target = _scrub_pose(delta)
		"foam":
			target = _foam_pose()
		"polish":
			target = _roof_polish_pose() if roof else _polish_pose()
		"wait":
			target = _wait_pose()
		_:
			target = _idle_pose()
	# blinking (random, sometimes a double blink)
	if t >= _next_blink:
		_blink_until = t + 0.11
		_next_blink = t + (0.22 if _rng.randf() < 0.25 else _rng.randf_range(2.6, 5.5))
	target["blink"] = t < _blink_until
	if _xfade < 1.0:
		var old_tool := str(_from.get("tool", ""))
		var new_tool := str(target.get("tool", ""))
		var swap := old_tool != new_tool
		_xfade = minf(1.0, _xfade + delta / (_swap_time if swap else XFADE))
		var raw := target
		target = blend(_from, target, _ease(_xfade))
		_hands_around(target, _from, raw, _ease(_xfade))
		if swap:
			# the old tool shrinks away in the first half of the move, the new one grows in the second
			if _xfade < 0.5:
				target["tool"] = old_tool
				target["tool_k"] = 1.0 - _ease(_xfade * 2.0)
				for key in ["grip", "aim", "pad", "tool_rot", "t"]:
					if _from.has(key):
						target[key] = _from[key]
			else:
				target["tool"] = new_tool
				target["tool_k"] = _ease(_xfade * 2.0 - 1.0)
		spray *= _ease(_xfade) if not swap else 0.0
	pose = target


## Blended hands travel on a curve that stays clear of the shoulder: a straight line between two far-apart
## holds (arms folded -> reaching over the roof, roof polisher -> flex) can pass right by the shoulder, and the
## elbow whips round (v0.18c). Works in place on `out` (a blend of a -> b by k).
static func _hands_around(out: Dictionary, a: Dictionary, b: Dictionary, k: float) -> void:
	if int(out.get("view", 0)) != 0 or int(a.get("view", 0)) != 0:
		return
	var tx := Rig.torso_xf(out)
	for near in [true, false]:
		var key := "hand_n" if near else "hand_f"
		if not (a.has(key) and b.has(key)):
			continue
		var a0: Vector2 = a[key]
		var b0: Vector2 = b[key]
		var sh := tx * Rig.shoulder(near, 0)
		var mid := (a0 + b0) * 0.5
		var perp := (b0 - a0).orthogonal()
		if perp.length() < 0.01:
			continue
		perp = perp.normalized()
		var side := (mid - sh).dot(perp)
		if absf(side) < 0.01:
			side = 0.01 * signf(perp.x + 0.001)
		if side < 0.0:
			perp = -perp
			side = -side
		if side >= 45.0:
			continue
		var ctrl := mid + perp * (90.0 - 2.0 * side)
		out[key] = a0.lerp(ctrl, k).lerp(ctrl.lerp(b0, k), k)


static func _ease(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)


## Blends every number / vector in two poses (bools + strings come from b).
static func blend(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var out := b.duplicate()
	for key in b:
		if a.has(key) and (b[key] is float or b[key] is Vector2):
			out[key] = lerp(a[key], b[key], k)
	return out


## Breathing + weight shift shared by every standing state. Returns [breath 0..1, shift -1..1].
func _life() -> Array:
	var b := 0.5 - 0.5 * cos(t * TAU / 3.4)
	b = b * b * (3.0 - 2.0 * b)
	return [b, sin(t * TAU / 7.3 + _phase)]


func _idle_pose() -> Dictionary:
	var p := {"view": 0, "tool": "mitt"}
	var life := _life()
	var b: float = life[0]
	var w: float = life[1]
	p["hip"] = Rig.rest_hip() + Vector2(2.6 * w, 1.2 * absf(w) - 0.8 * b)
	p["breathe"] = 0.014 * b
	p["torso_rot"] = -0.015 + 0.018 * w
	p["head_rot"] = 0.03 * sin(t * TAU / 9.1 + _phase * 0.7) - 0.01 * b
	p["foot_n"] = Rig.rest_foot(true, 0)
	p["foot_f"] = Rig.rest_foot(false, 0)
	var tx := Rig.torso_xf(p)
	var shn := tx * Rig.shoulder(true, 0)
	var shf := tx * Rig.shoulder(false, 0)
	# arms hang relaxed and a touch forward; they swing a little with the breath and the weight shift
	p["hand_n"] = shn + Vector2(30.0 + 2.0 * w, 72.0 - 2.0 * b)
	p["hand_f"] = shf + Vector2(20.0 + 2.0 * w, 72.0 - 2.0 * b)
	p["fist_n"] = -0.15
	p["fist_f"] = -0.3
	return p


func _scrub_pose(delta: float) -> Dictionary:
	# walk the route: dwell at a spot, then ease to the next one
	if _spot_k >= 1.0:
		_dwell -= delta
		if _dwell <= 0.0:
			_route_i = (_route_i + 1) % route.size()
			_spot_from = _spot_to
			_spot_to = SPOTS[route[_route_i]]
			_spot_k = 0.0
	else:
		_spot_k = minf(1.0, _spot_k + delta / MOVE)
		if _spot_k >= 1.0:
			var d: Vector2 = _spot_to["dwell"]
			_dwell = _rng.randf_range(d.x, d.y)
	var k := _ease(_spot_k)
	var s := {}
	for key in _spot_to:
		var a = _spot_from[key]
		var b2 = _spot_to[key]
		s[key] = lerp(a, b2, k) if (b2 is float or b2 is Vector2) else b2
	# the scrub slows down while he moves between spots, then picks up again
	var moving := sin(k * PI) if _spot_k < 1.0 else 0.0
	_scrub_t += delta * float(s["rate"]) * (1.0 - 0.8 * moving)
	var a_ang := _scrub_t * TAU
	var circ: Vector2 = s["circ"] * (1.0 - 0.85 * moving)
	var scrub := Vector2(cos(a_ang) * circ.x, sin(a_ang) * circ.y)
	# a little "up" through the move = he straightens up / steps through instead of sliding
	var lift := Vector2(0, -6.0 * moving)
	var life := _life()
	var br: float = life[0]
	var p := {"view": 0, "tool": "mitt"}
	# body follows the scrubbing hand a little (weight goes into the stroke)
	p["hip"] = Rig.rest_hip() + s["hip"] + lift + Vector2(scrub.x * 0.10, absf(scrub.y) * 0.06 - 0.6 * br)
	p["breathe"] = 0.010 * br
	p["torso_rot"] = float(s["torso_rot"]) + scrub.x * 0.0022
	p["head_rot"] = float(s["head_rot"]) + scrub.y * 0.002
	p["foot_n"] = Rig.rest_foot(true, 0)
	p["foot_f"] = Rig.rest_foot(false, 0)
	p["hand_f"] = s["hand_f"] + scrub + lift
	# the free hand sits on his hip (or his knee when crouched) and rides along with the body
	p["hand_n"] = s["hand_n"] + Vector2(scrub.x * 0.10, 0) + lift
	p["fist_f"] = float(s["fist_f"]) + sin(a_ang) * 0.15
	p["fist_n"] = s["fist_n"]
	return p


## Foam cannon: braced stance, gun at the hip in both hands, three sweeps along the car (top, middle,
## bottom), pump pulses kick the gun a little. Synced to the car's progress through the
## foam part of its job, so a short job sweeps quickly and a long one takes its time.
func _foam_pose() -> Dictionary:
	var ph := clampf(_job_p / maxf(0.01, _ph.x), 0.0, 1.0)
	# three passes while the trigger is held: along the top, back along the middle, along the bottom
	var sw := clampf((ph - 0.08) / 0.80, 0.0, 1.0)
	var pos := sw * 3.0
	var band := mini(int(pos), 2)
	var f := pos - float(band)
	var e := 0.5 - 0.5 * cos(f * PI)
	spray_s = e if band % 2 == 0 else 1.0 - e
	var step := clampf((f - 0.8) / 0.2, 0.0, 1.0) if band < 2 else 0.0
	spray_h = (float(band) + step * step * (3.0 - 2.0 * step)) / 2.0
	# trigger: on once he's aimed, off just before the phase ends (the tool swap happens with it released)
	var on := clampf(ph / 0.12, 0.0, 1.0) * (1.0 - clampf((ph - 0.86) / 0.12, 0.0, 1.0))
	spray = on
	var pulse := sin(t * TAU * 3.0) * on
	var life := _life()
	var br: float = life[0]
	var p := {"view": 0, "tool": "cannon", "tool_k": 1.0, "spray": on}
	var hip := Rig.rest_hip() + Vector2(-3.0 - 0.8 * pulse, 5.0 - 0.6 * br)
	p["hip"] = hip
	p["breathe"] = 0.010 * br
	p["torso_rot"] = -0.05 - 0.012 * pulse
	p["foot_n"] = Rig.rest_foot(true, 0) + Vector2(-6, 0)
	p["foot_f"] = Rig.rest_foot(false, 0) + Vector2(6, 0)
	var grip := hip + Vector2(20.0 - 1.5 * pulse, -42.0)
	var aim := clampf((aim_local - grip).angle(), -0.85, 0.55) - 0.02 * pulse
	p["grip"] = grip
	p["aim"] = aim
	p["head_rot"] = aim * 0.35
	p["hand_n"] = grip + Vector2(-2, -6).rotated(aim)
	p["hand_f"] = grip + Vector2(46, -2).rotated(aim)
	p["fist_n"] = 0.0
	p["fist_f"] = 0.0
	return p


## Polisher (Paint Correction and up): pad pressed on the panel at his end of the car, slow overlapping passes
## up and down (crouching a little for the low ones), the machine buzzing in his hands. polish_q tells the car
## how far the shine has got.
func _polish_pose() -> Dictionary:
	var u := clampf((_job_p - _ph.y) / maxf(0.01, 1.0 - _ph.y), 0.0, 1.0)
	polish_q = u
	var life := _life()
	var br: float = life[0]
	var pass_ := 0.5 - 0.5 * cos(u * TAU * 1.5)          # 0 = top of the panel, 1 = bottom
	var buzz := Vector2(sin(t * 57.0), cos(t * 61.0)) * 1.3
	var pad := Vector2(100.0 + sin(u * TAU) * 8.0, lerpf(-140.0, -86.0, pass_)) + buzz
	var rot := 0.08 * sin(u * TAU * 3.0)
	var p := {"view": 0, "tool": "polisher", "tool_k": 1.0, "pad": pad, "tool_rot": rot, "t": t}
	var hip := Rig.rest_hip() + Vector2(6.0, 10.0 * pass_ - 0.6 * br)
	p["hip"] = hip
	p["breathe"] = 0.010 * br
	p["torso_rot"] = 0.12 + 0.12 * pass_ + buzz.x * 0.002
	p["head_rot"] = -0.05 - 0.10 * pass_
	p["foot_n"] = Rig.rest_foot(true, 0) + Vector2(-4, 0)
	p["foot_f"] = Rig.rest_foot(false, 0) + Vector2(4, 0)
	p["hand_n"] = pad + (Rig.sk("pol_grip") as Vector2).rotated(rot) + Vector2(0, -6)
	# far hand presses down on the machine's head (not the knob right by his shoulder: that folded the arm
	# up completely and made the elbow whip around, bug 19 Oct); it doesn't take the buzz
	p["hand_f"] = pad - buzz + Vector2(-8, -34).rotated(rot)
	p["fist_n"] = 0.0
	p["fist_f"] = 0.0
	return p


## Arms folded, weight on one leg, watching the car get foamed (head follows the spray a little).
func _wait_pose() -> Dictionary:
	var p := {"view": 0, "tool": ""}
	var life := _life()
	var b: float = life[0]
	var w: float = life[1]
	p["hip"] = Rig.rest_hip() + Vector2(-2.0 + 2.0 * w, 1.0 * absf(w) - 0.8 * b)
	p["breathe"] = 0.016 * b
	p["torso_rot"] = -0.04 + 0.012 * w
	p["head_rot"] = 0.05 * sin(t * TAU / 6.3 + _phase) - 0.02
	p["foot_n"] = Rig.rest_foot(true, 0) + Vector2(-5, 0)
	p["foot_f"] = Rig.rest_foot(false, 0) + Vector2(5, 0)
	var tx := Rig.torso_xf(p)
	# near forearm across the chest, the far hand tucked in under it (behind the body)
	p["hand_n"] = tx * Vector2(10.0, -40.0 - 1.5 * b)
	p["hand_f"] = tx * Vector2(-22.0, -30.0)
	p["fist_n"] = -0.25
	p["fist_f"] = 0.0
	return p


## The polisher on the roof (the detailer behind the car): the machine held out at arm's length with its
## handle down (below the roof line, hidden by the car), so over the roof you see the pad and his far hand on the
## machine's head in front of his face, never across it. The near arm can't reach that far in 3/4 view: that
## hand rests against the car (hidden by it).
func _roof_polish_pose() -> Dictionary:
	var u := clampf((_job_p - _ph.y) / maxf(0.01, 1.0 - _ph.y), 0.0, 1.0)
	var life := _life()
	var br: float = life[0]
	var sweep := 0.5 - 0.5 * cos(u * TAU * 2.0)            # along the roof and back, twice
	var buzz := Vector2(sin(t * 57.0), cos(t * 61.0)) * 1.3
	var rot := -1.0 + 0.05 * sin(u * TAU * 3.0)
	var pad := Vector2(lerpf(116.0, 128.0, sweep), -206.0 + 3.0 * sin(u * TAU * 4.0)) + buzz
	var p := {"view": 0, "tool": "polisher", "tool_k": 1.0, "pad": pad, "tool_rot": rot, "t": t}
	var hip := Rig.rest_hip() + Vector2(4.0 + 4.0 * sweep, -2.0 - 0.6 * br)
	p["hip"] = hip
	p["breathe"] = 0.010 * br
	p["torso_rot"] = 0.18 + 0.04 * sweep + buzz.x * 0.002
	p["head_rot"] = -0.16
	p["foot_n"] = Rig.rest_foot(true, 0) + Vector2(-4, 0)
	p["foot_f"] = Rig.rest_foot(false, 0) + Vector2(4, 0)
	p["hand_n"] = hip + Vector2(30.0 + 4.0 * sweep, -44.0)
	p["hand_f"] = pad - buzz + Vector2(-8, -26).rotated(rot)
	p["fist_n"] = 0.0
	p["fist_f"] = 0.0
	return p


## The flex, by time f (0..FLEX_T), in his working view (3/4).
##   0 .. A   tool shrinks away, arms drop straight to his sides (the near elbow switches to bending outwards
##            while the arm is straight, so it never flips)
##   A .. B   arms swing up in an arc into a double bicep, grin
##   B .. C   two pumps
##   C .. end arms come back down straight, elbow back to normal, then the job blends back in
func _flex_pose(f: float) -> Dictionary:
	const A := 0.34
	const B := 0.60
	const C := 1.40
	if f < A:
		var k := _ease(f / A)
		var to := _flex34(0.0, 0.0, -1.0)
		var p := blend(_flex_from, to, k)
		# hands travel on a curve that stays clear of the shoulder (a straight line from a hand held up and
		# forward, e.g. the roof polisher, passes right by it and whips the elbow round)
		_hands_around(p, _flex_from, to, k)
		p["tool"] = str(_flex_from.get("tool", ""))
		p["tool_k"] = float(_flex_from.get("tool_k", 1.0)) * (1.0 - k)
		for key in ["grip", "aim", "pad", "tool_rot", "t"]:
			if _flex_from.has(key):
				p[key] = _flex_from[key]
		p["spray"] = 0.0
		return p
	var up := _ease(clampf((f - A) / (B - A), 0.0, 1.0)) * (1.0 - _ease(clampf((f - C) / 0.2, 0.0, 1.0)))
	var pump := 0.0
	for c in [0.82, 1.16]:
		pump = maxf(pump, exp(-pow((f - c) / 0.09, 2.0)))
	var bend := lerpf(-1.0, 1.0, _ease(clampf((f - (C + 0.18)) / (FLEX_T - C - 0.18), 0.0, 1.0)))
	return _flex34(up, pump, bend)


## His working view, up = 0 arms hanging straight .. 1 double bicep; pump = a squeeze; bend_n = near elbow side.
func _flex34(up: float, pump: float, bend_n: float) -> Dictionary:
	var life := _life()
	var br: float = life[0]
	var p := {"view": 0, "tool": "", "grin": up > 0.25, "bend_n": bend_n, "bend_f": 1.0, "far_front": false,
		"flex_arms": up > 0.05}
	p["hip"] = Rig.rest_hip() + Vector2(0, 1.5 * pump - 0.6 * br - 3.0 * up)
	p["breathe"] = 0.012 * br + 0.035 * pump
	p["torso_rot"] = -0.04 * up                       # chest out
	p["head_rot"] = -0.05 * up + 0.04 * pump
	p["foot_n"] = Rig.rest_foot(true, 0)
	p["foot_f"] = Rig.rest_foot(false, 0)
	var tx := Rig.torso_xf(p)
	for near in [true, false]:
		var side := -1.0 if near else 1.0
		var sh := tx * Rig.shoulder(near, 0)
		var hang := sh + Vector2(side * 6.0, 84.0)               # nearly straight
		var flex := sh + Vector2(side * (42.0 - 6.0 * pump), -42.0 + 5.0 * pump)
		var ctrl := sh + Vector2(side * 78.0, 34.0)              # arc out to the side, not past the shoulder
		p["hand_n" if near else "hand_f"] = hang.lerp(ctrl, up).lerp(ctrl.lerp(flex, up), up)
		p["fist_n" if near else "fist_f"] = 0.0
	return p


## Facing the camera; up = 0 arms hanging .. 1 double-bicep flex; pump = 0..1 a squeeze.
func _front_pose(up: float, pump: float) -> Dictionary:
	var life := _life()
	var br: float = life[0]
	var p := {"view": 1, "tool": "", "grin": up > 0.3}
	p["hip"] = Rig.rest_hip() + Vector2(0, 1.5 * pump - 0.6 * br - 3.0 * up)
	p["breathe"] = 0.012 * br + 0.035 * pump
	p["torso_rot"] = 0.0
	p["head_rot"] = 0.04 * pump
	p["foot_n"] = Rig.rest_foot(true, 1)
	p["foot_f"] = Rig.rest_foot(false, 1)
	var tx := Rig.torso_xf(p)
	for near in [true, false]:
		var side := -1.0 if near else 1.0
		var sh := tx * Rig.shoulder(near, 1)
		var hang := sh + Vector2(side * 8.0, 78.0)
		# double bicep: upper arm out flat, forearm straight up, fist about level with the top of his head;
		# a pump squeezes the fist in and down a touch
		var flex := sh + Vector2(side * (42.0 - 6.0 * pump), -42.0 + 5.0 * pump)
		# swing up in an arc out to the side (a straight line would pass right by the shoulder and whip the
		# elbow over the top)
		var ctrl := sh + Vector2(side * 78.0, 34.0)
		p["hand_n" if near else "hand_f"] = hang.lerp(ctrl, up).lerp(ctrl.lerp(flex, up), up)
		p["fist_n" if near else "fist_f"] = 0.0
	return p
