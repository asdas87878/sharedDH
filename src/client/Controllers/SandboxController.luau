--!strict
-- The movement sandbox, client side (Studio only; docs/sandbox.md): for play-testing the ride, the jump and the camera
-- against the reference.
--   N: the tuning panel. Every number of the hop, the lock, Oxygen by land, crashes, props, the herd, the ride and the
--      camera, changed while playing (- and +, or type a value). A changed number turns yellow. "Copy changes" lists them, in the panel and in the Output, to paste
--      to Claude, who writes them into Config: nothing here outlives the play session.
--   V: the side view, square on to the way you are headed, to judge the arc.
--   R: back to the start of the lane, onto a fish.
--   The arc trace: a dot every 0.04 s of the flight, left in the water until the next jump.
--   After each jump, its numbers: time in the air, height, distance, the speed it came down at.
-- The switches (no fail, endless air) are the server's (SandboxService); the rest is local.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.Lib.State)

local SandboxController = {}

-- group, key, step
local TUNABLES: { { any } } = {
	{ "Jump", "Window", 0.1 },
	{ "Jump", "Warn", 0.1 },
	{ "Jump", "AutoGrab", 1 },
	{ "Jump", "MinFlight", 0.05 },
	{ "Jump", "Cooldown", 0.05 },
	{ "Jump", "InputGap", 0.05 },
	{ "Jump", "LaunchTime", 0.05 },
	{ "Jump", "BoostTime", 0.05 },
	{ "Jump", "Launch", 0.05 },
	{ "Jump", "FreeLaunch", 5 },
	{ "Jump", "Apex", 1 },
	{ "Jump", "Ceiling", 1 },
	{ "Jump", "SeatRoom", 1 },
	{ "Jump", "FloatTime", 0.1 },
	{ "Jump", "FloatRise", 1 },
	{ "Jump", "AirSpeed", 2 },
	{ "Jump", "Drop", 1 },
	{ "Jump", "DropCurve", 0.1 },
	{ "Jump", "DropSpeed", 2 },
	{ "Jump", "Tilt", 5 },
	{ "Jump", "TiltFrom", 0.1 },
	{ "Jump", "TiltTo", 0.1 },
	{ "Jump", "DropTilt", 2 },
	{ "Jump", "DropTiltTime", 0.05 },
	{ "Jump", "Bank", 2 },
	{ "Jump", "FloorClearance", 1 },
	{ "Jump", "GrabRange", 5 },
	{ "Jump", "GrabSpeed", 10 },
	{ "Jump", "ReelTime", 0.02 },
	{ "Jump", "ReelCurve", 0.1 },
	{ "Jump", "ReelMin", 0.01 },
	{ "Jump", "ReelMax", 0.05 },
	{ "Jump", "ReelSwoop", 0.1 },
	{ "Jump", "ReelFov", 1 },
	{ "Jump", "LandFov", 1 },
	{ "Jump", "LandFovTime", 0.05 },
	{ "Jump", "LandKick", 0.05 },
	{ "Jump", "LandKickRate", 1 },
	{ "Jump", "LandKickDamp", 0.05 },
	{ "Jump", "LandShake", 0.1 },
	{ "Jump", "LandShakeTime", 0.02 },
	{ "Jump", "LandShakeRate", 1 },
	{ "Jump", "LandShakeRoll", 0.2 },
	{ "Jump", "LandShakeAt", 5 },
	{ "Jump", "LandShakeBySpeed", 0.05 },
	{ "Jump", "ReelTip", 5 },
	{ "Jump", "ReelTurnEnd", 0.05 },
	{ "Jump", "ReelSitStart", 0.05 },
	{ "Jump", "ReelFovCurve", 0.1 },
	{ "Jump", "TrailEvery", 0.005 },
	{ "Jump", "TrailLife", 0.05 },
	{ "Jump", "RingRadius", 1 },
	{ "Jump", "RingGrow", 5 },
	{ "Jump", "RingFollow", 1 },
	{ "Jump", "RingSpin", 5 },
	{ "Jump", "RingFace", 0.05 },
	{ "Jump", "RingPreview", 0.05 },
	{ "Jump", "FlyGlow", 0.05 },
	{ "Jump", "PreviewGlow", 0.05 },
	{ "Jump", "GlowFade", 0.05 },
	{ "Jump", "AckTime", 0.1 },
	{ "Jump", "RefusedTime", 0.1 },
	{ "Jump", "Slack", 0.1 },
	{ "Jump", "LandSlack", 2 },
	{ "Jump", "CameraPitch", 2 },
	{ "Jump", "CameraZoom", 0.05 },
	{ "Lock", "Cone", 2 },
	{ "Lock", "AimRadius", 1 },
	{ "Lock", "MaxAngle", 5 },
	{ "Lock", "AngleWeight", 0.05 },
	{ "Lock", "DistanceWeight", 0.05 },
	{ "Lock", "LeftPenalty", 0.1 },
	{ "Lock", "Sticky", 0.05 },
	{ "Lock", "MinHold", 0.05 },
	{ "Lock", "KeepCone", 0.1 },
	{ "Lock", "FallbackRadius", 1 },
	{ "Lock", "Preview", 1 },
	-- Oxygen a second on a Common, land by land (the list Config.ZoneDrain)
	{ "ZoneDrain", 1, 0.5 },
	{ "ZoneDrain", 2, 1 },
	{ "ZoneDrain", 3, 2 },
	{ "ZoneDrain", 4, 5 },
	{ "ZoneDrain", 5, 20 },
	{ "ZoneDrain", 6, 50 },
	{ "ZoneDrain", 7, 100 },
	{ "ZoneDrain", 8, 500 },
	{ "ZoneDrain", 9, 1000 },
	{ "ZoneDrain", 10, 2000 },
	{ "Oxygen", "Refill", 0.05 },
	{ "Oxygen", "KeepUp", 0.5 },
	{ "Oxygen", "TierDrain", 0.05 },
	{ "Oxygen", "FreeDrain", 1 },
	{ "Oxygen", "FloatSpeed", 1 },
	{ "Oxygen", "SwimSpeed", 1 },
	{ "Oxygen", "DockRadius", 10 },
	{ "Oxygen", "DockWait", 0.5 },
	{ "Crash", "Slow", 0.05 },
	{ "Crash", "Recover", 0.1 },
	{ "Crash", "Cost", 0.01 },
	{ "Crash", "Floor", 1 },
	{ "Crash", "Cooldown", 0.1 },
	{ "Crash", "HeadOn", 0.05 },
	{ "Crash", "MinSpeed", 2 },
	{ "Crash", "Reach", 1 },
	{ "Crash", "Every", 0.05 },
	{ "Crash", "Kick", 0.05 },
	{ "Props", "MinLength", 1 },
	{ "Props", "Reach", 1 },
	{ "Props", "Topple", 2 },
	{ "Props", "MaxLoose", 5 },
	{ "Props", "Push", 2 },
	{ "Props", "Scatter", 1 },
	{ "Props", "Sink", 1 },
	{ "Props", "Spin", 10 },
	{ "Props", "KnockTime", 0.1 },
	{ "Props", "Rebuild", 1 },
	{ "Props", "RebuildTime", 0.1 },
	{ "Props", "RebuildStagger", 0.1 },
	{ "Props", "Slow", 0.05 },
	{ "Props", "Cost", 0.01 },
	{ "Props", "WildEvery", 0.1 },
	{ "Herd", "SpeedShare", 0.05 },
	{ "Herd", "RideHeight", 1 },
	{ "Herd", "RideHeightGain", 0.1 },
	{ "Herd", "RideHeightPitch", 5 },
	{ "Herd", "Ahead", 10 },
	{ "Herd", "ObstacleLook", 10 },
	{ "Herd", "ObstacleGap", 2 },
	{ "Herd", "ObstacleShift", 5 },
	{ "Herd", "WallGap", 1 },
	{ "Ride", "RampTime", 0.1 },
	{ "Ride", "Surge", 0.05 },
	{ "Ride", "SurgeTime", 0.1 },
	{ "Ride", "YawRate", 5 },
	{ "Ride", "TurnEase", 1 },
	{ "Ride", "Bank", 2 },
	{ "Ride", "BankEase", 1 },
	{ "Ride", "MaxPitch", 5 },
	{ "Ride", "LaneMargin", 5 },
	{ "Ride", "SlowDownTime", 0.1 },
	{ "Ride", "SeatHeight", 0.1 },
	{ "Ride", "FloorClearance", 1 },
	{ "Ride", "Ceiling", 1 },
	{ "Ride", "SpeedSlack", 0.1 },
	{ "Camera", "Fov", 2 },
	{ "Camera", "SpeedFov", 2 },
	{ "Camera", "SpeedFovFrom", 5 },
	{ "Camera", "SpeedFovTo", 5 },
	{ "Camera", "Distance", 1 },
	{ "Camera", "Height", 0.5 },
	{ "Camera", "FocusHeight", 0.05 },
	{ "Camera", "ArmHeight", 0.05 },
	{ "Camera", "FocusTime", 0.02 },
	{ "Camera", "TurnTime", 0.01 },
	{ "Camera", "ZoomTime", 0.05 },
	{ "Camera", "FovTime", 0.05 },
	{ "Camera", "AutoRecentre", 1 },
	{ "Camera", "Recentre", 0.1 },
	{ "Camera", "LookBack", 0.5 },
	{ "Camera", "AirRest", 1 },
	{ "Camera", "StickSensitivity", 0.2 },
	{ "Camera", "AirMouseLook", 1 },
	{ "Camera", "MouseSensitivity", 0.001 },
	{ "Camera", "TouchSensitivity", 0.001 },
	{ "Camera", "RestPitch", 2 },
	{ "Camera", "PitchFollow", 0.5 },
	{ "Camera", "AirPitchFollow", 0.5 },
	{ "Camera", "PitchMin", 5 },
	{ "Camera", "PitchMax", 5 },
	{ "Camera", "WallGap", 0.1 },
	{ "Camera", "WheelStep", 0.5 },
	{ "Camera", "ZoomMin", 1 },
	{ "Camera", "ZoomMax", 2 },
	{ "AimHud", "RefusedTime", 0.05 },
	{ "AimHud", "FollowRate", 2 },
	{ "AimHud", "PreviewTransparency", 0.05 },
	{ "AimHud", "PulsePeriod", 0.05 },
	{ "AimHud", "PulseWhiten", 0.05 },
	{ "AimHud", "PulseScale", 0.02 },
	{ "Net", "RangeSlack", 0.05 },
	{ "Switch", "HandBack", 0.1 },
	{ "Burst", "Count", 5 },
	{ "Burst", "Time", 0.1 },
	{ "Burst", "Reach", 1 },
	{ "Spawn", "PerThousand", 2 },
	{ "Spawn", "HeightMin", 2 },
	{ "Spawn", "HeightMax", 2 },
	{ "Spawn", "HeightFloor", 1 },
}

type Row = { Path: string, Group: string, Key: string, Step: number, Start: number, Box: TextBox }

local FONT = Enum.Font.GothamMedium
local DARK = Color3.fromRGB(18, 28, 44)
local MID = Color3.fromRGB(40, 58, 84)
local WHITE = Color3.new(1, 1, 1)
local CHANGED = Color3.fromRGB(255, 221, 51)
local TRACE_DOTS = 110

local rows: { Row } = {}
local panel: Frame
local tag: TextLabel
local stats: TextLabel
local output: TextBox
local flagButtons: { [string]: TextButton } = {}

local traceOn = true
local traceFolder: Folder
local dots: { Part } = {}
local dotIndex = 0
local dotAt = 0

-- the flight being measured
local measuring = false
local flightFrom = Vector3.zero
local flightAt = 0
local flightTop = 0
local flightSpeed = 0

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

local function text(props: { [string]: any }, parent: Instance, class: string?): any
	props.Font = FONT
	props.TextSize = props.TextSize or 13
	props.TextColor3 = props.TextColor3 or WHITE
	props.BorderSizePixel = 0
	return new(class or "TextLabel", props, parent)
end

local function valueOf(row: Row): number
	return (Config :: any)[row.Group][row.Key]
end

local function show(row: Row)
	local value = valueOf(row)
	row.Box.Text = string.format("%.3f", value):gsub("0+$", ""):gsub("%.$", "")
	row.Box.TextColor3 = if math.abs(value - row.Start) > 1e-6 then CHANGED else WHITE
end

local function apply(row: Row, value: number)
	value = math.floor(value * 1000 + 0.5) / 1000
	(Config :: any)[row.Group][row.Key] = value
	Config.refresh()
	Net.Sandbox:FireServer("Tune", row.Path, value)
	show(row)
end

local function changes(): string
	local lines = {}
	for _, row in rows do
		local value = valueOf(row)
		if math.abs(value - row.Start) > 1e-6 then
			table.insert(
				lines,
				string.format("Config.%s = %s -- was %s", row.Path, tostring(value), tostring(row.Start))
			)
		end
	end
	return if #lines > 0 then table.concat(lines, "\n") else "no numbers changed"
end

-- the switches: name -> read, write
local FLAGS: { { any } } = {
	{
		"Sandbox on",
		function()
			return workspace:GetAttribute("Sandbox") == true
		end,
		function(on: boolean)
			Net.Sandbox:FireServer("Flag", "On", on)
		end,
	},
	{
		"No fail (a sunk jump leaves you floating)",
		function()
			return workspace:GetAttribute("SandboxNoFail") == true
		end,
		function(on: boolean)
			Net.Sandbox:FireServer("Flag", "NoFail", on)
		end,
	},
	{
		"Endless air (off: Oxygen drains by land)",
		function()
			return workspace:GetAttribute("SandboxEndlessAir") == true
		end,
		function(on: boolean)
			Net.Sandbox:FireServer("Flag", "EndlessAir", on)
		end,
	},
	{
		"Side view (V)",
		function()
			return State.SideCam
		end,
		function(on: boolean)
			State.SideCam = on
		end,
	},
	{
		"Arc trace",
		function()
			return traceOn
		end,
		function(on: boolean)
			traceOn = on
		end,
	},
	{
		"Grab the locked fish for you when the window ends",
		function()
			return Config.Jump.AutoGrab > 0
		end,
		function(on: boolean)
			Config.Jump.AutoGrab = if on then 1 else 0
		end,
	},
}

local function showFlags()
	for _, flag in FLAGS do
		local button = flagButtons[flag[1]]
		if button then
			local on = flag[2]()
			button.Text = (if on then "[x]  " else "[  ]  ") .. flag[1]
			button.TextColor3 = if on then WHITE else Color3.fromRGB(150, 165, 185)
		end
	end
	tag.Text = if workspace:GetAttribute("Sandbox") == true
		then "SANDBOX    N numbers    V side view    R back to the start"
		else "sandbox off    N to open its panel"
end

local function build()
	local gui = new("ScreenGui", {
		Name = "Sandbox",
		ResetOnSpawn = false,
		DisplayOrder = 20,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, State.Player:WaitForChild("PlayerGui"))

	tag = text({
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.fromOffset(440, 22),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	}, gui)
	new("UIPadding", { PaddingLeft = UDim.new(0, 8) }, tag)
	stats = text({
		Position = UDim2.fromOffset(12, 34),
		Size = UDim2.fromOffset(440, 40),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = "jump to see its numbers here",
	}, gui)
	new("UIPadding", { PaddingLeft = UDim.new(0, 8) }, stats)

	panel = new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -40, 0, 50),
		Size = UDim2.new(0, 320, 1, -110),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Visible = false,
	}, gui)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, panel)
	text({
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 0, 22),
		BackgroundTransparency = 1,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Movement sandbox",
	}, panel)

	local y = 32
	for _, flag in FLAGS do
		local button = text({
			Position = UDim2.fromOffset(10, y),
			Size = UDim2.new(1, -20, 0, 22),
			BackgroundColor3 = MID,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = flag[1],
			AutoButtonColor = true,
		}, panel, "TextButton")
		new("UIPadding", { PaddingLeft = UDim.new(0, 8) }, button)
		button.Activated:Connect(function()
			flag[3](not flag[2]())
			task.delay(0.15, showFlags) -- the server's switches come back as attributes
			showFlags()
		end)
		flagButtons[flag[1]] = button
		y += 24
	end

	local copy = text({
		Position = UDim2.fromOffset(10, y + 4),
		Size = UDim2.new(0.5, -14, 0, 24),
		BackgroundColor3 = Color3.fromRGB(60, 120, 90),
		Text = "Copy changes",
	}, panel, "TextButton")
	local reset = text({
		Position = UDim2.new(0.5, 4, 0, y + 4),
		Size = UDim2.new(0.5, -14, 0, 24),
		BackgroundColor3 = Color3.fromRGB(120, 70, 60),
		Text = "Numbers back to start",
	}, panel, "TextButton")
	y += 34

	output = text({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -10),
		Size = UDim2.new(1, -20, 0, 120),
		BackgroundColor3 = Color3.fromRGB(8, 14, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		ClearTextOnFocus = false,
		MultiLine = true,
		TextEditable = false,
		TextSize = 12,
		Text = "Copy changes lists the changed numbers here: click in, Ctrl+A, Ctrl+C, and paste them to Claude.",
	}, panel, "TextBox")
	new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingTop = UDim.new(0, 4) }, output)

	local list = new("ScrollingFrame", {
		Position = UDim2.fromOffset(10, y),
		Size = UDim2.new(1, -20, 1, -y - 140),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, panel)
	new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, list)

	local order = 0
	local lastGroup = ""
	for _, tunable in TUNABLES do
		local group, key, step = tunable[1], tunable[2], tunable[3]
		local start = (Config :: any)[group][key]
		if type(start) == "number" then
			if group ~= lastGroup then
				lastGroup = group
				order += 1
				text({
					Size = UDim2.new(1, -8, 0, 20),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(140, 200, 255),
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = group,
					LayoutOrder = order,
				}, list)
			end
			order += 1
			local line =
				new("Frame", { Size = UDim2.new(1, -8, 0, 24), BackgroundTransparency = 1, LayoutOrder = order }, list)
			text({
				Size = UDim2.new(1, -132, 1, 0),
				BackgroundTransparency = 1,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = if type(key) == "number" then "land " .. key else key,
			}, line)
			local minus = text({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -104, 0, 0),
				Size = UDim2.fromOffset(24, 22),
				BackgroundColor3 = MID,
				Text = "-",
			}, line, "TextButton")
			local box = text({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -28, 0, 0),
				Size = UDim2.fromOffset(72, 22),
				BackgroundColor3 = Color3.fromRGB(8, 14, 24),
				ClearTextOnFocus = false,
				Text = "",
			}, line, "TextBox")
			local plus = text({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(24, 22),
				BackgroundColor3 = MID,
				Text = "+",
			}, line, "TextButton")
			local row: Row =
				{ Path = group .. "." .. key, Group = group, Key = key, Step = step, Start = start, Box = box }
			table.insert(rows, row)
			show(row)
			minus.Activated:Connect(function()
				apply(row, valueOf(row) - row.Step)
			end)
			plus.Activated:Connect(function()
				apply(row, valueOf(row) + row.Step)
			end)
			box.FocusLost:Connect(function()
				local typed = tonumber(box.Text)
				if typed then
					apply(row, typed)
				else
					show(row)
				end
			end)
		end
	end

	copy.Activated:Connect(function()
		local listed = changes()
		output.Text = listed
		print("[Sandbox] changed numbers:\n" .. listed)
	end)
	reset.Activated:Connect(function()
		for _, row in rows do
			if math.abs(valueOf(row) - row.Start) > 1e-6 then
				apply(row, row.Start)
			end
		end
	end)
	showFlags()
end

local function buildTrace()
	traceFolder = Instance.new("Folder")
	traceFolder.Name = "SandboxTrace"
	for _ = 1, TRACE_DOTS do
		local dot = Instance.new("Part")
		dot.Shape = Enum.PartType.Ball
		dot.Size = Vector3.new(0.7, 0.7, 0.7)
		dot.Anchored = true
		dot.CanCollide = false
		dot.CanQuery = false
		dot.CanTouch = false
		dot.CastShadow = false
		dot.Material = Enum.Material.Neon
		dot.Color = WHITE
		dot.Transparency = 1
		dot.Parent = traceFolder
		table.insert(dots, dot)
	end
	traceFolder.Parent = workspace.CurrentCamera
end

local function step()
	local _, root = State.character()
	if not root then
		return
	end
	local jumping = State.Mode == "Jumping"
	if jumping and not measuring then
		-- a jump begins: its numbers and its trace start again
		measuring = true
		flightFrom = root.Position
		flightAt = os.clock()
		flightTop = 0
		flightSpeed = 0
		dotIndex = 0
		dotAt = 0
		for _, dot in dots do
			dot.Transparency = 1
		end
	end
	if jumping then
		flightTop = math.max(flightTop, root.Position.Y - flightFrom.Y)
		flightSpeed = State.Speed
		if traceOn and os.clock() - dotAt >= 0.04 and dotIndex < TRACE_DOTS then
			dotAt = os.clock()
			dotIndex += 1
			local dot = dots[dotIndex]
			dot.Position = root.Position
			dot.Transparency = 0.1
		end
	elseif measuring then
		measuring = false
		local along = (root.Position - flightFrom) * Vector3.new(1, 0, 1)
		stats.Text = string.format(
			"last jump: %s   %.2f s in the air   %.1f studs up   %.0f studs along   came down at %.0f studs a second",
			if State.Mode == "Riding" then "landed" else "sank",
			os.clock() - flightAt,
			flightTop,
			along.Magnitude,
			flightSpeed
		)
	end
end

function SandboxController.Start()
	if not RunService:IsStudio() then
		return
	end
	build()
	buildTrace()
	for _, attribute in { "Sandbox", "SandboxNoFail", "SandboxEndlessAir" } do
		workspace:GetAttributeChangedSignal(attribute):Connect(showFlags)
	end
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == Enum.KeyCode.N then
			panel.Visible = not panel.Visible
		elseif workspace:GetAttribute("Sandbox") ~= true then
			return
		elseif input.KeyCode == Enum.KeyCode.V then
			State.SideCam = not State.SideCam
			showFlags()
		elseif input.KeyCode == Enum.KeyCode.R then
			Net.Sandbox:FireServer("Reset")
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return SandboxController
