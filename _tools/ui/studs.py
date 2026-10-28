#!/usr/bin/env python3
"""Render a tileable top-down 'Studs' overlay (like Roblox's Studs material) for GUI backgrounds.
White highlights + black shadows on transparency, so it tints whatever colour sits under it.
out/Studs.png: 2x2 studs per 128px tile (use ScaleType.Tile)."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

SS = 4                      # supersample
CELL = 64 * SS
N = 2
W = CELL * N

def layer():
    return Image.new('L', (W, W), 0)

shadow, light, top = layer(), layer(), layer()
ds, dl, dt = ImageDraw.Draw(shadow), ImageDraw.Draw(light), ImageDraw.Draw(top)
r = CELL * 0.30
off = CELL * 0.05
for i in range(N):
    for j in range(N):
        cx, cy = (i + .5) * CELL, (j + .5) * CELL
        # drop shadow down-right of the stud
        ds.ellipse([cx - r + off, cy - r + off * 1.6, cx + r + off, cy + r + off * 1.6], fill=150)
        # stud side: lit rim top-left
        dl.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
        # stud top face, nudged down-right so the rim reads as a lit edge
        rt = r * 0.80
        dt.ellipse([cx - rt + off * .5, cy - rt + off * .5, cx + rt + off * .5, cy + rt + off * .5], fill=255)
# plate seams between the 2x2 plates
seam = layer(); dsm = ImageDraw.Draw(seam)
for k in range(N + 1):
    dsm.line([(k * CELL, 0), (k * CELL, W)], fill=90, width=SS * 2)
    dsm.line([(0, k * CELL), (W, k * CELL)], fill=90, width=SS * 2)

from PIL import ImageChops
shadow = ImageChops.subtract(shadow.filter(ImageFilter.GaussianBlur(SS * 3)), light)  # only outside the stud
rgba = Image.new('RGBA', (W, W), (0, 0, 0, 0))
def comp(mask, rgb, alpha):
    a = mask.point(lambda v: int(v * alpha))
    rgba.alpha_composite(Image.merge('RGBA', (*[Image.new('L', (W, W), c) for c in rgb], a)))
comp(seam, (0, 0, 0), .55)
comp(shadow, (0, 0, 0), .9)
# stud side: white crescent on the lit (top-left) edge, dark crescent on the far edge
from PIL import ImageChops
lit = ImageChops.subtract(light, top.transform(top.size, Image.AFFINE, (1, 0, -off, 0, 1, -off)))
dark = ImageChops.subtract(light, top.transform(top.size, Image.AFFINE, (1, 0, off, 0, 1, off)))
comp(dark.filter(ImageFilter.GaussianBlur(SS)), (0, 0, 0), .45)
comp(lit.filter(ImageFilter.GaussianBlur(SS)), (255, 255, 255), .6)
comp(top, (255, 255, 255), .06)            # top face, barely lighter than the plate
out = Path(__file__).resolve().parent / 'out' / 'Studs.png'
rgba.resize((W // SS, W // SS), Image.LANCZOS).save(out)
# preview on the game's colours
prev = Image.new('RGBA', (512, 128))
for n, c in enumerate([(81, 190, 91), (32, 167, 223), (242, 172, 55), (60, 70, 110)]):
    tile = Image.new('RGBA', (128, 128), c + (255,)); tile.alpha_composite(Image.open(out)); prev.paste(tile, (n * 128, 0))
prev.save(out.with_name('Studs_preview.png'))
print(out)
