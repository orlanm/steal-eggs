-- Pet Index (Steal an Egg style): biome sections of pet cards, a preview of the selected pet and its rewards.
-- Cards show the pet's 2D icon when it has one, otherwise a 3D render of its model (loaded only for the
-- biomes the player scrolls to). Undiscovered pets are dark translucent silhouettes.
local Players=game:GetService('Players')
local TweenService=game:GetService('TweenService')
local UIS=game:GetService('UserInputService')
local Shared=game.ReplicatedStorage:WaitForChild('BabyBeastsShared')
local Config=require(Shared.PetIndexConfig)
local Art=require(Shared.PetIndexArt)
local PopupLayout=require(Shared.PopupLayout)
local PetRig=require(Shared.PetRig)
local Catalog=require(Shared.PetCatalog)
local GamePet=require(Shared.GamePet)
local GameEgg=require(Shared.GameEgg)
local EggVisual=require(Shared.EggVisual)
local player=Players.LocalPlayer
local remotes=Shared:WaitForChild('Remotes')
local get=remotes:WaitForChild('PetIndexSnapshot')
local claim=remotes:WaitForChild('PetIndexClaim')
local modelRequest=remotes:WaitForChild('PetIndexModels',10)
-- Steal an Egg's stud texture and the soft shadow under each pet (public images)
local PATTERN=Art.Studs
local SHADOW='rbxassetid://140035627431522'
local SILHOUETTE=Color3.new(0,0,0)
-- The popup sits above every HUD ScreenGui; its HUD button lives in its own, lower ScreenGui.
local gui=Instance.new('ScreenGui');gui.Name='PetIndex';gui.ResetOnSpawn=false;gui.DisplayOrder=PopupLayout.DisplayOrder;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=player:WaitForChild('PlayerGui')
local function new(class,parent,props)
 local o=Instance.new(class);for k,v in props do o[k]=v end;o.Parent=parent;return o
end
local function stroke(o,color,thick) return new('UIStroke',o,{Color=color or Color3.fromRGB(8,10,18),Thickness=thick or 3,ApplyStrokeMode=Enum.ApplyStrokeMode.Border}) end
local function frame(parent,name,pos,size,color)
 return new('Frame',parent,{Name=name,Position=pos,Size=size,BackgroundColor3=color or Color3.fromRGB(50,50,65),BorderSizePixel=0})
end
local function label(parent,text,pos,size,fontSize)
 local o=new('TextLabel',parent,{Text=text,Position=pos,Size=size,BackgroundTransparency=1,TextColor3=Color3.new(1,1,1),Font=Enum.Font.BuilderSansExtraBold,TextSize=fontSize or 24,TextWrapped=true})
 new('UIStroke',o,{Thickness=2,Color=Color3.new(0,0,0)});return o
end
local function pattern(parent)
 new('ImageLabel',parent,{Name='StudPattern',Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Image=PATTERN,ImageTransparency=.5,ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.fromOffset(48,48),ZIndex=parent.ZIndex})
end
-- light at the top, darker at the bottom (rotation 90) or right-to-left (180), like the reference cards
local function shade(parent,rotation,low)
 new('UIGradient',parent,{Rotation=rotation or 90,Color=ColorSequence.new(Color3.new(1,1,1),Color3.new(low or .72,low or .72,low or .72))})
end
local function button(parent,text,pos,size,color)
 local b=new('TextButton',parent,{Text='',Position=pos,Size=size,BackgroundColor3=color or Color3.fromRGB(10,183,240),BorderSizePixel=0,AutoButtonColor=true,Selectable=true});stroke(b);pattern(b);shade(b,90,.78)
 local l=label(b,text,UDim2.fromScale(0,0),UDim2.fromScale(1,1),26);return b,l
end
local function image(parent,id,pos,size)
 return new('ImageLabel',parent,{Image=id,Position=pos,Size=size,BackgroundTransparency=1,ScaleType=Enum.ScaleType.Fit})
end
local function format(n)
 for _,v in {{1e15,'Qa'},{1e12,'T'},{1e9,'B'},{1e6,'M'},{1e3,'K'}} do if n>=v[1] then return string.format('%.1f%s',n/v[1],v[2]):gsub('%.0','') end end
 return tostring(math.floor(n))
end
local backdrop=new('TextButton',gui,{Name='Backdrop',Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text='',Visible=false,Active=false,AutoButtonColor=false,ZIndex=1})
local root=frame(gui,'Popup',UDim2.fromScale(.5,.5),UDim2.fromOffset(1010,530));root.AnchorPoint=Vector2.new(.5,.5);root.BackgroundTransparency=1;root.Visible=false;root.ZIndex=2
-- above EggAnnouncements (41) so the banner stack can't cover it
local buttonGui=Instance.new('ScreenGui');buttonGui.Name='PetIndexButton';buttonGui.ResetOnSpawn=false;buttonGui.DisplayOrder=50;buttonGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;buttonGui.Parent=gui.Parent
local openButton=button(buttonGui,'Index',UDim2.new(0,16,.47,0),UDim2.fromOffset(104,50))
openButton.Name='OpenIndex';openButton.ZIndex=10
image(openButton,Art.Book,UDim2.fromOffset(2,4),UDim2.fromOffset(28,42))
-- Speed slider under the Index button: left = Roblox's stock WalkSpeed, right = the player's full trained pace.
local setSpeedScale=remotes:WaitForChild('SetSpeedScale',10)
local speedTrack=new('TextButton',buttonGui,{Name='SpeedSlider',Text='',Position=UDim2.new(0,16,.47,62),Size=UDim2.fromOffset(104,25),BackgroundColor3=Color3.fromRGB(34,36,51),BorderSizePixel=0,AutoButtonColor=false,ZIndex=10});stroke(speedTrack);pattern(speedTrack)
local speedFill=frame(speedTrack,'Fill',UDim2.fromScale(0,0),UDim2.fromScale(1,1),Color3.fromRGB(255,206,38));speedFill.ZIndex=10;pattern(speedFill);shade(speedFill,90,.78)
local speedHandle=new('Frame',speedTrack,{Name='Handle',AnchorPoint=Vector2.new(1,.5),Position=UDim2.fromScale(1,.5),Size=UDim2.new(0,28,1,8),BackgroundColor3=Color3.fromRGB(255,255,255),BorderSizePixel=0,ZIndex=12});stroke(speedHandle);shade(speedHandle,90,.75)
new('UICorner',speedHandle,{CornerRadius=UDim.new(0,6)})
new('TextLabel',speedHandle,{Name='Bolt',Text='\u{26A1}',Size=UDim2.fromScale(1,1),BackgroundTransparency=1,TextScaled=true,Font=Enum.Font.BuilderSansExtraBold,TextColor3=Color3.fromRGB(255,200,0),ZIndex=13})
local speedScale,speedDragging,speedSent=1,nil,0
local function showSpeed(f)
 speedScale=math.clamp(f,0,1);speedHandle.AnchorPoint=Vector2.new(speedScale,.5);speedHandle.Position=UDim2.fromScale(speedScale,.5);speedFill.Size=UDim2.fromScale(speedScale,1)
end
local function sendSpeed(force)
 if setSpeedScale and (force or os.clock()-speedSent>.1) then speedSent=os.clock();setSpeedScale:FireServer(speedScale) end
end
local function dragSpeed(x)
 showSpeed((x-speedTrack.AbsolutePosition.X)/math.max(speedTrack.AbsoluteSize.X,1));sendSpeed(false)
end
speedTrack.InputBegan:Connect(function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then speedDragging=input;dragSpeed(input.Position.X) end
end)
UIS.InputChanged:Connect(function(input)
 if speedDragging and (input==speedDragging or input.UserInputType==Enum.UserInputType.MouseMovement) then dragSpeed(input.Position.X) end
end)
UIS.InputEnded:Connect(function(input)
 if speedDragging and (input==speedDragging or input.UserInputType==Enum.UserInputType.MouseButton1) then speedDragging=nil;sendSpeed(true) end
end)
player:GetAttributeChangedSignal('SpeedScale'):Connect(function()if not speedDragging then showSpeed(tonumber(player:GetAttribute('SpeedScale')) or 1) end end)
showSpeed(tonumber(player:GetAttribute('SpeedScale')) or 1)
local scale=new('UIScale',root,{Scale=1})
local panel=frame(root,'Panel',UDim2.fromOffset(0,0),UDim2.fromOffset(860,530));stroke(panel,Color3.fromRGB(21,21,21),5);pattern(panel)
local header=frame(panel,'Header',UDim2.fromOffset(4,4),UDim2.fromOffset(852,70),Color3.fromRGB(255,255,255));pattern(header)
new('UIGradient',header,{Color=ColorSequence.new(Color3.fromRGB(150,219,255),Color3.fromRGB(0,150,219))})
stroke(header,Color3.fromRGB(82,82,107),2)
label(header,'Pet Index',UDim2.fromOffset(18,2),UDim2.fromOffset(400,65),40).TextXAlignment=Enum.TextXAlignment.Left
local close=button(header,'X',UDim2.fromOffset(786,9),UDim2.fromOffset(55,51),Color3.fromRGB(240,35,40))
local listBox=frame(panel,'ListBox',UDim2.fromOffset(14,87),UDim2.fromOffset(590,364),Color3.fromRGB(38,38,49));stroke(listBox,Color3.fromRGB(21,21,21),3)
local list=new('ScrollingFrame',listBox,{Name='BiomeList',Position=UDim2.fromOffset(6,6),Size=UDim2.new(1,-8,1,-12),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=6,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollingDirection=Enum.ScrollingDirection.Y})
new('UIListLayout',list,{Padding=UDim.new(0,12),SortOrder=Enum.SortOrder.LayoutOrder})
local footer=frame(panel,'TotalProgress',UDim2.fromOffset(14,465),UDim2.fromOffset(590,50),Color3.fromRGB(17,17,22));stroke(footer)
image(footer,Art.Book,UDim2.fromOffset(4,-2),UDim2.fromOffset(60,55))
local totalLabel=label(footer,'Loading collection…',UDim2.fromOffset(65,0),UDim2.fromOffset(515,50),30)
local viewing=frame(panel,'PetPreview',UDim2.fromOffset(618,87),UDim2.fromOffset(226,246),Color3.fromRGB(112,112,118));stroke(viewing,Color3.fromRGB(171,171,171),2)
shade(viewing,90,.45)
local previewHolder=frame(viewing,'Preview',UDim2.fromOffset(23,5),UDim2.fromOffset(180,157));previewHolder.BackgroundTransparency=1
local petName=label(viewing,'Select a pet',UDim2.fromOffset(5,162),UDim2.fromOffset(216,33),25)
local rarity=label(viewing,'',UDim2.fromOffset(5,194),UDim2.fromOffset(216,23),21)
local income=label(viewing,'',UDim2.fromOffset(5,220),UDim2.fromOffset(216,22),21);income.TextColor3=Color3.fromRGB(92,255,81)
local rewards=frame(panel,'Rewards',UDim2.fromOffset(618,347),UDim2.fromOffset(226,168),Color3.fromRGB(255,255,255));stroke(rewards,Color3.fromRGB(0,145,17),2)
new('UIGradient',rewards,{Rotation=90,Color=ColorSequence.new(Color3.fromRGB(25,29,38),Color3.fromRGB(24,70,32))})
label(rewards,'Rewards:',UDim2.fromOffset(8,2),UDim2.fromOffset(110,24),18).TextXAlignment=Enum.TextXAlignment.Left
local function rewardTile(x,icon)
 local tile=new('ImageLabel',rewards,{Position=UDim2.fromOffset(x,28),Size=UDim2.fromOffset(62,62),BackgroundColor3=Color3.fromRGB(34,36,51),BorderSizePixel=0});stroke(tile,nil,2);pattern(tile);shade(tile,90,.6)
 image(tile,icon,UDim2.fromOffset(6,2),UDim2.fromOffset(50,46))
 return label(tile,'—',UDim2.fromOffset(0,42),UDim2.fromOffset(62,20),15)
end
local cashLabel=rewardTile(40,Art.Cash)
local speedLabel=rewardTile(124,Art.Speed)
local claimButton,claimLabel=button(rewards,'LOCKED',UDim2.fromOffset(22,112),UDim2.fromOffset(182,42),Color3.fromRGB(98,100,106))
local world=button(root,'World',UDim2.fromOffset(880,84),UDim2.fromOffset(123,59))
local limited=button(root,'Special',UDim2.fromOffset(880,156),UDim2.fromOffset(123,59),Color3.fromRGB(195,139,35))
local toast=label(root,'',UDim2.fromOffset(0,535),UDim2.fromOffset(860,40),21)
local colors={Common=Color3.fromRGB(175,178,184),Uncommon=Color3.fromRGB(80,214,48),Rare=Color3.fromRGB(25,137,255),Epic=Color3.fromRGB(183,61,245),Legendary=Color3.fromRGB(255,207,31),Mythic=Color3.fromRGB(240,47,70),Divine=Color3.fromRGB(255,155,30),Secret=Color3.fromRGB(233,235,255),Cosmic=Color3.fromRGB(97,53,200)}
local state={Ready=false,Discovered={},Claimed={}}
local selected=nil;local busy=false;local special=false
local cards={};local sections={}
local blur=new('BlurEffect',game:GetService('Lighting'),{Name='PetIndexBlur',Size=0,Enabled=false})

-- ---------------------------------------------------------------------------------------------
-- pet pictures: the 2D icon, or a 3D render of the model in a ViewportFrame
-- ---------------------------------------------------------------------------------------------
local renders={} -- entry id -> Model (built once, cloned into the preview)
-- the pet's own model when it has one (many Steal an Egg icon ids no longer load), else its egg, else its icon
local function hasModel(e)
 local entry=Catalog.get(e.SourceName)
 return (entry~=nil and Catalog.hasModel(entry)) or GamePet.get(e.SourceName)~=nil or GameEgg.get(e.SourceName)~=nil
end
local function hasIcon(e) return not hasModel(e) and e.Icon~=nil and e.Icon~='' end
local function viewport(parent)
 local vp=new('ViewportFrame',parent,{Name='Render',Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Ambient=Color3.fromRGB(175,175,175),LightColor=Color3.new(1,1,1),LightDirection=Vector3.new(-.6,-1,-.8)})
 local cam=new('Camera',vp,{FieldOfView=30});vp.CurrentCamera=cam
 new('WorldModel',vp,{})
 return vp
end
local function frameModel(vp,model,distance)
 local cf,size=model:GetBoundingBox()
 local reach=math.max(size.X,size.Y,size.Z)
 -- three-quarter view from the front (pets look along -Z)
 local dir=Vector3.new(.62,.32,-1).Unit
 vp.CurrentCamera.CFrame=CFrame.lookAt(cf.Position+dir*reach*(distance or 1.62),cf.Position)
end
local function showModel(vp,model)
 local wm=vp:FindFirstChildOfClass('WorldModel')
 wm:ClearAllChildren();model.Parent=wm;frameModel(vp,model,vp:GetAttribute('Distance'))
end
local function buildRender(e)
 while renders[e.Id]=='building' do task.wait(.1) end
 if renders[e.Id]~=nil then return renders[e.Id] or nil end
 renders[e.Id]='building'
 local ok,rig=pcall(PetRig.build,e.SourceName,Vector3.new(4,4,4))
 if not (ok and rig) then
  local egg=GameEgg.get(e.SourceName)
  ok,rig=false,nil
  if egg then ok,rig=pcall(EggVisual.build,egg,Vector3.new(4,4,4)) end
 end
 if not (ok and rig) then renders[e.Id]=false;return nil end
 rig:place(CFrame.identity)
 local model=rig.model
 for _,d in model:GetDescendants() do if d:IsA('BasePart') then d.Anchored=true end end
 renders[e.Id]=model
 return model
end
local function paint(pic,known)
 -- ImageLabel and ViewportFrame both tint with ImageColor3
 if not pic then return end
 pic.ImageColor3=known and Color3.new(1,1,1) or SILHOUETTE;pic.ImageTransparency=known and 0 or .25
end
-- picture for a card or the preview: the icon right away, or a viewport filled once the model is ready
local function picture(parent,e,onReady,distance)
 local art=Art.Pets[e.Id]
 if art then
  local im=image(parent,art.Image,UDim2.fromScale(0,0),UDim2.fromScale(1,1));im.Name='Icon';im.ImageRectOffset=art.Offset;im.ImageRectSize=art.Size;return im
 end
 if not hasModel(e) then
  local im=image(parent,hasIcon(e) and e.Icon or Art.Book,UDim2.fromScale(0,0),UDim2.fromScale(1,1));im.Name='Icon';return im
 end
 local vp=viewport(parent)
 vp:SetAttribute('Distance',distance)
 task.spawn(function()
  local model=buildRender(e)
  if not vp.Parent then return end
  if model then showModel(vp,model:Clone());if onReady then onReady(vp) end return end
  -- no model after all: fall back to the icon
  vp:Destroy()
  local im=image(parent,(e.Icon~=nil and e.Icon~='') and e.Icon or Art.Book,UDim2.fromScale(0,0),UDim2.fromScale(1,1));im.Name='Icon'
  if onReady then onReady(im) end
 end)
 return vp
end

local function details()
 local e=selected;if not e then return end
 local known=state.Discovered[e.Id]==true
 if previewHolder:GetAttribute('Pet')~=e.Id then
  previewHolder:ClearAllChildren();previewHolder:SetAttribute('Pet',e.Id)
  local shadow=image(previewHolder,SHADOW,UDim2.new(.05,0,.86,0),UDim2.new(.9,0,.12,0));shadow.ImageColor3=Color3.new(0,0,0);shadow.ImageTransparency=.75;shadow.ScaleType=Enum.ScaleType.Stretch
  local pic=picture(previewHolder,e,function(p) if previewHolder:GetAttribute('Pet')==e.Id then previewHolder:SetAttribute('Pic',p.Name);details() end end,2)
  previewHolder:SetAttribute('Pic',pic.Name)
 end
 paint(previewHolder:FindFirstChild(previewHolder:GetAttribute('Pic') or ''),known)
 petName.Text=known and e.Name or '???';rarity.Text=e.Rarity;rarity.TextColor3=colors[e.Rarity] or Color3.new(1,1,1)
 income.Text=known and ('$'..format(e.Income)..'/s') or 'Not discovered'
 cashLabel.Text='$'..format(e.CashReward);speedLabel.Text='+'..format(e.SpeedReward)
 local claimed=state.Claimed[e.Id]==true
 claimLabel.Text=busy and 'CLAIMING…' or (not state.Ready and 'LOADING…' or (claimed and 'CLAIMED!' or (known and 'CLAIM!' or 'HATCH TO CLAIM')))
 claimLabel.TextSize=known and 23 or 16
 claimButton.BackgroundColor3=(known and not claimed and state.Ready) and Color3.fromRGB(83,219,31) or Color3.fromRGB(105,107,112)
 claimButton.Active=known and not claimed and state.Ready and not busy
end
local function refresh()
 local total,found=0,0
 for id in Config.ById do total+=1;if state.Discovered[id] then found+=1 end end
 totalLabel.Text=state.Ready and ('Unlocked: '..found..'/'..total) or 'Loading collection…'
 for id,c in cards do
  local known=state.Discovered[id]==true;c.title.Text=known and c.entry.Name or '???';paint(c.pic,known)
  c.outline.Color=(selected and selected.Id==id) and Color3.new(1,1,1) or Color3.new(0,0,0);c.outline.Thickness=(selected and selected.Id==id) and 3 or 2
 end
 for _,s in sections do local n=0 for _,e in s.config.Entries do if state.Discovered[e.Id] then n+=1 end end
  s.count.Text=n..'/'..#s.config.Entries;s.fill.Size=UDim2.fromScale(#s.config.Entries>0 and n/#s.config.Entries or 0,1)
  s.frame.Visible=s.config.Limited==special
 end
 details()
end
-- cards are built (and models requested) only when their biome scrolls into view
local function buildSection(s)
 if s.built then return end
 s.built=true
 local want={}
 for i,e in s.config.Entries do
  local col=(i-1)%4;local row=math.floor((i-1)/4)
  local b=new('TextButton',s.frame,{Name='Pet_'..e.Id,Text='',Position=UDim2.fromOffset(130+col*109,7+row*111),Size=UDim2.fromOffset(101,104),BackgroundColor3=colors[e.Rarity] or colors.Rare,BorderSizePixel=0,Selectable=true,AutoButtonColor=false,ClipsDescendants=true})
  local st=stroke(b,nil,2);shade(b,180,.72);pattern(b)
  local shadow=image(b,SHADOW,UDim2.fromOffset(5,88),UDim2.fromOffset(91,11));shadow.ImageColor3=Color3.new(0,0,0);shadow.ImageTransparency=.75;shadow.ScaleType=Enum.ScaleType.Stretch
  local holder=frame(b,'Picture',UDim2.fromOffset(4,20),UDim2.fromOffset(93,82));holder.BackgroundTransparency=1
  local pic=picture(holder,e,function(p) local c=cards[e.Id];if c then c.pic=p;paint(p,state.Discovered[e.Id]==true) end end)
  if not Art.Pets[e.Id] and hasModel(e) then table.insert(want,e.SourceName) end
  local title=label(b,'???',UDim2.fromOffset(3,1),UDim2.fromOffset(95,24),17)
  title.TextScaled=true;new('UITextSizeConstraint',title,{MaxTextSize=22})
  cards[e.Id]={entry=e,title=title,pic=pic,outline=st}
  b.Activated:Connect(function()selected=e;refresh()end)
 end
 if #want>0 and modelRequest then modelRequest:FireServer(want) end
 refresh()
end
for order,section in Config.Sections do
 local rows=math.ceil(#section.Entries/4);local h=rows*111+52
 local box=frame(list,'Biome_'..section.Id,UDim2.new(),UDim2.new(1,-12,0,h));box.LayoutOrder=order;box.BackgroundTransparency=1
 local banner=frame(box,'BiomeBanner',UDim2.fromOffset(6,7),UDim2.new(0,113,1,-14),section.Color);stroke(banner,nil,2)
 local bannerImage=Art.Biomes[section.Id]
 local bannerId=if typeof(bannerImage)=='string' then bannerImage elseif typeof(bannerImage)=='table' then bannerImage.Image else nil
 if typeof(bannerId)=='string' and bannerId~='' then
  local im=image(banner,bannerId,UDim2.new(),UDim2.fromScale(1,1));im.ScaleType=Enum.ScaleType.Crop
  if typeof(bannerImage)=='table' and bannerImage.Offset and bannerImage.Size then
   im.ImageRectOffset=bannerImage.Offset;im.ImageRectSize=bannerImage.Size
  end
 else pattern(banner) end
 label(banner,section.Name,UDim2.fromOffset(3,8),UDim2.new(1,-6,0,70),24)
 local bar=frame(box,'Progress',UDim2.fromOffset(130,h-40),UDim2.fromOffset(428,34),Color3.fromRGB(17,17,22));stroke(bar,nil,2)
 local fill=frame(bar,'Fill',UDim2.new(),UDim2.fromScale(0,1),Color3.fromRGB(255,255,255));pattern(fill)
 new('UIGradient',fill,{Rotation=180,Color=ColorSequence.new(Color3.fromRGB(6,172,3),Color3.fromRGB(120,240,60))})
 local count=label(bar,'0/'..#section.Entries,UDim2.fromScale(.3,0),UDim2.fromScale(.4,1),30)
 table.insert(sections,{config=section,frame=box,fill=fill,count=count,built=false})
end
local function buildVisible()
 if not root.Visible then return end
 local top=list.AbsolutePosition.Y-200;local bottom=list.AbsolutePosition.Y+list.AbsoluteSize.Y+200
 for _,s in sections do
  if s.frame.Visible and not s.built then
   local y=s.frame.AbsolutePosition.Y
   if y+s.frame.AbsoluteSize.Y>=top and y<=bottom then buildSection(s) end
  end
 end
end
list:GetPropertyChangedSignal('CanvasPosition'):Connect(buildVisible)
local function fetch()
 local ok,data=pcall(function()return get:InvokeServer()end)
 if ok and typeof(data)=='table' then state=data;state.Discovered=state.Discovered or {};state.Claimed=state.Claimed or {};refresh() else toast.Text='Unable to load collection. Try opening it again.' end
end
local function setOpen(value)
 root.Visible=value;backdrop.Visible=value;backdrop.Active=value;blur.Enabled=value
 if value then
  TweenService:Create(blur,TweenInfo.new(.2),{Size=12}):Play();toast.Text='';task.spawn(fetch)
  task.defer(buildVisible)
 else blur.Size=0 end
end
local function showTab(isSpecial)
 special=isSpecial;list.CanvasPosition=Vector2.zero;refresh();task.defer(buildVisible)
end
openButton.Activated:Connect(function()setOpen(not root.Visible)end)
close.Activated:Connect(function()setOpen(false)end);backdrop.Activated:Connect(function()setOpen(false)end)
world.Activated:Connect(function()showTab(false)end)
limited.Activated:Connect(function()showTab(true)end)
claimButton.Activated:Connect(function()
 if busy or not selected or not state.Ready or not state.Discovered[selected.Id] or state.Claimed[selected.Id] then return end
 busy=true;details();local ok,result=pcall(function()return claim:InvokeServer(selected.Id)end);busy=false
 if ok and typeof(result)=='table' then toast.Text=result.Message or '';if result.State then state=result.State end else toast.Text='Connection interrupted. Reopen the index to check your reward.' end
 refresh()
end)
local function resize()
 local size=workspace.CurrentCamera.ViewportSize
 PopupLayout.fit(gui,root,scale,Vector2.new(1010,530),1.2)
 openButton.Size=UDim2.fromOffset(math.clamp(size.X*.085,90,104),math.clamp(size.Y*.065,40,50))
 local w,h=openButton.Size.X.Offset,openButton.Size.Y.Offset
 speedTrack.Size=UDim2.fromOffset(w,math.max(22,h/2));speedTrack.Position=UDim2.new(0,PopupLayout.navLeft(),.47,h+10)
 openButton.Position=UDim2.new(0,PopupLayout.navLeft(),.47,0)
 local handle=speedTrack:FindFirstChild('Handle')
 if handle and handle:IsA('GuiObject') then handle.Size=UDim2.new(0,math.clamp(w*.27,22,28),1,8) end
 task.defer(buildVisible)
end
PopupLayout.watch(gui,resize)
UIS.InputBegan:Connect(function(input,processed)if not processed and input.KeyCode==Enum.KeyCode.Escape and root.Visible then setOpen(false) end end)
player:GetAttributeChangedSignal('PetIndexRevision'):Connect(function()if root.Visible then task.spawn(fetch) end end)
selected=Config.Sections[1] and Config.Sections[1].Entries[1];refresh()
