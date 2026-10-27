extends "res://scripts/portrait.gd"
## The manager standing at their station (v0.17d, posh rig v0.19).
## CASH managers (v0.19, 19 Oct) = the posh managers from the Manager Lab: ManagerRig draws them (look per
## manager id from their tier's pool: Junior m00-05, Senior m06-11, Executive m12-16; crew colour on the tie /
## pocket square), ManagerAnim plays their idle loop (pose_of: arm pump / arms crossed / hands on hips / folio)
## and, while their ability runs, INSTRUCT (point + chop at what they boss, talking). They're turned towards
## their workers: bays + desk face right, the valet faces left (towards the ute). The SUDS AURA (ManagerAura,
## colour by ability kind) is drawn behind + in front of them and is NOT clipped to the portrait box.
## The old "move 2x faster while the ability runs" is gone for cash managers.
## PREMIUM managers are unchanged: their dossier look (draw_figure below), 2x while their ability runs.
## Nobody here = the "+ HIRE" box, as before. Tap = open the manager panel.

const Rig = preload("res://scripts/manager_rig.gd")
const Anim = preload("res://scripts/manager_anim.gd")
const Aura = preload("res://scripts/manager_aura.gd")

const MP = preload("res://scripts/manager_parts.gd")

const POSES := 4
const HEAD_TOP := 21.6         # top of a (male) posh head in rig units (ManagerParts.LOOKS "top")
const AURA_FADE := 0.55        # s, the effect fades in / out (same as the lab)
const EFFECT := "suds"         # cash managers' active effect (premium ones can get their own id later)

var _t := 0.0                  # premium managers' old idle clock
var _anim = null                # ManagerAnim for the cash manager standing here
var _anim_id := ""
var _aura := 0.0               # effect alpha
var _kind := "income"


const AnimClock = preload("res://scripts/anim_clock.gd")
var _clock := AnimClock.new()   # v0.19w

func _ready() -> void:
	super._ready()
	clip_contents = false      # the aura + the instructing arm reach outside the box
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _process(delta: float) -> void:
	if station_key.begins_with("bay") and GameState.bay_index(station_key) >= GameState.bays.size():
		return
	if station_key != "":
		manager = GameState.manager_at(station_key)
	if not _on_screen():
		return
	var dt := _clock.tick(delta)   # v0.19w perf: moves + redraws AnimClock.HZ times a second
	if dt <= 0.0:
		return
	if not manager.is_empty():
		if GameState.is_premium(manager):
			_t += dt * (2.0 if GameState.ability_active(manager) else 1.0)
		else:
			_tick_cash(dt)
	queue_redraw()


func _on_screen() -> bool:
	if not is_visible_in_tree():
		return false
	return get_global_rect().intersects(get_viewport_rect().grow(80.0))


func _tick_cash(delta: float) -> void:
	var id := _id_of(manager)
	if _anim == null or id != _anim_id:
		_anim = make_anim(manager, facing_of(station_key))
		_anim_id = id
		_aura = 0.0
	var on := GameState.ability_active(manager)
	_anim.active = on
	_anim.update(delta)
	if on:
		_kind = str(GameState.ability_def(manager)["kind"])
	_aura = move_toward(_aura, 1.0 if on else 0.0, delta / AURA_FADE)


static func _id_of(m: Dictionary) -> String:
	return str(m.get("id", "")) + "|" + str(m.get("rarity", 0))


static func pose_of(m: Dictionary) -> int:
	return absi(hash(str(m.get("id", "")) + str(m.get("name", "")))) % POSES


## Which of the 17 posh looks a cash manager wears: always the same one for the same person, from their tier.
static func look_of(m: Dictionary) -> int:
	var pool: Array = Rig.looks_of_tier(clampi(int(m.get("rarity", 0)), 0, 2))
	if pool.is_empty():
		return 0
	return pool[absi(hash("look" + str(m.get("id", "")))) % pool.size()]


## +1 = turned right (bays: the car, desk: the cashier), -1 = turned left (valet: the ute in the lane).
static func facing_of(key: String) -> float:
	return -1.0 if key == "valet" else 1.0


static func make_anim(m: Dictionary, facing := 1.0):
	var seed := float(absi(hash("seed" + str(m.get("id", "")))) % 1000) / 1000.0 * 2.4 + 0.2
	var a = Anim.new(look_of(m), pose_of(m), seed)
	a.point_dir = facing
	return a


## v0.19m polish (was a grey "+ HIRE" box): the ghost of the manager to come (a "?" on the head: every hire
## is a surprise) standing where they'll stand, over a HIRE tag with the price. The tag turns green and the
## ghost bobs gently once you can afford it.
func _draw_hire() -> void:
	var cost := -1.0
	if station_key != "":
		cost = GameState.hire_cost(GameState.area_of(station_key))
	var can := cost >= 0.0 and GameState.cash >= cost
	var w := minf(size.x, 80.0)
	var x0 := (size.x - w) * 0.5
	var tag_h := 46.0 if cost >= 0.0 else 30.0
	var tag := Rect2(x0, size.y - tag_h - 2, w, tag_h)
	var bob := sin(Time.get_ticks_msec() * 0.004) * 2.5 if can else 0.0
	# ghost: head + shoulders, soft white
	var body_h := minf(tag.position.y - 4.0, w * 1.15)
	var top := tag.position.y - body_h + bob
	var hr := w * 0.2
	var hc := Vector2(size.x * 0.5, top + hr + 2)
	var ghost := Color(1, 1, 1, 0.22 if can else 0.14)
	var line := Color(1, 1, 1, 0.75 if can else 0.45)
	var torso := Rect2(size.x * 0.5 - w * 0.36, hc.y + hr + 3, w * 0.72, tag.position.y - (hc.y + hr + 3) + 6)
	if torso.size.y > 8.0:
		UiTheme.rounded(self, torso.grow(1.5), Color(0, 0, 0, 0.0), int(minf(w * 0.3, torso.size.y * 0.5)) + 1, 2, Color(0, 0, 0, 0.22))
		UiTheme.rounded(self, torso, ghost, int(minf(w * 0.3, torso.size.y * 0.5)), 2, line)
		# lapels: a little V so it reads as a suit
		var nk := Vector2(size.x * 0.5, torso.position.y + 2)
		draw_polyline(PackedVector2Array([nk + Vector2(-w * 0.14, 0), nk + Vector2(0, minf(16.0, torso.size.y * 0.5)), nk + Vector2(w * 0.14, 0)]), line, 2.0, true)
	draw_circle(hc, hr, ghost)
	draw_arc(hc, hr + 1.5, 0.0, TAU, 32, Color(0, 0, 0, 0.22), 2.0, true)
	draw_arc(hc, hr, 0.0, TAU, 32, line, 2.0, true)
	UiTheme.text(self, Vector2(hc.x - hr, hc.y + hr * 0.55), "?", int(maxf(18.0, hr * 1.4)), line, HORIZONTAL_ALIGNMENT_CENTER, hr * 2.0, 0, UiTheme.DISPLAY_FONT)
	# the tag
	var c := UiTheme.GOOD if can else Color("5a6478")
	UiTheme.rounded(self, Rect2(tag.position + Vector2(0, 4), tag.size), c.darkened(0.4), 10, 2, UiTheme.INK)
	UiTheme.rounded(self, Rect2(tag.position, tag.size - Vector2(0, 3)), c, 10, 2, UiTheme.INK)
	UiTheme.text(self, Vector2(tag.position.x, tag.position.y + 20), "HIRE", 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, w, 4, UiTheme.DISPLAY_FONT)
	if cost >= 0.0:
		UiTheme.text(self, Vector2(tag.position.x, tag.position.y + 39), GameState.money(cost), 18,
			UiTheme.CASH if can else Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_CENTER, w, 4)


## Figure height (px for the rig's FIG_UNITS) so a manager stands in `box_h` px with their head just inside.
static func fig_px(box_h: float) -> float:
	return (box_h - 5.0) * Rig.FIG_UNITS / (MP.GROUND - HEAD_TOP)


func _draw() -> void:
	if manager.is_empty():
		_draw_hire()
		return
	if GameState.is_premium(manager):
		var look: Dictionary = manager["look"]
		draw_figure(self, Vector2(size.x * 0.5, size.y - 3), size.y - 8, look, pose_of(manager), _t,
			Color(GameState.rarity_def(manager)["color"]), str(look.get("tool", "")))
		return
	if _anim == null:
		_anim = make_anim(manager, facing_of(station_key))
		_anim_id = _id_of(manager)
	var feet := Vector2(size.x * 0.5, size.y - 3)
	var h := fig_px(size.y)
	var rc := Color(GameState.rarity_def(manager)["color"])
	# rarity shadow on the floor (as before)
	draw_set_transform(feet, 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, h * 0.15, Color(rc.r, rc.g, rc.b, 0.55))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var t: float = _anim.t
	var seed: float = _anim._seed
	Aura.draw_back(self, feet, h, EFFECT, _kind, _aura, t, seed)
	Rig.draw(self, feet, h, _anim.look, _anim.pose(), Color(GameState.crew_def(manager)["color"]), _anim.mem,
		Aura.rim(EFFECT, _kind, _aura, t), _anim.point_dir)
	Aura.draw_front(self, feet, h, EFFECT, _kind, _aura, t, seed)


## PREMIUM managers (unchanged): a standing person in their dossier look with feet at `feet`, `h` px tall.
static func draw_figure(ci: CanvasItem, feet: Vector2, h: float, look: Dictionary, pose: int, t: float, rarity_col: Color, tool: String = "") -> void:
	var u := h / 10.0
	var skin: Color = Art.SKINS[int(look["skin"]) % Art.SKINS.size()]
	var hair := Color(look["hair"])
	var shirt := Color(look["shirt"])
	var pants := Color(look["pants"])
	var shoes := Color(look["shoes"])
	var style := int(look["style"])
	var sway := 0.0
	var nod := 0.0
	match pose:
		1:
			sway = sin(t * 1.6) * u * 0.18
		2:
			nod = maxf(0.0, sin(t * 2.2)) * u * 0.12
	var cx := feet.x
	var top := feet.y - h
	# rarity shadow on the floor
	ci.draw_set_transform(Vector2(cx, feet.y), 0.0, Vector2(1.0, 0.32))
	ci.draw_circle(Vector2.ZERO, u * 2.3, Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.55))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var bx := cx + sway   # upper body x
	var y0 := top + u * 2.6   # shoulders (chunky proportions, like the Kenney detailers)
	var head_c := Vector2(bx, top + u * 1.3 + nod)
	var hr := u * 1.2
	var line := Color(0.1, 0.1, 0.12, 0.85)
	if style == 1:
		ci.draw_rect(Rect2(head_c.x - hr * 1.05, head_c.y - hr * 0.2, hr * 2.1, hr * 2.0), hair)
	# legs + shoes
	var hip := y0 + u * 3.2
	ci.draw_rect(Rect2(cx - u * 1.2, hip - 1, u * 2.4, feet.y - hip - u * 0.4), line)   # leg outline
	ci.draw_rect(Rect2(cx - u * 1.1, hip, u * 1.05, feet.y - hip - u * 0.45), pants)
	ci.draw_rect(Rect2(cx + u * 0.05, hip, u * 1.05, feet.y - hip - u * 0.45), pants)
	Art._rounded(ci, Rect2(cx - u * 1.45, feet.y - u * 0.7, u * 1.4, u * 0.7), line)
	Art._rounded(ci, Rect2(cx + u * 0.05, feet.y - u * 0.7, u * 1.4, u * 0.7), line)
	Art._rounded(ci, Rect2(cx - u * 1.38, feet.y - u * 0.64, u * 1.26, u * 0.58), shoes)
	Art._rounded(ci, Rect2(cx + u * 0.12, feet.y - u * 0.64, u * 1.26, u * 0.58), shoes)
	# torso (blends from the hips to the swaying shoulders)
	var torso := PackedVector2Array([Vector2(bx - u * 1.6, y0), Vector2(bx + u * 1.6, y0),
		Vector2(cx + u * 1.35, hip + u * 0.25), Vector2(cx - u * 1.35, hip + u * 0.25)])
	ci.draw_circle(Vector2(bx - u * 1.2, y0 + u * 0.35), u * 0.58, line)
	ci.draw_circle(Vector2(bx + u * 1.2, y0 + u * 0.35), u * 0.58, line)
	ci.draw_colored_polygon(torso, shirt)
	var tl := torso.duplicate()
	tl.append(torso[0])
	ci.draw_polyline(tl, line, 2.0, true)
	ci.draw_circle(Vector2(bx - u * 1.2, y0 + u * 0.35), u * 0.5, shirt)
	ci.draw_circle(Vector2(bx + u * 1.2, y0 + u * 0.35), u * 0.5, shirt)
	if look.get("suit", false):
		# white shirt V under the jacket
		ci.draw_colored_polygon(PackedVector2Array([Vector2(bx - u * 0.55, y0), Vector2(bx + u * 0.55, y0), Vector2(bx, y0 + u * 1.6)]), Color("eef3f8"))
	if str(look.get("tie", "")) != "":
		var tie := Color(look["tie"])
		ci.draw_colored_polygon(PackedVector2Array([Vector2(bx - u * 0.18, y0 + u * 0.1), Vector2(bx + u * 0.18, y0 + u * 0.1),
			Vector2(bx + u * 0.26, y0 + u * 1.7), Vector2(bx, y0 + u * 2.0), Vector2(bx - u * 0.26, y0 + u * 1.7)]), tie)
	ci.draw_rect(Rect2(cx - u * 1.3, hip - u * 0.05, u * 2.6, u * 0.34), pants.darkened(0.3))   # belt
	# neck + head
	ci.draw_rect(Rect2(head_c.x - hr * 0.38, head_c.y + hr * 0.6, hr * 0.76, y0 - head_c.y - hr * 0.5), skin)
	var hm := {"look": look}
	ci.draw_circle(head_c, hr + 1.5, line)
	Art._head(ci, head_c, hr, hm, Art.ALL, skin, hair, style)
	# arms
	var ls := Vector2(bx - u * 1.55, y0 + u * 0.5)
	var rs := Vector2(bx + u * 1.55, y0 + u * 0.5)
	var aw := u * 0.8
	match pose:
		0:
			# arm pump: the right arm goes up for a moment every few seconds
			var k := clampf(sin(fmod(t, 3.2) / 3.2 * TAU * 1.0) * 2.2, 0.0, 1.0)
			k = k * k * (3.0 - 2.0 * k)
			_arm(ci, ls, ls + Vector2(-u * 0.2, u * 1.6), ls + Vector2(-u * 0.05, u * 3.1), aw, shirt, skin)
			var el := rs + Vector2(u * 0.25, u * 1.6).lerp(Vector2(u * 0.9, -u * 0.5), k)
			var hd := rs + Vector2(u * 0.1, u * 3.1).lerp(Vector2(u * 0.5, -u * 2.2), k)
			_arm(ci, rs, el, hd, aw, shirt, skin)
			if tool != "":
				Art.draw_tool(ci, hd + Vector2(u * 0.3, -u * 0.4 * k), u * 1.3, tool)
		1:
			# arms crossed: upper arms at the sides, forearms over the chest
			var le := ls + Vector2(-u * 0.15, u * 1.55)
			var re := rs + Vector2(u * 0.15, u * 1.55)
			_arm(ci, rs, re, re + Vector2(-u * 2.3, -u * 0.25), aw, shirt, skin)
			_arm(ci, ls, le, le + Vector2(u * 2.3, -u * 0.6), aw, shirt, skin)
		2:
			# hands on hips
			_arm(ci, ls, ls + Vector2(-u * 0.9, u * 1.4), Vector2(cx - u * 1.3, hip - u * 0.1), aw, shirt, skin)
			_arm(ci, rs, rs + Vector2(u * 0.9, u * 1.4), Vector2(cx + u * 1.3, hip - u * 0.1), aw, shirt, skin)
		_:
			# clipboard in the left hand, pen tapping with the right
			var lh := Vector2(bx - u * 0.35, y0 + u * 2.2)
			_arm(ci, ls, ls + Vector2(-u * 0.25, u * 1.5), lh, aw, shirt, skin)
			Art._rounded(ci, Rect2(lh + Vector2(-u * 0.3, -u * 1.35), Vector2(u * 1.5, u * 1.9)), Color("8d6e63"))
			ci.draw_rect(Rect2(lh + Vector2(-u * 0.12, -u * 1.15), Vector2(u * 1.14, u * 1.5)), Color.WHITE)
			for k in 3:
				ci.draw_rect(Rect2(lh + Vector2(u * 0.05, -u * 0.9 + k * u * 0.38), Vector2(u * 0.75, u * 0.09)), Color("90a4ae"))
			var tap := absf(sin(t * 3.0)) * u * 0.45
			var rh := Vector2(bx + u * 0.65, y0 + u * 1.55 - tap)
			_arm(ci, rs, rs + Vector2(u * 0.35, u * 1.45), rh, aw, shirt, skin)
			ci.draw_line(rh, rh + Vector2(-u * 0.45, -u * 0.55), Color("1e88e5"), maxf(2.0, u * 0.16))


static func _arm(ci: CanvasItem, sh: Vector2, el: Vector2, hand: Vector2, w: float, sleeve: Color, skin: Color) -> void:
	var line := Color(0.1, 0.1, 0.12, 0.85)
	ci.draw_line(sh, el, line, w + 3.0)
	ci.draw_line(el, hand, line, w + 2.0)
	ci.draw_circle(hand, w * 0.55 + 1.5, line)
	ci.draw_line(sh, el, sleeve, w)
	ci.draw_circle(el, w * 0.5, sleeve)
	ci.draw_line(el, el.lerp(hand, 0.35), sleeve, w * 0.95)
	ci.draw_line(el.lerp(hand, 0.3), hand, skin, w * 0.8)
	ci.draw_circle(hand, w * 0.55, skin)
