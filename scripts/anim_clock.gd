extends RefCounted
## v0.19w perf (Hamza: 40-70 fps on a 240 Hz PC; the profiler showed the characters' drawing on top): the
## characters and the strips they live in (bays, managers, the cashier, the valet forecourt) move and redraw
## HZ times a second instead of every frame. Scrolling, the valet's ute, panels and tweens stay at the full
## frame rate. Each clock starts at a random phase so the strips don't all redraw in the same frame.
## tick(delta) returns the time since the last update (0 = not yet).

const HZ := 30.0

var _acc := 0.0


func _init() -> void:
	_acc = randf() / HZ


func tick(delta: float) -> float:
	_acc += delta
	if _acc < 1.0 / HZ:
		return 0.0
	var d := minf(_acc, 0.25)   # (after a long hitch, don't jump a quarter second ahead)
	_acc = 0.0
	return d
