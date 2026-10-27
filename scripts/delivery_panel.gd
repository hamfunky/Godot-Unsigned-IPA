extends "res://scripts/sheet.gd"
## v0.19t DAILY DELIVERY: tap the parcel in the pickup lot. A 7-day track of rewards (GameState.DELIVERY_REWARDS)
## that loops and never resets: miss a day and the next parcel just carries on. OPEN gives today's reward.

const Data = preload("res://scripts/game_data.gd")
const HudMeta = preload("res://scripts/hud_meta.gd")

var _tiles: Array = []      # DayTile per slot
var _open_btn: Button
var _status: Label
var _result: RichTextLabel   # v0.19v: rich (Shine Bucks icon)
var _tick := 0.0


class DayTile extends Control:
	const UiTheme = preload("res://scripts/ui_theme.gd")
	const HudMeta = preload("res://scripts/hud_meta.gd")
	const Data = preload("res://scripts/game_data.gd")
	var slot := 0
	var state := "later"     # "done" | "today" | "later"
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if state == "today":
			queue_redraw()

	func _draw() -> void:
		var ink := UiTheme.INK
		var r := Rect2(Vector2(3, 3), size - Vector2(6, 10))
		var big := slot == Data.DELIVERY_REWARDS.size() - 1
		var col := Color("ffcf4a") if state == "today" else (Color("6fd36a") if state == "done" else (Color("b07cff") if big else Color("5b8def")))
		UiTheme.rounded(self, Rect2(r.position + Vector2(0, 6), r.size), col.darkened(0.45), 12, 3, ink)
		UiTheme.rounded(self, r, col, 12, 3, ink)
		if state == "today":
			var pulse := 0.5 + 0.5 * sin(_t * 4.0)
			UiTheme.rounded(self, r.grow(3), Color(1, 1, 1, 0.0), 14, 3, Color(1, 1, 1, 0.5 + 0.5 * pulse))
		UiTheme.text(self, Vector2(r.position.x, r.position.y + 24), "DAY %d" % (slot + 1), 18, ink if state == "today" else Color.WHITE,
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 0 if state == "today" else 4, UiTheme.DISPLAY_FONT)
		_parcel(Vector2(r.position.x + r.size.x * 0.5, r.position.y + 62), 1.15 if big else 0.9, state == "done")
		var lines := GameState.delivery_reward_text(slot).split(" + ")
		for k in lines.size():
			var ln: String = ("+ " if k > 0 else "") + lines[k]
			var y := r.end.y - 38 + (k - (lines.size() - 1) * 0.5) * 18.0
			var tc := ink if state == "today" else Color.WHITE
			if ln.contains("{sb}"):   # v0.19v: "15 [banknote]"
				var num := ln.replace("{sb}", "").strip_edges()
				var tw := UiTheme.BODY_FONT.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
				var x0 := r.position.x + r.size.x * 0.5 - (tw + 26.0) * 0.5
				UiTheme.text(self, Vector2(x0, y), num, 15, tc, HORIZONTAL_ALIGNMENT_LEFT, -1, 0 if state == "today" else 4)
				HudMeta.draw_droplet(self, Vector2(x0 + tw + 15.0, y - 5.0), 7.0)
				continue
			UiTheme.text(self, Vector2(r.position.x + 4, y), ln, 15, tc, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 8, 0 if state == "today" else 4)

	func _parcel(c: Vector2, k: float, open: bool) -> void:
		var ink := UiTheme.INK
		var w := 44.0 * k
		var h := 30.0 * k
		UiTheme.rounded(self, Rect2(c.x - w * 0.5, c.y - h * 0.5, w, h), Color("c98b4f"), 4, 2, ink)
		draw_rect(Rect2(c.x - 4 * k, c.y - h * 0.5 + 2, 8 * k, h - 4), Color("e8553d"))
		if open:
			var tick := PackedVector2Array([c + Vector2(-10, 0) * k, c + Vector2(-3, 8) * k, c + Vector2(12, -9) * k])
			draw_polyline(tick, ink, 9.0 * k, true)
			draw_polyline(tick, Color.WHITE, 4.5 * k, true)
		else:
			draw_circle(c + Vector2(-7 * k, -h * 0.5 - 2), 6 * k, Color("e8553d"))
			draw_circle(c + Vector2(7 * k, -h * 0.5 - 2), 6 * k, Color("e8553d"))
			draw_circle(c + Vector2(0, -h * 0.5), 3.5 * k, Color("ff8a65"))


func setup() -> void:
	set_title("Daily Delivery")
	var intro := UiTheme.label("A parcel turns up at your pickup lot every day. Open one a day to move along the week; miss a day and you just carry on where you were.", 19, UiTheme.MUTED)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(intro)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	for k in Data.DELIVERY_REWARDS.size():
		var t := DayTile.new()
		t.slot = k
		t.custom_minimum_size = Vector2(150, 156)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(t)
		_tiles.append(t)
	_result = UiTheme.rich_label("", 26, UiTheme.CASH, 0, true)
	_result.visible = false
	body.add_child(_result)
	_open_btn = UiTheme.button("OPEN", 26, UiTheme.GOOD)
	_open_btn.custom_minimum_size = Vector2(0, 84)
	_open_btn.pressed.connect(_on_open)
	body.add_child(_open_btn)
	_status = UiTheme.label("", 19, UiTheme.MUTED)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_status)
	_refresh()


func _process(delta: float) -> void:
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		_refresh()


func _refresh() -> void:
	if _open_btn == null:
		return
	var ready := GameState.delivery_ready()
	var cur := GameState.delivery_slot()
	var week_done := GameState.delivery_count % Data.DELIVERY_REWARDS.size()   # opened this week so far
	for t in _tiles:
		if ready and t.slot == cur:
			t.state = "today"
		elif t.slot < week_done or (not ready and week_done == 0 and GameState.delivery_count > 0):
			t.state = "done"
		else:
			t.state = "later"
		t.queue_redraw()
	_open_btn.disabled = not ready
	_open_btn.text = "OPEN TODAY'S PARCEL" if ready else "OPENED"
	_status.text = "" if ready else "Next parcel in %s" % GameState.fmt_time(GameState.delivery_in())


func _on_open() -> void:
	var res := GameState.open_delivery()
	if res.is_empty():
		Sfx.play("error")
		return
	Sfx.play("hire")
	Sfx.buzz(20)
	UiTheme.set_bb(_result, "Day %d: %s!" % [int(res["slot"]) + 1, res["text"]])
	_result.visible = true
	_refresh()
