--!strict
-- The Fuse machine's window (Hugo, 2026-11-25; docs/design/fusing.md): put in three fish of one kind, see what comes out,
-- fuse. The biggest of the three stays and grows one size, the other two are used up. Built of the shop's kit (UI/Shop)
-- in the tinkerer's blue and purple (Shared/Keepers), drawn as the hub's machine: three pods with tubes into a core.
--   Left, the machine: the pods in the order they were filled (a press on one takes its fish out again), STAYS on the
--   one that stays and USED UP on the others once three are in, what comes out in the core, its size before and after
--   and what it earns, a red plate naming the special fish that would be used up (Shared/Fuse.special), and Fuse.
--   Right, the fish that can go in: from the server's own lists, "TankList" (the tank) and "Hands" (carried). Only kinds
--   with three that can; after the first pick only its kind. A fish of those kinds that can't go in (equipped, the ride
--   fish, already the top size) is shown last, dimmed, with the word across it.
--   Fuse asks "Sure?" once when a special fish would be used up; then Action "Fuse" with the three names, "T" and the
--   tank key or "H" and the carried key. Everything is decided by the server (FuseService): Ride "Fused" with what came
--   of it starts the show, "FuseDenied" says why not. What is shown before is Shared/Fuse's, the rules the server uses.
--   The show (Fuse.SwirlTime, HoldTime): the three swirl into the core, the bigger one comes out, bubbles at the machine
--   itself. A press anywhere skips it: the fusing was done before it began.
-- It opens when the player stands on the machine's floor ring and closes when they walk off (Controllers/StallController).
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Fuse = require(ReplicatedStorage.Shared.Fuse)
local Net = require(ReplicatedStorage.Shared.Net)
local Fx = require(script.Parent.Parent.Lib.Fx)
local State = require(script.Parent.Parent.Lib.State)
local Anim = require(script.Parent.Anim)
local Kit = require(script.Parent.Kit)
local Portrait = require(script.Parent.Portrait)
local Shop = require(script.Parent.Shop)

local FusePanel = {}

-- sizes in the window's own points (Shop.window fits them to the screen; its body is 836 by 450)
local WIDE, HIGH = 860, 540
local MACHINE = 404 -- the machine's width
local POD = 96
local PODS = { Vector2.new(66, 176), Vector2.new(202, 62), Vector2.new(338, 176) } -- their middles
local CORE, CORE_AT = 128, Vector2.new(202, 198)
local CARD_W, CARD_H = 128, 154
local GAP = 8
local SURE = 2.5 -- seconds Fuse asks "Sure?" before it is Fuse again
local SURE_LEAST = 0.35 -- a second press sooner than this is the same click
local ASK_WAIT = 3 -- seconds to wait for the server's answer
local TOAST = 2.6

local BLUE = Color3.fromRGB(58, 112, 224) -- the tinkerer's (Shared/Keepers.Colours)
local GLOW = Color3.fromRGB(255, 226, 110)
local FLOOR = Color3.fromRGB(26, 28, 62)
local GLASS = Color3.fromRGB(46, 50, 104)
local TUBE_OFF = Color3.fromRGB(62, 58, 112)
local PURPLE = Shop.Kinds.Purple[2]
local SOFT = Color3.fromRGB(214, 222, 236)
local LIGHT = Color3.fromRGB(236, 255, 230) -- a picked card's border

local SIZE_HUE: { [string]: Color3 } = { -- as the tank popup's and the fish tags' size words, cool to hot
	Tiny = Color3.fromRGB(150, 178, 204),
	Normal = Color3.fromRGB(176, 192, 214),
	Big = Color3.fromRGB(84, 226, 190),
	Giant = Color3.fromRGB(80, 182, 255),
	Huge = Color3.fromRGB(255, 160, 48),
	Colossal = Color3.fromRGB(255, 72, 80),
}
local TIER_RANK = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7 }

-- Why the server said no, in words
local DENIED: { [string]: string } = {
	Off = "THE MACHINE IS CLOSED",
	Dock = "COME BACK TO THE DOCK",
	Dead = "TRY AGAIN",
	Busy = "GET OFF YOUR RIDE FIRST",
	Far = "STAND AT THE MACHINE",
	Gone = "ONE OF THEM IS GONE",
	Equipped = "UNEQUIP IT FIRST",
	Ride = "YOU ARE RIDING THAT ONE",
	Kind = "3 OF THE SAME FISH",
	Size = "3 OF THE SAME SIZE",
	Top = "IT CAN'T GROW ANY MORE",
	Coins = "NOT ENOUGH COINS",
	Three = "PICK 3 FISH",
}
-- What is written across a fish that can't go in, and said when it is pressed
local BANDS: { [string]: string } = { Equipped = "Equipped", Ride = "Riding", Top = "Max size" }

type Fish = { Key: string, Id: string, Size: string, Variant: string, Bar: string?, Hand: boolean }
type Words = { Row: Frame, Size: TextLabel, Variant: TextLabel, Fill: UIGradient }
type Card = {
	Item: Shop.ItemCard,
	Edge: UIStroke,
	Words: Words,
	Picture: Portrait.Portrait,
	Tick: Frame,
	Veil: Frame,
	Band: TextLabel,
	Press: TextButton,
	Fish: Fish?,
}
type Plate = { Root: Frame, Word: TextLabel, Fill: UIGradient }
type Pod = {
	Root: Frame,
	Press: TextButton,
	Number: TextLabel,
	Picture: Portrait.Portrait,
	Size: Plate,
	Tag: Plate,
	Ring: UIStroke,
	Colour: UIGradient,
	Tube: UIGradient,
	Shown: string?,
}
type Flyer = { Root: Frame, Scale: UIScale, Picture: Portrait.Portrait, From: Vector2 }
type Show = { At: number, Out: boolean, Keep: number, Info: any }

local window: Shop.Window? = nil
local machine: Frame
local pods: { Pod } = {}
local flyers: { Flyer } = {}
local core: Frame
local coreQuestion: TextLabel
local coreFlash: Frame
local corePicture: Portrait.Portrait
local coreSize: Plate
local coreRing: UIStroke
local coreColour: UIGradient
local coreShown: string? = nil
local nameLine: TextLabel
local nameFill: UIGradient
local growRow: Frame
local growFrom: TextLabel
local growTo: TextLabel
local earnRow: Frame
local earnFrom: TextLabel
local earnTo: TextLabel
local hint: TextLabel
local warn: Frame
local warnWord: TextLabel
local fuseButton: Shop.Button
local skip: TextButton
local list: ScrollingFrame
local empty: TextLabel
local toast: Frame
local toastWord: TextLabel
local toastFill: UIGradient
local toastAt = -math.huge
local toastShown = false

local cards: { Card } = {}
local listed: { Fish } = {} -- the fish in the grid, in its order
local slots: { [number]: Fish } = {} -- what is in each pod
local sureAt, sureUntil = 0, 0
local asking: { Fish }? = nil -- the three asked for, until the answer
local askedAt = 0
local show: Show? = nil

----------------------------------------------------------------------------------------------------------------------
-- The fish: what the player has, and what can go in

local function decode(name: string): { any }
	local ok, rows = pcall(function()
		local value = State.Player:GetAttribute(name)
		return HttpService:JSONDecode(if type(value) == "string" then value else "[]")
	end)
	return if ok and type(rows) == "table" then rows else {}
end

-- Everything the player has, and why one can't go in (Bar; nil: it can)
local function read(): { Fish }
	local out: { Fish } = {}
	local function add(key: string, row: { any }, from: number, hand: boolean, bar: string?)
		local f: Fish = {
			Key = key,
			Id = tostring(row[from]),
			Size = tostring(row[from + 1] or "Normal"),
			Variant = tostring(row[from + 2] or ""),
			Bar = bar,
			Hand = hand,
		}
		local why = Fuse.refuses({}, f)
		if why == "Gone" then
			return
		end
		f.Bar = why or bar
		table.insert(out, f)
	end
	for _, row in decode("TankList") do
		if type(row) == "table" and row[1] ~= nil and type(row[2]) == "string" then
			local earns = row[5] == 1 and Config.Fuse.Earning == 0
			add("T" .. tostring(row[1]), row, 2, false, if earns then "Equipped" else nil)
		end
	end
	local ride = State.Player:GetAttribute("EquippedIndex")
	for i, row in decode("Hands") do
		if type(row) == "table" and type(row[1]) == "string" and row[4] ~= nil then
			add("H" .. tostring(row[4]), row, 1, true, if i == ride then "Ride" else nil)
		end
	end
	return out
end

local function tierOf(f: Fish): number
	local kind = Config.FishById[f.Id]
	return if kind then TIER_RANK[kind.Tier] or 0 else 0
end

-- The fish that must be together to fuse: a kind's, or a kind's of one size (Fuse.SameSize)
local function groupOf(f: Fish): string
	return if Config.Fuse.SameSize ~= 0 then f.Id .. "|" .. f.Size else f.Id
end

local function inSlot(key: string): number?
	for i = 1, Fuse.Count do
		local f = slots[i]
		if f and f.Key == key then
			return i
		end
	end
	return nil
end

-- What is in the pods, in their order
local function inside(): { Fish }
	local out = {}
	for i = 1, Fuse.Count do
		local f = slots[i]
		if f then
			table.insert(out, f)
		end
	end
	return out
end

-- The grid's fish: the groups with three that can go in, or with one in a pod its group alone; those that can't go in
-- come last. Also whether a group would have three but for the equipped ones.
local function choose(all: { Fish }): ({ Fish }, boolean)
	local free: { [string]: number } = {}
	local owned: { [string]: number } = {}
	for _, f in all do
		local group = groupOf(f)
		if not f.Bar then
			free[group] = (free[group] or 0) + 1
		end
		if f.Bar ~= "Top" then
			owned[group] = (owned[group] or 0) + 1
		end
	end
	local first = inside()[1]
	local out: { Fish } = {}
	local nearly = false
	for _, f in all do
		local group = groupOf(f)
		-- (a top-sized fish is shown beside its kind's others, whatever the group)
		local with = if f.Bar == "Top" then f.Id else group
		local enough = (free[with] or 0) >= Fuse.Count
		if first then
			enough = with == (if f.Bar == "Top" then first.Id else groupOf(first))
		end
		if enough then
			table.insert(out, f)
		elseif (owned[group] or 0) >= Fuse.Count then
			nearly = true
		end
	end
	table.sort(out, function(a: Fish, b: Fish): boolean
		if (a.Bar == nil) ~= (b.Bar == nil) then
			return a.Bar == nil
		end
		local x, y = tierOf(a), tierOf(b)
		if x ~= y then
			return x > y
		end
		if a.Id ~= b.Id then
			return a.Id < b.Id
		end
		local m, n = Fuse.rank(a.Size), Fuse.rank(b.Size)
		if m ~= n then
			return m > n
		end
		if a.Variant ~= b.Variant then
			return a.Variant > b.Variant
		end
		return a.Key < b.Key
	end)
	return out, nearly
end

local function earns(id: string, size: string, variant: string): number
	local kind = Config.FishById[id]
	return if kind then Config.incomeOf(kind, size, variant) else 0
end

local function nameOf(id: string): string
	local kind = Config.FishById[id]
	return if kind then kind.Name else id
end

local function busy(): boolean
	return asking ~= nil or show ~= nil
end

----------------------------------------------------------------------------------------------------------------------
-- Words: the toast, a fish's size and colour

local function say(text: string, good: boolean)
	local pair = if good then Shop.Kinds.Cash else Shop.Kinds.Red
	toastFill.Color = Shop.halves(pair[1], pair[2])
	toastWord.Text = text
	toastAt = os.clock()
	if toastShown then
		Anim.punch(toast, 1.08) -- a new line over one still up
	end
end

-- A word in a fish's colour (Silver, Gold, Rainbow), or hidden for a plain one
local function colourWord(label: TextLabel, fill: UIGradient, variant: string)
	local colours = Kit.variantFill(variant)
	fill.Enabled = colours ~= nil
	if colours then
		fill.Color = colours
	end
	label.Text = string.upper(variant)
	label.Visible = variant ~= ""
end

-- "BIG GOLD": a row of two labels
local function newWords(parent: Instance, props: { [string]: any }): Words
	local row: Frame = Kit.new("Frame", {
		Name = "Words",
		Position = props.Position,
		Size = props.Size,
		BackgroundTransparency = 1,
		ZIndex = props.ZIndex,
	}, parent)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	local function word(name: string, order: number): TextLabel
		return Shop.text(row, {
			Name = name,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			TextSize = props.TextSize,
			LayoutOrder = order,
			ZIndex = props.ZIndex + 1,
		})
	end
	local size = word("Size", 1)
	local variant = word("Variant", 2)
	local fill: UIGradient = Kit.new("UIGradient", { Enabled = false }, variant)
	return { Row = row, Size = size, Variant = variant, Fill = fill }
end

-- A small coloured plate with a word on it
local function newPlate(parent: Instance, props: { [string]: any }): Plate
	local root: Frame = Kit.new("Frame", {
		Name = props.Name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = props.Position,
		Size = props.Size,
		Rotation = props.Rotation or 0,
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = props.ZIndex,
	}, parent)
	Kit.corner(root, 5)
	Kit.stroke(root, 2.5, Shop.Edge)
	local fill: UIGradient = Kit.new("UIGradient", { Rotation = 90 }, root)
	local word = Shop.text(root, {
		Name = "Word",
		Size = UDim2.fromScale(1, 1),
		TextSize = props.TextSize or 15,
		ZIndex = props.ZIndex + 1,
	})
	return { Root = root, Word = word, Fill = fill }
end

local function setPlate(plate: Plate, text: string, top: Color3, bottom: Color3)
	plate.Word.Text = text
	plate.Fill.Color = Shop.halves(top, bottom)
	plate.Root.Visible = true
end

local function sizePlate(plate: Plate, size: string)
	local hue = SIZE_HUE[size] or Kit.White
	setPlate(plate, string.upper(size), hue, Kit.darker(hue, 0.16))
end

-- "HUGE GOLD" of a fish that would be used up, as on its card
local function specialWord(f: Fish): string
	return string.upper(if f.Variant ~= "" then f.Size .. " " .. f.Variant else f.Size)
end

----------------------------------------------------------------------------------------------------------------------
-- Showing it: the pods, the core, the lines under them and the grid

local update: () -> ()

local function setRing(ring: UIStroke, fill: UIGradient, variant: string, plain: Color3)
	local colours = Kit.variantFill(variant)
	fill.Enabled = colours ~= nil
	if colours then
		fill.Color = colours
	end
	ring.Color = if colours then Kit.White else plain
end

local function drawPod(i: number, f: Fish?, tag: string?)
	local pod = pods[i]
	pod.Number.Visible = f == nil
	pod.Picture.Frame.Visible = f ~= nil
	if f and pod.Shown ~= f.Id then
		pod.Shown = if pod.Picture.show(f.Id) then f.Id else nil
	end
	if f then
		sizePlate(pod.Size, f.Size)
	else
		pod.Size.Root.Visible = false
	end
	setRing(pod.Ring, pod.Colour, if f then f.Variant else "", if f then PURPLE else TUBE_OFF)
	pod.Tube.Color = if f
		then Shop.halves(Shop.Kinds.Purple[1], Shop.Kinds.Purple[2])
		else Shop.halves(TUBE_OFF, TUBE_OFF)
	if tag == "Stays" then
		setPlate(pod.Tag, "STAYS", Shop.Kinds.Cash[1], Shop.Kinds.Cash[2])
	elseif tag == "Used" then
		setPlate(pod.Tag, "USED UP", Shop.Kinds.Red[1], Shop.Kinds.Red[2])
	else
		pod.Tag.Root.Visible = false
	end
end

-- What is in the core: nothing yet ("?"), or the fish that comes out
local function drawCore(id: string?, size: string?, variant: string?)
	coreQuestion.Visible = id == nil
	corePicture.Frame.Visible = id ~= nil
	if id and coreShown ~= id then
		coreShown = if corePicture.show(id) then id else nil
	end
	if size then
		sizePlate(coreSize, size)
	else
		coreSize.Root.Visible = false
	end
	setRing(coreRing, coreColour, variant or "", if id then GLOW else BLUE)
	core.BackgroundTransparency = if id then 0 else 0.35
end

-- The lines under the machine: the fish, its size before and after, what it earns before and after
local function drawLines(id: string?, variant: string, from: string, to: string)
	local on = id ~= nil
	nameLine.Visible, growRow.Visible, earnRow.Visible = on, on, on
	if not id then
		return
	end
	nameLine.Text = if variant ~= "" then variant .. " " .. nameOf(id) else nameOf(id)
	local colours = Kit.variantFill(variant)
	nameFill.Enabled = colours ~= nil
	if colours then
		nameFill.Color = colours
	end
	growFrom.Text, growTo.Text = string.upper(from), string.upper(to)
	growFrom.TextColor3, growTo.TextColor3 = SIZE_HUE[from] or Kit.White, SIZE_HUE[to] or Kit.White
	earnFrom.Text = Kit.rate(earns(id, from, variant))
	earnTo.Text = Kit.rate(earns(id, to, variant))
end

-- The special fish that fusing these would use up
local function lost(three: { Fish }, outcome: Fuse.Outcome): { Fish }
	local out = {}
	for _, i in outcome.Used do
		if Fuse.special(three[i]) then
			table.insert(out, three[i])
		end
	end
	return out
end

local function drawMachine()
	local running = show
	if running then
		return -- (the show draws the machine itself)
	end
	local three = asking or inside()
	local outcome = Fuse.outcome(three :: any)
	for i = 1, Fuse.Count do
		local f: Fish? = if asking then asking[i] else slots[i]
		local tag: string? = nil
		if outcome then
			tag = if outcome.Keep == i then "Stays" else "Used"
		end
		drawPod(i, f, tag)
	end
	local warned = false
	if outcome then
		local stays = three[outcome.Keep]
		drawCore(stays.Id, outcome.To, stays.Variant)
		drawLines(stays.Id, stays.Variant, outcome.From, outcome.To)
		local words = {}
		for _, f in lost(three, outcome) do
			table.insert(words, specialWord(f))
		end
		warned = #words > 0
		if warned then
			warnWord.Text = "USES UP " .. table.concat(words, " + ")
		end
	else
		drawCore(nil, nil, nil)
		drawLines(nil, "", "", "")
	end
	warn.Visible = warned
	hint.Visible = outcome == nil
	local n = #three
	if asking then
		fuseButton.set("Fusing...", "Off", false)
	elseif outcome and os.clock() < sureUntil then
		fuseButton.set("Sure?", "Gold", true)
	elseif outcome then
		local price = Config.Fuse.Price
		fuseButton.set(if price > 0 then "Fuse  " .. Shop.cash(price) else "Fuse!", "Purple", true)
	else
		fuseButton.set(if n == 0 then "Pick 3 fish" else string.format("%d more", Fuse.Count - n), "Off", false)
	end
end

-- Puts a fish in the next free pod, or takes it out
local function pressFish(f: Fish)
	if busy() then
		return
	end
	local at = inSlot(f.Key)
	if at then
		slots[at] = nil
	else
		local why = f.Bar or Fuse.refuses(inside() :: any, f)
		if why == "Full" then
			say("THE MACHINE IS FULL", false)
			return
		elseif why then
			say(DENIED[why] or "IT CAN'T GO IN", false)
			return
		end
		for i = 1, Fuse.Count do
			if not slots[i] then
				slots[i] = f
				Anim.punch(pods[i].Root, 1.14)
				break
			end
		end
	end
	sureUntil = 0
	list.CanvasPosition = if #inside() <= 1 and not at then Vector2.zero else list.CanvasPosition
	update()
end

local function pressPod(i: number)
	if not busy() and slots[i] then
		slots[i] = nil
		sureUntil = 0
		update()
	end
end

local function newCard(): Card
	local item = Shop.itemCard(list, { Size = UDim2.fromOffset(CARD_W, CARD_H) })
	item.Name.TextTruncate = Enum.TextTruncate.AtEnd
	item.Name.TextSize = 16
	item.Name.Position = UDim2.fromOffset(7, 4)
	item.Name.Size = UDim2.new(1, -14, 0, 18)
	-- (no price here: nothing is sold)
	local strip = item.Root:FindFirstChild("PriceStrip")
	if strip and strip:IsA("GuiObject") then
		strip.Visible = false
	end
	item.Rate.Position = UDim2.new(0.5, 0, 1, -5)
	item.Rate.TextSize = 20
	local edge = item.Root:FindFirstChildOfClass("UIStroke") :: UIStroke
	local words = newWords(item.Root, {
		Position = UDim2.fromOffset(7, 22),
		Size = UDim2.new(1, -14, 0, 17),
		TextSize = 14,
		ZIndex = 4,
	})
	item.Picture.Position = UDim2.fromOffset(8, 40)
	item.Picture.Size = UDim2.new(1, -16, 1, -68)
	local picture = Portrait.new(item.Picture, { Size = UDim2.fromScale(1, 1), ZIndex = 2 })
	local tick: Frame = Kit.new("Frame", {
		Name = "Tick",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -5, 0, 40),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = Shop.Kinds.Cash[2],
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 6,
	}, item.Root)
	Kit.corner(tick, 999)
	Kit.stroke(tick, 2.5, Shop.Edge)
	Shop.check(tick, 7)
	local veil: Frame = Kit.new("Frame", {
		Name = "Veil",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Shop.BodyDeep,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 7,
	}, item.Root)
	Kit.corner(veil, 5)
	local band: Frame = Kit.new("Frame", {
		Name = "Band",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -12, 0, 26),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		Rotation = -6,
		ZIndex = 8,
	}, veil)
	Kit.corner(band, 4)
	Kit.stroke(band, 2.5, Shop.Edge)
	Kit.new("UIGradient", { Rotation = 90, Color = Shop.halves(Shop.Kinds.Blue[1], Shop.Kinds.Blue[2]) }, band)
	local bandWord = Shop.text(band, { Name = "Word", Size = UDim2.fromScale(1, 1), TextSize = 16, ZIndex = 9 })
	local press: TextButton = Kit.new("TextButton", {
		Name = "Press",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 10,
	}, item.Root)
	local card: Card = {
		Item = item,
		Edge = edge,
		Words = words,
		Picture = picture,
		Tick = tick,
		Veil = veil,
		Band = bandWord,
		Press = press,
		Fish = nil,
	}
	press.Activated:Connect(function()
		local f = card.Fish
		if f then
			pressFish(f)
		end
	end)
	return card
end

local function fillCard(card: Card, f: Fish, order: number)
	local old = card.Fish
	if not old or old.Id ~= f.Id then
		card.Picture.show(f.Id)
	end
	card.Fish = f
	local kind = Config.FishById[f.Id]
	local entry = Config.Tiers[if kind then kind.Tier else "Common"]
	local colour = if entry then entry.Colour else Kit.White
	-- (the Secret's own colour is near black: on the dark card its name is pink)
	if colour.R + colour.G + colour.B < 0.6 then
		colour = Kit.Pink
	end
	card.Item.Root.LayoutOrder = order
	card.Item.Name.Text = nameOf(f.Id)
	card.Item.Name.TextColor3 = colour
	card.Words.Size.Text = string.upper(f.Size)
	card.Words.Size.TextColor3 = SIZE_HUE[f.Size] or Kit.White
	colourWord(card.Words.Variant, card.Words.Fill, f.Variant)
	card.Item.Rate.Text = Kit.rate(earns(f.Id, f.Size, f.Variant))
	local on = inSlot(f.Key) ~= nil
	card.Tick.Visible = on
	card.Veil.Visible = f.Bar ~= nil
	card.Band.Text = BANDS[f.Bar or ""] or ""
	card.Edge.Color = if on then LIGHT else Shop.Edge
	card.Edge.Thickness = if on then 4 else 3
	card.Item.Root.Visible = true
end

function update()
	if not window then
		return
	end
	local all = read()
	if not busy() then
		-- a fish in a pod that is gone, or can't go in now, is taken out; one that changed is shown as it is
		local now: { [string]: Fish } = {}
		for _, f in all do
			now[f.Key] = f
		end
		for i = 1, Fuse.Count do
			local f = slots[i]
			if f then
				local fresh = now[f.Key]
				if fresh and not fresh.Bar and fresh.Id == f.Id then
					slots[i] = fresh
				else
					slots[i] = nil
					sureUntil = 0
				end
			end
		end
	end
	local nearly
	listed, nearly = choose(all)
	for i, f in listed do
		local card = cards[i]
		if not card then
			card = newCard()
			cards[i] = card
		end
		fillCard(card, f, i)
	end
	for i = #listed + 1, #cards do
		cards[i].Item.Root.Visible = false
		cards[i].Fish = nil
	end
	empty.Visible = #listed == 0 and show == nil
	if #listed == 0 then
		local same = if Config.Fuse.SameSize ~= 0 then "of the same kind and size" else "of the same kind"
		empty.Text = if nearly
			then "The ones in your tank are earning.\nUnequip them to fuse them."
			else string.format("You need %d fish %s.\nCatch more!", Fuse.Count, same)
	end
	drawMachine()
end

----------------------------------------------------------------------------------------------------------------------
-- Fusing: the press, the server's answer, and the show

-- Where the machine stands in the world (its core; else its ring), for the bubbles
local function coreInWorld(): Vector3?
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local dock = blockout and blockout:FindFirstChild("Dock")
	local stations = dock and dock:FindFirstChild("Stations")
	local station = stations and stations:FindFirstChild("Fuse")
	local part = station and (station:FindFirstChild("Core", true) or station:FindFirstChild("Ring"))
	return if part and part:IsA("BasePart") then part.Position else nil
end

local function endShow()
	if not show then
		return
	end
	show = nil
	skip.Visible = false
	coreFlash.BackgroundTransparency = 1
	for _, flyer in flyers do
		flyer.Root.Visible = false
	end
	core.Size = UDim2.fromOffset(CORE, CORE)
	table.clear(slots)
	update()
end

-- The bigger one comes out of the core
local function comeOut(s: Show)
	s.Out = true
	for _, flyer in flyers do
		flyer.Root.Visible = false
	end
	local info = s.Info
	for i = 1, Fuse.Count do
		drawPod(i, nil, nil)
	end
	core.Size = UDim2.fromOffset(CORE + 8, CORE + 8)
	drawCore(info.Id, info.To, info.Variant)
	drawLines(info.Id, info.Variant, info.From, info.To)
	coreFlash.BackgroundTransparency = 0
	Anim.punch(core, 1.5)
	Anim.punch(growRow, 1.2)
	fuseButton.set("Done!", "Cash", false)
	say(string.format("YOUR %s IS %s NOW!", string.upper(nameOf(info.Id)), string.upper(info.To)), true)
	local at = coreInWorld()
	if at then
		Fx.burst(at, 40, 0.4, 6)
		Fx.ring(CFrame.new(at), GLOW)
	end
end

local function startShow(three: { Fish }, info: any)
	local keep = 1
	for i, f in three do
		if f.Key == info.Pick then
			keep = i
		end
	end
	show = { At = os.clock(), Out = false, Keep = keep, Info = info }
	skip.Visible = true
	warn.Visible = false
	for i, f in three do
		local pod = pods[i]
		local flyer = flyers[i]
		pod.Picture.Frame.Visible = false
		pod.Size.Root.Visible = false
		pod.Tag.Root.Visible = false
		flyer.Picture.show(f.Id)
		flyer.Scale.Scale = 1
		flyer.Root.Position = UDim2.fromOffset(flyer.From.X, flyer.From.Y)
		flyer.Root.Visible = true
	end
	drawCore(nil, nil, nil)
	coreQuestion.Visible = false
	drawLines(nil, "", "", "")
	fuseButton.set("Fusing...", "Off", false)
end

-- One look of the show: t seconds in
local function stepShow(s: Show, t: number)
	local swirl = math.max(Config.Fuse.SwirlTime, 0.01)
	if t < swirl then
		local a = t / swirl
		local fall = a * a -- slow off, fast in
		for i, flyer in flyers do
			local arm = flyer.From - CORE_AT
			local reach = arm.Magnitude * (1 - fall)
			local turn = math.atan2(arm.Y, arm.X) + fall * math.pi * 2.5
			flyer.Root.Position =
				UDim2.fromOffset(CORE_AT.X + math.cos(turn) * reach, CORE_AT.Y + math.sin(turn) * reach)
			flyer.Scale.Scale = if i == s.Keep then 1 - 0.25 * fall else 1 - 0.9 * fall
		end
		local beat = CORE + 10 * a * (1 + math.sin(t * 22))
		core.Size = UDim2.fromOffset(beat, beat)
		coreFlash.BackgroundTransparency = 1 - 0.85 * fall
		return
	end
	if not s.Out then
		comeOut(s)
	end
	local out = t - swirl
	coreFlash.BackgroundTransparency = math.clamp(out / 0.35, 0, 1)
	if out >= Config.Fuse.HoldTime then
		endShow()
	end
end

-- A press while the show plays: to the bigger one coming out, then to its end
local function pressSkip()
	local s = show
	if not s then
		return
	end
	if s.Out then
		endShow()
	else
		s.At = os.clock() - math.max(Config.Fuse.SwirlTime, 0.01)
		stepShow(s, math.max(Config.Fuse.SwirlTime, 0.01))
	end
end

local function pressFuse()
	if busy() then
		return
	end
	local three = inside()
	local outcome = Fuse.outcome(three :: any)
	if not outcome then
		return
	end
	local now = os.clock()
	if #lost(three, outcome) > 0 then
		if now > sureUntil then
			sureAt, sureUntil = now, now + SURE
			Anim.punch(warn, 1.1)
			update()
			return
		elseif now - sureAt < SURE_LEAST then
			return
		end
	end
	sureUntil = 0
	asking, askedAt = three, now
	update()
	local picks = {}
	for _, f in three do
		table.insert(picks, f.Key)
	end
	Net.Action:FireServer("Fuse", picks)
end

local function answered(kind: string, what: any)
	local three = asking
	if kind == "Fused" and type(what) == "table" then
		asking = nil
		local w = window
		if three and w and w.isOpen() and type(what.Id) == "string" and SIZE_HUE[what.To] then
			startShow(three, what)
		end
		-- (the grid is the server's new list at once; the machine is the show's till it ends)
		table.clear(slots)
		update()
	elseif kind == "FuseDenied" and three then
		asking = nil
		say(DENIED[what] or "IT DIDN'T WORK", false)
		update()
	end
end

----------------------------------------------------------------------------------------------------------------------
-- Building the window

-- A tube from a pod to the core, under both
local function newTube(from: Vector2, to: Vector2): UIGradient
	local way = to - from
	local tube: Frame = Kit.new("Frame", {
		Name = "Tube",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((from.X + to.X) / 2, (from.Y + to.Y) / 2),
		Size = UDim2.fromOffset(way.Magnitude, 22),
		Rotation = math.deg(math.atan2(way.Y, way.X)),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, machine)
	Kit.stroke(tube, 3, Shop.Edge)
	return Kit.new("UIGradient", { Rotation = 90, Color = Shop.halves(TUBE_OFF, TUBE_OFF) }, tube)
end

local function newPod(i: number): Pod
	local at = PODS[i]
	local tube = newTube(at, CORE_AT)
	local root: Frame = Kit.new("Frame", {
		Name = "Pod" .. i,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(at.X, at.Y),
		Size = UDim2.fromOffset(POD, POD),
		BackgroundColor3 = Shop.Edge,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, machine)
	Kit.corner(root, 999)
	Kit.stroke(root, 3, Shop.Edge)
	local glass: Frame = Kit.new("Frame", {
		Name = "Glass",
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -12),
		BackgroundColor3 = GLASS,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, root)
	Kit.corner(glass, 999)
	local ring = Kit.stroke(glass, 5, TUBE_OFF)
	local colour: UIGradient = Kit.new("UIGradient", { Enabled = false }, ring)
	local number = Shop.text(glass, {
		Name = "Number",
		Size = UDim2.fromScale(1, 1),
		TextSize = 46,
		TextColor3 = Color3.fromRGB(150, 146, 214),
		Text = tostring(i),
		ZIndex = 5,
	})
	local picture = Portrait.new(glass, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.fromScale(0.86, 0.86),
		ZIndex = 5,
	})
	local size = newPlate(root, {
		Name = "Size",
		Position = UDim2.new(0.5, 0, 1, -3),
		Size = UDim2.fromOffset(88, 24),
		TextSize = 15,
		ZIndex = 7,
	})
	local tag = newPlate(root, {
		Name = "Tag",
		Position = UDim2.fromScale(0.5, 0.06),
		Size = UDim2.fromOffset(86, 24),
		TextSize = 15,
		Rotation = -5,
		ZIndex = 8,
	})
	local press: TextButton = Kit.new("TextButton", {
		Name = "Press",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 10,
	}, root)
	press.Activated:Connect(function()
		pressPod(i)
	end)
	return {
		Root = root,
		Press = press,
		Number = number,
		Picture = picture,
		Size = size,
		Tag = tag,
		Ring = ring,
		Colour = colour,
		Tube = tube,
		Shown = nil,
	}
end

local function newFlyer(i: number): Flyer
	local at = PODS[i]
	local root: Frame = Kit.new("Frame", {
		Name = "Flyer" .. i,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(at.X, at.Y),
		Size = UDim2.fromOffset(POD - 14, POD - 14),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 14,
	}, machine)
	return {
		Root = root,
		Scale = Anim.scaleOf(root),
		Picture = Portrait.new(root, { Size = UDim2.fromScale(1, 1), ZIndex = 14 }),
		From = at,
	}
end

-- "a -> b": two labels with an arrow between them, in the middle of the machine
local function newRow(name: string, y: number, high: number, size: number): (Frame, TextLabel, TextLabel)
	local row: Frame = Kit.new("Frame", {
		Name = name,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, high),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 5,
	}, machine)
	local function word(which: string, left: boolean): TextLabel
		return Shop.text(row, {
			Name = which,
			Position = if left then UDim2.new() else UDim2.new(0.5, 22, 0, 0),
			Size = UDim2.new(0.5, -22, 1, 0),
			TextSize = size,
			TextXAlignment = if left then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left,
			ZIndex = 6,
		})
	end
	Shop.arrow(row, 0, high * 0.84, UDim2.fromScale(0.5, 0.5), 6)
	return row, word("From", true), word("To", false)
end

local function buildMachine(body: Frame)
	machine = Shop.inset(body, {
		Name = "Machine",
		Size = UDim2.new(0, MACHINE, 1, 0),
		BackgroundColor3 = FLOOR,
		ZIndex = 2,
	})
	for i = 1, Fuse.Count do
		pods[i] = newPod(i)
	end
	core = Kit.new("Frame", {
		Name = "Core",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(CORE_AT.X, CORE_AT.Y),
		Size = UDim2.fromOffset(CORE, CORE),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, machine)
	Kit.corner(core, 999)
	Kit.stroke(core, 3, Shop.Edge)
	Kit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Kit.lighter(GLOW, 0.5), GLOW) }, core)
	local glass: Frame = Kit.new("Frame", {
		Name = "Glass",
		Position = UDim2.fromOffset(9, 9),
		Size = UDim2.new(1, -18, 1, -18),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, core)
	Kit.corner(glass, 999)
	Kit.new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Kit.lighter(PURPLE, 0.25), Kit.darker(PURPLE, 0.25)),
	}, glass)
	coreRing = Kit.stroke(glass, 6, BLUE)
	coreColour = Kit.new("UIGradient", { Enabled = false }, coreRing)
	coreQuestion = Shop.text(glass, {
		Name = "Question",
		Size = UDim2.fromScale(1, 1),
		TextSize = 66,
		Text = "?",
		ZIndex = 6,
	})
	corePicture = Portrait.new(glass, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.fromScale(0.9, 0.9),
		ZIndex = 6,
	})
	coreFlash = Kit.new("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Kit.White,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 9,
	}, core)
	Kit.corner(coreFlash, 999)
	coreSize = newPlate(core, {
		Name = "Size",
		Position = UDim2.new(0.5, 0, 1, -3),
		Size = UDim2.fromOffset(112, 28),
		TextSize = 19,
		ZIndex = 10,
	})
	for i = 1, Fuse.Count do
		flyers[i] = newFlyer(i)
	end

	nameLine = Shop.text(machine, {
		Name = "Fish",
		Position = UDim2.fromOffset(10, 280),
		Size = UDim2.new(1, -20, 0, 24),
		TextSize = 21,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Visible = false,
		ZIndex = 6,
	})
	nameFill = Kit.new("UIGradient", { Enabled = false }, nameLine)
	growRow, growFrom, growTo = newRow("Grow", 303, 30, 26)
	earnRow, earnFrom, earnTo = newRow("Earn", 332, 22, 19)
	earnFrom.TextColor3, earnTo.TextColor3 = Shop.Money, Shop.Money
	hint = Shop.text(machine, {
		Name = "Hint",
		Position = UDim2.fromOffset(24, 284),
		Size = UDim2.new(1, -48, 0, 84),
		TextSize = 18,
		TextWrapped = true,
		TextColor3 = SOFT,
		Text = "The biggest one grows a size\nand keeps its own colour.\nThe other two are used up.",
		ZIndex = 6,
	})
	warn = Kit.new("Frame", {
		Name = "Warn",
		Position = UDim2.fromOffset(10, 358),
		Size = UDim2.new(1, -20, 0, 30),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 6,
	}, machine)
	Kit.corner(warn, 5)
	Kit.stroke(warn, 2.5, Shop.Edge)
	Kit.new("UIGradient", { Rotation = 90, Color = Shop.halves(Shop.Kinds.Red[1], Shop.Kinds.Red[2]) }, warn)
	warnWord = Shop.text(warn, { Name = "Word", Size = UDim2.fromScale(1, 1), TextSize = 17, ZIndex = 7 })
	fuseButton = Shop.button(machine, {
		Name = "Fuse",
		Text = "Pick 3 fish",
		Kind = "Off",
		TextSize = 30,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -9),
		Size = UDim2.new(1, -20, 0, 46),
		Live = false,
		Shine = true,
	})
	fuseButton.Root.ZIndex = 6
	fuseButton.Root.Activated:Connect(pressFuse)
end

local function buildList(body: Frame)
	local left = MACHINE + 10
	Shop.text(body, {
		Name = "Heading",
		Position = UDim2.fromOffset(left, 0),
		Size = UDim2.new(1, -left, 0, 30),
		TextSize = 25,
		Text = if Config.Fuse.SameSize ~= 0 then "Pick 3 of the same fish and size" else "Pick 3 of the same fish",
		ZIndex = 3,
	})
	local tray = Shop.inset(body, {
		Name = "Tray",
		Position = UDim2.fromOffset(left, 36),
		Size = UDim2.new(1, -left, 1, -36),
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
		ScrollBarImageColor3 = BLUE,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ZIndex = 3,
	}, tray)
	Kit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(CARD_W, CARD_H),
		CellPadding = UDim2.fromOffset(GAP, GAP),
		FillDirectionMaxCells = 3,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
	}, list)
	Kit.new("UIPadding", {
		PaddingLeft = UDim.new(0, 4),
		PaddingTop = UDim.new(0, 5),
		PaddingBottom = UDim.new(0, 8),
	}, list)
	empty = Shop.text(tray, {
		Name = "Empty",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.new(1, -40, 0, 100),
		TextSize = 22,
		TextWrapped = true,
		TextColor3 = SOFT,
		Visible = false,
		ZIndex = 4,
	})
	toast = Kit.new("Frame", {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -24, 0, 38),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 12,
	}, tray)
	Kit.corner(toast, 5)
	Kit.stroke(toast, 3, Shop.Edge)
	toastFill = Kit.new("UIGradient", { Rotation = 90 }, toast)
	toastWord = Shop.text(toast, { Name = "Word", Size = UDim2.fromScale(1, 1), TextSize = 17, ZIndex = 13 })
end

local function build()
	local w = Shop.window({
		Name = "FusePanel",
		Parent = State.Player:WaitForChild("PlayerGui"),
		Title = "Fuse Fish",
		Head = BLUE,
		Width = WIDE,
		Height = HIGH,
		Dim = true,
		OnClose = function()
			Shop.go(nil)
		end,
	})
	buildMachine(w.Body)
	buildList(w.Body)
	skip = Kit.new("TextButton", {
		Name = "Skip",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		Visible = false,
		ZIndex = 30,
	}, w.Body)
	skip.Activated:Connect(pressSkip)

	for _, name in { "TankList", "Hands", "EquippedIndex" } do
		State.Player:GetAttributeChangedSignal(name):Connect(function()
			if w.isOpen() then
				update()
			end
		end)
	end
	Net.Ride.OnClientEvent:Connect(function(kind: string, what: any)
		if kind == "Fused" or kind == "FuseDenied" then
			answered(kind, what)
		end
	end)
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		-- (an answer that never came, the window open or not)
		if asking and now - askedAt > ASK_WAIT then
			asking = nil
			say("TRY AGAIN", false)
			update()
		end
		if not w.isOpen() then
			return
		end
		local s = show
		if s then
			stepShow(s, now - s.At)
		end
		local up = now - toastAt < TOAST
		if toastShown ~= up then
			toastShown = up
			Anim.toast(toast, up)
		end
		-- "Sure?" runs out by itself
		if sureUntil ~= 0 and now > sureUntil then
			sureUntil = 0
			update()
		end
	end)
	window = w
end

-- A press, for the checks (a script can't click): "Card", its place in the grid | "Pod", its number | "Fuse" | "Skip"
-- Test hook: only tools/fuse and Studio checks call this.
function FusePanel.press(what: string, index: number?)
	if not FusePanel.isOpen() then
		return
	end
	if what == "Card" then
		local card = cards[index or 0]
		if card and card.Fish then
			pressFish(card.Fish)
		end
	elseif what == "Pod" then
		pressPod(index or 0)
	elseif what == "Fuse" then
		pressFuse()
	elseif what == "Skip" then
		pressSkip()
	end
end

function FusePanel.isOpen(): boolean
	return window ~= nil and window.isOpen()
end

-- Open or close the window. (Through Shop.go("Fuse"), so another dock window closes.)
function FusePanel.open(on: boolean)
	if not window then
		if not on then
			return
		end
		build()
	end
	local w = window :: Shop.Window
	local opening = on and not w.isOpen()
	if not on then
		endShow()
	end
	if opening then
		table.clear(slots)
		sureUntil = 0
		toastAt = -math.huge
		list.CanvasPosition = Vector2.zero
		update()
	end
	w.show(on)
	if opening then
		local shown = {}
		for _, card in cards do
			if card.Fish then
				table.insert(shown, card.Item.Root :: GuiObject)
			end
		end
		Anim.stagger(shown)
	end
end

Shop.page("Fuse", FusePanel.open)

return FusePanel
