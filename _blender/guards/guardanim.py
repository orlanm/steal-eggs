"""Procedural guard animations (Sleep, Wake, Run, Idle) for the Steal-an-Egg guard rigs and big pet guards.

  python3 guardanim.py <Guard> [clip ...]        writes out/<Guard>_<Clip>.rbxmx (+ out/<Guard>_<Clip>.npz posed frames)

Rigs come from Studio (dump_rig.luau -> rigs/<Guard>.json): parts, Motor6D joints (keyed by Part1) and Bones,
all in the rig's root-part frame. recipes.json names the chains (legs, spine, neck, tail, ...) for each guard.

Poses are written as rotations about the RIG axes (X right, Y up, -Z forward) at each joint's pivot, relative to
its parent: +pitch = nose up / limb swings forward, +yaw = turn left, +roll = right side up. A joint's
Transform is Rf^T * Q * Rf, where Rf is the joint frame's rest rotation, so a rotation means the same thing
on every rig no matter how its bones were oriented on import. The rig root is moved with `lift` (studs, rig
axes) on the top-level joints. "follow" bones (IK feet parented to the root) are solved so they ride rigidly
on the end of their leg chain.
"""
import json, math, sys
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
OUT = HERE / 'out'
FPS = 20


# ------------------------------------------------------------------------------------------------
# math
# ------------------------------------------------------------------------------------------------
def cf(c):
    m = np.eye(4)
    m[:3, 3] = c[:3]
    m[:3, :3] = np.array(c[3:12]).reshape(3, 3)
    return m


def rx(d):
    a = math.radians(d); c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def ry(d):
    a = math.radians(d); c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def rz(d):
    a = math.radians(d); c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def Q(p=0.0, y=0.0, r=0.0):
    return ry(y) @ rx(p) @ rz(r)


def ortho(r):
    u, _, vt = np.linalg.svd(r)
    m = u @ vt
    if np.linalg.det(m) < 0:
        u[:, -1] *= -1
        m = u @ vt
    return m


def smooth(u):
    u = min(1.0, max(0.0, u))
    return u * u * (3 - 2 * u)


def lerp(a, b, u):
    return a + (b - a) * u


# ------------------------------------------------------------------------------------------------
# rig
# ------------------------------------------------------------------------------------------------
class Rig:
    def __init__(self, data):
        self.name = data['name']
        self.root = data['root']
        self.parts = {p['name']: {'size': np.array(p['size']), 'cf': cf(p['cf']), 'tr': p['transparency']} for p in data['parts']}
        self.nodes = {}
        for j in data['joints']:
            self.nodes[j['part1']] = {'kind': 'motor', 'parent': j['part0'], 'c0': cf(j['c0']), 'c1': cf(j['c1'])}
        for b in data['bones']:
            if b['name'] in self.nodes:
                raise RuntimeError(f"name clash {b['name']}")
            self.nodes[b['name']] = {'kind': 'bone', 'parent': b['parent'], 'cf': cf(b['cf']), 'world': cf(b['world'])}
        self.children = {}
        for n, v in self.nodes.items():
            self.children.setdefault(v['parent'], []).append(n)
        self.order, seen = [], set()

        def visit(n):
            if n in seen or n not in self.nodes:
                return
            seen.add(n)
            visit(self.nodes[n]['parent'])
            self.order.append(n)
        for n in self.nodes:
            visit(n)
        # rest worlds of parts and bones, and the rest joint frame (pivot + axes the Transform acts in)
        self.rest = self.fk({})
        self.frame = {}
        for n, v in self.nodes.items():
            if v['kind'] == 'motor':
                self.frame[n] = self.rest[v['parent']] @ v['c0']
            else:
                self.frame[n] = self.rest[n]
        self.scale = float(data.get('scale', 1.0))
        bb = data['bbox']
        self.bbox_center = np.array(bb['cf'][:3]); self.bbox_size = np.array(bb['size'])
        self.ground = self.bbox_center[1] - self.bbox_size[1] / 2
        self.rest_min = min(self.rest[n][1, 3] for n in self.nodes)

    def world0(self, n, posed):
        if n == self.root:
            return np.eye(4)
        if n in posed:
            return posed[n]
        if n in self.parts:
            return self.parts[n]['cf']
        return np.eye(4)

    def fk(self, T):
        """Posed worlds of every part / bone (rig root frame). T: node -> 4x4 Transform."""
        w = {self.root: np.eye(4)}
        for n in self.order:
            v = self.nodes[n]
            t = T.get(n, np.eye(4))
            p = w.get(v['parent'], self.world0(v['parent'], w))
            if v['kind'] == 'motor':
                w[n] = p @ v['c0'] @ t @ np.linalg.inv(v['c1'])
            else:
                w[n] = p @ v['cf'] @ t
        return w

    def pivot(self, n):
        return self.frame[n][:3, 3]


# ------------------------------------------------------------------------------------------------
# pose -> transforms
# ------------------------------------------------------------------------------------------------
def solve(rig, rec, pose):
    """pose: {'rot': {node: (p, y, r)}, 'lift': (x, y, z)} -> (T, worlds)."""
    T = {}
    lift = np.array(pose.get('lift', (0, 0, 0)), dtype=float)
    movers = set(rec.get('movers') or [c for c in rig.children.get(rig.root, []) if c not in rec.get('follow', {})])
    for n, ang in pose.get('rot', {}).items():
        if n not in rig.nodes:
            continue
        Rf = rig.frame[n][:3, :3]
        m = np.eye(4)
        m[:3, :3] = ortho(Rf.T @ Q(*ang) @ Rf)
        T[n] = m
    for n in movers:
        if n not in rig.nodes:
            continue
        m = T.get(n, np.eye(4)).copy()
        m[:3, 3] = rig.frame[n][:3, :3].T @ lift
        T[n] = m
    w = rig.fk(T)
    # IK-style feet parented to the root: ride rigidly on their leg's end
    for f, leader in rec.get('follow', {}).items():
        if f not in rig.nodes or leader not in w:
            continue
        v = rig.nodes[f]
        want = w[leader] @ np.linalg.inv(rig.rest[leader]) @ rig.rest[f]
        parent = w.get(v['parent'], rig.world0(v['parent'], w))
        base = parent @ (v['cf'] if v['kind'] == 'bone' else v['c0'])
        t = np.linalg.inv(base) @ want
        if v['kind'] == 'motor':
            t = t @ v['c1']
        t[:3, :3] = ortho(t[:3, :3])
        T[f] = t
    if rec.get('follow'):
        w = rig.fk(T)
    return T, w


def blend(a, b, u):
    """Blend two poses (dicts of euler triples) linearly in angle space."""
    out = {'rot': {}, 'lift': tuple(lerp(np.array(a.get('lift', (0, 0, 0)), float), np.array(b.get('lift', (0, 0, 0)), float), u))}
    for n in set(a.get('rot', {})) | set(b.get('rot', {})):
        pa = np.array(a.get('rot', {}).get(n, (0, 0, 0)), float)
        pb = np.array(b.get('rot', {}).get(n, (0, 0, 0)), float)
        out['rot'][n] = tuple(lerp(pa, pb, u))
    return out


def add(pose, n, p=0.0, y=0.0, r=0.0):
    a = pose['rot'].get(n, (0.0, 0.0, 0.0))
    pose['rot'][n] = (a[0] + p, a[1] + y, a[2] + r)


# ------------------------------------------------------------------------------------------------
# recipe helpers
# ------------------------------------------------------------------------------------------------
def legs(rec, where=None):
    return [L for L in rec.get('legs', []) if where is None or L.get('end') == where]


def sgn(side):
    return 1.0 if side == 'R' else -1.0


def contact_y(rig, w, nodes):
    """Lowest posed point of the given nodes, offset by how far each sat above the ground at rest."""
    ys = []
    for n in nodes:
        if n in w:
            rest_h = (rig.rest[n][1, 3]) - rig.ground
            ys.append(w[n][1, 3] - rest_h)
    return min(ys) if ys else rig.ground


def base_pose(rec, key):
    """Recipe-supplied static pose (e.g. 'stand' for rigs whose rest pose is lying down)."""
    src = rec.get(key) or {}
    return {'rot': {n: tuple(v) for n, v in src.get('rot', {}).items()}, 'lift': tuple(src.get('lift', (0, 0, 0)))}


def merged(*poses):
    out = {'rot': {}, 'lift': (0.0, 0.0, 0.0)}
    for p in poses:
        for n, a in p.get('rot', {}).items():
            add(out, n, *a)
        out['lift'] = tuple(np.array(out['lift']) + np.array(p.get('lift', (0, 0, 0)), float))
    return out


# ------------------------------------------------------------------------------------------------
# archetype poses
# ------------------------------------------------------------------------------------------------
def stand(rec):
    return base_pose(rec, 'stand')


def sleep_pose(rec, breath=0.0):
    """Lying / sitting asleep. breath in [-1, 1]."""
    p = merged(base_pose(rec, 'stand'), base_pose(rec, 'sleep'))
    kind = rec['type']
    S = rec.get('sleepScale', 1.0)
    if not rec.get('sleep', {}).get('manual'):
        if kind in ('quad',):
            # sleepFront / sleepBack: per-rig fold (hip, knee, paw pitch); tuned with sleepcheck.py
            for L in legs(rec, 'front'):
                for n, a in zip(L['chain'], rec.get('sleepFront', (-35, 105, -65))):
                    add(p, n, a * S)
            for L in legs(rec, 'back'):
                for n, a in zip(L['chain'], rec.get('sleepBack', (55, -120, 60))):
                    add(p, n, a * S)
            for i, n in enumerate(rec.get('neck', [])):
                add(p, n, -14 * S)
            if rec.get('head'): add(p, rec['head'], -10 * S)
            for i, n in enumerate(rec.get('tail', [])):
                add(p, n, -6 * S, 14 * S, 0)
        elif kind in ('biped', 'bird'):
            for L in legs(rec):
                for n, a in zip(L['chain'], rec.get('sleepLeg', (80, -95, 15))):
                    add(p, n, a * S)
            for n in rec.get('spine', [])[1:]:
                add(p, n, rec.get('sleepLean', -8) * S)
            for n in rec.get('neck', []):
                add(p, n, -16 * S)
            if rec.get('head'): add(p, rec['head'], -14 * S)
            for A in rec.get('arms', []):
                c = A['chain']
                add(p, c[0], 25 * S, 0, -sgn(A['side']) * 8 * S)
                if len(c) > 1: add(p, c[1], 35 * S)
            for W in rec.get('wings', []):
                for n in W['chain']:
                    add(p, n, 0, sgn(W['side']) * 10 * S, -sgn(W['side']) * 6 * S)
            for n in rec.get('tail', []):
                add(p, n, -8 * S)
        elif kind == 'multileg':
            for L in rec.get('legs', []):
                c = L['chain']
                add(p, c[0], 0, 0, sgn(L['side']) * 14 * S)
                if len(c) > 1: add(p, c[1], 0, 0, -sgn(L['side']) * 10 * S)
            for i, n in enumerate(rec.get('tail', [])):
                add(p, n, -14 * S)
            for A in rec.get('arms', []):
                add(p, A['chain'][0], -8 * S, -sgn(A['side']) * 10 * S)
            if rec.get('head'): add(p, rec['head'], -6 * S)
        elif kind == 'swim':
            for n in rec.get('spine', []):
                add(p, n, -2)
            for n in rec.get('tail', []):
                add(p, n, -4)
    lift = np.array(p['lift'], float)
    lift[1] -= rec.get('sleepDrop', 0.0)
    # breathing: chest swells (spine pitch) and the body rises a little
    b = breath * rec.get('breath', 1.0)
    for i, n in enumerate(rec.get('spine', [])):
        add(p, n, 1.4 * b * (1 if i % 2 == 0 else -0.6))
    if rec.get('head'): add(p, rec['head'], -0.8 * b)
    lift[1] += 0.012 * b * rec['height']
    p['lift'] = tuple(lift)
    return p


def run_pose(rec, ph):
    """Running / galloping / swimming cycle at phase ph in [0, 1)."""
    p = stand(rec)
    kind = rec['type']
    A = rec.get('runAmp', 1.0)
    tau = 2 * math.pi
    lift = np.array(p['lift'], float)
    H = rec['height']
    if kind == 'quad':
        offs = {'front': {'L': 0.0, 'R': 0.12}, 'back': {'L': 0.5, 'R': 0.62}}
        for L in rec.get('legs', []):
            th = tau * (ph - offs[L['end']][L['side']])
            s, c = math.sin(th), math.cos(th)
            ch = L['chain']
            add(p, ch[0], 34 * A * s)
            flex = max(0.0, c)
            if L['end'] == 'front':
                if len(ch) > 1: add(p, ch[1], -55 * A * flex)
                if len(ch) > 2: add(p, ch[2], 30 * A * flex)
            else:
                if len(ch) > 1: add(p, ch[1], -45 * A * flex)
                if len(ch) > 2: add(p, ch[2], 50 * A * flex)
        spine = rec.get('spine', [])
        for i, n in enumerate(spine):
            add(p, n, 4 * A * math.sin(tau * ph + i * 0.6))
        for n in rec.get('neck', []):
            add(p, n, -5 * A * math.sin(tau * ph))
        if rec.get('head'): add(p, rec['head'], 4 - 3 * A * math.sin(tau * ph))
        lift[1] += 0.035 * H * A * math.sin(tau * 2 * ph)
    elif kind in ('biped', 'bird'):
        lean = rec.get('runLean', 10 if kind == 'biped' else 14)
        for L in rec.get('legs', []):
            th = tau * (ph + (0.0 if L['side'] == 'L' else 0.5))
            s, c = math.sin(th), math.cos(th)
            ch = L['chain']
            add(p, ch[0], 38 * A * s)
            if len(ch) > 1: add(p, ch[1], -70 * A * max(0.0, c) - 8 * A)
            if len(ch) > 2: add(p, ch[2], 25 * A * max(0.0, c))
        for Arm in rec.get('arms', []):
            th = tau * (ph + (0.5 if Arm['side'] == 'L' else 0.0))
            ch = Arm['chain']
            add(p, ch[0], 32 * A * math.sin(th) * rec.get('armSwing', 1.0))
            if len(ch) > 1: add(p, ch[1], 35 * rec.get('armSwing', 1.0))
        for W in rec.get('wings', []):
            flap = math.sin(tau * ph * rec.get('flapRate', 1.0))
            for i, n in enumerate(W['chain']):
                add(p, n, 0, 0, sgn(W['side']) * (18 + 24 * flap) * (0.6 if i else 1.0) * rec.get('flap', 1.0))
        spine = rec.get('spine', [])
        if spine:
            add(p, spine[0], -lean)
            for n in spine[1:]:
                add(p, n, -2, 5 * A * math.sin(tau * ph), 0)
        for n in rec.get('neck', []):
            add(p, n, lean * 0.6 / max(1, len(rec.get('neck', []))))
        if rec.get('head'): add(p, rec['head'], lean * 0.4 + 3 * math.sin(tau * 2 * ph))
        for i, n in enumerate(rec.get('tail', [])):
            add(p, n, 4, 7 * A * math.sin(tau * ph - 0.7 * i), 0)
        lift[1] += 0.03 * H * A * (math.cos(tau * 2 * ph))
    elif kind == 'multileg':
        for L in rec.get('legs', []):
            th = tau * (ph + (0.0 if (L['index'] + (L['side'] == 'R')) % 2 == 0 else 0.5))
            s, c = math.sin(th), math.cos(th)
            ch = L['chain']
            add(p, ch[0], 0, 22 * A * s, sgn(L['side']) * 16 * A * max(0.0, c))
            if len(ch) > 1: add(p, ch[1], 0, 0, -sgn(L['side']) * 10 * A * max(0.0, c))
        for i, n in enumerate(rec.get('tail', [])):
            add(p, n, 5 * math.sin(tau * ph - 0.5 * i))
        for Arm in rec.get('arms', []):
            add(p, Arm['chain'][0], 5 * math.sin(tau * ph), sgn(Arm['side']) * 8 * math.sin(tau * 2 * ph))
        lift[1] += 0.02 * H * math.sin(tau * 2 * ph)
    elif kind == 'swim':
        for i, n in enumerate(rec.get('spine', [])):
            add(p, n, 5 * A * math.sin(tau * ph - 0.4 * i))
        for i, n in enumerate(rec.get('tail', [])):
            add(p, n, 22 * A * math.sin(tau * ph - 1.0 - 0.6 * i))
        if rec.get('head'): add(p, rec['head'], -4 * A * math.sin(tau * ph + 0.4))
        for Fin in rec.get('arms', []):
            add(p, Fin['chain'][0], 10 * math.sin(tau * ph), 0, sgn(Fin['side']) * 18 * math.sin(tau * ph + 0.8))
        lift[1] += 0.03 * H * math.sin(tau * ph + 0.8)
    p['lift'] = tuple(lift)
    return p


def idle_pose(rec, t, period):
    p = stand(rec)
    tau = 2 * math.pi
    u = t / period
    b = math.sin(tau * u * 2)
    for i, n in enumerate(rec.get('spine', [])):
        add(p, n, 1.2 * b * (1 if i % 2 == 0 else -0.5))
    look = math.sin(tau * u)
    necks = rec.get('neck', [])
    for n in necks:
        add(p, n, 0, 7 * look / max(1, len(necks)), 0)
    if rec.get('head'): add(p, rec['head'], 2 * math.sin(tau * u * 2 + 1), 8 * look, 0)
    for i, n in enumerate(rec.get('tail', [])):
        add(p, n, 0, 6 * math.sin(tau * u * 2 - 0.6 * i), 0)
    for W in rec.get('wings', []):
        for n in W['chain'][:1]:
            add(p, n, 0, 0, sgn(W['side']) * 4 * math.sin(tau * u * 2))
    lift = np.array(p['lift'], float)
    lift[1] += 0.008 * rec['height'] * b
    p['lift'] = tuple(lift)
    return p


def roar_pose(rec, k):
    """Head thrown up with the jaw open, k in [0, 1]."""
    p = {'rot': {}, 'lift': (0, 0, 0)}
    for n in rec.get('neck', []):
        add(p, n, 14 * k)
    if rec.get('head'): add(p, rec['head'], 10 * k)
    if rec.get('jaw'): add(p, rec['jaw'], -rec.get('jawOpen', 24) * k)
    for n in rec.get('spine', [])[1:2]:
        add(p, n, 4 * k)
    for W in rec.get('wings', []):
        for i, n in enumerate(W['chain']):
            add(p, n, 0, 0, sgn(W['side']) * 30 * k * (0.7 if i else 1.0))
    for A in rec.get('arms', []):
        if rec['type'] in ('biped',):
            add(p, A['chain'][0], 30 * k, 0, sgn(A['side']) * 25 * k)
    return p


# ------------------------------------------------------------------------------------------------
# clips: list of (time, pose)
# ------------------------------------------------------------------------------------------------
def clip_sleep(rec):
    period = rec.get('sleepPeriod', 3.6)
    n = int(period * FPS)
    return [(i / FPS, sleep_pose(rec, math.sin(2 * math.pi * i / n))) for i in range(n + 1)], True


def clip_wake(rec):
    dur = rec.get('wakeSeconds', 2.0)
    n = int(dur * FPS)
    out = []
    for i in range(n + 1):
        t = i / FPS
        u = t / dur
        rise = smooth((u - 0.18) / 0.5)              # 0.18 .. 0.68: get up
        base = blend(sleep_pose(rec, math.sin(2 * math.pi * t / 3.6)), stand(rec), rise)
        look = smooth(u / 0.25) * (1 - rise) * 0.6     # head lifts first, eyes open
        roar = smooth((u - 0.62) / 0.14) * (1 - smooth((u - 0.86) / 0.14))
        p = merged(base, roar_pose(rec, max(look, roar)))
        # a shake as it gets to its feet
        shake = math.sin(2 * math.pi * 3.0 * u) * (smooth((u - 0.5) / 0.1) * (1 - smooth((u - 0.68) / 0.1)))
        for s_ in rec.get('spine', [])[:1]:
            add(p, s_, 0, 0, 4 * shake)
        out.append((t, p))
    return out, False


def clip_run(rec):
    period = rec.get('runPeriod', 0.7)
    n = int(round(period * FPS * 2))   # finer sampling for the fast cycle
    return [(i * period / n, run_pose(rec, i / n)) for i in range(n + 1)], True


def clip_idle(rec):
    period = rec.get('idlePeriod', 4.8)
    n = int(period * FPS)
    return [(i / FPS, idle_pose(rec, i / FPS, period)) for i in range(n + 1)], True


CLIPS = {'Sleep': clip_sleep, 'Wake': clip_wake, 'Run': clip_run, 'Idle': clip_idle}
PRIORITY = {'Sleep': 1, 'Idle': 1, 'Run': 2, 'Wake': 4}     # Idle / Movement / Action


# ------------------------------------------------------------------------------------------------
# grounding + output
# ------------------------------------------------------------------------------------------------
def bottom(rig, w, n):
    """Lowest point of a node: the lowest corner of a visible part's box, else the joint itself (bones)."""
    m = w[n]
    part = rig.parts.get(n)
    if part is None or part['tr'] >= 0.95:
        return m[1, 3]
    return m[1, 3] - float(np.abs(m[1, :3]) @ (part['size'] / 2))


def grounded(rig, rec, pose, clip):
    """Keep the feet (standing clips) or the recipe's sleep contacts on the floor."""
    if rec['type'] == 'swim':
        return pose
    T, w = solve(rig, rec, pose)
    feet = rec.get('feet') or []
    if not feet and not (clip in ('Sleep', 'Wake') and rec.get('sleepAuto', True)):
        return pose
    y = contact_y(rig, w, feet)
    lift = np.array(pose.get('lift', (0, 0, 0)), float)
    if clip in ('Sleep', 'Wake') and rec.get('sleepAuto', True):
        # lying down: lower (or raise) the body until its lowest joint rests where the standing feet were
        movers = rec.get('movers') or [c for c in rig.children.get(rig.root, []) if c not in rec.get('follow', {})]
        carried = set(rec.get('follow', {}))
        stack = list(movers)
        while stack:
            n = stack.pop()
            carried.add(n)
            stack += rig.children.get(n, [])
        # the movers themselves are pivots (often a bone on the floor), not what touches it; groundIgnore names
        # other helper bones that reach the floor (e.g. a root stick under the hips)
        skip = set(movers) | set(rec.get('groundIgnore', []))
        body = [n for n in carried if n in w and n not in skip]
        _, w0 = solve(rig, rec, stand(rec))
        lowest = min(bottom(rig, w, n) for n in body)
        lift = np.array(pose.get('lift', (0, 0, 0)), float)
        lift[1] += min(bottom(rig, w0, n) for n in body if n in w0) - lowest
        out = dict(pose)
        out['lift'] = tuple(lift)
        return out
    if clip == 'Sleep':
        return pose
    # never sink below the floor; allow the run bob to leave it
    lift[1] += max(0.0, rig.ground - y)
    out = dict(pose)
    out['lift'] = tuple(lift)
    return out


def xml_cf(m):
    r = m[:3, :3]
    vals = dict(X=m[0, 3], Y=m[1, 3], Z=m[2, 3], R00=r[0, 0], R01=r[0, 1], R02=r[0, 2], R10=r[1, 0], R11=r[1, 1],
                R12=r[1, 2], R20=r[2, 0], R21=r[2, 1], R22=r[2, 2])
    return ''.join(f'<{k}>{v:.6g}</{k}>' for k, v in vals.items())


def write(rig, rec, name, clip, frames, loop):
    solved = [solve(rig, rec, pose) for _, pose in frames]
    moving = set()
    for T, _ in solved:
        for n, m in T.items():
            if not np.allclose(m, np.eye(4), atol=1e-5):
                moving.add(n)
    driven = set()

    def mark(n):
        hit = n in moving
        for c in rig.children.get(n, []):
            hit = mark(c) or hit
        if hit:
            driven.add(n)
        return hit
    mark(rig.root)

    def pose_xml(n, T):
        kids = ''.join(pose_xml(c, T) for c in rig.children.get(n, []) if c in driven)
        m = T.get(n, np.eye(4)).copy()
        m[:3, 3] /= rig.scale     # the Animator scales Pose translations by the model's scale
        return (f'<Item class="Pose"><Properties><CoordinateFrame name="CFrame">{xml_cf(m)}</CoordinateFrame>'
                f'<token name="EasingDirection">0</token><token name="EasingStyle">0</token>'
                f'<string name="Name">{n}</string><float name="Weight">1</float></Properties>{kids}</Item>')

    items, worlds = [], []
    for (t, pose), (T, w) in zip(frames, solved):
        top = ''.join(pose_xml(c, T) for c in rig.children.get(rig.root, []) if c in driven)
        root_pose = (f'<Item class="Pose"><Properties><CoordinateFrame name="CFrame">{xml_cf(np.eye(4))}</CoordinateFrame>'
                     f'<token name="EasingDirection">0</token><token name="EasingStyle">0</token>'
                     f'<string name="Name">{rig.root}</string><float name="Weight">0</float></Properties>{top}</Item>')
        items.append(f'<Item class="Keyframe"><Properties><string name="Name">Keyframe</string>'
                     f'<float name="Time">{t:.5f}</float></Properties>{root_pose}</Item>')
        worlds.append({k: v for k, v in w.items()})
    xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" version="4">'
           f'<Item class="KeyframeSequence"><Properties><string name="Name">Guard_{name}_{clip}</string>'
           f'<bool name="Loop">{"true" if loop else "false"}</bool><token name="Priority">{PRIORITY[clip]}</token></Properties>'
           + ''.join(items) + '</Item></roblox>')
    OUT.mkdir(exist_ok=True)
    (OUT / f'{name}_{clip}.rbxmx').write_text(xml)
    keys = sorted(worlds[0])
    np.savez_compressed(OUT / f'{name}_{clip}.npz', names=np.array(keys), times=np.array([t for t, _ in frames]),
                        worlds=np.array([[w[k] for k in keys] for w in worlds]))
    return OUT / f'{name}_{clip}.rbxmx'


def load(name):
    recipes = json.load(open(HERE / 'recipes.json'))
    rec = dict(recipes[name])
    rig = Rig(json.load(open(HERE / 'rigs' / f"{rec.get('rig', name)}.json")))
    rec.setdefault('height', float(rig.bbox_size[1]))
    if rec.get('feet') == 'auto':
        rec['feet'] = [L['chain'][-1] for L in rec.get('legs', [])]
    for L in rec.get('legs', []):
        missing = [n for n in L['chain'] if n not in rig.nodes]
        if missing:
            raise RuntimeError(f'{name}: unknown leg nodes {missing}')
    return rig, rec


def build(name, clips=None):
    rig, rec = load(name)
    out = []
    for clip in clips or ['Sleep', 'Wake', 'Run', 'Idle']:
        frames, loop = CLIPS[clip](rec)
        frames = [(t, grounded(rig, rec, p, clip)) for t, p in frames]
        out.append(write(rig, rec, name, clip, frames, loop))
    return out


if __name__ == '__main__':
    for p in build(sys.argv[1], sys.argv[2:] or None):
        print(p.name)
