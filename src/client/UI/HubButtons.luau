--!strict
-- The dock's two buttons, at the middle of the screen's left edge where the reference has its own at its hub (the
-- user, 2026-11-17: "Now recreate the index and shop buttons"): Shop over Index. Sizes, places and colours are measured
-- off the user's recording of the reference (0.78 of a unit here to its pixel at 720 high): a bright plate 147 by 48
-- with a black edge and a dark line inside it, paler at the top, a darker lip along the foot, a slanted band of
-- stronger colour toward the right, a faint pattern, a picture at the left, the word in white with a black outline, and
-- on the Index a round red "!" when there is something new in it.
-- The two pictures are the red basket and the blue book of the free icon pack the reference itself uses (gvesster's
-- Free Icon Pack, the user's copy, 2026-11-17; art/ui/icons/CREDITS.md). Ours, not the reference's: the pattern is our
-- stud tile until our own square tile is uploaded.
-- They show at the dock only. UI review 1 (2026-11-22): the reference's motion (UI.Anim): under the mouse a button
-- grows about 5% and darkens about 12%, a press dips it to 0.96, and the "!" bounces every 1.8 s. Shop opens the Shop
-- window (UI.ShopScreen: Controllers.StallController listens).
-- The Index (Hugo, 2026-11-23; NULLROOM task h2): its button opens the Index window and closes it again
-- (UI.IndexPanel, through Shop.go: one dock window at a time), and its "!" is up for as long as the Index holds a
-- reward to claim: the server's count, the player's "IndexClaims" attribute (IndexService). With the Index switched
-- off (Config.Index.On 0) the button opens nothing and the "!" is the hint it was: up on a first catch, down on a press.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Anim = require(script.Parent.Anim)
local IndexPanel = require(script.Parent.IndexPanel)
local Kit = require(script.Parent.Kit)
local Shop = require(script.Parent.Shop)

local HubButtons = {}

local pressed = Instance.new("BindableEvent")
-- Fired with "Shop", "Index" or "Sound" when that button is pressed
HubButtons.Pressed = pressed.Event

local WIDTH = 147
local HEIGHT = 48
local GAP = 8.5
local LEFT = 10 -- as the stat rows'
local DOWN = 4 -- the pair's middle sits a hair under the screen's
local EDGE = 1.5
local ICON_AT = 25 -- the picture's middle, from the button's left edge
local PICTURE = 40 -- the picture's box: the reference's basket is 39 wide
local WORD_AT = 0.62 -- the word's middle, across the button
local WORD = 16.5
local MARK = 23
local ON_TOUCH = 0.85

local BLACK = Kit.Edge -- the dock's one outline colour
-- The slanted band: where it starts and ends along a line turned SLANT degrees, and how see-through it is
local SLANT = 31
local BAND = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.763, 1),
	NumberSequenceKeypoint.new(0.768, 0.5),
	NumberSequenceKeypoint.new(0.994, 0.5),
	NumberSequenceKeypoint.new(1, 1),
})

type Look = { Top: Color3, Bottom: Color3, Lip: Color3, Band: Color3 }
local SHOP: Look = {
	Top = Color3.fromRGB(244, 148, 162),
	Bottom = Color3.fromRGB(230, 91, 117),
	Lip = Color3.fromRGB(192, 59, 88),
	Band = Color3.fromRGB(222, 0, 45),
}
local INDEX: Look = {
	Top = Color3.fromRGB(164, 199, 247),
	Bottom = Color3.fromRGB(117, 161, 224),
	Lip = Color3.fromRGB(88, 122, 179),
	Band = Color3.fromRGB(20, 85, 215),
}

local holder: Frame
local size: UIScale
local mark: Frame
local shopMark: Frame
local shown = false
local soundWord: TextLabel
local hint = false -- the Index switched off: something new was caught and the button has not been pressed since

-- The Index's "!", by the one rule: while a reward waits in it (the server's count); the Index off, the old hint
local function showMark()
	if not mark then
		return
	end
	if Config.Index.On ~= 0 then
		local waiting = Players.LocalPlayer:GetAttribute("IndexClaims")
		mark.Visible = type(waiting) == "number" and waiting > 0
	else
		mark.Visible = hint
	end
end

local function block(props: { [string]: any }, parent: Instance): Frame
	props.BorderSizePixel = 0
	return Kit.new("Frame", props, parent)
end

local function button(order: number, name: string, look: Look, picture: string): TextButton
	local plate: TextButton = Kit.new("TextButton", {
		Name = name,
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundColor3 = BLACK,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = order,
	}, holder)
	Kit.corner(plate, 1)
	local face = block({
		Name = "Face",
		Position = UDim2.fromOffset(EDGE, EDGE),
		Size = UDim2.new(1, -EDGE * 2, 1, -EDGE * 2),
		BackgroundColor3 = Kit.White,
		ZIndex = 2,
	}, plate)
	Kit.gradient(face, look.Top, look.Bottom)
	-- The faint block pattern, as the reference lays it (docs/design/ui.md, "How the reference does its stud
	-- pattern"): one tiled picture over the face, a tile 28 across (5% of the screen's height), started from the
	-- face's upper left corner and cut off by its edges. The reference's first square is flush with the button's left
	-- edge and a little down from its top: 8 across and 3 up from
	-- where our tile's would, so the picture starts that far outside the face. Until our tile is uploaded the map's
	-- stud tile stands in, smaller and fainter
	local emboss = Kit.Textures.Emboss ~= ""
	face.ClipsDescendants = true
	local pattern: ImageLabel = Kit.new("ImageLabel", {
		Name = "Pattern",
		Position = if emboss then UDim2.fromOffset(-7.8, -2.7) else UDim2.fromOffset(0, 0),
		Size = if emboss then UDim2.new(1, 7.8, 1, 2.7) else UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = if emboss then Kit.Textures.Emboss else Kit.Textures.Studs,
		ImageTransparency = if emboss then 0 else 0.8,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = if emboss then UDim2.fromOffset(28, 28) else UDim2.fromOffset(15, 15),
		ZIndex = 3,
	}, face)
	-- fading toward the foot, as the windows' studs (UI.Shop's Studs, Tail)
	Kit.new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.35, 0.14),
			NumberSequenceKeypoint.new(1, 0.55),
		}),
	}, pattern)
	local band = block({ Name = "Band", Size = UDim2.fromScale(1, 1), BackgroundColor3 = look.Band, ZIndex = 4 }, face)
	Kit.new("UIGradient", { Transparency = BAND, Rotation = SLANT }, band)
	block({
		Name = "Lip",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = look.Lip,
		ZIndex = 5,
	}, face)
	-- the dark line just inside the black edge
	local inner = block({
		Position = UDim2.fromOffset(EDGE, EDGE),
		Size = UDim2.new(1, -EDGE * 2, 1, -EDGE * 2),
		BackgroundTransparency = 1,
		ZIndex = 6,
	}, face)
	local rim = Kit.stroke(inner, EDGE, BLACK, 0.76)
	rim.LineJoinMode = Enum.LineJoinMode.Miter
	Kit.new("ImageLabel", {
		Name = "Picture",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, ICON_AT, 0.5, 0),
		Size = UDim2.fromOffset(PICTURE, PICTURE),
		BackgroundTransparency = 1,
		Image = picture,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 7,
	}, plate)
	local word: TextLabel = Kit.new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(WORD_AT, 0.5),
		Size = UDim2.fromOffset(80, HEIGHT),
		BackgroundTransparency = 1,
		Font = Kit.Font,
		Text = name,
		TextSize = WORD,
		TextColor3 = Kit.White,
		ZIndex = 8,
	}, plate)
	Kit.stroke(word, 1.4, BLACK)
	-- under the mouse it grows and darkens; a press dips it (the darkening over the face, under the picture and word)
	local shade = block({ Name = "Shade", Size = UDim2.fromScale(1, 1), ZIndex = 6 }, face)
	Anim.button(plate, { Grow = 1.05, Press = 0.96, Shade = shade, ShadeTo = 0.12 })
	plate.Activated:Connect(function()
		pressed:Fire(name)
	end)
	return plate
end

-- A red "!" on a button's upper right corner: a dark edge, a white ring, a red disc; it bounces while it shows
local function markOn(plate: Instance): Frame
	local m = block({
		Name = "Mark",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -9, 0, -4.5),
		Size = UDim2.fromOffset(MARK, MARK),
		BackgroundColor3 = Color3.fromRGB(24, 12, 12),
		Visible = false,
		ZIndex = 10,
	}, plate)
	Kit.corner(m, 999)
	local ring = block({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -2, 1, -2),
		BackgroundColor3 = Kit.White,
		ZIndex = 11,
	}, m)
	Kit.corner(ring, 999)
	local disc = block({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -3.5, 1, -3.5),
		BackgroundColor3 = Kit.White,
		ZIndex = 12,
	}, ring)
	Kit.corner(disc, 999)
	Kit.gradient(disc, Color3.fromRGB(226, 70, 76), Color3.fromRGB(188, 30, 46))
	local bang: TextLabel = Kit.new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Kit.Font,
		Text = "!",
		TextSize = 15,
		TextColor3 = Kit.White,
		Rotation = 8,
		ZIndex = 13,
	}, disc)
	Kit.stroke(bang, 1.2, BLACK)
	Anim.bounce(m)
	return m
end

function HubButtons.build(parent: Instance)
	holder = Kit.new("Frame", {
		Name = "HubButtons",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, LEFT, 0.5, DOWN),
		Size = UDim2.fromOffset(WIDTH, HEIGHT * 2 + GAP),
		BackgroundTransparency = 1,
		Visible = false,
	}, parent)
	size = Kit.new("UIScale", {}, holder)
	Kit.new("UIListLayout", { Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder }, holder)
	local shop = button(1, "Shop", SHOP, Kit.Textures.Shop)
	local index = button(2, "Index", INDEX, Kit.Textures.Index)
	shown = false

	-- under them, small: all the sound off, and on again (SoundController; 2026-11-24: there was no way to turn it off)
	local sound: TextButton = Kit.new("TextButton", {
		Name = "Sound",
		Size = UDim2.fromOffset(96, 34),
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = 3,
	}, holder)
	Kit.corner(sound, 1)
	soundWord = Kit.new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Kit.Font,
		Text = "SOUND ON",
		TextSize = 14,
		TextColor3 = Kit.White,
	}, sound)
	Kit.stroke(soundWord, 1.2, BLACK)
	Anim.button(sound, { Grow = 1.05, Press = 0.92 })
	sound.Activated:Connect(function()
		pressed:Fire("Sound")
	end)

	-- the red "!"s: the Index's when a new kind is in it, the Shop's from the start of each visit until it is opened
	-- (the user, 2026-11-22: "Is it possible to do the bouncing exclamation point on the shop?")
	mark = markOn(index)
	shopMark = markOn(shop)
	shopMark.Visible = true

	-- the Shop's shine, once its "!" is down and no window is open over it (one call for the eye at a time)
	Anim.shine(shop:FindFirstChild("Face") :: GuiObject, 0, function()
		return not shopMark.Visible and Anim.Windows == 0
	end)

	-- opening the Shop is what takes its mark off; the Index's follows what waits in it (showMark). A press on the
	-- Index opens its window, or closes it when it is the one open
	HubButtons.Pressed:Connect(function(name: string)
		if name == "Index" then
			hint = false
			showMark()
			if Config.Index.On ~= 0 then
				Shop.go(if Shop.Page == "Index" then nil else "Index")
			end
		elseif name == "Shop" then
			shopMark.Visible = false
		end
	end)
	Players.LocalPlayer:GetAttributeChangedSignal("IndexClaims"):Connect(showMark)
	showMark()
end

function HubButtons.sound(on: boolean)
	soundWord.Text = if on then "SOUND ON" else "SOUND OFF"
end

function HubButtons.place(touch: boolean)
	size.Scale = if touch then ON_TOUCH else 1
end

-- docked: at the dock, the only place the two buttons show
function HubButtons.update(docked: boolean)
	if docked ~= shown then
		shown = docked
		holder.Visible = docked
		-- each visit to the dock puts the Shop's "!" back up until the Shop is opened
		if docked then
			shopMark.Visible = true
		end
	end
end

-- The Shop was opened another way (a stat row's plus button): its red "!" goes, as when its own button opens it
function HubButtons.shopSeen()
	shopMark.Visible = false
end

-- Something new is in the Index (a kind caught for the first time). With the Index on this changes nothing by
-- itself: the "!" goes up when the server has counted the new kind's reward (a moment later) and stays until it is
-- claimed. With the Index off it is the hint: up until the button is pressed.
function HubButtons.mark(on: boolean)
	hint = on
	showMark()
end

-- Whether the Index window is open (for Studio's checks)
function HubButtons.indexOpen(): boolean
	return IndexPanel.isOpen()
end

return HubButtons
