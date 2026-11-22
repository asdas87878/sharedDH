--!strict
-- The words that come and go: the miss ("MISSED THE FISH!", "OUT OF AIR!": red words on a streak of the abyss, deep
-- red going to black, with a red line along each edge), the end of a dive (a gold title on a dark streak that fades
-- out at both ends, a little tilted, and under it the catch as round tokens and how deep it went), a new land's
-- name, and the catch banner (tilted, at the left: a plate in the fish's rarity colours with rays turning behind the
-- fish's picture).
-- The catch banner and the end of a dive are in "the genre's" strength of flavour (the user's pick, 2026-11-16;
-- docs/design/ui.md, "More flavour"): a drop shadow under a heading, rays behind the thing shown, a bursting badge
-- (NEW!, BEST!), a sign on a number, the catch as tokens. All of Roblox's own pieces: nothing is uploaded.
-- They slide and switch on and off, the rays turn and the metres count up; no text ever changes size.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Kit)
local Portrait = require(script.Parent.Portrait)
local CatchShow = require(script.Parent.CatchShow)
local CaughtText = require(script.Parent.CaughtText)

local Banners = {}

local hudRoot: Instance? = nil
local miss: TextLabel
local missGroup: CanvasGroup
local great: Frame
local greatMetres: TextLabel
local greatPill: Frame
local greatBest: Frame
local greatCatch: Frame
local greatCaught: TextLabel
local greatTokens: { Frame } = {}
local greatFills: { UIGradient } = {}
local greatPictures: { Portrait.Portrait } = {}
local catch: Frame
local catchWords: TextLabel
local catchArea: Frame
local catchFill: UIGradient
local catchRays: Frame
local catchSpin: Tween
local catchEarn: TextLabel
local catchChip: Frame
local catchNew: Frame
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
local CATCH_FROM = UDim2.new(0, -280, 0.2, 0)
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
-- The end of a dive goes away by itself this long after everything on it is in its place (Hugo, 2026-11-22, task b3:
-- "after 2 seconds it fades out by itself, in exactly the same way it does when clicked"). CatchShow.play closes it
-- then through the same close a click takes; it was 20 seconds (CatchShow.Wait). A click still skips and closes.
local GREAT_STAY = 2
local TOKENS = 7 -- the most fish shown at the end of a dive (Config.Tame.Carry is 7)
local SLIDE = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local LEAVE = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

-- A heading: its words, and under them the same words in the outline's colour, a little lower (the drop shadow).
-- For words that never change.
local function heading(props: { [string]: any }, parent: Instance, drop: number): TextLabel
	local under = table.clone(props)
	under.Position = (props.Position or UDim2.new()) + UDim2.fromOffset(0, drop)
	under.TextColor3 = Kit.Ink
	under.ZIndex = (props.ZIndex or 1) - 1
	Kit.text(under, parent)
	return Kit.text(props, parent)
end

-- A bursting badge: an eight-pointed star (two squares, one turned) with a word on it, tilted
local function badge(parent: Instance, word: string, size: number, turn: number, z: number): Frame
	local holder: Frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Rotation = turn,
		Visible = false,
		ZIndex = z,
	}, parent)
	for layer = 1, 2 do
		for _, angle in { 0, 45 } do
			local square = Kit.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.72, 0.72),
				Rotation = angle,
				BackgroundColor3 = Kit.Danger,
				BorderSizePixel = 0,
				ZIndex = z + layer - 1,
			}, holder)
			Kit.corner(square, size * 0.08)
			if layer == 1 then
				-- (the outline is on the two squares under; the two over them hide the lines that cross inside)
				Kit.stroke(square, 2, Kit.Ink)
			end
		end
	end
	Kit.text({
		Size = UDim2.fromScale(1, 1),
		TextSize = size * 0.27,
		Text = word,
		ZIndex = z + 2,
	}, holder)
	return holder
end

local RAY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.3, 0.7),
	NumberSequenceKeypoint.new(0.5, 0.8),
	NumberSequenceKeypoint.new(0.7, 0.7),
	NumberSequenceKeypoint.new(1, 1),
})

-- Rays behind the thing shown: pale bars through one point, fading out at their ends. Their plate is a CanvasGroup,
-- which cuts them off at its edge. Only the holder's turn ever changes.
local function rays(plate: Instance, x: number, y: number, size: number, count: number): Frame
	local holder: Frame = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
	}, plate)
	for i = 1, count do
		local bar = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 0.09),
			Rotation = (i - 1) * 180 / count,
			BackgroundColor3 = Kit.White,
			BorderSizePixel = 0,
		}, holder)
		Kit.new("UIGradient", { Transparency = RAY }, bar)
	end
	return holder
end

-- The colours of a catch's plate: its rarity's colour going darker (gold, the ember and the rainbow as they are)
local function plateFill(tier: string): (ColorSequence, number)
	if tier == "Legendary" or tier == "Mythic" or tier == "Secret" then
		return Kit.tierFill(tier, Config.Tiers)
	end
	local entry = Config.Tiers[tier]
	local colour: Color3 = if entry then entry.Colour else Kit.Navy
	return ColorSequence.new(Kit.lighter(colour, 0.1), Kit.darker(colour, 0.5)), 25
end

function Banners.build(parent: Instance)
	hudRoot = parent
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
		Size = UDim2.fromOffset(440, 150),
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
	local title = heading({
		Size = UDim2.fromScale(1, 1),
		TextSize = 42,
		Text = "GREAT DIVE!",
		ZIndex = 18,
	}, streak, 3)
	Kit.gradient(title, Color3.fromRGB(255, 244, 170), Color3.fromRGB(255, 170, 40))
	-- a new best: a bursting badge on the streak's end
	greatBest = badge(great, "BEST!", 56, 14, 19)
	greatBest.Position = UDim2.fromOffset(368, -20)

	-- the catch: one round token a fish, in its rarity's colours with its picture, and the count in words
	greatCatch = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 36),
		Visible = false,
		ZIndex = 16,
	}, great)
	Kit.dress(greatCatch, {
		Top = Kit.Themes.Navy.Top,
		Bottom = Kit.Themes.Navy.Bottom,
		Edge = Kit.Sun,
		Radius = Kit.Radius.Round,
		Bevel = false,
	})
	Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 16) }, greatCatch)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 3),
	}, greatCatch)
	for i = 1, TOKENS do
		local token: Frame = Kit.new("Frame", {
			Size = UDim2.fromOffset(27, 27),
			BackgroundColor3 = Kit.White,
			LayoutOrder = i,
			Visible = false,
			ZIndex = 17,
		}, greatCatch)
		Kit.corner(token, 999)
		Kit.stroke(token, 1.5, Kit.White)
		greatFills[i] = Kit.new("UIGradient", { Rotation = 90 }, token)
		greatPictures[i] = Portrait.new(token, {
			Position = UDim2.fromOffset(2, 2),
			Size = UDim2.new(1, -4, 1, -4),
			ZIndex = 18,
		})
		greatTokens[i] = token
	end
	Kit.new("Frame", { -- (a little air between the tokens and the words)
		Size = UDim2.fromOffset(4, 1),
		BackgroundTransparency = 1,
		LayoutOrder = TOKENS + 1,
	}, greatCatch)
	greatCaught = Kit.text({
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 36),
		TextSize = 17,
		RichText = true,
		LayoutOrder = TOKENS + 2,
		ZIndex = 17,
	}, greatCatch)

	-- how deep: a chip under the catch (under the title when nothing was caught). The metres count up
	greatPill = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 114),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 28),
		ZIndex = 16,
	}, great)
	Kit.dress(greatPill, {
		Top = Kit.Themes.Navy.Top,
		Bottom = Kit.Themes.Navy.Bottom,
		Radius = Kit.Radius.Round,
		Bevel = false,
	})
	Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, greatPill)
	greatMetres = Kit.text({
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 28),
		TextSize = 15,
		ZIndex = 17,
	}, greatPill)

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

	-- the catch banner: tilted, a fifth of the way down the left side, up for nearly three seconds (the place and the
	-- time are the reference's, off its frames). The plate is the fish's rarity colours with rays turning behind the
	-- fish's picture; over it "TAMED!" with a drop shadow and what the fish earns in a tank; small orange words above
	-- it, the fish's rarity and name under it, and a "NEW!" badge on its corner the first time
	catch = Kit.new("Frame", {
		Name = "Catch",
		Position = CATCH_AT,
		Size = UDim2.fromOffset(250, 112),
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
	local shadow = Kit.new("Frame", {
		Position = UDim2.fromOffset(0, 19),
		Size = UDim2.fromOffset(226, 58),
		BackgroundColor3 = Kit.Ink,
		BackgroundTransparency = 0.3,
		ZIndex = 14,
	}, catch)
	Kit.corner(shadow, 9)
	local plate = Kit.new("CanvasGroup", {
		Position = UDim2.fromOffset(0, 15),
		Size = UDim2.fromOffset(226, 58),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		ZIndex = 15,
	}, catch)
	Kit.corner(plate, 9)
	catchFill = Kit.new("UIGradient", {}, plate)
	catchRays = rays(plate, 32, 29, 200, 7)
	catchSpin = TweenService:Create(
		catchRays,
		TweenInfo.new(24, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
		{ Rotation = 360 }
	)
	local gloss = Kit.new("Frame", {
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 0, 20),
		BackgroundColor3 = Kit.White,
		BackgroundTransparency = 0.86,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, plate)
	Kit.corner(gloss, 7)
	-- the plate's edge, and what stands on it (not in the group, so the picture can break out of the plate's top)
	local rim = Kit.new("Frame", {
		Position = UDim2.fromOffset(0, 15),
		Size = UDim2.fromOffset(226, 58),
		BackgroundTransparency = 1,
		ZIndex = 16,
	}, catch)
	Kit.corner(rim, 9)
	Kit.stroke(rim, 3, Kit.Ink)
	local inner = Kit.new("Frame", {
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundTransparency = 1,
		ZIndex = 16,
	}, rim)
	Kit.corner(inner, 7)
	Kit.stroke(inner, 1.5, Kit.White, 0.5)
	catchPicture = Portrait.new(rim, {
		Position = UDim2.fromOffset(0, -7),
		Size = UDim2.fromOffset(64, 68),
		ZIndex = 17,
		Visible = false,
	})
	catchArea = Kit.new("Frame", {
		Position = UDim2.fromOffset(62, 0),
		Size = UDim2.new(1, -66, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 17,
	}, rim)
	local tamed = heading({
		Position = UDim2.fromOffset(0, 1),
		Size = UDim2.new(1, 0, 0, 35),
		TextSize = 30,
		Text = "TAMED!",
		ZIndex = 19,
	}, catchArea, 2.5)
	Kit.gradient(tamed, Kit.White, Kit.Sun)
	catchChip = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 36),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 17),
		BackgroundColor3 = Kit.Deep,
		BackgroundTransparency = 0.25,
		Visible = false,
		ZIndex = 18,
	}, catchArea)
	Kit.corner(catchChip, 999)
	Kit.stroke(catchChip, 1.5, Kit.Ink)
	Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8) }, catchChip)
	Kit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, catchChip)
	-- the user's cash icon, as on the coins row (the user, 2026-11-17: "yes the catch banner should take it")
	Kit.new("ImageLabel", {
		Size = UDim2.fromOffset(15, 15),
		BackgroundTransparency = 1,
		Image = Kit.Textures.Cash,
		ScaleType = Enum.ScaleType.Fit,
		LayoutOrder = 1,
		ZIndex = 19,
	}, catchChip)
	catchEarn = Kit.text({
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 17),
		TextSize = 10.5,
		TextColor3 = Kit.Cash,
		LayoutOrder = 2,
		ZIndex = 19,
	}, catchChip)
	catchNew = badge(catch, "NEW!", 46, 12, 20)
	catchNew.Position = UDim2.fromOffset(198, -8)
	local under = Kit.new("Frame", {
		Position = UDim2.fromOffset(12, 80),
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
	-- (task b5: FailController's Slam band shows them when it is there; what follows is the old plain streak)
	local show = Kit.FailShow
	if show then
		show(text, alpha)
		return
	end
	if text ~= shownMiss then
		shownMiss = text
		miss.Text = text
		missGroup.Visible = text ~= ""
	end
	if text ~= "" then
		missGroup.GroupTransparency = 1 - alpha
	end
end

-- Back on the dock after a dive: how deep it went (counted up), whether that is a new best, and what came home
-- (list: the dive's catch, oldest first; nil or empty for none)
function Banners.greatDive(metres: number, isBest: boolean, list: { { Id: string, Tier: string } }?)
	greatRun += 1
	local run = greatRun
	-- one of the animated looks (Kit.CatchLook), when one is chosen
	local look = CatchShow.look()
	CatchShow.Wait = GREAT_STAY
	if look ~= 0 and hudRoot and CatchShow.play(hudRoot, look, metres, isBest, list) then
		great.Visible = false
		return
	end
	local count = if list then #list else 0
	greatBest.Visible = isBest
	greatCatch.Visible = count > 0
	greatPill.Position = UDim2.new(0.5, 0, 0, if count > 0 then 114 else 72)
	if list and count > 0 then
		greatCaught.Text = string.format('You caught <font color="#FFD23F">%d</font> fish!', count)
		local first = math.max(count - TOKENS, 0)
		for i = 1, TOKENS do
			local item = list[first + i]
			greatTokens[i].Visible = item ~= nil
			if item then
				greatFills[i].Color, greatFills[i].Rotation = Kit.tierFill(item.Tier, Config.Tiers)
				greatPictures[i].Frame.Visible = greatPictures[i].show(item.Id)
			end
		end
	end
	-- the metres count up over half a second (the words change, their size never does)
	local whole = math.floor(metres)
	task.spawn(function()
		for step = 1, 12 do
			if run ~= greatRun then
				return
			end
			greatMetres.Text = math.floor(whole * step / 12) .. " m deep"
			task.wait(0.04)
		end
	end)
	great.Position = GREAT_FROM
	great.Visible = true
	TweenService:Create(great, SLIDE, { Position = GREAT_AT }):Play()
	task.delay(0.6 + GREAT_STAY, function() -- (the old plain banner: its count-up takes about 0.6 s)
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

-- A tame finished: the tilted banner at the left, with the creature's picture when it has a model to draw.
-- earns: what this fish earns a second in a tank (nil: not known, and the chip stays hidden); isNew: the first of its
-- kind caught
function Banners.caught(fishId: string, earns: number?, isNew: boolean?)
	local kind = Config.FishById[fishId]
	if not kind then
		return
	end
	catchRun += 1
	local run = catchRun
	-- one of the stylised looks (Kit.CaughtLook), when one is chosen
	local look = CaughtText.look()
	local info = CaughtText.info(fishId, earns, isNew)
	if look ~= 0 and hudRoot and info and CaughtText.play(hudRoot, look, info) then
		catch.Visible = false
		catchSpin:Pause()
		return
	end
	catchName.Text = kind.Name
	catchTier.Text = kind.Tier
	Kit.tierColours(catchTier, catchTierGradient, kind.Tier, Config.Tiers)
	catchWords.Text = CATCH_WORDS[kind.Tier] or "NICE CATCH!"
	catchFill.Color, catchFill.Rotation = plateFill(kind.Tier)
	catchNew.Visible = isNew == true
	catchChip.Visible = earns ~= nil
	if earns then
		catchEarn.Text = "+$" .. (if earns < 100 then string.format("%.1f", earns) else Kit.short(earns)) .. " a second"
	end
	-- with a picture the words sit to its right; with none they take the whole plate
	local pictured = catchPicture.show(fishId)
	catchPicture.Frame.Visible = pictured
	catchArea.Position = UDim2.fromOffset(if pictured then 62 else 0, 0)
	catchArea.Size = UDim2.new(1, if pictured then -66 else 0, 1, 0)
	catch.Position = CATCH_FROM
	catch.Visible = true
	catchSpin:Play()
	TweenService:Create(catch, SLIDE, { Position = CATCH_AT }):Play()
	task.delay(CATCH_TIME, function()
		if run ~= catchRun then
			return
		end
		local out = TweenService:Create(catch, LEAVE, { Position = CATCH_FROM })
		out.Completed:Once(function()
			if run == catchRun then
				catch.Visible = false
				catchSpin:Pause()
			end
		end)
		out:Play()
	end)
end

return Banners
