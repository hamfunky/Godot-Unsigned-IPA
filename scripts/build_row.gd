extends Control
## "Build the next bay" strip under the last bay (like Idle Miner's new shaft).
## v0.19i (Hamza): exactly one bay tall, with a dashed outline of the bay to come, so buying one turns the
## strip into the bay in place and nothing below jumps. Shine Bucks can buy a bay you can't afford yet and
## finish a running renovation (both ask for a second tap to confirm).

const UiTheme = preload("res://scripts/ui_theme.gd")
const Scenery = preload("res://scripts/scenery.gd")
const Data = preload("res://scripts/game_data.gd")
const HudMeta = preload("res://scripts/hud_meta.gd")
const BayCard = preload("res://scripts/bay_card.gd")

const HEIGHT := BayCard.HEIGHT   # v0.19i (was 130)
const CONFIRM_TIME := 3.0
const LANE_W := 96.0

var _press_pos := Vector2.ZERO
var _pressing := false
var _opened_at := -10.0   # when the lock was tapped (the open padlock fades out over the new strip)
var _confirm_at := -10.0  # first tap on a Shine Bucks button: tap again within CONFIRM_TIME to spend


var _opened_fx: Control


func _ready() -> void:
	custom_minimum_size = Vector2(0, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	# the padlock popping open after the tap, drawn over whatever the strip shows next
	_opened_fx = Control.new()
	_opened_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_opened_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_opened_fx.visible = false
	_opened_fx.draw.connect(func():
		var k := clampf((Time.get_ticks_msec() * 0.001 - _opened_at) / 0.9, 0.0, 1.0)
		var c := Vector2(size.x * 0.5, HEIGHT * 0.5 - k * 30.0)
		draw_padlock(_opened_fx, c, 40.0 + k * 10.0, minf(1.0, k * 4.0), 1.0 - k * k))
	add_child(_opened_fx)


func _process(_delta: float) -> void:
	# v0.19v perf: only while it's on screen (the strip sits under the last bay, often scrolled away)
	if is_visible_in_tree() and get_global_rect().intersects(get_viewport_rect().grow(40.0)):
		queue_redraw()
	_opened_fx.visible = Time.get_ticks_msec() * 0.001 - _opened_at < 0.9
	if _opened_fx.visible:
		_opened_fx.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_press_pos = event.position
		elif _pressing:
			_pressing = false
			if event.position.distance_to(_press_pos) < 16.0:
				_tap(event.position)


func _now() -> float:
	return Time.get_ticks_msec() * 0.001


func confirming() -> bool:
	return _now() - _confirm_at < CONFIRM_TIME


## Shine Bucks buttons ask for a second tap (so a stray tap never spends them).
func _gloss_tap(spend: Callable) -> void:
	if confirming():
		_confirm_at = -10.0
		if spend.call():
			Sfx.play("build_bay")
			Sfx.buzz(40)
	else:
		_confirm_at = _now()
		Sfx.play("click")


func _tap(pos: Vector2) -> void:
	if GameState.reno_needed() > 0:
		if GameState.reno_ready():
			# the timer ran out: tapping the lock finishes it
			if GameState.unlock_renovation():
				Sfx.play("unlock")
				Sfx.buzz(60)
				_opened_at = Time.get_ticks_msec() * 0.001
		elif not GameState.reno_running():
			if GameState.start_renovation():
				Sfx.play("reno_start")
				Sfx.buzz(30)
		elif _ad_rect().has_point(pos):
			if GameState.watch_reno_ad():
				Sfx.play("boost")
		elif _finish_rect().has_point(pos) and GameState.reno_finish_cost() > 0:
			_gloss_tap(func(): return GameState.finish_reno_gloss())
			if not GameState.reno_running():
				_opened_at = _now()
		return
	if _show_gloss_buy() and _sb_rect().has_point(pos):
		_gloss_tap(func(): return GameState.buy_bay_gloss())
		return
	var n := GameState.bays.size()
	GameState.buy_bay()
	if GameState.bays.size() > n:
		Sfx.play("build_bay")
		Sfx.buzz(30)


func _ad_rect() -> Rect2:
	return Rect2(size.x - 210, 22, 190, 82)


func _finish_rect() -> Rect2:
	return Rect2(20, 116, size.x - 40, 56)


func _build_rect() -> Rect2:
	return Rect2(size.x * 0.5 - 200, 34 if _show_gloss_buy() else 54, 400, 78)


func _sb_rect() -> Rect2:
	return Rect2(size.x * 0.5 - 150, 120, 300, 50)


## The "or X Shine Bucks" button shows when the bay is out of reach with cash.
func _show_gloss_buy() -> bool:
	var cost := GameState.next_bay_cost()
	if GameState.tutorial_step != GameState.TUT_DONE:
		return false   # not during the tutorial (keeps a new player's first screen simple)
	return GameState.reno_needed() == 0 and cost >= 0.0 and GameState.cash < cost and GameState.bay_gloss_cost() > 0


## A Shine Bucks button: "<label>  [icon] N", greyed when you can't pay, "TAP AGAIN" while confirming.
func _draw_gloss_button(r: Rect2, label: String, price: int) -> void:
	var can: bool = GameState.gloss >= price
	var conf := confirming()
	_lip_button(r, Color("7e57c2") if can else Color("8a94ab"))
	var fs := 21
	if conf and can:
		UiTheme.text(self, r.position + Vector2(0, r.size.y * 0.5 + 8), "TAP AGAIN TO CONFIRM", fs, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 5, UiTheme.DISPLAY_FONT)
		return
	var f: Font = UiTheme.DISPLAY_FONT
	var t2 := str(price)
	var w1 := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w2 := f.get_string_size(t2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var total := w1 + 14 + 34 + 6 + w2
	var x := r.get_center().x - total * 0.5
	var y := r.position.y + r.size.y * 0.5 + 8
	UiTheme.text(self, Vector2(x, y), label, fs, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 5, UiTheme.DISPLAY_FONT)
	HudMeta.draw_droplet(self, Vector2(x + w1 + 14 + 17, r.get_center().y), 11.0)
	UiTheme.text(self, Vector2(x + w1 + 14 + 40, y), t2, fs, Color("a8f5d6") if can else Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_LEFT, -1, 5, UiTheme.DISPLAY_FONT)


## A renovation stands between you and the next bay (like Idle Miner's rock barriers).
func _draw_renovation(w: float) -> void:
	var k := GameState.reno_needed()
	var title := GameState.reno_name(k)
	# boarded-up wall
	draw_rect(Rect2(0, 0, w, HEIGHT), Color("4e3b2a"))
	for x in range(0, int(w), 64):
		draw_rect(Rect2(x + 4, 8, 56, HEIGHT - 16), Color("6d5440"))
		draw_line(Vector2(x + 4, 20), Vector2(x + 60, HEIGHT - 20), Color("4e3b2a"), 4)
	if GameState.reno_ready():
		_draw_lock(w, title)
		return
	if not GameState.reno_running():
		var cost := GameState.reno_cost()
		var can: bool = GameState.cash >= cost
		# reads as the obvious next step: BEGIN RENOVATION, what it builds, then the price
		var btn := Rect2(w * 0.5 - 250, (HEIGHT - 106) * 0.5, 500, 106)
		var bc := Color("ff9a2e") if can else Color("8a94ab")
		_lip_button(btn, bc)
		UiTheme.text(self, btn.position + Vector2(0, 36), "BEGIN RENOVATION", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, btn.size.x, 6, UiTheme.DISPLAY_FONT)
		var sub := ("Becomes a " + title) if GameState.is_hometown() else title
		UiTheme.text(self, btn.position + Vector2(0, 64), sub, 19, Color("fff3e0"), HORIZONTAL_ALIGNMENT_CENTER, btn.size.x, 4)
		var eta := GameState.eta_text(cost)
		UiTheme.text(self, btn.position + Vector2(0, 94), "%s%s  ·  takes %s" % [GameState.money(cost), (" (%s)" % eta) if eta != "" else "", GameState.fmt_time(GameState.reno_seconds(k)).trim_suffix(" 0m")], 20,
			UiTheme.CASH if can else Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, btn.size.x, 5)
		return
	# in progress (v0.17g): scaffolding over the boards, a little dust, a bobbing hammer, then the countdown card
	_draw_scaffold(w)
	var box := Rect2(20, 16, w - 250, 88)
	UiTheme.rounded(self, Rect2(box.position + Vector2(0, 5), box.size), Color("b35f00"), 16, 3, UiTheme.INK)
	UiTheme.rounded(self, box, Color("ff9a2e"), 16, 3, UiTheme.INK)
	UiTheme.rounded(self, Rect2(box.position + Vector2(12, 6), Vector2(box.size.x - 24, 8)), Color(1, 1, 1, 0.25), 4)
	_draw_hammer(box.position + Vector2(44, 46))
	UiTheme.text(self, box.position + Vector2(60, 34), title, 19, Color("fff3e0"), HORIZONTAL_ALIGNMENT_CENTER, box.size.x - 70, 5)
	UiTheme.text(self, box.position + Vector2(60, 70), GameState.fmt_time(GameState.reno_left()) + " left", 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, box.size.x - 70, 6, UiTheme.DISPLAY_FONT)
	var ar := _ad_rect()
	var ads := GameState.reno_ads_left()
	_lip_button(ar, UiTheme.GOOD if ads > 0 else Color("8a94ab"))
	UiTheme.text(self, ar.position + Vector2(0, 34), "SKIP 30 MIN" if GameState.ad_free() else "WATCH AD", 19, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, ar.size.x, 4)
	UiTheme.text(self, ar.position + Vector2(0, 62), ("-30 min  (%d left)" % ads) if ads > 0 else "%d per hour" % Data.RENO_ADS_PER_HOUR, 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, ar.size.x, 4)
	# v0.19i (Hamza): Shine Bucks always finish the WHOLE renovation (stays expensive, no partial skips)
	var fc := GameState.reno_finish_cost()
	if fc > 0:
		_draw_gloss_button(_finish_rect(), "FINISH NOW", fc)


## Steel scaffolding across the boarded wall, with puffs of dust drifting up (renovation running).
func _draw_scaffold(w: float) -> void:
	var pipe := Color("9aa7b8")
	for x in range(30, int(w), 130):
		draw_rect(Rect2(x - 4, 0, 8, HEIGHT), UiTheme.INK)
		draw_rect(Rect2(x - 2, 0, 4, HEIGHT), pipe)
	for y in [14.0, 64.0, 114.0, 164.0]:
		draw_rect(Rect2(0, y - 4, w, 8), UiTheme.INK)
		draw_rect(Rect2(0, y - 2, w, 4), pipe)
	var t := Time.get_ticks_msec() * 0.001
	for k in 4:
		var ph := fposmod(t * 0.4 + k * 0.25, 1.0)
		var px := fposmod(k * 211.0 + 90.0, w)
		draw_circle(Vector2(px + sin(t + k) * 6.0, HEIGHT - 10 - ph * 50.0), 8.0 + ph * 10.0, Color(0.95, 0.88, 0.75, 0.35 * (1.0 - ph)))


## A little hammer tapping away.
func _draw_hammer(c: Vector2) -> void:
	var a := -0.6 + 0.6 * absf(sin(Time.get_ticks_msec() * 0.008))
	draw_set_transform(c, a, Vector2.ONE)
	draw_rect(Rect2(-3, -6, 6, 30), UiTheme.INK)
	draw_rect(Rect2(-1.5, -5, 3, 28), Color("c98a4b"))
	UiTheme.rounded(self, Rect2(-14, -16, 28, 13), Color("b0bccf"), 4, 2, UiTheme.INK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Renovation finished: a big padlock to tap.
func _draw_lock(w: float, title: String) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var bob := sin(t * 3.0) * 3.0
	var box := Rect2(w * 0.5 - 250, (HEIGHT - 106) * 0.5, 500, 106)
	_lip_button(box, UiTheme.GOOD)
	draw_padlock(self, Vector2(box.position.x + 70, box.position.y + 58 + bob), 34.0, 0.0)
	UiTheme.text(self, box.position + Vector2(120, 44), "TAP TO UNLOCK", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 130, 6, UiTheme.DISPLAY_FONT)
	var sub := ("Your %s is ready" % title) if GameState.is_hometown() else ("%s is ready" % title)
	UiTheme.text(self, box.position + Vector2(120, 80), sub, 19, Color("e8f5e9"), HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 130, 4)


## Padlock centred on c, about s px tall; open = 0 (locked) .. 1 (shackle up and to the side).
static func draw_padlock(ci: CanvasItem, c: Vector2, s: float, open: float, alpha: float = 1.0) -> void:
	var gold := Color(1.0, 0.8, 0.25, alpha)
	var dark := Color(0.55, 0.38, 0.05, alpha)
	var steel := Color(0.85, 0.87, 0.9, alpha)
	var body := Rect2(c + Vector2(-s * 0.55, -s * 0.05), Vector2(s * 1.1, s * 0.85))
	# shackle: an arc, lifted and swung open
	var sc := c + Vector2(open * s * 0.35, -s * 0.05 - open * s * 0.3)
	ci.draw_arc(sc, s * 0.36, PI, TAU, 18, steel, s * 0.14, true)
	ci.draw_line(sc + Vector2(-s * 0.36, 0), sc + Vector2(-s * 0.36, s * 0.12), steel, s * 0.14)
	ci.draw_line(sc + Vector2(s * 0.36, 0), sc + Vector2(s * 0.36, s * 0.12 + (1.0 - open) * s * 0.05), steel, s * 0.14)
	UiTheme.rounded(ci, body, gold, int(s * 0.18), 3, dark)
	ci.draw_circle(body.get_center() + Vector2(0, -s * 0.06), s * 0.12, dark)
	ci.draw_rect(Rect2(body.get_center() + Vector2(-s * 0.04, -s * 0.04), Vector2(s * 0.08, s * 0.22)), dark)


func _draw() -> void:
	var w := size.x
	var cost := GameState.next_bay_cost()
	# earth with pebbles (the ground the next bay gets dug into)
	draw_rect(Rect2(0, 0, w, HEIGHT), Color("8a6a4a"))
	draw_rect(Rect2(0, 0, w, 6), Color("6e5238"))
	for k in 34:
		var px := fposmod(k * 97.0, w)
		var py := fposmod(k * 53.0, HEIGHT - 12) + 8
		var r := 3.0 + (k % 4)
		draw_circle(Vector2(px, py + 1), r, Color("5e4630"))
		draw_circle(Vector2(px, py), r, Color("a5825c") if k % 3 else Color("9a9a9a"))
	if GameState.reno_needed() > 0:
		_draw_renovation(w)
		return
	if cost < 0.0:
		var t := "All bays built! Upgrade this city or expand on the MAP."
		if GameState.is_hometown():
			t = "All %d bays built! Max every station to finish the run (tap the sign)." % GameState.ht_cap()
		_draw_back_lot(w, t)
		return
	var can := GameState.cash >= cost
	# construction tape
	for x in range(0, int(w), 40):
		draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 20, 0), Vector2(x + 10, 12), Vector2(x - 10, 12)]), Color("ffcc00"))
	_draw_bay_outline(w)
	var btn := _build_rect()
	_lip_button(btn, UiTheme.GOOD if can else Color("8a94ab"))
	UiTheme.text(self, btn.position + Vector2(0, 33), "Build Bay %d" % (GameState.bays.size() + 1), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, btn.size.x, 6, UiTheme.DISPLAY_FONT)
	var eta := GameState.eta_text(cost)   # v0.19m: a goal you can see coming
	UiTheme.text(self, btn.position + Vector2(0, 63), GameState.money(cost) + (("  ·  " + eta) if eta != "" else ""), 24 if eta == "" else 22,
		UiTheme.CASH if can else Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER, btn.size.x, 6)
	if _show_gloss_buy():
		_draw_gloss_button(_sb_rect(), "or", GameState.bay_gloss_cost())


## v0.19u: once every bay is built, the space under the shop is the back lot (was plain dirt): asphalt with
## painted lines, a skip bin, a stack of tyres, a pallet of product and a painted sign with the message.
func _draw_back_lot(w: float, msg: String) -> void:
	var ink := UiTheme.INK
	Scenery.vgrad(self, Rect2(0, 0, w, HEIGHT), Color("5b606c"), Color("494d58"))
	for k in 22:   # speckles
		draw_circle(Vector2(fposmod(k * 83.0, w), fposmod(k * 47.0, HEIGHT - 10) + 5), 1.5 + (k % 3) * 0.6, Color(1, 1, 1, 0.06) if k % 2 == 0 else Color(0, 0, 0, 0.12))
	draw_rect(Rect2(0, 0, w, 8), Color("3a3e48"))
	for x in range(int(LANE_W) + 40, int(w), 120):   # parking lines
		draw_rect(Rect2(x, HEIGHT - 58, 5, 52), Color(1, 1, 1, 0.45))
	# skip bin (left)
	var sb := Rect2(LANE_W + 14, HEIGHT - 70, 96, 52)
	draw_colored_polygon(PackedVector2Array([sb.position, Vector2(sb.end.x, sb.position.y), Vector2(sb.end.x - 10, sb.end.y), Vector2(sb.position.x + 10, sb.end.y)]), Color("2f9e5a"))
	draw_polyline(PackedVector2Array([sb.position, Vector2(sb.end.x, sb.position.y), Vector2(sb.end.x - 10, sb.end.y), Vector2(sb.position.x + 10, sb.end.y), sb.position]), ink, 3.0, true)
	draw_rect(Rect2(sb.position.x + 6, sb.position.y + 10, sb.size.x - 12, 4), Color(1, 1, 1, 0.25))
	for k in 3:   # bits sticking out
		draw_rect(Rect2(sb.position.x + 14 + k * 26, sb.position.y - 8 + (k % 2) * 4, 18, 10), [Color("c98b4f"), Color("90a4ae"), Color("ffd23f")][k])
	# tyre stack (right)
	var tx := w - 150.0
	for k in 3:
		var ty := HEIGHT - 22.0 - k * 16.0
		draw_set_transform(Vector2(tx, ty), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 26.0, ink)
		draw_circle(Vector2.ZERO, 23.0, Color("2b2d33"))
		draw_circle(Vector2.ZERO, 11.0, Color("15161a"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# pallet of product boxes (middle right)
	var px := w - 250.0
	UiTheme.rounded(self, Rect2(px, HEIGHT - 22, 70, 10), Color("c98b4f"), 2, 2, ink)
	for k in 2:
		UiTheme.rounded(self, Rect2(px + 4 + k * 32, HEIGHT - 50, 30, 28), Color("d39a5e"), 3, 2, ink)
		draw_rect(Rect2(px + 4 + k * 32 + 12, HEIGHT - 50, 6, 28), Color("e8553d"))
	# painted sign board with the message
	var sr := Rect2(LANE_W + 130, 18, w - LANE_W - 140 - 90, 56)
	UiTheme.rounded(self, Rect2(sr.position + Vector2(0, 4), sr.size), Color(0, 0, 0, 0.3), 10)
	UiTheme.rounded(self, sr, Color("fff4d6"), 10, 3, ink)
	UiTheme.text(self, Vector2(sr.position.x + 8, sr.position.y + 24), msg.split("!")[0] + "!", 20, Color("e8553d"), HORIZONTAL_ALIGNMENT_CENTER, sr.size.x - 16, 0, UiTheme.DISPLAY_FONT)
	UiTheme.text(self, Vector2(sr.position.x + 8, sr.position.y + 46), msg.split("!")[1].strip_edges() if msg.count("!") > 0 else "", 16, Color("5d4037"), HORIZONTAL_ALIGNMENT_CENTER, sr.size.x - 16, 0)


## v0.19i: a dashed outline of the bay that will be built here (its band on top + the room), exactly its size.
func _draw_bay_outline(w: float) -> void:
	var r := Rect2(LANE_W + 6, 16, w - LANE_W - 14, HEIGHT - 24)
	var col := Color(1, 1, 1, 0.55)
	_dashed(Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), col)
	_dashed(Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y), col)
	_dashed(Vector2(r.end.x, r.end.y), Vector2(r.position.x, r.end.y), col)
	_dashed(Vector2(r.position.x, r.end.y), Vector2(r.position.x, r.position.y), col)
	_dashed(Vector2(r.position.x, r.position.y + BayCard.BAND_H - 14), Vector2(r.end.x, r.position.y + BayCard.BAND_H - 14), Color(1, 1, 1, 0.3))


func _dashed(a: Vector2, b: Vector2, col: Color) -> void:
	var d := b - a
	var n := int(d.length() / 16.0)
	for k in n:
		draw_line(a + d * (float(k) / n), a + d * ((k + 0.55) / n), col, 3.0)


## Chunky cartoon button drawn on the strip (same look as UiTheme.button).
static var _lips := {}

func _lip_button(r: Rect2, c: Color) -> void:
	if not _lips.has(c):
		_lips[c] = UiTheme.lip_box(c)   # v0.19v: made once per colour, not every frame
	draw_style_box(_lips[c], r)
	draw_style_box(UiTheme.flat(Color(1, 1, 1, 0.22), 6), Rect2(r.position + Vector2(12, 6), Vector2(r.size.x - 24, 12)))
