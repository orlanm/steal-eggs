# Fuse Machine for Steal Baby Beasts (matches the purple three-pod reference art).
# Builds into its own scene "FuseMachine" (the open scene is left alone) and exports
# _assets/fuse-machine/FuseMachine.fbx. Units are studs (1 Blender unit = 1 stud), Z up,
# front (stairs) faces -Y.
#
# Run in Blender: exec(open("<project>/_blender/fuse_machine.py").read())
# or: blender --background --python _blender/fuse_machine.py
#
# Object names start with a colour group (Navy_, Purple_, Grey_, Neon_, Glass_, Swirl_,
# Crystal_). Studio sets Color/Material/Transparency from that prefix after import
# (see FuseMachineBuild.luau STYLE).

import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.path.expanduser(
    "~/Desktop/steal baby beasts/_blender")
OUT_DIR = os.path.abspath(os.path.join(HERE, "..", "_assets", "fuse-machine"))
OUT_FBX = os.path.join(OUT_DIR, "FuseMachine.fbx")

COLORS = {
    "Navy": (0.05, 0.08, 0.20),
    "Purple": (0.30, 0.10, 0.75),
    "Grey": (0.55, 0.56, 0.60),
    "Neon": (1.00, 0.20, 0.90),
    "Glass": (0.80, 0.55, 1.00),
    "Swirl": (1.00, 0.55, 0.95),
    "Crystal": (1.00, 0.55, 1.00),
}
BEVEL = {"Navy": 0.14, "Purple": 0.12, "Grey": 0.1}

scene = None
coll = None
mats = {}


def setup():
    global scene, coll
    old = bpy.data.scenes.get("FuseMachine")
    if old:
        for o in list(old.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.scenes.remove(old)
    scene = bpy.data.scenes.new("FuseMachine")
    scene.unit_settings.system = "METRIC"
    coll = scene.collection
    for name, rgb in COLORS.items():
        m = bpy.data.materials.get("FM_" + name) or bpy.data.materials.new("FM_" + name)
        m.use_nodes = True
        bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = (*rgb, 1)
        if name in ("Neon", "Swirl", "Crystal"):
            bsdf.inputs["Emission Color"].default_value = (*rgb, 1)
            bsdf.inputs["Emission Strength"].default_value = 3.0
        if name == "Glass":
            bsdf.inputs["Alpha"].default_value = 0.35
        mats[name] = m


def finish(name, bm, matrix=None, bevel=True):
    """bmesh -> object (optionally bevelled and baked)."""
    group = name.split("_")[0]
    if matrix is not None:
        bm.transform(matrix)
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


def bake(obj):
    deps = bpy.context.evaluated_depsgraph_get()
    scene_view = bpy.context.window.scene if bpy.context.window else None
    # Evaluate in our scene: link temporarily into the context scene if needed.
    linked = False
    if scene_view and obj.name not in scene_view.collection.all_objects:
        scene_view.collection.objects.link(obj)
        linked = True
        deps = bpy.context.evaluated_depsgraph_get()
        deps.update()
    ev = obj.evaluated_get(deps)
    new = bpy.data.meshes.new_from_object(ev)
    old = obj.data
    obj.modifiers.clear()
    obj.data = new
    bpy.data.meshes.remove(old)
    if linked:
        scene_view.collection.objects.unlink(obj)


def prism(name, r1, r2, z0, z1, x=0.0, y=0.0, sides=8, rot=None, bevel=True):
    """Frustum with `sides` faces (flat face toward -Y for 8 sides)."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=sides,
                          radius1=r1, radius2=r2, depth=z1 - z0)
    spin = rot if rot is not None else (math.pi / sides if sides % 2 == 0 else -math.pi / 2)
    m = Matrix.Translation((x, y, (z0 + z1) / 2)) @ Matrix.Rotation(spin, 4, "Z")
    return finish(name, bm, m, bevel)


def box(name, center, size, rot_z=0.0, bevel=True):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    m = Matrix.Translation(center) @ Matrix.Rotation(rot_z, 4, "Z") @ Matrix.Diagonal((*size, 1))
    return finish(name, bm, m, bevel)


def ring_of(cx, cy, radius, angle):
    return Vector((cx + math.sin(angle) * radius, cy - math.cos(angle) * radius, 0))


def curve_tube(name, points, radius, closed=False, res=6):
    cu = bpy.data.curves.new(name + "_c", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = 2
    cu.resolution_u = res
    cu.use_fill_caps = True
    sp = cu.splines.new("POLY" if len(points) > 4 else "BEZIER")
    if sp.type == "BEZIER":
        sp.bezier_points.add(len(points) - 1)
        for bp, p in zip(sp.bezier_points, points):
            bp.co = p
            bp.handle_left_type = bp.handle_right_type = "AUTO"
    else:
        sp.points.add(len(points) - 1)
        for pt, p in zip(sp.points, points):
            pt.co = (*p, 1)
    sp.use_cyclic_u = closed
    tmp = bpy.data.objects.new(name + "_tmp", cu)
    view = bpy.context.window.scene
    view.collection.objects.link(tmp)
    deps = bpy.context.evaluated_depsgraph_get()
    deps.update()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(deps))
    view.collection.objects.unlink(tmp)
    bpy.data.objects.remove(tmp)
    bpy.data.curves.remove(cu)
    group = name.split("_")[0]
    me.name = name
    me.materials.clear()
    me.materials.append(mats[group])
    obj = bpy.data.objects.new(name, me)
    coll.objects.link(obj)
    return obj


def circle_tube(name, cx, cy, cz, radius, thick, seg=40):
    pts = [(cx + math.cos(t) * radius, cy + math.sin(t) * radius, cz)
           for t in (i / seg * math.tau for i in range(seg))]
    return curve_tube(name, pts, thick, closed=True)


def helix(name, cx, cy, z0, z1, radius, turns, thick, seg_per_turn=28, taper=0.45):
    n = int(turns * seg_per_turn)
    pts = []
    for i in range(n + 1):
        t = i / n
        a = t * turns * math.tau
        r = radius * (1 - taper + taper * math.sin(t * math.pi))
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r, z0 + (z1 - z0) * t))
    return curve_tube(name, pts, thick)


def triangle(name, center, size, depth=0.25):
    """Downward-pointing flat triangle facing -Y."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=3, radius1=size, radius2=size, depth=depth)
    # create_cone puts the first corner on +Y; spin it to -Y so the tip points down after the X turn.
    m = (Matrix.Translation(center) @ Matrix.Rotation(math.pi / 2, 4, "X")
         @ Matrix.Rotation(math.pi, 4, "Z"))
    return finish(name, bm, m, False)


def gem(name, x, y, z, r, h_up, h_down):
    bm = bmesh.new()
    top = bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=r, radius2=0.0, depth=h_up)
    bmesh.ops.translate(bm, verts=top["verts"], vec=(0, 0, h_up / 2))
    bm2 = bmesh.new()
    bot = bmesh.ops.create_cone(bm2, cap_ends=True, segments=6, radius1=0.0, radius2=r, depth=h_down)
    bmesh.ops.translate(bm2, verts=bot["verts"], vec=(0, 0, -h_down / 2))
    me = bpy.data.meshes.new("tmp")
    bm2.to_mesh(me)
    bm2.free()
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)
    return finish(name, bm, Matrix.Translation((x, y, z)), False)


def pod(tag, x, y, z, k=1.0):
    """Small chamber: tapered collar, glass jar, top collar, cap and crystal. z = collar bottom."""
    def P(name, r1, r2, a, b, **kw):
        return prism(name, r1 * k, r2 * k, z + a * k, z + b * k, x, y, **kw)
    P(f"Navy_{tag}Funnel", 1.5, 3.1, -1.2, 0)
    P(f"Navy_{tag}Collar", 3.25, 3.25, 0, 1.7)
    for n in range(8):
        a = (n + 0.5) / 8 * math.tau
        if n in (3, 4):
            continue  # front face gets the triangle badge
        p = ring_of(x, y, 3.25 * k, a)
        box(f"Grey_{tag}Block{n}", (p.x, p.y, z + 0.85 * k), (1.1 * k, 0.5 * k, 1.3 * k), rot_z=a)
    triangle(f"Neon_{tag}Arrow", (x, y - 3.3 * k, z + 0.85 * k), 0.55 * k)
    P(f"Navy_{tag}Seat", 2.75, 2.75, 1.7, 2.1)
    P(f"Glass_{tag}Jar", 2.5, 2.5, 2.1, 5.4, sides=24, bevel=False)
    P(f"Neon_{tag}Pool", 2.1, 2.1, 2.1, 2.3, sides=24, bevel=False)
    circle_tube(f"Swirl_{tag}Ring", x, y, z + 2.35 * k, 1.4 * k, 0.07 * k)
    # Wide, even coil filling the jar from the pool to just under the top collar.
    helix(f"Swirl_{tag}Helix", x, y, z + 2.4 * k, z + 5.25 * k, 1.85 * k, 1.75, 0.13 * k, taper=0.12)
    P(f"Purple_{tag}TopCollar", 3.0, 3.0, 5.4, 6.7)
    box(f"Neon_{tag}TopBar", (x, y - 2.95 * k, z + 6.05 * k), (1.5 * k, 0.2, 0.45 * k), bevel=False)
    P(f"Navy_{tag}Cap", 2.6, 1.55, 6.7, 7.5)
    P(f"Navy_{tag}CapRim", 1.55, 1.3, 7.5, 7.8)
    gem(f"Crystal_{tag}Gem", x, y, z + 8.35 * k, 0.8 * k, 1.3 * k, 0.55 * k)


def build():
    setup()
    # Base ----------------------------------------------------------------------------
    prism("Navy_BasePlinth", 11.8, 10.4, 0.0, 1.8)
    prism("Navy_BaseTier", 9.8, 9.0, 1.8, 3.0)
    prism("Navy_CoreFloor", 7.4, 7.0, 3.0, 3.8)
    # Stairs at the front, with grey rails and neon risers.
    for i in range(3):
        top = 3.0 - i * 1.0
        y = -8.4 - i * 1.4
        box(f"Navy_Step{i}", (0, y, top / 2), (5.6, 1.8, top))
        box(f"Neon_StepStrip{i}", (0, y - 0.92, top - 0.5), (3.0, 0.1, 0.26), bevel=False)
    for s in (-1, 1):
        box(f"Grey_StairRail{s+1}", (s * 3.4, -9.6, 1.5), (1.3, 5.0, 3.0))
    # Core chamber ----------------------------------------------------------------------
    prism("Glass_CoreTube", 5.6, 5.6, 3.8, 13.0, sides=32, bevel=False)
    prism("Neon_CorePool", 5.2, 5.2, 3.8, 4.05, sides=32, bevel=False)
    for r in (1.8, 3.1, 4.3):
        circle_tube(f"Swirl_CoreRing{int(r*10)}", 0, 0, 4.1, r, 0.1)
    helix("Swirl_CoreHelixA", 0, 0, 4.2, 12.6, 3.7, 2.4, 0.2)
    helix("Swirl_CoreHelixB", 0, 0, 4.6, 12.2, 2.2, 2.0, 0.11)
    for n, ang in enumerate((-2.25, -1.0, 1.0, 2.25)):
        p = ring_of(0, 0, 6.3, ang + math.pi)
        box(f"Purple_Pillar{n}", (p.x, p.y, 8.4), (2.2, 1.8, 9.2), rot_z=ang)
        box(f"Grey_PillarFoot{n}", (p.x, p.y, 4.5), (2.6, 2.2, 1.4), rot_z=ang)
        box(f"Navy_PillarShoulder{n}", (p.x, p.y, 12.6), (2.6, 2.2, 1.2), rot_z=ang)
    # Upper collar ----------------------------------------------------------------------
    prism("Navy_CoreCollar", 7.2, 7.2, 13.0, 15.6)
    prism("Navy_CoreCollarLip", 7.6, 7.2, 13.0, 13.6)
    for n in range(8):
        a = (n + 0.5) / 8 * math.tau
        if n in (3, 4):
            continue
        p = ring_of(0, 0, 7.3, a)
        box(f"Grey_CollarBlock{n}", (p.x, p.y, 14.3), (2.2, 0.7, 1.9), rot_z=a)
    prism("Navy_FrontBadge", 2.6, 2.6, 13.2, 16.2, 0, -6.9, sides=6, rot=0)
    triangle("Neon_CoreArrow", (0, -8.55, 14.7), 1.05)
    prism("Navy_CoreTop", 6.0, 4.0, 15.6, 16.8)
    prism("Navy_CenterSocket", 1.5, 1.3, 16.8, 17.4)
    for s in (-1, 1):
        prism(f"Navy_SideSocket{s+1}", 1.3, 1.1, 15.6, 16.3, s * 5.2, 0.4)
    # Pipes and pods ------------------------------------------------------------------
    k = 1.15
    pod("PodC", 0, 0.6, 20.0, k)
    pod("PodL", -10.6, 0.6, 19.2, k)
    pod("PodR", 10.6, 0.6, 19.2, k)
    curve_tube("Neon_PipeC", [(0, 0.3, 17.2), (0, 0.4, 17.9), (0, 0.6, 18.7)], 0.85)
    for s in (-1, 1):
        curve_tube(f"Neon_Pipe{s+1}", [
            (s * 5.2, 0.4, 16.1), (s * 5.4, 0.4, 17.6), (s * 7.6, 0.5, 17.4),
            (s * 10.6, 0.6, 16.9), (s * 10.6, 0.6, 18.1)], 0.72)
    return export()


def export():
    os.makedirs(OUT_DIR, exist_ok=True)
    win = bpy.context.window
    prev = win.scene
    win.scene = scene
    try:
        for o in scene.objects:
            o.select_set(True)
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
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in scene.objects)
    print("EXPORTED", OUT_FBX, "objects", len(scene.objects), "tris", tris)
    return OUT_FBX


build()
