# Restoring the S-curves (removed 2026-10-26)

## What was changed (place only — the place must be saved)
- Before: zones 6, 8, 10 … 20, 22 and 23 sat at X = 128. Odd zones from 7 onward sat at X = 0.
  Each 288-stud gap between zones (from Zone05 → Zone06 onward) was an S-curve model
  `workspace.BabyBeastsMap.CurvedConnections.CurveToZoneN` that jogged the road sideways.
- Now:
  - Every zone sits on X = 0. Zones 06, 08 … 20, 22 and 23 moved by X −128: parts, model pivots, and the
    `Center`/`FrontCenter`/`HomePosition`/`claude_OrigCFrame` attributes. Each zone carries
    attribute `claude_ShiftedX = -128` (and `claude_TerrainShifted = true`). The root
    `RouteEndWall` and its `WallTooth` row (z ≈ 14433) moved too and are tagged the same way.
  - Terrain water under those zones was copied 128 studs toward −X. Each curve gap now has
    straight water, x −76..76, y −8..0.
  - Each curve gap holds a straight connector,
    `workspace.BabyBeastsMap.StraightConnections.StraightToZoneN`. It has the curve's floor strips
    re-centred on X = 0, SideWalls at X = ±75 with WallTooth tops, and a WaterWalkSupport. The z
    layout is unchanged, so route length, speed balance and zone StartZ/EndZ all stay the same.
  - `ReplicatedStorage.BabyBeastsShared.RoutePath` (Studio-only module) has `P.UseCurves = false`.
- Backup: `ServerStorage.claude_BeforeCurveRemoval_20261026` holds:
  - `CurvedConnections`, all 17 original curve models, untouched.
  - `RouteChannelTerrain_vox_min_-100_-6_560`, a TerrainRegion of the route channel from before
    any change. Paste it at voxel corner (-100, -6, 560), which is studs (-400, -24, 2240).

## How to add the S-curves back
Run in the Studio **Edit** command bar, or via MCP execute_luau (Edit DataModel):

```lua
local m = workspace.BabyBeastsMap
local bk = game.ServerStorage.claude_BeforeCurveRemoval_20261026
local off = Vector3.new(128, 0, 0)
local POS = { Center = true, FrontCenter = true, HomePosition = true }
local function shift(root)
	local items = { root }
	for _, d in root:GetDescendants() do table.insert(items, d) end
	local parts, targets, models, pivots = {}, {}, {}, {}
	for _, d in items do
		if d:IsA("BasePart") then table.insert(parts, d); table.insert(targets, d.CFrame + off)
		elseif d:IsA("Model") and not d.PrimaryPart then table.insert(models, d); table.insert(pivots, d.WorldPivot + off) end
		for k, v in d:GetAttributes() do
			if (POS[k] and typeof(v) == "Vector3") or (k == "claude_OrigCFrame" and typeof(v) == "CFrame") then d:SetAttribute(k, v + off) end
		end
	end
	for i, p in parts do p.CFrame = targets[i] end
	for i, mm in models do mm.WorldPivot = pivots[i] end
end
-- 1. move the shifted zones (and the route end wall) back to X = 128
for _, z in m.BeastHabitats:GetChildren() do
	if z:GetAttribute("claude_ShiftedX") == -128 then
		shift(z); z:SetAttribute("claude_ShiftedX", nil); z:SetAttribute("claude_TerrainShifted", nil)
		task.wait()
	end
end
for _, p in m:GetChildren() do
	if p:IsA("BasePart") and p:GetAttribute("claude_ShiftedX") == -128 then p.CFrame += off; p:SetAttribute("claude_ShiftedX", nil) end
end
-- 2. restore terrain exactly as it was
workspace.Terrain:PasteRegion(bk["RouteChannelTerrain_vox_min_-100_-6_560"], Vector3int16.new(-100, -6, 560), true)
-- 3. swap connectors back
m.StraightConnections:Destroy()
bk.CurvedConnections.Parent = m
```

Then, by hand:
1. In `ReplicatedStorage.BabyBeastsShared.RoutePath`, set `P.UseCurves = true`.
2. Zone23 (Enchanted Forest) got a floor fix after the shift, with tiles extended and
   `claude_FloorUnderlay` added. These move with the zone, so no extra step is needed.
3. Zone name boards on the jail roofs (`src/server/JailSigns.luau`) are built at runtime
   from cell attributes, so they follow automatically.
4. Save the place.
