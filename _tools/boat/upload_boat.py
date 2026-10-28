#!/usr/bin/env python3
"""Upload _assets/fishing-boat/FishingBoat.fbx as a Model asset (Open Cloud) and record the id.

  python3 _tools/boat/upload_boat.py [--force]
Built by _blender/fishing_boat.py. Id is saved in _tools/boat/uploaded.json.
_tools/pets and _assets are git-ignored and only live in the main checkout (~/Desktop/steal eggs).
"""
import json, sys
from pathlib import Path

MAIN = Path.home() / 'Desktop' / 'steal eggs'
sys.path.insert(0, str(MAIN / '_tools' / 'pets'))
import upload  # reuses key / create_asset

FBX = MAIN / '_assets' / 'fishing-boat' / 'FishingBoat.fbx'
STATE = Path(__file__).with_name('uploaded.json')
state = json.loads(STATE.read_text()) if STATE.exists() else {}
if state.get('model') and '--force' not in sys.argv:
    print('already uploaded', state['model']); sys.exit()
state['model'] = upload.create_asset('Model', 'Steal Eggs Fishing Boat', 'Steal Eggs fishing boat', FBX, 'model/fbx')
STATE.write_text(json.dumps(state, indent=1))
print('uploaded', state['model'])
