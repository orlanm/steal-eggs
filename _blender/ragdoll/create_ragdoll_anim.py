"""R15 ragdoll knockdown for the guard tackle and fast wall crashes.

Builds an R15 mannequin from the player's real joint frames (r15_rig.json, dumped in Studio) and keys:
kicked up off the feet, a slow-motion spinning float at the top, a fast drop flat onto the floor face
down, a bounce, then a limp, twisted crumple that is held.

The body's height and tumble live in the animation (Root joint translation + rotation); the server only
slides the upright, anchored HumanoidRootPart along the floor at standing height. That makes floor
contact exact and checkable here:
  * landed key poses are ground-solved: the torso is lowered onto the floor, then every arm, leg and
    the head is swung down until it rests on the floor (no limb left hanging in the air);
  * every frame is lifted if any part would dip below the floor (nothing sinks into it).

    blender -b --python _blender/ragdoll/create_ragdoll_anim.py

Outputs (next to this script): ragdoll.blend, R15_Ragdoll.fbx, R15_Ragdoll.rbxmx, preview/*.png,
contact.json (per-part floor gaps of the landed poses)

Joint rotations are authored in the character's axes (Roblox: X right, Y up, Z back; R15 joint frames
are axis-aligned, so these are exactly the AnimationConstraint / Motor6D Transforms).
  +X  swings a hanging limb forward, tips torso / head back; knees bend with -X, elbows with +X
  +Z  swings a hanging limb toward +X (right arm / leg out); left limb out is -Z
  +Y  turns toward the left (yaw)
Root -90 X lays the body face down with the head toward the facing direction.
"""
import json
import math
from pathlib import Path

import bpy
from mathutils import Matrix, Quaternion, Vector

HERE = Path(__file__).resolve().parent
RIG = json.load(open(HERE / "r15_rig.json"))
FPS = 30
LAND = 1.12  # seconds: first floor impact (server: Knockdown LAND_TIME, landing VFX)
LENGTH = 2.6  # seconds; the last pose is held by the server until recovery / respawn
HRP_Y = 3.0  # HumanoidRootPart height above the floor when standing (HipHeight 2 + half of 2)
DEBUG = __import__("os").environ.get("RAGDEBUG") == "1"
CONTACT = 0.03  # studs: resting parts sit this far above the floor

# ------------------------------------------------------------------------------------------------
# Key poses: time, ease into this key, root lift (studs; "ground" = solved onto the floor, or
# ("ground", +h) for a bounce h above the solved height), joint angles (degrees, [x, y, z]).
# ------------------------------------------------------------------------------------------------
LIMP = {  # the crumpled, twisted prone pose everything lands into
	"Root": [-90, 360, -3], "Waist": [0, 6, -3], "Neck": [10, 72, 6],
	"LeftShoulder": [165, 10, -28], "LeftElbow": [55, 0, 0], "LeftWrist": [0, 0, -20],
	"RightShoulder": [18, -10, 32], "RightElbow": [28, 0, 0], "RightWrist": [10, 0, 25],
	"LeftHip": [8, -65, -38], "LeftKnee": [-75, 0, 0], "LeftAnkle": [20, 0, 0],
	"RightHip": [-4, 18, 12], "RightKnee": [-6, 0, 0], "RightAnkle": [35, 0, 0],
}


def varied(pose, scale, **over):
	out = {k: [a * scale for a in v] for k, v in pose.items()}
	out["Root"] = list(pose["Root"])
	out.update(over)
	return out


KEYS = [
	(0.00, "smooth", 0.0, {  # hit mid-stride
		"Root": [0, 0, 0], "Waist": [-6, 0, 0], "Neck": [0, 0, 0],
		"LeftShoulder": [20, 0, -8], "LeftElbow": [30, 0, 0], "RightShoulder": [-15, 0, 8], "RightElbow": [25, 0, 0],
		"LeftHip": [25, 0, 0], "LeftKnee": [-20, 0, 0], "RightHip": [-15, 0, 0], "RightKnee": [-35, 0, 0],
	}),
	(0.14, "out", 1.5, {  # kicked up: arched back, head snapped, limbs flung
		"Root": [30, 40, -12], "Waist": [26, 10, -8], "Neck": [40, -20, 12],
		"LeftShoulder": [140, 20, -60], "LeftElbow": [30, 0, 0], "LeftWrist": [0, 0, -15],
		"RightShoulder": [160, -25, 55], "RightElbow": [20, 0, 0], "RightWrist": [10, 0, 20],
		"LeftHip": [50, 10, -18], "LeftKnee": [-35, 0, 0], "LeftAnkle": [20, 0, 0],
		"RightHip": [20, -10, 20], "RightKnee": [-80, 0, 0], "RightAnkle": [30, 0, 0],
	}),
	(0.58, "out", 2.5, {  # slow-motion float at the top, spread out and turning over
		"Root": [-48, 175, 38], "Waist": [14, -16, 12], "Neck": [24, 30, -18],
		"LeftShoulder": [110, -10, -95], "LeftElbow": [50, 0, 10], "LeftWrist": [0, 0, -30],
		"RightShoulder": [100, 25, 100], "RightElbow": [65, 15, 0], "RightWrist": [25, 0, 20],
		"LeftHip": [30, 20, -40], "LeftKnee": [-60, 0, 0], "LeftAnkle": [35, 0, 10],
		"RightHip": [45, -15, 38], "RightKnee": [-25, 0, 0], "RightAnkle": [15, 10, -10],
	}),
	(0.90, "smooth", 1.9, {  # tipping forward, limbs trailing up as it starts to fall
		"Root": [-75, 300, 18], "Waist": [-10, 10, 8], "Neck": [-15, 50, 10],
		"LeftShoulder": [170, 5, -60], "LeftElbow": [40, 0, 0], "LeftWrist": [0, 0, -20],
		"RightShoulder": [40, -10, 70], "RightElbow": [35, 0, 0], "RightWrist": [15, 0, 25],
		"LeftHip": [-10, -40, -35], "LeftKnee": [-45, 0, 0], "LeftAnkle": [25, 0, 0],
		"RightHip": [-20, 10, 20], "RightKnee": [-30, 0, 0], "RightAnkle": [30, 0, 0],
	}),
	(LAND, "in", "ground", varied(LIMP, 1.0, Root=[-90, 360, 6])),  # slam flat
	(1.26, "out", ("ground", 0.55), varied(LIMP, 0.85, Root=[-80, 362, 12],
		LeftShoulder=[150, 20, -40], RightShoulder=[35, -5, 45], Neck=[25, 60, 0],
		LeftHip=[18, -55, -30], RightHip=[12, 20, 18])),  # bounce, limbs lifted
	(1.42, "in", "ground", varied(LIMP, 1.0, Root=[-90, 359, 8])),
	(1.52, "out", ("ground", 0.12), varied(LIMP, 0.95, Root=[-86, 359, 10])),  # small second bounce
	(1.64, "in", "ground", LIMP),
	(LENGTH, "smooth", "ground", LIMP),  # held
]

# Loose-part wobble (deg amplitude, Hz, phase): slow flailing in the air, a slap after each landing.
FLOP = {
	"Neck": (8, 2.4, 0.1), "LeftWrist": (16, 3.0, 0.4), "RightWrist": (16, 2.7, 0.9),
	"LeftElbow": (12, 2.2, 0.2), "RightElbow": (12, 2.0, 0.7), "LeftShoulder": (8, 1.6, 0.5),
	"RightShoulder": (8, 1.8, 0.0), "LeftAnkle": (12, 3.2, 0.3), "RightAnkle": (12, 2.9, 0.6),
	"LeftKnee": (9, 2.3, 0.8), "RightKnee": (9, 2.1, 0.15), "Waist": (4, 1.5, 0.35),
}
HINGES = {"LeftElbow", "RightElbow", "LeftKnee", "RightKnee"}
LIMBS = [  # chains swung onto the floor at ground keys (each joint lays its own segment down)
	["LeftShoulder", "LeftElbow", "LeftWrist"], ["RightShoulder", "RightElbow", "RightWrist"],
	["LeftHip", "LeftKnee", "LeftAnkle"], ["RightHip", "RightKnee", "RightAnkle"], ["Neck"],
]
HINGE_RANGE = {"LeftElbow": (0, 135), "RightElbow": (0, 135), "LeftKnee": (-135, 0), "RightKnee": (-135, 0)}

# ------------------------------------------------------------------------------------------------
# Rig + forward kinematics in Roblox space (part = part0 * C0 * Transform * C1^-1; frames axis-aligned)
# ------------------------------------------------------------------------------------------------
joints = RIG["joints"]
by_name = {j["name"]: j for j in joints}
by_child = {j["part1"]: j for j in joints}
child_of = {j["name"]: j["part1"] for j in joints}
order = []  # joints parent-first


def visit(part):
	for j in joints:
		if j["part0"] == part:
			order.append(j["name"])
			visit(j["part1"])


visit("HumanoidRootPart")
SIZES = {k: Vector(v) for k, v in RIG["parts"].items()}
CORNERS = [Vector((sx, sy, sz)) for sx in (-.5, .5) for sy in (-.5, .5) for sz in (-.5, .5)]


def rot_roblox(deg):
	x, y, z = (math.radians(v) for v in deg)
	return Matrix.Rotation(x, 3, "X") @ Matrix.Rotation(y, 3, "Y") @ Matrix.Rotation(z, 3, "Z")


def fk(rots, lift):
	"""World matrices of every part. rots: joint -> 3x3, lift: Root translation Y."""
	world = {"HumanoidRootPart": Matrix.Translation((0, HRP_Y, 0))}
	for name in order:
		j = by_name[name]
		t = rots[name].to_4x4()
		if name == "Root":
			t.translation = Vector((0, lift, 0))
		world[j["part1"]] = world[j["part0"]] @ Matrix.Translation(Vector(j["c0"])) @ t @ Matrix.Translation(Vector(j["c1"]) * -1)
	return world


def low(world, parts):
	return min((world[p] @ Vector((c.x * SIZES[p].x, c.y * SIZES[p].y, c.z * SIZES[p].z))).y
			   for p in parts for c in CORNERS)


def subtree(joint):
	parts, stack = [], [child_of[joint]]
	while stack:
		p = stack.pop()
		parts.append(p)
		stack += [j["part1"] for j in joints if j["part0"] == p]
	return parts


TORSO = ["LowerTorso", "UpperTorso"]
ALL_PARTS = [p for p in SIZES if p != "HumanoidRootPart"]


def swing(rots, lift, joint, axis_world, deg):
	"""rots with `joint` turned by deg about a world axis (pre-multiplied in its parent frame)."""
	world = fk(rots, lift)
	parent_rot = world[by_name[joint]["part0"]].to_3x3()
	r = dict(rots)
	r[joint] = parent_rot.transposed() @ Matrix.Rotation(math.radians(deg), 3, axis_world) @ parent_rot @ rots[joint]
	return r


def best(candidates, target):
	"""Pick the (own gap, subtree gap, delta, rots) that lays the joint's own segment closest to the floor
	while nothing below it goes under, preferring small corrections."""
	ok = [c for c in candidates if c[0] >= target - 0.005]
	pool = ok or [max(candidates, key=lambda c: c[1])]
	return min(pool, key=lambda c: (abs(c[0] - target) + 0.002 * abs(c[2])))


def ground(rots, bounce=0.0):
	"""Lay the torso on the floor and swing every limb / the head down onto it."""
	# bend the waist so both torso halves lie flat, then rest them on the floor
	def flat(dx):
		r = dict(rots)
		r["Waist"] = rots["Waist"] @ rot_roblox([dx, 0, 0])
		w = fk(r, 0.0)
		a, b = low(w, ["LowerTorso"]), low(w, ["UpperTorso"])
		return abs(a - b), r
	rots = min((flat(dx) for dx in range(-30, 31)), key=lambda c: c[0])[1]
	lift = 0.0
	lift -= low(fk(rots, lift), TORSO) - CONTACT
	for chain in LIMBS:
		for i, joint in enumerate(chain):
			parts = subtree(joint)
			own = [child_of[joint]]
			world = fk(rots, lift)
			pivot = (world[by_name[joint]["part0"]] @ Matrix.Translation(Vector(by_name[joint]["c0"]))).translation
			centre = sum((world[p].translation for p in parts), Vector()) / len(parts)
			if joint in HINGES:
				lo, hi = HINGE_RANGE[joint]
				base = rots[joint]
				cands = []
				for d in range(-60, 61, 2):
					r = dict(rots)
					extra = rot_roblox([d, 0, 0])
					trial = base @ extra
					ang = math.degrees(trial.to_euler("XYZ").x)
					if not (lo - 1 <= ang <= hi + 1):
						continue
					r[joint] = trial
					w = fk(r, lift)
					cands.append((low(w, own), low(w, parts), d, r))
			else:
				dirv = centre - pivot
				if DEBUG and joint == "Neck":
					print("   neck pivot", tuple(round(v, 2) for v in pivot), "centre", tuple(round(v, 2) for v in centre))
				axis = dirv.cross(Vector((0, -1, 0)))
				if axis.length < 1e-4:
					continue
				axis.normalize()
				cands = []
				for d in range(-50, 91, 2):
					r = swing(rots, lift, joint, axis, d)
					w = fk(r, lift)
					cands.append((low(w, own), low(w, parts), d, r))
			if cands:
				pick = best(cands, CONTACT)
				rots = pick[3]
				if DEBUG:
					print(f"  {joint:14s} d={pick[2]:4d} own={pick[0]:.3f} sub={pick[1]:.3f} range=({min(c[0] for c in cands):.2f},{max(c[0] for c in cands):.2f})")
	# second pass, tip first: lift any joint whose segments went under the floor
	for chain in LIMBS:
		for joint in reversed(chain):
			parts = subtree(joint)
			if low(fk(rots, lift), parts) >= CONTACT - 0.005:
				continue
			world = fk(rots, lift)
			pivot = (world[by_name[joint]["part0"]] @ Matrix.Translation(Vector(by_name[joint]["c0"]))).translation
			centre = sum((world[p].translation for p in parts), Vector()) / len(parts)
			if joint in HINGES:
				cands = []
				for d in range(-60, 61, 2):
					r = dict(rots)
					r[joint] = rots[joint] @ rot_roblox([d, 0, 0])
					w = fk(r, lift)
					cands.append((low(w, parts), low(w, parts), d, r))
			else:
				axis = (centre - pivot).cross(Vector((0, -1, 0)))
				if axis.length < 1e-4:
					continue
				axis.normalize()
				cands = []
				for d in range(-60, 31, 2):
					r = swing(rots, lift, joint, axis, d)
					w = fk(r, lift)
					cands.append((low(w, parts), low(w, parts), d, r))
			rots = best(cands, CONTACT)[3]
	# anything still under the floor lifts the whole body
	lift -= min(0.0, low(fk(rots, lift), ALL_PARTS) - CONTACT * 0.5)
	return rots, lift + bounce


# ------------------------------------------------------------------------------------------------
# Solve the key poses, then sample every frame
# ------------------------------------------------------------------------------------------------
solved = []  # (time, ease, rots, lift, raw angles)
for t, ease, lift, pose in KEYS:
	rots = {n: rot_roblox(pose.get(n, [0, 0, 0])) for n in order}
	if isinstance(lift, tuple) or lift == "ground":
		bounce = lift[1] if isinstance(lift, tuple) else 0.0
		if DEBUG:
			print("KEY", t)
		rots, lift = ground(rots, bounce)
	solved.append((t, ease, rots, lift, pose))

# Corrections the solver applied, per key and joint, as quaternions on top of the authored Euler pose
corr = []
for t, ease, rots, lift, pose in solved:
	c = {}
	for n in order:
		authored = rot_roblox(pose.get(n, [0, 0, 0]))
		c[n] = (rots[n] @ authored.transposed()).to_quaternion()
	corr.append(c)


def eased(u, kind):
	if kind == "in":
		return u * u
	if kind == "out":
		return 1 - (1 - u) * (1 - u)
	return u * u * (3 - 2 * u)


def segment(t):
	for i in range(len(solved) - 1):
		if solved[i][0] <= t <= solved[i + 1][0]:
			return i
	return len(solved) - 2


def channel(i, n, axis, t):
	"""Euler channel through the keys: Catmull-Rom while airborne (continuous spin), eased after landing."""
	ta, tb = solved[i][0], solved[i + 1][0]
	u = (t - ta) / max(tb - ta, 1e-6)
	pa = solved[i][4].get(n, [0, 0, 0])[axis]
	pb = solved[i + 1][4].get(n, [0, 0, 0])[axis]
	if tb <= LAND + 1e-6:
		def val(k):
			k = min(max(k, 0), len(solved) - 1)
			return solved[k][4].get(n, [0, 0, 0])[axis], solved[k][0]
		p0, t0 = val(i - 1)
		p3, t3 = val(i + 2)
		m1 = (pb - p0) / max(tb - t0, 1e-6) * (tb - ta) if i > 0 else 0.0
		m2 = (p3 - pa) / max(t3 - ta, 1e-6) * (tb - ta) if tb < LAND - 1e-6 else (pb - pa) * 1.6
		h = (2 * u ** 3 - 3 * u ** 2 + 1, u ** 3 - 2 * u ** 2 + u, -2 * u ** 3 + 3 * u ** 2, u ** 3 - u ** 2)
		return h[0] * pa + h[1] * m1 + h[2] * pb + h[3] * m2
	return pa + (pb - pa) * eased(u, solved[i + 1][1])


def flop(n, t):
	if n not in FLOP or t < 0.14:
		return [0, 0, 0]
	amp, hz, ph = FLOP[n]
	env = 0.8 * min(1.0, (t - 0.14) / 0.1) * (1.0 if t < LAND else math.exp(-5.0 * (t - LAND)))
	for slap in (LAND, 1.42):
		if t > slap:
			env += 0.7 * math.exp(-6.0 * (t - slap)) * min(1.0, (t - slap) / 0.04)
	w = amp * env
	axes = (1, 0, 0) if n in HINGES else (1, 0.6, 0.8)
	return [w * axes[0] * math.sin(2 * math.pi * (hz * t + ph)),
			w * axes[1] * math.sin(2 * math.pi * (hz * 0.8 * t + ph + 0.25)),
			w * axes[2] * math.sin(2 * math.pi * (hz * 1.1 * t + ph + 0.5))]


def frame_pose(t):
	i = segment(t)
	ta, tb = solved[i][0], solved[i + 1][0]
	u = (t - ta) / max(tb - ta, 1e-6)
	ue = eased(u, solved[i + 1][1])
	lift = solved[i][3] + (solved[i + 1][3] - solved[i][3]) * ue
	rots = {}
	for n in order:
		ang = [channel(i, n, a, t) for a in range(3)]
		wob = flop(n, t)
		ang = [ang[a] + wob[a] for a in range(3)]
		q = corr[i][n].slerp(corr[i + 1][n], ue)
		rots[n] = q.to_matrix() @ rot_roblox(ang)
	# nothing may sink into the floor
	gap = low(fk(rots, lift), ALL_PARTS)
	if gap < 0:
		lift -= gap
	return rots, lift


nframes = int(round(LENGTH * FPS)) + 1
frames = [frame_pose(f / FPS) for f in range(nframes)]

# Contact report for the landed poses
report = {}
for t, ease, rots, lift, pose in solved:
	if t >= LAND - 1e-6:
		w = fk(rots, lift)
		report[f"{t:.2f}"] = {p: round(low(w, [p]), 3) for p in ALL_PARTS}
json.dump(report, open(HERE / "contact.json", "w"), indent=1)
fin = report[f"{LENGTH:.2f}"]
print("FINAL contact gaps:", {k: v for k, v in sorted(fin.items(), key=lambda kv: kv[1])})
print("min over all frames:", round(min(low(fk(r, l), ALL_PARTS) for r, l in frames), 3))

# ------------------------------------------------------------------------------------------------
# KeyframeSequence (.rbxmx)
# ------------------------------------------------------------------------------------------------
children = {}
for j in joints:
	children.setdefault(j["part0"], []).append(j["part1"])
joint_of_part = {j["part1"]: j["name"] for j in joints}


def xml_cf(r, pos=(0, 0, 0)):
	vals = dict(X=pos[0], Y=pos[1], Z=pos[2], R00=r[0][0], R01=r[0][1], R02=r[0][2], R10=r[1][0], R11=r[1][1],
				R12=r[1][2], R20=r[2][0], R21=r[2][1], R22=r[2][2])
	return "".join(f"<{k}>{v:.6g}</{k}>" for k, v in vals.items())


def pose_xml(part, rots, lift):
	kids = "".join(pose_xml(c, rots, lift) for c in children.get(part, []))
	jn = joint_of_part.get(part)
	if jn:
		cf = xml_cf(rots[jn], (0, lift, 0) if jn == "Root" else (0, 0, 0))
		weight = 1
	else:
		cf = xml_cf(Matrix.Identity(3))
		weight = 0
	return (f'<Item class="Pose"><Properties><CoordinateFrame name="CFrame">{cf}</CoordinateFrame>'
			f'<token name="EasingDirection">0</token><token name="EasingStyle">0</token>'
			f'<string name="Name">{part}</string><float name="Weight">{weight}</float></Properties>{kids}</Item>')


items = []
for f, (rots, lift) in enumerate(frames):
	items.append(f'<Item class="Keyframe"><Properties><string name="Name">Keyframe</string>'
				 f'<float name="Time">{f / FPS:.5f}</float></Properties>{pose_xml("HumanoidRootPart", rots, lift)}</Item>')
xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" version="4">'
	   '<Item class="KeyframeSequence"><Properties><string name="Name">R15_Ragdoll</string>'
	   '<bool name="Loop">false</bool><token name="Priority">5</token></Properties>'  # Action4
	   + "".join(items) + "</Item></roblox>")
(HERE / "R15_Ragdoll.rbxmx").write_text(xml)
print(f"RBXMX OK frames={nframes}")

# ------------------------------------------------------------------------------------------------
# Blender scene: one box per part driven by the same FK (Roblox (x, y, z) -> Blender (x, -z, y)),
# armature keyed from it for the FBX, preview renders, .blend
# ------------------------------------------------------------------------------------------------
S = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = FPS
scene.frame_start, scene.frame_end = 0, nframes - 1
COLORS = {"Left": (0.35, 0.55, 0.95, 1), "Right": (0.95, 0.45, 0.35, 1), "Head": (0.98, 0.85, 0.4, 1)}
boxes = {}
for part in ALL_PARTS:
	size = SIZES[part]
	bpy.ops.mesh.primitive_cube_add(size=1)
	cube = bpy.context.active_object
	cube.name = part
	cube.scale = (size.x, size.z, size.y)
	bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
	mat = bpy.data.materials.new(part)
	mat.diffuse_color = next((c for k, c in COLORS.items() if part.startswith(k)), (0.8, 0.8, 0.8, 1))
	cube.data.materials.append(mat)
	cube.rotation_mode = "QUATERNION"
	boxes[part] = cube
for f, (rots, lift) in enumerate(frames):
	w = fk(rots, lift)
	for part, cube in boxes.items():
		m = S @ w[part] @ S.transposed()
		cube.location = m.translation
		cube.rotation_quaternion = m.to_quaternion()
		cube.keyframe_insert("location", frame=f)
		cube.keyframe_insert("rotation_quaternion", frame=f)
bpy.ops.mesh.primitive_plane_add(size=14, location=(0, -2, 0))
floor = bpy.context.active_object
floor.name = "Floor"
fm = bpy.data.materials.new("Floor")
fm.diffuse_color = (0.45, 0.75, 0.35, 1)
floor.data.materials.append(fm)

cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
scene.collection.objects.link(cam)
scene.camera = cam
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.rotation_euler = (0.6, 0.2, 0.8)
scene.collection.objects.link(sun)
world_bg = bpy.data.worlds.new("W")
world_bg.color = (0.55, 0.6, 0.65)
scene.world = world_bg
try:
	scene.render.engine = "BLENDER_WORKBENCH"
	scene.display.shading.color_type = "MATERIAL"
except TypeError:
	pass
scene.render.resolution_x, scene.render.resolution_y = 360, 300
(HERE / "preview").mkdir(exist_ok=True)
for old in (HERE / "preview").glob("*.png"):
	old.unlink()
target = Vector((0, 1.5, 1.6))
views = {"side": Vector((11, 1.5, 2.2)), "head": Vector((2, 13, 2.6)), "top": Vector((0.5, 1.5, 12))}
for f in (0, 4, 10, 17, 24, 30, 34, 38, 43, 46, 49, 60, 77):
	if f >= nframes:
		continue
	scene.frame_set(f)
	for name, loc in views.items():
		cam.location = loc
		aim = target if f < 30 else Vector((0, 1.5, 0.4))
		cam.rotation_euler = (aim - loc).to_track_quat("-Z", "Y").to_euler()
		scene.render.filepath = str(HERE / "preview" / f"{name}_{f:02d}.png")
		bpy.ops.render.render(write_still=True)

bpy.ops.export_scene.fbx(filepath=str(HERE / "R15_Ragdoll.fbx"), use_selection=False, bake_anim=True,
						 object_types={"MESH"})
bpy.ops.wm.save_as_mainfile(filepath=str(HERE / "ragdoll.blend"))
print("RAGDOLL OK")
