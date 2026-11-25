--!strict
-- The Index's window (Hugo, 2026-11-25: "Make index ui feel more like ride a dino ... you can generate land pictures
-- from the screenshots you took, make them a little more artistic and stylised"; NULLROOM task i1; docs/design/ui.md,
-- "The Index, richer"). The reference gave the feel and where things sit; the look is ours: the shop kit (UI.Shop:
-- window, orange header, studs, wells, buttons, font, X), our rarity colours, our fish pictures, our O2 bubble and cash,
-- and our own painted lands (UI.LandBanners; a land's plain colours until they are uploaded).
--   The header:    the book and the title at the left, CLAIM ALL (n) and the X at the right
--                  (an arrow points at CLAIM ALL until the first claim ever: the user, 2026-11-25)
--   The lands:     a tab each, a slice of the land's painting under its short name, a "!" while a reward waits there
--   The tray:      the shown land's banner, tall, at the left: its name at the top, and at its foot COMPLETE, what the
--                  whole set pays, and n / N on a bar, which becomes CLAIM! when the set is whole. Beside it the land's
--                  cards, big, in their rarity's colour: the name over the picture, a "!" on the corner while its reward
--                  waits. Not found: a dark card, the picture a dark shape, "???", the rarity on its edge
--   The kind:      the chosen one, big, in its rarity's colour: picture, name, rarity, what a Normal plain one earns a
--                  second, and how many of its looks (size and colour) are caught, which is all the game records of them
--   The rewards:   what its first catch pays, and CLAIM! (its edge gold while it waits)
--   The foot:      a fat bar, Unlocked n / N
-- Three layouts (SHAPES), by the screen: Wide (a PC, a tablet), Phone (held sideways), Tall (held upright: the kind and
-- the rewards go under the tray). A screen that turns builds the window again.
-- Nothing here decides anything: a press only asks (IndexBook.ask). UI.IndexPanel opens it and passes the server's word.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.Parent.Lib.State)
local Anim = require(script.Parent.Anim)
local IndexBook = require(script.Parent.IndexBook)
local Kit = require(script.Parent.Kit)
local LandBanners = require(script.Parent.LandBanners)
local LessonPrompt = require(script.Parent.LessonPrompt)
local Portrait = require(script.Parent.Portrait)
local Shop = require(script.Parent.Shop)

local IndexWindow = {}

----------------------------------------------------------------------------------------------------------------------
-- The layouts, in the window's own points

type Shape = {
	Wide: number,
	High: number,
	Title: number, -- the header's letters
	All: number, -- CLAIM ALL's width, and its letters
	AllText: number,
	TabHigh: number,
	TabRows: number,
	TabText: number,
	Side: number, -- the right column's width; Tall: how high the kind and the rewards are, under the foot
	Foot: number, -- the Unlocked bar's height
	FootText: number,
	Banner: number, -- the banner's width
	LandText: number, -- the land's name
	BoxText: number, -- the COMPLETE box's amounts
	Columns: number,
	CardW: number,
	CardH: number,
	CardGap: number,
	CardText: number, -- a name on a card, at most
	Mark: number, -- a "!" disc
	Name: number, -- the kind's name, its rarity and rate
	Line: number,
	OneLine: boolean?, -- the rarity and the rate share one line
	Pill: number, -- the variants' plate
	Rewards: number, -- the rewards box's height (Tall: its width)
	Tile: number, -- a reward's tile
	Claim: number, -- CLAIM!'s height, and its letters
	ClaimText: number,
}

local SHAPES: { [string]: Shape } = {
	Wide = {
		Wide = 1000,
		High = 624,
		Title = 46,
		All = 246,
		AllText = 30,
		TabHigh = 46,
		TabRows = 1,
		TabText = 18,
		Side = 288,
		Foot = 62,
		FootText = 38,
		Banner = 172,
		LandText = 34,
		BoxText = 24,
		Columns = 3,
		CardW = 150,
		CardH = 186,
		CardGap = 10,
		CardText = 22,
		Mark = 28,
		Name = 32,
		Line = 24,
		Pill = 34,
		Rewards = 196,
		Tile = 74,
		Claim = 62,
		ClaimText = 38,
	},
	Phone = {
		Wide = 900,
		High = 496,
		Title = 42,
		All = 232,
		AllText = 28,
		TabHigh = 44,
		TabRows = 1,
		TabText = 18,
		Side = 246,
		Foot = 48,
		FootText = 32,
		Banner = 146,
		LandText = 28,
		BoxText = 20,
		Columns = 3,
		CardW = 140,
		CardH = 133,
		CardGap = 8,
		CardText = 20,
		Mark = 26,
		Name = 26,
		Line = 21,
		OneLine = true,
		Pill = 27,
		Rewards = 152,
		Tile = 50,
		Claim = 50,
		ClaimText = 32,
	},
	Tall = {
		Wide = 480,
		High = 864,
		Title = 38,
		All = 194,
		AllText = 24,
		TabHigh = 45,
		TabRows = 2,
		TabText = 17,
		Side = 236,
		Foot = 52,
		FootText = 34,
		Banner = 130,
		LandText = 27,
		BoxText = 20,
		Columns = 2,
		CardW = 142,
		CardH = 152,
		CardGap = 8,
		CardText = 20,
		Mark = 26,
		Name = 27,
		Line = 21,
		Pill = 30,
		Rewards = 214,
		Tile = 102,
		Claim = 60,
		ClaimText = 34,
	},
}
local GAP = 8
local INNER = 8 -- the room between a tray or a box and what is in it

local HEAD = Color3.fromRGB(240, 128, 30) -- the partner's orange header
local PALE = Color3.fromRGB(214, 222, 236) -- quiet words on the dark body (Sell Fish's)
local AIR = Color3.fromRGB(140, 232, 255) -- an amount of Oxygen
local DARK_CARD = Color3.fromRGB(22, 36, 64) -- a kind not found yet: the partner's dark navy card
local SHADOW = Color3.fromRGB(8, 14, 30) -- and its picture, painted this dark
local PLATE = 18 -- the variants plate's room at the panel's sides
local LIST_PAD = 10 -- over the first row of cards and under the last
local TALL_TITLE = 25 -- the title's letters held upright, while the arrow points at CLAIM ALL
local OPENED = 0.4 -- seconds from its opening till the window stands at its full size (UI.Anim.Open.Time is 0.36)
local DIM_TAB = Color3.fromRGB(176, 186, 208) -- a land's tab while another is shown
local GOLD = Shop.Kinds.Gold
local BLUE = Shop.Kinds.Blue
local RED = { Color3.fromRGB(240, 78, 84), Color3.fromRGB(196, 32, 48) } -- the hub button's "!" disc

local lands = IndexBook.Lands

-- Which layout the screen wants (Studio: the workspace's PanelPhone, as UI.Shop's windows)
local function shapeOf(): string
	local camera = workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1920, 1080)
	local phone = if RunService:IsStudio() then workspace:GetAttribute("PanelPhone") else nil
	if typeof(phone) == "Vector2" then
		view = phone
	end
	if view.X < view.Y * 0.8 then
		return "Tall"
	end
	return if view.Y < 560 then "Phone" else "Wide"
end

----------------------------------------------------------------------------------------------------------------------
-- Words and small pieces

-- The letters that fit `text` on one line this wide: never over `most`, never under `least`
local function fitted(text: string, wide: number, most: number, least: number): number
	return math.clamp(math.floor(wide / (math.max(#text, 1) * 0.47)), least, most)
end

-- A card's fill in its rarity's colour: the top three rarities as the kit paints them (gold, ember, the rainbow), the
-- lower ones their colour running a little darker toward the foot (the partner's cards)
local function fillOf(tier: string): (ColorSequence, number)
	if tier == "Legendary" or tier == "Mythic" or tier == "Secret" then
		return Kit.tierFill(tier, Config.Tiers)
	end
	local entry = Config.Tiers[tier]
	local colour = if entry then entry.Colour else Kit.White
	return ColorSequence.new(Kit.lighter(colour, 0.06), Kit.darker(colour, 0.26)), 90
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

-- The red "!" on a card or a tab with a reward waiting (the hub button's mark, still)
local function mark(parent: Instance, at: UDim2, size: number, z: number): Frame
	local disc: Frame = Kit.new("Frame", {
		Name = "Waiting",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = at,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = z,
	}, parent)
	Kit.corner(disc, 999)
	Kit.gradient(disc, RED[1], RED[2])
	Kit.stroke(disc, 2.5, Kit.White)
	local bang = Shop.text(disc, {
		Size = UDim2.fromScale(1, 1),
		TextSize = math.floor(size * 0.86),
		Text = "!",
		ZIndex = z + 1,
	})
	bang.Rotation = 8
	return disc
end

-- A bar that fills: a dark track and a bright fill. Returns the track and how to set its share (0 to 1).
local function bar(
	parent: Instance,
	props: { [string]: any },
	pair: { Color3 },
	round: number
): (Frame, (share: number) -> ())
	props.BackgroundColor3 = Shop.BodyDeep
	props.BorderSizePixel = 0
	local track: Frame = Kit.new("Frame", props, parent)
	Kit.corner(track, round)
	Kit.stroke(track, 3, Shop.Edge)
	local fill: Frame = Kit.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = (props.ZIndex or 1) + 1,
	}, track)
	Kit.corner(fill, round)
	Kit.new("UIGradient", { Rotation = 90, Color = Shop.halves(pair[1], pair[2]) }, fill)
	-- (never thinner than the bar is tall: from its height at the first bit to the whole track at 1)
	local least: number = props.Size.Y.Offset
	return track,
		function(share: number)
			local s = math.clamp(share, 0, 1)
			fill.Visible = s > 0
			fill.Size = UDim2.new(s, (1 - s) * least, 1, 0)
		end
end

-- A picture and an amount on one line, in the middle of the room it is given. Returns the words.
local function amount(
	parent: Instance,
	props: { [string]: any },
	picture: string,
	colour: Color3,
	size: number
): TextLabel
	props.BackgroundTransparency = 1
	local z: number = props.ZIndex or 3
	local row: Frame = Kit.new("Frame", props, parent)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	Kit.new("ImageLabel", {
		Name = "Picture",
		Size = UDim2.fromOffset(size * 1.35, size * 1.35),
		BackgroundTransparency = 1,
		Image = picture,
		ScaleType = Enum.ScaleType.Fit,
		LayoutOrder = 1,
		ZIndex = z + 1,
	}, row)
	return Shop.text(row, {
		Name = "Amount",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		TextSize = size,
		TextColor3 = colour,
		LayoutOrder = 2,
		ZIndex = z + 1,
	})
end

-- A reward as a tile: its picture over its amount. Returns the words.
local function tile(
	parent: Instance,
	props: { [string]: any },
	picture: string,
	colour: Color3,
	high: number
): TextLabel
	props.BackgroundColor3 = Kit.White
	props.BorderSizePixel = 0
	local z: number = props.ZIndex or 3
	local plate: Frame = Kit.new("Frame", props, parent)
	Kit.corner(plate, Shop.Round.Card)
	Kit.stroke(plate, 3, Shop.Edge)
	Kit.gradient(plate, Kit.lighter(Shop.Border, 0.06), Shop.Body)
	local words = math.clamp(math.floor(high * 0.34), 17, 24)
	local room = high - words - 4
	Kit.new("ImageLabel", {
		Name = "Picture",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 2),
		Size = UDim2.fromOffset(room, room),
		BackgroundTransparency = 1,
		Image = picture,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = z + 1,
	}, plate)
	return Shop.text(plate, {
		Name = "Amount",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -2),
		Size = UDim2.new(1, 0, 0, words),
		TextSize = words,
		TextColor3 = colour,
		ZIndex = z + 2,
	})
end

-- A land's painting over its plain colours (which show while there is no picture): for a banner or a tab
local function landPicture(parent: Frame | TextButton, land: number, round: number, z: number): (ImageLabel, UIGradient)
	local plain: Frame = Kit.new("Frame", {
		Name = "Plain",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		ZIndex = z,
	}, parent)
	Kit.corner(plain, round)
	local fill: UIGradient = Kit.new("UIGradient", { Rotation = 90, Color = LandBanners.fill(land) }, plain)
	local image: ImageLabel = Kit.new("ImageLabel", {
		Name = "Painting",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = LandBanners.image(land),
		ScaleType = Enum.ScaleType.Crop,
		ZIndex = z + 1,
	}, parent)
	Kit.corner(image, round)
	return image, fill
end

----------------------------------------------------------------------------------------------------------------------
-- The window's pieces

type Card = {
	Fish: Config.FishType,
	Found: boolean, -- as it was built: a kind found since is built again
	Root: Frame,
	Edge: UIStroke,
	Name: TextLabel,
	Waiting: Frame,
}
type Tab = { Button: Shop.Button, Painting: ImageLabel, Shade: Frame, Waiting: Frame }

local window: Shop.Window? = nil
local built = "" -- the layout it was built for
local shape: Shape = SHAPES.Wide
local tabs: { Tab } = {}
local list: ScrollingFrame
local cards: { Card } = {}
local shownLand = 1
local chosen: string? = nil -- the chosen kind's id
local painted: string? = nil -- the kind the big picture shows, to pop it when another is chosen

-- the chosen kind, and its rewards
local panel: Frame
local panelFill: UIGradient
local panelLine: Frame
local panelLineFill: UIGradient
local panelPicture: Portrait.Portrait
local panelNone: TextLabel
local nameWord: TextLabel
local tierWord: TextLabel
local tierFill: UIGradient
local rateWord: TextLabel
local looksWord: TextLabel
local rewardsEdge: UIStroke
local kindOxygen: TextLabel
local kindCoins: TextLabel
local claimButton: Shop.Button

-- the land's banner
local painting: ImageLabel
local bannerShade: Frame
local plainFill: UIGradient
local landWord: TextLabel
local boxEdge: UIStroke
local landCount: TextLabel
local landTrack: Frame
local setLandBar: (share: number) -> ()
local landOxygen: TextLabel
local landCoins: TextLabel
local landButton: Shop.Button

-- the foot and the header
local foundWord: TextLabel
local setFoundBar: (share: number) -> ()
local allButton: Shop.Button
local allArrow: (on: boolean) -> () -- the arrow at it, until the first claim ever

-- what the server answered, over the tray's foot for a moment
local toast: Frame
local toastFill: UIGradient
local toastWord: TextLabel
local toastTurn = 0

function IndexWindow.say(text: string, good: boolean)
	if not window or not window.isOpen() then
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

local paint: () -> ()

-- One kind's card: its name over its picture, in its rarity's colour; not found, the picture dark, "???" and the
-- rarity's colour on the card's edge
local function newCard(fish: Config.FishType, order: number): Card
	local have = IndexBook.has(fish.Id)
	local root: Frame = Kit.new("Frame", {
		Name = fish.Id,
		Size = UDim2.fromOffset(shape.CardW, shape.CardH),
		BackgroundColor3 = if have then Kit.White else DARK_CARD,
		BorderSizePixel = 0,
		LayoutOrder = order,
		ZIndex = 4,
	}, list)
	Kit.corner(root, Shop.Round.Card)
	local edge = Kit.stroke(root, 3, Shop.Edge)
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local colours, turn = fillOf(fish.Tier)
	if have then
		Kit.new("UIGradient", { Color = colours, Rotation = turn }, root)
		Shop.pattern(root, "Card")
	else
		-- the rarity's colour as a line just inside the dark edge
		local inner: Frame = Kit.new("Frame", {
			Name = "Rarity",
			Position = UDim2.fromOffset(3, 3),
			Size = UDim2.new(1, -6, 1, -6),
			BackgroundTransparency = 1,
			ZIndex = 5,
		}, root)
		Kit.corner(inner, Shop.Round.Card - 1)
		local line = Kit.stroke(inner, 3, Kit.White)
		Kit.new("UIGradient", { Color = colours, Rotation = turn }, line)
	end
	local text = if have then fish.Name else "???"
	local name = Shop.text(root, {
		Name = "Name",
		Position = UDim2.fromOffset(2, 5),
		Text = text,
		ZIndex = 7,
	})
	local top = shape.CardText + 9
	local picture = Portrait.new(root, {
		Name = "Picture",
		Position = UDim2.fromOffset(8, top),
		Size = UDim2.new(1, -16, 1, -(top + 7)),
		Outline = if have then nil else 0, -- (a dark shape needs no outline: one copy of a live model, not nine)
		ZIndex = 5,
	})
	if picture.show(fish.Id) then
		tint(picture, if have then Kit.White else SHADOW)
	else
		Shop.text(
			picture.Frame,
			{ Size = UDim2.fromScale(1, 1), TextSize = 44, Text = "?", TextColor3 = PALE, ZIndex = 3 }
		)
	end
	local waiting = mark(root, UDim2.new(1, -5, 0, 5), shape.Mark, 8)
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
	return { Fish = fish, Found = have, Root = root, Edge = edge, Name = name, Waiting = waiting }
end

-- Scrolls the list just far enough to show the chosen kind's whole card (a land opens on its first reward waiting, which
-- can be rows down). A list's place is in pixels of the screen: the window's scale is counted in.
local function reveal()
	if not window then
		return
	end
	local scale = (window :: Shop.Window).Scale.Scale
	for i, card in cards do
		if card.Fish.Id == chosen then
			local row = math.ceil(i / shape.Columns)
			local top = (row - 1) * (shape.CardH + shape.CardGap)
			local foot = LIST_PAD + top + shape.CardH + LIST_PAD
			local at = list.CanvasPosition.Y / scale
			if top < at then
				list.CanvasPosition = Vector2.new(0, top * scale)
			elseif foot > at + list.Size.Y.Offset then
				list.CanvasPosition = Vector2.new(0, (foot - list.Size.Y.Offset) * scale)
			end
			return
		end
	end
end

-- The first of a land's kinds with a reward waiting, nil if none has
local function firstOwed(land: number): string?
	local entry = lands[land]
	local kinds: { Config.FishType } = if entry then entry.Kinds else {}
	for _, fish in kinds do
		if IndexBook.owedKind(fish.Id) then
			return fish.Id
		end
	end
	return nil
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
		chosen = firstOwed(shownLand) or if kinds[1] then kinds[1].Id else nil
	end
	list.CanvasPosition = Vector2.zero
	-- (after the new cards are laid out: the list cannot scroll further than it is long)
	task.defer(reveal)
end

-- The chosen kind and its rewards
local function paintKind()
	local fish = if chosen then Config.FishById[chosen] else nil
	if not fish then
		nameWord.Text, tierWord.Text, rateWord.Text, looksWord.Text = "", "", "", ""
		claimButton.set("CLAIM!", "Off", false)
		return
	end
	local have = IndexBook.has(fish.Id)
	local colours, turn = fillOf(fish.Tier)
	panel.BackgroundColor3 = if have then Kit.White else DARK_CARD
	panelFill.Enabled = have
	panelFill.Color, panelFill.Rotation = colours, turn
	panelLine.Visible = not have
	panelLineFill.Color, panelLineFill.Rotation = colours, turn
	local drawn = panelPicture.show(fish.Id)
	panelPicture.Frame.Visible = drawn
	panelNone.Visible = not drawn
	if drawn then
		tint(panelPicture, if have then Kit.White else SHADOW)
		if painted ~= fish.Id then
			Anim.punch(panelPicture.Frame, 1.12)
		end
	end
	painted = fish.Id
	local room = panel.Size.X.Offset - 16
	local name = if have then fish.Name else "???"
	nameWord.Text = name
	nameWord.TextSize = fitted(name, room, shape.Name, 18)
	tierWord.Text = string.upper(fish.Tier)
	Kit.tierColours(tierWord, tierFill, fish.Tier, Config.Tiers)
	if have then
		-- (on a face of its own colour the word is nearly white, with a touch of it)
		local tier = Config.Tiers[fish.Tier]
		tierFill.Color = ColorSequence.new(Kit.White, Kit.lighter(if tier then tier.Colour else Kit.White, 0.62))
		tierFill.Rotation = 90
	end
	rateWord.Text = if have then Kit.rate(Config.incomeOf(fish, "Normal", "")) else "Not found yet"
	if shape.OneLine then
		-- one size for both, so the two share the plate's width (capitals are wider)
		local letters = #tierWord.Text * 0.6 + #rateWord.Text * 0.47 + 0.6
		local size = math.clamp(math.floor((panel.Size.X.Offset - PLATE * 2) / letters), 14, shape.Line)
		tierWord.TextSize, rateWord.TextSize = size, size
	else
		tierWord.TextSize = fitted(tierWord.Text, room, shape.Line, 14)
		rateWord.TextSize = fitted(rateWord.Text, room, shape.Line + 3, 14)
	end
	rateWord.TextColor3 = if have then Kit.lighter(Shop.Money, 0.45) else PALE
	looksWord.Text = `Variants {IndexBook.looks(fish.Id)} / {Config.indexLooks()}`
	local oxygen, coins = Config.indexFirst(fish)
	kindOxygen.Text = IndexBook.oxygenText(oxygen)
	kindCoins.Text = Shop.cash(coins)
	local owed = IndexBook.owedKind(fish.Id)
	rewardsEdge.Color = if owed then GOLD[2] else Shop.Edge
	if not have then
		claimButton.set("CATCH IT FIRST", "Off", false)
	elseif owed then
		claimButton.set("CLAIM!", "Cash", true)
	else
		claimButton.set("CLAIMED", "Off", false)
	end
	claimButton.Label.TextSize =
		fitted(claimButton.Label.Text, claimButton.Root.Size.X.Offset - 16, shape.ClaimText, 18)
end

-- The shown land's banner
local function paintLand()
	painting.Image = LandBanners.image(shownLand)
	plainFill.Color = LandBanners.fill(shownLand)
	bannerShade.Visible = painting.Image ~= ""
	local name = IndexBook.landName(shownLand)
	-- (two words go on two lines, "Coral / Reef": the letters are sized by the longer)
	local longest = 1
	for word in string.gmatch(name, "%S+") do
		longest = math.max(longest, #word)
	end
	landWord.Text = string.gsub(name, "^(%S+) (%S+)$", "%1\n%2")
	landWord.TextSize = fitted(string.rep("a", longest), shape.Banner - 10, shape.LandText, 18)
	local have, of = IndexBook.setOf(shownLand)
	landCount.Text = `{have} / {of}`
	setLandBar(if of > 0 then have / of else 0)
	local oxygen, coins = Config.indexLand(shownLand)
	landOxygen.Text = IndexBook.oxygenText(oxygen)
	landCoins.Text = Shop.cash(coins)
	local paid, owed = IndexBook.landPaid(shownLand), IndexBook.owedLand(shownLand)
	landTrack.Visible = not paid and not owed
	landButton.Root.Visible = paid or owed
	landButton.set(if paid then "CLAIMED" else "CLAIM!", if owed then "Gold" else "Off", owed)
	boxEdge.Color = if owed then GOLD[1] else Shop.Edge
end

-- Everything on the window, from the Index as it stands. Called while the window is open and as it opens, never
-- for a closed one: it builds the shown land's cards again when a kind in it has been found since.
function paint()
	if not window then
		return
	end
	for _, card in cards do
		if card.Found ~= IndexBook.has(card.Fish.Id) then
			showLand(shownLand)
			break
		end
	end
	for land, tab in tabs do
		local on = land == shownLand
		tab.Button.Edge.Color = if on then Kit.White else Shop.Edge
		tab.Button.Edge.Thickness = if on then 4 else 3
		tab.Button.Root.ZIndex = if on then 4 else 3
		tab.Painting.ImageColor3 = if on then Kit.White else DIM_TAB
		tab.Shade.Visible = not on
		tab.Waiting.Visible = IndexBook.owedIn(land) > 0
	end
	for _, card in cards do
		local on = card.Fish.Id == chosen
		card.Edge.Color = if on then Kit.White else Shop.Edge
		card.Edge.Thickness = if on then 4.5 else 3
		local owed = IndexBook.owedKind(card.Fish.Id)
		card.Waiting.Visible = owed
		-- the name keeps clear of the mark on the card's corner
		local corner = if owed then shape.Mark // 2 + 6 else 0
		card.Name.Size = UDim2.new(1, -4 - corner, 0, shape.CardText + 4)
		card.Name.TextSize = fitted(card.Name.Text, shape.CardW - (if owed then 8 else 16) - corner, shape.CardText, 14)
	end
	paintKind()
	paintLand()
	local all, total = IndexBook.foundAll(), IndexBook.total()
	foundWord.Text = `Unlocked {all}/{total}`
	setFoundBar(if total > 0 then all / total else 0)
	local owed = IndexBook.owedAll()
	allButton.set(`CLAIM ALL ({owed})`, if owed > 0 then "Cash" else "Off", owed > 0)
	local first = owed > 0 and not IndexBook.taught()
	allArrow(first)
	if window and built == "Tall" then
		window.Title.TextSize = if first then TALL_TITLE else shape.Title -- (the arrow stands where its end would be)
	end
end

local function popCards()
	local shown: { GuiObject } = {}
	for _, card in cards do
		table.insert(shown, card.Root)
	end
	Anim.stagger(shown)
end

local function pressTab(land: number)
	if land ~= shownLand and lands[land] then
		chosen = nil
		showLand(land)
		paint()
		popCards()
	end
end

local function pressClaim()
	if chosen and IndexBook.owedKind(chosen) then
		IndexBook.ask("Claim", chosen)
	end
end

local function pressLand()
	if IndexBook.owedLand(shownLand) then
		IndexBook.ask("ClaimLand", shownLand)
	end
end

local function pressAll()
	if IndexBook.owedAll() > 0 then
		IndexBook.ask("ClaimAll")
	end
end

----------------------------------------------------------------------------------------------------------------------
-- Building it

-- The lands, a tab each: a slice of the painting under the land's short name
local function buildTabs(body: Frame, wide: number, high: number)
	local row: Frame = Kit.new("Frame", {
		Name = "Lands",
		Size = UDim2.new(1, 0, 0, high),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, body)
	local gap = 7
	local across = math.max(math.ceil(#lands / shape.TabRows), 1)
	local each = (wide - gap * (across - 1)) / across
	for land = 1, #lands do
		local column, line = (land - 1) % across, (land - 1) // across
		local b = Shop.button(row, {
			Name = "Land" .. land,
			Text = Kit.LandShort[land] or tostring(land),
			Kind = "Off",
			TextSize = shape.TabText,
			Position = UDim2.fromOffset(column * (each + gap), line * (shape.TabHigh + gap)),
			Size = UDim2.fromOffset(each, shape.TabHigh),
		})
		b.Root.ZIndex = 3
		local picture = landPicture(b.Root, land, Shop.Round.Button, 0)
		local shade: Frame = Kit.new("Frame", {
			Name = "Shade",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Kit.Deep,
			BackgroundTransparency = 0.68,
			BorderSizePixel = 0,
			ZIndex = 1, -- (over the painting, made before it; under the word)
		}, b.Root)
		Kit.corner(shade, Shop.Round.Button)
		for _, name in { "Studs", "Lip" } do
			local piece = b.Root:FindFirstChild(name)
			if piece then
				piece:Destroy() -- (a painting wears no studs)
			end
		end
		b.Root.Activated:Connect(function()
			pressTab(land)
		end)
		table.insert(tabs, {
			Button = b,
			Painting = picture,
			Shade = shade,
			Waiting = mark(b.Root, UDim2.new(1, -5, 0, 5), shape.Mark - 4, 6),
		})
	end
end

-- The shown land's banner: its painting, its name, and the COMPLETE box at its foot
local function buildBanner(tray: Frame, high: number)
	local banner: Frame = Kit.new("Frame", {
		Name = "LandSet",
		Position = UDim2.fromOffset(INNER, INNER),
		Size = UDim2.fromOffset(shape.Banner, high),
		BackgroundColor3 = Shop.BodyDeep,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, tray)
	Kit.corner(banner, Shop.Round.Card)
	Kit.stroke(banner, 4, Shop.Edge)
	painting, plainFill = landPicture(banner, shownLand, Shop.Round.Card, 1)
	-- a little dark behind the name, so white letters read over bright water (a painting only: paintLand)
	bannerShade = Kit.new("Frame", {
		Name = "Shade",
		Size = UDim2.fromScale(1, 0.42),
		BackgroundColor3 = Kit.Deep,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, banner)
	Kit.corner(bannerShade, Shop.Round.Card)
	Kit.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.55, 1) }, bannerShade)
	landWord = Shop.text(banner, {
		Name = "Land",
		Position = UDim2.fromOffset(2, 8),
		Size = UDim2.new(1, -4, 0, shape.LandText * 2 + 4),
		TextSize = shape.LandText,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 5,
	})
	local line = shape.BoxText + 8
	local barHigh = math.max(line + 4, 42) -- (its button, 44, is a finger tall on a phone)
	local title = shape.BoxText + 1
	local boxHigh = 7 + title + 3 + line * 2 + 4 + barHigh + 7
	local box: Frame = Kit.new("Frame", {
		Name = "Complete",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -7),
		Size = UDim2.new(1, -14, 0, boxHigh),
		BackgroundColor3 = Kit.Deep,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, banner)
	Kit.corner(box, Shop.Round.Card)
	boxEdge = Kit.stroke(box, 3, Shop.Edge)
	Shop.text(box, {
		Name = "Title",
		Position = UDim2.fromOffset(0, 7),
		Size = UDim2.new(1, 0, 0, title),
		TextSize = title - 3,
		TextColor3 = GOLD[1],
		Text = "COMPLETE",
		ZIndex = 6,
	})
	local at = 7 + title + 3
	landOxygen = amount(box, {
		Name = "Oxygen",
		Position = UDim2.fromOffset(0, at),
		Size = UDim2.new(1, 0, 0, line),
		ZIndex = 6,
	}, Kit.Textures.Oxygen, AIR, shape.BoxText)
	landCoins = amount(box, {
		Name = "Coins",
		Position = UDim2.fromOffset(0, at + line),
		Size = UDim2.new(1, 0, 0, line),
		ZIndex = 6,
	}, Kit.Textures.Cash, Shop.Money, shape.BoxText)
	local track, setLand = bar(box, {
		Name = "Bar",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 7, 1, -8),
		Size = UDim2.new(1, -14, 0, barHigh - 2),
		ZIndex = 6,
	}, GOLD, Shop.Round.Button)
	landTrack, setLandBar = track, setLand
	landCount = Shop.text(track, {
		Name = "Count",
		Size = UDim2.fromScale(1, 1),
		TextSize = shape.BoxText,
		ZIndex = 9,
	})
	landButton = Shop.button(box, {
		Name = "ClaimLand",
		Text = "CLAIM!",
		Kind = "Off",
		TextSize = shape.BoxText + 2,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 5, 1, -6),
		Size = UDim2.new(1, -10, 0, barHigh + 2),
	})
	landButton.Root.ZIndex = 8
	landButton.Root.Activated:Connect(pressLand)
end

-- The tray: the banner and the land's cards beside it
local function buildTray(body: Frame, at: Vector2, size: Vector2)
	local tray = Shop.inset(body, {
		Name = "Tray",
		Position = UDim2.fromOffset(at.X, at.Y),
		Size = UDim2.fromOffset(size.X, size.Y),
		ClipsDescendants = true,
		ZIndex = 2,
	})
	buildBanner(tray, size.Y - INNER * 2)
	local left = INNER + shape.Banner + INNER - 2
	list = Kit.new("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(left, 2),
		Size = UDim2.fromOffset(size.X - left - 4, size.Y - 4),
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
		CellSize = UDim2.fromOffset(shape.CardW, shape.CardH),
		CellPadding = UDim2.fromOffset(shape.CardGap, shape.CardGap),
		FillDirectionMaxCells = shape.Columns,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
	}, list)
	Kit.new("UIPadding", {
		PaddingLeft = UDim.new(0, 7),
		PaddingTop = UDim.new(0, LIST_PAD),
		PaddingBottom = UDim.new(0, LIST_PAD),
	}, list)
	toast = Kit.new("Frame", {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -40, 0, 46),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 12,
	}, tray)
	Kit.corner(toast, 5)
	Kit.stroke(toast, 3, Shop.Edge)
	toastFill = Kit.new("UIGradient", { Rotation = 90 }, toast)
	toastWord = Shop.text(toast, { Size = UDim2.fromScale(1, 1), TextSize = 24, ZIndex = 13 })
end

-- The fat bar: how many kinds are found of all there are, the book on its end
local function buildFoot(body: Frame, at: Vector2, wide: number)
	local foot: Frame = Kit.new("Frame", {
		Name = "Found",
		Position = UDim2.fromOffset(at.X, at.Y),
		Size = UDim2.fromOffset(wide, shape.Foot),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, body)
	local _, setFound = bar(foot, {
		Name = "Bar",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.new(1, -math.floor(shape.Foot * 0.5), 0, shape.Foot - 8),
		ZIndex = 3,
	}, BLUE, Shop.Round.Button)
	setFoundBar = setFound
	foundWord = Shop.text(foot, {
		Name = "Count",
		Size = UDim2.fromScale(1, 1),
		TextSize = shape.FootText,
		ZIndex = 6,
	})
	Kit.new("ImageLabel", {
		Name = "Book",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -4, 0.5, 0),
		Size = UDim2.fromOffset(shape.Foot + 12, shape.Foot + 12),
		Rotation = -8,
		BackgroundTransparency = 1,
		Image = Kit.Textures.Index,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 7,
	}, foot)
end

-- The chosen kind, big, in its rarity's colour
local function buildPanel(side: Frame, size: Vector2)
	panel = Kit.new("Frame", {
		Name = "Panel",
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = DARK_CARD,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, side)
	Kit.corner(panel, Shop.Round.Card)
	Kit.stroke(panel, 4, Shop.Edge).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	panelFill = Kit.new("UIGradient", { Rotation = 90 }, panel)
	Shop.pattern(panel, "Card")
	panelLine = Kit.new("Frame", {
		Name = "Rarity",
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 1, -8),
		BackgroundTransparency = 1,
		ZIndex = 4,
	}, panel)
	Kit.corner(panelLine, Shop.Round.Card - 1)
	panelLineFill = Kit.new("UIGradient", {}, Kit.stroke(panelLine, 4, Kit.White))
	-- from the foot up: the variants' plate, the rate, the rarity, the name; the picture has the rest
	local pillAt = size.Y - 10 - shape.Pill
	local rateAt = pillAt - 4 - (shape.Line + 4)
	local tierAt = if shape.OneLine then rateAt else rateAt - (shape.Line + 1)
	local edge = if shape.OneLine then PLATE else 4
	local nameAt = tierAt - (shape.Name + 2)
	panelPicture = Portrait.new(panel, {
		Name = "Picture",
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.fromOffset(size.X - 28, nameAt - 12),
		ZIndex = 5,
	})
	panelNone = Shop.text(panel, {
		Name = "None",
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.new(1, 0, 0, nameAt - 12),
		TextSize = 64,
		Text = "?",
		TextColor3 = PALE,
		Visible = false,
		ZIndex = 5,
	})
	nameWord = Shop.text(panel, {
		Name = "Name",
		Position = UDim2.fromOffset(4, nameAt),
		Size = UDim2.new(1, -8, 0, shape.Name + 2),
		TextSize = shape.Name,
		ZIndex = 6,
	})
	tierWord = Shop.text(panel, {
		Name = "Tier",
		Position = UDim2.fromOffset(edge, tierAt),
		Size = UDim2.new(1, -edge * 2, 0, shape.Line + 4),
		TextSize = shape.Line,
		TextXAlignment = if shape.OneLine then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
		ZIndex = 6,
	})
	tierFill = Kit.new("UIGradient", {}, tierWord)
	rateWord = Shop.text(panel, {
		Name = "Rate",
		Position = UDim2.fromOffset(edge, rateAt),
		Size = UDim2.new(1, -edge * 2, 0, shape.Line + 4),
		TextXAlignment = if shape.OneLine then Enum.TextXAlignment.Right else Enum.TextXAlignment.Center,
		TextSize = shape.Line + (if shape.OneLine then 0 else 3),
		TextColor3 = Shop.Money,
		ZIndex = 6,
	})
	local looks: Frame = Kit.new("Frame", {
		Name = "Variants",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, pillAt),
		Size = UDim2.new(1, -PLATE * 2, 0, shape.Pill),
		BackgroundColor3 = Shop.BodyDeep,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, panel)
	Kit.corner(looks, Shop.Round.Button)
	Kit.stroke(looks, 3, Shop.Edge)
	looksWord = Shop.text(looks, { Size = UDim2.fromScale(1, 1), TextSize = shape.Pill - 8, ZIndex = 7 })
end

-- What the chosen kind's first catch pays, and CLAIM!
local function buildRewards(side: Frame, at: Vector2, size: Vector2)
	local box = Shop.inset(side, {
		Name = "Rewards",
		Position = UDim2.fromOffset(at.X, at.Y),
		Size = UDim2.fromOffset(size.X, size.Y),
		ZIndex = 3,
	})
	rewardsEdge = box:FindFirstChildOfClass("UIStroke") :: UIStroke
	rewardsEdge.Thickness = 4
	local title = math.clamp(math.floor(shape.Line * 1.1), 20, 26)
	Shop.text(box, {
		Name = "Title",
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, title + 2),
		TextSize = title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Rewards",
		ZIndex = 4,
	})
	local claimAt = size.Y - 9 - shape.Claim
	local tileAt = 6 + title + 4 + math.max(0, (claimAt - 6 - (6 + title + 4) - shape.Tile) / 2)
	local tileWide = (size.X - 24 - 10) / 2
	kindOxygen = tile(box, {
		Name = "Oxygen",
		Position = UDim2.fromOffset(12, tileAt),
		Size = UDim2.fromOffset(tileWide, shape.Tile),
		ZIndex = 4,
	}, Kit.Textures.Oxygen, AIR, shape.Tile)
	kindCoins = tile(box, {
		Name = "Coins",
		Position = UDim2.fromOffset(12 + tileWide + 10, tileAt),
		Size = UDim2.fromOffset(tileWide, shape.Tile),
		ZIndex = 4,
	}, Kit.Textures.Cash, Shop.Money, shape.Tile)
	claimButton = Shop.button(box, {
		Name = "Claim",
		Text = "CLAIM!",
		Kind = "Off",
		TextSize = shape.ClaimText,
		Position = UDim2.fromOffset(12, claimAt),
		Size = UDim2.fromOffset(size.X - 24, shape.Claim),
	})
	claimButton.Root.ZIndex = 4
	claimButton.Root.Activated:Connect(pressClaim)
end

local function build()
	IndexBook.roster()
	built = shapeOf()
	shape = SHAPES[built]
	painted = nil
	local w = Shop.window({
		Name = "IndexPanel",
		Parent = State.Player:WaitForChild("PlayerGui"),
		Title = "Index",
		Head = HEAD,
		Gloss = true,
		Width = shape.Wide,
		Height = shape.High,
		OnClose = function()
			Shop.go(nil)
		end,
	})
	window = w

	-- the header: the book and the title at the left, CLAIM ALL beside the X
	local book = Shop.HeadHigh - 8
	Kit.new("ImageLabel", {
		Name = "Book",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, -2),
		Size = UDim2.fromOffset(book, book),
		Rotation = -8,
		BackgroundTransparency = 1,
		Image = Kit.Textures.Index,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 4,
	}, w.Header)
	w.Title.AnchorPoint = Vector2.new(0, 0.5)
	w.Title.Position = UDim2.new(0, book + 20, 0.5, -2)
	w.Title.Size = UDim2.new(1, -(book + 20 + shape.All + Shop.HeadHigh + 10), 1, -8)
	w.Title.TextSize = shape.Title
	w.Title.TextXAlignment = Enum.TextXAlignment.Left
	allButton = Shop.button(w.Header, {
		Name = "ClaimAll",
		Text = "CLAIM ALL (0)",
		Kind = "Off",
		TextSize = shape.AllText,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(Shop.HeadHigh + 4), 0.5, -2),
		Size = UDim2.fromOffset(shape.All, Shop.HeadHigh - 14),
		Shine = true, -- (the window's one money button)
	})
	allButton.Root.ZIndex = 5
	allButton.Root.Activated:Connect(pressAll)
	allArrow = LessonPrompt.arrow(allButton.Root, "Left")

	-- the body, in its own points (Shop.window's room: its pad at the sides, under the header and at the foot)
	local wide = shape.Wide + w.Body.Size.X.Offset
	local high = shape.High + w.Body.Size.Y.Offset
	local tabsHigh = shape.TabHigh * shape.TabRows + 7 * (shape.TabRows - 1)
	buildTabs(w.Body, wide, tabsHigh)
	local top = tabsHigh + GAP + 2
	local side: Frame = Kit.new("Frame", { Name = "Kind", BackgroundTransparency = 1, ZIndex = 2 }, w.Body)
	if built == "Tall" then
		local sideAt = high - shape.Side
		local footAt = sideAt - GAP - shape.Foot
		buildTray(w.Body, Vector2.new(0, top), Vector2.new(wide, footAt - GAP - top))
		buildFoot(w.Body, Vector2.new(0, footAt), wide)
		side.Position = UDim2.fromOffset(0, sideAt)
		side.Size = UDim2.fromOffset(wide, shape.Side)
		buildPanel(side, Vector2.new(wide - GAP - shape.Rewards, shape.Side))
		buildRewards(side, Vector2.new(wide - shape.Rewards, 0), Vector2.new(shape.Rewards, shape.Side))
	else
		local left = wide - shape.Side - GAP - 2
		buildTray(w.Body, Vector2.new(0, top), Vector2.new(left, high - shape.Foot - GAP - top))
		buildFoot(w.Body, Vector2.new(0, high - shape.Foot), left)
		local room = high - top
		side.Position = UDim2.fromOffset(wide - shape.Side, top)
		side.Size = UDim2.fromOffset(shape.Side, room)
		buildPanel(side, Vector2.new(shape.Side, room - GAP - 2 - shape.Rewards))
		buildRewards(side, Vector2.new(0, room - shape.Rewards), Vector2.new(shape.Side, shape.Rewards))
	end
	showLand(shownLand)
end

----------------------------------------------------------------------------------------------------------------------
-- For UI.IndexPanel

function IndexWindow.isOpen(): boolean
	return window ~= nil and window.isOpen()
end

IndexWindow.paint = function()
	paint()
end

-- Test hook: only the Studio checks and the offline check (tools/index/panel_test.luau) call this, through
-- IndexPanel.press. A press, as the player's: "Land", n | "Kind", fish id | "Claim" | "ClaimLand" | "ClaimAll".
function IndexWindow.press(what: string, arg: any?)
	if not IndexWindow.isOpen() then
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

-- Takes the window down (the look was changed, or the screen turned)
function IndexWindow.drop()
	local w = window
	if w then
		toastTurn += 1
		allArrow(false)
		w.show(false)
		w.Gui:Destroy()
		window = nil
		table.clear(tabs)
		table.clear(cards)
	end
end

local watching = false
local function watch()
	local camera = workspace.CurrentCamera
	if watching or not camera then
		return
	end
	watching = true
	-- a screen that turns while the window is open: the same window, laid out again
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if IndexWindow.isOpen() and shapeOf() ~= built then
			IndexWindow.drop()
			IndexWindow.open(true, true)
		end
	end)
end

-- Open or close the window. (turned: the same window again for a screen that turned, so what was shown stays.)
function IndexWindow.open(on: boolean, turned: boolean?)
	if on and window and not window.isOpen() and shapeOf() ~= built then
		IndexWindow.drop()
	end
	if not window then
		if not on then
			return
		end
		build()
		watch()
	end
	local w = window :: Shop.Window
	local opening = on and not w.isOpen()
	if opening then
		if not turned then
			-- the first land with a reward waiting, else the land last looked at
			for land = 1, #lands do
				if IndexBook.owedIn(land) > 0 then
					if land ~= shownLand then
						chosen = nil
						showLand(land)
					end
					break
				end
			end
			-- and its first kind with one, unless the kind last looked at has its own
			if not chosen or not IndexBook.owedKind(chosen) then
				chosen = firstOwed(shownLand) or chosen
			end
		end
		toastTurn += 1
		toast.Visible = false
		paint()
	end
	w.show(on)
	-- the cards pop in one after another as it opens
	if opening then
		popCards()
		task.defer(reveal)
		-- (once more at its full size: while the window springs open its list is shorter)
		task.delay(OPENED, reveal)
	end
end

return IndexWindow
