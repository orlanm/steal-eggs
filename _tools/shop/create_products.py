#!/usr/bin/env python3
"""Create the Shop's developer products and game passes on universe 10770569453 with Open Cloud, then
write src/shared/ShopProductIds.luau.

  python3 _tools/shop/create_products.py

Created ids are saved to _tools/shop/products.json after every call, so a re-run never creates a
product twice (Roblox products cannot be deleted, only taken off sale).
Needs developer-product:write (and game-pass:write for the passes) on the API key."""
import json, sys, time, uuid, urllib.request, urllib.error
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
UNIVERSE = 10770569453
STATE = HERE / 'products.json'
ICONS = HERE / 'out'

# key, kind, name, description, price, icon
ITEMS = [
    ('Passes.Growth', 'pass', 'x2 Growth', 'Eggs in your pen hatch x2 faster, forever.', 149, 'Stopwatch'),
    ('Passes.Money', 'pass', 'x2 Money', 'Your pets earn x2 money, forever.', 199, 'Coin'),
    ('Passes.Speed', 'pass', 'x2 Speed', 'Double your speed, forever.', 99, 'Sneaker'),
    # self-purchase products: used while the key cannot create game passes (game-pass:write)
    ('Self.Growth', 'product', 'x2 Growth', 'Eggs in your pen hatch x2 faster, forever.', 149, 'Stopwatch'),
    ('Self.Money', 'product', 'x2 Money', 'Your pets earn x2 money, forever.', 199, 'Coin'),
    ('Self.Speed', 'product', 'x2 Speed', 'Double your speed, forever.', 99, 'Sneaker'),
    ('Gifts.Growth', 'product', 'Gift: x2 Growth', 'Gift the x2 Growth pass to another player.', 149, 'Gift'),
    ('Gifts.Money', 'product', 'Gift: x2 Money', 'Gift the x2 Money pass to another player.', 199, 'Gift'),
    ('Gifts.Speed', 'product', 'Gift: x2 Speed', 'Gift the x2 Speed pass to another player.', 99, 'Gift'),
    ('Lucky.1', 'product', '1 Lucky Egg', 'One Lucky Egg: a rare egg from any biome.', 79, 'LuckyEgg'),
    ('Lucky.3', 'product', '3 Lucky Eggs', 'Three Lucky Eggs: rare eggs from any biome.', 199, 'LuckyEgg'),
    ('Lucky.5', 'product', '5 Lucky Eggs', 'Five Lucky Eggs: rare eggs from any biome. Best value!', 299, 'LuckyEgg'),
    ('Cash.Small', 'product', 'Cash Pack (Small)', '10 minutes of your pen income instantly.', 29, 'CashStack'),
    ('Cash.Medium', 'product', 'Cash Pack (Medium)', '1 hour of your pen income instantly.', 99, 'CashStack'),
    ('Cash.Large', 'product', 'Cash Pack (Large)', '6 hours of your pen income instantly. Best value!', 299, 'CashStack'),
    ('Stars.1', 'product', '1 Mount Star', 'Feed it to a pet in your pen and ride it as a mount!', 299, 'Star'),
    ('Stars.3', 'product', '3 Mount Stars', 'Three Mount Stars: turn three pets into mounts. Popular!', 699, 'Star'),
    ('Stars.5', 'product', '5 Mount Stars', 'Five Mount Stars: turn five pets into mounts. Best value!', 1099, 'Star'),
    # Growing Eggs panel (PenConfig): Grow All + per-egg Skip tiers by time left
    ('Grow.All', 'product', 'INSTANT GROW ALL!', 'Finish growing all the eggs in your pen.', 199, 'Stopwatch'),
    ('Grow.900', 'product', 'Instant Hatch (15m)', 'Skip the growth of your egg by up to 15 minutes!', 9, 'Stopwatch'),
    ('Grow.1800', 'product', 'Instant Hatch (30m)', 'Skip the growth of your egg by up to 30 minutes!', 19, 'Stopwatch'),
    ('Grow.3600', 'product', 'Instant Hatch (1h)', 'Skip the growth of your egg by up to 1 hour!', 29, 'Stopwatch'),
    # Vehicles section: owned forever, spawned from the hotbar on water
    ('Vehicles.Boat', 'product', 'Fishing Boat', 'Your own fishing boat! Equip it on water to sail anywhere.', 399, 'Boat'),
]


def key():
    # worktrees have no key file: fall back to the main checkout
    for path in (ROOT / '.roblox_opencloud_key', Path.home() / 'Desktop' / 'steal eggs' / '.roblox_opencloud_key'):
        if path.exists():
            return path.read_text().strip()
    sys.exit('missing .roblox_opencloud_key')


def post(url, fields, image):
    boundary = uuid.uuid4().hex
    body = b''
    for name, value in fields.items():
        body += f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode()
    body += (f'--{boundary}\r\nContent-Disposition: form-data; name="imageFile"; filename="{image.name}"\r\n'
             f'Content-Type: image/png\r\n\r\n').encode() + image.read_bytes() + b'\r\n'
    body += f'--{boundary}--\r\n'.encode()
    for attempt in range(5):
        req = urllib.request.Request(url, data=body, method='POST', headers={
            'x-api-key': key(), 'Content-Type': f'multipart/form-data; boundary={boundary}'})
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                return json.loads(r.read())
        except urllib.error.HTTPError as e:
            msg = e.read().decode('utf-8', 'replace')
            if e.code == 429 or e.code >= 500:
                time.sleep(3 * (attempt + 1))
                continue
            raise RuntimeError(f'{e.code} {msg[:300]}')
    raise RuntimeError('gave up after retries')


def main():
    state = json.loads(STATE.read_text()) if STATE.exists() else {}
    failed = []
    for k, kind, name, desc, price, icon in ITEMS:
        if k in state:
            continue
        fields = {'name': name, 'description': desc, 'isForSale': 'true', 'price': str(price)}
        if kind == 'pass':
            url = f'https://apis.roblox.com/game-passes/v1/universes/{UNIVERSE}/game-passes'
        else:
            url = f'https://apis.roblox.com/developer-products/v2/universes/{UNIVERSE}/developer-products'
        try:
            res = post(url, fields, ICONS / f'{icon}.png')
        except RuntimeError as e:
            print(f'FAILED {k}: {e}')
            failed.append(k)
            continue
        new_id = res.get('gamePassId') or res.get('productId') or res.get('id')
        if not new_id:
            print(f'FAILED {k}: no id in {json.dumps(res)[:300]}')
            failed.append(k)
            continue
        state[k] = int(new_id)
        STATE.write_text(json.dumps(state, indent=1))
        print(f'{k} = {new_id}  ({name}, {price} R$)')
        time.sleep(0.5)
    write_luau(state)
    if failed:
        sys.exit('not created: ' + ', '.join(failed))


def write_luau(state):
    def g(k):
        return state.get(k, 0)
    text = f"""--!strict
-- Explorer: ReplicatedStorage.BabyBeastsShared.ShopProductIds
-- Roblox dashboard ids for the Shop (universe {UNIVERSE}), created by _tools/shop/create_products.py.
-- 0 = not created yet: the button says so instead of prompting a purchase.
--   Passes: Game Passes bought for yourself (preferred when set).
--   Self:   Developer Products that unlock the pass for yourself, only used when Passes is 0
--           (taken off sale 2026-10-26 once the game passes existed; receipts still honoured).
--   Gifts:  Developer Products, one per pass, bought to give that pass to another player.
--   Lucky / Cash / Stars: Developer Products.
--   Grow: Growing Eggs panel (PenConfig): Grow All + Skip tiers keyed by seconds covered.
--   Vehicles: Developer Products for owned-forever vehicles (ShopConfig.Vehicles).
return {{
	Passes = {{ Growth = {g('Passes.Growth')}, Money = {g('Passes.Money')}, Speed = {g('Passes.Speed')} }},
	Self = {{ Growth = {g('Self.Growth')}, Money = {g('Self.Money')}, Speed = {g('Self.Speed')} }},
	Gifts = {{ Growth = {g('Gifts.Growth')}, Money = {g('Gifts.Money')}, Speed = {g('Gifts.Speed')} }},
	Lucky = {{ [1] = {g('Lucky.1')}, [3] = {g('Lucky.3')}, [5] = {g('Lucky.5')} }},
	Cash = {{ Small = {g('Cash.Small')}, Medium = {g('Cash.Medium')}, Large = {g('Cash.Large')} }},
	Stars = {{ [1] = {g('Stars.1')}, [3] = {g('Stars.3')}, [5] = {g('Stars.5')} }},
	Grow = {{ All = {g('Grow.All')}, [900] = {g('Grow.900')}, [1800] = {g('Grow.1800')}, [3600] = {g('Grow.3600')} }},
	Vehicles = {{ Boat = {g('Vehicles.Boat')} }},
}}
"""
    (ROOT / 'src' / 'shared' / 'ShopProductIds.luau').write_text(text)


if __name__ == '__main__':
    main()
