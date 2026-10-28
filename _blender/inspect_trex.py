import bpy

path = "/Users/orlan/Downloads/rigged-red-trex-swim.glb"
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete()
bpy.ops.import_scene.gltf(filepath=path)

print("=== OBJECTS ===")
for obj in bpy.data.objects:
    extra = ""
    if obj.type == "ARMATURE":
        extra = f" bones={len(obj.data.bones)}"
    elif obj.type == "MESH":
        extra = f" verts={len(obj.data.vertices)}"
    print(f"{obj.type}\t{obj.name}\tparent={obj.parent.name if obj.parent else None}{extra}")

print("=== ACTIONS ===")
for act in bpy.data.actions:
    print(f"action {act.name} frames={act.frame_range[:]}")

print("=== BONES ===")
for obj in bpy.data.objects:
    if obj.type != "ARMATURE":
        continue
    print(f"ARMATURE {obj.name}")
    for bone in obj.data.bones:
        head = bone.head_local
        tail = bone.tail_local
        parent = bone.parent.name if bone.parent else "-"
        print(
            f"{bone.name}\tparent={parent}\thead=({head.x:.3f},{head.y:.3f},{head.z:.3f})\ttail=({tail.x:.3f},{tail.y:.3f},{tail.z:.3f})"
        )

mesh = next((o for o in bpy.data.objects if o.type == "MESH"), None)
if mesh:
    xs = [v.co.x for v in mesh.data.vertices]
    ys = [v.co.y for v in mesh.data.vertices]
    zs = [v.co.z for v in mesh.data.vertices]
    print(
        f"MESH_BOUNDS x={min(xs):.3f},{max(xs):.3f} y={min(ys):.3f},{max(ys):.3f} z={min(zs):.3f},{max(zs):.3f}"
    )
