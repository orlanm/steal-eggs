"""Blender preview of a guard clip from guardanim.py's posed worlds (out/<Guard>_<Clip>.npz).
  blender -b --python preview.py -- <Guard> <Clip> [frames]
Builds a keyed proxy (boxes for Motor6D parts, sticks for bones; Roblox (x, y, z) -> Blender (x, -z, y)),
renders a side + three-quarter strip to preview/<Guard>_<Clip>.png and saves blend/<Guard>.blend
(one action per clip is appended on re-runs)."""
import bpy, sys, json, math
from pathlib import Path
import numpy as np
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
args = sys.argv[sys.argv.index('--') + 1:]
guard, clip = args[0], args[1]
nframes = int(args[2]) if len(args) > 2 else 6
data = np.load(HERE / 'out' / f'{guard}_{clip}.npz')
names = [str(n) for n in data['names']]
W = data['worlds']
rig = json.load(open(HERE / 'rigs' / f'{guard}.json'))
parts = {p['name']: p for p in rig['parts']}
bones = {b['name']: b for b in rig['bones']}
S = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
idx = {n: i for i, n in enumerate(names)}

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def mat(name, rgba):
    m = bpy.data.materials.new(name)
    m.diffuse_color = rgba
    return m


M_PART = mat('part', (0.75, 0.72, 0.68, 1))
M_BONE = mat('bone', (0.95, 0.55, 0.25, 1))
M_FLOOR = mat('floor', (0.45, 0.7, 0.4, 1))
objs = []
skinned = len(bones) > 0
for n in names:
    if n in parts and not skinned and parts[n]['transparency'] < 1:
        s = parts[n]['size']
        bpy.ops.mesh.primitive_cube_add(size=1)
        o = bpy.context.active_object
        o.scale = (s[0], s[2], s[1])
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        o.data.materials.append(M_PART)
        objs.append((n, o, None))
    elif n in bones:
        p = bones[n]['parent']
        if p in idx and p in bones:
            bpy.ops.mesh.primitive_cylinder_add(radius=1, depth=1, vertices=8)
            o = bpy.context.active_object
            o.data.materials.append(M_BONE)
            objs.append((n, o, p))
        bpy.ops.mesh.primitive_uv_sphere_add(radius=1, segments=8, ring_count=6)
        o = bpy.context.active_object
        o.data.materials.append(M_BONE)
        objs.append((n, o, 'dot'))

size = float(max(rig['bbox']['size']))
rad = size * 0.012
F = W.shape[0]
for f in range(F):
    for n, o, p in objs:
        m = S @ Matrix(W[f][idx[n]].tolist()) @ S.transposed()
        if p is None:
            o.matrix_world = m
        elif p == 'dot':
            o.matrix_world = Matrix.Translation(m.translation) @ Matrix.Scale(rad * 1.6, 4)
        else:
            a = (S @ Matrix(W[f][idx[p]].tolist()) @ S.transposed()).translation
            b = m.translation
            d = b - a
            L = max(d.length, 1e-4)
            rot = d.to_track_quat('Z', 'Y').to_matrix().to_4x4()
            o.matrix_world = Matrix.Translation((a + b) / 2) @ rot @ Matrix.Diagonal((rad, rad, L, 1))
        o.keyframe_insert('location', frame=f)
        o.keyframe_insert('rotation_euler', frame=f)
        o.keyframe_insert('scale', frame=f)

ground = rig['bbox']['cf'][1] - rig['bbox']['size'][1] / 2
bpy.ops.mesh.primitive_plane_add(size=size * 3, location=(0, 0, ground))
bpy.context.active_object.data.materials.append(M_FLOOR)
cam = bpy.data.objects.new('Cam', bpy.data.cameras.new('Cam'))
scene.collection.objects.link(cam)
scene.camera = cam
cam.data.type = 'ORTHO'
cam.data.ortho_scale = size * 1.35
sun = bpy.data.objects.new('Sun', bpy.data.lights.new('Sun', 'SUN'))
sun.rotation_euler = (0.7, 0.2, 0.9)
scene.collection.objects.link(sun)
scene.world = bpy.data.worlds.new('W')
scene.world.color = (0.6, 0.65, 0.7)
try:
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.display.shading.color_type = 'MATERIAL'
except TypeError:
    pass
scene.render.resolution_x, scene.render.resolution_y = 300, 260
c = rig['bbox']['cf']
target = Vector((c[0], -c[2], c[1]))
views = {'side': Vector((1, 0, 0.12)), 'three': Vector((0.8, -0.7, 0.4))}
tmp = HERE / 'preview' / '_tmp'
tmp.mkdir(parents=True, exist_ok=True)
picks = sorted(set(int(round(i * (F - 1) / max(1, nframes - 1))) for i in range(nframes)))
shots = []
for vn, d in views.items():
    for f in picks:
        scene.frame_set(f)
        cam.location = target + d.normalized() * size * 3
        cam.rotation_euler = (target - cam.location).to_track_quat('-Z', 'Y').to_euler()
        path = tmp / f'{vn}_{f:03d}.png'
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        shots.append((vn, f, path))
# contact sheet
import bpy as _b
imgs = [_b.data.images.load(str(p)) for _, _, p in shots]
w, h = imgs[0].size
cols = len(picks)
sheet = _b.data.images.new('sheet', w * cols, h * len(views))
px = np.zeros((h * len(views), w * cols, 4), dtype=np.float32)
for k, img in enumerate(imgs):
    r, cidx = divmod(k, cols)
    a = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    px[(len(views) - 1 - r) * h:(len(views) - r) * h, cidx * w:(cidx + 1) * w] = a
sheet.pixels = px.ravel()
sheet.filepath_raw = str(HERE / 'preview' / f'{guard}_{clip}.png')
sheet.file_format = 'PNG'
sheet.save()
for _, _, p in shots:
    p.unlink()
(HERE / 'blend').mkdir(exist_ok=True)
scene.frame_start, scene.frame_end = 0, F - 1
bpy.ops.wm.save_as_mainfile(filepath=str(HERE / 'blend' / f'{guard}_{clip}.blend'))
print('PREVIEW OK', guard, clip, 'frames', F, 'picks', picks)
