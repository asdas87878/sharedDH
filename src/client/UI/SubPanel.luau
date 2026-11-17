--!strict
-- The submarine's panel at the hub (docs/design/submarine.md): a SUB button under Shop and Index (or F on the dock)
-- opens a list of the lands after the first. Each says GO (yours: pick it), PICKED, BUY and its price (the next tier),
-- or LOCKED. "Ride with" picks a fish from your tank to be dropped onto (or none: you are flung into a hop). Under the
-- button a ticket says where the sub will take you when you next jump in. The server decides everything
-- (SubService: Action "SubBuy", "SubPick", land, fishKey); this only shows the player's SubTier, SubDest, SubFish,
-- Coins and Tank attributes. Placeholder look, in the hub signs' colours.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.Lib.State)

local SubPanel = {}

local BLUE = Color3.fromRGB(30, 140, 255)
local INK = Color3.fromRGB(16, 36, 63)
local YELLOW = Color3.fromRGB(255, 196, 38)
local GREEN = Color3.fromRGB(70, 200, 90)
local GREY = Color3.fromRGB(120, 130, 145)
local FONT = Enum.Font.LuckiestGuy

local gui: ScreenGui
local button: TextButton
local ticket: TextLabel
local panel: Frame
local list: ScrollingFrame
local coinsLabel: TextLabel
local fishButton: TextButton
local hintLabel: TextLabel
local hintAt = -math.huge
local open = false

local function attr(name: string, default: any): any
	local value = State.Player:GetAttribute(name)
	return if value == nil then default else value
end

local function label(parent: Instance, text: string, size: UDim2, at: UDim2, colour: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = at
	l.Font = FONT
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = colour or Color3.new(1, 1, 1)
	l.Parent = parent
	local edge = Instance.new("UIStroke")
	edge.Thickness = 2
	edge.Color = INK
	edge.Parent = l
	return l
end

local function plate(parent: Instance, text: string, colour: Color3, size: UDim2, at: UDim2): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BackgroundColor3 = colour
	b.Size = size
	b.Position = at
	b.Font = FONT
	b.TextScaled = true
	b.Text = text
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = b
	local edge = Instance.new("UIStroke")
	edge.Thickness = 2
	edge.Color = INK
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 5)
	pad.PaddingBottom = UDim.new(0, 5)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = b
	return b
end

type TankFish = { Key: string, Name: string }
local function tankFish(): { TankFish }
	local out: { TankFish } = {}
	local json = attr("Tank", "[]")
	local ok, rows = pcall(function()
		return HttpService:JSONDecode(json)
	end)
	if not ok or type(rows) ~= "table" then
		return out
	end
	for _, row in rows do
		if type(row) == "table" and type(row[1]) == "string" then
			local kind = Config.FishById[row[1]]
			local size, variant = tostring(row[2] or "Normal"), tostring(row[3] or "")
			local name = (if size ~= "Normal" then size .. " " else "")
				.. (if variant ~= "" then variant .. " " else "")
				.. (if kind then kind.Name else row[1])
			table.insert(out, { Key = row[1] .. "|" .. size .. "|" .. variant, Name = name })
		end
	end
	return out
end

local function fishName(key: string): string
	if key == "" then
		return "NONE: FLING ME"
	end
	for _, f in tankFish() do
		if f.Key == key then
			return string.upper(f.Name)
		end
	end
	return "NONE: FLING ME"
end

local function landName(index: number): string
	local zone = State.Zones[index]
	return if zone then string.upper(zone.Name) else ("LAND " .. index)
end

local function refresh()
	local tier = attr("SubTier", 0)
	local dest = attr("SubDest", 0)
	local coins = attr("Coins", 0)
	local fish = attr("SubFish", "")
	coinsLabel.Text = "COINS " .. Config.shortNumber(coins)
	fishButton.Text = "RIDE WITH: " .. fishName(fish)
	ticket.Text = if dest >= 2 then "SUB > " .. landName(dest) else "SUB: OFF"
	ticket.TextColor3 = if dest >= 2 then YELLOW else GREY
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local lands = math.max(#State.Zones, 10)
	local rows = 0
	local function row(name: string, text: string, colour: Color3, press: (() -> ())?)
		rows += 1
		local frame = Instance.new("Frame")
		frame.BackgroundColor3 = if rows % 2 == 0 then Color3.fromRGB(22, 70, 140) else Color3.fromRGB(26, 84, 165)
		frame.BorderSizePixel = 0
		frame.Size = UDim2.new(1, -8, 0, 40)
		frame.LayoutOrder = rows
		frame.Parent = list
		label(frame, name, UDim2.new(0.58, -8, 0.7, 0), UDim2.new(0, 8, 0.15, 0))
		local b = plate(frame, text, colour, UDim2.new(0.4, -6, 0.8, 0), UDim2.fromScale(0.6, 0.1))
		if press then
			b.Activated:Connect(press)
		else
			b.AutoButtonColor = false
		end
	end
	row("NO SUB: DIVE IN", if dest == 0 then "PICKED" else "PICK", if dest == 0 then GREEN else BLUE, function()
		Net.Action:FireServer("SubPick", 0, attr("SubFish", ""))
	end)
	for land = 2, lands do
		local need = land - 1 -- the tier that reaches it
		local price = Config.Sub.Prices[need]
		local name = string.format("%d %s", land, landName(land))
		if land == dest then
			row(name, "PICKED", GREEN, nil)
		elseif need <= tier then
			row(name, "GO", BLUE, function()
				Net.Action:FireServer("SubPick", land, attr("SubFish", ""))
			end)
		elseif need == tier + 1 and price then
			local can = coins >= price
			row(name, "BUY $" .. Config.shortNumber(price), if can then YELLOW else GREY, function()
				Net.Action:FireServer("SubBuy")
			end)
		else
			row(name, if price then "LOCKED $" .. Config.shortNumber(price) else "LOCKED", GREY, nil)
		end
	end
	list.CanvasSize = UDim2.fromOffset(0, rows * 44)
end

local function show(on: boolean)
	open = on and State.Mode == "Dock"
	panel.Visible = open
	if open then
		refresh()
	end
end

-- A line of help at the foot of the screen while it is asked for (called every frame it should show)
function SubPanel.hint(text: string)
	hintLabel.Text = text
	hintAt = os.clock()
end

function SubPanel.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "SubPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 7
	gui.Parent = State.Player:WaitForChild("PlayerGui")

	-- the SUB button, under Shop and Index at the left edge (HubButtons), with its ticket
	button = plate(gui, "SUB", YELLOW, UDim2.fromOffset(147, 44), UDim2.new(0, 10, 0.5, 66))
	button.Name = "SubButton"
	ticket = label(gui, "", UDim2.fromOffset(200, 20), UDim2.new(0, 10, 0.5, 112), YELLOW)
	ticket.TextXAlignment = Enum.TextXAlignment.Left
	button.Activated:Connect(function()
		show(not open)
	end)

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(440, 520)
	panel.BackgroundColor3 = BLUE
	panel.Visible = false
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = panel
	local edge = Instance.new("UIStroke")
	edge.Thickness = 4
	edge.Color = INK
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = panel
	label(panel, "SUBMARINE", UDim2.new(1, -80, 0, 44), UDim2.fromOffset(16, 10), YELLOW)
	label(
		panel,
		"BUY ONCE. RIDE FOREVER. PICK A LAND, THEN JUMP IN!",
		UDim2.new(1, -32, 0, 18),
		UDim2.fromOffset(16, 56)
	)
	coinsLabel = label(panel, "", UDim2.new(1, -32, 0, 22), UDim2.fromOffset(16, 80), YELLOW)
	local close = plate(panel, "X", Color3.fromRGB(220, 60, 80), UDim2.fromOffset(44, 44), UDim2.new(1, -56, 0, 12))
	close.Activated:Connect(function()
		show(false)
	end)
	list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(12, 110)
	list.Size = UDim2.new(1, -24, 1, -176)
	list.ScrollBarThickness = 6
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	fishButton = plate(panel, "", Color3.fromRGB(150, 90, 230), UDim2.new(1, -24, 0, 48), UDim2.new(0, 12, 1, -60))
	fishButton.Activated:Connect(function()
		-- the next fish of the tank, round to none
		local options = tankFish()
		local now = attr("SubFish", "")
		local nextKey = if #options > 0 then options[1].Key else ""
		for i, f in options do
			if f.Key == now then
				nextKey = if options[i + 1] then options[i + 1].Key else ""
				break
			end
		end
		Net.Action:FireServer("SubPick", attr("SubDest", 0), nextKey)
	end)

	hintLabel = label(gui, "", UDim2.fromOffset(520, 32), UDim2.new(0.5, -260, 0.78, 0), YELLOW)
	hintLabel.Visible = false

	for _, name in { "SubTier", "SubDest", "SubFish", "Coins", "Tank" } do
		State.Player:GetAttributeChangedSignal(name):Connect(function()
			refresh()
		end)
	end
	Net.Ride.OnClientEvent:Connect(function(kind: string, a: any)
		if kind == "SubDenied" then
			SubPanel.hint(
				if a == "Coins" then "Not enough coins!" elseif a == "Dock" then "Only at the hub!" else "Can't do that"
			)
		elseif kind == "SubBought" then
			SubPanel.hint("Tier " .. tostring(a) .. " bought! Your boarding pass is ready")
		end
	end)
	State.ModeChanged.Event:Connect(function(mode: string)
		button.Visible = mode == "Dock"
		ticket.Visible = mode == "Dock"
		if mode ~= "Dock" then
			show(false)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.F and State.Mode == "Dock" then
			show(not open)
		end
	end)
	RunService.RenderStepped:Connect(function()
		local on = os.clock() - hintAt < 2.2
		hintLabel.Visible = on
	end)
	refresh()
end

return SubPanel
