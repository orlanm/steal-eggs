#!/usr/bin/env python3
"""Render the pet-row sun-ray burst to _tools/ui/out/SunRays.png (white, alpha-faded; tinted in-game).
python3 _tools/ui/sunrays.py && python3 _tools/ui/upload_ui.py SunRays"""
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

SIZE, RAYS = 512, 16
out = Path(__file__).resolve().parent / 'out' / 'SunRays.png'
c = SIZE / 2
rays = Image.new('L', (SIZE, SIZE), 0)
d = ImageDraw.Draw(rays)
for i in range(RAYS):
    a0 = (i / RAYS) * 2 * math.pi
    a1 = a0 + math.pi / RAYS * 0.9
    r = SIZE
    d.polygon([(c, c), (c + r * math.cos(a0), c + r * math.sin(a0)), (c + r * math.cos(a1), c + r * math.sin(a1))], fill=255)
rays = rays.filter(ImageFilter.GaussianBlur(3))
# fade out towards the edge, with a soft bright core
fade = Image.new('L', (SIZE, SIZE), 0)
px = fade.load()
for y in range(SIZE):
    for x in range(SIZE):
        t = math.hypot(x - c, y - c) / c
        px[x, y] = int(255 * max(0.0, 1 - t) ** 1.3)
alpha = Image.new('L', (SIZE, SIZE))
ra, fa = rays.load(), fade.load()
al = alpha.load()
for y in range(SIZE):
    for x in range(SIZE):
        core = max(0.0, 1 - math.hypot(x - c, y - c) / (c * 0.35))
        al[x, y] = min(255, int(ra[x, y] * fa[x, y] / 255 * 0.85 + 200 * core ** 2))
img = Image.merge('RGBA', (Image.new('L', (SIZE, SIZE), 255),) * 3 + (alpha,))
out.parent.mkdir(exist_ok=True)
img.save(out)
print(out)
