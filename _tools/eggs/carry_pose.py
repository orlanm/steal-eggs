#!/usr/bin/env python3
"""R15 two-handed egg carry (Steal an Egg style): both forearms held level in front of the chest, palms up,
the egg resting on them. Arms only, so the legs keep the normal walk / run. Looping Action priority with a
light bob. Uploaded as an Animation; the id goes to src/shared/EggScale.luau (EggScale.CarryAnimation).
  python3 _tools/eggs/carry_pose.py           (writes out/EggCarry.rbxmx, uploads once, patches EggScale)
  python3 _tools/eggs/carry_pose.py --force   (re-upload)"""
import json, math, re, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / '_tools' / 'mounts'))
sys.path.insert(0, str(ROOT / '_tools' / 'pets'))
from rider_pose import rot, cf  # noqa: E402  (same Motor6D Transform conventions)
from upload import create_asset  # noqa: E402

OUT = HERE / 'out'
STATE = HERE / 'uploaded.json'

# only the arms are animated; the torso chain is present with weight 0 so the walk keeps it
TREE = {'LowerTorso': 'HumanoidRootPart', 'UpperTorso': 'LowerTorso',
        'LeftUpperArm': 'UpperTorso', 'LeftLowerArm': 'LeftUpperArm', 'LeftHand': 'LeftLowerArm',
        'RightUpperArm': 'UpperTorso', 'RightLowerArm': 'RightUpperArm', 'RightHand': 'RightLowerArm'}
ANIMATED = {'LeftUpperArm', 'LeftLowerArm', 'LeftHand', 'RightUpperArm', 'RightLowerArm', 'RightHand'}


def pose(t):
    s = math.sin(2 * math.pi * t)
    return {
        # upper arms forward, elbows by the ribs; forearms reach forward to either side of the egg
        'LeftUpperArm': rot(20 + 2 * s, 0, 14),
        'RightUpperArm': rot(20 + 2 * s, 0, -14),
        'LeftLowerArm': rot(68 - 2 * s),
        'RightLowerArm': rot(68 - 2 * s),
        # palms turned in against the shell
        'LeftHand': rot(8, 0, 30),
        'RightHand': rot(8, 0, -30),
    }


def pose_xml(name, P, kids):
    import numpy as np
    r = P.get(name, np.eye(3))
    inner = ''.join(pose_xml(k, P, kids) for k in kids.get(name, []))
    w = 1 if name in ANIMATED else 0
    return (f'<Item class="Pose"><Properties><CoordinateFrame name="CFrame">{cf(r)}</CoordinateFrame>'
            f'<token name="EasingDirection">0</token><token name="EasingStyle">0</token>'
            f'<string name="Name">{name}</string><float name="Weight">{w}</float></Properties>{inner}</Item>')


def build():
    kids = {}
    for c, p in TREE.items():
        kids.setdefault(p, []).append(c)
    frames, length = 6, 2.4
    items = []
    for i in range(frames + 1):
        t = i / frames
        items.append(f'<Item class="Keyframe"><Properties><string name="Name">Keyframe</string>'
                     f'<float name="Time">{t * length:.4f}</float></Properties>{pose_xml("HumanoidRootPart", pose(t % 1), kids)}</Item>')
    xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" version="4">'
           '<Item class="KeyframeSequence"><Properties><string name="Name">EggCarry</string>'
           '<bool name="Loop">true</bool><token name="Priority">2</token></Properties>' + ''.join(items) + '</Item></roblox>')
    OUT.mkdir(exist_ok=True)
    path = OUT / 'EggCarry.rbxmx'
    path.write_text(xml)
    return path


def main():
    path = build()
    state = json.loads(STATE.read_text()) if STATE.exists() else {}
    if '--build-only' in sys.argv:
        print(path)
        return
    if not state.get('EggCarry') or '--force' in sys.argv:
        state['EggCarry'] = create_asset('Animation', 'BB Egg Carry', 'Steal Baby Beasts: R15 two-handed egg carry', path, 'model/x-rbxm')
        STATE.write_text(json.dumps(state, indent=1))
    cfg = ROOT / 'src' / 'shared' / 'EggScale.luau'
    t = cfg.read_text()
    t = re.sub(r'EggScale\.CarryAnimation = \d+', f"EggScale.CarryAnimation = {state['EggCarry']}", t)
    cfg.write_text(t)
    print('EggCarry', state['EggCarry'])


if __name__ == '__main__':
    main()
