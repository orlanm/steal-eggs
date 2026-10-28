import math
import bpy
from mathutils import Euler, Matrix, Vector

GLB = "/Users/orlan/Downloads/rigged-red-trex-swim.glb"
FPS = 24
CYCLE = 144
JAW_CYCLE = 288
SECONDS = 30

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete()
bpy.ops.import_scene.gltf(filepath=GLB)

arm = bpy.data.objects["SmartRigArmature"]
mesh = bpy.data.objects["low_poly_unwrapped"]

scene = bpy.context.scene
scene.render.fps = FPS
scene.frame_start = 1
scene.frame_end = FPS * SECONDS
scene.frame_current = 1

if scene.world is None:
    scene.world = bpy.data.worlds.new("SwimWorld")
scene.world.use_nodes = True
bg = next(n for n in scene.world.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs[0].default_value = (0.16, 0.55, 0.78, 1.0)
bg.inputs[1].default_value = 1.0

sun_data = bpy.data.lights.new("SwimSun", "SUN")
sun_data.energy = 3.5
sun_data.color = (1.0, 0.96, 0.9)
sun = bpy.data.objects.new("SwimSun", sun_data)
sun.rotation_euler = Euler((math.radians(55), 0, math.radians(35)), "XYZ")
scene.collection.objects.link(sun)

fill_data = bpy.data.lights.new("SwimFill", "AREA")
fill_data.energy = 250
fill_data.size = 4
fill = bpy.data.objects.new("SwimFill", fill_data)
fill.location = (2.2, -1.4, 2.4)
fill.rotation_euler = Euler((math.radians(60), 0, math.radians(55)), "XYZ")
scene.collection.objects.link(fill)


def wave(frame, phase=0.0, cycles=1.0):
    return math.sin((frame - 1) / CYCLE * math.tau * cycles + phase)


spine = [
    ("Bone_000", 0.05),
    ("Bone_001", 0.045),
    ("Bone_003", 0.035),
    ("Bone_002", 0.025),
    ("Bone_019", 0.012),
]
neck = ["Bone_018", "Bone_030", "Bone_029"]
tail = [
    ("Bone_005", 0.42),
    ("Bone_004", 0.16),
    ("Bone_023", 0.10),
    ("Bone_022", 0.06),
    ("Bone_027", 0.34),
    ("Bone_026", 0.12),
    ("Bone_025", 0.10),
    ("Bone_024", 0.05),
]
fins = [
    ("Bone_033", 0.62, 0.0),
    ("Bone_032", 0.16, 0.15),
    ("Bone_031", 0.08, 0.3),
    ("Bone_036", 0.62, 0.0),
    ("Bone_035", 0.16, 0.15),
    ("Bone_034", 0.08, 0.3),
    ("Bone_014", 0.36, 0.4),
    ("Bone_013", 0.10, 0.55),
    ("Bone_017", 0.36, 0.4),
    ("Bone_016", 0.10, 0.55),
    ("Bone_011", 0.22, 0.2),
    ("Bone_008", 0.22, 0.2),
]
jaw = [
    ("Bone_039", 0.42),
    ("Bone_042", 0.42),
    ("Bone_038", 0.12),
    ("Bone_041", 0.12),
]

bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")
for pb in arm.pose.bones:
    pb.rotation_mode = "XYZ"

action = bpy.data.actions.new("RedTrexSwim")
if arm.animation_data is None:
    arm.animation_data_create()
arm.animation_data.action = action
if hasattr(action, "slots"):
    slot = action.slots.new(id_type="OBJECT", name=arm.name)
    try:
        arm.animation_data.action_slot = slot
    except Exception as exc:
        print("slot assign", exc)

tail = [
    ("Bone_004", 0.50),
    ("Bone_023", 0.22),
    ("Bone_022", 0.12),
    ("Bone_027", 0.42),
    ("Bone_026", 0.14),
]
frames = list(range(1, JAW_CYCLE + 2, 2))
if frames[-1] != JAW_CYCLE + 1:
    frames.append(JAW_CYCLE + 1)

for frame in frames:
    scene.frame_set(frame)
    for index, (name, amp) in enumerate(tail):
        pb = arm.pose.bones[name]
        pb.rotation_euler = (amp * wave(frame, phase=-0.2 - index * 0.12), 0.0, 0.0)
        pb.keyframe_insert("rotation_euler", frame=frame)
    flap = math.sin((frame - 1) / JAW_CYCLE * math.tau)
    for name, amp in jaw:
        pb = arm.pose.bones[name]
        pb.rotation_euler = (amp * flap, 0.0, 0.0)
        pb.keyframe_insert("rotation_euler", frame=frame)

cycled = 0
bags = []
if hasattr(action, "layers"):
    for layer in action.layers:
        for strip in getattr(layer, "strips", []):
            for slot in action.slots:
                try:
                    bag = strip.channelbag(slot)
                except Exception:
                    bag = None
                if bag:
                    bags.append(bag)
if not bags and hasattr(action, "fcurves"):
    bags.append(action)
for bag in bags:
    for fc in bag.fcurves:
        mod = fc.modifiers.new(type="CYCLES")
        mod.mode_before = "REPEAT"
        mod.mode_after = "REPEAT"
        cycled += 1

scene.frame_set(1)
bpy.ops.object.mode_set(mode="OBJECT")

print(f"SWIM_KEYS cycled={cycled} frame_end={scene.frame_end} action={action.name}")


def tip_z(name):
    pb = arm.pose.bones[name]
    return (arm.matrix_world @ pb.tail).z


if bpy.app.background:
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    for frame in (1, 13, 25, 37):
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        print(
            f"F{frame} tail={tip_z('Bone_022'):.3f} jaw={tip_z('Bone_037'):.3f} fin={tip_z('Bone_031'):.3f}"
        )
else:
    def start_playback():
        started = False
        for window in bpy.context.window_manager.windows:
            screen = window.screen
            for area in screen.areas:
                if area.type != "VIEW_3D":
                    continue
                region = next(r for r in area.regions if r.type == "WINDOW")
                space = area.spaces.active
                space.shading.type = "MATERIAL"
                space.shading.use_scene_lights = True
                space.shading.use_scene_world = True
                space.overlay.show_bones = False
                with bpy.context.temp_override(window=window, area=area, region=region):
                    arm.select_set(True)
                    mesh.select_set(True)
                    bpy.context.view_layer.objects.active = arm
                    bpy.ops.view3d.view_selected()
                    r3d = space.region_3d
                    r3d.view_location = Vector((0.0, 0.05, 0.72))
                    r3d.view_distance = 3.4
                    r3d.view_rotation = Euler((math.radians(72), 0.0, math.radians(32)), "XYZ").to_quaternion()
                    scene.frame_set(1)
                    if not screen.is_animation_playing:
                        bpy.ops.screen.animation_play()
                started = True
                break
            if started:
                break
        print("SWIM_PLAYING", started)
        return None

    bpy.app.timers.register(start_playback, first_interval=0.6)
