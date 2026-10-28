import bpy
from mathutils import Vector

path = "/Users/orlan/Downloads/rigged-red-trex-swim.glb"
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete()
bpy.ops.import_scene.gltf(filepath=path)

arm = bpy.data.objects["SmartRigArmature"]
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")

tips = {
    "mouth_L": "Bone_037",
    "mouth_R": "Bone_040",
    "tail_up": "Bone_022",
    "tail_down": "Bone_026",
    "dorsal": "Bone_024",
    "fin_L": "Bone_031",
    "fin_R": "Bone_034",
    "rear_L": "Bone_012",
    "rear_R": "Bone_015",
    "small_L": "Bone_009",
    "small_R": "Bone_006",
    "belly": "Bone_020",
}
roots = {
    "mouth_L": "Bone_039",
    "mouth_R": "Bone_042",
    "tail_up": "Bone_005",
    "tail_down": "Bone_027",
    "dorsal": "Bone_025",
    "fin_L": "Bone_033",
    "fin_R": "Bone_036",
    "rear_L": "Bone_014",
    "rear_R": "Bone_017",
    "small_L": "Bone_011",
    "small_R": "Bone_008",
    "belly": "Bone_021",
}

def tip_world(name):
    pb = arm.pose.bones[name]
    bpy.context.view_layer.update()
    return arm.matrix_world @ pb.tail


def rest():
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0, 0, 0)
    bpy.context.view_layer.update()


rest()
base = {k: tip_world(v).copy() for k, v in tips.items()}

for axis in (0, 1, 2):
    for sign in (1, -1):
        rest()
        label = "XYZ"[axis] + ("+" if sign > 0 else "-")
        print(f"=== ROT {label} ===")
        for key, root in roots.items():
            pb = arm.pose.bones[root]
            pb.rotation_mode = "XYZ"
            ang = [0, 0, 0]
            ang[axis] = sign * 0.45
            pb.rotation_euler = ang
            delta = tip_world(tips[key]) - base[key]
            print(f"{key}\td=({delta.x:.3f},{delta.y:.3f},{delta.z:.3f})")
