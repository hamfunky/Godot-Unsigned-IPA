# Economy sim report — v0.17d (17 Oct)

Run with `tools/sim/sim_v17d.py` (no tuning, game numbers as they are now): tuned.json plus the changes
since the v0.17 tune: Valet/Desk base 6, $15/level, +5%/level; **Detroit 200B, LA 20T** fixed prices;
cash managers' discounts modelled as an average cut on all level-ups.

The sim player is an "ideal" active player with the ad x2 (no-ads pack), who sleeps 8h a night.
Real play is slower: Hamza reached Bay 5 in 10–15 min, while the sim says ~6 min. Read the times as
**relative**, roughly x1.5–2 for a real player.

## Milestones (hours of real time)

| Scenario | Bay 5 | Reno 1 | Detroit | LA | Lima prestige | Miami | Houston | Japan (days) | Germany (days) |
|---|---|---|---|---|---|---|---|---|---|
| Old v0.17 numbers (Detroit 2.5B, LA 360B) | 0.33 | 0.5 | 0.9 | 3.5 | 4.3 | – | 48 | 3.6 | 14 |
| Now, never uses discount managers | 0.11 | 0.17 | 5.2 | 24.0 | 24.0 | 25.5 | 48 | 3.5 | 13 |
| Now, uses them a fair bit (avg 40% off) | 0.09 | 0.14 | 3.9 | 12.0 | 12.0 | 15.3 | 37 | 3.0 | 10 |
| Now, spends inside discount windows (60% off) | 0.08 | 0.12 | 3.4 | 9.7 | 9.7 | 12.2 | 30 | 2.0 | 8 |
| **LA at 5T**, never uses discounts | 0.11 | 0.17 | 5.2 | 12.5 | 12.6 | 24.0 | 48 | 3.6 | 11 |
| **LA at 5T**, uses them a fair bit | 0.09 | 0.14 | 3.9 | 9.5 | 9.6 | 14.8 | 34 | 2.5 | 10 |

## What it says
- **Detroit at 200B** lands about 3.5–5h in (was ~1h). That matches "Detroit opens when Lima's Bay 8 → 9 slows down".
- **LA at 20T** + "prestige needs LA" pushes **Lima's first prestige to 12–24h** (was ~4h). That's a long
  time before the first prestige, the game's biggest "wow". Some of that gap is a night's sleep in the sim.
- **LA at 5T** brings the prestige to ~10–13h and keeps Miami well after it.
- **Discount managers** (the 80% tiers) speed the early and mid game up by roughly 1.3–2x depending on how
  well the player uses them. Countries later on barely move (city prices and country unlocks dominate there).
- Valet/Desk are cheap now (v0.17b rebalance): they take only a few % of spending. That's fine for the early game,
  and the late Valet/Desk wall is still there (most cities can't keep up by day 60, as designed).

## Suggestion (not applied, Hamza decides)
- Keep **Detroit 200B**.
- Try **LA 5T** instead of 20T, so the first prestige comes around a session or two in, not a full day.
- Or keep LA 20T and let Lima prestige once Detroit is open (`PRESTIGE_NEEDS_CITY` 3 → 2). Then the first
  prestige lands around 4–5h again, and LA stays a bigger later goal.
