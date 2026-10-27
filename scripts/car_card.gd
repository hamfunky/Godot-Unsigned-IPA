extends Control
## A car tile in the Book. Undiscovered cars show as a dark silhouette.
## Tap = put on display / take off display.

signal pressed(car_id: String)

const Art = preload("res://scripts/car_view.gd")
const Data = preload("res://scripts/game_data.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")

var car_id := ""
var is_new := false   # v0.17g: red NEW sticker (cars you hadn't looked at when this page opened)
var _press_pos := Vector2.ZERO
var _pressing := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(0, 132)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _process(_delta: float) -> void:
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_press_pos = event.position
		elif _pressing:
			_pressing = false
			if event.position.distance_to(_press_pos) < 16.0:
				pressed.emit(car_id)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var inner := Rect2(0, 0, size.x, size.y - 6)
	if car_id == "":
		UiTheme.rounded(self, r, Color(1, 1, 1, 0.12), 14, 3, Color(1, 1, 1, 0.45))
		UiTheme.text(self, Vector2(0, size.y * 0.5 + 8), "Empty slot", 18, Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_CENTER, size.x, 4)
		return
	var car := GameState.car_def(car_id)
	var have := GameState.book.has(car_id)
	var shown := GameState.display.has(car_id)
	var is_vip: bool = car.get("vip", false)
	# v0.17f: pale collectible card with a chunky lip; rare cars get a rarity rim, cars on show a gold one
	var tile := Color("eef4ff") if have else Color("aeb9d1")
	var rim := UiTheme.INK
	var bw := 3
	if is_vip:
		rim = Color(Data.VIP_RARITIES[int(car["rarity"])]["color"])
		bw = 5
	if shown:
		rim = Color("f5b400")
		bw = 5
	UiTheme.rounded(self, r, tile.darkened(0.4), 14, 3, UiTheme.INK)
	UiTheme.rounded(self, inner, tile, 14, bw, rim)
	if bw > 3:
		UiTheme.rounded(self, inner.grow(-bw + 1), Color(0, 0, 0, 0), 12, 2, Color(0, 0, 0, 0.18))
	var cw := minf(size.x - 30, 150.0)
	var cr := Rect2((size.x - cw) * 0.5, 14, cw, cw * 0.42)
	if have:
		Art.draw_car(self, cr, Art.book_color(car), 0.0, [], 0.0, false, car)
		UiTheme.text(self, Vector2(6, 92), car["name"], 16, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER, size.x - 12, 0)
		var sub: String = Data.CLASS_NAMES[car["class"]]
		if is_vip:
			sub += "  ·  " + Data.VIP_RARITIES[int(car["rarity"])]["name"]
		UiTheme.text(self, Vector2(0, 113), sub, 15, GameState.class_color(car["class"]).darkened(0.2), HORIZONTAL_ALIGNMENT_CENTER, size.x, 0)
		if shown:
			UiTheme.rounded(self, Rect2(6, 6, 78, 22), UiTheme.CASH, 8, 2, UiTheme.INK)
			UiTheme.text(self, Vector2(6, 22), "ON SHOW", 12, UiTheme.INK, HORIZONTAL_ALIGNMENT_CENTER, 78, 0)
		# v0.19j (playtest: "why does it matter what cars?"): a car of a type your bay crew managers specialise
		# in gets a CREW tag in the crew's colour (they earn x1.5 on these cars)
		var crew_n: int = GameState.crew_bays(car["class"]).size()
		if crew_n > 0:
			var bonus: float = GameState.specialist_bonus(car["class"])
			var t := "CREW x%s" % (str(int(bonus)) if is_equal_approx(bonus, roundf(bonus)) else "%.1f" % bonus)
			var tr := Rect2(size.x - 92, 32 if is_new or (shown and size.x < 184.0) else 6, 86, 22)   # (narrow card: under ON SHOW)
			UiTheme.rounded(self, tr, GameState.class_color(car["class"]), 8, 2, UiTheme.INK)
			UiTheme.text(self, Vector2(tr.position.x, tr.position.y + 16), t, 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, tr.size.x, 3, UiTheme.DISPLAY_FONT)
		if is_new:
			var wob := sin(Time.get_ticks_msec() * 0.006) * 2.0
			var nr := Rect2(size.x - 62, 4 + wob, 56, 24)
			UiTheme.rounded(self, nr, Color("ff5a5f"), 10, 2, UiTheme.INK)
			UiTheme.text(self, Vector2(nr.position.x, nr.position.y + 18), "NEW", 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, nr.size.x, 3, UiTheme.DISPLAY_FONT)
	else:
		Art.draw_car(self, cr, Color("6f7c98"), 0.0, [], 0.0, true, car)
		UiTheme.text(self, Vector2(0, 100), "???", 20, Color(0.1, 0.12, 0.2, 0.45), HORIZONTAL_ALIGNMENT_CENTER, size.x, 0)
