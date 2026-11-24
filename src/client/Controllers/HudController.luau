--!strict
-- The dive's HUD (docs/design/ui.md, pass 3 for the places, pass 4 for the look): the reference's riding screen piece
-- for piece, in our build; every plate bold and themed by what it is for (UI.Kit's Themes). The pieces
-- are in Client.UI; this file makes the two screens, lays the pieces out for a phone or a keyboard, and feeds them
-- what the game knows each frame.
--   LandStrip   the ten lands across the top, your marker, the metres, your best
--   Rings       beside the rider, following them: the time left on this fish, and the tame
--   HopButton   lower right: the arrow turns over in the air; HOP and GRAB on a phone, the key's name on a keyboard
--   StatRows    your Oxygen (and coins, when the game has them)
--   Tags        the nearest wild fish: rarity, name, what each needs
--   Aim         in the hop: the aim, and the window as a ring
--   Slots       what you carry, with each creature's picture
--   Banners     a miss, the end of a dive, a catch, a new land
-- A fish too strong for you (Oxygen.StrainTime: a landing is never refused, the whole meter empties in a second and
-- the fish throws you off, unless you hop on first) is told four ways: the red plate on its tag before the hop; the ring red, bigger
-- and shaking from the landing, with "Too strong!" and what the fish needs under it; the same words under the empty
-- ring while you drown; and "TOO STRONG!" as the last words in place of "OUT OF AIR!".
-- Under them, on a screen of their own that covers the whole display: the speed lines and the edges closing in as
-- you drown (State.Vignette). Over them and every window, on a third screen: the black of a death (State.Fade: the
-- deaths'), so the HUD goes out and comes back with it (BLACK_ORDER).
-- For phones: nothing is made per frame, a label's text is set only when it changes, and text never changes size.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Archetypes = require(ReplicatedStorage.Shared.Archetypes)
local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Net = require(ReplicatedStorage.Shared.Net)
local Zones = require(ReplicatedStorage.Shared.Zones)
local Actions = require(script.Parent.Parent.Lib.Actions)
local State = require(script.Parent.Parent.Lib.State)

local UI = script.Parent.Parent.UI
local Aim = require(UI.Aim)
local Banners = require(UI.Banners)
local HopButton = require(UI.HopButton)
local HubButtons = require(UI.HubButtons)
local HubSigns = require(UI.HubSigns)
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
-- the narrowest the HUD may be laid out on, in its own units: a tall phone held upright scales by its height to a HUD
-- narrower than its hotbar, so its width caps the scale too (grade issue 4)
local SCALE_WIDTH = 420
local SHOULDER = Vector3.new(0, 1, 0) -- from the rider's middle to where the rings are level with
-- The server's word that a fish is too strong takes a moment to come; for this long after a landing the HUD judges it
-- itself, by the same rule (State.tooStrong), so the ring is red from the first frame
local STRAIN_GUESS = 0.3
local STRAIN_UNSAID = 0.6 -- still riding this long after the landing with no word from the server: the guess was wrong
-- The speed lines are on screen all the time you ride, so they are kept cheap: moved thirty times a second, half as
-- many on a phone, each line's turn set once, and its size written only when the speed's step changes
local LINES = 28
local LINES_ON_TOUCH = 14
local LINES_PERIOD = 1 / 30
-- The black of a death is drawn over the HUD and the dock's windows (the highest of them is 8: the Shop, the tank's
-- panel), under the kraken's dark (39) and the words of the fail (40: FailController), and under Studio's own panels
-- (20, 21). It was under the HUD, on RideHudFx: back on the dock the Shop and Index buttons, the plus buttons and the
-- full Oxygen came up bright on a screen still black (2026-11-23). Now whatever the HUD or the dock shows is under
-- the black until it lifts.
local BLACK_ORDER = 15

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
-- The meter: as the server last said (it drops in ticks, Config.Oxygen.Tick, each piece shown red on the ring); with
-- Tick 0 the old smooth drain, counted down between the server's updates (about ten a second)
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
local diveCaught = 0
local diveFrom = 0 -- how many were already carried as the dive began
local stripLand, stripAlong, stripMetres, stripName = 0, 0, 0, "The dock" -- what the land strip shows
local diveList: { State.Caught }? = nil -- the dive's catch at its longest (the server empties it at the dock)
-- the kinds caught since joining: a first catch of a kind says NEW! (until saves exist it is "new this session")
local kindsCaught: { [string]: boolean } = {}
local landSeen = 0 -- the deepest land of this dive so far (0: not in the water yet)
-- The end of the dive, kept until the words of the death that ended it are gone. Most dives end in a drowning, and
-- "GREAT DIVE!" came up on the dock while "OUT OF AIR!" was still fading with the black: two banners saying opposite
-- things, one over the other (the survey of 2026-11-16). Now one follows the other.
local endMetres = 0
local endBest = false
local endList: { State.Caught }? = nil
local endWaits = false
local bestMetres = 0
local bestLands = 0
local caughtCount = -1

-- the landing the rings last flashed for, and whether the fish of this ride is too strong (kept through the drowning
-- it ends in, for the words)
local mountedSeen = -math.huge
local strainRide = false
local strainNeeds = ""

local ringView: Rings.View = {
	Follow = false,
	X = 0,
	Y = 0,
	Wide = 0,
	High = 0,
	Fraction = 1,
	Amount = 0,
	Max = 1,
	RedAt = 0,
	Seconds = math.huge,
	Name = "",
	Tier = "",
	Note = "",
	NoteSub = "",
	Warn = false,
	Tame = nil,
	Ready = 1,
	Strained = false,
	Low = false,
	Kind = "",
	Endless = false,
}

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
		-- the abyss: red-black, as the miss's words are
		local edge = Kit.new("Frame", { BackgroundColor3 = Color3.fromRGB(34, 0, 12), BorderSizePixel = 0 }, fx)
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

	-- the black of a death: over the HUD and the windows (BLACK_ORDER)
	local over = Kit.new("ScreenGui", {
		Name = "RideBlack",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.None,
		DisplayOrder = BLACK_ORDER,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)
	fade = Kit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, over)

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
	HubButtons.build(root)
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
	local width = if camera then camera.ViewportSize.X else SCALE_WIDTH * 2
	local wanted = math.clamp(math.min(height / SCALE_HEIGHT, width / SCALE_WIDTH), 1, SCALE_MAX)
	local onTouch = Kit.touch()
	-- (the hotbar fits itself to the width, which can change without the scale: grade issue 4)
	Slots.fit(width / wanted)
	if wanted == hudScale and onTouch == touch then
		return
	end
	hudScale = wanted
	touch = onTouch
	scale.Scale = wanted
	root.Size = UDim2.fromScale(1 / wanted, 1 / wanted)
	LandStrip.place(onTouch)
	StatRows.place(onTouch)
	HubButtons.place(onTouch)
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
	-- (a hop leaves the fish backward a moment: the depth and the marker stay where they were, never going back)
	if mode ~= "Jumping" or metres >= stripMetres then
		stripLand, stripAlong, stripMetres = land, along, if zone then metres else 0
		stripName = if zone then zone.Name else "The dock"
	end
	LandStrip.update(stripLand, stripName, stripAlong, stripMetres, bestLands, bestMetres)
	-- a land deeper than any yet this dive: its name comes up (not the land the dive starts in)
	if inWater and zone then
		if landSeen == 0 then
			landSeen = land
		elseif land > landSeen then
			landSeen = land
			-- the strip plays its own intro instead, unless it is off (LandStrip.introLook, task l1)
			if LandStrip.introLook() == 0 then
				Banners.land(land, zone.Name, Kit.Lands[math.clamp(land, 1, #Kit.Lands)])
			end
		end
	elseif mode == "Dock" then
		landSeen = 0
	end
	-- drowning with the meter empty (not a missed hop, where there may be air left)
	local outOfAir = mode == "Drowning" and State.Player:GetAttribute("DeathQuick") ~= true

	-- the rings: the meter as seconds on the fish under us, at the rate the server counts (its "Drain"). The server
	-- sends the meter about ten times a second; between those we count down ourselves
	local fish = State.Fish
	local kind = fish and Config.FishById[fish:GetAttribute("FishType") :: string]
	-- a landing: the rings flash, and whether this fish is too strong is asked again
	if State.MountedAt ~= mountedSeen then
		mountedSeen = State.MountedAt
		strainRide = false
		Rings.landed(now)
	end
	local strained = false
	if mode == "Riding" and fish and kind and not endlessAir then
		strained = State.Strained or (now - State.MountedAt < STRAIN_GUESS and State.tooStrong(fish))
		if strained and not strainRide then
			strainRide = true
			strainNeeds = "needs " .. Config.wholeNumber(Config.requiredOfModel(fish) or 0) -- (this fish's own: task e1)
		elseif strainRide and not State.Strained and now - State.MountedAt > STRAIN_UNSAID then
			-- our own guess, and the server never said so: it is not too strong
			strainRide = false
		end
	elseif mode ~= "Riding" and mode ~= "Drowning" then
		strainRide = false
	end
	local drain = 0
	if strained then
		-- (this ride's own strain time, from the server: shorter for each red fish in a row, Oxygen.RedShrink)
		local seconds = State.Player:GetAttribute("StrainSeconds")
		drain = max / math.max(if type(seconds) == "number" then seconds else Config.Oxygen.StrainTime, 0.01)
	elseif mode == "Riding" and kind then
		local sent = State.Player:GetAttribute("Drain")
		drain = if type(sent) == "number" and sent > 0
			then sent
			else Config.drainFor((if fish then Config.requiredOfModel(fish) else nil) or 1, kind, max)
	elseif mode == "Free" then
		drain = Config.Oxygen.FreeDrain
	end
	if oxygen ~= heardOxygen or endlessAir then
		-- a drop: its piece goes red on the ring and fades (the server's OxygenTick says the same; Rings.lose keeps one)
		if heardOxygen >= 0 and oxygen < heardOxygen and not endlessAir then
			Rings.lose(now, heardOxygen, oxygen)
		end
		heardOxygen = oxygen
		meter = oxygen
	elseif Config.Oxygen.Tick > 0 then
		meter = oxygen -- (in ticks: nothing goes between them)
	else
		-- never more than a third of a second ahead of what the server last said
		meter = math.max(meter - drain * dt, oxygen - drain * 0.33, 0)
	end
	local seconds = math.huge
	local view = ringView
	-- the rings follow the rider on the screen, as the reference's follow the animal
	local camera = workspace.CurrentCamera
	local size = root.AbsoluteSize
	view.Wide = size.X / hudScale
	view.High = size.Y / hudScale
	view.Follow = false
	if rootPart and camera then
		local point = camera:WorldToScreenPoint(rootPart.Position + SHOULDER)
		if point.Z > 0 then
			local origin = root.AbsolutePosition
			view.Follow = true
			view.X = (point.X - origin.X) / hudScale
			view.Y = (point.Y - origin.Y) / hudScale
		end
	end
	view.Name = ""
	view.Tier = ""
	view.Note = ""
	view.NoteSub = ""
	view.Warn = false
	view.Tame = nil
	view.Ready = 1
	view.Strained = false
	view.Low = false
	view.Kind = ""
	view.Endless = endlessAir
	view.Max = max
	view.Amount = meter
	view.RedAt = max * Config.angryAt(if mode == "Riding" then kind else nil)
	if mode == "Riding" and kind then
		seconds = meter / math.max(drain, 0.001)
		view.Fraction = meter / max
		view.Seconds = seconds
		view.Name = kind.Name
		view.Tier = kind.Tier
		view.Tame = State.Tame
		view.Ready = 1 - math.clamp((State.JumpReadyAt - now) / math.max(Config.Jump.Cooldown, 0.01), 0, 1)
		view.Strained = strained
		-- the meter's low part: the ring is red, the button calls for the hop, and the fish under us is angry
		-- (one threshold for all three, Oxygen.AngryAt: Config.low is what the server asks too)
		view.Low = Config.low(meter, max, kind) -- (a Tank's low part starts lower)
		view.Kind = if Config.ArchetypeFeel.Tags > 0 then Archetypes.rich(kind) else ""
		if strainRide then
			view.Note = "Too strong!"
			view.NoteSub = strainNeeds
			view.Warn = true
		end
		Rings.update(now, view)
	elseif mode == "Free" then
		-- off a fish and not in a hop: the meter is the air you have left to float on, and the ring says so
		view.Fraction = meter / max
		view.Seconds = meter / math.max(drain, 0.001)
		view.Note = "Floating"
		Rings.update(now, view)
	elseif outOfAir and State.FadeText == "" then
		-- out of air (run out on a fish, or thrown off one too strong): the ring stays up, empty and red, so the
		-- reason is on the screen at once; it goes when the words come up over the middle. The Oxygen row at the
		-- corner is the most you can carry, not what is left, so it can't say this
		view.Fraction = 0
		view.Amount = 0
		view.Seconds = 0
		view.Note = if strainRide then "Too strong!" else "Out of air"
		view.NoteSub = if strainRide then strainNeeds else ""
		view.Warn = true
		view.Endless = false
		Rings.update(now, view)
	else
		Rings.hide(now)
	end

	local hot = mode == "Riding" and kind ~= nil and Config.low(meter, max, kind) and not endlessAir
	StatRows.update(max, State.Player:GetAttribute("Coins") :: number?, outOfAir, hot, mode == "Dock")
	HubButtons.update(mode == "Dock")

	-- the hop: the button, the aim, the window
	local target = State.JumpTarget
	local hopping = mode == "Jumping"
	if playing then
		local press = if not hopping then "hop" elseif target and not State.Reeling then "grab" else "off"
		HopButton.update(press, hot)
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
	local caught = State.Caught
	local count = if caught then #caught else -2
	if count ~= caughtCount then
		caughtCount = count
		Slots.update(caught)
		-- (the most carried this dive, for the words at its end: the server empties the list as it puts us on the dock)
		-- (what was already carried as the dive began isn't this dive's)
		if caught and count >= diveCaught and count > diveFrom then
			diveCaught = count
			diveList = table.move(caught, diveFrom + 1, count, 1, {})
		end
	end

	sinceJumpCheck += dt
	if sinceJumpCheck >= 0.25 then
		sinceJumpCheck = 0
		hideRobloxJump(touch and playing)
		endlessAir = RunService:IsStudio()
			and workspace:GetAttribute("Sandbox") == true
			and workspace:GetAttribute("SandboxEndlessAir") == true
	end

	-- the end of a dive comes up once the death's own words are gone (and not at all if we are diving again)
	if endWaits then
		if mode ~= "Dock" then
			endWaits = false
		elseif State.FadeText == "" and State.Fade <= 0.02 then
			endWaits = false
			Banners.greatDive(endMetres, endBest, endList)
		end
	end
	-- the last words: thrown off a fish too strong says so, in place of "OUT OF AIR!"
	Banners.miss(if State.FadeText ~= "" and strainRide and outOfAir then "TOO STRONG!" else State.FadeText, State.Fade)
	updateFx(now)
end

function HudController.Start()
	build() -- in Start: it waits for PlayerGui
	layout()
	UserInputService.LastInputTypeChanged:Connect(layout)
	workspace:GetAttributeChangedSignal("HudTouch"):Connect(layout) -- Studio: see Kit.touch
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
				local isBest = diveMetres > bestMetres and bestMetres > 0 -- (the first dive of all is no record)
				if diveMetres > bestMetres then
					bestMetres = diveMetres
					bestLands = diveLands
				end
				endMetres = diveMetres
				endBest = isBest
				endList = diveList
				endWaits = true
			end
			diveMetres = 0
			diveLands = 0
			diveCaught = 0
			diveList = nil
		elseif old == "Dock" and mode ~= "Dock" then
			diveFrom = if State.Caught then #State.Caught else 0
		end
	end)
	-- a tame: the banner, with what this very fish earns in a tank (its size and colour count: the fish under us
	-- carries them) and whether it is the first of its kind
	State.Tamed.Event:Connect(function(fishId: string)
		local kind = Config.FishById[fishId]
		local fish = State.Fish
		local earns: number? = nil
		if kind and fish and fish:GetAttribute("FishType") == fishId then
			local size, variant = fish:GetAttribute("SizeTier"), fish:GetAttribute("Variant")
			earns = Config.incomeOf(
				kind,
				if type(size) == "string" then size else "Normal",
				if type(variant) == "string" then variant else ""
			)
		end
		local isNew = not kindsCaught[fishId]
		kindsCaught[fishId] = true
		if isNew then
			HubButtons.mark(true)
		end
		Banners.caught(fishId, earns, isNew)
	end)
	HubSigns.start()
	-- the server's word of a tick (Oxygen.Tick) or the red zone's drop (RedDrop): that piece goes red on the ring.
	-- The red zone's drop comes with the landing's refill, so the Oxygen attribute alone would show a rise
	Net.Ride.OnClientEvent:Connect(function(what: string, lost: any, oxygen: any)
		if what == "OxygenTick" and type(lost) == "number" and type(oxygen) == "number" and not endlessAir then
			Rings.lose(os.clock(), oxygen + lost, oxygen)
		end
	end)

	RunService.RenderStepped:Connect(update)
end

return HudController
