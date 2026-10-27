extends Control
## Builds the whole screen in code:
##   HUD (cash, idle income + bottleneck, premium currency, reputation)
##   scrolling shop: Front Desk, Valet, Bay 1..N, Build next bay
##   bottom bar: Shop, Book, BOOST (total multiplier + timer), Info, Map
## plus popups (level panel, managers, shop, Book, welcome back),
## the rare car alert banner and a queue of toasts.

const Data = preload("res://scripts/game_data.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")
const BayCard = preload("res://scripts/bay_card.gd")
const ValetRow = preload("res://scripts/valet_row.gd")
const DeskRow = preload("res://scripts/desk_row.gd")
const Scenery = preload("res://scripts/scenery.gd")
const BuildRow = preload("res://scripts/build_row.gd")
const LaneOverlay = preload("res://scripts/lane_overlay.gd")
const HudMeta = preload("res://scripts/hud_meta.gd")
const HudMoney = preload("res://scripts/hud_money.gd")
const TROPHY_BOX := 84.0     # v0.19f: the prestige trophy, top middle of the HUD
const CITY_W := 146.0        # v0.19j: room for the city name under the trophy (between the left + right pills)
const LevelPanel = preload("res://scripts/level_panel.gd")
const ManagerPanel = preload("res://scripts/manager_panel.gd")
const ShopPanel = preload("res://scripts/shop_panel.gd")
const DeliveryPanel = preload("res://scripts/delivery_panel.gd")   # v0.19t
const BookPanel = preload("res://scripts/book_panel.gd")
const TutorialOverlay = preload("res://scripts/tutorial_overlay.gd")
const WorkshopPanel = preload("res://scripts/workshop_panel.gd")   # premises / prestige for this city
const MapPanel = preload("res://scripts/map_panel.gd")
const OverviewPanel = preload("res://scripts/overview_panel.gd")
const BoostPanel = preload("res://scripts/boost_panel.gd")
const HometownPanel = preload("res://scripts/hometown_panel.gd")
const UiIcons = preload("res://scripts/ui_icons.gd")
const DepthRow = preload("res://scripts/depth_row.gd")
const TitleScreen = preload("res://scripts/title_screen.gd")
const LoadingScreen = preload("res://scripts/loading_screen.gd")   # v0.19w: between cities
const InfoPanel = preload("res://scripts/info_panel.gd")
const TipOverlay = preload("res://scripts/tip_overlay.gd")
const SkyRow = preload("res://scripts/sky_row.gd")              # v0.19v: taller sky over the shop (Lucky Wheel)
const AdBoostButton = preload("res://scripts/ad_boost_button.gd")   # v0.19v: big AD BOOST in the bottom bar

var _cash_label: Label
var _city_label: Label
var _scroll: ScrollContainer
var _jump_up: Control
var _jump_down: Control
var _rows: VBoxContainer
var _overlay: Control
var _valet_row: Control
var _desk_row: Control
var _build_row: Control
var _bay_rows: Array = []
var _boost_btn: Button
var _sky_row: Control
var _ad_btn: Control
var _prestige_badge: Control
var _fx: Control
var _sync_city := ""
var _shown_cash := 0.0
var _title: Control = null   # the title screen while it's up
var _loading: Control = null   # v0.19w: the loading card while a city change runs under it
var loading_in_tests := false
var _badge_clock = preload("res://scripts/anim_clock.gd").new()  # (the autotest calls GameState directly; it turns this on to test the card)
var _meta: Control = null    # top-right Shine Bucks + Reputation buttons
var _money: Control = null   # v0.19j: top-left cash + idle income pills
var _tips: Control = null    # v0.17h one-time tips
var _slow_key := ""          # the station that's been the slowest ...
var _slow_for := 0.0         # ... for this many seconds (valet / desk tips)
var _map_alert: Label
var _book_alert: Label
var _shop_alert: Label
var _double_btn: Button
var _balance: Label
var _balance_timer := 0.0
var _alert_timer := 0.0
var _ht_alert := false
var _popup: Control
var _popup_label: Label
var _popup_pic: Control   # v0.19u: the Welcome back scene
var _toast: Label             # the toast's text (inside _toast_box)
var _toast_rich: RichTextLabel = null   # v0.19v: used instead when the toast has an icon in it
var _toast_box: PanelContainer
var _toast_ok: Button
var _toast_at := 0             # ms when the current toast appeared (OK ignores taps for OK_GRACE_MS)
var _toast_closing := false
var _toast_tween: Tween = null
var _quiet_toasts := {}        # v0.19j: toast texts that close by themselves (no OK)
var _reno_pending: Array = []  # v0.19j: renovations finishing in the same frame -> one toast
var _toast_queue: Array = []
var _toast_busy := false
var _banner: PanelContainer
var _banner_label: Label
var _banner_bay := 0
var _big_queue: Array = []     # big centre messages wait their turn (never two stacked)
var _big_busy := false
var _big_node: Control = null  # v0.19j: the big message on screen, waiting for OK
var _big_at := 0
var _big_tween: Tween = null
const OK_GRACE_MS := 350       # v0.19j: a tap already on its way when a message pops up doesn't close it
var _star_frame := -1          # a star-up in the same frame as a rare car payout joins its message
var _star_value := 0
var _star_merged := false


func _ready() -> void:
	theme = UiTheme.build()
	_build_ui()
	_build_banner()
	_build_offline_popup()
	var tut := TutorialOverlay.new()
	tut.main = self
	add_child(tut)
	_tips = TipOverlay.new()
	_tips.main = self
	add_child(_tips)
	GameState.tutorial_finished.connect(func():
		_big_banner("YOU'RE GOOD TO GO!", Color("7cf29a"), "Hire managers to keep the cars moving, even while you're away."))
	GameState.state_changed.connect(_sync_bays)
	_connect_feel()
	GameState.city_changed.connect(func():
		_scroll.scroll_vertical = 0
		if GameState.pending_offline.is_empty():
			_popup.visible = false)   # v0.19m: a reset save no longer leaves an old "Welcome back" up
	GameState.offline_earnings_ready.connect(_show_offline_popup)
	GameState.hometown_changed.connect(_on_hometown_changed)
	GameState.renovation_done.connect(func(id, k):
		_reno_pending.append([id, k])
		if _reno_pending.size() == 1:
			_flush_reno.call_deferred())
	_ht_seen = {"key": "", "unlocked": GameState.hometown.get("unlocked", false), "stage": GameState.ht_stage()}
	# v0.19j: the details that used to come as a second toast are now the big message's second line (one OK)
	GameState.manager_called.connect(func(m):
		_big_banner("%s JOINED!" % str(m["name"]).to_upper(), Color(GameState.rarity_def(m)["color"]).lightened(0.2),
			"%s is on your team. Tap a %s's manager to put them to work (PREMIUM tab)." % [m["name"], {"bay": "bay", "valet": "valet", "desk": "front desk"}[m["area"]]]))
	GameState.vip_arrived.connect(_on_vip_arrived)
	GameState.vip_finished.connect(_on_vip_finished)
	GameState.star_up.connect(func(s): _tip("star", func(): return Rect2(_meta.global_position + _meta._pill(1).position, _meta._pill(1).size)))
	GameState.renovation_started.connect(_reno_tip)
	GameState.stash_collected.connect(func(id, amt):   # v0.19v: arriving in a city collects what it made
		if id != "" and amt > 0.0:
			_show_toast("Collected %s that %s made while you were away." % [GameState.money(amt, GameState.country_of(id)),
				str(GameState.city_def(id)["name"]).split(",")[0]], false))
	_sync_bays()
	if GameState.pending_offline_earnings > 0.0:
		_show_offline_popup()
	# a VIP may already be waiting from before the UI existed (welcome-back visit)
	if not GameState.vip.is_empty() and GameState.vip["phase"] == "lot":
		_on_vip_arrived(GameState.car_def(GameState.vip["id"]), GameState.settings.get("rare_alerts", true))
	# v0.17g: title screen on launch (the autotest skips it)
	if not get_tree().root.has_node("AutoTest"):
		_title = TitleScreen.new()
		add_child(_title)


func _process(_delta: float) -> void:
	_update_perf(_delta)
	# v0.17g: the cash counter rolls up to the new amount (spending snaps straight down)
	if GameState.cash < _shown_cash or _shown_cash <= 0.0 or GameState.cash > _shown_cash * 1000.0:
		_shown_cash = GameState.cash
	else:
		_shown_cash = lerpf(_shown_cash, GameState.cash, minf(1.0, _delta * 9.0))
		if GameState.cash - _shown_cash < maxf(0.5, GameState.cash * 1e-4):
			_shown_cash = GameState.cash
	_cash_label.text = GameState.money(_shown_cash)
	if GameState.is_hometown():
		_set_city_text("Hometown Garage", "Hometown")
	else:
		var cname: String = GameState.city_def(GameState.active_city)["name"].split(",")[0]
		_set_city_text("%s, %s" % [cname, GameState.country_def(GameState.country)["name"]], cname)
	# v0.19j: just this city's idle $/s (tap the pill for the Overview: every city's income)
	_money.rate_text = "%s/s" % GameState.money(GameState.idle_income())
	_update_boost_btn()
	if _balance != null:
		_balance_timer -= _delta
		if _balance_timer <= 0.0:
			_balance_timer = 0.5
			_balance.text = _balance_text()
	# v0.17g: the prestige trophy (was a star) is always there (blank = no prestige yet, gold + number after); it shines when ready
	_prestige_badge.visible = not GameState.is_hometown()
	# (no trophy in the Hometown: its name takes the trophy's spot)
	# v0.19w (Hamza): no "Lima, USA" under the trophy any more (the shop's banner says it); only the Hometown,
	# which has no trophy, keeps its name in that spot
	_city_label.visible = not _prestige_badge.visible
	_city_label.position.y = _prestige_badge.position.y + TROPHY_BOX * 0.5 - 13.0
	if _prestige_badge.visible:
		var sig := "%d|%s" % [GameState.prestige, _prestige_ready_now()]
		var shine := _prestige_ready_now() and _badge_clock.tick(_delta) > 0.0   # (the shine moves at 30 fps)
		if shine or _prestige_badge.get_meta("sig", "") != sig:   # v0.19w: still unless it's shining
			_prestige_badge.set_meta("sig", sig)
			_prestige_badge.queue_redraw()
	_alert_timer -= _delta
	if _alert_timer <= 0.0:
		_alert_timer = 0.5
		_check_slow_station()
		if _desk_row.parcel_showing():
			_tip("delivery", func(): return Rect2(_desk_row.global_position + DeskRow.PARCEL.position, DeskRow.PARCEL.size))
		elif GameState.bays.size() >= 3 and _valet_row.cat_showing() and GameState.tip_seen("delivery"):
			_tip("cat", func(): return Rect2(_valet_row.global_position + _valet_row.cat.rect().position, _valet_row.cat.rect().size))
		_ht_alert = (GameState.ht_claimable() > 0 or (GameState.hometown.get("unlocked", false) and not GameState.hometown.get("seen", true))) \
			and not GameState.is_hometown()
		var nudge := GameState.check_city_nudge()
		if nudge != "":
			_show_toast("%s is open for %s! Tap MAP to expand." % [str(GameState.city_def(nudge)["name"]).split(",")[0], GameState.money(GameState.city_unlock_cost(nudge))])
		if GameState.city_nudge_pending():
			_ht_alert = true   # (same "!" + opens the WORLD tab)
	_map_alert.visible = GameState.tutorial_step == GameState.TUT_DONE and (GameState.callable_count() > 0 or GameState.unopened_case_files() > 0 or _ht_alert)
	_book_alert.visible = GameState.book_unseen and GameState.tutorial_step == GameState.TUT_DONE
	_shop_alert.visible = GameState.wheel_free_ready() and GameState.tutorial_step == GameState.TUT_DONE and GameState.bays.size() >= 2
	# v0.17g: a new RARE car gets a gold star badge so it can't get lost among the everyday cars
	var rare := GameState.book_new_rare()
	if _book_alert.visible and bool(_book_alert.get_meta("rare", false)) != rare:
		_book_alert.set_meta("rare", rare)
		var bs := UiTheme.box(Color("ffc93c") if rare else Color("ff7a45"), 10, 0)
		bs.set_border_width_all(3)
		bs.border_color = Color.WHITE
		_book_alert.add_theme_stylebox_override("normal", bs)
		_book_alert.add_theme_color_override("font_color", UiTheme.INK if rare else Color.WHITE)
	# jump buttons only once the shop is taller than the screen
	var tall := GameState.tutorial_step == GameState.TUT_DONE and _rows.size.y > _scroll.size.y + 60.0 \
		and not (_toast_box.visible and _toast_ok.visible)   # v0.19j: a toast waiting for OK sits over them
	_jump_up.visible = tall
	_jump_down.visible = tall
	if _banner.visible:
		_update_banner()
	# v0.19j: a big message that had to wait (tip / welcome back / title screen up) comes in once it's clear
	if not _big_busy and not _big_queue.is_empty() and not _big_blocked():
		_next_big()


func _unhandled_input(event: InputEvent) -> void:
	# Dev cheats (editor/debug builds only)
	if not (OS.is_debug_build() and event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_M:
			GameState.cash = GameState.cash * 2.0 + 1000.0
		KEY_G:
			GameState.gloss += 500
		KEY_V:
			GameState.spawn_vip()
		KEY_E:
			GameState.grant_test_materials(100)
		KEY_F:
			GameState.debug_skip(3600.0)
			_show_toast("Skipped 1 hour", false)
		KEY_H:
			GameState.debug_skip(8.0 * 3600.0)
			_show_toast("Skipped 8 hours", false)
		KEY_T:
			Engine.time_scale = 1.0 if Engine.time_scale > 1.0 else 10.0
			_show_toast("Game speed x%d (timers still use real time)" % int(Engine.time_scale), false)
		KEY_B:
			_toggle_balance_overlay()
		KEY_P:
			toggle_perf_overlay()


# ---------------------------------------------------------------- layout

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("8a6a4a")   # earth under the last bay (matches the build strip)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# HUD
	var hud := PanelContainer.new()
	var hs := UiTheme.box(UiTheme.HUD, 0, 0)
	hs.content_margin_top = 40     # room for the phone's status bar
	hs.content_margin_bottom = 8
	hs.content_margin_left = 20
	hs.content_margin_right = 16
	hs.border_width_bottom = 5
	hs.border_color = UiTheme.INK
	hud.add_theme_stylebox_override("panel", hs)
	root.add_child(hud)
	var hh := HBoxContainer.new()
	hud.add_child(hh)
	# v0.19j (playtest: "too cluttered, could barely see the idle income"): left = cash + idle pills,
	# middle = the prestige trophy with the city under it, right = Shine Bucks + Rating pills
	_money = HudMoney.new()
	_money.rate_pressed.connect(_open_overview)
	hh.add_child(_money)
	_cash_label = _money.cash_label
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hh.add_child(gap)
	# v0.19f (Hamza: the top-left corner was too cluttered): the prestige trophy now sits on its own in the
	# TOP MIDDLE of the bar (blank before the first prestige, gold + number after, shines when ready); it's
	# added over the HUD at the end of _build so it stays centred whatever the cash number's width.
	_prestige_badge = Control.new()
	_prestige_badge.size = Vector2(TROPHY_BOX, TROPHY_BOX)
	_prestige_badge.mouse_filter = Control.MOUSE_FILTER_STOP
	_prestige_badge.draw.connect(_draw_prestige_badge)
	_prestige_badge.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_open_workshops())
	# v0.19j: the city name sits under the trophy (was a line under the cash)
	_city_label = UiTheme.label("", 18, Color("fff3c4"))
	_city_label.add_theme_font_override("font", UiTheme.DISPLAY_FONT)
	_city_label.add_theme_color_override("font_outline_color", UiTheme.INK)
	_city_label.add_theme_constant_override("outline_size", 6)
	_city_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_city_label.clip_text = true
	_city_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_city_label.size = Vector2(CITY_W, 26)
	hud.resized.connect(func():
		# v0.19w (Hamza): lower, level with the idle income + rating pills (out of the phone camera's way)
		_prestige_badge.position = Vector2(hud.size.x * 0.5 - TROPHY_BOX * 0.5, hud.position.y + hud.size.y - TROPHY_BOX - 2.0)
		_city_label.position = Vector2(hud.size.x * 0.5 - CITY_W * 0.5, _prestige_badge.position.y + TROPHY_BOX - 4.0))
	var meta := HudMeta.new()
	meta.premium_pressed.connect(_open_premium_info)
	meta.rep_pressed.connect(_open_reputation)
	_meta = meta
	hh.add_child(meta)

	# scrolling shop
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)
	var content := MarginContainer.new()   # stacks the rows and the lane overlay on top of each other
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(content)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 0)
	content.add_child(_rows)
	_overlay = LaneOverlay.new()
	content.add_child(_overlay)

	_sky_row = SkyRow.new()
	_sky_row.wheel_pressed.connect(_open_wheel)
	_rows.add_child(_sky_row)
	_desk_row = DeskRow.new()
	_connect_station(_desk_row)
	_desk_row.sign_pressed.connect(func(): _open_hometown() if GameState.is_hometown() else _open_workshops())
	_desk_row.parcel_pressed.connect(_open_delivery)
	_rows.add_child(_desk_row)
	_valet_row = ValetRow.new()
	_connect_station(_valet_row)
	_rows.add_child(_valet_row)
	_build_row = BuildRow.new()
	_rows.add_child(_build_row)
	_rows.add_child(DepthRow.new())   # v0.17g: the ground down to the last bay slot
	add_child(_prestige_badge)        # v0.19f: over the HUD, top middle (positioned on hud.resized)
	add_child(_city_label)

	# bottom bar
	var nav := PanelContainer.new()
	var ns := UiTheme.box(Color("2b63b8"), 0, 12)
	ns.content_margin_bottom = 26
	ns.border_width_top = 4
	ns.border_color = UiTheme.INK
	nav.add_theme_stylebox_override("panel", ns)
	root.add_child(nav)
	var nh := HBoxContainer.new()
	nh.add_theme_constant_override("separation", 8)
	nav.add_child(nh)
	var shop := _nav_button("SHOP", UiTheme.GOOD, "shop")
	shop.pressed.connect(_open_shop)
	_shop_alert = _alert_badge()   # v0.19n: a free Lucky Wheel spin is ready
	shop.add_child(_shop_alert)
	var book := _nav_button("BOOK", Color("8e44ad"), "book")
	book.pressed.connect(_open_book)
	# "!" when a new car went into the Book (instead of a toast), until you open it
	_book_alert = _alert_badge()
	book.add_child(_book_alert)
	_boost_btn = _nav_button("BOOST", Color("ffb300"), "boost")
	_boost_btn.pressed.connect(_open_boosts)
	var map := _nav_button("MAP", Color("e53935"), "map")
	map.pressed.connect(func(): _open_map(0 if _ht_alert or not _map_alert.visible else 2))
	# "!" when a Case File is waiting or a dossier is ready to call
	_map_alert = _alert_badge()
	map.add_child(_map_alert)
	# v0.19v: INFO left the bar (the $/s pill under your cash opens the same Overview); the middle is the
	# big AD BOOST button, which sticks up out of the bar
	var mid := Control.new()
	mid.custom_minimum_size = Vector2(150, 0)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for b in [shop, book, mid, _boost_btn, map]:
		if b != mid:
			b.custom_minimum_size = Vector2(0, 76)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nh.add_child(b)
	_ad_btn = AdBoostButton.new()
	_ad_btn.boost_pressed.connect(_on_ad_boost)
	nav.resized.connect(func():
		_ad_btn.position = Vector2(nav.position.x + nav.size.x * 0.5 - _ad_btn.size.x * 0.5, nav.position.y + nav.size.y - _ad_btn.size.y - 18.0))

	# v0.17g: flying coins live on their own layer under every popup / full screen (they used to fly over the map)
	_fx = Control.new()
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)

	# quick jump to the top / bottom of the shop (v0.17d)
	_jump_up = _jump_button(true)
	add_child(_jump_up)
	_jump_down = _jump_button(false)
	add_child(_jump_down)
	add_child(_ad_btn)   # v0.19v: over the bar + the shop (it sticks up out of the bar)

	# toast: a card just above the bottom bar. v0.19j (playtest: "didn't last long enough to read"):
	# it stays until you tap its OK button; the shop keeps running and stays tappable around it.
	_toast_box = PanelContainer.new()
	_toast_box.add_theme_stylebox_override("panel", UiTheme.card(Color("23407f"), 20, 14, UiTheme.INK))
	_toast_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_toast_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast_box.offset_left = 30
	_toast_box.offset_right = -30
	_toast_box.offset_bottom = -196   # just above the bottom bar (v0.19v: and the AD BOOST button)
	_toast_box.offset_top = -196
	_toast_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_toast_box.visible = false
	add_child(_toast_box)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 12)
	_toast_box.add_child(th)
	_toast = UiTheme.label("", 22, Color.WHITE)
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	th.add_child(_toast)
	_toast_ok = UiTheme.button("OK", 24, UiTheme.GOOD)
	_toast_ok.custom_minimum_size = Vector2(100, 60)
	_toast_ok.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_toast_ok.pressed.connect(_dismiss_toast)
	th.add_child(_toast_ok)
	_toast_box.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed and not _toast_ok.visible:
			_dismiss_toast())   # a toast that closes by itself can be tapped away early


## Bottom-bar button (v0.17f): a code-drawn icon on top, the label underneath.
func _nav_button(text: String, color: Color, icon: String) -> Button:
	var b := UiTheme.button(text, 17, color)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb: StyleBoxFlat = (b.get_theme_stylebox(st) as StyleBoxFlat).duplicate()
		sb.content_margin_top += 30   # v0.19v: a slimmer bar (room for the AD BOOST button)
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_constant_override("line_spacing", -4)
	b.draw.connect(func():
		var down := 3.0 if b.get_draw_mode() == BaseButton.DRAW_PRESSED or b.get_draw_mode() == BaseButton.DRAW_HOVER_PRESSED else 0.0
		UiIcons.draw(b, icon, Vector2(b.size.x * 0.5, 23 + down), 30.0))
	return b


## Small red "!" badge for the top-left corner of a bottom-bar button.
## v0.19u (Hamza: fewer shouty "!"s): a small dot in the button's top-right corner instead of a red "!" badge.
func _alert_badge() -> Label:
	var l := UiTheme.label("", 10, Color.WHITE)
	var bs := UiTheme.box(Color("ff7a45"), 10, 0)
	bs.set_border_width_all(3)
	bs.border_color = Color.WHITE
	l.add_theme_stylebox_override("normal", bs)
	l.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	l.offset_left = -26.0
	l.offset_right = -6.0
	l.offset_top = -6.0
	l.offset_bottom = 14.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.visible = false
	return l


func _connect_station(row: Control) -> void:
	row.level_pressed.connect(_open_level_panel)
	row.manager_pressed.connect(_open_manager_panel)


## Make the bay rows match GameState.bays (new bays appear above "Build").
func _sync_bays() -> void:
	while _bay_rows.size() > GameState.bays.size():
		_bay_rows.pop_back().queue_free()
	# v0.17g: a bay you just built (one new bay, same city) drops in
	var just_built := _sync_city == GameState.active_city and GameState.bays.size() == _bay_rows.size() + 1 and not _bay_rows.is_empty()
	_sync_city = GameState.active_city
	for i in range(_bay_rows.size(), GameState.bays.size()):
		var card := BayCard.new()
		card.index = i
		card.fresh = just_built
		_connect_station(card)
		_rows.add_child(card)
		_rows.move_child(card, _build_row.get_index())
		_bay_rows.append(card)
	_overlay.rows = [_valet_row] + _bay_rows


# ---------------------------------------------------------------- rare car banner

func _build_banner() -> void:
	_banner = PanelContainer.new()
	_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_left = 16
	_banner.offset_right = -16
	_banner.offset_top = 150
	_banner.visible = false
	add_child(_banner)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_banner.add_child(v)
	_banner_label = UiTheme.label("", 21)
	_banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_banner_label)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	var go := UiTheme.button("GO TO CAR", 22, UiTheme.GOOD)
	go.custom_minimum_size = Vector2(0, 60)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.pressed.connect(func():
		_banner.visible = false
		_vip_tip.call_deferred()
		# still waiting in the pickup lot (top of the screen): go there so you can tap it in
		if not GameState.vip.is_empty() and GameState.vip["phase"] == "lot":
			_scroll_to_top()
		else:
			_scroll_to_bay(_banner_bay))
	h.add_child(go)
	var later := UiTheme.button("OK", 22, Color("3d4657"))
	later.custom_minimum_size = Vector2(120, 60)
	later.pressed.connect(func():
		_banner.visible = false
		_vip_tip())
	h.add_child(later)


func _on_vip_arrived(car: Dictionary, alert: bool) -> void:
	# (Phone push notifications for when the game is closed need an Android
	# plugin; that hooks in here later.)
	var bay := int(GameState.vip["bay"])
	if not alert:
		_show_toast("VIP: %s pulled into your pickup lot (Bay %d)" % [car["name"], bay + 1], false)   # alerts are off: don't stop play
		_vip_tip()
		return
	var r: Dictionary = Data.VIP_RARITIES[int(car["rarity"])]
	_banner_bay = bay
	_banner.add_theme_stylebox_override("panel", UiTheme.card(Color("23407f"), 22, 18, Color(r["color"])))
	move_child(_banner, get_child_count() - 1)
	_banner.visible = true
	_update_banner()


func _update_banner() -> void:
	if GameState.vip.is_empty():
		_banner.visible = false
		return
	var car := GameState.car_def(GameState.vip["id"])
	var r: Dictionary = Data.VIP_RARITIES[int(car["rarity"])]
	var when := "heading to Bay %d in %s" % [_banner_bay + 1, GameState.fmt_time(GameState.vip["timer"])] \
		if GameState.vip["phase"] == "lot" else "now in Bay %d" % (_banner_bay + 1)
	_banner_label.text = "%s CAR!  A %s just rolled into your pickup lot, %s.\nUse your manager boosts on that bay to cash in big!" % [
		str(r["name"]).to_upper(), car["name"], when]


func _scroll_to_top() -> void:
	_scroll.create_tween().tween_property(_scroll, "scroll_vertical", 0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _scroll_to_bottom() -> void:
	# v0.17g: the shop now goes on (as dirt) to the last bay slot: "bottom" = your Build Bay strip
	var bottom := int(maxf(0.0, _build_row.position.y + _build_row.size.y + 40.0 - _scroll.size.y))
	_scroll.create_tween().tween_property(_scroll, "scroll_vertical", bottom, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Round up / down button over the valet lane (bottom left): jump to the top or bottom of the shop.
func _jump_button(up: bool) -> Control:
	var b := Control.new()
	b.size = Vector2(64, 64)
	b.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	b.offset_left = 16
	b.offset_right = 80
	b.offset_bottom = -144 if not up else -218
	b.offset_top = b.offset_bottom - 64
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.draw.connect(func():
		var c := b.size * 0.5
		# v0.17f: round bubbly button with a lip
		b.draw_circle(c + Vector2(0, 5), 31, UiTheme.INK)
		b.draw_circle(c + Vector2(0, 4), 28, Color("1f5fb0"))
		b.draw_circle(c, 31, UiTheme.INK)
		b.draw_circle(c, 28, Color("2f9bff"))
		b.draw_arc(c + Vector2(0, -2), 20, PI * 1.15, PI * 1.6, 8, Color(1, 1, 1, 0.45), 4.0, true)
		var d := -1.0 if up else 1.0
		var tri := PackedVector2Array([c + Vector2(-14, -7 * d), c + Vector2(14, -7 * d), c + Vector2(0, 11 * d)])
		b.draw_colored_polygon(tri, Color.WHITE)
		tri.append(tri[0])
		b.draw_polyline(tri, UiTheme.INK, 2.5, true))
	b.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			Sfx.play("click")
			if up:
				_scroll_to_top()
			else:
				_scroll_to_bottom())
	return b


func _scroll_to_bay(i: int) -> void:
	if i >= _bay_rows.size():
		return
	var row: Control = _bay_rows[i]
	var target := int(row.position.y - _scroll.size.y * 0.4)
	_scroll.create_tween().tween_property(_scroll, "scroll_vertical", maxi(target, 0), 0.4)


## One clean payout message in the middle of the screen (no second toast). If the
## followers it gave pushed you up a star, that goes in the same message.
func _on_vip_finished(res: Dictionary) -> void:
	_banner.visible = false
	var extra := ""
	if _star_frame == Engine.get_process_frames():
		extra = "\n%s  %s" % [star_title(_star_value), _star_rewards()]
		_star_merged = true
	# v0.19j: OK the first time (and when a new star rides along); after that it closes by itself (every ~20 min)
	var first := not GameState.tip_seen("vip_paid")
	GameState.mark_tip("vip_paid")
	_big_banner("RARE CAR PAID %s!" % GameState.money(res["pay"]), UiTheme.CASH,
		"%s  ·  +%s followers  ·  +%d {sb}%s" % [res["car"]["name"], GameState.fmt(res["followers"]), res["gloss"], extra],
		first or extra != "")


func _on_star_up(s: int) -> void:
	_star_frame = Engine.get_process_frames()
	_star_value = s
	_star_merged = false
	_star_banner.call_deferred(s)


func _star_banner(s: int) -> void:
	if _star_merged:
		return   # already in the rare car payout message
	_big_banner(star_title(s), Color("ffca28"), ("Your shop is rated %s stars.  " % GameState.rating_text(s) if s == 2 else "") + _star_rewards())


## v0.19l: "RATED 4.5 STARS!", or "FIRST REVIEWS ARE IN!" for the step from No reviews yet to 1.0.
func star_title(s: int) -> String:
	return "FIRST REVIEWS ARE IN!" if s == 2 else "RATED %s STARS!" % GameState.rating_text(s)


## v0.19j: what a new star gives (was its own toast, now the star message's second line).
func _star_rewards() -> String:
	return "+%d {sb}, a x2 Booster, %d Certs" % [Data.STAR_GLOSS, Data.STAR_CERTS]


# ---------------------------------------------------------------- game feel (sounds, vibration, juice)

func _connect_feel() -> void:
	# Sounds only for things the PLAYER does (taps, buttons, upgrades, hiring, prestige).
	# Automatic stuff (cars finishing, valet trips, cash coming in, rare cars, stars)
	# stays quiet so the game isn't noisy. Background music will come later.
	GameState.cash_earned.connect(_on_cash_feel)
	GameState.manager_hired.connect(func(_m):
		Sfx.play("hire")
		Sfx.buzz(40))
	GameState.star_up.connect(_on_star_up)
	GameState.tier_set_completed.connect(func(t): _big_banner("SET COMPLETE!", Color("ce93d8"),
		"Book set complete: %s!  +%d {sb}, x%s income" % [Data.TIER_NAMES[t], Data.TIER_SET_GLOSS, str(Data.TIER_SET_INCOME_BONUS)]))
	GameState.prestiged.connect(func(id):
		Sfx.play("big_win")
		Sfx.buzz(200)
		_big_banner("PRESTIGE!", Color("ce93d8"), "%s is now a %s! It earns x%s. +%d {sb}  Plus %d Certs." % [GameState.city_def(id)["name"],
			GameState.premises_def(int(GameState.cities[id]["prestige"]))["name"], GameState.fmt(GameState.city_mult_of(id)),
			Data.PRESTIGE_GLOSS, Data.PRESTIGE_CERTS]))
	GameState.leveled.connect(func(key, _n, boosts):
		# reaching a boost keeps its own sound, but no text on screen (Hamza, v0.17c)
		if boosts.is_empty():
			Sfx.play("level_up")
			Sfx.buzz(15)
		else:
			Sfx.play("boost")
			Sfx.buzz(80))


## When YOU tap the front desk (before it has a manager): cha-ching, the cash pops
## and coins fly up to your balance. Once a manager runs the desk it's silent.
func _on_cash_feel(amount: float) -> void:
	if GameState.is_automated("desk") or amount <= 0.0:
		return
	Sfx.play("cash")
	_cash_label.pivot_offset = Vector2(0, _cash_label.size.y * 0.5)
	var tw := _cash_label.create_tween()
	tw.tween_property(_cash_label, "scale", Vector2(1.12, 1.12), 0.06)
	tw.tween_property(_cash_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not _desk_row.is_visible_in_tree():
		return
	var from := _desk_row.get_global_rect().position + Vector2(_desk_row.size.x - 150, 150)
	var to := _cash_label.get_global_rect().position + Vector2(60, 24)
	for k in 4:
		var coin := Control.new()
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coin.size = Vector2(22, 22)
		coin.draw.connect(func():
			coin.draw_circle(Vector2(11, 11), 11, Color("b8860b"))
			coin.draw_circle(Vector2(11, 11), 8.5, Color("ffd54f"))
			coin.draw_rect(Rect2(9, 6, 4, 10), Color("b8860b")))
		_fx.add_child(coin)
		coin.position = from + Vector2(randf_range(-30, 30), randf_range(-10, 10))
		var mid := Vector2(lerpf(coin.position.x, to.x, 0.5) + randf_range(-80, 80), minf(coin.position.y, to.y) - 40)
		var ct := coin.create_tween()
		ct.tween_interval(k * 0.06)
		ct.tween_property(coin, "position", mid, 0.22).set_ease(Tween.EASE_OUT)
		ct.tween_property(coin, "position", to, 0.25).set_ease(Tween.EASE_IN)
		ct.tween_callback(coin.queue_free)


## Big centred celebration text that pops in (optional smaller line under it).
## v0.19j: it stays on a card with an OK button until you tap OK (the autotest's
## GameState.popups_need_ok = false keeps the old pop + fade). They queue up: only one is ever on screen.
func _big_banner(text: String, color: Color, sub: String = "", need_ok: bool = true) -> void:
	if _big_queue.size() >= (6 if GameState.popups_need_ok else 2):
		_big_queue.pop_front()   # lots at once: skip the oldest waiting one
	_big_queue.append([text, color, sub, need_ok])
	if not _big_busy:
		_next_big()


## v0.19j: the big message on screen (waiting for its OK).
func big_showing() -> bool:
	return _big_node != null and is_instance_valid(_big_node)


## v0.19j: wait while a tip, the Welcome back popup or the title screen is up (never two cards at once).
func _big_blocked() -> bool:
	return title_showing() or loading_showing() or (_popup != null and _popup.visible) or (_tips != null and _tips.busy())


func _next_big() -> void:
	if _big_queue.is_empty() or _big_blocked():
		_big_busy = false   # (_process starts it once it's clear)
		return
	_big_busy = true
	var item: Array = _big_queue.pop_front()
	var text: String = item[0]
	var color: Color = item[1]
	var sub: String = item[2]
	if GameState.popups_need_ok:
		_show_big_card(text, color, sub, item.size() < 4 or bool(item[3]))
		return
	var w := size.x - 80.0
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiTheme.display_label(text, 34, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(w, 0)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 12)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(l)
	var node: Control = box
	if sub != "":
		var sl := UiTheme.label(sub, 21, Color.WHITE)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.custom_minimum_size = Vector2(w, 0)
		sl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		sl.add_theme_constant_override("outline_size", 8)
		sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(sl)
		# a message with a second line gets a dark card behind it so it reads over the shop
		var card := PanelContainer.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_theme_stylebox_override("panel", UiTheme.card(Color(0.14, 0.25, 0.5, 0.94), 22, 16, UiTheme.INK))
		card.add_child(box)
		node = card
	add_child(node)
	node.reset_size()
	var sz := node.get_combined_minimum_size()
	node.size = sz
	node.position = Vector2((size.x - sz.x) * 0.5, size.y * 0.38)
	node.pivot_offset = sz * 0.5
	node.scale = Vector2(0.3, 0.3)
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2(1.1, 1.1), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, 0.1)
	tw.tween_interval(1.6 if sub != "" else 1.0)
	tw.tween_property(node, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func():
		node.queue_free()
		_next_big())


## v0.19j: the big message as a card that waits for OK. A light dim behind it stops taps
## going through to the shop while you read (the game keeps running underneath).
## need_ok = false (v0.19j: routine ones, e.g. the 2nd+ rare car payout): no dim and no OK, the shop stays
## tappable, it closes by itself after a reading time that grows with the text, or when you tap the card.
func _show_big_card(text: String, color: Color, sub: String, need_ok: bool = true) -> void:
	var w := size.x - 80.0
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.05, 0.15, 0.4) if need_ok else Color(0, 0, 0, 0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP if need_ok else Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.card(Color(0.14, 0.25, 0.5, 0.97), 24, 22, UiTheme.INK))
	dim.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	var l := UiTheme.display_label(text, 36, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(w - 44.0, 0)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 12)
	box.add_child(l)
	if sub.contains("{"):   # v0.19v: icons in it ("+5 {sb}")
		var rl := UiTheme.rich_label(sub, 23, Color.WHITE, 8)
		rl.custom_minimum_size = Vector2(w - 44.0, 0)
		box.add_child(rl)
	elif sub != "":
		var sl := UiTheme.label(sub, 23, Color.WHITE)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.custom_minimum_size = Vector2(w - 44.0, 0)
		sl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		sl.add_theme_constant_override("outline_size", 8)
		box.add_child(sl)
	if need_ok:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 4)
		box.add_child(gap)
		var ok := UiTheme.button("OK", 28, UiTheme.GOOD)
		ok.custom_minimum_size = Vector2(0, 72)
		ok.pressed.connect(_dismiss_big)
		box.add_child(ok)
	else:
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
				_dismiss_big())
	card.reset_size()
	var sz := card.get_combined_minimum_size()
	card.size = sz
	card.position = Vector2((size.x - sz.x) * 0.5, maxf(120.0, size.y * 0.44 - sz.y * 0.5))
	card.pivot_offset = sz * 0.5
	card.scale = Vector2(0.3, 0.3)
	dim.modulate.a = 0.0
	var tw := card.create_tween()
	tw.tween_property(card, "scale", Vector2(1.08, 1.08), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", Vector2.ONE, 0.1)
	dim.create_tween().tween_property(dim, "modulate:a", 1.0, 0.15)
	_big_node = dim
	_big_at = Time.get_ticks_msec()
	if not need_ok:
		_big_tween = dim.create_tween()
		_big_tween.tween_interval(read_time(text + " " + sub))
		_big_tween.tween_callback(func(): _dismiss_big(true))


## OK on the big message: it goes, and the next waiting one (if any) comes in.
func _dismiss_big(timed: bool = false) -> void:
	if not big_showing() or (not timed and Time.get_ticks_msec() - _big_at < OK_GRACE_MS):
		return
	if _big_tween != null and _big_tween.is_valid():
		_big_tween.kill()
	_big_tween = null
	var node := _big_node
	_big_node = null
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := node.create_tween()
	tw.tween_property(node, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func():
		node.queue_free()
		_big_busy = false
		_next_big())


# ---------------------------------------------------------------- tutorial helpers

func is_blocking_popup_open() -> bool:
	return _popup.visible or title_showing() or big_showing()


## v0.19w (Hamza): BIG changes (going to another city, opening a city / country, prestige, a new Hometown run)
## happen under a loading card with a bar: the card goes up first, then work() runs, then the bar fills while
## the new shop warms up. title = where you're going (a city id, or any words), sub = the line under it.
func with_loading(work: Callable, where: String = "", sub: String = "") -> void:
	if is_instance_valid(_loading) or (get_tree().root.has_node("AutoTest") and not loading_in_tests):
		work.call()
		return
	var ls := LoadingScreen.new()
	if where == Data.HOMETOWN_ID or str(GameState.city_def(where)["id"]) == where:
		ls.title = "HOMETOWN GARAGE" if where == Data.HOMETOWN_ID else str(GameState.city_def(where)["name"]).split(",")[0].to_upper()
		ls.country = "hometown" if where == Data.HOMETOWN_ID else GameState.country_of(where)   # (the skyline you're going to)
		if sub == "" and where != Data.HOMETOWN_ID:
			sub = str(GameState.country_def(GameState.country_of(where))["name"])
	else:
		ls.title = where.to_upper()
	ls.sub = sub
	_loading = ls
	add_child(ls)
	await ls.run(work)


func loading_showing() -> bool:
	return is_instance_valid(_loading)


## v0.17h: the title screen is up (the tutorial + tips wait until it's gone).
## v0.19j: a panel (level, managers, Book, Shop...) is open over the shop.
func sheet_open() -> bool:
	for c in get_children():
		if (c.has_method("clear_body") or c is MapPanel) and c.visible and not c.is_queued_for_deletion():
			return true   # (the map / HQ is a full screen of its own, not a sheet)
	return false


func title_showing() -> bool:
	return _title != null and is_instance_valid(_title) and _title.is_inside_tree()


## Screen rect of a thing the tutorial points at.
func tut_rect(what: String) -> Variant:
	if _bay_rows.is_empty():
		return null
	var bay: Control = _bay_rows[0]
	var r: Rect2
	match what:
		"bay_car":
			r = Rect2(bay.global_position + Vector2(BayCard.CAR_X, BayCard.BAND_H + 6), Vector2(bay.size.x - 108 - BayCard.CAR_X, BayCard.FLOOR_Y - BayCard.BAND_H - 4))
		"bay0_portrait":
			r = bay._portrait.get_global_rect()
		"bay_level":
			r = bay._level_btn.get_global_rect()
		"valet":
			r = Rect2(_valet_row.global_position, Vector2(96, _valet_row.size.y - 10))
		"valet_portrait":
			r = _valet_row.portrait.get_global_rect()
		"desk":
			r = Rect2(_desk_row.global_position + Vector2(316, 128), Vector2(_desk_row.size.x - 112 - 316, DeskRow.FLOOR_Y - 120))
		"desk_portrait":
			r = _desk_row.portrait.get_global_rect()
		_:
			return null
	return r


## The open popup of this kind for this station, or null.
func open_sheet(kind: String, key: String) -> Control:
	for c in get_children():
		if kind == "manager" and c is ManagerPanel and c.key == key and not c.is_queued_for_deletion():
			return c
		if kind == "level" and c is LevelPanel and c.key == key and not c.is_queued_for_deletion():
			return c
	return null


# ---------------------------------------------------------------- popups

func _open_level_panel(key: String) -> void:
	var p := LevelPanel.new()
	add_child(p)
	p.setup(key)
	_tip("levels")


func _open_manager_panel(key: String) -> void:
	var p := ManagerPanel.new()
	add_child(p)
	p.setup(key)
	_tip("managers")


# ---------------------------------------------------------------- v0.17h one-time tips

## id -> [title, text]. %s = the premium currency's name.
const TIPS := {
	"book": ["YOUR BOOK", "Every car you wash goes in here. Put your favourites ON SHOW: they bring followers every hour, and a rare car on show visits more often. Collect a whole category for %s and +10%% income forever. Each city also has a CAR OF THE WEEK: it pays x3 when it comes in."],
	"shop": ["THE SHOP", "Spin the LUCKY WHEEL here (a free spin every 8 hours) and spend %s: recharge every manager's ability in one go, or grab today's booster deals. Tap the %s button at the top to see how to earn more."],
	"boosts": ["BOOSTS", "Boosters multiply ALL your income and keep running while you're away. Running boosters add up (x5 + x2 = x7). Tap USE on one you own; it joins the RUNNING NOW row. Tap the \"i\" for the full breakdown."],
	"managers": ["MANAGERS", "A manager runs this station for you, even while you're away. Every hire is a surprise: you get a speed, discount or income ability, and most are Junior (a few are Senior or Executive). The round button above their head is their ability: tap it for a boost, then it recharges. Got spare managers? Tap ASSIGN to swap them in."],
	"overview": ["OVERVIEW", "What every station makes per second. The red ! marks your slowest station: upgrade that one first. You can use abilities from here too."],
	"delivery": ["DAILY DELIVERY", "A parcel turns up in your pickup lot every day. Tap it to open it: boosters, %s, Case Files... Day 7 is the big one, then the week starts again."],
	"cat": ["SUDS THE SHOP CAT", "Meet Suds! She naps on the forecourt. Give her a pet (tap her): she always loves it, and once a day she leaves you a little treat."],
	"prestige": ["PRESTIGE", "Turn this city into a fancier shop: it earns x3 forever, but its bays and levels start from scratch. Your %s, Book and reputation stay. It costs the same as your next city, so you choose: expand or prestige! Each prestige wins this city a trophy (top middle)."],
	"levels": ["UPGRADES", "Every level earns more. At Lv 10, 25, 50... a big boost multiplies this station's income and gives you %s. The soft green on the bar shows how far your purchase takes you. Swipe left or right for the next station."],
	"map": ["WORLD MAP", "Drag to look around, pinch (or use the mouse wheel) to zoom. Tap a city to visit, unlock or prestige it: every city keeps earning while you're elsewhere. Managers, Skills, Equipment and your Hometown Garage are the little islands on the left."],
	"vip": ["RARE CAR!", "Rare cars pay way more than normal cars and bring lots of followers. This one is heading to Bay %d: upgrade that bay and use its manager's ability before it gets there to cash in big. Can't wait? Tap the car to send it in now."],
	"star": ["FIRST REVIEWS!", "People are reviewing your shop online! You start at 1.0 and every new half star boosts all your bays and brings more rare cars. Tap here any time to see how to get more followers."],
	"valet_slow": ["VALET TOO SLOW", "Money is piling up in your bays: the valet can't carry it all. Level up the valet here."],
	"reno": ["NO NEED TO WAIT", "%s"],   # v0.19k: text from reno_tip_text()
	"desk_slow": ["FRONT DESK TOO SLOW", "Cars are waiting in the pickup lot: the front desk can't check them out fast enough. Upgrade it here."],
}


func _tip(id: String, target: Variant = null, arg: Variant = null) -> void:
	if _tips == null:
		return
	_tips.show_tip(id, TIPS[id][0], tip_text(id, arg), target)


## A tip's text with the currency name (or arg) filled in.
func tip_text(id: String, arg: Variant = null) -> String:
	var d: Array = TIPS[id]
	var text: String = d[1]
	if arg != null:
		text = text % arg
	elif text.count("%s") == 1:
		text = text % Data.PREMIUM_NAME
	elif text.count("%s") == 2:
		text = text % [Data.PREMIUM_NAME, Data.PREMIUM_NAME]
	else:
		text = text.replace("%%", "%")
	return text


## v0.17h: the valet or front desk has been the slowest station for a while: point at its Level button once.
func _check_slow_station() -> void:
	var k := GameState.bottleneck() if GameState.bays_total_income() > 0.0 and GameState.tutorial_step == GameState.TUT_DONE else ""
	if k != _slow_key:
		_slow_key = k
		_slow_for = 0.0
		return
	_slow_for += 0.5
	if _slow_for < 8.0:
		return
	var btn: Control = _valet_row.level_btn if k == "valet" else (_desk_row.level_btn if k == "desk" else null)
	if btn == null or not get_viewport_rect().encloses(btn.get_global_rect()):
		return   # wait until it's on screen, so the arrow has something to point at
	if k == "valet":
		_tip("valet_slow", func(): return _valet_row.level_btn.get_global_rect() if _valet_row.level_btn.is_visible_in_tree() else null)
	elif k == "desk":
		_tip("desk_slow", func(): return _desk_row.level_btn.get_global_rect() if _desk_row.level_btn.is_visible_in_tree() else null)


## v0.19k (Hamza): the first renovation you start, point at the WATCH AD / SKIP button and say what it does.
func _reno_tip(cid: String, _k: int) -> void:
	if GameState.tip_seen("reno") or cid != GameState.active_city:
		return
	_scroll_to_bottom()   # the button it points at is on the Build strip (normally already on screen)
	var target := func():
		if not GameState.reno_running() or GameState.reno_ready() or not _build_row.is_visible_in_tree():
			return null
		var r: Rect2 = _build_row._ad_rect()
		return Rect2(_build_row.global_position + r.position, r.size)
	_tip("reno", target, reno_tip_text())


## "1h to go, but you don't have to wait! Each ad you watch here takes 30 min off..." with today's numbers.
func reno_tip_text() -> String:
	var left := GameState.reno_left()
	var step := Data.RENO_AD_SECONDS
	var n := int(ceil(left / step))
	var per := "%d per hour" % Data.RENO_ADS_PER_HOUR
	var what := "Each SKIP here takes %d min off (%s)" % [int(step / 60.0), per] if GameState.ad_free() \
		else "Each ad you watch here takes %d min off (%s)" % [int(step / 60.0), per]
	var tt := GameState.fmt_time(ceil(left / 60.0) * 60.0)   # whole minutes: "1h", not "59m 59s"
	if tt.ends_with(" 0m"):
		tt = tt.trim_suffix(" 0m")
	var t := "%s to go, but you don't have to wait! %s" % [tt, what]
	if n <= Data.RENO_ADS_PER_HOUR:
		t += ", so %s and it's finished now." % (("tap it %s" % ("once" if n == 1 else "twice")) if GameState.ad_free() else ("watch %d" % n))
	else:
		t += "."
	var fc := GameState.reno_finish_cost()
	if fc > 0:
		t += " Or tap FINISH NOW for %d %s." % [fc, Data.PREMIUM_NAME]
	return t


## The first rare car: point at it (in the pickup lot, or its bay once it's in) and explain.
func _vip_tip() -> void:
	if GameState.tip_seen("vip") or GameState.vip.is_empty():
		return
	var bay := int(GameState.vip["bay"])
	if GameState.vip["phase"] == "lot":
		_scroll_to_top()
	else:
		_scroll_to_bay(bay)
	var target := func():
		if GameState.vip.is_empty():
			return null
		if GameState.vip["phase"] == "lot":
			return Rect2(_desk_row.global_position + Vector2(4, 72), Vector2(206, DeskRow.FLOOR_Y - 76))
		var b := int(GameState.vip["bay"])
		return _bay_rows[b].get_global_rect() if b < _bay_rows.size() else null
	_tip("vip", target, bay + 1)


## Wandering off to another screen during the tutorial ends it quietly
## (players often tap elsewhere to get rid of popups).
func _end_tutorial_quietly() -> void:
	if GameState.tutorial_step != GameState.TUT_DONE:
		GameState.finish_tutorial(true)


## (tests) the Boosts breakdown mentions the rain.
func _boost_info_has_rain() -> bool:
	return BoostPanel.info_text().contains("RAINY DAY")


## v0.19t: today's Daily Delivery parcel.
func _open_delivery() -> void:
	_end_tutorial_quietly()
	var p := DeliveryPanel.new()
	add_child(p)
	p.setup()


## v0.19v: the Lucky Wheel from the sky over the shop (it's also first in the Shop).
func _open_wheel() -> void:
	if is_blocking_popup_open():
		return
	var wp = load("res://scripts/wheel_panel.gd").new()
	add_child(wp)
	wp.setup()


## v0.19v: the big AD BOOST button: watch an ad (placeholder) = x2 for +4h; when it's full, open Boosts.
func _on_ad_boost() -> void:
	if GameState.ad_boost_left() >= Data.AD_BOOST_MAX_HOURS * 3600.0 - 60.0:
		_open_boosts()
		return
	GameState.watch_ad_boost()
	Sfx.play("boost")


func _open_shop() -> void:
	_end_tutorial_quietly()
	var p := ShopPanel.new()
	add_child(p)
	p.setup()
	_tip("shop")


func _open_workshops() -> void:
	_end_tutorial_quietly()
	if GameState.is_hometown():
		_open_hometown()
		return
	var p := WorkshopPanel.new()
	add_child(p)
	p.setup()
	_tip("prestige")


func _open_overview() -> void:
	var p := OverviewPanel.new()
	add_child(p)
	p.setup()
	_tip("overview")


func _open_boosts() -> void:
	_end_tutorial_quietly()
	var p := BoostPanel.new()
	add_child(p)
	p.setup()
	_tip("boosts")


## Centre button: the total income multiplier and how long until it next drops.
func _update_boost_btn() -> void:
	var total := GameState.total_boost()
	if total > 1.0:
		_boost_btn.text = "x%s\n%s" % [BoostPanel.num(total), GameState.fmt_time(GameState.boost_time_left())]
		_set_font_size(_boost_btn, 16)
	else:
		var owned := 0
		for id in GameState.boosters:
			owned += int(GameState.boosters[id])
		_boost_btn.text = ("BOOST\n%d ready" % owned) if owned > 0 else "BOOST"
		_set_font_size(_boost_btn, 15 if owned > 0 else 17)


## v0.19w perf: setting a theme override (even to the same value) redraws the button and re-measures it, so
## only touch it when the size really changes (this ran every frame).
func _set_font_size(b: Control, fs: int) -> void:
	if not b.has_theme_font_size_override("font_size") or b.get_theme_font_size("font_size") != fs:
		b.add_theme_font_size_override("font_size", fs)


var _ht_seen := {}


## Quiet heads-ups for the Hometown Garage (no sounds: these happen on their own).
func _on_hometown_changed() -> void:
	var ht: Dictionary = GameState.hometown
	var key := "%s|%d|%d" % [ht.get("unlocked", false), GameState.ht_run(), GameState.ht_stage()]
	if ht.get("unlocked", false) and not _ht_seen["unlocked"]:
		_big_banner("HOMETOWN UNLOCKED!", Color("ffcc80"),
			"Your Hometown Garage is open! Tap MAP to visit it. It's where you find Premium managers, and it never resets.")
	_ht_seen = {"key": key, "unlocked": ht.get("unlocked", false), "stage": GameState.ht_stage()}


## The prestige trophy (v0.17g star -> v0.17h-3 trophy, Hamza): one trophy for this city, top middle
## of the HUD (v0.19f). Blank before its first prestige, gold with the prestige number after. When the city can
## prestige it pulses with rays. Tap = prestige screen.
## v0.19j: "Lima, USA" under the trophy; the city alone if that doesn't fit.
func _set_city_text(full: String, short: String) -> void:
	var f: Font = UiTheme.DISPLAY_FONT
	var t := full if f.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x <= CITY_W - 6.0 else short
	if _city_label.text != t:
		_city_label.text = t


## v0.19w (Hamza: cleaner): always a plain gold trophy (the city's prestige count on the cup). When a prestige
## is ready it bobs gently, a band of light sweeps across the cup every couple of seconds and a few sparkles
## twinkle round it: no glow disc, no rotating rays.
func _prestige_ready_now() -> bool:
	return GameState.tutorial_step == GameState.TUT_DONE and GameState.prestige_ready()


func _draw_prestige_badge() -> void:
	var b := _prestige_badge
	var t := Time.get_ticks_msec() * 0.001
	var c := Vector2(b.size.x * 0.5, b.size.y * 0.5 + 2.0)
	var p := GameState.prestige
	var ready := _prestige_ready_now()
	var h := 58.0
	if ready:
		c.y += sin(t * 2.4) * 2.5
	HudMeta.draw_trophy(b, c, h, true, str(p) if p > 0 else "")
	if not ready:
		return
	# the shine: a slanted band of light crossing the cup, once every 2.2 s
	var ph := fmod(t, 2.2) / 0.7
	if ph < 1.0:
		var x := lerpf(-h * 0.55, h * 0.55, ph)
		var band := PackedVector2Array([c + Vector2(x - h * 0.06, -h * 0.6), c + Vector2(x + h * 0.08, -h * 0.6),
			c + Vector2(x - h * 0.06, h * 0.15), c + Vector2(x - h * 0.2, h * 0.15)])
		for piece in Geometry2D.intersect_polygons(band, HudMeta.trophy_cup(c, h)):
			b.draw_colored_polygon(piece, Color(1, 1, 1, 0.75 * sin(ph * PI)))
	for k in 3:   # sparkles taking turns
		var sp := fmod(t * 0.9 + k * 0.33, 1.0)
		if sp < 0.4:
			var at: Vector2 = c + [Vector2(-h * 0.42, -h * 0.42), Vector2(h * 0.44, -h * 0.2), Vector2(h * 0.3, h * 0.38)][k]
			UiTheme.sparkle(b, at, 7.0 * sin(sp / 0.4 * PI), Color(1, 1, 0.85, 0.95))


# ---------------------------------------------------------------- balance overlay (debug)

## v0.19v dev: frame rate + what a frame costs (key P, or Shop > FPS in debug builds). For judging smoothness
## on a real PC / phone: FPS, CPU time of scripts + drawing, the renderer's CPU time, draw calls, shapes.
var _perf: Label = null
var _perf_t := 0.0


## v0.19w: honest numbers (the old "scripts+draw" was Performance.TIME_PROCESS, which also counts waiting for the
## GPU / the screen's refresh, so it read 30-40 ms at 65 fps). Over the last 0.5 s:
##   frame  = average time between frames (1000 / fps) and the WORST frame (a hitch shows up here)
##   game   = CPU time for scripts + layout + all the drawing code (first _process -> the renderer starts)
##   render = CPU time the renderer spent on the frame
class PerfClock extends Node:
	var t0 := 0
	var game_sum := 0.0
	var game_max := 0.0
	var n := 0
	func _ready() -> void:
		process_priority = -1000000   # runs before every other _process
		RenderingServer.frame_pre_draw.connect(_pre_draw)
	func _process(_d: float) -> void:
		t0 = Time.get_ticks_usec()
	func _pre_draw() -> void:
		if t0 > 0:
			var g := (Time.get_ticks_usec() - t0) / 1000.0
			game_sum += g
			game_max = maxf(game_max, g)
			n += 1


var _perf_clock: PerfClock = null
var _perf_frames := 0.0
var _perf_frame_max := 0.0
var _perf_dt := 0.0


func toggle_perf_overlay() -> void:
	if _perf != null:
		_perf.queue_free()
		_perf = null
		if is_instance_valid(_perf_clock):
			_perf_clock.queue_free()
		_perf_clock = null
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), false)
		return
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_perf_clock = PerfClock.new()
	add_child(_perf_clock)
	_perf = UiTheme.label("", 18, Color("b9ff9c"))
	_perf.add_theme_color_override("font_outline_color", Color.BLACK)
	_perf.add_theme_constant_override("outline_size", 6)
	_perf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_perf.position = Vector2(12, 176)
	_perf.z_index = 100
	add_child(_perf)


func _update_perf(delta: float) -> void:
	if _perf == null:
		return
	_perf_frames += 1.0
	_perf_dt += delta
	_perf_frame_max = maxf(_perf_frame_max, delta * 1000.0)
	_perf_t -= delta
	if _perf_t > 0.0:
		return
	_perf_t = 0.5
	var vp := get_viewport().get_viewport_rid()
	var c := _perf_clock
	_perf.text = "FPS %d   frame %.1f ms (worst %.1f)\ngame %.1f ms (worst %.1f)   render %.1f ms\ndraw calls %d   shapes %dK   nodes %d" % [
		Engine.get_frames_per_second(), _perf_dt * 1000.0 / maxf(1.0, _perf_frames), _perf_frame_max,
		c.game_sum / maxf(1.0, c.n), c.game_max,
		RenderingServer.viewport_get_measured_render_time_cpu(vp),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))]
	c.game_sum = 0.0
	c.game_max = 0.0
	c.n = 0
	_perf_frames = 0.0
	_perf_dt = 0.0
	_perf_frame_max = 0.0
	move_child(_perf, get_child_count() - 1)


func _toggle_balance_overlay() -> void:
	if _balance != null:
		_balance.queue_free()
		_balance = null
		return
	_balance = UiTheme.label("", 15, Color.WHITE)
	_balance.add_theme_stylebox_override("normal", UiTheme.box(Color(0, 0, 0, 0.78), 10, 10))
	_balance.position = Vector2(8, 150)
	_balance.custom_minimum_size = Vector2(430, 0)
	_balance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_balance)
	_balance.text = _balance_text()


func _balance_text() -> String:
	var gs = GameState
	var lines := []
	lines.append("BALANCE  (B hides · F +1h · H +8h · T x10)")
	lines.append("Played %s  ·  speed x%d" % [gs.fmt_time(gs.play_time), int(Engine.time_scale)])
	lines.append("Idle %s/s  ·  slowest: %s" % [gs.money(gs.idle_income()), gs.bottleneck() if gs.bays_total_income() > 0.0 else "-"])
	var nb: float = gs.next_bay_cost()
	if nb >= 0.0:
		lines.append("Next bay %s  ->  %s" % [gs.money(nb), _eta_text(nb)])
	var k: int = gs.reno_needed()
	if k > 0:
		if gs.reno_ready():
			lines.append("Renovation %d: ready, tap the lock" % k)
		elif gs.reno_running():
			lines.append("Renovation %d: %s left" % [k, gs.fmt_time(gs.reno_left())])
		else:
			lines.append("Renovation %d %s (%s)  ->  %s" % [k, gs.money(gs.reno_cost()), gs.fmt_time(gs.reno_seconds(k)), _eta_text(gs.reno_cost())])
	var pc: float = gs.prestige_cost(gs.active_city)
	if pc >= 0.0:
		var need: String = gs.prestige_needs(gs.active_city)
		lines.append("Prestige %s  ->  %s%s" % [gs.money(pc), _eta_text(pc),
			("  (needs " + str(gs.city_def(need)["name"]).split(",")[0] + ")") if need != "" else ""])
	lines.append("x city %s · boost %s · rep %s · book %s" % [gs.fmt(gs.city_mult() / gs.total_boost()), gs.fmt(gs.total_boost()),
		gs.fmt(gs.reputation_mult()), gs.fmt(gs.book_set_mult())])
	lines.append("x uniforms  bay %s · valet %s · desk %s" % [gs.fmt(gs.wardrobe_mult("bay")), gs.fmt(gs.wardrobe_mult("valet")), gs.fmt(gs.wardrobe_mult("desk"))])
	lines.append("Gloss %d · Certs %d · Case Files %d" % [gs.gloss, gs.certs, gs.unopened_case_files()])
	return "\n".join(lines)


func _eta_text(cost: float) -> String:
	var t: float = GameState.eta(cost)
	if t == 0.0:
		return "can buy now"
	return "never (no idle income)" if t < 0.0 else GameState.fmt_time(t)


func _open_hometown() -> void:
	var p := HometownPanel.new()
	add_child(p)
	p.setup()


func _open_map(tab: int = 0) -> void:
	_end_tutorial_quietly()
	if tab == 0:
		GameState.mark_city_nudges_seen()
	var p := MapPanel.new()
	add_child(p)
	p.setup(tab)
	# v0.19w perf: the map covers the whole screen, but the shop under it kept drawing every frame (most of the
	# map's frame time). Hide the shop while the map is open.
	_scroll.visible = false
	p.tree_exiting.connect(func():
		if is_instance_valid(_scroll):
			_scroll.visible = true)
	_tip("map")


## v0.17h: "What are Shine Bucks?" card (top-right button). Its button opens the Shop.
func _open_premium_info() -> void:
	_end_tutorial_quietly()
	var p := InfoPanel.new()
	add_child(p)
	p.setup_premium()
	p.go_pressed.connect(_open_shop)


## v0.17h: Reputation card (stars + followers). Its button opens the Book.
func _open_reputation() -> void:
	_end_tutorial_quietly()
	var p := InfoPanel.new()
	add_child(p)
	p.setup_reputation()
	p.go_pressed.connect(_open_book)


func _open_book() -> void:
	_end_tutorial_quietly()
	GameState.mark_book_seen()
	var p := BookPanel.new()
	add_child(p)
	p.setup()
	_tip("book")
	if not GameState.book_opened:
		# v0.19k: sets you've already collected complete now, AFTER the Book tip (the tip takes the screen
		# on the next frame; a big message then waits for its GOT IT)
		for i in 3:
			await get_tree().process_frame
		GameState.open_book_first()


## Toasts queue up so several events in a row don't overwrite each other.
## need_ok = false (v0.19j): a routine note that closes by itself after read_time() (or a tap on it).
func _show_toast(t: String, need_ok: bool = true) -> void:
	if not need_ok:
		_quiet_toasts[t] = true
	_toast_queue.append(t)
	if not _toast_busy:
		_next_toast()


func _next_toast() -> void:
	if _toast_queue.is_empty():
		_toast_busy = false
		_toast_box.visible = false
		_toast.text = ""
		return
	_toast_busy = true
	move_child(_toast_box, get_child_count() - 1)
	if big_showing():
		move_child(_big_node, get_child_count() - 1)   # the big card (and its dim) stays on top
	var raw: String = _toast_queue.pop_front()
	_toast.text = raw
	_toast.custom_minimum_size = Vector2(maxf(200.0, size.x - 60.0 - 28.0 - 112.0), 0)
	# v0.19v: a toast with an icon in it ("+5 {sb}") shows as rich text; _toast keeps the words (plain)
	var rich := raw.contains("{")
	if rich:
		_toast.text = UiTheme.plain(raw)
		if _toast_rich == null:
			_toast_rich = UiTheme.rich_label("", 22, Color.WHITE, 6)
			_toast_rich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_toast_rich.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_toast.add_sibling(_toast_rich)
		_toast_rich.custom_minimum_size = _toast.custom_minimum_size
		UiTheme.set_bb(_toast_rich, raw)
	_toast.visible = not rich
	if _toast_rich != null:
		_toast_rich.visible = rich
	_toast_box.offset_top = _toast_box.offset_bottom   # re-fit the card to this text (it grows upwards)
	_toast_box.visible = true
	_toast_box.modulate.a = 1.0
	var quiet := _quiet_toasts.has(raw)
	_quiet_toasts.erase(raw)
	_toast_ok.visible = GameState.popups_need_ok and not quiet
	_toast_at = Time.get_ticks_msec()
	if _toast_ok.visible:
		return   # v0.19j: stays until OK
	_toast_tween = _toast_box.create_tween()
	if GameState.popups_need_ok:
		_toast_tween.tween_interval(read_time(_toast.text))
	else:
		_toast_tween.tween_interval(1.4 if _toast_queue.is_empty() else 0.9)   # (autotest: the old timing)
	_toast_tween.tween_property(_toast_box, "modulate:a", 0.0, 0.35)
	_toast_tween.tween_callback(_next_toast)


## v0.19j: how long a message that closes by itself stays up: about 1 s + a bit per word, 3-6 s.
static func read_time(t: String) -> float:
	return clampf(1.0 + 0.28 * t.split(" ", false).size(), 3.0, 6.0)


## v0.19j: renovations that finished together (e.g. while you were away) come as one toast.
func _flush_reno() -> void:
	var items := _reno_pending.duplicate()
	_reno_pending = []
	if items.is_empty():
		return
	if items.size() == 1:
		var id: String = items[0][0]
		var k: int = int(items[0][1])
		if GameState.is_hometown(id):
			_show_toast("Hometown renovation done: it's a %s now!" % Data.HOMETOWN_STAGES[clampi(k, 0, 3)]["name"])
		else:
			_show_toast("%s: renovation done (%s). +%d {sb}, +%d Certs" % [str(GameState.city_def(id)["name"]).split(",")[0],
				GameState.reno_name(k, id), Data.RENO_GLOSS, Data.RENO_CERTS])
		return
	var names := []
	var cities := 0
	for it in items:
		if GameState.is_hometown(it[0]):
			names.append("Hometown (now a %s)" % Data.HOMETOWN_STAGES[clampi(int(it[1]), 0, 3)]["name"])
		else:
			cities += 1
			names.append(str(GameState.city_def(it[0])["name"]).split(",")[0])
	var t := "%d renovations done: %s." % [items.size(), ", ".join(names)]
	if cities > 0:
		t += "  +%d {sb}, +%d Certs" % [cities * Data.RENO_GLOSS, cities * Data.RENO_CERTS]
	_show_toast(t)


## v0.19j: OK on the toast: the next one waiting (if any) takes its place.
func _dismiss_toast() -> void:
	if not _toast_busy or _toast_closing or Time.get_ticks_msec() - _toast_at < OK_GRACE_MS:
		return
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_closing = true
	var tw := _toast_box.create_tween()
	tw.tween_property(_toast_box, "modulate:a", 0.0, 0.12)
	tw.tween_callback(func():
		_toast_closing = false
		_next_toast())


func _build_offline_popup() -> void:
	_popup = ColorRect.new()
	_popup.color = Color(0, 0, 0, 0.65)
	_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_popup.visible = false
	add_child(_popup)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(580, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	panel.add_child(v)

	# v0.19u: a little scene: your shop under today's sky, a fat money bag out front (what they made)
	var pic := Control.new()
	pic.custom_minimum_size = Vector2(0, 200)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.draw.connect(func():
		var w := pic.size.x
		var nt := Scenery.night_amount()
		var sky := Scenery.sky_colors(-1.0, GameState.raining())
		UiTheme.rounded(pic, Rect2(0, 0, w, 200), sky[1], 16, 3, UiTheme.INK)
		Scenery.vgrad(pic, Rect2(3, 3, w - 6, 150), sky[0], sky[1])
		if nt > 0.0:
			for k in 14:
				pic.draw_circle(Vector2(fmod(k * 83.0 + 20.0, w - 20.0) + 10.0, fmod(k * 37.0, 70.0) + 10.0), 1.4, Color(1, 1, 0.9, nt))
		var wall := Color(GameState.premises_def()["color"]).lerp(Color("cfd8e3"), 0.55)
		Scenery.shop_front(pic, Rect2(w * 0.08, 52, w * 0.58, 120), GameState.shop_name if GameState.shop_name != "" else "WELCOME BACK", wall, nt, Time.get_ticks_msec() * 0.001)
		UiTheme.rounded(pic, Rect2(3, 172, w - 6, 25), Color("5b606c"), 12)
		Scenery.money_bag(pic, Vector2(w * 0.8, 140), 44.0)
		for k in 3:
			UiTheme.rounded(pic, Rect2(w * 0.8 - 92 + k * 8, 160 - k * 9, 50, 12), Color("6fd36a").darkened(0.1 * k), 3, 2, UiTheme.INK))
	v.add_child(pic)
	_popup_pic = pic
	var head := UiTheme.label("Welcome back!", 42, UiTheme.CASH)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	_popup_label = UiTheme.label("", 26)
	_popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_popup_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_popup_label)

	var collect := UiTheme.button("Collect", 28, UiTheme.GOOD)
	collect.custom_minimum_size = Vector2(0, 80)
	collect.pressed.connect(func():
		GameState.collect_offline(1.0)
		_popup.visible = false)
	v.add_child(collect)

	# Rewarded ad goes here later (AdMob). Placeholder: works straight away.
	_double_btn = UiTheme.button("", 22)
	_double_btn.custom_minimum_size = Vector2(0, 64)
	_double_btn.pressed.connect(func():
		GameState.collect_offline(2.0)
		_popup.visible = false)
	v.add_child(_double_btn)


func _show_offline_popup() -> void:
	move_child(_popup, get_child_count() - 1)
	_double_btn.text = "Collect x2  (free with no-ads pack)" if GameState.ad_free() else "Collect x2  (watch ad)"
	var lines := []
	for cid in GameState.pending_offline.keys():
		lines.append(GameState.money(GameState.pending_offline[cid], cid))
	_popup_label.text = "Your managers kept the shops running for %s and earned\n%s" % [
		GameState.fmt_time(GameState.pending_offline_seconds), "\n".join(lines)]
	if GameState.last_away_followers >= 1.0:   # v0.19t
		_popup_label.text += "\n+%s followers from your showroom" % GameState.fmt(floorf(GameState.last_away_followers))
	var others := 0   # v0.19v: your other shops kept theirs: COLLECT on the map
	for id in GameState.stash.keys():
		if id != GameState.active_city and GameState.stash_of(id) > 0.0:
			others += 1
	if others > 0:
		_popup_label.text += "\nYour other %s saved up too: COLLECT on the MAP" % ("shop" if others == 1 else "%d shops" % others)
	_popup.visible = true
	_popup_pic.queue_redraw()
