# tools/ (ignored by Godot thanks to .gdignore)

## autotest.gd — automated playtest (674 checks + screenshots, v0.19v)
How it has been run (Linux, Godot 4.7 headless binary + xvfb):
1. Copy the project to a temp folder, e.g. `p/`, and copy this file to `p/tests/autotest.gd`.
2. In `p/project.godot` add under `[autoload]`: `AutoTest="*res://tests/autotest.gd"`.
3. `SHOTS=/some/dir xvfb-run -a -s "-screen 0 720x1280x24" Godot_v4.7-stable_linux.x86_64 --path p --resolution 720x1280`
   It prints `ok` / `FAIL` lines and ends with `RESULT: PASS (0 failures)`; screenshots go to $SHOTS.
   (Vulkan/icon errors at start-up are harmless.) A quick parse check: `--headless --quit-after 60`.
Helpers inside: `own(id)` gives a premium manager, `build_all()` builds every bay finishing renovations.
v0.19t: it forces daylight, no rain and no Car of the Week (Scenery.hour_override = 13, GameState.rain_override = 0,
cotw_enabled = false) so payouts and screenshots stay exact; _v19t_checks turns each one on to test it.

## playbot.gd — fresh-player pass (v0.19j)
Plays a brand-new save like a first-time player (tips + OK popups ON): tutorial, taps manual stations, hires,
builds, levels the bottleneck, uses abilities, opens each screen once. Runs SPEED x (default 6) with the
real-clock timers shifted to match. Screenshots every tip / big message / toast / new screen once + the shop
every 5 min; prints a timeline + milestones. Set up like the autotest, but autoload it AS `AutoTest`
(`AutoTest="*res://tests/playbot.gd"`, so the title screen is skipped):
`PLAYMIN=60 SPEED=6 SHOTS=/dir xvfb-run -a -s "-screen 0 720x1280x24" godot --path p --resolution 720x1280`
(~25 min real time for 60 game min on the cloud box). Note: it plays faster than a person (taps every 0.5 s).
v0.19k: it SAVES for the next bay / renovation once that's within ~3 min of income (the old bot kept 30% of
next_bay_cost(), which is -1 while a renovation is needed, so it never saved for one), taps the lock when a
renovation is done, and uses the renovation SKIP only after it has read the renovation tip (like a new player).

## econ_sim.gd — whole-game economy sim on the REAL game code (v0.19s)
Plays every country on GameState's own prices/rates/timers in a few minutes (no UI, no rendering):
GameState.sim_mode = true stops _process and saving, the sim drives `now` itself. Players (PLAYER env):
decent = 4 sessions a day (~80 min), keen = 6 (~2h50), casual = 2 (~30 min); offline earnings in between with
the real cap, collected x2. Not modelled: abilities, premium managers, skills, Hometown, gear (they'd make it faster).
Set up like the autotest but headless (no xvfb) and autoload it AS `AutoTest`:
`PLAYER=decent DAYS=60 SEED=1 godot --headless --path p` -> a timeline + every city's end state.
~2-10 min real per 45-60 days (gets slower with more cities). Each run differs a little: run 2-3 seeds.
Env extras: `CAL=1` (idle formula vs the live per-frame stations), `DAILY=1`, `PROG=n`, `WATCH=<city id>`.
Don't run more than 4 at once on the cloud box (memory; it only has 2 cores, so 2 at a time is quickest).
v0.19t: the player also opens the Daily Delivery and pets the cat each session, and buys Night Shift with Shine
Bucks. To try other numbers without touching the project, copy the run folder, patch scripts/game_data.gd there
and run it (how the v0.19t prices were picked: prestige x3 / x5 / x8 / x10, country prices x1e6 vs ~1.5 days of
the previous country's ceiling).

## sim/ — economy simulations (Python 3, v0.17: OUT OF DATE, use econ_sim.gd)
- `world2.py` — whole-world sim v3 (5 countries x 5 cities, prestige needing the 3rd city, renovations with
  skips, renovation tiers, valet/desk kept 1.1x ahead, players save for builds/cities/prestige, sleep 8h/night
  with the offline cap, ad x2 always on = no-ads pack player). Knobs in `P`.
  `python3 world2.py 10` prints a timeline (loads tuned.json); `python3 world2.py 10 noads` = never watches ads.
- `tune_world.py` — searches each knob near its current value to hit the targets (list at the top), several
  passes. `python3 tune_world.py 2 resume` continues from tuned.json, `python3 tune_world.py report` prints the
  milestones, valet/desk spending shares and the renovation-tier take-over for tuned.json.
- `tuned.json` — v0.17 result, APPLIED to game_data.gd (build costs, valet/desk, city unlock base + growth,
  prestige costs, country costs, renovation tiers).
- `home.py` — Hometown run sim (x2.5 growth per bay, tiers, valet/desk to Lv 10 x run bays, renovations).
  `python3 home.py tune` fits the Hometown knobs; `home_tuned.json` = v0.17 result (applied).
The sim mirrors game formulas by hand: if you change formulas in game_state.gd, update the sim too.

## car_sheet.gd — every car on one PNG
`godot --path <project> --script res://tools/car_sheet.gd -- <out.png> [dirt 0-1]` (needs a display / xvfb).

## sim/sim_v17d.py — pacing check with today's numbers (no tuning)
Prints the milestone report for 3 discount-use scenarios. Results: sim/REPORT_v17d.md.

## sim/sim_v17g.py — early-game pacing after the 17 Oct playtest
`python3 sim/sim_v17g.py` (v0.17g numbers) / `python3 sim/sim_v17g.py old`. Results: sim/REPORT_v17g.md.

## audio_synth.py — temporary music + "pop" sounds made in code (v0.17g)
`python3 tools/audio_synth.py music|sfx|all` (numpy + ffmpeg with libvorbis). Writes assets/game/music/*.ogg
(3 chill loops) and assets/game/sfx/pop_*.ogg. Copyright-free placeholders: swap in real tracks any time
(the game plays every .ogg in assets/game/music). Open Godot afterwards so it imports new files.

## v0.19v dev tools (all autoloaded AS AutoTest like the autotest, copied to <p>/tests/)
- `perf.gd` — frame-cost probe (v0.19w: prints SCENE ms = scripts + layout + drawing per frame, draw calls,
  primitives): builds a 10-bay shop and measures the shop at rest / scrolling and the map at
  rest / dragging. `PERF_GROUPS=0` skips the per-script breakdown, `PERF_HIDE=1` hides each part of the screen in
  turn, `PERF_FRAMES=n`. NOTE: on the cloud box (no GPU, software GL) the numbers are noisy and slow; compare
  before/after runs only, and trust the in-game FPS overlay (key P / Shop > FPS) on a real PC / phone.
- `bake_icons.gd` — bakes scripts/game_icons.gd (Shine Bucks banknote, wheel, booster gem, wardrobe tee, v0.19w: the ad screen) to
  assets/game/ui/icon_*.png (used for "30 {sb}" style prices via UiTheme.set_rich / rich_label / bb).
- `bake_kit.gd` — bakes scripts/kit_art.gd (the detailed service kit on each bay's back wall, one per service) to
  assets/game/sprites/kit/kit_<tier>.png; `SHEET=/dir/kit_sheet.png` also writes a review sheet (big + bay size).
  After baking new PNGs, open the editor once so Godot imports them (their .import files have mipmaps on).
- `bay_shots.gd` — screenshots of 11 bays, one per service tier (SHOTS=/dir).
- `skyline_shots.gd` — v0.19w: the skyline mockup sheets (scripts/skyline_art.gd): now vs new, then every country +
  the Hometown by day / dusk / night (OUT=/dir). Autoload AS AutoTest, run with a display.
- `proto_shots.gd` — main-screen screenshots at night / day / with the ad boost running (SHOTS=/dir).
