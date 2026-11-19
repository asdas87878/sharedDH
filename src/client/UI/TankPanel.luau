--!strict
-- The tank's popup (Hugo, 2026-11-19: "Making placing in the fishtank easier, you should be able to click on the plot
-- from nearby, then get a little popup where you can equip the best fish instantly, unequip certain fishes and see how
-- much money they produce and their rarities and special traits (like gold or colossal)").
--   Opening it: a click (or a tap) on one's own tank, from no further than the plot's "PanelReach" studs (written by
--   AquariumService, so both sides use one number). Near enough, the tank's glass is outlined under the mouse and a
--   small sign over the tank says to click or tap it. It closes with its X, a second click on the tank, walking away or
--   leaving the dock.
--   What it shows: every fish in the tank, the equipped ones (which earn and swim there, at most "TankEarning") and the
--   stored ones, and what one carries; each as a card with its picture (UI.Portrait: the partner's renders), name,
--   rarity, size (Tiny to Colossal), colour (Silver, Gold, Rainbow), archetype icons and coins a second. The coins are
--   Config.incomeOf, the one function the server pays by too, so the economy draft's numbers show here as they land.
--   What it asks (the server decides, AquariumService: Action "Tank", verb, ...): EQUIP BEST, EQUIP and UNEQUIP on a
--   card, PUT IN on a carried fish and PUT ALL IN. Refusals come back as Ride "TankDenied", reason.
--   The look: the UI kit's plates (Kit.panel, Kit.dress, Kit.text), the Navy theme, a card's edge in its rarity's
--   colour. Phones get bigger points and fewer columns (Kit.touch).
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Archetypes = require(ReplicatedStorage.Shared.Archetypes)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.Lib.State)
local Kit = require(script.Parent.Kit)
local Portrait = require(script.Parent.Portrait)

local TankPanel = {}

-- sizes in the panel's own points (a UIScale fits them to the screen)
local PANEL_W, PANEL_H = 664, 470
local CARD_W, CARD_H = 142, 196
local GAP = 8
local HEAD = 56 -- the title row
local BAR = 46 -- the row of EQUIP BEST and PUT ALL IN
local CLICK_MOVE = 12 -- a press that moves further than this (pixels) is a camera drag, not a click
local CLICK_TIME = 0.45

local SIZE_HUE = { -- as the fish tags' size words (UI.Tags), cool to hot
	Tiny = Color3.fromRGB(150, 178, 204),
	Normal = Color3.fromRGB(176, 192, 214),
	Big = Color3.fromRGB(84, 226, 190),
	Giant = Color3.fromRGB(80, 182, 255),
	Huge = Color3.fromRGB(255, 160, 48),
	Colossal = Color3.fromRGB(255, 72, 80),
}
local VARIANT_LOOK = {
	Silver = { Top = Color3.fromRGB(226, 234, 244), Bottom = Color3.fromRGB(120, 136, 160), Word = "SILVER" },
	Gold = { Top = Color3.fromRGB(255, 232, 110), Bottom = Color3.fromRGB(226, 140, 16), Word = "GOLD" },
	Rainbow = { Top = Color3.new(1, 1, 1), Bottom = Color3.new(1, 1, 1), Word = "RAINBOW" },
}
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 140)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 200, 110)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(240, 250, 130)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(130, 240, 170)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(120, 190, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 140, 255)),
})
local PICTURE_BACK = { Top = Color3.fromRGB(56, 120, 196), Bottom = Color3.fromRGB(20, 52, 104) }

type Fish = { Key: string, Id: string, Size: string, Variant: string, On: boolean, Hand: number? }
type Card = {
	Frame: Frame,
	Picture: Portrait.Portrait,
	Back: UIGradient,
	Edge: UIStroke,
	Name: TextLabel,
	Rarity: TextLabel,
	SizeWord: TextLabel,
	VariantChip: Frame,
	VariantWord: TextLabel,
	VariantFill: UIGradient,
	Icons: Frame,
	Coins: TextLabel,
	Button: TextButton,
	ButtonLook: Kit.Dressed,
	ButtonWord: TextLabel,
	Fish: Fish,
}

local gui: ScreenGui
local root: Frame
local scale: UIScale
local panel: Kit.Panel
local list: ScrollingFrame
local titleIncome: TextLabel
local bestButton: TextButton
local bestLook: Kit.Dressed
local bestWord: TextLabel
local allButton: TextButton
local allWord: TextLabel
local toast: TextLabel
local toastAt = -math.huge
local sections: { [string]: { Head: TextLabel, Grid: Frame, Layout: UIGridLayout } } = {}
local cards: { [string]: Card } = {}
local open = false
local touch = false

local hint: BillboardGui? = nil
local farAt = -math.huge -- when a click on the tank came from too far away
local outline: Highlight? = nil

local function attr(name: string, default: any): any
	local value = State.Player:GetAttribute(name)
	return if value == nil then default else value
end

local function decode(name: string): { any }
	local ok, rows = pcall(function()
		return HttpService:JSONDecode(attr(name, "[]"))
	end)
	return if ok and type(rows) == "table" then rows else {}
end

-- What a fish earns a second: the server's own function (AquariumService pays by it too)
local function incomeOf(f: Fish): number
	local kind = Config.FishById[f.Id]
	return if kind then Config.incomeOf(kind, f.Size, f.Variant) else 0
end

local function tankRows(): { Fish }
	local out: { Fish } = {}
	for _, row in decode("TankList") do
		if type(row) == "table" and type(row[1]) == "string" and type(row[2]) == "string" then
			table.insert(out, {
				Key = row[1],
				Id = row[2],
				Size = tostring(row[3] or "Normal"),
				Variant = tostring(row[4] or ""),
				On = row[5] == 1,
			})
		end
	end
	return out
end

local function handRows(): { Fish }
	local out: { Fish } = {}
	for i, row in decode("Hands") do
		if type(row) == "table" and type(row[1]) == "string" then
			table.insert(out, {
				Key = "H" .. i .. "|" .. row[1],
				Id = row[1],
				Size = tostring(row[2] or "Normal"),
				Variant = tostring(row[3] or ""),
				On = false,
				Hand = i,
			})
		end
	end
	return out
end

-- Our own plot, and its tank's water (nil: no tank, or not streamed in)
local function ownPlot(): (Model?, BasePart?)
	local name = State.Player:GetAttribute("Plot")
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local dock = blockout and blockout:FindFirstChild("Dock")
	local plots = dock and dock:FindFirstChild("Plots")
	local plot = plots and type(name) == "string" and plots:FindFirstChild(name)
	if not plot or not plot:IsA("Model") then
		return nil, nil
	end
	local water = plot:FindFirstChild("TankWater")
	return plot, if water and water:IsA("BasePart") then water else nil
end

-- How far we stand from our tank's water, across the floor (math.huge with no tank), and the reach it opens from
local function distance(): (number, number)
	local plot, water = ownPlot()
	local _, root = State.character()
	if not plot or not water or not root then
		return math.huge, 0
	end
	local offset = water.CFrame:PointToObjectSpace(root.Position)
	local half = water.Size / 2
	local dx = math.max(math.abs(offset.X) - half.X, 0)
	local dz = math.max(math.abs(offset.Z) - half.Z, 0)
	local reach = plot:GetAttribute("PanelReach")
	return math.sqrt(dx * dx + dz * dz), if type(reach) == "number" then reach else 36
end

-- The parts of our plot a click opens the popup from: the tank, its sign and the fish in it; not the floor pads or
-- the trainer
local SKIP = { Pad = true, CollectPad = true, CollectRim = true, TrainerSpot = true, TrainerBase = true }
local clickParts: { Instance } = {}
local clickPlot: Model? = nil
local clickAt = -math.huge
local function partsOf(plot: Model): { Instance }
	if plot == clickPlot and os.clock() - clickAt < 3 then
		return clickParts
	end
	clickPlot, clickAt = plot, os.clock()
	clickParts = {}
	local ride = plot:FindFirstChild("TrainerRide")
	for _, d in plot:GetDescendants() do
		if
			d:IsA("BasePart")
			and not SKIP[d.Name]
			and not string.find(d.Name, "^Trainer")
			and not string.find(d.Name, "^Spring")
			and not (ride and d:IsDescendantOf(ride))
		then
			table.insert(clickParts, d)
		end
	end
	return clickParts
end

-- Whether a point on the screen is over our tank: an input's Position (under the top bar's inset), or with `whole`
-- a point on the whole viewport (UserInputService:GetMouseLocation)
local function overTank(x: number, y: number, whole: boolean?): boolean
	local plot = ownPlot()
	local camera = workspace.CurrentCamera
	if not plot or not camera then
		return false
	end
	local ray = if whole then camera:ViewportPointToRay(x, y) else camera:ScreenPointToRay(x, y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = partsOf(plot)
	return workspace:Raycast(ray.Origin, ray.Direction * 600, params) ~= nil
end

local function say(text: string)
	toast.Text = text
	toastAt = os.clock()
end

local function button(parent: Instance, theme: string, word: string, size: number): (TextButton, Kit.Dressed, TextLabel)
	local b: TextButton = Kit.new("TextButton", { Text = "", AutoButtonColor = false }, parent)
	local look = Kit.dress(b, Kit.Themes[theme])
	local label = Kit.text({
		Size = UDim2.fromScale(1, 1),
		Text = word,
		TextSize = size,
		ZIndex = 3,
	}, b)
	b.MouseEnter:Connect(function()
		b.BackgroundTransparency = 0.15
	end)
	b.MouseLeave:Connect(function()
		b.BackgroundTransparency = 0
	end)
	return b, look, label
end

local function paint(look: Kit.Dressed, theme: string)
	local style = Kit.Themes[theme]
	look.paint(style.Top, style.Bottom)
end

local function newCard(f: Fish): Card
	local frame: Frame = Kit.new("Frame", {
		Name = "Card",
		BackgroundColor3 = Kit.Navy,
		BorderSizePixel = 0,
	}, nil)
	Kit.corner(frame, Kit.Radius.Plate)
	Kit.gradient(frame, Color3.fromRGB(40, 78, 132), Color3.fromRGB(16, 34, 62))
	local edge = Kit.stroke(frame, Kit.Outline.Bold, Kit.Ink)
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	-- the picture, on a backdrop that turns gold or rainbow with the fish
	local back: Frame = Kit.new("Frame", {
		Name = "Back",
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 0, 84),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
	}, frame)
	Kit.corner(back, Kit.Radius.Tile)
	local backFill = Kit.gradient(back, PICTURE_BACK.Top, PICTURE_BACK.Bottom)
	local picture = Portrait.new(back, {
		Position = UDim2.fromOffset(2, 4),
		Size = UDim2.new(1, -4, 1, -8),
		ZIndex = 2,
	})
	local sizeWord = Kit.text({
		Name = "Size",
		Position = UDim2.fromOffset(5, 2),
		Size = UDim2.new(0.6, 0, 0, 16),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.GothamBlack,
		ZIndex = 4,
	}, back, 1.6)
	local chip: Frame = Kit.new("Frame", {
		Name = "Variant",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -3, 0, 3),
		Size = UDim2.fromOffset(58, 16),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, back)
	Kit.corner(chip, 999)
	Kit.stroke(chip, Kit.Outline.Thin, Kit.Ink).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local chipFill = Kit.new("UIGradient", {}, chip)
	local chipWord = Kit.text({
		Size = UDim2.fromScale(1, 1),
		TextSize = 11,
		Font = Enum.Font.GothamBlack,
		ZIndex = 5,
	}, chip, 1.4)
	local icons: Frame = Kit.new("Frame", {
		Name = "Icons",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 4, 1, -3),
		Size = UDim2.new(1, -8, 0, 18),
		BackgroundTransparency = 1,
		ZIndex = 4,
	}, back)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
	}, icons)

	local name = Kit.text({
		Name = "FishName",
		Position = UDim2.fromOffset(6, 92),
		Size = UDim2.new(1, -12, 0, 20),
		TextSize = 16,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, frame)
	local rarity = Kit.text({
		Name = "Rarity",
		Position = UDim2.fromOffset(6, 112),
		Size = UDim2.new(1, -12, 0, 16),
		TextSize = 13,
		Font = Enum.Font.GothamBlack,
	}, frame, 1.6)
	local coins = Kit.text({
		Name = "Coins",
		Position = UDim2.fromOffset(6, 130),
		Size = UDim2.new(1, -12, 0, 22),
		TextSize = 19,
		TextColor3 = Kit.Cash,
	}, frame)
	local b, look, word = button(frame, "Good", "EQUIP", 15)
	b.Position = UDim2.new(0, 8, 1, -38)
	b.Size = UDim2.new(1, -16, 0, 30)

	local card: Card = {
		Frame = frame,
		Picture = picture,
		Back = backFill,
		Edge = edge,
		Name = name,
		Rarity = rarity,
		SizeWord = sizeWord,
		VariantChip = chip,
		VariantWord = chipWord,
		VariantFill = chipFill,
		Icons = icons,
		Coins = coins,
		Button = b,
		ButtonLook = look,
		ButtonWord = word,
		Fish = f,
	}
	b.Activated:Connect(function()
		local now = card.Fish
		if now.Hand then
			Net.Action:FireServer("Tank", "PutIn", now.Hand, now.Id)
		elseif now.On then
			Net.Action:FireServer("Tank", "Unequip", now.Key)
		else
			Net.Action:FireServer("Tank", "Equip", now.Key)
		end
	end)
	return card
end

local function fill(card: Card, f: Fish, full: boolean)
	card.Fish = f
	local kind = Config.FishById[f.Id]
	card.Picture.show(f.Id)
	card.Name.Text = string.upper(if kind then kind.Name else f.Id)
	local tier = if kind then kind.Tier else "Common"
	local entry = Config.Tiers[tier]
	local colour = if entry then entry.Colour else Kit.White
	-- (the Secret's own colour is near black: on a dark card it is drawn white, edged in pink)
	local dark = colour.R + colour.G + colour.B < 0.6
	card.Rarity.Text = string.upper(tier)
	card.Rarity.TextColor3 = if dark then Kit.White else colour
	card.Edge.Color = if dark then Kit.Pink else colour
	card.Edge.Thickness = if f.On then Kit.Outline.Heavy else Kit.Outline.Bold
	card.SizeWord.Text = string.upper(f.Size)
	card.SizeWord.TextColor3 = SIZE_HUE[f.Size] or Kit.White
	local look = VARIANT_LOOK[f.Variant]
	card.VariantChip.Visible = look ~= nil
	if look then
		card.VariantWord.Text = look.Word
		card.VariantFill.Rotation = if f.Variant == "Rainbow" then 0 else 90
		card.VariantFill.Color = if f.Variant == "Rainbow" then RAINBOW else ColorSequence.new(look.Top, look.Bottom)
		card.Back.Rotation = if f.Variant == "Rainbow" then 20 else 90
		card.Back.Color = if f.Variant == "Rainbow"
			then RAINBOW
			else ColorSequence.new(Kit.lighter(look.Top, 0.2), look.Bottom)
	else
		card.Back.Rotation = 90
		card.Back.Color = ColorSequence.new(PICTURE_BACK.Top, PICTURE_BACK.Bottom)
	end
	Archetypes.icons(card.Icons, if kind then Archetypes.line(kind) else "", 18)
	card.Coins.Text = "$" .. Config.shortNumber(incomeOf(f)) .. "/s"
	if f.Hand then
		card.ButtonWord.Text = "PUT IN"
		paint(card.ButtonLook, "Grab")
	elseif f.On then
		card.ButtonWord.Text = "UNEQUIP"
		paint(card.ButtonLook, "Off")
	else
		card.ButtonWord.Text = "EQUIP"
		paint(card.ButtonLook, if full then "Navy" else "Good")
	end
end

local function section(name: string, order: number)
	local head = Kit.text({
		Name = name .. "Head",
		Size = UDim2.new(1, -8, 0, 24),
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
	}, list)
	local grid: Frame = Kit.new("Frame", {
		Name = name,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = order + 1,
	}, list)
	local layout = Kit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(CARD_W, CARD_H),
		CellPadding = UDim2.fromOffset(GAP, GAP),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	sections[name] = { Head = head, Grid = grid, Layout = layout }
end

local function refresh()
	if not open then
		return
	end
	local fish = tankRows()
	local hands = handRows()
	local most = attr("TankEarning", Config.Aquarium.Earning)
	local equipped, stored = {}, {}
	local income = 0
	for _, f in fish do
		if f.On then
			table.insert(equipped, f)
			income += incomeOf(f)
		else
			table.insert(stored, f)
		end
	end
	local byIncome = function(a: Fish, b: Fish): boolean
		local x, y = incomeOf(a), incomeOf(b)
		return if x ~= y then x > y else a.Key < b.Key
	end
	table.sort(equipped, byIncome)
	table.sort(stored, byIncome)
	local full = #equipped >= most
	titleIncome.Text = "$" .. Config.shortNumber(income) .. "/s"

	-- EQUIP BEST is bright while it would change something: a free place and a stored fish, or a stored fish that
	-- earns more than the poorest equipped one
	local better = #stored > 0 and (not full or (#equipped > 0 and incomeOf(stored[1]) > incomeOf(equipped[#equipped])))
	paint(bestLook, if better then "Gold" else "Off")
	bestWord.Text = if better then "EQUIP BEST" else "BEST EQUIPPED"
	allButton.Visible = #hands > 0
	allWord.Text = "PUT ALL IN (" .. #hands .. ")"

	local seen: { [string]: boolean } = {}
	local function lay(rows: { Fish }, where: string)
		for i, f in rows do
			local key = if f.Hand then f.Key else "T" .. f.Key
			seen[key] = true
			local card = cards[key]
			if not card then
				card = newCard(f)
				cards[key] = card
			end
			card.Frame.LayoutOrder = i
			card.Frame.Parent = sections[where].Grid
			fill(card, f, full)
		end
	end
	lay(hands, "Hands")
	lay(equipped, "Earning")
	lay(stored, "Stored")
	for key, card in cards do
		if not seen[key] then
			card.Frame:Destroy()
			cards[key] = nil
		end
	end
	sections.Hands.Head.Visible = #hands > 0
	sections.Hands.Grid.Visible = #hands > 0
	sections.Hands.Head.Text = "IN YOUR HANDS  " .. #hands
	sections.Earning.Head.Text = "EARNING  " .. #equipped .. "/" .. most
	sections.Stored.Head.Text = "STORED  " .. #stored
	sections.Stored.Head.Visible = true
	if #fish == 0 and #hands == 0 then
		sections.Earning.Head.Text = "NO FISH YET: CATCH SOME AND PUT THEM IN!"
	end
end

-- The panel's size and its points for this screen; the columns follow the width
local function layout()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local view = camera.ViewportSize
	touch = Kit.touch()
	-- (Studio's phone still: the workspace's "PanelPhone", a phone's screen in pixels, lays the popup out for that
	-- screen in a box of its size in the middle of this one)
	local phone = if RunService:IsStudio() then workspace:GetAttribute("PanelPhone") else nil
	if typeof(phone) == "Vector2" then
		view = phone
		touch = true
	end
	-- a phone: bigger points, the panel near the whole screen
	local s = math.clamp(view.Y / (if touch then 470 else 700), 0.6, 1.8)
	scale.Scale = s
	root.Size = UDim2.fromScale(1 / s, 1 / s)
	if typeof(phone) == "Vector2" then
		root.Size = UDim2.fromOffset(view.X / s, view.Y / s)
	end
	local w = math.min(PANEL_W, view.X / s - 20)
	local h = math.min(PANEL_H, view.Y / s - 16)
	panel.Frame.Size = UDim2.fromOffset(w, h)
	local columns = math.max(2, math.floor((w - 28 + GAP) / (CARD_W + GAP)))
	list.Size = UDim2.new(1, -20, 1, -(HEAD + BAR + 22))
	-- the cards centred in what the columns leave
	for _, s2 in sections do
		s2.Layout.FillDirectionMaxCells = columns
		s2.Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	end
end

local function show(on: boolean)
	open = on and State.Mode == "Dock"
	panel.Frame.Visible = open
	if open then
		layout()
		refresh()
	end
end

-- Studio's tests: open or close the popup as a click on the tank does
function TankPanel.toggle(on: boolean)
	show(on)
end

function TankPanel.isOpen(): boolean
	return open
end

local function build()
	gui = Kit.new("ScreenGui", {
		Name = "TankPanel",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 8,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, State.Player:WaitForChild("PlayerGui"))
	root = Kit.new("Frame", {
		Name = "Root",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, gui)
	scale = Kit.new("UIScale", {}, root)
	-- (the root is the screen in points: its size is the screen over the scale)
	-- (the root is the screen in points: its size is the screen over the scale; layout sets it)
	panel = Kit.panel(root, {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(PANEL_W, PANEL_H),
		Visible = false,
	}, Kit.Themes.Navy)
	local face = panel.Face

	local title = Kit.text({
		Name = "Title",
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(0.5, -16, 0, 40),
		Text = "YOUR TANK",
		TextSize = 32,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	}, face)
	title.Font = Enum.Font.LuckiestGuy
	titleIncome = Kit.text({
		Name = "Income",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -66, 0, 10),
		Size = UDim2.new(0.5, -70, 0, 38),
		TextSize = 30,
		TextColor3 = Kit.Cash,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
	}, face)
	local close, _, _ = button(face, "Danger", "X", 24)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 9)
	close.Size = UDim2.fromOffset(44, 40)
	close.Activated:Connect(function()
		show(false)
	end)

	local word: TextLabel
	bestButton, bestLook, word = button(face, "Gold", "EQUIP BEST", 20)
	bestWord = word
	bestButton.Position = UDim2.fromOffset(12, HEAD)
	bestButton.Size = UDim2.new(0.5, -18, 0, BAR - 6)
	bestButton.Activated:Connect(function()
		Net.Action:FireServer("Tank", "Best")
	end)
	local allLook
	allButton, allLook, allWord = button(face, "Grab", "PUT ALL IN", 20)
	allLook.paint(Kit.Themes.Grab.Top, Kit.Themes.Grab.Bottom)
	allButton.AnchorPoint = Vector2.new(1, 0)
	allButton.Position = UDim2.new(1, -12, 0, HEAD)
	allButton.Size = UDim2.new(0.5, -18, 0, BAR - 6)
	allButton.Activated:Connect(function()
		Net.Action:FireServer("Tank", "PutAll")
	end)

	list = Kit.new("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(10, HEAD + BAR + 6),
		Size = UDim2.new(1, -20, 1, -(HEAD + BAR + 22)),
		BackgroundColor3 = Kit.Deep,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Kit.Aqua,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 2,
	}, face)
	Kit.corner(list, Kit.Radius.Tile)
	Kit.new("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}, list)
	Kit.new("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 12),
	}, list)
	section("Hands", 1)
	section("Earning", 3)
	section("Stored", 5)

	toast = Kit.text({
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(1, -40, 0, 30),
		TextSize = 22,
		TextColor3 = Kit.Sun,
		Visible = false,
		ZIndex = 6,
	}, face)
end

-- The sign over our tank while we are near it with the popup shut, and the glass outlined under the mouse
local function keepHint(near: boolean, hovered: boolean)
	local _, water = ownPlot()
	if not water then
		return
	end
	if not hint or hint.Adornee ~= water then
		if hint then
			hint:Destroy()
		end
		local b: BillboardGui = Kit.new("BillboardGui", {
			Name = "TankHint",
			Adornee = water,
			AlwaysOnTop = true,
			LightInfluence = 0,
			Size = UDim2.fromOffset(260, 40),
			StudsOffsetWorldSpace = Vector3.new(0, water.Size.Y / 2 + 9, 0),
			MaxDistance = 200,
		}, gui)
		local plate: Frame = Kit.new("Frame", { Size = UDim2.fromScale(1, 1) }, b)
		Kit.dress(plate, Kit.Themes.Navy)
		Kit.text({ Name = "Word", Size = UDim2.fromScale(1, 1), TextSize = 20, ZIndex = 3 }, plate)
		hint = b
	end
	local h = hint :: BillboardGui
	local far = os.clock() - farAt < 2
	h.Enabled = (near or far) and not open
	local w = h:FindFirstChild("Word", true)
	if w and w:IsA("TextLabel") then
		w.Text = if near then (if touch then "TAP YOUR TANK" else "CLICK YOUR TANK") else "WALK CLOSER!"
	end
	if not outline or outline.Adornee ~= water then
		if outline then
			outline:Destroy()
		end
		outline = Kit.new("Highlight", {
			Name = "TankHover",
			Adornee = water,
			FillTransparency = 1,
			OutlineColor = Kit.Sun,
			DepthMode = Enum.HighlightDepthMode.Occluded,
		}, gui)
	end
	(outline :: Highlight).Enabled = hovered and near and not open
end

-- A press on the world (not on a button): a click if it neither moved far nor lasted long
local function watchClicks()
	local downAt: { [InputObject]: { at: Vector3, t: number } } = {}
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			downAt[input] = { at = input.Position, t = os.clock() }
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject, processed: boolean)
		local start = downAt[input]
		downAt[input] = nil
		if not start or processed or State.Mode ~= "Dock" then
			return
		end
		if (input.Position - start.at).Magnitude > CLICK_MOVE or os.clock() - start.t > CLICK_TIME then
			return
		end
		TankPanel.click(input.Position.X, input.Position.Y)
	end)
end

-- A click or tap at a point on the screen (an input's Position): on our tank and near enough, the popup opens (or
-- shuts); too far, the sign over the tank says to come closer. Studio's tests call it too. True when it was on the tank
function TankPanel.click(x: number, y: number): boolean
	if State.Mode ~= "Dock" or not overTank(x, y) then
		return false
	end
	local gap, reach = distance()
	if gap <= reach then
		show(not open)
	elseif not open then
		farAt = os.clock() -- (the sign over the tank says to come closer)
	end
	return true
end

function TankPanel.init()
	if Config.Aquarium.On == 0 then
		return
	end
	build()
	watchClicks()
	for _, name in { "TankList", "Hands", "TankEarning" } do
		State.Player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	Net.Ride.OnClientEvent:Connect(function(kind: string, reason: any)
		if kind == "TankDenied" then
			say(
				if reason == "Full"
					then "THE TANK IS FULL: UNEQUIP ONE FIRST"
					elseif reason == "Far" then "TOO FAR FROM YOUR TANK"
					else "THAT FISH IS GONE"
			)
		end
	end)
	State.ModeChanged.Event:Connect(function(mode: string)
		if mode ~= "Dock" then
			show(false)
		end
	end)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
	end
	UserInputService.LastInputTypeChanged:Connect(function()
		if Kit.touch() ~= touch then
			layout()
		end
	end)
	layout()
	local lastLook = 0
	local near, hovered = false, false
	RunService.RenderStepped:Connect(function()
		toast.Visible = os.clock() - toastAt < 2.2
		if os.clock() - lastLook < 0.1 then
			return
		end
		lastLook = os.clock()
		if State.Mode ~= "Dock" then
			near, hovered = false, false
		else
			local gap, reach = distance()
			near = gap <= reach
			local mouse = UserInputService:GetMouseLocation()
			hovered = near and not touch and overTank(mouse.X, mouse.Y, true)
			-- walked away: it closes
			if open and gap > reach + 8 then
				show(false)
			end
		end
		keepHint(near, hovered)
	end)
end

return TankPanel
