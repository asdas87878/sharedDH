--!strict
-- The words that come and go: the miss ("MISSED THE FISH!", "OUT OF AIR!": red words on a streak of the abyss, deep
-- red going to black, with a red line along each edge), the end of a dive (a gold title on a dark streak that fades
-- out at both ends, a little tilted, and a pill under it), and the catch banner (tilted, at the left, a green brick
-- plate; it waits for taming).
-- They slide and switch on and off; no text ever changes size.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Kit)

local Banners = {}

local miss: TextLabel
local missGroup: CanvasGroup
local great: Frame
local greatMetres: TextLabel
local greatBest: TextLabel
local catch: Frame
local catchName: TextLabel
local catchTier: TextLabel
local catchTierGradient: UIGradient

local shownMiss = ""
local greatRun = 0
local catchRun = 0

local ENDS = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.24, 0.1),
	NumberSequenceKeypoint.new(0.76, 0.1),
	NumberSequenceKeypoint.new(1, 1),
})
local LINE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.25, 0),
	NumberSequenceKeypoint.new(0.75, 0),
	NumberSequenceKeypoint.new(1, 1),
})
-- The end of a dive sits in the upper part of the screen, clear of the player standing at the middle and of the land
-- strip at the top, on a phone as on a wide screen (it was on the player's head at the middle)
local GREAT_AT = UDim2.new(0.5, 0, 0.36, -20)
local GREAT_FROM = UDim2.new(0.5, 0, 0.36, 20)
local SLIDE = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local LEAVE = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

function Banners.build(parent: Instance)
	-- the miss: one group, so the whole of it fades in with the black as one number
	missGroup = Kit.new("CanvasGroup", {
		Name = "Miss",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -8),
		Size = UDim2.fromOffset(460, 84),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 20,
	}, parent)
	local abyss = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(440, 58),
		Rotation = -2,
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
	}, missGroup)
	Kit.new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(150, 14, 34), Color3.fromRGB(14, 0, 10)),
		Transparency = ENDS,
	}, abyss)
	for _, y in { 0, 1 } do
		local line = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0, y),
			Position = UDim2.fromScale(0, y),
			Size = UDim2.new(1, 0, 0, 3),
			BackgroundColor3 = Kit.Coral,
			BorderSizePixel = 0,
		}, abyss)
		Kit.new("UIGradient", { Transparency = LINE }, line)
	end
	miss = Kit.text({
		Size = UDim2.fromScale(1, 1),
		TextSize = 32,
		ZIndex = 2,
	}, abyss, 3.5)
	Kit.gradient(miss, Color3.fromRGB(255, 214, 200), Color3.fromRGB(255, 70, 80))

	-- the end of a dive
	great = Kit.new("Frame", {
		Name = "GreatDive",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = GREAT_AT,
		Size = UDim2.fromOffset(440, 110),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 15,
	}, parent)
	local streak = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(440, 60),
		Rotation = -2.5,
		BackgroundColor3 = Color3.fromRGB(10, 32, 64),
		BorderSizePixel = 0,
		ZIndex = 15,
	}, great)
	Kit.new("UIGradient", { Transparency = ENDS }, streak)
	for _, y in { 0, 1 } do
		local line = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0, y),
			Position = UDim2.fromScale(0, y),
			Size = UDim2.new(1, 0, 0, 2.5),
			BackgroundColor3 = Kit.Sun,
			BorderSizePixel = 0,
			ZIndex = 16,
		}, streak)
		Kit.new("UIGradient", { Transparency = LINE }, line)
	end
	local title = Kit.text({
		Size = UDim2.fromScale(1, 1),
		TextSize = 42,
		Text = "GREAT DIVE!",
		ZIndex = 17,
	}, streak, 3.5)
	Kit.gradient(title, Color3.fromRGB(255, 244, 170), Color3.fromRGB(255, 170, 40))
	local pill = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 72),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		ZIndex = 16,
	}, great)
	Kit.dress(pill, {
		Top = Kit.Themes.Navy.Top,
		Bottom = Kit.Themes.Navy.Bottom,
		Edge = Kit.Sun,
		Radius = Kit.Radius.Round,
		Bevel = false,
	})
	Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, pill)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	}, pill)
	greatMetres = Kit.text({
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		TextSize = 16,
		LayoutOrder = 1,
		ZIndex = 17,
	}, pill)
	greatBest = Kit.text({
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		TextSize = 11,
		TextColor3 = Kit.Sun,
		Text = "NEW BEST",
		LayoutOrder = 2,
		ZIndex = 17,
	}, pill, 1.8)

	-- the catch banner
	catch = Kit.new("Frame", {
		Name = "Catch",
		Position = UDim2.fromOffset(18, 176),
		Size = UDim2.fromOffset(190, 74),
		Rotation = -6,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 15,
	}, parent)
	Kit.text({
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.fromOffset(170, 13),
		TextSize = 10.5,
		TextColor3 = Color3.fromRGB(255, 176, 87),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "NICE CATCH!",
		ZIndex = 16,
	}, catch, 1.8)
	local plate = Kit.new("Frame", {
		Position = UDim2.fromOffset(0, 15),
		Size = UDim2.fromOffset(170, 36),
		ZIndex = 15,
	}, catch)
	Kit.dress(plate, Kit.Themes.Good)
	local tamed = Kit.text({
		Size = UDim2.fromScale(1, 1),
		TextSize = 23,
		Text = "TAMED!",
		ZIndex = 16,
	}, plate, 2.6)
	Kit.gradient(tamed, Color3.fromRGB(226, 255, 170), Kit.Lime)
	catchTier = Kit.text({
		Position = UDim2.fromOffset(14, 56),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 15),
		TextSize = 12,
		ZIndex = 16,
	}, catch)
	catchTierGradient = Kit.gradient(catchTier, Kit.White, Kit.White)
	catchName = Kit.text({
		Position = UDim2.fromOffset(84, 56),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 15),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 16,
	}, catch)
end

-- The words of a miss, as the deaths set them (State.FadeText), fading in with the black
function Banners.miss(text: string, alpha: number)
	if text ~= shownMiss then
		shownMiss = text
		miss.Text = text
		missGroup.Visible = text ~= ""
	end
	if text ~= "" then
		missGroup.GroupTransparency = 1 - alpha
	end
end

-- Back on the dock after a dive: how deep it went, and whether that is a new best
function Banners.greatDive(metres: number, isBest: boolean)
	greatRun += 1
	local run = greatRun
	greatMetres.Text = math.floor(metres) .. " m"
	greatBest.Visible = isBest
	great.Position = GREAT_FROM
	great.Visible = true
	TweenService:Create(great, SLIDE, { Position = GREAT_AT }):Play()
	task.delay(3.2, function()
		if run ~= greatRun then
			return
		end
		local out = TweenService:Create(great, LEAVE, { Position = GREAT_FROM })
		out.Completed:Once(function()
			if run == greatRun then
				great.Visible = false
			end
		end)
		out:Play()
	end)
end

-- A tame finished: the tilted banner at the left for a moment (called when the game has taming)
function Banners.caught(fishId: string)
	local kind = Config.FishById[fishId]
	if not kind then
		return
	end
	catchRun += 1
	local run = catchRun
	catchName.Text = kind.Name
	catchTier.Text = kind.Tier
	Kit.tierColours(catchTier, catchTierGradient, kind.Tier, Config.Tiers)
	catch.Position = UDim2.fromOffset(-200, 176)
	catch.Visible = true
	TweenService:Create(catch, SLIDE, { Position = UDim2.fromOffset(18, 176) }):Play()
	task.delay(1.8, function()
		if run ~= catchRun then
			return
		end
		local out = TweenService:Create(catch, LEAVE, { Position = UDim2.fromOffset(-200, 176) })
		out.Completed:Once(function()
			if run == catchRun then
				catch.Visible = false
			end
		end)
		out:Play()
	end)
end

return Banners
