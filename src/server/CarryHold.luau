--!strict
-- Explorer: ServerScriptService.BabyBeastsServer.CarryHold
-- Carried eggs (CaveBubbles) and held pets (TankBeasts pet tools) share this two-hand carry.
local EggScale = require(game.ReplicatedStorage.BabyBeastsShared.EggScale)

local CarryHold = {}

-- Held in both hands in front of the chest, Steal an Egg style: the egg is welded to the upper
-- torso while the tool is out (resting on the forearms of EggScale.CarryAnimation) and back on the
-- tool handle when it is put away. No tag over the held egg.
local CARRY_HANDS_Y = 0.0 -- forearm height above the upper torso's centre in the carry pose
local CARRY_REACH = 0.55 -- chest front from the upper torso's centre
local carryAnimation = Instance.new("Animation")
carryAnimation.AnimationId = "rbxassetid://" .. EggScale.CarryAnimation

function CarryHold.holdInHands(tool: Tool, body: BasePart, handleWeld: WeldConstraint, carry: Vector3)
	local track: AnimationTrack? = nil
	local weld: Weld? = nil
	local function release()
		if weld then
			weld:Destroy()
			weld = nil
		end
		if track then
			track:Stop(0.15)
			track = nil
		end
		handleWeld.Enabled = true
	end
	tool.Equipped:Connect(function()
		release()
		local character = tool.Parent
		local torso = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"))
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not (torso and torso:IsA("BasePart") and humanoid) then
			return
		end
		handleWeld.Enabled = false
		-- the egg sits on the forearms: its bottom a little under them, centred ahead of the chest
		local centerY = CARRY_HANDS_Y + carry.Y * 0.5 - math.min(carry.Y * 0.5, 0.8)
		local centerZ = -(CARRY_REACH + math.max(carry.Z * 0.5, 0.65))
		local joint = Instance.new("Weld")
		joint.Name = "CarryWeld"
		joint.Part0 = torso
		joint.Part1 = body
		joint.C0 = CFrame.new(0, centerY, centerZ)
		joint.Parent = body
		weld = joint
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator and EggScale.CarryAnimation > 0 then
			local ok, loaded = pcall(animator.LoadAnimation, animator, carryAnimation)
			if ok and loaded then
				loaded.Priority = Enum.AnimationPriority.Action
				loaded.Looped = true
				loaded:Play(0.15)
				track = loaded
			end
		end
	end)
	tool.Unequipped:Connect(release)
	tool.Destroying:Connect(release)
end

return CarryHold
