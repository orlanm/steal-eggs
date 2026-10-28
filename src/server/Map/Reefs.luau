--!strict
local G=require(script.Parent.Geometry)
local Caves=require(script.Parent.Caves)
local D=require(script.Parent.RockDetails)
local Reef={}
function Reef.build(root,config,layouts)
 local group=G.folder(root,"BeastHabitats")
 for id,layout in ipairs(layouts) do
  local rng=Random.new(config.Seed+layout.SeedOffset)
  local habitat=G.folder(nil,layout.Name)
  habitat:SetAttribute("HabitatId",id); habitat:SetAttribute("Center",layout.Center); habitat:SetAttribute("EntranceWidth",54)
  local steps=34; local gap=math.rad(52)
  for i=0,steps-1 do
   local angle=layout.Opening+gap/2+(2*math.pi-gap)*(i+.5)/steps
   local rearDelta=math.abs(math.atan2(math.sin(angle-layout.Opening-math.pi),math.cos(angle-layout.Opening-math.pi)))
   if rearDelta>.49 then
    local radial=Vector3.new(math.cos(angle),0,math.sin(angle))
    local pos=layout.Center+radial*config.ChamberRadius
    local frame=CFrame.lookAt(pos,layout.Center)
    local h=88+18*math.sin(i*.8+id)+rng:NextNumber(0,22)
    local palette={Color3.fromRGB(81,143,135),Color3.fromRGB(145,111,137),Color3.fromRGB(155,132,91),Color3.fromRGB(94,130,162),Color3.fromRGB(128,153,112),Color3.fromRGB(161,112,99),Color3.fromRGB(105,148,145)}
    local color=palette[(id+math.floor(i/5)-1)%7+1]:Lerp(config.Rock,rng:NextNumber(.05,.25))
    local rock=G.part(habitat,"LiveRock",Vector3.new(28,h,25),frame*CFrame.new(0,h/2-2,0)*CFrame.Angles(0,0,rng:NextNumber(-.08,.08)),color,true)
    D.wedge(habitat,"RivenPinnacle",Vector3.new(29,26+rng:NextNumber(0,22),29),frame*CFrame.new(0,h+8,0)*CFrame.Angles(0,rng:NextNumber(-.5,.5),.12),color)
    if i%2==0 then
     D.wedge(habitat,"LayeredButtress",Vector3.new(22,h*.65,28),frame*CFrame.new(5,h*.3,-13)*CFrame.Angles(0,.25,.08),color:Lerp(Color3.new(0,0,0),.12))
     D.crack(rock,rng,Color3.fromRGB(120,219,203),i%8==0)
    end
   end
  end
  Caves.build(habitat,config,layout,id)
  habitat.Parent=group; task.wait()
 end
end
return Reef
