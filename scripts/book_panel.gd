extends "res://scripts/sheet.gd"
## The Book: every car you've detailed, your reputation, and your display.
## v0.17g (Hamza): the front page is the showroom (reputation + display) and a grid of CATEGORY tiles
## (Bombs ... Exotics, Rare Visitors), each with its "X / Y" and a NEW count. Tap a tile to see its cars.
## A car counts as seen as soon as its category page has been on screen (no tapping needed); its NEW
## sticker stays for that visit so you can spot it.

const Data = preload("res://scripts/game_data.gd")
const CarCard = preload("res://scripts/car_card.gd")
const HudMeta = preload("res://scripts/hud_meta.gd")
const CarView = preload("res://scripts/car_view.gd")

const RARE := 6   # "tier" of the Rare Visitors category

var _rep: Label
var _slots: GridContainer
var _slot_btn: Button
var _display_sig := ""
var _page := 0               # 0 = front page, 1-5 = car tiers, 6 = rare visitors
var _tiles: Array = []       # front page category tiles
var _live_box: VBoxContainer = null   # v0.19j: what the cars on show do right now (category pages), as chains
var _live_sig := ""


## A category tile on the front page: name, a car picture, X / Y, NEW count.
class CategoryTile extends Control:
	const UT = preload("res://scripts/ui_theme.gd")
	const CV = preload("res://scripts/car_view.gd")
	const DA = preload("res://scripts/game_data.gd")
	signal pressed(tier: int)
	var tier := 1
	var title := ""
	var _press := Vector2.ZERO
	var _down := false

	func _ready() -> void:
		custom_minimum_size = Vector2(0, 150)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _process(_d: float) -> void:
		queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_down = true
				_press = e.position
			elif _down:
				_down = false
				if e.position.distance_to(_press) < 16.0:
					Sfx.play("click")
					pressed.emit(tier)

	func _cars() -> Array:
		return DA.VIP_CARS if tier == 6 else DA.CARS.filter(func(c): return c["tier"] == tier)

	func _draw() -> void:
		var rare := tier == 6
		var cnt := GameState.book_count(tier)
		var done: bool = not rare and GameState.tiers_done.has(tier)
		var col := Color("f5a300") if rare else (Color("3ccf5a") if done else Color("8e5bd9"))
		var r := Rect2(Vector2.ZERO, size)
		var inner := Rect2(0, 0, size.x, size.y - 7)
		UT.rounded(self, r, col.darkened(0.45), 16, 3, UT.INK)
		UT.rounded(self, inner, col, 16, 3, UT.INK)
		UT.rounded(self, Rect2(10, 6, size.x - 20, 8), Color(1, 1, 1, 0.25), 4)
		# picture: the best car you have in it (silhouette until you have one)
		var pick: Dictionary = {}
		for c in _cars():
			if GameState.book.has(c["id"]):
				pick = c
		var pic := Rect2(size.x * 0.5 - 70, 18, 140, 58)
		UT.rounded(self, pic.grow(6), Color(1, 1, 1, 0.3), 26)
		if pick.is_empty():
			var c0: Dictionary = _cars()[0]
			CV.draw_car(self, pic, Color(0, 0, 0, 0.35), 0.0, [], 0.0, true, GameState.car_def(c0["id"]))
		else:
			CV.draw_car(self, pic, CV.book_color(pick), 0.0, [], 0.0, false, GameState.car_def(pick["id"]))
		UT.text(self, Vector2(0, 104), title, 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, size.x, 6, UT.DISPLAY_FONT)
		var sub := "%d / %d" % [cnt[0], cnt[1]] + ("  ·  DONE" if done else "")
		UT.text(self, Vector2(0, 129), sub, 17, Color("fff3c4"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 4)
		var n := GameState.book_new_count(tier)
		if n > 0:
			var wob := sin(Time.get_ticks_msec() * 0.006) * 2.0
			var nr := Rect2(size.x - 88, 6 + wob, 80, 28)
			UT.rounded(self, nr, Color("ff5a5f"), 12, 3, UT.INK)
			UT.text(self, Vector2(nr.position.x, nr.position.y + 21), "%d NEW" % n, 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, nr.size.x, 4, UT.DISPLAY_FONT)


func setup() -> void:
	set_finish("carbon")   # v0.19u
	_show_page(0)


func _show_page(p: int) -> void:
	_page = p
	_display_sig = ""
	_tiles = []
	_rep = null
	_slots = null
	_slot_btn = null
	_live_box = null
	_live_sig = ""
	clear_body()
	if p == 0:
		_build_front()
	else:
		_build_category(p)
	_refresh()


# ---------------------------------------------------------------- front page

func _build_front() -> void:
	set_title("Your Book")
	# the showroom card: reputation, the display and what it does
	var show := PanelContainer.new()
	show.add_theme_stylebox_override("panel", UiTheme.card(Color("7d4bd1"), 22, 14, UiTheme.INK))
	body.add_child(show)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	show.add_child(sv)
	_rep = UiTheme.outlined(UiTheme.label("", 19, Color("fff3c4")), 5)
	_rep.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sv.add_child(_rep)
	sv.add_child(UiTheme.ribbon("ON DISPLAY  ·  pick cars to show off inside a category", 15, Color("f5a300")))
	_slots = GridContainer.new()
	_slots.add_theme_constant_override("h_separation", 8)
	_slots.add_theme_constant_override("v_separation", 8)
	sv.add_child(_slots)
	var why := UiTheme.outlined(UiTheme.label("Cars on show bring you followers every hour, and a rare car on show visits %dx more often." % int(Data.VIP_DISPLAY_WEIGHT), 16, Color("efe6ff")), 4)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sv.add_child(why)
	_slot_btn = UiTheme.button("", 18, Color("0277bd"))
	_slot_btn.custom_minimum_size = Vector2(0, 50)
	_slot_btn.pressed.connect(GameState.buy_display_slot)
	body.add_child(_slot_btn)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	body.add_child(grid)
	for t in range(1, Data.TIER_NAMES.size()):
		grid.add_child(_tile(t, Data.TIER_NAMES[t]))
	grid.add_child(_tile(RARE, "Rare Visitors"))


func _tile(t: int, title: String) -> Control:
	var tile := CategoryTile.new()
	tile.tier = t
	tile.title = title
	tile.pressed.connect(_show_page)
	_tiles.append(tile)
	return tile


# ---------------------------------------------------------------- a category

func _build_category(t: int) -> void:
	set_title(Data.TIER_NAMES[t] if t < RARE else "Rare Visitors")
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	body.add_child(top)
	var back := UiTheme.button("<  BOOK", 20, Color("8e5bd9"))
	back.custom_minimum_size = Vector2(150, 54)
	back.pressed.connect(func(): _show_page(0))
	top.add_child(back)
	var info := UiTheme.rich_label("", 17, Color("fff3c4"), 4, false, false)   # v0.19v: rich (Shine Bucks icon)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(info)
	# v0.17h (playtest): what's on show, right here too (tap one to take it off)
	var show := PanelContainer.new()
	show.add_theme_stylebox_override("panel", UiTheme.card(Color("7d4bd1"), 20, 12, UiTheme.INK))
	body.add_child(show)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 6)
	show.add_child(sv)
	sv.add_child(UiTheme.ribbon("ON SHOW  ·  tap a car below to show it, tap here to take it off", 15, Color("f5a300")))
	_slots = GridContainer.new()
	_slots.add_theme_constant_override("h_separation", 8)
	_slots.add_theme_constant_override("v_separation", 8)
	sv.add_child(_slots)
	# v0.19j (playtest: "why does it matter what cars?"): the live effect of what's on show; it changes as you swap cars
	var lp := PanelContainer.new()
	lp.add_theme_stylebox_override("panel", UiTheme.card(Color("5a2fa8"), 14, 10, UiTheme.INK))
	sv.add_child(lp)
	_live_box = VBoxContainer.new()
	_live_box.add_theme_constant_override("separation", 8)
	lp.add_child(_live_box)
	var cnt := GameState.book_count(t)
	if t < RARE:
		UiTheme.set_bb(info, "%d / %d  ·  %s" % [cnt[0], cnt[1], ("DONE: x%s income" % str(Data.TIER_SET_INCOME_BONUS)) if GameState.tiers_done.has(t)
			else "collect all: +%d {sb}, x%s income" % [Data.TIER_SET_GLOSS, str(Data.TIER_SET_INCOME_BONUS)]])
	else:
		UiTheme.set_bb(info, "%d / %d  ·  every country has its own. Tap one you own to put it on show." % [cnt[0], cnt[1]])
	var seen: Array = []
	if t < RARE:
		body.add_child(_grid(Data.CARS.filter(func(c): return c["tier"] == t), seen))
	else:
		for cdef in Data.COUNTRIES:
			var cars := Data.VIP_CARS.filter(func(c): return c.get("country", "usa") == cdef["id"])
			var cc := GameState.book_count(RARE, cdef["id"])
			var txt := "%s   %d/%d" % [cdef["name"], cc[0], cc[1]]
			if not GameState.country_unlocked(cdef["id"]):
				txt += "   (visit %s to find them)" % cdef["name"]
			body.add_child(UiTheme.ribbon(txt, 17, Color("e0a000")))
			body.add_child(_grid(cars, seen))
	# just looking counts: these cars lose their NEW sticker next time (it stays up for this visit)
	GameState.mark_cars_seen(seen)


func _grid(cars: Array, seen: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for c in cars:
		var card := CarCard.new()
		card.car_id = c["id"]
		card.is_new = GameState.book_new.has(c["id"])
		if card.is_new:
			seen.append(c["id"])
		card.pressed.connect(_on_card)
		grid.add_child(card)
	return grid


func _on_card(id: String) -> void:
	if not GameState.book.has(id):
		return
	if not GameState.display.has(id) and GameState.display.size() >= GameState.display_slots():
		return
	GameState.toggle_display(id)


func _on_slot(id: String) -> void:
	if id != "":
		GameState.toggle_display(id)


func _process(_delta: float) -> void:
	# a car logged while its own category is open counts as seen straight away
	if _page != 0 and not GameState.book_new.is_empty():
		var ids: Array = []
		for id in GameState.book_new.keys():
			var c := GameState.car_def(id)
			if (_page == RARE and c.get("vip", false)) or (_page < RARE and not c.get("vip", false) and int(c["tier"]) == _page):
				ids.append(id)
		if not ids.is_empty():
			GameState.mark_cars_seen(ids)
	_refresh()


func _refresh() -> void:
	if _slots == null:
		return
	var nxt := GameState.next_star_followers()
	if _rep != null:
		_rep.text = "%s  ·  %s followers%s\nOn show: +%s followers/hour  ·  Rating gives x%s bay income" % [
		GameState.rating_line(), GameState.fmt(GameState.followers),
		(("  ·  next half star at " if GameState.has_reviews() else "  ·  first review at ") + GameState.fmt(nxt)) if nxt > 0.0 else "",
			GameState.fmt(GameState.display_followers_per_hour()), "%.2f" % GameState.reputation_mult()]
		var cw := GameState.car_of_week()   # v0.19t
		if cw != "":
			_rep.text += "\nCar of the week here: %s (pays x%d, +%d followers)" % [GameState.car_def(cw)["name"], int(Data.COTW_PAY_MULT), int(Data.COTW_FOLLOWERS)]

	if _live_box != null:
		var lt := live_text()
		if lt != _live_sig:
			_live_sig = lt
			_build_live()

	var sig := str(GameState.display) + str(GameState.display_slots())
	if sig != _display_sig:
		_display_sig = sig
		for c in _slots.get_children():
			c.queue_free()
		_slots.columns = clampi(GameState.display_slots(), 1, 4)
		for k in GameState.display_slots():
			var card := CarCard.new()
			card.car_id = GameState.display[k] if k < GameState.display.size() else ""
			card.custom_minimum_size = Vector2(0, 132)
			card.pressed.connect(_on_slot)
			_slots.add_child(card)

	if _slot_btn == null:
		return
	if GameState.bought_slots >= Data.MAX_BOUGHT_SLOTS:
		_slot_btn.disabled = true
		UiTheme.set_rich(_slot_btn, "All extra display slots bought")
	else:
		_slot_btn.disabled = GameState.gloss < Data.SLOT_COST
		UiTheme.set_rich(_slot_btn, "+1 display slot   %d {sb}" % Data.SLOT_COST)   # v0.19v: icon


## v0.19j: what the cars on show are doing for you right now, as chains of chips (mockup book_mockup_v1):
##   followers:  [+X followers/hour] » next half star in ~Y » [xN bay income]
##   customers:  [JDM customers 33% (+16%)] » your 2 JDM Crew managers (Bay 1, Bay 3) earn x1.5 on them
## Each part is [kind, text, colour]: kind "chip" (rounded tag), "txt" or "arr".
static func live_rows() -> Array:
	var gs = GameState
	var rows: Array = []
	var fph: float = gs.display_followers_per_hour()
	var nxt: float = gs.next_star_followers()
	var mult: float = gs.reputation_mult()
	var r1: Array = [["chip", "+%s followers/hour" % gs.fmt(fph), Color("fff3c4")]]
	if nxt > 0.0 and fph > 0.0:
		var secs := maxf(0.0, nxt - gs.followers) / fph * 3600.0
		r1.append(["arr", "»", Color.WHITE])
		r1.append(["txt", ("next half star in ~%s" if gs.has_reviews() else "first review in ~%s") % (("%d days" % roundi(secs / 86400.0)) if secs >= 2.0 * 86400.0 else gs.fmt_time(secs)), Color.WHITE])
		r1.append(["arr", "»", Color.WHITE])
		r1.append(["chip", "x%.2f bay income" % (mult * Data.STAR_INCOME_BONUS), Color("ffca28")])
		r1.append(["txt", "(now x%.2f)" % mult, Color("d9c9ff")])
	else:
		r1.append(["txt", "%s = x%.2f bay income" % [gs.rating_line(), mult], Color.WHITE])
	rows.append(r1)
	# customer mix: the share of each shown car's type now vs with nothing on show
	var w: Dictionary = gs.class_weights()
	var total := 0.0
	var base := {}
	var base_total := 0.0
	var bias: Dictionary = gs.country_def(gs.country)["bias"]
	for c in Data.CAR_CLASSES:
		total += float(w.get(c, 0.0))
		base[c] = 1.0 + float(bias.get(c, 0.0))
		base_total += base[c]
	var shown := []
	var rare := false
	for id in gs.display:
		var cd: Dictionary = gs.car_def(id)
		if cd.get("vip", false):
			rare = true
		if not shown.has(cd["class"]):
			shown.append(cd["class"])
	for c in Data.CAR_CLASSES:
		if not shown.has(c) or total <= 0.0:
			continue
		var now := float(w[c]) / total
		var was := float(base[c]) / base_total
		var cname: String = Data.CLASS_NAMES[c]
		var r: Array = [["chip", "%s customers %d%% (+%d%%)" % [cname, roundi(now * 100.0), roundi((now - was) * 100.0)], gs.class_color(c)], ["arr", "»", Color.WHITE]]
		var cb: Array = gs.crew_bays(c)
		var bonus: float = gs.specialist_bonus(c)
		var bx := str(int(bonus)) if is_equal_approx(bonus, roundf(bonus)) else "%.1f" % bonus
		if cb.is_empty():
			r.append(["txt", "hire a %s Crew manager for a bay to earn x%s on these" % [cname, bx], Color("d9c9ff")])
		else:
			var names: Array = cb.map(func(i): return "Bay %d" % (i + 1))
			r.append(["txt", "your %d %s Crew manager%s (%s) earn x%s on them" % [cb.size(), cname, "" if cb.size() == 1 else "s", ", ".join(names), bx], Color("ffd23f")])
		rows.append(r)
	if shown.is_empty():
		rows.append([["txt", "Cars on show also bring in more customers of their type (JDM, Euro, Muscle, 4x4), and crew managers earn x%s on their own type." % str(Data.CREW_SPECIALIST_BONUS), Color("d9c9ff")]])
	if rare:
		rows.append([["txt", "Rare car on show: it visits %dx more often." % int(Data.VIP_DISPLAY_WEIGHT), Color("ffd23f")]])
	return rows


## The chains as plain text (one line per row).
static func live_text() -> String:
	var lines: Array = []
	for r in live_rows():
		lines.append(" ".join(r.map(func(p): return str(p[1]))))
	return "\n".join(lines)


func _build_live() -> void:
	for c in _live_box.get_children():
		_live_box.remove_child(c)
		c.queue_free()
	for r in live_rows():
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 4)
		_live_box.add_child(flow)
		for p in r:
			var col: Color = p[2]
			if p[0] == "chip":
				var l := UiTheme.label(str(p[1]), 16, UiTheme.INK if col.get_luminance() > 0.6 else Color.WHITE)
				l.add_theme_font_override("font", UiTheme.DISPLAY_FONT)
				if col.get_luminance() <= 0.6:
					UiTheme.outlined(l, 4)
				l.add_theme_stylebox_override("normal", UiTheme.card(col, 11, 4, UiTheme.INK))
				flow.add_child(l)
			elif p[0] == "arr":
				var a := UiTheme.outlined(UiTheme.label(str(p[1]), 20, Color("ffd23f")), 4)
				a.add_theme_font_override("font", UiTheme.DISPLAY_FONT)
				flow.add_child(a)
			else:
				# plain text words flow one by one so a long line wraps naturally inside the chain
				for word in str(p[1]).split(" ", false):
					flow.add_child(UiTheme.outlined(UiTheme.label(word, 17, col), 4))
