-- Lightweight local presentation; fusion transactions remain on the server.
local RunService=game:GetService('RunService')
local models={}
local function bind(m)
 if not m:IsA('Model') or m.Name~='PrismFusion' or models[m] then return end
 local parts={}
 for _,p in m:GetDescendants() do
  if p:IsA('BasePart') and (p.Name:find('Orbit_') or p.Name=='White_CoreEgg' or p.Name=='Gold_CoreBelt') then
   parts[#parts+1]={part=p,base=p.CFrame,orbit=p.Name:find('Orbit_')~=nil,direction=p.Name:find('Orbit_A') and 1 or -1}
  end
 end
 models[m]=parts
end
for _,m in workspace:GetDescendants() do bind(m) end
workspace.DescendantAdded:Connect(function(m)if m.Name=='PrismFusion' then task.defer(bind,m)end end)
local elapsed=0
RunService.Heartbeat:Connect(function(dt)
 elapsed+=dt;if elapsed<1/30 then return end;elapsed=0
 local camera=workspace.CurrentCamera;if not camera then return end
 local t=os.clock()
 for m,parts in models do
  if not m.Parent then models[m]=nil;continue end
  if (camera.CFrame.Position-m:GetPivot().Position).Magnitude>120 then continue end
  for _,item in parts do
   local p=item.part
   if p.Parent then
    if item.orbit then p.CFrame=CFrame.new(item.base.Position)*CFrame.Angles(0,t*.35*item.direction,0)*(item.base-item.base.Position)
    else p.CFrame=item.base+Vector3.new(0,math.sin(t*1.5)*.18,0) end
   end
  end
 end
end)
