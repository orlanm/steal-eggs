# Trail Shop stall for Steal Baby Beasts.
# Run inside Blender: Text Editor -> Open this file -> Run Script.
# Or from a terminal:
#   blender --background --python trail_shop.py
# Exports an FBX next to the project so Studio can import it.

import bpy
import math
import os

OUT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "_assets", "trail-shop"))
OUT_FBX = os.path.join(OUT_DIR, "TrailShop.fbx")


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0


def material(name, color, emission=0.0, roughness=0.45, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission > 0 and "Emission Color" in bsdf.inputs:
        bsdf.inputs["Emission Color"].default_value = (*color, 1)
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


def assign(obj, mat):
    obj.data.materials.append(mat)


def box(name, location, scale, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    assign(obj, mat)
    return obj


def cylinder(name, location, radius, depth, mat, vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location)
    obj = bpy.context.active_object
    obj.name = name
    assign(obj, mat)
    return obj


def text_mesh(name, body, location, size, mat, extrude=0.08):
    bpy.ops.object.text_add(location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.body = body
    obj.data.align_x = "CENTER"
    obj.data.align_y = "CENTER"
    obj.data.size = size
    obj.data.extrude = extrude
    obj.data.bevel_depth = 0.01
    bpy.ops.object.convert(target="MESH")
    assign(obj, mat)
    return obj


def build():
    reset_scene()
    wood = material("StallWood", (0.55, 0.32, 0.14), roughness=0.62)
    stone = material("StallStone", (0.45, 0.47, 0.52), roughness=0.8)
    canopy = material("CanopyCyan", (0.15, 0.85, 0.95), emission=2.2, roughness=0.25)
    canopy2 = material("CanopyPurple", (0.55, 0.2, 0.95), emission=1.6, roughness=0.25)
    neon = material("SignNeon", (0.35, 1.0, 1.0), emission=8.0, roughness=0.15)
    cloth = material("Awning", (0.95, 0.45, 0.85), roughness=0.55)
    skin = material("Shopkeeper", (0.95, 0.78, 0.62), roughness=0.5)
    shirt = material("ShopShirt", (0.2, 0.35, 0.85), roughness=0.4)
    orb = material("TrailOrb", (0.7, 0.3, 1.0), emission=6.0, roughness=0.1)
    orb2 = material("TrailOrbCyan", (0.2, 0.95, 1.0), emission=6.0, roughness=0.1)

    parts = []
    parts.append(box("Base", (0, 0, 0.35), (7.2, 5.2, 0.35), stone))
    parts.append(box("Deck", (0, 0, 0.75), (6.6, 4.6, 0.18), wood))
    for x in (-3.0, 3.0):
        for y in (-2.0, 2.0):
            parts.append(box(f"Post_{x}_{y}", (x, y, 4.4), (0.28, 0.28, 3.6), wood))
    parts.append(box("Counter", (0, -1.55, 1.85), (4.4, 0.7, 0.55), wood))
    parts.append(box("CounterTop", (0, -1.55, 2.2), (4.6, 0.85, 0.08), stone))
    parts.append(box("Roof", (0, 0, 8.15), (7.6, 5.6, 0.18), canopy))
    parts.append(box("RoofStripe", (0, 0, 8.32), (7.8, 0.45, 0.12), canopy2))
    parts.append(box("Awning", (0, -2.55, 6.4), (5.2, 1.3, 0.08), cloth))
    parts.append(box("SignBoard", (0, 0, 9.15), (3.4, 0.16, 0.7), neon))
    parts.append(text_mesh("SignText", "TRAILS", (0, -0.12, 9.15), 0.55, neon))
    for index, (x, mat) in enumerate(((-1.6, orb), (1.6, orb2))):
        parts.append(cylinder(f"Pedestal_{index}", (x, -1.15, 2.55), 0.28, 0.7, stone))
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.32, location=(x, -1.15, 3.1))
        sphere = bpy.context.active_object
        sphere.name = f"Sample_{index}"
        assign(sphere, mat)
        parts.append(sphere)

    # Blocky shopkeeper behind the counter.
    parts.append(box("ShopkeeperTorso", (0, 0.15, 2.7), (0.9, 0.45, 1.1), shirt))
    parts.append(box("ShopkeeperHead", (0, 0.15, 3.7), (0.55, 0.5, 0.55), skin))
    parts.append(box("ShopkeeperArmL", (-0.75, 0.15, 2.65), (0.22, 0.22, 0.9), skin))
    parts.append(box("ShopkeeperArmR", (0.75, 0.15, 2.65), (0.22, 0.22, 0.9), skin))
    parts.append(box("ShopkeeperLegL", (-0.28, 0.15, 1.45), (0.24, 0.24, 1.0), shirt))
    parts.append(box("ShopkeeperLegR", (0.28, 0.15, 1.45), (0.24, 0.24, 1.0), shirt))

    bpy.ops.object.empty_add(type="PLAIN_AXES", location=(0, 0, 0))
    root = bpy.context.active_object
    root.name = "TrailShop"
    for obj in parts:
        obj.parent = root

    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.fbx(
        filepath=OUT_FBX,
        use_selection=True,
        apply_scale_options="FBX_SCALE_ALL",
        object_types={"MESH", "EMPTY"},
        mesh_smooth_type="FACE",
        path_mode="AUTO",
        axis_forward="-Z",
        axis_up="Y",
    )
    print("EXPORTED", OUT_FBX)


if __name__ == "__main__":
    build()
