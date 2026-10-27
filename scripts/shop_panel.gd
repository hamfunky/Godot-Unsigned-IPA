extends "res://scripts/sheet.gd"
## Shop: shop-wide upgrades, future premium items, and debug tools.

var _stats: Label
var _wheel_btn: Button
var _decor_btns: Array = []   # v0.19t: [Button, decor id]
var _alerts: CheckButton

const Data = preload("res://scripts/game_data.gd")
const SoundBoard = preload("res://scripts/sound_board_panel.gd")
const WardrobePanel = preload("res://scripts/wardrobe_panel.gd")


func setup() -> void:
	set_title("Shop")
	# v0.19n: the Lucky Wheel, first thing in the Shop
	# v0.19v: "[wheel] LUCKY WHEEL · spin for 50 [Shine Bucks]" (icons, not words); also in the sky over the shop
	var wb0 := UiTheme.button("", 24, Color("ff9a2e"))
	wb0.custom_minimum_size = Vector2(0, 80)
	_wheel_btn = wb0
	wb0.pressed.connect(func():
		var wp = load("res://scripts/wheel_panel.gd").new()
		get_parent().add_child(wp)
		wp.setup()
		close())
	body.add_child(wb0)

	# v0.19v (Hamza): Night Shift is gone: time away always earns in full, however long you're away
	# v0.19v (Hamza): "Recharge manager abilities" for Shine Bucks is gone (too strong; not worth it if pricier)
	# v0.19j: boosters are sold as 3 rotating deals (each once per 12 h) on the Boosts screen, not here
	body.add_child(UiTheme.ribbon("BOOSTERS", 17, Color("e0a000")))
	var deals := UiTheme.button("", 22, Color("e0a000"))
	UiTheme.set_rich(deals, "{booster}  TODAY'S BOOSTER DEALS  >")
	deals.custom_minimum_size = Vector2(0, 68)
	deals.pressed.connect(func():
		var m := get_parent()
		close()
		if m.has_method("_open_boosts"):
			m._open_boosts())
	body.add_child(deals)

	var wb := UiTheme.button("", 22, Color("8e24aa"))
	UiTheme.set_rich(wb, "{wardrobe}  WARDROBE  ·  crew uniforms")
	wb.custom_minimum_size = Vector2(0, 72)
	wb.pressed.connect(func():
		var wp := WardrobePanel.new()
		get_parent().add_child(wp)
		wp.setup())
	body.add_child(wb)
	_decor_section()
	for t in ["%s packs  (coming soon)" % Data.PREMIUM_NAME, "Remove ads  (coming soon)"]:
		var b := UiTheme.button(t, 20, Color("3d4657"))
		b.disabled = true
		b.custom_minimum_size = Vector2(0, 60)
		body.add_child(b)

	body.add_child(UiTheme.ribbon("SETTINGS", 17, Color("5d6a85")))
	_alerts = CheckButton.new()
	_alerts.text = "Rare car alerts (for cars not in your Book yet)"
	_alerts.add_theme_font_size_override("font_size", 19)
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		_alerts.add_theme_stylebox_override(st, UiTheme.card(UiTheme.CARD, 12, 12))
	_alerts.button_pressed = GameState.settings.get("rare_alerts", true)
	_alerts.toggled.connect(func(on): GameState.set_setting("rare_alerts", on))
	body.add_child(_alerts)
	for opt in [["sound", "Sound effects"], ["vibration", "Vibration"], ["ad_free", "No-ads pack (placeholder: ad buttons are free skips)"]]:
		var key: String = opt[0]
		var cb := CheckButton.new()
		cb.text = opt[1]
		cb.add_theme_font_size_override("font_size", 19)
		for st in ["normal", "hover", "pressed", "hover_pressed"]:
			cb.add_theme_stylebox_override(st, UiTheme.card(UiTheme.CARD, 12, 12))
		cb.button_pressed = GameState.settings.get(key, true)
		cb.toggled.connect(func(on):
			GameState.set_setting(key, on)
			Sfx.play("toggle"))
		body.add_child(cb)

	# v0.17g: music on/off + volume, and the Sound board (audition / swap every sound)
	var mus := CheckButton.new()
	mus.text = "Music"
	mus.add_theme_font_size_override("font_size", 19)
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		mus.add_theme_stylebox_override(st, UiTheme.card(UiTheme.CARD, 12, 12))
	mus.button_pressed = Sfx.music_on()
	mus.toggled.connect(func(on):
		GameState.set_setting("music", on)
		Sfx.refresh_music()
		Sfx.play("toggle"))
	body.add_child(mus)
	var vrow := PanelContainer.new()
	vrow.add_theme_stylebox_override("panel", UiTheme.card(UiTheme.CARD, 12, 12))
	body.add_child(vrow)
	var vh := HBoxContainer.new()
	vh.add_theme_constant_override("separation", 12)
	vrow.add_child(vh)
	vh.add_child(UiTheme.label("Music volume", 19))
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = Sfx.music_volume()
	vol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vol.custom_minimum_size = Vector2(0, 40)
	vol.value_changed.connect(func(x):
		GameState.settings["music_volume"] = x
		Sfx.refresh_music())
	vol.drag_ended.connect(func(_c): GameState.set_setting("music_volume", vol.value))
	vh.add_child(vol)
	var sb := UiTheme.button("SOUND BOARD  ·  try every sound", 19, Color("8e5bd9"))
	sb.custom_minimum_size = Vector2(0, 60)
	sb.pressed.connect(func():
		var p := SoundBoard.new()
		get_parent().add_child(p)
		p.setup())
	body.add_child(sb)
	var tips := UiTheme.button("SHOW TIPS AGAIN", 19, Color("2a63c4"))
	tips.custom_minimum_size = Vector2(0, 60)
	tips.pressed.connect(func():
		GameState.reset_tips()
		tips.text = "Tips will show again"
		tips.disabled = true)
	body.add_child(tips)

	_stats = UiTheme.label("", 18, UiTheme.MUTED)
	body.add_child(_stats)

	if OS.is_debug_build():
		var reset := UiTheme.button("Reset save (debug only)", 20, Color("b23b3b"))
		reset.custom_minimum_size = Vector2(0, 60)
		reset.pressed.connect(func():
			GameState.reset_save()
			close())
		body.add_child(reset)
		var dk := UiTheme.label("Debug keys: M money, G %s, V VIP visit, E materials, B balance overlay, F skip 1h, H skip 8h, T game speed x10, P frame rate." % Data.PREMIUM_NAME, 16, UiTheme.MUTED)
		dk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(dk)
		var row2 := HBoxContainer.new()
		row2.add_theme_constant_override("separation", 8)
		body.add_child(row2)
		for opt in [["Balance overlay", func(): get_parent()._toggle_balance_overlay()], ["FPS", func(): get_parent().toggle_perf_overlay()], ["Skip 1h", func(): GameState.debug_skip(3600.0)],
				["Skip 8h", func(): GameState.debug_skip(28800.0)]]:
			var b := UiTheme.button(opt[0], 17, Color("455a64"))
			b.custom_minimum_size = Vector2(0, 56)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(opt[1])
			row2.add_child(b)
		var lp := UiTheme.label("Milestone log: " + GameState.balance_log_file(), 14, UiTheme.MUTED)
		lp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(lp)
	_refresh()


static func _dur(minutes: float) -> String:
	if minutes >= 1440.0:
		return "%d day%s" % [int(minutes / 1440.0), "" if minutes < 2880.0 else "s"]
	if minutes >= 60.0:
		return "%d hour%s" % [int(minutes / 60.0), "" if minutes < 120.0 else "s"]
	return "%d min" % int(minutes)


## v0.19t SHOP DECOR: bought once with Shine Bucks, shows in every city, +1 follower an hour each.
func _decor_section() -> void:
	body.add_child(UiTheme.ribbon("SHOP DECOR", 17, Color("ff6fa5")))
	var intro := UiTheme.label("Make the place yours. Every piece shows in all your shops and brings +%d follower an hour (curb appeal), even while you're away." % int(Data.DECOR_FOLLOWERS), 18, UiTheme.MUTED)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(intro)
	for d in Data.DECOR:
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UiTheme.card(UiTheme.CARD, 12, 12))
		body.add_child(row)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		row.add_child(h)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(UiTheme.label(str(d["name"]), 22))
		var dl := UiTheme.label(str(d["desc"]), 17, UiTheme.MUTED)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(dl)
		var b := UiTheme.button("", 20, Color("ff6fa5"))
		b.custom_minimum_size = Vector2(170, 64)
		var id: String = d["id"]
		b.pressed.connect(func():
			if GameState.buy_decor(id):
				Sfx.play("level_up")
				Sfx.buzz(20)
			else:
				Sfx.play("error")
			_refresh())
		h.add_child(b)
		_decor_btns.append([b, id])


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	UiTheme.set_rich(_wheel_btn, "{wheel} LUCKY WHEEL  ·  " + ("FREE SPIN READY!" if GameState.wheel_free_ready() else "spin for %d {sb}" % Data.WHEEL_SPIN_COST))
	for pair in _decor_btns:
		var d := GameState.decor_def(pair[1])
		if GameState.has_decor(pair[1]):
			pair[0].disabled = true
			UiTheme.set_rich(pair[0], "IN YOUR SHOP")
		else:
			pair[0].disabled = GameState.gloss < int(d["price"])
			UiTheme.set_rich(pair[0], "%d {sb}" % int(d["price"]))
	_stats.text = "Managers: %d   ·   Premium: %d / %d   ·   Cities: %d" % [GameState.managers.size(), GameState.owned_managers().size(), GameState.roster.size(), GameState.cities.size()]
