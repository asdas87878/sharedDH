--!strict
-- The offline rewards' window (Hugo, 2026-11-25: "Add offline rewards and use image gen to get something similar to ref
-- image 1"; NULLROOM task o1; docs/design/offline-rewards.md): "Welcome back!", what the tank earned while its player was
-- away, and CLAIM. Laid out as the reference since 2026-11-25 (Hugo: "better layout and ui wise"; NULLROOM task o2): a
-- wide window, the chest and the title at the left of a shining header, the X at its right, a heading, a big chest left of
-- the middle in a dark body the dock shows through, the gold amount over its foot, and a row of wide buttons. The look is
-- the dock's own (UI.Shop's window, header, studs and button) with our own chest (art/ui/offline). The reference's second
-- button, Claim x3 for Robux (Hugo, 2026-11-25; Products.Triple), is there only once its product has an Id.
--   OfflinePanel.open(on)    opens or closes it, as Shop.go("Offline"): one dock window at a time
--   OfflinePanel.owed()      the coins waiting (the player's "OfflineOwed" attribute: OfflineService decides everything)
--   OfflinePanel.chip(on)    the small CLAIM beside the dock's buttons, for as long as coins wait and the window is
--                            closed (the X keeps them). It sits by UI.HubButtons' own holder, on the same scale
--   OfflinePanel.claiming(on), OfflinePanel.say(text)   a claim is on its way; a line in place of the hours (a refusal)
--   OfflinePanel.share(row)  the row's buttons side by side, equally wide, as many as there are in it
-- Controllers/OfflineController shows it, asks for the claim and answers.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Products = require(ReplicatedStorage.Shared.Products)
local State = require(script.Parent.Parent.Lib.State)
local Anim = require(script.Parent.Anim)
local Kit = require(script.Parent.Kit)
local Shop = require(script.Parent.Shop)

local OfflinePanel = {}

----------------------------------------------------------------------------------------------------------------------
-- Pictures, sizes and colours (the window's own points)

-- Upload id for the chest (2026-11-25, the user: "Yes, both"; empty: a live game shows the cash picture).
-- Studio reads it from its own content folder: python tools/offline/picture.py studio
OfflinePanel.Chest = "rbxassetid://90279043093713" -- art/ui/offline/chest.png
local STUDIO = "rbxasset://textures/ridefish/offline_chest_o1.png"

-- The window's two shapes. Wide is the reference's (1.6 to 1) on a computer, a tablet and a phone held sideways. Held
-- upright a phone is too narrow for it (at 375 its words would be half their size), so there the window is Narrow: the
-- same things in the same places, less wide, in bigger points (0.74 at 375).
type Lay = {
	Wide: number,
	High: number,
	Head: number, -- the header's height
	Icon: number, -- the chest in it
	Title: number, -- the title's letters
	Close: number, -- the X (44 px or more on every phone)
	Heading: number, -- "OFFLINE EARNINGS:", its letters
	Hours: number, -- the line under it, its letters
	Chest: number, -- the big chest
	Amount: number, -- the amount's letters (smaller when there are too many)
	Row: number, -- the buttons' height
	Claim: number, -- their letters
}
local LAYS: { [string]: Lay } = {
	Wide = {
		Wide = 760,
		High = 476,
		Head = 80,
		Icon = 72,
		Title = 40,
		Close = 68,
		Heading = 42,
		Hours = 20,
		Chest = 206,
		Amount = 68,
		Row = 72,
		Claim = 38,
	},
	Narrow = {
		Wide = 480,
		High = 396,
		Head = 68,
		Icon = 62,
		Title = 36,
		Close = 62,
		Heading = 34,
		Hours = 18,
		Chest = 160,
		Amount = 56,
		Row = 64,
		Claim = 34,
	},
}
local NARROW = 550 -- a screen less wide than this gets Narrow
local EDGE = 3 -- the window's dark edge inside its own rim: the header and the body sit this far in
local BAND = 8 -- the pale frame inside the body, down its sides and along its foot
local MARGIN = 12 -- from that frame to the words and buttons, the same at the sides and the foot
local GAP = 20 -- between two buttons (a multiple of 4: half of half of it is still a whole point)
local CLEAR = 0.14 -- how much of the dock shows through the body
-- Of the big chest's own size: where the amount starts (over the chest's right), and its line's height at the chest's foot
local OVER, FOOT = 0.76, 0.46
local LETTER = 0.6 -- a letter's width, of its size, at the most on average

local HEAD = Shop.Heads.Coral
local PALE = Color3.fromRGB(214, 222, 236) -- quiet words on the dark body (Sell Fish's)
local GOLD = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 246, 170)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 210, 63)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(246, 150, 26)),
})

local CHIP_WIDE, CHIP_HIGH = 147, 48 -- the hub buttons' own
local CHIP_GAP = 12
local CHIP_OVER = 24 -- over the Shop button: clear of its red "!"

local window: Shop.Window? = nil
local lay: Lay = LAYS.Wide
local hours: TextLabel
local group: Frame -- the big chest and the amount
local amount: TextLabel
local claim: Shop.Button
local triple: Shop.Button? = nil -- Claim x3 (none while it is not on sale)
local price = Products.Triple.Price -- (Roblox's own once it has answered)
local chip: Shop.Button? = nil
local chipAmount: TextLabel
local said = false -- the hours' line holds something else
local asking = false

local pressed = Instance.new("BindableEvent")
-- Fired as CLAIM is pressed
OfflinePanel.Pressed = pressed.Event

local pressedTriple = Instance.new("BindableEvent")
-- Fired as Claim x3 is pressed
OfflinePanel.Triple = pressedTriple.Event

local function chestPicture(): string
	if OfflinePanel.Chest ~= "" then
		return OfflinePanel.Chest
	end
	return if RunService:IsStudio() then STUDIO else Kit.Textures.Cash
end

local function number(name: string): number
	local value = State.Player:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

function OfflinePanel.owed(): number
	return if Config.Offline.On ~= 0 then number("OfflineOwed") else 0
end

-- So many seconds in words: "45 min", "8 h", "3 h 12 min"
function OfflinePanel.time(secs: number): string
	local minutes = math.max(math.floor(secs / 60), 1)
	local h, m = math.floor(minutes / 60), minutes % 60
	if h == 0 then
		return `{m} min`
	end
	return if m == 0 then `{h} h` else `{h} h {m} min`
end

local function picture(parent: Instance, size: number, props: { [string]: any }): ImageLabel
	props.Size = UDim2.fromOffset(size, size)
	props.BackgroundTransparency = 1
	props.Image = chestPicture()
	props.ScaleType = Enum.ScaleType.Fit
	return Kit.new("ImageLabel", props, parent)
end

----------------------------------------------------------------------------------------------------------------------
-- What it says now

local function paint()
	local owed = OfflinePanel.owed()
	if window then
		local words = Shop.cash(owed)
		amount.Text = words
		local room = lay.Wide - 2 * (EDGE + BAND + MARGIN) - lay.Chest * OVER
		amount.TextSize = math.min(lay.Amount, math.floor(room / (#words * LETTER)))
		if not said then
			hours.Text = `Your tank worked {OfflinePanel.time(number("OfflineSecs"))} without you`
		end
		claim.set(
			if asking then "..." else "Claim!",
			if asking or owed < 1 then "Off" else "Cash",
			not asking and owed >= 1
		)
		if triple then
			local ready = not asking and owed >= 1
			triple.set(`Claim x3  {price}`, if ready then "Robux" else "Off", ready)
		end
	end
	if chip then
		chipAmount.Text = Shop.cash(owed)
	end
end
OfflinePanel.paint = paint

----------------------------------------------------------------------------------------------------------------------
-- The window

-- The row's buttons side by side, equally wide, in their LayoutOrder: one takes it all, two take half each
function OfflinePanel.share(row: Instance)
	local all: { GuiObject } = {}
	for _, child in row:GetChildren() do
		if child:IsA("GuiObject") then
			table.insert(all, child)
		end
	end
	table.sort(all, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	local n = #all
	for i, button in all do
		local of = 2 * i - 1
		button.AnchorPoint = Vector2.new(0.5, 0.5) -- (a press dips about its middle)
		button.Position = UDim2.new(of / (2 * n), GAP * (of - n) / (2 * n), 0.5, 0)
		button.Size = UDim2.new(1 / n, -GAP * (n - 1) / n, 1, 0)
	end
end

local function child(of: Instance, name: string): any
	return of:FindFirstChild(name)
end

local function build()
	local w = Shop.window({
		Name = "OfflinePanel",
		Parent = State.Player:WaitForChild("PlayerGui"),
		Title = "Welcome back!",
		Head = HEAD,
		Gloss = true,
		Dim = true,
		Width = LAYS.Wide.Wide,
		Height = LAYS.Wide.High,
		OnClose = function()
			Shop.go(nil)
		end,
	})
	local body = w.Body
	-- the kit's frame, with the dock showing through it: no grey face and no shadow behind the body
	local face = child(w.Frame, "Face")
	local inner = child(face, "Inner")
	face.BackgroundTransparency = 1
	child(w.Frame, "Shadow").Visible = false
	inner.BackgroundTransparency = CLEAR
	for _, side in
		{
			{ Name = "BandLeft", At = UDim2.new(), Size = UDim2.new(0, BAND, 1, 0) },
			{ Name = "BandRight", At = UDim2.new(1, -BAND, 0, 0), Size = UDim2.new(0, BAND, 1, 0) },
			{ Name = "BandFoot", At = UDim2.new(0, BAND, 1, -BAND), Size = UDim2.new(1, -2 * BAND, 0, BAND) },
		}
	do
		Kit.new("Frame", {
			Name = side.Name,
			Position = side.At,
			Size = side.Size,
			BackgroundColor3 = Kit.White,
			BackgroundTransparency = 0.82,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, inner)
	end
	local icon = picture(w.Header, 0, { Name = "Chest", AnchorPoint = Vector2.new(0, 0.5), ZIndex = 4 })
	w.Title.AnchorPoint = Vector2.new(0, 0.5)
	w.Title.TextXAlignment = Enum.TextXAlignment.Left
	local heading = Shop.text(body, {
		Name = "Offline",
		TextSize = LAYS.Wide.Heading,
		Text = "OFFLINE EARNINGS:",
		ZIndex = 3,
	})
	hours = Shop.text(body, {
		Name = "Hours",
		TextSize = LAYS.Wide.Hours,
		TextColor3 = PALE,
		ZIndex = 3,
	})
	-- the chest and the amount, together in the middle: the amount starts over the chest's right side
	group = Kit.new("Frame", {
		Name = "Group",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, body)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, group)
	local slot = Kit.new("Frame", { Name = "Slot", BackgroundTransparency = 1, LayoutOrder = 1, ZIndex = 4 }, group)
	local chest = picture(slot, 0, { Name = "Chest", ZIndex = 4 })
	amount = Shop.text(group, {
		Name = "Amount",
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = LAYS.Wide.Amount,
		LayoutOrder = 2,
		ZIndex = 6,
	})
	Kit.new("UIGradient", { Rotation = 90, Color = GOLD }, amount)
	local row = Kit.new("Frame", {
		Name = "Row",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, body)
	claim = Shop.button(row, {
		Name = "Claim",
		Text = "Claim!",
		Kind = "Cash",
		TextSize = LAYS.Wide.Claim,
		LayoutOrder = 2, -- (the reference has Claim at the right of the two)
		Shine = true, -- (the window's one money button)
	})
	claim.Root.ZIndex = 3
	claim.Root.Activated:Connect(function()
		if claim.Live and not asking then
			pressed:Fire()
		end
	end)
	if Products.onSale(Products.Triple) then
		local b = Shop.button(row, {
			Name = "Triple",
			Text = "Claim x3",
			Kind = "Robux",
			Sign = "Robux",
			TextSize = LAYS.Wide.Claim,
			LayoutOrder = 1,
		})
		b.Root.ZIndex = 3
		b.Root.Activated:Connect(function()
			if b.Live and not asking then
				pressedTriple:Fire()
			end
		end)
		triple = b
	end
	OfflinePanel.share(row)

	-- puts everything where this shape has it
	local function place(l: Lay)
		lay = l
		local top = EDGE + l.Head + 2 * EDGE -- (the header's edge and the body's meet)
		local side = EDGE + BAND + MARGIN
		w.Frame.Size = UDim2.fromOffset(l.Wide, l.High)
		w.Header.Position = UDim2.fromOffset(EDGE, EDGE)
		w.Header.Size = UDim2.new(1, -2 * EDGE, 0, l.Head)
		inner.Position = UDim2.fromOffset(EDGE, top)
		inner.Size = UDim2.new(1, -2 * EDGE, 1, -(top + EDGE))
		body.Position = UDim2.fromOffset(side, top + 4)
		body.Size = UDim2.new(1, -2 * side, 1, -(top + 4 + side))
		icon.Position = UDim2.new(0, 10, 0.5, -3)
		icon.Size = UDim2.fromOffset(l.Icon, l.Icon)
		local left = 10 + l.Icon + 10
		w.Title.Position = UDim2.new(0, left, 0.5, -3)
		w.Title.Size = UDim2.new(1, -(left + l.Close + 14), 1, -8)
		w.Title.TextSize = l.Title
		w.Close.Root.Position = UDim2.new(1, -6, 0.5, 0)
		w.Close.Root.Size = UDim2.fromOffset(l.Close, l.Close)
		w.Close.Label.TextSize = math.floor(l.Close * 0.66)
		heading.Size = UDim2.new(1, 0, 0, l.Heading + 4)
		heading.TextSize = l.Heading
		hours.Position = UDim2.fromOffset(0, l.Heading + 4)
		hours.Size = UDim2.new(1, 0, 0, l.Hours + 6)
		hours.TextSize = l.Hours
		-- (the chest's own clear margin may run a little over the line above and the row below)
		local from = l.Heading + l.Hours + 10
		local room = l.High - (top + 4 + side) - from - l.Row
		group.Position = UDim2.new(0.5, 0, 0, from + room / 2)
		group.Size = UDim2.new(1, 0, 0, l.Chest)
		slot.Size = UDim2.fromOffset(l.Chest * OVER, l.Chest)
		chest.Size = UDim2.fromOffset(l.Chest, l.Chest)
		amount.Size = UDim2.fromOffset(0, l.Chest * FOOT)
		row.Size = UDim2.new(1, 0, 0, l.Row)
		claim.Label.TextSize = l.Claim
		if triple then
			-- (half the row holds the sign, the words and the price)
			local half = (l.Wide - 2 * side - GAP) / 2
			triple.Label.TextSize = math.min(l.Claim, math.floor(half / (14 * LETTER)))
		end
		paint()
	end
	-- the kit's fit knows one size: on a screen too narrow for it, the narrow shape at its own scale
	local kitFit = w.fit
	function w.fit()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		kitFit()
		local view = camera.ViewportSize
		local phone = if RunService:IsStudio() then workspace:GetAttribute("PanelPhone") else nil
		if typeof(phone) == "Vector2" then
			view = phone
		end
		local l = if view.X < NARROW then LAYS.Narrow else LAYS.Wide
		if l == LAYS.Narrow then
			local s = math.min(1.4, view.X / (l.Wide + 24), view.Y / (l.High + 16))
			local by = w.Scale.Scale / s
			local size = w.Root.Size
			w.Scale.Scale = s
			w.Root.Size = UDim2.new(size.X.Scale * by, size.X.Offset * by, size.Y.Scale * by, size.Y.Offset * by)
		end
		if l ~= lay then
			place(l)
		end
	end
	window = w
	place(LAYS.Wide)
end

function OfflinePanel.isOpen(): boolean
	return window ~= nil and window.isOpen()
end

-- (through Shop.go("Offline"), so another dock window closes)
function OfflinePanel.open(on: boolean)
	if not window then
		if not on then
			return
		end
		build()
	end
	if on then
		said = false
		paint()
	end
	(window :: Shop.Window).show(on)
	if on then
		Anim.punch(group, 1.12) -- (the two together: the amount alone would push the chest along)
	end
end

Shop.page("Offline", OfflinePanel.open)

-- A claim is on its way: CLAIM waits (the amount goes when the server says so)
function OfflinePanel.claiming(on: boolean)
	asking = on
	paint()
end

-- Roblox's own price for Claim x3, in place of ours
function OfflinePanel.price(robux: number)
	price = robux
	paint()
end

-- A line in place of the hours, until the window is opened again
function OfflinePanel.say(text: string)
	if window then
		said = true
		hours.Text = text
	end
end

----------------------------------------------------------------------------------------------------------------------
-- The small CLAIM by the dock's buttons

-- Over them on a computer; on a phone, where the rows sit right over them, beside the first
local function placeChip(root: GuiObject, buttons: GuiObject)
	local at = buttons.Position
	local fit = buttons:FindFirstChildOfClass("UIScale")
	local s = if fit then fit.Scale else 1
	local half = buttons.Size.Y.Offset * s / 2
	if Kit.touch() then
		root.AnchorPoint = Vector2.zero
		root.Position =
			UDim2.new(at.X.Scale, at.X.Offset + buttons.Size.X.Offset * s + CHIP_GAP, at.Y.Scale, at.Y.Offset - half)
	else
		root.AnchorPoint = Vector2.new(0, 1)
		root.Position = UDim2.new(at.X.Scale, at.X.Offset, at.Y.Scale, at.Y.Offset - half - CHIP_OVER)
	end
end

function OfflinePanel.chip(on: boolean)
	if not chip then
		local gui = State.Player:FindFirstChildOfClass("PlayerGui")
		local buttons = on and gui and gui:FindFirstChild("HubButtons", true)
		if not buttons or not buttons:IsA("GuiObject") then
			return
		end
		local b = Shop.button(buttons.Parent :: Instance, {
			Name = "OfflineClaim",
			Text = "",
			Kind = "Gold",
			Size = UDim2.fromOffset(CHIP_WIDE, CHIP_HIGH),
			Shine = true,
		})
		picture(b.Root, 50, {
			Name = "Chest",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 29, 0.5, -2),
			Rotation = -8,
			ZIndex = 4,
		})
		Shop.text(b.Root, {
			Name = "Claim",
			Position = UDim2.fromOffset(58, 4),
			Size = UDim2.new(1, -62, 0, 20),
			TextSize = 16,
			Text = "Claim",
			ZIndex = 4,
		})
		chipAmount = Shop.text(b.Root, {
			Name = "Amount",
			Position = UDim2.fromOffset(58, 22),
			Size = UDim2.new(1, -62, 0, 22),
			TextSize = 18,
			TextColor3 = Shop.Money,
			ZIndex = 4,
		})
		b.Root.Activated:Connect(function()
			Shop.go("Offline")
		end)
		chip = b
		paint()
	end
	local root = (chip :: Shop.Button).Root
	if on then
		local buttons = root.Parent and root.Parent:FindFirstChild("HubButtons")
		if buttons and buttons:IsA("GuiObject") then
			placeChip(root, buttons)
		end
	end
	if root.Visible ~= on then
		root.Visible = on
	end
end

return OfflinePanel
