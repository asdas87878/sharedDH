--!strict
-- The row of slots at the bottom middle (where the reference has its own): what you carry home this dive. Each slot is
-- a studded plate in the windows' stud (the user, 2026-11-25: "get rid of our water ones"; it was a tile of water
-- glass): an empty one dark and see-through, a filled one its rarity's colours, solid (gold for a Legendary, the
-- rainbow for a Secret), with the creature's picture, its name cut short, and its size and colour in words when it has
-- any. One word above the row: "3 CAUGHT".
-- The chosen catch has a square white ring a little outside its black outline, as the reference's (measured off the
-- user's screenshot, 2026-11-17: 5% of a slot thick, 3% out from the outline): the newest catch until the player
-- clicks another, and any caught slot while the mouse is over it ("it will just be on the last dino caught or the one
-- you select with the mouse when clicking, but should appear on hover"). A click fires Slots.Selected; back at your
-- dock, a click also fires Slots.Picked, which holds that fish over the head (AquariumController).
-- The picture is bigger than its slot and stands over the slot's top and sides ("scale the icons so that they all
-- overlap the inventory artistically"): the slot reads as what the fish rises out of. Where a fish sits in its picture
-- goes by its kind of picture (UI.Portrait), so every bust stands the same, every small fish the same.
-- Every caught slot has the light rim inside its black outline over a darker lip at the foot (2026-11-25; from
-- 2026-11-18 only the chosen one had it); the ring alone says which is chosen. Square corners; the names in
-- Gotham Black with a thin outline; the fish lower and more in the middle, nearer its name, still over the top edge;
-- the slots as far apart as the reference's (a gap of an eighth of a slot between their outlines); and a slot grows a
-- little under the mouse.
-- The ride fish (task e3, Hugo 2026-11-20: "1 should be first inventory slot while q should be a completely seperate
-- slot"; docs/design/equip.md): a slot of its own, with a small Q key cap at its corner in the shop's button look
-- (UI.Shop). It shows the equipped fish (the server's EquippedFish, EquipController calls Slots.equipped), with the
-- white ring while it is ridden on land and a small cross to unequip; empty, it says how ("HOLD A FISH, THEN Q", on
-- two short lines over it). It is not one of the numbered slots: 1 is always the first catch. Each numbered slot
-- shows its key (1 to 7) on a keyboard; Slots.pick(n) is the key's press, the very path of a click.
-- The row as it was before e3 (Hugo, 2026-11-20, task c1: "remove the many slots to the base again + the q but make
-- sure its all centered around the original slots, with the q slot just being a little to the side"): seven numbered
-- slots, the row's frame the very size and place it had, centred; the Q slot stands outside that frame, to its left,
-- APART gaps from slot 1, so it never moves the row.
-- The row is hidden while the game has no taming (State.Caught is nil). The picture is the creature's own model drawn
-- in a small window (UI.Portrait), which needs no upload; a creature with no model to draw yet shows its name alone.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local TweenService = game:GetService("TweenService")

local State = require(script.Parent.Parent.Lib.State)
local Kit = require(script.Parent.Kit)
local Portrait = require(script.Parent.Portrait)
local Shop = require(script.Parent.Shop)

local Slots = {}

local selectedEvent = Instance.new("BindableEvent")
-- Fired with (the catch's place in the list, the catch) when the player clicks a caught slot
Slots.Selected = selectedEvent.Event
local rideEvent = Instance.new("BindableEvent")
-- Fired with "Ride" (a click on the equipped slot: equip the held fish, else on or off it on land) or "Unequip" (its
-- cross)
Slots.Ride = rideEvent.Event
local pickedEvent = Instance.new("BindableEvent")
-- Fired with (the catch's place in the list, the catch or nil) on every click of a slot, an empty one too (holding a
-- fish over the head, AquariumController: the same slot again or an empty one puts it away)
Slots.Picked = pickedEvent.Event

export type Caught = { Id: string, Tier: string, Size: string?, Variant: string?, Key: number? }

local SIZE = 34 -- a slot on a phone; on a keyboard, BIG
local BIG = 46
-- The gap between two slots' faces: the reference's 8 pixels between outlines at 720 high (an eighth of a slot), and
-- the two outlines, which stand outside the faces
local GAP = 8
local BIG_GAP = 10
local COUNT = 7 -- the numbered slots, keys 1 to 7 (the hands hold Tame.Carry, 100: these are the best of them)
local APART = 2 -- the equipped slot's gap from slot 1, in gaps (it stands outside the row's frame)
local OUTLINE = 2
local HINT_FOOT = 7 -- the Q slot's words' foot, from the row's top (level with the count's: -6 + its 13)
local HINT_WIDE = 30 -- how much wider than a slot its words may run
local RING = 2.3 -- the white ring's thickness
local RING_GAP = 1.4 -- and its gap outside the black outline
local HOVER = 1.06 -- how much a slot grows under the mouse: its picture's overhang and this stay inside the gap
local FONT = Enum.Font.GothamBlack
local NAME_LINE = 1 -- the names' outline (was 1.6)
local BLACK = Color3.fromRGB(6, 8, 14) -- the outline: nearly black (it was the navy ink)

local holder: Frame
local count: TextLabel
local tiles: { any } = {} -- (the Tile of each, below)
local rings: { Frame } = {}

local keys: { TextLabel } = {}
-- the equipped slot (task e3)
type Ride = {
	Panel: Kit.Panel,
	Picture: Portrait.Portrait,
	Name: TextLabel,
	Rim: Frame,
	Lip: Frame,
	Pattern: ImageLabel,
	Variant: TextLabel,
	Size: TextLabel,
	Ring: Frame,
	Cap: any, -- (a Shop.Button)
	Cross: TextButton,
	Hint: TextLabel,
}
local ride: Ride
local rideItem: Caught? = nil
local rideOn = false

local current: { Caught } = {}
local bar: { number } = {} -- which fish stand in the slots, by Key, slot 1 first
local places: { number } = {} -- and where each is in the list (the server's asks go by that place)
local selected: number? = nil -- which catch has the white ring (its Key)
local hovered: number? = nil -- which slot the mouse is over
local lastCount = 0

-- An empty slot's plate: dark, see-through, level top to bottom. No drop shadow (it made a square slot read as taller
-- than wide: the user, 2026-11-17: "they almost look rectangular")
local PLATE: Kit.Style = {
	Top = Color3.fromRGB(26, 38, 62),
	Bottom = Color3.fromRGB(14, 22, 40),
	Fade = 0.42,
	Radius = 0,
	Outline = OUTLINE,
	Drop = 0,
	Bevel = false,
	Shine = false,
}
-- The studs on it: the windows' raised square (Kit.Textures.Emboss), a whole number to a slot so none is cut, fading
-- toward the foot where the name is
local STUDS = 4
local STUDS_EMPTY = 0.62 -- how see-through they are on an empty slot
local STUDS_CAUGHT = 0.1 -- and on a caught one
local STUDS_TAIL = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.4, 0.15),
	NumberSequenceKeypoint.new(1, 0.75),
})
local RING_HOVER = 0.45 -- how see-through the ring is on a slot under the mouse that isn't the chosen one
local BRIGHTER = 0.14 -- how far a Legendary's, a Mythic's and a Secret's colours go toward white
-- A fish's size and colour, in words down its slot's left side (nothing for a plain one of the normal size); the sizes
-- in the fish tags' colours (UI.Tags, UI.TankPanel), cool to hot
local TAG_SIZE = { Phone = 6.5, Keys = 8.5 }
local SIZE_HUE: { [string]: Color3 } = {
	Tiny = Color3.fromRGB(176, 206, 234),
	Big = Color3.fromRGB(84, 226, 190),
	Giant = Color3.fromRGB(110, 200, 255),
	Huge = Color3.fromRGB(255, 160, 48),
	Colossal = Color3.fromRGB(255, 96, 100),
}
-- A caught slot's highlight (the user, 2026-11-17: "the highlight between the outline and the inner bit isnt placed
-- correctly, and isnt thick enough and doesnt fade correctly"): a light band right inside the black outline, 5% of a slot wide, along the top and down both sides but not the foot;
-- nearly white along the top, fading down the sides to a faint tint at the bottom. The foot has a darker band instead
local RIM = 2.3
local RIM_TOP = 0.25 -- how see-through the white is along the top
local RIM_SIDES = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.3),
	NumberSequenceKeypoint.new(0.5, 0.58),
	NumberSequenceKeypoint.new(1, 0.85),
})
local LIP = 2.5 -- the darker band along the foot
local LIP_FADE = 0.6 -- black at 40% over the slot's colour
-- The picture's window, in slots: wider than the slot by 5% a side, from 19% above its top to 3% above its foot, so a
-- fish stands a little over the top edge and comes down to its name
local WINDOW = { Wide = 1.1, High = 1.16, Foot = 0.97 }
-- Its shape, which is what frames the creature (UI.Portrait): the catch screen's tiles frame by it too, so a fish there
-- is the very picture it is in its slot (Hugo, 2026-11-19)
Slots.Aspect = WINDOW.Wide / WINDOW.High
local HOVER_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- The white ring: solid on the chosen catch, fainter on another caught slot under the mouse
local function showRings()
	for i = 1, COUNT do
		local key = bar[i]
		local chosen = key ~= nil and key == selected
		rings[i].Visible = chosen or (key ~= nil and i == hovered)
		local line = rings[i]:FindFirstChildOfClass("UIStroke")
		if line then
			line.Transparency = if chosen then 0 else RING_HOVER
		end
	end
end

-- Each colour of a sequence a little nearer white
local function brighter(colours: ColorSequence): ColorSequence
	local points = {}
	for _, point in colours.Keypoints do
		table.insert(points, ColorSequenceKeypoint.new(point.Time, Kit.lighter(point.Value, BRIGHTER)))
	end
	return ColorSequence.new(points)
end

-- A caught slot's colours: its rarity's colour as a mid tone, a little lighter at the top and a little darker at the
-- foot, so the white band inside the outline shows against it (the reference's: (255, 106, 143) to (228, 83, 119)).
-- The top three keep their own gold, ember and rainbow, a little brighter
local function tileFill(tier: string): (ColorSequence, number)
	local entry = Config.Tiers[tier]
	if tier == "Legendary" or tier == "Mythic" or tier == "Secret" or not entry then
		local colours, turn = Kit.tierFill(tier, Config.Tiers)
		return brighter(colours), turn
	end
	local colour: Color3 = entry.Colour
	return ColorSequence.new(Kit.lighter(colour, 0.08), Kit.darker(colour, 0.1)), 90
end

-- One slot of the row, its look and its parts (a numbered one, or the equipped one), its middle `x` from the row's left
type Tile = {
	Panel: Kit.Panel,
	Rim: Frame,
	Lip: Frame,
	Pattern: ImageLabel,
	Variant: TextLabel,
	Size: TextLabel,
	Ring: Frame,
	Hit: TextButton,
	Picture: Portrait.Portrait,
	Name: TextLabel,
	Up: Tween,
	Down: Tween,
}
local function makeTile(x: number): Tile
	-- (held by its middle, so it grows from there under the mouse)
	local slot = Kit.panel(holder, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, x, 1, -SIZE / 2),
		Size = UDim2.fromOffset(SIZE, SIZE),
	}, PLATE)
	local look = slot.Look
	look.Outline.Color = BLACK
	look.Outline.LineJoinMode = Enum.LineJoinMode.Miter -- (square corners: Kit's outlines are rounded)
	Kit.new("UIGradient", { Rotation = 90 }, look.Outline) -- (a coloured fish's colour: tint)
	local pattern: ImageLabel = Kit.new("ImageLabel", {
		Name = "Studs",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = Kit.Textures.Emboss,
		ImageTransparency = STUDS_EMPTY,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromScale(1 / STUDS, 1 / STUDS),
		ZIndex = 0,
	}, slot.Face)
	Kit.new("UIGradient", { Transparency = STUDS_TAIL, Rotation = 90 }, pattern)
	-- a caught fish's darker lip along the foot and its light rim inside the outline (shown when caught)
	local lip = Kit.new("Frame", {
		Name = "Lip",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, LIP),
		BackgroundColor3 = BLACK,
		BackgroundTransparency = LIP_FADE,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 1,
	}, slot.Face)
	local rim = Kit.new("Frame", {
		Name = "Rim",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 1,
	}, slot.Face)
	Kit.new("Frame", { -- along the top, the whole width
		Name = "Top",
		Size = UDim2.new(1, 0, 0, RIM),
		BackgroundColor3 = Kit.White,
		BackgroundTransparency = RIM_TOP,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, rim)
	for _, right in { false, true } do -- down each side, from under the top band to the darker foot
		local side = Kit.new("Frame", {
			Name = if right then "Right" else "Left",
			AnchorPoint = Vector2.new(if right then 1 else 0, 0),
			Position = UDim2.new(if right then 1 else 0, 0, 0, RIM),
			Size = UDim2.new(0, RIM, 1, -(RIM + LIP)),
			BackgroundColor3 = Kit.White,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, rim)
		Kit.new("UIGradient", { Transparency = RIM_SIDES, Rotation = 90 }, side)
	end
	-- the white ring, square, a little outside the black outline; under the picture, which may stand over it
	local out = OUTLINE + RING_GAP
	local ring = Kit.new("Frame", {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, out * 2, 1, out * 2),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 0,
	}, slot.Frame)
	local ringLine = Kit.stroke(ring, RING, Kit.White)
	ringLine.LineJoinMode = Enum.LineJoinMode.Miter
	-- a little bigger under the mouse, with the ring
	local grow = Kit.new("UIScale", {}, slot.Frame)
	local hit: TextButton = Kit.new("TextButton", {
		Name = "Hit",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 5,
	}, slot.Frame)
	local picture = Portrait.new(slot.Face, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, WINDOW.Foot),
		Size = UDim2.fromScale(WINDOW.Wide, WINDOW.High),
		Aspect = Slots.Aspect,
		Visible = false,
		ZIndex = 2,
	})
	local name = Kit.text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -1),
		Size = UDim2.fromOffset(SIZE + 8, 10),
		TextSize = 8.5,
		Font = FONT,
		ZIndex = 3,
	}, slot.Face, NAME_LINE)
	local function tag(which: string, row: number): TextLabel
		return Kit.text({
			Name = which,
			Position = UDim2.new(0, 2, 0.24 + row * 0.2, 0),
			Size = UDim2.new(1, -2, 0.2, 0),
			TextSize = TAG_SIZE.Keys,
			Font = FONT,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 3,
		}, slot.Face, NAME_LINE)
	end
	return {
		Panel = slot,
		Rim = rim,
		Lip = lip,
		Pattern = pattern,
		Variant = tag("VariantWord", 0),
		Size = tag("SizeWord", 1),
		Ring = ring,
		Hit = hit,
		Picture = picture,
		Name = name,
		Up = TweenService:Create(grow, HOVER_INFO, { Scale = HOVER }),
		Down = TweenService:Create(grow, HOVER_INFO, { Scale = 1 }),
	}
end

-- (a coloured fish's slot: its outline and name in its colour, 2026-11-24: a Rainbow's looked as a plain one's)
local function tint(slot: Kit.Panel, name: TextLabel, variant: string?)
	local colours = Kit.variantFill(variant)
	slot.Look.Outline.Color = if colours then Kit.White else BLACK
	local edge = slot.Look.Outline:FindFirstChildOfClass("UIGradient")
	if edge then
		edge.Color = colours or ColorSequence.new(Kit.White)
	end
	local words = name:FindFirstChildOfClass("UIGradient") or Kit.new("UIGradient", { Rotation = 90 }, name)
	words.Color = colours or ColorSequence.new(Kit.White)
	words.Rotation = if variant == "Rainbow" then 0 else 90
end

-- A fish's colour and size in words (the first alone moves up into the only row)
local function tags(t: any, item: Caught?)
	local variant = item and Kit.variantFill(item.Variant)
	local size = item and item.Size
	local sized = size ~= nil and SIZE_HUE[size] ~= nil
	local top: TextLabel, under: TextLabel = t.Variant, t.Size
	top.Text = if item and variant then string.upper(item.Variant :: string) else ""
	local words = top:FindFirstChildOfClass("UIGradient") or Kit.new("UIGradient", {}, top)
	words.Color = variant or ColorSequence.new(Kit.White)
	words.Rotation = if item and item.Variant == "Rainbow" then 0 else 90
	under.Text = if sized then string.upper(size :: string) else ""
	under.TextColor3 = if sized then SIZE_HUE[size :: string] else Kit.White
	under.Position = UDim2.new(0, 2, if variant then 0.44 else 0.24, 0)
end

local function paint(t: any, item: Caught?)
	local slot: Kit.Panel = t.Panel
	local name: TextLabel = t.Name
	local fill = slot.Look.Fill
	if item then
		local kind = Config.FishById[item.Id]
		slot.Face.BackgroundTransparency = 0
		fill.Color, fill.Rotation = tileFill(item.Tier)
		t.Pattern.ImageTransparency = STUDS_CAUGHT
		local words = if kind then kind.Name else item.Id
		-- cut short with a full stop, never after a space ("Great White": "Great.", not "Great .")
		name.Text = if #words > 7 then (string.gsub(string.sub(words, 1, 6), "%s+$", "")) .. "." else words
		tint(slot, name, item.Variant)
		t.Picture.Frame.Visible = t.Picture.show(item.Id)
	else
		slot.Face.BackgroundTransparency = PLATE.Fade or 0
		fill.Color = ColorSequence.new(PLATE.Top, PLATE.Bottom)
		fill.Rotation = 90
		t.Pattern.ImageTransparency = STUDS_EMPTY
		name.Text = ""
		tint(slot, name, nil)
		t.Picture.show(nil)
		t.Picture.Frame.Visible = false
	end
	t.Lip.Visible = item ~= nil
	t.Rim.Visible = item ~= nil
	tags(t, item)
end

local touchNow = false
local fitScale: UIScale? = nil
local screenWide = math.huge -- the HUD's width in its own units (HudController: Slots.fit)
local EDGE_PHONE = 8 -- the least room left between the hotbar and the screen's edges on a phone
local EDGE_KEYS = 176 -- and on a keyboard at the left, where the stat rows stand level with it (StatRows)
local FIT_LEAST = 0.8 -- the smallest the hotbar is shrunk to fit (34 studs a slot become 27 at the very narrowest)

-- Where slot n's middle is from the row's left (0: the equipped slot, left of the row's frame)
local function middleOf(n: number, size: number, gap: number): number
	if n == 0 then
		return -gap * APART - size / 2
	end
	return (n - 1) * (size + gap) + size / 2
end

-- The row's frame: the numbered slots only, as before e3 (so the Q slot never shifts it)
local function rowWidth(size: number, gap: number): number
	return COUNT * size + (COUNT - 1) * gap
end

-- What the equipped slot says above it, and its cap and cross
local function drawRide()
	if not ride then
		return
	end
	local item = rideItem
	paint(ride, item)
	ride.Ring.Visible = item ~= nil and rideOn
	ride.Cross.Visible = item ~= nil
	ride.Cap.Root.Visible = not touchNow
	ride.Hint.Text = if item and rideOn
		then "RIDING"
		elseif item then (if touchNow then "TAP TO RIDE" else "CLICK TO RIDE")
		elseif lastCount == 0 or State.Mode ~= "Dock" then "" -- (nothing to hold, or not where one is held, 2026-11-24)
		else (if touchNow then "HOLD A FISH, THEN TAP" else "HOLD A FISH, THEN Q")
end

function Slots.build(parent: Instance)
	holder = Kit.new("Frame", {
		Name = "Slots",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(rowWidth(SIZE, GAP), SIZE + 18),
		BackgroundTransparency = 1,
		Visible = false,
	}, parent)
	count = Kit.text({
		-- (lifted clear of the pictures, which stand a little over the slots' tops; over slot 1)
		Position = UDim2.fromOffset(0, -6),
		Size = UDim2.fromOffset(120, 13),
		TextSize = 12,
		Font = FONT,
		TextColor3 = Kit.Good,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, holder, 1.2)
	for i = 1, COUNT do
		local t = makeTile(middleOf(i, SIZE, GAP))
		local hit = t.Hit
		hit.MouseEnter:Connect(function()
			hovered = i
			t.Up:Play()
			showRings()
		end)
		hit.MouseLeave:Connect(function()
			if hovered == i then
				hovered = nil
			end
			t.Down:Play()
			showRings()
		end)
		hit.Activated:Connect(function()
			Slots.pick(i)
		end)
		-- its key, 1 to 7, at its top left (a keyboard only)
		keys[i] = Kit.text({
			Name = "Key",
			Position = UDim2.fromOffset(2, 1),
			Size = UDim2.fromOffset(10, 10),
			Text = tostring(i),
			TextSize = 9,
			Font = FONT,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 4,
		}, t.Panel.Face, NAME_LINE)
		tiles[i] = t
		rings[i] = t.Ring
	end
	-- the equipped slot, at the far left (task e3)
	local t = makeTile(middleOf(0, SIZE, GAP))
	t.Panel.Frame.Name = "Equipped"
	t.Hit.MouseEnter:Connect(function()
		t.Up:Play()
	end)
	t.Hit.MouseLeave:Connect(function()
		t.Down:Play()
	end)
	t.Hit.Activated:Connect(function()
		rideEvent:Fire("Ride")
	end)
	-- the Q key cap: a small shop button (UI.Shop), over the slot's top left corner; pressing it is the slot's press
	local cap = Shop.button(t.Panel.Frame, {
		Name = "QKey",
		Kind = "Cash",
		Text = "Q",
		TextSize = 11,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.fromOffset(16, 16),
	})
	cap.Edge.Thickness = 1.5
	cap.Root.ZIndex = 6
	cap.Root.Interactable = false
	-- the cross that unequips, over the top right corner
	local cross: TextButton = Kit.new("TextButton", {
		Name = "Unequip",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -1, 0, 1),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Kit.Coral,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		Text = "X",
		TextColor3 = Kit.White,
		TextSize = 10,
		Font = FONT,
		Visible = false,
		ZIndex = 7,
	}, t.Panel.Frame)
	Kit.corner(cross, 4)
	Kit.stroke(cross, 1.5, BLACK).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	cross.Activated:Connect(function()
		rideEvent:Fire("Unequip")
	end)
	-- what it is, just over it: centred on it, in two short lines when long, its foot level with "N CAUGHT"'s (it
	-- was one long line running off to the left, and was cut off at the screen's edge)
	local hint = Kit.text({
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromOffset(middleOf(0, SIZE, GAP), HINT_FOOT),
		Size = UDim2.fromOffset(SIZE + HINT_WIDE, 26),
		TextSize = 9,
		Font = FONT,
		TextColor3 = Kit.Sun,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Bottom,
	}, holder, 1.2)
	ride = {
		Panel = t.Panel,
		Picture = t.Picture,
		Name = t.Name,
		Rim = t.Rim,
		Lip = t.Lip,
		Pattern = t.Pattern,
		Variant = t.Variant,
		Size = t.Size,
		Ring = t.Ring,
		Cap = cap,
		Cross = cross,
		Hint = hint,
	}
	drawRide()
	State.ModeChanged.Event:Connect(drawRide)
	fitScale = Kit.new("UIScale", { Name = "Fit" }, holder)
end

-- Keeps the whole hotbar on the screen (grade issue 4): the numbered row stays centred while the Q slot and its words
-- at its left fit; when they don't, the row moves right just enough, and only when even that won't do, the whole
-- hotbar shrinks a little (never under FIT_LEAST)
local function fitRow(size: number, gap: number)
	if not holder or not fitScale then
		return
	end
	local ring = OUTLINE + RING_GAP
	local half = rowWidth(size, gap) / 2
	local left = half + gap * APART + size + math.max(ring, HINT_WIDE / 2)
	local right = half + ring
	local edgeLeft = if touchNow then EDGE_PHONE else EDGE_KEYS
	local edgeRight = EDGE_PHONE
	local wide = screenWide
	local f = 1
	local room = wide - edgeLeft - edgeRight
	if room < left + right then
		f = math.max(room / (left + right), FIT_LEAST)
	end
	local shift = math.max(0, left * f - (wide / 2 - edgeLeft))
	fitScale.Scale = f
	holder.Position = UDim2.new(0.5, shift, 1, if touchNow then -10 else -14)
end

function Slots.fit(wide: number)
	if wide ~= screenWide then
		screenWide = wide
		local size = if touchNow then SIZE else BIG
		local gap = if touchNow then GAP else BIG_GAP
		fitRow(size, gap)
	end
end

function Slots.place(touch: boolean)
	touchNow = touch
	local function tagSize(t: any)
		t.Variant.TextSize = if touch then TAG_SIZE.Phone else TAG_SIZE.Keys
		t.Size.TextSize = t.Variant.TextSize
	end
	local size = if touch then SIZE else BIG
	local gap = if touch then GAP else BIG_GAP
	holder.Size = UDim2.fromOffset(rowWidth(size, gap), size + 18)
	-- its bottom edge level with the stat rows' on a keyboard (StatRows.place)
	holder.Position = UDim2.new(0.5, 0, 1, if touch then -10 else -14)
	for i = 1, COUNT do
		local t = tiles[i]
		t.Panel.Frame.Size = UDim2.fromOffset(size, size)
		t.Panel.Frame.Position = UDim2.new(0, middleOf(i, size, gap), 1, -size / 2)
		t.Name.TextSize = if touch then 8.5 else 11
		tagSize(t)
		keys[i].Visible = not touch
		keys[i].TextSize = if touch then 9 else 11
	end
	count.Position = UDim2.fromOffset(0, -6)
	if ride then
		ride.Panel.Frame.Size = UDim2.fromOffset(size, size)
		ride.Panel.Frame.Position = UDim2.new(0, middleOf(0, size, gap), 1, -size / 2)
		ride.Name.TextSize = if touch then 8.5 else 11
		tagSize(ride)
		ride.Hint.Position = UDim2.fromOffset(middleOf(0, size, gap), HINT_FOOT)
		ride.Hint.Size = UDim2.fromOffset(size + HINT_WIDE, 26)
		ride.Hint.TextSize = if touch then 9 else 11
		local cap = if touch then 14 else 18
		ride.Cap.Root.Size = UDim2.fromOffset(cap, cap)
		ride.Cap.Label.TextSize = if touch then 10 else 12
		local cross = if touch then 24 else cap - 2 -- (a fingertip's on a phone)
		ride.Cross.Size = UDim2.fromOffset(cross, cross)
		ride.Cross.TextSize = if touch then 14 else 10
		drawRide()
	end
	fitRow(size, gap)
end

-- A numbered slot pressed (a click, a tap, or its key 1 to 7: task e3): the very same path for each. Fires Picked
-- (holding, AquariumController) with the catch at that place, or nil for an empty one; a caught one takes the ring
function Slots.pick(n: number)
	if n < 1 or n > COUNT or not holder or not holder.Visible then
		return
	end
	local at = places[n] or #current + n -- (an empty slot: a place with no fish)
	local item = current[at]
	if item then
		selected = item.Key
		showRings()
		selectedEvent:Fire(at, item)
	end
	pickedEvent:Fire(at, item)
end

-- The equipped fish (nil: none), and whether it is ridden on land now (EquipController, from the server's attributes)
function Slots.equipped(item: Caught?, mounted: boolean)
	rideItem = item
	rideOn = mounted
	drawRide()
end

-- Which of the list stand in the slots (the user, 2026-11-24: "if the player has a fish they caught that is a legendary,
-- it should replace a common in the bar, and that logic should follow through"): the best COUNT (Config.finest). A fish
-- keeps its slot while it is one of them; a better one takes the slot of the poorest, which goes to the bag; as one
-- leaves, the others close up and the best of the bag comes in at the end.
local function fill(list: { Caught })
	local at: { [number]: number } = {}
	for i, item in list do
		at[item.Key or 0] = i
	end
	local best = Config.finest(list, COUNT)
	local wanted: { [number]: boolean } = {}
	for _, i in best do
		wanted[list[i].Key or 0] = true
	end
	for i = #bar, 1, -1 do
		if not at[bar[i]] then
			table.remove(bar, i)
		end
	end
	local isIn: { [number]: boolean } = {}
	for _, key in bar do
		isIn[key] = true
	end
	local coming: { number } = {}
	for _, i in best do
		if not isIn[list[i].Key or 0] then
			table.insert(coming, i)
		end
	end
	for i, key in bar do
		if not wanted[key] then
			local with = table.remove(coming, 1)
			if with then
				bar[i] = list[with].Key or 0
			end
		end
	end
	table.sort(coming) -- (into empty slots in the order they were caught)
	for _, i in coming do
		table.insert(bar, list[i].Key or 0)
	end
	table.clear(places)
	for i, key in bar do
		places[i] = at[key]
	end
end

-- list: what the player carries, newest last (nil: the game has no taming, and the row stays hidden).
-- Called when the list changes, not every frame.
function Slots.update(list: { Caught }?)
	holder.Visible = list ~= nil
	if not list then
		return
	end
	count.Text = if #list > COUNT
		then string.format("%d / %d CAUGHT  (BEST %d SHOWN)", #list, Config.Tame.Carry, COUNT)
		elseif #list > 0 then #list .. " CAUGHT"
		else ""
	current = list
	fill(list)
	-- a new catch takes the ring (when it made the bar); a shorter list (home at the dock) keeps it on what is still
	-- there
	local newest = list[#list]
	if newest and #list > lastCount and table.find(bar, newest.Key or 0) then
		selected = newest.Key
	elseif not selected or not table.find(bar, selected) then
		selected = bar[#bar]
	end
	lastCount = #list
	drawRide()
	for i = 1, COUNT do
		local place = places[i]
		paint(tiles[i], if place then list[place] else nil)
	end
	showRings()
end

return Slots
