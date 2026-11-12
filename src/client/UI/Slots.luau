--!strict
-- The row of slots at the bottom middle (where the reference has its own): what you carry home this dive. Each slot is
-- a small aquarium: a tile of see-through blue glass with a thick dark outline, a pale line inside it, a shine over
-- its upper half and the water's pattern. A filled one is its rarity's colours behind the glass (gold for a
-- Legendary, the rainbow for a Secret), with the creature's name cut short; the newest has a white outline. One word
-- above the row: "3 CAUGHT".
-- The row stays hidden until the game has taming (State.Caught). A creature's picture comes with it: the creature's
-- own model drawn in a small window, which needs no upload.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Kit)

local Slots = {}

export type Caught = { Id: string, Tier: string }

local SIZE = 34
local GAP = 5
local COUNT = 7

local holder: Frame
local count: TextLabel
local slots: { Kit.Panel } = {}
local names: { TextLabel } = {}

local GLASS: Kit.Style = table.clone(Kit.Themes.Glass)
GLASS.Radius = Kit.Radius.Tile
GLASS.Outline = 2.5
GLASS.Drop = 2

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
		Size = UDim2.fromOffset(120, 12),
		TextSize = 11,
		TextColor3 = Color3.fromRGB(156, 240, 106),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, holder, 1.8)
	for i = 1, COUNT do
		local slot = Kit.panel(holder, {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, (i - 1) * (SIZE + GAP), 1, 0),
			Size = UDim2.fromOffset(SIZE, SIZE),
		}, GLASS)
		names[i] = Kit.text({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -2),
			Size = UDim2.fromOffset(SIZE + 8, 10),
			TextSize = 8.5,
		}, slot.Face, 1.6)
		slots[i] = slot
	end
end

function Slots.place(touch: boolean)
	local size = if touch then SIZE else 46
	local gap = if touch then GAP else 6
	holder.Size = UDim2.fromOffset(COUNT * size + (COUNT - 1) * gap, size + 18)
	for i = 1, COUNT do
		slots[i].Frame.Size = UDim2.fromOffset(size, size)
		slots[i].Frame.Position = UDim2.new(0, (i - 1) * (size + gap), 1, 0)
		names[i].TextSize = if touch then 8.5 else 11
	end
end

-- list: what the player carries, newest last (nil: the game has no taming yet, and the row stays hidden).
-- Called when the list changes, not every frame.
function Slots.update(list: { Caught }?)
	holder.Visible = list ~= nil
	if not list then
		return
	end
	count.Text = if #list > 0 then #list .. " CAUGHT" else ""
	local first = math.max(#list - COUNT, 0)
	for i = 1, COUNT do
		local item = list[first + i]
		local slot = slots[i]
		local fill = slot.Look.Fill
		if item then
			local kind = Config.FishById[item.Id]
			slot.Face.BackgroundTransparency = 0
			fill.Color, fill.Rotation = Kit.tierFill(item.Tier, Config.Tiers)
			local name = if kind then kind.Name else item.Id
			names[i].Text = if #name > 7 then string.sub(name, 1, 6) .. "." else name
			slot.Look.Outline.Color = if first + i == #list then Kit.White else Kit.Ink
		else
			slot.Face.BackgroundTransparency = GLASS.Fade or 0
			fill.Color = ColorSequence.new(GLASS.Top, GLASS.Bottom)
			fill.Rotation = 90
			names[i].Text = ""
			slot.Look.Outline.Color = Kit.Ink
		end
	end
end

return Slots
