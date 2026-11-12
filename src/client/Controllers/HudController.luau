--!strict
-- The dive's HUD (docs/design/ui.md, pass 3): the reference's riding screen piece for piece, in our build. The pieces
-- are in Client.UI; this file makes the two screens, lays the pieces out for a phone or a keyboard, and feeds them
-- what the game knows each frame.
--   LandStrip   the ten lands across the top, your marker, the metres, your best
--   Rings       beside the rider: the seconds left on this fish, and the tame
--   HopButton   lower right: the arrow turns over in the air; HOP and GRAB on a phone, the key's name on a keyboard
--   StatRows    your Oxygen (and coins, when the game has them)
--   Tags        the nearest wild fish: rarity, name, what each needs
--   Aim         in the hop: the aim, and the window as a ring
--   Slots       what you carry (when the game has taming)
--   Banners     a miss, the end of a dive, a catch
-- Under them, on a screen of their own that covers the whole display: the speed lines, the edges closing in as you
-- drown, and the drowning's black (State.Vignette, State.Fade: DeathController's).
-- For phones: nothing is made per frame, a label's text is set only when it changes, and text never changes size.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Zones = require(ReplicatedStorage.Shared.Zones)
local Actions = require(script.Parent.Parent.Lib.Actions)
local State = require(script.Parent.Parent.Lib.State)

local UI = script.Parent.Parent.UI
local Aim = require(UI.Aim)
local Banners = require(UI.Banners)
local HopButton = require(UI.HopButton)
local Kit = require(UI.Kit)
local LandStrip = require(UI.LandStrip)
local Rings = require(UI.Rings)
local Slots = require(UI.Slots)
local StatRows = require(UI.StatRows)
local Tags = require(UI.Tags)

local HudController = {}

-- The HUD is drawn once at phone size (a screen 390 high is scale 1); bigger screens scale it up by their height, less
-- than in proportion, so a desktop gets a smaller HUD against its screen than a phone does
local SCALE_HEIGHT = 560
local SCALE_MAX = 2.2
local HOT_SECONDS = 1 -- under this on a fish, the ring and the button call for the hop
-- The speed lines are on screen all the time you ride, so they are kept cheap: moved thirty times a second, half as
-- many on a phone, each line's turn set once, and its size written only when the speed's step changes
local LINES = 28
local LINES_ON_TOUCH = 14
local LINES_PERIOD = 1 / 30

local root: Frame
local scale: UIScale
local fade: Frame
local edges: { Frame } = {}
local lines: { { frame: Frame, angle: number, offset: number, length: number } } = {}

local touch = false
local hudScale = 0
local linesAt = 0
local linesShown = 0
local linesStep = -1

-- this dive, and the best of this session (until the game saves a best)
-- The meter, counted down between the server's updates (about ten a second) so the ring turns smoothly
local heardOxygen = -1
local meter = 0

-- Roblox's own jump button on a touch screen: hidden while ours shows, given back on the dock
local playerGui: Instance
local robloxJump: GuiObject? = nil
local hidJump = false
local sinceJumpCheck = math.huge

-- The Studio sandbox's endless air: the server then doesn't drain the meter, so the ring must not count down either
local endlessAir = false

local diveMetres = 0
local diveLands = 0
local bestMetres = 0
local bestLands = 0
local caughtCount = -1

-- A value another controller may publish on State before this file knows its name is typed (docs/design/ui.md, "Open
-- points"): nil until it exists, and the HUD then falls back or hides the piece
local published: { [string]: any } = State :: any

local function build()
	playerGui = State.Player:WaitForChild("PlayerGui")
	local fx = Kit.new("ScreenGui", {
		Name = "RideHudFx",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.None,
		DisplayOrder = 4,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)

	-- speed lines, behind everything
	local linesFrame = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, fx)
	local rng = Random.new(7)
	for i = 1, LINES do
		local angle = (i / LINES) * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local frame = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			BackgroundTransparency = 1,
			Rotation = math.deg(angle),
		}, linesFrame)
		table.insert(lines, {
			frame = frame,
			angle = angle,
			offset = rng:NextNumber(),
			length = rng:NextNumber(90, 220),
		})
	end

	-- the grace vignette: four edges closing in
	for i = 1, 4 do
		local edge = Kit.new("Frame", { BackgroundColor3 = Color3.fromRGB(10, 0, 20), BorderSizePixel = 0 }, fx)
		local gradient = Kit.new("UIGradient", { Transparency = NumberSequence.new(0, 1) }, edge)
		gradient.Rotation = ({ 90, 270, 0, 180 })[i]
		edge.AnchorPoint = ({ Vector2.new(0, 0), Vector2.new(0, 1), Vector2.new(0, 0), Vector2.new(1, 0) })[i]
		edge.Position = ({ UDim2.fromScale(0, 0), UDim2.fromScale(0, 1), UDim2.fromScale(0, 0), UDim2.fromScale(1, 0) })[i]
		edge.Visible = false
		table.insert(edges, edge)
	end

	-- the tags over wild fish: on this screen, whose points are the camera's own, and under the black
	local tagLayer =
		Kit.new("Frame", { Name = "Tags", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5 }, fx)
	Tags.build(tagLayer)

	-- the drowning's black
	fade = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 10,
	}, fx)

	-- the HUD itself, kept clear of a phone's notch
	local gui = Kit.new("ScreenGui", {
		Name = "RideHud",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		DisplayOrder = 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)
	root = Kit.new("Frame", { Name = "Root", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui)
	scale = Kit.new("UIScale", {}, root)

	LandStrip.build(root)
	StatRows.build(root)
	Slots.build(root)
	Rings.build(root)
	Aim.build(root)
	HopButton.build(root, function()
		if State.inWater() and not State.dying() then
			Actions.jump()
		end
	end)
	Banners.build(root)
end

-- The scale for this screen, and the phone or the keyboard layout
local function layout()
	local camera = workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else SCALE_HEIGHT
	local wanted = math.clamp(height / SCALE_HEIGHT, 1, SCALE_MAX)
	local onTouch = Kit.touch()
	if wanted == hudScale and onTouch == touch then
		return
	end
	hudScale = wanted
	touch = onTouch
	scale.Scale = wanted
	root.Size = UDim2.fromScale(1 / wanted, 1 / wanted)
	LandStrip.place(onTouch)
	StatRows.place(onTouch)
	Slots.place(onTouch)
	Rings.place(onTouch)
	HopButton.place(onTouch)
	Tags.scale(wanted)
end

-- Our button does the hop on a phone, so Roblox's own jump button would be a second one beside it
local function hideRobloxJump(hide: boolean)
	local button = robloxJump
	if not button or button.Parent == nil then
		local touchGui = playerGui:FindFirstChild("TouchGui")
		local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
		local found = frame and frame:FindFirstChild("JumpButton")
		button = if found and found:IsA("GuiObject") then found else nil
		robloxJump = button
	end
	if not button then
		return
	end
	if hide then
		if button.Visible then
			button.Visible = false
			hidJump = true
		end
	elseif hidJump then
		button.Visible = true
		hidJump = false
	end
end

local function updateFx(now: number)
	fade.BackgroundTransparency = 1 - State.Fade

	-- the screen closes in as you drown
	local closing = State.Vignette
	for i, edge in edges do
		edge.Visible = closing > 0
		if closing > 0 then
			local amount = 0.12 + 0.3 * closing
			edge.Size = if i <= 2 then UDim2.fromScale(1, amount) else UDim2.fromScale(amount, 1)
		end
	end

	if now - linesAt < LINES_PERIOD then
		return
	end
	linesAt = now
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local strength = 0
	if State.inWater() then
		strength = Ease.smoothstep(38, 95, State.Speed)
	end
	local wanted = if strength <= 0.01 then 0 elseif touch then LINES_ON_TOUCH else LINES
	-- lines no longer wanted go clear once, not every frame
	for i = wanted + 1, linesShown do
		lines[i].frame.BackgroundTransparency = 1
	end
	local more = wanted > linesShown -- lines coming back have no size yet
	linesShown = wanted
	if wanted == 0 then
		return
	end
	local size = camera.ViewportSize
	local centre = size / 2
	local reach = math.max(size.X, size.Y) * 0.5
	local step = math.floor(strength * 10 + 0.5)
	local resize = more or step ~= linesStep
	linesStep = step
	for i = 1, wanted do
		local line = lines[i]
		local frame = line.frame
		local travel = (line.offset + now * (0.8 + strength * 1.6)) % 1
		local distance = reach * (0.55 + 0.5 * travel)
		local at = centre + Vector2.new(math.cos(line.angle), math.sin(line.angle)) * distance
		frame.Position = UDim2.fromOffset(at.X, at.Y)
		if resize then
			frame.Size = UDim2.fromOffset(line.length * (0.5 + step / 10), 2 + step / 5)
		end
		frame.BackgroundTransparency = 1 - strength * 0.55 * math.sin(travel * math.pi)
	end
end

local function update(dt: number)
	local now = os.clock()
	local mode = State.Mode
	local inWater = State.inWater()
	local playing = inWater and not State.dying()
	local oxygen = (State.Player:GetAttribute("Oxygen") :: number?) or 0
	local max = math.max((State.Player:GetAttribute("MaxOxygen") :: number?) or Config.Oxygen.StartMax, 1)

	-- where we are
	local _, rootPart = State.character()
	local zone: Zones.Zone? = nil
	local along, metres = 0, 0
	if rootPart then
		zone, along, metres = Zones.locate(State.Zones, rootPart.Position)
	end
	local land = if zone then zone.Index else 0
	if inWater and zone and metres > diveMetres then
		diveMetres = metres
		diveLands = zone.Index - 1 + along
	end
	LandStrip.update(
		land,
		if zone then zone.Name else "The dock",
		along,
		if zone then metres else 0,
		bestLands,
		bestMetres
	)
	-- drowning with the meter empty (not a missed hop, where there may be air left)
	local outOfAir = mode == "Drowning" and State.Player:GetAttribute("DeathQuick") ~= true
	StatRows.update(max, State.Player:GetAttribute("Coins") :: number?, outOfAir)

	-- the rings: the meter as seconds on the fish under us, at the rate the server counts (its "Drain"). The server
	-- sends the meter about ten times a second; between those we count down ourselves
	local fish = State.Fish
	local kind = fish and Config.FishById[fish:GetAttribute("FishType") :: string]
	local drain = 0
	if mode == "Riding" and kind then
		local sent = State.Player:GetAttribute("Drain")
		drain = if type(sent) == "number" and sent > 0 then sent else Config.drain(math.max(land, 1), kind.Tier)
	elseif mode == "Free" then
		drain = Config.Oxygen.FreeDrain
	end
	if oxygen ~= heardOxygen or endlessAir then
		heardOxygen = oxygen
		meter = oxygen
	else
		-- never more than a third of a second ahead of what the server last said
		meter = math.max(meter - drain * dt, oxygen - drain * 0.33, 0)
	end
	local seconds = math.huge
	if mode == "Riding" and kind then
		seconds = meter / math.max(drain, 0.001)
		Rings.update(now, meter / max, seconds, kind.Name, kind.Tier, published.Tame, endlessAir)
	elseif mode == "Free" then
		-- off a fish and not in a hop: the meter is the air you have left to float on, and the ring says so
		Rings.update(now, meter / max, meter / math.max(drain, 0.001), "Floating", "", nil, endlessAir)
	elseif outOfAir and State.FadeText == "" then
		-- out of air (run out on a fish, or thrown off one too strong): the ring stays up, empty and red, so the
		-- reason is on the screen at once; it goes when the words come up over the middle. The Oxygen row at the
		-- corner is the most you can carry, not what is left, so it can't say this
		Rings.update(now, 0, 0, "Out of air", "", nil, false)
	else
		Rings.hide()
	end

	-- the hop: the button, the aim, the window
	local target = State.JumpTarget
	local hopping = mode == "Jumping"
	if playing then
		local press = if not hopping then "hop" elseif target and not State.Reeling then "grab" else "off"
		HopButton.update(press, mode == "Riding" and seconds < HOT_SECONDS and not endlessAir)
	else
		HopButton.hide()
	end
	if hopping and not State.Reeling then
		Aim.update(now, State.WindowLeft, target ~= nil, now - State.NoTargetAt < Config.AimHud.RefusedTime)
	else
		Aim.hide()
	end

	if playing then
		Tags.update(dt, State.Zones, max, fish, target, hopping)
	else
		Tags.hide()
	end

	-- what we carry: only looked at when its length changes
	local caught = published.Caught
	local count = if type(caught) == "table" then #caught else -2
	if count ~= caughtCount then
		caughtCount = count
		Slots.update(if count >= 0 then caught else nil)
	end

	sinceJumpCheck += dt
	if sinceJumpCheck >= 0.25 then
		sinceJumpCheck = 0
		hideRobloxJump(touch and playing)
		endlessAir = RunService:IsStudio()
			and workspace:GetAttribute("Sandbox") == true
			and workspace:GetAttribute("SandboxEndlessAir") == true
	end

	Banners.miss(State.FadeText, State.Fade)
	updateFx(now)
end

function HudController.Start()
	build() -- in Start: it waits for PlayerGui
	layout()
	UserInputService.LastInputTypeChanged:Connect(layout)
	local watched: RBXScriptConnection? = nil
	local function watch()
		if watched then
			watched:Disconnect()
		end
		local camera = workspace.CurrentCamera
		if camera then
			watched = camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
		end
		layout()
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watch)
	watch()

	-- back on the dock after a dive: how deep it went
	State.ModeChanged.Event:Connect(function(mode: string, old: string)
		if mode == "Dock" and old ~= "Dock" then
			if diveMetres >= 1 then
				local isBest = diveMetres > bestMetres
				if isBest then
					bestMetres = diveMetres
					bestLands = diveLands
				end
				Banners.greatDive(diveMetres, isBest)
			end
			diveMetres = 0
			diveLands = 0
		end
	end)
	local tamed = published.Tamed
	if typeof(tamed) == "Instance" and tamed:IsA("BindableEvent") then
		tamed.Event:Connect(Banners.caught)
	end

	RunService.RenderStepped:Connect(update)
end

return HudController
