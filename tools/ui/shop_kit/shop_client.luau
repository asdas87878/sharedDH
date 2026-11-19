-- Task s1's capture client (a temporary LocalScript in StarterPlayerScripts, put there by s1_capture.py and taken out
-- after). It opens the screen named by the workspace's "ShopShot": "Sub" (the sub stand), "Aura" (the aura shop),
-- "Kit" (a sample of the kit's list pieces in the sell list's layout, built here only), "" (all closed).
-- The workspace's "ShopFree" (0 or 1) sets this client's Config.Sub.Free, to see the price states while subs are free.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local UI = client:WaitForChild("UI")
task.wait(2)
local Config = require(ReplicatedStorage.Shared.Config)
local Shop = require(UI.Shop)
local Kit = require(UI.Kit)
local Portrait = require(UI.Portrait)
local SubPanel = require(UI.SubPanel)
local AuraShop = require(UI.AuraShop)

local kit: any = nil
local function buildKit()
	local w = Shop.window({
		Name = "KitSample",
		Parent = player.PlayerGui,
		Title = "Sell Fish",
		Icon = "Shell",
		Head = "Kelp",
		Width = 800,
		Height = 500,
		OnClose = function()
			kit.show(false)
		end,
	})
	local body = w.Body
	-- the sort column
	local side = Instance.new("Frame")
	side.BackgroundTransparency = 1
	side.Size = UDim2.new(0, 170, 1, -82)
	side.ZIndex = 3
	side.Parent = body
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = side
	Shop.text(side, { Size = UDim2.new(1, 0, 0, 28), TextSize = 26, Text = "Sort by:", LayoutOrder = 1, ZIndex = 3 })
	Shop.sort(side, { Text = "  Value", On = true, Size = UDim2.new(1, 0, 0, 46), LayoutOrder = 2 })
	Shop.sort(side, { Text = "  Rarity", On = false, Size = UDim2.new(1, 0, 0, 46), LayoutOrder = 3 })
	Shop.button(side, { Text = "Select All", Kind = "Blue", Size = UDim2.new(1, 0, 0, 46), LayoutOrder = 4 })
	-- the cards
	local tray = Shop.inset(body, {
		Position = UDim2.fromOffset(182, 0),
		Size = UDim2.new(1, -182, 1, -82),
		ZIndex = 2,
	})
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(170, 186)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.Parent = tray
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 10)
	pad.Parent = tray
	for i, f in
		{
			{ "ReefShark", "Reef Shark", Color3.fromRGB(190, 110, 255), 400, 80000 },
			{ "Clownfish", "Clownfish", Color3.fromRGB(120, 230, 90), 12, 2400 },
			{ "MantaRay", "Manta Ray", Color3.fromRGB(80, 170, 255), 95, 19000 },
		}
	do
		local card = Shop.itemCard(tray, {
			Name = f[2],
			NameColour = f[3],
			Rate = Shop.cash(f[4]) .. "/s",
			Price = Shop.cash(f[5]),
			LayoutOrder = i,
		})
		local p = Portrait.new(card.Picture, { Size = UDim2.fromScale(1, 1), ZIndex = 3 })
		p.show(f[1])
	end
	-- the footer
	local foot = Shop.inset(body, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 70),
		ZIndex = 2,
	})
	Shop.text(foot, {
		Position = UDim2.fromOffset(18, 0),
		Size = UDim2.new(0, 200, 1, 0),
		TextSize = 32,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Total Value:",
		ZIndex = 3,
	})
	Shop.money(foot, {
		Position = UDim2.fromOffset(220, 0),
		Size = UDim2.new(0, 220, 1, 0),
		TextSize = 34,
		Colour = Kit.White,
		Align = Enum.HorizontalAlignment.Left,
		Text = "$0",
	})
	local sell = Shop.button(foot, {
		Text = "Sell (0)",
		Kind = "Off",
		TextSize = 30,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(250, 52),
	})
	sell.Root.ZIndex = 3
	local buy = Shop.button(foot, {
		Text = "999",
		Kind = "Robux",
		Sign = "Robux",
		TextSize = 26,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -276, 0.5, 0),
		Size = UDim2.fromOffset(130, 44),
	})
	buy.Root.ZIndex = 3
	return w
end

local function apply()
	local which = workspace:GetAttribute("ShopShot") or ""
	local free = workspace:GetAttribute("ShopFree")
	if type(free) == "number" then
		Config.Sub.Free = free
	end
	SubPanel.toggle(which == "Sub")
	AuraShop.open(which == "Aura")
	if which == "Kit" and not kit then
		kit = buildKit()
	end
	if kit then
		kit.show(which == "Kit")
	end
end
local function report(text: string)
	local r = ReplicatedStorage:FindFirstChild("ZZShopReport")
	if r then
		(r :: RemoteEvent):FireServer(text)
	end
end
local function safe()
	local ok, err = pcall(apply)
	report(if ok then "applied " .. tostring(workspace:GetAttribute("ShopShot")) else "ERR " .. tostring(err))
end
workspace:GetAttributeChangedSignal("ShopShot"):Connect(safe)
workspace:GetAttributeChangedSignal("ShopFree"):Connect(safe)
safe()
