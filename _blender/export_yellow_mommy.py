# Replace mommy visuals with Downloads/yellow-trex FBX, re-rig with the same
# 11 bones / hierarchy, auto-skin, export MommyMeshData for the existing clips.
import bpy
import json
import os
from mathutils import Vector, Matrix

FBX = "/Users/orlan/Downloads/yellow-trex/Meshy_AI_Geometric_Predator_1018145446_texture.fbx"
MESH_DIR = "/Users/orlan/Desktop/steal eggs/src/shared/MommyMeshData"
OLD_BONES = "/Users/orlan/Desktop/steal eggs/_assets/yellow-trex/old_mommy.json"
OUT_META = "/Users/orlan/Desktop/steal eggs/_assets/yellow-trex/new_mommy_meta.json"
CHUNK_PAYLOAD = 180000

# Same order / parents as the live MommyClips samples.
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
	return Matrix((
		(r00, r01, r02, x),
		(r10, r11, r12, y),
		(r20, r21, r22, z),
		(0.0, 0.0, 0.0, 1.0),
	))


def matrix_to_cframe(m):
	return [
		round(m[0][3], 7), round(m[1][3], 7), round(m[2][3], 7),
		round(m[0][0], 7), round(m[0][1], 7), round(m[0][2], 7),
		round(m[1][0], 7), round(m[1][1], 7), round(m[1][2], 7),
		round(m[2][0], 7), round(m[2][1], 7), round(m[2][2], 7),
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


def main():
	old = load_old_bones()
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.import_scene.fbx(filepath=FBX)
	mesh_obj = next(o for o in bpy.data.objects if o.type == "MESH")
	mesh_obj.name = "YellowTrex"
	bpy.context.view_layer.objects.active = mesh_obj
	mesh_obj.select_set(True)
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

	# FBX length on Y (head at -Y) -> mommy length on Z (head at -Z, up +Y).
	for v in mesh_obj.data.vertices:
		x, y, z = v.co
		v.co = Vector((x, z, y))
	mesh_obj.data.update()

	xs = [v.co.x for v in mesh_obj.data.vertices]
	ys = [v.co.y for v in mesh_obj.data.vertices]
	zs = [v.co.z for v in mesh_obj.data.vertices]
	size = Vector((max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)))
	scale = 3.325 / max(size.z, 1e-6)
	for v in mesh_obj.data.vertices:
		v.co *= scale
	xs = [v.co.x for v in mesh_obj.data.vertices]
	ys = [v.co.y for v in mesh_obj.data.vertices]
	zs = [v.co.z for v in mesh_obj.data.vertices]
	center = Vector(((min(xs) + max(xs)) * 0.5, (min(ys) + max(ys)) * 0.5, (min(zs) + max(zs)) * 0.5))
	for v in mesh_obj.data.vertices:
		v.co -= center
	zs = [v.co.z for v in mesh_obj.data.vertices]
	shift = -1.662 - min(zs)
	for v in mesh_obj.data.vertices:
		v.co.z += shift
	mesh_obj.data.update()

	coords = [v.co.copy() for v in mesh_obj.data.vertices]

	def in_z(a, b):
		return [p for p in coords if a <= p.z <= b]

	def side(points, sign, min_abs=0.25):
		picked = [p for p in points if p.x * sign > min_abs]
		return picked if picked else points

	# Landmarks on the replacement mesh, bone rotations reused from the old rig
	# so MommyClips local quaternions still spin the same axes.
	root_pos = Vector((0.0, -0.12, 0.0))
	head_pts = in_z(-1.55, -0.75)
	jaw_pts = [p for p in head_pts if p.y < average(head_pts).y - 0.05] or head_pts
	body_pts = in_z(-0.75, -0.2)
	rear_pts = in_z(-0.05, 0.35)
	tail_pts = in_z(0.45, 0.95)
	fan_pts = in_z(1.05, 1.7)
	front_band = in_z(-1.2, -0.55)
	rear_band = in_z(-0.4, 0.2)

	positions = {
		"Root": root_pos,
		"Head": average(head_pts) if head_pts else Vector((0.0, 0.05, -1.0)),
		"Jaw": average(jaw_pts) if jaw_pts else Vector((0.0, -0.05, -1.15)),
		"Body": average(body_pts) if body_pts else Vector((0.0, -0.05, -0.55)),
		"Rear": average(rear_pts) if rear_pts else Vector((0.0, -0.1, 0.15)),
		"TailBase": average(tail_pts) if tail_pts else Vector((0.0, 0.0, 0.73)),
		"TailFan": average(fan_pts) if fan_pts else Vector((0.0, 0.15, 1.2)),
		"FrontFin.L": average(side(front_band, 1.0)) if front_band else Vector((0.45, -0.15, -0.9)),
		"FrontFin.R": average(side(front_band, -1.0)) if front_band else Vector((-0.45, -0.15, -0.9)),
		"RearFin.L": average(side(rear_band, 1.0)) if rear_band else Vector((0.45, -0.2, -0.2)),
		"RearFin.R": average(side(rear_band, -1.0)) if rear_band else Vector((-0.45, -0.2, -0.2)),
	}

	bone_cfs = {}
	for name, _parent in BONES:
		bone_cfs[name] = placed(old[name]["cf"], positions[name])

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
		verts_out.append([
			round(v.co.x, 7), round(v.co.y, 7), round(v.co.z, 7),
			[b for b, _ in weights],
			[round(w / total, 6) for _, w in weights],
		])

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
	headish = [v for v in verts_out if v[2] < -0.35]
	hxs = [v[0] for v in headish]
	hys = [v[1] for v in headish]
	hzs = [v[2] for v in headish]
	meta = {
		"verts": len(verts_out),
		"faces": len(faces_out),
		"uvs": len(uvs_out),
		"bones": {name: positions[name][:] for name, _ in BONES},
		"bounds": {
			"min": [min(xs), min(ys), min(zs)],
			"max": [max(xs), max(ys), max(zs)],
			"size": [max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)],
		},
		"head_size": [max(hxs) - min(hxs), max(hys) - min(hys), max(hzs) - min(hzs)],
		"head_center_y": (min(hys) + max(hys)) * 0.5,
		"snout": min(zs),
		"scale_applied": scale,
	}
	os.makedirs(os.path.dirname(OUT_META), exist_ok=True)
	with open(OUT_META, "w", encoding="utf-8") as f:
		json.dump(meta, f, indent=2)
	print("META", json.dumps(meta))

	raw = json.dumps(payload, separators=(",", ":"))
	for name in os.listdir(MESH_DIR):
		if name.startswith("Chunk") and name.endswith(".luau"):
			os.remove(os.path.join(MESH_DIR, name))
	index = 1
	for i in range(0, len(raw), CHUNK_PAYLOAD):
		chunk = raw[i : i + CHUNK_PAYLOAD]
		path = os.path.join(MESH_DIR, f"Chunk{index:02d}.luau")
		with open(path, "w", encoding="utf-8") as f:
			f.write("return [==[" + chunk + "]==]\n")
		print("wrote", path, os.path.getsize(path))
		index += 1
	print("DONE chunks", index - 1)


if __name__ == "__main__":
	main()
