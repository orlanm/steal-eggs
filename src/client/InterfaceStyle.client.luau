-- Shared presentation only: existing buttons retain their original purchase/action handlers.
local Players=game:GetService('Players')
local Shared=game.ReplicatedStorage:WaitForChild('BabyBeastsShared')
local Art=require(Shared:WaitForChild('UIArt'))
local ICON_ATLAS='rbxassetid://70709300103633'
local STUDS='rbxassetid://90905612029973'
local iconNames={'CashStack','Sneaker','Star','Gift','Cart','Book','LuckyEgg','Fuse','Tag','Stopwatch','Treadmill','Coin','Paw','Settings','Home','Trails'}
local iconRects={}
for i,k in iconNames do iconRects[Art[k]]=Vector2.new(((i-1)%4)*256,math.floor((i-1)/4)*256) end
local function atlas(i)
 local offset=iconRects[i.Image]
 if offset then i.Image=ICON_ATLAS;i.ImageRectOffset=offset;i.ImageRectSize=Vector2.new(256,256) end
end
local gui=Players.LocalPlayer:WaitForChild('PlayerGui')
local allowed={PetIndex=true,PetIndexButton=true,ShopGui=true,ShopButton=true,EggShopGui=true,EggShopButton=true,TrailShopGui=true,FuseGui=true,CornerHud=true,MountGui=true,StarHandlerDialog=true,NamePlate=true,TreadmillToast=true,NightBanner=true,EggAnnouncements=true,EggPlaceHint=true,MommyEncounterHUD=true}
local replacements={}
local old={Cart='107949492969780',CashStack='115323095843772',Coin='131973943181308',Gift='134843472439582',LuckyEgg='91499233186183',Sneaker='98938055119026',Star='107674190234622',Stopwatch='92469144483321',Tag='122745120761261',Treadmill='102979272129329',Book='140346688424028',Studs='90325592797235'}
for key,id in old do replacements['rbxassetid://'..id]=Art[key] end
replacements['rbxassetid://134699487403515']=Art.CashStack;replacements['rbxassetid://112997668597638']=Art.Sneaker
replacements['rbxassetid://103752643923608']=Art.Studs
local function pic(parent,key,name)
 local i=Instance.new('ImageLabel');i.Name=name or 'ThemeIcon';i.BackgroundTransparency=1;i.Image=Art[key];i.ScaleType=Enum.ScaleType.Fit;i.Active=false;i.Parent=parent;atlas(i);return i
end
local function tint(parent)
 local grad=parent:FindFirstChildOfClass('UIGradient')
 if grad then return grad.Color.Keypoints[1].Value end
 local col=parent.BackgroundColor3
 if math.max(col.R,col.G,col.B)<.25 then return Color3.fromRGB(130,130,150) end
 return col
end
local function surface(parent,key,alpha)
 if parent:FindFirstChild('ThemeSurface') or parent:FindFirstChild('Studs') or parent:FindFirstChild('StudPattern') then return end
 local i=pic(parent,'Studs','ThemeSurface');i.Image=STUDS;i.Size=UDim2.fromScale(1,1);i.ScaleType=Enum.ScaleType.Tile;i.TileSize=UDim2.fromOffset(128,128);i.ImageTransparency=alpha;i.ZIndex=0
 i.ImageColor3=tint(parent)
end
local function gloss(parent)
 if parent:FindFirstChild('ThemeGloss') then return end
 local clip=Instance.new('Frame');clip.Name='ThemeGloss';clip.BackgroundTransparency=1;clip.Size=UDim2.fromScale(1,1);clip.ClipsDescendants=true;clip.ZIndex=0;clip.Parent=parent
 for j,w in {80,26} do
  local band=Instance.new('Frame');band.BorderSizePixel=0;band.BackgroundColor3=Color3.new(1,1,1);band.BackgroundTransparency=.82;band.Size=UDim2.new(0,w,0,220);band.Position=UDim2.new(.5,j*85,0,-90);band.Rotation=40;band.Parent=clip
 end
end
local function textStyle(o)
 if o:IsA('TextLabel') or o:IsA('TextButton') then
  if o.TextSize>=20 then o.Font=Enum.Font.FredokaOne
   if not o:FindFirstChildOfClass('UIStroke') then local st=Instance.new('UIStroke');st.Color=Color3.fromRGB(8,9,15);st.Thickness=2;st.Parent=o end
  end
 end
end
local function style(o)
 if o.Name:sub(1,5)=='Theme' then return end
 textStyle(o)
 if (o:IsA('TextButton') or o:IsA('TextLabel')) and o.Text=='⚡' then o.TextTransparency=1;local i=pic(o,'Sneaker','ThemeIcon');i.Size=UDim2.fromScale(.86,.86);i.Position=UDim2.fromScale(.07,.07) end
 if o:IsA('UICorner')then o.CornerRadius=UDim.new(0,2)
 elseif o:IsA('ImageLabel')or o:IsA('ImageButton')then
  if replacements[o.Image]then o.Image=replacements[o.Image]end;atlas(o)
  if o.Name=='HeaderArtwork' then o.Image=STUDS;o.BackgroundTransparency=0;o.BackgroundColor3=o:FindFirstAncestor('FuseGui') and Color3.fromRGB(145,45,235) or Color3.fromRGB(244,177,32);o.ImageColor3=o.BackgroundColor3;o.ImageTransparency=.75;o.ScaleType=Enum.ScaleType.Tile;o.TileSize=UDim2.fromOffset(128,128) end
  if o.Name=='Studs' or o.Name=='StudPattern'then o.Image=STUDS;o.ImageTransparency=.78;o.ImageColor3=tint(o.Parent);o.ScaleType=Enum.ScaleType.Tile;o.TileSize=UDim2.fromOffset(128,128) end
 elseif o:IsA('GuiButton')then
  if o.Name=='Backdrop' or o.Name=='Shade' or o.BackgroundTransparency>.4 or o.Name:match('^Pet_')then return end
  o.BorderSizePixel=0
  local c=o:FindFirstChildOfClass('UICorner')or Instance.new('UICorner');c.CornerRadius=UDim.new(0,2);c.Parent=o
  local st=o:FindFirstChildOfClass('UIStroke')or Instance.new('UIStroke');st.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;st.Color=Color3.fromRGB(8,9,15);st.Thickness=2;st.Parent=o
  surface(o,'Button',.78)
  if o:IsA('TextButton')then o.Font=Enum.Font.FredokaOne end
  local t=o:IsA('TextButton')and o.Text or '';local child=o:FindFirstChildWhichIsA('TextLabel')
  if t=='X' or t=='×' or (child and (child.Text=='X'or child.Text=='×'))then
   o.BackgroundColor3=Color3.fromRGB(231,64,69)
   local label=child or o
   label.TextTransparency=0;label.TextColor3=Color3.new(1,1,1);label.Font=Enum.Font.FredokaOne
   label.TextStrokeTransparency=1
   local outline=label:FindFirstChild('CloseOutline') or Instance.new('UIStroke');outline.Name='CloseOutline';outline.ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual;outline.Thickness=2.5;outline.Color=Color3.new(0,0,0);outline.Parent=label

  end
 elseif o:IsA('Frame')then
  if o.Name=='Header' then surface(o,'Header',.76);gloss(o)
  elseif o.BackgroundTransparency<.2 and (o.Name=='Panel' or o.Name=='GiftPlayer' or o.Parent:IsA('ScreenGui')) then o.BackgroundColor3=Color3.fromRGB(43,43,53);surface(o,'Studs',.78) end
 end
end
local function nav(g)
 local kind=g.Name=='ShopButton'and'Cart'or g.Name=='EggShopButton'and'LuckyEgg'or g.Name=='PetIndexButton'and'Book'
 if not kind or kind=='LuckyEgg' then return end
 local b
 for _,v in g:GetChildren()do if v:IsA('GuiButton')and v.Name~='Backdrop'then b=v;break end end
 if not b then return end
 -- Tight width: icon + label with minimal side padding (was 110/155).
 local cam=workspace.CurrentCamera;local small=cam.ViewportSize.X<900;local w,h=small and 90 or 104,small and 40 or 50
 local slot=kind=='Cart'and-1 or kind=='Book'and 0 or 1
 b.AnchorPoint=Vector2.zero;b.Position=UDim2.new(0,16,.47,slot*(h+10));b.Size=UDim2.fromOffset(w,h)
 b.BackgroundColor3=kind=='Cart'and Color3.fromRGB(95,236,20)or kind=='Book'and Color3.fromRGB(0,198,242)or Color3.fromRGB(242,172,55)
 if kind=='LuckyEgg'then
  b.Text='';local icon=b:FindFirstChild('ThemeIcon')or pic(b,kind);icon.Position=UDim2.fromScale(.02,.08);icon.Size=UDim2.fromScale(.28,.84)
  local l=b:FindFirstChild('ThemeCaption')or Instance.new('TextLabel');l.Name='ThemeCaption';l.BackgroundTransparency=1;l.Font=Enum.Font.FredokaOne;l.Text='Eggs';l.TextColor3=Color3.new(1,1,1);l.TextSize=small and 18 or 22;l.Position=UDim2.fromScale(.30,0);l.Size=UDim2.fromScale(.68,1);l.Parent=b
 else
  for _,i in b:GetChildren()do if i:IsA('ImageLabel')and i.Name~='Studs'and i.Name~='StudPattern'and i.Name~='ThemeSurface'then i.Image=Art[kind];atlas(i);i.Position=UDim2.fromScale(.02,.08);i.Size=UDim2.fromScale(.28,.84)end end
 end
 for _,l in b:GetChildren()do if l:IsA('TextLabel')then
  l.Font=Enum.Font.FredokaOne;l.TextScaled=false;l.TextSize=small and 18 or 22;l.TextColor3=Color3.new(1,1,1);l.TextXAlignment=Enum.TextXAlignment.Left
  l.Text=kind=='Cart'and'Shop'or kind=='Book'and'Index'or'Eggs';l.Position=UDim2.fromScale(.30,0);l.Size=UDim2.fromScale(.68,1)
  local st=l:FindFirstChildOfClass('UIStroke')or Instance.new('UIStroke');st.Thickness=2;st.Color=Color3.fromRGB(8,9,15);st.Parent=l
 end end
end
local function bind(g)
 if not g:IsA('ScreenGui')or not allowed[g.Name]then return end
 for _,o in g:GetDescendants()do style(o)end
 g.DescendantAdded:Connect(function(o)task.defer(function()if o.Parent then style(o)end end)end)
 task.defer(nav,g)
end
for _,g in gui:GetChildren()do bind(g)end
gui.ChildAdded:Connect(function(g)task.defer(bind,g)end)
workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Connect(function()task.defer(function()for _,g in gui:GetChildren()do nav(g)end end)end)

