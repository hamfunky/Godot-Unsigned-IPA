extends RefCounted
## Detailer character rig (v0.18, 19 Oct): the locked design (tools/char/, sheet v4) cut into part
## textures and pinned together here. Arms and legs use 2-bone IK (hands / feet follow targets, elbows and
## knees work themselves out); the shirt sleeves are rebuilt every frame from the torso's shoulder line to
## the upper arm, so the shoulders always look attached. Everything is drawn with a CanvasItem's draw calls.
##
## Coordinates ("units") are the design's: the figure is ~266 units tall, origin = between the feet on the
## floor, +x = the way he faces, y down. `draw()` scales units to pixels and mirrors for facing -1.
##
## A pose is a Dictionary (DetailerAnim builds them):
##   view        0 = 3/4 (facing the car), 1 = front (facing you)
##   hip         Vector2  torso pivot (belt), rest = REST_HIP
##   torso_rot   float    lean (+ = forward / clockwise)
##   breathe     float    torso stretch (0 = rest, 0.012 = full breath)
##   head_rot    float    head tilt on the neck
##   hand_n, hand_f  Vector2  wrist targets for the near / far arm (front view: left / right)
##   foot_n, foot_f  Vector2  ankle positions
##   fist_n, fist_f  float    extra fist rotation
##   tool        String   "mitt" (far hand) or ""
##   blink, grin bool
##   squash      Vector2  whole-figure scale around the feet (turns, anticipation)

const P = preload("res://scripts/detailer_parts.gd")
const DIR := "res://assets/game/sprites/detailer/%s.png"
const HEIGHT_UNITS := 266.0        # top of the hair to the soles
const FAR_TINT := Color(0.80, 0.80, 0.86)

static var _tex := {}
static var _torso := {}


static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(DIR % name)
	return _tex[name]


static func _torso_poly(view: int) -> PackedVector2Array:
	if not _torso.has(view):
		_torso[view] = PackedVector2Array(P.TORSO_F if view == 1 else P.TORSO_34)
	return _torso[view]


static func sk(key: String):
	return P.SKEL[key]


static func rest_hip() -> Vector2:
	return Vector2(0, float(sk("hip_y")) - float(sk("ground")))


static func rest_foot(near: bool, view: int) -> Vector2:
	var g := float(sk("ground"))
	if view == 1:
		var f: Vector2 = sk("foot_F")
		return Vector2(-f.x if near else f.x, f.y - g)
	var v: Vector2 = sk("foot_near34") if near else sk("foot_far34")
	return Vector2(v.x, v.y - g)


## Shoulder joint (torso-local) for an arm.
static func shoulder(near: bool, view: int) -> Vector2:
	if view == 1:
		var s: Vector2 = sk("sh_F")
		return Vector2(-s.x if near else s.x, s.y)
	return sk("sh_near34") if near else sk("sh_far34")


static func torso_xf(pose: Dictionary) -> Transform2D:
	var b := 1.0 + float(pose.get("breathe", 0.0))
	return Transform2D(float(pose.get("torso_rot", 0.0)), Vector2(1.0, b), 0.0, pose.get("hip", rest_hip()))


## 2-bone IK: returns [mid joint, end joint]. bend +1 / -1 picks which side the joint bends to.
## v0.18b (arm-jitter fix, 19 Oct): the limb eases into full stretch instead of snapping straight (acos is
## infinitely steep at full reach, so a target hovering there made the elbow twitch), and a target very close
## to the shoulder no longer spins the whole limb around it (its direction blends to a steady "down").
static func ik(a: Vector2, target: Vector2, l1: float, l2: float, bend: float) -> Array:
	var to := target - a
	var raw := to.length()
	var full := l1 + l2
	var knee := full * 0.90
	var d := raw
	if d > knee:
		var room := full * 0.995 - knee
		d = knee + room * tanh((d - knee) / room)
	d = maxf(d, absf(l1 - l2) + 0.5)
	var dir := to / raw if raw > 0.001 else Vector2.DOWN
	var near_r := full * 0.25
	if raw < near_r:
		dir = Vector2.DOWN.lerp(dir, raw / near_r).normalized()
	var c := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var mid := a + dir.rotated(acos(c) * bend) * l1
	var end := mid + (a + dir * d - mid).normalized() * l2
	return [mid, end]


## Draws the figure with its feet at `feet` (px), `height` px tall, facing +1 (right) or -1 (left).
## Returns {"nozzle": px} while he holds the foam cannon (where its spray starts), else {}.
static func draw(ci: CanvasItem, feet: Vector2, height: float, facing: float, pose: Dictionary, modulate := Color.WHITE) -> Dictionary:
	var out := {}
	var k := height / HEIGHT_UNITS
	var sq: Vector2 = pose.get("squash", Vector2.ONE)
	var fig := Transform2D(0.0, Vector2(k * signf(facing) * sq.x, k * sq.y), 0.0, feet)
	var view := int(pose.get("view", 0))
	var tx := torso_xf(pose)
	var hip: Vector2 = pose.get("hip", rest_hip())
	var hj: Vector2
	var arms := {}
	for near in [true, false]:
		var sh := tx * shoulder(near, view)
		var target: Vector2 = pose.get("hand_n" if near else "hand_f", sh + Vector2(0, 80))
		# 3/4 view: elbows down / back. Front view (the flex): elbows out to the sides.
		var bend := 1.0 if view == 0 else (-1.0 if near else 1.0)
		bend = float(pose.get("bend_n" if near else "bend_f", bend))   # the flex flips the near elbow out
		arms[near] = [sh] + ik(sh, target, float(sk("upper_arm")), float(sk("forearm")), bend)
	var legs := {}
	for near in [true, false]:
		if view == 1:
			var hf: Vector2 = sk("hip_F")
			hj = hip + Vector2(-hf.x if near else hf.x, hf.y)
		else:
			hj = hip + (sk("hip_near34") if near else sk("hip_far34"))
		var ft: Vector2 = pose.get("foot_n" if near else "foot_f", rest_foot(near, view))
		var kb := -1.0 if view == 0 else (1.0 if near else -1.0)
		legs[near] = [hj] + ik(hj, ft, float(sk("thigh")), float(sk("shin")), kb)
	if view == 0:
		# far_front: the far arm comes round in front of his head (holding the top of the polisher)
		# far_front: the far forearm + fist come round in front of his head (holding the top of the polisher);
		# the upper arm stays behind his body like a far arm should
		var far_front := bool(pose.get("far_front", false))
		_arm(ci, fig, pose, arms[false], false, view, tx, modulate, 1 if far_front else 0)
		_leg(ci, fig, legs[false], "boot34", FAR_TINT * modulate)
		_leg(ci, fig, legs[true], "boot34", modulate)
		_part(ci, fig * tx, "torso34", Vector2.ZERO, 0.0, modulate)
		_head(ci, fig, pose, tx, view, modulate)
		if str(pose.get("tool", "")) == "cannon":
			out["nozzle"] = _cannon(ci, fig, pose, modulate)
		elif str(pose.get("tool", "")) == "polisher":
			_polisher(ci, fig, pose, modulate)
		if far_front:
			_arm(ci, fig, pose, arms[false], false, view, tx, modulate, 2)
		_arm(ci, fig, pose, arms[true], true, view, tx, modulate)
	else:
		_leg(ci, fig, legs[true], "bootF", modulate)
		_leg(ci, fig, legs[false], "bootF", modulate)
		_part(ci, fig * tx, "torsoF", Vector2.ZERO, 0.0, modulate)
		_arm(ci, fig, pose, arms[true], true, view, tx, modulate)
		_arm(ci, fig, pose, arms[false], false, view, tx, modulate)
		_head(ci, fig, pose, tx, view, modulate)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	return out


## Polisher in his hands (pivot = the pad's face): cord to the floor behind him, the machine, then the pad
## spinning (ticks scrolling across it) and a few flecks of compound flicking off.
static func _polisher(ci: CanvasItem, fig: Transform2D, pose: Dictionary, mod: Color) -> void:
	var pad: Vector2 = pose.get("pad", Vector2(100, -130))
	var rot := float(pose.get("tool_rot", 0.0))
	var tk := float(pose.get("tool_k", 1.0))
	var t := float(pose.get("t", 0.0))
	if tk <= 0.01:
		return
	var cord_at := pad + (sk("pol_cord") as Vector2).rotated(rot) * tk
	ci.draw_set_transform_matrix(fig)
	var cord := PackedVector2Array([cord_at])
	_cubic(cord, cord_at, cord_at + Vector2(-30, 10), Vector2(-60, -2), Vector2(-160, -1), 14)
	var fade := Color(1, 1, 1, clampf(tk * 2.0 - 1.0, 0.0, 1.0))
	ci.draw_polyline(cord, Color(str(sk("ink"))) * mod * fade, 7.0 * tk, true)
	ci.draw_polyline(cord, Color("2b2e36") * mod * fade, 3.5 * tk, true)
	_part(ci, fig, "polisher", pad, rot, mod, false, tk)
	# pad spin: short ticks sliding across the pad face
	ci.draw_set_transform_matrix(fig * Transform2D(rot, Vector2(tk, tk), 0.0, pad))
	for k in 3:
		var y := fposmod(t * 140.0 + k * 16.0, 46.0) - 23.0
		ci.draw_line(Vector2(-4, y), Vector2(5, y), Color(0.78, 0.36, 0.08, 0.85) * mod, 2.4, true)
	# compound flecks flicking off the pad
	for k in 5:
		var ph := fposmod(t * 2.3 + k * 0.37, 1.0)
		var dir := Vector2(-0.6, -1.0 + 0.5 * k).normalized()
		var c := Vector2(2, -18 + 9 * k) + dir * ph * 34.0
		ci.draw_circle(c, 2.6 * (1.0 - ph) + 0.6, Color(1.0, 0.94, 0.85, 0.9 * (1.0 - ph)) * mod)
	ci.draw_set_transform_matrix(fig)


## Foam cannon in his hands: hose down to the floor and away behind him, then the gun (pivot = grip).
## Returns the nozzle in px.
static func _cannon(ci: CanvasItem, fig: Transform2D, pose: Dictionary, mod: Color) -> Vector2:
	var grip: Vector2 = pose.get("grip", Vector2(14, -108))
	var aim := float(pose.get("aim", 0.0))
	var tk := float(pose.get("tool_k", 1.0))
	var hose_at := grip + (sk("hose") as Vector2).rotated(aim) * tk
	var g := float(sk("ground"))
	ci.draw_set_transform_matrix(fig)
	var hose := PackedVector2Array()
	_cubic(hose, hose_at, hose_at + Vector2(-6, 40), Vector2(-40, -2), Vector2(-150, -1), 14)
	hose.insert(0, hose_at)
	var fade := Color(1, 1, 1, clampf(tk * 2.0 - 1.0, 0.0, 1.0))   # the hose appears once the gun has mostly popped in
	ci.draw_polyline(hose, Color(str(sk("ink"))) * mod * fade, 9.0 * tk, true)
	ci.draw_polyline(hose, Color("3a3f4a") * mod * fade, 5.0 * tk, true)
	_part(ci, fig, "cannon", grip, aim, mod, false, tk)
	return fig * (grip + (sk("nozzle") as Vector2).rotated(aim) * tk)


## One part texture, its pivot placed at `at` (units, in xf's space), rotated by `rot`.
static func _part(ci: CanvasItem, xf: Transform2D, name: String, at: Vector2, rot: float, modulate := Color.WHITE, flip := false, scl := 1.0) -> void:
	if scl <= 0.01:
		return
	var info: Dictionary = P.PARTS[name]
	var res := float(sk("res"))
	var m := xf * Transform2D(rot, Vector2((-1.0 if flip else 1.0) * scl, scl), 0.0, at)
	ci.draw_set_transform_matrix(m)
	ci.draw_texture_rect(tex(name), Rect2(-info["pivot"] / res, info["size"] / res), false, modulate)


static func _bone_rot(a: Vector2, b: Vector2) -> float:
	return (b - a).angle() - PI * 0.5


static func _leg(ci: CanvasItem, fig: Transform2D, j: Array, boot: String, mod: Color) -> void:
	_part(ci, fig, "shin", j[1], _bone_rot(j[1], j[2]), mod)
	_part(ci, fig, "thigh", j[0], _bone_rot(j[0], j[1]), mod)
	_part(ci, fig, boot, j[2], 0.0, mod)


static func _head(ci: CanvasItem, fig: Transform2D, pose: Dictionary, tx: Transform2D, view: int, mod: Color) -> void:
	var name := "head34"
	if view == 1:
		name = "headF_grin" if pose.get("grin", false) else "headF"
		if pose.get("blink", false) and not pose.get("grin", false):
			name = "headF_blink"
	elif pose.get("grin", false):
		name = "head34_grin"
	elif pose.get("blink", false):
		name = "head34_blink"
	var neck: Vector2 = sk("neckF") if view == 1 else sk("neck34")
	# the head doesn't stretch with the breath: place it at the neck, rotate with the torso + its own tilt
	var at := tx * neck
	_part(ci, fig, name, at, float(pose.get("torso_rot", 0.0)) + float(pose.get("head_rot", 0.0)), mod)


## which: 0 = the whole arm, 1 = upper arm + sleeve only, 2 = forearm + fist (+ tool) only.
static func _arm(ci: CanvasItem, fig: Transform2D, pose: Dictionary, j: Array, near: bool, view: int, tx: Transform2D, mod: Color, which := 0) -> void:
	var sh: Vector2 = j[0]
	var el: Vector2 = j[1]
	var wr: Vector2 = j[2]
	# flex_arms (the double bicep): the forearm folds in FRONT of the upper arm, and the far arm's textures flip
	# so both biceps bulge upwards (otherwise the arm looks on backwards, Hamza 19 Oct)
	var flexing := bool(pose.get("flex_arms", false))
	var flip := (not near) if (view == 1 or flexing) else false
	if flexing and which == 0:
		_part(ci, fig, "upper_arm", sh, _bone_rot(sh, el), mod, flip)
		ci.draw_set_transform_matrix(fig)
		_sleeve(ci, tx * _torso_poly(view), sh, el, -1.0 if near else 1.0, mod, 0.62 if view == 1 else 0.42)
		_part(ci, fig, "forearm", el, _bone_rot(el, wr), mod, flip)
		_fist(ci, fig, pose, el, wr, near, mod)
		return
	if which == 2:
		_part(ci, fig, "forearm", el, _bone_rot(el, wr), mod, flip)
		_fist(ci, fig, pose, el, wr, near, mod)
		return
	if which == 0:
		_part(ci, fig, "forearm", el, _bone_rot(el, wr), mod, flip)
	_part(ci, fig, "upper_arm", sh, _bone_rot(sh, el), mod, flip)
	# sleeve: one shape around the shoulder joint; its ink is hidden where it lies over the torso, so the
	# shoulder blends into the body at any arm angle
	var side := -1.0 if near else 1.0
	var torso := tx * _torso_poly(view)
	ci.draw_set_transform_matrix(fig)
	# front view: the shoulder joint sits inside the shirt outline, so the sleeve runs further down the arm
	# (otherwise it all lands on the shirt and the arms read as bare)
	_sleeve(ci, torso, sh, el, side, mod, 0.62 if view == 1 else 0.42)
	if which == 0:
		_fist(ci, fig, pose, el, wr, near, mod)


static func _fist(ci: CanvasItem, fig: Transform2D, pose: Dictionary, el: Vector2, wr: Vector2, near: bool, mod: Color) -> void:
	var frot := _bone_rot(el, wr) + float(pose.get("fist_n" if near else "fist_f", 0.0))
	_part(ci, fig, "fist", wr, frot, mod)
	if not near and str(pose.get("tool", "")) == "mitt":
		var hc := wr + Vector2(0, float(sk("hand_r")) * 0.55).rotated(frot)
		_part(ci, fig, "mitt", hc, 0.0, mod, false, float(pose.get("tool_k", 1.0)))


static func _cubic(out: PackedVector2Array, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, n: int) -> void:
	for i in range(1, n + 1):
		var t := float(i) / n
		var m := 1.0 - t
		out.append(p0 * m * m * m + p1 * 3.0 * m * m * t + p2 * 3.0 * m * t * t + p3 * t * t * t)


static func _quad(out: PackedVector2Array, p0: Vector2, p1: Vector2, p2: Vector2, n: int) -> void:
	for i in range(1, n + 1):
		var t := float(i) / n
		out.append(p0.lerp(p1, t).lerp(p1.lerp(p2, t), t))


## The shirt sleeve (rebuilt 19 Oct after the crouch bug): a rounded cap around the shoulder joint (covers
## the top of the upper arm at any angle), a deltoid swell down the outer side, the hem, and the inner side.
## Sides + hem are always inked; the cap is inked only where it sticks out of the torso, so where it overlaps
## the body there is no seam and the shoulder reads as part of the shirt.
static func _sleeve(ci: CanvasItem, torso: PackedVector2Array, sh: Vector2, el: Vector2, side: float, mod: Color, hem_t := 0.42) -> void:
	var L := sh.distance_to(el)
	if L < 1.0:
		return
	var u := (el - sh) / L
	var no := Vector2(u.y, -u.x) if side > 0.0 else Vector2(-u.y, u.x)   # outward
	const R := 25.0
	var H := sh + u * L * hem_t
	var H1 := H + no * 23.0
	var H2 := H - no * 21.0
	var cap := PackedVector2Array()
	for i in 13:
		var a := PI * float(i) / 12.0          # inner side -> over the top -> outer side
		cap.append(sh + (-no * cos(a) - u * sin(a)) * R)
	var rest := PackedVector2Array([cap[cap.size() - 1]])
	_cubic(rest, sh + no * R, sh + no * (R + 7.0) + u * L * 0.12, H1 - u * L * 0.14 + no * 2.0, H1, 8)
	_quad(rest, H1, (H1 + H2) * 0.5 + u * 2.5, H2, 4)
	rest.append(H2.lerp(cap[0], 0.5))
	rest.append(cap[0])
	var fill := cap.duplicate()
	for i in range(1, rest.size() - 1):
		fill.append(rest[i])
	if Geometry2D.triangulate_polygon(fill).size() == 0:
		return
	var shirt: Array = sk("shirt")
	var base := Color(shirt[0]) * mod
	var shade := Color(shirt[1]) * mod
	ci.draw_colored_polygon(fill, shade)
	# lit part = the same shape nudged in from the outer edge (v0.18 perf: no polygon intersection; where it
	# pokes past the sleeve it lands on the same-coloured shirt or under the ink line)
	var off := -no * 5.0 + Vector2(0, -3)
	var moved := PackedVector2Array()
	for p in fill:
		moved.append(p + off)
	ci.draw_colored_polygon(moved, base)
	ci.draw_line(H1 - u * 5.0, H2 - u * 5.0, shade, 2.5, true)
	var ink := Color(str(sk("ink"))) * mod
	ci.draw_polyline(rest, ink, 6.0, true)
	for part in Geometry2D.clip_polyline_with_polygon(cap, torso):
		if part.size() > 1:
			ci.draw_polyline(part, ink, 6.0, true)
			ci.draw_circle(part[0], 3.0, ink)
			ci.draw_circle(part[part.size() - 1], 3.0, ink)
	ci.draw_circle(rest[0], 3.0, ink)
	ci.draw_circle(rest[rest.size() - 1], 3.0, ink)


## A polygon we can fill: triangulates and no two non-neighbouring edges cross.
static func _valid(poly: PackedVector2Array) -> bool:
	var n := poly.size()
	if n < 3 or Geometry2D.triangulate_polygon(poly).size() == 0:
		return false
	for i in n:
		var a1 := poly[i]
		var a2 := poly[(i + 1) % n]
		for j in range(i + 2, n):
			if i == 0 and j == n - 1:
				continue
			if Geometry2D.segment_intersects_segment(a1, a2, poly[j], poly[(j + 1) % n]) != null:
				return false
	return true
