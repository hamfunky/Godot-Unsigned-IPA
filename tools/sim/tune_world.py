"""Tunes the whole economy (world2.py) to the pacing targets, one knob at a time
(binary search on a log scale), several passes because the knobs interact.

  python3 tune_world.py 3          3 fresh passes
  python3 tune_world.py 2 resume   2 more passes starting from tuned.json
  python3 tune_world.py report     just print the result for tuned.json

Targets (active player with the no-ads pack, hours of real time):
  valet + desk take ~1/3 of the USA's level-up spending in the first 2 hours (the sim player
  keeps them 1.1x ahead of the bays). Their capacity growth per level (vg/dg 1.05) is chosen so
  the price that gives that share stays roughly flat from hour 0 to day 14 (see PROJECT_NOTES);
  the tuner sets their level price.
  bay 6 (first bay after renovation 1) out-earns every older bay at about Lv 25 (Lima played solo)
  Bay 5 0.33h, renovation 1 0.5h, Detroit 1h, Lima prestige just after LA (city 3),
  all 5 US cities 48h, Japan 96h, Germany 336h, Australia 672h, UAE 1344h, a 5-star city 504h
"""
import math, json, sys, time, os
import world2 as w

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'tuned.json')

BASE_BUILD = list(w.P['build'])
BASE = dict(vcap=4.0, dcap=4.0, ti=3.0, vg=1.05, dg=1.05)   # design choices (not tuned)


def apply(k, x):
    if k == 'early':
        w.P['build'] = [BASE_BUILD[0]] + [b * x for b in BASE_BUILD[1:5]] + w.P['build'][5:]
    elif k == 'b5':
        w.P['build'][5] = x
    elif k == 'vd':
        w.P['vcost'] = 15.0 * x
        w.P['dcost'] = 15.0 * x
    elif k == 'vg':
        w.P['vg'] = x
        w.P['dg'] = x
    elif k in ('unlock_base', 'p0', 'pg', 'unlock_growth', 'tc'):
        w.P[k] = x
    elif k[0] == 'c':
        w.P['country'][int(k[1])] = x


def late_builds():
    """bays 7-20 keep the old placeholder shape, x ti per renovation tier (tier bays earn ti x more)"""
    for n in range(6, 20):
        w.P['build'][n] = BASE_BUILD[n] * w.P['ti'] ** w.TIER[n] * (w.P['build'][5] / BASE_BUILD[5])


def lima_detail(hours):
    tr = {}
    w.run(hours / 24.0, verbose=False, track=tr)
    lima = None
    for c in tr.get('done', []):
        if c.idx == 0 and c.p == 0:
            lima = c
    if lima is None:
        lima = tr['cities'][(0, 0)]
    return tr, lima


def solo_lima(hours):
    """Lima played on its own (no other cities, no prestige, no sleep): how a city's bays
    behave when you level the city on screen"""
    keep = dict(w.P)
    keep['build'] = list(w.P['build'])
    keep['country'] = list(w.P['country'])
    w.P.update(unlock_base=1e300, p0=1e300, sleep=False)
    tr = {}
    log = w.run(hours / 24.0, verbose=False, track=tr)
    w.P.clear()
    w.P.update(keep)
    return tr['cities'][(0, 0)], log


def measure(k):
    """the value a knob is tuned on and its target"""
    if k == 'vd':   # valet + desk share of the USA's level-up spending in the first 2 hours
        tr = {}
        w.run(2.05 / 24, verbose=False, track=tr)
        return w.spend_share(tr['usa'], 0, 2 * 3600, True), 0.33
    if k == 'tc':   # bay 6 out-earns every older bay at ~Lv 25 (solo Lima)
        lima, _ = solo_lima(30)
        if 5 not in lima.built_at:
            return 0.0, 25.0
        tk = lima.takeover.get(5)
        return (tk[0] if tk else 400.0), 25.0
    keys = {'early': (('bay', (0, 0), 0, 5), 0.33), 'b5': (('reno', (0, 0), 0, 1), 0.5),
            'unlock_base': (('city', 0, 1), 1.0), 'unlock_growth': (('city', 0, 4), 48.0),
            'c1': (('country', 1), 96.0), 'pg': (('5star',), 504.0), 'c2': (('country', 2), 336.0),
            'c3': (('country', 3), 672.0), 'c4': (('country', 4), 1344.0)}
    if k == 'p0':
        log = w.run(days=6, verbose=False, targets=[('prestige', (0, 0), 1)])
        la = log.get(('city', 0, 2), 1e18) / 3600
        return log.get(('prestige', (0, 0), 1), 1e18) / 3600, la * 1.15
    key, hours = keys[k]
    log = w.run(days=hours * 3 / 24 + 0.2, verbose=False, targets=[key])
    return log.get(key, 1e18) / 3600, hours


RANGES = {'vd': (0.1, 1e4), 'tc': (1, 1e5), 'early': (0.05, 50), 'b5': (1e6, 1e14), 'unlock_base': (1e4, 1e14),
          'p0': (1e6, 1e22), 'unlock_growth': (1, 1e5), 'c1': (1e8, 1e32), 'pg': (10, 1e7),
          'c2': (1e12, 1e42), 'c3': (1e12, 1e46), 'c4': (1e18, 1e52)}
ORDER = ['vd', 'tc', 'early', 'b5', 'unlock_base', 'unlock_growth', 'p0', 'c1', 'pg', 'c2', 'c3', 'c4']


def current(k):
    if k == 'early':
        return w.P['build'][1] / BASE_BUILD[1]
    if k == 'b5':
        return w.P['build'][5]
    if k == 'vd':
        return w.P['vcost'] / 15.0
    if k[0] == 'c' and k[1].isdigit():
        return w.P['country'][int(k[1])]
    return w.P[k]


def tune(k, iters=7, span=3.0):
    """binary search within span x either side of the current value (inside RANGES)"""
    x0 = math.log10(current(k))
    lo = max(math.log10(RANGES[k][0]), x0 - math.log10(span))
    hi = min(math.log10(RANGES[k][1]), x0 + math.log10(span))
    for _ in range(iters):
        mid = (lo + hi) / 2
        apply(k, 10 ** mid)
        late_builds()
        val, target = measure(k)
        if val < target:      # too fast / too small -> raise
            lo = mid
        else:
            hi = mid
    x = 10 ** ((lo + hi) / 2)
    apply(k, x)
    late_builds()
    return x


def save(res):
    json.dump({'P': w.P, 'res': res}, open(OUT, 'w'), default=float, indent=1)


def report():
    tr = {}
    log = w.run(60, verbose=False, track=tr)
    lima = None
    for c in tr.get('done', []):
        if c.idx == 0 and c.p == 0:
            lima = c
    lima = lima or tr['cities'][(0, 0)]
    h = lambda key: log.get(key, float('nan')) / 3600
    print("milestones (hours): bay5 %.2f  reno1 %.2f  bay6 %.2f  Detroit %.2f  LA %.2f  Lima prestige %.2f  Miami %.1f  Houston %.1f"
          % (h(('bay', (0, 0), 0, 5)), h(('reno', (0, 0), 0, 1)), h(('bay', (0, 0), 0, 6)), h(('city', 0, 1)), h(('city', 0, 2)),
             h(('prestige', (0, 0), 1)), h(('city', 0, 3)), h(('city', 0, 4))))
    print("  Lima p0 bay 10 %.1fh  bay 11 %.1fh  bay 15 %.1fh" % (h(('bay', (0, 0), 0, 10)), h(('bay', (0, 0), 0, 11)), h(('bay', (0, 0), 0, 15))))
    print("countries (days): Japan %.1f  Germany %.1f  Australia %.1f  UAE %.1f  5-star city %.1f"
          % (h(('country', 1)) / 24, h(('country', 2)) / 24, h(('country', 3)) / 24, h(('country', 4)) / 24, h(('5star',)) / 24))
    u = tr['usa']
    ss = lambda a, b: w.spend_share(u, a * 3600, b * 3600, True)
    print("valet+desk share of USA level-up spending: 0-1h %.2f  1-2h %.2f  2-4h %.2f  4-12h %.2f  12-36h %.2f  2-4d %.2f  7-14d %.2f"
          % (ss(0, 1), ss(1, 2), ss(2, 4), ss(4, 12), ss(12, 36), ss(48, 96), ss(168, 336)))
    behind = [k for k, c in tr['cities'].items() if min(w.vrate(c.v, len(c.bays)), w.drate(c.d)) < w.bays_out(c)]
    print("day 60: cities with valet or desk at Lv 400: %d,  cities where valet/desk can't keep up: %d"
          % (sum(1 for c in tr['cities'].values() if c.v >= 400 or c.d >= 400), len(behind)))
    solo, slog = solo_lima(72)
    print("renovation tiers (solo Lima, 72h): tier bay out-earns every older bay at [level, hours after build]:",
          {k + 1: (v[0], round(v[1] / 3600, 2)) for k, v in solo.takeover.items()},
          "  its Lv1 deal vs the best older bay: x", {k + 1: round(v, 1) for k, v in solo.deal_at_build.items()})
    return log


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'report':
        w.P.update(json.load(open(OUT))['P'])
        report()
        sys.exit()
    passes = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    w.P.update(BASE)
    res = {}
    if len(sys.argv) > 2:   # resume from the last result
        d = json.load(open(OUT))
        w.P.update(d['P'])
        res = d.get('res', {})
        e = res.get('early', 1.0)
        BASE_BUILD[:] = [b / (e if 1 <= i <= 4 else 1.0) for i, b in enumerate(w.P['build'])]
        b5 = w.P['build'][5]
        for n in range(6, 20):
            BASE_BUILD[n] = w.P['build'][n] / (w.P['ti'] ** w.TIER[n] * b5 / BASE_BUILD[5])
    for p in range(passes):
        for k in ORDER:
            t0 = time.time()
            x = tune(k)
            res[k] = x
            print(f"pass {p} {k:14s} = {x:.4g}   ({time.time() - t0:.0f}s)", flush=True)
            save(res)
        report()
