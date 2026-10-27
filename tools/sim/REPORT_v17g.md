# Early-game pacing — v0.17g (17 Oct, after Hamza's playtest)

Problem (Hamza, no boosts): ~20 min in he had 6 bays and ~9M/s, and Bay 7 cost 3.79B (200x Bay 6). A new
Bay 7 then did almost nothing (its levels cost x352 more), and Detroit (200B) / prestige (needed LA) were hours
away, so there was nothing to aim for.

Run: `python3 tools/sim/sim_v17g.py` (v0.17g numbers) or `python3 tools/sim/sim_v17g.py old`.
Player: no ads (boost x1), uses the free renovation skips, discount managers a little (levels x0.8).
Sim times are an "ideal" player: real play is roughly x1.3-1.5.

| | Bay 7 | Bay 8 | Detroit | Lima 1st prestige | LA | Miami | Japan | Germany | Australia |
|---|---|---|---|---|---|---|---|---|---|
| v0.17f | 80 min | 7 h | 9.7 h | 35 h | 35 h | 48 h | 5 d | 23 d | 48 d |
| **v0.17g** | **23 min** | **62 min** | **50 min** | **67 min** | **3.5 h** | **5.3 h** | 2 d | 15 d | 35 d |

Changes (game_data.gd):
- `RENO_TIER_COST` 352.5 -> 120: a new bay after a renovation out-earns the older ones straight away and
  levelling it is the best deal (it used to be ~37x worse).
- `BAY_BUILD_COSTS` Bays 7-10: 3.79B / 75.9B / 1.14T / 22.8T -> 300M / 4B / 60B / 1.2T. (Bay 11 is still
  1.7 quadrillion behind renovation 2 (8h): a deliberate big gate, look at it later.)
- `CITY_UNLOCK_OVERRIDE`: Detroit 200B -> 4B, LA 20T -> 5T.
- Prestige: no "3rd city" rule (`PRESTIGE_NEEDS_CITY` 0). A city's 1st prestige costs the same as the next
  city in its country (Lima = Detroit = 4B), so the player picks: expand or prestige. Prestige 2+ keep the
  old `PRESTIGE_COSTS` (Hamza: re-balance later).

Side effect: everything after the USA comes sooner (Japan day 2 instead of 5). Fine for the USA-only
playtest; re-tune the later countries when they come back.

Event density (bays, renovations, cities, prestiges): hour 0-1 15 events (longest wait 27 min), hour 1-2 12
(11 min), hour 2-4 21 (49 min), hour 4-6 12 (37 min).

Not modelled: the v0.17g valet change (stepped driving + capacity compensation). It moves the same money
or up to ~15% more (more with few bays), so the sim slightly undersells the valet. Fine.
