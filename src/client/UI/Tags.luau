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
local function pin(wide: number, high: number, point: Vector3, camera: Camera): (number, number)
	local size = camera.ViewportSize
	local side = wide / 2 + 8 * hudScale
	local x, y = point.X, point.Y
	if point.Z <= 0 then
		x = size.X - x
		y = size.Y
	end
	return math.clamp(x, side, math.max(size.X - side, side)),
		math.clamp(y, high + 64 * hudScale, math.max(size.Y - 92 * hudScale, high + 64 * hudScale))
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
	local icons: Frame = Kit.new("Frame", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, STACK_ICON),
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		Visible = false,
	}, top)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 3),
	}, icons)
	Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 2) }, icons)
	-- line 2: the name, white for every rarity, with the thick dark edge (it reads on sand and on the pink reef)
	local name = Kit.text({
		Size = UDim2.fromOffset(WIDE, STACK_NAME),
		TextSize = 16,
		LayoutOrder = 2,
	}, root, 3)
	-- line 3: "Required: n" and the bubble; on a red plate when the fish is too strong
	local reqRow: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(WIDE, STACK_REQ),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
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

-- A three-line tag's rarity word and icons for its fish
local function putStack(st: StackParts, rare: number, tier: string, line: string, lk: Look)
	local text = string.upper(tier)
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
	local shiny = rare >= SHINY
	for _, spark in st.Sparks do
		spark.Visible = shiny
		spark.BackgroundColor3 = Kit.lighter(colour, 0.55)
	end
	Archetypes.icons(st.Icons, line, STACK_ICON)
end

-- The shimmer of Legendary and up on the three-line tag: the word's gradient swings, its glow breathes, the stars
-- turn; the Secret's rainbow goes all the way round. Per frame, on the tags drawn only
local function shimmer(tag: Alt, st: StackParts, t: number)
	local phase = t * 2.2 + tag.Rare
	if tag.TierName == "Secret" then
		st.WordFill.Rotation = (t * 70) % 360
	else
		st.WordFill.Rotation = st.Turn + math.sin(phase) * 28
	end
	st.GlowEdge.Transparency = (WORD_GLOW[tag.Rare] or { 0, 0.5 })[2] + math.sin(phase * 1.3) * 0.12
	local spin = (t * 90) % 360
	st.Sparks[1].Rotation = 45 + spin
	st.Sparks[2].Rotation = 45 - spin
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
	if size ~= "Normal" then
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
		putStack(st, tag.Rare, kind.Tier, line, lk)
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
		local word = st.WordWide + (if tag.Rare >= SHINY then 2 * (SPARK + 6) else 0)
		local number = 13 + 8 * #tag.Need.Text
		local wide, high
		if form == MARK then
			wide = math.max(word, number + 12)
			high = STACK_TOP + STACK_GAP + STACK_REQ
		else
			local icons = if tag.LeadCount > 0 then tag.LeadCount * (STACK_ICON + 3) + 4 else 0
			wide = math.max(word + icons, tag.NameWide, REQ_WIDE + number + 12)
			high = STACK_TOP + STACK_NAME + STACK_REQ + STACK_GAP * 2
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
		-- far or crowded: the rarity's word and what the fish needs, no icons, no name
		st.Icons.Visible = not marked and tag.LeadCount > 0
		st.Req.Visible = not marked
	end
	tag.Name.Visible = not marked
	tag.Chip.Visible = priced
	-- a mark of a Legendary or rarer fish is bigger: the rare fish are the ones seen from far off
	local size = if marked and tag.Rare >= SHINY then tag.Size * 1.3 else tag.Size
	tag.Scale.Scale = size * hudScale
end

local function followAlt(camera: Camera)
	local t = os.clock()
	for _, tag in alts do
		local st = tag.Stk
		if st and tag.Rare >= SHINY and tag.Fish and tag.Frame.Visible then
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
