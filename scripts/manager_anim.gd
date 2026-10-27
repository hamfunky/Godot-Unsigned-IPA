extends RefCounted
## One cash manager's animation state (v0.19). Builds the pose ManagerRig draws.
## Idle loops (the same four as before, picked per manager):
##   0 arm pump      left hand on the hip, right fist pumps up every few seconds
##   1 arms crossed  swaying a little
##   2 hands on hips nodding
##   3 clipboard     leather folio in the left hand, fountain pen tapping
## While their ability runs they INSTRUCT: point at what they're bossing (point_dir +1 right / -1 left) and
## chop the arm up and down, other hand on the hip, folio put away, mouth going. Style by age:
## Junior quick and keen, Senior steady, Executive slow and lazy with the nose in the air.
## Switching is one smooth blend (hands travel on a curve through a relaxed pose, nothing snaps).

const Rig = preload("res://scripts/manager_rig.gd")

const BLEND_IN := 0.8       # idle -> instruct (s)
const BLEND_OUT := 1.4      # instruct -> idle: slower, so the arm settles back gently (Hamza 19 Oct)
const STYLE := [   # period (s), chop up / down (deg from level), reach, head bob, bounce, talk speed
	{"period": 0.62, "up": -34.0, "down": 10.0, "reach": 82.0, "bob": 1.6, "bounce": 0.010, "talk": 1.25},
	{"period": 0.95, "up": -24.0, "down": 8.0, "reach": 81.0, "bob": 0.9, "bounce": 0.005, "talk": 1.0},
	{"period": 1.55, "up": -15.0, "down": 4.0, "reach": 78.0, "bob": 0.0, "bounce": 0.0, "talk": 0.75},
]

var look := 0
var idle := 2
var point_dir := 1.0      # +1 = faces / points right (bays, desk), -1 = left (valet); the rig mirrors
var active := false
var t := 0.0
var blend := 0.0
var mem := {}            # the rig memory (fallback IK, forearm order)
var _mem_a := {}         # elbow memory while solving the idle pose
var _mem_b := {}         # ... and the instruct pose
var _uw := {}            # last unwrapped joint angles
var _dirs := {}          # arc direction per bone for the current switch
var _seed := 0.0


func _init(look_i := 0, idle_i := 2, seed_f := 0.0) -> void:
	look = look_i
	idle = idle_i
	_seed = seed_f
	t = seed_f * 7.3


func update(delta: float) -> void:
	t += delta
	blend = move_toward(blend, 1.0 if active else 0.0, delta / (BLEND_IN if active else BLEND_OUT))


static func _ss(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)


static func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


static func _bez(a: Vector2, c: Vector2, b: Vector2, s: float) -> Vector2:
	return a.lerp(c, s).lerp(c.lerp(b, s), s)


func pose() -> Dictionary:
	## Arms are blended BONE BY BONE (joint angles), not by hand position: each pose is solved on its own
	## (its own elbow memory, so neither ever flips), then the upper arm and the forearm each rotate from one
	## pose's angle to the other's. Big swings go the "down" way round (through a relaxed hang), so an arm
	## never whips over the head or through the body. The arc direction is picked once per switch.
	var lk := Rig.look(look)
	var a := _idle_pose(lk)
	var b := _instruct_pose(lk)
	var ja := _joints(lk, a, _mem_a)
	var jb := _joints(lk, b, _mem_b)
	if blend <= 0.0001 or blend >= 0.9999:
		_dirs.clear()
		var p := a if blend <= 0.0001 else b
		var j := ja if blend <= 0.0001 else jb
		p["arm_l"] = j["l"]
		p["arm_r"] = j["r"]
		return p
	var s := _ease(blend)
	var out := {}
	for side in ["l", "r"]:
		var A: Vector3 = ja[side]
		var B: Vector3 = jb[side]
		out["arm_" + side] = Vector3(_arc(A.x, B.x, s, side + "u"), _arc(A.y, B.y, s, side + "f"), lerpf(A.z, B.z, s))
		out["hand_" + side] = Vector2(a["hand_" + side]).lerp(b["hand_" + side], s)
		out["point_" + side] = 0.0
	out["front_r"] = b["front_r"] if s > 0.5 else a["front_r"]
	out["folio"] = float(a["folio"]) * (1.0 - _ss(blend * 2.2))
	out["pen"] = float(a["pen"]) * (1.0 - _ss(blend * 2.2))
	out["head_rot"] = lerpf(a["head_rot"], b["head_rot"], s)
	out["head_off"] = Vector2(a["head_off"]).lerp(b["head_off"], s)
	out["breathe"] = lerpf(a["breathe"], b["breathe"], s)
	out["talk"] = b["talk"] and blend > 0.65
	out["blink"] = a["blink"]
	return out


## Upper-arm angle, forearm angle, forearm length per arm for one pose (IK with that pose's own memory).
func _joints(lk: Dictionary, p: Dictionary, m: Dictionary) -> Dictionary:
	var out := {}
	for side in [-1, 1]:
		var s := "l" if side < 0 else "r"
		var sh := Rig.shoulder(lk, side, float(p["breathe"]))
		var hand: Vector2 = p["hand_" + s]
		var fl := float(p["fore_" + s])
		var el := Rig.elbow(sh, hand, Rig.UPPER, fl, p["hint_" + s], m, "el_" + s)
		out[s] = Vector3((el - sh).angle(), (hand - el).angle(), fl)
	return out


## Angle blend with the direction fixed for the whole switch: the way round whose halfway angle hangs
## lowest (closest to pointing straight down).
func _arc(a0: float, b0: float, s: float, key: String) -> float:
	# both angles are unwrapped over time (continuous, no jump at +-180 deg), so their difference is too
	var A := _unwrap("a" + key, a0)
	var B := _unwrap("b" + key, b0)
	if not _dirs.has(key):
		# once per switch: pick which way round to turn (the way whose halfway angle hangs lowest)
		var d := wrapf(B - A, -PI, PI)
		var alt := d - signf(d) * TAU
		var down := PI * 0.5
		var m1 := absf(wrapf(A + d * 0.5 - down, -PI, PI))
		var m2 := absf(wrapf(A + alt * 0.5 - down, -PI, PI))
		var pick := d if (absf(d) < 2.2 or m1 <= m2) else alt
		_dirs[key] = pick - (B - A)          # a fixed multiple of 2*PI for the whole switch
	return A + (B - A + float(_dirs[key])) * s


func _unwrap(key: String, ang: float) -> float:
	if _uw.has(key):
		var prev: float = _uw[key]
		ang = prev + wrapf(ang - prev, -PI, PI)
	_uw[key] = ang
	return ang


func _hip(lk: Dictionary, side: int) -> Vector2:
	return Vector2(side * (float(lk["W"]) + 3.0), float(lk["hip"]) - 16.0)


func _relaxed(lk: Dictionary, side: int) -> Vector2:
	return Vector2(side * (float(lk["S"]) + 8.0), float(lk["hip"]) + 14.0)


func _base(lk: Dictionary) -> Dictionary:
	var blink := fmod(t + _seed * 1.7, 3.9 + _seed) < 0.13
	return {"hand_l": _hip(lk, -1), "hand_r": _hip(lk, 1), "hint_l": Vector2(-1, 0.25), "hint_r": Vector2(1, 0.25),
		"fore_l": Rig.FORE, "fore_r": Rig.FORE, "point_l": 0.0, "point_r": 0.0, "front_r": true,
		"folio": 0.0, "pen": 0.0, "head_rot": 0.0, "head_off": Vector2.ZERO,
		"breathe": 0.006 * sin(t * 2.0 + _seed), "talk": false, "blink": blink}


func _idle_pose(lk: Dictionary) -> Dictionary:
	var p := _base(lk)
	var sy := float(lk["sy"])
	match idle:
		0:   # arm pump: the right fist swings up and out every 3.2 s
			var ph := fmod(t + _seed, 3.2) / 3.2
			var k := clampf(sin(ph * TAU) * 2.2, 0.0, 1.0)
			k = _ss(k)
			var sh := Rig.shoulder(lk, 1, 0.0)
			var th := deg_to_rad(lerpf(80.0, -72.0, k))
			var r := lerpf(80.0, 72.0, k) + 3.0 * sin(k * PI)
			p["hand_r"] = sh + Vector2.from_angle(th) * r
			p["hint_r"] = Vector2(1, 0.12)
			p["head_off"] = Vector2(0, -1.4 * k)
			p["head_rot"] = 0.03 * k
		1:   # arms crossed, swaying
			p["hand_r"] = Vector2(-18, sy + 40)
			p["hand_l"] = Vector2(16, sy + 48)
			p["fore_r"] = 70.0
			p["fore_l"] = 68.0
			p["hint_r"] = Vector2(1, 0.4)
			p["hint_l"] = Vector2(-1, 0.4)
			p["front_r"] = false
			p["head_rot"] = sin(t * 1.6 + _seed) * 0.035
		2:   # hands on hips, nodding
			p["head_off"] = Vector2(0, maxf(0.0, sin(t * 2.2 + _seed)) * 1.6)
			p["head_rot"] = sin(t * 1.1 + _seed) * 0.015
		_:   # folio + fountain pen tapping
			var tap := absf(sin(t * 3.0 + _seed)) * 4.0
			p["hand_l"] = Vector2(-15, sy + 66)
			p["hint_l"] = Vector2(-1, 0.4)
			p["hand_r"] = Vector2(12, sy + 36 - tap)
			p["hint_r"] = Vector2(1, 0.45)
			p["folio"] = 1.0
			p["pen"] = 1.0
			p["head_rot"] = 0.02
	return p


func _instruct_pose(lk: Dictionary) -> Dictionary:
	var p := _base(lk)
	var st: Dictionary = STYLE[int(lk["tier"])]
	var d := 1     # poses are built facing +x; the rig mirrors the figure when point_dir < 0
	var s := "r" if d > 0 else "l"
	var sh := Rig.shoulder(lk, d, 0.0)
	var w := sin(TAU * t / float(st["period"]))              # -1..1 smooth chop
	var deg := lerpf(float(st["up"]), float(st["down"]), 0.5 + 0.5 * w)
	var th := deg_to_rad(deg)
	var dir := Vector2(cos(th) * d, sin(th))
	p["hand_" + s] = sh + dir * float(st["reach"])
	p["hint_" + s] = Vector2(d, 0.55)
	# no pointing finger (Hamza: looked rude) - the fist does the bossing
	p["front_r"] = d > 0
	var bob := float(st["bob"]) * (0.5 + 0.5 * sin(TAU * t / float(st["period"]) + 0.6))
	if int(lk["tier"]) == 2:
		# Executive: nose in the air, head turned a touch away, lazy flick
		p["head_off"] = Vector2(0, -2.5)
		p["head_rot"] = -d * 0.06
	else:
		p["head_off"] = Vector2(d * 1.0, -bob)
		p["head_rot"] = d * 0.045
	p["breathe"] = float(p["breathe"]) + float(st["bounce"]) * (0.5 + 0.5 * w)
	# mouth: open / shut in an uneven rhythm
	var ts := t * float(st["talk"])
	p["talk"] = sin(ts * 11.0) + sin(ts * 6.3 + 1.3) * 0.8 > 0.35
	return p
