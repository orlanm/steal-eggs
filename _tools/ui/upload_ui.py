#!/usr/bin/env python3
"""Upload _tools/ui/out/<Name>.png as private Images (ids in _tools/ui/ids.json).
python3 _tools/ui/upload_ui.py Studs [...]"""
import json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'pets'))
import upload  # noqa: E402

HERE = Path(__file__).resolve().parent
IDS = HERE / 'ids.json'
ids = json.loads(IDS.read_text()) if IDS.exists() else {}
for name in sys.argv[1:]:
    ids[name] = upload.create_asset('Image', f'BB UI {name}', 'Steal Baby Beasts UI texture', HERE / 'out' / f'{name}.png', 'image/png')
    print(name, ids[name])
    IDS.write_text(json.dumps(ids, indent=1))
