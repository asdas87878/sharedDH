--!strict
-- The server's boost and what was bought, on the player's own machine (PackService, PurchaseService; docs/design/
-- starter-packs.md): a chip at the top of the screen while the boost runs (what it does, the time left, who turned it
-- on), and a note to the buyer when a purchase has come in. Nothing here decides anything.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Products = require(ReplicatedStorage.Shared.Products)
local DockNotes = require(script.Parent.Parent.UI.DockNotes)
local Kit = require(script.Parent.Parent.UI.Kit)
local Shop = require(script.Parent.Parent.UI.Shop)
local SoundController = require(script.Parent.SoundController)

local BoostController = {}

local chip: Frame? = nil
local words: TextLabel

local function build(): Frame
	local gui = Kit.new("ScreenGui", {
		Name = "BoostChip",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		DisplayOrder = 4,
	}, Players.LocalPlayer:WaitForChild("PlayerGui"))
	local made: Frame = Kit.new("Frame", {
		Name = "Chip",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(210, 40),
		BackgroundColor3 = Color3.fromRGB(16, 150, 170),
		BorderSizePixel = 0,
	}, gui)
	Kit.corner(made, 10)
	Kit.stroke(made, 2, Shop.Edge).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	words = Shop.text(made, {
		Name = "Words",
		Size = UDim2.fromScale(1, 1),
		TextSize = 15,
		Text = "",
		ZIndex = 2,
	})
	return made
end

local function clock(left: number): string
	local hours = left // 3600
	return if hours > 0
		then string.format("%d:%02d:%02d", hours, left // 60 % 60, left % 60)
		else string.format("%d:%02d", left // 60, left % 60)
end

local function draw(): boolean
	local ends = workspace:GetAttribute("BoostEnds")
	local left = if type(ends) == "number" then math.floor(ends - workspace:GetServerTimeNow()) else 0
	local on = left > 0 and Config.Boost.On ~= 0
	if on then
		local made = chip or build()
		chip = made
		made.Visible = true
		words.Text =
			`x{Config.Boost.Oxygen} OXYGEN & CASH  {clock(left)}\nfrom {tostring(workspace:GetAttribute("BoostBy"))}`
	elseif chip then
		chip.Visible = false
	end
	return on
end

local function nameOf(key: any): string?
	for _, section in Products.Sections do
		for _, offer in section.Offers do
			if offer.Key == key then
				return offer.Name
			end
		end
	end
	return nil
end

function BoostController.Start()
	local remote = Net.Folder:WaitForChild("Purchase") :: RemoteEvent
	remote.OnClientEvent:Connect(function(what: any, key: any)
		local name = nameOf(key)
		if what == "Got" and name then
			SoundController.play("Claim")
			DockNotes.note(name, "Yours. Thank you!", true)
		end
	end)
	while true do
		task.wait(if draw() then 1 else 2)
	end
end

return BoostController
