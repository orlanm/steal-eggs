--!strict
-- Explorer: StarterPlayer.StarterPlayerScripts.BabyBeastsClient.LaneGlow
-- Client-only glow around an occupied lane portrait. Nothing here replicates.

local CollectionService = game:GetService("CollectionService")

local function refresh(board: BasePart)
	local owned = board:GetAttribute("OwnerUserId")
	local active = typeof(owned) == "number" and owned > 0
	local glow = board:FindFirstChild("ClientGlow")
	local light = board:FindFirstChild("ClientGlowLight")
	if active then
		local highlight = if glow and glow:IsA("Highlight") then glow else nil
		if not highlight then
			if glow then
				glow:Destroy()
			end
			highlight = Instance.new("Highlight")
			highlight.Name = "ClientGlow"
			highlight.Adornee = board
			highlight.FillColor = Color3.fromRGB(255, 214, 120)
			highlight.FillTransparency = 0.78
			highlight.OutlineColor = Color3.fromRGB(255, 236, 170)
			highlight.OutlineTransparency = 0
			highlight.Parent = board
		end
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		if not light then
			local lamp = Instance.new("PointLight")
			lamp.Name = "ClientGlowLight"
			lamp.Color = Color3.fromRGB(255, 220, 140)
			lamp.Brightness = 1.4
			lamp.Range = 16
			lamp.Shadows = false
			lamp.Parent = board
		end
	elseif not active then
		if glow then
			glow:Destroy()
		end
		if light then
			light:Destroy()
		end
	end
end

local function watch(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	inst:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		refresh(inst)
	end)
	refresh(inst)
end

for _, inst in CollectionService:GetTagged("LaneBoard") do
	watch(inst)
end
CollectionService:GetInstanceAddedSignal("LaneBoard"):Connect(watch)
