extends Node
## v0.19v perf probe (dev only). v0.19w: SCENE ms = scripts + layout + drawing per frame (first _process ->
## RenderingServer.frame_pre_draw), the honest number; "process" (TIME_PROCESS) also counts GPU / V-Sync waits. Autoload it AS AutoTest (like the autotest) and run with xvfb:
##   PERF_OUT=/dir xvfb-run -a -s "-screen 0 720x1280x24" godot --path p --resolution 720x1280
## Builds a mid-game shop (10 bays, mixed tiers, managers), then measures the average CPU time per frame
## (script _process + _draw recording; Performance.TIME_PROCESS) and the wall time per frame for:
##   top       the shop at rest (top of the scroll)
##   scroll    scrolling up and down all the time
##   map       the world map open, at rest
##   map_pan   dragging the map all the time
## and, for "top" and "scroll", what each group of nodes costs (that group's _process switched off).

const Data = preload("res://scripts/game_data.gd")
var FRAMES := int(OS.get_environment("PERF_FRAMES")) if OS.get_environment("PERF_FRAMES") != "" else 150

var _wall: Array = []


var _t0 := 0
var _scene_us := 0.0
var _scene_n := 0
var _scene_on := false


func _ready() -> void:
	process_priority = -100000
	RenderingServer.frame_pre_draw.connect(func():
		if _scene_on and _t0 > 0:
			_scene_us += Time.get_ticks_usec() - _t0
			_scene_n += 1)
	_run.call_deferred()


func _process(_d: float) -> void:
	_t0 = Time.get_ticks_usec()


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func m() -> Node:
	return get_tree().current_scene


func _measure(label: String, per_frame: Callable = Callable()) -> Dictionary:
	var calls := 0.0
	var proc := 0.0
	var walls := 0.0
	var prims := 0.0
	var rcpu := 0.0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var t_prev := Time.get_ticks_usec()
	for f in FRAMES:
		if per_frame.is_valid():
			per_frame.call(f)
		await get_tree().process_frame
		var t := Time.get_ticks_usec()
		if f == 10:
			_scene_us = 0.0
			_scene_n = 0
			_scene_on = true
		if f >= 10:
			proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			walls += (t - t_prev) / 1000.0
			prims += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
			calls += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			rcpu += RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid())
		t_prev = t
	var n := float(FRAMES - 10)
	var res := {"label": label, "process_ms": proc / n, "frame_ms": walls / n, "prims": prims / n, "render_ms": rcpu / n}
	res["calls"] = calls / n
	_scene_on = false
	res["scene_ms"] = _scene_us / maxf(1.0, _scene_n) / 1000.0
	print("PERF %-28s SCENE (scripts+layout+draw, no rendering) %6.2f ms" % [label, res["scene_ms"]])
	print("PERF %-28s render-cpu %6.2f ms   frame %6.2f ms   draw calls %6.0f   primitives %7.0f" % [label, res["render_ms"], res["frame_ms"], res["calls"], res["prims"]])
	return res


func _groups() -> Dictionary:
	var g := {}
	for n in m().find_children("*", "", true, false):
		var s: Script = n.get_script()
		if s == null:
			continue
		var k := s.resource_path.get_file().get_basename()
		if not g.has(k):
			g[k] = []
		g[k].append(n)
	return g


func _set_group(nodes: Array, on: bool) -> void:
	for n in nodes:
		n.set_process(on)


func _run() -> void:
	var gs = GameState
	gs.tips_enabled = false
	gs.popups_need_ok = false
	gs.rain_override = 0
	gs.cotw_enabled = false
	gs.reset_save()
	await wait(0.5)
	gs.finish_tutorial(true)
	gs.cash = 1e40
	for k in 25:
		if gs.bays.size() >= 10:
			break
		if gs.reno_needed() > 0:
			gs.start_renovation()
			gs._cstate("")["reno_until"] = gs.now - 1.0
			gs.unlock_renovation()
			continue
		gs.buy_bay()
	var lv := [5, 30, 120, 60, 150, 15, 250, 90, 40, 300]
	for i in gs.bays.size():
		gs.buy_levels("bay%d" % i, lv[i % lv.size()] - int(gs.bays[i]["level"]))
	gs.buy_levels("valet", 120)
	gs.buy_levels("desk", 120)
	for key in ["desk", "valet", "bay0", "bay1", "bay2", "bay3", "bay4"]:
		gs.hire_manager(key)
	for c in m().get_children():
		if c.has_method("clear_body"):
			c.close()
	if m().has_method("_dismiss_toast"):
		m()._dismiss_toast()
	m()._popup.visible = false
	await wait(1.5)

	print("PERF ---- shop")
	var base_top := await _measure("top (at rest)")
	var sc: ScrollContainer = m()._scroll
	var span := maxf(1.0, m()._rows.size.y - sc.size.y)
	var scroller := func(f: int):
		var k := fmod(f * 22.0, span * 2.0)
		sc.scroll_vertical = int(k if k < span else span * 2.0 - k)
	var base_scroll := await _measure("scroll", scroller)
	sc.scroll_vertical = 0
	await wait(0.3)

	if OS.get_environment("PERF_HIDE") == "1":
		base_top = await _measure("top again (base for hiding)")
		# what each part of the screen costs: hide it (it doesn't draw at all) and measure again
		var parts := {"sky_row": m().get("_sky_row"), "desk_row": m()._desk_row, "valet_row": m()._valet_row,
			"build_row": m()._build_row, "lane_overlay": m()._overlay, "ad_btn": m().get("_ad_btn")}
		var bays: Array = m()._bay_rows
		for k in parts.keys():
			var n = parts[k]
			if n == null:
				continue
			n.visible = false
			var a := await _measure("  hide %s" % k)
			n.visible = true
			print("PERF   => %-14s costs %5.2f ms scene" % [k, base_top["scene_ms"] - a["scene_ms"]])
		for b in bays:
			b.visible = false
		var c := await _measure("  hide all bays")
		for b in bays:
			b.visible = true
		print("PERF   => %-14s costs %5.2f ms scene" % ["bays", base_top["scene_ms"] - c["scene_ms"]])
		var root: Control = m()._scroll
		root.visible = false
		var d := await _measure("  hide whole shop")
		root.visible = true
		print("PERF   => %-14s costs %5.2f ms scene" % ["whole shop", base_top["scene_ms"] - d["scene_ms"]])
	var groups := _groups() if OS.get_environment("PERF_GROUPS") != "0" else {}
	print("PERF ---- cost per group (its _process off), top / scroll")
	for k in groups.keys():
		var nodes: Array = groups[k]
		var any := false
		for n in nodes:
			if n.is_processing():
				any = true
		if not any or k in ["game_state", "sfx", "perf"]:
			continue
		_set_group(nodes, false)
		var a := await _measure("  -%s x%d top" % [k, nodes.size()])
		var b := await _measure("  -%s x%d scroll" % [k, nodes.size()], scroller)
		_set_group(nodes, true)
		sc.scroll_vertical = 0
		# what it draws: hide them for a moment
		var vis := []
		for n in nodes:
			vis.append(n.visible)
			n.visible = false
		var h := await _measure("  hidden %s" % k)
		for i in nodes.size():
			nodes[i].visible = vis[i]
		print("PERF   => %-20s saves  top %5.2f ms  scroll %5.2f ms   draws %6.0f primitives" % [k, base_top["process_ms"] - a["process_ms"],
			base_scroll["process_ms"] - b["process_ms"], base_top["prims"] - h["prims"]])

	print("PERF ---- map")
	m()._open_map(0)
	await wait(1.0)
	var mp = null
	for c in m().get_children():
		if c.has_method("_set_tab"):
			mp = c
	await _measure("map (at rest)")
	var panner := func(f: int):
		var dr := InputEventScreenDrag.new()
		dr.index = 0
		dr.position = Vector2(360, 640)
		dr.relative = Vector2(-14 if (f / 40) % 2 == 0 else 14, -9 if (f / 40) % 2 == 0 else 9)
		mp._touches = {0: Vector2(360, 640)}
		mp._on_view_input(dr)
	await _measure("map_pan", panner)
	mp._touches = {}
	print("PERF done")
	get_tree().quit()
