"""Hometown Garage run pacing sim (v0.17 rules).

A run = build every bay, every bay to Lv 50, valet + desk to Lv 10 x run bays.
Each deeper bay earns and costs x2.5 (HOMETOWN_GROWTH). Renovation tiers: bays after each
of the run's 3 renovation points earn ti x more and their levels cost tc x more per tier.
Valet + desk use the same formulas as cities (constants read from tuned.json), kept 1.1x
ahead of the bays. Renovations (2h / 5h / 10h at 20 bays, scaled by run bays / 20) run while
you keep levelling; skips: 1h off at the start, then 1.5x speed. Income x4 (ad x2 + skills).

  python3 home.py          run times with home_tuned.json (the values in the game)
  python3 home.py tune     tunes vd_mult (valet+desk ~1/3 of spending), vd_growth (run 1 : run 4
                           length)
                           and cost_mult (20-bay run length) for the tier jumps ti / tc below.
                           ti 2.4 = a tier bay out-earns the (Lv 50) older bays at ~Lv 25.
"""
import math, sys, json, os

BAY_MS = [(10, 2), (25, 2), (50, 3), (100, 3), (150, 2), (200, 3), (250, 2), (300, 3), (350, 2), (400, 5)]
BM = [1.0] * 402
for _L in range(402):
    _m = 1.0
    for _lv, _x in BAY_MS:
        if _L >= _lv:
            _m *= _x
    BM[_L] = _m

P = dict(G=2.5, build0=40.0, lvl0=12.0, cost_mult=150.0, vd_mult=1.0, vd_growth=1.11, mult=4.0, bay_target=50,
         ti=2.4, tc=3.6, reno_hours=[2.0, 5.0, 10.0], skip_rate=1.5, margin=1.1,
         vcap=12.0, vg=1.075, vcost=15.0, vcg=1.11, dcap=5.0, dg=1.075, dcost=15.0, dcg=1.11)
HERE = os.path.dirname(os.path.abspath(__file__))


def load_city_values():
    tj = os.path.join(HERE, 'tuned.json')
    if os.path.exists(tj):
        d = json.load(open(tj))['P']
        for k in ('vcap', 'vg', 'vcost', 'vcg', 'dcap', 'dg', 'dcost', 'dcg', 'margin'):
            if k in d:
                P[k] = d[k]


def reno_bays(cap):
    return [int(math.ceil(cap * k / 4.0)) + 1 for k in range(1, 4)]


def run(cap, verbose=False):
    rb = reno_bays(cap)
    tier = [sum(1 for b in rb if i + 1 >= b) for i in range(cap)]
    unit = [P['G'] ** i * P['ti'] ** tier[i] for i in range(cap)]
    cost0 = [P['lvl0'] * P['cost_mult'] * P['G'] ** i * P['tc'] ** tier[i] for i in range(cap)]
    M = P['mult']
    T = P['bay_target']
    VD = 10 * cap
    bays = [1]; vl = 1; dl = 1; cash = 0.0; t = 0.0
    renos = 0; reno_left = None
    log = {}
    takeover = {}
    spend = {'b': 0.0, 'v': 0.0, 'd': 0.0, 'n': 0.0, 'r': 0.0}
    maxed = {}

    def ips(i, L):
        return unit[i] * L * BM[L]

    def vrate(L, B):
        return P['vcap'] * L * P['vg'] ** (L - 1) * BM[L] / ((2 * B * 1.2 + B * 0.25 + 0.5) / (1 + 0.02 * (L - 1)))

    def drate(L):
        return P['dcap'] * L * P['dg'] ** (L - 1) * BM[L] / 3.0

    while True:
        B = len(bays)
        bs = sum(ips(i, L) for i, L in enumerate(bays))
        inc = min(bs, vrate(vl, B), drate(dl)) * M
        if B == cap and all(L >= T for L in bays) and vl >= VD and dl >= VD:
            break
        if t > 86400 * 30:
            return None
        # renovation finishes on its own
        if reno_left is not None and reno_left <= 0:
            reno_left = None
            renos += 1
        # what to buy next
        need = 0
        if B < cap:
            for k, b in enumerate(rb):
                if B + 1 == b and renos < k + 1:
                    need = k + 1
        act = None
        if (vrate(vl, B) < P['margin'] * bs and vl < VD) or (B == cap and all(L >= T for L in bays) and vl < VD):
            c = P['vcost'] * P['vd_mult'] * P['vd_growth'] ** (vl - 1); act = 'v'
        elif (drate(dl) < P['margin'] * bs and dl < VD) or (B == cap and all(L >= T for L in bays) and dl < VD):
            c = P['dcost'] * P['vd_mult'] * P['vd_growth'] ** (dl - 1); act = 'd'
        elif B < cap and need == 0:
            c = P['build0'] * P['cost_mult'] * P['G'] ** B; act = 'n'
        elif need and reno_left is None:
            c = 3.0 * P['build0'] * P['cost_mult'] * P['G'] ** B; act = 'r'
        else:
            best = None
            for i, L in enumerate(bays):
                if L >= T:
                    continue
                cc = cost0[i] * 1.1 ** (L - 1)
                sc = cc / (ips(i, L + 1) - ips(i, L))
                if best is None or sc < best[0]:
                    best = (sc, cc, i)
            if best is None:
                # waiting on a renovation with everything maxed
                dt = max(reno_left or 1.0, 1.0) / P['skip_rate']
                t += dt
                cash += inc * dt
                reno_left = (reno_left or 0) - dt * P['skip_rate']
                continue
            c = best[1]; act = ('b', best[2])
        if cash < c:
            dt = (c - cash) / max(inc, 1e-9)
            if reno_left is not None:
                dt = min(dt, max(reno_left / P['skip_rate'], 1.0))
            t += dt
            cash += inc * dt
            if reno_left is not None:
                reno_left -= dt * P['skip_rate']
            if cash < c:
                continue
        cash -= c
        spend[act if isinstance(act, str) else 'b'] += c
        if act == 'v':
            vl += 1
        elif act == 'd':
            dl += 1
        elif act == 'n':
            bays.append(1)
            log[len(bays)] = t
        elif act == 'r':
            h = P['reno_hours'][need - 1] * cap / 20.0 * 3600
            reno_left = h - 3600.0
        else:
            bays[act[1]] += 1
            if bays[act[1]] >= T:
                maxed[act[1] + 1] = t
        for n in range(len(bays)):
            if tier[n] > 0 and n not in takeover and n - 1 >= 0 and tier[n] > tier[n - 1]:
                if all(ips(n, bays[n]) >= ips(j, bays[j]) for j in range(n)) and bays[n] > 1:
                    takeover[n] = bays[n]
    lv = spend['b'] + spend['v'] + spend['d']
    share = (spend['v'] + spend['d']) / lv if lv > 0 else 0.0
    if verbose:
        print(f"run {cap:2d} bays: done {t / 3600:5.1f}h  valet+desk {share:.0%} of level spending  bays built at (h):",
              {k: round(v / 3600, 1) for k, v in log.items()}, "\n      each bay at Lv50 (h):", {k: round(v / 3600, 1) for k, v in sorted(maxed.items())},
              "  tier bays out-earn older ones at Lv:", {k + 1: v for k, v in takeover.items()})
    return t, takeover, share


TARGETS = {5: 6.0, 10: 10.0, 15: 14.0, 20: 18.5}


def tune(passes=2):
    """Tunes, for the given ti / tc (tier income + cost jump):
       vd_mult   valet + desk level prices x this in Hometown -> ~1/3 of level spending (20-bay run)
       vd_growth valet + desk level price growth in Hometown -> run 1 (5 bays) vs run 4 (20 bays)
                 length ratio (6h : 18.5h); their Lv 10 x run-bays targets set the long runs
       cost_mult all Hometown bay costs -> the 20-bay run takes TARGETS[20] hours"""
    def bisect(key, lo, hi, f, target, iters=14, log=True):
        lo, hi = (math.log10(lo), math.log10(hi)) if log else (lo, hi)
        for _ in range(iters):
            mid = (lo + hi) / 2
            P[key] = 10 ** mid if log else mid
            if f() < target:
                lo = mid
            else:
                hi = mid
        P[key] = 10 ** ((lo + hi) / 2) if log else (lo + hi) / 2
        return P[key]

    def hours(cap):
        r = run(cap)
        return r[0] / 3600 if r else 1e9

    def fit_cost():
        bisect("cost_mult", 1e-4, 1e7, lambda: hours(20), TARGETS[20])

    def ratio():   # run 1 / run 4 length, with cost_mult refitted
        fit_cost()
        return -hours(5) / hours(20)     # higher G -> shorter short runs; negated so it rises with G

    def share():
        fit_cost()
        r = run(20)
        return r[2] if r else 1.0
    def share_mid():
        fit_cost()
        r = run(10)
        return r[2] if r else 1.0
    for _ in range(passes):
        bisect("vd_growth", 1.03, 1.12, ratio, -TARGETS[5] / TARGETS[20], iters=10, log=False)
        bisect("vd_mult", 1e-3, 1e6, share_mid, 0.33, iters=12)
    fit_cost()
    return P


if __name__ == '__main__':
    load_city_values()
    ht = os.path.join(HERE, 'home_tuned.json')
    if os.path.exists(ht):
        P.update(json.load(open(ht)))
    if len(sys.argv) > 1 and sys.argv[1] == 'tune':
        tune()
        json.dump({k: P[k] for k in ('G', 'cost_mult', 'vd_mult', 'vd_growth', 'ti', 'tc', 'build0', 'lvl0', 'mult')},
                  open(ht, 'w'), indent=1)
        print("HOMETOWN_COST_MULT %.4g  HOMETOWN_VD_COST_MULT %.4g  HOMETOWN_VD_LEVEL_GROWTH %.4g  HOMETOWN_TIER_INCOME %.3g  HOMETOWN_TIER_COST %.4g"
              % (P['cost_mult'], P['vd_mult'], P['vd_growth'], P['ti'], P['tc']))
    for cap in (5, 10, 15, 20):
        run(cap, True)
