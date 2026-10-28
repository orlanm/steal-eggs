--!strict
local G=require(script.Parent.Geometry)
local Paths={}
-- A single tessellation owns every exposed ground surface. No overlays or intersecting floors.
function Paths.buildGround(parent,config,layouts)
 local step=config.CheckerSize
 local minX,minZ=-504,-252
 local function onPath(x,z)
  if math.abs(x)<=100 and z>=-160 and z<=140 then return true end
  if math.abs(x)<=config.RoadWidth/2 and z>=140 and z<=1495 then return true end
  for _,layout in ipairs(layouts) do
   if layout.Name~="End" and math.abs(z-layout.Center.Z)<=21 and math.abs(x)<=math.abs(layout.Center.X) and x*layout.Center.X>=0 then return true end
  end
  return false
 end
 for ix=0,41 do
  local row=G.folder(nil,"GroundRow"..ix)
  for iz=0,81 do
   local x=minX+(ix+.5)*step; local z=minZ+(iz+.5)*step
   local path=onPath(x,z); local even=(ix+iz)%2==0
   local color=if path then (if even then config.Road else config.RoadAlternate) else (if even then config.Sand else Color3.fromRGB(154,220,123))
   local tile=G.part(row,if path then "PathTile" else "GroundTile",Vector3.new(step,4,step),CFrame.new(x,-2,z),color,true)
   tile:SetAttribute("SurfaceLevel",0)
   -- Sparse light sources: no emissive material or texture assets required.
   if path and ix==21 and iz%6==0 then
    local a=Instance.new("Attachment"); a.Position=Vector3.new(0,3,0); a.Parent=tile
    local light=Instance.new("PointLight"); light.Color=config.RoadAlternate; light.Brightness=.35; light.Range=28; light.Shadows=false; light.Parent=a
   end
  end
  row.Parent=parent; task.wait()
 end
end
return Paths
