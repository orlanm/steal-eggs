"""Build chase 'fastSwim' clips from existing swim samples (trex + lava leviathan)."""
from __future__ import annotations

import json
import math
import re
from pathlib import Path

BONE_AMP = [
	1.0,  # Root
	1.4,  # Head
	2.4,  # Body
	3.0,  # Rear
	3.4,  # TailBase
	3.8,  # TailFan
	3.2,  # RearFin.L
	3.2,  # RearFin.R
	2.0,  # Jaw
	3.3,  # FrontFin.L
	3.3,  # FrontFin.R
]
MAX_ANGLE = math.radians(78)


def load_clips(path: Path) -> dict:
	text = path.read_text(encoding="utf-8")
	m = re.search(r"JSONDecode\(\[==\[(.*)\]==\]\)", text, re.S)
	assert m, path
	return json.loads(m.group(1))


def save_clips(path: Path, clips: dict) -> None:
	raw = json.dumps(clips, separators=(",", ":"))
	path.write_text(
		'return game:GetService("HttpService"):JSONDecode([==[' + raw + "]==])\n",
		encoding="utf-8",
	)


def amplify_quat(wxyz, factor: float):
	w, x, y, z = wxyz
	n = math.sqrt(w * w + x * x + y * y + z * z) or 1.0
	w, x, y, z = w / n, x / n, y / n, z / n
	w = max(-1.0, min(1.0, w))
	angle = 2.0 * math.acos(w)
	axis_len = math.sqrt(x * x + y * y + z * z)
	if axis_len < 1e-8 or abs(angle) < 1e-6:
		return [1.0, 0.0, 0.0, 0.0]
	ax, ay, az = x / axis_len, y / axis_len, z / axis_len
	sign = 1.0 if angle >= 0 else -1.0
	new_angle = min(abs(angle) * factor, MAX_ANGLE) * sign
	half = new_angle * 0.5
	s = math.sin(half)
	return [
		round(math.cos(half), 7),
		round(ax * s, 7),
		round(ay * s, 7),
		round(az * s, 7),
	]


def yaw_quat(degrees: float):
	half = math.radians(degrees) * 0.5
	return [math.cos(half), 0.0, math.sin(half), 0.0]


def mul_quat(a, b):
	aw, ax, ay, az = a
	bw, bx, by, bz = b
	return [
		aw * bw - ax * bx - ay * by - az * bz,
		aw * bx + ax * bw + ay * bz - az * by,
		aw * by - ax * bz + ay * bw + az * bx,
		aw * bz + ax * by - ay * bx + az * bw,
	]


def make_fast_swim(swim: dict) -> dict:
	samples = swim["samples"]
	# Keep a snappy 2.4s loop at 20 fps from the swim poses.
	fps = 20
	duration = 2.4
	count = int(duration * fps) + 1
	# Extra chase yaw layered on body/tail/fins (degrees peak).
	extra = {
		2: 16,  # Body
		3: 28,  # Rear
		4: 40,  # TailBase
		5: 50,  # TailFan
		6: 22,  # RearFin.L
		7: 22,  # RearFin.R
		9: 30,  # FrontFin.L
		10: 30,  # FrontFin.R
		8: 10,  # Jaw
		1: 8,  # Head
	}
	out = []
	for i in range(count):
		u = i / max(count - 1, 1)
		# Two full undulation cycles inside one clip.
		phase = u * math.pi * 4.0
		src_u = (u * 2.0) % 1.0
		src = src_u * (len(samples) - 1)
		a = int(src)
		b = min(a + 1, len(samples) - 1)
		t = src - a
		row = []
		for bone_i, amp in enumerate(BONE_AMP):
			qa = samples[a][bone_i]
			qb = samples[b][bone_i]
			qw = qa[0] * (1 - t) + qb[0] * t
			qx = qa[1] * (1 - t) + qb[1] * t
			qy = qa[2] * (1 - t) + qb[2] * t
			qz = qa[3] * (1 - t) + qb[3] * t
			q = amplify_quat([qw, qx, qy, qz], amp)
			peak = extra.get(bone_i)
			if peak:
				# Opposite side fins get mirrored yaw.
				sign = -1.0 if bone_i in (7, 10) else 1.0
				q = amplify_quat(mul_quat(q, yaw_quat(sign * peak * math.sin(phase))), 1.0)
			row.append(q)
		out.append(row)
	return {"duration": duration, "fps": fps, "samples": out}


def main():
	# Trex only — Leviathan fastSwim is authored in export_leviathan_fast_swim.py.
	path = Path("/Users/orlan/Desktop/steal eggs/src/shared/MommyClips.luau")
	clips = load_clips(path)
	assert "swim" in clips, path
	clips["fastSwim"] = make_fast_swim(clips["swim"])
	save_clips(path, clips)
	fs = clips["fastSwim"]
	print(
		path.name,
		"fastSwim",
		"dur",
		fs["duration"],
		"fps",
		fs["fps"],
		"samples",
		len(fs["samples"]),
	)


if __name__ == "__main__":
	main()
