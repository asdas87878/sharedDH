--!strict
-- The saddles in the Index (Hugo, 2026-11-25: "add saddles as a reward in index"; NULLROOM task s2; docs/design/ui.md):
-- three pieces UI.IndexWindow hangs in itself, none of which is there while Config.Saddles.On is 0.
--   plate   a land's saddle on its banner, over what else the whole set pays: its picture and name, a padlock until the
--           land is claimed, then OWNED or WORN. A press opens the page
--   door    the "Saddles" button at the end of the Unlocked bar: opens the page
--   page    over the window's body: a card for each land's saddle, WEAR or TAKE OFF on the ones that are theirs,
--           CLAIM! where the land's set is whole, else how far the land's set is (a press goes to that land)
-- Nothing here decides anything: a press only asks (IndexBook.ask); what is worn is the player's attribute Saddle.
local Anim = require(script.Parent.Anim)
local IndexBook = require(script.Parent.IndexBook)
local Kit = require(script.Parent.Kit)
local LandBanners = require(script.Parent.LandBanners)
local SaddlePicture = require(script.Parent.SaddlePicture)
local Shop = require(script.Parent.Shop)

local SaddlePage = {}

local PALE = Color3.fromRGB(214, 222, 236)
local LOCKED = Color3.fromRGB(150, 156, 172) -- a picture that is not theirs yet is dimmed by this
local GOLD = Shop.Kinds.Gold
local GAP = 8

-- The letters that fit `text` on one line this wide: never over `most`, never under `least`
local function fitted(text: string, wide: number, most: number, least: number): number
	return math.clamp(math.floor(wide / (math.max(#text, 1) * 0.47)), least, most)
end

-- A drawn padlock (no upload), filling a square of this size
local function padlock(parent: Instance, at: UDim2, size: number, z: number): Frame
	local disc: Frame = Kit.new("Frame", {
		Name = "Lock",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = at,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Kit.Deep,
		BorderSizePixel = 0,
		ZIndex = z,
	}, parent)
	Kit.corner(disc, 999)
	Kit.stroke(disc, 2, PALE)
	local bow: Frame = Kit.new("Frame", {
		Name = "Bow",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.24),
		Size = UDim2.fromScale(0.26, 0.4),
		BackgroundTransparency = 1,
		ZIndex = z + 1,
	}, disc)
	Kit.corner(bow, 999)
	Kit.stroke(bow, math.max(size * 0.08, 1.5), PALE)
	local body: Frame = Kit.new("Frame", {
		Name = "Body",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.46, 0.33),
		BackgroundColor3 = PALE,
		BorderSizePixel = 0,
		ZIndex = z + 2,
	}, disc)
	Kit.corner(body, 2)
	return disc
end

-- A round green tick
local function tick(parent: Instance, at: UDim2, size: number, z: number): Frame
	local disc: Frame = Kit.new("Frame", {
		Name = "Tick",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = at,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		ZIndex = z,
	}, parent)
	Kit.corner(disc, 999)
	Kit.gradient(disc, Shop.Kinds.Cash[1], Shop.Kinds.Cash[2])
	Kit.stroke(disc, 2, Kit.White)
	Shop.check(disc, z + 1)
	return disc
end

----------------------------------------------------------------------------------------------------------------------
-- The land's saddle on its banner

export type Plate = { Root: TextButton, paint: (land: number) -> () }

-- In `size` points; flat and wide (a phone's) it is one row, else the picture over the words
function SaddlePage.plate(parent: Instance, at: Vector2, size: Vector2, text: number, onPress: () -> ()): Plate
	local row = size.Y < 100
	local root: TextButton = Kit.new("TextButton", {
		Name = "Saddle",
		Position = UDim2.fromOffset(at.X, at.Y),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = Kit.Deep,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 5,
	}, parent)
	Kit.corner(root, Shop.Round.Card)
	local edge = Kit.stroke(root, 3, Shop.Edge)
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local line = text + 3
	local wide = if row then size.Y - 4 else size.X - 8
	local high = if row then size.Y - 4 else size.Y - line * 2 - 8
	local picture = SaddlePicture.new(root, {
		Name = "Picture",
		Position = UDim2.fromOffset(if row then 2 else 4, 2),
		Size = UDim2.fromOffset(wide, high),
		ZIndex = 6,
	})
	local left = if row then wide + 4 else 4
	local room = size.X - left - 4
	local name = Shop.text(root, {
		Name = "SaddleName",
		Position = UDim2.fromOffset(left, if row then size.Y / 2 - line - 1 else high + 3),
		Size = UDim2.fromOffset(room, line),
		ZIndex = 7,
	})
	local state = Shop.text(root, {
		Name = "State",
		Position = UDim2.fromOffset(left, if row then size.Y / 2 + 1 else high + 3 + line),
		Size = UDim2.fromOffset(room, line),
		ZIndex = 7,
	})
	local corner = if row then UDim2.fromOffset(wide - 8, size.Y - 13) else UDim2.fromOffset(size.X - 16, 16)
	local lock = padlock(root, corner, 22, 8)
	local done = tick(root, corner, 22, 8)
	Anim.button(root)
	root.Activated:Connect(onPress)

	local function paint(land: number)
		local design = IndexBook.saddle(land)
		root.Visible = design ~= nil
		if not design then
			picture.show(nil)
			return
		end
		picture.show(design.Key)
		local own, worn = IndexBook.ownsSaddle(land), IndexBook.worn() == land;
		(picture.Frame :: any).ImageColor3 = if own then Kit.White else LOCKED
		name.Text = design.Name
		name.TextSize = fitted(design.Name, room, text, 13)
		state.Text = if worn then "WORN" elseif own then "OWNED" else "Saddle"
		state.TextSize = fitted(state.Text, room, text - 1, 13)
		state.TextColor3 = if own then Kit.lighter(Shop.Money, 0.35) else PALE
		lock.Visible = not own
		done.Visible = own
		edge.Color = if worn then Kit.White else Shop.Edge
	end
	return { Root = root, paint = paint }
end

-- The door to the page: a button
function SaddlePage.door(parent: Instance, props: { [string]: any }, onPress: () -> ()): Shop.Button
	props.Name = "Saddles"
	props.Text = "Saddles"
	props.Kind = "Purple"
	local button = Shop.button(parent, props)
	button.Root.Activated:Connect(onPress)
	return button
end

----------------------------------------------------------------------------------------------------------------------
-- The page

type Card = {
	Land: number,
	Key: string,
	Root: Frame,
	Edge: UIStroke,
	Picture: SaddlePicture.Picture,
	Button: Shop.Button,
	Lock: Frame,
	Tick: Frame,
}
export type Page = {
	Root: Frame,
	paint: () -> (),
	show: (on: boolean) -> (),
	isOpen: () -> boolean,
	press: (land: number) -> (),
}

-- Over a body `size` points big. columns: how many cards a row; text: a card's letters; goTo: shows a land (and closes
-- the page).
function SaddlePage.page(
	body: Instance,
	size: Vector2,
	columns: number,
	text: number,
	buttonHigh: number,
	goTo: (land: number) -> ()
): Page
	local lands = IndexBook.Lands
	local root: Frame = Kit.new("Frame", {
		Name = "SaddlesPage",
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = Shop.Body,
		BorderSizePixel = 0,
		Active = true, -- (nothing under it is pressed through it)
		Visible = false,
		ZIndex = 20,
	}, body)
	local head = math.max(buttonHigh, 44)
	local back = Shop.button(root, {
		Name = "Back",
		Text = "BACK",
		Kind = "Blue",
		TextSize = 24,
		Size = UDim2.fromOffset(108, head),
	})
	back.Root.ZIndex = 22
	Shop.text(root, {
		Name = "Title",
		Position = UDim2.fromOffset(114, 0),
		Size = UDim2.new(1, -228, 0, head),
		TextSize = 34,
		Text = "Saddles",
		ZIndex = 22,
	})
	local count = Shop.text(root, {
		Name = "Count",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 0),
		Size = UDim2.fromOffset(106, head),
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = GOLD[1],
		ZIndex = 22,
	})

	local shown: { number } = {}
	for land = 1, #lands do
		if IndexBook.saddle(land) then
			table.insert(shown, land)
		end
	end
	local top = head + GAP
	local tray = Shop.inset(root, {
		Name = "Rack",
		Position = UDim2.fromOffset(0, top),
		Size = UDim2.fromOffset(size.X, size.Y - top),
		ZIndex = 21,
	})
	local rows = math.max(math.ceil(#shown / columns), 1)
	local across = (size.X - GAP * (columns + 1)) / columns
	local high = (size.Y - top - GAP * (rows + 1)) / rows
	local line = text + 4
	local cards: { Card } = {}

	local function press(card: Card)
		local land = card.Land
		if IndexBook.worn() == land then
			IndexBook.ask("Saddle", 0)
		elseif IndexBook.ownsSaddle(land) then
			IndexBook.ask("Saddle", land)
		elseif IndexBook.owedLand(land) then
			IndexBook.ask("ClaimLand", land)
		else
			goTo(land)
		end
	end

	for i, land in shown do
		local design = IndexBook.saddle(land) :: any
		local card: Frame = Kit.new("Frame", {
			Name = "Saddle" .. land,
			Position = UDim2.fromOffset(
				GAP + ((i - 1) % columns) * (across + GAP),
				GAP + ((i - 1) // columns) * (high + GAP)
			),
			Size = UDim2.fromOffset(across, high),
			BackgroundColor3 = Kit.White,
			BorderSizePixel = 0,
			LayoutOrder = i,
			ZIndex = 22,
		}, tray)
		Kit.corner(card, Shop.Round.Card)
		local edge = Kit.stroke(card, 3, Shop.Edge)
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		Kit.new("UIGradient", { Rotation = 90, Color = LandBanners.fill(land) }, card)
		Shop.pattern(card, "Card")
		local place = IndexBook.landName(land)
		Shop.text(card, {
			Name = "Land",
			Position = UDim2.fromOffset(6, 3),
			Size = UDim2.new(1, -40, 0, line),
			TextSize = fitted(place, across - 46, text - 2, 13),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = place,
			ZIndex = 25,
		})
		local buttonAt = high - buttonHigh - 6
		local nameAt = buttonAt - line - 3
		Shop.text(card, {
			Name = "SaddleName",
			Position = UDim2.fromOffset(2, nameAt),
			Size = UDim2.new(1, -4, 0, line),
			TextSize = fitted(design.Name, across - 8, text, 13),
			Text = design.Name,
			ZIndex = 25,
		})
		local picture = SaddlePicture.new(card, {
			Name = "Picture",
			Position = UDim2.fromOffset(5, line - 2),
			Size = UDim2.fromOffset(across - 10, nameAt - line + 4),
			ZIndex = 24,
		})
		local button = Shop.button(card, {
			Name = "Wear",
			Text = "WEAR",
			Kind = "Off",
			TextSize = math.min(text + 4, buttonHigh - 14),
			Position = UDim2.fromOffset(6, buttonAt),
			Size = UDim2.fromOffset(across - 12, buttonHigh),
		})
		button.Root.ZIndex = 25
		local made: Card = {
			Land = land,
			Key = design.Key,
			Root = card,
			Edge = edge,
			Picture = picture,
			Button = button,
			Lock = padlock(card, UDim2.new(1, -17, 0, 17), 24, 26),
			Tick = tick(card, UDim2.new(1, -17, 0, 17), 24, 26),
		}
		button.Root.Activated:Connect(function()
			press(made)
		end)
		table.insert(cards, made)
	end

	local function paint()
		local worn = IndexBook.worn()
		local have, of = IndexBook.saddles()
		count.Text = `{have} / {of}`
		for _, card in cards do
			local own = IndexBook.ownsSaddle(card.Land)
			local on = own and worn == card.Land;
			(card.Picture.Frame :: any).ImageColor3 = if own then Kit.White else LOCKED
			card.Edge.Color = if on then Kit.White else Shop.Edge
			card.Edge.Thickness = if on then 4.5 else 3
			card.Lock.Visible = not own
			card.Tick.Visible = on
			if on then
				card.Button.set("TAKE OFF", "Blue", true)
			elseif own then
				card.Button.set("WEAR", "Cash", true)
			elseif IndexBook.owedLand(card.Land) then
				card.Button.set("CLAIM!", "Gold", true)
			else
				local found, whole = IndexBook.setOf(card.Land)
				card.Button.set(`{found} / {whole}`, "Off", true)
			end
		end
	end

	-- (what the page lies over is not drawn while it is open: the tabs' marks and the rewards' frame reach out past it)
	local under: { GuiObject } = {}
	local drawing = 0
	local function show(on: boolean)
		drawing += 1
		local turn = drawing
		root.Visible = on
		for _, piece in under do
			piece.Visible = true
		end
		table.clear(under)
		if on then
			for _, piece in body:GetChildren() do
				if piece:IsA("GuiObject") and piece ~= root and piece.Visible and piece.Name ~= "Toast" then
					piece.Visible = false
					table.insert(under, piece)
				end
			end
		end
		if not on then
			return
		end
		paint()
		local faces: { GuiObject } = {}
		for _, card in cards do
			table.insert(faces, card.Root)
		end
		Anim.stagger(faces)
		-- (a picture a frame, so opening it is no hitch; made once and kept)
		task.spawn(function()
			for _, card in cards do
				if drawing ~= turn or not card.Root.Parent then
					return
				end
				card.Picture.show(card.Key)
				task.wait()
			end
		end)
	end
	local self: Page = {
		Root = root,
		paint = paint,
		show = show,
		isOpen = function(): boolean
			return root.Visible
		end,
		press = function(land: number)
			for _, card in cards do
				if card.Land == land then
					press(card)
				end
			end
		end,
	}
	back.Root.Activated:Connect(function()
		show(false)
	end)
	return self
end

return SaddlePage
