--!strict
-- The riding HUD, all built in code: the Oxygen meter (flashing while you drown, the screen closing in), speed, the
-- depth gauge with the zone's name, speed lines that come in as you go faster, and the drowning's black and its words
-- (State.Fade and State.FadeText, from DeathController). The jump's ring and glow are in the world (JumpController).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Zones = require(ReplicatedStorage.Shared.Zones)
local State = require(script.Parent.Parent.Lib.State)

local HudController = {}

local FONT = Enum.Font.FredokaOne
local AIR = Color3.fromRGB(90, 220, 255)
local LOW = Color3.fromRGB(255, 200, 60)
local OUT = Color3.fromRGB(255, 70, 70)

local gui: ScreenGui
local meter: Frame
local meterFill: Frame
local meterText: TextLabel
local graceText: TextLabel
local speedText: TextLabel
local depthText: TextLabel
local zoneText: TextLabel
local depthPip: Frame
local depthFrame: Frame
local fade: Frame
local fadeText: TextLabel
local fadeScale: UIScale
local edges: { Frame } = {}
local lines: { { frame: Frame, angle: number, offset: number, length: number } } = {}

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

local function label(props: { [string]: any }, parent: Instance): TextLabel
	props.BackgroundTransparency = 1
	props.Font = FONT
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	props.TextStrokeTransparency = 0.2
	return new("TextLabel", props, parent)
end

local function corner(parent: Instance, radius: number)
	new("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function build()
	gui = new("ScreenGui", {
		Name = "RideHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, State.Player:WaitForChild("PlayerGui"))

	-- speed lines, behind everything
	local linesFrame = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui)
	local rng = Random.new(7)
	for i = 1, 28 do
		local frame = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			BackgroundTransparency = 1,
		}, linesFrame)
		table.insert(lines, {
			frame = frame,
			angle = (i / 28) * math.pi * 2 + rng:NextNumber(-0.1, 0.1),
			offset = rng:NextNumber(),
			length = rng:NextNumber(90, 220),
		})
	end

	-- the grace vignette: four edges closing in
	for i = 1, 4 do
		local edge = new("Frame", { BackgroundColor3 = Color3.fromRGB(10, 0, 20), BorderSizePixel = 0 }, gui)
		local gradient = new("UIGradient", { Transparency = NumberSequence.new(0, 1) }, edge)
		gradient.Rotation = ({ 90, 270, 0, 180 })[i]
		edge.AnchorPoint = ({ Vector2.new(0, 0), Vector2.new(0, 1), Vector2.new(0, 0), Vector2.new(1, 0) })[i]
		edge.Position = ({ UDim2.fromScale(0, 0), UDim2.fromScale(0, 1), UDim2.fromScale(0, 0), UDim2.fromScale(1, 0) })[i]
		edge.Visible = false
		table.insert(edges, edge)
	end

	-- the Oxygen meter, bottom centre
	meter = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -28),
		Size = UDim2.fromOffset(380, 30),
		BackgroundColor3 = Color3.fromRGB(15, 30, 50),
		BackgroundTransparency = 0.2,
	}, gui)
	corner(meter, 10)
	new("UIStroke", { Thickness = 3, Color = Color3.fromRGB(255, 255, 255) }, meter)
	meterFill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = AIR, BorderSizePixel = 0 }, meter)
	corner(meterFill, 10)
	meterText = label({ Size = UDim2.fromScale(1, 1), TextScaled = true, Text = "OXYGEN", ZIndex = 2 }, meter)
	new("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3) }, meterText)
	graceText = label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -6),
		Size = UDim2.fromOffset(380, 34),
		TextScaled = true,
		TextColor3 = OUT,
		Text = "",
	}, meter)
	speedText = label({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(1, 14, 1, 0),
		Size = UDim2.fromOffset(130, 42),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	}, meter)

	-- the depth gauge, right edge
	depthFrame = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -18, 0.42, 0),
		Size = UDim2.fromOffset(14, 260),
		BackgroundColor3 = Color3.fromRGB(15, 30, 50),
		BackgroundTransparency = 0.25,
	}, gui)
	corner(depthFrame, 7)
	new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(120, 230, 255), Color3.fromRGB(10, 10, 40)),
		Rotation = 90,
	}, depthFrame)
	depthPip = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(26, 8),
		Position = UDim2.fromScale(0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, depthFrame)
	corner(depthPip, 4)
	depthText = label({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromOffset(-12, 0),
		Size = UDim2.fromOffset(150, 34),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "0 m",
	}, depthPip)
	zoneText = label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 1, 8),
		Size = UDim2.fromOffset(220, 24),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
	}, depthFrame)

	-- the drowning's black	-- the deaths' black
	fade = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 10,
	}, gui)
	fadeText = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(500, 60),
		TextScaled = true,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Text = "",
		ZIndex = 11,
	}, fade)
	fadeScale = new("UIScale", {}, fadeText)
end

local function updateMeter(now: number)
	local oxygen = (State.Player:GetAttribute("Oxygen") :: number?) or 0
	local max = (State.Player:GetAttribute("MaxOxygen") :: number?) or Config.Oxygen.StartMax
	local fraction = math.clamp(oxygen / math.max(max, 1), 0, 1)
	local drowning = State.Mode == "Drowning"
	meterFill.Size = UDim2.fromScale(math.max(fraction, 0.02), 1)
	local colour = if fraction > 0.5 then AIR elseif fraction > 0.2 then AIR:Lerp(LOW, (0.5 - fraction) / 0.3) else OUT
	if drowning then
		local flash = (math.sin(now * 18) + 1) / 2
		colour = OUT
		meter.BackgroundColor3 = Color3.fromRGB(60, 10, 10):Lerp(OUT, flash * 0.6)
		graceText.Text = "OUT OF AIR!"
	else
		meter.BackgroundColor3 = Color3.fromRGB(15, 30, 50)
		graceText.Text = ""
	end
	meterFill.BackgroundColor3 = colour
	meterText.Text = string.format("OXYGEN  %d / %d", math.ceil(oxygen), max)

	-- the screen closes in as you drown
	local closing = State.Vignette
	for i, edge in edges do
		edge.Visible = closing > 0
		local amount = 0.12 + 0.3 * closing
		edge.Size = if i <= 2 then UDim2.fromScale(1, amount) else UDim2.fromScale(amount, 1)
	end
end

local function updateDepth()
	local _, root = State.character()
	if not root then
		return
	end
	local zone, _, metres = Zones.locate(State.Zones, root.Position)
	local shown = if zone then metres else math.max(0, -root.Position.Y / 3)
	depthText.Text = string.format("%d m", math.floor(shown))
	zoneText.Text = if zone then zone.Name elseif State.Mode == "Dock" then "THE DOCK" else ""
	-- the pip runs down the gauge by zone, evenly, since the metres grow so fast
	local count = math.max(#State.Zones, 1)
	local progress = 0
	if zone then
		local _, u = Zones.locate(State.Zones, root.Position)
		progress = (zone.Index - 1 + u) / count
	end
	depthPip.Position = UDim2.fromScale(0.5, progress)
end

local shownText = ""

local function updateFade()
	fade.BackgroundTransparency = 1 - State.Fade
	if State.FadeText ~= shownText then
		shownText = State.FadeText
		fadeText.Text = shownText
		if shownText ~= "" then
			fadeScale.Scale = 1.6
			TweenService:Create(fadeScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
	end
	local textAlpha = if shownText ~= "" then State.Fade else 0
	fadeText.TextTransparency = 1 - textAlpha
	fadeText.TextStrokeTransparency = 1 - textAlpha * 0.7
end

local function updateLines(now: number)
	local camera = workspace.CurrentCamera
	local size = camera.ViewportSize
	local strength = 0
	if State.inWater() then
		strength = Ease.smoothstep(38, 95, State.Speed)
	end
	local centre = size / 2
	local reach = math.max(size.X, size.Y) * 0.5
	for _, line in lines do
		local frame = line.frame
		if strength <= 0.01 then
			frame.BackgroundTransparency = 1
		else
			local travel = (line.offset + now * (0.8 + strength * 1.6)) % 1
			local distance = reach * (0.55 + 0.5 * travel)
			local dir = Vector2.new(math.cos(line.angle), math.sin(line.angle))
			local at = centre + dir * distance
			frame.Position = UDim2.fromOffset(at.X, at.Y)
			frame.Size = UDim2.fromOffset(line.length * (0.5 + strength), 2 + strength * 2)
			frame.Rotation = math.deg(line.angle)
			frame.BackgroundTransparency = 1 - strength * 0.55 * math.sin(travel * math.pi)
		end
	end
end

function HudController.Start()
	build() -- in Start: it waits for PlayerGui
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local inWater = State.inWater()
		meter.Visible = inWater
		depthFrame.Visible = true
		speedText.Text = if inWater then string.format("%d st/s", math.floor(State.Speed + 0.5)) else ""
		updateMeter(now)
		updateDepth()
		updateLines(now)
		updateFade()
	end)
end

return HudController
