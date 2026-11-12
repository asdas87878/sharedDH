--!strict
-- A tag over each of the nearest wild fish, stacked as the reference stacks its own: the rarity in its colour, the
-- name, and what the fish needs (the bubble and a number). Ours: the number is green when you would hold the fish two
-- seconds or more, yellow when it will be short, red when it is too strong; and the locked fish's tag is a quarter
-- bigger and, in the hop, says how long it holds.
-- A handful of tags, made once and moved from fish to fish. The fish are looked over a few times a second, never per
-- frame, and a label's text is set only when its fish changes.
-- The tags are frames on the screen, put over their fish each frame (six points turned from the world to the screen).
-- They were BillboardGuis first: those attached to the fish and reported themselves on, but drew nothing in Studio
-- (2026-11-12), so they are drawn the way the rest of the HUD is.
-- A herd is the usual case, so tags mustn't pile up: they are placed nearest first (the locked fish before all), and
-- a tag whose words would land on one already placed is left out until the next look. More fish are tagged than can
-- show at once so that leaving some out still leaves a few to read. A far fish's tag is drawn smaller.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Zones = require(ReplicatedStorage.Shared.Zones)
local Kit = require(script.Parent.Kit)
local State = require(script.Parent.Parent.Lib.State)

local Tags = {}

local POOL = 10
local REACH = 260 -- studs: fish further off get no tag
local PERIOD = 0.25 -- seconds between looks at the herd
-- the room a tag's words take at size 1, to tell when two would land on each other (the frame itself is wider)
local WORDS_WIDE = 118
local WORDS_HIGH = 43
local HOLD_HIGH = 14 -- the extra line on the locked fish in the hop
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
	Need: TextLabel,
	Hold: TextLabel,
	Fish: Model?,
	TierName: string,
	Size: number,
	State: number,
	HoldText: string,
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
		Padding = UDim.new(0, -3),
	}, root)
	local tier = Kit.text({ Size = UDim2.fromOffset(260, 15), TextSize = 12, LayoutOrder = 1 }, root)
	local tierGradient = Kit.gradient(tier, Kit.White, Kit.White)
	local name = Kit.text({ Size = UDim2.fromOffset(260, 17), TextSize = 13.5, LayoutOrder = 2 }, root)
	local needRow = Kit.new("Frame", {
		Size = UDim2.fromOffset(260, 15),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
	}, root)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, needRow)
	Kit.text({
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 15),
		TextSize = 9.5,
		Text = "Needs",
		LayoutOrder = 1,
	}, needRow, 1.8)
	Kit.bubble(needRow, 11).LayoutOrder = 2
	local need = Kit.text({
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 15),
		TextSize = 12,
		LayoutOrder = 3,
	}, needRow)
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
		Need = need,
		Hold = hold,
		Fish = nil,
		TierName = "",
		Size = 0,
		State = 0,
		HoldText = "",
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
	tag.Offset = Vector3.new(0, kind.Size.Y * 0.5 + 2.5, 0)
	tag.Name.Text = kind.Name
	tag.TierName = kind.Tier
	tag.Tier.Text = kind.Tier
	Kit.tierColours(tag.Tier, tag.TierGradient, kind.Tier, Config.Tiers)
	local required = fish:GetAttribute("Required")
	tag.Need.Text = Kit.short(if type(required) == "number" then required else kind.Required)
	tag.State = 0
end

-- Each tag over its fish, every frame: the one thing here that runs per frame
local function follow(camera: Camera)
	for _, tag in tags do
		local fish = tag.Fish
		local root = fish and fish.PrimaryPart
		if root and not tag.Crowded then
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
	if sinceLook < PERIOD then
		follow(camera)
		return
	end
	sinceLook = 0
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
			-- how long a full meter would last on it where it swims, as the game counts it
			local seconds = State.secondsOn(fish)
			if not seconds then
				local zone = Zones.locate(zones, root.Position)
				seconds = maxOxygen / math.max(Config.drain(if zone then zone.Index else 1, tag.TierName), 0.001)
			end
			local state = if seconds >= Kit.HoldFine then 1 elseif seconds >= Kit.HoldShort then 2 else 3
			if state ~= tag.State then
				tag.State = state
				tag.Need.TextColor3 = NEED[state]
				tag.Hold.TextColor3 = NEED[state]
			end
			local holdText = if isLocked and hopping then "holds " .. Kit.seconds(seconds) .. " s" else ""
			if holdText ~= tag.HoldText then
				tag.HoldText = holdText
				tag.Hold.Text = holdText
				tag.Hold.Visible = holdText ~= ""
			end
			local distance = (root.Position - eye).Magnitude
			local size = if isLocked
				then 1.25
				elseif distance < 60 then 0.9
				elseif distance < 110 then 0.74
				elseif distance < 170 then 0.6
				else 0.5
			if size ~= tag.Size then
				tag.Size = size
				tag.Scale.Scale = size * hudScale
			end
			-- its place in the queue, and where its words would sit
			local point = camera:WorldToViewportPoint(root.Position + tag.Offset)
			tag.Rank = if isLocked then -1 elseif point.Z > 0 then distance else math.huge
			tag.X = point.X
			tag.Y = point.Y
			tag.Wide = WORDS_WIDE * size * hudScale
			tag.High = (WORDS_HIGH + (if holdText ~= "" then HOLD_HIGH else 0)) * size * hudScale
		end
	end

	-- room on the screen, nearest first: a tag is left out when its words would land on one already placed
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
		if not crowded then
			for j = 1, i - 1 do
				local placed = order[j]
				if
					not placed.Crowded
					and math.abs(tag.X - placed.X) < (tag.Wide + placed.Wide) / 2
					and tag.Y - tag.High < placed.Y
					and placed.Y - placed.High < tag.Y
				then
					crowded = true
					break
				end
			end
		end
		tag.Crowded = crowded
	end
	follow(camera)
end

return Tags
