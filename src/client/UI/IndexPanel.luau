--!strict
-- The Index (Hugo, 2026-11-23: "Import index system with the same ui consistent with the one my partner made";
-- NULLROOM task h2): every kind of fish, land by land, the ones you have caught in their rarity's colour and the
-- rest as dark shapes, with a reward to claim for each new kind and for each land's whole set. The hub's Index button
-- opens and closes it (UI.HubButtons, through Shop.go("Index"): one dock window at a time; leaving the dock closes
-- it). What it holds follows the reference's Index; how it looks is ours: the partner's Index design
-- (docs/attachments/ui7-panel-index.jpg: the orange header, a tab a land, cards in the rarity's colour, "???" on a dark
-- card with the rarity's colour on its edge, "n of N found", a bar toward the land's reward) built from the shop kit
-- (UI.Shop: the same window, header, wells, buttons, font and X as Sell Fish and the Shop).
--   Laid out: the ten lands as tabs across the top; under them the land's cards in a tray, five to a row; under the
--   tray the land's set (a bar, n / N, what the whole set pays and its claim); along the foot how many kinds are found
--   of all there are, and CLAIM ALL (n). At the right the chosen kind: its picture, name, rarity, what a Normal plain
--   one earns a second, how many of its looks (size and colour) you have caught, what its first catch pays and CLAIM.
--   Nothing here decides anything: what is found and what is claimed is the server's (IndexService, the Index remote:
--   Net.luau), sent whole after every change; a press only asks. The rewards shown are Config.indexFirst and
--   Config.indexLand, the same sums the server pays by (Config.Index: every number a DRAFT).
--   The pictures are UI.Portrait's (the partner's renders from UI.FishIcons, else the live model). A kind not found
--   yet is the same picture painted dark.
-- For the session only: the game has no saves yet.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.Lib.State)
local Anim = require(script.Parent.Anim)
local Kit = require(script.Parent.Kit)
local Portrait = require(script.Parent.Portrait)
local Shop = require(script.Parent.Shop)

local IndexPanel = {}

----------------------------------------------------------------------------------------------------------------------
-- Sizes and colours, in the window's own points

local WIDE, HIGH = 880, 500 -- (a little lower than Sell Fish's 540, so a phone's points come out bigger)
local GAP = 8
local TAB_HIGH = 46
local TAB_GAP = 6
local SIDE = 228 -- the chosen kind's column, at the right
local LAND_HIGH = 52 -- the land's set bar
local FOOT_HIGH = 46 -- the found bar and CLAIM ALL
local ALL_WIDE = 162 -- CLAIM ALL
local COLUMNS = 5
local CARD_W, CARD_H = 113, 108
local CARD_GAP = 6

local HEAD = Color3.fromRGB(240, 128, 30) -- the partner's orange header
local PALE = Color3.fromRGB(214, 222, 236) -- quiet words on the dark body (Sell Fish's)
local DARK_CARD = Color3.fromRGB(22, 36, 64) -- a kind not found yet: the partner's dark navy card
local SHADOW = Color3.fromRGB(8, 14, 30) -- and its picture, painted this dark
local TAB_OFF = { Color3.fromRGB(38, 56, 92), Color3.fromRGB(24, 38, 68) } -- a land's tab while another is shown
local TAB_WORD = Color3.fromRGB(150, 186, 240)
local GOLD = Shop.Kinds.Gold
local RED = { Color3.fromRGB(240, 78, 84), Color3.fromRGB(196, 32, 48) } -- the hub button's "!" disc

----------------------------------------------------------------------------------------------------------------------
-- The player's Index, as the server last sent it

local found: { [string]: number } = {} -- fish id -> how many of its looks they have caught
local claimedKinds: { [string]: boolean } = {} -- fish id -> its reward is paid
local claimedLands: { [string]: boolean } = {} -- the land as a string -> its set's reward is paid

type Land = { Kinds: { Config.FishType }, Set: { Config.FishType } }
local lands: { Land } = {}
local total = 0 -- every kind of the Index, all lands together

local function readRoster()
	table.clear(lands)
	for land = 1, Config.indexLands() do
		table.insert(lands, { Kinds = Config.indexKinds(land), Set = Config.indexSet(land) })
	end
	total = Config.indexCount()
end

local function owedKind(id: string): boolean
	return found[id] ~= nil and not claimedKinds[id]
end

-- How many kinds of a land's set are found, and how many it has
local function setOf(land: number): (number, number)
	local entry = lands[land]
	if not entry then
		return 0, 0
	end
	local have = 0
	for _, fish in entry.Set do
		if found[fish.Id] then
			have += 1
		end
	end
	return have, #entry.Set
end

local function owedLand(land: number): boolean
	local have, of = setOf(land)
	return of > 0 and have == of and not claimedLands[tostring(land)]
end

-- How many rewards wait in one land (its kinds' and its set's), and in all of them
local function owedIn(land: number): number
	local entry = lands[land]
	if not entry then
		return 0
	end
	local count = if owedLand(land) then 1 else 0
	for _, fish in entry.Kinds do
		if owedKind(fish.Id) then
			count += 1
		end
	end
	return count
end

local function owedAll(): number
	local count = 0
	for land = 1, #lands do
		count += owedIn(land)
	end
	return count
end

local function foundAll(): number
	local count = 0
	for _, entry in lands do
		for _, fish in entry.Kinds do
			if found[fish.Id] then
				count += 1
			end
		end
	end
	return count
end

----------------------------------------------------------------------------------------------------------------------
-- Words and small pieces

-- A land's name as the map has it ("Coral Reef"), else its short one
local function landName(land: number): string
	local zone = State.Zones[land]
	if zone and zone.Name ~= "" then
		local words: { string } = {}
		for word in string.gmatch(string.lower(zone.Name), "%S+") do
			table.insert(words, string.upper(string.sub(word, 1, 1)) .. string.sub(word, 2))
		end
		return table.concat(words, " ")
	end
	return Kit.LandShort[land] or ("Land " .. land)
end

-- Max Oxygen as a reward: whole while it fits (Config.wholeNumber), short past that
local function oxygenText(value: number): string
	return "+" .. (if value < 100000 then Config.wholeNumber(value) else Kit.short(value))
end

-- A card's fill in its rarity's colour: the top three rarities as the kit paints them (gold, ember, the rainbow), the
-- lower ones their colour running a little darker toward the foot (the partner's cards)
local function fillOf(tier: string): (ColorSequence, number)
	if tier == "Legendary" or tier == "Mythic" or tier == "Secret" then
		return Kit.tierFill(tier, Config.Tiers)
	end
	local entry = Config.Tiers[tier]
	local colour = if entry then entry.Colour else Kit.White
	return ColorSequence.new(Kit.darker(colour, 0.06), Kit.darker(colour, 0.3)), 90
end

local function tierColour(tier: string): Color3
	local entry = Config.Tiers[tier]
	return if entry then entry.Colour else Kit.White
end

-- Paints a Portrait's picture: SHADOW for a kind not found, white (its own colours) for one that is. A Portrait has
-- no such switch of its own, so this reaches into what it is made of: its colour layers are the pictures and windows
-- at ZIndex 2 straight under its frame (the black outline's are at 1).
local function tint(picture: Portrait.Portrait, colour: Color3)
	for _, child in picture.Frame:GetChildren() do
		if (child:IsA("ImageLabel") or child:IsA("ViewportFrame")) and child.ZIndex == 2 then
			(child :: any).ImageColor3 = colour
		end
	end
end

-- The small red "!" on a card, a tab or a button with a reward waiting (the hub button's mark, small and still)
local function mark(parent: Instance, at: UDim2, z: number): Frame
	local disc: Frame = Kit.new("Frame", {
		Name = "Waiting",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = at,
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = z,
	}, parent)
	Kit.corner(disc, 999)
	Kit.gradient(disc, RED[1], RED[2])
	Kit.stroke(disc, 2, Kit.White)
	local bang = Shop.text(disc, { Size = UDim2.fromScale(1, 1), TextSize = 13, Text = "!", ZIndex = z + 1 })
	bang.Rotation = 8
	return disc
end

-- A bar that fills: a dark track and a bright fill. Returns the track and how to set its share (0 to 1).
local function bar(parent: Instance, props: { [string]: any }, pair: { Color3 }): (Frame, (share: number) -> ())
	props.BackgroundColor3 = Shop.BodyDeep
	props.BorderSizePixel = 0
	local track: Frame = Kit.new("Frame", props, parent)
	Kit.corner(track, 999)
	Kit.stroke(track, 2, Shop.Edge)
	local fill: Frame = Kit.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = (props.ZIndex or 1) + 1,
	}, track)
	Kit.corner(fill, 999)
	Kit.new("UIGradient", { Rotation = 90, Color = Shop.halves(pair[1], pair[2]) }, fill)
	return track,
		function(share: number)
			local s = math.clamp(share, 0, 1)
			fill.Visible = s > 0
			-- (never thinner than its own round ends)
			fill.Size = UDim2.fromScale(s, 1)
		end
end

-- A reward as a small plate: a picture (the O2 bubble or the cash) and an amount. Returns the plate and its words.
local function chip(parent: Instance, props: { [string]: any }, picture: string, colour: Color3): (Frame, TextLabel)
	props.BackgroundColor3 = Shop.BodyDeep
	props.BorderSizePixel = 0
	local z: number = props.ZIndex or 3
	local size: number = props.TextSize or 16
	props.TextSize = nil
	local plate: Frame = Kit.new("Frame", props, parent)
	Kit.corner(plate, Shop.Round.Strip)
	Kit.stroke(plate, 2, Shop.Edge)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, plate)
	Kit.new("ImageLabel", {
		Name = "Picture",
		Size = UDim2.fromOffset(size * 1.3, size * 1.3),
		BackgroundTransparency = 1,
		Image = picture,
		ScaleType = Enum.ScaleType.Fit,
		LayoutOrder = 1,
		ZIndex = z + 1,
	}, plate)
	local words = Shop.text(plate, {
		Name = "Amount",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		TextSize = size,
		TextColor3 = colour,
		LayoutOrder = 2,
		ZIndex = z + 1,
	})
	return plate, words
end

----------------------------------------------------------------------------------------------------------------------
-- The window's pieces

type Card = {
	Fish: Config.FishType,
	Found: boolean, -- as it was built: a kind found since is built again
	Root: Frame,
	Edge: UIStroke,
	Waiting: Frame,
}
type Tab = { Button: Shop.Button, Waiting: Frame }

local window: Shop.Window? = nil
local tabs: { Tab } = {}
local list: ScrollingFrame
local cards: { Card } = {}
local shownLand = 1
local chosen: string? = nil -- the chosen kind's id

-- the chosen kind's column
local well: Frame
local wellFill: UIGradient
local wellPicture: Portrait.Portrait
local wellNone: TextLabel
local nameWord: TextLabel
local tierWord: TextLabel
local tierFill: UIGradient
local rateWord: TextLabel
local looksWord: TextLabel
local kindOxygen: TextLabel
local kindCoins: TextLabel
local claimButton: Shop.Button

-- the land's set
local landWord: TextLabel
local landCount: TextLabel
local setLandBar: (share: number) -> ()
local landOxygen: TextLabel
local landCoins: TextLabel
local landButton: Shop.Button

-- the foot
local foundWord: TextLabel
local setFoundBar: (share: number) -> ()
local allButton: Shop.Button

-- what the server answered, over the tray's foot for a moment
local toast: Frame
local toastFill: UIGradient
local toastWord: TextLabel
local toastTurn = 0

local function say(text: string, good: boolean)
	if not window then
		return
	end
	local pair = if good then Shop.Kinds.Cash else Shop.Kinds.Red
	toastFill.Color = Shop.halves(pair[1], pair[2])
	toastWord.Text = text
	toastTurn += 1
	local turn = toastTurn
	if toast.Visible then
		Anim.punch(toast, 1.08) -- a new line over one still up
	else
		Anim.toast(toast, true)
	end
	task.delay(2.4, function()
		if toastTurn == turn then
			Anim.toast(toast, false)
		end
	end)
end

-- One ask to the server, no sooner after the last than it would listen (Index.AskGap); false when it is too soon
local askedAt = -math.huge
local function ask(what: string, arg: any?): boolean
	local now = os.clock()
	if now - askedAt < Config.Index.AskGap + 0.05 then
		return false
	end
	askedAt = now
	Net.Index:FireServer(what, arg)
	return true
end

local paint: () -> ()

local function fishOf(id: string?): Config.FishType?
	return if id then Config.FishById[id] else nil
end

-- One kind's card: its picture over its name and rarity, in its rarity's colour; not found, the picture dark, "???"
-- and the rarity's colour on the card's edge
local function newCard(fish: Config.FishType, order: number): Card
	local have = found[fish.Id] ~= nil
	local colour = tierColour(fish.Tier)
	local root: Frame = Kit.new("Frame", {
		Name = fish.Id,
		Size = UDim2.fromOffset(CARD_W, CARD_H),
		BackgroundColor3 = if have then Kit.White else DARK_CARD,
		BorderSizePixel = 0,
		LayoutOrder = order,
		ZIndex = 4,
	}, list)
	Kit.corner(root, Shop.Round.Card)
	local edge = Kit.stroke(root, 3, Shop.Edge)
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	if have then
		local colours, turn = fillOf(fish.Tier)
		Kit.new("UIGradient", { Color = colours, Rotation = turn }, root)
		Shop.pattern(root, "Card")
	else
		-- the rarity's colour as a thin line just inside the dark edge
		local inner: Frame = Kit.new("Frame", {
			Name = "Rarity",
			Position = UDim2.fromOffset(2, 2),
			Size = UDim2.new(1, -4, 1, -4),
			BackgroundTransparency = 1,
			ZIndex = 5,
		}, root)
		Kit.corner(inner, Shop.Round.Card - 1)
		local line = Kit.stroke(inner, 2, Kit.White)
		local colours, turn = fillOf(fish.Tier)
		Kit.new("UIGradient", { Color = colours, Rotation = turn }, line)
	end
	local picture = Portrait.new(root, {
		Name = "Picture",
		Position = UDim2.fromOffset(8, 5),
		Size = UDim2.new(1, -16, 0, 56),
		Outline = if have then nil else 0, -- (a dark shape needs no outline: one copy of a live model, not nine)
		ZIndex = 5,
	})
	if picture.show(fish.Id) then
		tint(picture, if have then Kit.White else SHADOW)
	else
		Shop.text(
			picture.Frame,
			{ Size = UDim2.fromScale(1, 1), TextSize = 30, Text = "?", TextColor3 = PALE, ZIndex = 3 }
		)
	end
	Shop.text(root, {
		Name = "Name",
		Position = UDim2.fromOffset(4, 61),
		Size = UDim2.new(1, -8, 0, 30),
		TextSize = 13,
		TextWrapped = true,
		Text = if have then fish.Name else "???",
		ZIndex = 6,
	})
	local rarity: TextLabel = Kit.new("TextLabel", {
		Name = "Tier",
		Position = UDim2.fromOffset(4, 90),
		Size = UDim2.new(1, -8, 0, 14),
		BackgroundTransparency = 1,
		Font = Kit.Font,
		TextSize = 11,
		Text = string.upper(fish.Tier),
		TextColor3 = if have then Kit.darker(colour, 0.7) else Kit.White,
		ZIndex = 6,
	}, root)
	if not have then
		Kit.tierColours(rarity, Kit.new("UIGradient", {}, rarity), fish.Tier, Config.Tiers)
	end
	local waiting = mark(root, UDim2.new(1, -7, 0, 7), 8)
	local press: TextButton = Kit.new("TextButton", {
		Name = "Press",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 10,
	}, root)
	press.Activated:Connect(function()
		chosen = fish.Id
		paint()
	end)
	return { Fish = fish, Found = have, Root = root, Edge = edge, Waiting = waiting }
end

-- Shows a land's cards (built again each time: only the shown land's pictures exist)
local function showLand(land: number)
	shownLand = math.clamp(land, 1, math.max(#lands, 1))
	for _, card in cards do
		card.Root:Destroy()
	end
	table.clear(cards)
	local entry = lands[shownLand]
	local kinds: { Config.FishType } = if entry then entry.Kinds else {}
	local keep = false
	for i, fish in kinds do
		table.insert(cards, newCard(fish, i))
		keep = keep or fish.Id == chosen
	end
	if not keep then
		-- the first kind with a reward waiting, else the land's first
		chosen = if kinds[1] then kinds[1].Id else nil
		for _, fish in kinds do
			if owedKind(fish.Id) then
				chosen = fish.Id
				break
			end
		end
	end
	list.CanvasPosition = Vector2.zero
end

-- Everything on the window, from the Index as it stands
function paint()
	if not window then
		return
	end
	-- a kind found since its card was built: the land's cards again
	for _, card in cards do
		if card.Found ~= (found[card.Fish.Id] ~= nil) then
			showLand(shownLand)
			break
		end
	end
	for land, tab in tabs do
		local on = land == shownLand
		tab.Button.set(nil, if on then "Gold" else "Off", true)
		if not on then
			tab.Button.Fill.Color = Shop.halves(TAB_OFF[1], TAB_OFF[2])
		end
		tab.Button.Label.TextColor3 = if on then Kit.White else TAB_WORD
		tab.Waiting.Visible = owedIn(land) > 0
	end
	for _, card in cards do
		local on = card.Fish.Id == chosen
		card.Edge.Color = if on then Kit.White else Shop.Edge
		card.Edge.Thickness = if on then 4 else 3
		card.Waiting.Visible = owedKind(card.Fish.Id)
	end

	-- the chosen kind
	local fish = fishOf(chosen)
	if fish then
		local have = found[fish.Id] ~= nil
		local colours, turn = fillOf(fish.Tier)
		well.BackgroundColor3 = if have then Kit.White else DARK_CARD
		wellFill.Enabled = have
		wellFill.Color, wellFill.Rotation = colours, turn
		local drawn = wellPicture.show(fish.Id)
		wellPicture.Frame.Visible = drawn
		wellNone.Visible = not drawn
		if drawn then
			tint(wellPicture, if have then Kit.White else SHADOW)
		end
		nameWord.Text = if have then fish.Name else "???"
		tierWord.Text = string.upper(fish.Tier)
		Kit.tierColours(tierWord, tierFill, fish.Tier, Config.Tiers)
		rateWord.Text = if have then Shop.cash(Config.incomeOf(fish, "Normal", "")) .. "/s" else "Not found yet"
		rateWord.TextColor3 = if have then Shop.Money else PALE
		looksWord.Text = `Variants {found[fish.Id] or 0} / {Config.indexLooks()}`
		local oxygen, coins = Config.indexFirst(fish)
		kindOxygen.Text = oxygenText(oxygen)
		kindCoins.Text = Shop.cash(coins)
		if not have then
			claimButton.set("Catch it first", "Off", false)
		elseif claimedKinds[fish.Id] then
			claimButton.set("Claimed", "Off", false)
		else
			claimButton.set("Claim", "Cash", true)
		end
	else
		nameWord.Text = ""
		claimButton.set("Claim", "Off", false)
	end

	-- the land's set
	local have, of = setOf(shownLand)
	landWord.Text = landName(shownLand) .. " set"
	landCount.Text = `{have} / {of}`
	setLandBar(if of > 0 then have / of else 0)
	local oxygen, coins = Config.indexLand(shownLand)
	landOxygen.Text = oxygenText(oxygen)
	landCoins.Text = Shop.cash(coins)
	if claimedLands[tostring(shownLand)] then
		landButton.set("Claimed", "Off", false)
	elseif owedLand(shownLand) then
		landButton.set("Claim", "Gold", true)
	else
		landButton.set("Claim", "Off", false)
	end

	-- the foot
	local all = foundAll()
	foundWord.Text = `{all} of {total} found`
	setFoundBar(if total > 0 then all / total else 0)
	local owed = owedAll()
	allButton.set(`Claim All ({owed})`, if owed > 0 then "Cash" else "Off", owed > 0)
end

local function pressTab(land: number)
	if land ~= shownLand and lands[land] then
		chosen = nil
		showLand(land)
		paint()
		local shown: { GuiObject } = {}
		for _, card in cards do
			table.insert(shown, card.Root)
		end
		Anim.stagger(shown)
	end
end

local function pressClaim()
	if chosen and owedKind(chosen) then
		ask("Claim", chosen)
	end
end

local function pressLand()
	if owedLand(shownLand) then
		ask("ClaimLand", shownLand)
	end
end

local function pressAll()
	if owedAll() > 0 then
		ask("ClaimAll")
	end
end

local function build()
	readRoster()
	local w = Shop.window({
		Name = "IndexPanel",
		Parent = State.Player:WaitForChild("PlayerGui"),
		Title = "Index",
		Head = HEAD,
		Gloss = true,
		Width = WIDE,
		Height = HIGH,
		OnClose = function()
			Shop.go(nil)
		end,
	})
	local body = w.Body
	-- the book of the hub's Index button, at the header's left
	Kit.new("ImageLabel", {
		Name = "Book",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, -2),
		Size = UDim2.fromOffset(Shop.HeadHigh - 12, Shop.HeadHigh - 12),
		Rotation = -8,
		BackgroundTransparency = 1,
		Image = Kit.Textures.Index,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 4,
	}, w.Header)

	-- the lands, a tab each, across the top
	local row: Frame = Kit.new("Frame", {
		Name = "Lands",
		Size = UDim2.new(1, 0, 0, TAB_HIGH),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, body)
	local count = math.max(#lands, 1)
	for land = 1, #lands do
		local b = Shop.button(row, {
			Name = "Land" .. land,
			Text = Kit.LandShort[land] or tostring(land),
			Kind = "Off",
			TextSize = 14,
			Position = UDim2.new((land - 1) / count, if land == 1 then 0 else TAB_GAP / 2, 0, 0),
			Size = UDim2.new(1 / count, -(if land == 1 or land == count then TAB_GAP / 2 else TAB_GAP), 1, 0),
		})
		b.Root.ZIndex = 3
		b.Root.Activated:Connect(function()
			pressTab(land)
		end)
		table.insert(tabs, { Button = b, Waiting = mark(b.Root, UDim2.new(1, -6, 0, 6), 6) })
	end

	-- the land's cards, in a dark tray
	local top = TAB_HIGH + GAP
	local trayHigh = -(top + LAND_HIGH + GAP + FOOT_HIGH + GAP)
	local tray = Shop.inset(body, {
		Name = "Tray",
		Position = UDim2.fromOffset(0, top),
		Size = UDim2.new(1, -(SIDE + GAP), 1, trayHigh),
		ClipsDescendants = true,
		ZIndex = 2,
	})
	list = Kit.new("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 1, -8),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = HEAD,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ZIndex = 3,
	}, tray)
	Kit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(CARD_W, CARD_H),
		CellPadding = UDim2.fromOffset(CARD_GAP, CARD_GAP),
		FillDirectionMaxCells = COLUMNS,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
	}, list)
	Kit.new("UIPadding", {
		PaddingLeft = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
	}, list)
	toast = Kit.new("Frame", {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -40, 0, 38),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 12,
	}, tray)
	Kit.corner(toast, 5)
	Kit.stroke(toast, 3, Shop.Edge)
	toastFill = Kit.new("UIGradient", { Rotation = 90 }, toast)
	toastWord = Shop.text(toast, { Size = UDim2.fromScale(1, 1), TextSize = 18, ZIndex = 13 })

	-- the land's set: its name over a bar, n / N, what the whole set pays, and its claim
	local landBox = Shop.inset(body, {
		Name = "LandSet",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -(FOOT_HIGH + GAP)),
		Size = UDim2.new(1, -(SIDE + GAP), 0, LAND_HIGH),
		ZIndex = 2,
	})
	landWord = Shop.text(landBox, {
		Name = "Land",
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.fromOffset(222, 20),
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})
	local _, setLand = bar(landBox, {
		Name = "Bar",
		Position = UDim2.fromOffset(12, 30),
		Size = UDim2.fromOffset(222, 14),
		ZIndex = 3,
	}, GOLD)
	setLandBar = setLand
	landCount = Shop.text(landBox, {
		Name = "Count",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 238, 0.5, 0),
		Size = UDim2.fromOffset(78, 30),
		TextSize = 20,
		TextColor3 = GOLD[1],
		ZIndex = 3,
	})
	local _, landO = chip(landBox, {
		Name = "Oxygen",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 320, 0.5, 0),
		Size = UDim2.fromOffset(80, 32),
		TextSize = 14,
		ZIndex = 3,
	}, Kit.Textures.Oxygen, Kit.White)
	landOxygen = landO
	local _, landC = chip(landBox, {
		Name = "Coins",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 404, 0.5, 0),
		Size = UDim2.fromOffset(80, 32),
		TextSize = 14,
		ZIndex = 3,
	}, Kit.Textures.Cash, Shop.Money)
	landCoins = landC
	landButton = Shop.button(landBox, {
		Name = "ClaimLand",
		Text = "Claim",
		Kind = "Off",
		TextSize = 20,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(112, 40),
	})
	landButton.Root.ZIndex = 3
	landButton.Root.Activated:Connect(pressLand)

	-- the foot: how many kinds are found of all there are, and CLAIM ALL
	local foot = Shop.inset(body, {
		Name = "Found",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, -(SIDE + GAP + ALL_WIDE + GAP), 0, FOOT_HIGH),
		ZIndex = 2,
	})
	local _, setFound = bar(foot, {
		Name = "Bar",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 46, 0.5, 0),
		Size = UDim2.new(1, -58, 0, 24),
		ZIndex = 3,
	}, Shop.Kinds.Blue)
	setFoundBar = setFound
	foundWord = Shop.text(foot, {
		Name = "Count",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 46, 0.5, 0),
		Size = UDim2.new(1, -58, 0, 24),
		TextSize = 18,
		ZIndex = 6,
	})
	Kit.new("ImageLabel", {
		Name = "Book",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 4, 0.5, 0),
		Size = UDim2.fromOffset(42, 42),
		Rotation = -8,
		BackgroundTransparency = 1,
		Image = Kit.Textures.Index,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 7,
	}, foot)
	allButton = Shop.button(body, {
		Name = "ClaimAll",
		Text = "Claim All (0)",
		Kind = "Off",
		TextSize = 20,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -(SIDE + GAP), 1, 0),
		Size = UDim2.fromOffset(ALL_WIDE, FOOT_HIGH),
		Shine = true, -- (the window's one money button)
	})
	allButton.Root.ZIndex = 3
	allButton.Root.Activated:Connect(pressAll)

	-- the chosen kind, at the right
	local side = Shop.inset(body, {
		Name = "Kind",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, top),
		Size = UDim2.new(0, SIDE, 1, -top),
		ZIndex = 2,
	})
	well = Kit.new("Frame", {
		Name = "Well",
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 0, 104),
		BackgroundColor3 = DARK_CARD,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, side)
	Kit.corner(well, Shop.Round.Card)
	Kit.stroke(well, 3, Shop.Edge).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	wellFill = Kit.new("UIGradient", { Rotation = 90 }, well)
	wellPicture = Portrait.new(well, {
		Name = "Picture",
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 1, -12),
		ZIndex = 4,
	})
	wellNone = Shop.text(well, {
		Name = "None",
		Size = UDim2.fromScale(1, 1),
		TextSize = 44,
		Text = "?",
		TextColor3 = PALE,
		Visible = false,
		ZIndex = 4,
	})
	nameWord = Shop.text(side, {
		Name = "Name",
		Position = UDim2.fromOffset(8, 118),
		Size = UDim2.new(1, -16, 0, 44),
		TextSize = 20,
		TextWrapped = true,
		ZIndex = 3,
	})
	tierWord = Shop.text(side, {
		Name = "Tier",
		Position = UDim2.fromOffset(8, 162),
		Size = UDim2.new(1, -16, 0, 18),
		TextSize = 15,
		ZIndex = 3,
	})
	tierFill = Kit.new("UIGradient", {}, tierWord)
	rateWord = Shop.text(side, {
		Name = "Rate",
		Position = UDim2.fromOffset(8, 182),
		Size = UDim2.new(1, -16, 0, 24),
		TextSize = 20,
		TextColor3 = Shop.Money,
		ZIndex = 3,
	})
	local looks: Frame = Kit.new("Frame", {
		Name = "Variants",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 209),
		Size = UDim2.new(1, -40, 0, 24),
		BackgroundColor3 = Shop.BodyDeep,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, side)
	Kit.corner(looks, Shop.Round.Strip)
	Kit.stroke(looks, 2, Shop.Edge)
	looksWord = Shop.text(looks, { Size = UDim2.fromScale(1, 1), TextSize = 14, TextColor3 = PALE, ZIndex = 4 })
	Kit.new("Frame", {
		Name = "Line",
		Position = UDim2.fromOffset(10, 241),
		Size = UDim2.new(1, -20, 0, 3),
		BackgroundColor3 = Shop.Edge,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, side)
	Shop.text(side, {
		Name = "Reward",
		Position = UDim2.fromOffset(8, 247),
		Size = UDim2.new(1, -16, 0, 18),
		TextSize = 14,
		TextColor3 = PALE,
		Text = "First catch reward",
		ZIndex = 3,
	})
	local _, kindO = chip(side, {
		Name = "Oxygen",
		Position = UDim2.fromOffset(10, 268),
		Size = UDim2.new(0.5, -13, 0, 34),
		ZIndex = 3,
	}, Kit.Textures.Oxygen, Kit.White)
	kindOxygen = kindO
	local _, kindC = chip(side, {
		Name = "Coins",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 268),
		Size = UDim2.new(0.5, -13, 0, 34),
		ZIndex = 3,
	}, Kit.Textures.Cash, Shop.Money)
	kindCoins = kindC
	claimButton = Shop.button(side, {
		Name = "Claim",
		Text = "Claim",
		Kind = "Off",
		TextSize = 22,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -20, 0, 44),
	})
	claimButton.Root.ZIndex = 3
	claimButton.Root.Activated:Connect(pressClaim)

	window = w
	showLand(shownLand)
end

----------------------------------------------------------------------------------------------------------------------
-- For the hub's button, and Studio's checks

local changed = Instance.new("BindableEvent")
-- Fired when the server has sent the Index again (something found or claimed)
IndexPanel.Changed = changed.Event

-- How many rewards wait to be claimed, as this client counts them (the server's own count is the player's
-- "IndexClaims" attribute)
function IndexPanel.waiting(): number
	if #lands == 0 then
		readRoster()
	end
	return owedAll()
end

function IndexPanel.isOpen(): boolean
	return window ~= nil and window.isOpen()
end

-- Test hook: only the Studio checks and the offline check (tools/index/panel_test.luau) call this. A press, as the
-- player's: "Land", n | "Kind", fish id | "Claim" | "ClaimLand" | "ClaimAll".
function IndexPanel.press(what: string, arg: any?)
	if not IndexPanel.isOpen() then
		return
	end
	if what == "Land" and type(arg) == "number" then
		pressTab(arg)
	elseif what == "Kind" and type(arg) == "string" and Config.FishById[arg] then
		chosen = arg
		paint()
	elseif what == "Claim" then
		pressClaim()
	elseif what == "ClaimLand" then
		pressLand()
	elseif what == "ClaimAll" then
		pressAll()
	end
end

-- Open or close the window. (Through Shop.go("Index"), so another dock window closes.)
function IndexPanel.open(on: boolean)
	if not window then
		if not on then
			return
		end
		build()
	end
	local w = window :: Shop.Window
	local opening = on and not w.isOpen()
	if opening then
		-- the first land with a reward waiting, else the land last looked at
		for land = 1, #lands do
			if owedIn(land) > 0 then
				if land ~= shownLand then
					chosen = nil
					showLand(land)
				end
				break
			end
		end
		toastTurn += 1
		toast.Visible = false
		paint()
	end
	w.show(on)
	-- the cards pop in one after another as it opens
	if opening then
		local shown: { GuiObject } = {}
		for _, card in cards do
			table.insert(shown, card.Root)
		end
		Anim.stagger(shown)
	end
end

Shop.page("Index", IndexPanel.open)

-- The server's word: the whole Index after every change, and what a claim paid or why it was refused
Net.Index.OnClientEvent:Connect(function(what: any, a: any, b: any, c: any)
	if what == "State" and type(a) == "table" and type(b) == "table" and type(c) == "table" then
		found, claimedKinds, claimedLands = a, b, c
		paint()
		changed:Fire()
	elseif what == "Paid" and type(a) == "number" and type(b) == "number" then
		local words = { oxygenText(a) .. " Oxygen" }
		if b > 0 then
			table.insert(words, "+" .. Shop.cash(b))
		end
		say(table.concat(words, "   "), true)
	elseif what == "Denied" and a == "Dock" then
		say("Stand on the dock to claim", false)
	end
end)
-- (in case the server's first word went out before this was listening)
Net.Index:FireServer("Sync")

return IndexPanel
