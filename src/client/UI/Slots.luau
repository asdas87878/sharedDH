--!strict
-- The row of slots at the bottom middle (where the reference has its own): what you carry home this dive. Each slot is
-- a small aquarium: a tile of see-through blue glass with a thick dark outline, a pale line inside it, a shine over
-- its upper half and the water's pattern. A filled one is its rarity's colours behind the glass (gold for a
-- Legendary, the rainbow for a Secret), with the creature's picture and its name cut short. One word above the row:
-- "3 CAUGHT".
-- The chosen catch has a square white ring a little outside its black outline, as the reference's (measured off the
-- user's screenshot, 2026-11-17: 5% of a slot thick, 3% out from the outline): the newest catch until the player
-- clicks another, and any caught slot while the mouse is over it ("it will just be on the last dino caught or the one
-- you select with the mouse when clicking, but should appear on hover"). A click fires Slots.Selected; back at your
-- tank, its prompt puts the chosen one in (Slots.chosen, AquariumController).
-- The glass fades out toward its top, and its outline does too, but less (the user, 2026-11-17: "retain the texture
-- but make the texture fade out in a gradient to some capacity alongside the outline to a different lesser capacity"),
-- and the picture is bigger than its slot and stands over the slot's top and sides ("scale the icons so that they all
-- overlap the inventory artistically"): the slot reads as what the fish rises out of. Where a fish sits in its picture
-- goes by its kind of picture (UI.Portrait), so every bust stands the same, every small fish the same.
-- Closer to the reference's (the user, 2026-11-17, measured off their recording): square corners; a black outline,
-- nearly solid; a caught fish's slot nearly solid and brighter, with the water's pattern faint behind and a light rim
-- inside the outline over a darker lip at the foot ("if you catch a fish it feels more satisfying"); the names in
-- Gotham Black with a thin outline; the fish lower and more in the middle, nearer its name, still over the top edge;
-- the slots as far apart as the reference's (a gap of an eighth of a slot between their outlines); and a slot grows a
-- little under the mouse.
-- The row is hidden while the game has no taming (State.Caught is nil). The picture is the creature's own model drawn
-- in a small window (UI.Portrait), which needs no upload; a creature with no model to draw yet shows its name alone.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local TweenService = game:GetService("TweenService")

local Kit = require(script.Parent.Kit)
local Portrait = require(script.Parent.Portrait)

local Slots = {}

local selectedEvent = Instance.new("BindableEvent")
-- Fired with (the catch's place in the list, the catch) when the player clicks a caught slot
Slots.Selected = selectedEvent.Event

export type Caught = { Id: string, Tier: string }

local SIZE = 34 -- a slot on a phone; on a keyboard, BIG
local BIG = 46
-- The gap between two slots' faces: the reference's 8 pixels between outlines at 720 high (an eighth of a slot), and
-- the two outlines, which stand outside the faces
local GAP = 8
local BIG_GAP = 10
local COUNT = 7
local OUTLINE = 2
local RING = 2.3 -- the white ring's thickness
local RING_GAP = 1.4 -- and its gap outside the black outline
local HOVER = 1.06 -- how much a slot grows under the mouse: its picture's overhang and this stay inside the gap
local FONT = Enum.Font.GothamBlack
local NAME_LINE = 1 -- the names' outline (was 1.6)
local BLACK = Color3.fromRGB(6, 8, 14) -- the outline: nearly black (it was the navy ink)

local holder: Frame
local count: TextLabel
local slots: { Kit.Panel } = {}
local names: { TextLabel } = {}
local pictures: { Portrait.Portrait } = {}
local rims: { Frame } = {}
local lips: { Frame } = {}
local patterns: { UIGradient } = {}
local rings: { Frame } = {}

local current: { Caught } = {}
local firstShown = 0 -- the list's place of the catch before the first slot
local selected: number? = nil -- which catch has the white ring (its place in the list)
local hovered: number? = nil -- which slot the mouse is over
local lastCount = 0

local GLASS: Kit.Style = table.clone(Kit.Themes.Glass)
GLASS.Radius = 0
GLASS.Outline = OUTLINE
-- No drop shadow: it thickened the foot, so a square slot read as a little taller than wide (the user, 2026-11-17:
-- "they almost look rectangular"). The reference's slots have none either
GLASS.Drop = 0
GLASS.Shine = false -- (the pale band over the upper half would sit where the glass has faded out)

-- How see-through a slot is from its top (0) to its foot (1), on top of what it is anyway: the glass and its pattern
-- fade most, the shadow under it with the glass
local function fade(top: number, middle: number): NumberSequence
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, top),
		NumberSequenceKeypoint.new(0.5, middle),
		NumberSequenceKeypoint.new(1, 0),
	})
end
local BODY = fade(0.9, 0.4)
-- The outline: solid, with only a touch of the fade at the very top (the user: "make the border more concrete and
-- less transparent and fade differently", then "mainly opaque and more black")
local EDGE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.15),
	NumberSequenceKeypoint.new(0.12, 0),
	NumberSequenceKeypoint.new(1, 0),
})
-- A caught fish's slot: nearly solid, a breath of see-through at the very top; its pattern faint and even
local CAUGHT = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.12),
	NumberSequenceKeypoint.new(0.35, 0),
	NumberSequenceKeypoint.new(1, 0),
})
local CAUGHT_EVEN = NumberSequence.new(0) -- (the rainbow runs side to side)
local PATTERN_CAUGHT = NumberSequence.new(0.45) -- on top of the pattern's own 0.8: about 11% strong
local BRIGHTER = 0.14 -- how far a caught fish's rarity colours go toward white
-- A caught slot's highlight, as the reference's (measured off the user's screenshot, 2026-11-17: "the highlight
-- between the outline and the inner bit isnt placed correctly, and isnt thick enough and doesnt fade correctly"): a
-- light band right inside the black outline, 5% of a slot wide, along the top and down both sides but not the foot;
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

-- The white ring on the chosen catch and on a caught slot under the mouse
local function showRings()
	for i = 1, COUNT do
		local at = firstShown + i
		rings[i].Visible = current[at] ~= nil and (at == selected or i == hovered)
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

function Slots.build(parent: Instance)
	holder = Kit.new("Frame", {
		Name = "Slots",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(COUNT * SIZE + (COUNT - 1) * GAP, SIZE + 18),
		BackgroundTransparency = 1,
		Visible = false,
	}, parent)
	count = Kit.text({
		-- (lifted clear of the pictures, which stand a little over the slots' tops)
		Position = UDim2.fromOffset(0, -6),
		Size = UDim2.fromOffset(120, 13),
		TextSize = 12,
		Font = FONT,
		TextColor3 = Kit.Good,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, holder, 1.2)
	for i = 1, COUNT do
		-- (held by its middle, so it grows from there under the mouse)
		local slot = Kit.panel(holder, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, (i - 1) * (SIZE + GAP) + SIZE / 2, 1, -SIZE / 2),
			Size = UDim2.fromOffset(SIZE, SIZE),
		}, GLASS)
		local look = slot.Look
		look.Fill.Transparency = BODY
		look.Outline.Color = BLACK
		look.Outline.LineJoinMode = Enum.LineJoinMode.Miter -- (square corners: Kit's outlines are rounded)
		Kit.new("UIGradient", { Transparency = EDGE, Rotation = 90 }, look.Outline)
		if look.Texture then
			patterns[i] = Kit.new("UIGradient", { Transparency = BODY, Rotation = 90 }, look.Texture)
		end
		-- a caught fish's darker lip along the foot and its light rim inside the outline (shown when caught)
		lips[i] = Kit.new("Frame", {
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
		rims[i] = rim
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
		rings[i] = ring
		-- a little bigger under the mouse, with the ring; a click chooses a caught slot
		local grow = Kit.new("UIScale", {}, slot.Frame)
		local up = TweenService:Create(grow, HOVER_INFO, { Scale = HOVER })
		local down = TweenService:Create(grow, HOVER_INFO, { Scale = 1 })
		local hit: TextButton = Kit.new("TextButton", {
			Name = "Hit",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 5,
		}, slot.Frame)
		hit.MouseEnter:Connect(function()
			hovered = i
			up:Play()
			showRings()
		end)
		hit.MouseLeave:Connect(function()
			if hovered == i then
				hovered = nil
			end
			down:Play()
			showRings()
		end)
		hit.Activated:Connect(function()
			local at = firstShown + i
			local item = current[at]
			if item then
				selected = at
				showRings()
				selectedEvent:Fire(at, item)
			end
		end)
		-- no pale line inside an empty slot (the user: "it also shouldnt be present if you dont have a fish"); a caught
		-- one has the rim above instead
		if look.Bevel then
			look.Bevel.Enabled = false
		end
		Kit.new("UIGradient", { Transparency = BODY, Rotation = 90 }, slot.Shadow)
		local under = slot.Shadow:FindFirstChildOfClass("UIStroke")
		if under then
			under.LineJoinMode = Enum.LineJoinMode.Miter
			Kit.new("UIGradient", { Transparency = BODY, Rotation = 90 }, under)
		end
		pictures[i] = Portrait.new(slot.Face, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, WINDOW.Foot),
			Size = UDim2.fromScale(WINDOW.Wide, WINDOW.High),
			Aspect = Slots.Aspect,
			Visible = false,
			ZIndex = 2,
		})
		names[i] = Kit.text({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -1),
			Size = UDim2.fromOffset(SIZE + 8, 10),
			TextSize = 8.5,
			Font = FONT,
			ZIndex = 3,
		}, slot.Face, NAME_LINE)
		slots[i] = slot
	end
end

function Slots.place(touch: boolean)
	local size = if touch then SIZE else BIG
	local gap = if touch then GAP else BIG_GAP
	holder.Size = UDim2.fromOffset(COUNT * size + (COUNT - 1) * gap, size + 18)
	-- its bottom edge level with the stat rows' on a keyboard (StatRows.place)
	holder.Position = UDim2.new(0.5, 0, 1, if touch then -10 else -14)
	for i = 1, COUNT do
		slots[i].Frame.Size = UDim2.fromOffset(size, size)
		slots[i].Frame.Position = UDim2.new(0, (i - 1) * (size + gap) + size / 2, 1, -size / 2)
		names[i].TextSize = if touch then 8.5 else 11
	end
end

-- The chosen catch (the one with the white ring): its place in the list and the catch, or nil with none. What the
-- tank's prompt puts in (AquariumController)
function Slots.chosen(): (number?, Caught?)
	local item = if selected then current[selected] else nil
	return if item then selected else nil, item
end

-- list: what the player carries, newest last (nil: the game has no taming, and the row stays hidden).
-- Called when the list changes, not every frame.
function Slots.update(list: { Caught }?)
	holder.Visible = list ~= nil
	if not list then
		return
	end
	count.Text = if #list > 0 then #list .. " CAUGHT" else ""
	local first = math.max(#list - COUNT, 0)
	current = list
	firstShown = first
	-- a new catch takes the ring; a shorter list (home at the dock) keeps it on what is still there
	if #list > lastCount then
		selected = #list
	elseif selected and selected > #list then
		selected = if #list > 0 then #list else nil
	end
	lastCount = #list
	for i = 1, COUNT do
		local item = list[first + i]
		local slot = slots[i]
		local fill = slot.Look.Fill
		local picture = pictures[i]
		if item then
			local kind = Config.FishById[item.Id]
			slot.Face.BackgroundTransparency = 0
			local colours, turn = tileFill(item.Tier)
			fill.Color, fill.Rotation = colours, turn
			fill.Transparency = if turn == 90 then CAUGHT else CAUGHT_EVEN
			if patterns[i] then
				patterns[i].Transparency = PATTERN_CAUGHT
			end
			lips[i].Visible = true
			rims[i].Visible = true
			local name = if kind then kind.Name else item.Id
			names[i].Text = if #name > 7 then string.sub(name, 1, 6) .. "." else name
			slot.Look.Outline.Color = BLACK
			picture.Frame.Visible = picture.show(item.Id)
		else
			slot.Face.BackgroundTransparency = GLASS.Fade or 0
			fill.Color = ColorSequence.new(GLASS.Top, GLASS.Bottom)
			fill.Rotation = 90
			fill.Transparency = BODY
			if patterns[i] then
				patterns[i].Transparency = BODY
			end
			lips[i].Visible = false
			rims[i].Visible = false
			names[i].Text = ""
			slot.Look.Outline.Color = BLACK
			picture.show(nil)
			picture.Frame.Visible = false
		end
	end
	showRings()
end

return Slots
