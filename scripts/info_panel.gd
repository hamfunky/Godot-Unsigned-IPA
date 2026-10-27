extends "res://scripts/sheet.gd"
## v0.17h (playtest: "what is Gloss?", "make followers understandable"): short explainer cards.
##   setup_premium()     - what Shine Bucks are, how you get them, what they buy
##   setup_reputation()  - rating + followers: what they do, how you get them, how close the next half star is

const Data = preload("res://scripts/game_data.gd")
const HudMeta = preload("res://scripts/hud_meta.gd")

signal go_pressed   # the big button at the bottom (Shop / Book)

var _live: RichTextLabel   # v0.19v: rich (icons in it)
var _live_fn: Callable


func setup_premium() -> void:
	set_finish("carbon")   # v0.19u
	set_title(Data.PREMIUM_NAME)
	_banner("premium", "%s are the game's special money. You keep them forever (prestige never takes them)." % Data.PREMIUM_NAME, Color("2a9d78"))
	_live = _big_number()
	_live_fn = func(): return "You have %s {sb}" % GameState.fmt(GameState.gloss)
	_section("SPEND THEM ON", Color("2f9bff"), [
		"Lucky Wheel spins: boosters, cash, Case Files, even a Legendary manager (Shop)",
		"Boosters: x2 to x5 income for a while (Shop)",
		"Extra display slots in your Book",
	])
	_section("GET THEM FROM", Color("e0a000"), [
		"Reaching a big boost on any station (Lv 10, 25, 50...): +%d, then +%d, then +%d" % [Data.BOOST_GLOSS[0], Data.BOOST_GLOSS[1], Data.BOOST_GLOSS_REST],
		"Rare cars: +2 to +20 each",
		"Every half star on your rating: +%d" % Data.STAR_GLOSS,
		"Finishing a renovation: +%d" % Data.RENO_GLOSS,
		"Completing a set in your Book: +%d" % Data.TIER_SET_GLOSS,
		"Prestiging a city: +%d" % Data.PRESTIGE_GLOSS,
	])
	_go("SPEND THEM IN THE SHOP", UiTheme.GOOD)
	_refresh_live()


func setup_reputation() -> void:
	set_finish("carbon")   # v0.19u
	set_title("Reputation")
	_banner("rep", "People review your shop online. More followers = a better rating (up to 5 stars), and every half star makes the whole shop better." if GameState.has_reviews() else "People review your shop online. You're brand new, so nobody has yet: get followers for your first reviews (a rare car always brings some), then climb to 5 stars. Every half star makes the whole shop better.", Color("7d4bd1"))
	# v0.17h-3: a Google-style rating row instead of a row of 9 stars
	var stars := Control.new()
	stars.custom_minimum_size = Vector2(0, 56)
	stars.draw.connect(func():
		HudMeta.draw_rating(stars, Vector2(stars.size.x * 0.5, 28), 22.0, GameState.rating()))
	stars.process_mode = Node.PROCESS_MODE_ALWAYS
	body.add_child(stars)
	_live = _big_number()
	_live_fn = func():
		var nxt := GameState.next_star_followers()
		return "%s  ·  %s followers%s" % [("Rated %s / 5" % GameState.rating_text()) if GameState.has_reviews() else "No reviews yet", GameState.fmt(GameState.followers),
			("\nNext: %s stars at %s followers" % [GameState.rating_text(GameState.stars() + 1), GameState.fmt(nxt)]) if nxt > 0.0 else "\nTop rating! 5 stars"]
	_section("EVERY HALF STAR GIVES YOU", Color("e0a000"), [
		"x%s income in all your bays (now x%s)" % [str(Data.STAR_INCOME_BONUS), "%.2f" % GameState.reputation_mult()],
		"Rare cars visit %d%% more often" % int(Data.STAR_VIP_BONUS * 100.0),
		"+%d {sb} and a free x2 Booster" % Data.STAR_GLOSS,
	])
	_section("GET FOLLOWERS BY", Color("2f9bff"), [
		"Washing a car you've never had before (it goes in your Book)",
		"Finishing rare cars: lots of followers each",
		"Putting cars ON SHOW in your Book: followers every hour, even while you're away",
		"Shop decor (SHOP > SHOP DECOR): +%d an hour each, even while you're away" % int(Data.DECOR_FOLLOWERS),
	])
	_reviews()
	_go("OPEN YOUR BOOK", Color("8e44ad"))
	_refresh_live()


## v0.19t: what customers are saying today (3 short reviews, stars round your rating).
func _reviews() -> void:
	var rv := GameState.todays_reviews()
	if rv.is_empty():
		return
	body.add_child(UiTheme.ribbon("WHAT CUSTOMERS SAY", 17, Color("ff6fa5")))
	for r in rv:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UiTheme.card(Color("fff6e5"), 14, 12))
		body.add_child(p)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		p.add_child(v)
		var st := Control.new()
		st.custom_minimum_size = Vector2(0, 26)
		var stars: float = r[0]
		st.draw.connect(func():
			for k in 5:
				var fill := clampf(stars - k, 0.0, 1.0)
				HudMeta.draw_star(st, Vector2(14 + k * 26, 13), 11.0, fill >= 0.99)
				if fill > 0.0 and fill < 0.99:
					HudMeta.draw_star(st, Vector2(14 + k * 26, 13), 6.0, true))
		v.add_child(st)
		var q := UiTheme.label("\"%s\"" % r[1], 19, UiTheme.INK)
		q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(q)
		v.add_child(UiTheme.label("— %s" % r[2], 16, Color("8a7a66")))


func _process(_delta: float) -> void:
	_refresh_live()


func _refresh_live() -> void:
	if _live != null and _live_fn.is_valid():
		UiTheme.set_bb(_live, _live_fn.call())


## Coloured card at the top with the icon and one plain sentence.
func _banner(icon: String, text: String, col: Color) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.card(col, 20, 14, UiTheme.INK))
	body.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	var ic := Control.new()
	ic.custom_minimum_size = Vector2(70, 64)
	ic.draw.connect(func():
		if icon == "premium":
			HudMeta.draw_droplet(ic, Vector2(35, 34), 24.0)
		else:
			HudMeta.draw_star(ic, Vector2(35, 32), 28.0, true))
	h.add_child(ic)
	var l := UiTheme.outlined(UiTheme.label(text, 21, Color.WHITE), 5)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)


func _big_number() -> RichTextLabel:
	var l := UiTheme.rich_label("", 26, UiTheme.CASH, 7, true)
	body.add_child(l)
	return l


func _section(title: String, col: Color, lines: Array) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.card(UiTheme.CARD, 16, 12))
	body.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(UiTheme.ribbon(title, 18, col))
	for t in lines:
		if str(t).contains("{"):   # v0.19v: a line with an icon in it ("+5 {sb}")
			v.add_child(UiTheme.rich_label("·  " + str(t), 20, UiTheme.TEXT, 0, false, false))
			continue
		var l := UiTheme.label("·  " + str(t), 20)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)


func _go(text: String, col: Color) -> void:
	var b := UiTheme.button(text, 24, col)
	b.custom_minimum_size = Vector2(0, 80)
	b.pressed.connect(func():
		go_pressed.emit()
		close())
	body.add_child(b)
