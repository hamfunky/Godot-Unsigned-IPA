extends RefCounted
## Paint Correction look on a car (v0.18): after the hand wash the paint is clean but dull, a pale haze
## with swirl marks over the body. The polish clears it from the detailers' end(s) of the car towards the
## middle; a bright streak rides the edge of the cleared part, and polished paint gets mirror reflections.
## Static drawing only (state = the numbers passed in); purely visual.

const CarArt = preload("res://scripts/car_art.gd")

## haze 0..1 = how dull the paint is (fades in as the hand wash finishes); front 0..1 = how far the polish has
## got; ends 1 = one detailer from the left end, 2 = one from each end. car = the car's dictionary.
static func draw(ci: CanvasItem, rect: Rect2, car: Dictionary, haze: float, front: float, ends: int, t: float) -> void:
	if haze <= 0.01:
		return
	var body := CarArt.body_outline(rect, car)
	if body.size() < 3:
		return
	var w := rect.size.x
	# the part still to polish (rect pieces, intersected with the body)
	var dull: Array = []
	if ends == 1:
		dull.append(_band(rect, front, 1.0))
	else:
		dull.append(_band(rect, front * 0.5, 1.0 - front * 0.5))
	var polished: Array = []
	if ends == 1:
		polished.append(_band(rect, 0.0, front))
	else:
		polished.append(_band(rect, 0.0, front * 0.5))
		polished.append(_band(rect, 1.0 - front * 0.5, 1.0))
	# 1) haze + swirl marks on what's still dull
	for r in dull:
		for poly in Geometry2D.intersect_polygons(body, r):
			_fill(ci, poly, Color(0.93, 0.92, 0.90, 0.34 * haze))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in 26:
		var p := rect.position + Vector2(rng.randf(), rng.randf_range(0.25, 0.85)) * rect.size
		var rel := (p.x - rect.position.x) / w
		var still := rel > front if ends == 1 else (minf(rel, 1.0 - rel) * 2.0 > front)
		if not still or not Geometry2D.is_point_in_polygon(p, body):
			continue
		var rr := w * rng.randf_range(0.025, 0.05)
		var a0 := rng.randf() * TAU
		ci.draw_arc(p, rr, a0, a0 + PI * 1.3, 10, Color(1, 1, 1, 0.45 * haze), maxf(1.0, w * 0.005), true)
	# 2) mirror reflections on the polished paint
	for r in polished:
		var ref := PackedVector2Array()
		for k in 2:
			var x0 := rect.position.x + w * (0.18 + 0.42 * k)
			ref = PackedVector2Array([Vector2(x0, rect.position.y), Vector2(x0 + w * 0.07, rect.position.y),
				Vector2(x0 - w * 0.05, rect.end.y), Vector2(x0 - w * 0.12, rect.end.y)])
			for a in Geometry2D.intersect_polygons(body, ref):
				for b in Geometry2D.intersect_polygons(a, r):
					_fill(ci, b, Color(1, 1, 1, 0.22 * haze))
	# 3) the bright streak riding the edge of the polish
	if front > 0.0 and front < 1.0:
		var edges: Array = [front] if ends == 1 else [front * 0.5, 1.0 - front * 0.5]
		for e in edges:
			var x := rect.position.x + w * float(e)
			var pulse := 0.75 + 0.25 * sin(t * 9.0)
			for layer in [[0.05, 0.30], [0.018, 0.75]]:
				var hw := w * float(layer[0])
				var streak := PackedVector2Array([Vector2(x - hw + w * 0.03, rect.position.y), Vector2(x + hw + w * 0.03, rect.position.y),
					Vector2(x + hw - w * 0.03, rect.end.y), Vector2(x - hw - w * 0.03, rect.end.y)])
				for poly in Geometry2D.intersect_polygons(body, streak):
					_fill(ci, poly, Color(1, 1, 1, float(layer[1]) * pulse * haze))


static func _band(rect: Rect2, a: float, b: float) -> PackedVector2Array:
	var x0 := rect.position.x + rect.size.x * a
	var x1 := rect.position.x + rect.size.x * b
	return PackedVector2Array([Vector2(x0, rect.position.y - 4), Vector2(x1, rect.position.y - 4),
		Vector2(x1, rect.end.y + 4), Vector2(x0, rect.end.y + 4)])


static func _fill(ci: CanvasItem, poly: PackedVector2Array, col: Color) -> void:
	if poly.size() >= 3 and Geometry2D.triangulate_polygon(poly).size() > 0:
		ci.draw_colored_polygon(poly, col)
