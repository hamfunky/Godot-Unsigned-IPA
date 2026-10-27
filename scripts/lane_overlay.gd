extends Control
## Draws the valet car driving up and down the lane on top of the rows.
## rows[0] is the valet row (floor 0); rows[k] is bay k-1 (floor k).

const Art = preload("res://scripts/car_view.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")
const Data = preload("res://scripts/game_data.gd")

const LANE_X := 46.0

var rows: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _floor_y(f: int) -> float:
	f = clampi(f, 0, rows.size() - 1)
	var r: Control = rows[f]
	# v0.19c: stop in the middle of the room under the slab band
	return r.position.y + 44.0 + (r.size.y - 44.0) * 0.5


func _draw() -> void:
	if rows.is_empty():
		return
	var v := GameState.valet
	var pos: float = v["pos"]
	var f := int(floor(pos))
	var y := lerpf(_floor_y(f), _floor_y(f + 1), pos - f) if f + 1 < rows.size() else _floor_y(f)
	var carried: float = v["carried"]
	# v0.19p: loading is a visible step. While the ute waits at a bay, cash bundles hop from that bay's key
	# cabinet into the tray one after another, and the tray fills up as they land (not all at the end).
	var load_k := -1.0
	if v["phase"] == "load" and int(v["stop"]) >= 1 and int(v["stop"]) < rows.size():
		var total_t: float = Data.VALET_LOAD_TIME / maxf(GameState.valet_load_speed(), 0.0001)
		load_k = clampf(1.0 - float(v["timer"]) / maxf(total_t, 0.0001), 0.0, 1.0)
		var bay: Dictionary = GameState.bays[int(v["stop"]) - 1]
		var take: float = minf(float(bay["ready"]), GameState.valet_capacity() - carried)
		carried += take * load_k
		_draw_loading(int(v["stop"]), y, load_k, take > 0.0)
	var fill := carried / maxf(GameState.valet_capacity(), 0.0001)
	var down: bool = v["phase"] in ["idle", "down", "load"]
	if not GameState.convoy().is_empty():
		# v0.19q Marco's Convoy: two more utes follow the main one, just as loaded
		var lo := _floor_y(0) - 20.0
		var hi := _floor_y(rows.size() - 1) + 20.0
		var dir := -1.0 if down else 1.0   # they trail behind the way it's driving ...
		if y + dir * 200.0 < lo or y + dir * 200.0 > hi:
			dir = -dir                      # ... or queue on the other side when there's no room (parked at the top)
		for k in [2, 1]:
			Art.draw_ute_sprite(self, Vector2(LANE_X, y + dir * 100.0 * k), 50.0, fill, down)
	Art.draw_ute_sprite(self, Vector2(LANE_X, y), 50.0, fill, down)
	if carried > 0.0:
		# v0.17f: green cash bubble with a little tail pointing at the ute
		var bub := Rect2(2, y - 84, 88, 26)
		draw_colored_polygon(PackedVector2Array([Vector2(LANE_X - 7, bub.end.y - 2), Vector2(LANE_X + 7, bub.end.y - 2), Vector2(LANE_X, bub.end.y + 7)]), UiTheme.INK)
		UiTheme.rounded(self, bub, Color("2fb457"), 13, 3, UiTheme.INK)
		draw_colored_polygon(PackedVector2Array([Vector2(LANE_X - 4, bub.end.y - 3), Vector2(LANE_X + 4, bub.end.y - 3), Vector2(LANE_X, bub.end.y + 3)]), Color("2fb457"))
		UiTheme.text(self, Vector2(2, y - 65), GameState.money(carried), 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 88, 4, UiTheme.DISPLAY_FONT)


## v0.19p: three cash bundles arc from the bay's key cabinet into the ute's tray, one after another.
func _draw_loading(f: int, ute_y: float, k: float, has_cash: bool) -> void:
	if not has_cash:
		return
	var r: Control = rows[f]
	var from := Vector2(136.0, r.position.y + 44.0 + 40.0)   # the key cabinet (BayCard: LANE_W + 8 .. + 72)
	var to := Vector2(LANE_X, ute_y - 6.0)
	for n in 3:
		var t := clampf((k - n * 0.22) / 0.5, 0.0, 1.0)
		if t <= 0.0 or t >= 1.0:
			continue
		var p := from.lerp(to, t) + Vector2(0, -sin(t * PI) * 46.0)
		draw_set_transform(p, sin(t * PI * 2.0) * 0.5, Vector2.ONE)
		UiTheme.rounded(self, Rect2(-12, -7, 24, 14), Color("6fd36a"), 3, 2, UiTheme.INK)
		draw_rect(Rect2(-3, -7, 6, 14), Color("2e7d32"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
