--!strict
-- Pet tags (TankBeasts addPetTag) are sized in pixels, which reads huge on a phone screen.
-- Shrink them, and the ★ MOUNT badge on top, with the viewport's short side.

local camera = workspace.CurrentCamera
local BASE = Vector2.new(190, 84) -- server tag size
local BADGE = 22 -- Mounts.client badge height

local function factor(): number
	local view = camera.ViewportSize
	return math.clamp(math.min(view.X, view.Y) / 720, 0.6, 1)
end

local function fit(tag: BillboardGui)
	local k = factor()
	tag.Size = UDim2.fromOffset(math.round(BASE.X * k), math.round(BASE.Y * k))
	local badge = tag:FindFirstChild("MountBadge")
	if badge and badge:IsA("GuiObject") then
		badge.Position = UDim2.fromOffset(0, -math.round(BADGE * k))
		badge.Size = UDim2.new(1, 0, 0, math.round(BADGE * k))
	end
end

local function watch(item: Instance)
	if item.Name == "PetTag" and item:IsA("BillboardGui") then
		fit(item)
		item.ChildAdded:Connect(function(child)
			if child.Name == "MountBadge" then
				task.defer(fit, item)
			end
		end)
	end
end

for _, item in workspace:GetDescendants() do
	watch(item)
end
workspace.DescendantAdded:Connect(watch)
camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	for _, item in workspace:GetDescendants() do
		if item.Name == "PetTag" and item:IsA("BillboardGui") then
			fit(item)
		end
	end
end)
