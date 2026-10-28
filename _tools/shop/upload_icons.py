#!/usr/bin/env python3
"""Upload _tools/shop/out/*.png as private Images and write src/shared/ShopArt.luau.
Already uploaded icons (ids.json) are skipped unless named:  python3 _tools/shop/upload_icons.py [Name ...]"""
import json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'pets'))
import upload  # noqa: E402

HERE = Path(__file__).resolve().parent
IDS = HERE / 'ids.json'
ids = json.loads(IDS.read_text()) if IDS.exists() else {}
force = set(sys.argv[1:])
for png in sorted((HERE / 'out').glob('*.png')):
    name = png.stem
    if name in ids and name not in force:
        continue
    ids[name] = upload.create_asset('Image', f'BB Shop {name}', 'Steal Baby Beasts shop icon', png, 'image/png')
    print(name, ids[name])
    IDS.write_text(json.dumps(ids, indent=1))
lines = ['-- Explorer: ReplicatedStorage.BabyBeastsShared.ShopArt', '-- Shop icons rendered by _tools/shop/icons.py (uploaded with _tools/shop/upload_icons.py).', 'return {']
lines += [f'\t{k} = "rbxassetid://{v}",' for k, v in sorted(ids.items())]
lines.append('}')
(HERE.parents[1] / 'src' / 'shared' / 'ShopArt.luau').write_text('\n'.join(lines) + '\n')
