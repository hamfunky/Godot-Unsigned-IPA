extends RefCounted
## Posh cash manager rig (v0.19, 19 Oct): the locked compact-v2 managers (tools/char/posh.py) baked into part
## textures by tools/char/manager_parts.py and pinned together here. Front view only (they face you).
##   body (+ crew overlay tinted with the crew colour) and head are textures; the arms and hands are drawn in
##   code every frame (2-bone IK) so they bend smoothly with no seams.
## Units = design units: feet on the floor at y = P.GROUND, x = 0 between the feet, y down.
##
## They're drawn turned towards their workers (facing +x); facing = -1 mirrors the whole figure (valet).
## A pose (ManagerAnim builds them, always for facing +x):
##   hand_l, hand_r   Vector2  wrist targets (l = image-left arm)
##   hint_l, hint_r   Vector2  which way the elbow points (picked between the two IK answers)
##   fore_l, fore_r   float    forearm length (cartoon stretch for crossed arms)
##   point_l, point_r float    0..1 pointing finger
##   front_r          bool     the right forearm is drawn over the left one
##   folio            float    0..1 clipboard / folio in the left hand (scales away)
##   pen              float    0..1 pen in the right hand
##   head_rot         float    head tilt (radians) on the chin
##   head_off         Vector2  head offset
##   breathe          float    body stretch up (0.01 = 1%)
##   talk, blink      bool

const P = preload("res://scripts/manager_parts.gd")
const DIR := "res://assets/game/sprites/managers/%s.png"
const INK := Color("1d1b2b")
const UPPER := 44.0
const FORE := 40.0
const HAND_R := 7.5
const FIG_UNITS := 270.0          # px_height maps to this many units (top of a normal head .. soles)
const OUTLINE := 4.6
const HEAD_LEAN := 2.0           # the head sits a touch towards the workers (they're turned that way)



static func look(i: int) -> Dictionary:
	return P.LOOKS[clampi(i, 0, P.LOOKS.size() - 1)]


static func looks_of_tier(tier: int) -> Array:
	var out := []
	for i in P.LOOKS.size():
		if int(P.LOOKS[i]["tier"]) == tier:
			out.append(i)
	return out


static func shoulder(lk: Dictionary, side: int, breathe: float) -> Vector2:
	var y := float(lk["sy"]) + 8.0
	return Vector2(side * (float(lk["S"]) - 4.0), y - (P.GROUND - y) * breathe)


## Two-bone IK. Returns the elbow; `mem` keeps the last elbow so near-ties never flip.
static func elbow(sh: Vector2, hand: Vector2, a: float, b: float, hint: Vector2, mem: Dictionary, key: String) -> Vector2:
	## Two answers exist (elbow on either side of the shoulder->hand line). The elbow keeps to the side it was
	## on last frame (no flips), and only takes the hinted side when the arm is nearly straight, where both
	## answers sit on top of each other so the change can't be seen.
	var d := hand - sh
	var L := clampf(d.length(), absf(a - b) + 0.5, a + b - 0.05)
	var c := clampf((a * a + L * L - b * b) / (2.0 * a * L), -1.0, 1.0)
	var ang := acos(c)
	var base := d.angle()
	var e1 := sh + Vector2.from_angle(base + ang) * a
	var e2 := sh + Vector2.from_angle(base - ang) * a
	var s1 := (e1 - sh).normalized().dot(hint.normalized())
	var s2 := (e2 - sh).normalized().dot(hint.normalized())
	var hinted := e1 if s1 >= s2 else e2
	var e := hinted
	if mem.has(key) and e1.distance_to(e2) > 6.0:
		var prev: Vector2 = mem[key]
		e = e1 if e1.distance_to(prev) <= e2.distance_to(prev) else e2
	mem[key] = e
	return e


## Elbows + wrists for both arms (also used by tools/char/manager_probe.gd to check for jumps).
static func solve_arms(lk: Dictionary, pose: Dictionary, mem: Dictionary, br: float) -> Dictionary:
	var arms := {}
	for side in [-1, 1]:
		var s := "l" if side < 0 else "r"
		var sh := shoulder(lk, side, br)
		var hand: Vector2 = pose["hand_" + s]
		if pose.has("arm_" + s):
			# joint angles from ManagerAnim (upper arm, forearm, forearm length): plain forward kinematics
			var j: Vector3 = pose["arm_" + s]
			var e := sh + Vector2.from_angle(j.x) * UPPER
			arms[s] = {"sh": sh, "el": e, "wr": e + Vector2.from_angle(j.y) * j.z, "side": side}
			continue
		var fl := float(pose.get("fore_" + s, FORE))
		var el := elbow(sh, hand, UPPER, fl, pose.get("hint_" + s, Vector2(side, 0.3)), mem, "el_" + s)
		var d := hand - el
		var reach := d.length()
		var wr := el + d.normalized() * minf(reach, fl) if reach > 0.001 else hand
		arms[s] = {"sh": sh, "el": el, "wr": wr, "side": side}
	return arms


class Pen:
	## Maps design units to the canvas and draws shapes with the ink + cel-shade look.
	static var _tex := {}
	static func texture(n: String) -> Texture2D:
		if not _tex.has(n):
			_tex[n] = load(DIR % n)
		return _tex[n]
	static func capsule(a: Vector2, b: Vector2, ra: float, rb: float) -> PackedVector2Array:
		var d := b - a
		var ang := d.angle() if d.length() > 0.001 else 0.0
		var pts := PackedVector2Array()
		for i in 9:
			pts.append(b + Vector2.from_angle(ang - PI * 0.5 + PI * i / 8.0) * rb)
		for i in 9:
			pts.append(a + Vector2.from_angle(ang + PI * 0.5 + PI * i / 8.0) * ra)
		return pts
	var ci: CanvasItem
	var feet: Vector2
	var k: float
	var fx := 1.0           # -1 = mirrored (facing left)
	func _init(c: CanvasItem, f: Vector2, kk: float, facing := 1.0) -> void:
		ci = c
		feet = f
		k = kk
		fx = -1.0 if facing < 0.0 else 1.0
	func px(u: Vector2) -> Vector2:
		return feet + Vector2(u.x * fx, u.y - P.GROUND) * k
	func poly(u_pts: PackedVector2Array, col: Color) -> void:
		var p := PackedVector2Array()
		for q in u_pts:
			p.append(px(q))
		ci.draw_colored_polygon(p, col)
	## v0.19w perf: a solid capsule as two circles + the quad between them (drawn by the engine; the old way built
	## an 18-point shape in script and triangulated it, 3x per limb, every frame). Opaque colours only: with
	## see-through ones the overlaps would show (the rim light still uses poly(capsule)).
	func cap(a: Vector2, b: Vector2, ra: float, rb: float, col: Color) -> void:
		var pa := px(a)
		var pb := px(b)
		var r_a := ra * k
		var r_b := rb * k
		ci.draw_circle(pa, r_a, col)
		ci.draw_circle(pb, r_b, col)
		var d := pb - pa
		if d.length_squared() < 0.0001:
			return
		var n := Vector2(-d.y, d.x).normalized()
		ci.draw_colored_polygon(PackedVector2Array([pa + n * r_a, pb + n * r_b, pb - n * r_b, pa - n * r_a]), col)
	func limb(a: Vector2, b: Vector2, ra: float, rb: float, base: Color, shade: Color, ink := true) -> void:
		if ink:
			cap(a, b, ra + OUTLINE * 0.5, rb + OUTLINE * 0.5, INK)
		cap(a, b, ra, rb, shade)
		var off := Vector2(-1.0, -0.8)
		cap(a + off, b + off, ra * 0.72, rb * 0.72, base)
	func dot(c: Vector2, r: float, base: Color, shade: Color) -> void:
		ci.draw_circle(px(c), (r + OUTLINE * 0.5) * k, INK)
		ci.draw_circle(px(c), r * k, shade)
		ci.draw_circle(px(c + Vector2(-1.1, -1.0)), r * 0.74 * k, base)
	func part(n: String, at: Vector2, rot := 0.0, sc := Vector2.ONE, mod := Color.WHITE) -> void:
		var info: Dictionary = P.PARTS[n]
		var s := k / float(info["res"])
		ci.draw_set_transform(px(at), rot * fx, Vector2(sc.x * s * fx, sc.y * s))
		ci.draw_texture(Pen.texture(n), -Vector2(info["pivot"]), mod)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Draws the manager. feet = canvas point between the feet, px_h = height in pixels for FIG_UNITS.
## rim = active-ability rim light colour (alpha = strength, 0 = off); it comes from the effect layer.
static func draw(ci: CanvasItem, feet: Vector2, px_h: float, li: int, pose: Dictionary, crew: Color, mem: Dictionary, rim := Color(1, 1, 1, 0), facing := 1.0) -> void:
	var lk := look(li)
	var id: String = lk["id"]
	var tier := int(lk["tier"])
	var pen := Pen.new(ci, feet, px_h / FIG_UNITS, facing)
	var br := float(pose.get("breathe", 0.0))
	var skin := Color(lk["skin"])
	var skin_sh := Color(lk["skin_shade"])
	var suit := Color(lk["suit"])
	var suit_sh := Color(lk["suit_shade"])
	var arms := solve_arms(lk, pose, mem, br)
	# chin (where the head sits) follows the breathing
	var chin_y := float(lk["chin"])
	var chin := Vector2(HEAD_LEAN, chin_y - (P.GROUND - chin_y) * br) + Vector2(pose.get("head_off", Vector2.ZERO))
	var hrot := float(pose.get("head_rot", 0.0))
	# ---- rim light (active ability), behind everything
	if rim.a > 0.01:
		pen.part(id + "_body_glow", Vector2(0, P.GROUND), 0.0, Vector2(1, 1 + br), rim)
		pen.part(id + "_head_glow", chin, hrot, Vector2.ONE, rim)
		for s in arms:
			var a: Dictionary = arms[s]
			for w in [6.0, 3.5]:
				var c := Color(rim.r, rim.g, rim.b, rim.a * 0.33)
				pen.poly(Pen.capsule(a["sh"], a["el"], 8.5 + w, 6.5 + w), c)
				pen.poly(Pen.capsule(a["el"], a["wr"], 6.5 + w, 5.5 + w), c)
				ci.draw_circle(pen.px(Vector2(a["wr"]) + (Vector2(a["wr"]) - Vector2(a["el"])).normalized() * 4.0), (HAND_R + w) * pen.k, c)
	# ---- upper arms (behind the jacket)
	for s in arms:
		var a: Dictionary = arms[s]
		pen.limb(a["sh"], a["el"], 8.5, 6.8, suit, suit_sh)
	# ---- body + crew-colour items
	pen.part(id + "_body", Vector2(0, P.GROUND), 0.0, Vector2(1, 1 + br))
	pen.part(id + "_body_crew", Vector2(0, P.GROUND), 0.0, Vector2(1, 1 + br), crew)
	# ---- head
	var hn := id + ("_head_blink" if pose.get("blink", false) else ("_head_talk" if pose.get("talk", false) else "_head"))
	pen.part(hn, chin, hrot)
	# ---- folio in the left hand
	var fo := float(pose.get("folio", 0.0))
	if fo > 0.02:
		var lw: Vector2 = arms["l"]["wr"]
		pen.part("folio", lw + Vector2(11, -24) * fo, -0.17, Vector2(fo, fo))
	# ---- forearms + hands (front)
	var front_r: bool = pose.get("front_r", true)
	var cross = Geometry2D.segment_intersects_segment(arms["l"]["el"], arms["l"]["wr"], arms["r"]["el"], arms["r"]["wr"])
	if cross != null and mem.has("front_r"):
		front_r = mem["front_r"]          # forearms overlap: don't swap which one is in front
	mem["front_r"] = front_r
	var order := ["l", "r"] if front_r else ["r", "l"]
	for s in order:
		_forearm(pen, arms[s], tier, skin, skin_sh, suit, suit_sh, float(pose.get("point_" + s, 0.0)),
			float(pose.get("pen", 0.0)) if s == "r" else 0.0)


static func _forearm(pen: Pen, a: Dictionary, tier: int, skin: Color, skin_sh: Color, suit: Color, suit_sh: Color, point: float, pen_k: float) -> void:
	var el: Vector2 = a["el"]
	var wr: Vector2 = a["wr"]
	var d := (wr - el).normalized() if wr.distance_to(el) > 0.01 else Vector2.DOWN
	var hand_c := wr + d * HAND_R * 0.55
	if tier == 0:
		# Junior: sleeves a size too long, the hand peeks out
		_hand(pen, hand_c + d * 2.5, d, skin, skin_sh, point)
		_sleeve(pen, a, wr + d * 3.0, 6.6, suit, suit_sh)
	else:
		_sleeve(pen, a, wr, 5.6, suit, suit_sh)
		# shirt cuff + gold cufflink
		var n := Vector2(-d.y, d.x)
		var c := wr - d * 1.2
		pen.ci.draw_line(pen.px(c + n * 6.4), pen.px(c - n * 6.4), INK, 7.0 * pen.k)
		pen.ci.draw_line(pen.px(c + n * 5.4), pen.px(c - n * 5.4), Color("f7f4ec"), 3.6 * pen.k)
		pen.ci.draw_circle(pen.px(c), 1.6 * pen.k, Color("e7b93c"))
		_hand(pen, hand_c, d, skin, skin_sh, point)
	if pen_k > 0.02:
		var tip := hand_c + Vector2(-15, 8) * pen_k
		pen.ci.draw_line(pen.px(hand_c + Vector2(3, -4)), pen.px(tip), INK, 6.5 * pen.k)
		pen.ci.draw_line(pen.px(hand_c + Vector2(3, -4)), pen.px(tip), Color("2a2d34"), 3.2 * pen.k)
		pen.ci.draw_line(pen.px(hand_c.lerp(tip, 0.45)), pen.px(hand_c.lerp(tip, 0.6)), Color("e7b93c"), 3.2 * pen.k)
		pen.dot(hand_c, HAND_R * 0.95, skin, skin_sh)


## The forearm sleeve, joined to the upper arm as ONE piece of cloth: outline first, then the end of the upper
## arm is filled again over it, then the forearm fill - so no outline ring shows at the elbow.
static func _sleeve(pen: Pen, a: Dictionary, end: Vector2, rb: float, suit: Color, suit_sh: Color) -> void:
	var sh: Vector2 = a["sh"]
	var el: Vector2 = a["el"]
	var ul := el.distance_to(sh)
	var u := (el - sh) / ul if ul > 0.01 else Vector2.DOWN
	var off := Vector2(-1.0, -0.8)
	pen.cap(el, end, 6.8 + OUTLINE * 0.5, rb + OUTLINE * 0.5, INK)
	# repaint the elbow end of the upper arm over the forearm's outline, so no ring shows at the elbow. It's the
	# upper arm's own shape and colours (its last ~10 units), so where it lands on the upper arm nothing changes.
	# (v0.19w perf: was the upper arm clipped to a disc with Geometry2D.intersect_polygons every frame.)
	var back := minf(ul, 6.8 + OUTLINE * 0.5 + 1.2)
	var mid := el - u * back
	var r_mid := 6.8 + (8.5 - 6.8) * (back / maxf(ul, 0.01))
	# all shade first, then all highlight, so neither piece's edge lands on the other
	pen.cap(mid, el, r_mid, 6.8, suit_sh)
	pen.cap(el, end, 6.8, rb, suit_sh)
	pen.cap(mid + off, el + off, r_mid * 0.72, 6.8 * 0.72, suit)
	pen.cap(el + off, end + off, 6.8 * 0.72, rb * 0.72, suit)
	# a soft crease on the inside of the bend (only when the elbow is bent)
	var bend := u.angle_to((end - el).normalized())
	if absf(bend) > 0.35:
		var inner := (u.rotated(-PI * 0.5) if bend > 0.0 else u.rotated(PI * 0.5))
		var c := el + inner * 3.2 - u * 1.0
		pen.ci.draw_line(pen.px(c - u * 2.6), pen.px(c + (end - el).normalized() * 2.6), suit_sh.darkened(0.25), 1.3 * pen.k)


static func _hand(pen: Pen, c: Vector2, d: Vector2, skin: Color, skin_sh: Color, point: float) -> void:
	if point > 0.02:
		# pointing finger: a little capsule out of the fist along the arm
		var tip := c + d * (HAND_R + 9.0 * point)
		pen.limb(c, tip, 2.9, 2.5, skin, skin_sh)
	pen.dot(c, HAND_R, skin, skin_sh)
	if point > 0.02:
		pen.limb(c + d * HAND_R * 0.4, c + d * (HAND_R + 9.0 * point), 2.9, 2.5, skin, skin_sh, false)
