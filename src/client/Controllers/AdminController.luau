--!strict
-- The admin panel for playtesting, client side (Hugo, 2026-11-18; docs/sandbox.md, "The admin panel"). P opens and
-- closes it, for a player the server has marked Admin (AdminService: anyone in Studio, the place's owner and
-- Config.Admin.Users in a live server). Every button only asks the server, which checks again and does it:
--   endless air and no fail (for you alone), a max Oxygen, into the water at any land's start, a fish of any kind,
--   size and colour put in your hands (as if caught), a fail now, coins, and every sub unlocked.
-- The line at the bottom says what the server did, or why it didn't.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.Lib.State)
local Kit = require(script.Parent.Parent.UI.Kit)

local AdminController = {}

local KEY = Enum.KeyCode.P
local FONT = Enum.Font.GothamMedium
local DARK = Color3.fromRGB(26, 31, 41)
local MID = Color3.fromRGB(62, 72, 90)
local RED = Color3.fromRGB(150, 40, 48)
local GREEN = Color3.fromRGB(40, 120, 70)
local AMBER = Color3.fromRGB(255, 190, 70)
local WHITE = Color3.new(1, 1, 1)
local GREY = Color3.fromRGB(150, 165, 185)
local WIDE = 300

local VARIANTS = { "", "Silver", "Gold", "Rainbow" }

local remote: RemoteEvent? = nil
local panel: Frame? = nil
local status: TextLabel? = nil
local toggles: { [string]: TextButton } = {}
local maxLabel: TextLabel? = nil
local fishLabel: TextButton? = nil

-- the fish to give: every kind, by its home land then by name
local fishList: { Config.FishType } = {}
local fishAt = 1
local sizeAt = 2 -- Normal
local variantAt = 1

local function new(class: string, props: { [string]: any }, parent: Instance?): any
	local object = Instance.new(class :: any)
	for key, value in props do
		(object :: any)[key] = value
	end
	if parent then
		object.Parent = parent
	end
	return object
end

local function edge(object: GuiObject)
	new("UICorner", { CornerRadius = UDim.new(0, 4) }, object)
	local line = new("UIStroke", { Thickness = 1.5, Color = Color3.fromRGB(8, 10, 14) }, object)
	line.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
end

local function send(...: any)
	if remote then
		remote:FireServer(...)
	end
end

local function say(text: string, colour: Color3)
	if status then
		status.Text = text
		status.TextColor3 = colour
	end
end

local function label(parent: Instance, x: number, y: number, w: number, text: string, colour: Color3?): TextLabel
	return new("TextLabel", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, 18),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 13,
		TextColor3 = colour or AMBER,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = text,
	}, parent)
end

local function button(
	parent: Instance,
	x: number,
	y: number,
	w: number,
	text: string,
	colour: Color3?,
	onClick: () -> ()
): TextButton
	local b: TextButton = new("TextButton", {
		Name = text,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, 22),
		BackgroundColor3 = colour or MID,
		BorderSizePixel = 0,
		Font = FONT,
		TextSize = 12,
		TextColor3 = WHITE,
		Text = text,
		AutoButtonColor = true,
	}, parent)
	edge(b)
	b.Activated:Connect(onClick)
	return b
end

local function showToggles()
	local player = State.Player
	for name, b in toggles do
		local on = player:GetAttribute("Admin" .. name) == true
		b.Text = (if on then "[x]  " else "[  ]  ") .. (if name == "NoFail" then "No fail" else "Endless air")
		b.TextColor3 = if on then WHITE else GREY
	end
end

local function showMax()
	if maxLabel then
		local max = State.Player:GetAttribute("MaxOxygen")
		maxLabel.Text = "MAX OXYGEN   (now "
			.. (if type(max) == "number" then tostring(math.floor(max)) else "?")
			.. ")"
	end
end

local function showFish()
	local fish = fishList[fishAt]
	if fishLabel and fish then
		local variant = VARIANTS[variantAt]
		fishLabel.Text = string.format("%s  ·  land %d  ·  %s", fish.Name, fish.Home, fish.Tier)
		local sizeB = fishLabel.Parent and fishLabel.Parent:FindFirstChild("Size") :: TextButton?
		local variantB = fishLabel.Parent and fishLabel.Parent:FindFirstChild("Variant") :: TextButton?
		if sizeB then
			sizeB.Text = "size: " .. Config.SizeOrder[sizeAt]
		end
		if variantB then
			variantB.Text = "colour: " .. (if variant == "" then "plain" else variant)
		end
	end
end

-- a typed name picks the first fish whose name or id holds it
local function find(typed: string)
	local want = string.lower((typed:gsub("%s", "")))
	if want == "" then
		return
	end
	for i, fish in fishList do
		if
			string.find(string.lower((fish.Name:gsub("%s", ""))), want, 1, true)
			or string.find(string.lower(fish.Id), want, 1, true)
		then
			fishAt = i
			showFish()
			return
		end
	end
	say("no fish called " .. typed, Color3.fromRGB(255, 120, 120))
end

local function build()
	local gui = new("ScreenGui", {
		Name = "Admin",
		ResetOnSpawn = false,
		DisplayOrder = 21,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, State.Player:WaitForChild("PlayerGui"))
	local face: Frame = new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(WIDE, 452),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Visible = false,
	}, gui)
	local slate = table.clone(Kit.Themes.Tool)
	slate.Fade = 0.04
	slate.Radius = 8
	Kit.dress(face, slate)
	panel = face
	local inner = WIDE - 20

	new("TextLabel", {
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.fromOffset(inner, 22),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 15,
		TextColor3 = AMBER,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "ADMIN   (P)",
	}, face)
	new("Frame", {
		Position = UDim2.fromOffset(10, 28),
		Size = UDim2.fromOffset(inner, 2),
		BackgroundColor3 = AMBER,
		BorderSizePixel = 0,
	}, face)

	local y = 36
	-- the two switches, for you alone
	local half = (inner - 6) / 2
	toggles.EndlessAir = button(face, 10, y, half, "Endless air", nil, function()
		send("EndlessAir", State.Player:GetAttribute("AdminEndlessAir") ~= true)
	end)
	toggles.NoFail = button(face, 16 + half, y, half, "No fail", nil, function()
		send("NoFail", State.Player:GetAttribute("AdminNoFail") ~= true)
	end)
	for _, b in toggles do
		b.TextXAlignment = Enum.TextXAlignment.Left
		new("UIPadding", { PaddingLeft = UDim.new(0, 8) }, b)
	end
	y += 30

	-- max Oxygen
	maxLabel = label(face, 10, y, inner, "MAX OXYGEN")
	y += 20
	local maxes = Config.Admin.Maxes
	local w = (inner - 4 * (#maxes - 1)) / #maxes
	for i, n in maxes do
		button(face, 10 + (i - 1) * (w + 4), y, w, tostring(n), nil, function()
			send("Max", n)
		end)
	end
	y += 30

	-- the lands
	label(face, 10, y, inner, "INTO THE WATER AT A LAND'S START")
	y += 20
	local lw = (inner - 4 * 4) / 5
	for i = 1, 10 do
		local col, row = (i - 1) % 5, (i - 1) // 5
		button(
			face,
			10 + col * (lw + 4),
			y + row * 26,
			lw,
			i .. " " .. (Kit.LandShort[i] or ""),
			Color3.fromRGB(40, 70, 110),
			function()
				send("Land", i)
			end
		).TextSize =
			10
	end
	y += 58

	-- a fish in your hands
	label(face, 10, y, inner, "A FISH IN YOUR HANDS (put it in the tank)")
	y += 20
	button(face, 10, y, 26, "<", nil, function()
		fishAt = (fishAt - 2) % #fishList + 1
		showFish()
	end)
	fishLabel = button(face, 40, y, inner - 60, "", Color3.fromRGB(44, 52, 68), function() end);
	(fishLabel :: TextButton).AutoButtonColor = false
	(fishLabel :: TextButton).TextTruncate = Enum.TextTruncate.AtEnd
	button(face, 10 + inner - 26, y, 26, ">", nil, function()
		fishAt = fishAt % #fishList + 1
		showFish()
	end)
	y += 26
	local search: TextBox = new("TextBox", {
		Name = "Search",
		Position = UDim2.fromOffset(10, y),
		Size = UDim2.fromOffset(inner, 22),
		BackgroundColor3 = Color3.fromRGB(16, 20, 28),
		BorderSizePixel = 0,
		Font = FONT,
		TextSize = 12,
		TextColor3 = WHITE,
		PlaceholderText = "type a name, Enter (megalodon, clown...)",
		PlaceholderColor3 = GREY,
		Text = "",
		ClearTextOnFocus = true,
	}, face)
	edge(search)
	search.FocusLost:Connect(function()
		find(search.Text)
	end)
	y += 26
	local sizeB = button(face, 10, y, half, "size", nil, function()
		sizeAt = sizeAt % #Config.SizeOrder + 1
		showFish()
	end)
	sizeB.Name = "Size"
	local variantB = button(face, 16 + half, y, half, "colour", nil, function()
		variantAt = variantAt % #VARIANTS + 1
		showFish()
	end)
	variantB.Name = "Variant"
	y += 26
	button(face, 10, y, inner, "GIVE THIS FISH", GREEN, function()
		local fish = fishList[fishAt]
		if fish then
			send("Fish", fish.Id, Config.SizeOrder[sizeAt], VARIANTS[variantAt])
		end
	end)
	y += 32

	-- the rest
	label(face, 10, y, inner, "MORE")
	y += 20
	local third = (inner - 8) / 3
	for i, n in Config.Admin.Coins do
		local text = if n >= 1000 then (n // 1000) .. "k coins" else n .. " coins"
		button(face, 10 + (i - 1) * (third + 4), y, third, "+" .. text, Color3.fromRGB(70, 100, 40), function()
			send("Coins", n)
		end)
	end
	button(face, 10 + 2 * (third + 4), y, third, "All subs", Color3.fromRGB(40, 90, 110), function()
		send("Subs")
	end)
	y += 26
	button(face, 10, y, inner, "FAIL NOW", RED, function()
		send("Fail")
	end)
	y += 30

	status = new("TextLabel", {
		Position = UDim2.fromOffset(10, y),
		Size = UDim2.fromOffset(inner, 34),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 12,
		TextColor3 = GREY,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "every button is checked by the server",
	}, face)
	face.Size = UDim2.fromOffset(WIDE, y + 40)

	showToggles()
	showMax()
	showFish()
end

-- For Studio's tests: open or close the panel
function AdminController.toggle(on: boolean?)
	if panel then
		panel.Visible = if on == nil then not panel.Visible else on
	end
end

local started = false
local function start()
	if started or State.Player:GetAttribute("Admin") ~= true then
		return
	end
	started = true
	remote = Net.Folder:WaitForChild("Admin") :: RemoteEvent
	for _, fish in Config.Fish do
		table.insert(fishList, fish)
	end
	table.sort(fishList, function(a, b)
		if a.Home ~= b.Home then
			return a.Home < b.Home
		end
		return a.Name < b.Name
	end)
	build();
	(remote :: RemoteEvent).OnClientEvent:Connect(function(kind: string, text: string)
		say(text, if kind == "Done" then Color3.fromRGB(141, 240, 106) else Color3.fromRGB(255, 120, 120))
	end)
	local player = State.Player
	player:GetAttributeChangedSignal("AdminEndlessAir"):Connect(showToggles)
	player:GetAttributeChangedSignal("AdminNoFail"):Connect(showToggles)
	player:GetAttributeChangedSignal("MaxOxygen"):Connect(showMax)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == KEY then
			AdminController.toggle()
		end
	end)
end

function AdminController.Start()
	State.Player:GetAttributeChangedSignal("Admin"):Connect(start)
	start()
end

return AdminController
