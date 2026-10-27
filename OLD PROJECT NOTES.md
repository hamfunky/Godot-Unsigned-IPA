# Idle Detailing Tycoon — OLD project notes (history)

Everything below is the full PROJECT_NOTES.md as it stood on 27 Oct 2026 (v0.19u), moved here so the main
notes stay short. The per-version logs, old decisions and the detailed system write-ups (managers, equipment,
Hometown, wardrobe, renovations, balance history) live here. Newer facts in PROJECT_NOTES.md win where they differ
(e.g. Night Shift and the offline cap are gone since v0.19v, the ad boost is per city, other cities keep a stash).

---

## v0.19v (moved here from PROJECT_NOTES.md when v0.19w was done)

### DONE (27 Oct, v0.19v) — Hamza's 27 Oct list
1. AD BOOST IS PER CITY (Hamza): one ad = x2 for +4h in the city you're in (banked up to 24h).
   `GameState.ad_until` {city: unix time} (+ `ad_boost_until` kept as a property = the current city's);
   `watch_ad_boost(city)`, `ad_boost_left(city)`, `ad_boost_full(city)`. BOOST ALL = one ad for every city of a
   country, only once all 5 of its cities are open (`boost_all_ready / boost_all_wanted / boost_all(cid)`).
   Old saves: the one timer is copied to every city.
2. CITY STASHES (Hamza): a city you're NOT in keeps what it earns in `GameState.stash` {city: amount} until you
   COLLECT it (map) or go there (`go_to_city` collects it, toast "Collected $X that Lima made..."). The city you're
   in pays straight into your cash. Offline: this city -> Welcome back (x2 with an ad), other cities -> their stash.
   `stash_of / collect_city / collect_all / stash_total`, signal `stash_collected`.
3. NO NIGHT SHIFT, NO OFFLINE CAP (Hamza: away 3 days = 3 days of money). Old saves get the Shine Bucks they spent on
   Night Shift back. `SKILL_FLAT_TYPES` lost "offline_hours" (no skill node used it). Economy sim NOT re-run (Hamza).
4. MAP CORNERS (like Idle Miner, `scripts/map_side_panel.gd`): top-left COLLECT (coins) = every city's little shop,
   its stash, its x2 time left, BOOST ALL per country, COLLECT ALL. Top-right PRESTIGE (trophy) = every city's
   trophies, income multiplier, price, PRESTIGE -> that city's prestige screen. Orange dots when there's something.
   Words on the map GROW as you zoom out (`MapLabels.lk`, up to 2.8x) so they stay readable over the whole world.
   Perf: the still world is baked into 4 textures (`_bake_world`, cached between visits); the words, shops and
   pins are a separate layer (`MapLabels`) redrawn twice a second / on zoom.
5. MAIN SCREEN (prototype sent 27 Oct and put in the build so Hamza can try it; WAITING for his verdict; shots proto_main_*): a taller SKY strip above the
   shop (`scripts/sky_row.gd`: skyline, sun / moon + stars by the real clock, rain) with the LUCKY WHEEL on a pole
   (turns slowly, faster + "FREE SPIN!" when one is ready; tap = the wheel). Bottom bar slimmer (buttons 76 px), INFO
   left the bar (the $/s pill under your cash opens the same Overview), and the middle is a big round AD BOOST
   button sticking up out of the bar (`scripts/ad_boost_button.gd`: breathes when off, shows time left + a ring for
   the banked hours; full = opens Boosts).
6. SHINE BUCKS ICON IN PRICES: write `{sb}` where the currency goes ("30 {sb}"). Buttons: `UiTheme.set_rich(b, s)`
   (b.text becomes "" and a centred row of labels + icons is laid over it; the source string is meta "rich_src"),
   sentences: `UiTheme.rich_label()` / `set_bb()` (RichTextLabel, inline images), `UiTheme.plain(s)` = the words back.
   Toasts + big messages switch to rich text when the text has `{`. Other tokens: {wheel} {booster} {wardrobe}.
   Icons are drawn in `scripts/game_icons.gd` and baked to `assets/game/ui/icon_*.png` (tools/bake_icons.gd).
   The word stays where it's a name (titles, explainer card heading, tips' sentences, the shop's packs line).
   Shop: "[wheel] LUCKY WHEEL · spin for 50 [sb]", "[gem] TODAY'S BOOSTER DEALS >", "[tee] WARDROBE".
7. REMOVED: "Recharge manager abilities" for Shine Bucks (Hamza: too strong).
8. BAY KIT, DETAILED (Hamza): one piece of kit per service drawn big in `scripts/kit_art.gd` (bucket + chenille
   mitt, hose reel + foam cannon, shop vac + microfibre stack, clay pegboard + sprays, DA polisher + pads, steamer,
   ceramic case, spanner board + degreaser, carbon panel + graphene bottle, trophy + show photo, PPF rolls + heat gun),
   baked to `assets/game/sprites/kit/kit_<tier>.png` (tools/bake_kit.gd, review sheet kit_sheet.png) and drawn at
   0.23 in the MIDDLE of the bay's shelf (both ends get covered by the crew / car roof); bottles either side.
9. PERFORMANCE (Hamza: ~20-30 fps feel, scrolling worst): every rounded box drew a NEW StyleBoxFlat each frame ->
   `UiTheme.flat()` cache; bays + valet row draw their still parts on a `_bg` child only when they change
   (`_draw_static`, signature check); level buttons redraw only on change (glow + arrow are tweened nodes); HUD pills
   only on change; desk / build rows only while on screen; BAY CARS come from pictures (`scripts/car_cache.gd`:
   each car drawn once clean + once fully dirty into small SubViewports, the dirty one faded over by how dirty it
   still is; sparkles live; LRU 48); the map world is baked. Dev FPS overlay: key P or Shop > FPS (debug builds):
   FPS, scripts+draw ms, render ms, draw calls, shapes, nodes. The cloud box has no GPU, so real numbers must come
   from Hamza's PC / phone.
10. BUGS: the AD BOOST card's timer kept the time it was built with (extra ads looked like they did nothing); the
    valet lane drew one yellow dash above its strip, into the pickup lot.
- Tests: `_v19v_checks`; 674 autotest checks PASS (27 Oct). Shots v19v_01 .. 05.


---

# Idle Detailing Tycoon — project notes

Read this first in any new chat. Keep it short and current.

## >>> HANDOFF: START HERE (new chat) <<<

### NEXT CHAT (27 Oct, after v0.19u): TWO JOBS FROM HAMZA
1. DO: prices as "30 [Shine Bucks icon]", not "30 Shine Bucks". Wherever a number is followed by the word, show
   the number then the real icon (HudMeta.draw_droplet = the mint banknote with a sparkle, drawn in code;
   build_row._draw_gloss_button already does "<label> [icon] N", copy that idea). Plain Buttons can't draw it,
   so they need the icon as a texture (render the droplet once into an ImageTexture and use Button.icon, or a
   tiny "price" Control with label + icon) and a RichTextLabel/inline image for sentences. Places found with
   `grep -n PREMIUM_NAME scripts/*.gd` (33 lines): shop_panel 185/245/255 + wheel line 21, wardrobe_panel 47,
   wheel_panel 207/240/245, book_panel 197/296, main 594/618/633/639/948/950/1006/1297/1309, info_panel 20/58,
   game_state 1896/1900 (delivery reward text), valet_row 92 (cat treat pop text), workshop_panel 61.
   Keep the word where it is a name, not a price (titles like "Shine Bucks", "What are Shine Bucks?", the
   shop ribbon, the debug-keys line).
2. BRAINSTORM WITH HAMZA FIRST, then fix: on his PC in Godot the game does NOT feel smooth, like low FPS.
   Measure before changing anything (Performance monitors / the Godot profiler: FPS, process time, draw calls,
   which _draw()s are hot). Leads to check:
   - ~25 scripts call queue_redraw() every frame in _process (bay_card, build_row x2, valet_row, desk_row,
     desk_backdrop, depth_row, level_button (one per bay), hud_money, hud_meta, portrait, car_card,
     station_manager, ability_icon, lane_overlay, main, ...), and every _draw is many polygons + text,
     redrawn from scratch. Ideas: redraw only when something changed or at 10-20 Hz for idle bits; split the
     static parts (walls, shelves, back lot, kit) into a separate child Control drawn once; cache a static
     look into a texture (SubViewport snapshot / Image) and blit it; skip redraw for bays scrolled off screen.
   - foam_layer: lots of draw_texture_rect blobs per car (smaller bubbles in v0.19u = more of them).
   - project.godot: renderer = "mobile", windows driver = d3d12. Try Forward+ / Compatibility, Vulkan, vsync
     settings, and check physics ticks / max_fps; a 2D UI game may run smoother on Compatibility.
   - Text: many UiTheme.text() calls per frame with outlines (outline size 3-5) are costly.
   - Tweens / timers are fine; float positions (sub-pixel jitter) can also *look* like low FPS: check
     snap 2D transforms/vertices to pixel.
   - Then test on a phone too (the old "phone performance check" item).

### DONE (27 Oct, v0.19u): VISUAL PASS + THE WORLD MAP (Hamza picked 1-5, 7, 8, 9 of the visual list; 10/11 not yet;
### 6 "number-plate labels" left out: he has bigger plans for the map)
1. BAYS: one piece of kit per SERVICE stands at the right end of the bottle shelf (bay_card._draw_service_kit,
   70% size, toned towards the wall so it stays background): bucket, hose reel, vacuum hose, clay pegboard,
   polisher + pads, steamer, lit ceramic bottles, spanner board, carbon panel, trophy + photo, film rolls. From
   Paint Correction a soft LED strip along the wall top. (Wall-mounted version was hidden behind car roofs.)
2. FOAM (foam_layer.gd): bubbles ~2/3 the size, ~2.4x as many (SPACING 0.034, RADIUS 0.033), a touch see-through,
   tiny bubble rims on top, drips running down as it's wiped; layouts cached per body shape (static _layouts) +
   grid neighbour search, so more bubbles cost nothing per car. Hand-wash bubbles smaller + twice as many.
3. LEVEL TAG (level_button.gd): slimmer (74x80 inside the same tap area): dark gloss + chrome rim when you can't
   afford a level (sits back), bright green + soft pulsing glow when you can, gold at max.
4. ALERTS: main._alert_badge is a small orange dot with a white ring in the button's top-right (gold for a new
   rare car), no more red "!" circles.
5. BACK LOT (build_row._draw_back_lot): once every bay's built: asphalt, parking lines, skip bin, tyre stack,
   pallet, painted sign with the message.
7. PANEL FINISHES (sheet.gd finish_box / set_finish): 9-patch StyleBoxTexture rims made in code: "chrome" (default:
   Shop, Wheel, Delivery, Prestige, Hometown, Wardrobe), "gloss" (black gloss: Level, Manager, Overview, Boosts,
   gear picker), "carbon" (Book, Reputation / Shine Bucks info, Dossier, Case result, Sound board). A band of light
   sweeps across the rim when a sheet opens.
8. WORLD MAP (map_panel.gd rewritten): one big code-drawn canvas (WorldCanvas, 2300x3150) you drag (touch drag /
   mouse drag via emulated touch), zoom (pinch, wheel, trackpad; ZOOM_MIN 0.34 .. 1.6) and tap. Countries are
   islands in their theme (USA greens + tan Houston + LA sign; Japan sakura + Mt Fuji; Germany pine forest + ring
   track; Australia outback + big red rock; UAE dunes + palms + tower), split by rivers into the 5 city patches.
   Patch = shop icon (fancier with prestige) + name ribbon + $/s; next city = green UNLOCK ribbon; locked islands
   grey with a padlock + price. Tap a patch / locked island = card at the bottom (GO / PRESTIGE / UNLOCK). The
   accessories are a chain of islets on the left: Hometown Garage (card + GO), Managers, Skill Tree, Equipment
   (open over the map with "< MAP"), Events (soon). Dots on islets when something's waiting. Locate button
   recentres on where you are. Redraws twice a second at most (pan/zoom just move + scale the canvas).
   API kept: setup(tab), _set_tab, _skills/_roster/_equip, _on_prestige; new: select(id), tap(pos), zoom_at, pan.
9. TITLE SCREEN = your shop from the street at the real time of day (sky, sun/moon, stars, rain), your shop name
   on the sign, a car being foamed in the open bay, the hero car out front (Scenery.shop_front). WELCOME BACK has a
   little scene on top (your shop + a money bag, Scenery.money_bag).
- Tests: _v19u_checks (24); 659 autotest checks PASS. Shots v19u_01 .. 07.

### DONE (26 Oct, v0.19t): PACING FIX + A BIG BATCH OF NEW STUFF (Hamza: "happy with whatever you think ... use
### that on adding a tonne of updates ... make the game more appealing and enjoyable to play")
1. PACING (tools/econ_sim.gd runs, PACING_TABLE below). Changes: Night Shift now costs SHINE BUCKS
   (Data.NIGHT_SHIFT base 30 x1.8: 30, 55, 95 ... 5950; GameState.night_shift_gloss(); was cash and maxed in hour 1);
   PRESTIGE_MULT 4 -> 3 (tip + panels read it); PRESTIGE_COSTS[1..4] x8 the v0.19s values; country unlock
   prices = about 1.5 days of the previous country's MAXED income (5e26 / 5e31 / 5e36 / 5e41; every country's
   ceiling is x1e5 the last, since each city is x10). First session unchanged (Night Shift 1 is bought with the
   starting Shine Bucks). Lesson from the runs: a country price far above ~1-2 days of the previous country's
   ceiling = weeks of flat income (Valet/Desk Lv 400 wall) with nothing to buy.
2. UNCOMMON SIGNATURES (own pictures, ability_bubble.py sig): Gazza FOAM CANNON (his bay + both neighbours x3 .. x5
   for 45 .. 90s; GameState.foam_cannon_mult), Yuki FLASH POLISH (her bay's next 10 .. 20 cars take 0.3s each;
   counted, flash_left), Lukas TRAINING DAY (every bay in the city works like +10 .. +25 levels for 60 .. 90s,
   services included; training_bonus), Rosa REFERRAL (a rare car rolls into the lot now, or right after the one
   that's here; referral_wait; 40 min recharge). Mori still open.
3. DAY + NIGHT on the phone's clock (Scenery.local_hour / night_amount / golden_amount / sky_colors; dev:
   Scenery.hour_override): sunset sky, stars + moon, warm bulbs round the sign, the forecourt darkens and the street
   lamp glows. RAINY DAYS: 3h windows of the real clock, 18% chance, the same for everyone, never in a new game's
   first hour (GameState.raining / rain_override for tests): grey sky + clouds, rain streaks, puddles, "RAIN x1.25"
   tag; muddy cars pay x1.25 (weather_mult in _bay_base_pay, Boosts "i" says so).
4. SUDS THE SHOP CAT (scripts/shop_cat.gd, on the valet forecourt): naps / sits up, tap = pet (hearts, a synthesized
   "mrrp", Sfx slot "cat" = pop_mrrp.ogg via audio_synth.py cat); first pet of a local day = +5 Shine Bucks.
   DAILY DELIVERY (scripts/delivery_panel.gd): a parcel in the pickup lot once a day from Bay 6 / a 2nd city;
   7-day track that loops and NEVER resets (2 x2 boosters, 15 SB, Basic File, x3 1h, 30 SB, x5 2h, Classified +
   50 SB). SHOP DECOR (Shop list, Shine Bucks, shown in every city, +1 follower/h each also while away): bunting,
   potted palm, neon OPEN sign, balloons, fountain, gold sign. Tips "delivery" + "cat".
5. Also: CAR OF THE WEEK per city (an everyday model of its first-bay tier, x3 pay + 3 followers, gold tag on the bay,
   line in the Book), customer REVIEWS on the Reputation card (3 a day, GameState.todays_reviews), NAME YOUR SHOP
   (prestige panel; sign = "Name · City"; GameState.shop_name / sign_text), level buys pop "+$X/s", Welcome back
   says the followers from the showroom and when the offline cap cut the time short (Night Shift nudge).
- PACING_TABLE (econ_sim, one seed each; NO abilities / premium managers / skills / Hometown, so real players a bit faster):
  | | Detroit | LA | Japan | Germany | Australia | UAE | Dubai | ~everything prestige 5 |
  | decent (~80 min/day) | 47 min | day 1 | day 21 | day 40 | day 61 | day 75 | day 77 | day 98 |
  | casual (~30 min/day) | 56 min | day 1.3 | day 30 | day 56 | day 81 | day 110 | day 113 | day 134 |
  (v0.19s was decent Japan day 2 / Dubai day 17.) Night Shift: levels 1-8 in week 1, 9-10 in weeks 3-5. Rating
  (decent): 1.0 ~5 min, 2.0 day 1, 2.5 ~day 13, 3.0 ~day 17, 3.5 ~day 36, 4.0 ~day 64. Keen players aren't much
  faster than decent (with a 12h cap 4 check-ins already earn ~24h a day): an idle game, as intended.
- 635 autotest checks PASS (_v19t_checks 54 new; _v19k marks the delivery/cat tips seen). Shots v19t_01 .. v19t_10.
- Saved: delivery_day/count, cat_treat_day, decor, shop_name + the new manager fields. Tests: _v19t_checks; the
  autotest forces daylight + no rain + no Car of the Week (Scenery.hour_override 13, rain_override 0,
  cotw_enabled false) so older checks stay exact.

### DONE (26 Oct, v0.19s): FAST WHOLE-GAME ECONOMY SIM (dev only). (Levers picked + applied in v0.19t, above)
Hamza: "if you can do the run fast then go for it ... add any dev tools ... doesn't have to be usable for me".
- tools/econ_sim.gd (see tools/README.md): plays all 5 countries on GameState's own code, headless, 2-10 min
  real per 45-60 days. Hooks in game_state.gd: `sim_mode` (no _process, no saves, no balance log) and
  `signal milestone(kind, text)` (emitted by _log_milestone). No gameplay change. Autotest 581 still PASS.
- CAL=1 check: the idle formula = live per-frame stations within ~5% when bays are the bottleneck (live is
  faster when the valet is), so the sim isn't flattering the game.
- RESULTS (3 players, 4 sessions/day "decent" ~80 min; "casual" 2 sessions ~30 min; "keen" 6 ~2h50; no-ads pack,
  starter boosters, free wheel; NO abilities / premium managers / skills / Hometown, which would be faster):
  | | Detroit | LA | Japan | Germany | Australia | UAE | last city (Dubai) | ~all cities prestige 5 |
  | keen | 30 min | day 1 | day 1.4 | day 4 | day 7 | day 11 | day 12 | day 16 |
  | decent | 35 min | day 1 | day 2 | day 5 | day 8-9 | day 14-15 | day 17 | day 22 |
  | casual | 60 min | day 1.3 | day 3 | day 9 | day 16 | day 25 | day 28 | day 36 |
  TARGET 2-6 months for all countries -> about 4-6x TOO FAST (decent player done in ~3 weeks).
  Rating (decent): 1.0 6 min, 1.5 day 1, 2.0 day 2, 2.5 day 15-17, 3.0 day 20-22, 3.5 day 39-41 (casual 2.5 day
  33, 3.5 day 58): close to the v0.19l targets (2.5 a bit late), it's time-based so it doesn't move with the economy.
- Why it's fast: Night Shift (500 x3^n x city scale) maxes the offline cap to 12h within the first hour, so a
  player who checks in 4x a day earns ~24h a day (x2 ad boost, x2 collect); prestige x4 (x1024 at P5) compounds
  with x10 per city. Lima reaches prestige 5 on day 4-6.
- CEILING: from ~day 10 the prestige-5 cities are capped by Valet + Front Desk at Lv 400 (bays out-earn them
  3-30x), so bay levels stop mattering there (the old "max level 400: decide later" note).
- Levers offered to Hamza (v0.19t used the first three): Night Shift pricier / tied to progress; PRESTIGE_MULT 4 -> 3 or
  steeper later prestiges; bigger country unlock costs (keeps day 1 the same); a higher Valet/Desk cap.

### DONE (26 Oct, v0.19r): THE EARLY COMMONS' SIGNATURES (Hamza: "yes all good"; Mori later)
All 30 min recharge, own baked pictures (ability_bubble.py sig), payoff popped over the station
(GameState.signature_popped -> UiTheme.pop_text). Lv1 .. Lv50 ranges in game_data (CLEAR_LOT_MULT etc).
- Shazza CLEAR THE LOT (desk, was Upsell): checks out the whole pickup lot now, x1.5 .. x2 (instant).
- Tash SHOWSTOPPER (bay, was Elbow Grease): her bay's next car is a show car: x25 .. x50 pay, +5 .. +10
  followers; waits for that car ("next car"), then recharges.
- Jono MATE'S RATES (bay, was Trade Prices): his bay's next 5 .. 10 levels are free (levels_cost skips them,
  buy_levels counts them down; "N free"), then recharges.
- Bec LOYALTY CARD (desk, was Express Lane): 60s, every checkout also brings +1 .. +2 followers.
- Mick TOW TRUCK (valet, was Big Trailer): the next trip that STARTS has no carry limit (empties every key
  cabinet; v["tow"]), then recharges. "Counted" signatures (convoy, showstopper, mates_rates, tow_truck) set
  active_until +1h and end early via GameState._end_signature. 581 autotest checks (_v19r_checks).
- Still open: Mori's signature; Gaffer (desk in game, bay in PREMIUM_PROPOSAL), Simone, Tony, Sergei parked.

### DONE (26 Oct, v0.19q): MARCO'S CONVOY + SIGNATURE PICTURES
Hamza: Legendary signatures can wait (most players won't own a Legendary for months: "3 months into Idle Miner
and no legendary"); focus on the Commons / Uncommons players actually get. Playbot runs cost credits: only
after big balance updates. Phone performance check: later.
- CONVOY (Marco, valet, Uncommon; was Lead Foot): his next 5 (Lv1) .. 8 (Lv50) trips carry x10 (CONVOY_TRIPS,
  CONVOY_MULT; Hamza: the proposal's 3 trips is over too fast). Counted in trips (m["convoy_left"], saved):
  ends + starts its 40 min recharge when the last convoy trip unloads. Two extra utes follow the main one
  (lane_overlay; they queue on the other side when parked at the top). Ability bubble / panels say "5 trips"
  (GameState.ability_left_text / ability_length_text) instead of a time.
- PICTURES: tools/char/ability_bubble.py <project> sig bakes icon_shortcut (key + green leap arrow),
  icon_finish_line (chequered flag), icon_convoy (3 utes) + greys (mipmaps on in the .import files);
  ability_icon._pic_name uses icon_<ability id> on the gold signature bubble when it exists (Dazza: tip jar).
- (BUILT in v0.19r) PROPOSED: Shazza "Clear the Lot" (desk: check out the whole pickup lot now,
  x1.5), Tash "Showstopper" (bay: next car = show car x25 + 5 followers, Lv50 x50 + 10), Jono "Mate's Rates"
  (bay: next 5 levels free, Lv50 10). Bec (desk) + Mick (valet) still need ideas. All 30 min recharge.
- 570 autotest checks.

### DONE (26 Oct, v0.19n-p): LUCKY WHEEL, KEV + PRIYA SIGNATURES, VISIBLE VALET LOADING (Hamza picked 1-2-3)
- v0.19n LUCKY WHEEL (scripts/wheel_panel.gd; Data.WHEEL_*; GameState.spin_wheel/wheel_chance/wheel_prize_name):
  the early Shine Bucks sink. FREE spin every WHEEL_FREE_HOURS 8 (saved wheel_free_at; a new game starts with
  one), extra spins WHEEL_SPIN_COST 50 SB (placeholders). 12 slices, 4 tiers like Idle Miner (Hamza's odds):
  Legendary 0.5% (whole Legendary premium manager = Mori / Gaffer / Simone, 3 Classified Files once you own all
  three; x500 for 5m), Epic 2% (Classified File, x50 5m), Rare 27% (Detailed File, x20 5m, x10 10m, 4h cash),
  Common 70.5% (Case File, x5 15m, x2 30m, 30m cash). Every prize in a tier equally likely. New wheel-only
  boosters x10_10m / x20_5m / x50_5m / x500_5m (never in the deals; gems orange / pink / gold). Cash = that long
  of max(idle, bays) income, at least the next bay's price. Prize is given at the tap; the wheel spins 4.2s
  (quart ease-out) to it, the slice glows, a card says what you won + where it went. "i" next to the title =
  odds card (every prize %). Entry: first button in the Shop; SHOP "!" when a free spin is ready (from Bay 2).
  NOTE: Hamza now wants Case Files from the wheel (overrides "Case Files only from the Hometown", v0.17c).
- v0.19o PREMIUM SIGNATURES (PREMIUM_PROPOSAL.md): Kev = SHORTCUT (valet; 30s Lv1 -> 60s Lv50 before perks,
  30 min recharge): every car finished in his city goes straight to the pickup lot (bay keys show a green
  "TO LOT" tag, the lot a SHORTCUT tag + green rim). Priya = FINISH LINE (desk; 60s, 45 min): in her city the
  last 10 levels before each station's next boost cost 50% less (Lv50: 20 levels, 70%); Level buttons in the
  window show "-50%". Discounts multiply, DISCOUNT_FLOOR 5%. Kev was Lead Foot, Priya Supplier Deal before.
  Placeholder: their ability bubble uses the signature (tip jar) picture.
- v0.19p VALET LOADING is a visible step (Hamza 20 Oct idea): VALET_LOAD_TIME 0.25 -> 0.9s per bay, cash
  bundles hop from the cabinet into the ute (lane_overlay._draw_loading) and the tray fills as they land.
  Rebalance: VALET_CAP_COMP 1.5 -> 1.72, so it moves x1.02 .. x1.19 of v0.17f's money (autotest range check).
  Loading Speed (+2%/level) was already a level-panel stat. "Quick Hands": NOT a new ability (the cash ability
  deck is one income / speed / discount per 3 hires); Lead Foot now says "drives and loads x faster" (it always
  did both). Ask Hamza if he wants a separate one. Tutorial loop is ~0.7s longer (2 autotest waits adjusted).
- 563 autotest checks (_v19n_checks wheel, _v19o_checks Kev/Priya). Shots v19n_01..03, v19o_01..02.
  New file scripts/wheel_panel.gd (Godot makes its .uid on the next editor open).

### DONE (26 Oct, v0.19m): FIRST-SCREEN POLISH (Hamza: lots of updates before the next playtest, so she isn't
### playing the same game; "get as much done as you can" that makes it more satisfying + rewarding)
- PICKUP LOT (desk_row._draw_lot, was a grey box): asphalt with speckles, painted border, 3 marked bays with
  yellow wheel stops (a parked car per bay as money piles up, with a shadow), blue "P" sign on a post, the name on
  a green street-sign plate, the waiting cash on a tag.
- HIRE (station_manager._draw_hire, was a grey "+ HIRE" box): a ghost of the manager to come (head with "?",
  suit V, soft outline) over a HIRE tag WITH THE PRICE; tag green + ghost bobs once you can afford it.
- VALET FORECOURT (valet_row._draw_forecourt): white picket fence along the back, the valet's key podium beside
  the manager, a street lamp, flower beds with bushes sitting on the footpath (were two floating bushes).
- BAY WALL SHELF (bay_card._draw_wall_shelf): a small shelf high on the back wall with bottles / spray bottle /
  towels, mixed per bay index so the strips differ.
- TIME-TO-AFFORD (GameState.eta_text): Build Bay shows "$61 · in ~57s" and BEGIN RENOVATION "$19.0M (in ~3m)"
  at the current idle income (nothing when affordable, manual-only or > a day). A goal you can see coming.
- Bug: Reset save left an old "Welcome back" popup on screen (main: city_changed hides it if nothing pending).
- 535 autotest checks (_v19m_checks). Shots v19m_01_shop_polish; tools/char-style comparison polish_before_after.
- Proposed next (Hamza to pick): see chat 26 Oct (Shine Bucks sink, next-goal pull in hour 1-2, Kev + Priya
  premium signatures, valet loading step).

### DONE (26 Oct, v0.19l): RATING STARTS AT "NO REVIEWS YET" (Hamza's call after v0.19k). NEXT = Hamza's look
Hamza: a new shop isn't established, so it starts with no reviews; first step = ~10% of the climb, not ~30%;
whole game (all countries) 2-6 months, premium managers good enough for the hardest events 1 year+. Polish the
first city (Lima) first; rough numbers only, NO sim re-run (don't spend long on reputation yet).
- 10 steps: step 1 (0 followers) = No reviews yet (rating 0, x1, HUD pill = empty star + "NEW SHOP"), then 1.0,
  1.5 ... 5.0. STAR_THRESHOLDS = [0, 15, 150, 600, 4K, 30K, 150K, 500K, 1.5M, 5M] (rough targets in game_data:
  1.0 ~10 min, 1.5 ~day 1, 2.0 day 1-3, 2.5 ~week 1, 3.0 weeks 2-3, 3.5 ~month 1, 4.0 ~month 2, 4.5 ~month 4,
  5.0 ~month 6). Late steps are guesses from the old v0.17 curve; only the first hour was measured.
- First review GUARANTEED: 15 = the Bombs set's 9 new-car followers + the guaranteed first rare car's 10 (in all
  3 playbot runs that landed at the first rare car, 9-13 min); and any rare car payout tops followers up to 15.
- Bonuses re-split, not nerfed (Hamza): x1.18 per step (9 steps = x4.44 at 5.0; was 8 x1.2 = x4.30), rare cars
  +22% per step (2.98x at 5.0; was 3x). Extra display slots now at steps 5 / 7 (= 2.5 / 3.5 stars, as before).
- Texts: GameState.has_reviews() / rating_line() ("No reviews yet" / "Rated 4.5 stars"); banner
  main.star_title(): "FIRST REVIEWS ARE IN!" (+ "Your shop is rated 1.0 stars."), then "RATED X STARS!"; tip
  "FIRST REVIEWS!"; Book strip "first review at 15" / "first review in ~X"; Reputation card text for a new shop.
- 531 autotest checks pass (v0.19l rating checks inside _v19k_checks; 3 older checks now start past the first
  review). Shots v19l_01_hud_new_shop, v19l_02_first_reviews, h3_rating_card.
- Renovation (Hamza 26 Oct): keep EXACTLY as v0.19k (watch 2 ads / skip the first hour). Ads stay placeholders.

### DONE (26 Oct, v0.19k): THE AGREED PACING FIXES (Hamza OK'd them 21/26 Oct)
Built, 525 autotest checks pass (504 + 21: _v19k_checks + one older set check), written back + verified on the PC.
1. TEACHING RENOVATION: a city's renovation 1 costs Data.RENO_FIRST_COST_BUILDS (1x) the next bay (Lima $19M, was
   $57M); renovations 2/3 + Hometown keep RENO_COST_BUILDS 3x; 1h timer kept. NOTE: it's "renovation 1 of EVERY
   city" (Detroit, LA, after a prestige too), not only the player's first ever: easy to change in reno_cost().
   One-time tip "NO NEED TO WAIT" when the first renovation starts (GameState.renovation_started signal ->
   main._reno_tip; text main.reno_tip_text() with live numbers): rings the SKIP 30 MIN / WATCH AD button, scrolls
   to the Build strip. No-ads pack: "1h to go, but you don't have to wait! Each SKIP here takes 30 min off (2 per
   hour), so tap it twice and it's finished now. Or tap FINISH NOW for 30 Shine Bucks." (ads: "Each ad you watch
   here ... so watch 2 ..."). Bay 6 price unchanged (Hamza OK).
2. RATING: STAR_THRESHOLDS[1] 100 -> 40, the rest unchanged.
3. BOMBS SET: GameState.book_opened (saved; saves from before v0.19k load as true). _check_tier_sets() does nothing
   until the Book has been opened; main._open_book() calls GameState.open_book_first() 3 frames after the Book tip
   is queued, so SET COMPLETE comes right after GOT IT. Shots v19k_01_reno_tip, v19k_02_book_tip_first, v19k_03.
4. PLAYBOT fixed (tools/playbot.gd): saves for the next bay / renovation once it's within ~3 min of income, taps the
   renovation lock (the old bot never did), uses the SKIP only after it has read the renovation tip.
   BEFORE (old code, new bot) vs AFTER (2 runs; run 1 was cut at 41 min by a tool timeout):
   - 1st renovation started 30:14 vs 28:30 / 35:20 (income at min 20-25 is only ~$10-100K/s, not the $0.4-1.5M/s
     the 21 Oct note said, so even $19M takes a few minutes of saving)
   - renovation done: BEFORE not within the hour (due 1:30) vs 28:57 / 35:47 (tip -> 2 skips)
   - Bay 6: never vs 31:51 / 39:58. Bay 7: never vs 41:31 / 54:13. THIS is the real win.
   - Bombs set: right after the Book tip in all runs (the bot opens the Book at 2:00, so it hides the difference).
   - 1.5 stars: BEFORE 42:58 (lucky Legendary +250) vs 40:42 / NOT reached (run 2 got only 1 rare car in 60 min).
     40 followers alone does NOT make "RATED 1.5" land in session 1 reliably: the bot never puts cars ON SHOW, but
     rare cars (+10) are the main source and they're random (~1 per 20 min at 1 star). OPEN for Hamza: lower to
     ~30, give the guaranteed first rare car more followers, or add the "+1 follower per new Book car" idea.
Later / parked: booster crate system; Lv 300 showroom; valet loading step; girlfriend's next playtest = a bigger
batch in a week or two with 3-4 specific questions. NO itch / web build work for now.

### NEXT CHAT (21 Oct): GIRLFRIEND'S PLAYTEST FEEDBACK (round 2)
She played the v0.19i web build (H:\idledetailingtycoon\idle_detailing_tycoon_web_v0.19i.zip on itch,
Restricted + password). Hamza pastes her feedback a point at a time. Same workflow as before (How we work, below):
DONE so far (v0.19j, 21 Oct):
- Point 1 ("you're good to go message didn't last long enough to read"; Hamza: give every tip / popup an OK
  button). Tips, the rare-car banner and Welcome back already had buttons; the two kinds that faded on a timer now
  wait for OK: (a) BIG MESSAGES (main._big_banner: YOU'RE GOOD TO GO, RATED X STARS, PRESTIGE, X JOINED, RARE CAR
  PAID, SET COMPLETE, HOMETOWN UNLOCKED) = a centred card (title + 2nd line + big green OK) over a light dim that
  stops taps reaching the shop (game keeps running). One at a time, queue of up to 6. (b) TOASTS (main._show_toast:
  renovation done, "city X is open", VIP when rare alerts are off, dev cheats) = the same bottom card with a small
  OK on the right; not modal (shop stays tappable); the up/down jump buttons hide while one waits. OK ignores taps
  in the first 0.35 s (OK_GRACE_MS) so a tap already on its way doesn't close it unread; a double tap closes one.
  Double popups merged into one card: the toast that came with a star / prestige / manager joined / set complete /
  Hometown unlocked is now the big card's 2nd line (_star_rewards()). Tips and big cards never stack: a tip waits
  for the big card's OK (tip_overlay blocked by main.big_showing()), a big card waits for GOT IT / Welcome back /
  title screen (main._big_blocked()); the tutorial bubble hides behind a big card (is_blocking_popup_open).
  GameState.popups_need_ok (not saved): the autotest sets it false so older checks see the old timed fade;
  _v19j_checks turn it on (20 checks, 451 total). Shots v19j_01_good_to_go_ok, v19j_02_star_ok, v19j_03_toast_ok.
- Follow-up (Hamza: "not everything should need OK"): routine messages close by themselves after read_time()
  (1 s + 0.28 s/word, 3-6 s; a tap closes them early): _show_toast(t, false) = dev cheats + the VIP note when rare
  alerts are OFF; _big_banner(.., need_ok=false) = no dim, no OK. RARE CAR PAID needs OK only the first time
  (tips_seen "vip_paid", so SHOW TIPS AGAIN resets it) or when a new star rides along in it. Renovations finishing in
  the same frame (offline catch-up) = one toast "N renovations done: Lima, Detroit. +X SB, +Y Certs" (_flush_reno).
- Point 2 ("hire gets you a random one"): wording only. Manager tip + manager panel now say "Every hire is a
  surprise: a speed, discount or income ability" (+ the Junior/Senior/Executive odds).
- Point 3 ("pop up for valets is good, just bad timing"): BUG. Tips that point into the shop (valet / desk too
  slow, rare car, new star) showed over an open panel, ringing a button hidden under it. Now a tip with a target
  waits while any panel is open (main.sheet_open(): children with clear_body()); tips about the panel still show.
- Point 4 quick part: Book category pages have a live strip under ON SHOW (BookPanel.live_text()): followers/hour
  from what's on show + when that brings the next half star; "Rating X stars = xN bay income · next half star: xM";
  the customer share of each shown car's type now vs nothing on show ("JDM 25% (+11%)"); rare car on show = 4x
  visits. Updates as you swap cars. _v19j2_checks (16, 467 total). Shots v19j2_01..04.
- Point 5 BOOSTS AS BADGES (Hamza loved mockup tools/char/boosts_mockup_v1.png; built): scripts/boost_gem.gd draws
  an octagon gem with "xN" (x2 purple, x3 teal, x4 blue, x5 red, ad green, total gold, grey) + optional count
  bubble. boost_panel.gd rewritten: TOTAL card = big gold gem + the sum as mini gems "base x (x5 + x2 +N)" +
  caption "base boost x boosters added together" + an "i" button (Hamza: no small print) that opens the whole
  breakdown in words (BoostPanel.info_text()). RUNNING NOW = ONE ROW THAT SCROLLS SIDEWAYS (Hamza: never stack
  downwards): ad badge pinned left (WATCH AD +4h), each new booster on the RIGHT, the row jumps to the new one;
  the same booster used twice = one badge with a count bubble + "2 running = x4" (GameState.booster_groups();
  values unchanged, they still add); "N more >" pill at the right end of the heading when some are off screen.
  No stack limit (there never was one). YOUR BOOSTERS = 3-column tiles (duration, gem, N left, USE).
- TODAY'S DEALS (Hamza: boosters shouldn't be endless): 3 different boosters per 12 h window (real clock,
  window = floor(unix / 12h), seeded RNG = same for everyone, reopening can't reroll), weighted
  (Data.DEAL_WEIGHTS: x4 week pass rarest), each buyable ONCE (SOLD); GameState.deals()/deal_sold()/
  deals_refresh_in(); deals_bought saved. buy_booster() only sells today's deals. The Shop's booster list is
  now one "TODAY'S BOOSTER DEALS >" button that opens Boosts. LATER (Hamza): a crate system for boosters.
- Point 4 BOOK CLARITY (mockup tools/char/book_mockup_v1.png; built): car cards of a type one of your bay crew
  managers has get a "CREW x1.5" tag in the crew colour (car_card.gd, GameState.crew_bays(class)). The live strip
  is now chip chains (BookPanel.live_rows(), HFlowContainer): [+X followers/hour] » next half star in ~Y »
  [x1.20 bay income] (now xN); per shown type [JDM customers 25% (+11%)] » "your 1 JDM Crew manager (Bay 1) earn
  x1.5 on them" or "hire a JDM Crew manager for a bay to earn x1.5 on these"; rare on show = 4x visits.
  No "BEST PICKS" button (Hamza left it to me: the tags already point at the right cars and the Book should
  stay hands-on; easy to add later if playtesters still don't get it). Font note: Fredoka has » and x-sign,
  no arrow glyph. _v19j3_checks (25, 492 total). Shots v19j3_01..05.
- TOP BAR (her: "too cluttered, could barely see the idle income / second"; Hamza's layout): scripts/hud_money.gd
  = two pills on the LEFT in the HudMeta style: CASH (bigger, gold coin badge; main._cash_label is its Label, still
  pops + gets the coins) and IDLE "$X/s" (clock badge, "IDLE" + chevron; tap = Overview, which lists every city,
  so the old "other cities +$X/s" text is gone from the bar). Trophy stays top middle (y +30), the city name sits
  under it ("Lima, USA"; the city alone if too wide, CITY_W 146; "Hometown Garage" takes the trophy's spot in the
  Hometown). Removed: followers line (it's in the Rating card) and "Tap to work · hire managers" ($0/s instead).
  _v19j4_checks (8, 500 total). Shots v19j4_01/02.
- FRESH-PLAYER PASS (21 Oct, tools/playbot.gd, 2 runs of 60 min agree). Fixed straight away: 3 out-of-date
  tips (boosts said ACTIVATE -> USE + the "i"; shop said boosters -> today's deals; prestige said trophy "top
  left" -> top middle); tips pointing into the shop now also wait for the MAP / HQ screen (a full screen, not a
  sheet: main.sheet_open() checks MapPanel) and for the rare car banner (they stacked on it). 504 checks.
  Timeline (bot plays faster than a person): tutorial 1:00, 1st manager 2:30, desk+valet+bay automated 3:30,
  bays 2/3/4/5 at ~4:30 / 6:00 / 8:00 / 15-20 min, 1st rare car 6-9 min, Book sets: Bombs at 2-4 min (!),
  Daily Drivers ~19-25 min. Then a DEAD ZONE: bay 6 needs the 1st renovation, affordable only at ~40-47 min,
  and it takes 1 h -> nothing new unlocks from ~15-20 min to ~1h40. Rating stuck at 1.0 all hour (45 of 100
  followers: only rare cars +10 each + display 0.4/h). Shine Bucks pile up: ~200 by 20 min, little to spend on
  (it would finish the renovation for 30 SB, but the bot didn't think of it: does a player?). Prestige ($4B)
  not near after 1 h. Pacing changes = Hamza's call (see the report in chat 21 Oct); none made.
- NEXT (Hamza 21 Oct): stop sending her every update; she gets a bigger batch every week or two with 3-4 specific
  questions. Meanwhile Claude does a FRESH-PLAYER PASS (new save, first 30-60 min, screenshot every popup / tip /
  new screen, report what's cluttered, overlapping, confusing or slow + sim pacing check). NO web build / itch work
  for now (Hamza: itch had buttons not pressing and the page reloading every few minutes); focus = refining the game.
1. Read the feedback, sort it into bugs / quick polish / design changes, and say back what you understood.
2. Fix bugs first, then quick polish; DISCUSS design changes (mockups first) before building them.
3. After each batch: autotest (581 checks), screenshots for Hamza, write back + verify on the PC, update these notes.
4. When Hamza wants a new playtest build: export the web zip in the cloud (see item 2e below for how).
Post-playtest ideas already parked: valet loading as a real visible step (2e), the Lv 300 "Showroom" desk tier
making the showroom fancier (2c), polish list: "+ HIRE" boxes, pickup lot, bay wall decor, valet lawn.

### PREVIOUS (19-20 Oct): FRIENDS PLAYTEST BUILD (all done, kept for reference)
Goal: a build Hamza can hand to a small batch of friends. Do these in order, one at a time, showing Hamza each:
1. DONE (19 Oct, v0.19b, waiting for Hamza's look): Managers into the game. station_manager.gd draws cash managers
   with ManagerRig / ManagerAnim / ManagerAura: look = StationManager.look_of(m) (hash of the id, from the tier's
   pool: Junior m00-05, Senior m06-11, Executive m12-16; same person = same look; a new hire at the station gets a
   new anim), crew colour, idle loop = pose_of(m), INSTRUCT + suds aura (colour = ability kind) while the ability
   runs, aura fades 0.55s. Facing: bays + desk right, valet LEFT (facing_of). Station portraits no longer clip
   (clip_contents off) so the aura + chopping arm reach outside the box. Size: fig_px(box_h) = head just inside the
   box (valet box is shorter, so the valet manager is a bit smaller, as before). Rarity shadow kept. Old 2x idle
   gone for cash managers. Stations off screen don't animate or redraw (they used to redraw every frame).
   List portraits (portrait.gd: manager panel, overview) = the same person head-to-chest (BUST_TOP/BUST_BOTTOM),
   idle loop only, rim light in the ability colour while it runs (no instructing in lists: easier to read).
   Premium managers unchanged (old draw_figure, 2x while active). No number changes. cash_look() removed.
   Autotest: _v19_checks (28 new, 397 total). Perf (cloud box, CPU to build draw commands): old figure 0.22 ms
   per manager, rig idle 0.36, instruct + aura 0.71; only on-screen managers draw now, so a screen costs about the
   same as before. Video: managers_in_stations_v1.mp4 (tools/char/station_showcase.gd, autoload + --write-movie;
   remove window_*_override from project.godot first or the movie is 450x800).
1b. DONE (19 Oct, v0.19c, Hamza OK'd the mockup): IDLE MINER ZOOM. Scrolled to the top you see the front desk
   down to the bottom of Bay 3 (was mid Bay 5). Only the station strips changed (top bar + bottom bar the same).
   Bays + valet = 185 tall: a 44px navy SLAB BAND on top (Scenery.slab_band) carrying the ability button over the
   manager + one text line (bays: car name left, service / "RARE · pays $X" right; valet: VALET + "!" + tool
   left, "Carries $X / trip" right; CREW xN tag on the left of the band), then a 141px room. Front desk 250 tall
   (FLOOR_Y 230), its ability button sits on the awning. Detailers 88 -> 118 px (BayCrew FRONT_H/BACK_H/
   BACK_RAISE), managers ~120 px, cars 210 -> 272 px wide (BayCard.CAR_MAX_W, CAR_NUDGE 14 right so the left
   detailer clears the manager), cashiers 80 -> 106 (temporary, item 2), counter/till/cash stacks/lot cars +
   rare-car lot card bigger, ute 42 -> 50, key cabinet smaller with the $ under it, Level buttons centred in
   the room. Lamp + hose reel dropped from the bay wall. DepthRow.SLOT_H = BayCard.HEIGHT. The bottom slab of
   each strip is gone (the next strip's band does it). Tutorial / VIP-card rects in main.gd follow the new sizes.
   Numbers unchanged. 397 autotest checks pass.
1c. DONE (19 Oct, v0.19d): SOAP-BUBBLE ABILITY BUTTONS (Hamza: the old ones were a rough sketch). ability_icon.gd
   draws baked textures from tools/char/ability_bubble.py (Playwright SVG -> assets/game/sprites/ability/,
   mipmaps on in the .import files): a translucent bubble tinted by kind (aura colours) with an iridescent rim,
   the picture inside (income = money bag "$", speed = stopwatch + speed lines, discount = price tag "%",
   Tip Jar = jar of coins, gold), white glints on top. Ready: bobs, film colours swirl, a jelly wobble every
   ~4s. Active: glow pulse + tiny bubbles fizzing up. Recharging: smaller grey bubble + grey picture. Tap: squash
   + a ring and burst of tiny bubbles. The time pill now sits under the bubble. Off-screen buttons don't redraw.
   Video ability_bubbles_v1.mp4 (station_showcase.gd now taps the buttons).
2. DONE (19 Oct, v0.19e): THE FRONT DESK CASHIER (Hamza approved prototype v4 after 4 rounds). NOT crew-built:
   skinny secretary build, silky raspberry wrap dress (modest V neck, waist tie, satin sheen, name badge, pumps),
   natural pretty face (level eyes, light lash line, soft unlined lips, light blush, even dark brows), dark
   brunette messy high bun + curtain bangs + loose face-framing strands, brown eyes, slim black reading glasses
   (shape from his sunglasses reference), lower sloping shoulders, light tan skin (v4b, was too pale). Art: tools/char/cashier.py (v1 crew version kept
   in cashier_crew_v1.py), sheets cashier_prototype_v1..v4.png. Bake: tools/char/cashier_parts.py ->
   assets/game/sprites/cashier/ (c_body, c_head, c_head_blink, c_head_happy; mipmaps on) + scripts/cashier_parts.gd.
   Rig: scripts/cashier_rig.gd (textures + arms/hands/notes in code via ManagerRig.Pen + ManagerRig.elbow),
   scripts/cashier_anim.gd: idle (hands on the counter, blinks, sway), COUNT while the desk runs (left hand holds the
   stack, right hand deals notes onto the counter, head tipped down; deal speed from the desk cycle), CHEER (left
   fist pump + happy face) when YOU tapped for the payout; when a manager runs the desk just the happy face (calm).
   desk_row.gd: at most 2 cashiers (MAX_CASHIERS; 1, then 2 from "Second Cashier" Lv 25), 140px tall behind the
   counter, the 2nd mirrored (DeskRow.cashier_x); the Kenney cashier is gone. "FRONT DESK" is a wooden plaque
   hanging above the till; the counter front shows the desk upgrade name ("Cash Tin", "Second Cashier"...);
   the desk "!" sits by the plaque; TAP! over the till. Autotest _v19e_checks (404 total). Video
   cashier_in_game_v1.mp4 (tools/char/desk_showcase.gd).
2b. DONE (19 Oct, v0.19f, Hamza's polish list): the red/white scalloped awning over the desk is gone (a plain roof
   trim in the premises colour at y 41-51; the desk ability bubble moved down to (241, 48) on the wall). The counter
   front says "FRONT DESK" again: the desk upgrade tier name ("Loyalty Program" etc.) meant nothing to a player, so
   it's gone, and so is the hanging plaque (desk "!" now over the till). The bay key board (same 64x52 board) shows
   0..3 proper CAR KEYS on 3 hooks (split ring, dark fob in a coloured shell with lock/unlock/panic buttons, notched
   blade; one more key per x100 cash waiting; tiny sway) instead of 8 pixel blobs (BayCard._draw_car_key). The
   prestige trophy moved out of the top-left corner to the TOP MIDDLE of the HUD (84px box, a child of main over
   the HUD, centred on hud.resized; the city + followers lines now sit under the idle rate). Autotest _v19f_checks
   + the trophy-position check (406 total).
2c. DONE (19 Oct, v0.19g, Hamza picked the showroom from desk_mockup_v1 over a plain shop wall): NEW FRONT DESK ART.
   tools/char/desk_art.py bakes assets/game/sprites/desk/ (2x, mipmaps on) + scripts/desk_parts.gd (pivots, WIN,
   PANES, PLATE, CEIL, FLOOR, PLINTH_Y). Counter = wood with a marble top and a brass plate (FRONT DESK drawn on it
   in Godot). REGISTER grows with the desk (DeskRow.register_stage): Lv 1 cash tin (lid lifts on payout), Lv 10
   + card reader, Lv 50 mint retro cash register, Lv 200 touchscreen POS (tap pad + receipt printer); the retro +
   POS cash drawer slides out over the counter's right side panel on payout. Cash = banded note stacks (up to 4)
   + a coin stack, sliding into the register at the end. SHOWROOM WINDOW behind the cashiers (scripts/
   desk_backdrop.gd, a show_behind_parent child that also draws the sky/wall/roof trim/floor and only redraws
   when the Book showcase changes): 3 glass panes; showcase slots 1-3 stand in front on plinths (one per pane,
   with the hexagon LED ceiling reflected in their paint, Hamza's idea), slots 4-10 on a raised back shelf,
   smaller and hazier; an empty front slot shows a pale mystery car. Hexagon LED ceiling + its reflection in the
   polished floor. Autotest _v19g_checks (411 total). Ideas not built: the Lv 300 "Showroom" desk tier could make
   the showroom fancier (turntables / brighter lights).
2d. DONE (19 Oct, v0.19h): BUG FIX: settings["tips_seen"] (one-time tips), "music" and "music_volume" were saved
   but never loaded, so every tip came back and the music settings reset on each restart. load_game now restores
   them (_v19h_checks). "FRONT DESK" text centred on its plate. 414 checks. Hamza: ready for the friends playtest.
2e. DONE (20 Oct, v0.19i, Hamza):
   - LEVEL PANEL, Idle Miner style (level_panel.gd): the boost ladder is gone; a big stats card instead, one row
     per stat (icon tile, name 30pt, value + green "+what this upgrade adds", times show "-0.5s"; muted "+0"
     when nothing changes). Bays: Income/s, Pay per Car, Time per Car. Valet: Total Transport/s, Load per Trip,
     Loading Speed, Driving Speed. Desk: Total Checkout/s, Cash per Checkout, Checkout Time. "Next boost at Lv N:
     x2 income" (says what it gives). Orange hint when the station is the bottleneck. Body fixed at BODY_H 900
     (panel ~1024 of 1280 px, same for every station, nothing scrolls). Arrows / swipe / x1..MAX / Upgrade kept.
   - SHINE BUCKS: buy the next bay you can't afford with cash ("or [SB] N" under Build Bay): N = 10 + 1 per 5 min
     of play income short (play_income = slowest of bays/valet/desk), max 300 (BAY_GLOSS_*). FINISH NOW on a
     running renovation: always finishes the WHOLE renovation, 1 SB per 2 min left, min 10 (RENO_GLOSS_MINUTES,
     RENO_FINISH_MIN): 1h = 30, 8h = 240, 48h = 1440. Ad skips unchanged. Both need a second tap ("TAP AGAIN TO
     CONFIRM", 3s). GameState.bay_gloss_cost/buy_bay_gloss/reno_finish_cost/finish_reno_gloss.
   - BUILD STRIP = one bay tall (BuildRow.HEIGHT = BayCard.HEIGHT) with a dashed outline of the bay to come:
     buying turns it into the bay in place and the content height doesn't change (nothing below jumps).
   - The "or N SB" bay button is hidden during the tutorial. Autotest _v19i_checks (431 total). (Known flaky,
     timing: "... and the '!' on BOOK" in _v17g fails rarely; a rerun passes.)
   - WEB BUILD for the friends playtest exported in the CLOUD (20 Oct): H:\idledetailingtycoon\
     idle_detailing_tycoon_web_v0.19i.zip (upload that zip to itch as an HTML game). How: only the web templates
     are pulled from the 1.2 GB Godot_v4.7-stable_export_templates.tpz with HTTP range reads (python zipfile over
     a range-reading file; suffix ranges are refused, explicit ranges work) into
     ~/.local/share/godot/export_templates/4.7.stable/, then a copy of the project WITHOUT the AutoTest autoload
     line: godot --headless --export-release "Web" out/index.html. Checked it boots in headless Chromium
     (swiftshader) with no console errors.
   Post-playtest idea (Hamza 20 Oct): make valet LOADING a real visible step with its own upgrade stat + a
   "Quick Hands" style ability (needs a rebalance with tools/sim; loading is 0.25s/bay + 0.5s unload today).
3. CANCELLED by Hamza (19 Oct: "never mind dont worry about it", polish the current game instead). Was: playtest
   switches: HIDE (not delete) everything outside the USA core (see PLAYTEST PLAN), one switch per system,
   autotest runs both ways.
4. Fresh-save pass over the first 30 min (tutorial, first managers, first prestige pace), performance check on the
   web build, then export to itch.io (Restricted + password) for the friends.

### How we work
- Hamza is the designer. Claude builds. Godot 4.7, GDScript, all UI built in code. Project on Hamza's PC:
  `H:\idledetailingtycoon\idle-car-tycoon` (Claude reaches it through the linked-computer file tools).
- Workflow: stage the project into the cloud workspace (copy from the PC), edit there, run `tools/autotest.gd`
  (cloud box has no Godot: curl Godot_v4.7-stable_linux.x86_64.zip from the godotengine GitHub release, ~1 min)
  (see tools/README.md), look at the screenshots, then write changed files back to the PC and **list the folder to
  check every file size matches**. Godot's editor has twice saved its old copy over a new file. Tell Hamza
  to close open script tabs and press Reload. Re-sending a file from the same cloud staging path can write the
  OLD cached copy (happened 16 Oct): stage a re-send under a new folder name, then check the size again.
- Hamza's rules: original GTA-style car brand names only; no progress bars in gameplay (the level panel's
  next-boost bar is OK); sounds ONLY for player taps/buttons (none for automatic events); calm screen (no "+$" spam);
  skill tree is one screen; he balances by playtesting; discuss design before building big things.
- Current build on the PC = v0.19u (27 Oct: visual pass + world map + title scene) + v0.19t (26 Oct: pacing fix, Uncommon signatures, day/night + rain, Suds the cat, Daily
  Delivery, decor, Car of the Week, reviews, shop name) + v0.19s (26 Oct: dev econ sim, tools/econ_sim.gd +
  GameState.sim_mode) + v0.19r (26 Oct: Shazza / Tash / Jono / Bec / Mick signatures) + v0.19q (26 Oct: Marco's Convoy, signature pictures) + v0.19p (26 Oct: Lucky Wheel, Kev Shortcut + Priya Finish Line, visible valet loading) + v0.19m (26 Oct: pickup lot, hire ghosts, valet forecourt, wall shelves, time-to-afford) + v0.19l (26 Oct: No reviews yet + 10 rating steps) + v0.19k (26 Oct: teaching renovation 1x + skip tip, 1st rating step 40, sets wait for the Book, playbot saves) + v0.19j (21 Oct: popups wait for OK / routine ones close by themselves, hire wording, shop tips wait for panels, Book crew tags + chains, Boosts as badges + today's deals, clean top bar) + v0.19i (20 Oct: level panel stats, Shine Bucks for bays + renovations, bay-sized build strip) + v0.19h (tips/music settings now load) + v0.19g (new desk art + showroom window) + v0.19f (desk awning/plaque gone, car keys, trophy top middle) + v0.19e (front desk cashier) + v0.19d (soap-bubble ability buttons) + v0.19c (Idle Miner zoom) + v0.19b (posh cash managers in the stations) on top of
  v0.18 (detailers), v0.17h (girlfriend's playtest fixes) ... 581 autotest checks pass.
- Playtests: Hamza's girlfriend played v0.17g on itch.io (web build, Restricted + password). Hiding the non-USA
  systems is now for the WIDER playtest (nephews / randoms), not hers.
- PLAYTEST PLAN (Hamza, 17 Oct): his girlfriend plays it for a while and gives honest reactions. Polish what she sees in
  the first 10-30 min first. At the END (before her playtest), HIDE (not delete) everything outside the USA core: the other
  4 countries ("coming soon" on the map), Hometown Garage, premium managers / case files / dossiers, equipment +
  materials, wardrobe; skill tree shows only the USA branch. One switch per system; autotest runs both ways.
- CHARACTERS (19 Oct): DETAILER DESIGN LOCKED (sheet v4: build "A" chunky/muscly blue-collar, orange tee + white droplet
  logo, charcoal cargos, tan boots, black nitrile gloves, no cap/hi-vis/apron, stubble dots, thick square jaw, short
  quiff). Eyes = Hamza's "hunter" sketch: straight LEVEL brows sitting low across the middle of the eye, only the lower
  half of the eye + brown iris shows; brows trimmed thinner in v4. Shoulders must grow out of the shirt (no ball).
  Faces the car while working (3/4 view), turns to face the camera to celebrate (double-bicep flex + grin).
  Art source: tools/char/detailer.py (SVG); tools/char/parts.py bakes part PNGs (assets/game/sprites/detailer/, mipmaps
  on) + scripts/detailer_parts.gd (pivots/skeleton). Rig: scripts/detailer_rig.gd (part textures, 2-bone IK arms/legs,
  sleeves rebuilt per frame), scripts/detailer_anim.gd (pose per state, blends), scenes/character_lab.tscn (F6 preview).
  Animation plan, ONE AT A TIME with Hamza's OK: 1 idle (built, sent) -> 2 scrub (side / roof reach / crouch at wheels,
  no snapping) -> 3 foam cannon + polisher -> 4 celebrate (turn, flex pump, turn back) -> 5 into bays (replace Kenney;
  animation on its own loop, job times + income UNCHANGED). Managers come after (same rig approach), not yet.
- v0.18 progress (19 Oct): 1 idle LOCKED, 2 scrub LOCKED (side / bonnet top / crouch at the wheel, free hand on hip or
  knee; sleeve rebuilt so it never vanishes), 3a foam cannon LOCKED (scripts/foam_layer.gd: honeycomb foam slots over
  the car's real body outline (CarArt.body_outline), spray = soft brush + foam spreads into gaps -> car COMPLETELY
  buried at any car time; clears from the detailer's end during the hand wash), 3b polisher built (scripts/
  polish_layer.gd: dull haze + swirl marks after the wash, cleared by the polish from the ends with a shine streak,
  mirror reflections after). Job per car by bay service (DetailerAnim.phases): Lv 1-9 mitt only; Lv 10-99 foam 30% then
  hand wash; Lv 100+ foam 22% / hand wash to 55% / polish. Next: 4 celebrate (flex), 5 into the bays.
- v0.18 (Hamza): from Paint Correction (bay Lv 100) a car takes at least PC_MIN_CAR_TIME = 9s (game_data) so the
  routine plays out. GameState.bay_base_time() feeds BOTH bay_cycle_time and _bay_base_pay, so $/s is unchanged.
  Loopholes closed: rare-car pay uses vip_base_pay() (old car time, so longer cars don't multiply VIP payouts);
  crossing Lv 100 mid-car rescales progress (keeps the seconds worked, no windfall); the level panel's "(+$X)" preview
  now uses the car time AT the new level (bay_cycle_time(i, level)). Book discovery a bit slower in Lv 100+ bays 1-10:
  Hamza OK with it. Hometown never reaches Lv 100 (cap 50). Autotest: _v18_checks.
- Foam Party (cash managers) stays a plain income boost, no custom look (Hamza: custom animations are for PREMIUM
  managers). Premium overhaul note: one of the five premium Foam Party managers (Gazza, Lukas, Tony, Sergei, Mori)
  could get a proper "Foam Party" signature (coloured foam, foam on the floor, bubbles).
- FIXED (19 Oct, after Hamza spotted it): the far arm spazzed during / after the polish. Cause: the far hand held the
  polisher's knob ~6-25 units from its own shoulder (arm fully folded), so the machine buzz whipped the elbow around.
  Now the far hand presses on the polisher's head and ignores the buzz; Rig.ik() also eases into full stretch (no
  twitch at max reach) and steadies targets right next to the shoulder. tools/char/arm_probe.gd prints any
  frame-to-frame elbow/wrist jump (copy it to tests/ and run with --script). Hose / cord fade in with their tool.
- 4 CELEBRATE (19 Oct, v2 after Hamza: "he's already facing the camera, the flip makes no sense"): NO turning.
  DetailerAnim.celebrate() = 1.7s in his working view: tool shrinks away while his arms drop straight, arms swing up
  in an arc into a double bicep with a grin (head34_grin texture), two pumps, arms back down, then the job blends back
  in. The near elbow switches to bending outwards (pose bend_n) only while that arm is straight, so it never flips.
  (The old turn-to-camera front-view flex code, _front_pose + view 1 parts, is kept for later / managers.)
  Lab: FLEX button; FOAM / POLISH JOB flex after every car (the next car waits). In the bays (step 5) it should play
  while the next car rolls in.
- Polish (Hamza 19 Oct): tried drawing the far forearm in front of his head (pose far_front, still supported by the
  rig) but the hand then covered the polisher: REVERTED to the earlier look (far hand on the polisher head, arm behind
  his head, passes -140..-86). Hamza: small thing, nobody will notice.
- Flex arms (Hamza 19 Oct, "arm looks on backwards"): during the flex (pose flex_arms) the forearm is drawn IN FRONT
  of the upper arm and the far arm's textures are flipped so both biceps bulge upwards.
- Write-back tip (19 Oct): PNGs can arrive on the PC with a different FILE SIZE (the transfer re-compresses them) but
  identical pixels. For PNGs compare pixels, not sizes; scripts must still match exactly.
- 5 INTO THE BAYS (19 Oct, v0.18): bay_card.gd now draws scripts/bay_crew.gd (the Kenney detailer sprites are no
  longer used in bays). BayCrew: front pair at the car's ends (left always; right from crew 2 or a rare car), extras
  (crew 3-6) behind the car (70 px, feet raised 30 px, roof wipe only). Routine by bay level: <10 mitt, 10-99 foam +
  wash, 100+ foam + wash + polish (BayCrew.tier_for). Flex after every car (also when a rare car leaves); the next
  car's routine runs in the time left after the flex (p_vis), so it's still clean exactly at its end. No flex when a
  bay runs itself and its cars take < 5s (FLEX_MIN_CAR, calm); manual bays always flex. Cars < 2.5s (FAST_CAR, speed
  boosts) = plain hand-wash loop. Car name / service text is drawn after the crew (heads behind the car never cover it).
  PERF: bays scrolled off screen no longer animate or redraw (all 20 used to redraw every frame, old to-do E); foam
  blobs = 2 baked textures each (was 4 circles); sleeve shading without polygon intersection. Desktop/xvfb probe, 20
  bays mixed tiers: bay drawing ~29 ms/frame vs ~36 ms with the old Kenney bays (tools/char/perf.gd).
  Also fixed: UiTheme.sparkle skips near-zero stars (the old "triangulation failed" errors in the logs).
  tools/char/showcase.gd = autoload that records a mixed-bay demo (write-movie).
- 5b CROWD + BACK DETAILER (19 Oct, v0.18c, Hamza): at most 3 detailers drawn per bay (BayCrew.MAX_CREW: the two at
  the ends + one behind the car), whatever the bay's crew number says (it's only visual; Lv 300 with 5 looked
  crowded). The one behind now follows the routine too (DetailerAnim.roof): arms folded while the front pair foam
  ("wait" state), roof wipe during the hand wash, then a polisher on the roof (held out with the handle down below the
  roof line, so it never crosses his face). On a sedan you mostly see his head + the tool over the roof.
  Blended hands now curve round the shoulder when a straight line would pass close to it (_hands_around; fixed an
  elbow whip from arms-folded to the roof reach and from the roof polisher into the flex). Front pair unchanged.
  Valet tip text: "Level up the valet here." (the "(or tap the ute)" hint pointed at the manual run, not upgrades).
- CASH MANAGERS (19 Oct): concept v1 (tools/char/manager.py, chunky detailer-style) was WRONG, not used. Hamza:
  managers are SKINNY / scrawny and POSH, a very different design from the detailers; only the theme is shared
  (cartoony, ink outlines, shading). Everyone wears suits. RANK = AGE: Junior young, Senior middle-aged,
  Executive old. Keep their current idle loops. Discuss before drawing; then one prototype for Hamza to adjust.
  Hamza 19 Oct: women too; wacky / characterful is fine (still App Store safe); tier is read from AGE, mostly hair
  colour (Junior natural colour, Senior greying, Executive white/silver), skin etc still varies; few wrinkles on
  the old ones. EXECUTIVE prototype v1: tools/char/posh.py + sheet_exec.py -> tools/char/executive_prototype_v1.png
  (The Professor, The Dame, The Count; lanky, long pointy nose, heavy half-shut lids, double-breasted suits, crew
  bow tie + pocket square, pointy shoes). Hamza LIKES IT: Executive LOCKED ("super serious and snobby").
  Snobbery drops with age: Senior = middle ground, Junior = full of life, happy, optimistic.
  AGE LADDER v1 (tools/char/managers_age_ladder_v1.png, people in people_ladder.py, sheet_ladder.py; posh.py
  handles all 3 tiers via p["tier"], posh_exec_locked.py = the locked exec-only copy): Junior = natural hair,
  big round sparkly eyes, beaming smile, button nose, slim suit a size too big, skinny crew tie, name badge, crew
  socks; Senior = greying temples, calm eyes (light lid), polite smile, open jacket over a crew waistcoat, tie,
  pocket square, brown shoes (ladies: blouse bow / brooch).
  Tried a modern chibi style (managers_chibi_test.png, outputs only): REJECTED by Hamza's girlfriend + sister, they
  prefer the posh ladder look. COMPACT v2 (19 Oct, Hamza): same posh design, shorter legs (hip = ank - 62) +
  bigger head (posh.HEAD_SCALE 1.38) for the detailers' compact look -> tools/char/managers_compact_v2.png.
  Senior glasses fixed (drawn over the nose). COMPACT v2 LOCKED (19 Oct).
  BUILD PLAN (agreed 19 Oct, one step at a time with his OK): 1 bake parts + rig, the 4 idle loops in the lab;
  2 INSTRUCT animation while the ability runs (replaces "2x speed"): ease out of the idle pose, point at what they
  boss (bays: car/detailers = right, desk: cashier = right, valet: ute = LEFT), arm chops up/down smoothly, other
  hand on the hip, clipboard put away; mouth opens/closes (no talking sound; only the ability-activate tap sound);
  style by age: Junior big keen quick chops, Senior steady point, Executive slow lazy point, nose in the air; ease
  back into the same idle loop after; 3 into the stations + list portraits, numbers unchanged. CASH managers only;
  premium managers stay as they are for now.
  ACTIVE EFFECT (Hamza): a special effect while a manager's ability runs, SEPARATE from the manager animation
  (own layer, keyed by an effect id) so premium managers can get custom ones later. Cash managers: soft,
  smooth-edged (Idle Miner uses a soft light-blue flame). Our version = "SUDS AURA" (Claude's pick, Hamza: must look
  fleshed out, polish stage): soft rounded egg-shaped glow + 3 rising rounded tongues, glowing suds ring at the feet,
  soap bubbles (some in front), twinkles, coloured rim around the manager; colour by ability (income green, speed
  blue, discount orange = ability icon colours). Still prototype: tools/char/aura.py + sheet_aura.py ->
  manager_aura_v1.png. Hamza: "very happy", animate it smooth.
- v0.19 MANAGERS IN THE LAB (19 Oct, steps 1 + 2 done, NOT in the stations yet): scenes/manager_lab.tscn (F6;
  `-- preview` = auto on/off schedule, used for manager_lab_v1.mp4). Bake: tools/char/manager_parts.py (posh.py
  looks -> assets/game/sprites/managers/, mipmaps on, + scripts/manager_parts.gd). Pool of 17 looks: m00-05 Junior,
  m06-11 Senior, m12-16 Executive (m12 Professor, m13 Dame, m14 Count, m15 Baron, m16 silver bob + pearls). Each:
  body (crew items neutral grey) + body_crew (greyscale, drawn with modulate = crew colour) + head / head_talk /
  head_blink + body_glow / head_glow (rim light). scripts/manager_rig.gd draws it: textures for body + head, arms +
  hands drawn in code (2-bone IK, elbow hint + memory so they never flip; forearm length per pose = cartoon
  stretch for crossed arms; pointing finger; Junior sleeves too long, others white cuff + gold cufflink).
  scripts/manager_anim.gd: the 4 idle loops + INSTRUCT (point + smooth chop, other hand on the hip, folio/pen put
  away, talking mouth, Junior quick / Senior steady / Executive slow with the nose up); idle <-> instruct = one
  0.75s blend, hands travel on a curve through a relaxed hang (arms staying on the hip go straight).
  scripts/manager_aura.gd = the effect layer (effect id "suds"; draw_back / draw_front / rim), fades 0.55s.
  TURNED (Hamza 19 Oct): managers face their workers, not us: baked turned (posh "turn" 0.75 = face features
  shifted + narrowed, far ear tucked, irises look over, chest details shifted, feet point that way;
  manager_parts.TURN). Drawn facing +x (bays + desk); ManagerRig.draw(..., facing = -1) mirrors the whole figure
  for the valet (ManagerAnim always builds poses facing +x; point_dir = facing). Video: manager_lab_v2.mp4.
  Fixes (Hamza 19 Oct): NO pointing finger (looked like flipping them off) - the fist does the bossing; going
  back to idle is slower and gentler (BLEND_IN 0.8s, BLEND_OUT 1.4s, smoothstep, arms on a soft arc). v3 video.
  SNAP FIX (Hamza 19 Oct, "arms snapping"): cause 1 = the elbow IK flipped to the other side of the arm for one
  frame (jumps of 60-88 units); now ManagerRig.elbow keeps the side it was on and only takes the hinted side when
  the arm is nearly straight. Cause 2 = blending HAND positions; now ManagerAnim blends BONE ANGLES (idle and
  instruct each solved with their own elbow memory, upper arm + forearm rotate between them, angles unwrapped
  over time, turn direction fixed once per switch = the way that hangs lowest). Forearm draw order doesn't swap
  while the forearms overlap. tools/char/manager_probe.gd (copy to tests/, run with --script) steps all 17 looks
  x 4 idles through idle -> ability -> idle at 60 fps and prints any elbow/wrist jump: 0 now (was 171). v4 video.
  SLEEVES (Hamza 19 Oct, "joints look like animation bones"): it was the drawing, not the animation. Each arm was
  two separately outlined capsules, so the forearm's outline ring showed at the elbow. ManagerRig._sleeve now draws
  the forearm outline first, repaints the elbow end of the upper arm (cut out with a disc so the cut lands on matching
  colours), then all shade before all highlight: one continuous sleeve + a small crease inside the bend. Animation
  untouched; probe still 0 jumps, autotest PASS. v5 video + manager_sleeves_before_after.png.
  Next = step 3 (with Hamza's OK): station_manager.gd + portrait.gd use the new rig (look from the manager id per
  tier, crew colour, idle loop = pose_of, point left at the valet), aura drawn outside the portrait clip, the old
  2x-speed idle goes; premium managers unchanged. Autotest still 369/369 with the new files.
- Idea for later (not agreed): small signature touches per service (clay bar block Lv 50, ceramic applicator Lv 200,
  PPF squeegee Lv 400).
- Premium managers: design AGREED (17 Oct) in PREMIUM_PROPOSAL.md (8 signature managers; only Dazza's Tip Jar is
  built). Build after Hamza's playtest + balance chat.
- Still open (Hamza decides): trim the premium roster to those 8 or keep all 25; LA price (20T makes Lima's first
  prestige land at 12-24h in the sim, see tools/sim/REPORT_v17d.md: try LA 5T or let Lima prestige after Detroit).
- Remote write-back tip: stage files under a NEW folder in /mnt/user-data/outputs each time (v19u_out was the last).
  Don't run long Godot jobs inside a Monitor tool: it kills its command after 30 min (use Bash run_in_background).

### v0.17h decisions (18 Oct, girlfriend's playtest notes)
- Premium currency renamed "Shine Bucks" (`Data.PREMIUM_NAME`; code still says gloss). Icon = mint banknote with an
  "S" and a sparkle (`HudMeta.draw_droplet`, name kept).
- Top bar right side = two chunky buttons (`hud_meta.gd`): Shine Bucks (+) -> "What are Shine Bucks?" card (spend on /
  get from, button to the Shop); Reputation (star with your star count + followers, chevron) -> Reputation card (what
  each star gives, how to get followers, next star; button to the Book). `scripts/info_panel.gd`.
- v0.17h-2 (Hamza, 19 Oct): the Reputation button is a big star badge with the star count + "2 STARS"; followers moved
  to the HUD's left column (under the city). The Shine Bucks icon is a matching round badge.
- v0.17h-3 (Hamza, 19 Oct: "too many stars"): one symbol per idea. PRESTIGE = a gold TROPHY (number on the cup, blank before the first prestige, rays when ready) at the left of the city name + followers lines; the map and prestige screen show trophies too. REPUTATION = a review RATING like Google reviews: the 9 steps are 1.0, 1.5 ... 5.0 stars (GameState.rating() / rating_text()); the button reads "★ 4.5 RATING", the card shows a 5-star row with half stars, banners say "RATED 4.5 STARS!". Shine Bucks unchanged.
- Text: nothing below 18 in labels/buttons (`UiTheme.MIN_FONT`); station strips bigger (bay car name 20, service 17,
  valet/desk tool names 20, ability timers 15). Rare car in a bay: name 22 + one line "RARE · pays $X" at 20.
- One-time tips (`scripts/tip_overlay.gd`, texts in `main.gd` TIPS): first time you open the Book, Shop, Boosts, a
  manager panel, a level panel, Overview, prestige, HQ; the first rare car (after OK / GO TO CAR: scrolls to it, ring +
  arrow, "pays more, followers, heading to Bay N, get that bay ready, tap it to send it in now"); the first star
  (points at the Reputation button); valet / front desk slowest for 8s (points at its Level button, only when on
  screen). GOT IT dismisses; each shows once (settings "tips_seen"); Shop > SHOW TIPS AGAIN. They wait for the title
  screen, the first-loop tutorial and the Welcome back popup. The autotest turns them off (`GameState.tips_enabled`).
- Book: category pages also show the ON SHOW strip (tap to take off).
- Level panel: swipe left / right = next / previous station (arrows stay).
- Valet: prices unchanged (Hamza: early balance feels right; 1 sample). Tapping the ute / the lane opens the valet's
  upgrades once it has a manager (before that a tap still runs it).
- Bug fixed: the first-loop tutorial bubble showed through the title screen.

### v0.17g decisions (17 Oct, Hamza's playtest)
- Tutorial = just the first loop (car -> valet -> desk), then a big "YOU'RE GOOD TO GO!" (+ "hire managers" line).
  No hiring / level steps. After a prestige it runs the loop again, silently at the end.
- Prestige: one big star in the top bar (blank = no prestige, gold + number after; rays when ready; tap = prestige
  screen). The little stars on the awning are gone. NO "needs the 3rd city" rule: a city's 1st prestige costs the same as
  the next city (Lima = Detroit). Prestige 2+ keep old prices (re-balance later).
- Level panel: a soft green ghost on the next-boost bar = where the selected x1 / x10 / x50 / NEXT BOOST / MAX takes
  you (MAX = what you can afford; nothing if you can't).
- Book: front page = showroom (reputation, display) + 6 category tiles (5 tiers + Rare Visitors) with X/Y and a red
  "N NEW". A car counts as seen once its category page is on screen (no tap needed); its NEW sticker stays for that
  visit. A new RARE car makes the BOOK badge gold. The "x3" wash counter on cards is gone. "Customers coming in" % is
  gone; the display says what it does (followers/hour, rare car on show visits 4x more often). Bay managers' cards say
  their crew bonus ("x1.5 on JDM cars").
- Shop scrolls past your last bay: plain dirt down to the last slot, with a boarded "RENOVATION k" band where each
  renovation still waits. The down-arrow jumps to your Build Bay strip.
- Overview: big rows (3-4 on screen) with the ability button on each manager (fires it from there).
- Valet (Hamza): driving speed only steps up at its boost levels (to what +2%/level would have given); every level gives
  +2% loading speed and more capacity. It drives calmer (1.8s per bay, was 1.2) and carries x1.5 (+ the lag of the
  speed step) to make up: it moves the same money or a bit more (test checks x1.0 .. x1.2).
- Pacing (tools/sim/REPORT_v17g.md): Bay 7 was a 200x wall. Now RENO_TIER_COST 120 (was 352), Bays 7-10 300M / 4B /
  60B / 1.2T, Detroit 4B, LA 5T. Sim (no ads): Bay 7 23 min, Detroit 50 min, Lima prestige ~67 min, LA 3.5h.
  Later countries now come sooner (Japan day 2): re-tune when they come back. Max level 400: decide after pacing feels
  right (Idle Miner shafts go to 800).
- Audio: background music (3 temporary loops made in code, tools/audio_synth.py; any .ogg in assets/game/music plays,
  shuffled). Settings: Music on/off + volume, SOUND BOARD (audition every sound, pick versions, saved). Shrill Kenney
  sounds replaced by soft mid-low "pops" made in code (click, tap, panel open/close, toggle, cash, level, hire, error);
  originals still selectable. Everything plays a touch lower (pitch 0.97, small random variation); quick repeated
  level-ups climb a little (max +9%). Hamza: high-pitched = bad, mid-low light pops = good; boost + renovation sounds
  are good. Sound effects still only for player taps.
- Bug fixed: coins from tapping the desk flew over the map (they're on their own layer under popups now).
- Extra polish: title screen (logo, shiny car, soap bubbles, TAP TO PLAY; skipped by the autotest), cars roll into the
  bay (skipped when the bay is too fast), a new bay drops in with a squash, rare car in a bay gets a red carpet + camera
  flashes, renovation in progress shows scaffolding + dust + a hammer, the cash counter rolls up.

### Next (options for Hamza to pick from, 17 Oct)
A. Hamza playtests v0.17e (new look, Tip Jar, Detroit 200B / LA 20T, manager tiers + tabs) and reports back. Then:
   balance chat (LA price, Gaffer/Sergei numbers, reputation pace, discount-manager speed-up).
B. Build the premium managers from PREMIUM_PROPOSAL.md (Kev + Priya first, then Sergei, Tony, Marco, then Gaffer +
   Simone), and trim the roster if Hamza picks that.
0. (done 18 Oct: girlfriend's notes -> v0.17h.) Next: Hamza checks v0.17h on his phone (text sizes, tips wording,
   top bar), then hide the non-USA systems before the wider playtest.
   Old item: Hamza plays v0.17g (fresh save) and reports: music + pops (Sound board), valet feel, pacing to Bay 8 / Detroit /
   first prestige, Book categories. Then: hide the non-USA systems (see PLAYTEST PLAN) -> girlfriend playtest.
C. Characters: prototype ONE character in Hamza's design (he describes it / adjusts), then redo detailers, cashiers
   and managers in that look. (Art pass part 2 = everything else, done in v0.17f.) Not done on purpose: coins
   flying every time the desk pays (clashes with the calm-screen rule; coins still fly when YOU tap the desk).
   Ask Hamza if he wants it anyway.
D. Launch groundwork: Android export settings, AdMob rewarded-ad hooks, save backups / corruption guard, IAP
   placeholders (Gloss packs, Remove Ads), privacy/consent checklist. Needs Hamza's accounts for the real thing.
E. Performance pass for phones / web build (20 bays x 5 cities redraw every frame; cache or redraw less).
F. Music + more sounds (background music; Hamza's rule: sound effects only for player taps).
G. Late-game Valet/Desk "wall": specialist managers that help with it (design agreed 16 Oct, see below).
H. Bigger later (from the old ideas list): car show events (material farm), Hometown skill branch, Android launch.

Late-game wall (design agreed 16 Oct): late cities hit a Valet/Desk "wall" on purpose (they can't keep up even at
Lv 400). It should last long enough that players get 1-2 specialist managers that help with it ("bay ahead /
valet ahead / desk ahead"); much later it wraps back round so bays become the expensive side again and different
managers matter. Not built yet.

### v0.17 decisions (16 Oct, Hamza)
- PREMIUM tab: assigning a premium manager who works elsewhere opens a popup "X is currently at Bay 2 in Detroit"
  with ASSIGN / CANCEL. Cash managers (MANAGERS tab) are never pulled off a station: Remove first.
- Valet + Front Desk: keeping them ~1.1x ahead of the bays should take about 1/3 of early level-up spending.
- Renovation tiers apply in the Hometown Garage too.
- The late Valet/Desk wall stays (see Next 4).

### v0.17c decisions (17 Oct, Hamza)
- Premium managers will get UNIQUE abilities later (e.g. "your income for the next 30s is teleported straight to the
  top of the valet, ready for the front desk"), so their current ability strengths are placeholders: don't tune them.
- Case Files only come from the Hometown Garage. The first Premium manager (Dazza's whole dossier) is a reward for
  Hometown run 1's first renovation. Stars / prestige / Book sets give Gloss, boosters and Certs instead.
- Reputation is a slow burn with high passive value: 2 stars ~1h, 5 stars ~week 1, 9 stars months.
- Each country has its own rare cars (Hometown gets all unlocked countries'); filling the Book takes the whole game.
- Speed abilities last twice as long as income ones (`SPEED_DURATION_MULT`).
- Car art: don't trace/paint over photos of real cars (even with badges removed). Draw original look-alikes from
  scratch; IP lawyer before launch.

### v0.17d decisions (17 Oct, Hamza)
- Cash managers go the Idle Miner route: Junior 30% off / x2 for 1 min, recharge 4 min; Senior 50% / x3, 4 min,
  recharge 12 min; Executive 80% / x5, 10 min, recharge 20 min (speed lasts 2x). Odds 60 / 30 / 10, hires x3 each.
  Discounts only ever cut that station's level-ups (never bay builds). Goal: players get used to using managers.
- v0.17d-2: odds back to 70 / 25 / 5 (better tiers rarer). The ABILITY of a hire is dealt like a deck: picked from the
  types you have fewest of at that station type in that city, so every 3 hires = one speed, one discount, one
  income (random order). No farming one type, no floods (he got heaps of speed at the desk by plain bad luck).
- Detroit unlock = 200B (when Lima's Bay 8 -> 9 slows down at ~600M/s), LA = 20T. Both PLACEHOLDERS in
  `CITY_UNLOCK_OVERRIDE`; other cities still use the formula. Lima's prestige (385B) needs LA, so it now comes later
  than the old sim said. Bay 9 (1.14T) stays: by then players should be heading to Detroit.
- Early on players can't afford many hires, so an 80% manager is a lucky pull; a bay hits diminishing returns within
  a few minutes of a discount and other bays become better with a simple Junior boost. That's intended.
- Premium managers stay as they are (30 min recharge) until the big premium overhaul: 4-8 premium managers with
  unique abilities, roughly 1-2 per tier.

## What it is
Portrait mobile idle tycoon (Godot 4.7, Mobile renderer, 720x1280). Idle Miner style layout: one scrolling shop with slim station strips. Monetisation plan: rewarded ads (AdMob) + paid "remove ads" + premium managers later. Android first.

## Core loop (3-station chain, like Idle Miner shaft -> elevator -> warehouse)
1. **Bays** detail cars. Finished cars' value piles up in the bay's key cabinet.
2. **Valet** drives down the left lane, collects from bays (up to its capacity), brings them up to the pickup lot.
3. **Front Desk** checks customers out: turns the lot into cash. Only the desk makes cash.
- Income = slowest station (HUD + rows show "BOTTLENECK").
- Without a manager a station only works when tapped (bay car / valet lane / desk).
- v0.17c: Valet and Front Desk are always moving. With a manager the valet runs non-stop (nothing ready = it drives
  to the last bay and comes back empty) and the desk counts non-stop (an empty lot = full animation, $0). A tap
  without a manager always does one run / one count, even empty. Bays always have a car in them.

## Levels + boosts
- Every station has a Level button (right side) -> panel with x1 / x10 / x50 / NEXT BOOST / MAX.
- v0.17: < > arrows in the panel's title step through Front Desk -> Valet -> Bay 1 ... last bay (wrapping both ways). The next-boost box just says "Next boost at Lv 10", with the bar and "+5" + a Gloss droplet at its end.
- Boost ladders at Lv 10, 25, 50, 100, 150 ... 400 (max). Bay boosts ARE the services (Quick Wash -> Foam Cannon -> Full Detail -> Clay Bar -> Paint Correction -> ... -> Ceramic -> Graphene -> PPF). Each = income multiplier and more detailers shown in the bay.
- Old service picker + global upgrades (Pressure Washer, Premium Products) were removed. Night Shift moved to the Shop.

## Income boosts (v0.10)
- TOTAL = BASE x BOOSTERS. BASE = permanent boosts x ad x2 (multiplied). BOOSTERS = all running boosters ADDED (x5 + x2 = x7, none = x1).
- Examples: ad x2 with x5 + x2 boosters = x14. Lifetime x2 x ad x2 x x5 booster = x20.
- Ad x2: +4h per ad, caps at 24h (placeholder button until AdMob). Boosters: x2 30m, x3 1h, x5 15m, x5 2h, x2 day pass, x4 week pass (Gloss prices are placeholders).
- New games start with 2x "x2 30m" + 1x "x5 15m". Each reputation star gives an x2 30m booster.
- Applies to every city (city_mult). Offline earnings use the AVERAGE boost over the time away.
- Centre bottom button BOOST shows the total + time left; opens the Boosts panel (breakdown, ad, running, owned, buy). Manager "activate all" now lives in INFO only.
- 20 bays per city (was 10). Bays 11-20 build costs are placeholders. Car tiers step up every 4 bays; each premises level shifts them up.

## Cars, VIPs, reputation, the Book (v0.3)
- Every job is a specific car with an ORIGINAL brand (`Data.CARS`), GTA-style: brands hint at a country/style (Hoshino, Raiden, Isarwerk, Sternwagen, Henderson, Southcross...) but never copy real names. Get an IP lawyer to glance at the list before launch. Bays 1-2 get Bombs, 3-4 Daily Drivers, 5-6 Enthusiast, 7-8 Performance & Luxury, 9-10 Exotics (`BAY_TIERS`). Classes: JDM / Euro / Muscle / 4x4 (same ids as the manager crews).
- **VIP visits**: rare cars (`VIP_CARS`, Rare/Epic/Legendary; v0.17c: 31 models, each tied to a country, 6-7 per country; a country only gets its own, Hometown gets every unlocked country's; the guaranteed first one is always a plain Rare) roll into the pickup lot, wait 2 min (countdown, tap to send now), then take over one bay. Pay = bay pay x 25/75/250, worked out when the car FINISHES, so firing manager boosts on that bay pays off. Gives cash + followers + premium currency. v0.17: NONE at all until a guaranteed first one 5s after Bay 3 is built; then ~1 per 20 min while playing at 1 star, +25% per star (9 stars = 3x); 40% chance one is waiting after 20m+ away (only after the first). Payout = ONE message in the middle of the screen ("RARE CAR PAID $X!" + car, followers, Gloss, and "2 STARS!" if its followers earned a star). Big centre messages now queue: only one is ever on screen (the old "two stacked texts" was the payout banner + a star-up banner at once).
- Big alert banner only for VIPs NOT yet in your Book (and only if "Rare car alerts" is on in Shop settings); otherwise a small toast. Phone push notifications when the game is closed = later (needs an Android plugin; hook is in `main.gd` `_on_vip_arrived`).
- **Reputation**: followers -> 1-9 stars. v0.17c slow burn: new car +1 follower, VIP 10/50/250, display 0.4-20/h (VIP on display 40/100/250/h), v0.19l: No reviews yet, then 1.0 at 15 / 150 / 600 / 4K / 30K / 150K / 500K / 1.5M / 5.0 at 5M. Each step = x1.18 bay income, +22% VIP rate, +10 premium currency. Followers come from new cars in the Book, VIPs, and cars on display (followers/hour, also while away).
- **The Book**: every car you've detailed (rare visitors listed per country). New cars don't pop a toast any more (v0.17): a red "!" sits on the BOOK button until you open the Book. 3 display slots (+1 at 4 and 6 stars, +3 buyable). Each displayed car adds weight to its class in the customer mix and makes that VIP model 4x likelier. Completing a tier = +50 premium + x1.1 income forever.
- Followers, Book and premium currency are meant to survive the workshop prestige reset.
- **Premium currency**: placeholder name "Gloss" (`Data.PREMIUM_NAME`, rename in one place). Start 25. Spend on Pro/Elite manager crates, extra display slots, instant boost recharge. Buying packs with real money = later.

## World: countries, cities, prestige (v0.6)
- `Data.COUNTRIES`: USA ($), Japan (¥), Germany (€), Australia (A$), UAE (AED). Each has 5 cities and its OWN cash wallet. Real city/currency names are fine; only car brands must be invented.
- Every unlocked city is its own shop and they ALL earn: the city on screen runs live; the others earn their idle rate in the background (GameState `_bg_rates`, refreshed every 2s). Offline earnings come from every city, per currency.
- Each city in world order is x10 bigger (`CITY_SCALE_GROWTH`): costs AND income x10. Unlock the next city in a country with that country's cash (`CITY_UNLOCK_BASE` x scale x `CITY_UNLOCK_GROWTH` per city already open there).
- Prestige = upgrade a city's premises (`PREMISES`, 6 levels = 5 prestiges: Suburban Car Wash -> Detailing Studio -> Performance Garage -> Prestige Atelier -> Hypercar Hangar -> Concours Pavilion). Costs cash (`PRESTIGE_COSTS` x scale), income x4 per prestige, +50 premium, tutorial restarts. v0.17g: no city needed any more, the 1st prestige costs the same as the next city (was: needs the 3rd city). It's a FULL reset of that city: bays, levels, renovations, and the cash managers hired there are DELETED (hiring starts cheap again). Kept: premium managers (freed), gear, uniforms, boosters, Book, reputation, skills, Hometown, other cities, country cash. Leapfrog: a prestiged early city out-earns a newer one.
- New country: bought with the previous country's currency once its last city is unlocked (`unlock_cost`).
- Each country biases the customer mix (USA muscle/4x4, Japan JDM, Germany Euro...).
- Managers: cash hires belong to their city (`home`); premium crate managers are a shared pool that can work in any city (one job at a time).
- UI: MAP button = world map (scroll sideways). Top bar shows only currencies you own. City cards: stars, premises, x mult, income/s, BEST EARNER / YOU'RE HERE, GO / UNLOCK / PRESTIGE (two-tap). Tap the shop sign at the top = premises/prestige panel for the city you're in.
- MAP button = HEADQUARTERS hub with tabs: WORLD, SKILLS (+ MANAGERS, EQUIP, EVENTS greyed "soon").

## Skill tree (v0.7)
- ONE skill tree screen (HQ > SKILLS), never per city. All 5 country branches side by side, joined by one trunk. A country's branch greys out until that country is unlocked.
- Tokens are per country, bought with that country's cash: price = 1K x (country's first-city scale) x10 per token bought. Spend them on that branch's nodes (Lv n costs cost x n tokens). Nodes need Lv 1 in their parent node(s).
- Nodes boost anything anywhere: country income, all income, background cities, valet/desk/bay speed, crew specialists per class, level/hire discounts, rare car rate/pay/premium, followers, display slots, manager boost duration. Data in `Data.SKILL_BRANCHES`; effects applied via `GameState.skill(type, key)`.
- `scripts/skill_tree_view.gd` draws it.

## Art pass (v0.17e) — the current look
- Goal (Hamza): bubbly, cartoony, inviting, for a wide audience; Idle Miner as a reference for warmth, not to copy.
  Not pixel art.
- Font: **Fredoka** (SIL OFL, free for commercial use, `assets/game/fonts/fredoka_*.ttf` + licence). Bold for titles
  and numbers (`UiTheme.DISPLAY_FONT`), SemiBold for everything else (`UiTheme.BODY_FONT`, the theme default).
- Buttons: `UiTheme.button` = chunky rounded "lip" buttons (ink outline, deep darker bottom edge that squashes on
  press, shine strip); any colour snaps to the cartoon palette. `UiTheme.lip_box` for buttons drawn in code
  (Build Bay, Level buttons, renovation strip).
- Palette: friendlier blues (`UiTheme` constants), ink outline colour `UiTheme.INK`.
- **Cars** (`scripts/car_art.gd`): original side-view cartoon cars drawn in code, 11 body styles (hatch, sedan,
  wagon, coupe, muscle, gt, hyper, suv, boxy, ute, limo) picked per car id in `CarArt.BODY`. Rounded (smoothed)
  bodies, thick outlines, gradient paint, glass glare, big shiny wheels, dirt as mud blobs. Rare cars get wings,
  stripes, light bars and gold rims. `tools/car_sheet.gd` renders every car into one PNG for review
  (`godot --path . --script res://tools/car_sheet.gd -- out.png [dirt]`).
- Scenery (`scripts/scenery.gd`): lane with curb, tiled bay walls + lamp + floor that **change with the premises
  level** (6 themes), number badges, shop sign + scalloped awning + clouds, forecourt lawn + bushes, earth under
  the last bay. Car art reference images from Hamza (AI-generated) were used as style reference only.
- Managers in lists use the same cartoon person as at the stations (no more Kenney face sprites for cash managers).

## Art pass part 2 (v0.17f) — everything except the characters
- Shared look in `UiTheme`: `card()` = bubbly tile (rounded, outlined, chunky darker bottom lip; optional coloured
  rim: gold `CARD_GOLD` = claimable / wearing / premium, green = running ad boost). It's also the theme default for
  PanelContainer. `ribbon()` = section heading as a coloured pill. `set_tab_look()` = open tab yellow, others blue
  (HQ tabs, Equip tabs, manager ability tabs, level x1/x10/x50 tabs). `outlined()` = ink outline on a label.
  `draw_pattern_bg()` = bright striped background with faint sparkles (HQ). `sparkle()` = 4-point twinkle.
- Popups (sheets) have an ink outline; every dark row is now a raised card (Overview section headers are blue
  ribbons, Boosts total is an orange card, Book header is a purple "showroom" card with the display + mix, Book car
  tiles are pale collectible cards, prestige NOW/NEXT cards, case-file cards: coloured back with a big "?" and a
  CLASSIFIED tag, dossier figure on a pale tile, toasts + the rare-car banner + big messages are rounded cards).
- HQ: bright striped background, HUD-blue title bar, yellow open tab; countries are big chunky cards in their
  colour with lighter city tiles, ink-outlined map pins; skill tree = wooden trunk/stems, chunky nodes with a lip
  (grey locked, blue open, country colour levelled, orange maxed), gold links with an ink edge; equipment, material,
  uniform icons sit on pale tiles; roster section headings are rarity ribbons; unknown premium portraits have a pale
  backing so the silhouette pops (the characters themselves are unchanged).
- Bottom bar: code-drawn icons above the labels (`scripts/ui_icons.gd`: bag, book, lightning, clipboard, globe).
  INFO is blue now. The bar is 12px taller; jump buttons + toast moved up to match.
- Valet ute: drawn in code (`CarView.draw_ute_sprite`, yellow cartoon ute from above, round headlights, cab with
  windscreen glare, wooden tray, cash bundles fill it: empty / 1/4 / 1/2 / 3/4 / overflowing). Kenney `ute.png` is
  no longer used (still in assets). The cash it carries shows in a green speech bubble.
- Ability icons above managers: ink outline, darker lip, shine, shadowed symbol. VIP waiting in the pickup lot =
  rarity-coloured card with a gold "VIP RARE" pill.
- Small life (silent, calm): soap bubbles drift up + suds along the sills while a bay washes, then twinkles on the
  paint as it comes up clean.

## Art + sound (v0.8)
- Kenney CC0 packs (free for commercial use, no credit required) are in `assets/kenney_*` with a `.gdignore` so Godot doesn't import/export the whole packs. Only the files the game uses are copied into `assets/game/` (sfx, sprites, ui buttons, font) = ~300 KB.
- Sprites: detailers = Kenney male person (orange hi-vis), cashiers = female person, manager faces = 4 Kenney characters (v0.17f: the valet ute is drawn in code now). Side-view cars in bays are still drawn in code (needs an artist later).
- UI: Kenney flat buttons (blue/green/yellow/red/grey picked from the colour passed to `UiTheme.button`), Kenney Future font for big numbers/titles (`UiTheme.DISPLAY_FONT`, `display_label`).
- Sound: autoload `Sfx` (`scripts/sfx.gd`): `Sfx.play("click")`, `Sfx.buzz(ms)` for vibration. v0.17g: slots with
  versions (Sound board), music player (assets/game/music). RULE (Hamza): sounds ONLY for things the player does (taps to start work, buttons, upgrades, boosts, hiring, prestige, panels). Automatic stuff (cars finishing, valet trips, cash coming in, rare cars, stars) is silent. Background music to come later. Settings in Shop: sound, vibration.
- Juice: coins fly + cash pops only when YOU tap the desk (before it has a manager); floating "+$" only on stations without a manager. Level buttons bounce, big banners for boosts (with Gloss reward) / rare car payouts / stars / prestige, characters scrub and cheer.
- No "BOTTLENECK" tags: a small red "!" sits next to FRONT DESK / VALET when one of them is the slowest station (v0.17: never on bays). INFO button = Overview screen (like Idle Miner's Mine Overview): each station's $/s, manager + boost state, each bay's share, the slowest station outlined with a red "!" (no text since v0.17c), Activate-all button.
- Boost levels give premium: 1st boost on a station +5, 2nd +3, later +1 (`BOOST_GLOSS`). Shown in the level panel. Reaching a boost plays its own sound but shows NO banner (v0.17c). Repeats after prestige.
- Tutorial ends quietly if the player opens Map / Shop / Book / premises during it.
- First rare car is guaranteed 5s after building Bay 3 (early wow moment); none before it.
- The game is exported as a WEB build (`../phone/index.html`) and played in the phone browser.

## Planned UI (from Hamza)
- Prestige icon inside the city screen: static when you can't prestige, shines when you can; tap = GUI with prestige benefits + cost.
- Managers, Equipment, Events tabs in the HQ hub.
- Layout will change once art/mockups exist; logic is separate from UI so it's just moving things (can convert key screens to .tscn scenes for visual editing).
- Numbers: K, M, B, T, then aa, ab ... az, ba ...
- All prices are placeholders; Hamza will balance by playtesting.

## Feel rules (from playtests)
- No progress bars. Show progress with visuals: bays = dirt fading; valet = ute tray filling with cash (empty, 1/4, 1/2, 3/4, overflowing); front desk = cashier counting note stacks onto the counter, then the cash tin/till opens and takes them.
- No tap-to-speed-up. Tapping only STARTS a station before it has a manager. Jobs take a fixed time; speed comes from levels (valet driving speed +2%/level) and manager boosts.

## Tutorial
- v0.17g: bouncing arrow + speech bubble: tap car -> tap valet -> tap desk, then "YOU'RE GOOD TO GO!". Skip button.
  (The hire / level steps were removed; old saves on them just finish.)
- Steps live in GameState (`TUT_*`, `tutorial_step`, saved); drawing in `tutorial_overlay.gd`; targets in `main.gd` `tut_rect()`. Call `GameState.start_tutorial()` after a workshop prestige.
- First manager hires are cheap ($10 / $25 / $25) so the tutorial flows.

## Managers (v0.11)
- Tapping a station's manager portrait opens its panel: whoever works there on top, then two tabs.
- v0.17 ability button (like Idle Miner): a small round icon ABOVE each station's portrait. Tap = use the ability. "$" income, fast-forward arrows speed, "%" discount. Glows + time left while active, dimmed + countdown while recharging. The old lightning badge on portraits is gone. (`scripts/ability_icon.gd`)
- Station manager panel (v0.17d): current manager on top, HIRE MANAGER under it, then tabs PREMIUM (always gold with a shiny star; faded gold when open) / SPEED / DISCOUNT / INCOME. The ability tabs list your FREE cash managers with that ability, best tier first. HIRE rolls a random ability + tier and jumps to that manager's tab with them highlighted ("NEW!").
- Cash hires: Junior 70% / Senior 25% / Executive 5% (ability dealt like a deck, see v0.17d decisions), hire cost x3 per hire in that area in that city (was x8). Tiers (`Data.RARITIES`): Junior 30% off or x2, 1 min, recharge 4 min; Senior 50% / x3, 4 min, 12 min; Executive 80% / x5, 10 min, 20 min. Speed abilities last 2x. They only work in the city they were hired in. Assigning never pulls one off another station (Remove it there first). A city's prestige deletes the cash managers hired there.
- Managers STAND at their station (v0.17d, `scripts/station_manager.gd`): code-drawn person with one calm idle loop per manager (arm pump / arms crossed / hands on hips / clipboard), moving 2x faster while their ability runs; rarity-coloured shadow. Cash managers dress by tier (Junior polo in crew colour, Senior shirt + crew tie, Executive dark suit + tie). Premium managers wear their dossier look and raise their signature tool. Empty station = "+ HIRE" box.
- PREMIUM tab (v0.17): every premium manager you own for that station type, free, working elsewhere or in another city. Assign on a busy one -> popup "X is currently at Bay 2 in Detroit" [ASSIGN] [CANCEL].
- PREMIUM tab: 25 unique named managers (one of each), Common/Uncommon/Rare/Epic/Legendary (grey/green/blue/purple/gold). Work in any city, one station at a time. One manager per station either way (seating one frees whoever was there).
  - Unlock: collect 6 clues (shirt, pants, shoes, hair, face, signature tool) into their dossier (silhouette fills in), then CALL for a flat $100.
  - Ability (30 min recharge for now, stronger by rarity; unique abilities coming in the premium overhaul, see
    PREMIUM_PROPOSAL.md)
  - **Dazza's signature: Tip Jar** (v0.17e, `Data.SIGNATURE_ABILITIES`): for 30s his bay's cars go into a glass jar
    beside him instead of the key cabinet; then he cashes it x3 (Lv1) .. x5 (Lv50) straight into your wallet
    (skips valet + desk). Jar fills on screen, "+$X TIPS x3!" pops. Signature abilities have kind "signature"., passive while working (bay income / valet carry / checkout +10% Common ... +60% Legendary at Lv1, +4% of that per level).
  - Certs level them (max 50). Promotions: Rookie 1, Pro 10, Lead 20, Chief 35, Master 50. Perks at Lv20 (small) and Lv50 (big): Quick Recovery, Stamina, Crew Regular, VIP Handler / Veteran, Shop Boss, All-Rounder (counts as every crew), Signature Move.
  - Legendary passives (while working anywhere): Mirror Mori = every city +25%, The Gaffer = managers in his city use abilities by themselves, Simone Laurent = rare cars twice as often + pay x2.
- Crews (both kinds): specialist x1.5 on their crew's cars, chain (bay+valet+desk same crew) x1.5, pair (valet+desk) x1.25.
- CASE FILES (v0.17c) open one CARD at a time: face-down black card -> flips -> the manager (silhouette filling in) + the clues it gave -> NEXT CARD -> ... -> summary. Each card = one manager (the same one can come up twice in a file) + 1-6 clues they're missing (never a repeat; prefers dossiers you've started); clues beyond what's missing become 3 Certs each. Clue roll 1-6 = 45 / 30 / 15 / 7 / 2.5 / 0.5%, capped per file: Basic 2 cards x up to 2 clues (+5 Certs), Detailed 3 x up to 3 (+15), Classified 4 x up to 6 (+40). Not sold in the shop. (`scripts/case_result_panel.gd`)
  - ONLY from the Hometown Garage (renovation goals: Basic; finished run: Detailed / Classified). Dazza's whole dossier = Hometown run 1, renovation 1 goal. Stars give +10 Certs, prestige +25 Certs, rare cars +3 Certs.
- HQ > MANAGERS tab = the premium roster + Case Files. MAP button shows "!" when a file is waiting or a dossier is ready to call.
- Gloss manager crates removed; old crate managers became Detailed Case Files. Save v7 (v6 "supervisors" from a short-lived build turn back into Junior managers).

## Equipment (v0.12)
- Crafted only, never dropped. One of each item exists. Craft the Common, then upgrade it to Rare and Epic (the item below is used up + materials). Instant.
- Premium managers only, 1 slot each, swap any time (an item moves off whoever had it).
- 10 generic items. Station ones help wherever the wearer works: Pro Stopwatch (ability cooldown), Energy Drink Fridge (ability time), Lucky Air Freshener (passive), Microfibre Gloves (station speed), Detailing Apron (station income), Crew Jacket (crew bonuses), Deal Clipboard (level-up cost). Global ones work while the wearer works anywhere: VIP Lanyard (rare cars more often), Night Lamp (offline earnings), Blueprint Tube (Hometown renovations, used once that exists).
- Materials (only for crafting): Microfibre, Rubber, Steel / Chrome, Polishing Compound / Carbon Fibre, Ceramic, Alcantara.
- Materials come from Hometown Garage goals (v0.13) + car show events (not built yet). For testing: debug key E or the debug button in MATERIALS gives 100 of each.
- HQ > EQUIP has EQUIPMENT (craft / upgrade / equip) and MATERIALS tabs. Dossiers have a GEAR slot.

## Hometown Garage (v0.13)
- Unlocks when any city has 5 bays. Its own column at the start of the MAP. v0.17c: toast "Tap MAP to visit it", MAP shows "!" and opens scrolled to the Hometown until you've been there once (`hometown["seen"]`). Own currency (HT$). Never touched by prestige. Shares boosts, skills (global nodes), managers, Book/reputation bonuses.
- Played in RUNS: 5 bays, then 10, 15, then 20 forever. Finish a run = every bay built and at Lv 50 + Valet and Front Desk at Lv 10 x run bays (50/100/150/200). Levels stop at those targets there.
- Pace: each deeper bay earns AND costs x2.5 (cities: x8 / x12). v0.17 sim (tools/sim/home.py, ad x2 + skills): 5 bays ~5.3h, 10 ~8.9h, 15 ~12.3h, 20 ~18.5h incl. renovations. Knobs: HOMETOWN_COST_MULT, HOMETOWN_VD_COST_MULT + HOMETOWN_VD_LEVEL_GROWTH (valet/desk prices there), HOMETOWN_TIER_INCOME / _COST, HOMETOWN_GROWTH (2.5).
- 3 renovations per run at 1/4, 2/4, 3/4 of the bays (see Renovations below): timers 2h / 5h / 10h at 20 bays, scaled by run bays / 20 for smaller runs. Stages: Dirt Lot -> House Garage -> Detailing Shop -> Premium Studio (better cars each stage).
- Goals with rewards to CLAIM (tap the shop sign in Hometown): build each bay (common materials), each renovation (Case File + rare material), each bay to Lv50 (Certs + common), valet/desk targets (Certs + rare), FINISH RUN (Detailed, or Classified from 15 bays; lots of Certs, rare + epic materials). Rewards x(1 + 0.2 per finished run). Then START NEXT RUN: back to a dirt lot, cash 0, hired managers kept (jobs freed).
- MAP shows "!" when Hometown has rewards to claim.
- One-time city nudge (v0.17e): when the next city in your country is affordable and costs less than your next bay,
  a toast ("Detroit is open for $200B! Tap MAP to expand.") + MAP "!" until you open the map. Once per city, ever
  (`GameState.city_nudges`, saved).

## Wardrobe (v0.14)
- Shop > WARDROBE. Crates bought with Gloss (can be bought any number of times): Wardrobe Crate 100 (1 uniform), Big 450 (5, one Rare+), Designer 1200 (1 Epic/Legendary). Legendary guaranteed within 40 uniforms (pity).
- 15 uniforms: 5 rarities (Common..Legendary) for each crew: Detailers (bays), Valets, Front Desk.
- One worn per crew; it boosts that station type in EVERY city (Hometown too): x(1 + base x (1 + 0.15 x (level-1))), base 0.10 / 0.20 / 0.40 / 0.75 / 1.50. A better new uniform is worn automatically; you can switch any time.
- Duplicates level a uniform up: Lv L -> L+1 needs L copies. Max Lv 25. The long game: land a Legendary and keep levelling it.

## Renovations (v0.16)
- Every city (and Hometown) has 3 renovations, like Idle Miner's rock barriers: before bays 6, 11 and 16 in cities (Hometown: 1/4, 2/4, 3/4 of the run). Event cities may skip them later.
- Cost 3x the next bay's build cost (RENO_COST_BUILDS); v0.19k: a city's 1st renovation only 1x (RENO_FIRST_COST_BUILDS). Timer runs on its own (also while away). v0.17d: at 0:00 a padlock appears ("TAP TO UNLOCK"); tapping it finishes the renovation (unlock sound) and the bay can be built. It waits for you if it ran out while you were away or in another city (Hometown card on the MAP says so).
- Sounds (v0.17d): building a bay (wood knock), starting a renovation (pick), the unlock (lock clunk + chime): `build_bay`, `reno_start`, `unlock` in `assets/game/sfx`.
- The strip reads "BEGIN RENOVATION" with what it builds under it, then price + time (v0.17).
- Renovation tiers (v0.17): bays after each renovation (6-10, 11-15, 16-20) earn x`RENO_TIER_INCOME` (3) per tier but their levels cost x`RENO_TIER_COST` (~350) per tier, so their first levels are a much worse deal than levelling the older bays; sim (Lima played on its own): Bay 6 out-earns every older bay at ~Lv 25 (2nd boost), but only ~10h after it is built (Lima prestiges at ~4h, so in Lima's first run Bay 6 stays a slow starter). Lower RENO_TIER_COST if that feels too slow (sim: x100 = take-over at ~Lv 20, ~1.5h after building). Hometown: x2.4 income / x3.6 cost per tier (older bays sit at their Lv 50 cap there, so the income jump sets the take-over at ~Lv 25; a bigger cost jump would stretch runs).
- Cities: same timers everywhere, 1h / 8h / 48h (CITY_RENO_HOURS). Hometown: 2h / 5h / 10h at 20 bays (HOMETOWN_RENO_HOURS).
- Skip: -30 min, 2 per hour per renovation site (RENO_AD_SECONDS / RENO_ADS_PER_HOUR). Blueprint Tube gear shortens timers.
- City renovation done = +10 Gloss, +5 Certs. Prestige brings a city's renovations back (shop resets to 1 bay). Old saves: renovations already passed count as done.

## Ads (placeholder until AdMob)
- Setting "No-ads pack (placeholder)" in Shop, ON by default: ad buttons are free skips (renovation -30 min, ad x2 boost +4h, Collect x2 offline). OFF: they say WATCH AD (still instant until AdMob is in).

## Balancing tools (debug builds only)
- **B** balance overlay: play time, idle income, slowest station, time until next bay / renovation / prestige, multiplier breakdown, Gloss/Certs/Case Files.
- **F** skip 1 hour, **H** skip 8 hours (timers run down, managers earn as if you were away). **T** game speed x10 (renovation/boost timers still use real time).
- Milestone log: every bay, renovation, prestige, city, country, star, Hometown run, skip -> `balance_log.csv` in the game's user folder (path shown at the bottom of the Shop). Send it after a session.

## Files
- `scripts/game_data.gd` — ALL balance numbers, boost ladders, manager abilities, crews, names. Tune here.
- `scripts/game_state.gd` — autoload `GameState`. Chain simulation, levels/costs, managers, cars + customer mix, Book, reputation, VIPs, premium, save/load (v3, migrates v0.1/v0.2 saves), offline earnings, number formatting.
- `scripts/main.gd` — screen layout: HUD, scroll of rows, bottom bar, popups, toast.
- `scripts/desk_row.gd`, `valet_row.gd`, `bay_card.gd` (one bay strip), `build_row.gd` — the station strips.
- `scripts/lane_overlay.gd` — draws the valet car moving in the lane over the rows.
- `scripts/car_art.gd` (cartoon cars), `scripts/scenery.gd` (row scenery).
- `scripts/portrait.gd`, `station_manager.gd`, `level_button.gd`, `ability_icon.gd` — manager portrait (lists), standing manager at a station, Level button, ability button above the manager.
- `scripts/manager_rig.gd`, `manager_anim.gd`, `manager_aura.gd`, `manager_parts.gd` (generated) — posh cash managers (v0.19): rig, idle/instruct animation, suds aura. `scenes/manager_lab.tscn` = preview.
- `scripts/sheet.gd` (base bottom sheet), `level_panel.gd`, `manager_panel.gd`, `shop_panel.gd`, `book_panel.gd` — popups.
- `scripts/tutorial_overlay.gd` — tutorial arrow + bubble.
- `scripts/workshop_panel.gd` — prestige screen for a city (tap the shop sign, the HUD PRESTIGE badge, or PRESTIGE on the map).
- `scripts/map_panel.gd` — HQ hub: world map tab + skills tab.
- `scripts/skill_tree_view.gd` — the skill tree.
- `scripts/car_card.gd` — car tile in the Book. `scripts/hud_meta.gd` — premium currency + stars in the HUD.
- `scripts/car_view.gd` — placeholder art drawn in code (cars, workers, faces). Swap for sprites later.
- `scripts/ui_theme.gd` — colours, theme, lip buttons, cards/ribbons/tabs (v0.17f), game font, text/box drawing helpers.
- `scripts/ui_icons.gd` — code-drawn bottom-bar icons (v0.17f).
- `scripts/depth_row.gd` — the dirt under the Build Bay strip down to the last bay slot + renovation bands (v0.17g).
- `scripts/title_screen.gd` — title screen on launch (v0.17g).
- `scripts/info_panel.gd` — Shine Bucks + Reputation explainer cards; `scripts/tip_overlay.gd` — one-time tips (v0.17h). `scripts/sound_board_panel.gd` — Sound board (v0.17g).
- `assets/game/music/` — background music (every .ogg plays). `tools/audio_synth.py` makes the temporary tracks + pops.
- `scripts/sfx.gd` — autoload `Sfx`: sounds + vibration.
- `scripts/overview_panel.gd` — INFO / Overview screen.
- `scripts/boost_panel.gd` — Boosts screen (centre bottom button).
- `scripts/manager_art.gd` — code-drawn named managers (bust + full body, parts hidden until their clue is found).
- `scripts/wardrobe_panel.gd`, `wardrobe_result_panel.gd`, `uniform_icon.gd` (Wardrobe).
- `scripts/hometown_panel.gd` (Hometown run goals / claims / next run). Renovation strip lives in `build_row.gd`.
- `scripts/equip_view.gd` (HQ Equip tab), `gear_picker_panel.gd`, `equip_icon.gd`, `equipment_art.gd` (code-drawn item + material icons).
- `scripts/roster_view.gd` (HQ Managers tab), `dossier_panel.gd`, `case_result_panel.gd`, `manager_panel.gd` (a station's managers: MANAGERS / PREMIUM tabs).

## Rules of the code
- Logic lives in GameState; UI only reads it and calls its methods.
- UI is built in code (no big .tscn files) so edits stay small.
- Debug builds only: **M** = money, **G** = +500 premium, **V** = spawn a VIP, **E** = 100 of each material, **B** balance overlay, **F** / **H** skip 1h / 8h, **T** speed x10; "Reset save" in Shop.

## Balance (v0.17, tools/sim)
- Whole-world sim (active player, no-ads pack, sleeps 8h a night): Bay 5 0.33h, renovation 1 0.5h, Detroit 0.9h,
  Los Angeles 3.5h, Lima's 1st prestige 4.3h (right after LA), all 5 US cities 48h, Japan day 3.6, Germany day 14,
  Australia day 26, UAE day 55, first 5-star city day 21. A player who never watches ads: about 1.5-2x as long
  (Detroit 1.75h, Japan day 6, Germany day 23, Australia day 49).
- Valet + Front Desk (v0.17b, after Hamza's 16 Oct playtest: at $81/level they fell behind as soon as Bay 1 was
  levelled): base capacity 6 (start ~2x Bay 1), level price $15, capacity +5%/level. Goal (Hamza): about 1.5x
  the bays early if you level them alongside (~half of what goes into bays each), so they need regular upgrades
  but don't fall behind. The old "1/3 of spending" target is dropped. Not re-simulated: Hamza judges by playtest.
  Late, big cities hit the Valet/Desk wall (on purpose, see Next 3).
- Early build costs are lower than v0.16 (Bay 2 $61, Bay 5 $2.1M) because Valet/Desk now take their share.
- Hometown (home.py, ad x2 + skills): runs ~5.3h / 8.9h / 12.3h / 18.5h incl. renovations; Hometown bay costs x0.47
  (was x150), Valet/Desk prices x67 with +9.3%/level there, hires x0.16 (in proportion).

## Status
- v0.17h: girlfriend's playtest: Shine Bucks (rename + icon), top bar buttons + explainer cards, bigger text, one-time
  tips (screens, first rare car pointer, first star, slow valet/desk), Book ON SHOW strip in categories, level panel
  swipe, tap the ute for valet upgrades, tutorial-over-title bug.
- v0.17g: Hamza's 17 Oct playtest list: tutorial ends after the first loop, prestige star in the top bar + prestige
  without the 3rd-city rule, level bar ghost preview, Book categories + NEW stickers, scroll past your bays, big
  Overview rows with ability buttons, valet stepped speed + calmer, early pacing fix (Bay 7 wall), music + soft pops
  + Sound board, coins-over-map bug; title screen, cars roll in, bays drop in, red carpet, renovation scaffolding,
  rolling cash counter.
- v0.17f: ART PASS PART 2 (everything but the characters): bubbly cards/ribbons/tabs everywhere, bright HQ (map,
  skill tree, managers, equip), Book showroom header + collectible car tiles, case files, prestige cards, bottom bar
  icons, code-drawn cartoon ute + cash bubble, bubbly ability icons, foam + sparkles while washing. Characters wait
  for Hamza's design (one prototype first).
- v0.17e: ART PASS (Fredoka font, lip buttons, brighter palette, all cars redrawn as cartoon cars, new scenery
  per premises level, HUD / bottom bar / sheets restyled, cartoon portraits), Dazza's Tip Jar, one-time next-city
  nudge, premium overhaul proposal, sim report.
- v0.17d-2: manager panel layout is fixed (HIRE / tabs / list box never move; empty station = placeholder card); no
  "FREE" heading or "Free" card line; managers recharging are greyed with "Recharging: Xm left" (still assignable);
  up / down jump buttons over the valet lane (bottom left); no "Hired X" toast; rare car "GO TO CAR" scrolls to the
  top while it waits in the pickup lot; odds 70/25/5 + deck-style ability roll; Detroit 200B, LA 20T placeholders.
- v0.17d: cash manager tiers (30/50/80% off, short recharges), hires x3, ability tabs + gold PREMIUM tab, HIRE jumps
  to the new manager, standing animated managers, renovation padlock to tap, sounds for build / renovation / unlock.
- v0.17c (Hamza's 17 Oct playtest): valet/desk always moving (empty runs, $0 counts); level panel shows the gain
  "(+$15K)" and, for bays, "4.5s per car · 34% of your bay income" (no $ per car: VIPs made it misleading); no boost
  "UNLOCKED" banner (sound kept); Overview "!" without "SLOWEST"; first rare car always a plain Rare; Case Files
  card-by-card + Hometown-only, first Premium manager from Hometown run 1; Hometown nudge; reputation slow burn;
  31 rare cars across the 5 countries (Book sections per country); speed abilities last 2x. Economy unchanged.
- v0.17b: valet does exactly one run per tap (a 2nd tap while it was out queued another run); Valet/Desk
  rebalanced to ~1.5x the bays early (price $15, base capacity 6). Hometown Valet/Desk prices unchanged.
  Early build costs left as v0.17 for Hamza to judge. (Hamza's 16 Oct playtest used a x2 boost; boosts scale
  bays, valet and desk alike.)
- v0.17: Hamza's playtest list: level panel arrows + simpler next-boost line, "!" only on Valet/Desk, one rare car payout message, Book "!" instead of toasts, prestige = full city reset (cash managers deleted) and needs the 3rd city, managers tab free-only + premium assign popup, Idle Miner style ability button above portraits, no rare cars before Bay 3, BEGIN RENOVATION strip, renovation tiers (cities + Hometown), Valet/Desk ~1/3 of early spending, whole economy re-tuned (sim v3: tiers, valet/desk, 3rd-city rule, skips, players save for goals).
- v0.16: renovations in every city (bays 6/11/16, 1h/8h/48h), Hometown renovations 2h/5h/10h, skips -30 min x2/hour, no-ads placeholder, balancing tools (overlay, skips, x10 speed, milestone log), economy re-tuned with a whole-world sim.
- v0.15: prestige screen (now -> next, rewards, resets, you keep, 2-tap confirm) for any city; shining HUD badge + sign shine when the city you're in can prestige; ready cities glow on the map.
- v0.14: Wardrobe crates (Gloss): 15 crew uniforms, duplicates level up, global crew boosts, pity. Skeleton complete.
- v0.13: Hometown Garage (runs 5/10/15/20, renovations with ad skips, stages, goals + rewards: Certs, Case Files, materials).
- v0.12: crafted equipment (10 items x Common/Rare/Epic, one of each, premium managers only), 8 materials, HQ Equip tab. Popups scroll when too tall.
- v0.11: Premium managers tab (unique named managers: clues, dossiers, call, Certs, Lv20/50 perks, Legendary passives), Case Files, HQ Managers tab. Cash managers unchanged. Gloss crates removed. Save v7.
- v0.10: income boosts (base x boosters), ad x2 placeholder, boosters + Boosts screen, 20 bays.
- v0.2: Idle Miner style layout, bay/valet/desk chain, levels + boost ladders, managers with abilities + crews, save v2.
- v0.9: interaction-only sounds, calmer screen, "!" slowest markers, Overview screen, Gloss from boosts, tutorial fix.
- v0.8: Kenney art + sounds + game feel pass, sound/vibration settings, guaranteed first rare car.
- v0.7: one skill tree (5 country branches, per-country tokens), HQ hub tabs. Save v5 + skills.
- v0.6: world map, 5 countries x 5 cities with own currencies, per-city prestige (premises), background earning, cash vs premium managers. Save v5 (older saves become Lima, Ohio).
- v0.5: no progress bars (cash ute, counting till), no tap rushing, valet speed by level, workshops (prestige). Save v4.
- v0.4: original brand names for all cars, first-time tutorial with arrows.
- v0.3: car tiers, VIP visits + alert banner, reputation/stars, the Book with display + customer mix, crew specialists, premium currency + crates, settings. Save v3.

## Decided direction
- Cars use GTA-style parody names and look-alike (not exact) designs. No real brand names, badges or logos.
- Workshops = Idle Miner's mines: new locations with better car tiers (bombs -> luxury -> hypercars) and bigger pay. Acts as prestige; reputation + Book carry over.
- Keep it simple in looks, deep in mechanics. No swipe-to-clean; tapping stays.
- Make it its own game, not an Idle Miner reskin: lean into cars, the Book, reputation and VIPs. Restyle Idle Miner-looking UI bits (Level button) when real art arrives.

## Next (agreed build order)
1. (done v0.11) Managers rework.
2. (done v0.12) Equipment.
3. (done v0.13) Hometown Garage. Later: car show events (main material farm), Hometown skill branch?
4. (done v0.14) Wardrobe crates. Next: balance pass (Hamza playtests), then launch prep (AdMob, IAP, music, art, Android). Events after launch.
Later: prestige icon + details screen, map shine, HQ Managers/Equip/Events tabs, music, AdMob, rebalance bays 11-20.

## Old ideas list
- Event cities with a gimmick (Show & Shine, Mud Season...).
- Balance everything after playtesting.
- Rewarded ad on VIP finish ("post it to your page" = 2x followers).
- Real art: detailer sprites in bays, manager portraits, valet vehicles.
- AdMob rewarded ads: 2x offline, boost, instant ability recharge. Premium managers.
- Sounds, wash particles, tutorial for the first taps.
- Android export + Google Play listing.
