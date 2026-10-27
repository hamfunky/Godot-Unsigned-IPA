extends Node
## v0.19v: bakes scripts/kit_art.gd (the bays' service kit, one per service tier) to
## assets/game/sprites/kit/kit_<tier>.png (art size = 4x the bay, transparent; mipmaps on in the .import),
## and writes a review sheet (big + bay size) to $SHEET if set.
## Copy to <project>/tests/, autoload it AS AutoTest, run with a display:
##   SHEET=/dir/kit_sheet.png xvfb-run -a godot --path <project>

const KitArt = preload("res://scripts/kit_art.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")
const Scenery = preload("res://scripts/scenery.gd")


class Pic extends Control:
	var tier := 0
	func _draw() -> void:
		KitArt.draw(self, tier, Vector2(4, 4), 1.0)


class Sheet extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("26324f"))
		var cols := 3
		var cw := 330.0
		var ch := 250.0
		for t in KitArt.WIDTHS.size():
			var o := Vector2(20 + (t % cols) * cw, 20 + (t / cols) * ch)
			UiTheme.rounded(self, Rect2(o, Vector2(cw - 20, ch - 20)), Color("d9e6f2"), 14, 3, UiTheme.INK)
			UiTheme.text(self, o + Vector2(14, 30), "%d  %s" % [t, KitArt.NAMES[t]], 20, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 5, UiTheme.DISPLAY_FONT)
			KitArt.draw(self, t, o + Vector2(14, 44), 1.0)
			# in the bay: on a bit of tiled wall + shelf, at the bay's size (and x2 to see it)
			var wo := o + Vector2(cw - 20 - 92, ch - 20 - 60)
			UiTheme.rounded(self, Rect2(wo + Vector2(-8, -6), Vector2(96, 58)), Color("bfe3f7"), 6, 2, UiTheme.INK)
			UiTheme.rounded(self, Rect2(wo + Vector2(-6, KitArt.ART_H * KitArt.GAME_SCALE + 2), Vector2(92, 6)), Color("a06a46"), 3, 2, UiTheme.INK)
			KitArt.draw(self, t, wo + Vector2(0, 2), KitArt.GAME_SCALE)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/game/sprites/kit"))
	for t in KitArt.WIDTHS.size():
		var vp := SubViewport.new()
		vp.size = Vector2i(int(KitArt.WIDTHS[t]) + 8, int(KitArt.ART_H) + 8)
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var p := Pic.new()
		p.tier = t
		p.size = Vector2(vp.size)
		vp.add_child(p)
		get_tree().root.add_child(vp)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://assets/game/sprites/kit/kit_%d.png" % t))
		print("baked kit_%d %s" % [t, img.get_size()])
		vp.queue_free()
	var out := OS.get_environment("SHEET")
	if out != "":
		var vp := SubViewport.new()
		vp.size = Vector2i(1010, 20 + 4 * 250)
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var s := Sheet.new()
		s.size = Vector2(vp.size)
		vp.add_child(s)
		get_tree().root.add_child(vp)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(out)
		print("sheet ", out)
	get_tree().quit()
