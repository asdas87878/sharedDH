--!strict
-- What a fish does when your Oxygen hits 0 on it (Config.Fail; Hugo, 2026-11-19, task e1: "as soon as it hits 0
-- either getting eaten or thrown off. Be creative for fishes and what they would do"). The server picks the outcome
-- (Config.failOf), holds the rider on the fish in the "Failing" state and tells every client (Fx "Fail", player, fish,
-- kind); this plays it on every client, so friends see it too:
--   on the rider's own machine (it owns the fish and the character) the fish's root is moved along the outcome's
--   path, its swim and turn switched off meanwhile, and the camera given a shot (State.DeathCam, as the drown's);
--   on every machine the rider is slid about on the saddle (the ride weld's C0, set the same everywhere), hidden once
--   in a mouth, and the outcome's props shown (an angler's lure, a kraken's arms), local only, under the camera.
-- A "Throw" outcome then ends in the throw and the drown (DeathController); a "Taken" one is the fail itself: the jaws
-- close the screen (Chomp, Gulp) and it fades to the fail screen (State.Fade and FadeText; DeathController lifts the
-- black at the dock). Stand-ins for the partner's animations: they can read the player's FailKind attribute (and
-- Config.Fail.Outcomes[kind].Hook) and play the real thing; the sound is a placeholder from Lib/Fx.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Net = require(ReplicatedStorage.Shared.Net)
local Course = require(script.Parent.Parent.Lib.Course)
local Fx = require(script.Parent.Parent.Lib.Fx)
local Shake = require(script.Parent.Parent.Lib.Shake)
local State = require(script.Parent.Parent.Lib.State)

local FailController = {}

type Def = { Time: number, End: string, Text: string, Sound: string, Hook: string }

type Fail = {
	Kind: string,
	Def: Def,
	Player: Player,
	Mine: boolean,
	Start: number, -- os.clock() it began here
	Fish: Model,
	FishRoot: BasePart,
	From: CFrame, -- the fish's root as it began
	Speed: number, -- and its speed then
	Length: number,
	Height: number,
	Width: number,
	Saddle: CFrame, -- the rider's place on the fish (the weld's C0 as it began)
	Weld: Weld?,
	Character: Model?,
	CamFrom: Vector3,
	FloorY: number?,
	Hidden: { [Instance]: number }, -- parts and decals we made unseen, and their own transparency
	Props: { Instance }, -- what we made for it (the lure, the arms), local only
	Paused: { Constraint }, -- the fish's swim and turn, off while we move it
	Driving: boolean,
	Bit: boolean, -- the bite, the slam or the splash has happened (once)
	Jaws: ScreenGui?,
}

local fails: { [Player]: Fail } = {}

local TAU = math.pi * 2

local function rootOf(model: Model?): BasePart?
	local root = model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
	return if root and root:IsA("BasePart") then root else nil
end

local function flat(v: Vector3): Vector3
	local f = v * Vector3.new(1, 0, 1)
	return if f.Magnitude > 0.01 then f.Unit else Vector3.new(0, 0, -1)
end

-- how far the fish has gone since it began: its speed, dying away (rate k a second)
local function travel(f: Fail, t: number, k: number): number
	return f.Speed * (1 - math.exp(-k * t)) / k
end

-- the fish's start frame carried forward along its old heading
local function carried(f: Fail, t: number, k: number): CFrame
	return f.From + f.From.LookVector * travel(f, t, k)
end

local function bump(a: number, b: number, t: number): number
	-- 0 at a, 1 at the middle, 0 at b
	if t <= a or t >= b then
		return 0
	end
	return math.sin(math.pi * (t - a) / (b - a))
end

----------------------------------------------------------------------------------------------------------------------
-- The outcomes. Each gives, at `t` seconds in, the fish's root (world) and where the rider is (world, nil: on the
-- saddle), and whether the rider is out of sight. Lengths are in the fish's own size, so a giant's are bigger.
type Frame = { Fish: CFrame, Rider: CFrame?, Hide: boolean, Focus: Vector3? }

local OUTCOMES: { [string]: (f: Fail, t: number) -> Frame } = {}

-- turns on you: it rears, you are tossed up off its back, it comes round and its mouth meets you, snap, a shake
OUTCOMES.Chomp = function(f, t)
	local L, H = f.Length, f.Height
	local base = carried(f, t, 3)
	local seat = base * f.Saddle
	-- the rider: up off the back in an arc, tumbling, and hanging there
	local rise = Ease.outQuad(math.clamp(t / 0.45, 0, 1))
	local riderAt = seat.Position + Vector3.new(0, rise * (H * 0.5 + 6), 0) - f.From.LookVector * rise * L * 0.1
	local tumble = CFrame.Angles(-rise * math.rad(200), 0, rise * math.rad(30))
	local rider = CFrame.new(riderAt) * f.From.Rotation * tumble
	-- the fish: nose up as it rears, then round to face the rider, lunging so its mouth meets them at the bite
	local rear = bump(0, 0.55, t) * math.rad(35)
	local turn = math.pi * Ease.smoothstep(0.12, 0.72, t)
	local frame = base * CFrame.Angles(0, turn, 0) * CFrame.Angles(rear, 0, 0)
	local lunge = Ease.smoothstep(0.45, 0.8, t)
	if lunge > 0 then
		local look = (riderAt - frame.Position)
		local aim = if look.Magnitude > 0.1 then look.Unit else frame.LookVector
		local mouthTo = riderAt - aim * L * 0.5
		local at = frame.Position:Lerp(mouthTo, lunge)
		local toward = CFrame.lookAt(at, at + frame.LookVector:Lerp(aim, lunge))
		frame = toward
	end
	if t >= 0.8 then
		-- shut: it shakes its head and swims on with you inside
		local after = t - 0.8
		local shake = math.sin(after * 26) * math.rad(18) * math.exp(-after * 3)
		frame = frame + frame.LookVector * after * f.Speed * 0.25
		frame = frame * CFrame.Angles(0, shake, shake * 0.5)
		rider = frame * CFrame.new(0, 0, -L * 0.35)
	end
	return { Fish = frame, Rider = rider, Hide = t >= 0.8, Focus = riderAt }
end

-- the lure flares and draws the eye; then the mouth comes up under you and swallows you
local function lurePlace(fish: CFrame, f: Fail): CFrame
	return fish * CFrame.new(0, f.Height * 0.6 + 1.5, -f.Length * 0.62)
end

OUTCOMES.Gulp = function(f, t)
	local L, H = f.Length, f.Height
	local base = carried(f, t, 2.5)
	local hover = math.sin(t * 3) * 0.6
	local tilt = math.rad(12) * Ease.smoothstep(0, 0.6, t) - math.rad(30) * bump(0.8, 1.25, t)
	local frame = base * CFrame.new(0, hover, 0) * CFrame.Angles(tilt, 0, 0)
	-- the rider leans to the lure, then slides over the head and down into the mouth
	local seat = frame * f.Saddle
	local mouth = frame * CFrame.new(0, -H * 0.1, -L * 0.5)
	local draw = Ease.smoothstep(0.15, 0.8, t) * 0.25
	local slide = Ease.smoothstep(0.8, 1.05, t)
	local over = frame * CFrame.new(0, H * 0.5 + 2, -L * 0.45)
	local p = seat.Position:Lerp(over.Position, draw)
	if slide > 0 then
		p = p:Lerp(over.Position, slide):Lerp(mouth.Position, Ease.smoothstep(0.5, 1, slide))
	end
	local rider = CFrame.new(p) * frame.Rotation * CFrame.Angles(math.rad(-40) * slide, 0, 0)
	return { Fish = frame, Rider = rider, Hide = t >= 1.05, Focus = lurePlace(frame, f).Position }
end

-- arms close round you and it dives, dragging you down into the dark
OUTCOMES.Wrap = function(f, t)
	local H = f.Height
	local base = carried(f, t, 4)
	local dive = Ease.smoothstep(0.35, 0.8, t)
	local fall = math.max(0, t - 0.4)
	local down = 18 * fall * fall + 6 * fall
	local at = base.Position - Vector3.new(0, down, 0)
	local floorY = f.FloorY
	if floorY then
		at = Vector3.new(at.X, math.max(at.Y, floorY + H * 0.6 + 2), at.Z)
	end
	local roll = math.rad(25) * math.sin(t * 5) * (1 - dive)
	local frame = CFrame.new(at) * base.Rotation * CFrame.Angles(-math.rad(70) * dive, 0, roll + dive * math.rad(120))
	return { Fish = frame, Rider = nil, Hide = false, Focus = (frame * f.Saddle).Position }
end

-- a giant rolls right over with a heavy splash and bucks you off its back
OUTCOMES.Roll = function(f, t)
	local u = math.clamp(t / f.Def.Time, 0, 1)
	local base = carried(f, t, 1.5)
	local rise = bump(0, 1, u) * f.Height * 0.4
	local roll = TAU * Ease.inOutSine(math.clamp(u / 0.85, 0, 1))
	local frame = base * CFrame.new(0, rise, 0) * CFrame.Angles(math.rad(10) * bump(0, 0.5, u), 0, roll)
	return { Fish = frame, Rider = nil, Hide = false }
end

-- a ray flips over and you drop off its back
OUTCOMES.Flip = function(f, t)
	local u = math.clamp(t / f.Def.Time, 0, 1)
	local base = carried(f, t, 2)
	local frame = base
		* CFrame.new(0, bump(0, 1, u) * 4, 0)
		* CFrame.Angles(math.rad(35) * bump(0, 0.8, u), 0, math.pi * Ease.inOutSine(math.clamp(u / 0.7, 0, 1)))
	-- (upside down, the rider falls off the underside)
	local seat = frame * f.Saddle
	local drop = Ease.smoothstep(0.6, 1, u) * 3
	return { Fish = frame, Rider = seat - Vector3.new(0, drop, 0), Hide = false }
end

-- a turtle stops, tucks in and shakes you off its shell
OUTCOMES.Shell = function(f, t)
	local base = carried(f, t, 5)
	local grow = Ease.smoothstep(0.15, 0.6, t)
	local shake = math.sin(t * 50) * math.rad(22) * grow
	local frame = base * CFrame.Angles(-math.rad(14) * Ease.smoothstep(0, 0.3, t), shake * 0.3, shake)
	local seat = frame * f.Saddle
	local hop = math.abs(math.sin(t * 25)) * grow * 1.2
	return { Fish = frame, Rider = seat + Vector3.new(0, hop, 0), Hide = false }
end

-- a serpent coils round itself, faster and faster, and flings you out
OUTCOMES.Coil = function(f, t)
	local u = math.clamp(t / f.Def.Time, 0, 1)
	local base = carried(f, t, 3)
	local spin = TAU * 1.5 * u * u
	local frame = base * CFrame.new(0, u * 8, 0) * CFrame.Angles(0, spin, math.rad(40) * Ease.smoothstep(0, 0.5, u))
	-- out to its side as it spins
	local seat = frame * f.Saddle
	local out = frame.RightVector * Ease.smoothstep(0.3, 1, u) * f.Width * 0.8
	return { Fish = frame, Rider = seat + out, Hide = false }
end

-- a crawler noses down to the floor and pins you under it
OUTCOMES.Pin = function(f, t)
	local H = f.Height
	local base = carried(f, t, 3)
	local floorY = f.FloorY or (f.From.Position.Y - 20)
	local dive = Ease.inQuad(math.clamp((t - 0.1) / 0.6, 0, 1))
	local at = base.Position:Lerp(Vector3.new(base.Position.X, floorY + H * 0.5 + 2.5, base.Position.Z), dive)
	local nose = -math.rad(45) * bump(0.1, 0.85, t)
	local judder = if t > 0.7 then math.sin(t * 40) * math.rad(3) * math.exp(-(t - 0.7) * 2) else 0
	local frame = CFrame.new(at) * base.Rotation * CFrame.Angles(nose + judder, 0, judder)
	-- the rider is scraped off the back and under the head, flat on the floor
	local under = CFrame.new(frame.Position.X, floorY + 1.2, frame.Position.Z) * frame.Rotation
	under = under * CFrame.new(0, 0, -f.Length * 0.25) * CFrame.Angles(-math.pi / 2, 0, 0)
	local seat = frame * f.Saddle
	local slide = Ease.smoothstep(0.35, 0.7, t)
	local rider = seat:Lerp(under, slide)
	return { Fish = frame, Rider = rider, Hide = false, Focus = rider.Position }
end

----------------------------------------------------------------------------------------------------------------------

-- the jaws closing the screen (Chomp, Gulp): two dark halves with teeth
local function makeJaws(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "FailJaws"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 40
	gui.ResetOnSpawn = false
	for _, top in { true, false } do
		local half = Instance.new("Frame")
		half.Name = if top then "Top" else "Bottom"
		half.BorderSizePixel = 0
		half.BackgroundColor3 = Color3.fromRGB(60, 8, 14)
		half.Size = UDim2.fromScale(1.2, 0.55)
		half.AnchorPoint = Vector2.new(0.5, if top then 1 else 0)
		half.Position = UDim2.fromScale(0.5, if top then 0 else 1)
		half.Parent = gui
		for i = 0, 15 do
			local tooth = Instance.new("Frame")
			tooth.BorderSizePixel = 0
			tooth.BackgroundColor3 = Color3.fromRGB(250, 244, 226)
			tooth.Size = UDim2.fromScale(0.032, 0.032)
			tooth.SizeConstraint = Enum.SizeConstraint.RelativeXX
			tooth.AnchorPoint = Vector2.new(0.5, 0.5)
			tooth.Rotation = 45
			tooth.Position = UDim2.fromScale((i + 0.5 + (if top then 0 else 0.5)) / 16, if top then 1 else 0)
			tooth.ZIndex = 0
			tooth.Parent = half
		end
	end
	gui.Parent = State.Player:WaitForChild("PlayerGui")
	return gui
end

local function setJaws(gui: ScreenGui, shut: number)
	local top = gui:FindFirstChild("Top") :: Frame?
	local bottom = gui:FindFirstChild("Bottom") :: Frame?
	if top and bottom then
		top.Position = UDim2.fromScale(0.5, shut * 0.5)
		bottom.Position = UDim2.fromScale(0.5, 1 - shut * 0.5)
	end
end

local function hide(f: Fail)
	local character = f.Character
	if not character then
		return
	end
	for _, d in character:GetDescendants() do
		if (d:IsA("BasePart") or d:IsA("Decal")) and f.Hidden[d] == nil then
			f.Hidden[d] = d.Transparency
			d.Transparency = 1
		end
	end
end

local function unhide(f: Fail)
	for d, was in f.Hidden do
		if d.Parent then
			(d :: any).Transparency = was
		end
	end
	table.clear(f.Hidden)
end

local function localPart(size: Vector3, colour: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = colour
	p.Material = material
	p.Parent = workspace.CurrentCamera
	return p
end

-- the outcome's props, made at the start
local function makeProps(f: Fail)
	if f.Kind == "Gulp" then
		local ball = localPart(Vector3.one * (1 + f.Length * 0.04), Color3.fromRGB(255, 244, 170), Enum.Material.Neon)
		ball.Shape = Enum.PartType.Ball
		ball.Name = "Lure"
		local light = Instance.new("PointLight")
		light.Color = ball.Color
		light.Range = 40
		light.Brightness = 0
		light.Parent = ball
		table.insert(f.Props, ball)
	elseif f.Kind == "Wrap" then
		local kind = Config.FishById[f.Fish:GetAttribute("FishType") :: string]
		local colour = (if kind then kind.Fin else Color3.fromRGB(150, 60, 90)):Lerp(Color3.new(1, 1, 1), 0.3)
		for i = 1, 6 do
			local arm = localPart(Vector3.new(1, 1, 1), colour, Enum.Material.SmoothPlastic)
			arm.Shape = Enum.PartType.Cylinder
			arm.Name = "Arm" .. i
			table.insert(f.Props, arm)
		end
	end
end

local function updateProps(f: Fail, fish: CFrame, rider: Vector3, t: number)
	if f.Kind == "Gulp" then
		local ball = f.Props[1] :: BasePart?
		if ball then
			local glow = Ease.smoothstep(0, 0.5, t) * (1 - Ease.smoothstep(1.05, 1.3, t))
			local pulse = 0.75 + 0.25 * math.sin(t * 14)
			ball.CFrame = lurePlace(fish, f)
			ball.Transparency = 1 - math.max(0.15, glow)
			local light = ball:FindFirstChildOfClass("PointLight")
			if light then
				light.Brightness = 6 * glow * pulse
			end
		end
	elseif f.Kind == "Wrap" then
		local n = #f.Props
		local grow = Ease.outQuad(math.clamp(t / 0.45, 0, 1))
		local tight = Ease.smoothstep(0.2, 0.7, t)
		for i, prop in f.Props do
			local arm = prop :: BasePart
			local a = (i - 1) / n * TAU
			local side = if i % 2 == 0 then 1 else -1
			local from = (fish * CFrame.new(side * f.Width * 0.4, -f.Height * 0.2, -f.Length * (0.1 + 0.08 * i))).Position
			local around = a + t * 5
			local radius = Ease.lerp(5, 1.3, tight)
			local goal = rider + Vector3.new(math.cos(around) * radius, (i - n / 2) * 0.5, math.sin(around) * radius)
			local tip = from:Lerp(goal, grow)
			local span = (tip - from).Magnitude
			if span < 0.2 then
				arm.Transparency = 1
			else
				arm.Transparency = 0
				local thick = Ease.lerp(2.4, 1.3, tight) * (0.8 + f.Length * 0.006)
				arm.Size = Vector3.new(span, thick, thick)
				arm.CFrame = CFrame.lookAt((from + tip) / 2, tip) * CFrame.Angles(0, math.pi / 2, 0)
			end
		end
	end
end

local function weldOf(fishRoot: BasePart, character: Model?): Weld?
	local root = rootOf(character)
	for _, child in fishRoot:GetChildren() do
		if child:IsA("Weld") and child.Name == "RideWeld" and (root == nil or child.Part1 == root) then
			return child
		end
	end
	return nil
end

local function release(f: Fail)
	-- the fish goes back to its own swim (the server's dismount, or the coast)
	for _, c in f.Paused do
		if c.Parent then
			c.Enabled = true
		end
	end
	table.clear(f.Paused)
	f.Driving = false
end

local function begin(player: Player, fish: Model, kind: string)
	local def = Config.Fail.Outcomes[kind]
	local fishRoot = fish.PrimaryPart
	if not def or not OUTCOMES[kind] or not fishRoot then
		return
	end
	local old = fails[player]
	if old then
		FailController.stop(player)
	end
	local type_ = Config.FishById[fish:GetAttribute("FishType") :: string]
	local body = if type_ then Config.bodyOf(fish, type_) else fishRoot.Size
	local character = player.Character
	local weld = weldOf(fishRoot, character)
	local start = os.clock()
	local at = player:GetAttribute("FailAt")
	if type(at) == "number" then
		start = math.min(start, os.clock() - math.clamp(workspace:GetServerTimeNow() - at, 0, 0.5))
	end
	local from = fishRoot.CFrame
	local right = flat(from.RightVector)
	local camera = workspace.CurrentCamera.CFrame.Position
	-- the shot: off to the side we were already looking from, back and up
	local sideSign = if (camera - from.Position):Dot(right) >= 0 then 1 else -1
	local f: Fail = {
		Kind = kind,
		Def = def,
		Player = player,
		Mine = player == State.Player,
		Start = start,
		Fish = fish,
		FishRoot = fishRoot,
		From = from,
		Speed = math.min(fishRoot.AssemblyLinearVelocity.Magnitude, 120),
		Length = body.Z,
		Height = body.Y,
		Width = body.X,
		Saddle = if weld then weld.C0 else CFrame.new(0, body.Y / 2, 0),
		Weld = weld,
		Character = character,
		CamFrom = from.Position + right * sideSign * (body.Z * 0.45 + 14) + Vector3.new(0, body.Y * 0.6 + 6, 0) - flat(
			from.LookVector
		) * body.Z * 0.15,
		FloorY = Course.floor(from.Position),
		Hidden = {},
		Props = {},
		Paused = {},
		Driving = false,
		Bit = false,
		Jaws = nil,
	}
	if f.Mine then
		for _, name in { "Swim", "Turn" } do
			local c = fishRoot:FindFirstChild(name)
			if c and c:IsA("Constraint") and c.Enabled then
				c.Enabled = false
				table.insert(f.Paused, c)
			end
		end
		f.Driving = true
	end
	makeProps(f)
	fails[player] = f
	-- (the hook for the real animations and sounds: Def.Hook)
	if def.End ~= "Taken" or kind == "Wrap" or kind == "Pin" then
		Fx.sound(def.Sound, fishRoot)
	end
end

function FailController.stop(player: Player)
	local f = fails[player]
	if not f then
		return
	end
	fails[player] = nil
	release(f)
	unhide(f)
	if f.Weld and f.Weld.Parent then
		f.Weld.C0 = f.Saddle
	end
	for _, p in f.Props do
		p:Destroy()
	end
	if f.Jaws then
		f.Jaws:Destroy()
	end
	if f.Mine and player:GetAttribute("State") ~= "Drowning" then
		-- (the drown takes these over itself; the dock, or a fail with no failing, gets them back as they were)
		State.DeathCam = nil
		State.Darken = 0
		State.Vignette = 0
	end
end

local function step(_dt: number)
	local clock = os.clock()
	for player, f in fails do
		local state = player:GetAttribute("State")
		local t = clock - f.Start
		-- (Studio only, for capturing it frame by frame: workspace's FailClock, seconds into the outcome)
		local held = if RunService:IsStudio() then workspace:GetAttribute("FailClock") else nil
		if type(held) == "number" and held >= 0 then
			t = held
		end
		local def = f.Def
		local taken = def.End == "Taken"
		-- over: the State has moved on (the drown, the dock), or it lost the fish or the character
		if
			player.Parent == nil
			or (state ~= "Failing" and clock - f.Start > 0.3)
			or f.Fish.Parent == nil
			or player.Character ~= f.Character
		then
			FailController.stop(player)
			continue
		end
		local motion = OUTCOMES[f.Kind]
		local frame = motion(f, math.min(t, def.Time + (if taken then def.Time else 0.2)))
		local weld = f.Weld
		if weld and weld.Parent == nil then
			weld = nil
			f.Weld = nil
			release(f)
		end
		-- the fish: ours to move while it holds us
		if f.Driving and f.Mine then
			if weld or t < def.Time then
				f.FishRoot.CFrame = frame.Fish
				f.FishRoot.AssemblyLinearVelocity = Vector3.zero
				f.FishRoot.AssemblyAngularVelocity = Vector3.zero
			else
				release(f)
			end
		end
		-- the rider, slid about on the saddle (everyone works out the same)
		local fishNow = f.FishRoot.CFrame
		local riderAt = frame.Rider
		if weld then
			weld.C0 = if riderAt then fishNow:Inverse() * riderAt else f.Saddle
		end
		local riderPos = if riderAt then riderAt.Position else (fishNow * f.Saddle).Position
		if frame.Hide and next(f.Hidden) == nil then
			hide(f)
		end
		updateProps(f, fishNow, riderPos, t)
		-- the moment it lands: the bite, the slam, the splash
		local beat = if f.Kind == "Chomp"
			then 0.8
			elseif f.Kind == "Gulp" then 1.05
			elseif f.Kind == "Pin" then 0.7
			elseif f.Kind == "Roll" then def.Time * 0.85
			else -1
		if beat >= 0 and not f.Bit and t >= beat then
			f.Bit = true
			if f.Kind == "Chomp" or f.Kind == "Gulp" then
				Fx.sound(def.Sound, f.FishRoot)
				Fx.burst(riderPos, 25, nil, 6)
			elseif f.Kind == "Pin" then
				Fx.sound(def.Sound, f.FishRoot)
				Fx.burst(riderPos, 40, nil, f.Length * 0.4)
			else
				Fx.sound("Splash", f.FishRoot)
				Fx.burst(fishNow.Position, 70, 0.3, f.Length * 0.5)
			end
			if f.Mine then
				Shake.play(if f.Kind == "Roll" then "LandBig" else "Crash")
			end
		end
		if not f.Mine then
			continue
		end
		-- our own: the shot, the dark, the jaws and the fade
		local focus = frame.Focus or riderPos
		State.DeathCam = {
			Position = f.CamFrom + f.From.LookVector * travel(f, t, 3) * 0.6 + Vector3.new(0, t * 0.6, 0),
			Focus = focus:Lerp(fishNow.Position, 0.3),
		}
		local u = math.clamp(t / math.max(def.Time, 0.01), 0, 1)
		State.Darken = 0.3 * u
		State.Vignette = 0.5 * u
		if beat >= 0 and (f.Kind == "Chomp" or f.Kind == "Gulp") and t >= beat - 0.12 then
			local jaws = f.Jaws or makeJaws()
			f.Jaws = jaws
			-- snap almost shut at the bite (a slit to see it shake its head through), all the way as it ends, then
			-- dark from the mouth outward as the fade comes in
			local snap = 0.72 * Ease.outQuad(math.clamp((t - (beat - 0.12)) / 0.12, 0, 1))
			setJaws(jaws, snap + 0.28 * Ease.smoothstep(def.Time - 0.2, def.Time, t))
			local dark = Ease.smoothstep(def.Time, def.Time + Config.Fail.TakenFade * 0.6, t)
			for _, half in jaws:GetChildren() do
				if half:IsA("Frame") then
					half.BackgroundColor3 = Color3.fromRGB(60, 8, 14):Lerp(Color3.new(0, 0, 0), dark)
					for _, tooth in half:GetChildren() do
						if tooth:IsA("Frame") then
							tooth.BackgroundTransparency = dark
						end
					end
				end
			end
		end
		if taken and t >= def.Time then
			State.Fade = math.clamp((t - def.Time) / math.max(Config.Fail.TakenFade, 0.05), 0, 1)
			State.FadeText = def.Text
		end
	end
end

function FailController.Init()
	Net.Fx.OnClientEvent:Connect(function(kind: string, player: Player, fish: Model, outcome: string)
		if
			kind ~= "Fail"
			or typeof(player) ~= "Instance"
			or typeof(fish) ~= "Instance"
			or type(outcome) ~= "string"
		then
			return
		end
		begin(player, fish, outcome)
	end)
	-- our own: no input while the fish does its thing (the ride's drive and steering stop: State.Mode "Failing")
	State.Player:GetAttributeChangedSignal("State"):Connect(function()
		if State.Player:GetAttribute("State") == "Failing" then
			State.setMode("Failing")
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		FailController.stop(player)
	end)
end

function FailController.Start()
	-- before the drown's step (DeathController, Camera - 3), so it takes the shot over on the same frame
	RunService:BindToRenderStep("RideFail", Enum.RenderPriority.Camera.Value - 4, step)
end

return FailController
