extends Node
## v0.19w dev: the skyline MOCKUP sheet for Hamza (scripts/skyline_art.gd): the sky strip as it is now vs the
## detailed one, then every country (+ the Hometown) by day, at dusk and at night.
## Copy to <project>/tests/, autoload it AS AutoTest, run with a display:  OUT=/dir xvfb-run -a godot --path <project>

const SkylineArt = preload("res://scripts/skyline_art.gd")
const Scenery = preload("res://scripts/scenery.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")
const GameIcons = preload("res://scripts/game_icons.gd")

const W := 720.0
const H := 128.0
const LABEL := 34.0


class Strip extends Control:
	const SkylineArt = preload("res://scripts/skyline_art.gd")
	const Scenery = preload("res://scripts/scenery.gd")
	const GameIcons = preload("res://scripts/game_icons.gd")
	var rows := []   # [label, country, hour, new?]

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("26324f"))
		for i in rows.size():
			var o := Vector2(0, i * (H + LABEL))
			UiTheme_text(self, o + Vector2(14, 25), rows[i][0])
			_strip(Rect2(o + Vector2(0, LABEL), Vector2(W, H)), rows[i][1], rows[i][2], rows[i][3])

	static func UiTheme_text(ci: CanvasItem, p: Vector2, t: String) -> void:
		ci.draw_string(load("res://assets/game/fonts/fredoka_700.ttf"), p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)

	func _strip(r: Rect2, country: String, hour: float, new: bool) -> void:
		var sky := Scenery.sky_colors(hour, false)
		var nt := Scenery.night_amount(hour)
		var top: Color = (sky[0] as Color).darkened(0.18).lerp(Color("0d1233"), 0.35 * nt)
		Scenery.vgrad(self, r, top, sky[0])
		Scenery.night_sky(self, Rect2(r.position, Vector2(r.size.x, r.size.y - 30)), nt)
		if nt < 0.95:
			Scenery.cloud(self, r.position + Vector2(W * 0.42, 34), 18, 0.8 * (1.0 - nt * 0.8))
			Scenery.cloud(self, r.position + Vector2(W * 0.78, 62), 14, 0.7 * (1.0 - nt * 0.8))
			if nt < 0.5:
				draw_circle(r.position + Vector2(W - 70, 40), 30, Color(1, 0.95, 0.6, 0.25 * (1.0 - nt * 2.0)))
				draw_circle(r.position + Vector2(W - 70, 40), 20, Color(1, 0.93, 0.55, 1.0 - nt * 2.0))
		if new:
			SkylineArt.draw(self, Rect2(r.position + Vector2(160, 0), Vector2(W - 160, H)), country, nt, [sky[0], sky[0]], false)
		else:
			_old(r, sky, nt)
		# the wheel on its post, as in the game
		var wc := r.position + Vector2(84, 52)
		Scenery.rr(self, Rect2(wc.x - 6, wc.y, 12, r.end.y - wc.y), Color("9aa6b8"), 3, 2)
		Scenery.rr(self, Rect2(wc.x - 34, r.end.y - 10, 68, 12), Color("7a8699"), 4, 2)
		GameIcons.wheel(self, wc, 42.0, 0.3, true)
		# the top of the shop's sign below, for context
		draw_rect(Rect2(r.position.x, r.end.y - 2, W, 2), Color(0, 0, 0, 0.3))

	func _old(r: Rect2, sky: Array, nt: float) -> void:
		var sk: Color = (sky[0] as Color).lerp(Color("2a3355"), 0.45).lerp(Color("0f1430"), 0.4 * nt)
		var x := 170.0
		var k := 0
		while x < W + 40.0:
			var bw := 38.0 + fmod(k * 23.0, 34.0)
			var bh := 22.0 + fmod(k * 37.0, 46.0)
			draw_rect(Rect2(r.position.x + x, r.end.y - bh, bw, bh), sk)
			if k % 3 == 1:
				draw_rect(Rect2(r.position.x + x + bw * 0.45, r.end.y - bh - 10, 3, 10), sk)
			if nt > 0.1:
				for wy in range(int(H - bh + 6), int(H - 4), 9):
					for wx in range(int(x + 6), int(x + bw - 6), 9):
						if (wx * 7 + wy * 3 + k) % 5 < 2:
							draw_rect(Rect2(r.position.x + wx, r.position.y + wy, 3, 4), Color(1, 0.86, 0.5, 0.75 * nt))
			x += bw + 4.0
			k += 1


func _ready() -> void:
	_run.call_deferred()


func _sheet(rows: Array, out: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(int(W), int(rows.size() * (H + LABEL)))
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var s := Strip.new()
	s.rows = rows
	s.size = Vector2(vp.size)
	vp.add_child(s)
	get_tree().root.add_child(vp)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out)
	print("sheet ", out)
	vp.queue_free()


func _run() -> void:
	var out := OS.get_environment("OUT")
	await _sheet([["NOW (USA, day)", "usa", 13.0, false], ["NEW (USA, day)", "usa", 13.0, true],
		["NOW (USA, night)", "usa", 23.0, false], ["NEW (USA, night)", "usa", 23.0, true]], out + "/skyline_before_after.png")
	var rows := []
	for c in [["USA", "usa"], ["JAPAN", "japan"], ["GERMANY", "germany"], ["AUSTRALIA", "australia"], ["UAE", "uae"], ["HOMETOWN", "hometown"]]:
		rows.append([c[0] + "  day", c[1], 12.0, true])
		rows.append([c[0] + "  dusk", c[1], 19.5, true])
		rows.append([c[0] + "  night", c[1], 23.0, true])
	await _sheet(rows.slice(0, 9), out + "/skyline_countries_1.png")
	await _sheet(rows.slice(9), out + "/skyline_countries_2.png")
	get_tree().quit()
