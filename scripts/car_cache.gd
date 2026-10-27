extends RefCounted
## v0.19v perf (Hamza: the game felt like 20-30 fps, scrolling worst): the cars in the bays were drawn shape by
## shape every frame (smoothed body polygons, glass glare cut with polygon clipping, wheels of circles, 26 mud
## blobs tested point-in-polygon...). Now each car is drawn ONCE into a texture, clean and fully dirty, and the
## bay shows the clean one with the dirty one faded over it (alpha = how dirty it still is: the same as the paint
## blending towards mud). The "comes up clean" sparkles are still drawn live (a few stars, only at the end).
## The pictures are little SubViewports that render once and keep their image (no GPU read-back); the oldest are
## freed past MAX_KEEP. Until a picture is ready (one frame) or with no real renderer (headless), the car is
## drawn the old way.

const CarArt = preload("res://scripts/car_art.gd")

const MAX_KEEP := 48
const PAD := 0.14   # room round the car rect for outlines / wheels / the light bar

static var _cache := {}       # key -> {vp, tex, at (frame requested), used (frame)}
static var _holder: Node = null


class Pic extends Control:
	const CarArt = preload("res://scripts/car_art.gd")
	var car: Dictionary
	var color: Color
	var dirt := 0.0
	var specks: Array = []
	var rect := Rect2()

	func _draw() -> void:
		CarArt.draw(self, rect, car, color, dirt, specks, 0.0, false)


static func _enabled() -> bool:
	return DisplayServer.get_name() != "headless"


## Draw a bay's car: clean picture + the dirty one faded over it + live sparkles. Same look as CarArt.draw.
static func draw(ci: CanvasItem, rect: Rect2, car: Dictionary, color: Color, dirt: float, specks: Array, shine: float, specks_id: int) -> void:
	if not _enabled() or not ci.is_inside_tree():
		CarArt.draw(ci, rect, car, color, dirt, specks, shine, false)
		return
	var sz := Vector2i(int(round(rect.size.x)), int(round(rect.size.y)))
	var base := "%s|%s|%dx%d" % [str(car.get("id", "")), color.to_html(false), sz.x, sz.y]
	var clean := _picture(ci, base + "|c", car, color, 0.0, [], sz)
	var dirty: Texture2D = null
	if dirt > 0.01:
		dirty = _picture(ci, base + "|d%d" % specks_id, car, color, 1.0, specks, sz)
	if clean == null or (dirt > 0.01 and dirty == null):
		CarArt.draw(ci, rect, car, color, dirt, specks, shine, false)
		return
	var pad := Vector2(sz) * PAD
	var r := Rect2(rect.position - pad, Vector2(sz) + pad * 2.0)
	ci.draw_texture_rect(clean, r, false)
	if dirty != null:
		ci.draw_texture_rect(dirty, r, false, Color(1, 1, 1, clampf(dirt, 0.0, 1.0)))
	if shine > 0.0:
		CarArt.draw_shine(ci, rect, car, shine)


static func _picture(ci: CanvasItem, key: String, car: Dictionary, color: Color, dirt: float, specks: Array, sz: Vector2i) -> Texture2D:
	var f := Engine.get_frames_drawn()
	var e: Dictionary = _cache.get(key, {})
	if e.is_empty():
		e = _bake(ci, car, color, dirt, specks, sz)
		_cache[key] = e
		_trim()
	e["used"] = f
	if f <= int(e["at"]) + 1:
		return null   # rendering on the next frame
	var vp: SubViewport = e["vp"]
	if vp.render_target_update_mode != SubViewport.UPDATE_DISABLED:
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED   # keep the picture, never render it again
	return e["tex"]


static func _bake(ci: CanvasItem, car: Dictionary, color: Color, dirt: float, specks: Array, sz: Vector2i) -> Dictionary:
	if _holder == null or not is_instance_valid(_holder):
		_holder = Node.new()
		_holder.name = "CarCache"
		ci.get_tree().root.add_child.call_deferred(_holder)
	var pad := Vector2(sz) * PAD
	var vp := SubViewport.new()
	vp.size = Vector2i((Vector2(sz) + pad * 2.0).ceil())
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var p := Pic.new()
	p.car = car
	p.color = color
	p.dirt = dirt
	p.specks = specks
	p.rect = Rect2(pad, Vector2(sz))
	p.size = Vector2(vp.size)
	vp.add_child(p)
	_holder.add_child.call_deferred(vp)   # (never add nodes while drawing)
	return {"vp": vp, "tex": vp.get_texture(), "at": Engine.get_frames_drawn() + 1, "used": Engine.get_frames_drawn()}


static func _trim() -> void:
	if _cache.size() <= MAX_KEEP:
		return
	var keys := _cache.keys()
	keys.sort_custom(func(a, b): return int(_cache[a]["used"]) < int(_cache[b]["used"]))
	for k in keys.slice(0, _cache.size() - MAX_KEEP):
		var vp: SubViewport = _cache[k]["vp"]
		if is_instance_valid(vp):
			vp.queue_free()
		_cache.erase(k)


## v0.19w: pictures asked for but not rendered yet (the loading bar waits for these to reach 0).
static func pending() -> int:
	var f := Engine.get_frames_drawn()
	var n := 0
	for e in _cache.values():
		if f <= int(e["at"]) + 1:
			n += 1
	return n


## Forget every picture (e.g. after a city switch nothing needs them). Not required: they age out.
static func clear() -> void:
	for k in _cache.keys():
		var vp: SubViewport = _cache[k]["vp"]
		if is_instance_valid(vp):
			vp.queue_free()
	_cache.clear()
