#!/usr/bin/env python3
"""Upload _assets/fuse-machine/FuseMachine.fbx as a Model asset (Open Cloud) and record the id.

  python3 _tools/fuse/upload_fuse.py [--force]
Built by _blender/fuse_machine.py. Id is saved in _tools/fuse/uploaded.json.
"""
import json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'pets'))
import upload  # reuses key / create_asset

ROOT = Path(__file__).resolve().parents[2]
FBX = ROOT / '_assets' / 'fuse-machine' / 'FuseMachine.fbx'
STATE = Path(__file__).with_name('uploaded.json')
state = json.loads(STATE.read_text()) if STATE.exists() else {}
if state.get('model') and '--force' not in sys.argv:
    print('already uploaded', state['model']); sys.exit()
state['model'] = upload.create_asset('Model', 'BB Fuse Machine', 'Steal Baby Beasts fuse machine', FBX, 'model/fbx')
STATE.write_text(json.dumps(state, indent=1))
print('uploaded', state['model'])
