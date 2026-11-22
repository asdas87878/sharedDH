--!strict
-- The shop kit (NULLROOM task s1, Hugo 2026-11-19: the buy screens "replicated as well as you can but more stylised and
-- cohesive" after his three reference shots; docs/design/ui.md, "Shop style"). Every buy or equip screen is built from
-- these pieces, so they read as one family with the HUD's Kit (its ink, its font, its rarity colours):
--   Shop.window   a chunky header bar (its colour, a fish-scale pattern, a diagonal gloss, an icon, a big outlined
--                 title, the red square X) over a dark slate body with a fine bubble pattern; fits itself to the screen
--   Shop.inset    a darker well inside a body (a list's tray, a footer bar)
--   Shop.button   a flat bright button: lighter top half, dark edge, outlined words; kinds Cash (green: you can pay),
--                 Off (grey: you can't), Robux (orange-yellow), Blue, Lavender, Red; an optional cash or Robux sign
--   Shop.card     a tall card tinted in its tier's colour: small name, a big line, a cream picture well, a stat strip,
--                 room for buttons; select() gives it the light border
--   Shop.itemCard a list card: its name in its rarity's colour, a picture, a green rate, a dark price strip
--   Shop.carousel a sideways row of cards with big arrow buttons either side
--   Shop.sort     a sort button (a down arrow and a word; green when on)
--   Shop.money    "$1.4K" in the cash green, with or without the cash sign
--   Shop.tabs     the shop's pages as tabs on a window's top edge (task b2: the hub's Shop button opens one shop with
--                 the auras and the fish selling in it); Shop.page names a page's opener, Shop.go shows one page
-- Its pictures are drawn by code (tools/ui/shop_kit/shop_art.py, art/ui/shop/). Not uploaded: Studio reads them from
-- its own content folder; a live game uses Shop.Textures' ids once they are filled, and the stand-ins below until then.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Kit = require(script.Parent.Kit)

local Shop = {}

-- Upload ids for the pictures (empty until Hugo says yes to the upload)
Shop.Textures = {
	Body = "", -- art/ui/shop/shop_body.png
	Head = "", -- art/ui/shop/shop_head.png
	Icons = "", -- art/ui/shop/shop_icons.png
}
local STUDIO = {
	Body = "rbxasset://textures/ridefish/shop_body_s1.png",
	Head = "rbxasset://textures/ridefish/shop_head_s1.png",
	Icons = "rbxasset://textures/ridefish/shop_icons_s1b.png",
}
-- Roblox's own Robux sign, shipped with every client
Shop.Robux = "rbxasset://textures/ui/common/robux.png"

local function picture(name: string): string
	local id = (Shop.Textures :: any)[name]
	if id ~= "" then
		return id
	end
	if RunService:IsStudio() then
		return (STUDIO :: any)[name]
	end
	-- a live game before the upload: the water's picture for the patterns, no header icon
	return if name == "Icons" then "" else Kit.Textures.Water
end

-- The header icons, by their place in shop_icons.png
Shop.Icons = { Sub = 0, Shell = 1, Seahorse = 2, Bubble = 3, Arrow = 4 }

-- The colours. The body is a cool slate, a little blue, so it sits under water with the HUD's navy
Shop.Body = Color3.fromRGB(34, 40, 54)
Shop.BodyDeep = Color3.fromRGB(22, 26, 36)
Shop.Edge = Color3.fromRGB(10, 12, 22) -- every thick border
Shop.Cream = Color3.fromRGB(252, 242, 218) -- a picture well
Shop.Money = Color3.fromRGB(92, 236, 60) -- cash, a rate, a multiplier
-- One colour a shop's header, each said once here (a shop picks one by name)
Shop.Heads = {
	Sea = Color3.fromRGB(44, 196, 230), -- the sub stand
	Lavender = Color3.fromRGB(168, 160, 250), -- auras
	Coral = Color3.fromRGB(255, 120, 130),
	Kelp = Color3.fromRGB(110, 220, 80), -- selling, the tank
	Sand = Color3.fromRGB(250, 200, 90),
}
-- The buttons' colours: { top half, bottom half }
Shop.Kinds = {
	Cash = { Color3.fromRGB(150, 250, 70), Color3.fromRGB(70, 206, 32) },
	Off = { Color3.fromRGB(214, 218, 226), Color3.fromRGB(160, 166, 180) },
	Robux = { Color3.fromRGB(255, 222, 60), Color3.fromRGB(255, 150, 28) },
	Blue = { Color3.fromRGB(100, 216, 255), Color3.fromRGB(28, 150, 236) },
	Lavender = { Color3.fromRGB(196, 190, 255), Color3.fromRGB(138, 128, 240) },
	Red = { Color3.fromRGB(255, 92, 110), Color3.fromRGB(214, 34, 64) },
	Gold = { Color3.fromRGB(255, 232, 110), Color3.fromRGB(246, 168, 26) },
	Purple = { Color3.fromRGB(196, 130, 255), Color3.fromRGB(142, 70, 230) },
}

-- Sizes, in the window's own points
Shop.HeadHigh = 64
Shop.Pad = 10

-- A number as money: $950, $5K, $1.4B
function Shop.cash(value: number): string
	return "$" .. Kit.short(value)
end

-- Two colours split hard at the middle: a lit top half over the colour (the reference's buttons and bars)
local function halves(top: Color3, bottom: Color3, split: number?): ColorSequence
	local at = split or 0.5
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, Kit.lighter(top, 0.12)),
		ColorSequenceKeypoint.new(at - 0.01, top),
		ColorSequenceKeypoint.new(at, bottom),
		ColorSequenceKeypoint.new(1, Kit.darker(bottom, 0.08)),
	})
end
Shop.halves = halves

-- A tiled pattern over a face: "Body" (bubble dots) or "Head" (fish scales), white tinted by colour
function Shop.pattern(face: Instance, which: string, tile: number, fade: number, colour: Color3?): ImageLabel
	return Kit.new("ImageLabel", {
		Name = "Pattern",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = picture(which),
		ImageColor3 = colour or Kit.White,
		ImageTransparency = fade,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(tile, tile),
		ZIndex = 0,
	}, face)
end

-- The gloss: two pale diagonal streaks over a bar, as one gradient (it keeps to the bar's corners)
function Shop.gloss(face: Instance, at: number?, strength: number?): Frame
	local x = at or 0.6
	local pale = 1 - (strength or 0.22)
	local frame: Frame = Kit.new("Frame", {
		Name = "Gloss",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		ZIndex = 0,
	}, face)
	Kit.new("UIGradient", {
		Rotation = -62,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(x - 0.07, 1),
			NumberSequenceKeypoint.new(x - 0.065, pale),
			NumberSequenceKeypoint.new(x - 0.01, pale),
			NumberSequenceKeypoint.new(x - 0.005, 1),
			NumberSequenceKeypoint.new(x + 0.02, 1),
			NumberSequenceKeypoint.new(x + 0.025, pale + (1 - pale) * 0.4),
			NumberSequenceKeypoint.new(x + 0.04, pale + (1 - pale) * 0.4),
			NumberSequenceKeypoint.new(x + 0.045, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, frame)
	return frame
end

-- A header icon from the atlas (empty in a live game until the upload)
function Shop.icon(parent: Instance, which: string, size: number, props: { [string]: any }?): ImageLabel
	local p = props or {}
	p.Name = p.Name or "Icon"
	p.Size = UDim2.fromOffset(size, size)
	p.BackgroundTransparency = 1
	p.Image = picture("Icons")
	p.ImageRectOffset = Vector2.new(((Shop.Icons :: any)[which] or 0) * 128, 0)
	p.ImageRectSize = Vector2.new(128, 128)
	p.ScaleType = Enum.ScaleType.Fit
	return Kit.new("ImageLabel", p, parent)
end

-- Letters as the shop writes them: Kit's font and ink edge, a little heavier than the HUD's
function Shop.text(parent: Instance, props: { [string]: any }): TextLabel
	local size = props.TextSize or 18
	return Kit.text(props, parent, math.clamp(size * 0.13, 1.5, 4.5))
end

-- A darker well inside a body (a tray, a footer bar): its own border and the bubble pattern
function Shop.inset(parent: Instance, props: { [string]: any }): Frame
	props.BackgroundColor3 = props.BackgroundColor3 or Shop.BodyDeep
	props.BorderSizePixel = 0
	local frame: Frame = Kit.new("Frame", props, parent)
	Kit.corner(frame, 6)
	Kit.stroke(frame, 3, Shop.Edge)
	Shop.pattern(frame, "Body", 40, 0.93)
	return frame
end

export type Button = {
	Root: TextButton,
	Label: TextLabel,
	Sign: ImageLabel?,
	Fill: UIGradient,
	Edge: UIStroke,
	Live: boolean,
	set: (text: string?, kind: string?, live: boolean?) -> (),
}

-- A flat bright button. props: Text, Kind (a name in Shop.Kinds), Size, Position, AnchorPoint, TextSize, Sign ("Cash"
-- or "Robux": the sign before the words), LayoutOrder, Name. Pressing it dips it; Activated fires only while live.
function Shop.button(parent: Instance, props: { [string]: any }): Button
	local kind: string = props.Kind or "Cash"
	local root: TextButton = Kit.new("TextButton", {
		Name = props.Name or "Button",
		Size = props.Size or UDim2.fromOffset(160, 44),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
	}, parent)
	Kit.corner(root, 5)
	local fill = Kit.new("UIGradient", { Rotation = 90 }, root)
	local edge = Kit.stroke(root, 3, Shop.Edge)
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	Shop.pattern(root, "Head", 26, 0.88)
	-- the inner light line along the top edge
	Kit.new("Frame", {
		Name = "Lip",
		Position = UDim2.fromOffset(4, 3),
		Size = UDim2.new(1, -8, 0, 2),
		BackgroundColor3 = Kit.White,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, root)
	local holder: Frame = Kit.new("Frame", {
		Name = "Words",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, root)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, holder)
	local size: number = props.TextSize or 22
	local sign: ImageLabel? = nil
	if props.Sign == "Cash" then
		sign = Kit.new("ImageLabel", {
			Name = "Sign",
			Size = UDim2.fromOffset(size * 1.25, size * 1.25),
			BackgroundTransparency = 1,
			Image = Kit.Textures.Cash,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 3,
		}, holder)
	elseif props.Sign == "Robux" then
		-- the Robux sign in the reference's green, on a dark disc so it reads on the orange
		local disc: Frame = Kit.new("Frame", {
			Name = "SignDisc",
			Size = UDim2.fromOffset(size * 1.05, size * 1.05),
			BackgroundTransparency = 1,
			ZIndex = 3,
		}, holder)
		sign = Kit.new("ImageLabel", {
			Name = "Sign",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = Shop.Robux,
			ImageColor3 = Color3.fromRGB(30, 150, 60),
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 4,
		}, disc)
	end
	local label = Shop.text(holder, {
		Name = "Label",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		TextSize = size,
		Text = props.Text or "",
		LayoutOrder = 2,
		ZIndex = 3,
	})
	local dip = Kit.new("UIScale", {}, root)
	local self: Button = {
		Root = root,
		Label = label,
		Sign = sign,
		Fill = fill,
		Edge = edge,
		Live = props.Live ~= false,
		set = nil :: any,
	}
	function self.set(text: string?, k: string?, live: boolean?)
		if text and label.Text ~= text then
			label.Text = text
		end
		if k then
			local pair = (Shop.Kinds :: any)[k] or Shop.Kinds.Cash
			fill.Color = halves(pair[1], pair[2])
			edge.Color = Shop.Edge
		end
		if live ~= nil then
			self.Live = live
			root.Active = live
		end
	end
	root.MouseButton1Down:Connect(function()
		if self.Live then
			dip.Scale = 0.94
		end
	end)
	local function up()
		dip.Scale = 1
	end
	root.MouseButton1Up:Connect(up)
	root.MouseLeave:Connect(up)
	self.set(nil, kind, self.Live)
	return self
end

export type Window = {
	Gui: ScreenGui,
	Root: Frame, -- the screen in the window's points
	Frame: Frame, -- the window
	Header: Frame,
	Title: TextLabel,
	Body: Frame, -- the room under the header, padded
	Close: Button,
	Scale: UIScale,
	fit: () -> (),
	show: (on: boolean) -> (),
}

-- A shop's window in its own ScreenGui. props: Name, Title, Icon (a name in Shop.Icons), Head (a name in Shop.Heads,
-- or a Color3), Centre (the title in the middle, as the auras' shot; else after the icon), Width, Height (points),
-- DisplayOrder, Parent (the PlayerGui). The X calls props.OnClose. It fits itself to the screen as TankPanel does:
-- a phone gets bigger points; in Studio the workspace's "PanelPhone" (a Vector2) lays it out for that phone.
function Shop.window(props: { [string]: any }): Window
	local wide: number = props.Width or 760
	local high: number = props.Height or 480
	-- (room kept above the window for its tabs, so they stay on a small screen)
	local above: number = if props.Tabs then Shop.TabHigh else 0
	local headColour: Color3 = if typeof(props.Head) == "Color3"
		then props.Head
		else (Shop.Heads :: any)[props.Head or "Sea"] or Shop.Heads.Sea
	local gui: ScreenGui = Kit.new("ScreenGui", {
		Name = props.Name or "Shop",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = props.DisplayOrder or 8,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
	}, props.Parent)
	local root: Frame =
		Kit.new("Frame", { Name = "Root", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui)
	local scale: UIScale = Kit.new("UIScale", {}, root)
	local holder: Frame = Kit.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, above / 2),
		Size = UDim2.fromOffset(wide, high),
		BackgroundTransparency = 1,
	}, root)
	local shadow: Frame = Kit.new("Frame", {
		Name = "Shadow",
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
	}, holder)
	Kit.corner(shadow, 10)
	local frame: Frame = Kit.new("Frame", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Shop.Body,
		BorderSizePixel = 0,
	}, holder)
	Kit.corner(frame, 10)
	Kit.stroke(frame, 4, Shop.Edge)
	Kit.gradient(frame, Kit.lighter(Shop.Body, 0.04), Kit.darker(Shop.Body, 0.12))
	Shop.pattern(frame, "Body", 44, 0.9)

	-- the header bar: its colour in two halves, scales, the gloss, a dark edge
	local header: Frame = Kit.new("Frame", {
		Name = "Header",
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 0, Shop.HeadHigh),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, frame)
	Kit.corner(header, 6)
	Kit.new("UIGradient", {
		Rotation = 90,
		Color = halves(Kit.lighter(headColour, 0.22), headColour, 0.46),
	}, header)
	Kit.stroke(header, 3, Shop.Edge)
	Shop.pattern(header, "Head", 34, 0.84)
	Shop.gloss(header, 0.62, 0.3)
	-- a darker line inside its bottom edge, so it sits on the body as a ledge
	Kit.new("Frame", {
		Name = "Floor",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 5),
		BackgroundColor3 = Kit.darker(headColour, 0.35),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, header)
	local iconSize = Shop.HeadHigh - 10
	if props.Icon then
		Shop.icon(header, props.Icon, iconSize, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Rotation = -8,
			ZIndex = 4,
		})
	end
	local centre = props.Centre == true
	local title = Shop.text(header, {
		Name = "Title",
		AnchorPoint = if centre then Vector2.new(0.5, 0.5) else Vector2.new(0, 0.5),
		Position = if centre then UDim2.fromScale(0.5, 0.5) else UDim2.new(0, iconSize + 22, 0.5, 0),
		Size = UDim2.new(1, -(iconSize * 2 + 60), 1, -8),
		TextSize = 40,
		TextXAlignment = if centre then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left,
		Text = props.Title or "",
		ZIndex = 4,
	})
	-- the red square X
	local close = Shop.button(header, {
		Name = "Close",
		Kind = "Red",
		Text = "X",
		TextSize = 34,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -7, 0.5, 0),
		Size = UDim2.fromOffset(Shop.HeadHigh - 12, Shop.HeadHigh - 12),
	})
	close.Root.ZIndex = 5
	close.Root.Activated:Connect(function()
		if props.OnClose then
			props.OnClose()
		end
	end)

	local body: Frame = Kit.new("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(Shop.Pad + 2, Shop.HeadHigh + 6 + Shop.Pad),
		Size = UDim2.new(1, -(Shop.Pad + 2) * 2, 1, -(Shop.HeadHigh + 6 + Shop.Pad * 2)),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, frame)

	local self: Window = {
		Gui = gui,
		Root = root,
		Frame = holder,
		Header = header,
		Title = title,
		Body = body,
		Close = close,
		Scale = scale,
		fit = nil :: any,
		show = nil :: any,
	}
	function self.fit()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local view = camera.ViewportSize
		local touch = Kit.touch()
		local phone = if RunService:IsStudio() then workspace:GetAttribute("PanelPhone") else nil
		if typeof(phone) == "Vector2" then
			view = phone
			touch = true
		end
		-- as big as the screen lets, a phone's points bigger; never past the screen's edges
		local s = math.clamp(view.Y / (if touch then 500 else 720), 0.5, 1.4)
		s = math.min(s, view.Y / (high + above + 16), view.X / (wide + 24))
		scale.Scale = s
		root.Size = UDim2.fromScale(1 / s, 1 / s)
		root.Position = UDim2.new()
		if typeof(phone) == "Vector2" then
			local whole = camera.ViewportSize
			root.Size = UDim2.fromOffset(view.X / s, view.Y / s)
			root.Position = UDim2.fromOffset((whole.X - view.X) / 2, (whole.Y - view.Y) / 2)
		end
	end
	local pop = Kit.new("UIScale", {}, holder)
	function self.show(on: boolean)
		if on and not gui.Enabled then
			self.fit()
			-- a short pop in
			pop.Scale = 0.86
			TweenService
				:Create(pop, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
				:Play()
		end
		gui.Enabled = on
	end
	local function refit()
		if gui.Enabled then
			self.fit()
		end
	end
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(refit)
	end
	if RunService:IsStudio() then
		workspace:GetAttributeChangedSignal("PanelPhone"):Connect(refit)
	end
	return self
end

-- The shop's pages (task b2): each a window of its own (UI.AuraShop, UI.SellFish) with the same tabs on its top edge.
-- A page gives its opener to Shop.page as it is required; Shop.go(name) shows that page and closes the others
-- (nil: closes them all); Shop.Page is the one showing. In the tabs' order.
Shop.TabHigh = 38
Shop.Pages = {
	{ Name = "Auras", Word = "AURAS", Kind = "Lavender" },
	{ Name = "Sell", Word = "SELL FISH", Kind = "Cash" },
}
Shop.Page = nil :: string?
Shop.LastPage = "Auras"
local openers: { [string]: (on: boolean) -> () } = {}

function Shop.page(name: string, open: (on: boolean) -> ())
	openers[name] = open
end

function Shop.go(name: string?)
	if name and not openers[name] then
		return
	end
	for other, open in openers do
		if other ~= name then
			open(false)
		end
	end
	Shop.Page = name
	if name then
		Shop.LastPage = name
		openers[name](true)
	end
end

-- The tabs on a window's top edge (the window made with Tabs = true): this page's in its colour and standing a
-- little taller, the others grey; a press goes to that page.
function Shop.tabs(window: Window, own: string): { [string]: Button }
	local row: Frame = Kit.new("Frame", {
		Name = "Tabs",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -32, 0, Shop.TabHigh + 8),
		BackgroundTransparency = 1,
		ZIndex = 0,
	}, window.Frame)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	local out: { [string]: Button } = {}
	for i, page in Shop.Pages do
		local mine = page.Name == own
		local b = Shop.button(row, {
			Name = page.Name,
			Text = page.Word,
			Kind = if mine then page.Kind else "Off",
			TextSize = if mine then 22 else 19,
			Size = UDim2.fromOffset(if mine then 176 else 160, if mine then Shop.TabHigh + 6 else Shop.TabHigh - 2),
			LayoutOrder = i,
		})
		b.Root.Activated:Connect(function()
			if not mine then
				Shop.go(page.Name)
			end
		end)
		out[page.Name] = b
	end
	return out
end

-- Money in the cash green: "$1.4K", the cash sign before it when asked. Returns the label (its Text to set) and the
-- holder (to place).
function Shop.money(parent: Instance, props: { [string]: any }): (TextLabel, Frame)
	local size: number = props.TextSize or 24
	local holder: Frame = Kit.new("Frame", {
		Name = props.Name or "Money",
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Position = props.Position or UDim2.new(),
		Size = props.Size or UDim2.fromOffset(200, size + 6),
		BackgroundTransparency = 1,
		ZIndex = props.ZIndex or 3,
	}, parent)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = props.Align or Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, holder)
	if props.Sign ~= false then
		Kit.new("ImageLabel", {
			Size = UDim2.fromOffset(size * 1.3, size * 1.3),
			BackgroundTransparency = 1,
			Image = Kit.Textures.Cash,
			ScaleType = Enum.ScaleType.Fit,
			LayoutOrder = 1,
			ZIndex = (props.ZIndex or 3) + 1,
		}, holder)
	end
	local label = Shop.text(holder, {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		TextSize = size,
		TextColor3 = props.Colour or Shop.Money,
		Text = props.Text or "",
		LayoutOrder = 2,
		ZIndex = (props.ZIndex or 3) + 1,
	})
	return label, holder
end

export type Card = {
	Root: Frame,
	Name: TextLabel,
	Line: TextLabel,
	Well: Frame, -- the cream picture box: put a picture or a viewport in it
	Stat: TextLabel?, -- the strip under the well (rich text: <font color=...>)
	Slot: Frame, -- the room for the buttons, at the foot
	tint: (colour: Color3) -> (),
	select: (on: boolean) -> (),
}

-- A tall card tinted in its tier's colour. props: Size (points), Tint, Name (small, at the top), Line (bigger, rich
-- text allowed), WellHigh, Stat (a strip under the well; rich text), StatHigh, SlotHigh (the buttons' room),
-- LayoutOrder. The card's colours: a lit top half, its colour under, a darker edge, the scale pattern.
function Shop.card(parent: Instance, props: { [string]: any }): Card
	local size: UDim2 = props.Size or UDim2.fromOffset(196, 300)
	local root: Frame = Kit.new("Frame", {
		Name = props.Name or "Card",
		Size = size,
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder or 0,
	}, parent)
	Kit.corner(root, 6)
	local fill = Kit.new("UIGradient", { Rotation = 90 }, root)
	local edge = Kit.stroke(root, 3, Shop.Edge)
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	Shop.pattern(root, "Head", 30, 0.86)
	Shop.gloss(root, 0.7, 0.16)
	local list: Frame = Kit.new("Frame", {
		Name = "Inside",
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.new(1, -16, 1, -14),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, root)
	Kit.new("UIListLayout", {
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}, list)
	local name = Shop.text(list, {
		Name = "Name",
		Size = UDim2.new(1, 0, 0, 16),
		TextSize = 15,
		Text = props.Title or "",
		LayoutOrder = 1,
		ZIndex = 3,
	})
	local line = Shop.text(list, {
		Name = "Line",
		Size = UDim2.new(1, 0, 0, 24),
		TextSize = 23,
		RichText = true,
		Text = props.Line or "",
		LayoutOrder = 2,
		ZIndex = 3,
	})
	local well: Frame = Kit.new("Frame", {
		Name = "Well",
		Size = UDim2.new(1, 0, 0, props.WellHigh or 120),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		LayoutOrder = 3,
		ZIndex = 3,
	}, list)
	Kit.corner(well, 4)
	Kit.gradient(well, Shop.Cream, Color3.fromRGB(240, 222, 186))
	Kit.stroke(well, 3, Shop.Edge).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	Shop.pattern(well, "Body", 30, 0.8, Color3.fromRGB(220, 196, 150))
	local stat: TextLabel? = nil
	if props.Stat then
		local strip: Frame = Kit.new("Frame", {
			Name = "StatStrip",
			Size = UDim2.new(1, 0, 0, props.StatHigh or 34),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.62,
			BorderSizePixel = 0,
			LayoutOrder = 4,
			ZIndex = 3,
		}, list)
		Kit.corner(strip, 4)
		stat = Shop.text(strip, {
			Name = "Stat",
			Size = UDim2.fromScale(1, 1),
			TextSize = props.StatSize or 26,
			RichText = true,
			Text = props.Stat,
			ZIndex = 4,
		})
	end
	local slot: Frame = Kit.new("Frame", {
		Name = "Slot",
		Size = UDim2.new(1, 0, 0, props.SlotHigh or 44),
		BackgroundTransparency = 1,
		LayoutOrder = 9,
		ZIndex = 3,
	}, list)
	Kit.new("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
	}, slot)
	local ring: UIStroke = Kit.new(
		"UIStroke",
		{
			Name = "Selected",
			Thickness = 0,
			Color = Color3.fromRGB(236, 255, 230),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			LineJoinMode = Enum.LineJoinMode.Round,
		},
		Kit.new("Frame", {
			Name = "SelectedRing",
			Position = UDim2.fromOffset(-5, -5),
			Size = UDim2.new(1, 10, 1, 10),
			BackgroundTransparency = 1,
			ZIndex = 1,
		}, root)
	)
	local self: Card = {
		Root = root,
		Name = name,
		Line = line,
		Well = well,
		Stat = stat,
		Slot = slot,
		tint = nil :: any,
		select = nil :: any,
	}
	function self.tint(colour: Color3)
		fill.Color = halves(Kit.lighter(colour, 0.2), colour, 0.5)
	end
	function self.select(on: boolean)
		ring.Thickness = if on then 4 else 0
		edge.Color = if on then Kit.White else Shop.Edge
	end
	self.tint(props.Tint or Shop.Heads.Sea)
	return self
end

export type ItemCard = { Root: Frame, Name: TextLabel, Picture: Frame, Rate: TextLabel, Price: TextLabel }

-- A list card, as the reference's sell list: the name in its rarity's colour at the top left, a clear picture area,
-- a rate in green over it, and a dark price strip with the cash sign. props: Size, Name, NameColour, Rate, Price,
-- LayoutOrder.
function Shop.itemCard(parent: Instance, props: { [string]: any }): ItemCard
	local root: Frame = Kit.new("Frame", {
		Name = "Item",
		Size = props.Size or UDim2.fromOffset(170, 186),
		BackgroundColor3 = Color3.fromRGB(44, 50, 66),
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder or 0,
	}, parent)
	Kit.corner(root, 5)
	Kit.stroke(root, 3, Shop.Edge).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	Shop.pattern(root, "Body", 34, 0.9)
	local name = Shop.text(root, {
		Name = "Name",
		Position = UDim2.fromOffset(8, 5),
		Size = UDim2.new(1, -16, 0, 20),
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = props.NameColour or Kit.White,
		Text = props.Name or "",
		ZIndex = 3,
	})
	local pic: Frame = Kit.new("Frame", {
		Name = "Picture",
		Position = UDim2.fromOffset(8, 26),
		Size = UDim2.new(1, -16, 1, -72),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, root)
	local rate = Shop.text(root, {
		Name = "Rate",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -40),
		Size = UDim2.new(1, -10, 0, 24),
		TextSize = 24,
		TextColor3 = Shop.Money,
		Text = props.Rate or "",
		ZIndex = 4,
	})
	local strip: Frame = Kit.new("Frame", {
		Name = "PriceStrip",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -5),
		Size = UDim2.new(1, -10, 0, 32),
		BackgroundColor3 = Shop.BodyDeep,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, root)
	Kit.corner(strip, 4)
	Kit.stroke(strip, 2, Shop.Edge)
	local price = Shop.money(strip, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 22,
		Colour = Kit.White,
		Align = Enum.HorizontalAlignment.Center,
		Text = props.Price or "",
		ZIndex = 4,
	})
	return { Root = root, Name = name, Picture = pic, Rate = rate, Price = price }
end

-- A fat white arrow: the atlas' arrow turned to its way (0 right, 90 down, 180 left), or, before the upload in a live
-- game, one drawn of two frames (a turned square for the head, a bar for the tail)
function Shop.arrow(parent: Instance, turn: number, size: number, at: UDim2, z: number): GuiObject
	if picture("Icons") ~= "" then
		return Shop.icon(parent, "Arrow", size, {
			Name = "Arrow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = at,
			Rotation = turn,
			ZIndex = z,
		})
	end
	local holder: Frame = Kit.new("Frame", {
		Name = "Arrow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = at,
		Size = UDim2.fromOffset(size, size),
		Rotation = turn,
		BackgroundTransparency = 1,
		ZIndex = z,
	}, parent)
	local head: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.62, 0.5),
		Size = UDim2.fromScale(0.42, 0.42),
		Rotation = 45,
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		ZIndex = z,
	}, holder)
	Kit.stroke(head, 2.5, Shop.Edge)
	local tail: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.36, 0.5),
		Size = UDim2.fromScale(0.36, 0.26),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		ZIndex = z + 1,
	}, holder)
	Kit.stroke(tail, 2.5, Shop.Edge)
	return holder
end

-- A sort button: a down arrow and a word, green when on, grey when off. Returns the button; set its kind to switch.
function Shop.sort(parent: Instance, props: { [string]: any }): Button
	props.Kind = if props.On then "Cash" else "Off"
	props.TextSize = props.TextSize or 22
	local b = Shop.button(parent, props)
	Shop.arrow(b.Root, 90, 30, UDim2.new(0, 24, 0.5, 0), 4)
	return b
end

export type Carousel = {
	Root: Frame,
	List: ScrollingFrame,
	Left: Button,
	Right: Button,
	step: (by: number) -> (),
	show: (index: number) -> (), -- scroll so that card index (1-based, in layout order) is in view
}

-- A sideways row of cards with a big arrow button at either side. props: Position, Size, CardWide, Gap, Kind (the
-- arrows' colour: "Lavender"). Cards go in List (a UIListLayout is there); arrows scroll by a card.
function Shop.carousel(parent: Instance, props: { [string]: any }): Carousel
	local cardWide: number = props.CardWide or 196
	local gap: number = props.Gap or 12
	local root: Frame = Kit.new("Frame", {
		Name = "Carousel",
		Position = props.Position or UDim2.new(),
		Size = props.Size or UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, parent)
	local arrowWide = 50
	local list: ScrollingFrame = Kit.new("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(arrowWide * 0.5, 0),
		Size = UDim2.new(1, -arrowWide, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Color3.fromRGB(150, 160, 220),
		ScrollBarImageTransparency = 0.2,
		HorizontalScrollBarInset = Enum.ScrollBarInset.None,
		ElasticBehavior = Enum.ElasticBehavior.Always,
		ZIndex = 2,
	}, root)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	}, list)
	Kit.new("UIPadding", {
		PaddingLeft = UDim.new(0, arrowWide * 0.5 + 6),
		PaddingRight = UDim.new(0, arrowWide * 0.5 + 6),
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 12),
	}, list)
	local function arrow(side: number): Button
		local b = Shop.button(root, {
			Name = if side < 0 then "Left" else "Right",
			Kind = props.Kind or "Lavender",
			Text = "",
			AnchorPoint = Vector2.new(if side < 0 then 0 else 1, 0.5),
			Position = UDim2.fromScale(if side < 0 then 0 else 1, 0.45),
			Size = UDim2.fromOffset(arrowWide, 64),
		})
		b.Root.ZIndex = 6
		Shop.arrow(b.Root, if side < 0 then 180 else 0, 40, UDim2.fromScale(0.5, 0.5), 7)
		return b
	end
	local left = arrow(-1)
	local right = arrow(1)
	local self: Carousel = {
		Root = root,
		List = list,
		Left = left,
		Right = right,
		step = nil :: any,
		show = nil :: any,
	}
	local function goTo(x: number)
		local most = math.max(0, list.AbsoluteCanvasSize.X - list.AbsoluteWindowSize.X)
		local target = math.clamp(x, 0, most)
		TweenService:Create(list, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CanvasPosition = Vector2.new(target, 0),
		}):Play()
	end
	-- (the canvas is in screen pixels: a card's step is its points times the window's scale)
	local function px(): number
		local s = 1
		local holder: Instance? = list
		while holder do
			local sc = holder:FindFirstChildOfClass("UIScale")
			if sc then
				s *= sc.Scale
			end
			holder = holder.Parent
		end
		return (cardWide + gap) * s
	end
	function self.step(by: number)
		goTo(list.CanvasPosition.X + by * px())
	end
	function self.show(index: number)
		goTo((index - 1) * px() - (list.AbsoluteWindowSize.X - px()) * 0.5)
	end
	left.Root.Activated:Connect(function()
		self.step(-1)
	end)
	right.Root.Activated:Connect(function()
		self.step(1)
	end)
	return self
end

return Shop
