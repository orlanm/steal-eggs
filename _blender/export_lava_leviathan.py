"""Import Meshy Lava Leviathan FBX + texture, rig to mommy bones, animate idle/swim, export for Roblox."""
from __future__ import annotations

import json
import math
import os
from mathutils import Euler, Matrix, Quaternion, Vector

import bpy

FBX = "/Users/orlan/Downloads/centipede-fish-fbx/Meshy_AI_Lava_Leviathan_1019180449_texture.fbx"
TEX = "/Users/orlan/Downloads/centipede-fish-fbx/Meshy_AI_Lava_Leviathan_1019180449_texture.png"
NORMAL = "/Users/orlan/Downloads/centipede-fish-fbx/Meshy_AI_Lava_Leviathan_1019180449_texture_normal.png"
METAL = "/Users/orlan/Downloads/centipede-fish-fbx/Meshy_AI_Lava_Leviathan_1019180449_texture_metallic.png"
ROUGH = "/Users/orlan/Downloads/centipede-fish-fbx/Meshy_AI_Lava_Leviathan_1019180449_texture_roughness.png"
OLD_BONES = "/Users/orlan/Desktop/steal eggs/_assets/yellow-trex/old_mommy.json"
OUT_DIR = "/Users/orlan/Desktop/steal eggs/_assets/lava-leviathan"
MESH_DIR = "/Users/orlan/Desktop/steal eggs/src/shared/MommyLeviathanMeshData"
CLIPS_LUA = "/Users/orlan/Desktop/steal eggs/src/shared/MommyLeviathanClips.luau"
BLEND = "/Users/orlan/Desktop/steal eggs/_blender/lava_leviathan_animated.blend"
EXPORT_FBX = "/Users/orlan/Desktop/steal eggs/_assets/lava-leviathan/LavaLeviathan_Animated.fbx"
CHUNK_PAYLOAD = 180000
TARGET_LENGTH = 3.325  # match existing mommy length on Z

BONES = [
	("Root", 0),
	("Head", 1),
	("Body", 2),
	("Rear", 3),
	("TailBase", 4),
	("TailFan", 5),
	("RearFin.L", 3),
	("RearFin.R", 3),
	("Jaw", 2),
	("FrontFin.L", 2),
	("FrontFin.R", 2),
]


def load_old_bones():
	with open(OLD_BONES, "r", encoding="utf-8") as f:
		return {b["name"]: b for b in json.load(f)["bones"]}


def cframe_to_matrix(cf):
	x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf
	return Matrix(
		(
			(r00, r01, r02, x),
			(r10, r11, r12, y),
			(r20, r21, r22, z),
			(0.0, 0.0, 0.0, 1.0),
		)
	)


def matrix_to_cframe(m):
	return [
		round(m[0][3], 7),
		round(m[1][3], 7),
		round(m[2][3], 7),
		round(m[0][0], 7),
		round(m[0][1], 7),
		round(m[0][2], 7),
		round(m[1][0], 7),
		round(m[1][1], 7),
		round(m[1][2], 7),
		round(m[2][0], 7),
		round(m[2][1], 7),
		round(m[2][2], 7),
	]


def rot_of(cf):
	m = cframe_to_matrix(cf)
	m[0][3] = m[1][3] = m[2][3] = 0.0
	return m


def placed(cf, pos):
	m = rot_of(cf)
	m[0][3], m[1][3], m[2][3] = pos.x, pos.y, pos.z
	return matrix_to_cframe(m)


def average(points):
	acc = Vector((0.0, 0.0, 0.0))
	for p in points:
		acc += p
	return acc / max(len(points), 1)


def quat_wxyz(q: Quaternion):
	q = q.normalized()
	return [round(q.w, 7), round(q.x, 7), round(q.y, 7), round(q.z, 7)]


def apply_texture(mesh_obj):
	img = bpy.data.images.load(TEX)
	mat = bpy.data.materials.new("LavaLeviathanMat")
	mat.use_nodes = True
	nt = mat.node_tree
	nodes = nt.nodes
	links = nt.links
	nodes.clear()
	out = nodes.new("ShaderNodeOutputMaterial")
	bsdf = nodes.new("ShaderNodeBsdfPrincipled")
	tex = nodes.new("ShaderNodeTexImage")
	tex.image = img
	links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
	if os.path.isfile(NORMAL):
		nmap = nodes.new("ShaderNodeTexImage")
		nmap.image = bpy.data.images.load(NORMAL)
		nmap.image.colorspace_settings.name = "Non-Color"
		normal = nodes.new("ShaderNodeNormalMap")
		links.new(nmap.outputs["Color"], normal.inputs["Color"])
		links.new(normal.outputs["Normal"], bsdf.inputs["Normal"])
	if os.path.isfile(ROUGH):
		rimg = nodes.new("ShaderNodeTexImage")
		rimg.image = bpy.data.images.load(ROUGH)
		rimg.image.colorspace_settings.name = "Non-Color"
		links.new(rimg.outputs["Color"], bsdf.inputs["Roughness"])
	if os.path.isfile(METAL):
		mimg = nodes.new("ShaderNodeTexImage")
		mimg.image = bpy.data.images.load(METAL)
		mimg.image.colorspace_settings.name = "Non-Color"
		links.new(mimg.outputs["Color"], bsdf.inputs["Metallic"])
	links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
	mesh_obj.data.materials.clear()
	mesh_obj.data.materials.append(mat)


def key_pose(arm_obj, frame, eulers_deg):
	bpy.context.scene.frame_set(frame)
	for name, xyz in eulers_deg.items():
		pb = arm_obj.pose.bones.get(name)
		if not pb:
			continue
		pb.rotation_mode = "XYZ"
		pb.rotation_euler = Euler(
			(math.radians(xyz[0]), math.radians(xyz[1]), math.radians(xyz[2])), "XYZ"
		)
		pb.keyframe_insert(data_path="rotation_euler", frame=frame)


def sample_clip(arm_obj, frame_start, frame_end, fps):
	samples = []
	for frame in range(frame_start, frame_end + 1):
		bpy.context.scene.frame_set(frame)
		bpy.context.view_layer.update()
		row = []
		for name, _ in BONES:
			pb = arm_obj.pose.bones[name]
			q = pb.matrix_basis.to_quaternion()
			row.append(quat_wxyz(q))
		samples.append(row)
	duration = (frame_end - frame_start) / float(fps)
	return {"duration": duration, "fps": fps, "samples": samples}


def main():
	old = load_old_bones()
	os.makedirs(OUT_DIR, exist_ok=True)
	os.makedirs(MESH_DIR, exist_ok=True)

	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.import_scene.fbx(filepath=FBX)
	mesh_obj = next(o for o in bpy.data.objects if o.type == "MESH")
	mesh_obj.name = "LavaLeviathan"
	bpy.context.view_layer.objects.active = mesh_obj
	mesh_obj.select_set(True)
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	apply_texture(mesh_obj)

	# FBX length on Y -> mommy length on Z (head at -Z, up +Y).
	# Negate Y so the axis remap keeps winding (det +1) for correct UVs in Roblox.
	for v in mesh_obj.data.vertices:
		x, y, z = v.co
		v.co = Vector((x, z, -y))
	mesh_obj.data.update()

	xs = [v.co.x for v in mesh_obj.data.vertices]
	ys = [v.co.y for v in mesh_obj.data.vertices]
	zs = [v.co.z for v in mesh_obj.data.vertices]
	size = Vector((max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)))
	scale = TARGET_LENGTH / max(size.z, 1e-6)
	for v in mesh_obj.data.vertices:
		v.co *= scale
	xs = [v.co.x for v in mesh_obj.data.vertices]
	ys = [v.co.y for v in mesh_obj.data.vertices]
	zs = [v.co.z for v in mesh_obj.data.vertices]
	center = Vector(
		((min(xs) + max(xs)) * 0.5, (min(ys) + max(ys)) * 0.5, (min(zs) + max(zs)) * 0.5)
	)
	for v in mesh_obj.data.vertices:
		v.co -= center
	zs = [v.co.z for v in mesh_obj.data.vertices]
	# Align snout near -1.662 like the trex mommy catch geometry.
	shift = -1.662 - min(zs)
	for v in mesh_obj.data.vertices:
		v.co.z += shift
	mesh_obj.data.update()

	coords = [v.co.copy() for v in mesh_obj.data.vertices]

	def in_z(a, b):
		return [p for p in coords if a <= p.z <= b]

	def side(points, sign, min_abs=0.18):
		picked = [p for p in points if p.x * sign > min_abs]
		return picked if picked else points

	root_pos = Vector((0.0, -0.12, 0.0))
	head_pts = in_z(-1.55, -0.75)
	jaw_pts = [p for p in head_pts if p.y < average(head_pts).y - 0.04] or head_pts
	body_pts = in_z(-0.75, -0.15)
	rear_pts = in_z(-0.05, 0.4)
	tail_pts = in_z(0.45, 1.0)
	fan_pts = in_z(1.05, 1.75)
	front_band = in_z(-1.25, -0.5)
	rear_band = in_z(-0.45, 0.25)

	positions = {
		"Root": root_pos,
		"Head": average(head_pts) if head_pts else Vector((0.0, 0.05, -1.0)),
		"Jaw": average(jaw_pts) if jaw_pts else Vector((0.0, -0.08, -1.15)),
		"Body": average(body_pts) if body_pts else Vector((0.0, -0.05, -0.5)),
		"Rear": average(rear_pts) if rear_pts else Vector((0.0, -0.1, 0.15)),
		"TailBase": average(tail_pts) if tail_pts else Vector((0.0, 0.0, 0.75)),
		"TailFan": average(fan_pts) if fan_pts else Vector((0.0, 0.12, 1.25)),
		"FrontFin.L": average(side(front_band, 1.0)) if front_band else Vector((0.4, -0.12, -0.85)),
		"FrontFin.R": average(side(front_band, -1.0)) if front_band else Vector((-0.4, -0.12, -0.85)),
		"RearFin.L": average(side(rear_band, 1.0)) if rear_band else Vector((0.4, -0.18, -0.15)),
		"RearFin.R": average(side(rear_band, -1.0)) if rear_band else Vector((-0.4, -0.18, -0.15)),
	}

	bone_cfs = {name: placed(old[name]["cf"], positions[name]) for name, _ in BONES}

	arm_data = bpy.data.armatures.new("MommyRig")
	arm_obj = bpy.data.objects.new("MommyRig", arm_data)
	bpy.context.collection.objects.link(arm_obj)
	bpy.context.view_layer.objects.active = arm_obj
	bpy.ops.object.mode_set(mode="EDIT")
	edit = {}
	for name, parent_index in BONES:
		eb = arm_data.edit_bones.new(name)
		m = cframe_to_matrix(bone_cfs[name])
		head = m.to_translation()
		tip = head + (m.to_3x3() @ Vector((0.0, 0.0, -0.14)))
		if (tip - head).length < 1e-4:
			tip = head + Vector((0.0, 0.0, -0.14))
		eb.head = head
		eb.tail = tip
		edit[name] = eb
	for name, parent_index in BONES:
		if parent_index > 0:
			parent_name = BONES[parent_index - 1][0]
			edit[name].parent = edit[parent_name]
			edit[name].use_connect = False
	bpy.ops.object.mode_set(mode="OBJECT")

	bpy.ops.object.select_all(action="DESELECT")
	mesh_obj.select_set(True)
	arm_obj.select_set(True)
	bpy.context.view_layer.objects.active = arm_obj
	bpy.ops.object.parent_set(type="ARMATURE_AUTO")

	# --- Animations ---
	# Idle (frames 1-120 @ 15fps = 8s): slow jaw chew, tail sway, side fins.
	# Swim (frames 140-200 @ 15fps = 4s): stronger body undulation + fins.
	fps = 15
	scene = bpy.context.scene
	scene.render.fps = fps

	# Clear prior pose
	bpy.context.view_layer.objects.active = arm_obj
	bpy.ops.object.mode_set(mode="POSE")
	for pb in arm_obj.pose.bones:
		pb.rotation_mode = "XYZ"
		pb.rotation_euler = Euler((0, 0, 0), "XYZ")

	# IDLE keys
	idle_keys = [
		(
			1,
			{
				"Jaw": (0, 0, 0),
				"Rear": (0, 0, 0),
				"TailBase": (0, 0, 0),
				"TailFan": (0, 0, 0),
				"FrontFin.L": (0, 0, 0),
				"FrontFin.R": (0, 0, 0),
				"RearFin.L": (0, 0, 0),
				"RearFin.R": (0, 0, 0),
			},
		),
		(
			30,
			{
				"Jaw": (14, 0, 0),
				"Rear": (0, 10, 0),
				"TailBase": (0, 16, 0),
				"TailFan": (0, 22, 0),
				"FrontFin.L": (0, 0, 18),
				"FrontFin.R": (0, 0, -18),
				"RearFin.L": (8, 0, 12),
				"RearFin.R": (8, 0, -12),
			},
		),
		(
			60,
			{
				"Jaw": (2, 0, 0),
				"Rear": (0, -10, 0),
				"TailBase": (0, -16, 0),
				"TailFan": (0, -22, 0),
				"FrontFin.L": (0, 0, -16),
				"FrontFin.R": (0, 0, 16),
				"RearFin.L": (-6, 0, -10),
				"RearFin.R": (-6, 0, 10),
			},
		),
		(
			90,
			{
				"Jaw": (16, 0, 0),
				"Rear": (0, 8, 0),
				"TailBase": (0, 14, 0),
				"TailFan": (0, 20, 0),
				"FrontFin.L": (0, 0, 14),
				"FrontFin.R": (0, 0, -14),
				"RearFin.L": (7, 0, 11),
				"RearFin.R": (7, 0, -11),
			},
		),
		(
			120,
			{
				"Jaw": (0, 0, 0),
				"Rear": (0, 0, 0),
				"TailBase": (0, 0, 0),
				"TailFan": (0, 0, 0),
				"FrontFin.L": (0, 0, 0),
				"FrontFin.R": (0, 0, 0),
				"RearFin.L": (0, 0, 0),
				"RearFin.R": (0, 0, 0),
			},
		),
	]
	for frame, pose in idle_keys:
		key_pose(arm_obj, frame, pose)

	# SWIM keys
	swim_keys = [
		(
			140,
			{
				"Body": (0, 0, 0),
				"Rear": (0, 0, 0),
				"TailBase": (0, 0, 0),
				"TailFan": (0, 0, 0),
				"Jaw": (4, 0, 0),
				"FrontFin.L": (0, 0, 0),
				"FrontFin.R": (0, 0, 0),
				"RearFin.L": (0, 0, 0),
				"RearFin.R": (0, 0, 0),
			},
		),
		(
			155,
			{
				"Body": (0, 8, 0),
				"Rear": (0, 18, 0),
				"TailBase": (0, 28, 0),
				"TailFan": (0, 36, 0),
				"Jaw": (10, 0, 0),
				"FrontFin.L": (12, 0, 28),
				"FrontFin.R": (-12, 0, -28),
				"RearFin.L": (10, 0, 22),
				"RearFin.R": (-10, 0, -22),
			},
		),
		(
			170,
			{
				"Body": (0, -8, 0),
				"Rear": (0, -18, 0),
				"TailBase": (0, -28, 0),
				"TailFan": (0, -36, 0),
				"Jaw": (2, 0, 0),
				"FrontFin.L": (-12, 0, -28),
				"FrontFin.R": (12, 0, 28),
				"RearFin.L": (-10, 0, -22),
				"RearFin.R": (10, 0, 22),
			},
		),
		(
			185,
			{
				"Body": (0, 6, 0),
				"Rear": (0, 14, 0),
				"TailBase": (0, 24, 0),
				"TailFan": (0, 32, 0),
				"Jaw": (12, 0, 0),
				"FrontFin.L": (10, 0, 24),
				"FrontFin.R": (-10, 0, -24),
				"RearFin.L": (8, 0, 18),
				"RearFin.R": (-8, 0, -18),
			},
		),
		(
			200,
			{
				"Body": (0, 0, 0),
				"Rear": (0, 0, 0),
				"TailBase": (0, 0, 0),
				"TailFan": (0, 0, 0),
				"Jaw": (4, 0, 0),
				"FrontFin.L": (0, 0, 0),
				"FrontFin.R": (0, 0, 0),
				"RearFin.L": (0, 0, 0),
				"RearFin.R": (0, 0, 0),
			},
		),
	]
	for frame, pose in swim_keys:
		key_pose(arm_obj, frame, pose)

	# Push actions into named actions for clarity
	if arm_obj.animation_data and arm_obj.animation_data.action:
		arm_obj.animation_data.action.name = "LeviathanIdleSwim"

	idle_clip = sample_clip(arm_obj, 1, 120, fps)
	swim_clip = sample_clip(arm_obj, 140, 200, fps)

	# Reset to rest for mesh export
	bpy.context.scene.frame_set(1)
	bpy.context.view_layer.update()

	bpy.ops.object.mode_set(mode="OBJECT")
	bpy.context.view_layer.objects.active = mesh_obj
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.select_all(action="SELECT")
	bpy.ops.mesh.quads_convert_to_tris(quad_method="BEAUTY", ngon_method="BEAUTY")
	bpy.ops.object.mode_set(mode="OBJECT")
	me = mesh_obj.data
	if not me.uv_layers:
		raise RuntimeError("FBX mesh has no UVs")
	uv_layer = me.uv_layers.active

	bones_out = []
	name_to_index = {}
	for i, (name, parent_index) in enumerate(BONES, start=1):
		bones_out.append({"name": name, "parent": parent_index, "cf": bone_cfs[name]})
		name_to_index[name] = i

	group_index_to_bone = {}
	for g in mesh_obj.vertex_groups:
		if g.name in name_to_index:
			group_index_to_bone[g.index] = name_to_index[g.name]

	verts_out = []
	for v in me.vertices:
		weights = []
		for g in v.groups:
			bone_i = group_index_to_bone.get(g.group)
			if bone_i and g.weight > 1e-4:
				weights.append((bone_i, g.weight))
		weights.sort(key=lambda item: item[1], reverse=True)
		weights = weights[:4]
		if not weights:
			weights = [(1, 1.0)]
		total = sum(w for _, w in weights) or 1.0
		verts_out.append(
			[
				round(v.co.x, 7),
				round(v.co.y, 7),
				round(v.co.z, 7),
				[b for b, _ in weights],
				[round(w / total, 6) for _, w in weights],
			]
		)

	uvs_out, uv_key_to_index = [], {}
	normals_out, n_key_to_index = [], {}
	faces_out = []
	for poly in me.polygons:
		loops = list(poly.loop_indices)
		if len(loops) != 3:
			continue
		n = poly.normal
		nkey = (round(n.x, 4), round(n.y, 4), round(n.z, 4))
		if nkey not in n_key_to_index:
			normals_out.append([nkey[0], nkey[1], nkey[2]])
			n_key_to_index[nkey] = len(normals_out)
		ni = n_key_to_index[nkey]
		v_idx, uv_idx, n_idx = [], [], []
		for li in loops:
			loop = me.loops[li]
			v_idx.append(loop.vertex_index + 1)
			uv = uv_layer.data[li].uv
			key = (round(uv.x, 6), round(uv.y, 6))
			if key not in uv_key_to_index:
				uvs_out.append([key[0], key[1]])
				uv_key_to_index[key] = len(uvs_out)
			uv_idx.append(uv_key_to_index[key])
			n_idx.append(ni)
		faces_out.append([v_idx, uv_idx, 1, n_idx])

	payload = {
		"bones": bones_out,
		"vertices": verts_out,
		"faces": faces_out,
		"uvs": uvs_out,
		"normals": normals_out,
		"colors": [[1, 1, 1]],
	}

	xs = [v[0] for v in verts_out]
	ys = [v[1] for v in verts_out]
	zs = [v[2] for v in verts_out]
	meta = {
		"verts": len(verts_out),
		"faces": len(faces_out),
		"uvs": len(uvs_out),
		"bones": {name: list(positions[name]) for name, _ in BONES},
		"bounds": {
			"min": [min(xs), min(ys), min(zs)],
			"max": [max(xs), max(ys), max(zs)],
			"size": [max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)],
		},
		"snout": min(zs),
		"scale_applied": scale,
		"idle_samples": len(idle_clip["samples"]),
		"swim_samples": len(swim_clip["samples"]),
	}
	with open(os.path.join(OUT_DIR, "meta.json"), "w", encoding="utf-8") as f:
		json.dump(meta, f, indent=2)
	print("META", json.dumps(meta))

	for name in os.listdir(MESH_DIR):
		if name.startswith("Chunk") and name.endswith(".luau"):
			os.remove(os.path.join(MESH_DIR, name))
	raw = json.dumps(payload, separators=(",", ":"))
	index = 1
	for i in range(0, len(raw), CHUNK_PAYLOAD):
		chunk = raw[i : i + CHUNK_PAYLOAD]
		path = os.path.join(MESH_DIR, f"Chunk{index:02d}.luau")
		with open(path, "w", encoding="utf-8") as f:
			f.write("return [==[" + chunk + "]==]\n")
		print("wrote", path, os.path.getsize(path))
		index += 1

	clips = {"idle": idle_clip, "swim": swim_clip}
	clips_json = json.dumps(clips, separators=(",", ":"))
	with open(CLIPS_LUA, "w", encoding="utf-8") as f:
		f.write(
			'return game:GetService("HttpService"):JSONDecode([==['
			+ clips_json
			+ "]==])\n"
		)
	print("wrote", CLIPS_LUA, os.path.getsize(CLIPS_LUA))

	# Export animated FBX for Studio import
	bpy.ops.object.select_all(action="DESELECT")
	mesh_obj.select_set(True)
	arm_obj.select_set(True)
	bpy.context.view_layer.objects.active = arm_obj
	bpy.ops.export_scene.fbx(
		filepath=EXPORT_FBX,
		use_selection=True,
		add_leaf_bones=False,
		bake_anim=True,
		bake_anim_use_all_bones=True,
		bake_anim_use_nla_strips=False,
		bake_anim_use_all_actions=False,
		bake_anim_force_startend_keying=True,
		path_mode="COPY",
		embed_textures=True,
	)
	print("exported", EXPORT_FBX)

	bpy.ops.wm.save_as_mainfile(filepath=BLEND)
	print("saved", BLEND)
	print("DONE")


if __name__ == "__main__":
	main()
