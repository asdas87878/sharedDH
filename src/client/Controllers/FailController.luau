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
--   swallowed, the throat bulges, and the outcome's props are made locally (the angler's lure, the screen dimming
--   dark; the kraken wraps you in its own arms, not made ones, and the dark arms over the screen were taken out:
--   Hugo, 2026-11-19).
-- A "Throw" outcome ends in the throw and the drown (DeathController, which leaves a loose body to the physics until its
-- joints are back); a "Taken" one is the fail itself and fades to the fail screen (State.Fade, FadeText).
-- The words of a failed run are drawn here too (Kit.failWords, the Bubble letters; "The words" below): what the
-- deaths set in State.FadeText comes through Banners.miss and Kit.FailShow.
-- A kind in Config.Fail.NewEat plays its new move instead (Lib/EatMoves: the fish's path, the rider's arc and the joints;
-- f.New here): everything below that asks for f.New is that, and nothing else changes for the rest.
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
local EatMoves = require(script.Parent.Parent.Lib.EatMoves)
local Fx = require(script.Parent.Parent.Lib.Fx)
local Shake = require(script.Parent.Parent.Lib.Shake)
local State = require(script.Parent.Parent.Lib.State)
local Underwater = require(script.Parent.Parent.Lib.Underwater)
local Kit = require(script.Parent.Parent.UI.Kit)
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
	Parent: string, -- the part it hangs from (its chain's links)
	Chain: number?, -- an arm's: which of the fish's own arms it is (f.Chains), and which link of it
	Link: number?,
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
type Hold = { Attachment: Attachment, Align: AlignPosition, Part: BasePart, Mass: number }
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
	New: boolean, -- (Config.Fail.NewEat) its fish plays a new eating move
	MouthOff: boolean, -- the boxes round the mouth are off (it is being swallowed)
	Recording: Take?, -- (Studio: this live run is being recorded)
	Replay: boolean, -- (Studio: this one is a playback: no physics of ours)
}

-- One of the fish's own arms (an octopus's, a crawler's claws), its joints root to tip (Hugo, 2026-11-19: "use the
-- actual tentacles from the model, don't add new ones"). Posed by a little inverse kinematics in the fish's own
-- space: each link's turn worked out so the tip reaches its target, from the rest pivots of Shared/Creatures.
type Chain = {
	Joints: { Joint },
	Rest: { Vector3 }, -- the pivots at rest, and the tip after them (fish space)
	Turns: { CFrame }, -- this frame's turn of each link against the one before
	Live: boolean, -- posed by the kinematics this frame
	Target: string?, -- the limb it takes
	Start: number, -- seconds in it reaches out
	Grab: number, -- and takes hold
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
	Chains: { Chain },
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
	Beak: Vector3, -- an octopus's beak, in the fish's space (among the roots of its arms)
	FishAt: Vector3?, -- where we last put the fish (its next move is kept in open water from there)
	-- the mouth found on the model (Fail.MouthFromModel; nil: the old guess off the box), in the fish's space, and
	-- the open mouth's room round it (for the checks); the angler's lure: its part and the bulb on it
	Mouth: CFrame?,
	MouthRoom: Vector3?,
	Lure: { Part: BasePart, Bulb: CFrame, Rest: CFrame }?,
	-- (Fail.Arrive) the seconds the outcome's own clock has waited for the body (the bite and the swallow), slowed;
	-- the outcome's clock is the real one less Wait
	Wait: number,
	Rate: number, -- (Fail.Arrive) the fish's clock's pace now (1: real time)
	U: number, -- the outcome's clock this frame
	-- (for the checks) when the pull began, the bite and the swallow came, and how far the body was from the mouth then
	GrabAt: number?,
	BiteAt: number?,
	BiteFar: number?,
	HideAt: number?,
	HideFar: number?,
	Dials: { Mouth: boolean, Arrive: boolean, Smooth: boolean }, -- Config.Fail's, read as it began
	-- (Config.Fail.NewEat) its new eating move (nil: the old one), the mantle it squeezes and its own size, the view's way
	-- as it began and the side the shot takes, the point the shot hangs from, and how far off it stood
	New: EatMoves.Plan?,
	Mantle: BasePart?,
	MantleSize: Vector3?,
	CamFrom: Vector3,
	CamSide: number,
	CamLeast: number,
	Pivot: Vector3,
	Aim: Vector3, -- (Chomp) studs its path is moved by, to meet the body where it really is
	TakenAt: Vector3?, -- where the body was as it was bitten
	ArmsHeld: EatMoves.ArmsHeld, -- (New, Wrap) how far each of its arms has closed
	Slip: Vector3, -- studs the sea bed or a wall holds it off its path by
}

local fails: { [Player]: Fail } = {}
local bodies: { [Player]: Body } = {}

-- Studio only, for the captures (tools/studio/fail_live_capture.py): Studio redraws a hidden window about once a
-- second, so a live run can't be filmed. A live run is recorded instead (workspace FailRecord: every part of the loose
-- body, each frame, in the fish's space as the fail began), and played back on the next one of that kind
-- (FailReplay) at the held clocks (FailClock, DeathClock), the body posed from the recording.
type Take = { Frames: { { T: number, Parts: { [string]: CFrame } } } }
local takes: { [string]: Take } = {}
type Last = { Kind: string, Base: CFrame }
local lastOf: { [Player]: Last } = {} -- our own last fail or throw: its kind, and the frame its recording is in
local replayed: { [Instance]: boolean } = {} -- joints switched off and parts anchored by the playback (to put back)
local function studio(name: string): boolean
	return RunService:IsStudio() and workspace:GetAttribute(name) == true
end

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
			or string.find(name, "Claw") ~= nil
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
			Parent = parent,
			Chain = nil,
			Link = nil,
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

-- The fish's own arms, found once: each chain from a first segment (Depth 1) out through its children
local function readChains(joints: { Joint }): { Chain }
	local byParent: { [string]: Joint } = {}
	for _, j in joints do
		if j.Kind == "arm" and j.Depth > 1 then
			byParent[j.Parent] = j
		end
	end
	local chains: { Chain } = {}
	for _, j in joints do
		if j.Kind == "arm" and j.Depth == 1 then
			local list: { Joint } = {}
			local at: Joint? = j
			while at and #list < 8 do
				table.insert(list, at)
				at = byParent[at.Name]
			end
			local rest: { Vector3 } = {}
			for _, link in list do
				table.insert(rest, link.Pivot)
			end
			-- the tip: on past the last pivot by the last link's own length (or its part's, for a one-link claw)
			local last = list[#list]
			local before = if #list > 1 then list[#list - 1].Pivot else nil
			local length = if before then (last.Pivot - before).Magnitude else last.Part.Size.Magnitude * 0.8
			table.insert(rest, last.Pivot + last.Dir * length)
			table.insert(chains, {
				Joints = list,
				Rest = rest,
				Turns = {},
				Live = false,
				Target = nil,
				Start = 0,
				Grab = 0,
			})
			for i, link in list do
				link.Chain = #chains
				link.Link = i
			end
		end
	end
	return chains
end

-- Where a chain's tip is with these absolute turns of its links (fish space)
local function chainTip(chain: Chain, abs: { CFrame }): Vector3
	local at = chain.Rest[1]
	for i = 1, #chain.Joints do
		at += abs[i] * (chain.Rest[i + 1] - chain.Rest[i])
	end
	return at
end

-- and where it is as posed this frame
local function tipNow(chain: Chain): Vector3
	local abs: { CFrame } = {}
	local acc = CFrame.identity
	for i = 1, #chain.Joints do
		acc = acc * (chain.Turns[i] or CFrame.identity)
		abs[i] = acc
	end
	return chainTip(chain, abs)
end

-- Reach for `target` (fish space), `w` of the way from rest: cyclic coordinate descent, each link turned at most
-- 75 degrees against the one before, so it bends like an arm and never folds through itself
local function reach(chain: Chain, target: Vector3, w: number)
	local n = #chain.Joints
	local abs: { CFrame } = table.create(n, CFrame.identity)
	for _ = 1, 10 do
		for i = n, 1, -1 do
			local pivot = chain.Rest[1]
			for k = 1, i - 1 do
				pivot += abs[k] * (chain.Rest[k + 1] - chain.Rest[k])
			end
			local a, b = chainTip(chain, abs) - pivot, target - pivot
			if a.Magnitude > 0.01 and b.Magnitude > 0.01 then
				local turn = turnTo(a.Unit, b.Unit, 1, rad(30))
				for k = i, n do
					abs[k] = turn * abs[k]
				end
				local before = if i > 1 then abs[i - 1] else CFrame.identity
				local axis, angle = (before:Inverse() * abs[i]):ToAxisAngle()
				if angle > rad(75) then
					local fix = before * CFrame.fromAxisAngle(axis, rad(75)) * abs[i]:Inverse()
					for k = i, n do
						abs[k] = fix * abs[k]
					end
				end
			end
		end
		if (chainTip(chain, abs) - target).Magnitude < 0.3 then
			break
		end
	end
	local rest = CFrame.identity
	for i = 1, n do
		abs[i] = rest:Lerp(abs[i], w)
	end
	for i = 1, n do
		chain.Turns[i] = if i == 1 then abs[1] else abs[i - 1]:Inverse() * abs[i]
	end
	chain.Live = true
end

-- Which of its own arms take which limb, and where each reaches this frame (every machine works out the same from
-- the body it sees). An octopus: the six nearest you, one after another, each to a limb, then curling back in toward
-- its beak with it. A crawler: its claws to your body, pressing you down under its jaws.
local LIMB_ORDER = { "Torso", "LArm", "RArm", "LLeg", "RLeg", "Lower" }

local function armsStep(f: Fail, t: number)
	for _, chain in f.Chains do
		chain.Live = false
	end
	if #f.Chains == 0 or not f.Character or (f.Kind ~= "Wrap" and f.Kind ~= "Pin") then
		return
	end
	local rootCF = f.FishRoot.CFrame
	local torso = limb(f.Character, "Torso")
	local first = if f.Kind == "Wrap" then 0.55 else 0.7
	if not torso or t < first then
		return
	end
	-- (handed out once: the arms nearest the body as they first reach)
	local given = false
	for _, chain in f.Chains do
		given = given or chain.Target ~= nil
	end
	if not given then
		local torsoLocal = rootCF:PointToObjectSpace(torso.Position)
		local order = table.clone(f.Chains)
		table.sort(order, function(a, b)
			return (a.Rest[#a.Rest] - torsoLocal).Magnitude < (b.Rest[#b.Rest] - torsoLocal).Magnitude
		end)
		local count = math.min(if f.Kind == "Wrap" then 6 else 2, #order)
		for i = 1, count do
			local chain = order[i]
			chain.Target = if f.Kind == "Wrap" then LIMB_ORDER[i] else "Torso"
			chain.Start = first + (i - 1) * 0.07
			chain.Grab = chain.Start + (if f.Kind == "Wrap" then 0.4 else 0.3)
		end
	end
	-- where they haul you: below and behind an octopus's beak, among its arms; under a crawler's jaws
	local home = if f.Kind == "Wrap"
		then f.Beak + Vector3.new(0, -f.Height * 0.3, f.Length * 0.2)
		else Vector3.new(0, -f.Height * 0.4, -f.Length * 0.72)
	for _, chain in f.Chains do
		local target = chain.Target
		local part = if target then limb(f.Character, target) else nil
		if target and part and t >= chain.Start then
			local goal = rootCF:PointToObjectSpace(part.Position)
			if t >= chain.Grab then
				-- (it holds the limb where it is and draws it in: the limb follows the tip, by the grab's pull)
				goal = goal:Lerp(home, ss(chain.Grab, chain.Grab + 1.0, t) * 0.35)
			end
			local w = Ease.outQuad(math.clamp((t - chain.Start) / math.max(chain.Grab - chain.Start, 0.05), 0, 1))
			reach(chain, goal, w)
		end
	end
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
		elseif j.Kind == "arm" and j.Chain and f.Chains[j.Chain].Live then
			-- its own arm reaching for, holding and hauling a limb (armsStep)
			local chain = f.Chains[j.Chain]
			local writhe = math.sin(t * 4 + j.Pivot.X * 0.7 + j.Depth) * rad(4)
			r = (chain.Turns[j.Link :: number] or CFrame.identity) * CFrame.Angles(writhe, 0, 0)
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

-- (Config.Fail.NewEat) The same for a new eating move: its joints from EatMoves, with the swim's own turn of each
-- (Motor6D.Transform, AnimController) taken out, so the jaw and the arms are exactly where they are put and what the
-- rider sits on does not move as they come off it.
local GRIPS = { "LeftUpperLeg", "Left Leg" }
local function gripsOf(f: Fail): { EatMoves.Grip? }
	local rootCF = f.FishRoot.CFrame
	local torso, lower = limb(f.Character, "Torso"), limb(f.Character, "Lower")
	if not torso or not lower then
		return {}
	end
	local legs: Vector3? = nil
	for _, name in GRIPS do
		local left = f.Character and f.Character:FindFirstChild(name)
		local right = f.Character and f.Character:FindFirstChild((string.gsub(name, "Left", "Right")))
		if left and right and left:IsA("BasePart") and right:IsA("BasePart") then
			legs = (left.Position + right.Position) / 2
			break
		end
	end
	local chest = rootCF:PointToObjectSpace(torso.Position)
	local waist = if lower ~= torso
		then rootCF:PointToObjectSpace(lower.Position)
		else rootCF:PointToObjectSpace(torso.CFrame * Vector3.new(0, -0.8, 0))
	local thighs = if legs then rootCF:PointToObjectSpace(legs) else waist + (waist - chest)
	local spine = chest - waist
	spine = if spine.Magnitude > 0.05 then spine.Unit else Vector3.zAxis
	local down = waist - thighs
	down = if down.Magnitude > 0.05 then down.Unit else spine
	return { { At = chest, Along = spine }, { At = waist, Along = spine }, { At = thighs, Along = down } }
end

-- every part of the rider where it is now, in the fish's space
local BODY = {
	"Head",
	"Torso",
	"Left Arm",
	"Right Arm",
	"Left Leg",
	"Right Leg",
	"UpperTorso",
	"LowerTorso",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
}
local function limbsOf(f: Fail): { EatMoves.Link }
	local rootCF = f.FishRoot.CFrame
	local list: { EatMoves.Link } = {}
	for _, name in BODY do
		local part = f.Character and f.Character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			table.insert(list, EatMoves.boxOf(rootCF:ToObjectSpace(part.CFrame), part.Size))
		end
	end
	return list
end

local function poseNew(f: Fail, plan: EatMoves.Plan, u: number, dt: number)
	local rig = EatMoves.rig(plan, u)
	local moves = Config.Fail.EatMoves
	local quiet = ss(0, 0.2, u)
	local all = if f.Kind == "Wrap" then EatMoves.arms(plan, u, dt, gripsOf(f), limbsOf(f), f.ArmsHeld) else {}
	-- (the spine's joints behind the rider bend from the start, those under and ahead of them only once they are off it)
	local seatZ = plan.Given.Saddle.Z / math.max(f.Length, 0.01)
	local behind = 0
	for _, j in f.Joints do
		if j.Kind == "spine" and j.Z > seatZ then
			behind += 1
		end
	end
	for _, j in f.Joints do
		local r = CFrame.identity
		if j.Kind == "jaw" then
			r = CFrame.Angles(-j.Open * rad(moves.JawTurn) * rig.Jaw, 0, 0)
		elseif j.Kind == "arm" and j.Chain and j.Link then
			local abs = all[j.Chain]
			local i = j.Link :: number
			if abs and abs[i] then
				r = if i == 1 then abs[1] else abs[i - 1]:Inverse() * abs[i]
			end
		elseif f.Kind == "Chomp" and j.Kind == "spine" then
			local back = math.clamp((j.Z - seatZ) * 2.2, 0, 1)
			local gulp = EatMoves.gulp(plan, u, j.Z)
			local wave = rig.Sway * math.sin(rig.Beat - j.Z * 5) * (0.2 + 0.8 * back)
			if j.Z > seatZ then
				r = CFrame.Angles(rig.Bunch / math.max(behind, 1) + gulp, wave * 2 / math.max(behind, 1), 0)
			else
				r = CFrame.Angles(gulp, wave * 0.4 * ss(0.6, 0.85, u), 0)
			end
		elseif f.Kind == "Chomp" and j.Kind == "fin" then
			local a = rig.Fins * (if j.Depth > 1 then 0.5 else 1)
			r = if a >= 0
				then CFrame.Angles(rad(28) * a, j.Side * rad(20) * a, j.Side * rad(24) * a)
				else CFrame.Angles(0, j.Side * rad(32) * a, j.Side * rad(6) * a)
		end
		local swim = CFrame.new():Lerp(j.Motor.Transform:Inverse(), quiet)
		j.Motor.C0 = j.C0 * r * swim
	end
	local mantle, size = f.Mantle, f.MantleSize
	if mantle and size then
		local q = rig.Squeeze * moves.Wrap.Squeeze
		mantle.Size = size * Vector3.new(1 - q, 1 - q, 1 + q * 0.8)
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
	if f.Mantle and f.MantleSize and f.Mantle.Parent then
		f.Mantle.Size = f.MantleSize
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

-- the mouth's place on the fish, in the fish's space (found on the model, or the old guess off its box)
local function mouthOf(f: Fail): CFrame
	if f.New and f.Kind == "Chomp" then
		-- (its mouth as the jaw is now)
		return CFrame.new(EatMoves.mouthAt(f.New.Given, EatMoves.chompRig(f.New, f.U).Jaw))
	end
	return f.Mouth or CFrame.new(0, -f.Height * 0.05, -f.Length * 0.47)
end

-- the mouth's pull at `u` seconds into the outcome: the mouth, then on down the throat (world)
local function mouthTarget(f: Fail, fishNow: CFrame, u: number): Vector3
	if f.New and f.Kind == "Chomp" then
		return fishNow * EatMoves.throat(f.New, u)
	end
	local deep = if f.Kind == "Gulp" then f.Length * 0.3 * ss(1.45, 1.8, u) else f.Length * 0.25 * ss(1.3, 1.7, u)
	return (fishNow * mouthOf(f) * CFrame.new(0, 0, deep)).Position
end

-- (Fail.MouthFromModel) The mouth and the lure on the fish's own model (tools/studio/fail_mouth_table.py does the
-- same on the exported meshes, and measures it against the painted mouth). Each part's place at rest, in the root's
-- space, is its joints' offsets (FishModel's Rig_ motors, as they were before we posed them) from the root down; its
-- box is its own size (both already at the fish's size). With jaw parts (named *Jaw*): their box's middle across and
-- along, a quarter down from its top for a lower jaw (up from its bottom for an upper one), its middle for jaws at the
-- sides (a worm's pincers: their reach past the Head's front left out); with none, the Head part's box: 0.3 up from
-- its bottom, 0.4 back from its front; with neither, nil. A fish in Fail.MouthAt: there instead. The lure: its bulb,
-- on the Lure part's end away from its hinge, 0.35 of the way in.
local function mouthFromModel(f: Fail): (CFrame?, Vector3?, { Part: BasePart, Bulb: CFrame, Rest: CFrame }?)
	local byName: { [string]: Joint } = {}
	for _, j in f.Joints do
		byName[j.Name] = j
	end
	local rests: { [string]: CFrame } = {}
	local function restOf(name: string, depth: number): CFrame
		if name == "" or depth > 40 then
			return CFrame.identity
		end
		local known = rests[name]
		if known then
			return known
		end
		local j = byName[name]
		if not j then
			return CFrame.identity
		end
		local rest = restOf(j.Parent, depth + 1) * j.C0 * j.Motor.C1:Inverse()
		rests[name] = rest
		return rest
	end
	local function boxOf(j: Joint): (Vector3, Vector3)
		local cf = restOf(j.Name, 0)
		local half = j.Part.Size / 2
		local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local p = cf * Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)
					lo, hi = lo:Min(p), hi:Max(p)
				end
			end
		end
		return lo, hi
	end
	local id = f.Fish:GetAttribute("Rig")
	local rig = if type(id) == "string" then Creatures.get(id) else nil
	local centre = if rig then 0.05 * rig.Size[1] + 0.05 else 0.05
	local k = if rig then f.Length / math.max(rig.Size[3], 0.01) else 1
	local mouth: CFrame? = nil
	local room: Vector3? = nil
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	local jaws, side, open, hinge = 0, true, 1, Vector3.zero
	for _, j in f.Joints do
		if j.Kind == "jaw" then
			local a, b = boxOf(j)
			lo, hi = lo:Min(a), hi:Max(b)
			jaws += 1
			side = side and math.abs(j.Pivot.X) / k > centre
			if jaws == 1 then
				open = j.Open
				-- (its hinge: the motor's own pivot, in the root's space)
				hinge = (restOf(j.Name, 0) * j.Motor.C1).Position
			end
		end
	end
	if jaws > 0 then
		local mid = (lo + hi) / 2
		local h = hi.Y - lo.Y
		local y = if side then mid.Y elseif open >= 0 then hi.Y - 0.25 * h else lo.Y + 0.25 * h
		local z = mid.Z
		if side and byName.Head then
			-- (pincers close in front of the mouth: their reach past the head's front is not the mouth)
			local front = (boxOf(byName.Head)).Z
			if lo.Z < front and front < hi.Z then
				z = (front + hi.Z) / 2
			end
		end
		mouth = CFrame.new(mid.X, y, z)
		-- the open mouth's room: the jaw's width and length, and the gap its top front corner opens at 58 degrees
		local corner = Vector3.new(0, if open >= 0 then hi.Y else lo.Y, lo.Z)
		local r = Vector2.new(corner.Y - hinge.Y, corner.Z - hinge.Z).Magnitude
		room = Vector3.new(hi.X - lo.X, math.max(2 * r * math.sin(rad(29)), 0.5), hi.Z - lo.Z)
	elseif byName.Head then
		local a, b = boxOf(byName.Head)
		local size = b - a
		mouth = CFrame.new((a.X + b.X) / 2, a.Y + 0.3 * size.Y, a.Z + 0.4 * size.Z)
		-- (nothing opens: the room is the mouth's own share of the head)
		room = Vector3.new(size.X * 0.6, size.Y * 0.3, size.Z * 0.4)
	end
	-- (a model the rule cannot read: its mouth put by hand, Fail.MouthAt, as shares of its box)
	local at = if rig and type(id) == "string" then Config.Fail.MouthAt[id] else nil
	if rig and at then
		mouth = CFrame.new(at[1] * rig.Size[1] * k, at[2] * rig.Size[2] * k, at[3] * rig.Size[3] * k)
	end
	local lure = nil
	for _, j in f.Joints do
		if string.find(j.Name, "Lure") and not string.find(j.Name, "_Glow") then
			-- the hinge in the part's own space is its motor's C1; the bulb is at the far end of its longest reach
			local pivot = j.Motor.C1.Position
			local half = j.Part.Size / 2
			local axis = Vector3.new(-math.sign(pivot.X) * half.X, 0, 0)
			if math.abs(pivot.Y) >= math.abs(pivot.X) and math.abs(pivot.Y) >= math.abs(pivot.Z) then
				axis = Vector3.new(0, -math.sign(pivot.Y) * half.Y, 0)
			elseif math.abs(pivot.Z) >= math.abs(pivot.X) then
				axis = Vector3.new(0, 0, -math.sign(pivot.Z) * half.Z)
			end
			local bulb = CFrame.new(axis * 0.65)
			lure = { Part = j.Part, Bulb = bulb, Rest = restOf(j.Name, 0) * bulb }
			break
		end
	end
	return mouth, room, lure
end

-- turns on you: it rears and tosses you off its back, comes round with its jaws wide, takes you, shakes and swallows
OUTCOMES.Chomp = function(f, t)
	local H = f.Height
	local base = carried(f, t, 2.2)
	local torso = torsoOf(f)
	local rig = still()
	-- the rear and the toss
	local rear = bump(0, 0.9, t) * rad(28)
	local turn = math.pi * inOut((t - 0.35) / 0.7)
	local rise = ss(0.2, 1.0, t) * H * 0.6
	local smooth = f.Dials.Smooth
	if smooth then
		-- (Fail.Smooth: the turn eased gently, slower for a long fish; the rise kept under the surface)
		local fs = Config.Fail
		local stretch = math.clamp(f.Length / math.max(fs.TurnLength, 1), 1, math.max(fs.TurnStretch, 1))
		turn = math.pi * ss(0.35, 0.35 + 0.7 * stretch, t)
		rise = math.min(rise, math.max(0, Config.Depth.SurfaceY - H * 0.5 - base.Position.Y))
	end
	local frame = base * CFrame.new(0, rise, 0) * CFrame.Angles(0, turn, 0) * CFrame.Angles(rear, 0, 0)
	-- round to face you and lunge, so the open mouth meets you as you come down
	local lunge = ss(0.75, 1.25, t)
	if f.Snap and t >= 1.3 then
		-- (from the bite on it goes from where it took you: you are in its mouth now, nothing to aim at)
		frame = f.Snap :: CFrame
	elseif torso and lunge > 0 then
		-- (never straight up: the climb is flattened, and the root put so the mouth lands right on you)
		local aim = (torso - frame.Position) * Vector3.new(1, 0.55, 1)
		aim = if aim.Magnitude > 0.1 then aim.Unit else frame.LookVector
		local look = frame.LookVector:Lerp(aim, lunge)
		look = if look.Magnitude > 0.01 then look.Unit else aim
		local mouthTo = CFrame.lookAt(Vector3.zero, look) * mouthOf(f)
		local at = frame.Position:Lerp(torso - mouthTo.Position, lunge)
		frame = CFrame.lookAt(at, at + look)
	end
	if t >= 1.3 then
		f.Snap = f.Snap or frame
		-- shut: it shakes its head and swims on
		local after = t - 1.3
		local shake = math.sin(after * 18) * rad(16) * math.exp(-after * 2.4)
		local on = travel(f, after, 1.5) * 0.15
		if smooth then
			-- (eased in: from the frame it bit they began at full speed, the head flung round at near 300 degrees a
			-- second and the body off at its swim's speed)
			shake *= ss(0, Config.Fail.ShakeIn, after)
			on *= ss(0, Config.Fail.OnIn, after)
		end
		frame = frame + frame.LookVector * on
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
	-- (on the model's own lure where it has one: Fail.MouthFromModel)
	if f.Lure then
		return fish * f.Lure.Rest
	end
	return fish * CFrame.new(0, f.Height * 0.62 + 1.5, -f.Length * 0.64)
end

OUTCOMES.Gulp = function(f, t)
	local L = f.Length
	local base = carried(f, t, 2.5)
	local hover = math.sin(t * 2.4) * 0.5
	local tilt = rad(10) * ss(0, 0.8, t) + rad(22) * bump(0.8, 1.8, t) - rad(10) * bump(1.6, 2.5, t)
	local frame = base * CFrame.new(0, hover, 0) * CFrame.Angles(tilt, 0, 0)
	if t > 1.7 then
		local on = travel(f, t - 1.7, 1.2) * 0.12
		if f.Dials.Smooth then
			on *= ss(0, Config.Fail.OnIn, t - 1.7) -- (eased in, Fail.Smooth: it began at full speed)
		end
		frame = frame + frame.LookVector * on
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
	-- down and away backward into the dark (along the floor, where the floor is close)
	local fall = math.max(0, t - 1.6)
	local away = 9 * fall * fall + 3 * fall
	local at = base.Position - Vector3.new(0, away * 0.75, 0) - flat(f.From.LookVector) * away * 0.65
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
	local beak = (frame * CFrame.new(f.Beak)).Position
	local focus = if torso then torso:Lerp(beak, 0.12) else beak
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
		Focus = if torso then torso:Lerp(frame.Position, 0.25) else frame.Position,
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
	-- (Fail.Arrive) the way in, mouth to throat in the fish's space: a box near it goes off with the mouth's, or the
	-- body is held outside against a fin or the neck
	local f = fails[b.Player]
	local way: { Vector3 }? = nil
	local root = fish.PrimaryPart
	if mouthy and f and f.Dials.Arrive and root then
		local mouth = mouthOf(f).Position
		way = { mouth, mouth + Vector3.new(0, 0, f.Length * (if b.Kind == "Gulp" then 0.3 else 0.25)) }
	end
	local function nearWay(d: BasePart): boolean
		if not way or not root then
			return false
		end
		local p = root.CFrame:PointToObjectSpace(d.Position)
		local a, c = way[1], way[2]
		local along = math.clamp((p - a):Dot(c - a) / math.max((c - a):Dot(c - a), 1e-3), 0, 1)
		local gap = (p - (a + (c - a) * along)).Magnitude - d.Size.Magnitude * 0.41
		return gap < Config.Fail.ClearAround
	end
	for _, d in fish:GetDescendants() do
		if d:IsA("BasePart") and d ~= fish.PrimaryPart and d.Transparency < 1 then
			local size = d.Size * 0.82
			-- (an octopus's own arms reach for you without batting you away: its shooting arms do the taking)
			local arm = string.match(d.Name, "^[AT]%d+[a-z]$") ~= nil or string.match(d.Name, "^T[RL][a-z]$") ~= nil
			if size.Magnitude < 1.2 or string.find(d.Name, "_Glow") or (arm and b.Kind == "Wrap") then
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
				-- (off while it swallows you; an octopus's all of them once its arms have you)
				Mouth = b.Kind == "Wrap"
					or b.Kind == "Pin"
					or (
						mouthy
						and (
							string.find(name, "Jaw") ~= nil
							or name == "Head"
							or name == "Body"
							or name == "S1"
							or nearWay(d)
						)
					),
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
		h = { Attachment = a, Align = align, Part = part, Mass = math.max(mass, 1) }
		b.Holds[key] = h
	elseif Config.Fail.Arrive ~= 0 or b.New then
		-- (Fail.Arrive: its strength follows every call, so a pull that ramps (the Chomp's from ChompGrabFrom to 22
		-- and on deeper, the Gulp's suction, the Pin's) really ramps; at 0, as before: kept as it was made)
		local r = Config.Fail.Ragdoll
		local held = h :: Hold
		held.Align.Responsiveness = pull or r.Pull
		held.Align.MaxForce = held.Mass * (force or r.PullForce)
	end
	-- (a grab never pulls into the floor or through a wall: its place kept in open water from the part it holds)
	(h :: Hold).Align.Position = Course.clearMove((h :: Hold).Part.Position, at, 1.5)
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
		New = false,
		MouthOff = false,
		Recording = nil,
		Replay = false,
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
	-- (Studio: the frame a recording is kept in: the fish's as the fail began, or as a plain throw left it)
	local playing = fails[player]
	if not playing then
		local from = (fish and fish.PrimaryPart) or rootOf(character)
		lastOf[player] = { Kind = kind, Base = if from then from.CFrame else CFrame.identity }
	end
	if studio("FailReplay") and takes[kind] then
		b.Replay = true
		return
	elseif studio("FailRecord") then
		b.Recording = { Frames = {} }
		takes[kind] = b.Recording
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
	local plan = if playing and playing.Kind == kind then playing.New else nil
	local velocity, spin = throwOf(
		kind,
		if fishRoot then fishRoot.CFrame else nil,
		if fishRoot then fishRoot.AssemblyLinearVelocity else Vector3.zero
	)
	-- (Death.UnderWater: near the surface it goes back more than up)
	velocity = Underwater.shapeThrow(velocity, if root then root.Position else nil)
	if playing and plan then
		-- (Config.Fail.NewEat: it goes on along the arc it is already on, so nothing jumps as it comes loose; and the
		-- mouth's boxes are off from here, the arc goes over them)
		b.New = true
		b.MouthOff = true
		velocity = EatMoves.velocity(plan, playing.U)
		spin = -plan.Level.RightVector * Config.Fail.EatMoves.Spin * (if kind == "Chomp" then 1 else -1)
	end
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
	if not b.Mine or dt <= 0 or b.Replay then
		return
	end
	local take = b.Recording
	local last = lastOf[b.Player]
	if take and last then
		local frame = { T = os.clock() - b.Since, Parts = {} }
		local inverse = last.Base:Inverse()
		for _, p in b.Parts do
			frame.Parts[p.Name] = inverse * p.CFrame
		end
		table.insert(take.Frames, frame)
	end
	local r = Config.Fail.Ragdoll
	-- the water: it holds most of the weight up and slows everything (each assembly once)
	local lift = workspace.Gravity * r.Float * dt
	local keep = math.exp(-r.Drag * dt)
	local under = Config.Death.UnderWater ~= 0
	for _, p in b.Parts do
		if p.AssemblyRootPart == p then
			local v
			local spin = p.AssemblyAngularVelocity * keep
			if under then
				-- (Death.UnderWater: only under the surface, less near the top, and a soft ceiling just over it)
				local d = Config.Death
				local y = p.Position.Y
				local wet = math.clamp((Config.Depth.SurfaceY - y) / math.max(d.WetBand, 0.05) + 0.5, 0, 1)
				local held =
					Ease.lerp(d.TopHold, 1, math.clamp((Config.Oxygen.SurfaceY - y) / math.max(d.TopBand, 0.1), 0, 1))
				v = p.AssemblyLinearVelocity * Ease.lerp(1, keep, wet) + Vector3.new(0, lift * held * wet, 0)
				local most = math.sqrt(2 * d.BreachBrake * math.max(0, Config.Depth.SurfaceY + d.Breach - y))
				if v.Y > most then
					v = Vector3.new(v.X, most, v.Z)
				end
				spin = p.AssemblyAngularVelocity * Ease.lerp(1, keep, wet)
			else
				v = p.AssemblyLinearVelocity * keep + Vector3.new(0, lift, 0)
			end
			if v.Magnitude > 140 then
				v = v.Unit * 140
			end
			p.AssemblyLinearVelocity = v
			p.AssemblyAngularVelocity = spin
		end
	end
	-- (Death.UnderWater) never onto the strip: a body over ground that stands above the water is moved out to open
	-- water, and one heading onto it is stopped short
	local main = limb(b.Character, "Torso")
	if under and main then
		Underwater.strip(b.Parts, main)
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
		-- (a hit, not a cannon: a part swung hard in one frame would throw the body at hundreds of studs a second)
		if velocity.Magnitude > 45 then
			velocity = velocity.Unit * 45
		end
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
-- Whether `at` is inside the mouth's room or anywhere along the way down the throat (nil: no room known, the mouth
-- not from the model)
local function inMouthOf(f: Fail, fishNow: CFrame, at: Vector3): boolean?
	local room = f.MouthRoom
	if not room then
		return nil
	end
	local p = (fishNow * mouthOf(f)):PointToObjectSpace(at)
	local deep = f.Length * (if f.Kind == "Gulp" then 0.3 else 0.25)
	return math.abs(p.X) <= room.X * 0.5 + 1
		and math.abs(p.Y) <= room.Y * 0.5 + 1
		and p.Z >= -room.Z * 0.5 - 1
		and p.Z <= deep + 1
end

-- The fish's grabs, by outcome (our own machine: AlignPositions on the loose body)

-- (Fail.Arrive) where the fish's clock may wait for the body: just before the bite and just before you are gone (the
-- hide: 1.62 for a Chomp, 1.78 for a Gulp, less 0.02), made once and not every frame (a Gulp's bite, 1.6, less 0.02
-- too: its suction runs down the throat from 1.45, so at 1.52 the body could be near and still 3 studs off at the bite)
local WAIT_CHOMP = { 1.2, 1.6 }
local WAIT_GULP = { 1.58, 1.76 }

-- (Config.Fail.NewEat) The loose body carried along its arc, then held by the mouth or the arms. It is still the real
-- ragdoll, pulled by its chest (and, in the arms, its hips): the limbs are its own.
local function grabsNew(f: Fail, b: Body, plan: EatMoves.Plan, u: number, fishNow: CFrame)
	local moves = Config.Fail.EatMoves
	local chomp = f.Kind == "Chomp"
	local has = if chomp then moves.Chomp.Bite else moves.Wrap.Catch
	local m = EatMoves.moment(plan, u + (if u < has then moves.Lead else 0))
	local at = m.Rider.Position + f.Slip * ss(has - 0.3, has, u)
	if chomp and u >= has then
		-- (from where you really are, as it shuts on you, into its mouth as it really is)
		local from = f.TakenAt or torsoOf(f) or at
		f.TakenAt = from
		at = from:Lerp(fishNow * EatMoves.throat(plan, u), EatMoves.taken(u))
	elseif u >= has then
		at = fishNow * m.Fish:PointToObjectSpace(m.Rider.Position)
	end
	local pull = if u >= has then Config.Fail.HidePull else moves.Pull
	hold(b, "Eat", "Torso", at, pull, moves.PullForce)
	if chomp then
		if u >= has then
			f.GrabAt = f.GrabAt or f.Last
		end
		-- (laid along its way, feet first into the mouth: hanging, the legs came out under its chin)
		local lie = ss(has - 0.45, has - 0.1, u)
		if lie > 0 then
			hold(b, "EatLegs", "Lower", at - fishNow.LookVector * 1.5, 20 + 50 * lie, 1500 * lie)
		end
	elseif u >= has - 0.1 then
		f.GrabAt = f.GrabAt or f.Last
		-- the legs drawn in toward the beak, the head out: you lie along its arms
		local w = ss(has - 0.1, has + 0.3, u)
		hold(b, "EatLegs", "Lower", fishNow * (EatMoves.held(plan, u) - Vector3.new(0, 0, 1.1)), 8 + 16 * w, 700 * w)
		hold(b, "EatHead", "Head", fishNow * (EatMoves.held(plan, u) + Vector3.new(0, 0, 1.5)), 4 + 5 * w, 220 * w)
	end
end

local function grabs(f: Fail, b: Body, t: number, fishNow: CFrame)
	if f.New then
		grabsNew(f, b, f.New, t, fishNow)
		return
	end
	local L, H = f.Length, f.Height
	local kind = f.Kind
	if kind == "Chomp" then
		-- the jaws take you: pulled into the mouth, then deeper (Fail.Arrive: from a little earlier, gently at first)
		local arrive = f.Dials.Arrive
		local from = if arrive then Config.Fail.ChompGrab else 1.12
		if t >= from then
			b.MouthOff = true
			f.GrabAt = f.GrabAt or t
			local deep = ss(1.3, 1.7, t)
			local pull = 22 + 20 * deep
			if arrive and t < 1.12 then
				pull = Ease.lerp(Config.Fail.ChompGrabFrom, 22, ss(from, 1.12, t))
			elseif arrive and t >= 1.3 then
				-- (from the bite on, held hard: the head's shake and the way down the throat swung it 7 studs out
				-- of the mouth at 22 to 32, still to be seen)
				pull = Config.Fail.HidePull
			end
			hold(b, "Mouth", "Torso", mouthTarget(f, fishNow, t), pull, 1400)
		end
	elseif kind == "Gulp" then
		-- the suction: drawn in, slow and then all at once
		if t >= 1.0 then
			b.MouthOff = true
			f.GrabAt = f.GrabAt or t
			local pull = 14 + 36 * ss(1.0, 1.45, t)
			if f.Dials.Arrive and next(f.Hidden) ~= nil then
				pull = Config.Fail.HidePull
			end
			hold(b, "Mouth", "Torso", mouthTarget(f, fishNow, t), pull, 2200)
		end
	elseif kind == "Wrap" then
		-- each arm, once it has hold, hauls its limb in under the body, with weight and lag
		-- its own arms (not drawn ones): each takes a limb at its tip, and as they curl back in the limb is hauled
		-- with them, hanging and lagging with its own weight
		for _, chain in f.Chains do
			local target = chain.Target
			if target and t >= chain.Grab and chain.Live then
				b.MouthOff = true
				hold(b, "Arm" .. target, target, fishNow * tipNow(chain), 22, 1200)
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
				local fling = Underwater.shapeThrow(away * 75 + Vector3.new(0, 22, 0), torso.Position)
				for _, p in b.Parts do
					p.AssemblyLinearVelocity = fling
					p.AssemblyAngularVelocity = fishNow.UpVector * 9
				end
			end
		end
	elseif kind == "Pin" then
		-- slammed under its head and dragged along the floor by it, the legs trailing
		if t >= 0.85 then
			b.MouthOff = true -- (its boxes off once it has you: pressed under its jaws, not pushed up onto its head)
			local floorY = f.FloorY or (f.From.Position.Y - 20)
			-- (under its jaws, just ahead of the head, so you are seen pinned)
			-- (its body lies on the floor, so "under its head" would be inside it: just ahead of its jaws)
			local under = fishNow * CFrame.new(0, -H * 0.4, -L * 0.72)
			local at = Vector3.new(under.Position.X, math.max(floorY + 1.2, under.Position.Y), under.Position.Z)
			hold(b, "Pin", "Torso", at, 20 + 20 * ss(0.85, 1.2, t), 1500)
			-- (and its own claws on you, where it has them: the body drawn to their tips)
			for _, chain in f.Chains do
				if chain.Target and t >= chain.Grab and chain.Live then
					hold(b, "Claw" .. chain.Joints[1].Name, "Lower", fishNow * tipNow(chain), 10, 300)
				end
			end
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
	end
end

-- the dark closing in (the kraken's): the screen dims, nothing more
-- (no arms over the screen now: Hugo, 2026-11-19, "remove the tentacles coming in from the screen"; only the dark)
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
	gui.Parent = State.Player:WaitForChild("PlayerGui")
	return gui
end

local function updateShade(gui: ScreenGui, t: number, from: number, to: number)
	local dim = gui:FindFirstChild("Dim") :: Frame?
	if dim then
		dim.BackgroundTransparency = 1 - 0.35 * ss(from, to, t)
	end
end

----------------------------------------------------------------------------------------------------------------------
-- The shot: one move to it, eased in and out, then held. Where it stands round the fish's way as it began (Side:
-- across it, on the side we were already on; Back: behind; Up: above, below for a low angle), and how far (Far, in
-- the fish's own size). It never comes closer to the fish than its own length.
-- `Near`: a shot sized to the rider, not the fish (for a giant whose grab happens off its body): this many studs from
-- where it throws you (`Behind` studs behind its root, `Lift` above), whatever its size
local SHOTS: {
	[string]: {
		Side: number,
		Back: number,
		Up: number,
		Far: number,
		Ahead: number,
		Near: number?,
		Behind: number?,
		Lift: number?,
	},
} =
	{
		Chomp = { Side = 1, Back = -0.15, Up = 0.2, Far = 0.8, Ahead = 0.3 }, -- side view
		Gulp = { Side = 1, Back = -0.55, Up = 0.2, Far = 0.6, Ahead = 0.4 }, -- side, from ahead, close on the mouth
		-- (on you where it throws you, from the side, its arms behind you: sized to you, not to a giant)
		Wrap = { Side = 1, Back = 0.25, Up = 0.3, Far = 1, Ahead = 0, Near = 30, Behind = 24, Lift = 14 },
		Roll = { Side = 1, Back = 0.25, Up = -0.5, Far = 1.2, Ahead = 0.3 }, -- low angle
		Flip = { Side = 1, Back = 0.2, Up = -0.65, Far = 1.05, Ahead = 0.3 }, -- low, looking up at the belly
		Shell = { Side = 0.8, Back = -0.6, Up = 0.55, Far = 1.0, Ahead = 0.1 }, -- three-quarter front, high
		Coil = { Side = 1, Back = 0.3, Up = 0.6, Far = 1.45, Ahead = 0.2 }, -- wide and high
		Pin = { Side = 0.9, Back = -0.6, Up = 0.55, Far = 0.75, Ahead = 0.4 }, -- high three-quarter front, on the jaws
	}

-- what the shot may pass through: fish, players, our own props, the map's props (they fade, PropController)
local function viewParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = { workspace.CurrentCamera }
	local folder = workspace:FindFirstChild("Fish")
	if folder then
		table.insert(skip, folder)
	end
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local lane = blockout and blockout:FindFirstChild("Lane")
	local props = lane and lane:FindFirstChild("Props")
	if props then
		table.insert(skip, props)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(skip, player.Character)
		end
	end
	params.FilterDescendantsInstances = skip
	return params
end

local function shotFor(f: Fail, sideSign: number): Vector3
	local s = SHOTS[f.Kind] or SHOTS.Chomp
	local look = flat(f.From.LookVector)
	local right = look:Cross(Vector3.yAxis).Unit
	local anchor = f.From.Position + look * math.min(f.Speed / 2.5, 40) * s.Ahead
	local dir = (right * sideSign * s.Side + -look * s.Back + Vector3.yAxis * s.Up)
	dir = if dir.Magnitude > 0.01 then dir.Unit else right
	local far = (f.Length * 0.48 + 15) * s.Far
	far = math.max(far, f.Length * 0.55 + 8)
	if s.Near then
		anchor = f.From.Position - look * (s.Behind or 0) + Vector3.new(0, s.Lift or 0, 0)
		far = s.Near
	end
	local at = anchor + dir * far
	-- not under the floor, and not behind a wall: brought in to the near side of it
	if f.FloorY then
		at = Vector3.new(at.X, math.max(at.Y, f.FloorY + 5), at.Z)
	end
	local params = viewParams()
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
local fadedProps: { [any]: boolean } = {} -- (the props of them: Prop, below)
local function unfade()
	for d in faded do
		if d.Parent then
			d.LocalTransparencyModifier = 0
		end
	end
	table.clear(faded)
	table.clear(fadedProps)
end

-- the map's props in the way: found by sweeping a ball from what the shot looks at back to the camera (props stream in
-- and out, so they are looked for where they are, not listed)
local function propsFolder(): Instance?
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local lane = blockout and blockout:FindFirstChild("Lane")
	return lane and lane:FindFirstChild("Props")
end

local function propsInWay(from: Vector3, to: Vector3): { Instance }
	local folder = propsFolder()
	local found: { Instance } = {}
	if not folder then
		return found
	end
	local params = viewParams()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip = params.FilterDescendantsInstances
	-- (viewParams leaves props out; here they are wanted)
	for i = #skip, 1, -1 do
		if skip[i] == folder then
			table.remove(skip, i)
		end
	end
	params.FilterDescendantsInstances = skip
	for _ = 1, 6 do
		local hit = workspace:Spherecast(from, 2.5, to - from, params)
		if not hit or not hit.Instance:IsDescendantOf(folder) then
			break
		end
		local model: Instance = hit.Instance
		while model.Parent and model.Parent ~= folder do
			model = model.Parent :: Instance
		end
		table.insert(found, model)
		params:AddToFilter(model)
	end
	return found
end

local fishParts: { [Instance]: { BasePart } } = setmetatable({}, { __mode = "k" }) :: any

local function fade(parts: { BasePart }, near: boolean)
	for _, d in parts do
		local want = if near then 0.85 else 0
		if want > 0 or faded[d] then
			d.LocalTransparencyModifier = d.LocalTransparencyModifier + (want - d.LocalTransparencyModifier) * 0.25
			faded[d] = if d.LocalTransparencyModifier > 0.01 then true else nil
			if not faded[d] then
				d.LocalTransparencyModifier = 0
			end
		end
	end
end

-- Wild fish and the map's props between the camera and what it looks at are made see-through, on our own screen
-- (LocalTransparencyModifier), while a death's shot is up. `skip`: the fish doing it (never faded).
local function clearView(skip: Model?, from: Vector3, to: Vector3, also: { Vector3 })
	local way = to - from
	local span = way.Magnitude
	if span < 1 then
		return
	end
	local dir = way / span
	local function between(at: Vector3, radius: number): boolean
		local rel = at - from
		local along = rel:Dot(dir)
		return along > -radius and along < span - 1 and (rel - dir * along).Magnitude < radius
	end
	local folder = workspace:FindFirstChild("Fish")
	for _, model in if folder then folder:GetChildren() else {} do
		local root = model:IsA("Model") and model.PrimaryPart
		if root and model ~= skip then
			local parts = fishParts[model]
			if not parts then
				local list: { BasePart } = {}
				for _, d in model:GetDescendants() do
					if d:IsA("BasePart") then
						table.insert(list, d)
					end
				end
				fishParts[model] = list
				parts = list
			end
			fade(parts :: { BasePart }, between(root.Position, root.Size.Magnitude * 0.6 + 5))
		end
	end
	local inWay: { [Instance]: boolean } = {}
	for _, model in propsInWay(to, from) do
		inWay[model] = true
		fadedProps[model] = true
	end
	for _, at in also do
		for _, model in propsInWay(at, from) do
			inWay[model] = true
			fadedProps[model] = true
		end
	end
	for model in fadedProps do
		local parts = fishParts[model]
		if not parts then
			local list: { BasePart } = {}
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					table.insert(list, d)
				end
			end
			fishParts[model] = list
			parts = list
		end
		local near = inWay[model] == true
		fade(parts :: { BasePart }, near)
		if not near and (#(parts :: { BasePart }) == 0 or not faded[(parts :: { BasePart })[1]]) then
			fadedProps[model] = nil
		end
	end
end

-- Every death's shot (a fail's, the drown after it): never through a wall (kept on the near side of anything solid
-- between it and what it looks at, eased so it slides rather than jumps), and nothing in the way of it
local viewReach = 1e4
local viewDir: Vector3? = nil
local viewParamsNow: RaycastParams? = nil
local viewParamsAt = -math.huge

----------------------------------------------------------------------------------------------------------------------
-- The words of a failed run (Hugo, 2026-11-22: "make text better and more stylised when failing a run", and of the
-- sheet: "Use the bubble text option"): the Bubble letters of Kit.failWords, over the black, each line in its own
-- colour (Config.failColours). The deaths still say what and when (State.FadeText, State.Fade: DeathController's
-- "OUT OF BREATH!" and "MISSED THE FISH!", HudController's "TOO STRONG!", a taken outcome's own Text); HudController
-- hands them to Banners.miss each frame, which hands them here (Kit.FailShow). Thrown off by an outcome, the plain
-- run-out's words are that outcome's own (Config.Fail.Outcomes' Text: "THROWN OFF!", "ROLLED OFF!"). The letters pop
-- up as the black begins, whatever the black's own pace, and float up and pop as it lifts, all gone before it is;
-- the words are kept as they came up until then (the server's attributes are gone by the time we are home).
-- Studio only, to look at any line without failing: workspace's "FailWords" (the words; "" or nil for none),
-- "FailWordsSub" (false: no second line), "FailWordsAge" (seconds in, held: a still of the motion), "FailWordsOut"
-- (0 to 1 of the way out) and "FailWordsScreen" (a Vector2: the words drawn as on a screen of that size, outlined,
-- for a phone's).
local words: Kit.FailWords? = nil
local wordsRaw = "" -- what the deaths last said
local wordsAt = 0 -- os.clock() they came up
local wordsPeak = 0 -- the most the black has been since
local wordsUpIn = 0 -- seconds the letters take to all be up
local wordsPops = 0 -- the pops heard so far (coming up, then going)
local wordsTest = "" -- (Studio: the line being looked at)
local thrownBy: string? = nil -- our own last outcome or throw, for its words

local function wordsBand(): Kit.FailWords
	if words then
		return words
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "RideFailWords"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 40 -- over the black (RideBlack, HudController's BLACK_ORDER) and the kraken's dark (FailShade)
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = State.Player:WaitForChild("PlayerGui")
	local made = Kit.failWords(gui)
	words = made
	return made
end

-- what the screen says for the deaths' words
local function wordsFor(raw: string): string
	if raw == Config.Fail.Breath and State.Player:GetAttribute("DeathThrown") == true then
		local def = Config.Fail.Outcomes[thrownBy or "Throw"]
		if def and def.Text ~= "" then
			return def.Text
		end
	end
	return raw
end

local function wordsUp(text: string, sub: string)
	wordsAt = os.clock()
	wordsPeak = 0
	wordsPops = 0
	local colour, deep = Config.failColours(text)
	wordsUpIn = wordsBand().show(text, sub, colour, deep)
end

-- The letters' pops, heard (the placeholder there is, pitched about): three as the word comes up, two as it goes
local POPS_IN = { 0.1, 0.55, 1 } -- of the time the letters take to all be up
local POPS_OUT = { 0.35, 0.65 } -- of the way out
local function wordsPop(age: number, out: number)
	local due = 0
	for _, share in POPS_IN do
		due += if age >= wordsUpIn * share then 1 else 0
	end
	for _, share in POPS_OUT do
		due += if out >= share then 1 else 0
	end
	if due > wordsPops then
		wordsPops = due
		local sound = Fx.sound("Pop")
		if sound then
			sound.PlaybackSpeed *= 0.85 + 0.12 * due
			sound.Volume *= if out > 0 then 0.6 else 1
		end
	end
end

local function wordsShow(raw: string, black: number)
	if wordsTest ~= "" then
		return
	end
	local band = words
	if raw == "" then
		if wordsRaw ~= "" then
			wordsRaw = ""
			thrownBy = nil
			if band then
				band.hide()
			end
		end
		return
	end
	-- new words: at once while the fail plays; never once we are on the way home (they would change as they leave)
	if raw ~= wordsRaw and (wordsRaw == "" or State.dying()) then
		wordsRaw = raw
		local caught = State.Caught
		wordsUp(wordsFor(raw), if caught and #caught > 0 then Config.Fail.Safe else "")
		band = words
	end
	if not band then
		return
	end
	local age = os.clock() - wordsAt
	wordsPeak = math.max(wordsPeak, black)
	local out = if not State.dying() and wordsPeak > 0 then 1 - math.clamp(black / wordsPeak, 0, 1) else 0
	wordsPop(age, out)
	band.pose(age, out)
end

local wordsScreen: Vector2? = nil -- (Studio: the pretended screen)

-- (Studio) a pretended screen: the words fit themselves to their Root's size, so a phone's is a box of that size,
-- outlined. Taken off again the moment the attribute goes, whatever is showing
local function wordsPretend()
	local box = workspace:GetAttribute("FailWordsScreen")
	local screen = if typeof(box) == "Vector2" and box.X > 0 and box.Y > 0 then box else nil
	if screen == wordsScreen or (screen and not words) then
		return
	end
	wordsScreen = screen
	local band = words
	if not band then
		return
	end
	local root = band.Root
	local edge = root:FindFirstChild("Pretend")
	if screen and not edge then
		local line = Instance.new("UIStroke")
		line.Name = "Pretend"
		line.Thickness = 2
		line.Color = Color3.new(1, 1, 1)
		line.Parent = root
	elseif edge and not screen then
		edge:Destroy()
	end
	root.AnchorPoint = if screen then Vector2.new(0.5, 0.5) else Vector2.zero
	root.Position = if screen then UDim2.fromScale(0.5, 0.5) else UDim2.new()
	root.Size = if screen then UDim2.fromOffset(screen.X, screen.Y) else UDim2.fromScale(1, 1)
end

local function wordsStudio()
	wordsPretend()
	local asked = workspace:GetAttribute("FailWords")
	local text = if type(asked) == "string" then asked else ""
	if text ~= wordsTest then
		wordsTest = text
		wordsRaw = ""
		if text == "" then
			if words then
				words.hide()
			end
			return
		end
		wordsUp(text, if workspace:GetAttribute("FailWordsSub") == false then "" else Config.Fail.Safe)
		wordsPretend()
	end
	local band = words
	if text == "" or not band then
		return
	end
	local held = workspace:GetAttribute("FailWordsAge")
	local out = workspace:GetAttribute("FailWordsOut")
	band.pose(
		if type(held) == "number" and held >= 0 then held else os.clock() - wordsAt,
		if type(out) == "number" then out else 0
	)
end

local function viewStep(dt: number)
	local shot = State.DeathCam
	if not shot then
		viewReach = 1e4
		viewDir = nil
		if next(faded) then
			unfade()
		end
		return
	end
	if not viewParamsNow or os.clock() - viewParamsAt > 1 then
		viewParamsNow = viewParams()
		viewParamsAt = os.clock()
	end
	local line = shot.Position - shot.Focus
	if line.Magnitude > 1 then
		-- the way it was asked for, or, when a wall would bring it in close, the clearest of a few swung up and round
		-- (eased toward, so it swings rather than jumps)
		local length = line.Magnitude
		local asked = line.Unit
		local function clearOf(dir: Vector3): number
			local hit = workspace:Raycast(shot.Focus, dir * length, viewParamsNow)
			return if hit then (hit.Position - shot.Focus).Magnitude - 3 else length
		end
		local want, best = asked, clearOf(asked)
		if best < math.min(length, 12) then
			local flatRight = asked:Cross(Vector3.yAxis)
			flatRight = if flatRight.Magnitude > 0.01 then flatRight.Unit else Vector3.xAxis
			for _, turn in
				{
					CFrame.fromAxisAngle(flatRight, rad(35)),
					CFrame.fromAxisAngle(flatRight, rad(65)),
					CFrame.Angles(0, rad(50), 0),
					CFrame.Angles(0, -rad(50), 0),
					CFrame.fromAxisAngle(flatRight, -rad(35)),
				}
			do
				local dir = (turn * CFrame.new(asked)).Position.Unit
				local clear = clearOf(dir)
				if clear > best + 2 then
					want, best = dir, clear
				end
			end
		end
		viewDir = if viewDir then (viewDir :: Vector3):Lerp(want, Ease.alpha(3, dt)).Unit else want
		local reachTo = math.max(4, clearOf(viewDir :: Vector3))
		viewReach =
			Ease.lerp(math.min(viewReach, length * 2), reachTo, Ease.alpha(if reachTo < viewReach then 10 else 2, dt))
		State.DeathCam = {
			Position = shot.Focus + (viewDir :: Vector3) * math.min(length, viewReach),
			Focus = shot.Focus,
			Rate = shot.Rate,
		}
	end
	local fail = fails[State.Player]
	-- (Config.Fail.NewEat: nothing of the map stands before the rider or the fish's head either, only the shot's middle)
	local also: { Vector3 } = {}
	if fail and fail.New then
		local torso = torsoOf(fail)
		if torso then
			table.insert(also, torso)
		end
		table.insert(also, (fail.FishRoot.CFrame * mouthOf(fail)).Position)
		table.insert(also, fail.FishRoot.Position)
	end
	clearView(if fail then fail.Fish else nil, workspace.CurrentCamera.CFrame.Position, shot.Focus, also)
end

local function letFishGo(f: Fail)
	-- the fish goes back to its own swim (the server's dismount, or the coast), leaving the way it came at its old
	-- speed, so it never stops in place
	if f.Driving and f.Mine and f.FishRoot.Parent then
		f.FishRoot.AssemblyLinearVelocity = flat(f.From.LookVector) * math.max(f.Speed, 20) * 0.8
	end
	for _, c in f.Paused do
		if c.Parent then
			c.Enabled = true
		end
	end
	table.clear(f.Paused)
	f.Driving = false
end

-- (Config.Fail.NewEat) The new move worked out: what it needs of the fish and of the water round it. A model without
-- what it needs (a jaw; three jointed arms) keeps the old one.
local function beginNew(f: Fail)
	local jaw: Joint? = nil
	for _, j in f.Joints do
		if j.Kind == "jaw" then
			jaw = jaw or j
		end
	end
	local mouth = f.Mouth
	local arms: { EatMoves.Arm } = {}
	for _, chain in f.Chains do
		-- (its links' own boxes, and its tip where its last link's mesh really ends: the meshes lean outward off the
		-- line of their pivots)
		local links: { EatMoves.Link } = {}
		local rest = table.clone(chain.Rest)
		for i, link in chain.Joints do
			local box = EatMoves.linkOf(link.Motor.C1:Inverse().Position, link.Part.Size)
			links[i] = box
			if i == #chain.Joints then
				rest[i + 1] = link.Pivot + box.Frame.Position + box.Frame.ZVector * box.Half.Z
			end
		end
		local out = (chain.Rest[1] - f.Beak) * Vector3.new(1, 1, 0)
		out = if out.Magnitude > 0.01 then out.Unit else Vector3.yAxis
		table.insert(arms, { Rest = rest, Links = links, Out = out, Turn = EatMoves.turnOf(out) })
	end
	if f.Kind == "Chomp" and not (jaw and mouth) then
		if not f.Dials.Mouth then
			f.Mouth, f.MouthRoom, f.Lure = nil, nil, nil
		end
		return
	elseif f.Kind == "Wrap" and #arms < 3 then
		return
	end
	-- the open water straight ahead, at the height it swims (a wall of the map; never the fish or the props)
	local look = flat(f.From.LookVector)
	local span = f.Length * 2 + 120
	local params = viewParams()
	local hit = workspace:Raycast(f.From.Position, look * span, params)
	f.New = EatMoves.plan({
		Kind = f.Kind,
		From = f.From,
		Speed = f.Speed,
		Length = f.Length,
		Height = f.Height,
		Saddle = f.Saddle.Position,
		Mouth = if mouth then mouth.Position else Vector3.zero,
		Hinge = if jaw then jaw.Pivot else Vector3.zero,
		Arms = arms,
		FloorY = f.FloorY,
		Ahead = if hit then (hit.Position - f.From.Position).Magnitude else span,
		SurfaceY = Config.Depth.SurfaceY,
	})
	f.Dials.Arrive = f.Kind == "Chomp"
	if f.Kind == "Wrap" then
		for _, j in f.Joints do
			if j.Kind == "body" and j.Part:IsA("MeshPart") then
				f.Mantle, f.MantleSize = j.Part, j.Part.Size
			end
		end
	end
	-- the shot's side: the one we look from, unless a wall is close on that side and the other is clearer
	f.CamFrom = f.CamStart - f.Focus
	f.Pivot = f.Focus
	local right = look:Cross(Vector3.yAxis).Unit
	local need = f.Length + 10
	local function clear(side: number): number
		local wall = workspace:Raycast(f.From.Position, right * side * need, params)
		return if wall then (wall.Position - f.From.Position).Magnitude else need
	end
	if clear(f.CamSide) < need * 0.7 and clear(-f.CamSide) > clear(f.CamSide) + 5 then
		f.CamSide = -f.CamSide
	end
end

-- the octopus's ink, left where it was as it jets off (a local, short-lived cloud; the engine's own smoke picture)
local function ink(f: Fail, at: Vector3)
	local spot = localPart(Vector3.one, Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	spot.Name = "Ink"
	spot.Transparency = 1
	spot.CFrame = CFrame.new(at)
	local size = math.max(f.Length * 0.16, 3)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(26, 12, 40), Color3.fromRGB(8, 6, 16))
	e.LightInfluence = 0
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size * 0.3),
		NumberSequenceKeypoint.new(0.25, size),
		NumberSequenceKeypoint.new(1, size * 1.5),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.5, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(1, 1.7)
	e.Speed = NumberRange.new(f.Length * 0.1, f.Length * 0.45)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 3
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-30, 30)
	e.Rate = 0
	e.Enabled = false
	e.Parent = spot
	e:Emit(math.floor(Config.Fail.EatMoves.Wrap.Ink))
	table.insert(f.Props, spot)
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
		Chains = {},
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
		Beak = Vector3.new(0, -body.Y * 0.2, 0),
		Mouth = nil,
		MouthRoom = nil,
		Lure = nil,
		Wait = 0,
		Rate = 1,
		U = 0,
		Dials = {
			Mouth = Config.Fail.MouthFromModel ~= 0,
			Arrive = Config.Fail.Arrive ~= 0,
			Smooth = Config.Fail.Smooth ~= 0,
		},
		New = nil,
		Mantle = nil,
		MantleSize = nil,
		CamFrom = Vector3.zero,
		CamSide = sideSign,
		CamLeast = (camera.Position - from.Position).Magnitude,
		Pivot = Vector3.zero,
		Aim = Vector3.zero,
		TakenAt = nil,
		ArmsHeld = {},
		Slip = Vector3.zero,
	}
	local id = fish:GetAttribute("FishType")
	local new = type(id) == "string" and (Config.Fail.NewEat[id] or 0) ~= 0 and (kind == "Chomp" or kind == "Wrap")
	if f.Dials.Mouth or (new and kind == "Chomp") then
		f.Mouth, f.MouthRoom, f.Lure = mouthFromModel(f)
	end
	f.Chains = readChains(f.Joints)
	local roots, sum = 0, Vector3.zero
	for _, j in f.Joints do
		if j.Kind == "arm" and j.Depth == 1 then
			roots += 1
			sum += j.Pivot
		end
	end
	if roots > 0 then
		f.Beak = sum / roots
	end
	for _, d in fish:GetDescendants() do
		if d:IsA("Trail") and d.Enabled then
			d.Enabled = false
			table.insert(f.Trails, d)
		end
	end
	f.CamTo = shotFor(f, sideSign)
	if new then
		beginNew(f)
	end
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
	if f.Mine then
		lastOf[player] = { Kind = kind, Base = from }
	end
	Fx.sound(def.Sound, fishRoot)
end

-- Test hook: only the Studio checks call this (tools/studio/fail_eat_check.py). The fail playing for `player` now, as
-- plain values (nil: none): its clocks, where its mouth is and how far the body is from it, and its dials.
function FailController.probe(player: Player): { [string]: any }?
	local f = fails[player]
	if not f then
		return nil
	end
	local fishNow = f.FishRoot.CFrame
	local mouth = fishNow * mouthOf(f)
	local torso = limb(f.Character, "Torso")
	local target = mouthTarget(f, fishNow, f.U)
	local inMouth: boolean? = if torso then inMouthOf(f, fishNow, torso.Position) else nil
	return {
		Kind = f.Kind,
		T = f.Last,
		U = f.U,
		Wait = f.Wait,
		Mouth = mouth.Position,
		MouthLocal = mouthOf(f).Position,
		Room = f.MouthRoom,
		Target = target,
		Torso = if torso then torso.Position else nil,
		Far = if torso then (torso.Position - target).Magnitude else nil,
		InMouth = inMouth,
		Hidden = next(f.Hidden) ~= nil,
		GrabAt = f.GrabAt,
		BiteAt = f.BiteAt,
		BiteFar = f.BiteFar,
		HideAt = f.HideAt,
		HideFar = f.HideFar,
		FishRoot = fishNow.Position,
		FishLook = fishNow.LookVector,
		Length = f.Length,
		Mouthed = f.Mouth ~= nil,
		Dials = { Mouth = f.Dials.Mouth, Arrive = f.Dials.Arrive, Smooth = f.Dials.Smooth },
	}
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

-- (the new moves', by their own numbers)
local function beatsOf(f: Fail): { { At: number, Name: string } }
	local plan = f.New
	if not plan then
		return BEATS[f.Kind] or {}
	end
	local m = Config.Fail.EatMoves
	if f.Kind == "Chomp" then
		return { { At = m.Chomp.Bite, Name = "bite" } }
	end
	local list = {}
	for i = 1, #plan.Takers do
		table.insert(list, { At = m.Wrap.Take + (i - 1) * m.Wrap.TakeEach + m.Wrap.TakeTime, Name = "take" .. i })
	end
	table.insert(list, { At = m.Wrap.Jet, Name = "ink" })
	return list
end

local function beat(f: Fail, name: string, fishNow: CFrame, riderPos: Vector3)
	if name == "ink" then
		Fx.sound("Rumble", f.FishRoot)
		local at = fishNow * (f.Beak + Vector3.new(0, 0, f.Length * 0.1))
		ink(f, at)
		Fx.burst(at, 24, nil, 5)
		if f.Mine then
			Shake.play("LandBig", 0.6)
		end
	elseif string.sub(name, 1, 4) == "take" then
		-- (an arm closes on you)
		Fx.sound("Pop", f.FishRoot)
		Fx.burst(riderPos, 8, 0.3, 2)
		if f.Mine then
			Shake.play("Crash", 0.35)
		end
	elseif name == "bite" then
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

-- (Studio) the playback: our own body posed from the recording at the held clocks, its joints off and its parts
-- anchored meanwhile; put back as soon as it is past the recording or the playback is off
local function unreplay()
	for thing, was in replayed do
		if thing.Parent then
			if thing:IsA("BasePart") then
				thing.Anchored = was
			else
				(thing :: any).Enabled = was
			end
		end
	end
	table.clear(replayed)
end

local function replayStep()
	local player = State.Player
	local last = lastOf[player]
	local take = last and takes[last.Kind]
	local character = player.Character
	if not studio("FailReplay") or not last or not take or #take.Frames == 0 or not character then
		unreplay()
		return
	end
	local def = Config.Fail.Outcomes[last.Kind]
	local state = player:GetAttribute("State")
	local failClock, deathClock = workspace:GetAttribute("FailClock"), workspace:GetAttribute("DeathClock")
	local tb: number? = nil
	if state == "Failing" and type(failClock) == "number" and failClock >= 0 then
		tb = failClock - def.Loose
	elseif state == "Drowning" and type(deathClock) == "number" and deathClock >= 0 then
		tb = deathClock + math.max(0, def.Time - def.Loose)
	end
	local frames = take.Frames
	if not tb or tb < 0 or tb > frames[#frames].T then
		unreplay()
		return
	end
	-- off: every joint of the body and the ride's weld; anchored: its parts
	local function off(thing: Instance)
		if replayed[thing] == nil then
			if thing:IsA("BasePart") then
				replayed[thing] = thing.Anchored
				thing.Anchored = true
			else
				replayed[thing] = (thing :: any).Enabled;
				(thing :: any).Enabled = false
			end
		end
	end
	for _, d in character:GetDescendants() do
		local joint = d:IsA("Motor6D") or d:IsA("AnimationConstraint") or d:IsA("BallSocketConstraint")
		if joint or (d:IsA("BasePart") and d:FindFirstAncestorOfClass("Accessory") == nil) then
			off(d)
		end
	end
	local f = fails[player]
	if f and f.Weld and f.Weld.Parent then
		off(f.Weld)
	end
	local i = 1
	while i < #frames and frames[i + 1].T < tb do
		i += 1
	end
	local a, b = frames[i], frames[math.min(i + 1, #frames)]
	local k = if b.T > a.T then math.clamp((tb - a.T) / (b.T - a.T), 0, 1) else 0
	local base = if f then f.From else last.Base
	-- (the second run's map round it can differ a little: the whole body kept above the floor there)
	local lift = 0
	local torsoFrame = a.Parts.UpperTorso or a.Parts.Torso
	if torsoFrame then
		local torsoAt = (base * torsoFrame).Position
		local floor = Course.floor(torsoAt + Vector3.new(0, 6, 0))
		if floor and torsoAt.Y < floor + 1.2 then
			lift = floor + 1.2 - torsoAt.Y
		end
	end
	for name, cf in a.Parts do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			local other = b.Parts[name] or cf
			part.CFrame = (base * cf:Lerp(other, k)) + Vector3.new(0, lift, 0)
		end
	end
end

-- A thin light outline round a rider in a fail or loose (every machine; local): a small dark avatar against the
-- water and a big fish otherwise disappears in the shot. Hidden with them once swallowed (the parts go unseen).
local outlines: { [Player]: Highlight } = {}
local function outlineStep()
	for player, h in outlines do
		if not (fails[player] or bodies[player]) or h.Adornee ~= player.Character or not h.Parent then
			h:Destroy()
			outlines[player] = nil
		end
	end
	for _, list in { fails, bodies } :: { { [Player]: any } } do
		for player in list do
			local character = player.Character
			if character and not outlines[player] then
				local h = Instance.new("Highlight")
				h.Name = "FailOutline"
				h.Adornee = character
				h.FillTransparency = 1
				h.OutlineColor = Color3.fromRGB(255, 250, 235)
				h.OutlineTransparency = 0.15
				h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				h.Parent = character
				outlines[player] = h
			end
		end
	end
	-- (swallowed: no outline either)
	for player, h in outlines do
		local f = fails[player]
		h.Enabled = not (f and next(f.Hidden) ~= nil)
	end
end

-- (Config.Fail.NewEat) This frame of a new move. Our own fish is aimed, a little, at where the loose body really is: the
-- mouth comes to you, not only you to it.
local STILL = still()
local function newFrame(f: Fail, plan: EatMoves.Plan, u: number): Frame
	local m = EatMoves.moment(plan, u)
	local fish = m.Fish
	local body = bodies[f.Player]
	local torso = torsoOf(f)
	if f.Kind == "Chomp" and body and torso then
		local bite = Config.Fail.EatMoves.Chomp.Bite
		if u < bite then
			local off = torso - m.Rider.Position
			local most = 1.5 + f.Length * 0.04
			off = if off.Magnitude > most then off.Unit * most else off
			f.Aim = off * ss(bite - plan.Lunge, bite - 0.04, u)
		end
		fish += f.Aim * (1 - ss(bite + 0.1, bite + 0.8, u))
	end
	return { Fish = fish, Rider = m.Rider, Rig = STILL, Focus = m.Focus }
end

local function step(dt: number)
	local clock = os.clock()
	if RunService:IsStudio() then
		replayStep()
	end
	-- the loose bodies first (the physics' own help), then the outcomes
	for player, b in bodies do
		local character = player.Character
		if player.Parent == nil or character ~= b.Character or not b.Character:GetAttribute("Ragdoll") then
			endBody(player)
		else
			stepBody(b, dt)
		end
	end
	outlineStep()
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
		-- (Fail.Arrive) the fish's clock slows, a little, just before the bite and again just before you are gone, while
		-- the body is not yet at its mouth (slowed, never stopped: eased down and back up). One clock `u` (t less the
		-- wait) runs the fish, the jaws, the grabs, the beats and the hide, so they stay together; the shot, the dark
		-- and the fade keep the real time, and the wait in all is at most Fail.ArriveWait, so the server's time for the
		-- fail still holds (never while FailClock is held)
		local fs = Config.Fail
		local mouthy = f.Kind == "Chomp" or f.Kind == "Gulp"
		local plan = f.New
		local gone = if f.Kind == "Chomp" then 1.62 else 1.78
		local waits = if f.Kind == "Chomp" then WAIT_CHOMP else WAIT_GULP
		if plan and f.Kind == "Chomp" then
			local bite = fs.EatMoves.Chomp.Bite
			gone = fs.EatMoves.Chomp.Gone
			waits = { bite - 0.04 }
		end
		local torsoNow = limb(f.Character, "Torso")
		local want = 1
		if f.Dials.Arrive and mouthy and torsoNow and not (type(held) == "number" and held >= 0) then
			local was = t - f.Wait
			for _, point in waits do
				if was >= point - fs.ArriveLead and was < point then
					local to = mouthTarget(f, f.FishRoot.CFrame, point)
					if plan and point < fs.EatMoves.Chomp.Bite then
						-- (its mouth is still on its way: how far off its arc the body is)
						to = EatMoves.moment(plan, was).Rider.Position + f.Slip
					end
					local far = (torsoNow.Position - to).Magnitude
					if far > fs.ArriveNear then
						-- (back up to pace over the wait's last third, so it never ends at once)
						local left = math.clamp((fs.ArriveWait - f.Wait) / math.max(fs.ArriveWait * 0.3, 0.01), 0, 1)
						want = Ease.lerp(1, fs.ArriveRate, left)
					end
				end
			end
		end
		if want < 1 or f.Rate < 1 then
			f.Rate = Ease.lerp(f.Rate, want, Ease.alpha(fs.ArriveEase, stepT))
			if f.Rate > 0.999 then
				f.Rate = 1
			end
			f.Wait = math.min(f.Wait + stepT * (1 - f.Rate), fs.ArriveWait)
		end
		local u = t - f.Wait
		f.U = u
		local frame: Frame
		if plan then
			frame = newFrame(f, plan, math.min(u, def.Time + def.Time))
		else
			frame = OUTCOMES[f.Kind](f, math.min(u, def.Time + (if taken then def.Time else 0.3)))
		end
		-- (Hugo, 2026-11-19: after it the fish carries on the way it was going: whatever turn, roll or lunge it made
		-- eases back onto its old heading over the outcome's last part, swimming on, never a U-turn or a stop; the
		-- server then takes it back onto its line, FishService.release)
		local home = ss(def.Time * 0.55, def.Time + (if taken then 0.6 else 0), u)
		if home > 0 and not plan then
			local heading = CFrame.lookAt(Vector3.zero, flat(f.From.LookVector))
			local onward = flat(f.From.LookVector) * f.Speed * 0.5 * math.max(0, u - def.Time * 0.55) * home
			frame.Fish = CFrame.new(frame.Fish.Position + onward) * frame.Fish.Rotation:Lerp(heading, home)
		end
		local weld = f.Weld
		if weld and weld.Parent == nil then
			weld = nil
			f.Weld = nil
		end
		-- the fish: ours to move through the outcome (it holds us, then lets go: the server's throwOff)
		if f.Driving and f.Mine then
			if u < def.Time + (if taken then def.Time else 0.05) then
				-- (never into the floor or through a wall: each frame's move kept in open water, Course.clearMove, so
				-- the rider on its back never goes in either)
				local from = f.FishAt or f.From.Position
				local at = Course.clearMove(from, frame.Fish.Position, f.Height * 0.5 + 1)
				f.FishAt = at
				f.Slip = at - frame.Fish.Position
				f.FishRoot.CFrame = CFrame.new(at) * frame.Fish.Rotation
				f.FishRoot.AssemblyLinearVelocity = Vector3.zero
				f.FishRoot.AssemblyAngularVelocity = Vector3.zero
			else
				letFishGo(f)
			end
		end
		local fishNow = f.FishRoot.CFrame
		-- its own parts (every machine)
		if plan then
			poseNew(f, plan, u, stepT)
		else
			armsStep(f, u)
			poseRig(f, frame.Rig, t)
		end
		-- the rider, still on the saddle (everyone works out the same), then loose
		local b = bodies[player]
		if weld then
			local riderAt = frame.Rider
			if riderAt and plan then
				-- (as it lies to the fish on its path, so it lies to the fish as it is on this machine)
				riderAt = fishNow * frame.Fish:ToObjectSpace(riderAt)
			end
			if riderAt then
				-- (the rider too: kept above the floor and out of walls as it is slid about on the saddle)
				local seat = (fishNow * f.Saddle).Position
				riderAt = CFrame.new(Course.clearMove(seat, riderAt.Position, 2.5)) * riderAt.Rotation
			end
			weld.C0 = if riderAt then fishNow:Inverse() * riderAt else f.Saddle
			f.Pose = riderPose(f, u)
		else
			f.Pose = nil
		end
		local torso = limb(f.Character, "Torso")
		local riderPos = if torso then torso.Position else (fishNow * f.Saddle).Position
		if b and b.Mine and not b.Replay then
			grabs(f, b, u, fishNow)
		end
		-- swallowed: out of sight, and the throat bulges
		if mouthy then
			-- (Fail.Arrive: not until the body is in the mouth or down the throat, at most Fail.HideLate later)
			local ready = u >= gone
			if ready and f.Dials.Arrive and torso and u < gone + Config.Fail.HideLate then
				ready = inMouthOf(f, fishNow, torso.Position) ~= false
			end
			if ready and next(f.Hidden) == nil then
				f.HideAt = t
				f.HideFar = if torso then (torso.Position - mouthTarget(f, fishNow, u)).Magnitude else nil
				hide(f)
			end
			bulge(f, u, gone + 0.05, gone + 0.7)
		end
		-- props
		if f.Kind == "Gulp" then
			local ball = f.Props[1] :: BasePart?
			if ball then
				local glow = ss(0, 0.6, u) * (1 - ss(1.5, 1.9, u))
				local pulse = 0.75 + 0.25 * math.sin(t * 10)
				-- (on the lure part as it is drawn, swaying with its swim; else where it would be)
				local lure = f.Lure
				ball.CFrame = if lure and lure.Part.Parent then lure.Part.CFrame * lure.Bulb else lurePlace(fishNow, f)
				ball.Transparency = 1 - math.max(0.1, glow)
				local light = ball:FindFirstChildOfClass("PointLight")
				if light then
					light.Brightness = 7 * glow * pulse
				end
			end
		end
		local beats: { { At: number, Name: string } } = beatsOf(f)
		for _, m in beats do
			if u >= m.At and u - stepT < m.At + 0.5 and not f.Beats[m.Name] then
				f.Beats[m.Name] = true
				if m.Name == "bite" then
					f.BiteAt = t
					f.BiteFar = if torso then (torso.Position - mouthTarget(f, fishNow, u)).Magnitude else nil
				end
				beat(f, m.Name, fishNow, riderPos)
			elseif u >= m.At then
				f.Beats[m.Name] = true
			end
		end
		if not f.Mine then
			continue
		end
		-- our own: the shot (one move, then held), the dark and the fade
		local move = inOut(t / math.max(Config.Fail.CameraTime, 0.05))
		local at = f.CamStart:Lerp(f.CamTo, move)
		local whole = 1 -- how much of the fish must be in it, with you
		if plan then
			-- (Config.Fail.NewEat: one even swing to the side, following what it looks at, then still, watching)
			local freeze = if f.Kind == "Chomp" then fs.EatMoves.Chomp.Bite else fs.EatMoves.Wrap.Jet
			if t < freeze + fs.EatMoves.Shot.Hold then
				f.Pivot = f.Focus
			end
			local dir, far, all = EatMoves.shot(plan, f.CamFrom, f.CamSide, t)
			whole = all
			at = f.Pivot + dir * far
			if f.FloorY then
				at = Vector3.new(at.X, math.max(at.Y, f.FloorY + 5), at.Z)
			end
		end
		-- (never into the fish: kept a length off it)
		local off = at - fishNow.Position
		local least = if SHOTS[f.Kind] and SHOTS[f.Kind].Near then 8 else f.Length * 0.55 + 6
		if plan then
			-- (no nearer than that in the end, and never pushed out to it at once)
			least = Ease.lerp(math.min(f.CamLeast, f.Length * 0.42 + 6), f.Length * 0.42 + 6, ss(0, fs.CameraTime, t))
		end
		if off.Magnitude < least then
			at = fishNow.Position + (if off.Magnitude > 0.1 then off.Unit else Vector3.yAxis) * least
		end
		local subject = frame.Focus or riderPos:Lerp(fishNow.Position, 0.5)
		f.Focus = f.Focus:Lerp(subject, Ease.alpha(if plan then 10 else 4, math.max(stepT, dt)))
		-- the rider and the fish both kept in the shot: backed off along its line as they draw apart (smoothly)
		local near = SHOTS[f.Kind] and SHOTS[f.Kind].Near and not plan
		local spread = if near
			then (riderPos - fishNow.Position).Magnitude * 0.5 + 8
			else (riderPos - fishNow.Position).Magnitude + f.Length * 0.5
		local need = spread * 0.5 / math.tan(rad(workspace.CurrentCamera.FieldOfView / 2)) * 1.15
		local away = at - f.Focus
		if away.Magnitude > 0.1 then
			local pull = math.max(0, need - away.Magnitude) * whole
			f.Pull = Ease.lerp(f.Pull, pull, Ease.alpha(if plan then 6 else 2.5, math.max(stepT, dt)))
			at += away.Unit * f.Pull
		end
		-- (walls and what is in the way: viewStep, after the drown's own step)
		State.DeathCam = { Position = at, Focus = f.Focus, Rate = if plan then fs.EatMoves.Shot.Rate else nil }
		local dim = math.clamp(t / math.max(def.Time, 0.01), 0, 1)
		State.Darken = 0.15 * dim
		State.Vignette = 0.3 * dim
		if f.Kind == "Wrap" then
			local shade = f.Shade or makeShade()
			f.Shade = shade
			updateShade(shade, t, if plan then fs.EatMoves.Wrap.Still else 1.0, def.Time)
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
		if player == State.Player and (kind == "Fail" or kind == "Ragdoll") and type(outcome) == "string" then
			thrownBy = outcome -- (for the words, should it end in the drown)
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
	-- the words of a failed run are ours to show (Banners.miss hands them over)
	Kit.FailShow = wordsShow
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
	-- after the drown's (Camera - 3), before the camera's own: the shot kept out of walls, the view kept clear
	RunService:BindToRenderStep("RideFailView", Enum.RenderPriority.Camera.Value - 2, viewStep)
	if RunService:IsStudio() then
		RunService.RenderStepped:Connect(wordsStudio)
	end
end

return FailController
