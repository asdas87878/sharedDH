--!strict
-- The words that come and go: the miss ("MISSED THE FISH!", "OUT OF AIR!": red words on a streak of the abyss, deep
-- red going to black, with a red line along each edge), the end of a dive (a gold title on a dark streak that fades
-- out at both ends, a little tilted, and a pill under it), a new land's name, and the catch banner (tilted, at the
-- left, a green brick plate with the creature's picture in it).
-- They slide and switch on and off; no text ever changes size.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Kit)
local Portrait = require(script.Parent.Portrait)

local Banners = {}

local miss: TextLabel
local missGroup: CanvasGroup
local great: Frame
local greatMetres: TextLabel
local greatBest: TextLabel
local greatCaught: TextLabel
local catch: Frame
local catchWords: TextLabel
local catchTamed: TextLabel
local catchPicture: Portrait.Portrait
local catchName: TextLabel
local catchTier: TextLabel
local catchTierGradient: UIGradient

local shownMiss = ""
local greatRun = 0
local catchRun = 0
local land: Frame
local landName: TextLabel
local landGradient: UIGradient
local landWord: TextLabel
local landLines: { Frame } = {}
local landRun = 0

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
local CATCH_AT = UDim2.new(0, 22, 0.2, 0) -- (the tilt swings the plate's top corner a few units to the left)
local CATCH_FROM = UDim2.new(0, -250, 0.2, 0)
local CATCH_TIME = 2.6
-- A new land's name: under the strip of lands, clear of the rider
local LAND_AT = UDim2.new(0.5, 0, 0, 88) -- (clear of the metres pill under the strip)
local LAND_FROM = UDim2.new(0.5, 0, 0, 72)
local LAND_TIME = 2.2
-- the small words over the catch banner, by rarity (the reference's get louder with the catch; the words are ours)
local CATCH_WORDS: { [string]: string } = {
	Rare = "GREAT CATCH!",
	Epic = "GREAT CATCH!",
	Legendary = "INCREDIBLE CATCH!",
	Mythic = "INCREDIBLE CATCH!",
	Secret = "INCREDIBLE CATCH!",
}
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
		BackgroundColor3 = Kit.Deep,
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
	}, streak)
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
	}, pill)
	greatCaught = Kit.text({
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		TextSize = 13,
		TextColor3 = Kit.Good,
		LayoutOrder = 3,
		ZIndex = 17,
	}, pill)

	-- a new land: its name on the same dark streak as the end of a dive, smaller, with lines in the land's colour
	land = Kit.new("Frame", {
		Name = "NewLand",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = LAND_AT,
		Size = UDim2.fromOffset(300, 44),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 15,
	}, parent)
	local band = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Kit.Deep,
		BorderSizePixel = 0,
		ZIndex = 15,
	}, land)
	Kit.new("UIGradient", { Transparency = ENDS }, band)
	for _, y in { 0, 1 } do
		local line = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0, y),
			Position = UDim2.fromScale(0, y),
			Size = UDim2.new(1, 0, 0, 2),
			BorderSizePixel = 0,
			ZIndex = 16,
		}, band)
		Kit.new("UIGradient", { Transparency = LINE }, line)
		table.insert(landLines, line)
	end
	landName = Kit.text({
		Position = UDim2.fromOffset(0, 3),
		Size = UDim2.new(1, 0, 0, 26),
		TextSize = 23,
		ZIndex = 17,
	}, land)
	landGradient = Kit.gradient(landName, Kit.White, Kit.White)
	landWord = Kit.text({
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 12),
		TextSize = 9.5,
		ZIndex = 17,
	}, land)

	-- the catch banner (the reference's, off its frames: tilted, a third of the way down the left side, a dark
	-- see-through plate with a bright green edge, the creature's picture at its left, big pale green words, small
	-- orange words above it and the creature under it; it is up for nearly three seconds)
	catch = Kit.new("Frame", {
		Name = "Catch",
		Position = CATCH_AT,
		Size = UDim2.fromOffset(230, 96),
		Rotation = -6,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 15,
	}, parent)
	catchWords = Kit.text({
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.fromOffset(200, 13),
		TextSize = 11,
		TextColor3 = Color3.fromRGB(255, 176, 87),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "NICE CATCH!",
		ZIndex = 16,
	}, catch)
	local plate = Kit.new("Frame", {
		Position = UDim2.fromOffset(0, 15),
		Size = UDim2.fromOffset(206, 50),
		ZIndex = 15,
	}, catch)
	Kit.dress(plate, Kit.Themes.Good)
	catchPicture = Portrait.new(plate, {
		Position = UDim2.fromOffset(4, 2),
		Size = UDim2.fromOffset(48, 46),
		ZIndex = 16,
		Visible = false,
	})
	catchTamed = Kit.text({
		Position = UDim2.fromOffset(50, 0),
		Size = UDim2.new(1, -54, 1, 0),
		TextSize = 29,
		Text = "TAMED!",
		ZIndex = 16,
	}, plate)
	Kit.gradient(catchTamed, Color3.fromRGB(226, 255, 170), Kit.Lime)
	local under = Kit.new("Frame", {
		Position = UDim2.fromOffset(12, 70),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 17),
		BackgroundTransparency = 1,
		ZIndex = 16,
	}, catch)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	}, under)
	catchTier = Kit.text({
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 17),
		TextSize = 13,
		LayoutOrder = 1,
		ZIndex = 16,
	}, under)
	catchTierGradient = Kit.gradient(catchTier, Kit.White, Kit.White)
	catchName = Kit.text({
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 17),
		TextSize = 14.5,
		LayoutOrder = 2,
		ZIndex = 16,
	}, under)
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

-- Back on the dock after a dive: how deep it went, whether that is a new best, and how many creatures came home
function Banners.greatDive(metres: number, isBest: boolean, caught: number)
	greatRun += 1
	local run = greatRun
	greatMetres.Text = math.floor(metres) .. " m"
	greatBest.Visible = isBest
	greatCaught.Visible = caught > 0
	if caught > 0 then
		greatCaught.Text = caught .. " CAUGHT"
	end
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

-- A land deeper than any yet this dive: its name for a moment (index: 1 to 10)
function Banners.land(index: number, name: string, colour: Color3)
	landRun += 1
	local run = landRun
	landName.Text = string.upper(name)
	landGradient.Color = ColorSequence.new(Kit.lighter(colour, 0.75), Kit.lighter(colour, 0.3))
	landWord.Text = "LAND " .. index .. " OF 10"
	for _, line in landLines do
		line.BackgroundColor3 = Kit.lighter(colour, 0.3)
	end
	land.Position = LAND_FROM
	land.Visible = true
	TweenService:Create(land, SLIDE, { Position = LAND_AT }):Play()
	task.delay(LAND_TIME, function()
		if run ~= landRun then
			return
		end
		local out = TweenService:Create(land, LEAVE, { Position = LAND_FROM })
		out.Completed:Once(function()
			if run == landRun then
				land.Visible = false
			end
		end)
		out:Play()
	end)
end

-- A tame finished: the tilted banner at the left, with the creature's picture when it has a model to draw
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
	catchWords.Text = CATCH_WORDS[kind.Tier] or "NICE CATCH!"
	-- with a picture the words sit to its right; with none they take the whole plate
	local pictured = catchPicture.show(fishId)
	catchPicture.Frame.Visible = pictured
	catchTamed.Position = UDim2.fromOffset(if pictured then 50 else 0, 0)
	catchTamed.Size = UDim2.new(1, if pictured then -54 else 0, 1, 0)
	catch.Position = CATCH_FROM
	catch.Visible = true
	TweenService:Create(catch, SLIDE, { Position = CATCH_AT }):Play()
	task.delay(CATCH_TIME, function()
		if run ~= catchRun then
			return
		end
		local out = TweenService:Create(catch, LEAVE, { Position = CATCH_FROM })
		out.Completed:Once(function()
			if run == catchRun then
				catch.Visible = false
			end
		end)
		out:Play()
	end)
end

return Banners
