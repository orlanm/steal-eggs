"""Search a guard's sleep fold angles so its body lies low (sphinx pose for quads, kneel/sit for bipeds).
  python3 sleepsearch.py <Guard> [--write]
Coordinate descent on sleepFront / sleepBack (quad) or sleepLeg (biped / bird), scored by sleepcheck's spine
height ratio plus penalties for limbs above the back and (quads) front paws tucked behind the shoulders.
--write stores the result in recipes.json."""
import itertools, json, sys
import numpy as np
import guardanim as ga
import sleepcheck as sc

STEPS = [40, 20, 10, 5]
RANGE = (-150, 150)


def score(rig, rec, stand_h):
    pose = ga.grounded(rig, rec, ga.sleep_pose(rec), 'Sleep')
    _, w = ga.solve(rig, rec, pose)
    low = sc.lowest(rig, rec, w)
    sp = [n for n in rec.get('spine', []) if n in w] or list(rec.get('movers', []))
    spine_y = float(np.mean([w[n][1, 3] for n in sp]))
    s = (spine_y - low) / stand_h
    pen = 0.0
    for L in rec.get('legs', []):
        for n in L['chain']:
            if n in w:
                pen += max(0.0, w[n][1, 3] - spine_y) / stand_h * 2      # limb over the back
        if rec['type'] == 'quad' and L.get('end') == 'front':
            hip, paw = w[L['chain'][0]][:3, 3], w[L['chain'][-1]][:3, 3]
            pen += max(0.0, paw[2] - hip[2]) / stand_h                   # paw behind the shoulder (+Z = back)
    return s + pen, s


def search(name):
    rig, rec = ga.load(name)
    stand_h = sc.spine_h(rig, rec, ga.stand(rec), 'Idle')
    keys = ['sleepFront', 'sleepBack'] if rec['type'] == 'quad' else ['sleepLeg']
    defaults = {'sleepFront': [-35, 105, -65], 'sleepBack': [55, -120, 60], 'sleepLeg': [80, -95, 15]}
    for k in keys:
        rec[k] = list(rec.get(k, defaults[k]))
    best, raw = score(rig, rec, stand_h)
    start = raw
    for step in STEPS:
        improved = True
        while improved:
            improved = False
            for k in keys:
                for i in range(3):
                    for d in (-step, step):
                        v = rec[k][i] + d
                        if not RANGE[0] <= v <= RANGE[1]:
                            continue
                        old = rec[k][i]
                        rec[k][i] = v
                        sc_, raw_ = score(rig, rec, stand_h)
                        if sc_ < best - 1e-4:
                            best, raw, improved = sc_, raw_, True
                        else:
                            rec[k][i] = old
    return {k: rec[k] for k in keys}, start, raw


if __name__ == '__main__':
    name = sys.argv[1]
    res, a, b = search(name)
    print(name, json.dumps(res), f'ratio {a:.2f} -> {b:.2f}')
    if '--write' in sys.argv:
        path = ga.HERE / 'recipes.json'
        recipes = json.load(open(path))
        recipes[name].update(res)
        path.write_text(json.dumps(recipes, indent=1))
        print('written')
