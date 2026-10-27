extends Node
## v0.19v: bakes scripts/game_icons.gd drawings to assets/game/ui/icon_*.png (2x size, transparent).
## Copy to <project>/tests/, autoload it AS AutoTest (like the autotest: the game's autoloads must exist)
## and run with a display:  xvfb-run -a godot --path <project>
## Open the editor afterwards so Godot imports the PNGs (mipmaps on in their .import for smooth scaling).

const GameIcons = preload("res://scripts/game_icons.gd")
const ICONS := {"sb": Vector2i(128, 96), "wheel": Vector2i(128, 128), "wheel_face": Vector2i(256, 256),
	"booster": Vector2i(96, 96), "wardrobe": Vector2i(96, 96), "ad": Vector2i(96, 96)}


class Pic extends Control:
	var icon := ""
	func _draw() -> void:
		var s := minf(size.x, size.y)
		if icon == "sb":
			s = size.y * 1.15
		GameIcons.draw(self, icon, size * 0.5, s * 0.92)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	for n in ICONS.keys():
		var vp := SubViewport.new()
		vp.size = ICONS[n]
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var p := Pic.new()
		p.icon = n
		p.size = Vector2(ICONS[n])
		vp.add_child(p)
		get_tree().root.add_child(vp)
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		var used := img.get_used_rect().grow(2).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		img = img.get_region(used)   # tight crop, so the icon sits snugly next to text
		var out := "res://assets/game/ui/icon_%s.png" % n
		img.save_png(ProjectSettings.globalize_path(out))
		print("baked ", out, " ", img.get_size())
		vp.queue_free()
	get_tree().quit()
