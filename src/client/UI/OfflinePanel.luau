--!strict
-- The offline rewards' window (Hugo, 2026-11-25: "Add offline rewards and use image gen to get something similar to ref
-- image 1"; NULLROOM task o1; docs/design/offline-rewards.md): "Welcome back!", what the tank earned while its player was
-- away, and CLAIM. The reference gives what it does and its order (title, picture, amount, claim); the look is the dock's
-- own (UI.Shop's window, header, well and button) with our own chest (art/ui/offline/chest.png, NULLROOM task g1). The
-- reference's second button (three times as much for Robux) is left out: nothing sells it.
--   OfflinePanel.open(on)    opens or closes it, as Shop.go("Offline"): one dock window at a time
--   OfflinePanel.owed()      the coins waiting (the player's "OfflineOwed" attribute: OfflineService decides everything)
--   OfflinePanel.chip(on)    the small CLAIM beside the dock's buttons, for as long as coins wait and the window is
--                            closed (the X keeps them). It sits by UI.HubButtons' own holder, on the same scale
--   OfflinePanel.claiming(on), OfflinePanel.say(text)   a claim is on its way; a line in place of the hours (a refusal)
-- Controllers/OfflineController shows it, asks for the claim and answers.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.Parent.Lib.State)
local Anim = require(script.Parent.Anim)
local Kit = require(script.Parent.Kit)
local Shop = require(script.Parent.Shop)

local OfflinePanel = {}

----------------------------------------------------------------------------------------------------------------------
-- Pictures, sizes and colours (the window's own points)

-- Upload id for the chest (empty until the user says yes to the upload: a live game shows the cash picture till then).
-- Studio reads it from its own content folder: python tools/offline/picture.py studio
OfflinePanel.Chest = "" -- art/ui/offline/chest.png
local STUDIO = "rbxasset://textures/ridefish/offline_chest_o1.png"

local WIDE, HIGH = 500, 452 -- (a phone 375 wide holds it at 0.72, so CLAIM is still 47 px high there)
local TITLE_HIGH = 34
local HOURS_HIGH = 22
local WELL_AT = TITLE_HIGH + HOURS_HIGH + 8
local CLAIM_HIGH = 66
local GAP = 10
local CHEST = 206
local AMOUNT = 58 -- the amount's letters, on one this short
local LETTERS = 7 -- and smaller past this many

local HEAD = Shop.Heads.Coral
local PALE = Color3.fromRGB(214, 222, 236) -- quiet words on the dark body (Sell Fish's)
local DEEP = Color3.fromRGB(20, 62, 88) -- the well behind the chest, lit water
local DARK = Color3.fromRGB(10, 26, 46)
local GOLD = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 246, 170)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 210, 63)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(246, 150, 26)),
})

local CHIP_WIDE, CHIP_HIGH = 147, 48 -- the hub buttons' own
local CHIP_GAP = 12
local CHIP_OVER = 24 -- over the Shop button: clear of its red "!"

local window: Shop.Window? = nil
local hours: TextLabel
local amount: TextLabel
local claim: Shop.Button
local chip: Shop.Button? = nil
local chipAmount: TextLabel
local said = false -- the hours' line holds something else
local asking = false

local pressed = Instance.new("BindableEvent")
-- Fired as CLAIM is pressed
OfflinePanel.Pressed = pressed.Event

local function chestPicture(): string
	if OfflinePanel.Chest ~= "" then
		return OfflinePanel.Chest
	end
	return if RunService:IsStudio() then STUDIO else Kit.Textures.Cash
end

local function number(name: string): number
	local value = State.Player:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

function OfflinePanel.owed(): number
	return if Config.Offline.On ~= 0 then number("OfflineOwed") else 0
end

-- So many seconds in words: "45 min", "8 h", "3 h 12 min"
function OfflinePanel.time(secs: number): string
	local minutes = math.max(math.floor(secs / 60), 1)
	local h, m = math.floor(minutes / 60), minutes % 60
	if h == 0 then
		return `{m} min`
	end
	return if m == 0 then `{h} h` else `{h} h {m} min`
end

local function picture(parent: Instance, size: number, props: { [string]: any }): ImageLabel
	props.Size = UDim2.fromOffset(size, size)
	props.BackgroundTransparency = 1
	props.Image = chestPicture()
	props.ScaleType = Enum.ScaleType.Fit
	return Kit.new("ImageLabel", props, parent)
end

----------------------------------------------------------------------------------------------------------------------
-- What it says now

local function paint()
	local owed = OfflinePanel.owed()
	if window then
		local words = Shop.cash(owed)
		amount.Text = words
		amount.TextSize = if #words > LETTERS then math.floor(AMOUNT * LETTERS / #words) else AMOUNT
		if not said then
			hours.Text = `Your tank worked {OfflinePanel.time(number("OfflineSecs"))} without you`
		end
		claim.set(
			if asking then "..." else "Claim!",
			if asking or owed < 1 then "Off" else "Cash",
			not asking and owed >= 1
		)
	end
	if chip then
		chipAmount.Text = Shop.cash(owed)
	end
end
OfflinePanel.paint = paint

----------------------------------------------------------------------------------------------------------------------
-- The window

local function build()
	local w = Shop.window({
		Name = "OfflinePanel",
		Parent = State.Player:WaitForChild("PlayerGui"),
		Title = "Welcome back!",
		Head = HEAD,
		Dim = true,
		Width = WIDE,
		Height = HIGH,
		OnClose = function()
			Shop.go(nil)
		end,
	})
	local body = w.Body
	picture(w.Header, Shop.HeadHigh - 4, {
		Name = "Chest",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, -2),
		Rotation = -8,
		ZIndex = 4,
	})
	Shop.text(body, {
		Name = "Offline",
		Size = UDim2.new(1, 0, 0, TITLE_HIGH),
		TextSize = 30,
		Text = "OFFLINE EARNINGS",
		ZIndex = 3,
	})
	hours = Shop.text(body, {
		Name = "Hours",
		Position = UDim2.fromOffset(0, TITLE_HIGH),
		Size = UDim2.new(1, 0, 0, HOURS_HIGH),
		TextSize = 18,
		TextColor3 = PALE,
		ZIndex = 3,
	})
	-- the chest in lit water, the amount over its foot
	local well = Shop.inset(body, {
		Name = "Well",
		Position = UDim2.fromOffset(0, WELL_AT),
		Size = UDim2.new(1, 0, 1, -(WELL_AT + CLAIM_HIGH + GAP + 2)),
		BackgroundColor3 = Kit.White,
		ZIndex = 2,
	})
	Kit.gradient(well, DEEP, DARK)
	picture(well, CHEST, {
		Name = "Chest",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -24),
		ZIndex = 4,
	})
	amount = Shop.text(well, {
		Name = "Amount",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.new(1, -16, 0, 64),
		TextSize = AMOUNT,
		ZIndex = 6,
	})
	Kit.new("UIGradient", { Rotation = 90, Color = GOLD }, amount)
	claim = Shop.button(body, {
		Name = "Claim",
		Text = "Claim!",
		Kind = "Cash",
		TextSize = 34,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, CLAIM_HIGH),
		Shine = true, -- (the window's one money button)
	})
	claim.Root.ZIndex = 3
	claim.Root.Activated:Connect(function()
		if claim.Live and not asking then
			pressed:Fire()
		end
	end)
	window = w
	paint()
end

function OfflinePanel.isOpen(): boolean
	return window ~= nil and window.isOpen()
end

-- (through Shop.go("Offline"), so another dock window closes)
function OfflinePanel.open(on: boolean)
	if not window then
		if not on then
			return
		end
		build()
	end
	if on then
		said = false
		paint()
	end
	(window :: Shop.Window).show(on)
	if on then
		Anim.punch(amount, 1.2)
	end
end

Shop.page("Offline", OfflinePanel.open)

-- A claim is on its way: CLAIM waits (the amount goes when the server says so)
function OfflinePanel.claiming(on: boolean)
	asking = on
	paint()
end

-- A line in place of the hours, until the window is opened again
function OfflinePanel.say(text: string)
	if window then
		said = true
		hours.Text = text
	end
end

----------------------------------------------------------------------------------------------------------------------
-- The small CLAIM by the dock's buttons

-- Over them on a computer; on a phone, where the rows sit right over them, beside the first
local function placeChip(root: GuiObject, buttons: GuiObject)
	local at = buttons.Position
	local fit = buttons:FindFirstChildOfClass("UIScale")
	local s = if fit then fit.Scale else 1
	local half = buttons.Size.Y.Offset * s / 2
	if Kit.touch() then
		root.AnchorPoint = Vector2.zero
		root.Position =
			UDim2.new(at.X.Scale, at.X.Offset + buttons.Size.X.Offset * s + CHIP_GAP, at.Y.Scale, at.Y.Offset - half)
	else
		root.AnchorPoint = Vector2.new(0, 1)
		root.Position = UDim2.new(at.X.Scale, at.X.Offset, at.Y.Scale, at.Y.Offset - half - CHIP_OVER)
	end
end

function OfflinePanel.chip(on: boolean)
	if not chip then
		local gui = State.Player:FindFirstChildOfClass("PlayerGui")
		local buttons = on and gui and gui:FindFirstChild("HubButtons", true)
		if not buttons or not buttons:IsA("GuiObject") then
			return
		end
		local b = Shop.button(buttons.Parent :: Instance, {
			Name = "OfflineClaim",
			Text = "",
			Kind = "Gold",
			Size = UDim2.fromOffset(CHIP_WIDE, CHIP_HIGH),
			Shine = true,
		})
		picture(b.Root, 50, {
			Name = "Chest",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 29, 0.5, -2),
			Rotation = -8,
			ZIndex = 4,
		})
		Shop.text(b.Root, {
			Name = "Claim",
			Position = UDim2.fromOffset(58, 4),
			Size = UDim2.new(1, -62, 0, 20),
			TextSize = 16,
			Text = "Claim",
			ZIndex = 4,
		})
		chipAmount = Shop.text(b.Root, {
			Name = "Amount",
			Position = UDim2.fromOffset(58, 22),
			Size = UDim2.new(1, -62, 0, 22),
			TextSize = 18,
			TextColor3 = Shop.Money,
			ZIndex = 4,
		})
		b.Root.Activated:Connect(function()
			Shop.go("Offline")
		end)
		chip = b
		paint()
	end
	local root = (chip :: Shop.Button).Root
	if on then
		local buttons = root.Parent and root.Parent:FindFirstChild("HubButtons")
		if buttons and buttons:IsA("GuiObject") then
			placeChip(root, buttons)
		end
	end
	if root.Visible ~= on then
		root.Visible = on
	end
end

return OfflinePanel
