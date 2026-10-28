--!strict
local G=require(script.Parent.Geometry)
local D=require(script.Parent.RockDetails)
local Caves={}
local palettes={
 Color3.fromRGB(74,94,100),Color3.fromRGB(96,87,106),Color3.fromRGB(103,94,81),
 Color3.fromRGB(72,100,93),Color3.fromRGB(88,94,111),Color3.fromRGB(107,88,88),Color3.fromRGB(89,103,91),
}
function Caves.build(parent,config,layout,id)
 local rng=Random.new(config.Seed+layout.SeedOffset+8000)
 local dir=Vector3.new(math.cos(layout.Opening),0,math.sin(layout.Opening))
 local front=layout.Center-dir*(config.ChamberRadius-11)
 local frame=CFrame.lookAt(front,front+dir)
 local cave=G.folder(parent,"SleepingDen")
 cave:SetAttribute("Facing",dir); cave:SetAttribute("FrontCenter",front); cave:SetAttribute("StyleId",id)
 local color=palettes[id]; local glow=color:Lerp(Color3.fromRGB(143,238,219),.8)
 local rx=47+id%3*4; local ry=63+(id*7)%17; local depth=84+(id%3)*8
 cave:SetAttribute("MouthWidth",rx*2-24); cave:SetAttribute("MouthHeight",12+ry); cave:SetAttribute("Depth",depth)
 local function stone(name,size,pos,roll,shade)
  return G.part(cave,name,size,frame*CFrame.new(pos)*CFrame.Angles(0,0,roll or 0),shade or color,true)
 end
 -- A continuous elliptical arch creates a genuinely hollow, rounded entrance.
 for i=0,14 do
  local angle=i*math.pi/14
  local x=rx*math.cos(angle); local y=12+ry*math.sin(angle)
  local tangent=math.atan2(ry*math.cos(angle),-rx*math.sin(angle))
  local rock=stone("ArchVoussoir",Vector3.new(21,24+rng:NextNumber(0,4),depth),Vector3.new(x,y,depth/2),tangent,color:Lerp(Color3.fromRGB(126,132,130),rng:NextNumber(0,.13)))
  if i%3==1 then D.crack(rock,rng,glow,i==7) end
  if i%2==0 then
   D.wedge(cave,"BrokenArchCrown",Vector3.new(23,22+(id+i)%4*7,depth*.7),frame*CFrame.new(x*1.12,y+15,depth*.55)*CFrame.Angles(0,(i%3)*.15,(i-7)*.045),color)
  end
 end
 stone("LeftFoundation",Vector3.new(25,24,depth),Vector3.new(-rx,10,depth/2))
 stone("RightFoundation",Vector3.new(25,24,depth),Vector3.new(rx,10,depth/2))
 stone("DenBack",Vector3.new(rx*2+26,ry+42,10),Vector3.new(0,(ry+42)/2,depth-5),0,color:Lerp(Color3.new(0,0,0),.38))
 -- Alternate shoulders and tall offset spires distinguish all seven silhouettes.
 for side=-1,1,2 do
  for j=1,3 do
   local h=55+rng:NextNumber(0,42)+(if side==1 and id%2==0 then 16 else 0)
   D.wedge(cave,"Buttress",Vector3.new(24,h,depth*.7),frame*CFrame.new(side*(rx+14+j*5),h/2,depth*.55)*CFrame.Angles(0,side*.25,side*.1),color:Lerp(config.Rock,.25))
  end
 end
 for i=1,7 do
  local x=(i-4)*11+rng:NextNumber(-3,3); local ceiling=12+ry*math.sqrt(1-(x/rx)^2)-14
  local h=rng:NextNumber(10,23)
  D.spike(cave,"Stalactite",frame,x,ceiling-h/2,5+rng:NextNumber(0,22),h,rng:NextNumber(3,5),color,true)
 end
 -- Keep the central 32-stud entrance lane unobstructed.
 for side=-1,1,2 do
  for j=1,3 do
   local h=rng:NextNumber(9,24)
   D.spike(cave,"Stalagmite",frame,side*(26+j*5+rng:NextNumber(-1,2)),h/2,8+j*12+rng:NextNumber(-4,4),h,4+rng:NextNumber(0,3),color,false)
  end
 end
end
return Caves
