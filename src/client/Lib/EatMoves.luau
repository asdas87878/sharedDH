--!strict
-- The new eating moves (Config.Fail.NewEat; Hugo, 2026-11-25: "the way they turn doesnt look good at all, maybe make the
-- fish slow down throw the player in front and then swallow midair"). Two so far, to be judged: a fish that bites
-- (Chomp) and an octopus that drags you down (Wrap). Nothing in here turns round after the rider.
--   Chomp  brakes (bunched, fins out), bucks you up and forward past its own nose, winds up looking at you, jaw open,
--          lunges and takes you at the top of your arc, snaps shut, gulps, settles and swims on the way it was going
--   Wrap   brakes and tips its mantle down, the arms swinging up behind it and opening like a flower; you are tossed up
--          over them, three arms curl round you one after another, it draws you in to its beak, a beat of stillness,
--          then it jets off down into the dark with its arms streaming and its ink behind it
-- Plain sums only, no Instances: FailController plays them (the same way on every machine), and tools/eat/eat_check.luau
-- runs them offline. Every place and turn is worked out once when the fail begins (plan) and then read by the seconds
-- in (u), so the fish's path, the rider's arc and the mouth or the arms meet where they were planned to. Only the
-- octopus's arms are not read by the clock alone: they close as a hand does, on the rider's real parts (EatMoves.arms).
-- All lengths are shares of the fish's own (Config.Fail.EatMoves), so every size moves the same way.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)

local EatMoves = {}

-- a box: one of an arm's links at rest (from its pivot), or a part of the rider (in the fish's space)
export type Link = { Frame: CFrame, Half: Vector3, Reach: number }

-- one of the octopus's arms at rest, in the fish's space: its pivots from the root, then its tip
export type Arm = {
	Rest: { Vector3 },
	Links: { Link }, -- each link's box
	Out: Vector3, -- outward from the body's axis, at the arm's root
	Turn: number, -- and the angle of that about the axis, radians
}

export type Given = {
	Kind: string, -- "Chomp" or "Wrap"
	From: CFrame, -- the fish's root as it began
	Speed: number,
	Length: number,
	Height: number,
	Saddle: Vector3, -- the rider's root on the fish, in its space
	Mouth: Vector3, -- (Chomp) the middle of its shut mouth, and the jaw's hinge, in its space
	Hinge: Vector3,
	Arms: { Arm }, -- (Wrap)
	FloorY: number?,
	Ahead: number, -- studs of open water straight ahead of its root (a wall there)
	SurfaceY: number,
}

export type Plan = {
	Given: Given,
	Level: CFrame, -- its heading, level (a turn only)
	Forward: Vector3,
	Brake: number, -- studs it slides on as it brakes
	Back: number, -- (Chomp) studs it is pushed back for want of room ahead
	-- Chomp: where you are taken, its root as it winds up and as it bites, how far it noses up, and how long it lunges
	Catch: Vector3,
	Coil: Vector3,
	Bite: Vector3,
	Pitch: number,
	Lunge: number,
	Room: number, -- how far it can bunch its body, with the floor this near (0 to 1)
	-- (both) how high the toss takes you over the seat. Wrap: its root as it catches you, how far it tips, where in its space you are
	-- caught and then held, which arms take you, and the jet's path
	Hold: Vector3,
	Tip: number,
	Toss: number,
	Caught: Vector3,
	Home: Vector3,
	Crown: Vector3,
	Reach: number, -- an arm's whole length
	Takers: { number },
	Jet: { { At: Vector3, Pitch: number } },
}

-- how far closed each arm is
export type ArmsHeld = { [number]: { At: number, Taking: boolean, Abs: { CFrame }? } }

export type Moment = { Fish: CFrame, Rider: CFrame, Focus: Vector3 }

-- what the joints do at this moment
export type Rig = {
	Jaw: number, -- 0 shut, 1 open wide
	Fins: number, -- 1 thrown out as brakes, -1 folded along the body
	Bunch: number, -- radians shared over the spine: the tail tucked under (+) or kicked up (-)
	Sway: number, -- the tail's sideways beat, radians at the tail
	Beat: number, -- where in the beat, radians
	Nod: number, -- the whole body's roll, the satisfied settle, radians
	Squeeze: number, -- the mantle: 1 thin and long, -1 short and fat
}

local rad = math.rad
local AXIS = Vector3.new(0, 0, 1) -- the octopus's own axis: its arms trail along it
local JET_STEP = 1 / 60
local SKIN = 0.03 -- studs an arm keeps off you
-- how a rider stands (R15, the usual sizes; about their root): the plan's own, before it is known where they really are
local STANDING = {
	{ Vector3.new(0, 0.2, 0), Vector3.new(2, 1.6, 1) },
	{ Vector3.new(0, -0.8, 0), Vector3.new(2, 0.4, 1) },
	{ Vector3.new(0, 1.6, 0), Vector3.new(1.2, 1.2, 1.2) },
	{ Vector3.new(-1.5, 0, 0), Vector3.new(1, 2, 1) },
	{ Vector3.new(1.5, 0, 0), Vector3.new(1, 2, 1) },
	{ Vector3.new(0, -1.95, 0), Vector3.new(2, 2.2, 1) },
}
local SOLES = 3.05 -- studs from their root down to their soles

local function boxOf(frame: CFrame, size: Vector3): Link
	return { Frame = frame, Half = size / 2, Reach = size.Magnitude / 2 }
end
EatMoves.boxOf = boxOf

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

-- 0 to 1, speeding up evenly over the first `a` of it and slowing evenly over the last `b`: no kick at either end
local function glide(u: number, a: number, b: number): number
	u = math.clamp(u, 0, 1)
	local top = 1 / (1 - a / 2 - b / 2)
	if u < a then
		return top * u * u / (2 * a)
	elseif u > 1 - b then
		return 1 - top * (1 - u) * (1 - u) / (2 * b)
	end
	return top * (u - a / 2)
end

local function flat(v: Vector3): Vector3
	local f = v * Vector3.new(1, 0, 1)
	return if f.Magnitude > 0.01 then f.Unit else Vector3.new(0, 0, -1)
end

-- the angle of `out` about the body's axis (0 at the top, growing toward the right)
function EatMoves.turnOf(out: Vector3): number
	return math.atan2(out.X, out.Y)
end

-- (Wrap) Which arms take you: the topmost (it ends up ahead), then the nearest to a third of the way round each side,
-- so the three close on you from three sides. The same on every machine.
local function takers(arms: { Arm }): { number }
	local list: { number } = {}
	for _, want in { 0, math.pi * 2 / 3, -math.pi * 2 / 3 } do
		local best, bestOff = 0, math.huge
		for i, arm in arms do
			if not table.find(list, i) then
				local off = math.abs((arm.Turn - want + math.pi) % (2 * math.pi) - math.pi)
				if off < bestOff then
					best, bestOff = i, off
				end
			end
		end
		if best > 0 then
			table.insert(list, best)
		end
	end
	return list
end

-- the jaw `open` (0 to 1) of the way: the middle of the mouth's gap, in the fish's space (half the jaw's own turn)
function EatMoves.mouthAt(g: Given, open: number): Vector3
	return g.Hinge + CFrame.Angles(-rad(Config.Fail.EatMoves.JawTurn) * 0.5 * open, 0, 0) * (g.Mouth - g.Hinge)
end

local function slide(p: Plan, u: number): Vector3
	local k = Config.Fail.EatMoves.BrakeRate
	return p.Given.From.Position + p.Given.From.LookVector * p.Brake * (1 - math.exp(-k * u))
end

local function planChomp(p: Plan)
	local g, m = p.Given, Config.Fail.EatMoves.Chomp
	local L = g.Length
	local clear = m.Clear * L + 2
	-- the room ahead: you are never thrown into a wall. It brakes harder, then is pushed back, to make the room
	local need = p.Brake + L * 0.5 + clear + m.RiderRoom
	if need > g.Ahead then
		local short = need - g.Ahead
		local lessBrake = math.min(short, p.Brake * 0.7)
		p.Brake -= lessBrake
		p.Back = math.min(short - lessBrake, L * m.MostBack)
	end
	local stop = g.From.Position + g.From.LookVector * p.Brake - p.Forward * p.Back
	-- it comes up under you as it winds up (no higher than the surface lets it), and noses up: less for a big one, less
	-- with no water to rise through, and no further than its tail has water under it
	local roof = g.SurfaceY - g.Height * 0.45
	local most = math.min(m.Lift * L, m.MostLift)
	local rise = math.clamp(roof - stop.Y, 0, most)
	local pitch = rad(m.Pitch) * math.clamp(m.PitchLength / L, 0.5, 1) * (0.4 + 0.6 * rise / most)
	local y = stop.Y + rise
	for _ = 1, 12 do
		local tail = y - math.sin(pitch) * (L * (0.5 + m.Draw) + 2) - g.Height * 0.4
		if not g.FloorY or tail > g.FloorY + 0.5 or pitch < rad(2) then
			break
		end
		pitch *= 0.8
	end
	p.Pitch = pitch
	if g.FloorY then
		p.Room = math.clamp((stop.Y - g.Height * 0.5 - g.FloorY) / (L * 0.3), 0.2, 1)
	end
	local turn = p.Level * CFrame.Angles(pitch, 0, 0)
	-- where its open mouth has you, a little ahead of where its nose has stopped
	local mouth = turn * EatMoves.mouthAt(g, 1)
	local ahead = L * 0.5 + clear
	p.Bite = Vector3.new(stop.X, y, stop.Z) + p.Forward * (ahead - mouth:Dot(p.Forward))
	if g.FloorY then
		p.Bite += Vector3.new(0, math.max(0, g.FloorY + 4 - (p.Bite.Y + mouth.Y)), 0)
	end
	p.Bite -= Vector3.new(0, math.max(0, p.Bite.Y + mouth.Y - (g.SurfaceY - 3)), 0)
	p.Catch = p.Bite + mouth
	-- wound up it is drawn straight back from there, the rider clear of its snout: the lunge is all forward
	p.Coil = p.Bite - turn.LookVector * (m.Draw * L + 2)
	-- the hop you are thrown with: up over the head, then hanging at the catch
	local seat = g.From.Position.Y + g.Saddle.Y
	p.Toss = math.clamp(g.SurfaceY - 2.5 - math.max(seat, p.Catch.Y), 0, m.Rise * L + 2)
	p.Lunge = m.Lunge * math.clamp((L / m.PitchLength) ^ 0.3, 1, 1.35)
end

-- the steepest an octopus may point down with its root this high, its mantle's end kept off the floor (radians)
local function steepest(g: Given, y: number): number
	local floorY = g.FloorY
	if not floorY then
		return math.pi
	end
	local room = y - floorY - 2 - g.Height * 0.3
	local s = room / (g.Length * 0.5)
	return if s >= 1 then math.pi else math.asin(math.clamp(s, 0, 1))
end

-- (Wrap) How far out from its arms' crown your root is when it has drawn you right in: your soles at the beak, or as near
-- as a small one's arms, spread, leave room for you.
local homeOf: (p: Plan) -> number

local function planWrap(p: Plan)
	local g, m = p.Given, Config.Fail.EatMoves.Wrap
	local L = g.Length
	local crown, reach = Vector3.zero, 0
	for _, arm in g.Arms do
		crown += arm.Rest[1]
		for i = 2, #arm.Rest do
			reach += (arm.Rest[i] - arm.Rest[i - 1]).Magnitude
		end
	end
	local n = math.max(#g.Arms, 1)
	p.Crown, p.Reach = crown / n, reach / n
	p.Takers = takers(g.Arms)
	p.Tip = rad(m.Tip)
	p.Caught = p.Crown + Vector3.new(0, 0, p.Reach * m.Caught)
	p.Home = p.Crown + Vector3.new(0, 0, homeOf(p) + Config.Fail.EatMoves.Wrap.Sag * p.Reach)
	p.Toss = math.min(m.Toss * L, m.MostToss) + 2
	if p.Brake + L * 0.5 > g.Ahead - 3 then
		p.Brake = math.clamp(g.Ahead - 3 - L * 0.5, 0, p.Brake)
	end
	local stop = g.From.Position + g.From.LookVector * p.Brake
	-- up off the floor, far enough for its mantle to hang down and for the jet under it; and down from the surface,
	-- far enough for your toss to stay under it (the toss gives way first, then the jet's room)
	local lo = if g.FloorY then g.FloorY + L * m.TipRoom + 1 else -math.huge
	local y = stop.Y
	if g.FloorY then
		y = math.max(y, math.min(lo + L * m.JetRoom, stop.Y + L * m.MostLift))
	end
	local over = y + g.Saddle.Y + p.Toss - (g.SurfaceY - 2.5)
	if over > 0 then
		local give = math.min(over, math.max(0, y - math.max(lo, stop.Y - L * m.MostLift)))
		y -= give
		p.Toss = math.max(1, p.Toss - (over - give))
	end
	p.Hold = Vector3.new(stop.X, y, stop.Z)
	-- (in water too shallow for it to hang straight down, it tips less: with its mantle's end off the floor, and where
	-- you are caught under the surface)
	p.Tip = math.min(p.Tip, math.max(steepest(g, p.Hold.Y), rad(20)))
	while p.Tip > rad(20) and p.Hold.Y + math.sin(p.Tip) * p.Caught.Z > g.SurfaceY - 3.5 do
		p.Tip -= rad(2)
	end
	-- the jet: mantle first, down and on the way it was going, pulled out along the floor where there is one
	local jet: { { At: Vector3, Pitch: number } } = {}
	local at, pitch = p.Hold, p.Tip
	local least = if g.FloorY then g.FloorY + math.max(g.Height * 0.5 + 1, L * 0.2) else -math.huge
	local span = 0.75 + 0.25 * L / 26
	local gone = 0 -- studs forward
	for i = 0, math.ceil((Config.Fail.Outcomes.Wrap.Time + 1.5) / JET_STEP) do
		local t = i * JET_STEP
		table.insert(jet, { At = at, Pitch = -pitch })
		local speed = span * (m.JetBurst * math.exp(-2.6 * t) + m.JetOn * ss(0.1, 0.9, t)) * ss(0, 0.14, t)
		local want = rad(m.Dive)
		-- (the steepest it may point with this much water under its mantle)
		local most = steepest(g, at.Y)
		want = math.min(want, most * 0.9)
		pitch += (want - pitch) * Ease.alpha(if want < pitch then 7 else 3, JET_STEP)
		pitch = math.min(pitch, math.max(most, p.Tip * (1 - i * JET_STEP)))
		local step = speed * JET_STEP
		-- (no further on than the open water ahead)
		local on = math.min(step * math.cos(pitch), math.max(0, g.Ahead - 4 - L * 0.5 - p.Brake - gone))
		gone += on
		at += p.Forward * on - Vector3.new(0, step * math.sin(pitch), 0)
		at = Vector3.new(at.X, math.max(at.Y, math.min(least, p.Hold.Y)), at.Z)
	end
	p.Jet = jet
end

function EatMoves.plan(g: Given): Plan
	local e = Config.Fail.EatMoves
	local forward = flat(g.From.LookVector)
	local p: Plan = {
		Given = g,
		Level = CFrame.lookAt(Vector3.zero, forward),
		Forward = forward,
		Brake = math.min(g.Speed / e.BrakeRate, g.Length * e.MostBrake),
		Back = 0,
		Catch = g.From.Position,
		Coil = g.From.Position,
		Bite = g.From.Position,
		Pitch = 0,
		Lunge = 0.25,
		Room = 1,
		Hold = g.From.Position,
		Tip = 0,
		Toss = 0,
		Caught = Vector3.zero,
		Home = Vector3.zero,
		Crown = Vector3.zero,
		Reach = 1,
		Takers = {},
		Jet = {},
	}
	if g.Kind == "Chomp" then
		planChomp(p)
	else
		planWrap(p)
	end
	return p
end

-- its turn at `u`: the one it had as it began, levelled as it brakes, then nosed up or down by `pitch`
local function turned(p: Plan, u: number, pitch: number, roll: number): CFrame
	local level = p.Given.From.Rotation:Lerp(p.Level, ss(0, 0.45, u))
	return level * CFrame.Angles(pitch, 0, 0) * CFrame.Angles(0, 0, roll)
end

----------------------------------------------------------------------------------------------------------------------
-- Chomp

-- how far up it is nosed at `u`
local function chompPitch(p: Plan, u: number): number
	local m = Config.Fail.EatMoves.Chomp
	local bite = m.Bite
	-- (the buck: nose down till you are past it, then up under you)
	local dip = -rad(m.Dip) * ss(0.02, 0.28, u) * (1 - ss(m.Past - 0.12, m.Past + 0.16, u))
	local up = p.Pitch * (0.7 * ss(m.Past - 0.06, m.Wound, u) + 0.3 * ss(bite - p.Lunge, bite, u))
	local over = p.Pitch * 0.25 * bump(bite, bite + 0.35, u)
	local home = 1 - ss(bite + 0.1, bite + 0.85, u)
	return dip + (up + over) * home
end

local function chompRoot(p: Plan, u: number): Vector3
	local m = Config.Fail.EatMoves.Chomp
	local bite = m.Bite
	local stop = p.Given.From.Position + p.Given.From.LookVector * p.Brake
	local back = p.Coil - stop
	local at = slide(p, u) + Vector3.new(back.X, 0, back.Z) * ss(0.2, m.Wound, u)
	at += Vector3.new(0, back.Y, 0) * ss(m.Past - 0.34, m.Wound, u)
	-- the lunge: from a standstill, faster and faster onto you, and on through the bite, dying away
	local way = p.Bite - p.Coil
	local k = math.clamp((u - (bite - p.Lunge)) / p.Lunge, 0, 1)
	at += way * k ^ m.LungePower
	if u > bite then
		local t = u - bite
		local v = way * (m.LungePower / p.Lunge)
		at += Vector3.new(v.X, 0, v.Z) * (1 - math.exp(-m.Through * t)) / m.Through
		at += Vector3.new(0, v.Y, 0) * (1 - math.exp(-3 * m.Through * t)) / (3 * m.Through)
		-- and it swims on, the way it was going
		local on = math.max(0, t - 0.3)
		local pace = math.max(p.Given.Speed, 20) * m.On
		at += p.Forward * pace * (on - (1 - math.exp(-1.6 * on)) / 1.6)
	end
	-- (never up through the surface)
	local roof = p.Given.SurfaceY - p.Given.Height * 0.45
	return Vector3.new(at.X, math.min(at.Y, math.max(roof, p.Given.From.Position.Y)), at.Z)
end

-- the rider's arc: off the saddle as it brakes, up and forward past its nose, hanging where it is taken
local function chompArc(p: Plan, u: number): Vector3
	local m = Config.Fail.EatMoves.Chomp
	local seat = p.Given.From.Rotation:Lerp(p.Level, ss(0, 0.45, u)) * p.Given.Saddle
	local stop = p.Given.From.Position + p.Given.From.LookVector * p.Brake
	local k = (u - m.Off) / (m.Bite - m.Off)
	local way = p.Catch - (stop + p.Level * p.Given.Saddle)
	return slide(p, u)
		+ seat
		+ Vector3.new(way.X, 0, way.Z) * glide(k, 0.25, m.Float)
		+ Vector3.new(0, p.Toss * glide(k / 0.55, 0.3, 0.7) + (way.Y - p.Toss) * glide((k - 0.5) / 0.5, 0.5, 0.5), 0)
end

function EatMoves.chompRig(p: Plan, u: number): Rig
	local m = Config.Fail.EatMoves.Chomp
	local bite = m.Bite
	local lunge = bite - p.Lunge
	local open = 0.18 * bump(0.02, 0.4, u) -- a gasp as it brakes
		+ ss(m.Past - 0.24, m.Wound, u) * (1 - ss(bite - 0.02, bite + 0.045, u))
		+ 0.06 * math.sin(u * 40) * bump(m.Wound - 0.1, lunge + 0.1, u) -- held wide, straining
		+ 0.16 * bump(bite + 0.3, bite + 0.55, u) -- a chew
	return {
		Jaw = math.clamp(open, 0, 1.06),
		Fins = ss(0.02, 0.2, u) * (1 - 0.55 * ss(0.45, 0.8, u)) -- thrown out to brake, half out as it winds up
			- 1.1 * ss(lunge - 0.06, lunge + 0.08, u) * (1 - ss(bite, bite + 0.16, u)) -- swept back in the lunge
			- 0.45 * ss(bite, bite + 0.16, u)
			+ 0.65 * bump(bite + 0.05, bite + 0.7, u), -- and out again as it pulls up
		Bunch = rad(m.Bunch) * p.Room * (0.75 * bump(0.0, 0.34, u) - 1.15 * bump(0.2, 0.62, u) + 1.0 * bump(
			0.55,
			bite + 0.02,
			u
		) - 0.5 * bump(lunge + 0.08, bite + 0.5, u)),
		Sway = rad(m.Sway) * (0.25 + 1.0 * ss(lunge, lunge + 0.1, u) * (1 - 0.75 * ss(bite + 0.05, bite + 0.6, u))),
		Beat = u * 7 + 8 * math.max(0, math.min(u, bite + 0.3) - lunge),
		Nod = rad(m.Nod) * math.sin((u - bite - 0.35) * 9) * bump(bite + 0.35, bite + 1.05, u),
		Squeeze = 0,
	}
end

function EatMoves.chomp(p: Plan, u: number): Moment
	local m = Config.Fail.EatMoves.Chomp
	local rig = EatMoves.chompRig(p, u)
	local fish = CFrame.new(chompRoot(p, u)) * turned(p, u, chompPitch(p, u), rig.Nod)
	local rider: CFrame
	if u <= m.Off then
		rider = fish * CFrame.new(p.Given.Saddle)
	elseif u < m.Bite then
		-- (thrown face first, tumbling forward till you lie along its way, feet to the mouth)
		local tumble = p.Pitch * ss(m.Past, m.Bite, u) - rad(m.Tumble) * ss(m.Off, m.Bite - 0.1, u)
		rider = CFrame.new(chompArc(p, u)) * p.Level * CFrame.Angles(tumble, 0, 0)
	else
		-- (the mouth closes round you as it goes on past: you are taken up into its speed, not snatched)
		local at = p.Catch:Lerp(fish * EatMoves.throat(p, u), EatMoves.taken(u))
		rider = CFrame.new(at) * fish.Rotation * CFrame.Angles(-rad(m.Tumble), 0, 0)
	end
	-- (from the weld on the moving saddle into the arc without a step)
	if u > m.Off and u < m.Off + 0.12 then
		rider = (fish * CFrame.new(p.Given.Saddle)):Lerp(rider, ss(m.Off, m.Off + 0.12, u))
	end
	local mouth = fish * EatMoves.mouthAt(p.Given, rig.Jaw)
	return { Fish = fish, Rider = rider, Focus = rider.Position:Lerp(mouth, 0.5) }
end

-- the gulp going down its body: how far (radians) the joint at z (a share of its length, behind the root +) bends up or
-- down for the hump to be there. Its parts are rigid: nothing can swell, so the hump is in the bends.
function EatMoves.gulp(p: Plan, u: number, z: number): number
	local m = Config.Fail.EatMoves.Chomp
	local t = (u - m.Bite - 0.16) / m.GulpTime
	if t <= 0 or t >= 1 then
		return 0
	end
	local x = (z - Ease.lerp(-0.5, 0.6, t)) / 0.16
	-- (the joints ahead carry the whole body behind them: they only nod)
	local share = p.Room * (if z < 0 then 0.22 else 1)
	return rad(m.Gulp) * share * -x * math.exp(0.5 - x * x * 0.5) * bump(0, 1, t) ^ 0.5
end

-- how far you are from hanging in the water (0) to its mouth's own (1), from the bite on
function EatMoves.taken(u: number): number
	local m = Config.Fail.EatMoves.Chomp
	return ss(m.Bite - 0.03, m.Gone + 0.04, u)
end

-- from the bite on: the middle of the open mouth, the shut one, then down the throat (the fish's space)
function EatMoves.throat(p: Plan, u: number): Vector3
	local m = Config.Fail.EatMoves.Chomp
	local rig = EatMoves.chompRig(p, u)
	local deep = p.Given.Length * m.Deep * ss(m.Bite - 0.03, m.Gone + 0.05, u)
	return EatMoves.mouthAt(p.Given, rig.Jaw) + Vector3.new(0, 0, deep)
end

----------------------------------------------------------------------------------------------------------------------
-- Wrap

local function jetAt(p: Plan, t: number): (Vector3, number)
	local i = math.clamp(t / JET_STEP, 0, #p.Jet - 1.001)
	local a = math.floor(i)
	local from, to = p.Jet[a + 1], p.Jet[a + 2]
	return from.At:Lerp(to.At, i - a), Ease.lerp(from.Pitch, to.Pitch, i - a)
end

function EatMoves.wrapRig(_p: Plan, u: number): Rig
	local m = Config.Fail.EatMoves.Wrap
	return {
		Jaw = 0,
		Fins = 0,
		Bunch = 0,
		Sway = 0,
		Beat = u * 5,
		Nod = 0,
		-- it swells to brake and drinks in again before the jet, and is wrung thin as it goes
		Squeeze = -0.8 * bump(0, 0.7, u)
			- 1.0 * ss(m.Still - 0.1, m.Jet - 0.08, u) * (1 - ss(m.Jet - 0.06, m.Jet + 0.06, u))
			+ 1.1 * ss(m.Jet - 0.06, m.Jet + 0.08, u) * (1 - ss(m.Jet + 0.12, m.Jet + 0.75, u))
			+ 0.5 * bump(m.Jet + 0.7, m.Jet + 1.2, u),
	}
end

local function wrapFish(p: Plan, u: number): CFrame
	local m = Config.Fail.EatMoves.Wrap
	if u >= m.Jet then
		local at, pitch = jetAt(p, u - m.Jet)
		at += Vector3.new(0, p.Given.Length * 0.03 * (1 - ss(0, 0.25, u - m.Jet)), 0) -- (from where it drew up to)
		return CFrame.new(at) * p.Level * CFrame.Angles(pitch, 0, 0)
	end
	local stop = p.Given.From.Position + p.Given.From.LookVector * p.Brake
	local at = slide(p, u) + (p.Hold - stop) * ss(0.05, m.TipBy + 0.1, u)
	-- (it drinks in before the jet: drawn up and back a little)
	local draw = p.Given.Length * 0.03 * bump(m.Still, m.Jet * 2 - m.Still, u)
	at += Vector3.new(0, draw, 0)
	local pitch = rad(7) * bump(0, 0.22, u) - p.Tip * glide((u - 0.06) / (m.TipBy - 0.06), 0.45, 0.45)
	return CFrame.new(at) * turned(p, u, pitch, 0)
end

-- the rider's way: tossed up off the saddle, over the opening arms, and down into them
local function wrapToss(p: Plan, u: number): Vector3
	local m = Config.Fail.EatMoves.Wrap
	local seat = p.Given.From.Rotation:Lerp(p.Level, ss(0, 0.45, u)) * p.Given.Saddle
	local stop = p.Given.From.Position + p.Given.From.LookVector * p.Brake
	local from = stop + p.Level * p.Given.Saddle
	local caught = (CFrame.new(p.Hold) * p.Level * CFrame.Angles(-p.Tip, 0, 0)) * p.Caught
	local way = caught - from
	local across = glide((u - m.Off) / (m.Catch - m.Off), 0.3, 0.45)
	-- up to the top of the toss, and down: the rise with the fish's own lift under it
	local lift = (p.Hold.Y - stop.Y) * ss(m.Off, m.Top, u)
	local rise = p.Toss * glide((u - m.Off) / (m.Top - m.Off), 0.3, 0.65)
	local top = from.Y + (p.Hold.Y - stop.Y) + p.Toss
	local fall = (caught.Y - top) * glide((u - m.Top) / (m.Catch - m.Top), 0.6, 0.35)
	local at = slide(p, u) + seat + Vector3.new(way.X, 0, way.Z) * across + Vector3.new(0, lift + rise + fall, 0)
	local most = math.max(p.Given.SurfaceY - 2.5, p.Given.From.Position.Y + p.Given.Saddle.Y)
	return Vector3.new(at.X, math.min(at.Y, most), at.Z)
end

-- where you are held once caught, in the fish's space: out in the arms, drawn in, home
function EatMoves.held(p: Plan, u: number): Vector3
	local m = Config.Fail.EatMoves.Wrap
	local give = p.Reach * 0.05 * bump(m.Catch - 0.1, m.Catch + 0.25, u) -- they give a little as they take your weight
	return p.Caught:Lerp(p.Home, glide((u - m.Draw) / (m.Still - m.Draw), 0.35, 0.45)) - Vector3.new(0, 0, give)
end

function EatMoves.wrap(p: Plan, u: number): Moment
	local m = Config.Fail.EatMoves.Wrap
	local fish = wrapFish(p, u)
	local rider: CFrame
	if u <= m.Off then
		rider = fish * CFrame.new(p.Given.Saddle)
	elseif u < m.Catch then
		rider = CFrame.new(wrapToss(p, u)) * p.Level * CFrame.Angles(rad(m.Tumble) * ss(m.Off, m.Catch, u), 0, 0)
	else
		rider = fish * CFrame.new(EatMoves.held(p, u)) * CFrame.Angles(rad(90), 0, 0)
	end
	if u > m.Off and u < m.Off + 0.16 then
		rider = (fish * CFrame.new(p.Given.Saddle)):Lerp(rider, ss(m.Off, m.Off + 0.16, u))
	elseif u >= m.Catch and u < m.Catch + 0.15 then
		rider = CFrame.new(wrapToss(p, u)):Lerp(rider, ss(m.Catch, m.Catch + 0.15, u))
	end
	return { Fish = fish, Rider = rider, Focus = rider.Position:Lerp(fish.Position, 0.45) }
end

function EatMoves.moment(p: Plan, u: number): Moment
	return if p.Given.Kind == "Chomp" then EatMoves.chomp(p, u) else EatMoves.wrap(p, u)
end

function EatMoves.rig(p: Plan, u: number): Rig
	return if p.Given.Kind == "Chomp" then EatMoves.chompRig(p, u) else EatMoves.wrapRig(p, u)
end

-- the rider's way (world), and their velocity on it: what a body just let loose leaves with
function EatMoves.velocity(p: Plan, u: number): Vector3
	local h = 0.01
	return (EatMoves.moment(p, u + h).Rider.Position - EatMoves.moment(p, u - h).Rider.Position) / (2 * h)
end

----------------------------------------------------------------------------------------------------------------------
-- The octopus's arms. Three joints each: too few for a real spiral, so a hold is a hook: the first two links reach past
-- you, the last lies across your far side, and three of them close on you from three sides.

-- An arm opened out (the flower), gathered, round the rider like a basket, or streaming: each link's turn from its
-- rest, in the fish's space (absolute, not against the link before).
local function bent(arm: Arm, angles: { number }, sway: number): { CFrame }
	local abs: { CFrame } = {}
	local side = AXIS:Cross(arm.Out)
	side = if side.Magnitude > 0.01 then side.Unit else Vector3.xAxis
	local sum = 0
	for i = 1, #arm.Rest - 1 do
		sum += angles[math.min(i, #angles)]
		abs[i] = CFrame.fromAxisAngle(arm.Out, sway * i * 0.5) * CFrame.fromAxisAngle(side, sum)
	end
	return abs
end

-- the open flower, the basket and the stream, blended by the clock
local function loose(p: Plan, index: number, u: number): { CFrame }
	local m = Config.Fail.EatMoves.Wrap
	local arm = p.Given.Arms[index]
	local late = 0.05 * ((index * 3) % 4) -- (never all together)
	local open = ss(0.06 + late * 0.6, m.Open + late * 0.6, u)
	local close = ss(m.Catch + 0.1 + late, m.Still - 0.05 + late * 0.4, u)
	local stream = ss(m.Jet - 0.03, m.Jet + 0.28 + late, u)
	local gather = -0.16 * bump(0, 0.24, u) + 0.12 * bump(m.Still, m.Jet + 0.06, u)
	local breath = 0.05 * math.sin(u * 3.2 + index) * (1 - bump(m.Still - 0.1, m.Jet, u))
	local flower, basket, trail = m.Flower, m.Basket, m.Stream
	local angles: { number } = {}
	for i = 1, 3 do
		local a = rad(flower[i]) * open
		a = Ease.lerp(a, rad(basket[i]), close)
		a = Ease.lerp(a, rad(trail[i]), stream)
		angles[i] = a + gather * (if i == 1 then 1 else 0.5) + breath * i * 0.5
	end
	-- (a wave running down the arms as they stream)
	local sway = rad(5) * math.sin(u * 9 - index * 1.7) * stream + rad(3) * math.sin(u * 2.6 + index * 2)
	return bent(arm, angles, sway)
end

-- the turn that takes `a` to `b` (unit vectors)
local function between(a: Vector3, b: Vector3): CFrame
	local axis = a:Cross(b)
	if axis.Magnitude < 1e-5 then
		return CFrame.identity
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(a:Dot(b), -1, 1)))
end

-- A link's own box, worked out from its part: `mid` from its pivot to its part's middle, `size` the part's box in the
-- fish's axes, both at rest. The link lies along `mid` (its mesh leans, up to 40 degrees, off the line of the pivots);
-- its length and its thickness are what best make that size. A little over, so that what is drawn is inside it.
function EatMoves.linkOf(mid: Vector3, size: Vector3): Link
	local d = if mid.Magnitude > 0.01 then mid.Unit else AXIS
	local s = AXIS:Cross(d)
	s = if s.Magnitude > 0.01 then s.Unit else Vector3.xAxis
	local n = d:Cross(s)
	local a, b = d:Abs(), s:Abs() + n:Abs()
	local aa, ab, bb = a:Dot(a), a:Dot(b), b:Dot(b)
	local across, long = 0, size.Magnitude
	local det = aa * bb - ab * ab
	if det > 1e-4 then
		long = (a:Dot(size) * bb - b:Dot(size) * ab) / det
		across = (aa * b:Dot(size) - ab * a:Dot(size)) / det
	end
	across = math.clamp(across, 0.05, size.Magnitude) * 1.14
	long = math.max(long, across) * 1.06
	return boxOf(CFrame.fromMatrix(mid, s, n, d), Vector3.new(across, across, long))
end

-- whether two boxes are clear of each other (their fifteen axes)
local function apart(a: Link, frame: CFrame, b: Link, skin: number): boolean
	local x, y, z, r11, r12, r13, r21, r22, r23, r31, r32, r33 = frame:ToObjectSpace(b.Frame):GetComponents()
	local ax, ay, az = a.Half.X + skin, a.Half.Y + skin, a.Half.Z + skin
	local bx, by, bz = b.Half.X, b.Half.Y, b.Half.Z
	local m11, m12, m13 = math.abs(r11) + 1e-6, math.abs(r12) + 1e-6, math.abs(r13) + 1e-6
	local m21, m22, m23 = math.abs(r21) + 1e-6, math.abs(r22) + 1e-6, math.abs(r23) + 1e-6
	local m31, m32, m33 = math.abs(r31) + 1e-6, math.abs(r32) + 1e-6, math.abs(r33) + 1e-6
	return math.abs(x) > ax + bx * m11 + by * m12 + bz * m13
		or math.abs(y) > ay + bx * m21 + by * m22 + bz * m23
		or math.abs(z) > az + bx * m31 + by * m32 + bz * m33
		or math.abs(x * r11 + y * r21 + z * r31) > bx + ax * m11 + ay * m21 + az * m31
		or math.abs(x * r12 + y * r22 + z * r32) > by + ax * m12 + ay * m22 + az * m32
		or math.abs(x * r13 + y * r23 + z * r33) > bz + ax * m13 + ay * m23 + az * m33
		or math.abs(z * r21 - y * r31) > ay * m31 + az * m21 + by * m13 + bz * m12
		or math.abs(z * r22 - y * r32) > ay * m32 + az * m22 + bx * m13 + bz * m11
		or math.abs(z * r23 - y * r33) > ay * m33 + az * m23 + bx * m12 + by * m11
		or math.abs(x * r31 - z * r11) > ax * m31 + az * m11 + by * m23 + bz * m22
		or math.abs(x * r32 - z * r12) > ax * m32 + az * m12 + bx * m23 + bz * m21
		or math.abs(x * r33 - z * r13) > ax * m33 + az * m13 + bx * m22 + by * m21
		or math.abs(y * r11 - x * r21) > ax * m21 + ay * m11 + by * m33 + bz * m32
		or math.abs(y * r12 - x * r22) > ax * m22 + ay * m12 + bx * m33 + bz * m31
		or math.abs(y * r13 - x * r23) > ax * m23 + ay * m13 + bx * m32 + by * m31
end

-- whether an arm, posed so, is clear of every part of the rider (its first `links` links)
local function clear(arm: Arm, abs: { CFrame }, limbs: { Link }, links: number, skin: number): boolean
	local at = arm.Rest[1]
	for i = 1, math.min(links, #arm.Links) do
		local link = arm.Links[i]
		local frame = CFrame.new(at) * abs[i] * link.Frame
		for _, b in limbs do
			local off = (frame.Position - b.Frame.Position).Magnitude
			if off < link.Reach + b.Reach + skin and not apart(link, frame, b, skin) then
				return false
			end
		end
		at += abs[i] * (arm.Rest[i + 1] - arm.Rest[i])
	end
	return true
end

-- An arm round you: a hook of its three links. `at` (fish space) is the middle of what it goes round, `along` the way
-- that lies; the last link lies across it `rho` off, `round` (0 to 1) of the way round it.
function EatMoves.hook(arm: Arm, at: Vector3, along: Vector3, round: number, rho: number): { CFrame }
	local base = arm.Rest[1]
	local l1 = (arm.Rest[2] - arm.Rest[1]).Magnitude
	local l2 = (arm.Rest[3] - arm.Rest[2]).Magnitude
	local l3 = (arm.Rest[4] - arm.Rest[3]).Magnitude
	local d = at - base
	d = d - along * d:Dot(along) -- (it comes in from its own side, square to what it goes round)
	d = if d.Magnitude > 0.05 then d.Unit else -arm.Out
	-- the side it goes round: the same way round for every arm
	local s = along:Cross(d).Unit
	local turn = Ease.lerp(rad(35), rad(128), round)
	local touch = at + (-d * math.cos(turn) + s * math.sin(turn)) * rho
	local lie = d * math.sin(turn) + s * math.cos(turn)
	local p3 = touch - lie * l3 * 0.42
	local gap = p3 - base
	local span = gap.Magnitude
	local p2: Vector3
	if span >= l1 + l2 - 0.01 then
		p2 = base + gap.Unit * l1
		p3 = base + gap.Unit * (l1 + l2)
		lie = (touch + lie * l3 * 0.58 - p3)
		lie = if lie.Magnitude > 0.01 then lie.Unit else d
	else
		span = math.max(span, math.abs(l1 - l2) + 0.01)
		local flatTo = gap.Unit
		local x = (l1 * l1 - l2 * l2 + span * span) / (2 * span)
		local out = math.sqrt(math.max(l1 * l1 - x * x, 0))
		-- (the elbow out to the side it goes round, and outward from the body's axis)
		local bulge = s * 0.5 + arm.Out
		bulge = bulge - flatTo * bulge:Dot(flatTo)
		bulge = if bulge.Magnitude > 0.01 then bulge.Unit else s
		p2 = base + flatTo * x + bulge * out
	end
	local p4 = p3 + lie * l3
	local points = { base, p2, p3, p4 }
	local abs: { CFrame } = {}
	for i = 1, 3 do
		abs[i] = between((arm.Rest[i + 1] - arm.Rest[i]).Unit, (points[i + 1] - points[i]).Unit)
	end
	return abs
end

-- An arm closing on you as a hand does: from where it was (`was`: 0 open, 1 shut, below 0 spread wider still), on toward
-- `want` and no further than where it first meets any part of you; where you have moved into it, it gives way. Never
-- faster than `most` a frame, so it never jumps. Returns how far closed it is now.
local function close(
	arm: Arm,
	limbs: { Link },
	was: number,
	want: number,
	most: number,
	pose: (number) -> { CFrame }
): number
	local function ok(c: number): boolean
		return clear(arm, pose(c), limbs, 3, SKIN)
	end
	local good: number, bad: number? = was, nil
	if ok(was) then
		local to = math.clamp(want, was - most, was + most)
		if to == was then
			return was
		end
		for i = 1, 3 do
			local c = Ease.lerp(was, to, i / 3)
			if not ok(c) then
				bad = c
				break
			end
			good = c
		end
	elseif not ok(-1) then
		return was -- (you are against its very root: no opening would help)
	else
		-- (give way: the nearest place back along its way that is clear)
		bad = was
		good = math.max(was - most * 2, -1)
		for i = 1, 6 do
			local c = math.max(was - most * i / 3, -1)
			if ok(c) then
				good = c
				break
			end
			bad = c
		end
	end
	if bad and good ~= bad then
		for _ = 1, 5 do
			local mid = (good + bad) / 2
			if ok(mid) then
				good = mid
			else
				bad = mid
			end
		end
	end
	return good
end

homeOf = function(p: Plan): number
	local m = Config.Fail.EatMoves.Wrap
	local least = SOLES + m.Beak
	local best = math.max(least, p.Caught.Z - p.Crown.Z)
	while best - 0.1 >= least do
		local frame = CFrame.new(p.Crown + Vector3.new(0, 0, best - 0.1)) * CFrame.Angles(rad(90), 0, 0)
		local limbs: { Link } = {}
		for _, row in STANDING do
			table.insert(limbs, boxOf(frame * CFrame.new(row[1]), row[2]))
		end
		for _, arm in p.Given.Arms do
			local spread = bent(arm, { rad(m.Spread), 0, 0 }, 0)
			if not clear(arm, spread, limbs, 2, m.Room) then
				return best
			end
		end
		best -= 0.1
	end
	return best
end

-- what an arm goes round: its middle and the way it lies, in the fish's space
export type Grip = { At: Vector3, Along: Vector3 }

-- every arm's links, as turns in the fish's space. `limbs` are the rider's parts where they really are (fish space): no
-- arm goes through them. `state` is kept between frames (by FailController): how far closed each arm is, and its last pose.
function EatMoves.arms(
	p: Plan,
	u: number,
	dt: number,
	grips: { Grip? },
	limbs: { Link },
	state: ArmsHeld
): { { CFrame } }
	local m = Config.Fail.EatMoves.Wrap
	local all: { { CFrame } } = {}
	for i, arm in p.Given.Arms do
		if #arm.Links ~= 3 then
			all[i] = loose(p, i, u)
			continue
		end
		local side = AXIS:Cross(arm.Out).Unit
		local taker = table.find(p.Takers, i)
		local grip = if taker then grips[taker] else nil
		local from = if taker then m.Take + (taker - 1) * m.TakeEach else math.huge
		local taking = grip ~= nil and u > from
		local start: { CFrame } = if taking
			then loose(p, i, from)
			else bent(arm, { rad(m.Flower[1]), rad(m.Flower[2]), rad(m.Flower[3]) }, 0)
		local to = loose(p, i, u)
		local half = math.max(arm.Links[3].Half.X, arm.Links[3].Half.Y)
		local function pose(c: number): { CFrame }
			local open = CFrame.fromAxisAngle(side, rad(90) * math.max(-c, 0))
			c = math.max(c, 0)
			local a, b, w = start, to, c
			if taking and grip then
				local rho = Ease.lerp(m.Clear + half, half * 0.5, ss(0.6, 1, c))
				b = EatMoves.hook(arm, grip.At, grip.Along, ss(0.4, 0.8, c), rho)
				w = ss(0, 0.6, c)
			end
			return { open * a[1]:Lerp(b[1], w), open * a[2]:Lerp(b[2], w), open * a[3]:Lerp(b[3], w) }
		end
		local was = state[i]
		if taking and (not was or not was.Taking) then
			was = { At = if was then math.min(was.At, 0) else 0, Taking = true, Abs = if was then was.Abs else nil }
		elseif not was then
			was = { At = 1, Taking = false }
		end
		local want = if taking then ss(from, from + m.TakeTime * 1.3, u) else 1
		local now = close(arm, limbs, was.At, want, math.clamp(dt, 0, 0.1) * m.CloseRate, pose)
		-- (and no link turns faster than this, however you are flung about in it)
		local abs = pose(now)
		local last = if was then was.Abs else nil
		if last and dt > 0 then
			local held: { CFrame } = {}
			for k, turn in abs do
				local _, angle = (last[k]:Inverse() * turn):ToAxisAngle()
				local most = rad(m.Turn) * math.clamp(dt, 0, 0.1)
				held[k] = if math.abs(angle) > most then last[k]:Lerp(turn, most / math.abs(angle)) else turn
			end
			if clear(arm, held, limbs, 3, 0) then
				abs = held -- (but it would sooner jump than go through you)
			end
		end
		state[i] = { At = now, Taking = taking, Abs = abs }
		all[i] = abs
	end
	return all
end

-- where the points of an arm are with these turns (its pivots, then its tip)
function EatMoves.points(arm: Arm, abs: { CFrame }): { Vector3 }
	local list = { arm.Rest[1] }
	for i = 1, #arm.Rest - 1 do
		list[i + 1] = list[i] + abs[i] * (arm.Rest[i + 1] - arm.Rest[i])
	end
	return list
end

----------------------------------------------------------------------------------------------------------------------
-- The shot, the same for both: one swing from where the view is to the side of the fish, at an even turn, then it only
-- follows, and at the end stands still and watches. `from`: the view's way as it began (from the fish to the camera).
function EatMoves.shot(p: Plan, from: Vector3, side: number, t: number): (Vector3, number)
	local e = Config.Fail.EatMoves
	local s = e.Shot
	local L = p.Given.Length
	local right = p.Forward:Cross(Vector3.yAxis).Unit
	local to = (right * side + p.Forward * -s.Back + Vector3.yAxis * s.Up).Unit
	local start = if from.Magnitude > 0.1 then from.Unit else to
	local axis = start:Cross(to)
	local dir = to
	if axis.Magnitude > 1e-3 then
		local angle = math.acos(math.clamp(start:Dot(to), -1, 1))
		dir = CFrame.fromAxisAngle(axis.Unit, angle * ss(0, Config.Fail.CameraTime, t)) * start
	end
	local far = if p.Given.Kind == "Chomp" then L * s.Chomp + s.Off else L * s.Wrap + s.Off
	return dir, Ease.lerp(math.max(from.Magnitude, 8), far, ss(0, Config.Fail.CameraTime, t))
end

return EatMoves
