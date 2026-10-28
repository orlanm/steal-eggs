--!strict
-- Explorer: StarterPlayer.StarterPlayerScripts.BabyBeastsClient.SpawnIntro
-- Covers the first frames, then reveals the player already facing their tank.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "SpawnLoading"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 200
gui.Parent = playerGui

local cover = Instance.new("Frame")
cover.Name = "Cover"
cover.Size = UDim2.fromScale(1, 1)
cover.BackgroundColor3 = Color3.fromRGB(10, 24, 38)
cover.BorderSizePixel = 0
cover.Parent = gui

local label = Instance.new("TextLabel")
label.Name = "Loading"
label.BackgroundTransparency = 1
label.Size = UDim2.fromScale(1, 1)
label.Font = Enum.Font.BuilderSansBold
label.TextSize = 40
label.TextColor3 = Color3.fromRGB(236, 255, 250)
label.Text = "Loading..."
label.Parent = cover

local function standing(): (BasePart?, Humanoid?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (root and root:IsA("BasePart") and humanoid and humanoid.Health > 0) then
		return nil, nil
	end
	if root.Anchored or root.Position.Y < 0.5 or root.Position.Y > 20 then
		return nil, nil
	end
	if typeof(player:GetAttribute("TankSlot")) ~= "number" then
		return nil, nil
	end
	if not workspace:FindFirstChild("BabyBeastsMap") then
		return nil, nil
	end
	return root, humanoid
end

local function shoulderView(root: BasePart, humanoid: Humanoid)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	-- Scriptable for the opening frame only. A leftover CameraOffset would
	-- keep the orbit center beside the body, so reversing direction swings
	-- the player around that point.
	humanoid.CameraOffset = Vector3.zero
	local focus = root.Position + Vector3.new(0, 1.6, 0)
	local camPos = root.CFrame:PointToWorldSpace(Vector3.new(1.7, 2.5, 8))
	camera.CameraSubject = humanoid
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(camPos, focus)
	camera.Focus = CFrame.new(focus)
end

task.spawn(function()
	local started = os.clock()
	local root: BasePart? = nil
	local humanoid: Humanoid? = nil
	while os.clock() - started < 30 do
		root, humanoid = standing()
		if root and humanoid then
			break
		end
		RunService.Heartbeat:Wait()
	end
	if root and humanoid then
		shoulderView(root, humanoid)
		RunService.Heartbeat:Wait()
		RunService.Heartbeat:Wait()
		local camera = workspace.CurrentCamera
		if camera then
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = humanoid
		end
		RunService.Heartbeat:Wait()
	end
	gui:Destroy()
end)
