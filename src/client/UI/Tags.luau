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
	local name = Kit.text({ Size = UDim2.fromOffset(260, 16), TextSize = 13, LayoutOrder = 2 }, root)
	local needRow = Kit.new("Frame", {
		Size = UDim2.fromOffset(260, 20),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
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
		LayoutOrder = 4,
		Visible = false,
	}, root)
	return {
		Frame = root,
		Offset = Vector3.zero,
		Scale = scale,
		Tier = tier,
		TierGradient = tierGradient,
		Name = name,
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

function Tags.build(parent: Instance)
	for i = 1, POOL do
		tags[i] = make(parent)
	end
end

function Tags.scale(value: number)
	hudScale = value
	for _, tag in tags do
		tag.Size = 0
	end
end

local function clear(tag: Tag)
	tag.Fish = nil
	tag.Crowded = false
	tag.Frame.Visible = false
end

function Tags.hide()
	for _, tag in tags do
		if tag.Fish then
			clear(tag)
		end
	end
	sinceLook = math.huge
end

local function put(tag: Tag, fish: Model)
	local kind = Config.FishById[fish:GetAttribute("FishType") :: string]
	local root = fish.PrimaryPart
	if not kind or not root then
		return
	end
	tag.Fish = fish
	-- this fish's own size (its roll: "x1.23") and variant, after its name
	local size = Config.sizeOf(fish)
	local variant = Config.variantOf(fish)
	tag.Offset = Vector3.new(0, kind.Size.Y * size * 0.5 + 2.5, 0)
	tag.Name.Text = string.format("%s%s x%.2f", if variant ~= "" then variant .. " " else "", kind.Name, size)
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
		tag.Name.Visible = not small
		tag.NeedWord.Visible = not small
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
	tag.High = (if small then SMALL_HIGH else WORDS_HIGH + tag.Extra) * size
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
local function pin(tag: Tag, point: Vector3, camera: Camera): (number, number)
	local size = camera.ViewportSize
	local side = tag.Wide / 2 + 8 * hudScale
	local x, y = point.X, point.Y
	if point.Z <= 0 then
		x = size.X - x
		y = size.Y
	end
	return math.clamp(x, side, math.max(size.X - side, side)),
		math.clamp(y, tag.High + 64 * hudScale, math.max(size.Y - 92 * hudScale, tag.High + 64 * hudScale))
end

-- Each tag over its fish, every frame: the one thing here that runs per frame
local function follow(camera: Camera)
	for _, tag in tags do
		local fish = tag.Fish
		local root = fish and fish.PrimaryPart
		if root and tag.Locked then
			local x, y = pin(tag, camera:WorldToViewportPoint(root.Position + tag.Offset), camera)
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
local function look(camera: Camera, ridden: Model?, locked: Model?)
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
				if distance < REACH and to:Dot(ahead) > distance * 0.25 then
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
	if sinceLook < PERIOD then
		follow(camera)
		return
	end
	sinceLook = 0
	lastLocked = locked
	if locked and not hopping and not LOCKED_WHILE_RIDING then
		locked = nil
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
			local seconds = Config.secondsOn(land, tag.TierName, maxOxygen)
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
				tag.X, tag.Y = pin(tag, point, camera)
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
