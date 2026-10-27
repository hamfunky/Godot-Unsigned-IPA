"""Whole-economy sim v3 (v0.17 rules). Good active player with the no-ads pack.

Mirrors the game's formulas by hand (game_data.gd / game_state.gd). If you change a
formula in the game, change it here too.

v0.17 rules modelled:
  - renovation tiers: bays after each renovation (6-10, 11-15, 16-20) earn ti x more per
    tier, their levels cost tc x more per tier
  - valet + front desk: own base capacity / level cost knobs; the player keeps them
    slightly ahead of the bays (margin x bay output, never behind)
  - prestige needs the 3rd city of that country unlocked (need_city)
  - renovation skips: -30 min, 2 per hour (no-ads pack): 1h off at the start, then the
    timer runs skip_rate x faster while awake (a check-in every ~2h uses both skips)

Player model: 16h awake (spends greedily on the best payback item; saves for the next
bay / renovation / city / country / prestige when it's close: within 10% of the time
played so far, at most save_h hours of income), 8h asleep (earns up
to the offline cap). Ad x2 always on (boost=2) = no-ads pack player.

python3 world2.py 10        timeline for 10 days
python3 world2.py 10 noads  same for a player who never watches ads (no x2, no skips)
"""
import math, sys

MS = [(10, 2), (25, 2), (50, 3), (100, 3), (150, 2), (200, 3), (250, 2), (300, 3), (350, 2), (400, 5)]
BM = [1.0] * 402
for _L in range(402):
    _m = 1.0
    for _lv, _x in MS:
        if _L >= _lv:
            _m *= _x
    BM[_L] = _m
NEXT_BOOST = [next((lv for lv, _ in MS if lv > L), 400) for L in range(402)]

P = dict(
    build=[0.0, 250.0, 15000.0, 350000.0, 8.5e6, 1.5e9, 1.0e11, 2.0e12, 3.0e13, 6.0e14,
           1.5e16, 4.0e17, 1.0e19, 3.0e20, 8.0e21, 2.5e23, 7.0e24, 2.0e26, 6.0e27, 2.0e29],
    unlock_base=1.0e6, unlock_growth=1.0, scale=10.0,
    p0=5e8, pg=100.0, pmult=4.0, need_city=3,
    country=[0, 1e14, 1e19, 1e24, 1e29], reno_hours=[1.0, 8.0, 48.0], reno_cost=3.0,
    skips=True, skip_rate=1.5,
    boost=2.0, rep_per_day=0.0, maxL=400, share=0.3, sleep=True, save_h=0.5,
    # renovation tiers
    ti=1.0, tc=1.0,
    # valet + desk: base capacity, capacity growth/level, level cost base, cost growth/level
    vcap=12.0, vg=1.075, vcost=15.0, vcg=1.11,
    dcap=5.0, dg=1.075, dcost=15.0, dcg=1.11,
    margin=1.1,
)
NC = 5
NCITY = 5
RENO_AT = [6, 11, 16]
TIER = [sum(1 for b in RENO_AT if i + 1 >= b) for i in range(20)]


UNIT = [1.0] * 20
COST0 = [1.0] * 20
G24 = (1.1 ** 24 - 1) / 0.1          # sum of 1.1^(L-1) for L = 1..24
POW11 = [1.1 ** k for k in range(402)]


def _prep():
    """per-run tables (P may change between runs)"""
    for i in range(20):
        UNIT[i] = 8.0 ** i * P['ti'] ** TIER[i]
        COST0[i] = 12.0 * 12.0 ** i * P['tc'] ** TIER[i]


def bay_unit(i):
    """income/s per (level x boost) of bay i (before city mult)"""
    return UNIT[i]


def bay_ips(i, L):
    return UNIT[i] * L * BM[L]


def bay_cost0(i):
    """level 1->2 cost of bay i (before city scale)"""
    return COST0[i]


def trip(L, B):
    return (2 * B * 1.2 + B * 0.25 + 0.5) / (1 + 0.02 * (L - 1))


def vrate(L, B):
    return P['vcap'] * L * P['vg'] ** (L - 1) * BM[L] / trip(L, B)


def drate(L):
    return P['dcap'] * L * P['dg'] ** (L - 1) * BM[L] / 3.0


class City:
    __slots__ = ('co', 'pos', 'idx', 'p', 'bays', 'v', 'd', 'renos', 'reno_left', 'spend', 'built_at', 'takeover', 'deal_at_build')

    def __init__(s, co, pos, p=0):
        s.co = co; s.pos = pos; s.idx = co * NCITY + pos; s.p = p
        s.bays = [1]; s.v = 1; s.d = 1; s.renos = 0; s.reno_left = None
        s.spend = {'b': 0.0, 'n': 0.0, 'r': 0.0, 'v': 0.0, 'd': 0.0}
        s.built_at = {}; s.takeover = {}; s.deal_at_build = {}


def S(c):
    return P['scale'] ** c.idx


def mult(c, t):
    return S(c) * P['pmult'] ** c.p * P['boost'] * (1.2 ** min(7, P['rep_per_day'] * t / 86400))


def bays_out(c):
    return sum(bay_ips(i, L) for i, L in enumerate(c.bays))


def income(c, t):
    m = mult(c, t)
    B = len(c.bays)
    return min(bays_out(c), vrate(c.v, B), drate(c.d)) * m


def reno_needed(c):
    n = len(c.bays) + 1
    if n > 20:
        return 0
    for k, b in enumerate(RENO_AT):
        if n == b and c.renos < k + 1:
            return k + 1
    return 0


def unlock_cost(co, pos):
    return P['unlock_base'] * P['scale'] ** (co * NCITY + pos) * P['unlock_growth'] ** pos


def prestige_cost(c):
    return P['p0'] * P['pg'] ** c.p * S(c)


def level_deal(i, L):
    """cost per extra income/s of one more level on bay i at level L (boost jumps left out)"""
    return bay_cost0(i) * 1.1 ** (L - 1) / (bay_unit(i) * BM[L])


def best_action(c, t):
    """cheapest-per-gain purchase in this city: (cost, action, score) or None.
    Valet/desk are levelled whenever they fall below margin x bay output."""
    B = len(c.bays)
    s = S(c)
    bs = bays_out(c)
    if vrate(c.v, B) < P['margin'] * bs and c.v < P['maxL']:
        return (P['vcost'] * s * P['vcg'] ** (c.v - 1), ('v',), None)
    if drate(c.d) < P['margin'] * bs and c.d < P['maxL']:
        return (P['dcost'] * s * P['dcg'] ** (c.d - 1), ('d',), None)
    best = None
    maxL = P['maxL']
    bsc = 1e300
    bi = -1
    for i, L in enumerate(c.bays):
        if L >= maxL:
            continue
        sc = COST0[i] * POW11[L - 1] / (UNIT[i] * ((L + 1) * BM[L + 1] - L * BM[L]))
        if sc < bsc:
            bsc = sc
            bi = i
    if bi >= 0:
        best = (bsc, COST0[bi] * s * POW11[c.bays[bi] - 1], ('b', bi))
    if best is None:
        return None
    return (best[1], best[2], best[0])


def goal(c):
    """the city's next build or renovation: (cost, action) or None. Players treat these as
    goals: bought as soon as affordable, saved for when close."""
    B = len(c.bays)
    if B >= 20:
        return None
    rn = reno_needed(c)
    if rn == 0:
        return (P['build'][B] * S(c), ('n',))
    if c.reno_left is None:
        return (P['reno_cost'] * P['build'][B] * S(c), ('r', rn))
    return None


def _note_tiers(c, t):
    """renovation-tier bays: record the level at which they first out-earn every older bay"""
    for n in (5, 10, 15):
        if n < len(c.bays) and n not in c.takeover:
            mine = bay_ips(n, c.bays[n])
            if all(mine >= bay_ips(j, c.bays[j]) for j in range(n)):
                c.takeover[n] = (c.bays[n], t - c.built_at.get(n, t))


CSPEND = [dict(b=0.0, n=0.0, r=0.0, v=0.0, d=0.0) for _ in range(NC)]   # spending per country (this run)


def _do(c, k, act, cost, t, note):
    """apply a purchase to city c"""
    c.spend[act[0]] += cost
    CSPEND[c.co][act[0]] += cost
    if act[0] == 'v':
        c.v += 1
    elif act[0] == 'd':
        c.d += 1
    elif act[0] == 'b':
        c.bays[act[1]] += 1
    elif act[0] == 'n':
        n = len(c.bays)
        if n in (5, 10, 15):
            others = min(level_deal(j, L) for j, L in enumerate(c.bays))
            c.deal_at_build[n] = level_deal(n, 1) / others
        c.bays.append(1)
        c.built_at[n] = t
        note(('bay', k, c.p, len(c.bays)), f"bay {k} p{c.p} -> {len(c.bays)}")
    elif act[0] == 'r':
        c.reno_left = P['reno_hours'][act[1] - 1] * 3600 - (1800.0 * 2 if P['skips'] else 0.0)
        if c.reno_left <= 0:
            c.reno_left = None
            c.renos += 1
        note(('reno', k, c.p, act[1]), f"reno {k} p{c.p} #{act[1]}")


def run(days=60, verbose=True, targets=None, track=None):
    """track: dict filled with per-city details (spend shares, tier takeovers)"""
    _prep()
    for d in CSPEND:
        for x in d:
            d[x] = 0.0
    t = 0.0
    cities = {(0, 0): City(0, 0)}
    wallets = [0.0] * NC
    nco = 1
    log = {}
    order = []
    hist = []   # Lima p0 snapshots for spend-share windows

    def note(key, txt):
        if key not in log:
            log[key] = t
            order.append((t, txt))

    while t < days * 86400:
        dt = min(3600.0, max(10.0, t * 0.002))
        day_t = t % 86400
        asleep = P['sleep'] and day_t >= 16 * 3600
        for c in cities.values():
            if c.reno_left is not None:
                rate = 1.0 if (asleep or not P['skips']) else P['skip_rate']
                c.reno_left -= dt * rate
                if c.reno_left <= 0:
                    c.reno_left = None
                    c.renos += 1
        incs = {k: income(c, t) for k, c in cities.items()}
        if asleep:
            cap = (4.0 if t < 86400 * 3 else 8.0) * 3600
            slept = day_t - 16 * 3600
            f = 1.0 if slept < cap else 0.0
            for k in cities:
                wallets[k[0]] += incs[k] * dt * f
            t += dt
            continue
        for k in cities:
            wallets[k[0]] += incs[k] * dt
        for co in range(nco):
            own = [k for k in cities if k[0] == co]
            inc_co = sum(incs.get(k, 0) for k in own) or 1e-9
            saving = False
            # saves up for a goal when it's close: within 10% of the time played so far (max save_h)
            horizon = min(max(60.0, 0.1 * t), P['save_h'] * 3600)
            # next city in this country
            if len(own) < NCITY:
                pos = len(own)
                cost = unlock_cost(co, pos)
                if wallets[co] >= cost:
                    wallets[co] -= cost
                    cities[(co, pos)] = City(co, pos)
                    note(('city', co, pos), f"unlock city {co}-{pos}")
                    own.append((co, pos))
                elif cost <= wallets[co] + inc_co * horizon:
                    saving = True
            # next country
            if co == nco - 1 and len(own) == NCITY and nco < NC:
                cost = P['country'][nco]
                if wallets[co] >= cost:
                    wallets[co] -= cost
                    cities[(nco, 0)] = City(nco, 0)
                    note(('country', nco), f"COUNTRY {nco}")
                    nco += 1
                elif cost <= wallets[co] + inc_co * horizon:
                    saving = True
            # prestige a developed city (past its 1st renovation) that isn't the main earner
            # (needs the 3rd city of the country unlocked)
            if len(own) >= P['need_city']:
                tot = sum(incs.get(k, 0) for k in own) or 1.0
                for k in sorted(own, key=lambda kk: cities[kk].idx):
                    c = cities[k]
                    if c.p >= 5 or len(c.bays) < 6 or incs.get(k, 0) / tot >= P['share']:
                        continue
                    pc = prestige_cost(c)
                    if wallets[co] >= pc:
                        wallets[co] -= pc
                        if track is not None:
                            track.setdefault('done', []).append(c)
                        cities[k] = City(co, k[1], c.p + 1)
                        incs[k] = 0.0
                        note(('prestige', k, c.p + 1), f"prestige {k} -> {c.p + 1}")
                        if c.p + 1 == 5:
                            note(('5star',), "first 5-star city")
                    elif pc <= wallets[co] + inc_co * horizon:
                        saving = True
                    break
            # next bay / renovation in each city: bought as soon as affordable
            for k in sorted(own, key=lambda kk: cities[kk].idx):
                c = cities[k]
                g = goal(c)
                while g is not None and wallets[co] >= g[0]:
                    cost, act = g
                    wallets[co] -= cost
                    _do(c, k, act, cost, t, note)
                    incs[k] = income(c, t)
                    g = goal(c)
                if g is not None and g[0] <= wallets[co] + inc_co * horizon:
                    saving = True
            if saving:
                continue
            # greedy spending: best payback across the country's cities, buy repeatedly
            for _ in range(80):
                best = None
                for k in own:
                    c = cities[k]
                    a = best_action(c, t)
                    if a is None:
                        continue
                    cost, act, sc = a
                    gain = (incs.get(k, 0) * 0.1 + 1e-9) if sc is None else cost / sc * mult(c, t)
                    pb = cost / gain
                    if sc is None:
                        pb = -1.0   # keeping valet/desk ahead comes first
                    if best is None or pb < best[0]:
                        best = (pb, cost, k, act)
                if best is None or wallets[co] < best[1]:
                    break
                _, cost, k, act = best
                c = cities[k]
                wallets[co] -= cost
                _do(c, k, act, cost, t, note)
                incs[k] = income(c, t)
            for k in own:
                _note_tiers(cities[k], t)
        if track is not None:
            if (0, 0) in cities and cities[(0, 0)].p == 0:
                hist.append((t, dict(cities[(0, 0)].spend)))
            track.setdefault('usa', []).append((t, dict(CSPEND[0])))
            allh = track.setdefault('hist', {})
            for k, c in cities.items():
                allh.setdefault((k, c.p), []).append((t, dict(c.spend)))
        t += dt
        if targets and all(tk in log for tk in targets):
            break
    if track is not None:
        track['cities'] = cities
        track['lima_hist'] = hist
    if verbose:
        for tt, txt in order:
            if txt.startswith('bay') and not ('(0, 0) p0' in txt):
                continue
            if txt.startswith('reno') and not ('(0, 0)' in txt):
                continue
            print(f"{tt / 3600:9.2f}h {tt / 86400:7.2f}d  {txt}")
    return log


def spend_share(hist, t0, t1, levels_only=False):
    """valet+desk share of all spending (bay builds, renovations, all levels) between t0
    and t1 seconds; levels_only=True leaves builds and renovations out"""
    a = None
    b = None
    for t, sp in hist:
        if a is None and t >= t0:
            a = sp
        if t <= t1:
            b = sp
    if a is None or b is None:
        return float('nan')
    d = {k: b[k] - a.get(k, 0.0) for k in b}
    tot = ((d['v'] + d['d'] + d['b']) if levels_only else sum(d.values())) or 1e-9
    return (d['v'] + d['d']) / tot


if __name__ == '__main__':
    import json, os
    here = os.path.dirname(os.path.abspath(__file__))
    tj = os.path.join(here, 'tuned.json')
    if os.path.exists(tj):
        P.update(json.load(open(tj))['P'])
    if 'noads' in sys.argv:
        P['boost'] = 1.0
        P['skips'] = False
    run(float(sys.argv[1]) if len(sys.argv) > 1 else 10)
