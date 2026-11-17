--!strict
-- A tag over each of the nearest wild fish, stacked as the reference stacks its own: the rarity in its colour, the
-- name, and what the fish needs (the bubble and a number). Ours: the number is green on a fish you can hold and on a
-- red plate on one too strong for you (a landing on that one is never refused: your whole meter empties in a quarter
-- of a second and it throws you off, Oxygen.StrainTime); and the locked fish's tag is a quarter bigger and, in the
-- hop, says how long it holds, or that it is too strong.
-- The number is what the fish needs in the land it swims in now (Config.required), the rule the server judges a
-- landing by. A fish that has strayed into a deeper land needs more there than at home.
-- A handful of tags, made once and moved from fish to fish. The fish are looked over a few times a second, never per
-- frame, and a label's text is set only when its fish changes.
-- The tags are frames on the screen, put over their fish each frame (six points turned from the world to the screen).
-- They were BillboardGuis first: those attached to the fish and reported themselves on, but drew nothing in Studio
-- (2026-11-12), so they are drawn the way the rest of the HUD is.
-- A herd is the usual case, so tags mustn't pile up: they are placed nearest first (the locked fish before all), and
-- a tag whose words would land on one already placed is left out until the next look. More fish are tagged than can
-- show at once so that leaving some out still leaves a few to read.
-- What a fish needs is the only warning the player gets before a hop (the game marks nothing while you ride, and a
-- fish too strong throws you off at once), so that line is never the part that is lost:
--   a fish too strong to hold has its "Needs" on a red plate, the number in white;
--   a far fish's tag is only the bubble and the number, at a size that still reads (the whole tag shrunk with
--   distance was too small to read);
--   a near fish whose whole tag has no room shows just the bubble and the number, before it is left out.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Archetypes = require(ReplicatedStorage.Shared.Archetypes)
local Config = require(ReplicatedStorage.Shared.Config)
local Zones = require(ReplicatedStorage.Shared.Zones)
local Kit = require(script.Parent.Kit)
local State = require(script.Parent.Parent.Lib.State)

local Tags = {}

local POOL = 10
local REACH = 260 -- studs: fish further off get no tag
local PERIOD = 0.25 -- seconds between looks at the herd
local QUICK = 0.08 -- and the soonest another look comes when the locked fish changes
-- the room a tag's words take at size 1, to tell when two would land on each other (the frame itself is wider)
local WORDS_WIDE = 118
local WORDS_HIGH = 51
local HOLD_HIGH = 14 -- the extra line on the locked fish in the hop
-- the line of a fish's passive archetypes, when it has any: one icon each, side by side (docs/design/archetypes.md;
-- the icons replaced the words, Hugo, 2026-11-13). Sized to read at riding distance: about twice the name's letters.
-- A fish with only one has it on the name's own line instead, left of the name, the two centred as one (Hugo,
-- 2026-11-13: "next to the fish name on the left, unless its 2+"); that icon is a little taller than the letters, and
-- the name's line grows by LEAD_HIGH to hold it
local KIND_ICON = 22
local KIND_HIGH = KIND_ICON + 3
local LEAD_ICON = 18
local LEAD_HIGH = 3
local NAME_HIGH = 16
local SMALL_WIDE = 62 -- the same for a tag that is only the bubble and the number
local SMALL_HIGH = 21
local FAR = 110 -- studs: from here on a tag is only the bubble and the number
-- The reference marks no animal while you still ride, only once you are in the air, and the game follows it
-- (Config.Lock.Preview 0: nothing is locked until the hop). Were the lock shown while riding again, true here would
-- give the locked fish its bigger tag then too.
local LOCKED_WHILE_RIDING = false

type Tag = {
	Frame: Frame,
	Offset: Vector3, -- from the fish's middle to where the tag's foot sits, above its back
	Scale: UIScale,
	Tier: TextLabel,
	TierGradient: UIGradient,
	Name: TextLabel,
	Head: Frame, -- the name's line: the name, and left of it the icon of a fish with one archetype
	Kind: Frame, -- the line under the name, an icon each (Archetypes.icons), for a fish with two or more
	KindOf: Config.FishType?, -- the fish's kind, for its own seconds (a Tank holds longer)
	KindHigh: number, -- the height its icons add to the tag (0 with none)
	NeedWord: TextLabel,
	Need: TextLabel,
	Plate: Frame,
	PlateEdge: UIStroke,
	Hold: TextLabel,
	Fish: Model?,
	TierName: string,
	Needs: number, -- the number written on it
	Size: number,
	State: number,
	HoldText: string,
	Locked: boolean,
	Far: boolean,
	Small: boolean, -- drawn as only the bubble and the number
	FullSize: number, -- its size as a whole tag, and as only the number
	SmallSize: number,
	Extra: number, -- the height of the extra line, when it has one
	Rank: number, -- its place in the queue for room on the screen: lower goes first
	Crowded: boolean, -- left out this look: its words would land on a nearer fish's
	X: number, -- where its foot was on the screen at the last look, and the room its words took
	Y: number,
	Wide: number,
	High: number,
}

local tags: { Tag } = {}
local order: { Tag } = table.create(POOL)
local picks: { Model } = table.create(POOL)
local reach: { number } = table.create(POOL)
local picked = 0
local sinceLook = math.huge
local lastLocked: Model? = nil
local hudScale = 1

local NEED = { Kit.Good, Kit.Sun, Color3.fromRGB(255, 100, 104) }
-- the rarities in order, for the options' "rare" fish (Epic and up are seen from further; Legendary and up glow)
local RANK = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7 }
local RARE = 4
local SHINY = 5

local function make(parent: Instance): Tag
	local root: Frame = Kit.new("Frame", {
		Name = "FishTag",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(260, 80),
		BackgroundTransparency = 1,
		Visible = false,
	}, parent)
	local scale: UIScale = Kit.new("UIScale", {}, root)
	Kit.new("UIListLayout", {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, root)
	-- The rows don't lap over each other (they did, by 3: a list's padding is not sized with the tag, so on a small
	-- tag the red plate covered the lower half of the name, 2026-11-12). The rarity's row is a little short for its
	-- letters, which only brings it closer to the name; the plate sits at the bottom of a taller row, clear of the
	-- name's tails.
	-- (the rarity is the biggest line, as the reference's; the name a little smaller under it)
	local tier = Kit.text({ Size = UDim2.fromOffset(260, 15), TextSize = 14, LayoutOrder = 1 }, root)
	local tierGradient = Kit.gradient(tier, Kit.White, Kit.White)
	-- the name's line: the name sized to its words, so that one archetype's icon sits just left of it and the two are
	-- centred together (the name alone stays centred). 260 wide holds the longest name and the icon with room to spare
	local head: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(260, NAME_HIGH),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
	}, root)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 3),
	}, head)
	-- (Archetypes.icons puts its icon at LayoutOrder 1, before the name)
	local name = Kit.text({
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, NAME_HIGH),
		TextSize = 13,
		LayoutOrder = 2,
	}, head)
	-- two or more archetypes, as icons under the name: you know what a fish does before you hop on it
	local kindLine: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(260, KIND_HIGH),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Visible = false,
	}, root)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, kindLine)
	local needRow = Kit.new("Frame", {
		Size = UDim2.fromOffset(260, 20),
		BackgroundTransparency = 1,
		LayoutOrder = 4,
	}, root)
	-- the plate round what the fish needs: clear, and red when the fish is too strong to hold
	local plate: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 17),
		BackgroundColor3 = Kit.Danger,
		BackgroundTransparency = 1,
	}, needRow)
	Kit.corner(plate, 999)
	Kit.new("UIGradient", { Color = ColorSequence.new(Kit.White, Color3.fromRGB(150, 120, 130)), Rotation = 90 }, plate)
	local plateEdge = Kit.stroke(plate, 2, Kit.Ink)
	plateEdge.Enabled = false
	Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, plate)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, plate)
	local needWord = Kit.text({
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 15),
		TextSize = 10.5,
		Text = "Needs",
		LayoutOrder = 1,
	}, plate)
	Kit.bubble(plate, 11).LayoutOrder = 2
	local need = Kit.text({
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 15),
		TextSize = 12,
		LayoutOrder = 3,
	}, plate)
	local hold = Kit.text({
		Size = UDim2.fromOffset(260, 15),
		TextSize = 11.5,
		LayoutOrder = 5,
		Visible = false,
	}, root)
	return {
		Frame = root,
		Offset = Vector3.zero,
		Scale = scale,
		Tier = tier,
		TierGradient = tierGradient,
		Name = name,
		Head = head,
		Kind = kindLine,
		KindOf = nil,
		KindHigh = 0,
		NeedWord = needWord,
		Need = need,
		Plate = plate,
		PlateEdge = plateEdge,
		Hold = hold,
		Fish = nil,
		TierName = "",
		Needs = -1,
		Size = 0,
		State = 0,
		HoldText = "",
		Locked = false,
		Far = false,
		Small = false,
		FullSize = 1,
		SmallSize = 1,
		Extra = 0,
		Rank = 0,
		Crowded = false,
		X = 0,
		Y = 0,
		Wide = 0,
		High = 0,
	}
end

local function clear(tag: Tag)
	tag.Fish = nil
	tag.Crowded = false
	tag.Frame.Visible = false
end

local function put(tag: Tag, fish: Model)
	local kind = Config.FishById[fish:GetAttribute("FishType") :: string]
	local root = fish.PrimaryPart
	if not kind or not root then
		return
	end
	tag.Fish = fish
	-- this fish's size and variant before its name, as the reference's tags have them ("GIANT Gold Great White"); a
	-- Normal size isn't named
	local variant = Config.variantOf(fish)
	local size = Config.sizeTierOf(fish)
	local name = kind.Name
	if variant ~= "" then
		name = variant .. " " .. name
	end
	if size ~= "Normal" then
		name = string.upper(size) .. " " .. name
	end
	tag.Offset = Vector3.new(0, Config.bodyOf(fish, kind).Y * 0.5 + 2.5, 0)
	tag.Name.Text = name
	local line = if Config.ArchetypeFeel.Tags > 0 then Archetypes.line(kind) else ""
	local count = if line == "" then 0 else #string.split(line, ",")
	tag.KindOf = kind
	-- one: its icon left of the name; two or more: a row under the name; none: the name alone
	Archetypes.icons(tag.Head, if count == 1 then line else "", LEAD_ICON)
	Archetypes.icons(tag.Kind, if count >= 2 then line else "", KIND_ICON)
	tag.Head.Size = UDim2.fromOffset(260, if count == 1 then NAME_HIGH + LEAD_HIGH else NAME_HIGH)
	tag.KindHigh = if count >= 2 then KIND_HIGH elseif count == 1 then LEAD_HIGH else 0
	tag.Kind.Visible = count >= 2 and not tag.Small
	tag.TierName = kind.Tier
	tag.Tier.Text = kind.Tier
	Kit.tierColours(tag.Tier, tag.TierGradient, kind.Tier, Config.Tiers)
	tag.Needs = -1
	tag.State = 0
end

-- A tag as the whole stack or as only the bubble and the number, at its size: written only when it changes
local function shape(tag: Tag, small: boolean)
	if small ~= tag.Small then
		tag.Small = small
		tag.Tier.Visible = not small
		tag.Head.Visible = not small
		tag.NeedWord.Visible = not small
	end
	local kindShown = not small and tag.KindHigh >= KIND_HIGH
	if tag.Kind.Visible ~= kindShown then
		tag.Kind.Visible = kindShown
	end
	local size = if small then tag.SmallSize else tag.FullSize
	if size ~= tag.Size then
		tag.Size = size
		tag.Scale.Scale = size * hudScale
	end
end

-- The room its words take on the screen, as the whole stack or as only the number
local function room(tag: Tag, small: boolean)
	local size = (if small then tag.SmallSize else tag.FullSize) * hudScale
	tag.Wide = (if small then SMALL_WIDE else WORDS_WIDE) * size
	tag.High = (if small then SMALL_HIGH else WORDS_HIGH + tag.Extra + tag.KindHigh) * size
end

-- Whether its words would land on one of the tags placed before it
local function clash(tag: Tag, before: number): boolean
	for j = 1, before do
		local placed = order[j]
		if
			not placed.Crowded
			and math.abs(tag.X - placed.X) < (tag.Wide + placed.Wide) / 2
			and tag.Y - tag.High < placed.Y
			and placed.Y - placed.High < tag.Y
		then
			return true
		end
	end
	return false
end

-- Where the locked fish's tag goes: over the fish, but kept on the screen. A locked fish can be under the rider or
-- behind the camera (the fish just left can be grabbed again), and its tag was then off the screen: the hop button
-- said GRAB and no tag said what (2026-11-12). Held inside the edges, clear of the strip of lands and the slots; a
-- fish behind the camera has its tag at the bottom, on the side it is on.
local AIM_CLEAR = 34 -- the aim's ring and a little air, from the middle of the screen, in the HUD's units
-- Whether a tag with its foot at x, y would touch the aim's ring
local function underAim(x: number, y: number, wide: number, high: number, camera: Camera): boolean
	local size = camera.ViewportSize
	local ring = AIM_CLEAR * hudScale
	return math.abs(x - size.X / 2) < wide / 2 + ring and y > size.Y / 2 - ring and y - high < size.Y / 2 + ring
end
local function pin(wide: number, high: number, point: Vector3, camera: Camera): (number, number)
	local size = camera.ViewportSize
	local side = wide / 2 + 8 * hudScale
	local x, y = point.X, point.Y
	if point.Z <= 0 then
		x = size.X - x
		y = size.Y
	end
	x = math.clamp(x, side, math.max(size.X - side, side))
	y = math.clamp(y, high + 64 * hudScale, math.max(size.Y - 92 * hudScale, high + 64 * hudScale))
	-- Clear of the aim at the middle of the screen. In a hop the locked fish is often dead ahead, so its tag sat
	-- under the aim's ring: the ring covered what the fish needs, and the tag covered the rider (the survey of
	-- 2026-11-16). A tag that would touch the ring sits just above it.
	if underAim(x, y, wide, high, camera) then
		y = size.Y / 2 - AIM_CLEAR * hudScale
	end
	return x, y
end

-- Each tag over its fish, every frame: the one thing here that runs per frame
local function follow(camera: Camera)
	for _, tag in tags do
		local fish = tag.Fish
		local root = fish and fish.PrimaryPart
		if root and tag.Locked then
			local x, y = pin(tag.Wide, tag.High, camera:WorldToViewportPoint(root.Position + tag.Offset), camera)
			tag.Frame.Visible = true
			tag.Frame.Position = UDim2.fromOffset(x, y)
		elseif root and not tag.Crowded then
			local point = camera:WorldToViewportPoint(root.Position + tag.Offset)
			local onScreen = point.Z > 0
			tag.Frame.Visible = onScreen
			if onScreen then
				tag.Frame.Position = UDim2.fromOffset(point.X, point.Y)
			end
		elseif fish then
			tag.Frame.Visible = false
		end
	end
end

-- The nearest free fish ahead of the camera, nearest first, into picks (no table is made)
local function look(camera: Camera, ridden: Model?, locked: Model?, rareReach: number?)
	picked = 0
	local eye = camera.CFrame.Position
	local ahead = camera.CFrame.LookVector
	local folder = workspace:FindFirstChild("Fish")
	if not folder then
		return
	end
	for _, fish in folder:GetChildren() do
		if fish ~= ridden and fish ~= locked and fish:IsA("Model") and State.isFreeFish(fish) then
			local root = fish.PrimaryPart
			if root then
				local to = root.Position - eye
				local distance = to.Magnitude
				local inReach = distance < REACH
				if not inReach and rareReach and distance < rareReach then
					local kind = Config.FishById[fish:GetAttribute("FishType") :: string]
					inReach = kind ~= nil and (RANK[kind.Tier] or 0) >= RARE
				end
				if inReach and to:Dot(ahead) > distance * 0.25 then
					-- insert by distance, keeping the nearest POOL - 1
					local at = picked + 1
					while at > 1 and reach[at - 1] > distance do
						at -= 1
					end
					if at <= POOL - 1 then
						local last = math.min(picked + 1, POOL - 1)
						for i = last, at + 1, -1 do
							picks[i] = picks[i - 1]
							reach[i] = reach[i - 1]
						end
						picks[at] = fish
						reach[at] = distance
						picked = last
					end
				end
			end
		end
	end
end

local function wanted(fish: Model, locked: Model?): boolean
	if fish == locked then
		return true
	end
	for i = 1, picked do
		if picks[i] == fish then
			return true
		end
	end
	return false
end

local function tagged(fish: Model): boolean
	for _, tag in tags do
		if tag.Fish == fish then
			return true
		end
	end
	return false
end

local function give(fish: Model)
	for _, tag in tags do
		if not tag.Fish then
			put(tag, fish)
			return
		end
	end
end

-- ===================================================================================================================
-- The options (Hugo, 2026-11-14: "attract the player more and feel less clumped"; docs/design/ui.md, "Fish tag
-- options"). Kit.FishTags picks one: 0 is the stacked tag above, 1 to 6 the looks here. Every look has one line that
-- leads (the name, or the plate it is on), shows the rarity by colour instead of a word, and gives far or crowded
-- fish less than the whole tag. A tag is in one of three shapes:
--   whole: the name's line (a rarity gem, the archetype icons, the name) and the price;
--   name: the name's line without the price;
--   mark: only the rarity gem, with the price if the look keeps it far off.
-- A crowded tag steps down (whole or name to mark, mark to left out), as the stacked tag does.

export type Look = {
	Name: string,
	Plate: string, -- "": words on the world; "glass": a dark see-through plate edged in the rarity; "ribbon": a plate
	-- filled with the rarity's colours
	NameSize: number,
	NameTier: boolean, -- the name in its rarity's colours (else white)
	TierWord: boolean, -- the rarity's word, small, over the whole tag of the fish in focus
	Gem: boolean, -- the rarity gem left of the name on a whole tag too (a mark is always the gem)
	IconsLeft: number, -- up to this many archetype icons sit left of the name; more go in a row under it
	IconSize: number,
	ChipUnder: boolean, -- the price on its own line under the name (else at the end of the name's line)
	Focus: boolean, -- only the fish in focus (locked, or nearest the middle of the screen) is whole; the rest are marks
	NameFrom: number?, -- studs from which a tag is only the name
	MarkFrom: number, -- studs from which a tag is only the mark
	FarPrice: boolean, -- a mark keeps the price
	ReachPrice: boolean, -- the price only on a fish within the hook's longest reach (Config.Jump.GrabRange)
	Bright: boolean, -- a fish you can hold: its price on a green chip
	Dim: boolean, -- a fish too strong: its name faded
	RareReach: number?, -- Epic and up are tagged this far (the stacked tag: REACH for all)
	Glow: boolean, -- Legendary and up: a soft glow round the plate, or round the gem of a mark
	Pad: number, -- room kept clear round each tag, in points
	Stack: boolean?, -- the three-line tag (7): the rarity's word and icons, the name in white, "Required:"
	ChipClear: boolean?, -- what the fish needs on no plate (a plate only when it is too strong)
}

Tags.Looks = {
	{
		Name = "One line: the name in its rarity's colours, the price beside it",
		Plate = "",
		NameSize = 16,
		NameTier = true,
		TierWord = false,
		Gem = false,
		IconsLeft = 3,
		IconSize = 18,
		ChipUnder = false,
		Focus = false,
		MarkFrom = 110,
		FarPrice = true,
		ReachPrice = false,
		Bright = false,
		Dim = false,
		Glow = false,
		Pad = 6,
	},
	{
		Name = "A dark glass plate edged in the rarity's colour",
		Plate = "glass",
		NameSize = 15,
		NameTier = false,
		TierWord = false,
		Gem = false,
		IconsLeft = 3,
		IconSize = 17,
		ChipUnder = false,
		Focus = false,
		MarkFrom = 110,
		FarPrice = true,
		ReachPrice = false,
		Bright = false,
		Dim = false,
		Glow = true,
		Pad = 6,
	},
	{
		Name = "Only the fish in focus is whole; every other fish is a gem and its price",
		Plate = "",
		NameSize = 18,
		NameTier = true,
		TierWord = true,
		Gem = false,
		IconsLeft = 1,
		IconSize = 20,
		ChipUnder = true,
		Focus = true,
		MarkFrom = 0,
		FarPrice = true,
		ReachPrice = false,
		Bright = false,
		Dim = false,
		Glow = true,
		Pad = 4,
	},
	{
		Name = "By distance: near whole, then the name, far a gem; rare fish seen from far",
		Plate = "",
		NameSize = 16,
		NameTier = true,
		TierWord = false,
		Gem = false,
		IconsLeft = 3,
		IconSize = 18,
		ChipUnder = false,
		Focus = false,
		NameFrom = 70,
		MarkFrom = 150,
		FarPrice = false,
		ReachPrice = false,
		Bright = false,
		Dim = false,
		RareReach = 420,
		Glow = true,
		Pad = 6,
	},
	{
		Name = "Can I take it: the price only in reach, green if yes, the name faded if not",
		Plate = "",
		NameSize = 15,
		NameTier = false,
		TierWord = false,
		Gem = true,
		IconsLeft = 3,
		IconSize = 17,
		ChipUnder = false,
		Focus = false,
		MarkFrom = 150,
		FarPrice = false,
		ReachPrice = true,
		Bright = true,
		Dim = true,
		Glow = true,
		Pad = 6,
	},
	{
		Name = "A ribbon in the rarity's colours, the price hanging under it",
		Plate = "ribbon",
		NameSize = 15,
		NameTier = false,
		TierWord = false,
		Gem = false,
		IconsLeft = 3,
		IconSize = 18,
		ChipUnder = true,
		Focus = false,
		MarkFrom = 110,
		FarPrice = true,
		ReachPrice = false,
		Bright = false,
		Dim = false,
		Glow = true,
		Pad = 6,
	},
	{
		-- Hugo, 2026-11-14, his own layout after sheet 1: "RARITY (class icons) / NAME / Required: n Oxygen icon",
		-- the names white, each rarity's word with "a cool design like in ride a dino"
		Name = "Three lines: the rarity's word and icons, the name in white, Required and the bubble",
		Plate = "",
		NameSize = 16,
		NameTier = false,
		TierWord = true,
		Gem = false,
		IconsLeft = 9,
		IconSize = 18,
		ChipUnder = true,
		Focus = false,
		MarkFrom = 110,
		FarPrice = true,
		ReachPrice = false,
		Bright = false,
		Dim = false,
		Glow = true,
		Pad = 5,
		Stack = true,
		ChipClear = true,
	},
} :: { Look }

local WHOLE, NAME, MARK = 1, 2, 3
local WIDE = 340 -- the frame of a tag in the options: wide enough for the longest name and its icons
local CHIP_HIGH = 19
local GEM = 11
-- the three-line tag (7): each line's height, the room between them, the icons on line 1, the stars by the word
local STACK_TOP = 22
local STACK_NAME = 19
local STACK_REQ = 18
local STACK_GAP = 3
local STACK_ICON = 18
local SPARK = 7
local REQ_SIZE = 12
local NUMBER_SIZE = 14
local BUBBLE = 13

-- a rarity as one colour (an edge, a glow): its own, or the middle of gold, the ember and the rainbow
local function solid(tier: string): Color3
	if tier == "Legendary" then
		return Color3.fromRGB(255, 200, 40)
	elseif tier == "Mythic" then
		return Color3.fromRGB(255, 80, 110)
	elseif tier == "Secret" then
		return Color3.fromRGB(200, 140, 255)
	end
	local entry = Config.Tiers[tier]
	return if entry then entry.Colour else Kit.White
end

-- the pieces only the options 1 to 6 have
type OptParts = {
	Word: TextLabel,
	WordFill: UIGradient,
	Halo: UIStroke,
	Card: Frame,
	CardFill: UIGradient,
	CardEdge: UIStroke,
	GemBox: Frame,
	GemFill: UIGradient,
	GemGlow: Frame,
	Lead: Frame,
	NameFill: UIGradient,
	Under: Frame,
	ChipRow: Frame,
}

-- the pieces only the three-line tag (7) has: line 1 the rarity's word and the archetype icons, line 3 "Required:"
type StackParts = {
	Word: TextLabel,
	WordFill: UIGradient,
	Glow: TextLabel, -- the same word behind it, in the rarity's colour with a wide soft edge: its glow
	GlowEdge: UIStroke,
	Sparks: { Frame }, -- a small star either side of the word, Legendary and up
	Icons: Frame,
	Req: TextLabel,
	ChipEdge: UIStroke,
	WordSize: number,
	WordWide: number,
	Turn: number, -- the word's gradient's own turn, which the shimmer swings about
	Top: Frame, -- line 1
	Holder: Frame, -- r1's word and glow
	-- a designed style's layers (WordStyle), in Art
	Art: Frame,
	Plate: Frame,
	PlateFill: UIGradient,
	PlateEdge: UIStroke,
	PlateEdgeFill: UIGradient,
	PlateHalo: Frame,
	PlateSweep: UIGradient,
	PlateShine: Frame,
	AGlow: TextLabel,
	AGlowEdge: UIStroke,
	Drops: { TextLabel },
	DropEdges: { UIStroke },
	Main: TextLabel,
	MainFill: UIGradient,
	MainEdge: UIStroke,
	MainEdgeFill: UIGradient,
	Gloss: TextLabel,
	GlossFill: UIGradient,
	Shine: TextLabel,
	ShineFill: UIGradient,
	Style: WordStyle?,
	-- the row under the word: the fish's size chip, then its archetype icons
	Row: Frame,
	RowOn: boolean,
	RowWide: number,
	SizeSlot: Frame,
	SizePill: Frame,
	SizePillFill: UIGradient,
	SizeEdge: UIStroke,
	SizeGloss: Frame,
	SizeGlossFill: UIGradient,
	SizeHalos: { Frame },
	SizeGems: { Frame },
	SizePips: { Frame },
	SizeWord: TextLabel,
	SizeWordFill: UIGradient,
	SizeWide: number,
	-- the size as a sticker on the word's top-left corner (Kit.SizeChip 4)
	Sticker: Frame,
	StickerGlow: TextLabel,
	StickerGlowEdge: UIStroke,
	StickerDrop: TextLabel,
	StickerDropEdge: UIStroke,
	StickerMain: TextLabel,
	StickerFill: UIGradient,
	StickerEdge: UIStroke,
	StickerShine: TextLabel,
	SparkWide: number,
	Animated: boolean,
}

type Alt = {
	Frame: Frame,
	Scale: UIScale,
	Name: TextLabel,
	Chip: Frame,
	Need: TextLabel,
	Hold: TextLabel,
	Opt: OptParts?,
	Stk: StackParts?,
	Offset: Vector3,
	Fish: Model?,
	KindOf: Config.FishType?,
	TierName: string,
	Rare: number,
	Needs: number,
	State: number,
	HoldText: string,
	NameWide: number,
	LeadCount: number,
	UnderCount: number,
	Locked: boolean,
	Focus: boolean,
	Want: number, -- the shape it would have with room
	Shape: number, -- the shape it is drawn in
	Size: number,
	Extra: number,
	Distance: number,
	Rank: number,
	Crowded: boolean,
	Point: Vector3, -- its foot on the screen at the last look (and how far in front)
	X: number,
	Y: number,
	Wide: number,
	High: number,
	Drawn: string, -- what was last written to it, so nothing is written twice
}

local alts: { Alt } = {}
local altOrder: { Alt } = table.create(POOL)

-- The rarity's word grows with the rarity, as the reference's does: the lower ones their colour with the dark edge,
-- from Rare a glow of their colour round the letters, from Legendary bigger, two stars and a shimmer (the gradient
-- swings), the Secret's rainbow turning. Size, then the glow's width and how see-through it is (nil: none)
local WORD_SIZE = { 14, 14, 15, 15.5, 16.5, 17, 17.5 }
local WORD_GLOW: { { number }? } = { nil, nil, { 3.5, 0.72 }, { 4.5, 0.6 }, { 5.5, 0.5 }, { 6, 0.45 }, { 6.5, 0.4 } }
local REQ_WIDE = 0 -- "Required:" at REQ_SIZE, measured once

-- The rarity word's designed styles (Hugo, 2026-11-14: "improve upon the rarity text, needs different font and they
-- all need a look with highlights shading and gradients"; ui.md, "Rarity word options"). Behind Kit.RarityWords: the
-- game keeps r1's word until Hugo picks. Each is layers of the same word, all from what Roblox ships (no upload):
-- a plate behind (a gradient pill with a lit top), a soft glow, one to three darker copies under it (the letters'
-- depth), the word in a gradient (its shading), a white copy cut to its top half (the highlight), and a thin white
-- line across it, still or sweeping. Four families, one per column of the sheet, each growing richer with the rarity:
--   1 Candy (Luckiest Guy): soft light-to-dark letters, a dark edge, a gloss on the top half, depth under them;
--   2 Chrome (Gotham Black): hard metal shading split at the middle, an edge of the rarity's darkest, a shine line;
--   3 Comic (Bangers): pale letters with a thick edge in the rarity's own gradient, a dark shadow down and right;
--   4 Badge (Denk One): white letters on a plate of the rarity's colours, the plate lit on top.
export type WordStyle = {
	Font: Enum.Font,
	Size: number,
	Fill: ColorSequence,
	FillTurn: number,
	Edge: Color3,
	EdgeThick: number,
	EdgeFill: ColorSequence?, -- the edge itself in a gradient (nil: Edge)
	Drops: number, -- darker copies under the word, each a step further
	DropColour: Color3,
	DropEdge: Color3,
	DropStep: Vector2,
	Gloss: number?, -- how see-through the white top half is (nil: none)
	Shine: number?, -- how see-through the thin white line is (nil: none)
	Sweep: boolean, -- the line sweeps across now and then instead of staying still
	Glow: { number }?, -- the soft edge's width and how see-through
	GlowColour: Color3,
	Plate: ColorSequence?, -- a plate behind the word
	PlateEdge: Color3,
	PlateEdgeFill: ColorSequence?,
	PlateGlow: number?, -- a soft halo round the plate, how see-through
	Sparks: boolean,
	Spin: boolean, -- the fill (or the edge, when the edge is the rainbow) turns round
	Tight: boolean, -- the word's box hugs its letters (its edge and glow spill over), so line 1 keeps the name's spacing
	Anim: string?, -- family 5's own motion: "gold" (Legendary), "ember" (Mythic), "prism" (Secret); nil: none
}

type Pal = { Light: Color3, Mid: Color3, Dark: Color3, Deep: Color3, Fill: ColorSequence? }

local function seq(points: { any }): ColorSequence
	local keys = {}
	for i = 1, #points, 2 do
		table.insert(keys, ColorSequenceKeypoint.new(points[i], points[i + 1]))
	end
	return ColorSequence.new(keys)
end

local rgb = Color3.fromRGB
local RAINBOW = seq({
	0,
	rgb(255, 96, 120),
	0.18,
	rgb(255, 176, 70),
	0.36,
	rgb(255, 240, 100),
	0.54,
	rgb(100, 236, 140),
	0.72,
	rgb(90, 190, 255),
	0.88,
	rgb(170, 120, 255),
	1,
	rgb(255, 96, 200),
})
-- each rarity's four tones: the lit top, its own colour, the shade, the deepest (edges, depth)
local PAL: { [string]: Pal } = {
	Common = { Light = rgb(252, 253, 255), Mid = rgb(198, 206, 218), Dark = rgb(128, 140, 160), Deep = rgb(58, 66, 84) },
	Uncommon = { Light = rgb(222, 255, 180), Mid = rgb(104, 224, 84), Dark = rgb(34, 160, 64), Deep = rgb(14, 80, 40) },
	Rare = { Light = rgb(200, 238, 255), Mid = rgb(76, 168, 255), Dark = rgb(36, 94, 226), Deep = rgb(18, 40, 124) },
	Epic = { Light = rgb(244, 210, 255), Mid = rgb(186, 98, 255), Dark = rgb(118, 46, 216), Deep = rgb(58, 18, 120) },
	Legendary = {
		Light = rgb(255, 252, 200),
		Mid = rgb(255, 208, 48),
		Dark = rgb(238, 128, 16),
		Deep = rgb(122, 52, 6),
	},
	Mythic = { Light = rgb(255, 210, 180), Mid = rgb(255, 72, 98), Dark = rgb(192, 22, 106), Deep = rgb(92, 8, 56) },
	Secret = {
		Light = rgb(255, 255, 255),
		Mid = rgb(200, 140, 255),
		Dark = rgb(110, 60, 200),
		Deep = rgb(26, 14, 46),
		Fill = RAINBOW,
	},
}
local WHITE = Kit.White

local function soft(p: Pal): ColorSequence
	return p.Fill or seq({ 0, p.Light, 0.5, p.Mid, 1, p.Dark })
end

local function base(p: Pal): WordStyle
	return {
		Font = Enum.Font.LuckiestGuy,
		Size = 15,
		Fill = soft(p),
		FillTurn = if p.Fill then 0 else 90,
		Edge = Kit.Ink,
		EdgeThick = 2.4,
		EdgeFill = nil,
		Drops = 1,
		DropColour = p.Deep,
		DropEdge = Kit.Ink,
		DropStep = Vector2.new(0, 1.5),
		Gloss = nil,
		Shine = nil,
		Sweep = false,
		Glow = nil,
		GlowColour = p.Mid,
		Plate = nil,
		PlateEdge = Kit.Ink,
		PlateEdgeFill = nil,
		PlateGlow = nil,
		Sparks = false,
		Spin = false,
		Tight = false,
		Anim = nil,
	}
end

local GROW = { 0, 0, 1, 1.5, 2.5, 3, 3.5 } -- each rarity's word this much bigger than the Common's
local secret = function(r: number): boolean
	return r == 7
end

local FAMILIES: { (r: number, p: Pal) -> WordStyle } = {
	-- 1 Candy
	function(r, p)
		local s = base(p)
		s.Size = 19 + GROW[r]
		s.Drops = if r >= 4 then 2 else 1
		s.Gloss = 0.5 - 0.035 * r
		s.Glow = if r >= 3 then { 2.5 + 0.6 * r, 0.86 - 0.05 * r } else nil
		s.Sweep = r >= 5
		s.Shine = if r >= 5 then 0.15 else nil
		s.Sparks = r >= 5
		s.Spin = secret(r)
		return s
	end,
	-- 2 Chrome
	function(r, p)
		local s = base(p)
		s.Font = Enum.Font.GothamBlack
		s.Size = 17 + GROW[r]
		if secret(r) then
			-- the void: near-black metal with the rainbow round it
			s.Fill =
				seq({ 0, rgb(236, 226, 255), 0.47, rgb(170, 146, 230), 0.53, rgb(70, 46, 130), 1, rgb(120, 90, 200) })
			s.FillTurn = 90
			s.EdgeFill = RAINBOW
			s.Edge = WHITE
			s.GlowColour = rgb(200, 140, 255)
		else
			s.Fill = seq({
				0,
				Kit.lighter(p.Light, 0.5),
				0.48,
				p.Light:Lerp(p.Mid, 0.3),
				0.52,
				p.Mid,
				1,
				p.Mid:Lerp(p.Dark, 0.6),
			})
			s.Edge = Kit.darker(p.Deep, 0.25)
		end
		s.EdgeThick = 2.2
		s.Drops = if r >= 4 then 3 else 2
		s.DropColour = Kit.darker(p.Deep, 0.3)
		s.DropEdge = Kit.darker(p.Deep, 0.45)
		s.DropStep = Vector2.new(0, 1.2)
		s.Shine = 0.1
		s.Sweep = r >= 6
		s.Glow = if r >= 4 then { 2 + 0.7 * r, 0.9 - 0.05 * r } else nil
		s.Sparks = r >= 6
		s.Spin = secret(r)
		return s
	end,
	-- 3 Comic
	function(r, p)
		local s = base(p)
		s.Font = Enum.Font.Bangers
		s.Size = 22 + GROW[r]
		s.Fill = seq({ 0, WHITE, 0.55, Kit.lighter(p.Light, 0.3), 1, p.Light })
		s.FillTurn = 90
		s.Edge = p.Dark
		s.EdgeThick = 3
		s.EdgeFill = if p.Fill then RAINBOW else seq({ 0, p.Mid, 1, p.Dark })
		s.Drops = 1
		s.DropColour = Kit.Ink
		s.DropEdge = Kit.Ink
		s.DropStep = Vector2.new(1.6, 2.4)
		s.Gloss = if r >= 3 then 0.55 else nil
		s.Glow = if r >= 3 then { 3 + 0.6 * r, 0.86 - 0.05 * r } else nil
		s.Sweep = r >= 5
		s.Shine = if r >= 5 then 0.2 else nil
		s.Sparks = r >= 5
		s.Spin = secret(r)
		return s
	end,
	-- 4 Badge
	function(r, p)
		local s = base(p)
		s.Font = Enum.Font.DenkOne
		s.Size = 16 + GROW[r] * 0.8
		s.Fill = seq({ 0, WHITE, 1, Kit.lighter(p.Light, 0.2) })
		s.FillTurn = 90
		s.EdgeThick = 2
		s.Drops = 1
		s.DropColour = p.Deep
		s.DropStep = Vector2.new(0, 1.3)
		if secret(r) then
			s.Plate = seq({ 0, rgb(70, 50, 110), 0.5, rgb(26, 14, 46), 1, rgb(10, 6, 20) })
			s.PlateEdgeFill = RAINBOW
			s.Fill = RAINBOW
			s.FillTurn = 0
		else
			s.Plate = seq({ 0, p.Mid:Lerp(p.Light, 0.35), 0.5, p.Mid, 1, p.Dark })
		end
		s.Gloss = nil
		s.Shine = if r >= 4 then 0.25 else nil
		s.Sweep = r >= 4
		s.PlateGlow = if r >= 5 then 0.55 else nil
		s.Sparks = r >= 5
		s.Spin = secret(r)
		return s
	end,
	-- 5 Live (Gotham Black; Hugo, 2026-11-14: "use the gotham black and make sure legendary + are animated and
	-- integrated"): Chrome's metal shading split at the middle, but edged in the name's own ink so the word and the
	-- name read as one tag; one dark step of depth; a glow of its colour from Rare; a still shine line on Epic; from
	-- Legendary each top rarity moves in its own way (shimmer: "gold", "ember", "prism")
	function(r, p)
		local s = base(p)
		s.Font = Enum.Font.GothamBlack
		s.Size = 15.5 + GROW[r]
		if secret(r) then
			s.Fill = RAINBOW
			s.FillTurn = 0
			s.GlowColour = rgb(200, 140, 255)
		else
			s.Fill = seq({
				0,
				Kit.lighter(p.Light, 0.5),
				0.48,
				p.Light:Lerp(p.Mid, 0.35),
				0.52,
				p.Mid,
				1,
				p.Mid:Lerp(p.Dark, 0.55),
			})
			s.FillTurn = 90
		end
		s.Edge = Kit.Ink
		s.EdgeThick = 2.4
		s.Drops = 1
		s.DropColour = Kit.darker(p.Deep, 0.2)
		s.DropEdge = Kit.Ink
		s.DropStep = Vector2.new(0, 1.6)
		s.Glow = (
			{ nil, nil, { 3.5, 0.74 }, { 4.5, 0.64 }, { 5.5, 0.52 }, { 6, 0.46 }, { 6.5, 0.42 } } :: { { number }? }
		)[r]
		s.Shine = if r >= 4 then 0.12 else nil
		s.Sweep = r >= 5
		-- no stars beside the word (Hugo, 2026-11-17: "remove the squares/circles or whatever shapes on the sides of
		-- higher tiers")
		s.Sparks = false
		s.Spin = secret(r)
		s.Tight = true
		s.Anim = if r == 5 then "gold" elseif r == 6 then "ember" elseif r == 7 then "prism" else nil
		return s
	end,
}
Tags.Families = #FAMILIES
local CODE: { [string]: string } =
	{ Common = "C", Uncommon = "U", Rare = "R", Epic = "E", Legendary = "L", Mythic = "M", Secret = "S" }

-- A rarity's style in a family (1 to 4), or nil for r1's look
function Tags.wordStyle(tier: string, family: number): WordStyle?
	local family_ = FAMILIES[family]
	local p = PAL[tier]
	if not family_ or not p then
		return nil
	end
	return family_(RANK[tier] or 1, p)
end

-- Which style each rarity's word takes: Kit.RarityWords, or in Studio the workspace's "RarityWord" ("0", "2", or
-- codes "C1 U2 ..."). Read a few times a second; the answer is the text it came from, to tell when it changed
local function wordChoice(): ({ [string]: number }, string)
	local forced = if RunService:IsStudio() then workspace:GetAttribute("RarityWord") else nil
	if type(forced) ~= "string" then
		local key = ""
		for tier, n in Kit.RarityWords do
			key ..= tier .. n
		end
		return Kit.RarityWords, key
	end
	local out: { [string]: number } = {}
	local all = tonumber(forced)
	if all then
		for tier in CODE do
			out[tier] = all
		end
		return out, forced
	end
	for _, code in string.split(forced, " ") do
		for tier, letter in CODE do
			if string.sub(code, 1, 1) == letter then
				out[tier] = tonumber(string.sub(code, 2)) or 0
			end
		end
	end
	return out, forced
end

-- Which size chip: Kit.SizeChip, or in Studio the workspace's "SizeChip"
local function sizeChoice(): number
	local forced = if RunService:IsStudio() then workspace:GetAttribute("SizeChip") else nil
	return if type(forced) == "number" then forced else Kit.SizeChip
end
local wordPicks, wordKey = wordChoice()
local sizeAt = sizeChoice()

-- The size chip (Hugo, 2026-11-14: "put size and icons below rarity, make the sizes cooler too"; Handoff, task
-- r4). Gotham Black like the rarity's word, but smaller and on a pill, so it never out-shouts it. Each size has its
-- colour, cool to hot as it grows (Tiny a pale steel, Big mint, Giant sky, Huge amber, Colossal a hot red), and the
-- bigger sizes get more: a brighter fill, a gloss, a glow round the pill, two gems either side. Nothing on it moves,
-- so the row never shifts while the word above animates.
local SIZE_RANK = { Tiny = 1, Big = 2, Giant = 3, Huge = 4, Colossal = 5 }
local SIZE_HUE = {
	Tiny = Color3.fromRGB(150, 178, 204),
	Big = Color3.fromRGB(84, 226, 190),
	Giant = Color3.fromRGB(80, 182, 255),
	Huge = Color3.fromRGB(255, 160, 48),
	Colossal = Color3.fromRGB(255, 72, 80),
}
local SIZE_TEXT = { 10.5, 11, 11.5, 12, 12.5 }
local ROW_HIGH = 20
local ROW_GAP = 6
local CHIP_PAD = 6
local GEM_SIDE = 10 -- room for a gem either side of the pill
local PIP_W, PIP_GAP, PIPS = 3, 2, 5
local PIPS_WIDE = PIPS * PIP_W + (PIPS - 1) * PIP_GAP + 4

type ChipLook = {
	Plate: ColorSequence,
	PlateAlpha: number,
	Edge: Color3,
	EdgeThick: number,
	Letters: ColorSequence,
	Size: number,
	High: number,
	Gloss: number?, -- how see-through the white top half of the pill is (nil: none)
	Halo: number?, -- a glow of the size's colour round the pill, how see-through (nil: none)
	Gems: boolean,
	Pips: boolean, -- five bars after the word, filled to the size (Meter)
	Hue: Color3,
	Rank: number,
}

function Tags.chipLook(style: number, tier: string): ChipLook?
	local r = SIZE_RANK[tier]
	local hue = SIZE_HUE[tier]
	if not r or not hue then
		return nil
	end
	local deep = Kit.Deep
	local cl: ChipLook = {
		Plate = ColorSequence.new(deep:Lerp(hue, 0.16 + 0.06 * r), deep),
		PlateAlpha = 0.1,
		Edge = if r == 1 then hue:Lerp(deep, 0.4) else hue,
		EdgeThick = if r <= 2 then 1.5 else 2,
		Letters = if r == 1
			then ColorSequence.new(Color3.fromRGB(214, 226, 238), Color3.fromRGB(164, 182, 202))
			else ColorSequence.new(Kit.lighter(hue, 0.5), hue),
		Size = SIZE_TEXT[r],
		High = 15 + math.ceil(r / 2),
		Gloss = if r == 5 then 0.72 elseif r >= 3 then 0.8 else nil,
		Halo = if r == 5 then 0.45 elseif r == 4 then 0.62 else nil,
		Gems = r == 5,
		Pips = false,
		Hue = hue,
		Rank = r,
	}
	if style == 2 then
		-- Meter: the pill stays dark and plain, the letters white; the bars say how big
		cl.Plate = ColorSequence.new(deep:Lerp(Kit.White, 0.08), deep)
		cl.PlateAlpha = 0.15
		cl.Edge = Kit.Ink
		cl.EdgeThick = 1.5
		cl.Letters = ColorSequence.new(Kit.White, Color3.fromRGB(206, 218, 234))
		cl.Gloss = nil
		cl.Halo = if r == 5 then 0.55 else nil
		cl.Gems = false
		cl.Pips = true
	elseif style == 3 then
		-- Solid: the pill is the size's colour, lit on top, white letters in the ink edge
		cl.Plate = ColorSequence.new(Kit.lighter(hue, 0.3), Kit.darker(hue, if r == 1 then 0.35 else 0.22))
		cl.PlateAlpha = 0
		cl.Edge = Kit.Ink
		cl.EdgeThick = 2
		cl.Letters = ColorSequence.new(Kit.White, Color3.fromRGB(232, 238, 246))
		cl.Gloss = if r >= 4 then 0.55 else 0.68
	end
	return cl
end

-- The sticker (Kit.SizeChip 4; Hugo, 2026-11-17, S8 of fish-tags-size-text-options-1.png): the size as a smaller word
-- built like the rarity word (metal split at the middle, the ink edge, one step of depth), tilted on the word's
-- top-left corner. Its own colours, cool and quiet to hot and loud; a shine line on Giant and Huge, a glow from Huge.
-- It sits in line 1, so far and crowded tags keep it.
local LADDER: { [string]: { Light: Color3, Mid: Color3, Dark: Color3, Deep: Color3 } } = {
	Tiny = { Light = rgb(238, 242, 248), Mid = rgb(170, 184, 202), Dark = rgb(118, 132, 152), Deep = rgb(50, 58, 74) },
	Big = { Light = rgb(214, 255, 240), Mid = rgb(80, 224, 186), Dark = rgb(22, 158, 138), Deep = rgb(8, 74, 66) },
	Giant = { Light = rgb(206, 244, 255), Mid = rgb(60, 196, 255), Dark = rgb(20, 120, 220), Deep = rgb(10, 46, 110) },
	Huge = { Light = rgb(255, 238, 186), Mid = rgb(255, 162, 40), Dark = rgb(230, 96, 12), Deep = rgb(112, 42, 4) },
	Colossal = { Light = rgb(255, 220, 200), Mid = rgb(255, 64, 76), Dark = rgb(196, 14, 52), Deep = rgb(92, 4, 28) },
}
local STICKER_SIZE = { 9.5, 10.5, 11.25, 12.25, 13 }
local STICKER_EDGE = { 1.7, 1.8, 2, 2.1, 2.2 }
local STICKER_TURN = -12
local STICKER_Z = 20

local GLOSS_CUT = 0.5
local function glossSeq(t: number): NumberSequence
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, t),
		NumberSequenceKeypoint.new(GLOSS_CUT - 0.06, math.min(t + 0.2, 1)),
		NumberSequenceKeypoint.new(GLOSS_CUT, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
end
local function lineSeq(t: number, at: number, half: number): NumberSequence
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(at - half, 1),
		NumberSequenceKeypoint.new(at, t),
		NumberSequenceKeypoint.new(at + half, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
end
local DROPS = 3
local PLATE_X, PLATE_Y = 8, 3

local function makeStack(parent: Instance): Alt
	local root: Frame = Kit.new("Frame", {
		Name = "FishTag",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(WIDE, 120),
		BackgroundTransparency = 1,
		Visible = false,
	}, parent)
	local scale: UIScale = Kit.new("UIScale", {}, root)
	Kit.new("UIListLayout", {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, STACK_GAP),
	}, root)
	-- line 1: [star] RARITY [star] and the icons, centred together
	local top: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(WIDE, STACK_TOP),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
	}, root)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 5),
	}, top)
	local sparks: { Frame } = {}
	for i = 1, 2 do
		local spark: Frame = Kit.new("Frame", {
			Size = UDim2.fromOffset(SPARK, SPARK),
			Rotation = 45,
			BackgroundColor3 = Kit.White,
			LayoutOrder = if i == 1 then 1 else 3,
			Visible = false,
		}, top)
		Kit.corner(spark, 2)
		Kit.stroke(spark, 1.5, Kit.Ink)
		sparks[i] = spark
	end
	local holder: Frame = Kit.new("Frame", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, STACK_TOP),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
	}, top)
	local glow: TextLabel = Kit.new("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, STACK_TOP),
		BackgroundTransparency = 1,
		Font = Kit.Font,
		TextSize = 14,
		Text = "",
		TextTransparency = 0.3,
		Visible = false,
	}, holder)
	local glowEdge = Kit.stroke(glow, 4, Kit.White, 0.6)
	local word = Kit.text({
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, STACK_TOP),
		TextSize = 14,
		ZIndex = 2,
	}, holder, 2.6)
	local wordFill = Kit.gradient(word, Kit.White, Kit.White)
	-- a designed style's word: its layers stacked in one frame, back to front
	local art: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(10, STACK_TOP),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Visible = false,
	}, top)
	local plate: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Kit.White,
		ZIndex = 2,
		Visible = false,
	}, art)
	Kit.corner(plate, 7)
	local plateFill = Kit.gradient(plate, Kit.White, Kit.White)
	local plateEdge = Kit.stroke(plate, 2, Kit.Ink)
	local plateEdgeFill: UIGradient = Kit.new("UIGradient", { Enabled = false }, plateEdge)
	local plateGloss: Frame = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Kit.White,
		ZIndex = 3,
	}, plate)
	Kit.corner(plateGloss, 7)
	Kit.new("UIGradient", { Rotation = 90, Transparency = glossSeq(0.45) }, plateGloss)
	local plateShine: Frame = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Kit.White,
		ZIndex = 4,
		Visible = false,
	}, plate)
	Kit.corner(plateShine, 7)
	local plateSweep: UIGradient =
		Kit.new("UIGradient", { Rotation = 20, Transparency = lineSeq(0.35, 0.5, 0.09) }, plateShine)
	local halo: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 8, 1, 8),
		BackgroundColor3 = Kit.White,
		ZIndex = 1,
		Visible = false,
	}, art)
	Kit.corner(halo, 11)
	local function layer(z: number): TextLabel
		return Kit.new("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = Enum.Font.LuckiestGuy,
			TextSize = 15,
			Text = "",
			TextColor3 = Kit.White,
			ZIndex = z,
		}, art)
	end
	local aGlow = layer(3)
	aGlow.TextTransparency = 0.3
	local aGlowEdge = Kit.stroke(aGlow, 4, Kit.White, 0.6)
	local drops: { TextLabel } = {}
	local dropEdges: { UIStroke } = {}
	for i = 1, DROPS do
		local d = layer(8 - i)
		drops[i] = d
		dropEdges[i] = Kit.stroke(d, 2, Kit.Ink)
	end
	local main = layer(10)
	local mainFill = Kit.gradient(main, Kit.White, Kit.White)
	local mainEdge = Kit.stroke(main, 2, Kit.Ink)
	local mainEdgeFill: UIGradient = Kit.new("UIGradient", { Enabled = false }, mainEdge)
	local gloss = layer(11)
	local glossFill: UIGradient = Kit.new("UIGradient", { Rotation = 90, Transparency = glossSeq(0.5) }, gloss)
	local shine = layer(12)
	local shineFill: UIGradient =
		Kit.new("UIGradient", { Rotation = 90, Transparency = lineSeq(0.2, 0.3, 0.06) }, shine)
	-- the sticker: its own small stack of the same layers, turned, on the word's top-left corner
	local sticker: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(2, 1),
		Size = UDim2.fromOffset(10, 18),
		Rotation = STICKER_TURN,
		BackgroundTransparency = 1,
		ZIndex = STICKER_Z,
		Visible = false,
	}, art)
	local function stickerLayer(z: number): TextLabel
		return Kit.new("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			TextSize = 11,
			Text = "",
			TextColor3 = Kit.White,
			ZIndex = STICKER_Z + z,
		}, sticker)
	end
	local sGlow = stickerLayer(1)
	sGlow.TextTransparency = 0.3
	local sGlowEdge = Kit.stroke(sGlow, 4, Kit.White, 0.6)
	local sDrop = stickerLayer(2)
	local sDropEdge = Kit.stroke(sDrop, 2, Kit.Ink)
	local sMain = stickerLayer(3)
	local sFill = Kit.gradient(sMain, Kit.White, Kit.White)
	local sEdge = Kit.stroke(sMain, 2, Kit.Ink)
	local sShine = stickerLayer(4)
	Kit.new("UIGradient", { Rotation = 90, Transparency = lineSeq(0.15, 0.3, 0.05) }, sShine)
	-- line 2 (Hugo, 2026-11-14: "put size and icons below rarity"): the size chip and every archetype icon, one row,
	-- centred, evenly spaced; hidden when the fish has neither
	local row: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(WIDE, ROW_HIGH),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Visible = false,
	}, root)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, ROW_GAP),
	}, row)
	-- the chip: its pieces placed by hand in one slot (halo, pill, gloss, word, bars, gems), so its size is known
	local slot: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(10, ROW_HIGH),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Visible = false,
	}, row)
	local halos: { Frame } = {}
	for i = 1, 2 do
		local h: Frame = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			BackgroundColor3 = Kit.White,
			BorderSizePixel = 0,
			ZIndex = i,
			Visible = false,
		}, slot)
		Kit.corner(h, 999)
		halos[i] = h
	end
	local pill: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, slot)
	Kit.corner(pill, 999)
	local pillFill = Kit.gradient(pill, Kit.White, Kit.White)
	local sizeEdge = Kit.stroke(pill, 1.5, Kit.Ink)
	local gloss2: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		ZIndex = 4,
		Visible = false,
	}, slot)
	Kit.corner(gloss2, 999)
	local glossFill2: UIGradient = Kit.new("UIGradient", { Rotation = 90, Transparency = glossSeq(0.7) }, gloss2)
	local sizeWord = Kit.text({
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(10, 14),
		Font = Enum.Font.GothamBlack,
		TextSize = 11,
		ZIndex = 6,
	}, slot, 1.5)
	local sizeWordFill = Kit.gradient(sizeWord, Kit.White, Kit.White)
	local pips: { Frame } = {}
	for i = 1, PIPS do
		local p: Frame = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Size = UDim2.fromOffset(PIP_W, 3 + 2 * i),
			BackgroundColor3 = Kit.White,
			BorderSizePixel = 0,
			ZIndex = 6,
			Visible = false,
		}, slot)
		Kit.corner(p, 1)
		Kit.stroke(p, 1, Kit.Ink)
		pips[i] = p
	end
	local gems: { Frame } = {}
	for i = 1, 2 do
		local g: Frame = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(
				if i == 1 then 0 else 1,
				if i == 1 then GEM_SIDE / 2 - 1 else 1 - GEM_SIDE / 2,
				0.5,
				0
			),
			Size = UDim2.fromOffset(6, 6),
			Rotation = 45,
			BackgroundColor3 = Kit.White,
			BorderSizePixel = 0,
			ZIndex = 6,
			Visible = false,
		}, slot)
		Kit.corner(g, 1)
		Kit.stroke(g, 1.5, Kit.Ink)
		gems[i] = g
	end
	local icons: Frame = Kit.new("Frame", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, STACK_ICON),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Visible = false,
	}, row)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, ROW_GAP),
	}, icons)
	-- line 3: the name, white for every rarity, with the thick dark edge (it reads on sand and on the pink reef)
	local name = Kit.text({
		Size = UDim2.fromOffset(WIDE, STACK_NAME),
		TextSize = 16,
		LayoutOrder = 3,
	}, root, 3)
	-- line 4: "Required: n" and the bubble; on a red plate when the fish is too strong
	local reqRow: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(WIDE, STACK_REQ),
		BackgroundTransparency = 1,
		LayoutOrder = 4,
	}, root)
	local chip: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, STACK_REQ),
		BackgroundColor3 = Kit.Danger,
		BackgroundTransparency = 1,
	}, reqRow)
	Kit.corner(chip, 999)
	local chipEdge = Kit.stroke(chip, 2, Kit.Ink)
	chipEdge.Enabled = false
	Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, chip)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, chip)
	local req = Kit.text({
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, STACK_REQ),
		TextSize = REQ_SIZE,
		Text = "Required:",
		TextColor3 = Color3.fromRGB(226, 238, 255),
		LayoutOrder = 1,
	}, chip, 2)
	local need = Kit.text({
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, STACK_REQ),
		TextSize = NUMBER_SIZE,
		LayoutOrder = 2,
	}, chip, 2.4)
	Kit.bubble(chip, BUBBLE).LayoutOrder = 3
	local hold =
		Kit.text({ Size = UDim2.fromOffset(WIDE, 15), TextSize = 11.5, LayoutOrder = 5, Visible = false }, root)
	if REQ_WIDE == 0 then
		REQ_WIDE = TextService:GetTextSize("Required:", REQ_SIZE, Kit.Font, Vector2.new(1000, 100)).X + 4
	end
	return {
		Frame = root,
		Scale = scale,
		Name = name,
		Chip = chip,
		Need = need,
		Hold = hold,
		Opt = nil,
		Stk = {
			Word = word,
			WordFill = wordFill,
			Glow = glow,
			GlowEdge = glowEdge,
			Sparks = sparks,
			Icons = icons,
			Req = req,
			ChipEdge = chipEdge,
			WordSize = 14,
			WordWide = 0,
			Turn = 90,
			Top = top,
			Holder = holder,
			Art = art,
			Plate = plate,
			PlateFill = plateFill,
			PlateEdge = plateEdge,
			PlateEdgeFill = plateEdgeFill,
			PlateHalo = halo,
			PlateSweep = plateSweep,
			PlateShine = plateShine,
			AGlow = aGlow,
			AGlowEdge = aGlowEdge,
			Drops = drops,
			DropEdges = dropEdges,
			Main = main,
			MainFill = mainFill,
			MainEdge = mainEdge,
			MainEdgeFill = mainEdgeFill,
			Gloss = gloss,
			GlossFill = glossFill,
			Shine = shine,
			ShineFill = shineFill,
			Style = nil,
			Row = row,
			RowOn = false,
			RowWide = 0,
			SizeSlot = slot,
			SizePill = pill,
			SizePillFill = pillFill,
			SizeEdge = sizeEdge,
			SizeGloss = gloss2,
			SizeGlossFill = glossFill2,
			SizeHalos = halos,
			SizeGems = gems,
			SizePips = pips,
			SizeWord = sizeWord,
			SizeWordFill = sizeWordFill,
			SizeWide = 0,
			Sticker = sticker,
			StickerGlow = sGlow,
			StickerGlowEdge = sGlowEdge,
			StickerDrop = sDrop,
			StickerDropEdge = sDropEdge,
			StickerMain = sMain,
			StickerFill = sFill,
			StickerEdge = sEdge,
			StickerShine = sShine,
			SparkWide = 0,
			Animated = false,
		},
		Offset = Vector3.zero,
		Fish = nil,
		KindOf = nil,
		TierName = "",
		Rare = 0,
		Needs = -1,
		State = 0,
		HoldText = "",
		NameWide = 0,
		LeadCount = 0,
		UnderCount = 0,
		Locked = false,
		Focus = false,
		Want = WHOLE,
		Shape = -1,
		Size = 0,
		Extra = 0,
		Distance = 0,
		Rank = 0,
		Crowded = false,
		Point = Vector3.zero,
		X = 0,
		Y = 0,
		Wide = 0,
		High = 0,
		Drawn = "",
	}
end

-- A designed style's word (WordStyle) into the Art layers; its width and the line's height
local function putArt(st: StackParts, style: WordStyle, text: string): (number, number)
	local measured = TextService:GetTextSize(text, style.Size, style.Font, Vector2.new(1000, 100))
	local spread = if style.Tight then 1 else style.EdgeThick + 2 + math.max(style.DropStep.X * style.Drops, 0)
	local wide = measured.X + spread * 2
	local high = math.max(STACK_TOP, style.Size + 8)
	local plated = style.Plate ~= nil
	if plated then
		wide += PLATE_X * 2
		high = math.max(STACK_TOP + 2, style.Size + PLATE_Y * 2 + 6)
	end
	st.Art.Size = UDim2.fromOffset(wide, high)
	local function letters(label: TextLabel)
		label.Font = style.Font
		label.TextSize = style.Size
		label.Text = text
	end
	-- the plate, its lit top, its sweep and halo
	st.Plate.Visible = plated
	if plated then
		st.Plate.Size = UDim2.new(1, 0, 0, style.Size + PLATE_Y * 2 + 2)
		st.PlateFill.Color = style.Plate :: ColorSequence
		st.PlateEdge.Color = style.PlateEdge
		st.PlateEdge.Thickness = 2
		st.PlateEdgeFill.Enabled = style.PlateEdgeFill ~= nil
		if style.PlateEdgeFill then
			st.PlateEdge.Color = WHITE
			st.PlateEdgeFill.Color = style.PlateEdgeFill
		end
		st.PlateShine.Visible = style.Shine ~= nil
		if style.Shine then
			st.PlateSweep.Transparency = lineSeq(style.Shine, 0.5, 0.1)
			st.PlateSweep.Offset = Vector2.new(if style.Sweep then -1.5 else 0, 0)
		end
	end
	st.PlateHalo.Visible = plated and style.PlateGlow ~= nil
	if plated and style.PlateGlow then
		st.PlateHalo.Size = UDim2.new(1, 8, 0, style.Size + PLATE_Y * 2 + 10)
		st.PlateHalo.BackgroundColor3 = style.GlowColour
		st.PlateHalo.BackgroundTransparency = style.PlateGlow
	end
	-- the glow
	local glow = style.Glow
	st.AGlow.Visible = glow ~= nil
	if glow then
		letters(st.AGlow)
		st.AGlow.TextColor3 = style.GlowColour
		st.AGlowEdge.Color = style.GlowColour
		st.AGlowEdge.Thickness = glow[1]
		st.AGlowEdge.Transparency = glow[2]
	end
	-- the depth under the letters
	for i, drop in st.Drops do
		drop.Visible = i <= style.Drops
		if i <= style.Drops then
			letters(drop)
			drop.TextColor3 = style.DropColour
			drop.Position = UDim2.new(0.5, style.DropStep.X * i, 0.5, style.DropStep.Y * i)
			st.DropEdges[i].Color = style.DropEdge
			st.DropEdges[i].Thickness = style.EdgeThick
		end
	end
	-- the letters, their edge
	letters(st.Main)
	st.MainFill.Color, st.MainFill.Rotation = style.Fill, style.FillTurn
	st.MainEdge.Color = style.Edge
	st.MainEdge.Thickness = style.EdgeThick
	st.MainEdgeFill.Enabled = style.EdgeFill ~= nil
	if style.EdgeFill then
		st.MainEdgeFill.Color = style.EdgeFill
		st.MainEdgeFill.Rotation = if style.EdgeFill == RAINBOW then 0 else 90
	end
	-- the highlight on the top half, the shine line
	st.Gloss.Visible = style.Gloss ~= nil
	if style.Gloss then
		letters(st.Gloss)
		st.GlossFill.Transparency = glossSeq(style.Gloss)
	end
	local line = not plated and style.Shine ~= nil
	st.Shine.Visible = line
	if line and style.Shine then
		letters(st.Shine)
		if style.Sweep then
			st.ShineFill.Rotation = 25
			st.ShineFill.Transparency = lineSeq(style.Shine, 0.5, 0.08)
			st.ShineFill.Offset = Vector2.new(-1.5, 0)
		else
			st.ShineFill.Rotation = 90
			st.ShineFill.Transparency = lineSeq(style.Shine, 0.3, 0.05)
			st.ShineFill.Offset = Vector2.zero
		end
	end
	return wide, high
end

-- The sticker for a size (rank 1 Tiny to 5 Colossal), or hidden (nil: Normal, or another size style)
local function putSticker(st: StackParts, r: number?, sizeTier: string)
	st.Sticker.Visible = r ~= nil
	if not r then
		return
	end
	local p = LADDER[sizeTier]
	local text = string.upper(sizeTier)
	local size = STICKER_SIZE[r]
	local measured = TextService:GetTextSize(text, size, Enum.Font.GothamBlack, Vector2.new(1000, 100))
	st.Sticker.Size = UDim2.fromOffset(measured.X + 2, math.ceil(size + 8))
	for _, label in { st.StickerGlow, st.StickerDrop, st.StickerMain, st.StickerShine } do
		label.Text = text
		label.TextSize = size
	end
	local glow = if r == 5 then { 4.5, 0.55 } elseif r == 4 then { 3.5, 0.68 } else nil
	st.StickerGlow.Visible = glow ~= nil
	if glow then
		st.StickerGlow.TextColor3 = p.Mid
		st.StickerGlowEdge.Color = p.Mid
		st.StickerGlowEdge.Thickness = glow[1]
		st.StickerGlowEdge.Transparency = glow[2]
	end
	st.StickerDrop.TextColor3 = Kit.darker(p.Deep, 0.2)
	st.StickerDrop.Position = UDim2.new(0.5, 0, 0.5, if r >= 4 then 1.4 else 1.2)
	st.StickerDropEdge.Thickness = STICKER_EDGE[r]
	st.StickerFill.Color = seq({
		0,
		Kit.lighter(p.Light, 0.5),
		0.48,
		p.Light:Lerp(p.Mid, 0.35),
		0.52,
		p.Mid,
		1,
		p.Mid:Lerp(p.Dark, 0.55),
	})
	st.StickerEdge.Thickness = STICKER_EDGE[r]
	st.StickerShine.Visible = r == 3 or r == 4
end

-- A three-line tag's rarity word, its size word and icons for its fish
local function putStack(st: StackParts, rare: number, tier: string, line: string, lk: Look, sizeTier: string)
	local text = string.upper(tier)
	local pick = wordPicks[tier]
	local style = if pick and pick > 0 then Tags.wordStyle(tier, pick) else nil
	st.Style = style
	st.Holder.Visible = style == nil
	st.Art.Visible = style ~= nil
	local high = STACK_TOP
	if style then
		st.WordWide, high = putArt(st, style, text)
		st.Turn = style.FillTurn
		st.Animated = style.Sweep or style.Spin or style.Sparks or style.Anim ~= nil
		st.AGlow.TextColor3 = style.GlowColour
		st.AGlowEdge.Color = style.GlowColour
		st.MainFill.Offset = Vector2.zero
	else
		-- r1's word: the tag's own font, its colour, a glow from Rare, stars and a shimmer from Legendary
		local size = WORD_SIZE[rare] or 14
		local fill, turn = Kit.tierFill(tier, Config.Tiers)
		local colour = solid(tier)
		st.Word.Text = text
		st.Word.TextSize = size
		st.WordFill.Color, st.WordFill.Rotation = fill, turn
		st.Turn = turn
		st.WordSize = size
		st.WordWide = TextService:GetTextSize(text, size, Kit.Font, Vector2.new(1000, 100)).X
		local glow = if lk.Glow then WORD_GLOW[rare] else nil
		st.Glow.Visible = glow ~= nil
		if glow then
			st.Glow.Text = text
			st.Glow.TextSize = size
			st.Glow.TextColor3 = colour
			st.GlowEdge.Color = colour
			st.GlowEdge.Thickness = glow[1]
			st.GlowEdge.Transparency = glow[2]
		end
		st.Animated = rare >= SHINY
	end
	st.Top.Size = UDim2.fromOffset(WIDE, high)
	local shiny = if style then style.Sparks else rare >= SHINY
	local sparkColour = Kit.lighter(if style then style.GlowColour else solid(tier), 0.55)
	for _, spark in st.Sparks do
		spark.Visible = shiny
		spark.BackgroundColor3 = sparkColour
		spark.BackgroundTransparency = 0
	end
	st.SparkWide = if shiny then 2 * (SPARK + 6) else 0
	-- the row under the word: the size chip (Tiny to Colossal; a Normal fish has none) and the icons
	-- the sticker (4) needs a designed word to sit on; on r1's word it falls back to the Glass chip
	local stickerRank = if sizeAt == 4 and style then SIZE_RANK[sizeTier] else nil
	putSticker(st, stickerRank, sizeTier)
	local chip = if stickerRank or sizeAt == 4 and SIZE_RANK[sizeTier] == nil
		then nil
		else Tags.chipLook(if sizeAt == 4 then 1 else sizeAt, sizeTier)
	st.SizeSlot.Visible = chip ~= nil
	st.SizeWide = 0
	if chip then
		local word = string.upper(sizeTier)
		local textWide = TextService:GetTextSize(word, chip.Size, Enum.Font.GothamBlack, Vector2.new(1000, 100)).X + 2
		local pillWide = textWide + CHIP_PAD * 2 + (if chip.Pips then PIPS_WIDE else 0)
		local side = if chip.Gems then GEM_SIDE else 0
		local pillHigh = chip.High
		st.SizeWide = pillWide + side * 2
		st.SizeSlot.Size = UDim2.fromOffset(st.SizeWide, ROW_HIGH)
		st.SizePill.Size = UDim2.fromOffset(pillWide, pillHigh)
		st.SizePillFill.Color = chip.Plate
		st.SizePill.BackgroundTransparency = chip.PlateAlpha
		st.SizeEdge.Color = chip.Edge
		st.SizeEdge.Thickness = chip.EdgeThick
		st.SizeGloss.Visible = chip.Gloss ~= nil
		if chip.Gloss then
			st.SizeGloss.Size = UDim2.fromOffset(pillWide - 4, pillHigh - 3)
			st.SizeGlossFill.Transparency = glossSeq(chip.Gloss)
		end
		for i, h in st.SizeHalos do
			h.Visible = chip.Halo ~= nil
			if chip.Halo then
				local grow = if i == 1 then 10 else 5
				h.Size = UDim2.fromOffset(pillWide + grow, pillHigh + grow)
				h.BackgroundColor3 = chip.Hue
				h.BackgroundTransparency = if i == 1 then (1 + chip.Halo) / 2 else chip.Halo
			end
		end
		local left = side + CHIP_PAD
		st.SizeWord.Text = word
		st.SizeWord.TextSize = chip.Size
		st.SizeWord.Size = UDim2.fromOffset(textWide, pillHigh)
		st.SizeWord.Position = UDim2.new(0, left, 0.5, 0)
		st.SizeWordFill.Color = chip.Letters
		local foot = ROW_HIGH / 2 + 5.5
		for i, p in st.SizePips do
			p.Visible = chip.Pips
			if chip.Pips then
				p.Position = UDim2.fromOffset(left + textWide + 3 + (i - 1) * (PIP_W + PIP_GAP), foot)
				p.BackgroundColor3 = if i <= chip.Rank then chip.Hue else Kit.Deep:Lerp(Kit.White, 0.12)
			end
		end
		for _, g in st.SizeGems do
			g.Visible = chip.Gems
			g.BackgroundColor3 = Kit.lighter(chip.Hue, 0.45)
		end
	end
	local icons = Archetypes.icons(st.Icons, line, STACK_ICON)
	st.Icons.Visible = icons > 0
	st.RowOn = chip ~= nil or icons > 0
	st.Row.Visible = st.RowOn
	st.RowWide = st.SizeWide
		+ (if icons > 0 then icons * STACK_ICON + (icons - 1) * ROW_GAP else 0)
		+ (if chip and icons > 0 then ROW_GAP else 0)
end

-- The animation of a word: r1's shimmer for Legendary and up (the gradient swings, the glow breathes, the stars turn,
-- the Secret's rainbow goes round), or a designed style's own (its shine sweeps across now and then, its rainbow
-- turns, its glow breathes). Per frame, on the tags drawn only
local SWEEP_EVERY = 2.6
local SWEEP_TIME = 0.8
local shineAt: number? = nil -- in Studio the workspace's "ShineAt" holds the sweep still there (-1.2 to 1.2), for pictures
-- Family 5's three motions (Hugo, 2026-11-14: "legendary + are animated"). Only gradients' offsets and turns,
-- transparencies, colours and the stars' turn change, never a size, so the tag never moves. Louder up the ladder:
--   gold (Legendary): a white shine crosses the word every 2.6 s, the glow breathes slowly, the stars twinkle;
--   ember (Mythic): the shine every 1.7 s, the metal's bright half rises and falls like heat, the glow throbs between
--     its red and a hot orange, the stars spin;
--   prism (Secret): the rainbow letters turn round, the glow goes through every colour, the shine every 1.5 s, the
--     stars spin fast in the glow's colour.
local EMBER_HOT = Color3.fromRGB(255, 150, 60)
local function liveWord(tag: Alt, st: StackParts, style: WordStyle, t: number)
	local anim = style.Anim
	local glow = style.Glow or { 5, 0.5 }
	local every = if anim == "gold" then 2.6 elseif anim == "ember" then 1.7 else 1.5
	local u = ((t + tag.Rare * 0.37) % every) / SWEEP_TIME
	st.ShineFill.Offset = Vector2.new(shineAt or (if u < 1 then -1.2 + 2.4 * u else 1.5), 0)
	if anim == "gold" then
		local b = math.sin(t * 2.4)
		st.AGlowEdge.Transparency = glow[2] + b * 0.1
		local tw = 0.5 + 0.5 * math.sin(t * 5)
		st.Sparks[1].Rotation = 45 + tw * 45
		st.Sparks[2].Rotation = 90 - tw * 45
		st.Sparks[1].BackgroundTransparency = 0.35 * (1 - tw)
		st.Sparks[2].BackgroundTransparency = 0.35 * tw
	elseif anim == "ember" then
		local b = 0.5 + 0.5 * math.sin(t * 4.2)
		st.MainFill.Offset = Vector2.new(0, (math.sin(t * 3.1) * 0.6 + math.sin(t * 7.3) * 0.4) * 0.09)
		st.AGlowEdge.Transparency = glow[2] + 0.14 - b * 0.24
		local c = style.GlowColour:Lerp(EMBER_HOT, b)
		st.AGlowEdge.Color = c
		st.AGlow.TextColor3 = c
		local spin = (t * 120) % 360
		st.Sparks[1].Rotation = 45 + spin
		st.Sparks[2].Rotation = 45 - spin
	else
		st.MainFill.Rotation = (t * 80) % 360
		local c = Color3.fromHSV((t * 0.18) % 1, 0.55, 1)
		st.AGlowEdge.Color = c
		st.AGlow.TextColor3 = c
		st.AGlowEdge.Transparency = glow[2] + math.sin(t * 3) * 0.08
		local spin = (t * 200) % 360
		st.Sparks[1].Rotation = 45 + spin
		st.Sparks[2].Rotation = 45 - spin
		local sc = Color3.fromHSV((t * 0.18 + 0.5) % 1, 0.35, 1)
		st.Sparks[1].BackgroundColor3 = sc
		st.Sparks[2].BackgroundColor3 = sc
	end
end

local function shimmer(tag: Alt, st: StackParts, t: number)
	local phase = t * 2.2 + tag.Rare
	local spin = (t * 90) % 360
	st.Sparks[1].Rotation = 45 + spin
	st.Sparks[2].Rotation = 45 - spin
	local style = st.Style
	if style and style.Anim then
		liveWord(tag, st, style, t)
		return
	end
	if style then
		if style.Spin then
			local turn = (t * 70) % 360
			if style.Fill == RAINBOW then
				st.MainFill.Rotation = turn
			end
			if style.EdgeFill == RAINBOW then
				st.MainEdgeFill.Rotation = turn
			end
			if style.PlateEdgeFill then
				st.PlateEdgeFill.Rotation = turn
			end
		end
		if style.Sweep then
			local u = ((t + tag.Rare * 0.37) % SWEEP_EVERY) / SWEEP_TIME
			local x = shineAt or (if u < 1 then -1.2 + 2.4 * u else 1.5)
			if style.Plate then
				st.PlateSweep.Offset = Vector2.new(x, 0)
			else
				st.ShineFill.Offset = Vector2.new(x, 0)
			end
		end
		local glow = style.Glow
		if glow and style.Sparks then
			st.AGlowEdge.Transparency = glow[2] + math.sin(phase * 1.3) * 0.1
		end
		return
	end
	if tag.TierName == "Secret" then
		st.WordFill.Rotation = (t * 70) % 360
	else
		st.WordFill.Rotation = st.Turn + math.sin(phase) * 28
	end
	st.GlowEdge.Transparency = (WORD_GLOW[tag.Rare] or { 0, 0.5 })[2] + math.sin(phase * 1.3) * 0.12
end

local function makeAlt(parent: Instance, lk: Look): Alt
	if lk.Stack then
		return makeStack(parent)
	end
	local root: Frame = Kit.new("Frame", {
		Name = "FishTag",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(WIDE, 120),
		BackgroundTransparency = 1,
		Visible = false,
	}, parent)
	local scale: UIScale = Kit.new("UIScale", {}, root)
	Kit.new("UIListLayout", {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 1),
	}, root)
	local word = Kit.text({ Size = UDim2.fromOffset(WIDE, 13), TextSize = 11, LayoutOrder = 1, Visible = false }, root)
	local wordFill = Kit.gradient(word, Kit.White, Kit.White)
	-- the plate's glow is a wide soft line on a frame that wraps the plate exactly
	local holder: Frame = Kit.new("Frame", {
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
	}, root)
	local radius = if lk.Plate == "ribbon" then 6 else 8
	Kit.corner(holder, radius)
	local halo = Kit.stroke(holder, 7, Kit.White, 0.55)
	halo.Enabled = false
	local card: Frame = Kit.new("Frame", {
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = if lk.Plate == "glass" then Kit.Deep else Kit.White,
		BackgroundTransparency = if lk.Plate == "glass" then 0.28 elseif lk.Plate == "ribbon" then 0 else 1,
	}, holder)
	Kit.corner(card, radius)
	local cardFill = Kit.gradient(card, Kit.White, Kit.White)
	cardFill.Enabled = lk.Plate == "ribbon"
	local cardEdge = Kit.stroke(card, 2.5, Kit.Ink)
	cardEdge.Enabled = lk.Plate ~= ""
	if lk.Plate ~= "" then
		Kit.new("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 2),
		}, card)
	end
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, card)
	-- the rarity gem: a square turned to a diamond, in the rarity's colours; Legendary and up a glow behind it
	local gemBox: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(GEM + 6, GEM + 6),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
	}, card)
	local gemGlow: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(GEM + 9, GEM + 9),
		Rotation = 45,
		BackgroundTransparency = 0.5,
		Visible = false,
	}, gemBox)
	Kit.corner(gemGlow, 4)
	local gem: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(GEM, GEM),
		Rotation = 45,
		BackgroundColor3 = Kit.White,
	}, gemBox)
	Kit.corner(gem, 2)
	local gemFill = Kit.gradient(gem, Kit.White, Kit.White)
	Kit.stroke(gem, 2, Kit.Ink)
	local lead: Frame = Kit.new("Frame", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, lk.IconSize),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
	}, card)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 2),
	}, lead)
	local name = Kit.text({
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, lk.NameSize + 4),
		TextSize = lk.NameSize,
	}, card)
	name.LayoutOrder = 3
	local nameFill = Kit.gradient(name, Kit.White, Kit.White)
	nameFill.Enabled = lk.NameTier
	local under: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(WIDE, lk.IconSize + 3),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Visible = false,
	}, root)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, under)
	local chipRow: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(WIDE, CHIP_HIGH + 2),
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		Visible = lk.ChipUnder,
	}, root)
	-- the price: the bubble and the number on a small dark chip (green or red as the fish is)
	local chip: Frame = Kit.new("Frame", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, CHIP_HIGH),
		BackgroundColor3 = Kit.Deep,
		BackgroundTransparency = 0.25,
		LayoutOrder = 4,
	}, if lk.ChipUnder then chipRow else card)
	if lk.ChipUnder then
		chip.AnchorPoint = Vector2.new(0.5, 0)
		chip.Position = UDim2.fromScale(0.5, 0)
	end
	Kit.corner(chip, 999)
	Kit.stroke(chip, 2, Kit.Ink)
	Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 6) }, chip)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 3),
	}, chip)
	Kit.bubble(chip, 11).LayoutOrder = 1
	local need = Kit.text({
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 15),
		TextSize = 12.5,
		LayoutOrder = 2,
	}, chip)
	local hold =
		Kit.text({ Size = UDim2.fromOffset(WIDE, 15), TextSize = 11.5, LayoutOrder = 5, Visible = false }, root)
	return {
		Frame = root,
		Scale = scale,
		Name = name,
		Chip = chip,
		Need = need,
		Hold = hold,
		Opt = {
			Word = word,
			WordFill = wordFill,
			Halo = halo,
			Card = card,
			CardFill = cardFill,
			CardEdge = cardEdge,
			GemBox = gemBox,
			GemFill = gemFill,
			GemGlow = gemGlow,
			Lead = lead,
			NameFill = nameFill,
			Under = under,
			ChipRow = chipRow,
		},
		Stk = nil,
		Offset = Vector3.zero,
		Fish = nil,
		KindOf = nil,
		TierName = "",
		Rare = 0,
		Needs = -1,
		State = 0,
		HoldText = "",
		NameWide = 0,
		LeadCount = 0,
		UnderCount = 0,
		Locked = false,
		Focus = false,
		Want = WHOLE,
		Shape = -1,
		Size = 0,
		Extra = 0,
		Distance = 0,
		Rank = 0,
		Crowded = false,
		Point = Vector3.zero,
		X = 0,
		Y = 0,
		Wide = 0,
		High = 0,
		Drawn = "",
	}
end

local function putAlt(tag: Alt, fish: Model, lk: Look)
	local kind = Config.FishById[fish:GetAttribute("FishType") :: string]
	local root = fish.PrimaryPart
	if not kind or not root then
		return
	end
	tag.Fish = fish
	local variant = Config.variantOf(fish)
	local size = Config.sizeTierOf(fish)
	local name = kind.Name
	if variant ~= "" then
		name = variant .. " " .. name
	end
	-- the three-line tag has the size on line 1, beside the rarity (Hugo, 2026-11-14); the options keep it here
	if size ~= "Normal" and not lk.Stack then
		name = string.upper(size) .. " " .. name
	end
	tag.Offset = Vector3.new(0, Config.bodyOf(fish, kind).Y * 0.5 + 2.5, 0)
	tag.Name.Text = name
	tag.NameWide = TextService:GetTextSize(name, lk.NameSize, Kit.Font, Vector2.new(1000, 100)).X
	local line = if Config.ArchetypeFeel.Tags > 0 then Archetypes.line(kind) else ""
	local count = if line == "" then 0 else #string.split(line, ",")
	tag.LeadCount = if count <= lk.IconsLeft then count else 0
	tag.UnderCount = if count > lk.IconsLeft then count else 0
	tag.KindOf = kind
	tag.TierName = kind.Tier
	tag.Rare = RANK[kind.Tier] or 1
	local fill, turn = Kit.tierFill(kind.Tier, Config.Tiers)
	local colour = solid(kind.Tier)
	local o = tag.Opt
	if o then
		Archetypes.icons(o.Lead, if tag.LeadCount > 0 then line else "", lk.IconSize)
		Archetypes.icons(o.Under, if tag.UnderCount > 0 then line else "", lk.IconSize + 2)
		o.Word.Text = string.upper(kind.Tier)
		o.WordFill.Color, o.WordFill.Rotation = fill, turn
		o.NameFill.Color, o.NameFill.Rotation = fill, turn
		o.GemFill.Color, o.GemFill.Rotation = fill, turn
		o.CardFill.Color, o.CardFill.Rotation = fill, turn
		if lk.Plate == "glass" then
			o.CardEdge.Color = colour
		end
		local shiny = lk.Glow and tag.Rare >= SHINY
		o.Halo.Color = colour
		o.Halo.Enabled = shiny and lk.Plate ~= ""
		o.GemGlow.BackgroundColor3 = colour
		o.GemGlow.Visible = shiny
	end
	local st = tag.Stk
	if st then
		putStack(st, tag.Rare, kind.Tier, line, lk, size)
	end
	tag.Needs = -1
	tag.State = 0
	tag.Shape = -1
	tag.Drawn = ""
end

-- The room a tag takes on the screen in a shape, kept clear by the look's Pad
local function roomAlt(tag: Alt, form: number, lk: Look)
	local s = tag.Size * hudScale
	local st = tag.Stk
	if st then
		local word = st.WordWide + st.SparkWide
		local number = 13 + 8 * #tag.Need.Text
		local top = st.Top.Size.Y.Offset
		local wide, high
		if form == MARK then
			wide = math.max(word, number + 12)
			high = top + STACK_GAP + STACK_REQ
		else
			wide = math.max(word, st.RowWide, tag.NameWide, REQ_WIDE + number + 12)
			high = top + STACK_NAME + STACK_REQ + STACK_GAP * 2 + (if st.RowOn then ROW_HIGH + STACK_GAP else 0)
		end
		tag.Wide = (wide + lk.Pad * 2) * s
		tag.High = (high + tag.Extra + lk.Pad * 2) * s
		return
	end
	local plate = if lk.Plate ~= "" then 20 else 0
	local chip = 28 + 8 * #tag.Need.Text
	local wide, high
	if form == MARK then
		wide = GEM + 10 + plate + (if lk.FarPrice and not lk.ChipUnder then chip else 0)
		high = 22 + (if lk.FarPrice and lk.ChipUnder then CHIP_HIGH + 2 else 0)
	else
		local gem = if lk.Gem then GEM + 10 else 0
		local icons = if tag.LeadCount > 0 then tag.LeadCount * (lk.IconSize + 2) + 4 else 0
		local priced = form == WHOLE
		wide = gem + icons + tag.NameWide + plate + (if priced and not lk.ChipUnder then chip + 4 else 0)
		high = lk.NameSize + 6 + (if plate > 0 then 4 else 0)
		if tag.UnderCount > 0 then
			high += lk.IconSize + 5
		end
		if priced and lk.ChipUnder then
			high += CHIP_HIGH + 3
		end
		if lk.TierWord and form == WHOLE and (tag.Focus or tag.Locked) then
			high += 14
		end
	end
	tag.Wide = (wide + lk.Pad * 2) * s
	tag.High = (high + tag.Extra + lk.Pad * 2) * s
end

local function clashAlt(tag: Alt, before: number): boolean
	for j = 1, before do
		local placed = altOrder[j]
		if
			not placed.Crowded
			and math.abs(tag.X - placed.X) < (tag.Wide + placed.Wide) / 2
			and tag.Y - tag.High < placed.Y
			and placed.Y - placed.High < tag.Y
		then
			return true
		end
	end
	return false
end

-- Draws a tag in a shape: written only when the shape, the focus or the size changed
local function shapeAlt(tag: Alt, form: number, lk: Look)
	local key = form .. (if tag.Focus or tag.Locked then "f" else "") .. tag.Size .. "/" .. hudScale
	if key == tag.Drawn then
		return
	end
	tag.Drawn = key
	tag.Shape = form
	local marked = form == MARK
	local priced = form == WHOLE or (marked and lk.FarPrice)
	local o = tag.Opt
	if o then
		o.Word.Visible = lk.TierWord and form == WHOLE and (tag.Focus or tag.Locked)
		o.GemBox.Visible = lk.Gem or marked
		o.Lead.Visible = not marked and tag.LeadCount > 0
		o.Under.Visible = not marked and tag.UnderCount > 0
		o.ChipRow.Visible = lk.ChipUnder and priced
	end
	local st = tag.Stk
	if st then
		-- far or crowded: the rarity's word and what the fish needs, no size, no icons, no name
		st.Row.Visible = not marked and st.RowOn
		st.Req.Visible = not marked
	end
	tag.Name.Visible = not marked
	tag.Chip.Visible = priced
	-- a mark of a Legendary or rarer fish is bigger: the rare fish are the ones seen from far off
	local size = if marked and tag.Rare >= SHINY then tag.Size * 1.3 else tag.Size
	tag.Scale.Scale = size * hudScale
end

local wordClock: number? = nil -- in Studio the workspace's "WordClock" holds the words' animation at that time, for frames
local function followAlt(camera: Camera)
	local t = wordClock or os.clock()
	for _, tag in alts do
		local st = tag.Stk
		if st and st.Animated and tag.Fish and tag.Frame.Visible then
			shimmer(tag, st, t)
		end
		local fish = tag.Fish
		local root = fish and fish.PrimaryPart
		if root and tag.Locked then
			local x, y = pin(tag.Wide, tag.High, camera:WorldToViewportPoint(root.Position + tag.Offset), camera)
			tag.Frame.Visible = true
			tag.Frame.Position = UDim2.fromOffset(x, y)
		elseif root and not tag.Crowded then
			local point = camera:WorldToViewportPoint(root.Position + tag.Offset)
			local onScreen = point.Z > 0
			tag.Frame.Visible = onScreen
			if onScreen then
				tag.Frame.Position = UDim2.fromOffset(point.X, point.Y)
			end
		elseif fish then
			tag.Frame.Visible = false
		end
	end
end

local function clearAlt(tag: Alt)
	tag.Fish = nil
	tag.Crowded = false
	tag.Frame.Visible = false
end

local function updateAlt(
	lk: Look,
	camera: Camera,
	zones: { Zones.Zone },
	maxOxygen: number,
	ridden: Model?,
	locked: Model?,
	hopping: boolean
)
	look(camera, ridden, locked, lk.RareReach)
	for _, tag in alts do
		local fish = tag.Fish
		if fish and (fish.Parent == nil or fish.PrimaryPart == nil or not wanted(fish, locked)) then
			clearAlt(tag)
		end
	end
	local function has(fish: Model): boolean
		for _, tag in alts do
			if tag.Fish == fish then
				return true
			end
		end
		return false
	end
	local function giveAlt(fish: Model)
		for _, tag in alts do
			if not tag.Fish then
				putAlt(tag, fish, lk)
				return
			end
		end
	end
	if locked and locked.Parent and not has(locked) then
		giveAlt(locked)
	end
	for i = 1, picked do
		if not has(picks[i]) then
			giveAlt(picks[i])
		end
	end

	local eye = camera.CFrame.Position
	local middle = camera.ViewportSize / 2
	local focus: Alt? = nil
	local focusBy = math.huge
	for _, tag in alts do
		local fish = tag.Fish
		local root = fish and fish.PrimaryPart
		if fish and root then
			local isLocked = fish == locked
			local zone = Zones.locate(zones, root.Position)
			local land = if zone then zone.Index else 1
			local needs = Config.required(land, tag.TierName)
			if needs ~= tag.Needs then
				tag.Needs = needs
				tag.Need.Text = Kit.short(needs)
			end
			local seconds = Config.secondsOn(land, tag.TierName, maxOxygen, tag.KindOf)
			local state = if Config.strained(land, tag.TierName, maxOxygen) or seconds < Kit.HoldShort
				then 3
				elseif seconds >= Kit.HoldFine then 1
				else 2
			if state ~= tag.State then
				tag.State = state
				local tooStrong = state == 3
				local bright = lk.Bright and state == 1
				tag.Need.TextColor3 = if tooStrong or bright then Kit.White else NEED[state]
				tag.Hold.TextColor3 = NEED[state]
				tag.Chip.BackgroundColor3 = if tooStrong
					then Kit.Danger
					elseif bright then Color3.fromRGB(38, 168, 72)
					else Kit.Deep
				tag.Chip.BackgroundTransparency = if tooStrong or bright then 0.04 elseif lk.ChipClear then 1 else 0.25
				local st = tag.Stk
				if st then
					st.ChipEdge.Enabled = tooStrong
				end
				tag.Name.TextTransparency = if lk.Dim and tooStrong then 0.45 else 0
			end
			local holdText = if not (isLocked and hopping)
				then ""
				elseif state == 3 then "TOO STRONG!"
				else "holds " .. Kit.seconds(seconds) .. " s"
			if holdText ~= tag.HoldText then
				tag.HoldText = holdText
				tag.Hold.Text = holdText
				tag.Hold.Visible = holdText ~= ""
			end
			local distance = (root.Position - eye).Magnitude
			tag.Distance = distance
			tag.Locked = isLocked
			tag.Focus = false
			tag.Extra = if holdText ~= "" then HOLD_HIGH else 0
			tag.Size = if isLocked then 1.2 elseif distance < 60 then 1 else 0.86
			local want = WHOLE
			if isLocked then
				want = WHOLE
			elseif lk.Focus then
				want = MARK
			else
				if lk.NameFrom and distance >= lk.NameFrom then
					want = NAME
				end
				if lk.ReachPrice and distance >= Config.Jump.GrabRange then
					want = NAME
				end
				if distance >= lk.MarkFrom then
					want = MARK
				end
			end
			tag.Want = want
			local point = camera:WorldToViewportPoint(root.Position + tag.Offset)
			tag.Rank = if isLocked then -2 elseif point.Z > 0 then distance else math.huge
			tag.Point = point
			tag.X = point.X
			tag.Y = point.Y
			-- the fish in focus, for a look that draws only one whole: nearest the middle of the screen, in reach
			if lk.Focus and point.Z > 0 and distance < Config.Jump.GrabRange then
				local by = (Vector2.new(point.X, point.Y) - middle).Magnitude
				if by < focusBy then
					focus, focusBy = tag, by
				end
			end
		end
	end
	if lk.Focus and not locked and focus then
		focus.Focus = true
		focus.Want = WHOLE
		focus.Rank = -1
		focus.Size = math.max(focus.Size, 1.05)
	end

	local count = 0
	for _, tag in alts do
		if tag.Fish then
			count += 1
			local at = count
			while at > 1 and altOrder[at - 1].Rank > tag.Rank do
				altOrder[at] = altOrder[at - 1]
				at -= 1
			end
			altOrder[at] = tag
		end
	end
	for i = 1, count do
		local tag = altOrder[i]
		local form = tag.Want
		local crowded = tag.Rank == math.huge
		if tag.Locked then
			roomAlt(tag, WHOLE, lk)
			tag.X, tag.Y = pin(tag.Wide, tag.High, tag.Point, camera)
		elseif not crowded then
			roomAlt(tag, form, lk)
			crowded = clashAlt(tag, i - 1)
			if crowded and form ~= MARK then
				form = MARK
				roomAlt(tag, form, lk)
				crowded = clashAlt(tag, i - 1)
			end
			-- in the hop the aim is at the middle of the screen: a tag that would sit under its ring is left out
			-- (the fish just left is often right there; the locked fish's tag is moved clear instead, in pin)
			if not crowded and hopping and underAim(tag.X, tag.Y, tag.Wide, tag.High, camera) then
				crowded = true
			end
		end
		tag.Crowded = crowded
		if not crowded then
			shapeAlt(tag, form, lk)
		end
	end
	followAlt(camera)
end

-- Which tags are drawn: Kit.FishTags, or in Studio the workspace's "FishTags" (to try them in a playtest)
local function chosen(): number
	if RunService:IsStudio() then
		local forced = workspace:GetAttribute("FishTags")
		if type(forced) == "number" then
			return forced
		end
	end
	return Kit.FishTags
end

local layer: Instance? = nil
local built = -1

-- The pool of tags for the chosen look; made again when the choice changes (only ever in Studio)
local function build(option: number)
	for _, tag in tags do
		tag.Frame:Destroy()
	end
	for _, tag in alts do
		tag.Frame:Destroy()
	end
	table.clear(tags)
	table.clear(alts)
	built = option
	local parent = layer
	if not parent then
		return
	end
	local lk = Tags.Looks[option]
	for i = 1, POOL do
		if lk then
			alts[i] = makeAlt(parent, lk)
		else
			tags[i] = make(parent)
		end
	end
end

function Tags.build(parent: Instance)
	layer = parent
	build(chosen())
end

function Tags.scale(value: number)
	hudScale = value
	for _, tag in tags do
		tag.Size = 0
	end
	for _, tag in alts do
		tag.Drawn = ""
	end
end

function Tags.hide()
	for _, tag in tags do
		if tag.Fish then
			clear(tag)
		end
	end
	for _, tag in alts do
		if tag.Fish then
			clearAlt(tag)
		end
	end
	sinceLook = math.huge
end

-- zones: the lands; maxOxygen: the player's; ridden: the fish under the player; locked: the fish a grab would take;
-- hopping: whether the player is in the hop
function Tags.update(
	dt: number,
	zones: { Zones.Zone },
	maxOxygen: number,
	ridden: Model?,
	locked: Model?,
	hopping: boolean
)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	sinceLook += dt
	-- the lock changing is looked at soon, not at the next quarter second, so the big tag and the hop button don't
	-- disagree for long (a tag could stay big for a quarter of a second after its lock was gone)
	if locked ~= lastLocked and sinceLook >= QUICK then
		sinceLook = math.huge
	end
	local lk = Tags.Looks[built]
	if sinceLook < PERIOD then
		if lk then
			followAlt(camera)
		else
			follow(camera)
		end
		return
	end
	sinceLook = 0
	lastLocked = locked
	if locked and not hopping and not LOCKED_WHILE_RIDING then
		locked = nil
	end
	local option = chosen()
	local nowPicks, nowKey = wordChoice()
	local nowSize = sizeChoice()
	if RunService:IsStudio() then
		local held = workspace:GetAttribute("ShineAt")
		shineAt = if type(held) == "number" then held else nil
		local clock = workspace:GetAttribute("WordClock")
		wordClock = if type(clock) == "number" then clock else nil
	end
	if nowKey ~= wordKey or nowSize ~= sizeAt then
		wordPicks, wordKey, sizeAt = nowPicks, nowKey, nowSize
		built = -1
	end
	if option ~= built then
		build(option)
		lk = Tags.Looks[built]
	end
	if lk then
		updateAlt(lk, camera, zones, maxOxygen, ridden, locked, hopping)
		return
	end
	look(camera, ridden, locked)
	for _, tag in tags do
		local fish = tag.Fish
		if fish and (fish.Parent == nil or fish.PrimaryPart == nil or not wanted(fish, locked)) then
			clear(tag)
		end
	end
	if locked and locked.Parent and not tagged(locked) then
		give(locked)
	end
	for i = 1, picked do
		if not tagged(picks[i]) then
			give(picks[i])
		end
	end

	local eye = camera.CFrame.Position
	for _, tag in tags do
		local fish = tag.Fish
		local root = fish and fish.PrimaryPart
		if fish and root then
			local isLocked = fish == locked
			-- what it needs, and how long a full meter would last on it, where it swims now: as the server counts
			local zone = Zones.locate(zones, root.Position)
			local land = if zone then zone.Index else 1
			local needs = Config.required(land, tag.TierName)
			if needs ~= tag.Needs then
				tag.Needs = needs
				tag.Need.Text = Kit.short(needs)
			end
			local seconds = Config.secondsOn(land, tag.TierName, maxOxygen, tag.KindOf) -- (longer on a Tank)
			local state = if Config.strained(land, tag.TierName, maxOxygen) or seconds < Kit.HoldShort
				then 3
				elseif seconds >= Kit.HoldFine then 1
				else 2
			if state ~= tag.State then
				tag.State = state
				local tooStrong = state == 3
				tag.Need.TextColor3 = if tooStrong then Kit.White else NEED[state]
				tag.Hold.TextColor3 = NEED[state]
				tag.Plate.BackgroundTransparency = if tooStrong then 0.04 else 1
				tag.PlateEdge.Enabled = tooStrong
			end
			local holdText = if not (isLocked and hopping)
				then ""
				elseif state == 3 then "TOO STRONG!"
				else "holds " .. Kit.seconds(seconds) .. " s"
			if holdText ~= tag.HoldText then
				tag.HoldText = holdText
				tag.Hold.Text = holdText
				tag.Hold.Visible = holdText ~= ""
			end
			local distance = (root.Position - eye).Magnitude
			tag.Locked = isLocked
			tag.Far = not isLocked and distance >= FAR
			tag.FullSize = if isLocked then 1.25 elseif distance < 60 then 0.9 else 0.74
			tag.SmallSize = if distance < FAR then 0.9 elseif distance < 170 then 0.84 else 0.76
			tag.Extra = if holdText ~= "" then HOLD_HIGH else 0
			-- its place in the queue, and where its words would sit
			local point = camera:WorldToViewportPoint(root.Position + tag.Offset)
			tag.Rank = if isLocked then -1 elseif point.Z > 0 then distance else math.huge
			if isLocked then
				room(tag, false)
				tag.X, tag.Y = pin(tag.Wide, tag.High, point, camera)
			else
				tag.X = point.X
				tag.Y = point.Y
			end
		end
	end

	-- room on the screen, nearest first: a tag whose words would land on one already placed is cut down to the bubble
	-- and the number, and left out only when that has no room either
	local count = 0
	for _, tag in tags do
		if tag.Fish then
			count += 1
			local at = count
			while at > 1 and order[at - 1].Rank > tag.Rank do
				order[at] = order[at - 1]
				at -= 1
			end
			order[at] = tag
		end
	end
	for i = 1, count do
		local tag = order[i]
		local crowded = tag.Rank == math.huge
		local small = tag.Far
		if not crowded then
			room(tag, small)
			crowded = clash(tag, i - 1)
			if crowded and not small and not tag.Locked then
				small = true
				room(tag, small)
				crowded = clash(tag, i - 1)
			end
		end
		tag.Crowded = crowded
		if not crowded then
			shape(tag, small)
		end
	end
	follow(camera)
end

return Tags
