-- The new eating moves (Config.Fail.NewEat; docs/design/riding-feel.md, "Eaten without turning"), checked offline: the
-- real FailController and EatMoves played frame by frame (tools/eat/eat_world.luau) over every size and place, and the
-- moves they replace measured the same way.
--   python3 tools/eat/boxes.py > work/eat/boxes.json
--   rojo build default.project.json -o work/eat/place.rbxl
--   lune run tools/eat/eat_check.luau        (add `old` for the old moves' numbers, `all` for every case's row,
--     `Octopus` or `Kronosaurus` for only that one, `quick` for open water only)
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Harness = require("../index/harness")
local World = require("./eat_world")

local Vector3, CFrame = roblox.Vector3, roblox.CFrame
local DT = World.DT
local w = World.open("work/eat/place.rbxl")
local Config = w.Config
local moves = Config.Fail.EatMoves
local ok, done = Harness.tally()
local args: { [string]: boolean } = {}
for _, a in process.args do
	args[a] = true
end

local TIERS = { "Tiny", "Normal", "Big", "Giant", "Huge", "Colossal" }

local function angle(a: any, b: any): number
	if a.Magnitude < 1e-6 or b.Magnitude < 1e-6 then
		return 0
	end
	return math.deg(math.acos(math.clamp(a.Unit:Dot(b.Unit), -1, 1)))
end

-- how deep a ball of radius r at p is in a box (studs; below 0: that far clear)
local function depthIn(box: any, p: any, r: number): number
	local o = box.CFrame:PointToObjectSpace(p)
	local h = box.Size / 2
	local out = Vector3.new(
		math.max(math.abs(o.X) - h.X, 0),
		math.max(math.abs(o.Y) - h.Y, 0),
		math.max(math.abs(o.Z) - h.Z, 0)
	)
	if out.Magnitude > 0 then
		return r - out.Magnitude
	end
	return r + math.min(h.X - math.abs(o.X), h.Y - math.abs(o.Y), h.Z - math.abs(o.Z))
end

-- how deep two turned boxes are in each other (middle, three unit axes, half sizes): the least push that parts them;
-- below 0: at least that far apart
local function inside(a: any, b: any): number
	local way = b.mid - a.mid
	local least = math.huge
	local function try(axis: any)
		local long = axis.Magnitude
		if long < 1e-4 then
			return
		end
		axis /= long
		local ra, rb = 0, 0
		for n = 1, 3 do
			ra += a.half[n] * math.abs(axis:Dot(a.axes[n]))
			rb += b.half[n] * math.abs(axis:Dot(b.axes[n]))
		end
		least = math.min(least, ra + rb - math.abs(way:Dot(axis)))
	end
	local clear = way.Magnitude - a.reach - b.reach
	if clear > 0 then
		return -clear
	end
	for n = 1, 3 do
		try(a.axes[n])
		try(b.axes[n])
		for k = 1, 3 do
			try(a.axes[n]:Cross(b.axes[k]))
		end
	end
	return least
end

-- a part of the rider as one of those
local function bodyBox(cf: any, size: any): any
	return {
		mid = cf.Position,
		axes = { cf.XVector, cf.YVector, cf.ZVector },
		half = { size.X / 2, size.Y / 2, size.Z / 2 },
		reach = size.Magnitude / 2,
	}
end

-- every box an arm's link is really made of, as posed (boxes.py reads them off the mesh), by link's name
local function armBoxes(r: any, fr: any): { [string]: { any } }
	local list: { [string]: { any } } = {}
	for _, row in r.rig.Parts do
		local box = w.boxes[r.case.Creature][row[1]]
		if box[3] then
			local at = fr.pose[row[1]]
			local pivot = Vector3.new(row[3], row[4], row[5])
			local own: { any } = {}
			for _, piece in box[3] do
				local axes, half = {}, {}
				for n = 1, 3 do
					axes[n] = at:VectorToWorldSpace(Vector3.new(table.unpack(piece.axes[n])))
					half[n] = piece.half[n] * r.k
				end
				table.insert(own, {
					mid = at * ((Vector3.new(table.unpack(piece.mid)) - pivot) * r.k),
					axes = axes,
					half = half,
					reach = Vector3.new(half[1], half[2], half[3]).Magnitude,
				})
			end
			list[row[1]] = own
		end
	end
	return list
end

-- everything a play says about itself
local function measure(r: any): any
	local m: any = {
		yaw = 0, -- fastest turn of its heading, degrees a second
		yawAll = 0, -- and in all
		pitch = 0,
		apart = 0, -- seconds its body points more than 45 degrees off the way it goes
		nose = 0, -- fastest its nose goes, studs a second
		kick = 0, -- the biggest change of the fish's speed in one frame, studs a second
		riderKick = 0, -- and of the rider's (in sight)
		through = -math.huge, -- deepest the rider's chest is in a part of the fish before it has them, studs
		throughAt = 0,
		throughIn = "",
		high = -math.huge, -- the highest point of the rider over the surface
		fishHigh = -math.huge,
		low = math.huge, -- the lowest point of the fish over the floor
		wall = math.huge, -- studs of water left between the rider and the wall
		camTurn = 0, -- the fastest the view turns, degrees a second
		camAll = 0,
		outOfView = 0, -- seconds the rider or the mouth is out of the picture
		camNear = math.huge,
		biteFar = nil,
		mouthAngle = nil,
		behind = 0,
	}
	local case, frames = r.case, r.frames
	local chomp = case.Kind == "Chomp"
	local has = if case.New then (if chomp then moves.Chomp.Bite else moves.Wrap.Take) else (if chomp then 1.3 else 1.0)
	local L = r.body.Z
	local was: any = nil
	for i, fr in frames do
		local before = frames[i - 1]
		if before then
			local a, b = before.fish.LookVector * Vector3.new(1, 0, 1), fr.fish.LookVector * Vector3.new(1, 0, 1)
			-- (a fish pointing straight down has no heading: not counted within 20 degrees of it)
			if a.Magnitude > 0.34 and b.Magnitude > 0.34 then
				local yaw = math.abs(math.deg(math.atan2(a.X * b.Z - a.Z * b.X, a:Dot(b))))
				m.yawAll += yaw
				if yaw / DT > m.yaw then
					m.yaw, m.yawAt = yaw / DT, fr.t
				end
				if fr.t < 1.3 then
					m.yawEarly = math.max(m.yawEarly or 0, yaw / DT)
				end
			end
			m.pitch = math.max(
				m.pitch,
				math.abs(math.deg(math.asin(fr.fish.LookVector.Y) - math.asin(before.fish.LookVector.Y))) / DT
			)
			local v = (fr.fish.Position - before.fish.Position) / DT
			if v.Magnitude > 15 and angle(v, fr.fish.LookVector) > 45 then
				m.apart += DT
			end
			local nose = CFrame.new(0, 0, -L / 2)
			m.nose = math.max(m.nose, ((fr.fish * nose).Position - (before.fish * nose).Position).Magnitude / DT)
			local rv = (fr.torso - before.torso) / DT
			if was then
				if fr.t > 0.05 then
					m.kick = math.max(m.kick, (v - was.v).Magnitude)
				end
				if not fr.hidden and fr.t > 0.05 and (not chomp or fr.u < moves.Chomp.Bite) then
					if (rv - was.rv).Magnitude > m.riderKick then
						m.riderKick = (rv - was.rv).Magnitude
						m.riderKickAt = fr.t
					end
				end
			end
			was = { v = v, rv = rv }
			if before.camera and fr.camera then
				local turn = angle(before.camera.LookVector, fr.camera.LookVector)
				m.camAll += turn
				if turn / DT > m.camTurn then
					m.camTurn = turn / DT
					m.camAt = fr.t
				end
			end
		end
		-- the rider against the fish's own parts
		if fr.u > 0.3 and fr.u < has - 0.06 then
			for name, box in fr.boxes do
				local d = depthIn(box, fr.torso, 0.8)
				local whole = w.boxes[case.Creature][name]
				if d > 0 and chomp and whole[3] then
					-- (a head's slices, of which its box is the whole: there is open water under a snout)
					d = -math.huge
					local mid = (Vector3.new(table.unpack(whole[1])) + Vector3.new(table.unpack(whole[2]))) / 2
					for _, slice in whole[3] do
						local lo, hi = Vector3.new(table.unpack(slice[1])), Vector3.new(table.unpack(slice[2]))
						local own = {
							CFrame = box.CFrame * CFrame.new(((lo + hi) / 2 - mid) * r.k),
							Size = (hi - lo) * r.k,
						}
						d = math.max(d, depthIn(own, fr.torso, 0.8))
					end
				end
				if d > m.through then
					m.through, m.throughAt, m.throughIn = d, fr.u, name
				end
			end
		end
		-- behind its own mouth's plane (nothing it could bite)
		if fr.loose and fr.u < has and fr.fish:PointToObjectSpace(fr.torso).Z > -L * 0.25 then
			m.behind += DT
		end
		if not fr.hidden then
			m.high = math.max(m.high, fr.torso.Y + 1.5)
			if case.Wall then
				m.wall = math.min(m.wall, case.Wall + fr.torso.Z - 1)
			end
		end
		for _, box in fr.boxes do
			local c, h = box.CFrame, box.Size / 2
			local reach = math.abs(c.XVector.Y) * h.X + math.abs(c.YVector.Y) * h.Y + math.abs(c.ZVector.Y) * h.Z
			m.fishHigh = math.max(m.fishHigh, c.Position.Y + reach)
			if w.sea.floor then
				m.low = math.min(m.low, c.Position.Y - reach - w.sea.floor)
			end
		end
		-- the picture: the rider (till swallowed) and the mouth inside it (70 degrees up and down, 16:9)
		if fr.camera and fr.t > 0.25 and not fr.hidden then
			for _, p in { fr.torso, (fr.fish * CFrame.new(0, 0, if chomp then -L * 0.4 else 0)).Position } do
				local o = fr.camera:PointToObjectSpace(p)
				if o.Z > -1 or math.abs(o.Y / o.Z) > 0.66 or math.abs(o.X / o.Z) > 1.15 then
					m.outOfView += DT
					m.outAt = m.outAt or fr.t
					break
				end
			end
			m.camNear = math.min(m.camNear, (fr.camera.Position - fr.torso).Magnitude)
		end
		-- the bite
		if chomp and not m.biteFar and fr.u >= has then
			local mouth
			if case.New then
				mouth = fr.fish * w.EatMoves.mouthAt(r.plan.Given, 1)
			else
				mouth = (fr.fish * CFrame.new(0, -r.body.Y * 0.05, -L * 0.47)).Position
			end
			m.biteFar = (fr.torso - mouth).Magnitude
			m.biteAt = fr.t
		end
		if fr.hidden and not m.hideAt then
			m.hideAt = fr.t
		end
	end
	-- the arms and the rider (Wrap): every link's own boxes against every part of the rider, to the very end
	if case.Kind == "Wrap" and case.New then
		m.deep, m.deepAt, m.deepIn, m.deepFor = -math.huge, 0, "", 0
		m.touch = {}
		m.whip, m.whipAt = 0, 0
		local last: { [string]: any } = {}
		local owners: { [string]: number } = {}
		for n, index in r.plan.Takers do
			for _, j in r.f.Chains[index].Joints do
				owners[j.Name] = n
			end
			m.touch[n] = { worst = 0, sum = 0, count = 0 }
		end
		for _, fr in frames do
			if fr.u >= 0.12 then
				local arms = armBoxes(r, fr)
				local worst = -math.huge
				local near: { number } = { -math.huge, -math.huge, -math.huge }
				for _, row in World.R15 do
					if row[1] ~= "HumanoidRootPart" then
						local body = bodyBox(fr.rider * row[2], row[3])
						for name, own in arms do
							for _, piece in own do
								local d = inside(piece, body)
								worst = math.max(worst, d)
								if d > m.deep then
									m.deep, m.deepAt, m.deepIn = d, fr.u, name .. " in " .. row[1]
								end
								local n = owners[name]
								if n then
									near[n] = math.max(near[n], d)
								end
							end
						end
					end
				end
				if worst > 0.1 then
					m.deepFor += DT
				end
				for n, t in m.touch do
					local from = moves.Wrap.Take + (n - 1) * moves.Wrap.TakeEach + moves.Wrap.TakeTime * 1.3
					if fr.u >= from and fr.u <= Config.Fail.Outcomes.Wrap.Time then
						t.worst = math.max(t.worst, -near[n])
						t.sum += -near[n]
						t.count += 1
					end
				end
				-- how fast a link's middle goes, in the fish's own space (arms that jump)
				for name, own in arms do
					local at = fr.fish:PointToObjectSpace(own[1].mid)
					if last[name] then
						local v = (at - last[name]).Magnitude / DT / r.plan.Reach
						if v > m.whip then
							m.whip, m.whipAt, m.whipIn = v, fr.u, name
						end
					end
					last[name] = at
				end
				-- how near the beak: the soles to the arms' crown, along the body, when it is still
				if fr.u >= moves.Wrap.Still and not m.feet then
					local o = fr.fish:PointToObjectSpace((fr.rider * CFrame.new(0, -3.05, 0)).Position)
					m.feet = o.Z - r.plan.Crown.Z
					m.off = (o * Vector3.new(1, 1, 0) - r.plan.Crown * Vector3.new(1, 1, 0)).Magnitude
				end
			end
		end
		for _, t in m.touch do
			t.mean = t.sum / math.max(t.count, 1)
		end
	end
	return m
end

local function row(name: string, r: any, m: any)
	print(
		string.format(
			"%-26s yaw %4.0f/s@%.2f <1.3 %4.0f (%3.0f)  pitch %4.0f/s  apart %.2fs  nose %3.0f  kick %3.0f  rider kick %3.0f@%.2f  in body %5.2f %s@%.2f  cam %3.0f/s@%.2f (%3.0f)  out %.2f@%.2f  near %2.0f  high %5.1f  low %5.1f  wall %5.1f%s",
			name,
			m.yaw,
			m.yawAt or 0,
			m.yawEarly or 0,
			m.yawAll,
			m.pitch,
			m.apart,
			m.nose,
			m.kick,
			m.riderKick,
			m.riderKickAt or 0,
			m.through,
			m.throughIn,
			m.throughAt,
			m.camTurn,
			m.camAt or 0,
			m.camAll,
			m.outOfView,
			m.outAt or 0,
			m.camNear,
			m.high,
			m.low,
			m.wall,
			if r.case.Kind == "Chomp"
				then string.format("  bite off %.2f@%.2f hid %.2f", m.biteFar or -1, m.biteAt or -1, m.hideAt or -1)
				else (if m.touch and m.touch[3]
					then string.format(
						"  arms %.2f/%.2f %.2f/%.2f %.2f/%.2f deepest %.2f (%s) at %.2f, over 0.1 for %.2fs  feet %.2f off %.2f  whip %.1f@%.2f",
						m.touch[1].mean,
						m.touch[1].worst,
						m.touch[2].mean,
						m.touch[2].worst,
						m.touch[3].mean,
						m.touch[3].worst,
						m.deep,
						m.deepIn,
						m.deepAt,
						m.deepFor,
						m.feet or -1,
						m.off or -1,
						m.whip,
						m.whipAt
					)
					else "")
		)
	)
end

local KINDS = { { "Kronosaurus", "Chomp" }, { "Octopus", "Wrap" } }

if args.old then
	print("the old moves (NewEat 0), open water")
	for _, kind in KINDS do
		for _, tier in { "Normal", "Huge" } do
			local r = World.play(w, { Creature = kind[1], Tier = tier, Kind = kind[2], New = false })
			row(kind[1] .. " " .. tier, r, measure(r))
		end
	end
	print("the new ones")
end

for _, kind in KINDS do
	local id, outcome = kind[1], kind[2]
	for _, tier in TIERS do
		if (args.Octopus and id ~= "Octopus") or (args.Kronosaurus and id ~= "Kronosaurus") then
			continue
		end
		local fishType = Config.FishById[id]
		local L = fishType.Size.Z * Config.sizeScale(tier, fishType)
		local H = fishType.Size.Y * Config.sizeScale(tier, fishType)
		local places: { any } = {
			{ "open", {} },
			{ "floor", { FloorUnder = 12 + H * 0.5 } },
			{ "wall", { Wall = L * 0.8 + 10 } },
			{ "wall close", { Wall = L * 0.5 + 8 } },
			{ "surface", { Top = H * 0.5 + 8 } },
			{ "shallow", { Top = H * 0.5 + 10, FloorUnder = H * 0.5 + 12 } },
			{ "diving", { Pitch = -30 } },
			{ "climbing", { Pitch = 25 } },
			{ "slow", { Speed = 15 } },
			{ "late loose", { Late = 0.2 } },
			{ "heavy pull", { Lag = 2 } },
		}
		for _, place in places do
			if args.quick and place[1] ~= "open" then
				continue
			end
			local case: any = { Creature = id, Tier = tier, Kind = outcome, New = true }
			for key, value in place[2] do
				case[key] = value
			end
			local r = World.play(w, case)
			local m = measure(r)
			local name = id .. " " .. tier .. " " .. place[1]
			if args.all or args[tier] then
				row(name, r, m)
			end
			local bad: { string } = {}
			local function need(what: string, yes: boolean, value: any)
				if not yes then
					table.insert(
						bad,
						what
							.. " "
							.. (if type(value) == "number" then string.format("%.2f", value) else tostring(value))
					)
				end
			end
			local shallow = place[1] == "shallow"
			need("it is the new move", r.plan ~= nil, "")
			need("it never turns round (degrees of heading)", m.yawAll < 1, m.yawAll)
			need("body and path agree (s apart)", outcome == "Wrap" or m.apart < 0.2 or case.Wall ~= nil, m.apart)
			need("its nose never over 175 studs/s", m.nose < 175, m.nose)
			need("no jump of the fish (studs/s a frame)", m.kick < 35, m.kick)
			need("no jump of the rider", m.riderKick < 40, m.riderKick)
			need("the rider never in its body", m.through < 0.8, m.through)
			need("the rider under the surface", m.high < 1, m.high)
			need("the fish off the floor", m.low > -1.5 or shallow, m.low)
			need("the rider off the wall", m.wall > 0.3, m.wall)
			need("the view never whips (degrees/s)", m.camTurn < 190, m.camTurn)
			need("rider and mouth in the picture (s out)", m.outOfView < 0.1, m.outOfView)
			if outcome == "Chomp" then
				need("the mouth has them at the bite", m.biteFar and m.biteFar < 1.5 + L * 0.02, m.biteFar)
				need(
					"out of sight inside its time",
					m.hideAt and m.hideAt < Config.Fail.Outcomes.Chomp.Time - 0.1,
					m.hideAt
				)
			else
				for n, t in m.touch do
					need("arm " .. n .. " touches", t.mean < 0.3, t.mean)
				end
				need("no arm in them, all 24 links to the end (studs deep)", m.deep < 0.1, m.deep)
				need("drawn in to the beak (soles to the arms' crown)", m.feet and m.feet < 1.5 and m.feet > 0, m.feet)
				need("no arm jumps (arm lengths a second)", m.whip < 10, m.whip)
			end
			ok(name, #bad == 0, table.concat(bad, "; "))
		end
	end
end
done()
