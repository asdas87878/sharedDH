--!strict
-- The air hop (Hugo, 2026-11-25; docs/design/submarine.md, "The air hop"): the rider jumps off their leaping ride fish at
-- the top of its arc onto the seat of the sub, which comes flying in from behind, noses down and splashes into the water,
-- straight into its run. Everything in it as a function of the seconds since the leap began, the same on the server, on
-- every machine and in the offline check (tools/subs/air_check.luau). The numbers are Config.Sub's Air ones. SubTrip has
-- the trip itself (phases, the run) and calls this one for everything before the run; nothing here needs SubTrip.
--   Seconds from the leap's start (server time), in order:
--     the crouch at the lip, the fish's arc (the dive's own: DiveController.planOf has the same sums);
--     HopAt: off the saddle;  SeatAt: on the seat;  SplashAt: the sub's middle in the water;  RideAt: the run begins;
--     the fish's own entry (Crouch + Time), about as the run begins, and its swim up to the sub (SubTrip.escort).
local Config = require(script.Parent.Config)
local Ease = require(script.Parent.Ease)

local UP = Vector3.yAxis

-- The fish's leap, as its rider's machine plans it: the rider's root (the saddle) along it
export type Leap = {
	Take: Vector3, -- where the arc begins (the root, at the lip),
	Heading: Vector3, -- the way it goes, flat,
	Far: number, -- the arc: Far out and Rise * u - Fall * u * u up, at u of the way,
	Rise: number,
	Fall: number,
	Crouch: number, -- after this long crouching,
	Time: number, -- in this long, seconds
	Tilts: { number }, -- how far its nose is down along it, degrees, evenly spaced over it
}

export type Air = {
	Leap: Leap,
	Half: Vector3, -- half the fish's box
	Saddle: Vector3, -- its saddle against its root
	HopAt: number,
	SeatAt: number,
	SplashAt: number,
	RideAt: number,
	Out: Vector3, -- the lane's way, flat
	Meet: Vector3, -- the sub's middle as its seat meets the rider
	Slope: number, -- how steeply it comes in down to there, radians
	Fall: number, -- it comes down this far out from there, studs,
	Pick: Vector3, -- and begins its run here (the path's first point after the lead-in),
	Way: Vector3, -- this way
	Over: boolean, -- it came in over the gate's arch (else under the beam)
	Back: number, -- the fish begins its sweeps this long after the leap began
}

local SubAir = {}

SubAir.Seat = CFrame.new(0, 7.4, 5) -- (SubTrip.Seat)

local function hermite(p0: number, v0: number, p1: number, v1: number, time: number, t: number): number
	local s = math.clamp(t / math.max(time, 1e-3), 0, 1)
	local s2, s3 = s * s, s * s * s
	return (2 * s3 - 3 * s2 + 1) * p0 + (s3 - 2 * s2 + s) * time * v0 + (3 * s2 - 2 * s3) * p1 + (s3 - s2) * time * v1
end

local function hermite3(p0: Vector3, v0: Vector3, p1: Vector3, v1: Vector3, time: number, t: number): Vector3
	local s = math.clamp(t / math.max(time, 1e-3), 0, 1)
	local s2, s3 = s * s, s * s * s
	return p0 * (2 * s3 - 3 * s2 + 1)
		+ v0 * ((s3 - 2 * s2 + s) * time)
		+ p1 * (3 * s2 - 2 * s3)
		+ v1 * ((s3 - s2) * time)
end

----------------------------------------------------------------------------------------------------------------------
-- The fish's leap

-- The saddle at `t` seconds, in the air (held to the arc's ends outside it)
function SubAir.saddle(leap: Leap, t: number): Vector3
	local u = math.clamp((t - leap.Crouch) / leap.Time, 0, 1)
	return leap.Take + leap.Heading * (leap.Far * u) + UP * (leap.Rise * u - leap.Fall * u * u)
end

function SubAir.velocity(leap: Leap, t: number): Vector3
	local u = math.clamp((t - leap.Crouch) / leap.Time, 0, 1)
	return (leap.Heading * leap.Far + UP * (leap.Rise - 2 * leap.Fall * u)) / leap.Time
end

function SubAir.tilt(leap: Leap, t: number): number
	local n = #leap.Tilts
	local at = math.clamp((t - leap.Crouch) / leap.Time, 0, 1) * (n - 1)
	local i = math.min(math.floor(at), n - 2)
	return Ease.lerp(leap.Tilts[i + 1], leap.Tilts[i + 2], at - i)
end

-- The rider's seat on it, turned as it is
local function saddleFrame(leap: Leap, t: number): CFrame
	local at = SubAir.saddle(leap, t)
	return CFrame.lookAt(at, at + leap.Heading) * CFrame.Angles(-math.rad(SubAir.tilt(leap, t)), 0, 0)
end

function SubAir.entry(air: Air): number
	return air.Leap.Crouch + air.Leap.Time
end

-- The dip as the rider pushes off it
local function push(air: Air, t: number): number
	local k = math.clamp((t - air.HopAt) / 0.4, 0, 1)
	return Config.Sub.AirPush * math.sin(k * math.pi) * (1 - k)
end

-- The fish's root in the air
function SubAir.fish(air: Air, t: number): CFrame
	return saddleFrame(air.Leap, t) * CFrame.new(-air.Saddle) - UP * push(air, t)
end

-- A long fish takes this many times as long to come up to the sub
local function slower(half: Vector3): number
	return math.clamp((half.Z / 15) ^ 0.35, 1, 1.6)
end

-- How long it takes from its splash to its place beside the sub
function SubAir.joining(half: Vector3): number
	return Config.Sub.AirSwim * slower(half)
end

-- The fish after its splash: where it would swim on its own, its root: how far on from its entry along its way, and how high
function SubAir.swim(air: Air, t: number, depth: number): (number, number, number)
	local leap = air.Leap
	local entry = SubAir.entry(air)
	local since = math.max(t - entry, 0)
	local v = SubAir.velocity(leap, entry)
	local out = leap.Far / leap.Time
	local pace = Config.Sub.AirPace
	-- (from the leap's own pace to the swim's)
	local on = pace * since + (out - pace) * 0.4 * (1 - math.exp(-since / 0.4))
	local frame = SubAir.fish(air, entry)
	-- (down to its depth, the sooner the faster it went in)
	local deep = math.abs(frame.Position.Y - depth)
	local y = hermite(frame.Position.Y, v.Y, depth, 0, math.clamp(1.5 * deep / math.max(-v.Y, 30), 0.35, 0.8), since)
	-- (its nose comes up to level)
	local tilt = SubAir.tilt(leap, entry) * (1 - Ease.smoothstep(0, 0.45, since))
	return on, y, tilt
end

----------------------------------------------------------------------------------------------------------------------
-- The sub

local function across(air: Air): Vector3
	return air.Out:Cross(UP)
end

-- Its speed as it reaches the water: out, and down
local function fallen(air: Air): (number, number)
	local c = Config.Sub
	local time = air.SplashAt - air.SeatAt
	local out0, down0 = c.AirSpeed * math.cos(air.Slope), c.AirSpeed * math.sin(air.Slope)
	local out = math.max(2 * air.Fall / time - out0, 40)
	local down = math.clamp(2 * (air.Meet.Y - Config.Depth.SurfaceY) / time - down0, 40, 190)
	return out, down
end

-- How far back along its way in it is, `left` seconds before it meets the rider
local function back(left: number): number
	local c = Config.Sub
	local more = math.max(left - c.AirRushFrom, 0)
	return c.AirSpeed * left + c.AirRush * more * more / 2
end

-- The bump as the rider lands on it: 0 to 1 and back
local function bump(air: Air, t: number): number
	local k = (t - air.SeatAt) / math.max(Config.Sub.AirDipTime, 0.05)
	if k <= 0 or k >= 1 then
		return 0
	end
	return math.sin(k * math.pi) * (1 - k) * 1.6
end

-- Its middle, up to the run
function SubAir.middle(air: Air, t: number): Vector3
	local c = Config.Sub
	if t <= air.SeatAt then
		local b = back(air.SeatAt - t)
		return air.Meet - air.Out * (b * math.cos(air.Slope)) + UP * (b * math.sin(air.Slope))
	end
	local side = across(air)
	local to = air.Pick - air.Meet
	local over = to:Dot(side) * Ease.smoothstep(air.SeatAt, air.RideAt, t)
	local out, down = fallen(air)
	local surface = Config.Depth.SurfaceY
	local along: number, y: number
	if t < air.SplashAt then
		local time = air.SplashAt - air.SeatAt
		local v0 = c.AirSpeed
		along = hermite(0, v0 * math.cos(air.Slope), air.Fall, out, time, t - air.SeatAt)
		y = hermite(air.Meet.Y, -v0 * math.sin(air.Slope), surface, -down, time, t - air.SeatAt)
	else
		local time = air.RideAt - air.SplashAt
		along = hermite(air.Fall, out, to:Dot(air.Out), c.AirRun * air.Way:Dot(air.Out), time, t - air.SplashAt)
		y = hermite(surface, -down, air.Pick.Y, c.AirRun * air.Way.Y, time, t - air.SplashAt)
	end
	return air.Meet * Vector3.new(1, 0, 1) + air.Out * along + side * over + UP * y
end

-- The sub up to the run, and its speed
function SubAir.sub(air: Air, t: number): (CFrame, number)
	local c = Config.Sub
	local h = 0.03
	local at = SubAir.middle(air, t)
	local before, after = t - h, math.min(t + h, air.RideAt)
	local v = (SubAir.middle(air, after) - SubAir.middle(air, before)) / math.max(after - before, 1e-3)
	-- (over the top of the fall its nose is a little ahead of its way: it tips in)
	local lead = math.clamp((t - air.SeatAt) * 0.4, 0, 0.04)
	local ahead = if lead <= 0 or t + lead + h > air.RideAt
		then v
		else (SubAir.middle(air, t + lead + h) - SubAir.middle(air, t + lead - h)) / (2 * h)
	local out = math.max(ahead:Dot(air.Out), 1)
	local pitch = math.atan2(ahead.Y, out)
	pitch = math.max(pitch, -math.rad(c.AirNose))
	local flat = air.Out
	-- (onto the run's own line as it begins)
	local k = Ease.smoothstep(air.SplashAt, air.RideAt, t)
	local dir = flat * math.cos(pitch) + UP * math.sin(pitch)
	if k > 0 then
		dir = dir:Lerp(air.Way, k * k).Unit
	end
	local hit = bump(air, t)
	local cf = CFrame.lookAt(at, at + dir) * CFrame.Angles(math.rad(c.AirNod) * hit, 0, 0)
	return cf - UP * (c.AirDip * hit), v.Magnitude
end

-- The sub's speed in studs a second at the seat, along its way
local function meetVelocity(air: Air): Vector3
	local v = Config.Sub.AirSpeed
	return air.Out * (v * math.cos(air.Slope)) - UP * (v * math.sin(air.Slope))
end

----------------------------------------------------------------------------------------------------------------------
-- The rider

-- The hop from `from` (where they left the saddle, at `began`) to the seat, at `t`; `velocity` as they left it
function SubAir.hop(air: Air, from: CFrame, velocity: Vector3, began: number, t: number): CFrame
	local c = Config.Sub
	local ends = math.max(air.SeatAt, began + c.AirLate)
	local seat = SubAir.sub(air, math.max(t, 0)) * SubAir.Seat
	if t >= ends then
		return seat
	end
	local time = ends - began
	local goal = (SubAir.sub(air, ends) * SubAir.Seat).Position
	local goalV = meetVelocity(air)
	if ends > air.SeatAt + 1e-3 then
		goalV = (
			(SubAir.sub(air, ends + 0.02) * SubAir.Seat).Position
			- (SubAir.sub(air, ends - 0.02) * SubAir.Seat).Position
		) / 0.04
	end
	-- (up: so that two thirds of the way through it is AirOver over the seat; down onto it at AirDown)
	local climb = goal.Y - from.Y
	local down = (goalV.Y - c.AirDown) * time
	local s = 0.65
	local h10, h01, h11 = s * (1 - s) ^ 2, s * s * (3 - 2 * s), s * s * (s - 1)
	local launch = math.max((climb + c.AirOver - h01 * climb - h11 * down) / h10 / time, velocity.Y)
	local v0 = Vector3.new(velocity.X, launch, velocity.Z)
	local v1 = Vector3.new(goalV.X, goalV.Y - c.AirDown, goalV.Z)
	local at = hermite3(from.Position, v0, goal, v1, time, t - began)
	local k = (t - began) / time
	local turned = from.Rotation:Lerp(seat.Rotation, Ease.smoothstep(0, 1, k))
	-- (leaning into it as they go up, back as they come down)
	local lean = math.rad(-24) * math.sin(math.clamp(k / 0.6, 0, 1) * math.pi)
		+ math.rad(14) * math.sin(math.clamp((k - 0.5) / 0.5, 0, 1) * math.pi)
	return CFrame.new(at) * turned * CFrame.Angles(lean, 0, 0)
end

-- The rider in the plain case (word in time): on the saddle, in the hop, on the seat
function SubAir.rider(air: Air, t: number): CFrame
	if t <= air.HopAt then
		return saddleFrame(air.Leap, t)
	end
	return SubAir.hop(air, saddleFrame(air.Leap, air.HopAt), SubAir.velocity(air.Leap, air.HopAt), air.HopAt, t)
end

----------------------------------------------------------------------------------------------------------------------
-- The plan (the server)

-- Do two boxes meet? (half sizes; by their six faces and nine edges, in numbers: it runs some hundreds of times a plan)
function SubAir.meets(a: CFrame, ha: Vector3, b: CFrame, hb: Vector3): boolean
	local ax, ay, az = ha.X, ha.Y, ha.Z
	local bx, by, bz = hb.X, hb.Y, hb.Z
	local ra, rb = math.sqrt(ax * ax + ay * ay + az * az), math.sqrt(bx * bx + by * by + bz * bz)
	local dx, dy, dz = b.X - a.X, b.Y - a.Y, b.Z - a.Z
	if dx * dx + dy * dy + dz * dz > (ra + rb) ^ 2 then
		return false
	end
	local _, _, _, a00, a01, a02, a10, a11, a12, a20, a21, a22 = a:GetComponents()
	local _, _, _, b00, b01, b02, b10, b11, b12, b20, b21, b22 = b:GetComponents()
	-- the second's middle and axes in the first's frame
	local px = dx * a00 + dy * a10 + dz * a20
	local py = dx * a01 + dy * a11 + dz * a21
	local pz = dx * a02 + dy * a12 + dz * a22
	local r00, r01, r02 =
		a00 * b00 + a10 * b10 + a20 * b20, a00 * b01 + a10 * b11 + a20 * b21, a00 * b02 + a10 * b12 + a20 * b22
	local r10, r11, r12 =
		a01 * b00 + a11 * b10 + a21 * b20, a01 * b01 + a11 * b11 + a21 * b21, a01 * b02 + a11 * b12 + a21 * b22
	local r20, r21, r22 =
		a02 * b00 + a12 * b10 + a22 * b20, a02 * b01 + a12 * b11 + a22 * b21, a02 * b02 + a12 * b12 + a22 * b22
	local e = 1e-4
	local q00, q01, q02 = math.abs(r00) + e, math.abs(r01) + e, math.abs(r02) + e
	local q10, q11, q12 = math.abs(r10) + e, math.abs(r11) + e, math.abs(r12) + e
	local q20, q21, q22 = math.abs(r20) + e, math.abs(r21) + e, math.abs(r22) + e
	return not (
		math.abs(px) > ax + bx * q00 + by * q01 + bz * q02
		or math.abs(py) > ay + bx * q10 + by * q11 + bz * q12
		or math.abs(pz) > az + bx * q20 + by * q21 + bz * q22
		or math.abs(px * r00 + py * r10 + pz * r20) > bx + ax * q00 + ay * q10 + az * q20
		or math.abs(px * r01 + py * r11 + pz * r21) > by + ax * q01 + ay * q11 + az * q21
		or math.abs(px * r02 + py * r12 + pz * r22) > bz + ax * q02 + ay * q12 + az * q22
		or math.abs(pz * r10 - py * r20) > ay * q20 + az * q10 + by * q02 + bz * q01
		or math.abs(pz * r11 - py * r21) > ay * q21 + az * q11 + bx * q02 + bz * q00
		or math.abs(pz * r12 - py * r22) > ay * q22 + az * q12 + bx * q01 + by * q00
		or math.abs(px * r20 - pz * r00) > ax * q20 + az * q00 + by * q12 + bz * q11
		or math.abs(px * r21 - pz * r01) > ax * q21 + az * q01 + bx * q12 + bz * q10
		or math.abs(px * r22 - pz * r02) > ax * q22 + az * q02 + bx * q11 + by * q10
		or math.abs(py * r00 - px * r10) > ax * q10 + ay * q00 + by * q22 + bz * q21
		or math.abs(py * r01 - px * r11) > ax * q11 + ay * q01 + bx * q22 + bz * q20
		or math.abs(py * r02 - px * r12) > ax * q12 + ay * q02 + bx * q21 + by * q20
	)
end

-- The hull's box about its middle, `gap` more under it and at its ends: its middle against the sub's, and its half size
local function hullBox(hull: { number }, gap: number): (CFrame, Vector3)
	local wide, up, down, nose, tail = hull[1], hull[2], hull[3], hull[4], hull[5]
	-- (-Z ahead)
	return CFrame.new(0, (up - down) / 2, (tail - nose) / 2),
		Vector3.new(wide, (up + down) / 2 + gap, (nose + tail) / 2 + gap)
end

-- The plan, from the leap (nil: it can't be done). `hull`: SubTrip.Hulls' row; `lip`: the lip's middle, looking out;
-- `low`, `high`: how far to the left and the right of the lip's middle the sub may be. The run's start is filled in after
-- (SubAir.aim): it depends on the lane
function SubAir.plan(leap: Leap, half: Vector3, saddle: Vector3, hull: { number }, lip: CFrame, longer: number?): Air?
	local c = Config.Sub
	local hopTime = c.AirHopTime + (longer or 0)
	if leap.Fall <= 0 or leap.Time <= 0 then
		return nil
	end
	local out = Vector3.new(lip.LookVector.X, 0, lip.LookVector.Z).Unit
	local side = out:Cross(UP)
	local top = leap.Crouch + leap.Time * math.clamp(leap.Rise / (2 * leap.Fall), 0.05, 1)
	local entry = leap.Crouch + leap.Time
	local hopAt = math.clamp(top * c.AirAt, math.max(c.AirAtLeast, leap.Crouch), c.AirAtMost)
	-- (a long climb sooner, and over longer)
	hopAt = math.max(math.min(hopAt, entry - 0.3) - (longer or 0) / 2, leap.Crouch + 0.05)
	local seatAt = hopAt + hopTime
	local from = SubAir.saddle(leap, hopAt)
	local room = math.max(c.EscortGate - hull[1] - c.AirGap, 0)
	local lateral = math.clamp((SubAir.saddle(leap, seatAt) - lip.Position):Dot(side), -room, room)
	local on = (from - lip.Position):Dot(out) + c.AirAhead
	local air: Air = {
		Leap = leap,
		Half = half,
		Saddle = saddle,
		HopAt = hopAt,
		SeatAt = seatAt,
		SplashAt = seatAt + c.AirFall,
		RideAt = seatAt + c.AirFall + c.AirUnder,
		Out = out,
		Meet = Vector3.zero,
		Slope = 0,
		Fall = c.AirFallLeast,
		Pick = Vector3.zero,
		Way = out,
		Over = false,
		Back = 0,
	}
	local centre, size = hullBox(hull, c.AirGap)
	local function gate(box: { number }): (CFrame, Vector3)
		return lip * CFrame.new(0, (box[2] + box[3]) / 2 - lip.Y, -(box[4] + box[5]) / 2),
			Vector3.new(box[1], (box[3] - box[2]) / 2, (box[5] - box[4]) / 2)
	end
	local beam, beamHalf = gate(c.AirBeam)
	local crest, crestHalf = gate(c.AirCrest)
	local step = 0.035
	-- the fish's box over the time the sub is near it
	local fish: { CFrame } = {}
	local function fishAt(t: number): CFrame
		local i = math.floor(t / step + 0.5)
		local cf = fish[i]
		if not cf then
			cf = SubAir.fish(air, t)
			fish[i] = cf
		end
		return cf
	end
	-- coming in: the least rise over the saddle that takes it clear over the fish and clear of the arch, for each slope
	local base = lip.Position + out * on + side * lateral
	local function meetAt(slope: number, rise: number): Vector3
		local seat = CFrame.lookAt(Vector3.zero, out * math.cos(slope) - UP * math.sin(slope)) * SubAir.Seat
		return Vector3.new(base.X, from.Y + rise, base.Z) - seat.Position
	end
	-- (its way in is the same at every height: worked out once a slope)
	local function comingIn(): { CFrame }
		air.Meet = meetAt(air.Slope, 0)
		local poses = {}
		local t = air.SeatAt - step
		while t >= math.max(air.SeatAt - c.AirSeen, 0) do
			table.insert(poses, SubAir.sub(air, t) * centre)
			t -= step
		end
		return poses
	end
	local function comesIn(poses: { CFrame }, rise: number): boolean
		for i, pose in poses do
			local cf = pose + UP * rise
			-- (before the leap leaves the lip the fish is where it stands)
			if
				SubAir.meets(cf, size, fishAt(math.max(air.SeatAt - step * i, leap.Crouch)), half)
				or SubAir.meets(cf, size, beam, beamHalf)
				or SubAir.meets(cf, size, crest, crestHalf)
			then
				return false
			end
		end
		return true
	end
	-- the fall: the nearest place past the fish's nose
	local function comesDown(): boolean
		local high = air.Meet.Y - Config.Depth.SurfaceY
		local fall = c.AirFallLeast
		while fall <= c.AirFallMost do
			local time = math.max(c.AirFall, fall / c.AirFallPace, high * 1.5 / c.AirFallDrop)
			air.Fall = math.max(fall, c.AirSpeed * math.cos(air.Slope) * time * 0.9)
			air.SplashAt = air.SeatAt + time
			SubAir.aim(air, nil, nil)
			local clear = true
			local t = air.SeatAt
			while t <= air.RideAt + step do
				local cf = SubAir.sub(air, math.min(t, air.RideAt)) * centre
				if SubAir.meets(cf, size, fishAt(math.min(t, entry)), half) then
					clear = false
					break
				end
				t += step
			end
			if clear then
				return true
			end
			fall += 12
		end
		return false
	end
	local tried: { [number]: boolean } = {}
	while true do
		local best, bestRise, bestSlope = math.huge, 0, 0
		for _, degrees in c.AirSlopes do
			if tried[degrees] then
				continue
			end
			air.Slope = math.rad(degrees)
			local poses = comingIn()
			local rise = 4
			while rise <= c.AirRiseMost and rise + degrees * 0.4 < best do
				if comesIn(poses, rise) then
					best, bestRise, bestSlope = rise + degrees * 0.4, rise, degrees
					break
				end
				rise += 2
			end
		end
		if best == math.huge then
			return nil
		end
		local more = math.clamp((bestRise - c.AirClimb) * c.AirClimbSlow, 0, c.AirClimbMost)
		if not longer and more > 0.02 then
			return SubAir.plan(leap, half, saddle, hull, lip, more)
		end
		air.Slope = math.rad(bestSlope)
		air.Meet = meetAt(air.Slope, bestRise)
		if comesDown() then
			break
		end
		tried[bestSlope] = true
	end
	-- over the gate, or under its beam
	local atGate = (air.Meet - lip.Position):Dot(out) + 14
	air.Over = air.Meet.Y + atGate * math.tan(air.Slope) > c.AirBeam[2]
	air.Back = SubAir.entry(air) + SubAir.joining(half) * c.AirPeel
	return air
end

-- Where the run begins: straight on from the fall (or `pick`, and the way the path goes there)
function SubAir.aim(air: Air, pick: Vector3?, way: Vector3?)
	local c = Config.Sub
	air.RideAt = air.SplashAt + c.AirUnder
	local out = fallen(air)
	air.Pick = pick
		or (
			air.Meet * Vector3.new(1, 0, 1)
			+ air.Out * (air.Fall + (out + c.AirRun) / 2 * c.AirUnder)
			+ UP * (Config.Depth.SurfaceY - c.EscortUnder - 3)
		)
	air.Way = way or air.Out
end

return SubAir
