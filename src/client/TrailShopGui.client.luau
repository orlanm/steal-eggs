-- Explorer: StarterPlayer.StarterPlayerScripts.BabyBeastsClient.TrailShopGui
-- Trail shop menu. Opens when the player steps on the glowing pad in front of the stall.
-- Layout follows the reference shop: purple studded header + red X, a dark body with a horizontal row of
-- rarity cards (name, rarity, runner art, speed bar, cash + Robux buttons). On desktop the window takes
-- ~61% x 64% of the screen like the reference; short screens (phones) switch to a compact layout that
-- fills the free popup area so the text stays readable.

local Players=game:GetService("Players")
local Tween=game:GetService("TweenService")
local UIS=game:GetService("UserInputService")
local Market=game:GetService("MarketplaceService")
local player=Players.LocalPlayer
local shared=game.ReplicatedStorage:WaitForChild("BabyBeastsShared")
local Economy=require(shared:WaitForChild("EconomyConfig"))
local Products=require(shared:WaitForChild("TrailProductIds"))
local Art=require(shared:WaitForChild("TrailShopArt"))
local remotes=shared:WaitForChild("Remotes")
local buy=remotes:WaitForChild("BuyTrail");local equip=remotes:WaitForChild("EquipTrail");local robux=remotes:WaitForChild("PromptTrailRobux");local result=remotes:WaitForChild("TrailShopResult")
local PopupLayout=require(shared:WaitForChild("PopupLayout"))
local gui=Instance.new("ScreenGui");gui.Name="TrailShopGui";gui.ResetOnSpawn=false;gui.DisplayOrder=PopupLayout.DisplayOrder;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Enabled=false;gui.Parent=player:WaitForChild("PlayerGui")

local INK=Color3.fromRGB(10,10,16)
local FONT=Enum.Font.FredokaOne
local LIME,LIME_EDGE=Color3.fromRGB(118,226,36),Color3.fromRGB(34,92,10)
local PURPLE,PURPLE_EDGE=Color3.fromRGB(168,52,240),Color3.fromRGB(70,14,120)
local SPEED_LIME="#9CFF3A"

-- Two size presets in design pixels (the window is scaled as a whole by a UIScale).
local FULL={W=1000,H=600,header=92,title=54,close=72,top=110,cardW=300,cardH=464,gap=20,name=38,rarity=22,heroY=58,heroH=300,bar=50,barText=34,btn=54,btnText=34,robuxText=30}
local COMPACT={W=640,H=470,header=72,title=44,close=58,top=86,cardW=262,cardH=362,gap=14,name=34,rarity=21,heroY=50,heroH=210,bar=46,barText=31,btn=50,btnText=31,robuxText=28}

local function corner(p,r) local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,r or 4);c.Parent=p;return c end
local function stroke(p,c,w,name) local s=Instance.new("UIStroke");s.Name=name or "UIStroke";s.Color=c;s.Thickness=w;s.ApplyStrokeMode=if p:IsA("GuiButton") or p:IsA("Frame") then Enum.ApplyStrokeMode.Border else Enum.ApplyStrokeMode.Contextual;s.LineJoinMode=Enum.LineJoinMode.Round;s.Parent=p;return s end
local function label(p,text,size)
 local l=Instance.new("TextLabel");l.BackgroundTransparency=1;l.Text=text;l.TextColor3=Color3.new(1,1,1);l.Font=FONT;l.TextSize=size;l.Parent=p;stroke(l,INK,3);return l
end
-- shrink-to-fit text capped at `size` (long names / big prices stay inside their box)
local function fit(l,size)
 local c=l:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint");c.MaxTextSize=size;c.MinTextSize=8;c.Parent=l
 l.TextScaled=true;l.TextSize=size
end
local function studs(p,tint,alpha,tile)
 local i=Instance.new("ImageLabel");i.Name="Studs";i.BackgroundTransparency=1;i.Image=Art.Background;i.Size=UDim2.fromScale(1,1);i.ScaleType=Enum.ScaleType.Tile;i.TileSize=UDim2.fromOffset(tile or 64,tile or 64);i.ImageColor3=tint;i.ImageTransparency=alpha;i.ZIndex=0;i.Parent=p;return i
end
local function button(p,name,color,edge)
 local b=Instance.new("TextButton");b.Name=name;b.Text="";b.BackgroundColor3=color;b.AutoButtonColor=true;b.Font=FONT;b.TextColor3=Color3.new(1,1,1);b.Parent=p;corner(b,4);stroke(b,edge,3)
 local t=label(b,"",30);t.Name="Caption";t.AnchorPoint=Vector2.new(.5,.5);t.Position=UDim2.fromScale(.5,.5);t.Size=UDim2.new(1,-10,.8,0);t.Active=false
 return b,t
end

local dim=Instance.new("TextButton");dim.Name="Backdrop";dim.Size=UDim2.fromScale(1,1);dim.BackgroundTransparency=1;dim.Text="";dim.AutoButtonColor=false;dim.Parent=gui
local window=Instance.new("Frame");window.Name="Window";window.AnchorPoint=Vector2.new(.5,.5);window.Position=UDim2.fromScale(.5,.5);window.Size=UDim2.fromOffset(FULL.W,FULL.H);window.BackgroundColor3=Color3.fromRGB(40,40,50);window.Parent=gui;corner(window,6);stroke(window,Color3.fromRGB(18,18,24),5)
studs(window,Color3.fromRGB(120,120,140),.86)
local scale=Instance.new("UIScale");scale.Parent=window

-- header: purple gradient, studs, two diagonal sheen bands, title, toast, red X
local header=Instance.new("Frame");header.Name="Header";header.Position=UDim2.fromOffset(0,0);header.BackgroundColor3=Color3.fromRGB(170,48,250);header.BorderSizePixel=0;header.ClipsDescendants=true;header.Parent=window;corner(header,6)
local hg=Instance.new("UIGradient");hg.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(150,34,236)),ColorSequenceKeypoint.new(.55,Color3.fromRGB(190,70,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(150,34,236))});hg.Parent=header
studs(header,Color3.fromRGB(235,190,255),.8)
local sheen=Instance.new("Frame");sheen.Name="ThemeGloss";sheen.BackgroundTransparency=1;sheen.Size=UDim2.fromScale(1,1);sheen.ZIndex=0;sheen.Parent=header
for j,w in {70,24} do
 local band=Instance.new("Frame");band.BorderSizePixel=0;band.BackgroundColor3=Color3.new(1,1,1);band.BackgroundTransparency=.84;band.AnchorPoint=Vector2.new(.5,.5);band.Size=UDim2.new(0,w,3,0);band.Position=UDim2.new(.62,(j-1)*110,.5,0);band.Rotation=35;band.Parent=sheen
end
local divider=Instance.new("Frame");divider.Name="Divider";divider.BorderSizePixel=0;divider.BackgroundColor3=Color3.fromRGB(18,18,24);divider.AnchorPoint=Vector2.new(0,1);divider.Size=UDim2.new(1,0,0,4);divider.Parent=window
local title=label(header,"Trail Shop",54);title.Name="ShopTitle";title.TextXAlignment=Enum.TextXAlignment.Left
local status=label(header,"",22);status.Name="Status";status.TextXAlignment=Enum.TextXAlignment.Right;status.TextWrapped=true;status.TextTransparency=1;status.TextColor3=Color3.fromRGB(255,240,140)
local statusStroke=status:FindFirstChildOfClass("UIStroke")
local close,closeText=button(header,"Close",Color3.fromRGB(226,34,34),Color3.fromRGB(96,8,8));closeText.Text="X"

-- cards row
local scroll=Instance.new("ScrollingFrame");scroll.Name="Cards";scroll.BackgroundTransparency=1;scroll.BorderSizePixel=0;scroll.ScrollBarThickness=6;scroll.ScrollBarImageColor3=Color3.fromRGB(210,210,222);scroll.ScrollBarImageTransparency=.15;scroll.ScrollingDirection=Enum.ScrollingDirection.X;scroll.AutomaticCanvasSize=Enum.AutomaticSize.X;scroll.CanvasSize=UDim2.new();scroll.ElasticBehavior=Enum.ElasticBehavior.WhenScrollable;scroll.Parent=window
local layout=Instance.new("UIListLayout");layout.FillDirection=Enum.FillDirection.Horizontal;layout.SortOrder=Enum.SortOrder.LayoutOrder;layout.Parent=scroll
local pad=Instance.new("UIPadding");pad.PaddingTop=UDim.new(0,4);pad.Parent=scroll

local cards={};local pendingUntil=0;local prices={}
local M=FULL
local function send(event,id)
 if os.clock()<pendingUntil then return end
 pendingUntil=os.clock()+.8;event:FireServer(id)
end
local toastId=0
local function toast(text)
 toastId+=1;local mine=toastId
 status.Text=text;status.TextTransparency=0;if statusStroke then statusStroke.Transparency=0 end
 task.delay(3,function()
  if mine~=toastId then return end
  Tween:Create(status,TweenInfo.new(.4),{TextTransparency=1}):Play()
  if statusStroke then Tween:Create(statusStroke,TweenInfo.new(.4),{Transparency=1}):Play() end
 end)
end
local function ownedSet() local t={};for id in tostring(player:GetAttribute("OwnedTrails") or ""):gmatch("[^,]+") do t[id]=true end;return t end

-- place every card's pieces for the current preset
local function placeCard(c)
 local w=M.cardW
 c.frame.Size=UDim2.fromOffset(w,M.cardH)
 c.name.Position=UDim2.fromOffset(6,8);c.name.Size=UDim2.new(1,-12,0,M.name+4);fit(c.name,M.name)
 c.rarity.Position=UDim2.fromOffset(6,M.name+4);c.rarity.Size=UDim2.new(1,-12,0,M.rarity+4);fit(c.rarity,M.rarity)
 c.hero.Position=UDim2.fromOffset(-10,M.heroY);c.hero.Size=UDim2.fromOffset(w+20,M.heroH)
 local btnY=M.cardH-14-M.btn
 local barY=btnY-12-M.bar
 c.bar.Position=UDim2.fromOffset(16,barY);c.bar.Size=UDim2.new(1,-32,0,M.bar);fit(c.barText,M.barText)
 local owned=c.owned
 local cashW=if owned then w-32 else math.floor((w-32)*.58)
 c.buy.Position=UDim2.fromOffset(16,btnY);c.buy.Size=UDim2.fromOffset(cashW,M.btn);fit(c.buyText,M.btnText)
 if c.robux then
  c.robux.Position=UDim2.fromOffset(16+cashW+6,btnY);c.robux.Size=UDim2.fromOffset(w-32-cashW-6,M.btn);fit(c.robuxText,M.robuxText)
 end
end

local function refresh()
 local owned=ownedSet();local selected=player:GetAttribute("EquippedTrail")
 for id,c in cards do
  local has=owned[id]==true
  c.owned=has
  if selected==id then
   c.buy.BackgroundColor3=Color3.fromRGB(24,178,170);c.buyText.Text="EQUIPPED"
  elseif has then
   c.buy.BackgroundColor3=Color3.fromRGB(255,206,30);c.buyText.Text="EQUIP"
  else
   c.buy.BackgroundColor3=LIME;c.buyText.Text=Economy.formatCash(c.trail.Cash)
  end
  if c.robux then
   c.robux.Visible=not has;c.robuxText.Text=utf8.char(0xE002).." "..tostring(prices[id] or c.trail.Robux)
  end
  placeCard(c)
 end
end

for index,trail in Economy.Trails do
 local card=Instance.new("Frame");card.Name=trail.Id;card.LayoutOrder=index;card.BackgroundColor3=Color3.new(1,1,1);card.ClipsDescendants=true;card.Parent=scroll;corner(card,4);stroke(card,Color3.fromRGB(20,20,28),4)
 local gradient=Instance.new("UIGradient");gradient.Rotation=90;gradient.Color=ColorSequence.new(trail.Card2,trail.Card);gradient.Parent=card
 studs(card,Color3.new(1,1,1),.7)
 local hero=Instance.new("ImageLabel");hero.Name="TrailProductArtwork";hero.BackgroundTransparency=1;hero.Image=Art.Hero;hero.ScaleType=Enum.ScaleType.Fit;hero.ImageColor3=trail.Figure;hero.ZIndex=1;hero.Parent=card
 if trail.Style=="rainbow" or trail.Id=="Moonbloom" or trail.Style=="galaxy" or trail.Style=="zebra" then
  hero.ImageColor3=Color3.new(1,1,1);local g=Instance.new("UIGradient");g.Rotation=35
  local colors=if trail.Style=="rainbow" then {Color3.fromRGB(255,235,72),Color3.fromRGB(255,145,66),Color3.fromRGB(110,255,149),Color3.fromRGB(74,190,255),Color3.fromRGB(188,94,255)} elseif trail.Style=="zebra" then {Color3.new(1,1,1),Color3.new(.08,.1,.17),Color3.new(1,1,1),Color3.new(.08,.1,.17),Color3.new(1,1,1)} elseif trail.Style=="galaxy" then {Color3.fromRGB(244,120,255),Color3.fromRGB(117,62,224),Color3.fromRGB(71,205,255)} else {Color3.fromRGB(132,255,205),Color3.fromRGB(68,208,255),Color3.fromRGB(196,143,255)}
  local keys={};for k,c in colors do table.insert(keys,ColorSequenceKeypoint.new((k-1)/(#colors-1),c)) end;g.Color=ColorSequence.new(keys);g.Parent=hero
 end
 local name=label(card,trail.Name,38);name.Name="TrailName";name.ZIndex=2
 local rarity=label(card,trail.Rarity,22);rarity.Name="Rarity";rarity.ZIndex=2
 local bar=Instance.new("Frame");bar.Name="SpeedBar";bar.BackgroundColor3=Color3.fromRGB(58,58,68);bar.BackgroundTransparency=.08;bar.ZIndex=2;bar.Parent=card;corner(bar,4);stroke(bar,Color3.fromRGB(24,24,30),3)
 local barText=label(bar,"",34);barText.Name="Multiplier";barText.AnchorPoint=Vector2.new(.5,.5);barText.Position=UDim2.fromScale(.5,.5);barText.Size=UDim2.new(1,-12,.84,0);barText.RichText=true;barText.ZIndex=3
 barText.Text='<font color="'..SPEED_LIME..'">'..Economy.formatMultiplier(trail.Multiplier).."</font> Speed"
 local cashB,cashText=button(card,"BuyCash",LIME,LIME_EDGE);cashB.ZIndex=2;cashText.ZIndex=3
 local robuxB,robuxText=nil,nil
 if trail.Robux>0 and Products[trail.Id] then
  robuxB,robuxText=button(card,"BuyRobux",PURPLE,PURPLE_EDGE);robuxB.ZIndex=2;robuxText.ZIndex=3
  robuxB.Activated:Connect(function() send(robux,trail.Id) end)
  task.spawn(function() local ok,info=pcall(Market.GetProductInfoAsync,Market,Products[trail.Id],Enum.InfoType.Product);if ok and info.PriceInRobux then prices[trail.Id]=info.PriceInRobux;refresh() end end)
 end
 cashB.Activated:Connect(function() local owned=ownedSet();if player:GetAttribute("EquippedTrail")==trail.Id then toast("This trail is already equipped");return end;send(if owned[trail.Id] then equip else buy,trail.Id) end)
 cards[trail.Id]={trail=trail,frame=card,name=name,rarity=rarity,hero=hero,bar=bar,barText=barText,buy=cashB,buyText=cashText,robux=robuxB,robuxText=robuxText,owned=false}
end

-- size the window: reference proportions on desktop, compact + fill on short or narrow screens
local function resize()
 local vp=workspace.CurrentCamera.ViewportSize
 local _,area=PopupLayout.area(gui)
 local compact=area.Y<540 or vp.X/vp.Y<.9
 M=if compact then COMPACT else FULL
 -- the reference window is 61% x 64% of a 1640x940 screen; smaller screens (laptops, tablets) give it more room
 local wFrac=math.clamp(.612+(1400-vp.X)/1400,.612,.92);local hFrac=math.clamp(.645+(900-vp.Y)/900,.645,.92)
 local maxScale=if compact then 1.15 else math.min(vp.X*wFrac/FULL.W,vp.Y*hFrac/FULL.H)
 maxScale=math.max(maxScale,.5)
 PopupLayout.fit(gui,window,scale,Vector2.new(M.W,M.H),maxScale,function(s,a)
  if not compact then return Vector2.new(M.W,M.H) end
  -- phones in landscape: widen to the free area so more cards show; portrait keeps ~2 cards
  return Vector2.new(math.clamp(math.floor(a.X*.98/s),M.W,1400),M.H)
 end)
 header.Size=UDim2.new(1,0,0,M.header)
 divider.Position=UDim2.fromOffset(0,M.header+2)
 title.Position=UDim2.fromOffset(22,0);title.Size=UDim2.new(.5,0,1,0);title.TextSize=M.title
 close.Size=UDim2.fromOffset(M.close,M.close);close.Position=UDim2.new(1,-(M.close+(M.header-M.close)/2),0,(M.header-M.close)/2);closeText.TextSize=math.floor(M.close*.7)
 status.Position=UDim2.new(.42,0,0,0);status.Size=UDim2.new(.58,-(M.close+30),1,0);status.TextSize=if compact then 20 else 24
 scroll.Position=UDim2.fromOffset(18,M.top);scroll.Size=UDim2.new(1,-22,0,M.cardH+22)
 layout.Padding=UDim.new(0,M.gap)
 pad.PaddingRight=UDim.new(0,M.gap)
 for _,c in cards do placeCard(c) end
end
PopupLayout.watch(gui,resize)

-- mouse wheel scrolls the card row sideways
scroll.InputChanged:Connect(function(input)
 if input.UserInputType~=Enum.UserInputType.MouseWheel then return end
 local max=math.max(0,scroll.AbsoluteCanvasSize.X-scroll.AbsoluteSize.X)
 scroll.CanvasPosition=Vector2.new(math.clamp(scroll.CanvasPosition.X-input.Position.Z*(M.cardW+M.gap)*scale.Scale*.5,0,max),0)
end)

local blur=Instance.new("BlurEffect");blur.Name="TrailShopBlur";blur.Size=0;blur.Enabled=false;blur.Parent=game:GetService("Lighting")
gui:GetPropertyChangedSignal("Enabled"):Connect(function()
 blur.Enabled=gui.Enabled
 if gui.Enabled then Tween:Create(blur,TweenInfo.new(.18),{Size=14}):Play() else blur.Size=0 end
end)
local function closeShop() gui.Enabled=false end
local opener=Instance.new("BindableEvent");opener.Name="OpenShop";opener.Parent=gui;opener.Event:Connect(function() gui.Enabled=true;refresh() end)
close.Activated:Connect(closeShop);dim.Activated:Connect(closeShop)
UIS.InputBegan:Connect(function(input,processed) if gui.Enabled and not processed and (input.KeyCode==Enum.KeyCode.Escape or input.KeyCode==Enum.KeyCode.ButtonB) then closeShop() end end)
local lastPadOpen=0
local function openFromPad()
 if gui.Enabled or os.clock()-lastPadOpen<.6 then return end
 lastPadOpen=os.clock();gui.Enabled=true;refresh()
end
local boundPads={}
local function bindPad(pad: BasePart)
 if boundPads[pad] then return end
 boundPads[pad]=true
 pad.Touched:Connect(function(hit)
  local char=player.Character;if not char or not hit:IsDescendantOf(char) then return end
  openFromPad()
 end)
end
local function scanPads(root: Instance)
 for _,d in root:GetDescendants() do
  if d:IsA("BasePart") and (d.Name=="TrailShopPad" or d:GetAttribute("TrailShopPad")==true) then bindPad(d) end
 end
end
scanPads(workspace)
workspace.DescendantAdded:Connect(function(d)
 if d:IsA("BasePart") and (d.Name=="TrailShopPad" or d:GetAttribute("TrailShopPad")==true) then task.defer(bindPad,d) end
end)
result.OnClientEvent:Connect(function(payload) if typeof(payload)=="table" then pendingUntil=0;if payload.Message and payload.Message~="" then toast(tostring(payload.Message)) end;refresh() end end)
for _,attr in {"OwnedTrails","EquippedTrail"} do player:GetAttributeChangedSignal(attr):Connect(refresh) end
refresh()
resize()
