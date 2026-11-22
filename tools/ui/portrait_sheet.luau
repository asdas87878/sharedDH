--!strict
-- Fish pictures on one sheet, each drawn the way a caught slot shows it (the rarity's colour, a black outline, the
-- picture's window standing a little over the top edge as in Slots.luau, the name over the foot), by the game's own
-- Portrait module. Edit mode; nothing is saved. Run it through tools/ui/portrait_sheet.py, which fills in ROWS:
--   python tools/ui/portrait_sheet.py <studio_id> all                      every fish, the Portrait in the repo
--   python tools/ui/portrait_sheet.py <studio_id> Dolphin,Kraken --before   a few, the last commit's and the repo's
--   python tools/ui/portrait_sheet.py <studio_id> off                      takes the sheet away
-- A row is { Label, Source (the Portrait code to draw with), Settings (numbers laid over Portrait.Settings) }.
-- A copy of the UI folder goes in ServerStorage for each row and is taken away with the sheet.
local WHICH = "all"
local TILE = 0
local PLAIN = false -- just the pictures, each filling a square on a white ground (for tools/ui/export_portraits.py)
local START = 1 -- and from which fish, how many
local COUNT = 0
local ROWS: { { any } } = {}

local StarterGui = game:GetService("StarterGui")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config) :: any

for _, where in { StarterGui, ServerStorage } do
	for _, old in where:GetChildren() do
		if string.sub(old.Name, 1, 13) == "PortraitSheet" then
			old:Destroy()
		end
	end
end
if WHICH == "" then
	return "sheet taken away"
end

local names: { string } = {}
if WHICH == "all" then
	for _, model in ReplicatedStorage.FishModels:GetChildren() do
		table.insert(names, model.Name)
	end
	table.sort(names)
else
	names = string.split(WHICH, ",")
end
if COUNT > 0 then
	names = table.move(names, START, math.min(START + COUNT - 1, #names), 1, {})
end

local gui = Instance.new("ScreenGui")
gui.Name = "PortraitSheet"
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
gui.Parent = StarterGui
local back = Instance.new("Frame")
back.Size = UDim2.fromScale(1, 1)
back.BackgroundColor3 = if PLAIN then Color3.new(1, 1, 1) else Color3.fromRGB(38, 70, 104)
back.BorderSizePixel = 0
back.Parent = gui

local function lighter(c: Color3, by: number): Color3
	return c:Lerp(Color3.new(1, 1, 1), by)
end
local function darker(c: Color3, by: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), by)
end

-- lays b's numbers over a's, table by table
local function lay(a: any, b: any)
	for key, value in b do
		if type(value) == "table" and type(a[key]) == "table" then
			lay(a[key], value)
		else
			a[key] = value
		end
	end
end

local cols = if #names <= 12 then #names else 12
local tile = if TILE > 0 then TILE else (if #ROWS > 1 then 84 else 96)
local gap = math.floor(tile * 0.22)
if PLAIN then
	cols = math.floor((workspace.CurrentCamera.ViewportSize.X - 20) / (tile + 10))
	gap = 10
end
local labelWide = if #ROWS > 1 then 70 else 0
local y = 10
local drawn = 0
for r, row in ROWS do
	local label, source, settings = row[1], row[2], row[3]
	local ui = game:GetService("StarterPlayer").StarterPlayerScripts.Client.UI:Clone()
	ui.Name = "PortraitSheet" .. r
	if source and source ~= "" then
		(ui :: any).Portrait.Source = source
	end
	ui.Parent = ServerStorage
	local Portrait = require((ui :: any).Portrait) :: any
	if settings and Portrait.Settings then
		lay(Portrait.Settings, settings)
		Portrait.reset()
	end
	if labelWide > 0 then
		local text = Instance.new("TextLabel")
		text.Position = UDim2.fromOffset(6, y + tile * 0.3)
		text.Size = UDim2.fromOffset(labelWide - 8, 30)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBlack
		text.TextSize = 15
		text.TextWrapped = true
		text.TextColor3 = Color3.fromRGB(255, 230, 120)
		text.Text = label
		text.Parent = back
	end
	for i, name in names do
		if PLAIN then
			-- a square of white, the picture filling it: what tools/ui/export_portraits.py cuts out
			local cell = Instance.new("Frame")
			cell.Position =
				UDim2.fromOffset(10 + ((i - 1) % cols) * (tile + gap), 10 + math.floor((i - 1) / cols) * (tile + gap))
			cell.Size = UDim2.fromOffset(tile, tile)
			cell.BackgroundTransparency = 1
			cell.Parent = back
			local picture = Portrait.new(cell, { Size = UDim2.fromScale(1, 1) })
			task.wait()
			if picture.show(name) then
				drawn += 1
			end
			continue
		end
		local slot = Instance.new("Frame")
		slot.Position = UDim2.fromOffset(
			labelWide + 10 + ((i - 1) % cols) * (tile + gap),
			y + math.floor((i - 1) / cols) * (tile + gap) + math.floor(tile * 0.2)
		)
		slot.Size = UDim2.fromOffset(tile, tile)
		local kind = Config.FishById[name]
		local tier = Config.Tiers[kind and kind.Tier or "Common"] or {}
		local colour: Color3 = tier.Colour or Color3.fromRGB(160, 170, 180)
		slot.BackgroundColor3 = Color3.new(1, 1, 1)
		slot.BorderSizePixel = 0
		slot.Parent = back
		local fill = Instance.new("UIGradient")
		fill.Color = ColorSequence.new(lighter(colour, 0.08), darker(colour, 0.1))
		fill.Rotation = 90
		fill.Parent = slot
		local edge = Instance.new("UIStroke")
		edge.Thickness = math.max(2, math.floor(tile / 23 + 0.5))
		edge.Color = Color3.fromRGB(6, 8, 14)
		edge.LineJoinMode = Enum.LineJoinMode.Miter
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		edge.Parent = slot
		-- (as Slots.luau's WINDOW: 10% wider than the slot, from 19% over its top to 3% above its foot)
		local picture = Portrait.new(slot, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 0.97),
			Size = UDim2.fromScale(1.1, 1.16),
			ZIndex = 2,
		})
		task.wait()
		if picture.show(name) then
			drawn += 1
		end
		local display = if kind then kind.Name else name
		local text = Instance.new("TextLabel")
		text.AnchorPoint = Vector2.new(0.5, 1)
		text.Position = UDim2.new(0.5, 0, 1, -1)
		text.Size = UDim2.new(1, 8, 0, math.floor(tile * 0.24))
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBlack
		text.TextSize = math.floor(tile * 0.24)
		text.TextColor3 = Color3.new(1, 1, 1)
		text.Text = if #display > 7 then (string.gsub(string.sub(display, 1, 6), "%s+$", "")) .. "." else display
		text.ZIndex = 3
		text.Parent = slot
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = math.max(1, math.floor(tile / 46 + 0.5))
		stroke.Color = Color3.fromRGB(6, 8, 14)
		stroke.Parent = text
	end
	y += math.ceil(#names / cols) * (tile + gap) + math.floor(tile * 0.2) + 6
end
return string.format("%d pictures drawn, %d rows", drawn, #ROWS)
