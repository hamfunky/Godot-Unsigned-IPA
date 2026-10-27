extends Control
## v0.19u WORLD MAP (Hamza, after Idle Miner's map): a real map you drag around (both ways) and zoom (pinch,
## mouse wheel, trackpad). Every country is an island in its own theme, split by rivers into its 5 cities:
## tap a city's patch for its card (GO / PRESTIGE / UNLOCK). The "accessories" sit together on a chain of
## little islands down the left: Hometown Garage, Managers, Skill Tree, Equipment, Events (soon).
## Everything is drawn in code on one big canvas (WorldCanvas) that only redraws when something changes
## (pan / zoom just move + scale it). Skills / Managers / Equipment open over the map with a "< MAP" button.
## Kept for older callers + tests: setup(tab), _set_tab(k), _skills, _roster, _equip, _on_prestige(id).

const Data = preload("res://scripts/game_data.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")
const HudMeta = preload("res://scripts/hud_meta.gd")
const SkillTreeView = preload("res://scripts/skill_tree_view.gd")
const RosterView = preload("res://scripts/roster_view.gd")
const PrestigePanel = preload("res://scripts/workshop_panel.gd")
const EquipView = preload("res://scripts/equip_view.gd")
const MapArt = preload("res://scripts/map_art.gd")
const MapSide = preload("res://scripts/map_side_panel.gd")   # v0.19v: the COLLECT + PRESTIGE side panels

const TAB_NAMES := ["WORLD MAP", "SKILL TREE", "MANAGERS", "EQUIPMENT"]
const ZOOM_MIN := 0.34
const ZOOM_MAX := 1.6

var _wallets: HBoxContainer
var _title: Label
var _back: Button
var _view: Control          # the map's window (clips the canvas)
var _canvas: WorldCanvas
var _card: PanelContainer   # the selected city / landmark's card (bottom)
var _card_box: VBoxContainer
var _locate: Button
var _skills: Control
var _roster: Control
var _equip: Control
var _tab := 0
var _zoom := 0.8
var _touches := {}          # index -> position (screen, view-local)
var _press_at := Vector2.ZERO
var _moved := 0.0
var _pinch_d := 0.0
var _selected := ""         # city id, "country:<id>" or "lm:<id>"
var _sig := ""
var _tick := 0.0
var _confirm_unlock := ""
var _collect_btn: Button    # v0.19v: top-left corner: every city's stash + BOOST ALL
var _prestige_btn: Button   # v0.19v: top-right corner: every city's prestige
var _side: Control = null   # the side panel that's open
var _world_sig := ""


class WorldCanvas extends Control:
	const Data = preload("res://scripts/game_data.gd")
	const UiTheme = preload("res://scripts/ui_theme.gd")
	const HudMeta = preload("res://scripts/hud_meta.gd")
	const WORLD := Vector2(2300, 3150)

	# where each country's island sits (world px), its size and a seed for its coastline
	const ISLANDS := {
		"usa": {"c": Vector2(1020, 2600), "r": 410.0, "seed": 3},
		"japan": {"c": Vector2(1790, 2080), "r": 345.0, "seed": 7},
		"germany": {"c": Vector2(990, 1600), "r": 360.0, "seed": 11},
		"australia": {"c": Vector2(1770, 1080), "r": 395.0, "seed": 5},
		"uae": {"c": Vector2(1010, 560), "r": 345.0, "seed": 13},
	}
	# each country's look: land shades for its 5 cities, the beach, and which props grow there
	const THEMES := {
		"usa": {"land": ["8fd16a", "7cc45d", "a1d97c", "6fb953", "d9b26a"], "beach": "f3dfa2", "props": ["tree", "tree", "house", "tree", "house"]},
		"japan": {"land": ["a9d98b", "f3b5c7", "9fd07f", "f0a3ba", "b6de98"], "beach": "f5e3b5", "props": ["sakura", "sakura", "tree", "torii", "sakura"]},
		"germany": {"land": ["5f9e57", "6fab63", "558f50", "7bb36c", "65a35c"], "beach": "e6d7a6", "props": ["pine", "pine", "house", "pine", "pine"]},
		"australia": {"land": ["e0874a", "eaa060", "d4733a", "efb070", "e3925a"], "beach": "f7dca0", "props": ["gum", "rock", "gum", "gum", "palm"]},
		"uae": {"land": ["f0cf7e", "f5d993", "e8c06a", "f7e0a4", "e2b65d"], "beach": "fbe9bf", "props": ["dune", "palm", "dune", "palm", "tower"]},
	}
	# the accessories: one chain of islets down the left, near the start
	const LANDMARKS := [
		{"id": "hometown", "name": "Hometown Garage", "pos": Vector2(300, 2830)},
		{"id": "managers", "name": "Managers", "pos": Vector2(250, 2470)},
		{"id": "skills", "name": "Skill Tree", "pos": Vector2(330, 2120)},
		{"id": "equip", "name": "Equipment", "pos": Vector2(250, 1770)},
		{"id": "events", "name": "Events", "pos": Vector2(330, 1420)},
	]
	var geo := {}           # country id -> {coast, shallow, beach, center, regions: [{city, poly, label, a0, a1}], rivers, props}
	var selected := ""
	var labels: MapLabels   # v0.19v: names, incomes, shops, pins on their own layer (the world itself rarely redraws)
	var tiles: Array = []   # v0.19v perf: the world baked into 4 textures (drawn instead of ~280K shapes a frame)
	var tile_size := Vector2.ZERO

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = WORLD
		_build_geo()
		labels = MapLabels.new()
		labels.world = self
		add_child(labels)

	# ---------------------------------------------------------------- geometry (made once, deterministic)
	static func _coast_r(isl: Dictionary, a: float) -> float:
		var s: float = isl["seed"]
		return float(isl["r"]) * (1.0 + 0.11 * sin(3.0 * a + s) + 0.07 * sin(5.0 * a + s * 1.7) + 0.035 * sin(9.0 * a + s * 2.3))

	func _build_geo() -> void:
		for cdef in Data.COUNTRIES:
			var cid: String = cdef["id"]
			var isl: Dictionary = ISLANDS[cid]
			var c: Vector2 = isl["c"]
			var rng := RandomNumberGenerator.new()
			rng.seed = int(isl["seed"]) * 7919
			var coast := PackedVector2Array()
			for k in 72:
				var a := TAU * k / 72.0
				coast.append(c + Vector2(cos(a), sin(a)) * _coast_r(isl, a))
			var g := {"coast": coast, "shallow": _scaled(coast, c, 1.13), "beach": _scaled(coast, c, 1.045), "regions": [], "rivers": [], "props": []}
			var cc := c + Vector2(rng.randf_range(-0.08, 0.08), rng.randf_range(-0.08, 0.08)) * float(isl["r"])
			g["center"] = cc
			# 5 slices, city 1 at the bottom (nearest the start), then clockwise; borders are rivers
			var angs := []
			for k in 6:
				angs.append(deg_to_rad(54.0 + 72.0 * k + (rng.randf_range(-9.0, 9.0) if k % 5 != 0 else 0.0)))
			angs[5] = angs[0] + TAU
			var rivers := []
			for k in 5:
				var a: float = angs[k]
				var b := c + Vector2(cos(a), sin(a)) * _coast_r(isl, a) * 0.99
				var pts := PackedVector2Array()
				var dir := b - cc
				var nrm := Vector2(-dir.y, dir.x).normalized()
				var amp := rng.randf_range(-0.07, 0.07) * dir.length()
				for t in 13:
					var u := t / 12.0
					pts.append(cc + dir * u + nrm * sin(u * PI) * amp + nrm * sin(u * TAU * 1.5) * amp * 0.25)
				rivers.append(pts)
			g["rivers"] = rivers
			var cities: Array = cdef["cities"]
			for k in 5:
				var poly := PackedVector2Array()
				for p in rivers[k]:
					poly.append(p)
				var a0: float = angs[k]
				var a1: float = angs[k + 1]
				var steps := 18
				for t in range(1, steps):
					var a := lerpf(a0, a1, t / float(steps))
					poly.append(c + Vector2(cos(a), sin(a)) * _coast_r(isl, a))
				var back: PackedVector2Array = rivers[(k + 1) % 5]
				for t in range(back.size() - 1, 0, -1):
					poly.append(back[t])
				var am := (a0 + a1) * 0.5
				var lab := cc + (c + Vector2(cos(am), sin(am)) * _coast_r(isl, am) - cc) * 0.56
				g["regions"].append({"city": cities[k]["id"], "poly": poly, "label": lab, "a0": a0, "a1": a1, "k": k})
				# props scattered in the patch, clear of the label
				var kinds: Array = THEMES[cid]["props"]
				var n := 0
				var tries := 0
				while n < 9 and tries < 80:
					tries += 1
					var aa := rng.randf_range(a0 + 0.06, a1 - 0.06)
					var rr := rng.randf_range(0.18, 0.9)
					var p := cc + (c + Vector2(cos(aa), sin(aa)) * _coast_r(isl, aa) - cc) * rr
					if not Geometry2D.is_point_in_polygon(p, poly) or p.distance_to(lab) < 95.0:
						continue
					var kind: String = kinds[k] if rng.randf() < 0.55 else kinds[(k + 1 + rng.randi() % 4) % 5]
					if kind in ["tower", "torii", "rock", "house"] and rng.randf() < 0.6:
						kind = {"tower": "palm", "torii": "sakura", "rock": "gum", "house": "tree"}[kind]
					g["props"].append([p, kind, rng.randf_range(0.8, 1.2)])
					n += 1
			# a signature landmark on each island
			match cid:
				"japan": g["props"].append([_region_point(g, 3, 0.75), "fuji", 1.0])
				"germany": g["props"].append([_region_point(g, 0, 0.72), "ring", 1.0])
				"australia": g["props"].append([_region_point(g, 1, 0.72), "bigrock", 1.0])
				"uae": g["props"].append([_region_point(g, 4, 0.74), "tower", 1.5])
				"usa": g["props"].append([_region_point(g, 2, 0.78), "sign", 1.0])
			g["props"].sort_custom(func(p, q): return p[0].y < q[0].y)   # back to front
			geo[cid] = g

	func _region_point(g: Dictionary, k: int, f: float) -> Vector2:
		var r: Dictionary = g["regions"][k]
		var am := (float(r["a0"]) + float(r["a1"])) * 0.5 + 0.18
		var cc: Vector2 = g["center"]
		var edge: Vector2 = g["coast"][int(fposmod(am / TAU, 1.0) * 72.0) % 72]
		return cc + (edge - cc) * f

	static func _scaled(poly: PackedVector2Array, c: Vector2, k: float) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p in poly:
			out.append(c + (p - c) * k)
		return out

	## Which city patch (or "country:<id>" for a locked island) is at this world point ("" = sea).
	func hit(p: Vector2) -> String:
		for cid in geo.keys():
			var g: Dictionary = geo[cid]
			if not Geometry2D.is_point_in_polygon(p, g["beach"]):
				continue
			if not GameState.country_unlocked(cid):
				return "country:" + cid
			for r in g["regions"]:
				if Geometry2D.is_point_in_polygon(p, r["poly"]):
					return r["city"]
			return "country:" + cid
		for lm in LANDMARKS:
			if p.distance_to(lm["pos"]) < 110.0:
				return "lm:" + lm["id"]
		return ""

	# ---------------------------------------------------------------- drawing
	func _draw() -> void:
		if not tiles.is_empty():
			for k in tiles.size():
				var tp := Vector2((k % 2) * tile_size.x, (k / 2) * tile_size.y)
				draw_texture_rect(tiles[k], Rect2(tp, tile_size), false)
			return
		var ink := UiTheme.INK
		# ocean
		UiTheme.rounded(self, Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0), 0)
		draw_rect(Rect2(Vector2.ZERO, size), Color("3f86d8"))
		for k in 140:   # little wave marks
			var p := Vector2(fposmod(k * 271.3, size.x), fposmod(k * 157.9, size.y))
			draw_arc(p, 9.0, PI * 1.15, PI * 1.85, 6, Color(1, 1, 1, 0.16), 2.0, true)
			draw_arc(p + Vector2(16, 0), 9.0, PI * 1.15, PI * 1.85, 6, Color(1, 1, 1, 0.16), 2.0, true)
		# shipping lanes between the islands (the order you open them)
		var order := ["usa", "japan", "germany", "australia", "uae"]
		for k in order.size() - 1:
			var a: Vector2 = ISLANDS[order[k]]["c"]
			var b: Vector2 = ISLANDS[order[k + 1]]["c"]
			var open := GameState.country_unlocked(order[k + 1])
			_dashed(a, b, Color(1, 1, 1, 0.35 if open else 0.15), 6.0)
		_draw_landmarks()
		for cdef in Data.COUNTRIES:
			_draw_island(cdef)
		# a few soft clouds drifting over the sea (fixed: calm)
		for q in [[Vector2(260, 330), 1.0], [Vector2(1980, 300), 1.3], [Vector2(2150, 1650), 0.9], [Vector2(150, 980), 1.1],
				[Vector2(1520, 2920), 1.2], [Vector2(2150, 2650), 0.8], [Vector2(560, 1180), 0.7], [Vector2(1420, 1420), 0.8]]:
			_cloud(q[0], q[1])

	func _cloud(c: Vector2, k: float) -> void:
		var parts := [Vector2(-60, 6), Vector2(-26, -18), Vector2(14, -26), Vector2(50, -6), Vector2(70, 10), Vector2(0, 8)]
		for q in parts:
			draw_circle(c + q * k + Vector2(6, 10) * k, 34.0 * k, Color(0.1, 0.25, 0.5, 0.12))
		for q in parts:
			draw_circle(c + q * k, 34.0 * k, Color(1, 1, 1, 0.9))
		for q in parts.slice(0, 4):
			draw_circle(c + q * k + Vector2(-6, -8) * k, 16.0 * k, Color(1, 1, 1, 1))

	func _dashed(a: Vector2, b: Vector2, col: Color, w: float) -> void:
		var L := a.distance_to(b)
		var n := int(L / 34.0)
		for k in n:
			if k % 2 == 0:
				draw_line(a.lerp(b, k / float(n)), a.lerp(b, (k + 1) / float(n)), col, w, true)

	func _draw_island(cdef: Dictionary) -> void:
		var cid: String = cdef["id"]
		var g: Dictionary = geo[cid]
		var th: Dictionary = THEMES[cid]
		var owned := GameState.country_unlocked(cid)
		var ink := UiTheme.INK
		draw_colored_polygon(g["shallow"], Color("6fb3ee"))
		draw_colored_polygon(g["beach"], Color(th["beach"]) if owned else Color("b8c0cc"))
		_outline(g["beach"], ink, 4.0)
		for r in g["regions"]:
			var id: String = r["city"]
			var col := Color(th["land"][int(r["k"])])
			if not owned:
				col = col.lerp(Color("8f9bb0"), 0.75)
			elif not GameState.city_unlocked(id):
				col = col.lerp(Color("7a8597"), 0.55)
			draw_colored_polygon(r["poly"], col)
		# rivers between the cities
		for rv in g["rivers"]:
			draw_polyline(rv, Color("2f6fc0") if owned else Color("6f7a8c"), 12.0, true)
			draw_polyline(rv, Color("7fc4ff") if owned else Color("a3adbd"), 7.0, true)
		_outline(g["coast"], Color(0, 0, 0, 0.18), 3.0)
		for p in g["props"]:
			_prop(p[0], p[1], p[2], owned)
		# (v0.19v: the selection outline, shops, names and incomes are on the labels layer)
		if not owned:
			MapArt.padlock(self, ISLANDS[cid]["c"], 46.0)

	func _outline(poly: PackedVector2Array, col: Color, w: float) -> void:
		var p := PackedVector2Array(poly)
		p.append(poly[0])
		draw_polyline(p, col, w, true)

	## What the static world looks like (redraw only when this changes: unlocks, not incomes).
	func signature() -> String:
		return "%s|%s|%s" % [str(GameState.unlocked_countries()), str(GameState.cities.keys()), GameState.hometown.get("unlocked", false)]

	# ---- props (all small, outlined, a shadow under each)
	func _prop(p: Vector2, kind: String, k: float, owned: bool) -> void:
		var ink := UiTheme.INK
		var dim := 0.0 if owned else 0.55
		var C := func(c: Color) -> Color: return c.lerp(Color("97a2b4"), dim)
		draw_set_transform(p + Vector2(0, 2), 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, 16.0 * k, Color(0, 0, 0, 0.16))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		match kind:
			"tree", "gum", "sakura":
				var leaf: Color = {"tree": Color("3f9e4a"), "gum": Color("8a9a4a"), "sakura": Color("ff9fbf")}[kind]
				draw_rect(Rect2(p + Vector2(-3, -14) * k, Vector2(6, 14) * k), C.call(Color("8a5a3b")))
				for q in [Vector2(-8, -20), Vector2(8, -20), Vector2(0, -30)]:
					draw_circle(p + q * k, 12.5 * k, ink)
				for q in [Vector2(-8, -20), Vector2(8, -20), Vector2(0, -30)]:
					draw_circle(p + q * k, 10.5 * k, C.call(leaf))
				draw_circle(p + Vector2(-3, -33) * k, 3.5 * k, C.call(leaf.lightened(0.3)))
			"pine":
				for t in 3:
					var y := -10.0 - t * 11.0
					var tri := PackedVector2Array([p + Vector2(-15 + t * 3, y) * k, p + Vector2(15 - t * 3, y) * k, p + Vector2(0, y - 18) * k])
					draw_colored_polygon(tri, C.call(Color("2e7d4f")))
					tri.append(tri[0])
					draw_polyline(tri, ink, 2.0, true)
			"palm":
				draw_line(p, p + Vector2(6, -36) * k, ink, 7.0 * k, true)
				draw_line(p, p + Vector2(6, -36) * k, C.call(Color("a1887f")), 4.0 * k, true)
				for a in [-2.7, -2.0, -1.2, -0.4]:
					var tip: Vector2 = p + Vector2(6, -36) * k + Vector2(cos(a), sin(a) + 0.6) * 22.0 * k
					draw_line(p + Vector2(6, -36) * k, tip, ink, 7.0 * k, true)
					draw_line(p + Vector2(6, -36) * k, tip, C.call(Color("43a047")), 4.0 * k, true)
			"cactus":
				UiTheme.rounded(self, Rect2(p + Vector2(-5, -32) * k, Vector2(10, 32) * k), C.call(Color("4caf50")), 5, 2, ink)
			"house":
				UiTheme.rounded(self, Rect2(p + Vector2(-13, -18) * k, Vector2(26, 18) * k), C.call(Color("fff3e0")), 2, 2, ink)
				var roof := PackedVector2Array([p + Vector2(-17, -18) * k, p + Vector2(17, -18) * k, p + Vector2(0, -32) * k])
				draw_colored_polygon(roof, C.call(Color("e8553d")))
				roof.append(roof[0])
				draw_polyline(roof, ink, 2.0, true)
			"torii":
				for sx in [-12.0, 12.0]:
					draw_line(p + Vector2(sx, 0) * k, p + Vector2(sx, -30) * k, C.call(Color("e53935")), 5.0 * k)
				draw_line(p + Vector2(-18, -30) * k, p + Vector2(18, -30) * k, C.call(Color("c62828")), 6.0 * k)
				draw_line(p + Vector2(-14, -22) * k, p + Vector2(14, -22) * k, C.call(Color("e53935")), 4.0 * k)
			"rock", "bigrock":
				var s := 1.0 if kind == "rock" else 2.6
				var rk := PackedVector2Array([p + Vector2(-22, 0) * k * s, p + Vector2(-16, -14) * k * s, p + Vector2(-2, -20) * k * s, p + Vector2(16, -15) * k * s, p + Vector2(24, 0) * k * s])
				draw_colored_polygon(rk, C.call(Color("c1502e")))
				rk.append(rk[0])
				draw_polyline(rk, ink, 3.0, true)
				draw_line(p + Vector2(-8, -16) * k * s, p + Vector2(10, -14) * k * s, Color(1, 1, 1, 0.25), 3.0)
			"dune":
				draw_arc(p + Vector2(0, 8) * k, 22.0 * k, PI * 1.1, PI * 1.9, 10, C.call(Color("d9a441")), 5.0 * k, true)
				draw_arc(p + Vector2(14, 14) * k, 16.0 * k, PI * 1.1, PI * 1.9, 10, C.call(Color("d9a441")), 4.0 * k, true)
			"tower":
				var tw := 18.0 * k
				var poly := PackedVector2Array([p + Vector2(-tw * 0.5, 0), p + Vector2(tw * 0.5, 0), p + Vector2(tw * 0.15, -110 * k), p + Vector2(-tw * 0.15, -110 * k)])
				draw_colored_polygon(poly, C.call(Color("b3d6f2")))
				poly.append(poly[0])
				draw_polyline(poly, ink, 3.0, true)
				draw_line(p + Vector2(0, -110) * k, p + Vector2(0, -140) * k, ink, 3.0)
				for t in 6:
					var wy := (-14.0 - t * 15.0) * k
					var half := tw * (0.4 - 0.04 * t)
					draw_line(p + Vector2(-half, wy), p + Vector2(half, wy), Color(1, 1, 1, 0.5), 2.0)
			"fuji":
				var m := PackedVector2Array([p + Vector2(-95, 0), p + Vector2(-18, -92), p + Vector2(18, -92), p + Vector2(95, 0)])
				draw_colored_polygon(m, C.call(Color("7e8fa8")))
				var snow := PackedVector2Array([p + Vector2(-34, -62), p + Vector2(-18, -92), p + Vector2(18, -92), p + Vector2(34, -62), p + Vector2(16, -56), p + Vector2(0, -66), p + Vector2(-16, -56)])
				draw_colored_polygon(snow, Color.WHITE)
				m.append(m[0])
				draw_polyline(m, ink, 4.0, true)
			"ring":   # the famous race track: a looping ring road
				draw_arc(p, 62.0, 0, TAU, 40, ink, 14.0, true)
				draw_arc(p, 62.0, 0, TAU, 40, C.call(Color("5d6470")), 10.0, true)
				for t in 12:
					var a := t * TAU / 12.0
					draw_line(p + Vector2(cos(a), sin(a)) * 60.0, p + Vector2(cos(a), sin(a)) * 64.0, Color.WHITE, 2.0)
			"sign":   # a big hillside sign of the city's initials
				UiTheme.text(self, p + Vector2(-90, 0), "LA", 44, C.call(Color.WHITE), HORIZONTAL_ALIGNMENT_CENTER, 180, 6, UiTheme.DISPLAY_FONT)

	# ---- the accessories: little round islets with a picture + ribbon
	func _draw_landmarks() -> void:
		for lm in LANDMARKS:
			var p: Vector2 = lm["pos"]
			var id: String = lm["id"]
			draw_circle(p + Vector2(0, 10), 104.0, Color("6fb3ee"))
			var blob := PackedVector2Array()
			for k in 40:
				var a := TAU * k / 40.0
				blob.append(p + Vector2(cos(a), sin(a) * 0.72) * (88.0 + 6.0 * sin(a * 3.0 + p.x)))
			draw_colored_polygon(blob, Color("f3dfa2"))
			_outline(blob, UiTheme.INK, 4.0)
			var inner := PackedVector2Array()
			for q in blob:
				inner.append(p + (q - p) * 0.82 + Vector2(0, -4))
			draw_colored_polygon(inner, Color("8fd16a"))
			var locked: bool = id == "events" or (id == "hometown" and not GameState.hometown.get("unlocked", false))
			_landmark_icon(p + Vector2(0, -16), id, locked)

	## A dot on a landmark: something waiting there.
	static func landmark_alert(id: String) -> bool:
		match id:
			"hometown":
				return GameState.ht_claimable() > 0 or (GameState.hometown.get("unlocked", false) and not GameState.hometown.get("seen", true))
			"managers":
				return GameState.callable_count() > 0 or GameState.unopened_case_files() > 0
		return false

	func _landmark_icon(c: Vector2, id: String, locked: bool) -> void:
		var ink := UiTheme.INK
		var g := func(col: Color) -> Color: return col.lerp(Color("9aa5b8"), 0.6) if locked else col
		match id:
			"hometown":   # a cosy garage
				UiTheme.rounded(self, Rect2(c + Vector2(-44, -30), Vector2(88, 52)), g.call(Color("ffe0b2")), 4, 3, ink)
				var roof := PackedVector2Array([c + Vector2(-54, -28), c + Vector2(54, -28), c + Vector2(0, -62)])
				draw_colored_polygon(roof, g.call(Color("8d6e63")))
				roof.append(roof[0])
				draw_polyline(roof, ink, 3.0, true)
				UiTheme.rounded(self, Rect2(c + Vector2(-30, -14), Vector2(60, 36)), g.call(Color("9fb0c4")), 3, 3, ink)
				for t in 4:
					draw_line(c + Vector2(-26, -6 + t * 8), c + Vector2(26, -6 + t * 8), Color(0, 0, 0, 0.18), 2.0)
			"managers":   # an office tower
				UiTheme.rounded(self, Rect2(c + Vector2(-34, -70), Vector2(68, 92)), g.call(Color("90caf9")), 4, 3, ink)
				for row in 4:
					for col in 3:
						draw_rect(Rect2(c + Vector2(-26 + col * 19, -62 + row * 20), Vector2(13, 13)), g.call(Color("e3f2fd")))
				UiTheme.rounded(self, Rect2(c + Vector2(-12, 2), Vector2(24, 20)), g.call(Color("ffcf4a")), 3, 2, ink)
			"skills":   # a big cog
				var pts := PackedVector2Array()
				for k in 24:
					var a := TAU * k / 24.0
					pts.append(c + Vector2(cos(a), sin(a)) * (40.0 if k % 2 == 0 else 31.0))
				draw_colored_polygon(pts, g.call(Color("b0bec5")))
				pts.append(pts[0])
				draw_polyline(pts, ink, 3.0, true)
				draw_circle(c, 14.0, ink)
				draw_circle(c, 11.0, g.call(Color("3ccf5a")))
			"equip":   # a red toolbox
				UiTheme.rounded(self, Rect2(c + Vector2(-44, -24), Vector2(88, 46)), g.call(Color("e53935")), 6, 3, ink)
				draw_arc(c + Vector2(0, -26), 16.0, PI, TAU, 10, ink, 5.0, true)
				draw_rect(Rect2(c + Vector2(-44, -6), Vector2(88, 5)), Color(0, 0, 0, 0.25))
				UiTheme.rounded(self, Rect2(c + Vector2(-8, -10), Vector2(16, 12)), g.call(Color("ffcf4a")), 2, 2, ink)
			"events":   # a striped marquee tent
				var tent := PackedVector2Array([c + Vector2(-48, 22), c + Vector2(-40, -20), c + Vector2(0, -56), c + Vector2(40, -20), c + Vector2(48, 22)])
				draw_colored_polygon(tent, g.call(Color("fff3e0")))
				for k in 4:
					var x0 := -40.0 + k * 20.0
					draw_colored_polygon(PackedVector2Array([c + Vector2(x0, -20), c + Vector2(x0 + 10, -20), c + Vector2(0, -56)]), g.call(Color("e53935")))
				tent.append(tent[0])
				draw_polyline(tent, ink, 3.0, true)
				draw_line(c + Vector2(0, -56), c + Vector2(0, -74), ink, 3.0)
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -74), c + Vector2(18, -68), c + Vector2(0, -62)]), g.call(Color("ffcf4a")))


## v0.19v: everything on the map that changes or has words: city shops + names + incomes + stashes, country
## names, the landmarks' names, the "you're here" pin, the selected outline. Redrawn twice a second and when
## you zoom. Words grow as you zoom out (lk), so they stay readable over the whole world (Hamza 27 Oct).
class MapLabels extends Control:
	const Data = preload("res://scripts/game_data.gd")
	const UiTheme = preload("res://scripts/ui_theme.gd")
	const HudMeta = preload("res://scripts/hud_meta.gd")
	const MapArt = preload("res://scripts/map_art.gd")
	var world: Control
	var lk := 1.0           # label scale (1 = close up; bigger when zoomed out)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		size = world.size

	func set_zoom(z: float) -> void:
		var k := clampf(0.9 / z, 1.0, 2.8)
		if absf(k - lk) > 0.02:
			lk = k
			queue_redraw()

	func _draw() -> void:
		var geo: Dictionary = world.geo
		for cdef in Data.COUNTRIES:
			var cid: String = cdef["id"]
			var g: Dictionary = geo[cid]
			var owned := GameState.country_unlocked(cid)
			for r in g["regions"]:
				if r["city"] == world.selected or (world.selected == "country:" + cid):
					MapArt.outline(self, r["poly"], Color(1, 1, 1, 0.95), 6.0)
			if owned:
				var best := GameState.best_city(cid)
				for r in g["regions"]:
					_marker(r, cid, best)
			# the country's name on a big ribbon at the top of its island
			var isl: Dictionary = world.ISLANDS[cid]
			var top := Vector2(float(isl["c"].x), float(isl["c"].y) - float(isl["r"]) * 1.12 - 26.0 * lk)
			var sub := ""
			if owned:
				sub = "%s/s" % GameState.money(GameState.country_income(cid), cid)
			else:
				var cost := GameState.country_unlock_cost(cid)
				sub = ("Unlock: " + GameState.money(cost, GameState.previous_country(cid))) if cost >= 0.0 else "Locked"
			MapArt.ribbon(self, top, str(cdef["name"]).to_upper(), Color(cdef["color"]) if owned else Color("6b7a99"), int(34 * minf(lk, 2.2)), sub)
		for lm in world.LANDMARKS:
			var p: Vector2 = lm["pos"]
			var id: String = lm["id"]
			var locked: bool = id == "events" or (id == "hometown" and not GameState.hometown.get("unlocked", false))
			var sub := ""
			if id == "events":
				sub = "Coming soon"
			elif id == "hometown" and locked:
				sub = "Locked"
			elif id == "hometown" and GameState.is_hometown():
				sub = "You're here"
			elif id == "hometown" and GameState.stash_of(Data.HOMETOWN_ID) > 0.0:
				sub = "+" + GameState.money(GameState.stash_of(Data.HOMETOWN_ID), Data.HOMETOWN_ID)
			MapArt.ribbon(self, p + Vector2(0, 62 + 14 * (lk - 1.0)), lm["name"], Color("2a63c4") if not locked else Color("6b7a99"), int(22 * lk), sub,
				Color("8dff8a") if sub.begins_with("+") else UiTheme.CASH)
			if world.landmark_alert(id):
				draw_circle(p + Vector2(58, -58), 15.0, Color.WHITE)
				draw_circle(p + Vector2(58, -58), 11.0, Color("ff7a45"))
			if id == "hometown" and GameState.is_hometown():
				MapArt.pin(self, p + Vector2(0, -98), lk)

	func _marker(r: Dictionary, cid: String, best: String) -> void:
		var id: String = r["city"]
		var at: Vector2 = r["label"]
		var name := str(GameState.city_def(id)["name"]).split(",")[0]
		var fs := int(22 * lk)
		if GameState.city_unlocked(id):
			var p := int(GameState.cities[id]["prestige"])
			var here := id == GameState.active_city
			MapArt.shop(self, at + Vector2(0, -18 * lk), p, here, Color(GameState.premises_def(p)["color"]), lk)
			var sub := "%s/s" % GameState.money(GameState.city_idle_rate(id), cid)
			var rr := MapArt.ribbon(self, at + Vector2(0, 30 * lk), name, Color("2a63c4") if not here else Color("e0a000"), fs, sub)
			# v0.19v: what it's made while you were elsewhere (COLLECT), and its ad boost
			var st := GameState.stash_of(id)
			if st > 0.0 and not here:
				var t := "+" + GameState.money(st, cid)
				var sfs := int(fs * 0.85)
				var sw := UiTheme.DISPLAY_FONT.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x + 24.0
				var sr := Rect2(at.x - sw * 0.5, rr.end.y + 2, sw, sfs + 10.0)
				UiTheme.rounded(self, sr, Color("2fb457"), int(sfs * 0.45), maxi(2, int(2 * lk)), UiTheme.INK)
				UiTheme.text(self, Vector2(sr.position.x, sr.position.y + sfs * 0.98), t, sfs, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, sw, int(4 * lk), UiTheme.DISPLAY_FONT)
			if GameState.ad_boost_left(id) > 0.0:
				var bc := Vector2(rr.end.x + 6 * lk, rr.position.y + 4 * lk)
				UiTheme.rounded(self, Rect2(bc + Vector2(-20, -14) * lk, Vector2(40, 28) * lk), Color("3ccf5a"), int(9 * lk), maxi(2, int(2 * lk)), UiTheme.INK)
				UiTheme.text(self, bc + Vector2(-20 * lk, 7 * lk), "x2", int(17 * lk), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 40 * lk, int(4 * lk), UiTheme.DISPLAY_FONT)
			if GameState.prestige_ready(id) and not here:
				HudMeta.draw_star(self, at + Vector2(38, -46) * lk, 15.0 * lk, true)
			if here:
				MapArt.pin(self, at + Vector2(0, -78 * lk), lk)
		else:
			var uc := GameState.city_unlock_cost(id)
			if uc >= 0.0:
				MapArt.ribbon(self, at, name, Color("2fa84a"), fs, "UNLOCK  " + GameState.money(uc, cid))
			else:
				MapArt.padlock(self, at, 22.0 * lk)
				UiTheme.text(self, at + Vector2(-160, 40) * Vector2(1, lk), name, int(18 * lk), Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER, 320, int(5 * lk))


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(tab: int = 0) -> void:
	var bg := ColorRect.new()
	bg.color = Color("3f86d8")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# top bar: title (or < MAP in a sub screen), every currency you own, X
	var top := PanelContainer.new()
	var ts := UiTheme.box(UiTheme.HUD, 0, 14)
	ts.content_margin_top = 44
	ts.border_width_bottom = 5
	ts.border_color = UiTheme.INK
	top.add_theme_stylebox_override("panel", ts)
	root.add_child(top)
	var tv := VBoxContainer.new()
	top.add_child(tv)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 10)
	tv.add_child(th)
	_back = UiTheme.button("< MAP", 20, Color("2a63c4"))
	_back.custom_minimum_size = Vector2(120, 56)
	_back.visible = false
	_back.pressed.connect(func(): _set_tab(0))
	th.add_child(_back)
	_title = UiTheme.display_label("WORLD MAP", 30, Color.WHITE)
	_title.add_theme_color_override("font_outline_color", UiTheme.INK)
	_title.add_theme_constant_override("outline_size", 8)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(_title)
	var x := UiTheme.button("X", 26, Color("ff5a5f"))
	x.custom_minimum_size = Vector2(64, 56)
	x.pressed.connect(func():
		Sfx.play("close")
		queue_free())
	th.add_child(x)
	_wallets = HBoxContainer.new()
	_wallets.add_theme_constant_override("separation", 22)
	tv.add_child(_wallets)

	# the map window
	_view = Control.new()
	_view.clip_contents = true
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.gui_input.connect(_on_view_input)
	root.add_child(_view)
	_canvas = WorldCanvas.new()
	_view.add_child(_canvas)
	# the selected place's card + the "where am I" button, over the map
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", UiTheme.card(Color("23345e"), 22, 16, UiTheme.INK))
	_card.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_card.offset_left = 14
	_card.offset_right = -14
	_card.offset_bottom = -14
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.visible = false
	_view.add_child(_card)
	_card_box = VBoxContainer.new()
	_card_box.add_theme_constant_override("separation", 8)
	_card.add_child(_card_box)
	_locate = UiTheme.button("", 20, Color("2a63c4"))
	_locate.custom_minimum_size = Vector2(76, 76)
	_locate.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_locate.offset_left = -92
	_locate.offset_top = -92
	_locate.offset_right = -16
	_locate.offset_bottom = -16
	_locate.pressed.connect(func():
		Sfx.play("click")
		center_on_here(true))
	var pin := Control.new()
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pin.set_anchors_preset(Control.PRESET_FULL_RECT)
	pin.draw.connect(func():
		var c := Vector2(38, 32)
		pin.draw_colored_polygon(PackedVector2Array([c + Vector2(-10, 6), c + Vector2(10, 6), c + Vector2(0, 28)]), UiTheme.INK)
		pin.draw_circle(c, 16.0, UiTheme.INK)
		pin.draw_colored_polygon(PackedVector2Array([c + Vector2(-8, 7), c + Vector2(8, 7), c + Vector2(0, 24)]), Color("ff5a5f"))
		pin.draw_circle(c, 13.0, Color("ff5a5f"))
		pin.draw_circle(c, 5.0, Color.WHITE))
	_locate.add_child(pin)
	_view.add_child(_locate)
	# v0.19v (Hamza, like Idle Miner): COLLECT top-left, PRESTIGE top-right; each opens a side panel
	_collect_btn = _corner_button("COLLECT", Color("2fa84a"), true)
	_collect_btn.pressed.connect(func(): _open_side("collect"))
	_view.add_child(_collect_btn)
	_prestige_btn = _corner_button("PRESTIGE", Color("8e24aa"), false)
	_prestige_btn.pressed.connect(func(): _open_side("prestige"))
	_view.add_child(_prestige_btn)

	_skills = SkillTreeView.new()
	_skills.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_skills.visible = false
	root.add_child(_skills)
	_roster = RosterView.new()
	_roster.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_roster.visible = false
	root.add_child(_roster)
	_equip = EquipView.new()
	_equip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_equip.visible = false
	root.add_child(_equip)
	_set_tab(tab)
	_refresh_wallets()
	center_on_here.call_deferred(false)
	_world_sig = _canvas.signature()
	_bake_world.call_deferred()
	_update_corners()


func _corner_button(t: String, col: Color, left: bool) -> Button:
	var b := UiTheme.button(t, 15, col)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb: StyleBox = b.get_theme_stylebox(st).duplicate()
		sb.content_margin_top += 44
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		b.add_theme_stylebox_override(st, sb)
	b.custom_minimum_size = Vector2(104, 98)
	b.set_anchors_preset(Control.PRESET_TOP_LEFT if left else Control.PRESET_TOP_RIGHT)
	b.offset_left = 14 if left else -118
	b.offset_right = 118 if left else -14
	b.offset_top = 14
	b.offset_bottom = 112
	b.draw.connect(func():
		var c := Vector2(b.size.x * 0.5, 32)
		if left:
			MapArt.coins(b, c, 44.0)
		else:
			HudMeta.draw_trophy(b, c, 42.0, true)
		if b.get_meta("alert", false):
			b.draw_circle(Vector2(b.size.x - 12, 12), 12.0, Color.WHITE)
			b.draw_circle(Vector2(b.size.x - 12, 12), 9.0, Color("ff7a45")))
	return b


## The orange dots: something to collect / a city that can prestige.
func _update_corners() -> void:
	var col := GameState.stash_total() > 0.0
	var pre := false
	for id in GameState.cities.keys():
		if id != Data.HOMETOWN_ID and GameState.prestige_ready(id):
			pre = true
	for pair in [[_collect_btn, col], [_prestige_btn, pre]]:
		if bool(pair[0].get_meta("alert", false)) != pair[1]:
			pair[0].set_meta("alert", pair[1])
			pair[0].queue_redraw()


func _open_side(k: String) -> void:
	if is_instance_valid(_side):
		_side.queue_free()
	Sfx.play("click")
	select("")
	_side = MapSide.new()
	_view.add_child(_side)
	_side.setup(k)
	_side.prestige_city.connect(_on_prestige)


## v0.19v perf: draw the (still) world once into 4 textures with mipmaps and show those instead of the
## shapes. Done again only when something opens (new city / country / Hometown). Kept between map visits.
static var _bake_cache := {}


func _bake_world() -> void:
	var sig := _canvas.signature()
	if not _bake_cache.has(sig):
		_canvas.tiles = []
		_canvas.queue_redraw()
		await bake_tiles(self, sig)
	if not _bake_cache.has(sig) or not is_instance_valid(_canvas) or _canvas.signature() != sig:
		return
	_canvas.tiles = _bake_cache[sig]
	_canvas.tile_size = (WorldCanvas.WORLD / 2.0).ceil()
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_canvas.labels.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_canvas.queue_redraw()


## v0.19w: draws the world into the cache (4 tiles with mipmaps) under host. Also used by the loading bar on
## launch (prebake) so the first map visit doesn't stall.
static func bake_tiles(host: Node, sig: String) -> void:
	if _bake_cache.has(sig) or DisplayServer.get_name() == "headless":
		return
	var ts := (WorldCanvas.WORLD / 2.0).ceil()
	var vps := []
	for k in 4:
		var vp := SubViewport.new()
		vp.size = Vector2i(ts)
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var wc := WorldCanvas.new()
		wc.labels.visible = false
		wc.position = -Vector2((k % 2) * ts.x, (k / 2) * ts.y)
		vp.add_child(wc)
		host.add_child(vp)
		vps.append(vp)
	var tree := host.get_tree()
	await RenderingServer.frame_post_draw
	await tree.process_frame
	await RenderingServer.frame_post_draw
	var tiles := []
	for vp in vps:
		if not is_instance_valid(vp):
			return
		var img: Image = vp.get_texture().get_image()
		vp.queue_free()
		if img == null or img.is_empty():
			return
		img.convert(Image.FORMAT_RGB8)
		img.generate_mipmaps()
		tiles.append(ImageTexture.create_from_image(img))
	_bake_cache = {sig: tiles}


## The world as it is now, baked ahead (launch loading bar).
static func prebake(host: Node) -> void:
	var wc := WorldCanvas.new()
	var sig := wc.signature()
	wc.free()
	await bake_tiles(host, sig)


func _set_tab(k: int) -> void:
	_tab = k
	_view.visible = k == 0
	_skills.visible = k == 1
	_roster.visible = k == 2
	_equip.visible = k == 3
	_back.visible = k != 0
	_title.text = TAB_NAMES[clampi(k, 0, TAB_NAMES.size() - 1)]


# ================================================================ camera

func _apply() -> void:
	var vs := _view.size
	var ws := WorldCanvas.WORLD * _zoom
	var p := _canvas.position
	# keep some of the world on screen, with a margin of sea all round
	var m := 160.0
	p.x = clampf(p.x, minf(vs.x - ws.x - m, (vs.x - ws.x) * 0.5), maxf(m, (vs.x - ws.x) * 0.5))
	p.y = clampf(p.y, minf(vs.y - ws.y - m, (vs.y - ws.y) * 0.5), maxf(m, (vs.y - ws.y) * 0.5))
	_canvas.position = p
	_canvas.scale = Vector2(_zoom, _zoom)
	_canvas.labels.set_zoom(_zoom)   # v0.19v: words grow as you zoom out


func zoom_at(screen_p: Vector2, factor: float) -> void:
	var nz := clampf(_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	var w := (screen_p - _canvas.position) / _zoom
	_zoom = nz
	_canvas.position = screen_p - w * _zoom
	_apply()


func pan(d: Vector2) -> void:
	_canvas.position += d
	_apply()


func to_world(screen_p: Vector2) -> Vector2:
	return (screen_p - _canvas.position) / _zoom


## Centre the map on the city you're in (or the Hometown).
func center_on_here(animate: bool = false) -> void:
	var target := Vector2(WorldCanvas.WORLD.x * 0.5, WorldCanvas.WORLD.y * 0.8)
	if GameState.is_hometown():
		target = WorldCanvas.LANDMARKS[0]["pos"]
	else:
		var cid := GameState.country_of(GameState.active_city)
		for r in _canvas.geo.get(cid, {}).get("regions", []):
			if r["city"] == GameState.active_city:
				target = r["label"]
	var z := 0.78
	var dest := _view.size * Vector2(0.5, 0.45) - target * z
	if animate:
		var tw := create_tween().set_parallel()
		tw.tween_method(func(v: float):
			_zoom = v
			_apply(), _zoom, z, 0.35)
		tw.tween_property(_canvas, "position", dest, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.chain().tween_callback(_apply)
	else:
		_zoom = z
		_canvas.position = dest
		_apply()


func _on_view_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			_touches[e.index] = e.position
			if _touches.size() == 1:
				_press_at = e.position
				_moved = 0.0
			elif _touches.size() == 2:
				var v: Array = _touches.values()
				_pinch_d = (v[0] as Vector2).distance_to(v[1])
		else:
			var was_single := _touches.size() == 1
			_touches.erase(e.index)
			if was_single and _moved < 14.0:
				tap(e.position)
	elif e is InputEventScreenDrag:
		_touches[e.index] = e.position
		_moved += e.relative.length()
		if _touches.size() >= 2:
			var v: Array = _touches.values()
			var d := (v[0] as Vector2).distance_to(v[1])
			if _pinch_d > 1.0:
				zoom_at(((v[0] as Vector2) + (v[1] as Vector2)) * 0.5, d / _pinch_d)
			_pinch_d = d
		else:
			pan(e.relative)
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_at(e.position, 1.12)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at(e.position, 1.0 / 1.12)
	elif e is InputEventMagnifyGesture:
		zoom_at(e.position, e.factor)
	elif e is InputEventPanGesture:
		pan(-e.delta * 12.0)


# ================================================================ taps + the card

func tap(screen_p: Vector2) -> void:
	if _card.visible and _card.get_rect().has_point(screen_p):
		return
	var hit := _canvas.hit(to_world(screen_p))
	select(hit)


## Select a city id, "country:<id>", "lm:<id>" or "" (nothing).
func select(what: String) -> void:
	if what.begins_with("lm:"):
		var id := what.substr(3)
		match id:
			"managers":
				Sfx.play("click")
				_set_tab(2)
				return
			"skills":
				Sfx.play("click")
				_set_tab(1)
				return
			"equip":
				Sfx.play("click")
				_set_tab(3)
				return
	if what != "":
		Sfx.play("click")
	_selected = what
	_canvas.selected = what
	_canvas.labels.queue_redraw()
	_build_card()


func _build_card() -> void:
	for c in _card_box.get_children():
		c.queue_free()
	_card.visible = _selected != ""
	_locate.visible = not _card.visible
	if _selected == "":
		return
	if _selected.begins_with("lm:"):
		_landmark_card(_selected.substr(3))
	elif _selected.begins_with("country:"):
		_country_card(_selected.substr(8))
	else:
		_city_card(_selected)


func _card_title(t: String, sub: String = "") -> void:
	var h := HBoxContainer.new()
	var l := UiTheme.display_label(t, 28, Color.WHITE)
	l.add_theme_color_override("font_outline_color", UiTheme.INK)
	l.add_theme_constant_override("outline_size", 7)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var x := UiTheme.button("X", 20, Color("ff5a5f"))
	x.custom_minimum_size = Vector2(52, 46)
	x.pressed.connect(func(): select(""))
	h.add_child(x)
	_card_box.add_child(h)
	if sub != "":
		var s := UiTheme.label(sub, 18, Color(1, 1, 1, 0.8))
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_card_box.add_child(s)


func _city_card(id: String) -> void:
	var cid := GameState.country_of(id)
	var nm: String = GameState.city_def(id)["name"]
	if GameState.city_unlocked(id):
		var p := int(GameState.cities[id]["prestige"])
		var here := id == GameState.active_city
		_card_title(nm, "%s  ·  %s" % [GameState.country_def(cid)["name"], GameState.premises_def(p)["name"]])
		var tro := Control.new()
		tro.custom_minimum_size = Vector2(0, 24)
		tro.draw.connect(func():
			for k in Data.MAX_PRESTIGE:
				HudMeta.draw_trophy(tro, Vector2(12 + k * 26, 12), 22.0, k < p))
		_card_box.add_child(tro)
		var rate := UiTheme.label("x%s income  ·  %s/s%s" % [GameState.fmt(GameState.city_mult_of(id)), GameState.money(GameState.city_idle_rate(id), cid),
			"  ·  BEST EARNER" if GameState.best_city(cid) == id else ""], 19, UiTheme.CASH)
		_card_box.add_child(rate)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		_card_box.add_child(h)
		var go := UiTheme.button("YOU'RE HERE" if here else "GO", 22, Color("8a94ab") if here else UiTheme.ACCENT)
		go.custom_minimum_size = Vector2(0, 66)
		go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		go.disabled = here
		go.pressed.connect(func(): go_to(id))
		h.add_child(go)
		var pc := GameState.prestige_cost(id)
		var pb := UiTheme.button("MAXED" if pc < 0.0 else (("PRESTIGE!\n" if GameState.prestige_ready(id) else "PRESTIGE\n") + GameState.money(pc, cid)), 17, Color("8e24aa"))
		pb.custom_minimum_size = Vector2(0, 66)
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.disabled = pc < 0.0
		pb.pressed.connect(func(): _on_prestige(id))
		h.add_child(pb)
	else:
		var uc := GameState.city_unlock_cost(id)
		_card_title(nm, "%s  ·  a x%s city" % [GameState.country_def(cid)["name"], GameState.fmt(GameState.city_scale(id))])
		if uc >= 0.0:
			var ub := UiTheme.button("UNLOCK  " + GameState.money(uc, cid), 22, UiTheme.GOOD)
			ub.custom_minimum_size = Vector2(0, 68)
			ub.disabled = GameState.wallets.get(cid, 0.0) < uc
			ub.pressed.connect(func():
				Sfx.play("unlock")
				_loading_go(GameState.unlock_city.bind(id), id, "New city!")
				queue_free())
			_card_box.add_child(ub)
		else:
			var prev := ""
			var list: Array = GameState.country_def(cid)["cities"]
			for k in list.size():
				if list[k]["id"] == id and k > 0:
					prev = str(list[k - 1]["name"]).split(",")[0]
			_card_box.add_child(UiTheme.label("Open %s first." % prev, 19, UiTheme.MUTED))


func _country_card(cid: String) -> void:
	var cdef := GameState.country_def(cid)
	var cost := GameState.country_unlock_cost(cid)
	_card_title(str(cdef["name"]), "5 cities, paid in %s. Every city keeps earning while you're elsewhere." % cdef["currency"])
	if cost >= 0.0:
		var prev := GameState.previous_country(cid)
		var b := UiTheme.button("UNLOCK %s   %s" % [str(cdef["name"]).to_upper(), GameState.money(cost, prev)], 22, UiTheme.GOOD)
		b.custom_minimum_size = Vector2(0, 68)
		b.disabled = GameState.wallets.get(prev, 0.0) < cost
		b.pressed.connect(func():
			Sfx.play("unlock")
			_loading_go(GameState.unlock_country.bind(cid), str(GameState.country_def(cid)["cities"][0]["id"]),
				"Welcome to %s!" % cdef["name"])
			queue_free())
		_card_box.add_child(b)
	else:
		var prev := GameState.previous_country(cid)
		var last: String = GameState.country_def(prev)["cities"][-1]["id"]
		_card_box.add_child(UiTheme.label("Open %s first." % str(GameState.city_def(last)["name"]).split(",")[0] if GameState.country_unlocked(prev) else "Open %s first." % GameState.country_def(prev)["name"], 19, UiTheme.MUTED))


func _landmark_card(id: String) -> void:
	match id:
		"hometown":
			var open: bool = GameState.hometown.get("unlocked", false)
			_card_title("Hometown Garage", "Your own garage back home. Never resets with prestige: finish runs for Certs, Case Files and crafting materials." if open
				else "Your own garage back home. It opens when any city has %d bays." % Data.HOMETOWN_UNLOCK_BAYS)
			if open:
				_card_box.add_child(UiTheme.label("Run %d  ·  %s  ·  Bays %d / %d" % [GameState.ht_run(), Data.HOMETOWN_STAGES[GameState.ht_stage()]["name"],
					GameState.ht_bays_built(), GameState.ht_cap()], 18, UiTheme.CASH))
				var here := GameState.is_hometown()
				var go := UiTheme.button("YOU'RE HERE" if here else "GO", 22, Color("8a94ab") if here else UiTheme.ACCENT)
				go.custom_minimum_size = Vector2(0, 66)
				go.disabled = here
				go.pressed.connect(func(): go_to(Data.HOMETOWN_ID))
				_card_box.add_child(go)
		"events":
			_card_title("Events", "Special limited-time shops with their own cars and prizes. Coming soon!")


## v0.19w: run a big change (travel, new city / country) under the main screen's loading card.
func _loading_go(work: Callable, where: String, sub: String = "") -> void:
	var m := get_tree().current_scene
	if m != null and m.has_method("with_loading"):
		m.with_loading(work, where, sub)
	else:
		work.call()


func go_to(id: String) -> void:
	Sfx.play("click")
	_loading_go(GameState.go_to_city.bind(id), id)   # v0.19w: under the loading card (bound to GameState: this panel is gone by then)
	queue_free()


## Opens the prestige screen for that city (it shows what you get and asks to confirm).
func _on_prestige(id: String) -> void:
	var p := PrestigePanel.new()
	get_parent().add_child(p)
	p.setup(id)


# ================================================================ live bits

func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	_refresh_wallets()
	if _tab == 0:
		var sig := _signature()
		if sig != _sig:
			_sig = sig
			if _card.visible:
				_build_card()
		_canvas.labels.queue_redraw()   # incomes tick (twice a second is plenty; pan / zoom don't need it)
		# v0.19v perf: the world itself only redraws (re-bakes) when something opens
		var ws := _canvas.signature()
		if ws != _world_sig:
			_world_sig = ws
			_bake_world()
		_update_corners()


func _signature() -> String:
	var s := GameState.active_city + "|%s|%s" % [GameState.hometown.get("unlocked", false), str(GameState.unlocked_countries())]
	for id in GameState.cities.keys():
		s += "|%s%d" % [id, int(GameState.cities[id]["prestige"])]
	return s


func _refresh_wallets() -> void:
	var owned := GameState.unlocked_countries()
	if _wallets.get_child_count() != owned.size():
		for c in _wallets.get_children():
			c.queue_free()
		for cid in owned:
			var wl := UiTheme.display_label("", 24, UiTheme.CASH)
			wl.add_theme_color_override("font_outline_color", UiTheme.INK)
			wl.add_theme_constant_override("outline_size", 7)
			_wallets.add_child(wl)
	for k in owned.size():
		if k < _wallets.get_child_count():
			var l: Label = _wallets.get_child(k)
			l.text = GameState.money(GameState.wallets.get(owned[k], 0.0), owned[k])
