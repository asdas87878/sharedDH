--!strict
-- Camera shakes: any number at once, added together (2026-11-16, the user: "professional camera shakes").
-- Until then RideController kept one shake: a new one replaced whatever was running, and every shake had the same
-- pattern. Here each moment has a character of its own (Config.Shake.Presets) and they add up:
--   a shake moves the camera (right, up, forward) AND turns it (nose, side, roll), each on its own smooth noise, so it
--     never repeats and never jumps between frames; a slow Rate reads as heavy, a quick one as sharp;
--   it comes on, holds and dies away on its own times (In, Hold, Out), dying quick at first with a long tail (Shape);
--   a Knock is a one-way push that swings back and settles: the nose dipping on a landing, the roll of a crash;
--   a rumble is a shake that stays for as long as its strength is kept up (a fish too strong, top speed).
-- RideController asks for the sum each frame (Shake.update) and puts it on the camera last. Nothing is made per frame:
-- a shake is one small table for as long as it lasts.
-- Everything is by the clock, never by the frame, so it looks the same at 30 and at 144 frames a second.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)

local Shake = {}

type Preset = Config.ShakePreset

type Source = {
	Preset: Preset,
	Strength: number,
	At: number, -- os.clock() it began
	Seed: number, -- its own pattern
	Side: number, -- which way its Knock rolls: -1, 1 (0: as the preset has it)
	Out: number?, -- its own time to die away (nil: the preset's)
	Want: number, -- a rumble's: the strength asked for, which Strength follows
	Held: boolean, -- a rumble: it lasts while Want is kept up
}

local sources: { Source } = {}
local rumbles: { [string]: Source } = {}
local moved = 0 -- how far the camera was moved the last frame, studs

-- the old single shake, as a preset: `size` studs either way, with the old roll (Jump.LandShakeRoll at Jump.LandShake)
local jolt: Preset = {
	Move = { 1, 1, 0 },
	Turn = { 0, 0, 2.4 },
	Rate = 16,
	In = 0,
	Hold = 0,
	Out = 0.38,
	Shape = 2,
}

local function preset(name: string): Preset?
	return Config.Shake.Presets[name]
end

local function scale(): number
	local s = Config.Shake
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	return math.max(s.Amount, 0) * (if touch then s.Touch else 1)
end

local function add(p: Preset, strength: number, side: number?, out: number?): Source
	local source: Source = {
		Preset = p,
		Strength = strength,
		At = os.clock(),
		Seed = math.random() * 1000,
		Side = side or 0,
		Out = out,
		Want = strength,
		Held = false,
	}
	table.insert(sources, source)
	return source
end

-- One shake of a kind (Config.Shake.Presets), `strength` times (1 without). `side`: which way its Knock rolls and
-- pushes, -1 for the left, 1 for the right (a hit from one side).
function Shake.play(name: string, strength: number?, side: number?)
	local p = preset(name)
	local by = strength or 1
	if p and by > 0 then
		add(p, by, side)
	end
end

-- One shake of a kind for something that happened at a place: full strength at the camera, none `radius` studs away
function Shake.at(name: string, place: Vector3, radius: number, strength: number?)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local near = 1 - (camera.CFrame.Position - place).Magnitude / math.max(radius, 1)
	if near > 0 then
		Shake.play(name, (strength or 1) * near * near)
	end
end

-- The old call (RideController.shake): thrown `size` studs either way, dying away over `time` seconds
function Shake.jolt(size: number, time: number?)
	if size > 0 then
		jolt.Rate = Config.Jump.LandShakeRate
		jolt.Turn[3] = Config.Jump.LandShakeRoll / math.max(Config.Jump.LandShake, 0.01)
		add(jolt, size, nil, time or Config.Jump.LandShakeTime)
	end
end

-- A shake that stays: call it every frame (or whenever it changes) with the strength wanted now; 0 lets it die away.
-- `key` names this rumble, so each can be kept up from its own place.
function Shake.rumble(key: string, name: string, strength: number)
	local source = rumbles[key]
	if not source then
		local p = preset(name)
		if not p or strength <= 0 then
			return
		end
		source = add(p, 0)
		source.Held = true
		rumbles[key] = source
	end
	source.Want = math.max(strength, 0)
end

-- Every shake's strength now: Shake.Amount, and less on a phone (Shake.Touch). For moves of the camera made
-- elsewhere that should answer the same dials (WildController's stride)
function Shake.amount(): number
	return scale()
end

-- How far the shakes moved the camera the last frame, studs (0: nothing running)
function Shake.moving(): number
	return moved
end

function Shake.clear()
	table.clear(sources)
	table.clear(rumbles)
	moved = 0
end

-- How much of a shake is left `t` seconds in (nil: it is over)
local function envelope(p: Preset, t: number, out: number): number?
	if t < p.In then
		return t / p.In
	end
	t -= p.In
	if t < p.Hold then
		return 1
	end
	t -= p.Hold
	if t >= out then
		return nil
	end
	return (1 - t / out) ^ p.Shape
end

-- This frame's shake, to put on the camera in its own space: all the shakes running, added together
function Shake.update(dt: number): CFrame
	if #sources == 0 then
		moved = 0
		return CFrame.identity
	end
	local s = Config.Shake
	local now = os.clock()
	local x, y, z = 0, 0, 0
	local nose, side, roll = 0, 0, 0
	for i = #sources, 1, -1 do
		local source = sources[i]
		local p = source.Preset
		local t = now - source.At
		local amount: number? = nil
		if source.Held then
			-- it follows what is asked of it, quickly up and a little slower down
			local rate = if source.Want > source.Strength then 10 else 4
			source.Strength += (source.Want - source.Strength) * (1 - math.exp(-rate * dt))
			if source.Want > 0 or source.Strength > 0.01 then
				amount = source.Strength
			end
		else
			local left = envelope(p, t, math.max(source.Out or p.Out, 0.01))
			if left then
				amount = left * source.Strength
			end
		end
		-- its Knock: a push one way that swings back and settles
		local knock = p.Knock
		local swung = 0
		if knock and not source.Held then
			local w = 2 * math.pi * (p.KnockRate or 3)
			local settle = math.exp(-(p.KnockDamp or 0.5) * w * t)
			if settle > 0.02 then
				swung = math.sin(w * t) * settle * source.Strength
			end
		end
		if not amount and swung == 0 then
			if source.Held then
				for key, held in rumbles do
					if held == source then
						rumbles[key] = nil
					end
				end
			end
			table.remove(sources, i)
		else
			if amount then
				local at = t * p.Rate
				local seed = source.Seed
				x += math.noise(seed, at) * 2 * p.Move[1] * amount
				y += math.noise(seed + 31.7, at) * 2 * p.Move[2] * amount
				z += math.noise(seed + 67.3, at) * 2 * p.Move[3] * amount
				nose += math.noise(seed + 101.9, at) * 2 * p.Turn[1] * amount
				side += math.noise(seed + 149.3, at) * 2 * p.Turn[2] * amount
				roll += math.noise(seed + 197.1, at) * 2 * p.Turn[3] * amount
			end
			if knock and swung ~= 0 then
				local way = if source.Side ~= 0 then source.Side else 1
				nose += knock[1] * swung
				roll += knock[2] * swung * way
				z += knock[3] * swung
				x += knock[3] * swung * 0.5 * (if source.Side ~= 0 then -source.Side else 0)
			end
		end
	end
	local by = scale()
	x, y, z = x * by, y * by, z * by
	nose, side, roll = nose * by, side * by, roll * by
	-- all together, never past what a view can take
	local far = math.sqrt(x * x + y * y + z * z)
	if far > s.MostMove and far > 0 then
		local keep = s.MostMove / far
		x, y, z = x * keep, y * keep, z * keep
		far = s.MostMove
	end
	local turned = math.max(math.abs(nose), math.abs(side), math.abs(roll))
	if turned > s.MostTurn and turned > 0 then
		local keep = s.MostTurn / turned
		nose, side, roll = nose * keep, side * keep, roll * keep
	end
	moved = far
	return CFrame.new(x, y, z) * CFrame.fromOrientation(math.rad(nose), math.rad(side), math.rad(roll))
end

return Shake
