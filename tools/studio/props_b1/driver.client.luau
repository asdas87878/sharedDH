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

-- the nearest tall prop ahead of us that is whole
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
			if whole and size.Y >= 18 and ahead > 220 and ahead < 1200 and side < 200 and ahead < bestFar then
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
			local near = Vector3.new(
				math.clamp(own.X, -h.X, h.X),
				math.clamp(own.Y, -h.Y, h.Y),
				math.clamp(own.Z, -h.Z, h.Z)
			)
			least = math.min(least, (own - near).Magnitude - radius)
		end
	end
	return least
end

local laneWay = nil -- the way down the lane at the start, from the first run
local function run(id, hop, hold, side)
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
	}
	table.clear(events)
	local full = 0
	local least = math.huge -- the least speed inside 60 studs of it, as a share of the speed we came with
	local nearest = math.huge
	local faded, flying, outMost, outServer = 0, 0, 0, 0
	local inside = false -- our middle was inside the prop's own box
	local hopped = false
	local passed = false
	local t0 = os.clock()
	local hoppedMode = nil
	while os.clock() - t0 < 25 do
		RunService.RenderStepped:Wait()
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
		if hop and not hopped and far < speed * 1.0 + 20 then
			hopped = true
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
		if g <= 0 then
			see.Touched = true
			see.In = math.max(see.In, most)
		elseif not see.Touched and tagsOf(model) == 0 then
			see.Before = math.max(see.Before, most)
		end
		if most > 0.01 and not see.FirstGap then
			see.FirstGap = g
		end
		if stats.Shakes > stats0.Shakes and not see.ShakeGap then
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
		least,
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
	local touches = PropController.Stats.Touches - stats0.Touches
	local shakes = PropController.Stats.Shakes - stats0.Shakes
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
	local P = Config.Props
	if side then
		-- beside: no touch, no shake; see-through if it came within SideNear, solid if it stayed past the slack
		check(shakes == 0 or see.MinGap <= 0, "a shake with no touch")
		if not Config.breaks(kind) then
			if see.MinGap > 0 and see.MinGap <= P.SideNear - 2 then
				check(faded > P.FadeTo * 0.6, string.format("passed %.1f beside and it stayed solid (%.2f)", see.MinGap, faded))
			elseif see.MinGap > P.SideNear + P.SideSlack then
				check(faded < 0.01, string.format("passed %.1f beside and it turned see-through (%.2f)", see.MinGap, faded))
			end
			check(see.Turns <= 2, "the see-through flickered")
		end
	elseif not breaks then
		check(see.Before < 0.01, string.format("it was see-through (%.2f) before we touched it", see.Before))
		check(touches >= 1, "no touch was seen")
		check(shakes == 1, string.format("%d shakes for one prop", shakes))
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
		check(outMost == 0 and outServer == 0, "a fish that goes through broke something")
		check(not crashed, "a fish that goes through crashed")
		check(least > 0.9, string.format("a fish that goes through was slowed (%.2f)", least))
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
		"CLUSTER %s: 4 pillars 22 studs apart at %.0f studs a second (one every %.2f s) | touches %d | shakes %d, seconds between them: %s | Props.ShakeGap %.2f",
		id,
		speed,
		22 / math.max(speed, 1),
		stats.Touches - t0,
		stats.Shakes - s0,
		table.concat(gaps, ", "),
		Config.Props.ShakeGap
	)
	if stats.Touches - t0 ~= 4 then
		log("CHECK FAIL: %d touches for four pillars", stats.Touches - t0)
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

cmd:GetPropertyChangedSignal("Value"):Connect(function()
	local words = string.split(cmd.Value, " ")
	task.spawn(function()
		local ok, err = pcall(function()
			if words[1] == "run" then
				run(words[2], words[3] == "1", words[4] == "1", tonumber(words[5]))
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
