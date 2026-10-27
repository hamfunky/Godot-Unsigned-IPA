extends RefCounted
## Front desk cashier rig (v0.19e, the approved prototype v4): body + head are baked textures
## (tools/char/cashier_parts.py), the slim arms, hands and the notes she counts are drawn in code
## (2-bone IK, same ink + cel-shade look as the managers' arms) so her hands can work on the counter.
## Front view: she faces the customer. facing = -1 mirrors her (the second cashier).
## A pose (CashierAnim builds them, always for facing +1):
##   hand_l, hand_r  Vector2  hand centres (design units; l = image-left)
##   hint_l, hint_r  Vector2  which way each elbow points
##   stack           float    0..1 the stack of notes in her left hand
##   note_r          float    0..1 a single note in her right hand
##   head            String   "c_head" / "c_head_blink" / "c_head_happy"
##   head_rot        float    head tilt (radians) on the chin
##   head_off        Vector2
##   breathe         float

const CP = preload("res://scripts/cashier_parts.gd")
const MRig = preload("res://scripts/manager_rig.gd")
const DIR := "res://assets/game/sprites/cashier/%s.png"
const FIG_UNITS := 324.0          # px height maps to this many units (top of the bun .. soles)
const INK := Color("1d1b2b")
const NOTE := Color("43a047")
const NOTE_LIGHT := Color("e8f5e9")

static var _tex := {}


static func tex(n: String) -> Texture2D:
	if not _tex.has(n):
		_tex[n] = load(DIR % n)
	return _tex[n]


static func shoulder(side: int, br: float) -> Vector2:
	return Vector2(side * CP.SHOULDER.x, CP.SHOULDER.y - (CP.GROUND - CP.SHOULDER.y) * br)


static func draw(ci: CanvasItem, feet: Vector2, px_h: float, pose: Dictionary, mem: Dictionary, facing := 1.0) -> void:
	var pen = MRig.Pen.new(ci, feet, px_h / FIG_UNITS, facing)
	var br := float(pose.get("breathe", 0.0))
	_part(pen, "c_body", Vector2(0, CP.GROUND), 0.0, Vector2(1, 1 + br))
	for side in [-1, 1]:
		var s := "l" if side < 0 else "r"
		_arm(pen, side, pose["hand_" + s], pose.get("hint_" + s, Vector2(side, 0.4)), mem, s, br,
			float(pose.get("stack", 0.0)) if side < 0 else 0.0, float(pose.get("note_r", 0.0)) if side > 0 else 0.0)
	var chin := Vector2(CP.CHIN.x, CP.CHIN.y - (CP.GROUND - CP.CHIN.y) * br) + Vector2(pose.get("head_off", Vector2.ZERO))
	_part(pen, str(pose.get("head", "c_head")), chin, float(pose.get("head_rot", 0.0)))


static func _part(pen, n: String, at: Vector2, rot := 0.0, sc := Vector2.ONE) -> void:
	var s: float = pen.k / CP.RES
	pen.ci.draw_set_transform(pen.px(at), rot * pen.fx, Vector2(sc.x * s * pen.fx, sc.y * s))
	pen.ci.draw_texture(tex(n), -CP.PARTS[n])
	pen.ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _arm(pen, side: int, hand: Vector2, hint: Vector2, mem: Dictionary, s: String, br: float, stack: float, note: float) -> void:
	var sh := shoulder(side, br)
	var el: Vector2 = MRig.elbow(sh, hand, CP.UPPER, CP.FORE, hint, mem, "el_" + s)
	var d := hand - el
	var wr := el + d.normalized() * minf(d.length(), CP.FORE) if d.length() > 0.01 else hand
	var skin: Array = CP.SKIN
	var dress: Array = CP.DRESS
	pen.limb(el, wr, 7.5, 6.2, skin[0], skin[1])
	pen.limb(sh, el, 9.0, 7.5, skin[0], skin[1])
	# short silky cap sleeve over the shoulder
	pen.limb(sh + Vector2(-side * 3.0, -2.0), sh + (el - sh) * 0.38, 10.5, 9.0, dress[0], dress[1])
	var u := (wr - el).normalized() if wr.distance_to(el) > 0.01 else Vector2.DOWN
	var hc := wr + u * 5.0
	if stack > 0.02:
		for k in 3:
			_note(pen, hc + Vector2(side * 2.0, -4.0 - k * 3.2), -0.08 * side, stack)
	if note > 0.02:
		_note(pen, hc + Vector2(-side * 4.0, -5.0), 0.25 * side, note)
	pen.dot(hc, 8.4, skin[0], skin[1])
	pen.dot(hc + Vector2(-side * 6.5, -3.0), 3.4, skin[0], skin[1])


## A banknote (design units), rotated, fading in with `a`.
static func _note(pen, c: Vector2, rot: float, a: float) -> void:
	var hw := 17.0 * a
	var hh := 5.6
	var pts := PackedVector2Array()
	var ink := PackedVector2Array()
	for q in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		pts.append(c + Vector2(q.x * hw, q.y * hh).rotated(rot))
		ink.append(c + Vector2(q.x * (hw + 1.6), q.y * (hh + 1.6)).rotated(rot))
	pen.poly(ink, INK)
	pen.poly(pts, NOTE)
	pen.poly(PackedVector2Array([c + Vector2(-hw * 0.8, -1.0).rotated(rot), c + Vector2(hw * 0.8, -1.0).rotated(rot),
		c + Vector2(hw * 0.8, 1.0).rotated(rot), c + Vector2(-hw * 0.8, 1.0).rotated(rot)]), NOTE_LIGHT)
