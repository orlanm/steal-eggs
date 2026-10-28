-- Decorative farm pens. Geometry is baked in Studio; ownership cards update at runtime.
local Players = game:GetService('Players')
local RoofData = require(script.Parent.FarmRoofData)
local Fences = require(script.Parent.Map.TankFences)
local Config = require(game.ReplicatedStorage.BabyBeastsShared.MapConfig)
local Farm = {}
local VERSION = 6
-- Corner posts stand this many plaza-wall heights (MapConfig.WallHeight) tall; the roof rests on their tops.
local CORNER_POST_WALLS = 2
-- Entrance posts beside the owner boards keep a fixed height.
local ENTRANCE_POST_HEIGHT = 10.4
local cream = Color3.fromRGB(243,218,164)
local brown = Color3.fromRGB(101,67,45)
local teal = Color3.fromRGB(28,77,72)
local function part(parent,name,size,cf,color)
 local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=cf;p.Color=color
 p.Material=Enum.Material.Plastic;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
 p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent
 return p
end
-- Post look: a square pillar with cream collars at the foot and the cap, and a carved inset strip
-- down two faces. Collar heights are measured from the foot (fromFoot) or the top (fromTop), so a
-- post of any height keeps the same trim.
local PILLAR_WIDTH = 2.1
local INSET_COLOR = Color3.fromRGB(147,97,57)
local INSET_MARGIN = 1.75 -- studs of plain pillar above and below the inset strip
local GIRTH_HEIGHT = 13.8 -- posts taller than this get thicker (up to MAX_GIRTH) so they don't look spindly
local MAX_GIRTH = 2.2
local COLLARS = {
 {fromFoot=.55,width=3.3,height=1.1}, -- plinth
 {fromFoot=1.35,width=2.65,height=.42},
 {fromTop=1,width=2.65,height=.45},
 {fromTop=.3,width=3.2,height=.6}, -- cap
}
local function girth(height)
 return math.clamp(height/GIRTH_HEIGHT,1,MAX_GIRTH)
end
local function post(parent,name,cf,height)
 local g=girth(height)
 local w=PILLAR_WIDTH*g
 local m=Instance.new('Model');m.Name=name;m:SetAttribute('Height',height);m.Parent=parent
 part(m,'Pillar',Vector3.new(w,height,w),cf*CFrame.new(0,height/2,0),brown)
 for _,c in ipairs(COLLARS) do
  local y=(if c.fromTop then height-c.fromTop*g else c.fromFoot*g)
  part(m,'CreamCollar',Vector3.new(c.width*g,c.height*g,c.width*g),cf*CFrame.new(0,y,0),cream)
 end
 for _,s in ipairs({-1,1}) do
  part(m,'Inset',Vector3.new(.10,height-INSET_MARGIN*g*2,.85*g),cf*CFrame.new(s*(w/2+.015),height/2,0),INSET_COLOR)
 end
 return m
end
-- The cap collar's top: what the roof rests on.
local function postTop(height)
 local cap=COLLARS[#COLLARS]
 local g=girth(height)
 return height-(cap.fromTop-cap.height/2)*g
end
-- Lowest point of the authored roof (its eave beams), so it can be set down on the posts exactly.
local ROOF_BOTTOM=(function()
 local low=math.huge
 for _,d in ipairs(RoofData) do
  for _,x in ipairs({-.5,.5}) do for _,y in ipairs({-.5,.5}) do for _,z in ipairs({-.5,.5}) do
   low=math.min(low,(d.cf*Vector3.new(x*d.size.X,y*d.size.Y,z*d.size.Z)).Y)
  end end end
 end
 return low
end)()
local function board(parent,cf,side)
 local m=Instance.new('Model');m.Name='OwnerBoard'..side;m.Parent=parent
 local panel=part(m,'Panel',Vector3.new(6,6,.35),cf,teal)
 panel:SetAttribute('OwnerBoardPanel',true)
 for _,x in ipairs({-1,1}) do
  part(m,'Frame',Vector3.new(.28,6.55,.5),cf*CFrame.new(x*3.14,0,0),cream)
  part(m,'Frame',Vector3.new(6.55,.28,.5),cf*CFrame.new(0,x*3.14,0),cream)
 end
 for _,x in ipairs({-1,1}) do for _,y in ipairs({-1,1}) do
  local bolt=part(m,'CornerStud',Vector3.new(.27,.27,.15),cf*CFrame.new(x*3.12,y*3.12,-.32),Color3.fromRGB(255,189,57))
  bolt.Shape=Enum.PartType.Ball
 end end
 local gui=Instance.new('SurfaceGui');gui.Name='OwnerCard';gui.Face=Enum.NormalId.Front
 gui.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize;gui.CanvasSize=Vector2.new(512,512)
 gui.LightInfluence=0;gui.Brightness=1.2;gui.MaxDistance=240;gui.Parent=panel
 local card=Instance.new('Frame');card.Name='Card';card.Size=UDim2.fromScale(1,1);card.BackgroundColor3=teal;card.BorderSizePixel=0;card.Parent=gui
 local gradient=Instance.new('UIGradient');gradient.Color=ColorSequence.new(Color3.fromRGB(52,122,106),Color3.fromRGB(17,50,53));gradient.Rotation=90;gradient.Parent=card
 local title=Instance.new('TextLabel');title.Name='Title';title.Size=UDim2.fromScale(.94,.12);title.Position=UDim2.fromScale(.03,.025);title.BackgroundTransparency=1;title.Text='BEAST RANCH';title.Font=Enum.Font.BuilderSansBold;title.TextScaled=true;title.TextColor3=cream;title.Parent=card
 local avatar=Instance.new('ImageLabel');avatar.Name='Avatar';avatar.Size=UDim2.fromScale(.64,.64);avatar.Position=UDim2.fromScale(.18,.145);avatar.BackgroundColor3=Color3.fromRGB(137,200,162);avatar.BorderSizePixel=0;avatar.Parent=card
 local round=Instance.new('UICorner');round.CornerRadius=UDim.new(1,0);round.Parent=avatar
 local stroke=Instance.new('UIStroke');stroke.Color=cream;stroke.Thickness=4;stroke.Parent=avatar
 local label=Instance.new('TextLabel');label.Name='PlayerName';label.Size=UDim2.fromScale(.94,.16);label.Position=UDim2.fromScale(.03,.81);label.BackgroundTransparency=1;label.Font=Enum.Font.BuilderSansBold;label.Text='AVAILABLE';label.TextScaled=true;label.TextColor3=Color3.new(1,1,1);label.Parent=card
 m.PrimaryPart=panel
 return m
end
function Farm.decorateTank(tank)
 local center=tank:GetAttribute('Center');if typeof(center)~='Vector3' then return end
 local front=tank:GetAttribute('FrontDir') or Vector3.zAxis
 local half=tank:GetAttribute('HalfSize') or 40.125
 if not tank:FindFirstChild('FarmFence') then Fences.build(tank,center) end
 local existing=tank:FindFirstChild('FarmArchitecture')
 if existing and existing:GetAttribute('Version')==VERSION then return end
 if existing then existing:Destroy() end
 local legacy=tank:FindFirstChild('OwnerPlaque');if legacy then legacy:Destroy() end
 local m=Instance.new('Model');m.Name='FarmArchitecture';m:SetAttribute('Version',VERSION)
 local cf=CFrame.lookAt(center,center+front)
 local wallHeight=Config.WallHeight or 35
 local fence=tank:FindFirstChild('FarmFence')
 local h=wallHeight*CORNER_POST_WALLS;m:SetAttribute('WallHeight',wallHeight);m:SetAttribute('PostHeight',h)
 for _,x in ipairs({-1,1}) do for _,z in ipairs({-1,1}) do
  post(m,'CornerPost_'..x..'_'..z,cf*CFrame.new(x*half,0,z*half),h)
 end end
 -- Replace the overlapping small corner posts; keep ordinary fence rails collidable.
 for _,p in ipairs(fence:GetDescendants()) do if p:IsA('BasePart') and p.Name=='FencePost' then
  local q=cf:PointToObjectSpace(p.Position)
  if math.abs(math.abs(q.X)-half)<.2 and math.abs(math.abs(q.Z)-half)<.2 then p:Destroy() end
 end end
 local roof=Instance.new('Model');roof.Name='BlenderFarmRoof';roof:SetAttribute('Source','FarmRoof.blend');roof.Parent=m
 local scale=half/40.125
 local roofBase=cf*CFrame.new(0,postTop(h)-ROOF_BOTTOM,0) -- eaves sit on the post caps
 for _,d in ipairs(RoofData) do
  local pos=d.cf.Position;local localCF=CFrame.new(pos.X*scale,pos.Y,pos.Z*scale)*d.cf.Rotation
  part(roof,d.name,Vector3.new(d.size.X*scale,d.size.Y,d.size.Z*scale),roofBase*localCF,d.color)
 end
 local gateHalf=Config.CheckerSize*1.5
 for _,s in ipairs({-1,1}) do
  local gate=cf*CFrame.new(s*gateHalf,0,-half)
  post(m,'EntrancePost_'..s,gate,ENTRANCE_POST_HEIGHT)
  board(m,gate*CFrame.new(0,6.7,-1.35),s==-1 and 'Left' or 'Right')
 end
 m.Parent=tank
 -- Preserve the existing spawn point and chase-safe volume.
 if not tank:GetAttribute('SpawnPosition') then
  local pos=center+front*(half+5.1)+Vector3.new(0,4,0)
  tank:SetAttribute('SpawnPosition',pos);tank:SetAttribute('SpawnLookAt',pos-front*4.5)
 end
end
function Farm.decorate(root)
 for _,tank in ipairs(root.PlayerTanks:GetChildren()) do Farm.decorateTank(tank);task.wait() end
end
function Farm.setOwner(tank,player)
 local token=(tank:GetAttribute('OwnerCardRevision') or 0)+1;tank:SetAttribute('OwnerCardRevision',token)
 local avatars={}
 for _,gui in ipairs(tank:GetDescendants()) do if gui:IsA('SurfaceGui') and gui.Name=='OwnerCard' then
  local card=gui:FindFirstChild('Card');if card then
   card.PlayerName.Text=player and player.DisplayName or 'AVAILABLE';card.Avatar.Image='';table.insert(avatars,card.Avatar)
  end
 end end
 if not player then return end
 local function sizeBoards(character)
  if tank:GetAttribute('OwnerCardRevision')~=token then return end
  local h=6
  local hum=character and character:FindFirstChildOfClass('Humanoid');local root=character and character:FindFirstChild('HumanoidRootPart')
  if hum and root then h=math.clamp(hum.HipHeight*2+root.Size.Y,5,9) end
  local architecture=tank:FindFirstChild('FarmArchitecture')
  if architecture then for _,model in ipairs(architecture:GetChildren()) do if model:IsA('Model') and model.Name:match('^OwnerBoard') then model:ScaleTo(h/6) end end end
 end
 if player.Character then sizeBoards(player.Character) end
 local connection;connection=player.CharacterAdded:Connect(function(character)
  if tank:GetAttribute('OwnerCardRevision')~=token then connection:Disconnect();return end
  task.delay(1,function() sizeBoards(character) end)
 end)
 task.spawn(function()
  local ok,image=pcall(Players.GetUserThumbnailAsync,Players,player.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size420x420)
  if ok and tank.Parent and tank:GetAttribute('OwnerCardRevision')==token then
   for _,avatar in ipairs(avatars) do if avatar.Parent then avatar.Image=image end end
  end
 end)
end
return Farm
