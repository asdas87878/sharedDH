--!strict
-- The submarine shop at the stand (docs/design/submarine.md; Hugo, 2026-11-18: "remove the sub button, make the
-- player able to buy the subs there and equip them"). Walking up to the stand (Dock.Stations.Sub) shows a prompt on
-- its ring; pressing it opens the shop: every sub (Shared/SubModels, one a tier) with its picture, the land it reaches
-- and BUY (the next one, its price shown, free while Config.Sub.Free is 1), EQUIP, EQUIPPED or LOCKED; "NO SUB" for
-- the ordinary dive-in. Under the list, GO TO cycles the lands the equipped sub reaches, and RIDE WITH a fish from your
-- tank to be dropped onto (or none: you are flung into a hop). It closes as you walk away. At the left edge a ticket
-- says where the sub will take you when you next jump in. The server decides everything (SubService: Action
-- "SubBuy", "SubEquip", n, "SubPick", land, fishKey, each only at the stand); this only shows the player's SubTier,
-- SubEquip, SubDest, SubFish, Coins and Tank attributes. Placeholder look, in the hub signs' colours.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local SubModels = require(ReplicatedStorage.Shared.SubModels)
local State = require(script.Parent.Parent.Lib.State)

local SubPanel = {}

local BLUE = Color3.fromRGB(30, 140, 255)
local INK = Color3.fromRGB(16, 36, 63)
local YELLOW = Color3.fromRGB(255, 196, 38)
local GREEN = Color3.fromRGB(70, 200, 90)
local GREY = Color3.fromRGB(120, 130, 145)
local FONT = Enum.Font.LuckiestGuy

local gui: ScreenGui
local ticket: TextLabel
local panel: Frame
local list: ScrollingFrame
local coinsLabel: TextLabel
local fishButton: TextButton
local goButton: TextButton
local prompt: ProximityPrompt? = nil
type Row = { Name: TextLabel, Reach: TextLabel, Button: TextButton }
local shopRows: { [number]: Row } = {} -- 0: no sub
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

-- The lands the equipped sub reaches, in order (none when no sub is equipped)
local function reachable(): { number }
	local out = {}
	local lands = math.max(#State.Zones, 10)
	for land = 2, math.min(attr("SubEquip", 0) + 1, lands) do
		table.insert(out, land)
	end
	return out
end

local function setButton(b: TextButton, text: string, colour: Color3, live: boolean)
	b.Text = text
	b.BackgroundColor3 = colour
	b.AutoButtonColor = live
	b.Active = live
end

local function refresh()
	local tier = attr("SubTier", 0)
	local equipped = attr("SubEquip", 0)
	local dest = attr("SubDest", 0)
	local coins = attr("Coins", 0)
	local fish = attr("SubFish", "")
	local free = Config.Sub.Free == 1
	coinsLabel.Text = "COINS " .. Config.shortNumber(coins) .. (if free then "   SUBS ARE FREE FOR NOW!" else "")
	fishButton.Text = "RIDE WITH: " .. fishName(fish)
	ticket.Text = if equipped >= 1 and dest >= 2 then "SUB > " .. landName(dest) else "SUB: OFF"
	ticket.TextColor3 = if equipped >= 1 and dest >= 2 then YELLOW else GREY
	goButton.Text = if equipped >= 1 and dest >= 2 then "GO TO: " .. dest .. " " .. landName(dest) else "GO TO: NO SUB"
	goButton.BackgroundColor3 = if equipped >= 1 then BLUE else GREY
	for n, row in shopRows do
		if n == 0 then
			if equipped == 0 then
				setButton(row.Button, "EQUIPPED", GREEN, false)
			else
				setButton(row.Button, "EQUIP", BLUE, true)
			end
			continue
		end
		local price = Config.Sub.Prices[n]
		local cost = if price then "$" .. Config.shortNumber(price) else ""
		row.Reach.Text = "TO " .. (n + 1) .. " " .. landName(n + 1) .. (if cost ~= "" then "  " .. cost else "")
		if n == equipped then
			setButton(row.Button, "EQUIPPED", GREEN, false)
		elseif n <= tier then
			setButton(row.Button, "EQUIP", BLUE, true)
		elseif n == tier + 1 and price then
			local can = free or coins >= price
			setButton(row.Button, if free then "BUY: FREE" else "BUY " .. cost, if can then YELLOW else GREY, can)
		else
			setButton(row.Button, "LOCKED", GREY, false)
		end
	end
end

-- One sub's picture: its model in a viewport, three-quarters from the front
local function picture(parent: Instance, n: number)
	local view = Instance.new("ViewportFrame")
	view.BackgroundColor3 = Color3.fromRGB(14, 50, 104)
	view.BorderSizePixel = 0
	view.Size = UDim2.fromOffset(86, 56)
	view.Position = UDim2.fromOffset(6, 4)
	view.Ambient = Color3.fromRGB(170, 170, 170)
	view.LightColor = Color3.new(1, 1, 1)
	view.LightDirection = Vector3.new(-1, -1, -0.5)
	view.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = view
	local model = SubModels.build(n)
	local sign = model:FindFirstChild("Label", true)
	if sign then
		sign:Destroy()
	end
	model.Parent = view
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.CFrame = CFrame.lookAt(Vector3.new(-44, 18, -36), Vector3.new(0, 2, 0))
	cam.Parent = view
	view.CurrentCamera = cam
end

local function build()
	local function row(n: number, name: string)
		local frame = Instance.new("Frame")
		frame.BackgroundColor3 = if n % 2 == 0 then Color3.fromRGB(22, 70, 140) else Color3.fromRGB(26, 84, 165)
		frame.BorderSizePixel = 0
		frame.Size = UDim2.new(1, -8, 0, 64)
		frame.LayoutOrder = n
		frame.Parent = list
		local left = 10
		if n >= 1 then
			picture(frame, n)
			left = 100
		end
		local title = label(frame, name, UDim2.new(0.62, -left, 0, 26), UDim2.fromOffset(left, 7))
		title.TextXAlignment = Enum.TextXAlignment.Left
		local reach = label(
			frame,
			if n == 0 then "THE ORDINARY DIVE-IN" else "",
			UDim2.new(0.62, -left, 0, 18),
			UDim2.fromOffset(left, 37),
			Color3.fromRGB(190, 225, 255)
		)
		reach.TextXAlignment = Enum.TextXAlignment.Left
		local b = plate(frame, "", BLUE, UDim2.new(0.36, -8, 0, 44), UDim2.new(0.64, 0, 0, 10))
		b.Activated:Connect(function()
			if not b.Active then
				return
			end
			if n >= 1 and n > attr("SubTier", 0) then
				Net.Action:FireServer("SubBuy")
			else
				Net.Action:FireServer("SubEquip", n)
			end
		end)
		shopRows[n] = { Name = title, Reach = reach, Button = b }
	end
	row(0, "NO SUB")
	for n, style in SubModels.List do
		if Config.Sub.Prices[n] then
			row(n, string.upper(style.Name))
		end
	end
	list.CanvasSize = UDim2.fromOffset(0, (#SubModels.List + 1) * 68)
end

local function show(on: boolean)
	open = on and State.Mode == "Dock"
	panel.Visible = open
	if open then
		refresh()
	end
end

-- The stand's ring (nil: not in the place, or not streamed in yet)
local function standRing(): BasePart?
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local dock = blockout and blockout:FindFirstChild("Dock")
	local stations = dock and dock:FindFirstChild("Stations")
	local stand = stations and stations:FindFirstChild("Sub")
	local ring = stand and (stand:FindFirstChild("Ring") or (stand:IsA("Model") and stand.PrimaryPart))
	return if ring and ring:IsA("BasePart") then ring else nil
end

-- The prompt on the stand's ring, made once it is there (and again if the stand is rebuilt)
local function keepPrompt()
	local ring = standRing()
	if not ring or (prompt and prompt.Parent == ring) then
		return
	end
	if prompt then
		prompt:Destroy()
	end
	local p = Instance.new("ProximityPrompt")
	p.Name = "SubShop"
	p.ActionText = "Submarines"
	p.ObjectText = "Sub shop"
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.HoldDuration = 0
	p.MaxActivationDistance = 16
	p.RequiresLineOfSight = false
	p.Triggered:Connect(function()
		show(not open)
	end)
	p.Parent = ring
	prompt = p
end

-- A line of help at the foot of the screen while it is asked for (called every frame it should show)
function SubPanel.hint(text: string)
	hintLabel.Text = text
	hintAt = os.clock()
end

-- Studio's tests: open or close the shop as the prompt does
function SubPanel.toggle(on: boolean)
	show(on)
end

function SubPanel.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "SubPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 7
	gui.Parent = State.Player:WaitForChild("PlayerGui")

	-- the ticket at the left edge, where the SUB button was: where the sub takes you
	ticket = label(gui, "", UDim2.fromOffset(200, 20), UDim2.new(0, 10, 0.5, 112), YELLOW)
	ticket.TextXAlignment = Enum.TextXAlignment.Left

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(520, 580)
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
	label(panel, "SUBMARINES", UDim2.new(1, -80, 0, 44), UDim2.fromOffset(16, 10), YELLOW)
	label(panel, "BUY A SUB, EQUIP IT, PICK A LAND, THEN JUMP IN!", UDim2.new(1, -32, 0, 18), UDim2.fromOffset(16, 56))
	coinsLabel = label(panel, "", UDim2.new(1, -32, 0, 22), UDim2.fromOffset(16, 80), YELLOW)
	local close = plate(panel, "X", Color3.fromRGB(220, 60, 80), UDim2.fromOffset(44, 44), UDim2.new(1, -56, 0, 12))
	close.Activated:Connect(function()
		show(false)
	end)
	list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(12, 110)
	list.Size = UDim2.new(1, -24, 1, -232)
	list.ScrollBarThickness = 6
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	goButton = plate(panel, "", BLUE, UDim2.new(1, -24, 0, 48), UDim2.new(0, 12, 1, -114))
	goButton.Activated:Connect(function()
		-- the next land the equipped sub reaches, round to the first
		local options = reachable()
		if #options == 0 then
			return SubPanel.hint("Equip a sub first!")
		end
		local now = attr("SubDest", 0)
		local nextLand = options[1]
		for i, land in options do
			if land == now then
				nextLand = options[i % #options + 1]
				break
			end
		end
		Net.Action:FireServer("SubPick", nextLand, attr("SubFish", ""))
	end)
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
	build()

	hintLabel = label(gui, "", UDim2.fromOffset(520, 32), UDim2.new(0.5, -260, 0.78, 0), YELLOW)
	hintLabel.Visible = false

	for _, name in { "SubTier", "SubEquip", "SubDest", "SubFish", "Coins", "Tank" } do
		State.Player:GetAttributeChangedSignal(name):Connect(function()
			refresh()
		end)
	end
	Net.Ride.OnClientEvent:Connect(function(kind: string, a: any)
		if kind == "SubDenied" then
			SubPanel.hint(
				if a == "Coins"
					then "Not enough coins!"
					elseif a == "Dock" then "Only at the sub stand!"
					else "Can't do that"
			)
		elseif kind == "SubBought" then
			local style = SubModels.style(tonumber(a) or 1)
			SubPanel.hint(string.upper(style.Name) .. " bought and equipped! Your boarding pass is ready")
		end
	end)
	State.ModeChanged.Event:Connect(function(mode: string)
		ticket.Visible = mode == "Dock"
		if prompt then
			prompt.Enabled = mode == "Dock"
		end
		if mode ~= "Dock" then
			show(false)
		end
	end)
	local lastLook = 0
	RunService.RenderStepped:Connect(function()
		hintLabel.Visible = os.clock() - hintAt < 2.2
		if os.clock() - lastLook > 1 then
			lastLook = os.clock()
			keepPrompt()
		end
		-- walked away from the stand: the shop closes
		if open then
			local ring = standRing()
			local character = State.Player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if ring and root and root:IsA("BasePart") then
				local gap = root.Position - ring.Position
				if Vector3.new(gap.X, 0, gap.Z).Magnitude > Config.Sub.Near then
					show(false)
				end
			end
		end
	end)
	refresh()
end

return SubPanel
