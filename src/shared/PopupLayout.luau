--!strict
-- Explorer: ReplicatedStorage.BabyBeastsShared.PopupLayout
-- Where popups may draw: below Roblox's top bar (menu / chat icons), above the backpack hotbar,
-- inside the device safe area. Popups are fitted to the largest box that fits there, and their
-- ScreenGuis sit above every HUD ScreenGui.

local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")

local PopupLayout = {}

PopupLayout.DisplayOrder = 60 -- HUD ScreenGuis stay below this
PopupLayout.Margin = 6
PopupLayout.HotbarHeight = 70 -- Roblox backpack hotbar (60px slots + padding), measured on phone and desktop

local function hotbarShown(): boolean
	local ok, enabled = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack)
	return not ok or enabled
end

-- The free box in screen pixels (top-left, size).
function PopupLayout.screenArea(): (Vector2, Vector2)
	local view = (workspace.CurrentCamera :: Camera).ViewportSize
	local topbar = GuiService.TopbarInset.Max.Y
	if topbar <= 0 then
		topbar = (GuiService:GetGuiInset()).Y
	end
	local top = topbar + PopupLayout.Margin
	local bottom = view.Y - PopupLayout.Margin - (if hotbarShown() then PopupLayout.HotbarHeight else 0)
	return Vector2.new(PopupLayout.Margin, top), Vector2.new(view.X - PopupLayout.Margin * 2, math.max(bottom - top, 100))
end

-- The free box in `gui`'s own coordinates (works for any IgnoreGuiInset / ScreenInsets setting).
function PopupLayout.area(gui: LayerCollector): (Vector2, Vector2)
	local at, size = PopupLayout.screenArea()
	-- AbsolutePosition is measured below the top bar inset whatever IgnoreGuiInset says
	local origin = gui.AbsolutePosition + (GuiService:GetGuiInset())
	local lo = Vector2.new(math.max(at.X, origin.X), math.max(at.Y, origin.Y))
	local hi = Vector2.new(math.min(at.X + size.X, origin.X + gui.AbsoluteSize.X), math.min(at.Y + size.Y, origin.Y + gui.AbsoluteSize.Y))
	return lo - origin, hi - lo
end

-- Scale `frame` (design size `design`, UIScale `scale`) to the largest size that fits the area and
-- centre it there. `stretch` (optional) gets the design size to use for a given scale, so popups
-- with scrolling content can grow taller/wider to fill the box. Returns the scale used.
function PopupLayout.fit(
	gui: LayerCollector,
	frame: GuiObject,
	scale: UIScale,
	design: Vector2,
	maxScale: number?,
	stretch: ((s: number, area: Vector2) -> Vector2)?
): number
	local at, area = PopupLayout.area(gui)
	local s = math.min(area.X / design.X, area.Y / design.Y, maxScale or 1.15)
	s = math.max(s, 0.2)
	local size = if stretch then stretch(s, area) else design
	scale.Scale = s
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = UDim2.fromOffset(size.X, size.Y)
	frame.Position = UDim2.fromOffset(math.floor(at.X + area.X / 2), math.floor(at.Y + area.Y / 2))
	return s
end

-- PenPanels egg/paw square buttons (right edge, vertically centred).
function PopupLayout.penButtonSide(): number
	return if (workspace.CurrentCamera :: Camera).ViewportSize.X < 900 then 48 else 66
end

-- Left HUD column: Shop / Index / speed slider (ShopGui, PetIndex, place-saved InterfaceStyle nav()).
function PopupLayout.navLeft(): number
	return 16
end

-- Call `refit` now and whenever the screen, safe area or top bar changes.
function PopupLayout.watch(gui: LayerCollector, refit: () -> ())
	local camera = workspace.CurrentCamera :: Camera
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(refit)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(refit)
	if gui:IsA("ScreenGui") then
		gui:GetPropertyChangedSignal("Enabled"):Connect(function()
			task.defer(refit) -- a disabled ScreenGui reports a stale size
		end)
	end
	task.defer(refit)
end

return PopupLayout
