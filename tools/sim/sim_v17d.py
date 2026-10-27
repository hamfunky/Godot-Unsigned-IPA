"""v0.17d pacing check (no tuning): tuned.json + the game's current values that changed after
the v0.17 tune: Valet/Desk (base 6, $15/level, +5%/level), Detroit 200B and LA 20T fixed
prices, and cash managers' discounts.

Discount model: level-ups (bays, valet, desk) cost x `disc` on average. 1.0 = the player never
uses discount managers; 0.6 = uses them a fair bit (Junior 30% every 5 min, the odd Senior/Exec);
0.4 = saves up and spends almost everything inside discount windows (lucky Executive pulls).

  python3 sim_v17d.py     -> prints the milestone report for each scenario
"""
import json, os, sys
import world2 as w
import tune_world as tw

HERE = os.path.dirname(os.path.abspath(__file__))
OVERRIDE = {(0, 1): 2.0e11, (0, 2): 2.0e13}   # (country, city position) -> fixed unlock price

_orig_unlock = w.unlock_cost
_orig_best = w.best_action


def unlock_cost(co, pos):
    return OVERRIDE.get((co, pos), _orig_unlock(co, pos))


def best_action_disc(c, t):
    a = _orig_best(c, t)
    if a is None:
        return None
    return (a[0] * w.P['disc'], a[1], a[2])


def setup(disc):
    w.P.update(json.load(open(os.path.join(HERE, 'tuned.json')))['P'])
    w.P.update(vcap=6.0, dcap=6.0, vg=1.05, dg=1.05, vcost=15.0, dcost=15.0, disc=disc)
    w.unlock_cost = unlock_cost
    w.best_action = best_action_disc


if __name__ == '__main__':
    for disc, label in [(1.0, "never uses discount managers"), (0.6, "uses them a fair bit (avg 40% off levels)"), (0.4, "spends inside discount windows (avg 60% off)")]:
        setup(disc)
        print("=== %s ===" % label, flush=True)
        tw.report()
        print(flush=True)
