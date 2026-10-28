"""How low a guard lies asleep: spine height above the floor, asleep vs standing.
  python3 sleepcheck.py [Guard ...]
Prints, per guard, standing / sleeping spine height (studs above the lowest point of the body) and their ratio;
a lying pose puts the body near the floor (ratio well under 0.5)."""
import json, sys
import numpy as np
import guardanim as ga


def lowest(rig, rec, w):
    # the movers are pivots (often a bone on the floor), not body
    skip = set(rec.get('movers') or []) | set(rec.get('groundIgnore', []))
    return min(ga.bottom(rig, w, n) for n in w if n in rig.nodes and n not in skip)


def spine_h(rig, rec, pose, clip):
    p = ga.grounded(rig, rec, pose, clip)
    _, w = ga.solve(rig, rec, p)
    sp = [n for n in rec.get('spine', []) if n in w] or list(rec.get('movers', []))
    return float(np.mean([w[n][1, 3] for n in sp]) - lowest(rig, rec, w))


def check(name):
    rig, rec = ga.load(name)
    st = spine_h(rig, rec, ga.stand(rec), 'Idle')
    sl = spine_h(rig, rec, ga.sleep_pose(rec), 'Sleep')
    return st, sl


if __name__ == '__main__':
    names = sys.argv[1:] or list(json.load(open(ga.HERE / 'recipes.json')))
    for n in names:
        try:
            st, sl = check(n)
            print(f'{n:18s} stand {st:6.2f}  sleep {sl:6.2f}  ratio {sl / max(st, 1e-3):.2f}')
        except Exception as e:
            print(f'{n:18s} ERR {e}')
