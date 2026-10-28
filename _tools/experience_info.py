#!/usr/bin/env python3
"""Set the Roblox experience (universe 10770569453) and its root place (121962317867552) name + description.
  python3 _tools/experience_info.py
The API key in .roblox_opencloud_key needs the universe:write and universe.place:write scopes
(Creator Hub > Open Cloud > API Keys) with this experience added; assets-only keys get 403 "Scope not authorized".
"""
import json, sys, urllib.request, urllib.error
from pathlib import Path
KEY = (Path(__file__).resolve().parents[1] / '.roblox_opencloud_key').read_text().strip()
NAME = 'Steal Eggs'
DESC = ('Sneak into guarded beast dens across 23 biomes, steal their eggs and race them back to your pen before '
        'the sleeping guardians wake up! Hatch your eggs into pets that earn cash, train your speed on treadmills, '
        'unlock speed trails, fuse and ride your pets with Mount Stars, and hunt for ultra-rare Huge eggs.')
def patch(path):
    body = json.dumps({'displayName': NAME, 'description': DESC}).encode()
    req = urllib.request.Request(f'https://apis.roblox.com/cloud/v2/{path}?updateMask=displayName,description', data=body, method='PATCH',
                                 headers={'x-api-key': KEY, 'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(req) as r:
            d = json.load(r); print('OK', path, d.get('displayName'), '|', d.get('description'))
    except urllib.error.HTTPError as e:
        print('FAIL', path, e.code, e.read().decode()[:400])
patch('universes/10770569453')
patch('universes/10770569453/places/121962317867552')
