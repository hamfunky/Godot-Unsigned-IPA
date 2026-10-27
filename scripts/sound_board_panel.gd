extends "res://scripts/sheet.gd"
## Sound board (v0.17g, playtest tool, Shop > Settings): every sound in the game, by slot. Tap a version
## to hear it AND use it from now on (saved). Slots with one sound just play it so you can judge it.
## Tell Claude which ones you like (or drop new .ogg files in and add them to Sfx.SOUNDS).

var _btns: Dictionary = {}   # slot -> Array of version buttons
var _track: Label

const NAMES := {"click": "Any button", "tap": "Tap a station to start it", "open": "A panel opens", "close": "A panel closes",
	"toggle": "Settings switch", "cash": "Front desk pays (when you tap it)", "level_up": "Buy a level", "hire": "Hire a manager",
	"error": "Can't do that", "boost": "Boost / ability", "build_bay": "Build a bay", "reno_start": "Start a renovation",
	"unlock": "Renovation unlocked", "big_win": "Big reward", "vip_arrive": "Rare car arrives", "vip_done": "Rare car paid",
	"car_done": "Car finished", "valet_drop": "Valet drops off", "new_car": "New car"}


func setup() -> void:
	set_finish("carbon")   # v0.19u
	set_title("Sound board")
	var intro := UiTheme.label("Tap a version to hear it. The one you tap last is the one the game uses.", 18, Color("e3ecff"))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(intro)

	# music
	body.add_child(UiTheme.ribbon("MUSIC", 17, Color("8e5bd9")))
	var mrow := PanelContainer.new()
	mrow.add_theme_stylebox_override("panel", UiTheme.card(UiTheme.CARD, 14, 10))
	body.add_child(mrow)
	var mh := HBoxContainer.new()
	mh.add_theme_constant_override("separation", 10)
	mrow.add_child(mh)
	_track = UiTheme.label("", 19)
	_track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_track.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mh.add_child(_track)
	var nxt := UiTheme.button("NEXT TRACK", 18, UiTheme.ACCENT)
	nxt.custom_minimum_size = Vector2(170, 56)
	nxt.pressed.connect(func(): Sfx._next_track())
	mh.add_child(nxt)

	body.add_child(UiTheme.ribbon("SOUNDS YOU CAN SWAP", 17, Color("2f9bff")))
	for key in Sfx.SOUNDS.keys():
		if Sfx.SOUNDS[key].size() > 1:
			_slot_row(key)
	body.add_child(UiTheme.ribbon("THE REST (tap to hear)", 17, Color("5d6a85")))
	for key in Sfx.SOUNDS.keys():
		if Sfx.SOUNDS[key].size() == 1:
			_slot_row(key)
	_refresh()


func _slot_row(key: String) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.card(UiTheme.CARD, 14, 10))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	body.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(UiTheme.outlined(UiTheme.label(NAMES.get(key, key), 19), 4))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	var list := []
	for i in Sfx.SOUNDS[key].size():
		var b := UiTheme.button(str(Sfx.SOUNDS[key][i][0]), 16, Color("2a63c4"))
		b.custom_minimum_size = Vector2(0, 52)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			Sfx.stop_effects()   # (cuts the button's own click)
			Sfx.play_version(key, i)
			if Sfx.SOUNDS[key].size() > 1:
				Sfx.set_pick(key, i)
			_refresh())
		h.add_child(b)
		list.append(b)
	_btns[key] = list


func _refresh() -> void:
	for key in _btns.keys():
		var list: Array = _btns[key]
		if list.size() < 2:
			continue
		for i in list.size():
			UiTheme.set_tab_look(list[i], i == Sfx.pick(key))


func _process(_delta: float) -> void:
	_track.text = ("Now playing: " + Sfx.track_name()) if Sfx.music_on() else "Music is off (Shop > Settings)"
