"""Author a punchy chase cycle on the Lava Leviathan rig and merge into MommyLeviathanClips."""
from __future__ import annotations

import json
import math
import re
from pathlib import Path

import bpy
from mathutils import Euler, Quaternion

BLEND = "/Users/orlan/Desktop/steal eggs/_blender/lava_leviathan_animated.blend"
CLIPS = Path("/Users/orlan/Desktop/steal eggs/src/shared/MommyLeviathanClips.luau")
BONES = [
	"Root",
	"Head",
	"Body",
	"Rear",
	"TailBase",
	"TailFan",
	"RearFin.L",
	"RearFin.R",
	"Jaw",
	"FrontFin.L",
	"FrontFin.R",
]


def quat_wxyz(q: Quaternion):
	q = q.normalized()
	return [round(q.w, 7), round(q.x, 7), round(q.y, 7), round(q.z, 7)]


def key_pose(arm, frame, eulers_deg):
	bpy.context.scene.frame_set(frame)
	for name, xyz in eulers_deg.items():
		pb = arm.pose.bones.get(name)
		if not pb:
			continue
		pb.rotation_mode = "XYZ"
		pb.rotation_euler = Euler(
			(math.radians(xyz[0]), math.radians(xyz[1]), math.radians(xyz[2])), "XYZ"
		)
		pb.keyframe_insert(data_path="rotation_euler", frame=frame)


def main():
	bpy.ops.wm.open_mainfile(filepath=BLEND)
	arm = bpy.data.objects.get("MommyRig")
	assert arm and arm.type == "ARMATURE"
	bpy.context.view_layer.objects.active = arm
	bpy.ops.object.mode_set(mode="POSE")

	fps = 20
	scene = bpy.context.scene
	scene.render.fps = fps
	# Chase on frames 220-268 (2.4s @ 20fps)
	start, end = 220, 268
	keys = [
		(
			220,
			{
				"Body": (0, 0, 0),
				"Rear": (0, 0, 0),
				"TailBase": (0, 0, 0),
				"TailFan": (0, 0, 0),
				"Jaw": (6, 0, 0),
				"FrontFin.L": (0, 0, 0),
				"FrontFin.R": (0, 0, 0),
				"RearFin.L": (0, 0, 0),
				"RearFin.R": (0, 0, 0),
				"Head": (0, 0, 0),
			},
		),
		(
			232,
			{
				"Body": (0, 14, 0),
				"Rear": (0, 28, 0),
				"TailBase": (0, 42, 0),
				"TailFan": (0, 52, 0),
				"Jaw": (18, 0, 0),
				"FrontFin.L": (18, 0, 40),
				"FrontFin.R": (-18, 0, -40),
				"RearFin.L": (16, 0, 32),
				"RearFin.R": (-16, 0, -32),
				"Head": (0, 8, 0),
			},
		),
		(
			244,
			{
				"Body": (0, -14, 0),
				"Rear": (0, -28, 0),
				"TailBase": (0, -42, 0),
				"TailFan": (0, -52, 0),
				"Jaw": (4, 0, 0),
				"FrontFin.L": (-18, 0, -40),
				"FrontFin.R": (18, 0, 40),
				"RearFin.L": (-16, 0, -32),
				"RearFin.R": (16, 0, 32),
				"Head": (0, -8, 0),
			},
		),
		(
			256,
			{
				"Body": (0, 12, 0),
				"Rear": (0, 24, 0),
				"TailBase": (0, 38, 0),
				"TailFan": (0, 48, 0),
				"Jaw": (16, 0, 0),
				"FrontFin.L": (16, 0, 36),
				"FrontFin.R": (-16, 0, -36),
				"RearFin.L": (14, 0, 28),
				"RearFin.R": (-14, 0, -28),
				"Head": (0, 6, 0),
			},
		),
		(
			268,
			{
				"Body": (0, 0, 0),
				"Rear": (0, 0, 0),
				"TailBase": (0, 0, 0),
				"TailFan": (0, 0, 0),
				"Jaw": (6, 0, 0),
				"FrontFin.L": (0, 0, 0),
				"FrontFin.R": (0, 0, 0),
				"RearFin.L": (0, 0, 0),
				"RearFin.R": (0, 0, 0),
				"Head": (0, 0, 0),
			},
		),
	]
	for frame, pose in keys:
		key_pose(arm, frame, pose)

	samples = []
	for frame in range(start, end + 1):
		scene.frame_set(frame)
		bpy.context.view_layer.update()
		row = []
		for name in BONES:
			pb = arm.pose.bones[name]
			row.append(quat_wxyz(pb.matrix_basis.to_quaternion()))
		samples.append(row)

	text = CLIPS.read_text(encoding="utf-8")
	m = re.search(r"JSONDecode\(\[==\[(.*)\]==\]\)", text, re.S)
	clips = json.loads(m.group(1))
	clips["fastSwim"] = {
		"duration": (end - start) / float(fps),
		"fps": fps,
		"samples": samples,
	}
	raw = json.dumps(clips, separators=(",", ":"))
	CLIPS.write_text(
		'return game:GetService("HttpService"):JSONDecode([==[' + raw + "]==])\n",
		encoding="utf-8",
	)
	bpy.ops.wm.save_mainfile()
	print("Leviathan fastSwim samples", len(samples), "dur", clips["fastSwim"]["duration"])


if __name__ == "__main__":
	main()
