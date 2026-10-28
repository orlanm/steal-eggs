--!strict
-- A light tint while the camera is under the surface. Fog and haze stay low
-- so the tank yard stays readable.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local top = require(game.ReplicatedStorage.BabyBeastsShared.MapConfig).WaterTop

Lighting.FogStart = 0
Lighting.FogEnd = 100000
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
if atmosphere then
	atmosphere.Density = math.min(atmosphere.Density, 0.08)
	atmosphere.Haze = 0
	atmosphere.Glare = 0
end

local effect = Instance.new("ColorCorrectionEffect")
effect.Name = "BabyBeastsUnderwater"
effect.Parent = Lighting

local elapsed = 0
RunService.RenderStepped:Connect(function(dt)
	elapsed += dt
	if elapsed < 0.15 then
		return
	end
	elapsed = 0
	local camera = workspace.CurrentCamera
	local underwater = camera ~= nil and camera.CFrame.Position.Y < top
	effect.TintColor = if underwater then Color3.fromRGB(176, 214, 226) else Color3.new(1, 1, 1)
	effect.Contrast = if underwater then 0.05 else 0
	effect.Saturation = if underwater then 0.08 else 0
	effect.Brightness = 0
end)
