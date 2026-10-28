local Config = require(game.ReplicatedStorage.BabyBeastsShared.BiomeLandmarkConfig)
local Builder = {}
local function part(parent, name, size, cf, color, collide)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanTouch = false
	p.Material = Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
function Builder.build(parent, z)
	local d = Config.Treadmill
	local src = game.ServerStorage.BiomeLandmarkMeshes:FindFirstChild("Plaza_Treadmill")
	if not src then
		src = game.AssetService:CreateMeshPartAsync(Content.fromUri("rbxassetid://" .. d.Id))
	end
	local id = 0
	-- Three machines per side (six total), spaced along the plaza corridor.
	for _, side in { -1, 1 } do
		for _, offset in { -70, 0, 70 } do
			id += 1
			local m = Instance.new("Model")
			m.Name = "TrainingTreadmill" .. id
			m:SetAttribute("TreadmillId", id)
			m:SetAttribute("TrainingUserId", 0)
			m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			local origin = CFrame.new(side * 48, 0, z + offset)
				* CFrame.Angles(0, if side < 0 then -math.pi / 2 else math.pi / 2, 0)
			m:SetAttribute("Origin", origin)
			local mesh = src:Clone()
			mesh.Name = "BlenderChassis"
			mesh.Size = d.Size
			mesh.CFrame = origin * CFrame.new(d.Center)
			mesh.Anchored = true
			mesh.CanCollide = false
			mesh.CanTouch = false
			mesh.TextureID = ""
			mesh.Color = d.PaintColor or Color3.fromRGB(255, 168, 72)
			mesh.Material = Enum.Material.SmoothPlastic
			mesh.Parent = m
			local deck = part(m, "Deck", Vector3.new(8.8, 0.5, 16), origin * CFrame.new(0, 2, 0), Color3.fromRGB(24, 40, 65), true)
			m.PrimaryPart = deck
			for i = 0, 15 do
				local slat = part(
					m,
					"BeltSlat",
					Vector3.new(8.5, 0.12, 0.82),
					origin * CFrame.new(0, 2.32, -7.5 + i),
					Color3.fromRGB(52, 74, 94),
					false
				)
				slat:SetAttribute("BeltIndex", i)
				if i % 4 == 0 then
					slat.Color = Color3.fromRGB(93, 209, 230)
					slat.Material = Enum.Material.Neon
				end
			end
			for _, x in { -4.75, 4.75 } do
				local strip = part(
					m,
					"ActiveGlow",
					Vector3.new(0.18, 0.16, 16),
					origin * CFrame.new(x, 2.4, 0),
					Color3.fromRGB(75, 236, 233),
					false
				)
				strip.Material = Enum.Material.Neon
				strip.Transparency = 0.65
				local l = Instance.new("PointLight")
				l.Color = strip.Color
				l.Brightness = 0.5
				l.Range = 12
				l.Enabled = false
				l.Parent = strip
			end
			-- Console faces the runner on the belt (Front = toward deck center).
			local screen = part(
				m,
				"ConsoleScreen",
				Vector3.new(6, 1.8, 0.12),
				origin * CFrame.new(0, 7, -6.1),
				Color3.fromRGB(18, 37, 70),
				false
			)
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Front
			gui.CanvasSize = Vector2.new(600, 180)
			gui.Parent = screen
			local label = Instance.new("TextLabel")
			label.Name = "Readout"
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Text = "STEP ON\nTRAIN SPEED"
			label.TextColor3 = Color3.fromRGB(174, 255, 234)
			label.Font = Enum.Font.BuilderSansBold
			label.TextScaled = true
			label.Parent = gui
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Train Speed"
			prompt.ObjectText = "Starlight Treadmill"
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			prompt.HoldDuration = 0
			prompt.Parent = deck
			m.Parent = parent
			game.CollectionService:AddTag(m, "TrainingTreadmill")
		end
	end
end
return Builder
