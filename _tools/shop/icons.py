"""Shop icon renders (cartoon look, black outline, transparent background).

  /Applications/Blender.app/Contents/MacOS/Blender -b -P _tools/shop/icons.py -- [names...]

Writes _tools/shop/out/<Name>.png (512x512). Upload with _tools/shop/upload_icons.py.
"""
import bpy, bmesh, math, sys
from mathutils import Vector
from pathlib import Path

OUT = Path(__file__).resolve().parent / 'out'
OUT.mkdir(exist_ok=True)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    try:
        s.render.engine = 'BLENDER_EEVEE'
    except TypeError:
        s.render.engine = 'BLENDER_EEVEE_NEXT'
    s.render.resolution_x = s.render.resolution_y = 512
    s.render.film_transparent = True
    s.render.image_settings.file_format = 'PNG'
    s.render.image_settings.color_mode = 'RGBA'
    s.view_settings.view_transform = 'Standard'
    s.render.use_freestyle = False
    s.render.line_thickness_mode = 'ABSOLUTE'
    s.render.line_thickness = 7
    vl = s.view_layers[0]
    vl.use_freestyle = True
    fs = vl.freestyle_settings
    ls = fs.linesets[0] if fs.linesets else fs.linesets.new('Lines')
    ls.select_by_visibility = True
    ls.select_by_edge_types = True
    for k in ('select_silhouette', 'select_border', 'select_external_contour'):
        setattr(ls, k, True)
    for k in ('select_crease', 'select_material_boundary'):
        setattr(ls, k, False)
    if ls.linestyle is None:
        ls.linestyle = bpy.data.linestyles.new('Ink')
    ls.linestyle.color = (0.03, 0.03, 0.05)
    ls.linestyle.thickness = 7
    w = bpy.data.worlds.new('W')
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == 'BACKGROUND')
    bg.inputs[0].default_value = (1, 1, 1, 1)
    bg.inputs[1].default_value = 0.9
    s.world = w
    for rot, energy in (((50, 10, -35), 3.2), ((-30, -20, 140), 1.2)):
        d = bpy.data.lights.new('Sun', 'SUN')
        d.energy = energy
        o = bpy.data.objects.new('Sun', d)
        o.rotation_euler = [math.radians(a) for a in rot]
        s.collection.objects.link(o)


MATS = {}


def mat(rgb, rough=0.45, metal=0.0, emit=0.0):
    key = (rgb, rough, metal, emit)
    if key in MATS:
        return MATS[key]
    m = bpy.data.materials.new('M')
    m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    c = tuple(pow(v / 255, 2.2) for v in rgb) + (1,)
    p.inputs['Base Color'].default_value = c
    p.inputs['Roughness'].default_value = rough
    p.inputs['Metallic'].default_value = metal
    if emit:
        p.inputs['Emission Color'].default_value = c
        p.inputs['Emission Strength'].default_value = emit
    MATS[key] = m
    return m


def finish(o, rgb, bevel=0.0, smooth=True, **kw):
    o.data.materials.append(mat(rgb, **kw))
    if bevel:
        b = o.modifiers.new('B', 'BEVEL')
        b.width = bevel
        b.segments = 4
        b.limit_method = 'ANGLE'
    if smooth and o.type == 'MESH':
        for poly in o.data.polygons:
            poly.use_smooth = True
    return o


def box(size, loc, rgb, bevel=0.06, rot=(0, 0, 0), **kw):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = Vector(size) / 2
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, rgb, bevel, smooth=False, **kw)


def cyl(r, depth, loc, rgb, rot=(0, 0, 0), verts=48, bevel=0.04, **kw):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, location=loc, rotation=rot, vertices=verts)
    return finish(bpy.context.object, rgb, bevel, smooth=False, **kw)


def sphere(r, loc, rgb, scale=(1, 1, 1), **kw):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=48, ring_count=24)
    o = bpy.context.object
    o.scale = scale
    return finish(o, rgb, **kw)


def torus(R, r, loc, rgb, rot=(0, 0, 0), **kw):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, location=loc, rotation=rot, major_segments=48, minor_segments=16)
    return finish(bpy.context.object, rgb, **kw)


def text(body, size, loc, rgb, depth=0.08, rot=(math.radians(90), 0, 0), **kw):
    bpy.ops.object.text_add(location=loc, rotation=rot)
    o = bpy.context.object
    o.data.body = body
    o.data.size = size
    o.data.extrude = depth
    o.data.bevel_depth = 0.015
    o.data.align_x = 'CENTER'
    o.data.align_y = 'CENTER'
    o.data.materials.append(mat(rgb, **kw))
    return o


def star_mesh(R, r, depth, loc, rgb, rot=(math.radians(90), 0, 0), **kw):
    bm = bmesh.new()
    pts = []
    for i in range(10):
        a = math.pi / 2 + i * math.pi / 5
        rad = R if i % 2 == 0 else r
        pts.append(bm.verts.new((math.cos(a) * rad, math.sin(a) * rad, 0)))
    f = bm.faces.new(pts)
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    for v in ext['geom']:
        if isinstance(v, bmesh.types.BMVert):
            v.co.z += depth
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new('Star')
    bm.to_mesh(me)
    o = bpy.data.objects.new('Star', me)
    bpy.context.scene.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = rot
    bpy.context.view_layer.objects.active = o
    finish(o, rgb, bevel=0.05, smooth=False, **kw)
    return o


def egg(r, loc, rgb, **kw):
    o = sphere(r, loc, rgb, scale=(1, 1, 1.28), **kw)
    for v in o.data.vertices:
        if v.co.z > 0:
            f = 1 - 0.22 * (v.co.z / r)
            v.co.x *= f
            v.co.y *= f
    return o


def outline(width):
    ink = bpy.data.materials.new('Ink')
    ink.use_nodes = True
    nt = ink.node_tree
    nt.nodes.clear()
    em = nt.nodes.new('ShaderNodeEmission')
    em.inputs[0].default_value = (0.012, 0.012, 0.02, 1)
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    nt.links.new(em.outputs[0], out.inputs[0])
    ink.use_backface_culling = True
    try:
        ink.use_backface_culling_shadow = True
    except AttributeError:
        pass
    for o in list(bpy.context.scene.objects):
        if o.type == 'FONT':
            bpy.context.view_layer.objects.active = o
            for x in bpy.context.selected_objects:
                x.select_set(False)
            o.select_set(True)
            bpy.ops.object.convert(target='MESH')
            o = bpy.context.object
        if o.type != 'MESH':
            continue
        o.data.materials.append(ink)
        m = o.modifiers.new('Outline', 'SOLIDIFY')
        m.thickness = width
        m.offset = 1
        m.use_flip_normals = True
        m.use_rim = False
        m.material_offset = len(o.data.materials) - 1


def shoot(name, view=(0.9, -2.2, 1.1), pad=1.12, line=0.07):
    s = bpy.context.scene
    bpy.context.view_layer.update()
    outline(line)
    bpy.context.view_layer.update()
    pts = []
    for o in s.objects:
        if o.type in ('MESH', 'FONT'):
            pts += [o.matrix_world @ Vector(c) for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    center = (lo + hi) / 2
    cam = bpy.data.cameras.new('Cam')
    cam.type = 'ORTHO'
    co = bpy.data.objects.new('Cam', cam)
    s.collection.objects.link(co)
    d = Vector(view).normalized()
    co.location = center + d * 30
    co.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
    bpy.context.view_layer.update()
    inv = co.matrix_world.inverted()
    local = [inv @ p for p in pts]
    w = max(p.x for p in local) - min(p.x for p in local)
    h = max(p.y for p in local) - min(p.y for p in local)
    cx = (max(p.x for p in local) + min(p.x for p in local)) / 2
    cy = (max(p.y for p in local) + min(p.y for p in local)) / 2
    co.location = co.matrix_world @ Vector((cx, cy, 0))
    cam.ortho_scale = max(w, h) * pad
    s.camera = co
    s.render.filepath = str(OUT / f'{name}.png')
    bpy.ops.render.render(write_still=True)
    print('wrote', name)


R = math.radians
GOLD = (255, 196, 30)
WHITE = (245, 245, 250)


def Cart():
    body = (255, 210, 40)
    # basket: open tray with slats
    box((2.4, 1.5, 0.12), (0, 0, 0.35), body)
    box((2.6, 0.12, 1.3), (0, -0.75, 1.0), body, rot=(R(-8), 0, 0))
    box((2.6, 0.12, 1.3), (0, 0.75, 1.0), body, rot=(R(8), 0, 0))
    box((0.12, 1.7, 1.3), (1.28, 0, 1.0), body, rot=(0, R(10), 0))
    box((0.12, 1.7, 1.3), (-1.28, 0, 1.0), body, rot=(0, R(-14), 0))
    for z in (0.75, 1.15):
        box((2.62, 1.6, 0.06), (0, 0, z), (230, 160, 20), bevel=0.02)
    cyl(0.09, 1.2, (-1.55, 0, 1.75), (220, 40, 40), rot=(R(90), 0, 0))
    box((0.12, 0.12, 0.9), (-1.45, -0.6, 1.4), (200, 200, 210), rot=(0, R(-14), 0))
    box((0.12, 0.12, 0.9), (-1.45, 0.6, 1.4), (200, 200, 210), rot=(0, R(-14), 0))
    for x in (-0.9, 0.9):
        cyl(0.28, 0.2, (x, -0.65, 0.0), (40, 40, 48), rot=(R(90), 0, 0))
        cyl(0.12, 0.22, (x, -0.65, 0.0), (200, 200, 210), rot=(R(90), 0, 0))
    shoot('Cart', view=(0.35, -2.2, 0.9))


def Gift():
    purple, ribbon = (170, 70, 255), (255, 214, 50)
    box((2, 2, 1.6), (0, 0, 0.8), purple, bevel=0.08)
    box((2.2, 2.2, 0.5), (0, 0, 1.75), (190, 100, 255), bevel=0.08)
    box((0.42, 2.24, 2.04), (0, 0, 1.0), ribbon, bevel=0.04)
    box((2.24, 0.42, 2.04), (0, 0, 1.0), ribbon, bevel=0.04)
    torus(0.42, 0.14, (-0.38, 0, 2.25), ribbon, rot=(R(90), R(25), 0))
    torus(0.42, 0.14, (0.38, 0, 2.25), ribbon, rot=(R(90), R(-25), 0))
    sphere(0.18, (0, 0, 2.08), ribbon)
    shoot('Gift')


def Stopwatch():
    cyl(1.3, 0.45, (0, 0, 0), (60, 200, 90), rot=(R(90), 0, 0))
    cyl(1.08, 0.5, (0, -0.02, 0), WHITE, rot=(R(90), 0, 0))
    cyl(0.25, 0.4, (0, 0, 1.45), (60, 200, 90), rot=(0, 0, 0))
    box((0.7, 0.4, 0.25), (0, 0, 1.75), (220, 50, 50), bevel=0.06)
    box((0.3, 0.3, 0.35), (1.05, 0, 1.0), (220, 50, 50), rot=(0, R(-40), 0))
    for i in range(12):
        a = R(i * 30)
        box((0.07, 0.05, 0.2 if i % 3 else 0.3), (math.sin(a) * 0.88, -0.28, math.cos(a) * 0.88), (40, 40, 48), bevel=0.01, rot=(0, a, 0))
    box((0.1, 0.05, 0.8), (0.2, -0.3, 0.3), (40, 40, 48), bevel=0.02, rot=(0, R(35), 0))
    box((0.1, 0.05, 0.55), (-0.2, -0.3, 0.12), (220, 50, 50), bevel=0.02, rot=(0, R(-60), 0))
    cyl(0.12, 0.1, (0, -0.32, 0), (40, 40, 48), rot=(R(90), 0, 0))
    shoot('Stopwatch', view=(0.5, -2.2, 0.6))


def Coin():
    cyl(1.3, 0.35, (0, 0, 0), GOLD, rot=(R(90), 0, 0), metal=0.3, rough=0.3)
    cyl(1.05, 0.4, (0, 0, 0), (255, 220, 70), rot=(R(90), 0, 0), metal=0.3, rough=0.3)
    text('$', 1.6, (0, -0.22, -0.05), (240, 170, 20), depth=0.06, metal=0.3)
    shoot('Coin', view=(0.5, -2.2, 0.5))


def CashStack():
    green, dark = (110, 210, 80), (60, 150, 50)
    for i, (x, y, rz) in enumerate(((0, 0, 0), (0.1, 0.05, 6), (-0.08, -0.04, -5), (0.05, 0.02, 3), (0, 0, -2))):
        box((2.6, 1.3, 0.16), (x, y, 0.16 + i * 0.18), green if i % 2 == 0 else (130, 225, 95), bevel=0.03, rot=(0, 0, R(rz)))
    box((0.5, 1.36, 0.95), (0, 0, 0.55), (255, 214, 50), bevel=0.03)
    cyl(0.32, 0.06, (0.85, 0, 1.02), dark, bevel=0.01)
    cyl(0.32, 0.06, (-0.85, 0, 1.02), dark, bevel=0.01)
    shoot('CashStack', view=(0.8, -2.0, 1.6))


def Sneaker():
    blue, white = (40, 140, 255), WHITE
    box((2.8, 1.1, 0.35), (0, 0, 0.18), white, bevel=0.15)
    box((2.75, 1.05, 0.12), (0, 0, 0.02), (60, 60, 70), bevel=0.05)
    s = sphere(1, (-0.35, 0, 0.75), blue, scale=(1.3, 0.55, 0.62))
    sphere(1, (0.75, 0, 0.5), blue, scale=(0.75, 0.52, 0.38))
    box((0.8, 1.0, 0.85), (-1.0, 0, 1.0), blue, bevel=0.25)
    box((0.85, 1.04, 0.22), (-1.0, 0, 1.45), white, bevel=0.08)
    for i in range(3):
        box((0.12, 0.9, 0.08), (0.05 + i * 0.3, -0.06, 0.95 - i * 0.1), white, bevel=0.03, rot=(0, R(-25), 0))
    star_mesh(0.28, 0.12, 0.06, (-0.4, -0.56, 0.7), (255, 214, 50))
    shoot('Sneaker', view=(0.25, -2.2, 0.7))


def LuckyEgg():
    egg(1.0, (0, 0, 1.05), (255, 205, 40), metal=0.35, rough=0.25)
    star_mesh(0.42, 0.18, 0.12, (0, -0.95, 1.05), (255, 245, 170), emit=0.4)
    for x, z, s in ((-1.1, 2.2, 0.22), (1.15, 1.8, 0.16), (-1.0, 0.4, 0.13)):
        star_mesh(s, s * 0.45, 0.06, (x, -0.2, z), (255, 250, 200), emit=1.0)
    shoot('LuckyEgg', view=(0.3, -2.2, 0.5))


def Star():
    star_mesh(1.3, 0.58, 0.45, (0, 0, 0), (255, 210, 30), rough=0.3)
    shoot('Star', view=(0.35, -2.2, 0.4))


def Tag():
    red = (240, 60, 70)
    bm = bmesh.new()
    pts = [(-1.2, -0.7), (0.8, -0.7), (1.4, 0), (0.8, 0.7), (-1.2, 0.7)]
    f = bm.faces.new([bm.verts.new((x, y, 0)) for x, y in pts])
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    for v in ext['geom']:
        if isinstance(v, bmesh.types.BMVert):
            v.co.z += 0.25
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new('Tag')
    bm.to_mesh(me)
    o = bpy.data.objects.new('Tag', me)
    bpy.context.scene.collection.objects.link(o)
    o.rotation_euler = (R(90), 0, R(0))
    o.location = (0, 0.12, 0)
    bpy.context.view_layer.objects.active = o
    finish(o, red, bevel=0.08, smooth=False)
    cyl(0.14, 0.4, (0.85, 0, 0), WHITE, rot=(R(90), 0, 0))
    text('%', 1.0, (-0.25, -0.16, -0.02), WHITE, depth=0.05)
    root = bpy.data.objects.new('Root', None)
    for ob in list(bpy.context.scene.objects):
        if ob.type in ('MESH', 'FONT'):
            ob.parent = root
    bpy.context.scene.collection.objects.link(root)
    root.rotation_euler = (0, R(-30), 0)
    shoot('Tag', view=(0.3, -2.2, 0.4))


def Treadmill():
    base, belt = (235, 235, 240), (50, 52, 60)
    box((3.2, 1.6, 0.35), (0, 0, 0.2), base, bevel=0.1)
    box((3.0, 1.25, 0.1), (0, 0, 0.42), belt, bevel=0.03)
    for y in (-0.72, 0.72):
        box((0.16, 0.16, 1.8), (-1.3, y, 1.2), base, bevel=0.05, rot=(0, R(-12), 0))
        box((1.2, 0.14, 0.14), (-0.75, y, 1.55), base, bevel=0.05)
    box((0.5, 1.7, 0.7), (-1.5, 0, 2.15), base, bevel=0.12, rot=(0, R(-25), 0))
    box((0.1, 1.2, 0.45), (-1.27, 0, 2.2), (60, 200, 255), bevel=0.04, rot=(0, R(-25), 0), emit=0.6)
    shoot('Treadmill', view=(1.4, -2.2, 1.0))


ALL = [Cart, Gift, Stopwatch, Coin, CashStack, Sneaker, LuckyEgg, Star, Tag, Treadmill]

if __name__ == '__main__':
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    for fn in ALL:
        if argv and fn.__name__ not in argv:
            continue
        reset()
        MATS.clear()
        fn()
