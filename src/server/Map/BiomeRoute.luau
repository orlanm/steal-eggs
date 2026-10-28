local G=require(script.Parent.Geometry)
local Layout=require(script.Parent.Layout)
local Landmarks=require(script.Parent.BiomeLandmarks)
local Biomes=require(game.ReplicatedStorage.BabyBeastsShared.BiomeConfig)
local MommyConfig=require(game.ReplicatedStorage.BabyBeastsShared.MommyConfig)
local Route={}
local function part(parent,name,size,pos,color,collide)
 return G.part(parent,name,size,CFrame.new(pos),color,collide)
end
local function floor(parent,center,width,length,step,a,b)
 for x=0,width/step-1 do
  local row=G.folder(nil,"TileRow"..x)
  for z=0,length/step-1 do
   local p=part(row,"CheckerTile",Vector3.new(step,4,step),center+Vector3.new(-width/2+(x+.5)*step,-2,-length/2+(z+.5)*step),if (x+z)%2==0 then a else b,true)
   p.Material=Enum.Material.Plastic; p.MaterialVariant=""
  end
  row.Parent=parent
  task.wait()
 end
end
-- Zone 0 road runs up the middle. Every tank has a 3-tile yellow path centered on its opening.
local function plazaGround(parent, config)
 local size = config.PlazaSize
 local step = config.CheckerSize
 local half = size / 2
 local roadHalf = config.RoadWidth / 2
 -- Steal An Egg base slab (105, 208, 20) and the darker green strip beside it.
 local yardA = Color3.fromRGB(105, 208, 20)
 local yardB = Color3.fromRGB(97, 186, 18)
 local roadA = Biomes[1].Floor
 local roadB = Biomes[1].Alternate
 local columns = size / step
 local function tileIndex(coord)
  return math.clamp(math.floor((coord + half) / step), 0, columns - 1)
 end
 local function three(coord)
  local mid = tileIndex(coord)
  return math.max(mid - 1, 0), math.min(mid + 1, columns - 1)
 end
 local function addSpur(list, a, b, c, d)
  if a > b then a, b = b, a end
  if c > d then c, d = d, c end
  table.insert(list, { x0 = a, x1 = b, z0 = c, z1 = d })
 end
 local function firstRow(coord)
  return math.clamp(math.ceil((coord + half) / step - 0.5), 0, columns - 1)
 end
 -- The main road runs through the mouth between the side pens. Each back opening gets a short spur.
 local halfPen = config.PenSize / 2
 local roadMinZ = math.huge
 local spurs = {}
 local minX, maxX = columns, 0
 for _, center in ipairs(Layout.tanks()) do
  if Layout.onBackRow(center) then
   local x0, x1 = three(center.X)
   minX = math.min(minX, x0)
   maxX = math.max(maxX, x1)
   local faceZ = center.Z + halfPen
   roadMinZ = math.min(roadMinZ, faceZ)
   addSpur(spurs, x0, x1, firstRow(faceZ + 1), firstRow(faceZ + 36))
  else
   local front = Layout.frontDir(center)
   local faceX = center.X + front.X * halfPen
   local z0, z1 = three(center.Z)
   addSpur(spurs, tileIndex(faceX), tileIndex(front.X * roadHalf), z0, z1)
  end
 end
 if roadMinZ == math.huge then
  roadMinZ = 0
 end
 local roadRow = firstRow(roadMinZ)
 if maxX >= minX then
  addSpur(spurs, minX, maxX, roadRow, math.min(roadRow + 2, columns - 1))
 end
 for ix = 0, columns - 1 do
  local row = G.folder(nil, "TileRow" .. ix)
  local x = -half + (ix + 0.5) * step
  for iz = 0, columns - 1 do
   local z = -half + (iz + 0.5) * step
   local onRoad = math.abs(x) <= roadHalf and z >= roadMinZ
   if not onRoad then
    for _, spur in spurs do
     if ix >= spur.x0 and ix <= spur.x1 and iz >= spur.z0 and iz <= spur.z1 then
      onRoad = true
      break
     end
    end
   end
   local even = (ix + iz) % 2 == 0
   local color = if onRoad then (if even then roadA else roadB) else (if even then yardA else yardB)
   local tile = part(row, if onRoad then "PathTile" else "CheckerTile", Vector3.new(step, 4, step), Vector3.new(x, -2, z), color, true)
   tile.Material = Enum.Material.Plastic
   tile.MaterialVariant = ""
   if not onRoad then
    for _, face in {"Top", "Bottom", "Left", "Right", "Front", "Back"} do
     tile[face .. "Surface"] = Enum.SurfaceType.Smooth
    end
   end
  end
  row.Parent = parent
  task.wait()
 end
end
-- Solid yellow plaza enclosure. Outer faces sit on the plaza edge (no path overlap);
-- ±X runs are shortened by wall thickness so corners meet flush without gaps or z-fight.
local function plazaWalls(parent,config,plazaSize)
 local half=plazaSize/2
 local thick=6
 local h=config.WallHeight
 local brown=Color3.fromRGB(196,154,98)
 local walls=G.folder(parent,"PlazaWalls")
 local function wall(name,size,pos)
  -- Match path SideWalls: Plastic + empty MaterialVariant so SurfaceType.Universal studs show.
  -- A named MaterialVariant ("Universal") overrides and hides classic stud faces.
  local p=part(walls,name,size,pos,brown,true)
  p.Material=Enum.Material.Plastic
  p.MaterialVariant=""
  return p
 end
 -- Center so the outer face lands on ±half (path begins at +Z = half).
 local c=half-thick/2
 wall("PlazaWallNegZ",Vector3.new(plazaSize,h,thick),Vector3.new(0,h/2,-c))
 -- +Z wings stop at the path SideWall outer faces (±roadHalf+thick) — no coplanar race.
 local pathOuter=config.RoadWidth/2+thick
 local wingLen=half-pathOuter
 local wingMid=(pathOuter+half)/2
 wall("PlazaWallPosZ_L",Vector3.new(wingLen,h,thick),Vector3.new(-wingMid,h/2,c))
 wall("PlazaWallPosZ_R",Vector3.new(wingLen,h,thick),Vector3.new(wingMid,h/2,c))
 wall("PlazaWallNegX",Vector3.new(thick,h,plazaSize-2*thick),Vector3.new(-c,h/2,0))
 wall("PlazaWallPosX",Vector3.new(thick,h,plazaSize-2*thick),Vector3.new(c,h/2,0))
end
local function jailLights(cell,_center,side,half,depth,width,height,accent)
 local lamps=G.folder(cell,"JailLights")
 local home=cell:GetAttribute("HomePosition")
 local facing=Vector3.new(-side,0,0)
 -- Match mommy rest pose: dropped pivot + snout reach along Facing.
 local worldScale=math.min(height*.53/MommyConfig.NativeSize.Y,width*.70/MommyConfig.NativeSize.X,(depth-18)/MommyConfig.NativeSize.Z)
 local snout=MommyConfig.SnoutOffset*worldScale
 local restY=home.Y-MommyConfig.RestDrop
 -- Head/face sits ahead of the pivot toward the bars.
 local face=Vector3.new(home.X,restY+12,home.Z)+facing*(snout*.55)
 -- Soft fill at the face (no SpotLight fixtures — those flooded every cell).
 local wash=G.part(lamps,"FaceWash",Vector3.new(.6,.6,.6),CFrame.new(face),accent,false)
 wash.Transparency=1
 wash.CanQuery=false
 wash.CastShadow=false
 local fill=Instance.new("PointLight")
 fill.Color=accent
 fill.Brightness=1.5
 fill.Range=32
 fill.Shadows=false
 fill.Parent=wash
 local ceil=part(lamps,"CeilingGlow",Vector3.new(depth*.42,1.2,width*.48),Vector3.new(side*(half+depth*.45),height-1.4,home.Z),accent,false)
 ceil.Material=Enum.Material.Neon
 ceil.Transparency=.35
end
local function zoneLabelText(id,name)
 -- Plain decimal id (no leading zeros): "0 PLAZA", "1 COZY BACKYARD", "23 ..."
 return string.format("%d %s", id, string.upper(name))
end
local function zoneBanner(zone,b,id,startZ,config)
 -- Board at the beginning of the zone. Forward arrivals read Front (this zone).
 -- Reverse arrivals hit the same board at the start of the previous zone's
 -- S-curve and read Back (previous zone).
 local boardColor=b.Wall:Lerp(Color3.new(0,0,0),.42)
 local sign=part(zone,"BiomeSign",Vector3.new(config.RoadWidth,12,3),Vector3.new(0,config.WallHeight+4,startZ+5),boardColor,false)
 local frontText=zoneLabelText(id,b.Name)
 local prev=nil
 for _,biome in Biomes do
  if biome.ZoneIndex==id-1 then prev=biome; break end
 end
 local backText=if prev then zoneLabelText(prev.ZoneIndex,prev.Name) else frontText
 for _,face in {Enum.NormalId.Front,Enum.NormalId.Back} do
  local gui=Instance.new("SurfaceGui")
  gui.Name=if face==Enum.NormalId.Front then "FrontLabel" else "BackLabel"
  gui.Face=face
  gui.CanvasSize=Vector2.new(900,160)
  gui.Parent=sign
  local label=Instance.new("TextLabel")
  label.Size=UDim2.fromScale(1,1)
  label.BackgroundTransparency=1
  label.Text=if face==Enum.NormalId.Front then frontText else backText
  label.Font=Enum.Font.BuilderSansBold
  label.TextScaled=true
  label.TextColor3=Color3.fromRGB(255,250,229)
  label.TextStrokeTransparency=.4
  label.Parent=gui
 end
end

function Route.build(root,config)
 local ground=G.folder(root,"GroundAndPaths")
 local plazaSize=config.PlazaSize
 plazaGround(ground, config)
 plazaWalls(ground,config,plazaSize)
 local habitats=G.folder(root,"BeastHabitats")
 local cursor=config.RouteStart
 local lastWall=Biomes[#Biomes].Wall
 for _,b in Biomes do
  local id=b.ZoneIndex
  local zoneLen=b.Length or (if b.HalfLength then config.ZoneLength*.5 else config.ZoneLength)
  local start=cursor
  local z=start+zoneLen/2
  local hasJail=not b.NoJail
  -- Jail mouth alternates; Plaza (0) has no jail so both sides stay solid.
  local side=if id%2==1 then -1 else 1
  local half=config.RoadWidth/2
  local zone=G.folder(nil,string.format("Zone%02d",id))
  zone:SetAttribute("ZoneIndex",id)
  zone:SetAttribute("BiomeName",b.Name)
  zone:SetAttribute("Center",Vector3.new(0,0,z))
  zone:SetAttribute("HabitatId",id)
  zone:SetAttribute("ZoneLength",zoneLen)
  zone:SetAttribute("StartZ",start);zone:SetAttribute("EndZ",start+zoneLen)
  zone:SetAttribute("SpeedRequirement",b.SpeedRequirement or 0);zone:SetAttribute("Guardian",b.Guardian or "")

  local tiles=G.folder(zone,"PathFloor")
  floor(tiles,Vector3.new(0,0,z),config.RoadWidth,zoneLen,config.CheckerSize,b.Floor,b.Alternate)
  for _,s in {-1,1} do
   if hasJail and s==side then
    local segment=(zoneLen-config.CellWidth)/2
    for _,e in {-1,1} do part(zone,"SideWall",Vector3.new(6,config.WallHeight,segment),Vector3.new(s*(half+3),config.WallHeight/2,z+e*(config.CellWidth/2+segment/2)),b.Wall,true) end
    part(zone,"GateLintel",Vector3.new(6,config.WallHeight-config.CellHeight,config.CellWidth),Vector3.new(s*(half+3),(config.WallHeight+config.CellHeight)/2,z),b.Wall,true)
   else
    part(zone,"SideWall",Vector3.new(6,config.WallHeight,zoneLen),Vector3.new(s*(half+3),config.WallHeight/2,z),b.Wall,true)
   end
   if hasJail then
    local landmarkIndex=0
    for _,e in {-1,1} do
     landmarkIndex+=1
     Landmarks.place(zone,Vector3.new(s*(half-19),0,z+e*112),b.Theme,landmarkIndex,s)
    end
   end
   if hasJail then Landmarks.badge(zone,Vector3.new(s*(half-2),16,z-100),b.Theme,s) end
   part(zone,"WallBand",Vector3.new(1,3,math.max(4,zoneLen-4)),Vector3.new(s*(half-.6),config.CellHeight+5,z),b.Trim,false)
  end
  if hasJail then
   local cell=G.folder(zone,"JailCell")
   cell.ModelStreamingMode=Enum.ModelStreamingMode.Persistent
   cell:SetAttribute("FrontCenter",Vector3.new(side*half,0,z));cell:SetAttribute("Facing",Vector3.new(-side,0,0))
   cell:SetAttribute("Depth",config.CellDepth);cell:SetAttribute("MouthWidth",config.CellWidth);cell:SetAttribute("MouthHeight",config.CellHeight);cell:SetAttribute("StyleId",id)
   cell:SetAttribute("HomePosition",Vector3.new(side*(half+config.CellDepth/2),17,z))
   cell:SetAttribute("AccentColor",b.Accent)
   local cellCenter=Vector3.new(side*(half+config.CellDepth/2),0,z)
   local cfloor=G.folder(cell,"CellFloor")
   floor(cfloor,cellCenter,config.CellDepth,config.CellWidth,config.CheckerSize,b.Wall:Lerp(b.Floor,.35),b.Wall:Lerp(b.Alternate,.35))
   part(cell,"BackWall",Vector3.new(6,config.CellHeight,config.CellWidth+12),Vector3.new(side*(half+config.CellDepth+3),config.CellHeight/2,z),b.Wall,true)
   for _,e in {-1,1} do part(cell,"CellSide",Vector3.new(config.CellDepth,config.CellHeight,6),Vector3.new(side*(half+config.CellDepth/2),config.CellHeight/2,z+e*(config.CellWidth/2+3)),b.Wall,true) end
   part(cell,"CellRoof",Vector3.new(config.CellDepth+6,2,config.CellWidth+12),Vector3.new(side*(half+config.CellDepth/2),config.CellHeight+1,z),b.Wall,true)
   -- No JailBars: the cell mouths stay open (removed 2026-10-26).
   jailLights(cell,cellCenter,side,half,config.CellDepth,config.CellWidth,config.CellHeight,b.Accent)
  end
  zoneBanner(zone,b,id,start,config)
  zone.Parent=habitats
  lastWall=b.Wall
  cursor+=zoneLen
  task.wait()
 end
 part(root,"RouteEndWall",Vector3.new(config.RoadWidth+12,config.WallHeight,6),Vector3.new(0,config.WallHeight/2,cursor+3),lastWall,true)
end
return Route
