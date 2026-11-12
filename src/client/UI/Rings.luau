--!strict
-- The two rings beside the rider (the reference's): the big one is the time left on this fish, the small one the tame.
-- Ours: the seconds are written in the big ring, and the fish's name and rarity sit under it. A new player has about
-- 2.5 seconds on a fish and the meter is full again on every landing, so this is a countdown: the number carries it,
-- the ring is the glance, and under a second everything goes red.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Kit)

local Rings = {}

local BIG = 64
local SMALL = 34

local holder: Frame
local big: Kit.Ring
local small: Kit.Ring
local number: TextLabel
local unit: TextLabel
local nameText: TextLabel
local tierText: TextLabel
local tierGradient: UIGradient

local shownSeconds = ""
local shownName = ""
local shownTier = ""
local shownBand = 0
local shownTame = -1
local shownEndless = false
local nextText = 0
local nextTurn = 0
local shownFraction = -1
local shownSpent = false

function Rings.build(parent: Instance)
	holder = Kit.new("Frame", {
		Name = "Rings",
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(40 + BIG, BIG + 34),
		BackgroundTransparency = 1,
		Visible = false,
	}, parent)
	big = Kit.ring(holder, BIG, 14)
	big.Frame.Position = UDim2.fromOffset(40, 0)
	number = Kit.text({
		Size = UDim2.new(1, 0, 1, -8),
		TextSize = 20,
	}, big.Hole, 2.4)
	unit = Kit.text({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -3),
		Size = UDim2.fromOffset(30, 8),
		TextSize = 7,
		Text = "SEC",
	}, big.Hole, 1.4)
	small = Kit.ring(holder, SMALL, 10.5)
	small.Frame.Position = UDim2.fromOffset(0, BIG / 2 + 2)
	small.colour(Kit.Pink)
	small.Hole.BackgroundTransparency = 1
	small.Frame.Visible = false
	nameText = Kit.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(40 + BIG / 2, BIG + 2),
		Size = UDim2.fromOffset(160, 15),
		TextSize = 12.5,
	}, holder)
	tierText = Kit.text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(40 + BIG / 2, BIG + 15),
		Size = UDim2.fromOffset(160, 13),
		TextSize = 10.5,
	}, holder)
	tierGradient = Kit.gradient(tierText, Kit.White, Kit.White)
end

-- Beside the rider: a little to the right of the middle of the screen
function Rings.place(touch: boolean)
	holder.Position = if touch then UDim2.new(0.5, 50, 0.5, 12) else UDim2.new(0.5, 78, 0.5, 6)
end

function Rings.hide()
	holder.Visible = false
end

-- fraction: how full the meter is; seconds: how long it lasts on this fish; name and tier: the fish ("" for none);
-- tame: 0 to 1, or nil when there is no tame to show; endless: the Studio sandbox's endless air is on, so the meter
-- doesn't drain (the number is then what a full meter would give on this fish, and the ring says ENDLESS)
function Rings.update(
	now: number,
	fraction: number,
	seconds: number,
	name: string,
	tier: string,
	tame: number?,
	endless: boolean
)
	holder.Visible = true
	-- the ring turns thirty times a second: with seconds on a fish it would otherwise turn every frame
	if now >= nextTurn or fraction > shownFraction + 0.05 then
		nextTurn = now + 1 / 30
		shownFraction = fraction
		big.set(fraction)
	end
	-- an empty meter: the whole ring red (with nothing left there is no arc to be red)
	local spent = fraction <= 0 and not endless
	if spent ~= shownSpent then
		shownSpent = spent
		big.spent(spent)
	end
	if endless ~= shownEndless then
		shownEndless = endless
		unit.Text = if endless then "ENDLESS" else "SEC"
	end
	local band = if endless then 1 elseif seconds < 1 then 3 elseif fraction < 0.6 then 2 else 1
	if band ~= shownBand then
		shownBand = band
		big.colour(if band == 3 then Kit.Coral elseif band == 2 then Kit.Sun else Kit.Aqua)
		number.TextColor3 = if band == 3 then Color3.fromRGB(255, 214, 214) else Kit.White
	end
	if now >= nextText then
		nextText = now + 1 / 15
		local text = Kit.seconds(seconds)
		if text ~= shownSeconds then
			shownSeconds = text
			number.Text = text
			unit.Visible = text ~= ""
		end
	end
	if name ~= shownName then
		shownName = name
		nameText.Text = name
	end
	if tier ~= shownTier then
		shownTier = tier
		tierText.Text = tier
		if tier ~= "" then
			Kit.tierColours(tierText, tierGradient, tier, Config.Tiers)
		end
	end
	local tameSteps = if tame then math.floor(math.clamp(tame, 0, 1) * 200 + 0.5) else -1
	if tameSteps ~= shownTame then
		shownTame = tameSteps
		small.Frame.Visible = tame ~= nil
		if tame then
			small.set(tame)
			small.colour(if tame >= 1 then Kit.Lime else Kit.Pink)
		end
	end
end

return Rings
