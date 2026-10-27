extends SceneTree
## Renders every car (regular + rare) into one PNG for reviewing the art.
##   godot --path <project> --script res://tools/car_sheet.gd -- <out.png> [dirt]

const CarArt = preload("res://scripts/car_art.gd")
const Data = preload("res://scripts/game_data.gd")

var _out := "user://cars.png"
var _dirt := 0.0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_dirt = float(args[1])
	var cv := Control.new()
	cv.size = Vector2(1400, 1500)
	root.add_child(cv)
	var cars: Array = []
	for c in Data.CARS:
		cars.append(c)
	for c in Data.VIP_CARS:
		cars.append(c)
	var cols := ["e53935", "1e88e5", "43a047", "fdd835", "8e24aa", "fb8c00", "eceff1", "263238", "00acc1"]
	var specks := []
	for k in 26:
		specks.append(Vector3(randf(), randf(), randf_range(0.5, 1.0)))
	cv.draw.connect(func():
		cv.draw_rect(Rect2(0, 0, 1400, 1500), Color("3b4a5e"))
		for i in cars.size():
			var c: Dictionary = cars[i]
			var x := 10 + (i % 7) * 198
			var y := 10 + (i / 7) * 136
			cv.draw_rect(Rect2(x, y, 190, 128), Color("4f6178") if not c.has("country") else Color("6b5a2e"))
			var col := Color(c["color"]) if c.has("color") else Color(cols[i % cols.size()])
			CarArt.draw(cv, Rect2(x + 12, y + 18, 166, 80), c, col, _dirt, specks, 0.0, false)
			cv.draw_string(ThemeDB.fallback_font, Vector2(x + 6, y + 120), "%s (%s)" % [c["name"], CarArt.style_of(c)], HORIZONTAL_ALIGNMENT_LEFT, 180, 11, Color.WHITE))
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out)
	quit()
