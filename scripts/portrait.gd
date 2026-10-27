extends Control
## Manager portrait. Shows the manager working at `station_key` (or a fixed
## `manager` dict in lists), else "HIRE". Cash managers = the posh manager (ManagerRig, v0.19) from the
## head down to the chest, playing their idle loop (rim light in the ability's colour while it runs);
## Premium managers = code-drawn person with a rarity frame.
## Ability state (show_state): glowing + time left while running. Station rows turn it
## off: the ability icon above the portrait shows it there.
## Managers you don't own yet draw as a silhouette showing only the clues found.

signal pressed

const Art = preload("res://scripts/manager_art.gd")
const Faces = preload("res://scripts/car_view.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")
const Data = preload("res://scripts/game_data.gd")


var station_key := ""
var manager: Dictionary = {}
var show_state := true
var show_level := false
var mask := -1       # clue mask to draw (-1 = all if owned, else the clues found)

var _press_pos := Vector2.ZERO
var _pressing := false
var _bust = null             # ManagerAnim for a cash manager's bust (v0.19)
var _bust_id := ""
var _bust_rim := 0.0

const BUST_TOP := 6.0        # rig units shown at the top of the box (just above the hair)
const BUST_BOTTOM := 222.0   # ... and at the bottom (mid-chest)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS   # posh manager part textures


func _process(delta: float) -> void:
	if station_key.begins_with("bay") and GameState.bay_index(station_key) >= GameState.bays.size():
		return
	if station_key != "":
		manager = GameState.manager_at(station_key)
	if not manager.is_empty() and not GameState.is_premium(manager):
		var SM = load("res://scripts/station_manager.gd")
		var id := str(manager.get("id", "")) + "|" + str(manager.get("rarity", 0))
		if _bust == null or id != _bust_id:
			_bust = SM.make_anim(manager, 1.0)
			_bust_id = id
		var on := show_state and GameState.ability_active(manager)
		_bust.active = false          # lists stay in the idle loop (easier to read); the rim light shows the ability
		_bust.update(delta)
		_bust_rim = move_toward(_bust_rim, 1.0 if on else 0.0, delta / 0.55)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_press_pos = event.position
		elif _pressing:
			_pressing = false
			if event.position.distance_to(_press_pos) < 16.0:
				pressed.emit()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if manager.is_empty():
		UiTheme.rounded(self, r, Color(0, 0, 0, 0.35), 12, 3, Color(1, 1, 1, 0.35))
		var c := r.get_center()
		draw_line(c + Vector2(-12, -10), c + Vector2(12, -10), Color(1, 1, 1, 0.8), 5)
		draw_line(c + Vector2(0, -22), c + Vector2(0, 2), Color(1, 1, 1, 0.8), 5)
		UiTheme.text(self, Vector2(0, size.y - 10), "HIRE", 16, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER, size.x, 4)
		return

	var rarity := GameState.rarity_def(manager)
	var crew := GameState.crew_def(manager)
	var rc := Color(rarity["color"])
	var m_mask := mask if mask >= 0 else (63 if manager.get("owned", true) else int(manager.get("clues", 0)))
	var active := show_state and GameState.ability_active(manager)

	if active:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
		UiTheme.rounded(self, r.grow(4), Color(1.0, 0.9, 0.3, 0.5 + 0.4 * pulse), 16)
	UiTheme.rounded(self, r, rc.darkened(0.1) if GameState.is_premium(manager) else Color("dfe8f2"), 12, 4, rc)
	if GameState.is_premium(manager):
		# crew colour behind the person (unknown crew until you own them)
		var known := m_mask == 63
		UiTheme.rounded(self, r.grow(-6), Color(crew["color"]).darkened(0.25) if known else Color("cdd7ea"), 8)   # v0.17f: pale so the silhouette pops
		Art.draw_bust(self, r.grow(-7), manager, m_mask)
	else:
		# cash manager: the same posh manager who stands at the station, head to chest (v0.19)
		UiTheme.rounded(self, r.grow(-5), Color(crew["color"]).lightened(0.35), 9)
		_draw_bust(Color(crew["color"]))
	# rarity strip at the bottom
	draw_rect(Rect2(4, size.y - 8, size.x - 8, 4), rc)

	if show_level and manager.get("owned", false):
		UiTheme.rounded(self, Rect2(3, 3, 40, 20), Color(0, 0, 0, 0.7), 6)
		UiTheme.text(self, Vector2(3, 18), "Lv%d" % int(manager["level"]), 13, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 40, 0)
	if not show_state:
		return
	if active:
		var left := float(manager["active_until"]) - GameState.now
		UiTheme.rounded(self, Rect2(2, size.y - 24, size.x - 4, 22), Color(0.1, 0.5, 0.2, 0.9), 8)
		UiTheme.text(self, Vector2(0, size.y - 7), GameState.fmt_time(left), 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, size.x, 0)


func _draw_bust(crew_col: Color) -> void:
	var SM = load("res://scripts/station_manager.gd")
	if _bust == null:
		_bust = SM.make_anim(manager, 1.0)
		_bust_id = str(manager.get("id", "")) + "|" + str(manager.get("rarity", 0))
	var Rig = SM.Rig
	var Aura = SM.Aura
	var k := size.y / (BUST_BOTTOM - BUST_TOP)          # px per rig unit
	var feet := Vector2(size.x * 0.5 - 2.0 * k, (SM.MP.GROUND - BUST_TOP) * k)
	var kind := str(GameState.ability_def(manager)["kind"])
	Rig.draw(self, feet, k * Rig.FIG_UNITS, _bust.look, _bust.pose(), crew_col, _bust.mem,
		Aura.rim(SM.EFFECT, kind, _bust_rim, _bust.t))
