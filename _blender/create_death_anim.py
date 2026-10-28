"""Build an R15-mapped dying fall armature and export Motor6D pose samples for Roblox."""
from __future__ import annotations

import json
from math import radians
from pathlib import Path

import bpy
from mathutils import Euler, Vector

OUT = Path(__file__).resolve().parent / "death_pose_samples.json"
BLEND = Path(__file__).resolve().parent / "r15_death_fall.blend"

# Roblox R15 Motor6D names we drive via Transform.
R15_MAP = {
	"Waist": "Spine",
	"Neck": "Head",
	"LeftShoulder": "LeftUpperArm",
	"LeftElbow": "LeftLowerArm",
	"LeftWrist": "LeftHand",
	"RightShoulder": "RightUpperArm",
	"RightElbow": "RightLowerArm",
	"RightWrist": "RightHand",
	"LeftHip": "LeftUpperLeg",
	"LeftKnee": "LeftLowerLeg",
	"LeftAnkle": "LeftFoot",
	"RightHip": "RightUpperLeg",
	"RightKnee": "RightLowerLeg",
	"RightAnkle": "RightFoot",
}

bpy.ops.wm.read_factory_settings(use_empty=True)

bones = [
	("Hips", None, (0, 0, 1.0), (0, 0, 1.15)),
	("Spine", "Hips", (0, 0, 1.15), (0, 0, 1.45)),
	("Chest", "Spine", (0, 0, 1.45), (0, 0, 1.7)),
	("Neck", "Chest", (0, 0, 1.7), (0, 0, 1.85)),
	("Head", "Neck", (0, 0, 1.85), (0, 0, 2.05)),
	("LeftShoulder", "Chest", (0.12, 0, 1.65), (0.35, 0, 1.62)),
	("LeftUpperArm", "LeftShoulder", (0.35, 0, 1.62), (0.55, 0, 1.35)),
	("LeftLowerArm", "LeftUpperArm", (0.55, 0, 1.35), (0.7, 0, 1.1)),
	("LeftHand", "LeftLowerArm", (0.7, 0, 1.1), (0.82, 0, 1.05)),
	("RightShoulder", "Chest", (-0.12, 0, 1.65), (-0.35, 0, 1.62)),
	("RightUpperArm", "RightShoulder", (-0.35, 0, 1.62), (-0.55, 0, 1.35)),
	("RightLowerArm", "RightUpperArm", (-0.55, 0, 1.35), (-0.7, 0, 1.1)),
	("RightHand", "RightLowerArm", (-0.7, 0, 1.1), (-0.82, 0, 1.05)),
	("LeftUpperLeg", "Hips", (0.12, 0, 1.0), (0.15, 0, 0.55)),
	("LeftLowerLeg", "LeftUpperLeg", (0.15, 0, 0.55), (0.15, 0, 0.15)),
	("LeftFoot", "LeftLowerLeg", (0.15, 0, 0.15), (0.15, -0.12, 0.05)),
	("RightUpperLeg", "Hips", (-0.12, 0, 1.0), (-0.15, 0, 0.55)),
	("RightLowerLeg", "RightUpperLeg", (-0.15, 0, 0.55), (-0.15, 0, 0.15)),
	("RightFoot", "RightLowerLeg", (-0.15, 0, 0.15), (-0.15, -0.12, 0.05)),
]

arm = bpy.data.armatures.new("R15DeathArmature")
obj = bpy.data.objects.new("R15DeathRig", arm)
bpy.context.collection.objects.link(obj)
bpy.context.view_layer.objects.active = obj
bpy.ops.object.mode_set(mode="EDIT")
created = {}
for name, parent, head, tail in bones:
	b = arm.edit_bones.new(name)
	b.head = Vector(head)
	b.tail = Vector(tail)
	if parent:
		b.parent = created[parent]
	created[name] = b
bpy.ops.object.mode_set(mode="POSE")

# Impact -> limp midair (arms trailing) -> crumpled land
poses = {
	1: {
		"LeftUpperArm": (35, 0, -95),
		"RightUpperArm": (40, 0, 100),
		"LeftLowerArm": (0, 0, -35),
		"RightLowerArm": (0, 0, 40),
		"Head": (-25, 15, 10),
		"Chest": (15, 0, -8),
		"Spine": (10, 0, 5),
		"LeftUpperLeg": (-20, 0, -8),
		"RightUpperLeg": (15, 0, 12),
		"LeftLowerLeg": (25, 0, 0),
		"RightLowerLeg": (10, 0, 0),
	},
	12: {
		"LeftUpperArm": (-25, 20, -70),
		"RightUpperArm": (-15, -25, 80),
		"LeftLowerArm": (0, 0, -55),
		"RightLowerArm": (15, 0, 50),
		"LeftHand": (0, 0, -20),
		"RightHand": (0, 0, 25),
		"Head": (35, -10, -15),
		"Chest": (25, 8, 12),
		"Spine": (18, -5, -6),
		"LeftUpperLeg": (35, 0, -15),
		"RightUpperLeg": (-10, 0, 20),
		"LeftLowerLeg": (55, 0, 0),
		"RightLowerLeg": (40, 0, 0),
		"LeftFoot": (-20, 0, 0),
		"RightFoot": (-15, 10, 0),
	},
	24: {
		"LeftUpperArm": (-60, 30, -45),
		"RightUpperArm": (-55, -35, 50),
		"LeftLowerArm": (10, 0, -70),
		"RightLowerArm": (5, 0, 65),
		"LeftHand": (0, 0, -15),
		"RightHand": (0, 0, 20),
		"Head": (50, 20, -25),
		"Chest": (40, 0, 15),
		"Spine": (30, 10, -8),
		"LeftUpperLeg": (70, 15, -20),
		"RightUpperLeg": (55, -20, 25),
		"LeftLowerLeg": (80, 0, 0),
		"RightLowerLeg": (70, 0, 0),
		"LeftFoot": (-35, 0, 15),
		"RightFoot": (-30, 0, -10),
	},
}

scene = bpy.context.scene
scene.frame_start = 1
scene.frame_end = 24
for frame, bone_eulers in poses.items():
	scene.frame_set(frame)
	for bname, xyz in bone_eulers.items():
		pb = obj.pose.bones.get(bname)
		if not pb:
			continue
		pb.rotation_mode = "XYZ"
		pb.rotation_euler = Euler((radians(xyz[0]), radians(xyz[1]), radians(xyz[2])), "XYZ")
		pb.keyframe_insert(data_path="rotation_euler", frame=frame)

# Sample evenly for Roblox Motor6D.Transform (radians XYZ via matrix_basis)
samples = []
for i in range(0, 25):
	frame = 1 + i
	alpha = i / 24
	scene.frame_set(frame)
	bpy.context.view_layer.update()
	pose = {"alpha": round(alpha, 4), "joints": {}}
	for motor, bone in R15_MAP.items():
		pb = obj.pose.bones.get(bone)
		if not pb:
			continue
		e = pb.matrix.to_euler("XYZ")
		# Relative to rest: pose bone matrix_basis euler is cleaner for Transform.
		be = pb.matrix_basis.to_euler("XYZ")
		pose["joints"][motor] = [round(be.x, 4), round(be.y, 4), round(be.z, 4)]
	samples.append(pose)

OUT.write_text(json.dumps({"frames": samples, "fps": 24, "duration": 1.0}, indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
print(f"Wrote {OUT}")
print(f"Saved {BLEND}")
