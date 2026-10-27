"""v0.17g early-game pacing (Hamza's 17 Oct playtest: Bay 7 felt like a wall ~20 min in, and a new Bay 7
did almost nothing). Uses world2.py with today's game numbers plus the v0.17g changes:
  - renovation-tier level cost (tc) lowered so a new tier bay pulls its weight sooner
  - bays 7-10 build costs smoothed
  - no "needs the 3rd city" rule: a city's 1st prestige costs the same as the next city in its country
    (later prestiges x PG each)
Player: no ads (boost 1), uses the free renovation skips, discount managers a little (levels x0.8).

  python3 sim_v17g.py            report for the v0.17g numbers
  python3 sim_v17g.py old        same report for the v0.17f numbers
"""
import json, os, sys
import world2 as w

HERE = os.path.dirname(os.path.abspath(__file__))
_orig_unlock = w.unlock_cost
_orig_best = w.best_action
CFG = {}


def unlock_cost(co, pos):
    return CFG['override'].get((co, pos), _orig_unlock(co, pos))


def prestige_cost(c):
    if CFG['rule'] == 'old':
        return w.P['p0'] * w.P['pg'] ** c.p * w.S(c)
    if c.p > 0:   # later prestiges keep the v0.17 prices (Hamza: re-balance prestige 2+ later)
        return w.P['p0'] * w.P['pg'] ** c.p * w.S(c)
    pos = c.idx % w.NCITY
    return unlock_cost(c.co, pos + 1) if pos + 1 < w.NCITY else w.P['p0'] * w.S(c)


def best_action_disc(c, t):
    a = _orig_best(c, t)
    if a is None:
        return None
    return (a[0] * 0.8, a[1], a[2])


def setup(new=True):
    w.P.update(json.load(open(os.path.join(HERE, 'tuned.json')))['P'])
    w.P.update(vcap=6.0, dcap=6.0, vg=1.05, dg=1.05, vcost=15.0, dcost=15.0, boost=1.0)
    CFG['override'] = {(0, 1): 2.0e11, (0, 2): 2.0e13}
    CFG['rule'] = 'old'
    w.P['need_city'] = 3
    if new:
        b = w.P['build']
        for i, v in NEW_BUILD.items():
            b[i] = v
        w.P['tc'] = NEW_TC
        CFG['override'] = dict(NEW_OVERRIDE)
        CFG['rule'] = 'new'
        w.P['need_city'] = 1
    w.unlock_cost = unlock_cost
    w.prestige_cost = prestige_cost
    w.best_action = best_action_disc


NEW_TC = 120.0
NEW_BUILD = {6: 3.0e8, 7: 4.0e9, 8: 6.0e10, 9: 1.2e12}
NEW_OVERRIDE = {(0, 1): 4.0e9, (0, 2): 5.0e12}


def report():
    tr = {}
    log = w.run(1.0, verbose=False, track=tr)
    h = lambda key: log.get(key, float('nan')) * 60 / 3600
    lima = ["bay%d %.0f" % (n, h(('bay', (0, 0), 0, n))) for n in range(2, 13)]
    print("Lima (minutes):", ", ".join(lima))
    print("  reno1 %.0f  reno2 %.0f  Detroit %.0f  Lima prestige %.0f  LA %.0f  Miami %.0f" % (
        h(('reno', (0, 0), 0, 1)), h(('reno', (0, 0), 0, 2)), h(('city', 0, 1)), h(('prestige', (0, 0), 1)),
        h(('city', 0, 2)), h(('city', 0, 3))))
    ev = sorted(t for k, t in log.items() if t < 6 * 3600 and k[0] in ('bay', 'reno', 'city', 'prestige'))
    gaps = [(b - a) / 60 for a, b in zip([0.0] + ev, ev)]
    for lo, hi in [(0, 1), (1, 2), (2, 4), (4, 6)]:
        g = [gp for gp, t in zip(gaps, ev) if lo * 3600 <= t < hi * 3600]
        print("  hour %d-%d: %d events, longest wait %.0f min" % (lo, hi, len(g), max(g) if g else float('nan')))
    solo = {}
    w.run(0.5, verbose=False, track=solo)
    c = solo['cities'][(0, 0)]
    print("  tier bay take-over (level, minutes after built):", {k + 1: (v[0], round(v[1] / 60)) for k, v in c.takeover.items()},
          " Lv1 deal vs best older bay x", {k + 1: round(v, 1) for k, v in c.deal_at_build.items()})


if __name__ == '__main__':
    setup(new='old' not in sys.argv)
    report()
