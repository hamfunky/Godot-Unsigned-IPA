# Idle Detailing Tycoon — project notes

Read this first in any new chat. Keep it SHORT and current: when a version is done, put its long log in
`OLD PROJECT NOTES.md` (the full history up to v0.19u is there: per-version logs, old decisions, the detailed
write-ups of managers, equipment, Hometown, wardrobe, renovations, balance runs). Where the two disagree, this file wins.

## >>> HANDOFF: START HERE <<<

### Current build: v0.19w (27 Oct) — Hamza's clean-up list before proper phone testing
(v0.19v's write-up is in OLD PROJECT NOTES.md, at the top; the stashes, per-city ad boost and map corners still
work as it says, except where this list changes them.)
1. FRAME RATE (Hamza: 40-70 fps on a 4080 / 7700X, 240 Hz screen). The profiler's top costs were the characters'
   `_draw` (Pen.limb / Pen.capsule / _arm). Now: characters, crews, cashiers, managers and the ability icons move
   + redraw at 30 Hz each (`scripts/anim_clock.gd`, random phase so they don't all land on one frame); scrolling,
   the ute, tweens and the HUD stay at full rate. Limbs are 2 circles + a quad (`Pen.cap`) instead of an
   18-point capsule; sleeves no longer clip polygons every frame. Cloud box bench: ~12-16 ms of `_draw` per
   frame -> ~3 ms (headless, no GPU: relative numbers only). NEED Hamza's FPS overlay (P) + profiler (Self).
2. FREE SPIN tag fits in the sky strip again (wheel a bit smaller + higher: `sky_row.gd` WHEEL_R 42, C (84,52)).
3. PRESTIGE TROPHY: no "Lima, USA" under it (the Hometown, which has no trophy, still shows its name there);
   lower, level with the idle-income / rating pills (away from the camera notch); always plain gold with the
   number; when a prestige is ready it bobs gently, a band of light sweeps across the cup and 3 sparkles take
   turns (no glow disc, no rays). Still otherwise: redraws only when its number / ready changes.
4. MAP PANELS like Idle Miner (`map_side_panel.gd`): COLLECT covers the LEFT side, PRESTIGE the RIGHT (the old
   one drew prestige on the left: it positioned itself before it had a size). Full height, dark blue, red X.
   COLLECT: per country its cities (shop, name, "Boost: 3h 20m", +stash), "= total", COLLECT x2 (AD ONLY, Hamza:
   `GameState.collect_ad(cid)`, `Data.COLLECT_AD_MULT` = 2) and BOOST ALL; at the bottom ALL COUNTRIES +
   COLLECT ALL x2. BOOST ALL is never greyed out: tapping it before all 5 cities are open (or when they're all
   full) shows a little message (`GameState.boost_all_block(cid)`); otherwise ONE ad puts every city of the
   country at the full 24h (`boost_all` no longer adds +4h each). Going to a city still collects its stash x1.
   Ad buttons show the {ad} icon (a little screen with a play button, `game_icons.gd` "ad", baked to
   assets/game/ui/icon_ad.png); with the no-ads pack (`ad_free()`, ON by default in dev) they're just words.
   PRESTIGE: header = your trophies / every trophy there is (N / 125); a row per city: shop, $/s, a trophy badge
   with its level, PRESTIGE (opens that city's prestige screen), "xN income" after it, a chevron that opens the
   price + what it does. The Hometown isn't listed (it doesn't prestige).
5. LOADING (Hamza: only for big changes): LAUNCH = the title screen fills a bar first ("Opening the shop /
   Washing the cars (car pictures) / Drawing the map (the world bake, `MapPanel.prebake`)") and only then shows
   TAP TO PLAY. CITY CHANGES = `main.with_loading(work, where, sub)`: a full-screen card (sky by the clock, a
   skyline, the city name, a bar with a freshly washed car driving along it) goes up FIRST, the change runs under it 2 frames
   later, the bar fills while the new shop's car pictures render (`CarCache.pending()`), min 0.7 s, max 2.5 s,
   then it fades. Used by: GO on the map, unlocking a city / a country, prestige, starting a Hometown run.
   (The work callables are bound to GameState, not the panel, because the panel is freed by then.)
6. SKYLINE (mockup sent 27 Oct, Hamza: "beautiful, add them in"): `scripts/skyline_art.gd` draws two layers
   (hazy far towers + the country's landmark: USA art-deco spire, Japan lattice tower, Germany TV tower + church
   spires, Australia tower + harbour sails, UAE needle + domes; the Hometown is a small town) and near buildings
   (glass window grids, brick + sills, shaded sides, roof tanks / AC / antennas with a red light at night, a
   car-wash billboard, lit windows at night). sky_row bakes it into a SubViewport picture (`SkyPic`) only when
   the hour bucket / weather / city changes; the loading card shows it twice the size on its horizon (drawn once).
   Review sheets: tools/skyline_shots.gd.
7. PERF ROUND 2 (Hamza's numbers 27 Oct, editor run: FPS 87 map / 50 scrolling / 65 at rest; profiler (Self):
   Frame 8.9 ms, ALL GDScript 2.3 ms, render 1.5 ms; draw calls ~2500-2900, shapes ~140K):
   - The overlay's old "scripts+draw" was Performance.TIME_PROCESS, which includes waiting on the GPU / V-Sync
     (read 28-42 ms at 65 fps). New overlay (P): frame ms + worst frame, game ms (scripts + layout + drawing:
     first _process -> RenderingServer.frame_pre_draw, `main.PerfClock`) + worst, render ms, calls, shapes, nodes.
   - THE MAP no longer has the whole shop drawing under it (`_scroll` hidden while a MapPanel is open): the map's
     frame work 32 ms -> 3 ms on the cloud box (~7 ms saved on Hamza's PC).
   - Things that redrew every frame for nothing: the AD BOOST button (a Control redraws whenever its SCALE
     changes, and it breathes with a scale tween: its picture is now on a child `_face`), the BOOST button
     (re-applied its font-size override every frame: `_set_font_size` only when it changes), the trophy shine
     (now 30 Hz).
   - Headless, the per-frame logic is ~0.1 ms: the cost is all drawing. On a 240 Hz screen with V-Sync, a 9 ms
     frame shows as 80 fps (3 refreshes), 10-12 ms as 60: that's why his numbers jump between ~60 and ~87.
   - Tools: tests/perf probe now prints SCENE ms (same window as "game"); tools note in README.
- Tests: 690 autotest checks PASS (27 Oct). `_v19w_checks` (FREE SPIN fits, trophy, loading card before the change, launch bar, panels left/right,
  BOOST ALL message + 24h, COLLECT x2). Shots v19w_01 .. 06, v19v_03/04 (panels).

### NEXT (talk to Hamza first)
- His numbers from the NEW FPS overlay (frame / game / render ms) at rest, scrolling, map, with V-Sync OFF for the
  test (Project Settings > Display > Window > V-Sync Mode = Disabled) so the real frame time shows; then the same
  with Rendering Method = gl_compatibility (often lighter for 2D, and what most Android phones will want), and an
  exported (release) build, which runs GDScript faster than the editor's debug run. If still
  choppy: try Project Settings > Rendering > Renderer > Rendering Method = gl_compatibility (often smoother for 2D
  on Windows + older phones), or rendering_device/driver.windows = vulkan instead of d3d12. Then a phone check.
- His verdict on the main-screen layout (sky strip + AD
  BOOST button) and the kit pictures.
- Parked by Hamza 27 Oct (don't raise unless he does): Mori's signature, visual list items 10/11, the premium
  managers still open (Gaffer, Simone, Tony, Sergei), premium roster size, the Valet/Desk Lv 400 cap, his
  girlfriend's next bigger playtest.

## How we work
- Hamza is the designer, Claude builds. Godot 4.7, GDScript, all UI built in code. Project on Hamza's PC:
  `H:\idledetailingtycoon\idle-car-tycoon`, reached through the linked-computer file tools (stage files into the
  cloud workspace, edit there, write back with commit). There is usually NO shell on the PC.
- Workflow: copy the project to the cloud box (scripts + assets + tools; ~700 files, 50 per stage call), get Godot
  (Godot_v4.7-stable_linux.x86_64.zip from the godotengine GitHub release), run `tools/autotest.gd` (see
  tools/README.md), look at the screenshots, then write changed files back and LIST THE FOLDER to check every size
  matches (Godot's editor has saved its old copy over a new file twice: tell Hamza to close open script tabs and
  press Reload). PNGs can arrive with a different size but the same pixels. Stage write-backs under a NEW folder in
  /mnt/user-data/outputs each time (re-sending from the same path once wrote an old copy). Don't run long Godot
  jobs inside a Monitor tool (killed at 30 min): use a background shell.
- Hamza's rules: original GTA-style car brand names only; no progress bars in gameplay (the level panel's
  next-boost bar is OK); sounds ONLY for player taps/buttons; calm screen (no "+$" spam); skill tree is one screen;
  he balances by playtesting; discuss design before building big things (mockup / prototype first); don't re-run
  the whole economy sim for small changes.
- Playtests: his girlfriend plays web builds on itch (Restricted + password) in bigger batches with 3-4 questions.
  No itch / web build work unless he asks.

## The game in brief (details: OLD PROJECT NOTES.md)
- Portrait idle tycoon (720x1280, Idle Miner style): each city is a shop with bays -> valet -> front desk; income =
  the slowest station. Levels with boost ladders (bay boosts = services, Quick Wash ... PPF, Lv 10-400), cash
  managers (abilities, tiers by age) + premium named managers (dossiers, Case Files, signatures), Book of cars +
  reputation (No reviews yet, 1.0 .. 5.0 stars), rare cars, renovations before bays 6/11/16, prestige per city
  (x3 each, 5 max), 5 countries x 5 cities (each city x10), Hometown Garage runs, skill tree, equipment, wardrobe,
  boosters (Today's deals), Lucky Wheel, Daily Delivery, Suds the cat, shop decor, day/night + rain, Car of the Week.
- Money: each country has one wallet; the city you're in pays into it, others into their stash (v0.19v).
- Boost: TOTAL = base (perm x this city's ad x2) x boosters added together.

## Files (main ones)
- `scripts/game_data.gd` all numbers. `scripts/game_state.gd` autoload GameState: the whole simulation, save/load.
- `scripts/main.gd` screen: HUD, the scrolling shop, bottom bar (+ AD BOOST), popups, toasts, tips, FPS overlay.
- Station strips: `sky_row.gd` (v0.19v), `desk_row.gd` (+ `desk_backdrop.gd`), `valet_row.gd`, `bay_card.gd`
  (+ `bay_crew.gd`, `kit_art.gd`, `car_cache.gd`), `build_row.gd`, `depth_row.gd`, `lane_overlay.gd` (the ute).
- Art in code: `car_art.gd` / `car_view.gd` (cars), `scenery.gd`, `ui_theme.gd` (look, buttons, cached boxes, rich
  text with icons), `ui_icons.gd` (bottom bar), `game_icons.gd` (icons next to text), `hud_meta.gd` (banknote,
  stars, trophy), `map_art.gd` (map shops, coins, padlock), `boost_gem.gd`.
- Characters: `detailer_*` (rig, anim, parts), `manager_*` (posh cash managers), `cashier_*`, `station_manager.gd`.
- Panels (sheets, `sheet.gd` base): level, manager, shop, book, boost, wheel, delivery, workshop (prestige),
  wardrobe, hometown, overview, info, dossier, case result, gear picker, sound board.
- `map_panel.gd` (world map: baked world + labels layer, corners), `map_side_panel.gd` (COLLECT / PRESTIGE).
- `loading_screen.gd` (the card between cities), `title_screen.gd` (launch: loading bar, then TAP TO PLAY),
  `anim_clock.gd` (30 Hz for characters), `skyline_art.gd` (the city skyline in the sky strip + loading card).
- `tools/` (ignored by Godot): autotest, econ_sim, playbot, perf, bakers, shot tools, audio_synth, char/ art sources.

## Rules of the code
- Logic lives in GameState; UI only reads it and calls its methods. UI is built in code (no big .tscn files).
- Things that redraw every frame must earn it: draw still parts once (a `_bg` child / baked texture), redraw on a
  signature change, move things with tweens / node properties instead of redrawing, skip off-screen rows.
- Debug builds: M money, G +500 Shine Bucks, V VIP, E materials, B balance overlay, F / H skip 1h / 8h, T speed x10,
  P FPS overlay; "Reset save" in the Shop.

## Decided direction
- GTA-style parody car names / look-alike designs, no real brands. Its own game, not an Idle Miner reskin: lean into
  cars, the Book, reputation, rare cars. Simple looks, deep mechanics; tapping, no swipe-to-clean.
- Launch prep later: AdMob (rewarded: ad boost, renovation skips, Collect x2), IAP (Shine Bucks packs, no-ads),
  Android export first.
