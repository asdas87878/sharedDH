--!strict
-- The row of slots at the bottom middle (the reference's): what you carry home this dive. A hairline dark frame; an
-- empty slot is almost clear and darkens a little toward the bottom. A filled one, as the reference's: the creature's
-- picture on its rarity's colour, lighter at the top, a pale edge, and the creature's name cut short along the bottom.
-- One word above the row: "3 CAUGHT".
-- The row is hidden while the game has no taming (State.Caught is nil). The picture is the creature's own model drawn
-- in a small window (UI.Portrait), which needs no upload; a creature with no model to draw yet shows its name alone.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Kit)
local Portrait = require(script.Parent.Portrait)

local Slots = {}

export type Caught = { Id: string, Tier: string }

local SIZE = 34
local GAP = 5
local COUNT = 7

local holder: Frame
local count: TextLabel
local frames: { Frame } = {}
local fills: { UIGradient } = {}
local names: { TextLabel } = {}
local outlines: { UIStroke } = {}
local pictures: { Portrait.Portrait } = {}

local EMPTY = NumberSequence.new(0.98, 0.83)
local FULL = NumberSequence.new(0.08)
local DARK = Color3.fromRGB(8, 18, 34)

function Slots.build(parent: Instance)
	holder = Kit.new("Frame", {
		Name = "Slots",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(COUNT * SIZE + (COUNT - 1) * GAP, SIZE + 16),
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
		local slot: Frame = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, (i - 1) * (SIZE + GAP), 1, 0),
			Size = UDim2.fromOffset(SIZE, SIZE),
			BackgroundColor3 = DARK,
			BorderSizePixel = 0,
		}, holder)
		Kit.corner(slot, 1)
		outlines[i] = Kit.stroke(slot, 1.5, DARK, 0.12)
		fills[i] = Kit.new("UIGradient", { Rotation = 90, Transparency = EMPTY }, slot)
		pictures[i] = Portrait.new(slot, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromScale(1, 0.9),
			Visible = false,
		})
		names[i] = Kit.text({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromOffset(SIZE + 8, 10),
			TextSize = 8.5,
			ZIndex = 2,
		}, slot, 1.6)
		frames[i] = slot
	end
end

function Slots.place(touch: boolean)
	local size = if touch then SIZE else 46
	local gap = if touch then GAP else 6
	holder.Size = UDim2.fromOffset(COUNT * size + (COUNT - 1) * gap, size + 16)
	for i = 1, COUNT do
		frames[i].Size = UDim2.fromOffset(size, size)
		frames[i].Position = UDim2.new(0, (i - 1) * (size + gap), 1, 0)
		names[i].TextSize = if touch then 8.5 else 11
	end
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
	for i = 1, COUNT do
		local item = list[first + i]
		local slot = frames[i]
		local picture = pictures[i]
		if item then
			local kind = Config.FishById[item.Id]
			local tier = Config.Tiers[item.Tier]
			local colour: Color3 = if tier then tier.Colour else Kit.White
			if item.Tier == "Secret" then
				colour = Color3.fromRGB(110, 110, 132)
			end
			slot.BackgroundColor3 = Kit.White
			fills[i].Transparency = FULL
			fills[i].Color = ColorSequence.new(Kit.lighter(colour, 0.5), Kit.lighter(colour, 0.12))
			local name = if kind then kind.Name else item.Id
			names[i].Text = if #name > 7 then string.sub(name, 1, 6) .. "." else name
			outlines[i].Color = Kit.lighter(colour, 0.7)
			outlines[i].Transparency = 0
			picture.Frame.Visible = picture.show(item.Id)
		else
			slot.BackgroundColor3 = DARK
			fills[i].Transparency = EMPTY
			fills[i].Color = ColorSequence.new(Kit.White)
			names[i].Text = ""
			outlines[i].Color = DARK
			outlines[i].Transparency = 0.12
			picture.show(nil)
			picture.Frame.Visible = false
		end
	end
end

return Slots
