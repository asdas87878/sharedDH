--!strict
-- In the hop: the aim at the middle of the screen, with the window to grab a fish as a thin ring round it that
-- empties. It goes red for the window's last part, and flashes red on a grab with no fish locked. With no fish locked
-- and the window running out it says so. No tenths to read: the window is a shape.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Kit)

local Aim = {}

local holder: Frame
local ring: Kit.Ring
local dot: Frame
local find: TextLabel

local shownRed = false
local shownFind = false
local nextTurn = 0

function Aim.build(parent: Instance)
	holder = Kit.new("Frame", {
		Name = "Aim",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(40, 40),
		BackgroundTransparency = 1,
		Visible = false,
	}, parent)
	ring = Kit.ring(holder, 40, 5, 1.5)
	ring.Hole.BackgroundTransparency = 1
	ring.colour(Kit.White)
	dot = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(6, 6),
		BackgroundColor3 = Kit.White,
	}, holder)
	Kit.corner(dot, 999)
	Kit.stroke(dot, 1.5, Kit.Ink)
	find = Kit.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 12),
		Size = UDim2.fromOffset(220, 24),
		TextSize = 20,
		TextColor3 = Kit.Coral,
		Text = "FIND A FISH!",
		Visible = false,
	}, holder)
end

function Aim.hide()
	holder.Visible = false
end

-- left: seconds left in the window (nil outside it); locked: whether a fish is locked; refused: a grab was just
-- pressed with none locked
function Aim.update(now: number, left: number?, locked: boolean, refused: boolean)
	holder.Visible = true
	local window = math.max(Config.Jump.Window, 0.01)
	local warn = left ~= nil and left <= Config.Jump.Warn
	if now >= nextTurn then
		nextTurn = now + 1 / 30
		ring.set(if left then left / window else 1)
	end
	local red = warn or refused
	if red ~= shownRed then
		shownRed = red
		local colour = if red then Kit.Coral else Kit.White
		ring.colour(colour)
		dot.BackgroundColor3 = colour
	end
	local lost = warn and not locked
	if lost ~= shownFind then
		shownFind = lost
		find.Visible = lost
	end
end

return Aim
