# Fishing Boat for Steal Eggs (low-poly reference: red/white/blue hull, grey deck, glass fish tank
# with an open lid at the bow, white console + steering wheel + red chair at the stern).
# Builds into its own scene "FishingBoat" (the open scene is left alone) and exports
# _assets/fishing-boat/FishingBoat.fbx. Units are studs (1 Blender unit = 1 stud), Z up,
# bow faces -Y, waterline is z = 0 (hull bottom sits at z = -1.6).
#
# Run in Blender: exec(open("<project>/_blender/fishing_boat.py").read())
#
# Object names start with a colour group (Red_, White_, Blue_, Deck_, Dark_, Glass_, Navy_, Grey_,
# Black_, Seat_). Studio restyles each part from that prefix after import (_tools/boat/assemble.luau).

import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.path.expanduser(
    "~/Desktop/steal eggs/_blender")
OUT_DIR = os.path.abspath(os.path.join(HERE, "..", "_assets", "fishing-boat"))
OUT_FBX = os.path.join(OUT_DIR, "FishingBoat.fbx")

COLORS = {
    "Red": (0.78, 0.10, 0.10),
    "White": (0.95, 0.95, 0.95),
    "Blue": (0.10, 0.36, 0.86),
    "Deck": (0.72, 0.74, 0.76),
    "Dark": (0.22, 0.23, 0.26),
    "Glass": (0.55, 0.80, 1.00),
    "Navy": (0.10, 0.14, 0.32),
    "Grey": (0.55, 0.57, 0.60),
    "Black": (0.05, 0.05, 0.06),
    "Seat": (0.85, 0.12, 0.12),
}
BEVEL = {"Dark": 0.12, "White": 0.12, "Seat": 0.15, "Grey": 0.06}

# Deck outline (clockwise from the stern, port side first), bow at -Y.
OUTLINE = [(-5.0, 12.0), (5.0, 12.0), (5.0, -2.5), (3.4, -8.6), (1.0, -12.2), (-1.0, -12.2),
           (-3.4, -8.6), (-5.0, -2.5)]
DECK_Z = 1.6  # deck top above the waterline

scene = None
coll = None
mats = {}


def setup():
    global scene, coll
    old = bpy.data.scenes.get("FishingBoat")
    if old:
        for o in list(old.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.scenes.remove(old)
    scene = bpy.data.scenes.new("FishingBoat")
    scene.unit_settings.system = "METRIC"
    coll = scene.collection
    for name, rgb in COLORS.items():
        m = bpy.data.materials.get("FB_" + name) or bpy.data.materials.new("FB_" + name)
        m.use_nodes = True
        bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = (*rgb, 1)
        if name == "Glass":
            bsdf.inputs["Alpha"].default_value = 0.4
        m.diffuse_color = (*rgb, 0.4 if name == "Glass" else 1)
        mats[name] = m


def bake(obj):
    win_scene = bpy.context.window.scene if bpy.context.window else None
    linked = False
    if win_scene and obj.name not in win_scene.collection.all_objects:
        win_scene.collection.objects.link(obj)
        linked = True
    deps = bpy.context.evaluated_depsgraph_get()
    deps.update()
    new = bpy.data.meshes.new_from_object(obj.evaluated_get(deps))
    old = obj.data
    obj.modifiers.clear()
    obj.data = new
    bpy.data.meshes.remove(old)
    if linked:
        win_scene.collection.objects.unlink(obj)


def finish(name, bm, matrix=None, bevel=True):
    group = name.split("_")[0]
    if matrix is not None:
        bm.transform(matrix)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mats[group])
    obj = bpy.data.objects.new(name, me)
    coll.objects.link(obj)
    width = BEVEL.get(group)
    if bevel and width:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = width
        mod.segments = 2
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(35)
        bake(obj)
    return obj


def offset(points, d):
    """Polygon offset (positive d = outward) with mitred corners."""
    n = len(points)
    out = []
    for i in range(n):
        p0, p1, p2 = Vector(points[i - 1]), Vector(points[i]), Vector(points[(i + 1) % n])
        e0 = (p1 - p0).normalized()
        e1 = (p2 - p1).normalized()
        # OUTLINE winds clockwise seen from +Z, so (-e.y, e.x) points outward
        n0 = Vector((-e0.y, e0.x))
        n1 = Vector((-e1.y, e1.x))
        m = (n0 + n1).normalized()
        out.append(tuple(p1 + m * (d / max(0.35, m.dot(n1)))))
    return out


def loft(name, rings, bevel=True):
    """rings: list of (outline points, z) from bottom to top; capped solid."""
    bm = bmesh.new()
    loops = [[bm.verts.new((x, y, z)) for x, y in pts] for pts, z in rings]
    n = len(loops[0])
    for a, b in zip(loops, loops[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(list(reversed(loops[0])))
    bm.faces.new(loops[-1])
    return finish(name, bm, bevel=bevel)


def band(name, outer, inner, z0, z1, bevel=True):
    """Wall ring between two outlines."""
    bm = bmesh.new()
    n = len(outer)
    ob = [bm.verts.new((x, y, z0)) for x, y in outer]
    ot = [bm.verts.new((x, y, z1)) for x, y in outer]
    ib = [bm.verts.new((x, y, z0)) for x, y in inner]
    it = [bm.verts.new((x, y, z1)) for x, y in inner]
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((ob[i], ob[j], ot[j], ot[i]))
        bm.faces.new((ib[j], ib[i], it[i], it[j]))
        bm.faces.new((ot[i], ot[j], it[j], it[i]))
        bm.faces.new((ob[j], ob[i], ib[i], ib[j]))
    return finish(name, bm, bevel=bevel)


def scaled(points, sx, sy, dy=0.0):
    return [(x * sx, y * sy + dy) for x, y in points]


def box(name, center, size, rot=None, bevel=True):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    m = Matrix.Translation(center) @ (rot or Matrix.Identity(4)) @ Matrix.Diagonal((*size, 1))
    return finish(name, bm, m, bevel)


def cyl(name, r, z0, z1, x=0.0, y=0.0, sides=16, rot=None, bevel=False):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=sides, radius1=r, radius2=r,
                          depth=z1 - z0)
    m = Matrix.Translation((x, y, (z0 + z1) / 2)) @ (rot or Matrix.Identity(4))
    return finish(name, bm, m, bevel)


def tube(name, r_out, r_in, z0, z1, x=0.0, y=0.0, sides=16):
    outer = [(x + math.cos(a) * r_out, y + math.sin(a) * r_out)
             for a in (-(i / sides) * math.tau for i in range(sides))]
    inner = [(x + math.cos(a) * r_in, y + math.sin(a) * r_in)
             for a in (-(i / sides) * math.tau for i in range(sides))]
    return band(name, outer, inner, z0, z1, bevel=False)


def torus(name, center, major, minor, rot, seg=20, ring=6):
    bm = bmesh.new()
    grid = []
    for i in range(seg):
        a = i / seg * math.tau
        row = []
        for k in range(ring):
            b = k / ring * math.tau
            rr = major + math.cos(b) * minor
            row.append(bm.verts.new((math.cos(a) * rr, math.sin(a) * rr, math.sin(b) * minor)))
        grid.append(row)
    for i in range(seg):
        for k in range(ring):
            i2, k2 = (i + 1) % seg, (k + 1) % ring
            bm.faces.new((grid[i][k], grid[i2][k], grid[i2][k2], grid[i][k2]))
    return finish(name, bm, Matrix.Translation(center) @ rot, bevel=False)


def build():
    setup()
    o = OUTLINE
    # Hull: red lower hull tapering to the keel, white stripe, blue rim with the deck inside it.
    loft("Red_Hull", [
        (scaled(o, 0.62, 0.86, 0.6), -1.6),
        (scaled(o, 0.90, 0.96, 0.2), -0.4),
        (o, 0.6),
    ])
    loft("White_Stripe", [(offset(o, 0.04), 0.6), (offset(o, 0.04), 1.2)], bevel=False)
    band("Blue_Rim", offset(o, 0.12), offset(o, -0.55), 1.2, DECK_Z + 0.55)
    loft("Deck_Floor", [(offset(o, -0.5), 1.15), (offset(o, -0.5), DECK_Z)], bevel=False)
    # Bumpers on both sides of the hull.
    for s in (-1, 1):
        for y in (-1.5, 4.0, 9.0):
            box(f"Dark_Bumper{('L' if s < 0 else 'R')}{int(y + 2)}", (s * 5.22, y, 0.9), (0.55, 2.4, 1.3))
    # Fish tank at the bow: glass cylinder between a navy base ring and a grey rim, lid hinged open.
    tx, ty, tr = 0.0, -5.0, 3.1
    tz0, tz1 = DECK_Z, DECK_Z + 4.6
    tube("Navy_TankBase", tr + 0.3, tr - 0.1, tz0, tz0 + 0.6, tx, ty)
    cyl("Glass_Tank", tr, tz0 + 0.3, tz1 - 0.2, tx, ty, sides=20)
    tube("Grey_TankRim", tr + 0.3, tr - 0.15, tz1 - 0.4, tz1, tx, ty)
    hinge_y = ty + tr + 0.2
    box("Grey_Hinge", (tx, hinge_y, tz1 + 0.05), (1.4, 0.5, 0.5))
    # lid swung up and back around the hinge (110 degrees)
    lid_rot = Matrix.Translation((tx, hinge_y, tz1 + 0.15)) @ Matrix.Rotation(math.radians(-110), 4, "X") \
        @ Matrix.Translation((0, -(tr + 0.2), 0))
    lid = bmesh.new()
    bmesh.ops.create_cone(lid, cap_ends=True, cap_tris=False, segments=20, radius1=tr + 0.25,
                          radius2=tr + 0.25, depth=0.35)
    finish("Blue_Lid", lid, lid_rot, bevel=False)
    knob = bmesh.new()
    bmesh.ops.create_cone(knob, cap_ends=True, cap_tris=False, segments=10, radius1=0.45, radius2=0.45,
                          depth=0.5)
    finish("Navy_LidKnob", knob, lid_rot @ Matrix.Translation((0, 0, 0.4)), bevel=False)
    # Console with the steering wheel facing the chair.
    cy = 5.4
    box("White_Console", (0, cy, DECK_Z + 1.6), (3.6, 2.0, 3.2))
    box("Dark_Dash", (0, cy + 0.35, DECK_Z + 3.35), (3.4, 1.5, 0.35),
        rot=Matrix.Rotation(math.radians(-18), 4, "X"))
    tilt = Matrix.Rotation(math.radians(-60), 4, "X")  # wheel plane leans toward the driver
    wheel_c = Vector((0, cy + 1.35, DECK_Z + 2.9))
    torus("Black_Wheel", wheel_c, 0.95, 0.13, tilt)
    hub = bmesh.new()
    bmesh.ops.create_cone(hub, cap_ends=True, cap_tris=False, segments=10, radius1=0.25, radius2=0.25,
                          depth=0.5)
    finish("Black_WheelHub", hub, Matrix.Translation(wheel_c) @ tilt @ Matrix.Translation((0, 0, -0.1)),
           bevel=False)
    for i in range(3):
        a = i / 3 * math.tau + math.pi / 2
        spoke = Matrix.Translation(wheel_c) @ tilt @ Matrix.Rotation(a, 4, "Z") \
            @ Matrix.Translation((0.48, 0, 0))
        box(f"Black_Spoke{i}", (0, 0, 0), (0.95, 0.14, 0.14), rot=spoke, bevel=False)
    box("Grey_Column", (0, cy + 1.15, DECK_Z + 2.7), (0.3, 0.6, 0.3), bevel=False)
    # Red chair behind the wheel.
    sy = 8.9
    cyl("Grey_SeatPost", 0.3, DECK_Z, DECK_Z + 1.4, 0, sy, sides=10)
    box("Grey_SeatBase", (0, sy, DECK_Z + 1.45), (1.6, 1.6, 0.2), bevel=False)
    box("Seat_Cushion", (0, sy, DECK_Z + 1.85), (2.6, 2.4, 0.7))
    box("Seat_Back", (0, sy + 1.25, DECK_Z + 3.2), (2.6, 0.6, 2.8),
        rot=Matrix.Rotation(math.radians(8), 4, "X"))
    return export()


def export():
    os.makedirs(OUT_DIR, exist_ok=True)
    win = bpy.context.window
    prev = win.scene
    win.scene = scene
    try:
        for ob in scene.objects:
            ob.select_set(True)
        bpy.ops.export_scene.fbx(
            filepath=OUT_FBX,
            use_selection=True,
            apply_scale_options="FBX_SCALE_ALL",
            object_types={"MESH"},
            mesh_smooth_type="FACE",
            path_mode="AUTO",
            axis_forward="-Z",
            axis_up="Y",
        )
    finally:
        win.scene = prev
    tris = sum(sum(len(p.vertices) - 2 for p in ob.data.polygons) for ob in scene.objects)
    print("EXPORTED", OUT_FBX, "objects", len(scene.objects), "tris", tris)
    return OUT_FBX


build()
