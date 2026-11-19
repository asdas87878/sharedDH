--!strict
-- What a fish does when your Oxygen hits 0 on it (Config.Fail; task e1, redone in task f3 on Hugo's notes of
-- 2026-11-19: smoother and one set, one eased camera move per outcome then held, the rider thrown and swallowed in full
-- view, the fish's own parts moving, real collisions, a real ragdoll, dragging with weight, the kraken's throw and then
-- its arms). The server picks the outcome (Config.failOf), holds the rider in the "Failing" state, and at the outcome's
-- Loose swaps the body's joints for ball sockets (RideService: the character's "Ragdoll" attribute, Fx "Ragdoll").
-- This plays it on every client, so friends see it too:
--   on the rider's own machine (it owns the fish and the character) the fish's root is moved along the outcome's path
--   with its swim and turn switched off, the loose body is thrown, held up and slowed by the water, and grabbed by the
--   fish (soft pulls at the arms, the jaw, the coil: AlignPositions, so it hangs and lags with its own weight), and the
--   fish gets invisible solid boxes on its parts so the body really hits it (and the map and the props, by the
--   "Ragdoll" group); the camera eases once to the outcome's shot and holds (State.DeathCam);
--   on every machine the fish's rig is posed through its own joints (FishModel's Rig_ Motor6Ds, from
--   Shared/Creatures' pivots: the jaw on its hinge, the spine thrashing and curling, the fins flaring, an octopus's arms
--   reaching and curling), the rider is slid about on the saddle before coming loose (the weld's C0), hidden once
--   swallowed, the throat bulges, and the outcome's props are made locally (the angler's lure, the kraken's shooting
--   arms, the dark arms closing in on the screen).
-- A "Throw" outcome ends in the throw and the drown (DeathController, which leaves a loose body to the physics until its
-- joints are back); a "Taken" one is the fail itself and fades to the fail screen (State.Fade, FadeText).
-- Stand-ins for the partner's animations: the player's FailKind attribute and Config.Fail.Outcomes[kind].Hook name
-- what plays; the sounds are placeholders from Lib/Fx.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Creatures = require(ReplicatedStorage.Shared.Creatures)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Net = require(ReplicatedStorage.Shared.Net)
local Course = require(script.Parent.Parent.Lib.Course)
local Fx = require(script.Parent.Parent.Lib.Fx)
local Shake = require(script.Parent.Parent.Lib.Shake)
local State = require(script.Parent.Parent.Lib.State)
local AnimController = require(script.Parent.AnimController)

local FailController = {}

type Def = { Time: number, Loose: number, End: string, Text: string, Sound: string, Hook: string }
type Pose = { [string]: CFrame }

-- one of the fish's own joints (FishModel's "Rig_<part>")
type Joint = {
	Motor: Motor6D,
	C0: CFrame, -- as it was: put back at the end
	Part: BasePart,
	Name: string,
	Kind: string, -- "jaw", "spine", "fin", "arm", "body" (the first part's) or "other"
	Side: number, -- a fin's or an arm's side: -1 left, 1 right, 0 the middle
	Z: number, -- along the body: -0.5 the nose, 0.5 the tail
	Open: number, -- a jaw: 1 a lower jaw (opens down), -1 an upper one
	Depth: number, -- an arm's or a fin's segment: 1 at its root
	Dir: Vector3, -- an arm segment's way at rest, in the fish's space
	Pivot: Vector3, -- in the fish's space
	Count: number, -- how many joints of its kind there are (a spine's turn is shared out)
}

-- the fish's rig this frame (every number eased by the outcome itself)
type Rig = {
	Jaw: number, -- 0 shut, 1 open wide
	Thrash: number, -- the tail's beat, radians either way at the tail
	Rate: number, -- beats a second
	Curl: number, -- the whole body bent round (yaw), radians in all
	Arch: number, -- and up or down (pitch), radians in all
	Flare: number, -- the fins thrown out, 0 to 1
	Reach: number, -- the arms reaching for ReachAt, 0 to 1
	ReachAt: Vector3?,
	Coil: number, -- the arms curled in, -1 (cocked back) to 1 (wrapped)
}

type Frame = { Fish: CFrame, Rider: CFrame?, Rig: Rig, Focus: Vector3? }

-- the loose body (a ragdoll): on every machine for the looks, on our own for the physics
type Collider = { Part: Part, Of: BasePart, Was: Vector3, On: boolean, Mouth: boolean }
type Hold = { Attachment: Attachment, Align: AlignPosition, Part: BasePart }
type Body = {
	Player: Player,
	Character: Model,
	Mine: boolean,
	Kind: string,
	Fish: Model?,
	Since: number, -- os.clock() it came loose here
	Parts: { BasePart }, -- the body's parts (not hats)
	Main: { BasePart }, -- the big ones: the hits are looked for on these
	Colliders: { Collider },
	Holds: { [string]: Hold },
	HitAt: number,
	MouthOff: boolean, -- the boxes round the mouth are off (it is being swallowed)
}

-- one of the kraken's arms shooting out to a limb
type Tentacle = {
	Segs: { BasePart },
	From: BasePart?, -- the rig's arm it comes out of (nil: the fish's underside)
	Target: string, -- the limb it goes for
	Start: number, -- seconds in it leaves
	Grab: number, -- and takes hold
	Phase: number,
	Thick: number,
}

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
	FloorY: number?,
	Hidden: { [Instance]: number }, -- parts and decals we made unseen, and their own transparency
	Props: { Instance }, -- what we made for it, local only
	Paused: { Constraint }, -- the fish's swim and turn, off while we move it
	Driving: boolean,
	Beats: { [string]: boolean }, -- moments that have happened (once each)
	Joints: { Joint },
	Bulge: { BasePart }, -- the spine's parts, nose to tail (the swallow's bulge runs down them)
	Sizes: { [BasePart]: Vector3 }, -- their own sizes
	Tentacles: { Tentacle },
	Shade: ScreenGui?,
	CamStart: Vector3,
	CamTo: Vector3,
	Focus: Vector3, -- where the shot looks, eased
	Pose: Pose?, -- the rider's pose on the fish (AnimController.FailPose)
	Last: number, -- the last t
	Released: boolean, -- the coil has let go
	Trails: { Trail }, -- the fish's wake, off while it does its thing
	Snap: CFrame?, -- where a Chomp bit (it goes on from there)
	Pull: number, -- studs the shot is backed off by to keep both in it
}

local fails: { [Player]: Fail } = {}
local bodies: { [Player]: Body } = {}

local TAU = math.pi * 2
local rad = math.rad

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

local function ss(a: number, b: number, t: number): number
	return Ease.smoothstep(a, b, t)
end

-- 0 at a, up to 1 and down to 0 at b, smoothly
local function bump(a: number, b: number, t: number): number
	if t <= a or t >= b then
		return 0
	end
	return math.sin(math.pi * (t - a) / (b - a)) ^ 2
end

local function inOut(u: number): number
	u = math.clamp(u, 0, 1)
	return if u < 0.5 then 4 * u * u * u else 1 - (-2 * u + 2) ^ 3 / 2
end

local function still(): Rig
	return { Jaw = 0, Thrash = 0, Rate = 1, Curl = 0, Arch = 0, Flare = 0, Reach = 0, ReachAt = nil, Coil = 0 }
end

-- the rider's parts by their R15 names, or an R6 avatar's
local LIMBS: { [string]: { string } } = {
	Torso = { "UpperTorso", "Torso" },
	Lower = { "LowerTorso", "Torso" },
	Head = { "Head" },
	LArm = { "LeftLowerArm", "LeftUpperArm", "Left Arm" },
	RArm = { "RightLowerArm", "RightUpperArm", "Right Arm" },
	LLeg = { "LeftLowerLeg", "LeftUpperLeg", "Left Leg" },
	RLeg = { "RightLowerLeg", "RightUpperLeg", "Right Leg" },
}

local function limb(character: Model?, name: string): BasePart?
	if not character then
		return nil
	end
	local names: { string } = LIMBS[name] or { name }
	for _, n in names do
		local p = character:FindFirstChild(n)
		if p and p:IsA("BasePart") then
			return p
		end
	end
	return nil
end

local function torsoOf(f: Fail): Vector3?
	local p = limb(f.Character, "Torso")
	return p and p.Position
end

local function rot(x: number, y: number, z: number): CFrame
	return CFrame.Angles(rad(x), rad(y), rad(z))
end

----------------------------------------------------------------------------------------------------------------------
-- The rig: the fish's own joints, read once from Shared/Creatures

local function readRig(fish: Model, length: number): { Joint }
	local id = fish:GetAttribute("Rig")
	local rig = if type(id) == "string" then Creatures.get(id) else nil
	local joints: { Joint } = {}
	if not rig then
		return joints
	end
	local k = length / math.max(rig.Size[3], 0.01)
	local centre = 0.05 * rig.Size[1] + 0.05
	local rows: { [string]: { any } } = {}
	local children: { [string]: string } = {}
	for _, row in rig.Parts do
		rows[row[1] :: string] = row
		children[row[2] :: string] = children[row[2] :: string] or row[1] :: string
	end
	local function isArm(name: string): boolean
		return string.match(name, "^[AT]%d+[a-z]$") ~= nil
			or string.match(name, "^T[RL][a-z]$") ~= nil
			or string.find(name, "Arm") ~= nil
			or string.find(name, "Tentacle") ~= nil
	end
	local function depthOf(name: string): number
		local d, at = 1, rows[name]
		while
			at
			and rows[at[2] :: string]
			and (isArm(at[2] :: string) or math.abs(rows[at[2] :: string][3]) > centre)
		do
			d += 1
			at = rows[at[2] :: string]
		end
		return d
	end
	local counts: { [string]: number } = {}
	for _, row in rig.Parts do
		local name, parent = row[1] :: string, row[2] :: string
		local motor = fish:FindFirstChild("Rig_" .. name, true)
		if not motor or not motor:IsA("Motor6D") or not motor.Part1 then
			continue
		end
		local pivot = Vector3.new(row[3], row[4], row[5]) * k
		local x = row[3] :: number
		local parentRow = rows[parent]
		local kind = "other"
		local side = 0
		if parent == "" then
			kind = "body" -- (the whole body hangs from it: not turned here, or the fish would swing about its Root)
		elseif string.find(name, "Jaw") then
			kind = "jaw"
		elseif isArm(name) then
			kind = "arm"
			side = if math.abs(x) > 0.01 then math.sign(x) else 0
		elseif string.find(name, "Rod") or string.find(name, "Lure") or string.find(name, "Antenna") then
			kind = "other"
		elseif math.abs(x) <= centre then
			kind = "spine"
		elseif math.abs(x) > centre then
			kind = "fin"
			side = math.sign(x)
		end
		-- an arm segment's way at rest: to its child's pivot (the last one: on from its parent's)
		local dir = Vector3.new(0, 0, 1)
		local child = children[name]
		if child and rows[child] then
			local c = rows[child]
			dir = (Vector3.new(c[3], c[4], c[5]) * k - pivot)
		elseif parentRow then
			dir = pivot - Vector3.new(parentRow[3], parentRow[4], parentRow[5]) * k
		end
		dir = if dir.Magnitude > 0.01 then dir.Unit else Vector3.new(0, 0, 1)
		local part = motor.Part1 :: BasePart
		local open = 1
		if kind == "jaw" and motor.Part0 then
			-- a lower jaw hangs below what it hinges on
			local root = fish.PrimaryPart
			if root then
				local below = root.CFrame:PointToObjectSpace(part.Position).Y
					< root.CFrame:PointToObjectSpace((motor.Part0 :: BasePart).Position).Y
				open = if below then 1 else -1
			end
		end
		counts[kind] = (counts[kind] or 0) + 1
		table.insert(joints, {
			Motor = motor,
			C0 = motor.C0,
			Part = part,
			Name = name,
			Kind = kind,
			Side = side,
			Z = (row[5] :: number) / math.max(rig.Size[3], 0.01),
			Open = open,
			Depth = if kind == "arm" or kind == "fin" then depthOf(name) else 1,
			Dir = dir,
			Pivot = pivot,
			Count = 0,
		})
	end
	for _, j in joints do
		j.Count = counts[j.Kind] or 1
	end
	return joints
end

-- the turn that takes `a` to `b`, `w` of the way, never more than `most` radians
local function turnTo(a: Vector3, b: Vector3, w: number, most: number): CFrame
	local axis = a:Cross(b)
	if axis.Magnitude < 1e-4 or w <= 0 then
		return CFrame.identity
	end
	local angle = math.min(math.acos(math.clamp(a:Dot(b), -1, 1)), most) * w
	return CFrame.fromAxisAngle(axis.Unit, angle)
end

local function poseRig(f: Fail, rig: Rig, t: number)
	local rootCF = f.FishRoot.CFrame
	local reachLocal = if rig.ReachAt then rootCF:PointToObjectSpace(rig.ReachAt) else nil
	for _, j in f.Joints do
		local r = CFrame.identity
		if j.Kind == "jaw" then
			r = CFrame.Angles(-j.Open * rad(58) * rig.Jaw, 0, 0)
		elseif j.Kind == "spine" then
			-- the tail beats from the middle back, the head a little the other way; the curl and the arch are shared out
			local n = math.max(j.Count, 1)
			local behind = math.clamp(j.Z + 0.25, 0, 1)
			local wave = rig.Thrash * math.sin(t * TAU * rig.Rate - j.Z * 4) * (0.25 + behind) * 3 / n
			r = CFrame.Angles(rig.Arch / n, rig.Curl / n + wave, 0)
		elseif j.Kind == "fin" then
			local flap = 0.7 + 0.3 * math.sin(t * 9 + j.Z * 3 + j.Depth)
			local amount = rig.Flare * (if j.Depth > 1 then 0.5 else 1)
			r = CFrame.Angles(0, -j.Side * rad(18) * amount, j.Side * rad(38) * amount * flap)
		elseif j.Kind == "arm" then
			-- writhing always; the first segment turns toward what it reaches for, the rest curl round it
			local writhe = math.sin(t * 5 + j.Pivot.X * 0.7 + j.Depth) * rad(10)
			if j.Depth == 1 and reachLocal and rig.Reach > 0 then
				r = turnTo(j.Dir, (reachLocal - j.Pivot).Unit, rig.Reach, rad(115))
			end
			local bend = j.Dir:Cross(Vector3.yAxis)
			bend = if bend.Magnitude > 0.01 then bend.Unit else Vector3.xAxis
			local curl = rig.Coil * rad(if j.Depth == 1 then 15 else 42)
			r = r * CFrame.fromAxisAngle(bend, curl + writhe)
		end
		j.Motor.C0 = j.C0 * r
	end
end

local function unposeRig(f: Fail)
	for _, j in f.Joints do
		if j.Motor.Parent then
			j.Motor.C0 = j.C0
		end
	end
	for part, size in f.Sizes do
		if part.Parent then
			part.Size = size
		end
	end
end

-- the swallow: a bulge running down the spine from `a` to `b` seconds
local function bulge(f: Fail, t: number, a: number, b: number)
	local n = #f.Bulge
	if n == 0 then
		return
	end
	local u = math.clamp((t - a) / math.max(b - a, 0.01), 0, 1)
	for i, part in f.Bulge do
		local at = (i - 0.5) / n
		local k = math.exp(-((u * 1.15 - at) / 0.13) ^ 2) * (if u > 0 and u < 1 then 1 else 0)
		local size = f.Sizes[part]
		if size then
			part.Size = size * Vector3.new(1 + 0.22 * k, 1 + 0.2 * k, 1)
		end
	end
end

----------------------------------------------------------------------------------------------------------------------
-- The outcomes. Each gives, at `t` seconds in, the fish's root (world), where the rider is while still on it (world;
-- nil: the saddle), the rig, and what the shot looks at. Lengths are in the fish's own size, so a giant's are bigger.
-- Every move is eased in and out: nothing starts or stops at once.

local OUTCOMES: { [string]: (f: Fail, t: number) -> Frame } = {}

-- the mouth's place on the fish, in the fish's space
local function mouthOf(f: Fail): CFrame
	return CFrame.new(0, -f.Height * 0.05, -f.Length * 0.47)
end

-- turns on you: it rears and tosses you off its back, comes round with its jaws wide, takes you, shakes and swallows
OUTCOMES.Chomp = function(f, t)
	local L, H = f.Length, f.Height
	local base = carried(f, t, 2.2)
	local torso = torsoOf(f)
	local rig = still()
	-- the rear and the toss
	local rear = bump(0, 0.9, t) * rad(28)
	local turn = math.pi * inOut((t - 0.35) / 0.7)
	local rise = ss(0.2, 1.0, t) * H * 0.6
	local frame = base * CFrame.new(0, rise, 0) * CFrame.Angles(0, turn, 0) * CFrame.Angles(rear, 0, 0)
	-- round to face you and lunge, so the open mouth meets you as you come down
	local lunge = ss(0.75, 1.25, t)
	if f.Snap and t >= 1.3 then
		-- (from the bite on it goes from where it took you: you are in its mouth now, nothing to aim at)
		frame = f.Snap :: CFrame
	elseif torso and lunge > 0 then
		local aim = torso - frame.Position
		aim = if aim.Magnitude > 0.1 then aim.Unit else frame.LookVector
		local mouthTo = torso - aim * L * 0.45
		local at = frame.Position:Lerp(mouthTo, lunge * 0.9)
		local look = frame.LookVector:Lerp(aim, lunge)
		frame = CFrame.lookAt(at, at + look)
	end
	if t >= 1.3 then
		f.Snap = f.Snap or frame
		-- shut: it shakes its head and swims on
		local after = t - 1.3
		local shake = math.sin(after * 18) * rad(16) * math.exp(-after * 2.4)
		frame = frame + frame.LookVector * travel(f, after, 1.5) * 0.15
		frame = frame * CFrame.Angles(0, shake, shake * 0.4)
	end
	rig.Thrash = 0.15 + 0.35 * bump(0, 1.0, t) + 0.5 * bump(1.2, 2.3, t)
	rig.Rate = 1.6 + 1.2 * ss(1.2, 1.4, t)
	rig.Curl = -rad(60) * bump(0.3, 1.1, t)
	rig.Flare = bump(0, 1.3, t)
	rig.Jaw = 0.25 * bump(0, 0.5, t) + ss(0.6, 1.05, t) * (1 - ss(1.22, 1.32, t)) + 0.12 * bump(1.5, 2.2, t)
	-- the rider: braced and bounced up on the saddle until the toss
	local seat = frame * f.Saddle
	local rider = seat * CFrame.new(0, bump(0, 0.6, t) * 1.2, 0)
	local mouth = (frame * mouthOf(f)).Position
	local focus = if torso then torso:Lerp(mouth, 0.45) else mouth
	return { Fish = frame, Rider = rider, Rig = rig, Focus = focus }
end

-- the lure flares and draws the eye; you lean to it, it bucks you up over its head and the wide mouth takes you in
local function lurePlace(fish: CFrame, f: Fail): CFrame
	return fish * CFrame.new(0, f.Height * 0.62 + 1.5, -f.Length * 0.64)
end

OUTCOMES.Gulp = function(f, t)
	local L = f.Length
	local base = carried(f, t, 2.5)
	local hover = math.sin(t * 2.4) * 0.5
	local tilt = rad(10) * ss(0, 0.8, t) + rad(22) * bump(0.8, 1.8, t) - rad(10) * bump(1.6, 2.5, t)
	local frame = base * CFrame.new(0, hover, 0) * CFrame.Angles(tilt, 0, 0)
	if t > 1.7 then
		frame = frame + frame.LookVector * travel(f, t - 1.7, 1.2) * 0.12
	end
	local rig = still()
	rig.Jaw = ss(0.6, 1.05, t) * (1 - ss(1.55, 1.7, t)) + 0.1 * bump(1.75, 2.4, t)
	rig.Thrash = 0.12 + 0.3 * bump(1.5, 2.5, t)
	rig.Rate = 1.2
	rig.Flare = 0.4 + 0.6 * bump(0.5, 1.8, t)
	-- the rider: leaning toward the light and slipping forward on the saddle
	local lean = ss(0.1, 0.9, t)
	local seat = frame * f.Saddle
	local rider = seat * CFrame.new(0, 0.3 * lean, -L * 0.06 * lean) * CFrame.Angles(-rad(25) * lean, 0, 0)
	local torso = torsoOf(f)
	local lure = lurePlace(frame, f).Position
	local focus = if t < 1
		then lure:Lerp(seat.Position, 0.35)
		else (torso or lure):Lerp((frame * mouthOf(f)).Position, 0.5)
	return { Fish = frame, Rider = rider, Rig = rig, Focus = focus }
end

-- throws you off, then its arms shoot out and wrap you, and it dives with you into the dark
OUTCOMES.Wrap = function(f, t)
	local H = f.Height
	local base = carried(f, t, 3)
	local torso = torsoOf(f)
	local rig = still()
	-- the buck that throws you: the mantle up and back, arms flung out
	local buck = bump(0, 0.6, t)
	-- then round toward you, and down, dragging you
	local face = 0
	if torso then
		local local_ = f.From:PointToObjectSpace(torso)
		face = math.atan2(-local_.X, -local_.Z) * ss(0.4, 1.0, t)
	end
	local fall = math.max(0, t - 1.6)
	local down = 9 * fall * fall + 3 * fall
	local at = base.Position - Vector3.new(0, down, 0)
	if f.FloorY then
		at = Vector3.new(at.X, math.max(at.Y, f.FloorY + H * 0.6 + 2), at.Z)
	end
	local dive = ss(1.5, 2.4, t)
	local frame = CFrame.new(at)
		* base.Rotation
		* CFrame.Angles(0, face, 0)
		* CFrame.Angles(rad(30) * buck - rad(55) * dive, 0, rad(10) * math.sin(t * 3) * (1 - dive))
	rig.Coil = 0.6 * buck - 0.8 * bump(0.5, 1.0, t) + 1.0 * ss(1.15, 1.7, t)
	rig.Reach = ss(0.6, 1.0, t) * (1 - ss(1.6, 2.2, t) * 0.6)
	rig.ReachAt = torso
	rig.Thrash = 0.1
	rig.Flare = buck
	local seat = frame * f.Saddle
	local rider = seat * CFrame.new(0, buck * 1.5, 0)
	local focus = if torso then torso:Lerp(frame.Position, 0.4) else frame.Position
	return { Fish = frame, Rider = rider, Rig = rig, Focus = focus }
end

-- a giant rolls right over: you slide off its flank as it goes and its side and flipper sweep past you
OUTCOMES.Roll = function(f, t)
	local u = math.clamp(t / f.Def.Time, 0, 1)
	local base = carried(f, t, 1.4)
	local rise = bump(0, 1, u) * f.Height * 0.35
	local roll = TAU * inOut(u / 0.9)
	local frame = base * CFrame.new(0, rise, 0) * CFrame.Angles(rad(8) * bump(0, 0.6, u), 0, roll)
	local rig = still()
	rig.Thrash = 0.25 + 0.45 * bump(0.1, 1, u)
	rig.Rate = 0.9
	rig.Flare = bump(0, 0.9, u)
	rig.Arch = rad(14) * bump(0.2, 0.9, u)
	rig.Jaw = 0.2 * bump(0.2, 0.8, u)
	-- the rider slides toward the side going down
	local seat = frame * f.Saddle
	local slide = ss(0.1, 0.35, u)
	local rider = seat * CFrame.new(-f.Width * 0.25 * slide, 0, 0) * CFrame.Angles(0, 0, -rad(25) * slide)
	return { Fish = frame, Rider = rider, Rig = rig, Focus = frame.Position + Vector3.new(0, f.Height * 0.3, 0) }
end

-- a ray noses up and flips: you drop off its underside, and its wings beat you down as it comes back over
OUTCOMES.Flip = function(f, t)
	local u = math.clamp(t / f.Def.Time, 0, 1)
	local base = carried(f, t, 1.8)
	local over = math.pi * inOut(u / 0.45) + math.pi * inOut((u - 0.55) / 0.45)
	local frame = base * CFrame.new(0, bump(0, 1, u) * 5, 0) * CFrame.Angles(rad(30) * bump(0, 0.6, u), 0, over)
	local rig = still()
	rig.Flare = 0.5 + 0.5 * bump(0, 1, u)
	rig.Thrash = 0.2
	rig.Rate = 1.4
	rig.Arch = -rad(20) * bump(0.3, 0.8, u)
	local seat = frame * f.Saddle
	return { Fish = frame, Rider = seat, Rig = rig, Focus = frame.Position }
end

-- a turtle stops, tucks in and shakes its shell harder and harder, you bounce, then it bucks you off
OUTCOMES.Shell = function(f, t)
	local base = carried(f, t, 4)
	local grow = ss(0.15, 0.95, t) * (1 - ss(1.05, 1.5, t))
	local shake = math.sin(t * 32) * rad(16) * grow
	local buck = bump(0.9, 1.4, t)
	local frame = base
		* CFrame.new(0, buck * 2.5, 0)
		* CFrame.Angles(-rad(12) * ss(0, 0.4, t) + rad(30) * buck, shake * 0.3, shake)
	local rig = still()
	rig.Flare = 0.4 * grow + buck
	rig.Thrash = 0.15
	rig.Jaw = 0.4 * bump(0.85, 1.4, t)
	local seat = frame * f.Saddle
	local hop = math.abs(math.sin(t * 16)) * grow * 1.6
	return { Fish = frame, Rider = seat + Vector3.new(0, hop, 0), Rig = rig, Focus = frame.Position }
end

-- a serpent coils round itself, faster and faster, swinging you on its coil, then flings you out
OUTCOMES.Coil = function(f, t)
	local u = math.clamp(t / f.Def.Time, 0, 1)
	local base = carried(f, t, 2.5)
	local spinU = math.clamp((t - 0.1) / 1.4, 0, 1)
	local spin = TAU * 1.4 * spinU * spinU
		+ (if t > 1.5 then TAU * 1.4 * 2 * (t - 1.5) / 1.4 * (1 - ss(1.5, 1.9, t) * 0.7) else 0)
	local frame = base
		* CFrame.new(0, ss(0, 1.5, t) * 6, 0)
		* CFrame.Angles(0, spin, rad(25) * ss(0, 0.6, t) * (1 - ss(1.5, 1.9, t)))
		* CFrame.Angles(rad(18) * bump(0, 0.5, u), 0, 0)
	local rig = still()
	rig.Curl = rad(220) * ss(0.1, 0.8, t) * (1 - ss(1.45, 1.85, t))
	rig.Thrash = 0.2 + 0.3 * ss(1.4, 1.6, t)
	rig.Rate = 2
	rig.Jaw = 0.3 * bump(0.2, 1.6, t)
	local seat = frame * f.Saddle
	return { Fish = frame, Rider = seat, Rig = rig, Focus = frame.Position }
end

-- a crawler noses down, scrapes you off ahead of it, slams down on you and drags you along the floor
OUTCOMES.Pin = function(f, t)
	local H, L = f.Height, f.Length
	local base = carried(f, t, 2.5)
	local floorY = f.FloorY or (f.From.Position.Y - 20)
	local dive = inOut((t - 0.25) / 0.75)
	local ground = Vector3.new(base.Position.X, floorY + H * 0.5 + 0.5, base.Position.Z)
	local at = base.Position:Lerp(ground, dive)
	-- crawling on along the floor, dragging you
	local crawl = math.max(0, t - 1.1)
	at += flat(f.From.LookVector) * (6 * crawl * ss(1.1, 1.5, t))
	local nose = -rad(35) * bump(0.1, 1.0, t) + rad(8) * bump(1.0, 1.4, t)
	local judder = math.sin(t * 30) * rad(2.5) * bump(0.95, 1.6, t)
	local frame = CFrame.new(at) * base.Rotation * CFrame.Angles(nose + judder, 0, judder)
	local rig = still()
	rig.Flare = 0.6 + 0.4 * math.sin(t * 7) * ss(1.0, 1.3, t)
	rig.Thrash = 0.1
	rig.Arch = -rad(15) * bump(0.2, 1.1, t)
	rig.Jaw = 0.5 * bump(0.8, 2.0, t)
	local seat = frame * f.Saddle
	local slide = ss(0.15, 0.45, t)
	local rider = seat * CFrame.new(0, 0, -L * 0.12 * slide)
	local torso = torsoOf(f)
	return {
		Fish = frame,
		Rider = rider,
		Rig = rig,
		Focus = if torso then torso:Lerp(frame.Position, 0.4) else frame.Position,
	}
end

----------------------------------------------------------------------------------------------------------------------
-- The rider's pose on the fish before coming loose (AnimController.FailPose)

local function braced(t: number): Pose
	local s = math.sin(t * 11)
	return {
		LeftShoulder = rot(120 + 20 * s, 0, -30),
		RightShoulder = rot(120 - 20 * s, 0, 30),
		LeftElbow = rot(20, 0, 0),
		RightElbow = rot(20, 0, 0),
		LeftHip = rot(70, 0, -15),
		RightHip = rot(70, 0, 15),
		LeftKnee = rot(-80, 0, 0),
		RightKnee = rot(-80, 0, 0),
		Waist = rot(-10, 0, 0),
		Neck = rot(-15, 0, 0),
	}
end

local function riderPose(f: Fail, t: number): Pose?
	if f.Kind == "Gulp" then
		-- drawn to the light: arms out to it, leaning in
		local k = ss(0.1, 0.8, t)
		return {
			LeftShoulder = rot(150 * k, 0, -10),
			RightShoulder = rot(150 * k, 0, 10),
			LeftElbow = rot(10, 0, 0),
			RightElbow = rot(10, 0, 0),
			LeftHip = rot(60, 0, -20),
			RightHip = rot(60, 0, 20),
			LeftKnee = rot(-70, 0, 0),
			RightKnee = rot(-70, 0, 0),
			Waist = rot(25 * k, 0, 0),
			Neck = rot(10 * k, 0, 0),
		}
	elseif f.Kind == "Coil" or f.Kind == "Flip" then
		return nil
	end
	return braced(t)
end

----------------------------------------------------------------------------------------------------------------------
-- The loose body (Body): the throw, the water, the fish's solid boxes, its grabs

-- how each outcome throws you (on our own machine, at the moment the body comes loose): the velocity and the tumble
local function throwOf(kind: string, fish: CFrame?, fishVelocity: Vector3): (Vector3, Vector3)
	local r = Config.Fail.Ragdoll
	local look = if fish then fish.LookVector else Vector3.new(0, 0, -1)
	local right = if fish then fish.RightVector else Vector3.new(1, 0, 0)
	local up = Vector3.yAxis
	local back = -flat(look)
	local carry = fishVelocity * 0.35
	local v, spin = Vector3.zero, Vector3.zero
	if kind == "Chomp" then
		v = (up * 0.92 + back * 0.4).Unit * 34
		spin = right * 6
	elseif kind == "Gulp" then
		v = (up * 0.7 + flat(look) * 0.7).Unit * 24
		spin = right * -3
	elseif kind == "Wrap" then
		v = (up * 0.5 + back * 0.85).Unit * 40
		spin = right * r.Spin
	elseif kind == "Roll" then
		v = (-right * 0.75 + up * 0.6).Unit * 58
		spin = look * r.Spin
	elseif kind == "Flip" then
		v = Vector3.new(0, -22, 0) + right * 10
		spin = look * 3
	elseif kind == "Shell" then
		v = (up * 0.85 + back * 0.5).Unit * 66
		spin = right * r.Spin
	elseif kind == "Coil" then
		v = up * 8
	elseif kind == "Pin" then
		v = (flat(look) * 0.9 - up * 0.3).Unit * 30
		spin = right * -5
	else
		v = (back * 0.78 + up * 0.62).Unit * r.Throw
		spin = right * r.Spin
	end
	return v + carry, spin
end

local function makeColliders(b: Body)
	local fish = b.Fish
	if not fish then
		return
	end
	local mouthy = b.Kind == "Chomp" or b.Kind == "Gulp"
	for _, d in fish:GetDescendants() do
		if d:IsA("BasePart") and d ~= fish.PrimaryPart and d.Transparency < 1 then
			local size = d.Size * 0.82
			if size.Magnitude < 1.2 or string.find(d.Name, "_Glow") then
				continue
			end
			local c = Instance.new("Part")
			c.Name = "FailSolid"
			c.Anchored = true
			c.CanCollide = false
			c.CanQuery = false
			c.CanTouch = false
			c.CastShadow = false
			c.Transparency = 1
			c.Size = Vector3.new(math.max(size.X, 0.6), math.max(size.Y, 0.6), math.max(size.Z, 0.6))
			c.CFrame = d.CFrame
			c.Parent = workspace.CurrentCamera
			local name = d.Name
			table.insert(b.Colliders, {
				Part = c,
				Of = d,
				Was = d.Position,
				On = false,
				Mouth = mouthy
					and (string.find(name, "Jaw") ~= nil or name == "Head" or name == "Body" or name == "S1"),
			})
		end
	end
end

local function inside(c: BasePart, p: Vector3, pad: number): boolean
	local o = c.CFrame:PointToObjectSpace(p)
	local h = c.Size / 2 + Vector3.one * pad
	return math.abs(o.X) < h.X and math.abs(o.Y) < h.Y and math.abs(o.Z) < h.Z
end

local function release(b: Body, key: string)
	local h = b.Holds[key]
	if h then
		h.Align:Destroy()
		h.Attachment:Destroy()
		b.Holds[key] = nil
	end
end

-- a grab: the part pulled toward `at` with its own weight and lag (our own machine only: it owns the body)
local function hold(b: Body, key: string, partName: string, at: Vector3, pull: number?, force: number?)
	if not b.Mine then
		return
	end
	local h = b.Holds[key]
	if not h then
		local part = limb(b.Character, partName)
		if not part then
			return
		end
		local r = Config.Fail.Ragdoll
		local a = Instance.new("Attachment")
		a.Name = "FailHold_" .. key
		a.Parent = part
		local align = Instance.new("AlignPosition")
		align.Name = "FailHold_" .. key
		align.Mode = Enum.PositionAlignmentMode.OneAttachment
		align.Attachment0 = a
		align.ApplyAtCenterOfMass = false
		align.Responsiveness = pull or r.Pull
		local mass = 0
		for _, p in b.Parts do
			mass += p.Mass
		end
		align.MaxForce = math.max(mass, 1) * (force or r.PullForce)
		align.Position = at
		align.Parent = part
		h = { Attachment = a, Align = align, Part = part }
		b.Holds[key] = h
	end
	(h :: Hold).Align.Position = at
end

local function endBody(player: Player)
	local b = bodies[player]
	if not b then
		return
	end
	bodies[player] = nil
	for key in b.Holds do
		release(b, key)
	end
	for _, c in b.Colliders do
		c.Part:Destroy()
	end
	if b.Mine and b.Character.Parent then
		local humanoid = b.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:ChangeState(
				if humanoid.PlatformStand
					then Enum.HumanoidStateType.PlatformStanding
					else Enum.HumanoidStateType.GettingUp
			)
		end
	end
	-- (the joints are back: the drown's pose is eased into from where the body lies)
	AnimController.settle(b.Character)
end

local function beginBody(player: Player, fish: Model?, kind: string)
	local character = player.Character
	if not character then
		return
	end
	endBody(player)
	local b: Body = {
		Player = player,
		Character = character,
		Mine = player == State.Player,
		Kind = kind,
		Fish = fish,
		Since = os.clock(),
		Parts = {},
		Main = {},
		Colliders = {},
		Holds = {},
		HitAt = 0,
		MouthOff = false,
	}
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") and d:FindFirstAncestorOfClass("Accessory") == nil then
			table.insert(b.Parts, d)
		end
	end
	for _, name in { "Torso", "Lower", "Head", "LArm", "RArm", "LLeg", "RLeg" } do
		local p = limb(character, name)
		if p and not table.find(b.Main, p) then
			table.insert(b.Main, p)
		end
	end
	bodies[player] = b
	if not b.Mine then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	end
	local root = rootOf(character)
	if root then
		for _, name in { "Float", "FloatTurn" } do
			local c = root:FindFirstChild(name)
			if c then
				c:Destroy()
			end
		end
	end
	-- the throw
	local fishRoot = fish and fish.PrimaryPart
	local velocity, spin = throwOf(
		kind,
		if fishRoot then fishRoot.CFrame else nil,
		if fishRoot then fishRoot.AssemblyLinearVelocity else Vector3.zero
	)
	for _, p in b.Parts do
		p.AssemblyLinearVelocity = velocity
		p.AssemblyAngularVelocity = spin
	end
	makeColliders(b)
	if fishRoot then
		Fx.burst(fishRoot.Position:Lerp(root and root.Position or fishRoot.Position, 0.7), 30, nil, 4)
	end
end

local function stepBody(b: Body, dt: number)
	if not b.Mine or dt <= 0 then
		return
	end
	local r = Config.Fail.Ragdoll
	-- the water: it holds most of the weight up and slows everything (each assembly once)
	local lift = workspace.Gravity * r.Float * dt
	local keep = math.exp(-r.Drag * dt)
	for _, p in b.Parts do
		if p.AssemblyRootPart == p then
			p.AssemblyLinearVelocity = p.AssemblyLinearVelocity * keep + Vector3.new(0, lift, 0)
			p.AssemblyAngularVelocity = p.AssemblyAngularVelocity * keep
		end
	end
	-- never left under the lane's floor
	local torso = limb(b.Character, "Torso")
	if torso then
		local laneY = Course.laneFloor(torso.Position)
		if laneY and torso.Position.Y < laneY - 2 then
			b.Character:PivotTo(b.Character:GetPivot() + Vector3.new(0, laneY + 3 - torso.Position.Y, 0))
		end
	end
	-- the fish's solid boxes follow its parts (with their speed, so a sweep of its side hits), and each comes on only
	-- once no part of the body is inside it (no pop out of the saddle)
	local now = os.clock()
	for _, c in b.Colliders do
		if not c.Of.Parent then
			c.Part.CanCollide = false
			continue
		end
		local cf = c.Of.CFrame
		local velocity = (cf.Position - c.Was) / dt
		c.Was = cf.Position
		c.Part.CFrame = cf
		c.Part.AssemblyLinearVelocity = velocity
		local wanted = not (c.Mouth and b.MouthOff)
		if wanted and not c.On and now - b.Since > 0.08 then
			local clear = true
			for _, p in b.Main do
				if inside(c.Part, p.Position, 1) then
					clear = false
					break
				end
			end
			c.On = clear
		elseif not wanted then
			c.On = false
		end
		c.Part.CanCollide = c.On
		-- a hit: a part of the body against it, fast
		if c.On and now - b.HitAt > 0.3 then
			for _, p in b.Main do
				if inside(c.Part, p.Position, 0.9) and (p.AssemblyLinearVelocity - velocity).Magnitude > r.HitSpeed then
					b.HitAt = now
					Fx.burst(p.Position, 14, 0.4, 3)
					Fx.sound("Pop", p)
					Shake.play("Crash", 0.5)
					break
				end
			end
		end
	end
end

----------------------------------------------------------------------------------------------------------------------
-- The fish's grabs, by outcome (our own machine: AlignPositions on the loose body)

local function grabs(f: Fail, b: Body, t: number, fishNow: CFrame)
	local L, H = f.Length, f.Height
	local kind = f.Kind
	if kind == "Chomp" then
		-- the jaws take you: pulled into the mouth, then deeper
		if t >= 1.12 then
			b.MouthOff = true
			local deep = ss(1.3, 1.7, t)
			local at = (fishNow * mouthOf(f) * CFrame.new(0, 0, L * 0.25 * deep)).Position
			hold(b, "Mouth", "Torso", at, 22 + 20 * deep, 1400)
		end
	elseif kind == "Gulp" then
		-- the suction: drawn in, slow and then all at once
		if t >= 1.0 then
			b.MouthOff = true
			local deep = ss(1.45, 1.8, t)
			local at = (fishNow * mouthOf(f) * CFrame.new(0, 0, L * 0.3 * deep)).Position
			hold(b, "Mouth", "Torso", at, 8 + 30 * ss(1.0, 1.5, t), 900)
		end
	elseif kind == "Wrap" then
		-- each arm, once it has hold, hauls its limb in under the body, with weight and lag
		for i, tent in f.Tentacles do
			if t >= tent.Grab then
				local spot = fishNow
					* CFrame.new(math.cos(i * 1.7) * f.Width * 0.25, -H * 0.45, -L * 0.1 + math.sin(i * 1.3) * 3)
				local haul = ss(tent.Grab, tent.Grab + 0.9, t)
				local part = limb(b.Character, tent.Target)
				local from = if part then part.Position else spot.Position
				hold(b, "Arm" .. i, tent.Target, from:Lerp(spot.Position, 0.35 + 0.65 * haul), 10 + 8 * haul, 450)
			end
		end
	elseif kind == "Coil" then
		-- held on its coil, swung round with it, then flung
		if t < 1.5 then
			local spot = fishNow * CFrame.new(f.Width * 0.9, H * 0.2, L * 0.05)
			hold(b, "Coil", "Torso", spot.Position, 16, 700)
		elseif not f.Released then
			f.Released = true
			release(b, "Coil")
			local torso = limb(b.Character, "Torso")
			if torso then
				local away = flat(torso.Position - fishNow.Position)
				local fling = away * 75 + Vector3.new(0, 22, 0)
				for _, p in b.Parts do
					p.AssemblyLinearVelocity = fling
					p.AssemblyAngularVelocity = fishNow.UpVector * 9
				end
			end
		end
	elseif kind == "Pin" then
		-- slammed under its head and dragged along the floor by it, the legs trailing
		if t >= 0.85 then
			local floorY = f.FloorY or (f.From.Position.Y - 20)
			local under = fishNow * CFrame.new(0, -H * 0.4, -L * 0.3)
			local at = Vector3.new(under.Position.X, math.max(floorY + 1.2, under.Position.Y), under.Position.Z)
			hold(b, "Pin", "Torso", at, 14 + 14 * ss(0.85, 1.2, t), 700)
			local feet = fishNow * CFrame.new(0, -H * 0.4, L * 0.05)
			hold(b, "Drag", "LLeg", Vector3.new(feet.Position.X, floorY + 1, feet.Position.Z), 6, 160)
		end
	end
end

----------------------------------------------------------------------------------------------------------------------
-- The props (every machine, local only)

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

local TENTACLE_SEGS = 14

local function makeProps(f: Fail)
	if f.Kind == "Gulp" then
		local ball = localPart(Vector3.one * (1 + f.Length * 0.05), Color3.fromRGB(255, 244, 170), Enum.Material.Neon)
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
		local colour = (if kind then kind.Fin else Color3.fromRGB(150, 60, 90)):Lerp(Color3.fromRGB(70, 20, 50), 0.25)
		-- the rig's arm tips they shoot from (the last segment of each arm), else the underside
		local tips: { BasePart } = {}
		for _, j in f.Joints do
			if j.Kind == "arm" and j.Depth >= 3 then
				table.insert(tips, j.Part)
			end
		end
		local targets = { "LArm", "RArm", "LLeg", "RLeg", "Torso", "Lower" }
		for i, target in targets do
			local segs: { BasePart } = {}
			for _ = 1, TENTACLE_SEGS do
				local seg = localPart(Vector3.one, colour, Enum.Material.SmoothPlastic)
				seg.Shape = Enum.PartType.Cylinder
				seg.Name = "Tentacle" .. i
				seg.Transparency = 1
				table.insert(segs, seg)
				table.insert(f.Props, seg)
			end
			local start = 0.72 + (i - 1) * 0.07
			table.insert(f.Tentacles, {
				Segs = segs,
				From = if #tips > 0 then tips[(i * 3 - 1) % #tips + 1] else nil,
				Target = target,
				Start = start,
				Grab = start + 0.32,
				Phase = i * 1.9,
				Thick = (0.9 + f.Length * 0.025) * (if target == "Torso" or target == "Lower" then 1.25 else 1),
			})
		end
	end
end

-- a point along a curve from a to b bending through c (0 to 1)
local function bezier(a: Vector3, c: Vector3, b: Vector3, u: number): Vector3
	return a:Lerp(c, u):Lerp(c:Lerp(b, u), u)
end

local function updateTentacles(f: Fail, fishNow: CFrame, t: number)
	for _, tent in f.Tentacles do
		local part = limb(f.Character, tent.Target)
		local base = if tent.From and tent.From.Parent
			then (tent.From.CFrame * CFrame.new(0, 0, tent.From.Size.Z * 0.45)).Position
			else (fishNow * CFrame.new(0, -f.Height * 0.4, 0)).Position
		local shoot = Ease.outQuad(math.clamp((t - tent.Start) / 0.32, 0, 1))
		local wrap = ss(tent.Grab, tent.Grab + 0.45, t)
		if shoot <= 0 or not part then
			for _, seg in tent.Segs do
				seg.Transparency = 1
			end
			continue
		end
		local target = part.Position
		-- the way out whips through a point off to the side, then settles straight
		local mid = base:Lerp(target, 0.5)
			+ Vector3.new(math.sin(tent.Phase) * 6, 5 + math.cos(tent.Phase) * 3, math.cos(tent.Phase * 1.3) * 6)
				* (1 - wrap * 0.7)
		local points: { Vector3 } = {}
		local n = TENTACLE_SEGS
		-- the last share of it coils round the limb (a helix about its length), tightening as it takes hold
		local coilShare = 0.45 * wrap
		local reach = shoot
		local axis = part.CFrame
		local radius = math.max(part.Size.X, part.Size.Z) * 0.5 + tent.Thick * 0.35 + (1 - wrap) * 1.2
		local lengthOf = part.Size.Y
		for s = 0, n do
			local u = s / n * reach
			local p: Vector3
			if u > 1 - coilShare and coilShare > 0.01 then
				local k = (u - (1 - coilShare)) / coilShare
				local a = tent.Phase + k * TAU * 1.6 + t * 1.5 * (1 - wrap)
				local along = (k - 0.5) * lengthOf * 0.9
				p = (axis * CFrame.new(math.cos(a) * radius, along, math.sin(a) * radius)).Position
			else
				local wiggle = math.sin(u * 9 - t * 7 + tent.Phase) * 0.8 * (1 - wrap)
				p = bezier(base, mid, target, u / math.max(1 - coilShare, 0.01)) + Vector3.new(0, wiggle, 0)
			end
			points[s + 1] = p
		end
		for s, seg in tent.Segs do
			local a, b2 = points[s], points[s + 1]
			local span = (b2 - a).Magnitude
			if span < 0.05 then
				seg.Transparency = 1
			else
				local thick = tent.Thick * Ease.lerp(1.15, 0.45, s / n)
				seg.Transparency = 0
				seg.Size = Vector3.new(span + thick * 0.6, thick, thick)
				seg.CFrame = CFrame.lookAt((a + b2) / 2, b2) * CFrame.Angles(0, math.pi / 2, 0)
			end
		end
	end
end

-- the dark closing in, with arms reaching over the screen (the kraken's)
local SHADE_ARMS = 7
local SHADE_DOTS = 16

local function makeShade(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "FailShade"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 39
	gui.ResetOnSpawn = false
	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.BorderSizePixel = 0
	dim.BackgroundColor3 = Color3.fromRGB(10, 2, 16)
	dim.BackgroundTransparency = 1
	dim.Size = UDim2.fromScale(1, 1)
	dim.Parent = gui
	for i = 1, SHADE_ARMS do
		local arm = Instance.new("Folder")
		arm.Name = "Arm" .. i
		arm.Parent = gui
		for k = 1, SHADE_DOTS do
			local dot = Instance.new("Frame")
			dot.Name = tostring(k)
			dot.BorderSizePixel = 0
			dot.BackgroundColor3 = Color3.fromRGB(22, 5, 30):Lerp(Color3.fromRGB(70, 18, 60), k / SHADE_DOTS * 0.5)
			dot.AnchorPoint = Vector2.new(0.5, 0.5)
			dot.SizeConstraint = Enum.SizeConstraint.RelativeYY
			dot.BackgroundTransparency = 1
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.5, 0)
			corner.Parent = dot
			dot.Parent = arm
		end
	end
	gui.Parent = State.Player:WaitForChild("PlayerGui")
	return gui
end

local function updateShade(gui: ScreenGui, t: number, from: number, to: number)
	local camera = workspace.CurrentCamera
	local aspect = camera.ViewportSize.X / math.max(camera.ViewportSize.Y, 1)
	local dim = gui:FindFirstChild("Dim") :: Frame?
	if dim then
		dim.BackgroundTransparency = 1 - 0.55 * ss(from, to, t)
	end
	for i = 1, SHADE_ARMS do
		local arm = gui:FindFirstChild("Arm" .. i)
		if not arm then
			continue
		end
		local start = from + (i - 1) * 0.12
		local grow = Ease.outQuad(math.clamp((t - start) / 1.1, 0, 1))
		-- from the edge (round the screen, never the middle of the top), curling in
		local angle = (i - 0.5) / SHADE_ARMS * TAU + 0.4
		local ex, ey = math.cos(angle), math.sin(angle)
		local scale = 1 / math.max(math.abs(ex) / aspect, math.abs(ey)) -- (to the screen's edge, in screen heights)
		local edge = Vector2.new(0.5 + ex * scale * 0.5 / aspect * 1.08, 0.5 + ey * scale * 0.5 * 1.08)
		local inward = (Vector2.new(0.5, 0.5) - edge)
		local perp = Vector2.new(-inward.Y, inward.X)
		for k = 1, SHADE_DOTS do
			local dot = arm:FindFirstChild(tostring(k)) :: Frame?
			if not dot then
				continue
			end
			local u = (k - 1) / (SHADE_DOTS - 1)
			local reach = u * grow * 0.62
			local wave = math.sin(u * 6 - t * 2.6 + i) * 0.09 * u
			-- the tip curls round
			local curl = ss(0.7, 1, u) * grow
			local p = edge + inward * reach + perp * (wave + curl * 0.06 * math.sin(i))
			dot.Position = UDim2.fromScale(p.X, p.Y)
			local size = Ease.lerp(0.2, 0.035, u) * (0.6 + 0.4 * grow)
			dot.Size = UDim2.fromScale(size, size)
			dot.BackgroundTransparency = if reach > 0.005 or u == 0 then 0.05 + 0.9 * (1 - grow) else 1
		end
	end
end

----------------------------------------------------------------------------------------------------------------------
-- The shot: one move to it, eased in and out, then held. Where it stands round the fish's way as it began (Side:
-- across it, on the side we were already on; Back: behind; Up: above, below for a low angle), and how far (Far, in
-- the fish's own size). It never comes closer to the fish than its own length.
local SHOTS: { [string]: { Side: number, Back: number, Up: number, Far: number, Ahead: number } } = {
	Chomp = { Side = 1, Back = -0.15, Up = 0.22, Far = 1.05, Ahead = 0.3 }, -- side view
	Gulp = { Side = 1, Back = -0.45, Up = 0.12, Far = 0.95, Ahead = 0.4 }, -- side, from a little ahead, the mouth and the lure
	Wrap = { Side = 1, Back = 0.35, Up = 0.38, Far = 1.5, Ahead = 0.1 }, -- wide
	Roll = { Side = 1, Back = 0.25, Up = -0.5, Far = 1.2, Ahead = 0.3 }, -- low angle
	Flip = { Side = 1, Back = 0.2, Up = -0.65, Far = 1.05, Ahead = 0.3 }, -- low, looking up at the belly
	Shell = { Side = 0.8, Back = -0.6, Up = 0.55, Far = 1.0, Ahead = 0.1 }, -- three-quarter front, high
	Coil = { Side = 1, Back = 0.3, Up = 0.6, Far = 1.45, Ahead = 0.2 }, -- wide and high
	Pin = { Side = 0.75, Back = -0.35, Up = 0.9, Far = 1.0, Ahead = 0.4 }, -- high, looking down at the floor
}

local function shotFor(f: Fail, sideSign: number): Vector3
	local s = SHOTS[f.Kind] or SHOTS.Chomp
	local look = flat(f.From.LookVector)
	local right = look:Cross(Vector3.yAxis).Unit
	local anchor = f.From.Position + look * math.min(f.Speed / 2.5, 40) * s.Ahead
	local dir = (right * sideSign * s.Side + -look * s.Back + Vector3.yAxis * s.Up)
	dir = if dir.Magnitude > 0.01 then dir.Unit else right
	local far = (f.Length * 0.48 + 15) * s.Far
	far = math.max(far, f.Length * 0.7 + 8)
	local at = anchor + dir * far
	-- not under the floor, and not behind a wall: brought in to the near side of it
	if f.FloorY then
		at = Vector3.new(at.X, math.max(at.Y, f.FloorY + 5), at.Z)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = { workspace.CurrentCamera }
	for _, name in { "Fish" } do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(skip, folder)
		end
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(skip, player.Character)
		end
	end
	params.FilterDescendantsInstances = skip
	local hit = workspace:Raycast(anchor, at - anchor, params)
	if hit then
		local back = (at - anchor).Unit
		at = hit.Position - back * 4
		if (at - anchor).Magnitude < f.Length * 0.7 + 8 then
			-- too close in: take the other side instead
			local other = anchor + (dir - right * sideSign * s.Side * 2).Unit * far
			local hit2 = workspace:Raycast(anchor, other - anchor, params)
			at = if hit2 then hit2.Position - (other - anchor).Unit * 4 else other
		end
	end
	return at
end

----------------------------------------------------------------------------------------------------------------------

local function weldOf(fishRoot: BasePart, character: Model?): Weld?
	local root = rootOf(character)
	for _, child in fishRoot:GetChildren() do
		if child:IsA("Weld") and child.Name == "RideWeld" and (root == nil or child.Part1 == root) then
			return child
		end
	end
	return nil
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

-- Wild fish between the camera and what it looks at are made see-through (our own screen; LocalTransparencyModifier)
local faded: { [BasePart]: boolean } = {}
local function clearView(f: Fail, from: Vector3, to: Vector3)
	local folder = workspace:FindFirstChild("Fish")
	if not folder then
		return
	end
	local way = to - from
	local span = way.Magnitude
	if span < 1 then
		return
	end
	local dir = way / span
	for _, model in folder:GetChildren() do
		local root = model:IsA("Model") and model.PrimaryPart
		if not root or model == f.Fish then
			continue
		end
		local rel = root.Position - from
		local along = rel:Dot(dir)
		local near = along > 0 and along < span - 2 and (rel - dir * along).Magnitude < root.Size.Magnitude * 0.6 + 6
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				local want = if near then 0.85 else 0
				if want > 0 or faded[d] then
					d.LocalTransparencyModifier = d.LocalTransparencyModifier
						+ (want - d.LocalTransparencyModifier) * 0.25
					faded[d] = if d.LocalTransparencyModifier > 0.01 then true else nil
					if not faded[d] then
						d.LocalTransparencyModifier = 0
					end
				end
			end
		end
	end
end

local function unfade()
	for d in faded do
		if d.Parent then
			d.LocalTransparencyModifier = 0
		end
	end
	table.clear(faded)
end

local function letFishGo(f: Fail)
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
	if fails[player] then
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
	local camera = workspace.CurrentCamera.CFrame
	local right = flat(from.LookVector):Cross(Vector3.yAxis).Unit
	-- the shot: on the side we were already looking from
	local sideSign = if (camera.Position - from.Position):Dot(right) >= 0 then 1 else -1
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
		FloorY = Course.floor(from.Position),
		Hidden = {},
		Props = {},
		Paused = {},
		Driving = false,
		Beats = {},
		Joints = readRig(fish, body.Z),
		Bulge = {},
		Sizes = {},
		Tentacles = {},
		Shade = nil,
		CamStart = camera.Position,
		CamTo = camera.Position,
		Focus = camera.Position + camera.LookVector * (from.Position - camera.Position).Magnitude,
		Pose = nil,
		Last = 0,
		Released = false,
		Trails = {},
		Snap = nil,
		Pull = 0,
	}
	for _, d in fish:GetDescendants() do
		if d:IsA("Trail") and d.Enabled then
			d.Enabled = false
			table.insert(f.Trails, d)
		end
	end
	f.CamTo = shotFor(f, sideSign)
	-- the spine's parts, nose to tail, for the swallow's bulge
	local spine: { Joint } = {}
	for _, j in f.Joints do
		if j.Kind == "spine" and j.Part:IsA("MeshPart") then
			table.insert(spine, j)
		end
	end
	table.sort(spine, function(a, b)
		return a.Z < b.Z
	end)
	for _, j in spine do
		table.insert(f.Bulge, j.Part)
		f.Sizes[j.Part] = j.Part.Size
	end
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
	Fx.sound(def.Sound, fishRoot)
end

function FailController.stop(player: Player)
	local f = fails[player]
	if not f then
		return
	end
	fails[player] = nil
	letFishGo(f)
	unhide(f)
	unposeRig(f)
	for _, trail in f.Trails do
		if trail.Parent then
			trail.Enabled = true
		end
	end
	if f.Mine then
		unfade()
	end
	if f.Weld and f.Weld.Parent then
		f.Weld.C0 = f.Saddle
	end
	for _, p in f.Props do
		p:Destroy()
	end
	if f.Shade then
		f.Shade:Destroy()
	end
	if f.Mine and player:GetAttribute("State") ~= "Drowning" then
		-- (the drown takes these over itself; the dock, or a fail with no failing, gets them back as they were)
		State.DeathCam = nil
		State.Darken = 0
		State.Vignette = 0
	end
end

-- the moments: the bite, the slam, the splash (once each, every machine; the shake on our own)
local BEATS: { [string]: { { At: number, Name: string } } } = {
	Chomp = { { At = 1.27, Name = "bite" } },
	Gulp = { { At = 1.6, Name = "bite" } },
	Wrap = { { At = 1.05, Name = "grab" }, { At = 1.7, Name = "dive" } },
	Roll = { { At = 0.95, Name = "splash" } },
	Flip = { { At = 1.15, Name = "splash" } },
	Shell = { { At = 1.05, Name = "buck" } },
	Coil = { { At = 1.5, Name = "fling" } },
	Pin = { { At = 1.0, Name = "slam" } },
}

local function beat(f: Fail, name: string, fishNow: CFrame, riderPos: Vector3)
	if name == "bite" then
		Fx.sound("Chomp", f.FishRoot)
		Fx.burst((fishNow * mouthOf(f)).Position, 30, nil, 6)
		if f.Mine then
			Shake.play("Crash")
		end
	elseif name == "slam" then
		Fx.sound("Rumble", f.FishRoot)
		local floorY = f.FloorY or riderPos.Y
		Fx.burst(Vector3.new(fishNow.Position.X, floorY + 1, fishNow.Position.Z), 60, nil, f.Length * 0.6)
		if f.Mine then
			Shake.play("LandBig")
		end
	elseif name == "grab" or name == "dive" then
		Fx.sound("Rumble", f.FishRoot)
		if f.Mine then
			Shake.play(if name == "dive" then "LandBig" else "Crash", 0.7)
		end
	else
		Fx.sound(if name == "buck" then "Pop" else "Splash", f.FishRoot)
		Fx.burst(fishNow.Position, 60, 0.3, f.Length * 0.5)
		if f.Mine then
			Shake.play("LandBig")
		end
	end
end

local function step(dt: number)
	local clock = os.clock()
	-- the loose bodies first (the physics' own help), then the outcomes
	for player, b in bodies do
		local character = player.Character
		if player.Parent == nil or character ~= b.Character or not b.Character:GetAttribute("Ragdoll") then
			endBody(player)
		else
			stepBody(b, dt)
		end
	end
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
		local stepT = math.max(0, t - f.Last)
		f.Last = t
		local frame = OUTCOMES[f.Kind](f, math.min(t, def.Time + (if taken then def.Time else 0.3)))
		local weld = f.Weld
		if weld and weld.Parent == nil then
			weld = nil
			f.Weld = nil
		end
		-- the fish: ours to move through the outcome (it holds us, then lets go: the server's throwOff)
		if f.Driving and f.Mine then
			if t < def.Time + (if taken then def.Time else 0.05) then
				f.FishRoot.CFrame = frame.Fish
				f.FishRoot.AssemblyLinearVelocity = Vector3.zero
				f.FishRoot.AssemblyAngularVelocity = Vector3.zero
			else
				letFishGo(f)
			end
		end
		local fishNow = f.FishRoot.CFrame
		-- its own parts (every machine)
		poseRig(f, frame.Rig, t)
		-- the rider, still on the saddle (everyone works out the same), then loose
		local b = bodies[player]
		if weld then
			weld.C0 = if frame.Rider then fishNow:Inverse() * frame.Rider else f.Saddle
			f.Pose = riderPose(f, t)
		else
			f.Pose = nil
		end
		local torso = limb(f.Character, "Torso")
		local riderPos = if torso then torso.Position else (fishNow * f.Saddle).Position
		if b and b.Mine then
			grabs(f, b, t, fishNow)
		end
		-- swallowed: out of sight, and the throat bulges
		if f.Kind == "Chomp" or f.Kind == "Gulp" then
			local gone = if f.Kind == "Chomp" then 1.62 else 1.78
			if t >= gone and next(f.Hidden) == nil then
				hide(f)
			end
			bulge(f, t, gone + 0.05, gone + 0.7)
		end
		-- props
		if f.Kind == "Gulp" then
			local ball = f.Props[1] :: BasePart?
			if ball then
				local glow = ss(0, 0.6, t) * (1 - ss(1.5, 1.9, t))
				local pulse = 0.75 + 0.25 * math.sin(t * 10)
				ball.CFrame = lurePlace(fishNow, f)
				ball.Transparency = 1 - math.max(0.1, glow)
				local light = ball:FindFirstChildOfClass("PointLight")
				if light then
					light.Brightness = 7 * glow * pulse
				end
			end
		elseif f.Kind == "Wrap" then
			updateTentacles(f, fishNow, t)
		end
		local beats: { { At: number, Name: string } } = BEATS[f.Kind] or {}
		for _, m in beats do
			if t >= m.At and t - stepT < m.At + 0.5 and not f.Beats[m.Name] then
				f.Beats[m.Name] = true
				beat(f, m.Name, fishNow, riderPos)
			elseif t >= m.At then
				f.Beats[m.Name] = true
			end
		end
		if not f.Mine then
			continue
		end
		-- our own: the shot (one move, then held), the dark and the fade
		local move = inOut(t / math.max(Config.Fail.CameraTime, 0.05))
		local at = f.CamStart:Lerp(f.CamTo, move)
		-- (never into the fish: kept a length off it)
		local off = at - fishNow.Position
		local least = f.Length * 0.75 + 6
		if off.Magnitude < least then
			at = fishNow.Position + (if off.Magnitude > 0.1 then off.Unit else Vector3.yAxis) * least
		end
		local subject = frame.Focus or riderPos:Lerp(fishNow.Position, 0.5)
		f.Focus = f.Focus:Lerp(subject, Ease.alpha(4, math.max(stepT, dt)))
		-- the rider and the fish both kept in the shot: backed off along its line as they draw apart (smoothly)
		local spread = (riderPos - fishNow.Position).Magnitude + f.Length * 0.5
		local need = spread * 0.5 / math.tan(rad(workspace.CurrentCamera.FieldOfView / 2)) * 1.15
		local away = at - f.Focus
		if away.Magnitude > 0.1 then
			f.Pull = Ease.lerp(f.Pull, math.max(0, need - away.Magnitude), Ease.alpha(2.5, math.max(stepT, dt)))
			at += away.Unit * f.Pull
		end
		State.DeathCam = { Position = at, Focus = f.Focus }
		local u = math.clamp(t / math.max(def.Time, 0.01), 0, 1)
		State.Darken = 0.3 * u
		State.Vignette = 0.35 * u
		-- wild fish that swim into the shot are see-through while they are in it
		clearView(f, at, f.Focus)
		if f.Kind == "Wrap" then
			local shade = f.Shade or makeShade()
			f.Shade = shade
			updateShade(shade, t, 1.0, def.Time)
		end
		if taken and t >= def.Time then
			State.Fade = math.clamp((t - def.Time) / math.max(Config.Fail.TakenFade, 0.05), 0, 1)
			State.FadeText = def.Text
		end
	end
end

function FailController.Init()
	Net.Fx.OnClientEvent:Connect(function(kind: string, player: Player, fish: Model?, outcome: string)
		if typeof(player) ~= "Instance" or not player:IsA("Player") then
			return
		end
		if kind == "Fail" and typeof(fish) == "Instance" and type(outcome) == "string" then
			begin(player, fish :: Model, outcome)
		elseif kind == "Ragdoll" then
			-- loose (RideService): a fish's Fail already playing keeps its fish, else the one we were thrown from
			beginBody(
				player,
				if typeof(fish) == "Instance" then fish :: Model else nil,
				if type(outcome) == "string" then outcome else "Throw"
			)
		end
	end)
	-- the rider's pose on the fish, for AnimController
	AnimController.FailPose = function(player: Player)
		local f = fails[player]
		return if f then f.Pose else nil
	end
	-- our own: no input while the fish does its thing (the ride's drive and steering stop: State.Mode "Failing")
	State.Player:GetAttributeChangedSignal("State"):Connect(function()
		if State.Player:GetAttribute("State") == "Failing" then
			State.setMode("Failing")
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		FailController.stop(player)
		endBody(player)
	end)
end

function FailController.Start()
	-- before the drown's step (DeathController, Camera - 3), so it takes the shot over on the same frame
	RunService:BindToRenderStep("RideFail", Enum.RenderPriority.Camera.Value - 4, step)
end

return FailController
