extends RefCounted
## One front desk cashier's animation (v0.19e). Purely visual: it only reads whether the desk is counting.
##   idle    hands resting on the counter, breathing, a little sway, blinks
##   count   (desk running) stack of notes in her left hand, the right hand deals them onto the counter
##           one by one, head tipped down to the counter
##   cheer   arm up + happy face (cheer()), or just the happy face (smile()) when the desk runs itself
## Hands blend smoothly between modes (no snapping); the rig's elbow memory keeps the elbows from flipping.

const COUNTER_Y := 196.0       # where her hands rest (design units: the counter lip)
const BLEND := 0.3
const CHEER_TIME := 0.8

var t := 0.0
var seed := 0.0
var working := 0.0             # 0..1 blend idle -> counting
var counting := false
var deal := 0.75               # seconds per note dealt
var mem := {}
var _cheer_t := -10.0
var _smile_t := -10.0
var _cheer_arm := false


func _init(seed_f := 0.0) -> void:
	seed = seed_f
	t = seed_f * 3.7


func update(delta: float, is_counting: bool, cycle := 3.0) -> void:
	t += delta
	counting = is_counting
	working = move_toward(working, 1.0 if is_counting else 0.0, delta / BLEND)
	deal = clampf(cycle / 4.0, 0.4, 0.9)


## Big cheer: arm up + happy face (the till just took the cash and the player tapped for it).
func cheer() -> void:
	_cheer_t = t
	_cheer_arm = true


## Small cheer for when the desk runs itself: just the happy face (calm screen).
func smile() -> void:
	_smile_t = t


static func _ss(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func cheering() -> float:
	var c := t - _cheer_t
	if c > CHEER_TIME:
		return 0.0
	return _ss(c / 0.15) * _ss((CHEER_TIME - c) / 0.25)


func pose() -> Dictionary:
	var br := 0.006 * sin(t * 2.0 + seed)
	# idle: hands resting on the counter
	var hl := Vector2(-20.0, COUNTER_Y + 1.0 * sin(t * 1.3 + seed))
	var hr := Vector2(22.0, COUNTER_Y + 1.0 * sin(t * 1.3 + seed + 1.0))
	var stack := 0.0
	var note := 0.0
	var head_rot := sin(t * 0.9 + seed) * 0.03
	var head_off := Vector2(0, 0)
	if working > 0.001:
		# counting: left hand holds the stack, the right hand deals a note onto the counter and comes back
		var u := fposmod(t / deal + seed, 1.0)
		var pick := Vector2(-10.0, COUNTER_Y - 6.0)
		var place := Vector2(30.0, COUNTER_Y + 1.0)
		var r: Vector2
		if u < 0.4:          # carry the note over in a little arc
			var q := _ss(u / 0.4)
			r = pick.lerp(place, q) + Vector2(0, -12.0 * sin(q * PI))
			note = 1.0
		elif u < 0.55:       # press it down
			r = place + Vector2(0, 1.5 * sin((u - 0.4) / 0.15 * PI))
			note = 1.0 - (u - 0.4) / 0.15
		else:                # back for the next one
			var q2 := _ss((u - 0.55) / 0.45)
			r = place.lerp(pick, q2) + Vector2(0, -6.0 * sin(q2 * PI))
		var hl2 := Vector2(-22.0, COUNTER_Y - 4.0)
		hl = hl.lerp(hl2, _ss(working))
		hr = hr.lerp(r, _ss(working))
		stack = _ss(working)
		note *= _ss(working)
		head_rot = lerpf(head_rot, 0.05, working)
		head_off = Vector2(0, 2.0 * working)
	var head := "c_head"
	if fmod(t + seed * 1.3, 3.9 + seed) < 0.12:
		head = "c_head_blink"
	var ch := cheering()
	if ch > 0.0 or t - _smile_t < 0.7:
		head = "c_head_happy"
	var hint_l := Vector2(-1, 0.4)
	if ch > 0.0 and _cheer_arm:
		# fist pump with the left arm (the right keeps whatever it was doing)
		var up := Vector2(-56.0, 96.0 + 6.0 * sin((t - _cheer_t) * 18.0))
		hl = hl.lerp(up, ch)
		stack *= 1.0 - ch
		hint_l = Vector2(-1, -0.1)
		br += 0.01 * ch
	return {"hand_l": hl, "hand_r": hr, "hint_l": hint_l, "hint_r": Vector2(1, 0.4), "stack": stack, "note_r": note,
		"head": head, "head_rot": head_rot, "head_off": head_off, "breathe": br}
