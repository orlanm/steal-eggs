#!/usr/bin/env python3
"""R15 riding pose (Steal an Egg rider: straddling, torso leaned forward ~25 deg, hands reaching forward to
the mount's neck) as a looping KeyframeSequence with a slow breathing sway, uploaded as an Animation.
  python3 _tools/mounts/rider_pose.py            (writes out/RiderPose.rbxmx, uploads once, patches MountConfig)
  python3 _tools/mounts/rider_pose.py --force    (re-upload)
Pose CFrames are Motor6D Transforms in the joint's C0 frame (R15 C0s are axis aligned): +X rotation swings a
limb that hangs down (-Y) forward (-Z)."""
import json, math, re, sys
import numpy as np
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / '_tools' / 'pets'))
from upload import create_asset

OUT = HERE / 'out'
STATE = HERE / 'uploaded.json'


def rot(rx=0.0, ry=0.0, rz=0.0):
    """CFrame.Angles(rx, ry, rz) in degrees (= Rx @ Ry @ Rz)."""
    a, b, c = map(math.radians, (rx, ry, rz))
    X = np.array([[1, 0, 0], [0, math.cos(a), -math.sin(a)], [0, math.sin(a), math.cos(a)]])
    Y = np.array([[math.cos(b), 0, math.sin(b)], [0, 1, 0], [-math.sin(b), 0, math.cos(b)]])
    Z = np.array([[math.cos(c), -math.sin(c), 0], [math.sin(c), math.cos(c), 0], [0, 0, 1]])
    return X @ Y @ Z


def cf(r, p=(0, 0, 0)):
    vals = dict(X=p[0], Y=p[1], Z=p[2], R00=r[0, 0], R01=r[0, 1], R02=r[0, 2], R10=r[1, 0], R11=r[1, 1], R12=r[1, 2],
                R20=r[2, 0], R21=r[2, 1], R22=r[2, 2])
    return ''.join(f'<{k}>{v:.6g}</{k}>' for k, v in vals.items())


# joint -> parent (R15 Motor6D tree, by Part1 name)
TREE = {'LowerTorso': 'HumanoidRootPart', 'UpperTorso': 'LowerTorso', 'Head': 'UpperTorso',
        'LeftUpperArm': 'UpperTorso', 'LeftLowerArm': 'LeftUpperArm', 'LeftHand': 'LeftLowerArm',
        'RightUpperArm': 'UpperTorso', 'RightLowerArm': 'RightUpperArm', 'RightHand': 'RightLowerArm',
        'LeftUpperLeg': 'LowerTorso', 'LeftLowerLeg': 'LeftUpperLeg', 'LeftFoot': 'LeftLowerLeg',
        'RightUpperLeg': 'LowerTorso', 'RightLowerLeg': 'RightUpperLeg', 'RightFoot': 'RightLowerLeg'}


def pose(t):
    """t in [0, 1): breathing sway on top of the riding pose."""
    s = math.sin(2 * math.pi * t)
    P = {
        'LowerTorso': (rot(-6 + 1.5 * s), (0, -0.05 * (1 + s) * 0.5, 0)),
        'UpperTorso': (rot(-19 - 2 * s), (0, 0, 0)),
        'Head': (rot(16 + 2 * s), (0, 0, 0)),                    # look ahead, not down
        'LeftUpperArm': (rot(62 + 3 * s, 0, -12), (0, 0, 0)),
        'RightUpperArm': (rot(62 + 3 * s, 0, 12), (0, 0, 0)),
        'LeftLowerArm': (rot(28), (0, 0, 0)),
        'RightLowerArm': (rot(28), (0, 0, 0)),
        'LeftHand': (rot(-10), (0, 0, 0)),
        'RightHand': (rot(-10), (0, 0, 0)),
        'LeftUpperLeg': (rot(58, 0, -28), (0, 0, 0)),            # thighs forward and spread round the back
        'RightUpperLeg': (rot(58, 0, 28), (0, 0, 0)),
        'LeftLowerLeg': (rot(-72, 0, 6), (0, 0, 0)),             # shins hang down the flanks
        'RightLowerLeg': (rot(-72, 0, -6), (0, 0, 0)),
        'LeftFoot': (rot(12), (0, 0, 0)),
        'RightFoot': (rot(12), (0, 0, 0)),
    }
    return P


def pose_xml(name, P, kids):
    r, p = P.get(name, (np.eye(3), (0, 0, 0)))
    inner = ''.join(pose_xml(k, P, kids) for k in kids.get(name, []))
    w = 0 if name == 'HumanoidRootPart' else 1
    return (f'<Item class="Pose"><Properties><CoordinateFrame name="CFrame">{cf(r, p)}</CoordinateFrame>'
            f'<token name="EasingDirection">0</token><token name="EasingStyle">0</token>'
            f'<string name="Name">{name}</string><float name="Weight">{w}</float></Properties>{inner}</Item>')


def build():
    kids = {}
    for c, p in TREE.items():
        kids.setdefault(p, []).append(c)
    frames = 8
    length = 3.2
    items = []
    for i in range(frames + 1):
        t = i / frames
        items.append(f'<Item class="Keyframe"><Properties><string name="Name">Keyframe</string>'
                     f'<float name="Time">{t * length:.4f}</float></Properties>{pose_xml("HumanoidRootPart", pose(t % 1), kids)}</Item>')
    xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" version="4">'
           '<Item class="KeyframeSequence"><Properties><string name="Name">RiderPose</string>'
           '<bool name="Loop">true</bool><token name="Priority">2</token></Properties>' + ''.join(items) + '</Item></roblox>')
    OUT.mkdir(exist_ok=True)
    path = OUT / 'RiderPose.rbxmx'
    path.write_text(xml)
    return path


def main():
    path = build()
    state = json.loads(STATE.read_text()) if STATE.exists() else {}
    if not state.get('RiderPose') or '--force' in sys.argv:
        state['RiderPose'] = create_asset('Animation', 'BB Rider Pose', 'Steal Baby Beasts: R15 riding pose for pet mounts', path, 'model/x-rbxm')
        STATE.write_text(json.dumps(state, indent=1))
    cfg = ROOT / 'src' / 'shared' / 'MountConfig.luau'
    t = cfg.read_text()
    t = re.sub(r'MountConfig\.RiderAnimation = \d+', f"MountConfig.RiderAnimation = {state['RiderPose']}", t)
    cfg.write_text(t)
    print('RiderPose', state['RiderPose'])


if __name__ == '__main__':
    main()
