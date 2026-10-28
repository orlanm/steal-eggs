#!/usr/bin/env python3
"""Give every Roblox store product (game passes + developer products) the icon the game shows for it.

  python3 _tools/shop/store_icons.py            # render + upload what is not done yet
  python3 _tools/shop/store_icons.py --render   # only render _tools/shop/store_icons/*.png
  python3 _tools/shop/store_icons.py --force    # re-upload everything

Source art is the place-saved UIArt set (copied to _tools/shop/game_art, same pixels as the live
asset ids). Tints copy the GUIs: treadmill upgrades use ShopGui's RARITY_TINT for the tier's rarity,
trails use TrailShopGui's TrailHero tinted by the trail's Figure colour or gradient.
Uploaded keys are saved to _tools/shop/store_icons.json so a re-run skips them."""
import json, math, struct, sys, time, uuid, zlib, urllib.request, urllib.error
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
UNIVERSE = 10770569453
ART = HERE / 'game_art'
OUT = HERE / 'store_icons'
STATE = HERE / 'store_icons.json'
PRODUCTS = json.loads((HERE / 'products.json').read_text())

WHITE = (255, 255, 255)
RARITY_TINT = {  # ShopGui RARITY_TINT
    'Uncommon': (120, 255, 120), 'Rare': (110, 190, 255), 'Epic': (200, 120, 255),
    'Legendary': (255, 214, 60), 'Mythic': (255, 90, 90), 'Cosmic': (150, 110, 255),
    'Secret': (120, 120, 130), 'Eternal': (255, 130, 220), 'Divine': (255, 240, 140),
}
# TreadmillProductIds: tier -> (product id, rarity)
TREADMILLS = {
    2: (3721186063, 'Uncommon'), 3: (3721252361, 'Rare'), 4: (3721252556, 'Epic'),
    5: (3721252364, 'Legendary'), 6: (3721252575, 'Mythic'), 7: (3721252583, 'Cosmic'),
    8: (3721252600, 'Secret'), 9: (3721252628, 'Eternal'), 10: (3721252639, 'Divine'),
}
RAINBOW = [(255, 235, 72), (255, 145, 66), (110, 255, 149), (74, 190, 255), (188, 94, 255)]
ZEBRA = [WHITE, (20, 26, 43), WHITE, (20, 26, 43), WHITE]
GALAXY = [(244, 120, 255), (117, 62, 224), (71, 205, 255)]
MOONBLOOM = [(132, 255, 205), (68, 208, 255), (196, 143, 255)]
# TrailProductIds + EconomyConfig Figure / Style (TrailShopGui gradients for the special styles)
TRAILS = {
    'Green': (3720154668, [(70, 210, 80)]), 'Blue': (3720154902, [(90, 170, 230)]),
    'Purple': (3720155033, [(150, 70, 240)]), 'Golden': (3720155131, [(255, 196, 40)]),
    'Red': (3720155233, [(210, 50, 50)]), 'Galaxy': (3720155317, GALAXY),
    'Secret': (3720155415, ZEBRA), 'Eternal': (3720155507, [(230, 90, 230)]),
    'Divine': (3720155590, RAINBOW), 'Moonbloom': (3720155706, MOONBLOOM),
}
SHOP_ICON = {'Growth': 'Stopwatch', 'Money': 'Coin', 'Speed': 'Sneaker'}


def items():
    """(state key, kind, id, art, tint colours)"""
    for k, pid in PRODUCTS.items():
        group, name = k.split('.')
        if group in ('Passes', 'Self'):
            art = SHOP_ICON[name]
        else:
            art = {'Gifts': 'Gift', 'Lucky': 'LuckyEgg', 'Cash': 'CashStack', 'Stars': 'Star'}[group]
        yield k, 'pass' if group == 'Passes' else 'product', pid, art, [WHITE]
    for tier, (pid, rarity) in TREADMILLS.items():
        yield f'Treadmill.{tier}', 'product', pid, 'Treadmill', [RARITY_TINT[rarity]]
    for name, (pid, colours) in TRAILS.items():
        yield f'Trail.{name}', 'product', pid, 'TrailHero', colours


# PNG ----------------------------------------------------------------------------------------------

def read_png(path):
    d = path.read_bytes()
    i, idat = 8, b''
    while i < len(d):
        ln, = struct.unpack('>I', d[i:i + 4])
        t, c = d[i + 4:i + 8], d[i + 8:i + 8 + ln]
        if t == b'IHDR':
            w, h, depth, ctype = struct.unpack('>IIBB', c[:10])
        elif t == b'IDAT':
            idat += c
        i += 12 + ln
    assert depth == 8 and ctype in (2, 6), (path, depth, ctype)
    bpp = 4 if ctype == 6 else 3
    raw, stride = zlib.decompress(idat), w * bpp
    prev, p, px = bytearray(stride), 0, []
    for _ in range(h):
        f, line = raw[p], bytearray(raw[p + 1:p + 1 + stride])
        p += 1 + stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if f == 1:
                line[x] = (line[x] + a) & 255
            elif f == 2:
                line[x] = (line[x] + b) & 255
            elif f == 3:
                line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        row = [tuple(line[x:x + bpp]) + ((255,) if bpp == 3 else ()) for x in range(0, stride, bpp)]
        px.append(row)
        prev = line
    return w, h, px


def write_png(path, w, h, px):
    raw = b''.join(b'\x00' + bytes(v for p in row for v in p) for row in px)
    def chunk(t, c):
        return struct.pack('>I', len(c)) + t + c + struct.pack('>I', zlib.crc32(t + c) & 0xffffffff)
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
                     + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))


def tint_at(colours, x, y, w, h):
    if len(colours) == 1:
        return colours[0]
    # UIGradient Rotation 35 across the image box
    r = math.radians(35)
    u = ((x / (w - 1) - .5) * math.cos(r) + (y / (h - 1) - .5) * math.sin(r)) / (math.cos(r) + math.sin(r)) + .5
    s = min(max(u, 0), 1) * (len(colours) - 1)
    i = min(int(s), len(colours) - 2)
    t = s - i
    a, b = colours[i], colours[i + 1]
    return tuple(round(a[k] + (b[k] - a[k]) * t) for k in range(3))


def render(key, art, colours):
    w, h, px = read_png(ART / f'{art}.png')
    out = [[(*(round(p[k] * tint_at(colours, x, y, w, h)[k] / 255) for k in range(3)), p[3])
            for x, p in enumerate(row)] for y, row in enumerate(px)]
    path = OUT / f'{key}.png'
    write_png(path, w, h, out)
    return path


# Open Cloud ---------------------------------------------------------------------------------------

def patch(url, image):
    boundary = uuid.uuid4().hex
    body = (f'--{boundary}\r\nContent-Disposition: form-data; name="imageFile"; filename="{image.name}"\r\n'
            f'Content-Type: image/png\r\n\r\n').encode() + image.read_bytes() + f'\r\n--{boundary}--\r\n'.encode()
    key = (ROOT / '.roblox_opencloud_key').read_text().strip()
    for attempt in range(5):
        req = urllib.request.Request(url, data=body, method='PATCH', headers={
            'x-api-key': key, 'Content-Type': f'multipart/form-data; boundary={boundary}'})
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                return r.status
        except urllib.error.HTTPError as e:
            msg = e.read().decode('utf-8', 'replace')
            if e.code == 429 or e.code >= 500:
                time.sleep(3 * (attempt + 1))
                continue
            raise RuntimeError(f'{e.code} {msg[:300]}')
    raise RuntimeError('gave up after retries')


def main():
    OUT.mkdir(exist_ok=True)
    state = json.loads(STATE.read_text()) if STATE.exists() and '--force' not in sys.argv else {}
    failed = []
    for key, kind, pid, art, colours in items():
        image = render(key, art, colours)
        if '--render' in sys.argv or key in state:
            continue
        if kind == 'pass':
            url = f'https://apis.roblox.com/game-passes/v1/universes/{UNIVERSE}/game-passes/{pid}'
        else:
            url = f'https://apis.roblox.com/developer-products/v2/universes/{UNIVERSE}/developer-products/{pid}'
        try:
            status = patch(url, image)
        except RuntimeError as e:
            print(f'FAILED {key} ({pid}): {e}')
            failed.append(key)
            continue
        state[key] = {'id': pid, 'art': art}
        STATE.write_text(json.dumps(state, indent=1))
        print(f'{key} ({pid}) <- {image.name}  [{status}]')
        time.sleep(0.5)
    if failed:
        sys.exit('not updated: ' + ', '.join(failed))


if __name__ == '__main__':
    main()
