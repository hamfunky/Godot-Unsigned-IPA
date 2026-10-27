extends "res://scripts/sheet.gd"
## Prestige screen for a city (tap the shop sign, the shining HUD badge, or PRESTIGE
## on the map). Like Idle Miner's: what you have now -> what you get, the rewards,
## the price, what resets and what you keep. Two taps to confirm.

const Data = preload("res://scripts/game_data.gd")
const HudMeta = preload("res://scripts/hud_meta.gd")

var city_id := ""
var _btn: Button
var _cash: Label
var _confirm_until := 0.0
var _shown := ""


func setup(id: String = "") -> void:
	city_id = GameState.active_city if id == "" else id
	_build()


func _process(_delta: float) -> void:
	var p := int(GameState.cities[city_id]["prestige"])
	if "%s:%d" % [city_id, p] != _shown:
		_build()
	_refresh()


func _build() -> void:
	var p := int(GameState.cities[city_id]["prestige"])
	_shown = "%s:%d" % [city_id, p]
	clear_body()
	_btn = null
	set_title("Prestige  ·  " + str(GameState.city_def(city_id)["name"]).split(",")[0])
	var cid := GameState.country_of(city_id)
	var maxed := p >= Data.MAX_PRESTIGE
	var now_pr := GameState.premises_def(p)
	var cur_mult := GameState.city_mult_of(city_id)

	_name_row()
	# --- now -> next
	var cmp := HBoxContainer.new()
	cmp.add_theme_constant_override("separation", 10)
	body.add_child(cmp)
	cmp.add_child(_premises_card(p, "NOW", cur_mult))
	if not maxed:
		var arrow := UiTheme.outlined(UiTheme.display_label(">", 44, UiTheme.CASH), 8)
		arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		arrow.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cmp.add_child(arrow)
		cmp.add_child(_premises_card(p + 1, "NEXT", cur_mult * Data.PRESTIGE_MULT))
	if maxed:
		var l := UiTheme.label("Fully upgraded: this is the best premises a city can have.", 19, UiTheme.GOOD)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(l)
	else:
		# --- rewards
		_section("YOU GET", Color("ffd54f"), [
			"Income in %s  x%s  (x%s -> x%s)" % [str(GameState.city_def(city_id)["name"]).split(",")[0], GameState.fmt(Data.PRESTIGE_MULT),
				GameState.fmt(cur_mult), GameState.fmt(cur_mult * Data.PRESTIGE_MULT)],
			"Better customers: %s" % _tiers(p + 1),
			"+%d {sb},  %d Certs" % [Data.PRESTIGE_GLOSS, Data.PRESTIGE_CERTS],
		])
		_section("FULL RESET OF THIS CITY", UiTheme.WARN, [
			"Bays, levels and renovations: back to 1 bay at Lv 1",
			"Cash managers hired here are let go (hiring starts cheap again)",
		])
		_section("YOU KEEP", UiTheme.GOOD, [
			"Your %s cash and every other city" % GameState.country_def(cid)["currency"],
			"Premium managers (freed to work anywhere), gear, uniforms, boosters",
			"Book, reputation, skill tree, Hometown Garage",
		])
		var need := GameState.prestige_needs(city_id)
		if need != "":
			var nl := UiTheme.label("Prestige opens once you've unlocked %s, your %s city in %s." % [
				str(GameState.city_def(need)["name"]).split(",")[0], _ordinal(Data.PRESTIGE_NEEDS_CITY), GameState.country_def(cid)["name"]], 19, UiTheme.WARN)
			nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			body.add_child(nl)
		_cash = UiTheme.label("", 18, UiTheme.MUTED)
		_cash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(_cash)
		_btn = UiTheme.button("", 26, Color("8e24aa"))
		_btn.custom_minimum_size = Vector2(0, 88)
		_btn.pressed.connect(_on_prestige)
		body.add_child(_btn)
	_refresh()


## v0.19t: name your shop (shows on the sign in every city: "Hamza's Detailing · Lima").
func _name_row() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.card(UiTheme.CARD, 12, 10))
	body.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	var le := LineEdit.new()
	le.name = "ShopName"
	le.placeholder_text = "Name your shop"
	le.text = GameState.shop_name
	le.max_length = Data.SHOP_NAME_MAX
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.custom_minimum_size = Vector2(0, 60)
	le.add_theme_font_size_override("font_size", 22)
	h.add_child(le)
	var b := UiTheme.button("SAVE NAME", 20, UiTheme.GOOD)
	b.custom_minimum_size = Vector2(170, 60)
	var save := func(_t = ""):
		GameState.set_shop_name(le.text)
		le.text = GameState.shop_name
		le.release_focus()
		Sfx.play("click")
	b.pressed.connect(save)
	le.text_submitted.connect(save)
	h.add_child(b)


func _premises_card(p: int, tag: String, mult: float) -> Control:
	var pr := GameState.premises_def(p)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := UiTheme.card(Color(pr["color"]).lightened(0.12), 20, 12, UiTheme.CASH if tag == "NEXT" else UiTheme.INK)
	card.add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)
	v.add_child(UiTheme.ribbon(tag, 14, Color("f5a300") if tag == "NEXT" else Color("5d6a85")))
	v.add_child(UiTheme.outlined(UiTheme.display_label(pr["name"], 21), 6))
	var stars := Control.new()
	stars.custom_minimum_size = Vector2(0, 22)
	stars.draw.connect(func():
		for k in Data.MAX_PRESTIGE:
			HudMeta.draw_trophy(stars, Vector2(11 + k * 24, 11), 20.0, k < p))   # v0.17h-3: prestige = trophies
	v.add_child(stars)
	v.add_child(UiTheme.outlined(UiTheme.display_label("x%s income" % GameState.fmt(mult), 22, UiTheme.CASH), 6))
	return card


func _section(title: String, color: Color, lines: Array) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.card(UiTheme.CARD, 12, 10))
	body.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	v.add_child(UiTheme.ribbon(title, 15, color))
	for t in lines:
		if str(t).contains("{"):   # v0.19v: a line with an icon in it ("+5 {sb}")
			v.add_child(UiTheme.rich_label("·  " + str(t), 17, UiTheme.TEXT, 0, false, false))
			continue
		var l := UiTheme.label("·  " + str(t), 17)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)


static func _ordinal(n: int) -> String:
	return str(n) + ({1: "st", 2: "nd", 3: "rd"}.get(n, "th") if n < 11 or n > 13 else "th")


func _tiers(p: int) -> String:
	var tiers: Array = GameState.premises_def(p)["tiers"]
	return "%s to %s" % [Data.TIER_NAMES[tiers[0]], Data.TIER_NAMES[tiers[-1]]]


func _refresh() -> void:
	if _btn == null:
		return
	var cid := GameState.country_of(city_id)
	var cost := GameState.prestige_cost(city_id)
	var have: float = GameState.wallets.get(cid, 0.0)
	_cash.text = "Costs %s  ·  you have %s" % [GameState.money(cost, cid), GameState.money(have, cid)]
	var need := GameState.prestige_needs(city_id)
	var can := have >= cost and need == ""
	if need != "":
		_btn.text = "NEEDS %s" % str(GameState.city_def(need)["name"]).split(",")[0].to_upper()
	elif GameState.now < _confirm_until:
		_btn.text = "TAP AGAIN TO PRESTIGE"
	else:
		_btn.text = ("PRESTIGE   " + GameState.money(cost, cid)) if can else "NEED %s MORE" % GameState.money(cost - have, cid)
	_btn.disabled = not can


func _on_prestige() -> void:
	# two taps so nobody resets a city by accident
	if GameState.now < _confirm_until:
		_confirm_until = 0.0
		var id := city_id
		var p := int(GameState.cities[id]["prestige"]) + 1 if GameState.cities.has(id) else 1
		var main := get_tree().current_scene
		if main != null and main.has_method("with_loading"):   # v0.19w: a prestige is a big change: loading card
			main.with_loading(GameState.prestige_city.bind(id), id, "Prestige %d: a fancier shop!" % p)
		else:
			GameState.prestige_city(id)
		close()
	else:
		_confirm_until = GameState.now + 3.0
