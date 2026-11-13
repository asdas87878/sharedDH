-- B1 props playtest: the client driver (temporary; removed after the run). Commands through ReplicatedStorage.B1Cmd:
--   run <FishId> [hop 0|1] [hold 0|1]: onto that fish, straight at the nearest tall prop ahead, through it and on.
--     Logs the speed kept, what the server said (Crashed, Boost), the boxes out, the copies flying, how see-through
--     the prop got on our screen and whether it came back, and when the prop rebuilt and how far we were then.
--     hop 1: hops off a second before the prop and glides through it. hold 1: keeps Props.RegenRadius huge for
--     8 s after the break, to see that a prop does not come back with a player "near".
--     side <studs>: passes beside the prop instead, its body about that many studs clear of the prop's box.
--     Since p1 (2026-11-13) each run also logs a SEE line: how see-through the prop was before our body touched it
--     (must be 0 head on), our body's gap when it first turned, the touches and shakes, the most see-through while
--     in it, how often the see-through turned round (flicker), and when it was solid again after we were out.
--   cluster <FishId>: four pillars of our own (this machine only) in a row dead ahead, to see the shakes are kept
--     Props.ShakeGap apart
--   suite: the four kinds of fish, the hop and the hold; then the passes beside and the cluster
--   set <Group> <Key> <value>
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LogService = game:GetService("LogService")
local CollectionService = game:GetService("CollectionService")
local player = Players.LocalPlayer
local report = RS:WaitForChild("B1Report")
local cmd = RS:WaitForChild("B1Cmd")
local serverOut = RS:WaitForChild("B1Out")
local function log(...)
	report:FireServer(string.format(...))
end
LogService.MessageOut:Connect(function(message, kind)
	if kind == Enum.MessageType.MessageWarning or kind == Enum.MessageType.MessageError then
		report:FireServer("CLIENT " .. kind.Name .. ": " .. message)
	end
end)
local Client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local RideController = require(Client:WaitForChild("Controllers"):WaitForChild("RideController"))
local PropController = require(Client.Controllers:WaitForChild("PropController"))
local Actions = require(Client:WaitForChild("Lib"):WaitForChild("Actions"))
local State = require(Client.Lib:WaitForChild("State"))
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Net = require(RS.Shared:WaitForChild("Net"))

local function rootOf()
	local _, root = State.character()
	return root
end
local function yawOf(v)
	return math.atan2(-v.X, -v.Z)
end
local function tune(group, key, value)
	Config[group][key] = value
	Config.refresh()
	Net.Sandbox:FireServer("Tune", group .. "." .. key, value)
end
local function settle(time)
	local t0 = os.clock()
	while os.clock() - t0 < time do
		RunService.RenderStepped:Wait()
	end
end
local function waitFor(test, time)
	local t0 = os.clock()
	while os.clock() - t0 < time do
		if test() then
			return true
		end
		RunService.RenderStepped:Wait()
	end
	return false
end

-- steering: the view is turned to a point each frame (the fish goes where the camera looks)
local aim = nil
RunService:BindToRenderStep("B1Look", Enum.RenderPriority.Input.Value + 1, function()
	local root = rootOf()
	if aim and root then
		local d = aim() - root.Position
		if d.Magnitude > 1 then
			RideController.look(yawOf(d), math.asin(math.clamp(d.Unit.Y, -1, 1)))
		end
	end
end)
RideController.moveVector = function()
	return Vector3.zero
end

local events = {}
Net.Ride.OnClientEvent:Connect(function(kind, a, b, c, d, e)
	if kind == "Crashed" or kind == "Boost" then
		table.insert(events, { Kind = kind, A = a, B = b, C = c, D = d, E = e })
	end
end)

local function getOn(id)
	aim = nil
	for try = 1, 3 do
		Net.Sandbox:FireServer("Ride", id, "")
		settle(0.5)
		if waitFor(function()
			return State.Mode == "Riding" and State.Fish ~= nil
		end, 9) then
			return true
		end
		log("getOn: try %d failed (mode %s)", try, State.Mode)
	end
	return false
end

-- the nearest tall prop ahead of us that is whole (and not one a run could not steer to: `missed`)
local missed = {}
local function pickProp(root, way)
	local props = workspace.ClaudeBlockout.Lane.Props
	local best, bestFar, bestCf, bestSize = nil, math.huge, nil, nil
	for _, model in props:GetChildren() do
		local boxes = model:GetChildren()
		if #boxes >= 10 then
			local cf, size = model:GetBoundingBox()
			local off = cf.Position - root.Position
			local ahead = off:Dot(way)
			local side = (off - way * ahead).Magnitude
			local whole = true
			for _, box in boxes do
				if CollectionService:HasTag(box, "PropOut") then
					whole = false
				end
			end
			if
				whole
				and not missed[model]
				and size.Y >= 18
				and ahead > 220
				and ahead < 1200
				and side < 200
				and ahead < bestFar
			then
				best, bestFar, bestCf, bestSize = model, ahead, cf, size
			end
		end
	end
	return best, bestCf, bestSize
end

local function seeThrough(model)
	local most, least, n = 0, 1, 0
	for _, box in model:GetChildren() do
		if box:IsA("BasePart") then
			n += 1
			most = math.max(most, box.LocalTransparencyModifier)
			least = math.min(least, box.LocalTransparencyModifier)
		end
	end
	return least, most, n
end
local function tagsOf(model)
	local n = 0
	for _, box in model:GetChildren() do
		if CollectionService:HasTag(box, "PropOut") then
			n += 1
		end
	end
	return n
end

-- our body as PropController takes it: a rod from tail to nose on a fish, a point off one; and its gap to a prop
local function bodyNow()
	local root = rootOf()
	local fish = State.Fish
	if State.Mode == "Riding" and fish and fish.PrimaryPart then
		local kind = Config.FishById[fish:GetAttribute("FishType")]
		local size = Config.bodyOf(fish, kind)
		local cf = fish.PrimaryPart.CFrame
		local radius = math.min(math.max(size.X, size.Y), size.Z) / 2
		local half = math.max(size.Z / 2 - radius, 0)
		return cf.Position - cf.LookVector * half, cf.Position + cf.LookVector * half, radius
	end
	return root.Position, root.Position, 2.5
end
local function gapTo(model)
	local tail, nose, radius = bodyNow()
	local least = math.huge
	for _, box in model:GetChildren() do
		if box:IsA("BasePart") and not CollectionService:HasTag(box, "PropOut") then
			local ab = nose - tail
			local on = tail
			if ab.Magnitude > 0.01 then
				on = tail + ab * math.clamp((box.Position - tail):Dot(ab) / ab:Dot(ab), 0, 1)
			end
			local own = box.CFrame:PointToObjectSpace(on)
			local h = box.Size / 2
			local near =
				Vector3.new(math.clamp(own.X, -h.X, h.X), math.clamp(own.Y, -h.Y, h.Y), math.clamp(own.Z, -h.Z, h.Z))
			least = math.min(least, (own - near).Magnitude - radius)
		end
	end
	return least
end

-- how near the line from our middle to the camera comes to a prop (PropController's view rule, Props.ViewNear)
local function viewGapTo(model)
	local tail, nose = bodyNow()
	local at = (tail + nose) / 2
	local eye = workspace.CurrentCamera.CFrame.Position
	local ab = eye - at
	local least = math.huge
	for _, box in model:GetChildren() do
		if box:IsA("BasePart") and not CollectionService:HasTag(box, "PropOut") then
			local on = at
			if ab:Dot(ab) > 1e-6 then
				on = at + ab * math.clamp((box.Position - at):Dot(ab) / ab:Dot(ab), 0, 1)
			end
			local own = box.CFrame:PointToObjectSpace(on)
			local h = box.Size / 2
			local near =
				Vector3.new(math.clamp(own.X, -h.X, h.X), math.clamp(own.Y, -h.Y, h.Y), math.clamp(own.Z, -h.Z, h.Z))
			least = math.min(least, (own - near).Magnitude)
		end
	end
	return least
end

-- the flying copies of a broken prop's boxes (p2, 2026-11-13): how see-through each is against how far it is from
-- the line camera to us (as PropController counts it: less half the box's biggest side), while it is younger than
-- Props.Hang, so the fade-out at the end of its life is not in the numbers
local EDGES = { 0, 6, 12, 18, 24, 30, 45 }
local debrisBins, debrisAge = {}, {}
local function resetDebris()
	table.clear(debrisBins)
	table.clear(debrisAge)
	-- (copies already flying, from a small prop broken on the way, are old: never counted)
	local holder = workspace.CurrentCamera:FindFirstChild("PropDebris")
	for _, copy in if holder then holder:GetChildren() else {} do
		debrisAge[copy] = -math.huge
	end
end
local function sampleDebris(me)
	local holder = workspace.CurrentCamera:FindFirstChild("PropDebris")
	if not holder then
		return
	end
	local eye = workspace.CurrentCamera.CFrame.Position
	local now = os.clock()
	local fish = State.Fish
	if State.Mode == "Riding" and fish and fish.PrimaryPart then
		me = fish.PrimaryPart.Position -- (PropController's "us" on a fish is the fish's middle)
	end
	for _, copy in holder:GetChildren() do
		if copy:IsA("BasePart") then
			debrisAge[copy] = debrisAge[copy] or now
			-- (not its first 0.15 s: the see-through eases in; and not once it has begun to fade away)
			local age = now - debrisAge[copy]
			if age > 0.15 and age < Config.Props.Hang - 0.05 then
				local ab = me - eye
				local on = eye
				if ab:Dot(ab) > 1e-6 then
					on = eye + ab * math.clamp((copy.Position - eye):Dot(ab) / ab:Dot(ab), 0, 1)
				end
				local far = (copy.Position - on).Magnitude - math.max(copy.Size.X, copy.Size.Y, copy.Size.Z) / 2
				local bin = #EDGES + 1
				for i, edge in EDGES do
					if far < edge then
						bin = i
						break
					end
				end
				local b = debrisBins[bin] or { N = 0, Sum = 0, Low = 1, High = 0 }
				debrisBins[bin] = b
				local t = copy.LocalTransparencyModifier
				b.N += 1
				b.Sum += t
				b.Low = math.min(b.Low, t)
				b.High = math.max(b.High, t)
			end
		end
	end
end
local function logDebris(id)
	local parts = {}
	for i = 1, #EDGES + 1 do
		local b = debrisBins[i]
		if b then
			local name = if i == 1
				then "touching"
				elseif i > #EDGES then string.format("%d+", EDGES[#EDGES])
				else string.format("%d-%d", EDGES[i - 1], EDGES[i])
			table.insert(parts, string.format("%s: %.2f (%.2f to %.2f, n %d)", name, b.Sum / b.N, b.Low, b.High, b.N))
		end
	end
	if #parts > 0 then
		log(
			"DEBRIS %s (Hang %.1f): see-through by studs from the line camera to us | %s",
			id,
			Config.Props.Hang,
			table.concat(parts, " | ")
		)
	end
	-- near (inside Props.DebrisNear) they are see-through to about FadeTo, from Props.DebrisFar on they are not
	local P = Config.Props
	for i = 1, #EDGES + 1 do
		local b = debrisBins[i]
		if b and b.N >= 5 then
			local low, high = EDGES[i - 1] or -math.huge, EDGES[i] or math.huge
			if high <= P.DebrisNear and b.Sum / b.N < P.FadeTo - 0.12 then
				log("CHECK FAIL: flying boxes under %d studs from us are only %.2f see-through", high, b.Sum / b.N)
			elseif low >= P.DebrisFar and b.Sum / b.N > 0.12 then
				log("CHECK FAIL: flying boxes over %d studs from us are %.2f see-through", low, b.Sum / b.N)
			end
		end
	end
end

-- frame times riding through the props of one stretch of the lane (p2): onto the fish at `startS` studs down the lane,
-- then from prop to prop (the nearest ahead, through its middle) for `seconds`
local function frames(id, startS, seconds, label)
	local was = Config.Sandbox.StartS
	tune("Sandbox", "StartS", startS)
	settle(0.5)
	if not getOn(id) then
		log("CHECK FAIL: no fish")
		tune("Sandbox", "StartS", was)
		return
	end
	settle(6) -- (this part of the map streams in)
	local root = rootOf()
	local way = root.AssemblyLinearVelocity
	way = if way.Magnitude > 5 then way.Unit else root.CFrame.LookVector
	way = Vector3.new(way.X, 0, way.Z).Unit
	local props = workspace.ClaudeBlockout.Lane.Props
	local target, targetAt = nil, nil
	local nextPick = 0
	aim = function()
		return targetAt or (rootOf().Position + way * 500)
	end
	local stats = PropController.Stats
	local t0, s0 = stats.Touches, stats.Shakes
	local dts = {}
	local roundMost, roundSum, throughMost = 0, 0, 0
	local from = root.Position
	local c0 = os.clock()
	while os.clock() - c0 < seconds do
		local dt = RunService.RenderStepped:Wait()
		root = rootOf()
		if not root then
			break
		end
		table.insert(dts, dt * 1000)
		roundMost = math.max(roundMost, stats.Round)
		roundSum += stats.Round
		throughMost = math.max(throughMost, stats.Through)
		local v = root.AssemblyLinearVelocity
		if v.Magnitude > 5 then
			way = way:Lerp(Vector3.new(v.X, 0, v.Z).Unit, 0.02).Unit
		end
		if os.clock() >= nextPick or (targetAt and (targetAt - root.Position):Dot(way) < 0) then
			nextPick = os.clock() + 0.5
			local best, bestFar = nil, math.huge
			for _, model in props:GetChildren() do
				if model ~= target and #model:GetChildren() >= 4 then
					local at = model:GetPivot().Position
					local off = at - root.Position
					local ahead = off:Dot(way)
					if
						ahead > 30
						and ahead < 400
						and (off - way * ahead).Magnitude < ahead * 0.5
						and ahead < bestFar
					then
						best, bestFar = model, ahead
					end
				end
			end
			if best then
				target = best
				targetAt = best:GetBoundingBox().Position
			end
		end
	end
	aim = nil
	table.sort(dts)
	local sum = 0
	for _, d in dts do
		sum += d
	end
	local function at(q)
		return dts[math.clamp(math.ceil(#dts * q), 1, #dts)] or 0
	end
	local loaded = #props:GetChildren()
	log(
		"FRAMES %s %s from S %d, %.0f s, %.0f studs swum, %d props loaded | FadeTo %.2f | %d frames: mean %.2f ms, half under %.2f, 95%% under %.2f, 99%% under %.2f, worst %.2f | props watched: mean %.1f, most %d; see-through at once, most %d | touches %d, shakes %d",
		label or "",
		id,
		startS,
		seconds,
		(root.Position - from).Magnitude,
		loaded,
		Config.Props.FadeTo,
		#dts,
		sum / math.max(#dts, 1),
		at(0.5),
		at(0.95),
		at(0.99),
		dts[#dts] or 0,
		roundSum / math.max(#dts, 1),
		roundMost,
		throughMost,
		stats.Touches - t0,
		stats.Shakes - s0
	)
	tune("Sandbox", "StartS", was)
end

local laneWay = nil -- the way down the lane at the start, from the first run
local function run(id, hop, hold, side, again)
	local kind = Config.FishById[id]
	log(
		"RUN %s (%s; box %.0f cubic studs; breaks %s)%s%s",
		id,
		if kind.Archetype == "" then "no archetype" else kind.Archetype,
		Config.volumeOf(kind),
		tostring(Config.breaks(kind)),
		if hop then " HOP" else "",
		(if hold then " HOLD" else "") .. (if side then string.format(" BESIDE %g", side) else "")
	)
	if not getOn(id) then
		log("CHECK FAIL: no fish")
		return
	end
	-- (the view is where the last run left it: turned back down the lane, as the first run found it)
	if laneWay then
		local from = rootOf().Position
		aim = function()
			return from + laneWay * 2000
		end
	end
	settle(3) -- (the landing's dip and burst are over)
	aim = nil
	local root = rootOf()
	local way = root.AssemblyLinearVelocity
	way = if way.Magnitude > 5 then way.Unit else root.CFrame.LookVector
	way = Vector3.new(way.X, 0, way.Z).Unit
	laneWay = laneWay or way
	local model, cf, size = pickProp(root, way)
	if not model then
		local n, broken = 0, 0
		for _, m in workspace.ClaudeBlockout.Lane.Props:GetChildren() do
			n += 1
			broken += if tagsOf(m) > 0 then 1 else 0
		end
		log(
			"CHECK FAIL: no prop ahead (%d props loaded, %d with boxes out; way %.2f %.2f %.2f)",
			n,
			broken,
			way.X,
			way.Y,
			way.Z
		)
		return
	end
	local centre = cf.Position
	log(
		"prop %s: %d boxes, %.0f x %.0f x %.0f, %.0f studs ahead",
		model.Name,
		#model:GetChildren(),
		size.X,
		size.Y,
		size.Z,
		(centre - root.Position).Magnitude
	)
	-- through its middle and on, 400 studs past
	local through = centre
	if side then
		-- beside it: past the side of its box, our body about `side` studs clear
		local across = way:Cross(Vector3.yAxis).Unit
		-- (on the side we come from: the big props stand near a wall, and the far side has no room)
		if (root.Position - centre):Dot(across) < 0 then
			across = -across
		end
		local halfAcross = (
			math.abs(cf.RightVector:Dot(across)) * size.X
			+ math.abs(cf.UpVector:Dot(across)) * size.Y
			+ math.abs(cf.LookVector:Dot(across)) * size.Z
		) / 2
		local _, _, radius = bodyNow()
		through = centre + across * (halfAcross + side + radius)
	end
	aim = function()
		return through
	end
	local stats0 = { Touches = PropController.Stats.Touches, Shakes = PropController.Stats.Shakes }
	local see = {
		Before = 0, -- the most see-through while our body was still clear of it, before the first touch
		FirstGap = nil, -- our body's gap when it first turned see-through at all
		In = 0, -- the most see-through with our body in it
		MinGap = math.huge,
		Touched = false,
		ShakeGap = nil, -- our body's gap the frame the shake fired
		Turns = 0, -- how often the see-through changed direction (up, down: 2 is one clean fade and back)
		Last = 0,
		Dir = 0,
		Debris = 0,
		ShakeLeft = 0,
		Mine = 0, -- shakes while our body was at this prop; Other: at some other prop on the way (sea grass, a stone)
		Other = 0,
		MineTouches = 0,
		ModeAtTouch = nil,
		SpeedIn = nil, -- our speed (from where we were a frame ago) at the touch, and the least while in it
		SpeedLeast = math.huge,
		SeenShakes = PropController.Stats.Shakes,
		SeenTouches = PropController.Stats.Touches,
		LastAt = nil,
		LastMode = nil,
		Moved = 0,
		HopSpeed = nil, -- the rider's own speed a few frames into the hop
		Flat = 0, -- our speed across the water (no rise or fall in it)
		VelIn = nil, -- the engine's own speed of our body at the touch, and the least while in the prop
		VelLeast = math.huge,
		Dts = {},
		DtIn = 0,
		LastShakeAt = -math.huge, -- the last shake seen, at any prop
		PrevShaking = 0,
		HopFrames = nil,
		ViewHeld = nil, -- the most see-through with our body well clear and the prop on the line camera to us
		ViewHeldFrames = nil,
		SolidAt = nil, -- our body's gap and the view line's gap when it was solid again
	}
	table.clear(events)
	resetDebris()
	local full = 0
	local least = math.huge -- the least speed inside 60 studs of it, as a share of the speed we came with
	local nearest = math.huge
	local faded, flying, outMost, outServer = 0, 0, 0, 0
	local inside = false -- our middle was inside the prop's own box
	local hopped = false
	local passed = false
	local t0 = os.clock()
	local hoppedMode = nil
	local lastDt = 1 / 60
	while os.clock() - t0 < 25 do
		lastDt = RunService.RenderStepped:Wait()
		root = rootOf()
		if not root then
			break
		end
		local off = centre - root.Position
		local far = off.Magnitude
		local speed = root.AssemblyLinearVelocity.Magnitude
		if far > 90 and far < 150 and not passed then
			full = math.max(full, speed)
		end
		if hop and not hopped and far < speed * 0.6 + 22 then
			hopped = true
			see.Had = speed
			see.Launch, see.Extra = Config.hopFrom(speed, kind, nil)
			log("hop pressed %.0f studs from the prop: %s", far, tostring(Actions.jump()))
		end
		if far < 60 and full > 0 then
			least = math.min(least, speed / full)
			if hop then
				hoppedMode = State.Mode
			end
		end
		nearest = math.min(nearest, far)
		local own = cf:PointToObjectSpace(root.Position)
		if math.abs(own.X) < size.X / 2 and math.abs(own.Y) < size.Y / 2 and math.abs(own.Z) < size.Z / 2 then
			inside = true
		end
		local _, most = seeThrough(model)
		local stats = PropController.Stats
		if tagsOf(model) == 0 then
			faded = math.max(faded, most)
		end
		local g = gapTo(model)
		see.MinGap = math.min(see.MinGap, g)
		-- (our speed from where our body was a frame ago; the hop changes the body, from the fish to the rider, so
		-- that one frame's jump from the fish's tail to the rider is not read as a speed)
		-- (the body's middle, not its tail: the tail swings when the fish turns, and it turns in the prop, where
		-- the test aims it on down the lane)
		local bodyTail, bodyNose = bodyNow()
		local bodyAt = (bodyTail + bodyNose) / 2
		if see.LastAt and see.LastMode == State.Mode then
			see.Moved = see.Moved + ((bodyAt - see.LastAt).Magnitude / math.max(lastDt, 1e-3) - see.Moved) * 0.3
		end
		if see.LastAt and see.LastMode == State.Mode then
			local d = bodyAt - see.LastAt
			see.Flat = see.Flat + (Vector3.new(d.X, 0, d.Z).Magnitude / math.max(lastDt, 1e-3) - see.Flat) * 0.3
		end
		see.LastAt = bodyAt
		see.LastMode = State.Mode
		-- the hop against its own curve (Config.hopSpeed: the speed across the water, the jump's rise left out):
		-- the share of the curve we fly at before the prop, and the least share while in it
		if hop and hopped and State.Mode ~= "Riding" then
			see.HopT0 = see.HopT0 or (os.clock() - lastDt)
			local t = os.clock() - see.HopT0
			if t > 0.2 then -- (the smoothing has settled on the rider's own speed)
				local share = see.Flat / math.max(Config.hopSpeed(t, see.Launch, see.Extra), 1)
				if g <= 0 then
					see.CurveIn = math.min(see.CurveIn or math.huge, share)
					see.CurveAtTouch = see.CurveAtTouch or Config.hopSpeed(t, see.Launch, see.Extra)
					see.FlatAtTouch = see.FlatAtTouch or see.Flat
				elseif not see.Touched then
					see.CurveBefore = share
				end
			end
		end
		if hop and hopped and not see.HopSpeed and State.Mode ~= "Riding" and see.Moved > 0 then
			see.HopFrames = (see.HopFrames or 0) + 1
			if see.HopFrames >= 12 then -- (the smoothing has settled on the rider's own speed)
				see.HopSpeed = see.Moved
			end
		end
		-- the line from the camera to us against this prop, once our body is out of it and past the side rule:
		-- how see-through the view rule alone keeps it
		if see.Touched and g > Config.Props.SideNear + Config.Props.SideSlack + 1 and tagsOf(model) == 0 then
			local vg = viewGapTo(model)
			if vg <= Config.Props.ViewNear then
				see.ViewHeld = math.max(see.ViewHeld or 0, most)
				see.ViewHeldFrames = (see.ViewHeldFrames or 0) + 1
			end
			if not see.SolidAt and most < Config.Props.FadeTo - 0.03 then
				see.SolidAt = { Body = g, View = vg }
			end
		end
		if stats.Touches > see.SeenTouches and g <= Config.Props.TouchSlack + 2 and not see.SinceShake then
			-- our prop's touch: how long ago the last shake was, and how big a shake was still running
			see.SinceShake = os.clock() - see.LastShakeAt
			see.Running = see.PrevShaking
		end
		see.PrevShaking = RideController.shaking()
		if stats.Shakes > see.SeenShakes then
			see.LastShakeAt = os.clock()
			if g <= Config.Props.TouchSlack + 2 then
				see.Mine += stats.Shakes - see.SeenShakes
			else
				see.Other += stats.Shakes - see.SeenShakes
			end
			see.SeenShakes = stats.Shakes
		end
		if stats.Touches > see.SeenTouches then
			if g <= Config.Props.TouchSlack + 2 then
				see.MineTouches += stats.Touches - see.SeenTouches
			end
			see.SeenTouches = stats.Touches
		end
		-- (frame times: the worst in the 2 s before the touch, and the worst while in the prop)
		if not see.Touched then
			table.insert(see.Dts, lastDt)
			if #see.Dts > 120 then
				table.remove(see.Dts, 1)
			end
		end
		if g <= 0 then
			if not see.Touched then
				see.ModeAtTouch = State.Mode
				see.SpeedIn = see.Moved
				see.VelIn = speed
			end
			see.SpeedLeast = math.min(see.SpeedLeast, see.Moved)
			see.VelLeast = math.min(see.VelLeast, speed)
			see.DtIn = math.max(see.DtIn, lastDt)
			see.Touched = true
			see.In = math.max(see.In, most)
		elseif not see.Touched and tagsOf(model) == 0 then
			see.Before = math.max(see.Before, most)
		end
		if most > 0.01 and not see.FirstGap then
			see.FirstGap = g
		end
		if see.Mine > 0 and not see.ShakeGap then
			see.ShakeGap = g
			see.ShakeLeft = RideController.shaking()
		end
		if tagsOf(model) == 0 and math.abs(most - see.Last) > 0.004 then
			local dir = if most > see.Last then 1 else -1
			if dir ~= see.Dir then
				see.Turns += 1
				see.Dir = dir
			end
			see.Last = most
		end
		see.Debris = math.max(see.Debris, stats.DebrisSeen)
		sampleDebris(root.Position)
		flying = math.max(flying, stats.Flying)
		outMost = math.max(outMost, tagsOf(model))
		outServer = math.max(outServer, serverOut.Value)
		if not passed and (far < 6 or (through - root.Position):Dot(way) < 0) then
			passed = true
			local on = root.Position + way * 500
			through = Vector3.new(on.X, root.Position.Y - 20, on.Z)
		end
		if passed and far > 140 then
			break
		end
	end
	if nearest > 60 and not side and not again then
		-- the test's own steering never got this fish to the prop (a big fish and a prop in a corner): not a result.
		-- Once more, at the next prop
		missed[model] = true
		aim = nil
		log(
			"MISS %s: never nearer than %.0f studs to %s in 25 s; the run is done again at another prop",
			id,
			nearest,
			model.Name
		)
		return run(id, hop, hold, side, true)
	end
	local crashed, boost = nil, nil
	for _, e in events do
		if e.Kind == "Crashed" then
			crashed = e.A
		else
			boost = e
		end
	end
	local a, b, n = seeThrough(model)
	log(
		"RESULT %s: nearest %.1f, inside its box %s, mode there %s | speed kept %.2f of %.0f | Crashed %s | Boost %s | boxes out %d of %d (server tags %d) | copies flying, most %d | see-through at most %.2f before any broke | now out %d, shown %.2f to %.2f",
		id,
		nearest,
		tostring(inside),
		tostring(hoppedMode or State.Mode),
		if least < math.huge then least else 0 / 0,
		full,
		if crashed then string.format("%.2f", crashed) else "no",
		if boost then string.format("%s x%.2f", tostring(boost.A), boost.B) else "no",
		outMost,
		n,
		outServer,
		flying,
		faded,
		tagsOf(model),
		a,
		b
	)
	local breaks = Config.breaks(kind) and not hop
	local function check(ok, what)
		if not ok then
			log("CHECK FAIL: %s", what)
		end
	end
	local touches = see.MineTouches
	local shakes = see.Mine
	log(
		"TOUCH %s: mode at the touch %s | the engine's speed at the touch %s, least while in it %s | worst frame in the 2 s before %.0f ms, in the prop %.0f ms | speed from where we were, at the touch %s, least while in it %s%s | shakes at other props on the way %d (touches in all %d) | behind us, on the line camera to us with our body over %d studs clear: see-through %s; it began to come back at body gap %s, view gap %s",
		id,
		tostring(see.ModeAtTouch),
		if see.VelIn then string.format("%.0f", see.VelIn) else "-",
		if see.VelLeast < math.huge then string.format("%.0f", see.VelLeast) else "-",
		(function()
			local worst = 0
			for _, d in see.Dts do
				worst = math.max(worst, d)
			end
			return worst * 1000
		end)(),
		see.DtIn * 1000,
		if see.SpeedIn then string.format("%.0f", see.SpeedIn) else "-",
		if see.SpeedLeast < math.huge then string.format("%.0f", see.SpeedLeast) else "-",
		if hop
			then string.format(
				" (the hop, off a fish going %.0f: with the jump's rise %s just after leaving; across the water %s at the touch against the hop's own curve %s there; share of the curve flown before the prop %s, least in it %s)",
				see.Had or 0,
				if see.HopSpeed then string.format("%.0f", see.HopSpeed) else "-",
				if see.FlatAtTouch then string.format("%.0f", see.FlatAtTouch) else "-",
				if see.CurveAtTouch then string.format("%.0f", see.CurveAtTouch) else "-",
				if see.CurveBefore then string.format("%.2f", see.CurveBefore) else "-",
				if see.CurveIn then string.format("%.2f", see.CurveIn) else "-"
			)
			else "",
		see.Other,
		PropController.Stats.Touches - stats0.Touches,
		Config.Props.SideNear + Config.Props.SideSlack,
		if see.ViewHeld then string.format("%.2f (%d frames)", see.ViewHeld, see.ViewHeldFrames) else "not seen",
		if see.SolidAt then string.format("%.1f", see.SolidAt.Body) else "-",
		if see.SolidAt then string.format("%.1f", see.SolidAt.View) else "-"
	)
	log(
		"SEE %s: body's least gap %.1f | see-through before the touch, most %.2f | first see-through at gap %s | touches %d, shakes %d (at gap %s, size %.2f) | most in it %.2f | turned round %d times | flying boxes see-through, most %.2f",
		id,
		see.MinGap,
		see.Before,
		if see.FirstGap then string.format("%.1f", see.FirstGap) else "never",
		touches,
		shakes,
		if see.ShakeGap then string.format("%.1f", see.ShakeGap) else "-",
		see.ShakeLeft,
		see.In,
		see.Turns,
		see.Debris
	)
	logDebris(id)
	local P = Config.Props
	if side then
		-- beside: no touch, no shake; see-through if it came within SideNear, solid if it stayed past the slack
		check(shakes == 0 or see.MinGap <= 0, "a shake with no touch")
		if not Config.breaks(kind) then
			if see.MinGap > 0 and see.MinGap <= P.SideNear - 2 then
				check(
					faded > P.FadeTo * 0.6,
					string.format("passed %.1f beside and it stayed solid (%.2f)", see.MinGap, faded)
				)
			elseif see.MinGap > P.SideNear + P.SideSlack then
				check(
					faded < 0.01,
					string.format("passed %.1f beside and it turned see-through (%.2f)", see.MinGap, faded)
				)
			end
			check(see.Turns <= 2, "the see-through flickered")
		end
	elseif not breaks then
		check(see.Before < 0.01, string.format("it was see-through (%.2f) before we touched it", see.Before))
		check(touches >= 1, "no touch was seen")
		-- one shake; none only when the game's own rule holds it back (another prop's shake under Props.ShakeGap
		-- before, or a bigger shake still running)
		local held = see.SinceShake ~= nil and (see.SinceShake < P.ShakeGap or (see.Running or 0) >= P.Shake * 0.5)
		if shakes == 0 and held then
			log(
				"SHAKE %s: none at this prop, held back as built: the last shake was %.2f s before the touch (Props.ShakeGap %.2f), a shake of %.2f still running",
				id,
				see.SinceShake,
				P.ShakeGap,
				see.Running or 0
			)
		else
			check(shakes == 1, string.format("%d shakes for one prop", shakes))
		end
		check(math.abs(see.In - P.FadeTo) < 0.05, string.format("in it, the see-through reached %.2f", see.In))
		check(see.Turns <= 2, "the see-through flickered")
	else
		check(shakes == 0, "the touch's shake on a fish that breaks props")
		check(see.Debris > 0.3, string.format("the flying boxes stayed solid near us (%.2f)", see.Debris))
	end
	if side then
		aim = nil
		local t9 = os.clock()
		waitFor(function()
			local _, m = seeThrough(model)
			return m == 0
		end, 10)
		log("BACK %s: solid again %.1f s after the pass", id, os.clock() - t9)
		return
	end
	check(inside, "we did not go through the prop's box")
	if breaks then
		check(outMost > 0, "a breaking fish knocked nothing out")
		check(flying > 0, "no copies flew")
		check(Config.Props.FadeForBreakers ~= 0 or faded < 0.05, "the prop faded for a fish that breaks it")
		if Config.hasArchetype(kind, "Breaker") then
			check(boost ~= nil and not crashed, "a Breaker should be paid and not crash")
		else
			check(crashed ~= nil and math.abs(crashed - Config.Props.Slow) < 0.01, "a Tank or giant pays Props.Slow")
		end
	else
		-- (after a hop off a fish that breaks props, that fish swims on and may break it as a wild one; its crash
		-- before the hop, in sea grass, is its own too)
		if not (hop and Config.breaks(kind)) then
			check(outMost == 0 and outServer == 0, "a fish that goes through broke something")
			check(not crashed, "a fish that goes through crashed")
		end
		if hop then
			-- (the hop slows by its own curve: in the prop it must fly the same share of that curve as before it)
			check(see.ModeAtTouch ~= "Riding", "the hop was over before the prop")
			check(
				see.CurveIn ~= nil and see.CurveBefore ~= nil and see.CurveIn > see.CurveBefore - 0.1,
				string.format(
					"the hop was slowed in the prop (%s of its curve before, %s in it)",
					tostring(see.CurveBefore),
					tostring(see.CurveIn)
				)
			)
		elseif see.VelIn and see.VelIn > 1 then
			-- (the engine's own speed of the fish; against the fish's ridden speed when it came in faster: a
			-- Predator's burst after a bite runs out by itself, in a prop or not. The speed read from where we were
			-- a frame ago is in the TOUCH line only: a long frame reads there as a slow one)
			local own = if State.Fish then Config.riddenOf(State.Fish, kind) else see.VelIn
			check(
				see.VelLeast / math.min(see.VelIn, own) > 0.9,
				string.format("slowed in the prop (%.0f to %.0f, its own speed %.0f)", see.VelIn, see.VelLeast, own)
			)
		end
		check(math.abs(faded - Config.Props.FadeTo) < 0.05, string.format("the fade reached %.2f", faded))
	end
	-- leaving: the fade comes back; a broken prop rebuilds once we are RegenRadius away for RegenDelay
	if hold and breaks then
		local radius = Config.Props.RegenRadius
		tune("Props", "RegenRadius", 100000)
		settle(8)
		log("HOLD: 8 s with a player 'near': boxes still out %d (must be %d)", tagsOf(model), outMost)
		check(tagsOf(model) == outMost, "the prop came back with a player near")
		tune("Props", "RegenRadius", radius)
	end
	local leftAt = nil
	local t1 = os.clock()
	local back = false
	while os.clock() - t1 < 30 do
		RunService.RenderStepped:Wait()
		root = rootOf()
		if not root then
			break
		end
		local far = (centre - root.Position).Magnitude
		if not leftAt and far > Config.Props.RegenRadius then
			leftAt = os.clock()
		end
		if tagsOf(model) == 0 and (not breaks or leftAt) then
			local _, most2 = seeThrough(model)
			if most2 == 0 then
				log(
					"BACK %s: whole and fully shown %.1f s after the pass, %.0f studs away%s",
					id,
					os.clock() - t1,
					far,
					if leftAt and breaks
						then string.format(
							", %.1f s after we left its %d studs",
							os.clock() - leftAt,
							Config.Props.RegenRadius
						)
						else ""
				)
				back = true
				break
			end
		end
	end
	check(back, "the prop was not whole and shown again within 30 s")
	if breaks and leftAt then
		check(os.clock() - leftAt >= Config.Props.RegenDelay - 0.2, "the prop came back sooner than RegenDelay")
	end
	aim = nil
end

-- four pillars of our own in a row dead ahead (on this machine only: the server never sees them, and they go with
-- the playtest), 14 studs thick and 8 apart: one touch each, and the shakes Props.ShakeGap apart
local function cluster(id)
	log("CLUSTER %s", id)
	if not getOn(id) then
		log("CHECK FAIL: no fish")
		return
	end
	if laneWay then
		local from = rootOf().Position
		aim = function()
			return from + laneWay * 2000
		end
	end
	settle(3)
	local root = rootOf()
	local way = root.AssemblyLinearVelocity
	way = if way.Magnitude > 5 then way.Unit else root.CFrame.LookVector
	local from = root.Position
	local made = {}
	for i = 1, 4 do
		local model = Instance.new("Model")
		model.Name = "B1Pillar" .. i
		for k = -1, 1 do
			local box = Instance.new("Part")
			box.Anchored = true
			box.CanCollide = false
			box.CanQuery = true
			box.Size = Vector3.new(14, 14, 14)
			box.CFrame = CFrame.lookAt(from + way * (150 + (i - 1) * 22), from + way * 2000) * CFrame.new(0, k * 14, 0)
			box.Parent = model
		end
		model.Parent = workspace.ClaudeBlockout.Lane.Props
		table.insert(made, model)
	end
	local target = from + way * 600
	aim = function()
		return target
	end
	local stats = PropController.Stats
	local t0, s0 = stats.Touches, stats.Shakes
	local times, last = {}, stats.Shakes
	local entered, ours = {}, 0
	local speed = 0
	local most = 0
	local c0 = os.clock()
	while os.clock() - c0 < 20 do
		RunService.RenderStepped:Wait()
		root = rootOf()
		if not root then
			break
		end
		if stats.Shakes > last then
			last = stats.Shakes
			table.insert(times, os.clock() - c0)
		end
		speed = math.max(speed, root.AssemblyLinearVelocity.Magnitude)
		most = math.max(most, stats.Inside)
		for i, model in made do
			local g = gapTo(model)
			if g <= 0 and not entered[i] then
				entered[i] = true
				ours += 1
			end
		end
		if (root.Position - from):Dot(way) > 150 + 3 * 22 + 60 then
			break
		end
	end
	local gaps = {}
	local least = math.huge
	for i = 2, #times do
		table.insert(gaps, string.format("%.2f", times[i] - times[i - 1]))
		least = math.min(least, times[i] - times[i - 1])
	end
	log(
		"CLUSTER %s: 4 pillars 22 studs apart at %.0f studs a second (one every %.2f s) | pillars entered %d, touches in all %d (the rest are the map's own props on the way) | shakes %d, seconds between them: %s | Props.ShakeGap %.2f",
		id,
		speed,
		22 / math.max(speed, 1),
		ours,
		stats.Touches - t0,
		stats.Shakes - s0,
		table.concat(gaps, ", "),
		Config.Props.ShakeGap
	)
	if ours ~= 4 or stats.Touches - t0 < 4 then
		log("CHECK FAIL: %d pillars entered, %d touches", ours, stats.Touches - t0)
	end
	if least < Config.Props.ShakeGap - 0.02 or stats.Shakes - s0 < 1 then
		log("CHECK FAIL: shakes %d, the nearest two %.2f s apart", stats.Shakes - s0, least)
	end
	settle(1.5)
	for _, model in made do
		model:Destroy()
	end
	aim = nil
end

-- A box of our own (this machine only) kept on the line from the camera to us, near the camera and clear of our body:
-- only the view rule (Props.ViewNear) can turn it see-through. Then 20 studs off the line (solid again), then back.
-- (It carries a Folder so PropController measures it again at every look: it moves with us.)
local function view(id)
	log("VIEW %s", id)
	if not getOn(id) then
		log("CHECK FAIL: no fish")
		return
	end
	if laneWay then
		local from = rootOf().Position
		aim = function()
			return from + laneWay * 2000
		end
	end
	settle(3)
	local P = Config.Props
	local camera = workspace.CurrentCamera
	local model = Instance.new("Model")
	model.Name = "B1View"
	local box = Instance.new("Part")
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = true
	box.Size = Vector3.new(3, 3, 3)
	box.Parent = model
	Instance.new("Folder").Parent = model
	local function place(off)
		local tail, nose = bodyNow()
		local mid = (tail + nose) / 2
		local eye = camera.CFrame.Position
		local line = eye - mid
		local unit = line.Unit
		local across = unit:Cross(Vector3.yAxis)
		across = if across.Magnitude > 0.01 then across.Unit else Vector3.xAxis
		box.CFrame = CFrame.new(eye - unit * math.min(4, line.Magnitude / 2) + across * off)
		return line.Magnitude
	end
	local reach = place(0)
	model.Parent = workspace.ClaudeBlockout.Lane.Props
	RunService.RenderStepped:Wait()
	-- (if the camera sits so near that the box would be inside the side rule, the side rule is pulled in for the test)
	local sideWas = P.SideNear
	local g0 = gapTo(model)
	if g0 <= P.SideNear + 1 then
		tune("Props", "SideNear", math.max(1, math.floor(g0 - 3)))
	end
	log(
		"VIEW %s: camera %.1f studs from our middle, the box %.1f from our body, Props.SideNear %g for this test (it is %g), ViewNear %g",
		id,
		reach,
		g0,
		Config.Props.SideNear,
		sideWas,
		P.ViewNear
	)
	for i, phase in { { "on the line camera to us", 0 }, { "20 studs off the line", 20 }, { "on the line again", 0 } } do
		local least, t0 = math.huge, os.clock()
		local inside = 0
		while os.clock() - t0 < 1.5 do
			RunService.RenderStepped:Wait()
			if not rootOf() then
				break
			end
			place(phase[2])
			least = math.min(least, gapTo(model))
			inside = math.max(inside, PropController.Stats.Inside)
		end
		local now = box.LocalTransparencyModifier
		log(
			"VIEW %s %d, %s: see-through %.2f after 1.5 s | our body's least gap to it %.1f | view gap %.1f",
			id,
			i,
			phase[1],
			now,
			least,
			viewGapTo(model)
		)
		if least <= Config.Props.SideNear then
			log("CHECK FAIL: the box came inside the side rule (%.1f): this phase shows nothing", least)
		elseif phase[2] == 0 and math.abs(now - P.FadeTo) > 0.05 then
			log("CHECK FAIL: between the camera and us it is %.2f see-through", now)
		elseif phase[2] ~= 0 and now > 0.01 then
			log("CHECK FAIL: off the line it is still %.2f see-through", now)
		end
	end
	model:Destroy()
	if Config.Props.SideNear ~= sideWas then
		tune("Props", "SideNear", sideWas)
	end
	aim = nil
end

cmd:GetPropertyChangedSignal("Value"):Connect(function()
	local words = string.split(cmd.Value, " ")
	task.spawn(function()
		local ok, err = pcall(function()
			if words[1] == "run" then
				run(words[2], words[3] == "1", words[4] == "1", tonumber(words[5]))
			elseif words[1] == "suite2" then
				run("Clownfish", false, false)
				run("ReefShark", false, false)
				run("Clownfish", true, false)
				run("StellersSeaCow", true, false)
				for _, beside in { 2, 6, 10, 16, 24, 40 } do
					run("Clownfish", false, false, beside)
				end
				run("ReefShark", false, false, 10)
				cluster("Clownfish")
				cluster("ReefShark")
				for _, id in { "HumpheadWrasse", "StellersSeaCow", "MoltenMegalodon" } do
					local hang = Config.Props.Hang
					tune("Props", "Hang", 3)
					run(id, false, false)
					tune("Props", "Hang", hang)
				end
				log("SUITE2 DONE")
			elseif words[1] == "view" then
				view(words[2])
			elseif words[1] == "suite3" then
				-- p3, 2026-11-13: Hugo's five points in one go. Fish that go through, head on:
				run("Clownfish", false, false)
				run("ReefShark", false, false)
				-- fish that break (a Breaker, a Tank with the hold, a giant), with the game's own Props.Hang:
				run("HumpheadWrasse", false, false)
				run("StellersSeaCow", false, true)
				run("MoltenMegalodon", false, false)
				-- the rider in the hop, off a fish that goes through and off one that breaks:
				run("Clownfish", true, false)
				run("StellersSeaCow", true, false)
				-- beside a prop, and the view rule alone:
				for _, beside in { 2, 6, 10, 16, 24, 40 } do
					run("Clownfish", false, false, beside)
				end
				run("ReefShark", false, false, 10)
				view("Clownfish")
				cluster("Clownfish")
				cluster("ReefShark")
				-- the loose boxes at every distance (they hang 3 s for this):
				for _, id in { "HumpheadWrasse", "StellersSeaCow", "MoltenMegalodon" } do
					local hang = Config.Props.Hang
					tune("Props", "Hang", 3)
					run(id, false, false)
					tune("Props", "Hang", hang)
				end
				log("SUITE3 DONE")
			elseif words[1] == "debris" then
				-- a breaking fish through a prop with the boxes hanging 3 s, so they are seen at every distance
				local hang = Config.Props.Hang
				tune("Props", "Hang", 3)
				run(words[2], false, false)
				tune("Props", "Hang", hang)
			elseif words[1] == "frames" then
				-- frames <FishId> <StartS> <seconds>: with the see-through on, then off (Props.FadeTo 0)
				local startS, seconds = tonumber(words[3]) or 4150, tonumber(words[4]) or 10
				frames(words[2], startS, seconds, "ON")
				local to = Config.Props.FadeTo
				tune("Props", "FadeTo", 0)
				frames(words[2], startS, seconds, "OFF")
				tune("Props", "FadeTo", to)
				frames(words[2], startS, seconds, "ON again")
				log("FRAMES DONE")
			elseif words[1] == "cluster" then
				cluster(words[2])
			elseif words[1] == "set" then
				tune(words[2], words[3], tonumber(words[4]))
				log("SET %s.%s = %s", words[2], words[3], tostring(Config[words[2]][words[3]]))
			elseif words[1] == "suite" then
				run("Clownfish", false, false)
				run("ReefShark", false, false)
				run("HumpheadWrasse", false, false)
				run("StellersSeaCow", false, true)
				run("MoltenMegalodon", false, false)
				run("Clownfish", true, false)
				run("StellersSeaCow", true, false)
				tune("Props", "FadeForBreakers", 1)
				run("StellersSeaCow", false, false)
				tune("Props", "FadeForBreakers", 0)
				for _, beside in { 2, 6, 10, 16, 24, 40 } do
					run("Clownfish", false, false, beside)
				end
				run("ReefShark", false, false, 6)
				cluster("Clownfish")
				cluster("ReefShark")
				log("SUITE DONE")
			end
		end)
		if not ok then
			log("ERROR %s", tostring(err))
		end
	end)
end)
log("driver up")
