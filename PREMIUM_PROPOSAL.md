# Premium managers overhaul — agreed design (17 Oct, Hamza + Claude)

Goal: every premium manager has a **signature move** you'd never get from a cash hire, with a clear moment
to use it. Not every one has to be revolutionary, but each needs a genuine purpose and must not be OP.
Numbers are starting points; Hamza balances by playtest. Build after his next playtest + balance chat.

Rules for all of them:
- One tap on the ability icon above their head. Their level (Certs) scales the move (Lv1 → Lv50).
- Their passive stays (+income at the station while they work). Lv20 / Lv50 promotions give perks.
- Each shows a small moment on screen (jar, convoy, sparkle). Sounds only on the tap + its payoff.
- Discounts from any source MULTIPLY (they never add), with a 95% safety ceiling. So Priya 70% + an 80% cash
  manager = 94% off. Stacking is intended: it's the lifeline when you can barely afford one upgrade.

| Tier | Manager | Station | Signature | Cooldown |
|---|---|---|---|---|
| Common | **Dazza** ✅ built | Bay | **Tip Jar** | 30 min |
| Common | **Kev** | Valet | **Shortcut** | 30 min |
| Uncommon | **Priya** | Desk | **Finish Line** | 45 min |
| Uncommon | **Marco** | Valet | **Convoy** | 40 min |
| Rare | **Two-Bucket Tony** | Bay | **Bucket Brigade** | 40 min |
| Epic | **Sergei Claybar** | Bay | **Showroom Finish** | 45 min |
| Legendary | **The Gaffer** | Bay | **Overtime** | 30 min |
| Legendary | **Simone Laurent** | Valet | **Red Carpet** | 3h → 2h (Lv20) → 1.5h (Lv50) |

### Dazza — Tip Jar (Common, bay) ✅ in the game
30s: every car his bay finishes goes into the glass tip jar beside him instead of the key cabinet. When time's
up he cashes it **x3 (Lv1) → x5 (Lv50)** straight into your wallet (skips the valet and desk). First premium
manager (Hometown run 1, renovation 1). Teaches "fire your ability at the right moment".

### Kev — Shortcut (Common, valet)
30s → 60s: every car finished in this city skips the cabinets and the valet and lands straight in the pickup
lot (Hamza's "teleported to the top" idea). Use when the valet has the red "!".

### Priya — Finish Line (Uncommon, desk)
60s: in this city, **the last 10 levels before each station's next boost cost 50% less** (Lv50: last 20 levels,
70% off; grows smoothly with her level). Same discount for every level in that window (simple to read). Can't
be gamed by saving up on a fresh bay: it only ever touches the stretch right before a boost. Use it to push a
station over a boost when every bit counts. Stacks (multiplies) with discount managers.

### Marco — Convoy (Uncommon, valet)
His next 3 trips (Lv50: 5) carry **x10**, with two extra utes following the main one. Use when the cabinets are
overflowing (the late-game valet wall).

### Two-Bucket Tony — Bucket Brigade (Rare, bay)
90s: **his own bay stops** and his crew helps every other bay in the city: **all other bays work x2 faster**.
Stacks with those bays' own managers (e.g. Tony x2 + a x3 manager = x6). The chain keeps it honest: if the
valet/desk can't keep up, the extra cars just pile up. Put him on a weak bay; use him to lift the whole city.

### Sergei Claybar — Showroom Finish (Epic, bay)
~200s: **the car in his bay when you tap is a Showroom Finish right away** (x10, sparkle + "SHOWROOM!"), then
**every 5th car** his bay finishes is one too. No randomness. Tied to cars, not seconds, so a faster bay gets more.
Rare-car use: tap him while a rare car is in his bay and that car pays x10. That multiplier is its own number
(`SHOWROOM_VIP_MULT`, starts at x10) so it can be tuned after playtesting if it's too strong.

### The Gaffer — Overtime (Legendary, bay)
60s: **every 5 seconds he pays 6 minutes (Lv1) → 10 minutes (Lv50) of his bay's CURRENT income** straight into
your wallet (12 payouts = 72 → 120 min of that bay's income per use, every 30 min: about +240% → +400% on that
bay). Skips the valet and desk, and it **ramps**: upgrading his bay during the minute makes every later payout
bigger. Play: put him on your best bay, spam that bay's upgrades during his minute, then save to catch the valet
and desk back up. (Different from the ad reward, which is city-wide and instant.) Passive kept: **Autopilot**
(managers in his city use their abilities by themselves). Compare: a cash Executive income manager (5% hire roll)
averages about +133% and is often capped by the valet/desk.

### Simone Laurent — Red Carpet (Legendary, valet)
A rare car rolls up right now, over a red carpet. **Never a Legendary rare car** (those only arrive naturally,
so the top of the Book stays a long-term goal). Epic chance **10% (Lv1) → 40% (Lv50)**, which is what players
chase. Cooldown is a passive drop through promotions: **3h → 2h at Lv20 → 1.5h at Lv50**. One car per call
(only one rare car can be in the shop at a time). Passive kept: rare cars twice as often and pay x2.

## The other 17 premium managers
Option 1 (recommended): trim the roster to these 8 (+ Mirror Mori's legendary passive as a 9th if wanted).
Fewer, more special managers like Idle Miner's super managers; tune Case File clue odds down to match.
Option 2: keep all 25; the other 17 keep plain abilities with better numbers than cash managers.
Hamza to decide.

## Build order (after the playtest)
Kev + Priya → Sergei, Tony, Marco → Gaffer + Simone. Roughly an hour each including the on-screen moments + tests.
