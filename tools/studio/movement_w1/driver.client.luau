-- W1 movement playtest: the client driver (temporary; removed after the run)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LogService = game:GetService("LogService")
local player = Players.LocalPlayer
local report = RS:WaitForChild("W1Report")
local cmd = RS:WaitForChild("W1Cmd")
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
local Actions = require(Client:WaitForChild("Lib"):WaitForChild("Actions"))
local State = require(Client.Lib:WaitForChild("State"))
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local Lane = require(RS.Shared:WaitForChild("Lane"))
local Net = require(RS.Shared:WaitForChild("Net"))
local camera = workspace.CurrentCamera
local Course = require(Client.Lib.Course)
local wallContact = {}
local wallMet = {}
-- (the wall ride's own state, as its last step left it: the ridden fish's, or the hop's)
local WallRide = require(Client.Lib.WallRide)
local rideState = nil
local stepOriginal = WallRide.step
local feels = {} -- every ray the wall ride cast this step
local ring = {} -- the last steps: what went in, what came out, and those rays
WallRide.step = function(ride, at, yaw, speed, ...)
	rideState = ride
	feels = {}
	local way, share = stepOriginal(ride, at, yaw, speed, ...)
	table.insert(ring, {
		T = os.clock(),
		Line = string.format(
			"at (%.1f, %.1f, %.1f) yaw %.1f speed %.0f -> way yaw %.1f share %.2f | taken %.2f slide %.2f kept %.2f near %.1f normal (%.2f, %.2f) | rays: %s",
			at.X,
			at.Y,
			at.Z,
			math.deg(yaw),
			speed,
			math.deg(math.atan2(-way.X, -way.Z)),
			share,
			ride.Taken or -1,
			ride.Slide,
			ride.Kept,
			ride.Near or -1,
			ride.Normal.X,
			ride.Normal.Z,
			table.concat(feels, "; ")
		),
	})
	if #ring > 8 then
		table.remove(ring, 1)
	end
	return way, share
end
local hardFrames = 0 -- frames Lib/Course's hard wall rule changed the flat velocity it was asked for
-- (until 2026-11-13 the wall ride asked Course.wall; now it feels ahead with Course.feel: its ray along our heading)
local wallName = if Course.feel then "feel" else "wall"
local wallOriginal = Course[wallName]
Course[wallName] = function(from, dir, reach, steps)
	local normal, far, share, normal2, far2, share2 = wallOriginal(from, dir, reach, steps)
	if wallName == "feel" then
		table.insert(
			feels,
			string.format(
				"dir %.0f: %s%s",
				math.deg(math.atan2(-dir.X, -dir.Z)),
				if normal then string.format("n (%.2f, %.2f) far %.1f x%.2f", normal.X, normal.Z, far, share) else "-",
				if normal2 then string.format(" + n (%.2f, %.2f) far %.1f", normal2.X, normal2.Z, far2) else ""
			)
		)
		local heading = CFrame.fromOrientation(0, State.Heading or 0, 0).LookVector
		if dir:Dot(heading) < 0.999 then
			return normal, far, share, normal2, far2, share2
		end
	end
	wallContact = { From = from, Dir = dir, Reach = reach, Normal = normal }
	if normal then
		-- what was met: which kind of part, its broad face or its end, or the lane's own edge with nothing solid there
		local params = RaycastParams.new()
		params.RespectCanCollide = true
		params.FilterType = Enum.RaycastFilterType.Exclude
		local skip = { workspace.CurrentCamera, Players.LocalPlayer.Character }
		local map = workspace:FindFirstChild("ClaudeBlockout")
		if map and map:FindFirstChild("Surface") then
			table.insert(skip, map.Surface)
		end
		params.FilterDescendantsInstances = skip
		local hit = workspace:Raycast(from, dir * reach, params)
		local what = "lane edge"
		if hit and hit.Normal.Y < 0.5 then
			local part = hit.Instance
			local right = part.CFrame.RightVector
			local face = math.abs(hit.Normal:Dot(right)) > 0.7
			what = (part.Parent and part.Parent.Name or "?") .. "." .. part.Name .. (if face then " face" else " END")
			if part.Size.X > 2 then
				what ..= " thick"
			end
		end
		wallMet[what] = (wallMet[what] or 0) + 1
	end
	return normal, far, share, normal2, far2, share2
end
local stallDumps = 0
local askedLast, gotLast, askedBefore, gotBefore = Vector3.zero, Vector3.zero, Vector3.zero, Vector3.zero
local clearOriginal = Course.clearVelocity
local lastStall = -math.huge
local tracing, lastTrace = false, -math.huge
Course.clearVelocity = function(from, velocity, clearance, reach)
	local result = clearOriginal(from, velocity, clearance, reach)
	local flatWanted = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local flatGot = Vector3.new(result.X, 0, result.Z).Magnitude
	if clearance == Config.Ride.FloorClearance and reach > 2.5 then
		askedBefore, gotBefore = askedLast, gotLast
		askedLast, gotLast = velocity, result
	end
	if
		flatWanted > 3
		and (Vector3.new(velocity.X - result.X, 0, velocity.Z - result.Z)).Magnitude > 0.03 * flatWanted
	then
		hardFrames += 1
	end
	if tracing and os.clock() - lastTrace > 0.12 then
		lastTrace = os.clock()
		local params = RaycastParams.new()
		params.RespectCanCollide = true
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { camera, player.Character, workspace.ClaudeBlockout.Surface }
		local hit = if flatWanted > 0.1
			then workspace:Raycast(
				from,
				Vector3.new(velocity.X, 0, velocity.Z).Unit * (flatWanted * 0.12 + reach),
				params
			)
			else nil
		local heading = CFrame.fromOrientation(0, State.Heading, 0).LookVector
		local hit2 = workspace:Raycast(from, heading * 40, params)
		log(
			"TRACE at (%.1f, %.1f, %.1f) wall=%s heading (%.2f, %.2f) wanted (%.1f, %.1f, %.1f) got (%.1f, %.1f, %.1f) reach %.1f | wallride normal %s for dir %s | velocity ray: %s | heading ray 40: %s",
			from.X,
			from.Y,
			from.Z,
			tostring(State.Wall),
			heading.X,
			heading.Z,
			velocity.X,
			velocity.Y,
			velocity.Z,
			result.X,
			result.Y,
			result.Z,
			reach,
			tostring(wallContact.Normal),
			tostring(wallContact.Dir),
			if hit
				then string.format(
					"%s size %s n (%.2f, %.2f, %.2f) %.1f away",
					hit.Instance:GetFullName(),
					tostring(hit.Instance.Size),
					hit.Normal.X,
					hit.Normal.Y,
					hit.Normal.Z,
					hit.Distance
				)
				else "nothing",
			if hit2
				then string.format(
					"%s n (%.2f, %.2f, %.2f) %.1f away",
					hit2.Instance:GetFullName(),
					hit2.Normal.X,
					hit2.Normal.Y,
					hit2.Normal.Z,
					hit2.Distance
				)
				else "nothing"
		)
	end
	if flatWanted > 15 and flatGot < flatWanted * 0.25 and os.clock() - lastStall > 0.35 then
		lastStall = os.clock()
		local params = RaycastParams.new()
		params.RespectCanCollide = true
		params.FilterType = Enum.RaycastFilterType.Exclude
		local skip = { camera, player.Character }
		local map = workspace:FindFirstChild("ClaudeBlockout")
		if map and map:FindFirstChild("Surface") then
			table.insert(skip, map.Surface)
		end
		params.FilterDescendantsInstances = skip
		local direction = Vector3.new(velocity.X, 0, velocity.Z).Unit
		local hit = workspace:Raycast(from, direction * (flatWanted * 0.12 + reach), params)
		if stallDumps < 2 then
			stallDumps += 1
			for _, item in ring do
				log("    step %.3f s ago: %s", os.clock() - item.T, item.Line)
			end
		end
		log(
			"STALL mode=%s wall=%s at=%s wanted=%s got=%s hit=%s normal=%s hitAt=%s HEADING=%s CAMYAW=%.1f WALLDIR=%s WALLNORMAL=%s REACH=%.1f",
			State.Mode,
			tostring(State.Wall),
			tostring(from),
			tostring(velocity),
			tostring(result),
			if hit then hit.Instance:GetFullName() else "nil",
			if hit then tostring(hit.Normal) else "nil",
			if hit then tostring(hit.Position) else "nil",
			tostring(State.Heading),
			math.deg(State.CamYaw or 0),
			tostring(wallContact.Dir),
			tostring(wallContact.Normal),
			wallContact.Reach or -1
		)
	end
	return result
end

local failures = 0
local function check(ok, what, ...)
	if not ok then
		failures += 1
		log("CHECK FAIL: " .. what, ...)
	end
end

-- the camera, watched all the time: its peak turn rate, the peak with no commanded look change in the last 0.3 s
-- ("unasked"), and its peak change of speed between frames, by phase (camReport logs and clears)
local cam = { Turn = 0, Unasked = 0, Accel = 0, Jerk = 0, Frames = 0, Note = "", Skip = 0 }
do
	local lastLook, lastPos, lastVel, lastAim, aimedAt = nil, nil, nil, 0, -math.huge
	local lastMode = nil
	local modeAt = -math.huge
	RunService:BindToRenderStep("W1Cam", Enum.RenderPriority.Last.Value, function(dt)
		local camera = workspace.CurrentCamera
		local look, pos = camera.CFrame.LookVector, camera.CFrame.Position
		local aim = State.CamYaw or 0
		local now = os.clock()
		if State.Mode ~= lastMode then
			lastMode = State.Mode
			modeAt = now
		end
		if lastLook and dt > 0 and dt < 0.1 and now > cam.Skip then
			local aimRate = math.deg(math.abs(math.atan2(math.sin(aim - lastAim), math.cos(aim - lastAim)))) / dt
			if aimRate > 20 then
				aimedAt = now
			end
			local turn = math.deg(math.acos(math.clamp(look:Dot(lastLook), -1, 1))) / dt
			local vel = (pos - lastPos) / dt
			local accel = if lastVel then (vel - lastVel).Magnitude / dt else 0
			local jerk = if lastVel then math.abs(vel.Magnitude - lastVel.Magnitude) else 0
			cam.Frames += 1
			cam.Turn = math.max(cam.Turn, turn)
			if now - aimedAt > 0.3 and turn > cam.Unasked then
				cam.Unasked = turn
				cam.Note = string.format(
					"%s/%s/%s %.2fs after the mode changed",
					tostring(State.Mode),
					tostring(State.JumpPhase),
					tostring(State.Wall),
					now - modeAt
				)
			end
			cam.Accel = math.max(cam.Accel, accel)
			cam.Jerk = math.max(cam.Jerk, jerk)
			lastVel = vel
		else
			lastVel = nil
		end
		lastLook, lastPos, lastAim = look, pos, aim
	end)
end
local function camReport(label)
	log(
		"CAMERA %s: peak turn %.0f deg/s (with no look command in the last 0.3 s: %.0f, at %s), peak speed change %.1f st/s in a frame, peak acceleration %.0f st/s2, %d frames",
		label,
		cam.Turn,
		cam.Unasked,
		cam.Note,
		cam.Jerk,
		cam.Accel,
		cam.Frames
	)
	cam.Turn, cam.Unasked, cam.Accel, cam.Jerk, cam.Frames, cam.Note = 0, 0, 0, 0, 0, ""
	local met = {}
	for what, n in wallMet do
		table.insert(met, what .. " x" .. n)
	end
	table.sort(met)
	if #met > 0 then
		log("WALLS MET %s: %s", label, table.concat(met, ", "))
	end
	table.clear(wallMet)
end

local function rootOf()
	local _, root = State.character()
	return root
end
local function yawOf(v)
	return math.atan2(-v.X, -v.Z)
end

-- a number on both machines
local function tune(group, key, value)
	Config[group][key] = value
	Config.refresh()
	Net.Sandbox:FireServer("Tune", group .. "." .. key, value)
end

-- the lane, as Lib/Course builds it
local lane = nil
local lastS = nil
local function laneAt(position)
	if not lane then
		local json = Net.Folder:GetAttribute("LanePath")
		lane = Lane.build(State.Zones, if type(json) == "string" and json ~= "" then json else nil)
	end
	local s = Lane.project(lane, position, lastS)
	lastS = s
	local centre, along, width = Lane.at(lane, s)
	local right = along:Cross(Vector3.yAxis)
	local across = (position - centre):Dot(right)
	return along, right, across, width, s
end

-- steering: a look (yaw from a function, each frame), or a held key
local lookYaw = nil -- function(): yaw, pitch
local key = 0
RideController.moveVector = function()
	return Vector3.new(key, 0, 0)
end
RunService:BindToRenderStep("W1Steer", Enum.RenderPriority.Camera.Value - 20, function()
	if lookYaw then
		local yaw, pitch = lookYaw()
		if yaw then
			RideController.look(yaw, pitch or math.rad(-12))
		end
	end
end)
local function lookAlongLane(angle) -- degrees to the right of the way down the lane
	lookYaw = function()
		local root = rootOf()
		if not root then
			return nil
		end
		local along, right = laneAt(root.Position)
		local a = math.rad(angle)
		return yawOf(along * math.cos(a) + right * math.sin(a))
	end
end
local function lookAt(model)
	lookYaw = function()
		local part = model.PrimaryPart
		if not part or not model.Parent then
			return nil
		end
		local d = part.Position - camera.CFrame.Position
		if d.Magnitude < 1 then
			return nil
		end
		return yawOf(d), math.asin(math.clamp(d.Unit.Y, -1, 1))
	end
end

-- what the server tells us
local events = {}
Net.Ride.OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "Crashed" or kind == "Mounted" or kind == "Denied" or kind == "Dismounted" then
		table.insert(events, { At = os.clock(), Kind = kind, A = a, B = b, C = c })
		if kind == "Crashed" then
			local fish = State.Fish
			local part = fish and fish.PrimaryPart
			if part then
				local params = RaycastParams.new()
				params.RespectCanCollide = true
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = { workspace.CurrentCamera, Players.LocalPlayer.Character, fish }
				local hit = workspace:Raycast(part.Position, part.CFrame.LookVector * 30, params)
				report:FireServer(
					string.format(
						"CRASHED slow=%s at (%.0f, %.0f, %.0f) wall=%s ahead=%s",
						tostring(a),
						part.Position.X,
						part.Position.Y,
						part.Position.Z,
						tostring(State.Wall),
						if hit
							then hit.Instance:GetFullName() .. string.format(" %.0f away", hit.Distance)
							else "nothing in 30"
					)
				)
			end
		end
	end
end)

local function fishSpeed()
	local fish = State.Fish
	local root = fish and fish.PrimaryPart
	return root and root.AssemblyLinearVelocity or Vector3.zero
end
local function flat(v)
	return Vector3.new(v.X, 0, v.Z).Magnitude
end
local function median(list)
	if #list == 0 then
		return 0
	end
	local copy = table.clone(list)
	table.sort(copy)
	return copy[math.max(1, math.ceil(#copy / 2))]
end
local function waitFor(test, timeout)
	local t0 = os.clock()
	while os.clock() - t0 < timeout do
		if test() then
			return true
		end
		RunService.RenderStepped:Wait()
	end
	return false
end
local function settle(time)
	local t0 = os.clock()
	while os.clock() - t0 < time do
		RunService.RenderStepped:Wait()
	end
end

-- onto a fish: the sandbox's reset (the nearest), or one of a kind
local function getOn(id)
	lookYaw = nil
	key = 0
	for try = 1, 3 do
		if id then
			Net.Sandbox:FireServer("Ride", id, "")
		else
			Net.Sandbox:FireServer("Reset")
		end
		settle(0.5)
		if waitFor(function()
			return State.Mode == "Riding" and State.Fish ~= nil
		end, 9) then
			lastS = nil
			cam.Skip = os.clock() + 1.5 -- (the reset moved us: not a camera jump of the game's)
			return true
		end
		log("getOn: try %d failed (mode %s)", try, State.Mode)
	end
	return false
end

local function fishId(model)
	return model and tostring(model:GetAttribute("FishType")) or "nil"
end

-- fish of a speed, with no archetype, that the game can spawn
local function pickFish()
	local list = {}
	for _, fish in Config.Fish do
		if fish.Archetype == "" then
			table.insert(list, fish)
		end
	end
	table.sort(list, function(a, b)
		return a.RiddenSpeed < b.RiddenSpeed
	end)
	return list
end

------------------------------------------------------------------------------------------------------------------
-- HOP: the boost, its decay, the airtime and the distance, off fish of different speeds
local function hopRun(label, id, angry, wait)
	tune("Angry", "Test", if angry then 1 else 0)
	if not getOn(id) then
		log("HOP %s: could not get on %s", label, tostring(id))
		return
	end
	lookAlongLane(0)
	settle(wait or 3.5)
	local kind = Config.FishById[State.Fish:GetAttribute("FishType")]
	local ridden = Config.riddenOf(State.Fish, kind)
	local samples = {}
	local t0 = os.clock()
	while os.clock() - t0 < 0.5 do
		RunService.RenderStepped:Wait()
		table.insert(samples, fishSpeed().Magnitude)
	end
	local hadMedian = median(samples)
	local had = fishSpeed().Magnitude
	local root = rootOf()
	local from = root.Position
	if not Actions.jump() then
		log("HOP %s: the jump was refused", label)
		return
	end
	local began = os.clock()
	local peak, peakAt = 0, 0
	local glideEnd, decayed = nil, nil
	local glideFrom = nil
	local air = 0
	local last = root.Position
	local path = 0
	local series = {}
	local nextMark = 0
	while State.Mode == "Jumping" and os.clock() - began < 8 do
		RunService.RenderStepped:Wait()
		local t = os.clock() - began
		local at = root.Position
		path += flat(at - last)
		last = at
		local speed = State.Speed
		if speed > peak then
			peak, peakAt = speed, t
		end
		if State.JumpPhase == "Drop" and not glideEnd then
			glideEnd = t
			glideFrom = flat(at - from)
		end
		if State.JumpPhase == "Glide" then
			air = speed
		end
		if t >= nextMark then
			table.insert(series, string.format("%.1f:%.0f", t, speed))
			nextMark += 0.1
		end
	end
	local window = os.clock() - began
	-- the decay: the first moment the speed is within 3% of the glide's pace
	for _, mark in series do
		local t, v = string.match(mark, "([%d%.]+):(%d+)")
		if tonumber(v) <= air * 1.03 + 0.5 and not decayed then
			decayed = tonumber(t)
		end
	end
	log(
		"HOP %s fish=%s ridden=%.0f had=%.1f | peak %.0f at %.2fs, glide pace %.0f, boost gone by %.1fs | glide ends %.2fs (%.0f studs), window %.2fs (%.0f studs along, path %.0f) | airOf=%.2f",
		label,
		kind.Id,
		ridden,
		had,
		peak,
		peakAt,
		air,
		decayed or -1,
		glideEnd or -1,
		glideFrom or -1,
		window,
		flat(root.Position - from),
		path,
		Config.airOf(had)
	)
	log("HOP %s speed by 0.1s: %s", label, table.concat(series, " ", 1, math.min(#series, 16)))
end

local function phaseHop()
	local saved = Config.Jump.AutoGrab
	tune("Jump", "AutoGrab", 0)
	local list = {}
	for _, fish in Config.Fish do
		if not Config.hasArchetype(fish, "Leaper") then
			table.insert(list, fish)
		end
	end
	table.sort(list, function(a, b)
		return a.RiddenSpeed < b.RiddenSpeed
	end)
	local slow, fast = list[1], list[#list]
	local mid = list[1]
	for _, fish in list do
		if math.abs(fish.RiddenSpeed - 75) < math.abs(mid.RiddenSpeed - 75) then
			mid = fish
		end
	end
	log(
		"HOP fish: slow %s %.0f, mid %s %.0f, fast %s %.0f",
		slow.Id,
		slow.RiddenSpeed,
		mid.Id,
		mid.RiddenSpeed,
		fast.Id,
		fast.RiddenSpeed
	)
	hopRun("slow", slow.Id, false)
	hopRun("normal", mid.Id, false)
	hopRun("fast", fast.Id, false)
	hopRun("normal-angry", mid.Id, true, 5)
	hopRun("slow-angry", slow.Id, true, 5)
	tune("Angry", "Test", 0)
	tune("Jump", "AutoGrab", saved)
	log("HOP done")
end

-- the slowest case still reaches a fish: off a slow angry fish, hands off, the pull-in must land us
local function phaseFair()
	local list = pickFish()
	local got = 0
	local total = 6
	for i = 1, total do
		tune("Angry", "Test", 1)
		if getOn(if i <= 3 then list[1].Id else nil) then
			lookAlongLane(0)
			settle(4)
			local had = fishSpeed().Magnitude
			local before = State.Fish
			local began = os.clock()
			Actions.jump()
			waitFor(function()
				return State.Mode ~= "Jumping"
			end, 8)
			settle(0.3)
			local ok = State.Mode == "Riding" and State.Fish ~= nil and State.Fish ~= before
			if ok then
				got += 1
			end
			log(
				"FAIR %d: had %.1f st/s, hands off -> %s after %.2fs (on %s)",
				i,
				had,
				if ok then "LANDED" else "no fish (" .. State.Mode .. ")",
				os.clock() - began,
				fishId(State.Fish)
			)
		end
	end
	tune("Angry", "Test", 0)
	log("FAIR done: %d of %d slow hops reached a fish with no press", got, total)
end

------------------------------------------------------------------------------------------------------------------
-- MOUNTS: hop, grab a fish, land; is there a second hook?
local function freeAhead(root, least, most)
	local folder = workspace:FindFirstChild("Fish")
	local look = CFrame.fromOrientation(0, State.Heading, 0).LookVector
	local list = {}
	for _, model in folder and folder:GetChildren() or {} do
		if model:IsA("Model") and State.isFreeFish(model) then
			local d = model.PrimaryPart.Position - root.Position
			if d.Magnitude >= least and d.Magnitude <= most and d.Unit:Dot(look) > 0.25 then
				table.insert(list, model)
			end
		end
	end
	return list
end

-- one mount. `mash`: Space is pressed every 0.1 s from the grab until a second after the landing.
local mountCam, mountRoot = {}, {}
local mashEvery = 0.1 -- seconds between the mash's presses (mounts <count> <fix> <mash> <every>)
local function mountOnce(i, mash)
	local root = rootOf()
	if State.Mode ~= "Riding" or not State.Fish then
		if not getOn(nil) then
			return "nofish"
		end
		lookAlongLane(0)
		settle(1.5)
		root = rootOf()
	end
	local list = freeAhead(root, 45, 165)
	if #list == 0 then
		lookAlongLane(0)
		settle(1)
		list = freeAhead(root, 30, 175)
		if #list == 0 then
			getOn(nil)
			return "notarget"
		end
	end
	local target = list[math.random(1, #list)]
	lookAt(target)
	settle(0.45)
	local from = State.Fish
	local mark = os.clock()
	if not Actions.jump() then
		return "nojump"
	end
	-- wait until it is the locked one (or anything is), then press
	waitFor(function()
		return os.clock() - mark > 0.3 and State.JumpTarget == target
	end, 0.9)
	local aimed = State.JumpTarget
	local range = if aimed and aimed.PrimaryPart then (aimed.PrimaryPart.Position - root.Position).Magnitude else -1
	local pressAt = os.clock()
	Actions.jump()
	local reels = {} -- every pull-in begun: { at, fish }
	local wasReeling = false
	local mounts = {}
	local hops = 0
	local wasMode = State.Mode
	local firstLand = nil
	local seen = #events
	local nextPress = pressAt + mashEvery
	local presses = 1
	local camLast, camVel, rootVel = nil, nil, nil
	local camJump, rootJump, camFast = 0, 0, 0
	while os.clock() - pressAt < 7 do
		local dt = RunService.RenderStepped:Wait()
		local now = os.clock()
		-- the camera through the pull-in and the landing: the most its speed changes between two frames, beside the
		-- most the rider's own does (the pull-in ends at once on the saddle: that is the design)
		do
			local eye = camera.CFrame.Position
			if camLast and dt > 0 then
				local v = (eye - camLast) / dt
				local rv = root.AssemblyLinearVelocity
				if camVel then
					camJump = math.max(camJump, (v - camVel).Magnitude)
					rootJump = math.max(rootJump, (rv - rootVel).Magnitude)
				end
				camFast = math.max(camFast, v.Magnitude)
				camVel, rootVel = v, rv
			end
			camLast = eye
		end
		if State.Reeling and not wasReeling then
			table.insert(reels, { At = now - pressAt, Fish = State.JumpTarget })
		end
		wasReeling = State.Reeling
		if State.Mode ~= wasMode then
			if State.Mode == "Jumping" and firstLand then
				hops += 1
			end
			wasMode = State.Mode
		end
		while seen < #events do
			seen += 1
			local e = events[seen]
			if e.Kind == "Mounted" then
				table.insert(mounts, { At = e.At - pressAt, Fish = e.A })
				if not firstLand then
					firstLand = e.At
					lookAlongLane(0) -- (we stop aiming at it once we are on it)
				end
			end
		end
		if mash and now >= nextPress and (not firstLand or now - firstLand < 1) then
			nextPress = now + mashEvery
			presses += 1
			Actions.jump()
		end
		if firstLand and now - firstLand > 1.6 and State.Mode == "Riding" then
			break
		end
		if State.Mode == "Free" then
			break
		end
	end
	local denied = {}
	for index = 1, #events do
		local e = events[index]
		if e.At >= mark and e.Kind == "Denied" then
			table.insert(denied, tostring(e.A) .. ":" .. tostring(e.B))
		end
	end
	-- the verdict
	local verdict
	local landed = mounts[1]
	local final = mounts[#mounts]
	if not landed then
		verdict = "MISS"
	elseif #mounts > 1 or hops > 0 then
		verdict = "SECOND-HOOK(after landing)"
	elseif #reels > 1 then
		verdict = "SECOND-HOOK(pulled to another)"
	elseif aimed and landed.Fish ~= aimed then
		verdict = "OTHER-FISH"
	else
		verdict = "clean"
	end
	local reelText = {}
	for _, reel in reels do
		table.insert(reelText, string.format("%.2f>%s", reel.At, if reel.Fish == aimed then "A" else "B"))
	end
	local mountText = {}
	for _, m in mounts do
		table.insert(
			mountText,
			string.format("%.2f>%s", m.At, if m.Fish == aimed then "A" elseif m.Fish == from then "FROM" else "B")
		)
	end
	log(
		"MOUNT %d%s: %s | range %.0f | pull-ins [%s] landings [%s] hops-after %d presses %d denied [%s] | camera: fastest %.0f st/s, biggest change of speed in a frame %.0f st/s (the rider's own: %.0f)",
		i,
		if mash then " mash" else "",
		verdict,
		range,
		table.concat(reelText, " "),
		table.concat(mountText, " "),
		hops,
		presses,
		table.concat(denied, " "),
		camFast,
		camJump,
		rootJump
	)
	table.insert(mountCam, camJump)
	table.insert(mountRoot, rootJump)
	settle(0.4)
	return verdict
end

local function phaseMounts(count, mash, label)
	local tally = {}
	local done = 0
	local tries = 0
	while done < count and tries < count * 3 do
		tries += 1
		local verdict = mountOnce(done + 1, mash)
		if verdict ~= "nofish" and verdict ~= "notarget" and verdict ~= "nojump" then
			done += 1
		end
		tally[verdict] = (tally[verdict] or 0) + 1
	end
	local text = {}
	for verdict, n in tally do
		table.insert(text, verdict .. "=" .. n)
	end
	table.sort(text)
	log("MOUNTS %s done (%d): %s", label, done, table.concat(text, ", "))
	table.sort(mountCam)
	table.sort(mountRoot)
	log(
		"MOUNTS %s camera: the biggest change of speed in one frame, per mount: median %.0f st/s, worst %.0f (the rider's own: median %.0f, worst %.0f)",
		label,
		median(mountCam),
		mountCam[#mountCam] or 0,
		median(mountRoot),
		mountRoot[#mountRoot] or 0
	)
	table.clear(mountCam)
	table.clear(mountRoot)
end

------------------------------------------------------------------------------------------------------------------
-- WALL: ride into the lane's side at an angle
local function wallRun(angle, id, hop, lead)
	if not getOn(id) then
		log("WALL %d: could not get on", angle)
		return
	end
	lookAlongLane(0)
	settle(lead or 3.5)
	local root = rootOf()
	do
		local _, _, across, width, s = laneAt(root.Position)
		log(
			"WALL %d%s starts %.0f studs down the lane (width %.0f, %.0f from the middle), at (%.0f, %.0f, %.0f) on %s",
			angle,
			if hop then " +hop" else "",
			s,
			width,
			across,
			root.Position.X,
			root.Position.Y,
			root.Position.Z,
			fishId(State.Fish)
		)
	end
	-- the baseline: a second straight down the lane
	local speeds, camTurn, camJerk = {}, 0, 0
	local lastLook, lastCam, lastCamSpeed = camera.CFrame.LookVector, camera.CFrame.Position, nil
	local lastRoot, lastAim, spikeAt = root.Position, State.CamYaw or 0, 0
	local previousVelocity = nil
	local cameraAccel, clipped, observed = 0, 0, 0
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.RespectCanCollide = true
	local map = workspace:FindFirstChild("ClaudeBlockout")
	overlap.FilterDescendantsInstances = if map then { map.Lane, map.Dock } else {}
	local function camStep(dt)
		local look = camera.CFrame.LookVector
		local turn = math.deg(math.acos(math.clamp(look:Dot(lastLook), -1, 1))) / dt
		local velocity = (camera.CFrame.Position - lastCam) / dt
		local speed = velocity.Magnitude
		local acceleration = if previousVelocity then (velocity - previousVelocity).Magnitude / dt else 0
		previousVelocity = velocity
		local jerk = if lastCamSpeed then math.abs(speed - lastCamSpeed) else 0
		local aim = State.CamYaw or 0
		local aimRate = math.deg(math.abs(math.atan2(math.sin(aim - lastAim), math.cos(aim - lastAim)))) / dt
		if (jerk > 50 or turn > 100) and os.clock() - spikeAt > 0.2 then
			spikeAt = os.clock()
			log(
				"CAMERA SPIKE angle%d mode=%s phase=%s wall=%s dt=%.4f turn=%.1f aimRate=%.1f camSpeed=%.1f deltaSpeed=%.1f rootStep=%.2f camStep=%.2f root=%s cam=%s",
				angle,
				State.Mode,
				tostring(State.JumpPhase),
				tostring(State.Wall),
				dt,
				turn,
				aimRate,
				speed,
				jerk,
				(root.Position - lastRoot).Magnitude,
				(camera.CFrame.Position - lastCam).Magnitude,
				tostring(root.Position),
				tostring(camera.CFrame.Position)
			)
		end
		lastRoot, lastAim = root.Position, aim
		lastLook, lastCam, lastCamSpeed = look, camera.CFrame.Position, speed
		return turn, jerk, acceleration
	end
	local t0 = os.clock()
	while os.clock() - t0 < 1 do
		local dt = RunService.RenderStepped:Wait()
		table.insert(speeds, flat(fishSpeed()))
		local turn, jerk = camStep(dt)
		camTurn, camJerk = math.max(camTurn, turn), math.max(camJerk, jerk)
	end
	local v0 = median(speeds)
	local baseTurn, baseJerk = camTurn, camJerk
	-- into the side
	lookAlongLane(angle)
	local began = os.clock()
	local touchAt = nil
	local after = {} -- flat speeds by time since the touch
	local least = math.huge
	local outMost = -math.huge
	local states = {}
	local heights = {}
	local wallTurn, wallJerk = 0, 0
	local crashes = #events
	local hopped, hopOk = false, nil
	local touchPos = nil
	local slid = 0
	local turnedIn = nil
	local realAngles, expected, keptNow = {}, {}, {}
	local clippedIn, beyond = "", 0
	local boundsParams = RaycastParams.new()
	boundsParams.FilterType = Enum.RaycastFilterType.Include
	boundsParams.RespectCanCollide = true
	boundsParams.FilterDescendantsInstances = if map then { map.Lane.Walls, map.Lane.Barrier } else {}
	while os.clock() - began < 14 do
		local dt = RunService.RenderStepped:Wait()
		local now = os.clock()
		local at = root.Position
		local along, right, across, width = laneAt(at)
		local out = math.abs(across) - width / 2
		outMost = math.max(outMost, out)
		local turn, jerk, acceleration = camStep(dt)
		if not turnedIn and now - began > 1.2 then
			turnedIn = true -- (the camera's own turn toward the wall is ours, not the wall's)
		end
		if State.Wall and not touchAt then
			touchAt = now
			touchPos = at
		end
		if touchAt then
			local t = now - touchAt
			local speed = if State.Mode == "Riding" then flat(fishSpeed()) else flat(root.AssemblyLinearVelocity)
			table.insert(after, { T = t, V = speed, Y = at.Y, W = State.Wall or "-" })
			if t < 1.2 then
				least = math.min(least, speed)
				-- the angle we really meet the wall at (the walls wave, so it is not the angle to the lane), and what
				-- the design says we keep at it: Config.wallKeep times the slide's share near square on
				if wallContact.Normal and wallContact.Dir and State.Wall then
					local into = math.clamp(-wallContact.Dir:Dot(wallContact.Normal), 0, 1)
					local real = math.deg(math.asin(into))
					local off = 90 - real
					local w = Config.Wall
					local u = math.clamp((off - w.HeadOn) / math.max(w.Blend, 0.1), 0, 1)
					local slideShare = u * u * (3 - 2 * u)
					table.insert(realAngles, real)
					table.insert(expected, Config.wallKeep(into) * slideShare)
					if t > 0.3 then
						table.insert(keptNow, speed / math.max(v0, 1))
					end
				end
			end
			wallTurn, wallJerk = math.max(wallTurn, turn), math.max(wallJerk, jerk)
			cameraAccel = math.max(cameraAccel, acceleration)
			observed += 1
			-- (GetPartBoundsInBox goes by each part's box along the world's axes, which is far bigger than a turned
			-- part: so each one found is asked whether the camera is really inside it)
			local eye = camera.CFrame.Position
			for _, part in workspace:GetPartBoundsInBox(CFrame.new(eye), Vector3.new(0.1, 0.1, 0.1), overlap) do
				local l = part.CFrame:PointToObjectSpace(eye)
				if
					math.abs(l.X) < part.Size.X / 2
					and math.abs(l.Y) < part.Size.Y / 2
					and math.abs(l.Z) < part.Size.Z / 2
				then
					clipped += 1
					clippedIn = part:GetFullName()
					break
				end
			end
			-- past the lane's surveyed edge: are we past the map's own walls too? (a ray back to the lane's middle
			-- that meets a wall or the barrier from behind)
			if out > 0 then
				local centre = at - right * across
				local back = workspace:Raycast(at, centre - at, boundsParams)
				if back then
					beyond += 1
				end
			end
			states[State.Wall or "-"] = (states[State.Wall or "-"] or 0) + dt
			slid = flat(at - touchPos)
			if hop and not hopped and t > 1.0 then
				hopped = true
				hopOk = Actions.jump()
			end
			if t > (if angle >= 80 then 7 else 3.2) then
				break
			end
		end
	end
	if not touchAt then
		log("WALL %d: never touched a wall in 14 s (out most %.1f)", angle, outMost)
		return
	end
	local function at(time)
		local list = {}
		for _, sample in after do
			if math.abs(sample.T - time) < 0.12 then
				table.insert(list, sample.V)
			end
		end
		return median(list)
	end
	local later = {}
	for _, sample in after do
		if sample.T > 1 and sample.T < 3 then
			table.insert(later, sample.V)
		end
	end
	local crashed = 0
	for index = crashes + 1, #events do
		if events[index].Kind == "Crashed" then
			crashed += 1
		end
	end
	local stateText = {}
	for name, time in states do
		table.insert(stateText, string.format("%s %.1fs", name, time))
	end
	table.sort(stateText)
	log(
		"WALL %d%s: before %.0f st/s | after the touch 0.2s %.0f, 0.5s %.0f, 1s %.0f, 2s %.0f | least in 1.2s %.0f | kept %.0f%% (wallKeep says %.0f%%) | slid %.0f studs | out past the lane's edge at most %.1f | Crashed x%d | %s | camera turn %.0f deg/s (straight %.0f), jerk %.1f (straight %.1f)%s",
		angle,
		if hop then " +hop" else "",
		v0,
		at(0.2),
		at(0.5),
		at(1),
		at(2),
		least,
		100 * median(later) / math.max(v0, 1),
		100 * Config.wallKeep(math.sin(math.rad(angle))),
		slid,
		outMost,
		crashed,
		table.concat(stateText, ", "),
		wallTurn,
		baseTurn,
		wallJerk,
		baseJerk,
		if hop then string.format(" | hop at the wall: %s, mode %s", tostring(hopOk), State.Mode) else ""
	)
	log(
		"CAMERA CHECK %d%s: acceleration peak %.0f st/s2, camera inside something solid in %d of %d frames",
		angle,
		if hop then " +hop" else "",
		cameraAccel,
		clipped,
		observed
	)
	-- the speed kept against the design's share at the angle the wall was REALLY met at (the walls wave)
	if not hop and #keptNow > 5 then
		check(
			median(keptNow) >= median(expected) - 0.12,
			"WALL %d kept %.0f%% of its speed, the design says %.0f%% at the angles met",
			angle,
			100 * median(keptNow),
			100 * median(expected)
		)
	end
	check(beyond == 0, "WALL %d was behind the map's walls or barrier in %d frames", angle, beyond)
	if outMost > 0.1 then
		log(
			"WALL %d: %.1f past the lane's surveyed edge at most, behind a wall or the barrier in %d frames",
			angle,
			outMost,
			beyond
		)
	end
	check(clipped == 0, "WALL %d camera inside %s in %d frames", angle, clippedIn, clipped)
	check(cameraAccel < 2500, "WALL %d camera acceleration %.0f st/s2", angle, cameraAccel)
	if touchPos then
		table.sort(realAngles)
		log(
			"WALL %d touched the wall at (%.0f, %.0f, %.0f) | the real angle to the wall in the first 1.2 s: median %.0f (from %.0f to %.0f) degrees | speed kept 0.3 to 1.2 s: median %.0f%%, the design's share at those angles: median %.0f%%",
			angle,
			touchPos.X,
			touchPos.Y,
			touchPos.Z,
			median(realAngles),
			realAngles[1] or 0,
			realAngles[#realAngles] or 0,
			100 * median(keptNow),
			100 * median(expected)
		)
	end
	if angle >= 80 and not hop then
		-- the swing: the turning points of our height
		local turns = {}
		local dir = 0
		local lastY = after[1].Y
		for index = 2, #after do
			local sample = after[index]
			local d = sample.Y - lastY
			if math.abs(d) > 0.02 then
				local now = if d > 0 then 1 else -1
				if dir ~= 0 and now ~= dir then
					table.insert(turns, string.format("%.2fs %+.1f", sample.T, lastY - after[1].Y))
				end
				dir = now
				lastY = sample.Y
			end
		end
		log(
			"WALL %d swing: turning points (time, studs from where we met the wall): %s",
			angle,
			table.concat(turns, " | ", 1, math.min(#turns, 9))
		)
	end
	-- steer off it: back down the lane
	if State.Mode == "Riding" then
		lookAlongLane(if angle < 0 then 25 else -25)
		local offAt = os.clock()
		local freeAt, fastAt = nil, nil
		while os.clock() - offAt < 5 do
			RunService.RenderStepped:Wait()
			local t = os.clock() - offAt
			if not State.Wall and not freeAt then
				freeAt = t
			end
			if freeAt and flat(fishSpeed()) >= 0.9 * v0 and not fastAt then
				fastAt = t
				break
			end
		end
		log(
			"WALL %d steer off: free of the wall after %.2fs, at 90%% of its speed after %.2fs",
			angle,
			freeAt or -1,
			fastAt or -1
		)
	else
		-- the hop at the wall: let it run, still steered into the wall
		local t1 = os.clock()
		local outHop = -math.huge
		local speedsHop = {}
		local wallHop = {}
		while State.Mode == "Jumping" and os.clock() - t1 < 6 do
			RunService.RenderStepped:Wait()
			local p = root.Position
			local _, _, across, width = laneAt(p)
			outHop = math.max(outHop, math.abs(across) - width / 2)
			table.insert(speedsHop, flat(root.AssemblyLinearVelocity))
			wallHop[State.Wall or "-"] = (wallHop[State.Wall or "-"] or 0) + 1
		end
		local text = {}
		for name, n in wallHop do
			table.insert(text, name .. " " .. n .. "f")
		end
		log(
			"WALL %d hop: median flat speed %.0f, out past the edge at most %.1f, states %s, ended %s",
			angle,
			median(speedsHop),
			outHop,
			table.concat(text, ", "),
			State.Mode
		)
	end
end

local function phaseWall(on)
	tune("Wall", "On", on)
	local list = pickFish()
	local mid = list[1]
	for _, fish in list do
		if math.abs(fish.RiddenSpeed - 75) < math.abs(mid.RiddenSpeed - 75) then
			mid = fish
		end
	end
	log("WALL fish %s %.0f, Wall.On %d", mid.Id, mid.RiddenSpeed, on)
	for _, angle in { 15, 30, 45, 60, 75, 90 } do
		wallRun(angle, mid.Id, false)
	end
	if on == 1 then
		wallRun(45, mid.Id, true)
		wallRun(90, mid.Id, true)
		wallRun(-45, mid.Id, false)
	end
	tune("Wall", "On", 1)
	log("WALL done (On %d)", on)
end

-- the hop itself into the wall: off the fish in the middle, steered at the side
local function phaseHopWall()
	tune("Jump", "AutoGrab", 0)
	for _, angle in { 40, 90 } do
		if getOn(nil) then
			lookAlongLane(angle)
			settle(1.6)
			local root = rootOf()
			-- leave when the wall is about a second away
			waitFor(function()
				local _, _, across, width = laneAt(root.Position)
				return width / 2 - math.abs(across) < 70
			end, 8)
			Actions.jump()
			local began = os.clock()
			local outMost, touchAt = -math.huge, nil
			local before, afterV, ys = {}, {}, {}
			while State.Mode == "Jumping" and os.clock() - began < 7 do
				RunService.RenderStepped:Wait()
				local p = root.Position
				local _, _, across, width = laneAt(p)
				outMost = math.max(outMost, math.abs(across) - width / 2)
				local v = flat(root.AssemblyLinearVelocity)
				if State.Wall and not touchAt then
					touchAt = os.clock() - began
				end
				if touchAt then
					table.insert(afterV, v)
					table.insert(ys, p.Y)
				else
					table.insert(before, v)
				end
			end
			local low, high = math.huge, -math.huge
			for _, y in ys do
				low, high = math.min(low, y), math.max(high, y)
			end
			log(
				"HOPWALL %d: touched at %.2fs | flat speed before %.0f, along the wall %.0f | out past the edge at most %.1f | height range after the touch %.1f | ended %s",
				angle,
				touchAt or -1,
				median(before),
				median(afterV),
				outMost,
				if #ys > 0 then high - low else 0,
				State.Mode
			)
		end
	end
	tune("Jump", "AutoGrab", 2)
	log("HOPWALL done")
end

------------------------------------------------------------------------------------------------------------------
-- REGRESSIONS: the landing's slow-down, A and D, angry mode
local function phaseRegress()
	-- A and D: a second of D
	if getOn(nil) then
		lookYaw = nil
		settle(2.5)
		local h0 = State.Heading
		key = 1
		settle(1)
		key = 0
		local turned = math.deg(math.abs(State.Heading - h0))
		settle(0.5)
		log("REGRESS steer: D held 1 s turned %.0f degrees (the control pass measured 129)", turned)
	end
	-- the landing's slow-down: the least speed in the first 0.5 s after a landing, over the fish's own speed
	for i = 1, 3 do
		lookAlongLane(0)
		settle(1.5)
		local verdict = mountOnce(900 + i, false)
		local fish = State.Fish
		if fish and State.Mode == "Riding" then
			local kind = Config.FishById[fish:GetAttribute("FishType")]
			local ridden = Config.riddenOf(fish, kind)
			log(
				"REGRESS startle %d (%s): 1.6 s after the landing the fish is at %.0f of %.0f (%.2f)",
				i,
				verdict,
				fishSpeed().Magnitude,
				ridden,
				fishSpeed().Magnitude / ridden
			)
		end
	end
	-- (the dip itself)
	if State.Mode == "Riding" then
		local root = rootOf()
		local list = freeAhead(root, 40, 150)
		if #list > 0 then
			local target = list[1]
			lookAt(target)
			settle(0.4)
			Actions.jump()
			settle(0.4)
			Actions.jump()
			local seen = #events
			if
				waitFor(function()
					for index = seen + 1, #events do
						if events[index].Kind == "Mounted" then
							return true
						end
					end
					return false
				end, 5)
			then
				lookAlongLane(0)
				local t0 = os.clock()
				local least = math.huge
				local fish = State.Fish
				local kind = Config.FishById[fish:GetAttribute("FishType")]
				local ridden = Config.riddenOf(fish, kind)
				while os.clock() - t0 < 0.45 do
					RunService.RenderStepped:Wait()
					if os.clock() - t0 > 0.15 then
						least = math.min(least, fishSpeed().Magnitude)
					end
				end
				log(
					"REGRESS startle dip: least speed 0.15 to 0.45 s after the landing %.0f of %.0f = x%.2f (Ride.StartleSlow %.2f)",
					least,
					ridden,
					least / ridden,
					Config.Ride.StartleSlow
				)
			end
		end
	end
	-- angry: the speed's share
	local list = pickFish()
	local mid = list[math.ceil(#list / 2)]
	if getOn(mid.Id) then
		lookAlongLane(0)
		settle(3.5)
		local calm = fishSpeed().Magnitude
		tune("Angry", "Test", 1)
		settle(4)
		local samples = {}
		local t0 = os.clock()
		while os.clock() - t0 < 2 do
			RunService.RenderStepped:Wait()
			table.insert(samples, fishSpeed().Magnitude)
		end
		log(
			"REGRESS angry: %s calm %.0f st/s, angry median %.0f (x%.2f), Angry attribute %s",
			mid.Id,
			calm,
			median(samples),
			median(samples) / calm,
			tostring(State.Fish and State.Fish:GetAttribute("Angry"))
		)
		tune("Angry", "Test", 0)
	end
	log("REGRESS done")
end

-- CHAIN: a hop made on purpose right after a landing must leave at Jump.Cooldown, as before
local function phaseChain()
	for i = 1, 8 do
		if State.Mode ~= "Riding" then
			getOn(nil)
			lookAlongLane(0)
			settle(1.5)
		end
		local root = rootOf()
		local list = freeAhead(root, 40, 150)
		if #list > 0 then
			lookAt(list[math.random(1, #list)])
			settle(0.4)
			Actions.jump()
			settle(0.4)
			Actions.jump() -- the grab: one press, none in the pull-in
			local seen = #events
			local landAt = nil
			waitFor(function()
				for index = seen + 1, #events do
					if events[index].Kind == "Mounted" then
						landAt = events[index].At
						return true
					end
				end
				return false
			end, 5)
			if landAt then
				lookAlongLane(0)
				-- a press too early (0.20 s), then presses every frame from 0.28 s: when does the hop begin?
				waitFor(function()
					return os.clock() - landAt >= 0.2
				end, 1)
				local early = Actions.jump()
				local hopAt = nil
				while os.clock() - landAt < 1.2 do
					RunService.RenderStepped:Wait()
					if os.clock() - landAt >= 0.28 and Actions.jump() and State.Mode == "Jumping" then
						hopAt = os.clock() - landAt
						break
					end
				end
				log(
					"CHAIN %d: press at 0.20 s after the landing %s; the hop began %.3f s after the landing (Jump.Cooldown %.2f)",
					i,
					if early then "TAKEN" else "refused (cooldown)",
					hopAt or -1,
					Config.Jump.Cooldown
				)
				waitFor(function()
					return State.Mode ~= "Jumping"
				end, 8)
				settle(0.5)
			end
		end
	end
	log("CHAIN done")
end

------------------------------------------------------------------------------------------------------------------
-- THE GLIDE (2026-11-13): the wall ride starts before the wall. How near the wall we really come, how smoothly the
-- way we go, the body and the camera turn, and whether Lib/Course's hard rule ever had to step in.
local glideParams = RaycastParams.new()
glideParams.RespectCanCollide = true
glideParams.FilterType = Enum.RaycastFilterType.Exclude
local function glideSkip()
	local skip = { camera, player.Character }
	local map = workspace:FindFirstChild("ClaudeBlockout")
	if map then
		if map:FindFirstChild("Surface") then
			table.insert(skip, map.Surface)
		end
		local props = map:FindFirstChild("Lane") and map.Lane:FindFirstChild("Props")
		if props then
			table.insert(skip, props) -- (no fish is stopped by a prop: Config.Props, 2026-11-13)
		end
	end
	glideParams.FilterDescendantsInstances = skip
end
-- the nearest wall face to a point, all round (floors and low steps with open water over them are not walls)
local function wallDistance(at)
	local best = math.huge
	local up = Vector3.new(0, 10, 0)
	local roofed = workspace:Raycast(at, up, glideParams) ~= nil
	for i = 0, 23 do
		local a = i * math.pi / 12
		local dir = Vector3.new(math.sin(a), 0, math.cos(a))
		local hit = workspace:Raycast(at, dir * 90, glideParams)
		if hit and hit.Normal.Y < 0.5 and hit.Distance < best then
			local step = not roofed and not workspace:Raycast(at + up, dir * (hit.Distance + 12), glideParams)
			if not step then
				best = hit.Distance
			end
		end
	end
	return best
end
local function takenNow()
	local r = rideState
	if not r then
		return 0
	end
	return r.Taken or (if r.Touch then 1 else 0)
end
local function angleBetween(a, b)
	local fa, fb = Vector3.new(a.X, 0, a.Z), Vector3.new(b.X, 0, b.Z)
	if fa.Magnitude < 0.01 or fb.Magnitude < 0.01 then
		return 0
	end
	return math.deg(math.acos(math.clamp(fa.Unit:Dot(fb.Unit), -1, 1)))
end
-- a meter over a stretch of frames. `mover`: the part that moves (the fish's root, or ours in the hop)
local function newMeter(mover, wide, long, v0)
	glideSkip()
	local m = {
		Frames = 0,
		Wall = math.huge, -- least distance, centre to the nearest wall face
		Side = math.huge, -- that less the body's half width
		Nose = math.huge, -- the least distance from the nose (along the body) to a wall
		Edge = math.huge, -- the least distance inside the lane's own edge
		Turn = 0, -- the biggest change of the way we go in one frame, degrees
		TurnRate = 0, -- and as a rate
		Dv = 0, -- the biggest change of flat speed in one frame, studs a second
		Face = 0, -- the fastest the body turned, degrees a second
		Split = 0, -- the most the body pointed away from the way it went, degrees
		Slow = 0, -- the longest time under a quarter of v0 while not in the swing, seconds
		Zero = 0, -- frames under 2 studs a second while not in the swing
		CamDv = 0, -- the biggest change of the camera's speed in one frame
		CamTurn = 0, -- the camera's fastest turn with no look command in the last 0.3 s
		Hard = 0, -- frames Lib/Course's hard wall rule changed the flat velocity
		Logged = 0,
		CamLogged = 0,
	}
	local lastV, lastLook, lastCamPos, lastCamV, lastCamLook = nil, nil, nil, nil, nil
	local slowFor = 0
	local hard0 = hardFrames
	local lastAim, aimedAt = State.CamYaw or 0, -math.huge
	function m.step(dt)
		if dt <= 0 or dt > 0.1 then
			lastV, lastCamV = nil, nil
			return
		end
		m.Frames += 1
		local at = mover.Position
		local v = mover.AssemblyLinearVelocity
		local speed = flat(v)
		local look = mover.CFrame.LookVector
		local d = wallDistance(at)
		m.Wall = math.min(m.Wall, d)
		m.Side = math.min(m.Side, d - wide)
		local ahead = workspace:Raycast(at, Vector3.new(look.X, 0, look.Z).Unit * 90, glideParams)
		if ahead and ahead.Normal.Y < 0.5 then
			local up = Vector3.new(0, 10, 0)
			local step = not workspace:Raycast(at, up, glideParams)
				and not workspace:Raycast(
					at + up,
					Vector3.new(look.X, 0, look.Z).Unit * (ahead.Distance + 12),
					glideParams
				)
			if not step then
				m.Nose = math.min(m.Nose, ahead.Distance - long)
			end
		end
		local _, _, across, width = laneAt(at)
		m.Edge = math.min(m.Edge, width / 2 + Config.Ride.LaneMargin - math.abs(across))
		local swinging = rideState and rideState.Slide < 0.9
		if lastV then
			if speed > math.max(5, v0 * 0.15) and flat(lastV) > math.max(5, v0 * 0.15) then
				local turn = angleBetween(v, lastV)
				if (turn > 8 and speed > v0 * 0.3 and m.Logged < 2) or (turn > 20 and m.Logged < 6) then
					m.Logged += 1
					local _, _, across, width, sNow = laneAt(at)
					local r = rideState
					for _, item in ring do
						log("    step %.3f s ago: %s", os.clock() - item.T, item.Line)
					end
					log(
						"  asked (%.1f, %.1f) got (%.1f, %.1f); the frame before asked (%.1f, %.1f) got (%.1f, %.1f)",
						askedLast.X,
						askedLast.Z,
						gotLast.X,
						gotLast.Z,
						askedBefore.X,
						askedBefore.Z,
						gotBefore.X,
						gotBefore.Z
					)
					log(
						"  TURN %.1f deg in a frame (dt %.3f) at (%.0f, %.0f, %.0f) s %.0f across %.0f of %.0f | v (%.1f, %.1f) was (%.1f, %.1f) | heading %.1f | taken %.2f bend %.1f share %.2f slide %.2f near %.1f normal (%.2f, %.2f) | wall %.1f state %s mode %s",
						turn,
						dt,
						at.X,
						at.Y,
						at.Z,
						sNow,
						across,
						width / 2,
						v.X,
						v.Z,
						lastV.X,
						lastV.Z,
						math.deg(State.Heading or 0),
						takenNow(),
						r and r.Bend and math.deg(r.Bend) or 0,
						r and r.Share or -1,
						r and r.Slide or -1,
						r and r.Near or -1,
						r and r.Normal.X or 0,
						r and r.Normal.Z or 0,
						d,
						tostring(State.Wall),
						State.Mode
					)
				end
				m.Turn = math.max(m.Turn, turn)
				m.TurnRate = math.max(m.TurnRate, turn / dt)
			end
			m.Dv = math.max(m.Dv, math.abs(speed - flat(lastV)))
			m.Face = math.max(m.Face, angleBetween(look, lastLook) / dt)
		end
		if speed > 8 and not swinging then
			m.Split = math.max(m.Split, angleBetween(look, v))
		end
		if not swinging and speed < v0 * 0.25 then
			slowFor += dt
			m.Slow = math.max(m.Slow, slowFor)
		else
			slowFor = 0
		end
		if not swinging and speed < 2 then
			m.Zero += 1
		end
		lastV, lastLook = v, look
		local camPos, camLook = camera.CFrame.Position, camera.CFrame.LookVector
		local aim = State.CamYaw or 0
		if math.deg(math.abs(math.atan2(math.sin(aim - lastAim), math.cos(aim - lastAim)))) / dt > 20 then
			aimedAt = os.clock()
		end
		lastAim = aim
		if lastCamPos then
			local camV = (camPos - lastCamPos) / dt
			if lastCamV then
				local jump = math.abs(camV.Magnitude - lastCamV.Magnitude)
				if jump > 100 and m.CamLogged < 3 then
					m.CamLogged += 1
					local hit = workspace:Raycast(at, camPos - at, glideParams)
					log(
						"  CAMJUMP %.0f st/s (dt %.3f; camera moved %.1f, the character's root is %.1f from the fish's, shake %s kick %s): camera %.1f from us (was %.1f), at (%.0f, %.0f, %.0f); between us and it: %s; wall state %s, mode %s, %d frames in",
						jump,
						dt,
						(camPos - lastCamPos).Magnitude,
						rootOf() and (rootOf().Position - at).Magnitude or -1,
						tostring(Config.Jump.LandShake),
						tostring(Config.Crash.Kick),
						(camPos - at).Magnitude,
						(lastCamPos - at).Magnitude,
						camPos.X,
						camPos.Y,
						camPos.Z,
						if hit then hit.Instance:GetFullName() else "nothing solid (props not counted)",
						tostring(State.Wall),
						State.Mode,
						m.Frames
					)
				end
				m.CamDv = math.max(m.CamDv, jump)
			end
			lastCamV = camV
			if os.clock() - aimedAt > 0.3 then
				m.CamTurn = math.max(m.CamTurn, math.deg(math.acos(math.clamp(camLook:Dot(lastCamLook), -1, 1))) / dt)
			end
		end
		lastCamPos, lastCamLook = camPos, camLook
		m.Hard = hardFrames - hard0
	end
	function m.line()
		return string.format(
			"nearest wall %.1f from the centre (%.1f clear of the side; body %.1f wide, %.1f long), nose %.1f clear, lane edge %.1f | way turned at most %.1f deg in a frame (%.0f deg/s), speed changed at most %.1f st/s in a frame, body turned at most %.0f deg/s, body off its way at most %.0f deg | under a quarter speed for %.2f s, %d frames near zero | camera: speed changed at most %.1f st/s in a frame, turned %.0f deg/s unasked | Course's hard wall rule: %d of %d frames",
			m.Wall,
			m.Side,
			wide * 2,
			long * 2,
			m.Nose,
			m.Edge,
			m.Turn,
			m.TurnRate,
			m.Dv,
			m.Face,
			m.Split,
			m.Slow,
			m.Zero,
			m.CamDv,
			m.CamTurn,
			m.Hard,
			m.Frames
		)
	end
	return m
end
local function bodyOfRidden()
	local fish = State.Fish
	local kind = fish and Config.FishById[fish:GetAttribute("FishType")]
	if not fish or not kind then
		return 2, 3
	end
	local size = Config.bodyOf(fish, kind)
	return size.X / 2, size.Z / 2
end
local function designKept()
	-- what the design says we keep at the angle we are steered into the wall that has us
	local r = rideState
	if not r or not State.Heading then
		return nil
	end
	local heading = CFrame.fromOrientation(0, State.Heading, 0).LookVector
	local into = math.clamp(-heading:Dot(r.Normal), 0, 1)
	local off = 90 - math.deg(math.asin(into))
	local w = Config.Wall
	local u = math.clamp((off - w.HeadOn) / math.max(w.Blend, 0.1), 0, 1)
	return Config.wallKeep(into) * u * u * (3 - 2 * u), math.deg(math.asin(into))
end

local glideTrace, lastGlideTrace = false, 0
local function glideRun(angle, id, lead, extras)
	if not getOn(id) then
		log("GLIDE %d: could not get on", angle)
		return
	end
	lookAlongLane(0)
	settle(lead or 3)
	local fish = State.Fish
	local mover = fish.PrimaryPart
	local wide, long = bodyOfRidden()
	local speeds = {}
	local t0 = os.clock()
	while os.clock() - t0 < 0.8 do
		RunService.RenderStepped:Wait()
		table.insert(speeds, flat(mover.AssemblyLinearVelocity))
	end
	local v0 = median(speeds)
	local sign = if angle < 0 then -1 else 1
	local _, _, _, _, s0 = laneAt(mover.Position)
	lookAlongLane(angle)
	local m = newMeter(mover, wide, long, v0)
	local began = os.clock()
	local seenAt, seenFar, rodeAt = nil, nil, nil
	local kept, design, angles = {}, {}, {}
	local states = {}
	local crashes = #events
	while os.clock() - began < 12 do
		local dt = RunService.RenderStepped:Wait()
		if State.Mode ~= "Riding" or State.Fish ~= fish then
			break
		end
		m.step(dt)
		local now = os.clock()
		local taken = takenNow()
		if glideTrace and now - lastGlideTrace > 0.1 then
			lastGlideTrace = now
			local p, v, look = mover.Position, mover.AssemblyLinearVelocity, mover.CFrame.LookVector
			log(
				"  t %.2f at (%.1f, %.1f, %.1f) v (%.1f, %.1f, %.1f) body yaw %.0f heading %.0f | taken %.2f slide %.2f kept %.2f near %.1f normal (%.2f, %.2f) lift %.1f | wall %.1f state %s",
				now - began,
				p.X,
				p.Y,
				p.Z,
				v.X,
				v.Y,
				v.Z,
				math.deg(yawOf(look)),
				math.deg(State.Heading or 0),
				taken,
				rideState and rideState.Slide or -1,
				rideState and rideState.Kept or -1,
				rideState and rideState.Near or -1,
				rideState and rideState.Normal.X or 0,
				rideState and rideState.Normal.Z or 0,
				rideState and rideState.Lift or 0,
				wallDistance(p),
				tostring(State.Wall)
			)
		end
		if not seenAt and taken > 0.03 then
			seenAt = now
			seenFar = wallDistance(mover.Position)
		end
		if seenAt and not rodeAt and taken > 0.9 then
			rodeAt = now
		end
		if State.Wall then
			states[State.Wall] = true
		end
		if rodeAt and now - rodeAt > 0.4 and now - rodeAt < 1.4 then
			local want, real = designKept()
			if want then
				table.insert(kept, flat(mover.AssemblyLinearVelocity) / v0)
				table.insert(design, want)
				table.insert(angles, real)
			end
		end
		if rodeAt and now - rodeAt > 2.2 then
			break
		end
	end
	local names = {}
	for name in states do
		table.insert(names, name)
	end
	table.sort(names)
	local crashed = 0
	for i = crashes + 1, #events do
		if events[i].Kind == "Crashed" then
			crashed += 1
		end
	end
	log(
		"GLIDE %d on %s at %.0f st/s, %.0f down the lane | wall first turned us %.1f studs off it, %.2f s before we rode it | real angle %.0f | kept %.0f%% (design %.0f%%) | states %s | crashes %d | %s",
		angle,
		fishId(fish),
		v0,
		s0,
		seenFar or -1,
		if seenAt and rodeAt then rodeAt - seenAt else -1,
		median(angles),
		median(kept) * 100,
		median(design) * 100,
		table.concat(names, "+"),
		crashed,
		m.line()
	)
	if extras and State.Mode == "Riding" and State.Fish == fish then
		-- steering off it
		lookAlongLane(-35 * sign)
		local off = newMeter(mover, wide, long, v0)
		local turned = os.clock()
		local freeAt, fastAt = nil, nil
		while os.clock() - turned < 3 do
			off.step(RunService.RenderStepped:Wait())
			if not freeAt and not State.Wall then
				freeAt = os.clock() - turned
			end
			if freeAt and not fastAt and flat(mover.AssemblyLinearVelocity) >= v0 * 0.9 then
				fastAt = os.clock() - turned
			end
		end
		log(
			"GLIDE %d steering off: free of the wall after %.2f s, at 90%% speed after %.2f s | %s",
			angle,
			freeAt or -1,
			fastAt or -1,
			off.line()
		)
		-- and holding into it at a shallow angle: hugging it
		lookAlongLane(12 * sign)
		waitFor(function()
			return takenNow() > 0.9
		end, 14)
		settle(1)
		local hug = newMeter(mover, wide, long, v0)
		local low, high, flips, last = math.huge, -math.huge, 0, State.Wall
		local hugSpeeds = {}
		local t1 = os.clock()
		while os.clock() - t1 < 4 do
			hug.step(RunService.RenderStepped:Wait())
			local d = wallDistance(mover.Position)
			if glideTrace and os.clock() - lastGlideTrace > 0.1 then
				lastGlideTrace = os.clock()
				local p, v = mover.Position, mover.AssemblyLinearVelocity
				local _, _, across, width, sNow = laneAt(p)
				log(
					"  hug at (%.1f, %.1f, %.1f) s %.0f across %.1f half width %.1f | v (%.1f, %.1f) heading %.0f | taken %.2f slide %.2f share %.2f near %.1f normal (%.2f, %.2f) | wall %.1f state %s hard %d",
					p.X,
					p.Y,
					p.Z,
					sNow,
					across,
					width / 2,
					v.X,
					v.Z,
					math.deg(State.Heading or 0),
					takenNow(),
					rideState and rideState.Slide or -1,
					rideState and rideState.Share or -1,
					rideState and rideState.Near or -1,
					rideState and rideState.Normal.X or 0,
					rideState and rideState.Normal.Z or 0,
					d,
					tostring(State.Wall),
					hardFrames
				)
			end
			low, high = math.min(low, d), math.max(high, d)
			if (State.Wall ~= nil) ~= (last ~= nil) then
				flips += 1
			end
			last = State.Wall
			table.insert(hugSpeeds, flat(mover.AssemblyLinearVelocity) / v0)
		end
		log(
			"GLIDE %d hugging (held 12 degrees into it for 4 s): wall %.1f to %.1f from the centre, the wall state came and went %d times, speed %.0f%% | %s",
			angle,
			low,
			high,
			flips,
			median(hugSpeeds) * 100,
			hug.line()
		)
	end
end

local function phaseGlide(id, lead)
	for _, angle in { 15, 30, 45, 60, 75, 90 } do
		glideRun(angle, id, lead, angle == 30 or angle == 60)
	end
	glideRun(-45, id, lead, false)
end

-- steering all over the lane for a while: both sides, necks, joints, terraces. A stall is logged where it happens.
local function wander(id, seconds, start)
	if not getOn(id) then
		log("WANDER: could not get on")
		return
	end
	lookAlongLane(0)
	settle(start or 1)
	local fish = State.Fish
	local mover = fish.PrimaryPart
	local wide, long = bodyOfRidden()
	local v0 = Config.riddenOf(fish, Config.FishById[fish:GetAttribute("FishType")])
	local m = newMeter(mover, wide, long, v0)
	local began = os.clock()
	lookYaw = function()
		local root = rootOf()
		if not root then
			return nil
		end
		local along, right = laneAt(root.Position)
		local t = os.clock() - began
		local a = math.rad(72 * math.sin(2 * math.pi * t / 9) + 22 * math.sin(2 * math.pi * t / 2.7))
		return yawOf(along * math.cos(a) + right * math.sin(a))
	end
	local slowFor, stalls = 0, 0
	local s1 = 0
	local _, _, _, _, sStart = laneAt(mover.Position)
	local walled = 0
	while os.clock() - began < seconds do
		local dt = RunService.RenderStepped:Wait()
		if State.Mode ~= "Riding" or State.Fish ~= fish then
			log("WANDER: off the fish after %.1f s (mode %s)", os.clock() - began, State.Mode)
			break
		end
		m.step(dt)
		if State.Wall then
			walled += 1
		end
		local swinging = rideState and rideState.Slide < 0.9
		if not swinging and flat(mover.AssemblyLinearVelocity) < v0 * 0.2 then
			slowFor += dt
			if slowFor > 0.35 then
				stalls += 1
				slowFor = -1.5
				local p = mover.Position
				local _, _, across, width, s = laneAt(p)
				log(
					"WANDER STALL at (%.0f, %.0f, %.0f), %.0f down the lane, %.0f from the middle of %.0f: speed %.1f, wall %s, taken %.2f, slide %.2f",
					p.X,
					p.Y,
					p.Z,
					s,
					across,
					width,
					flat(mover.AssemblyLinearVelocity),
					tostring(State.Wall),
					takenNow(),
					rideState and rideState.Slide or -1
				)
			end
		elseif slowFor > 0 then
			slowFor = 0
		elseif slowFor < 0 then
			slowFor = math.min(0, slowFor + dt)
		end
		local _, _, _, _, s = laneAt(mover.Position)
		s1 = s
	end
	log(
		"WANDER on %s for %.0f s, %.0f to %.0f down the lane, at a wall in %d frames: %d stalls | %s",
		fishId(fish),
		os.clock() - began,
		sStart,
		s1,
		walled,
		stalls,
		m.line()
	)
end

-- the rounded mouth of the hub: back up the lane from the start, at its sides and its gate
local function phaseMouth(id, only)
	for _, angle in only or { 150, 165, 180, -165, -150, 120, -120 } do
		if getOn(id) then
			local fish = State.Fish
			local mover = fish.PrimaryPart
			local wide, long = bodyOfRidden()
			local v0 = Config.riddenOf(fish, Config.FishById[fish:GetAttribute("FishType")])
			lookAlongLane(angle)
			local m = newMeter(mover, wide, long, v0)
			local began = os.clock()
			local states = {}
			while os.clock() - began < 9 and State.Mode == "Riding" and State.Fish == fish do
				m.step(RunService.RenderStepped:Wait())
				if State.Wall then
					states[State.Wall] = (states[State.Wall] or 0) + 1
				end
			end
			local p = mover.Position
			local _, _, across, width, s = laneAt(p)
			log(
				"MOUTH %d on %s: ended %.0f down the lane, %.0f from the middle of %.0f, at (%.0f, %.0f, %.0f), mode %s | Slide frames %d, Swing frames %d | %s",
				angle,
				fishId(fish),
				s,
				across,
				width,
				p.X,
				p.Y,
				p.Z,
				State.Mode,
				states.Slide or 0,
				states.Swing or 0,
				m.line()
			)
		end
	end
end

-- the hop and its glide, steered at a wall
local function phaseHopGlide(id, only)
	tune("Jump", "AutoGrab", 0)
	for _, angle in only or { 25, 45, 90 } do
		if getOn(id) then
			lookAlongLane(angle)
			settle(1.2)
			local root = rootOf()
			local fish = State.Fish
			local v0 = flat(fish.PrimaryPart.AssemblyLinearVelocity)
			glideSkip()
			-- leave when the wall is about a second and a half of the hop away
			waitFor(function()
				local look = CFrame.fromOrientation(0, State.Heading, 0).LookVector
				local hit = workspace:Raycast(root.Position, look * 400, glideParams)
				return hit ~= nil and hit.Normal.Y < 0.5 and hit.Distance < math.max(v0, 40) * 1.6
			end, 10)
			Actions.jump()
			waitFor(function()
				return State.Mode == "Jumping"
			end, 1)
			local m = newMeter(root, 1.5, 3, math.max(v0, 30))
			local began = os.clock()
			local seenAt, rodeAt = nil, nil
			local states = {}
			local dumped = true
			local leastRoom = math.huge
			while State.Mode == "Jumping" and os.clock() - began < 7 do
				m.step(RunService.RenderStepped:Wait())
				local taken = takenNow()
				if not dumped and m.Wall < 4.5 then
					dumped = true
					for _, item in ring do
						log("    step %.3f s ago: %s", os.clock() - item.T, item.Line)
					end
				end
				if taken > 0.5 and rideState and rideState.Near then
					leastRoom = math.min(leastRoom, rideState.Near)
				end
				if not seenAt and taken > 0.03 then
					seenAt = os.clock() - began
				end
				if not rodeAt and taken > 0.9 then
					rodeAt = os.clock() - began
				end
				if State.Wall then
					states[State.Wall] = true
				end
			end
			local names = {}
			for name in states do
				table.insert(names, name)
			end
			table.sort(names)
			log(
				"HOPGLIDE %d: left at %.0f st/s | the wall first turned us %.2f s into the hop, rode it from %.2f s | by the game's own rays the least water left to the gap line was %.1f (the gap is Wall.Gap %.1f and half our width; the meter's nearest wall also counts the seabed's tile edges as we sink to the floor) | states %s | ended %s | %s",
				angle,
				v0,
				seenAt or -1,
				rodeAt or -1,
				leastRoom,
				Config.Wall.Gap,
				table.concat(names, "+"),
				State.Mode,
				m.line()
			)
			settle(1)
		end
	end
	tune("Jump", "AutoGrab", 2)
end

-- the camera beside a wall: riding along one, the view is swung away from it (so the camera swings toward the wall)
local function phaseCamWall(id)
	do
		for _, sign in { 1, -1 } do
			if getOn(id) then
				lookAlongLane(30 * sign)
				waitFor(function()
					return takenNow() > 0.9
				end, 12)
				settle(0.8)
				local fish = State.Fish
				local mover = fish.PrimaryPart
				local wide, long = bodyOfRidden()
				local t0 = os.clock()
				lookYaw = function()
					local root = rootOf()
					if not root then
						return nil
					end
					local along, right = laneAt(root.Position)
					local u = math.clamp((os.clock() - t0) / 0.6, 0, 1)
					u = u * u * (3 - 2 * u)
					local a = math.rad((30 - 80 * u) * sign)
					return yawOf(along * math.cos(a) + right * math.sin(a))
				end
				local m = newMeter(mover, wide, long, 64)
				local inside = 0
				local op = OverlapParams.new()
				op.RespectCanCollide = true
				op.FilterType = Enum.RaycastFilterType.Include
				op.FilterDescendantsInstances =
					{ workspace.ClaudeBlockout.Lane.Walls, workspace.ClaudeBlockout.Lane.Ground }
				while os.clock() - t0 < 2 do
					m.step(RunService.RenderStepped:Wait())
					if #workspace:GetPartBoundsInRadius(camera.CFrame.Position, 0.2, op) > 0 then
						inside += 1
					end
				end
				log(
					"CAMWALL wall on the %s: the view swung 80 degrees away from the wall in 0.6 s | camera's speed changed at most %.1f st/s in a frame | camera inside a wall in %d of %d frames | fish at least %.1f from the wall",
					if sign > 0 then "right" else "left",
					m.CamDv,
					inside,
					m.Frames,
					m.Wall
				)
			end
		end
	end
end

-- THE CAMERA UNDER THE LIGHT (2026-11-13): where the camera is against the water's lit sheet, riding, looking about,
-- in a hop and floating in the first land
local function phaseCamTop(label)
	local function sheetBottom()
		local map = workspace:FindFirstChild("ClaudeBlockout")
		local layers = map and map:FindFirstChild("Surface") and map.Surface:FindFirstChild("WaterLayers")
		local sheet = layers and layers:FindFirstChild("Under")
		return if sheet then sheet.Position.Y - sheet.Size.Y / 2 else nil
	end
	local function watch(name, seconds, each, skip)
		local began = os.clock()
		local frames, above, inBand = 0, 0, 0
		local high, low = -math.huge, math.huge
		local lastY, lastVy, jump, lastPos, lastV, dv = nil, nil, 0, nil, nil, 0
		local rootHigh = -math.huge
		while os.clock() - began < seconds do
			local dt = RunService.RenderStepped:Wait()
			if each and each(os.clock() - began) == false then
				break
			end
			if os.clock() - began > (skip or 0) and dt > 0 and dt < 0.1 then
				local y = camera.CFrame.Position.Y
				local bottom = sheetBottom() or -8.5
				frames += 1
				if y > bottom then
					above += 1
				end
				if y > bottom and y < 0 then
					inBand += 1
				end
				high, low = math.max(high, y), math.min(low, y)
				local root = rootOf()
				if root then
					rootHigh = math.max(rootHigh, root.Position.Y)
				end
				if lastY then
					local vy = (y - lastY) / dt
					if lastVy then
						jump = math.max(jump, math.abs(vy - lastVy))
					end
					lastVy = vy
				end
				lastY = y
				local pos = camera.CFrame.Position
				if lastPos then
					local v = (pos - lastPos) / dt
					if lastV then
						dv = math.max(dv, (v - lastV).Magnitude)
					end
					lastV = v
				end
				lastPos = pos
			end
		end
		log(
			"CAMTOP %s %s: camera height %.1f to %.1f (the lit sheet's underside is at %.2f; we were as high as %.1f) | above the sheet's underside in %d of %d frames, in the band of layers in %d | the camera's rise changed by at most %.1f st/s in a frame, its velocity by %.1f",
			label,
			name,
			low,
			high,
			sheetBottom() or -8.5,
			rootHigh,
			above,
			frames,
			inBand,
			jump,
			dv
		)
	end
	if not getOn("Barracuda") then
		return
	end
	lookAlongLane(0)
	watch("riding, view left alone", 5, nil, 1.5)
	-- looking up and down while riding: the view from well above us to well below
	local t0 = os.clock()
	lookYaw = function()
		local root = rootOf()
		if not root then
			return nil
		end
		local along = laneAt(root.Position)
		return yawOf(along), math.rad(-65 + 110 * (0.5 - 0.5 * math.cos((os.clock() - t0) * 2 * math.pi / 4)))
	end
	watch("riding, looking up and down", 8)
	-- a hop, the view high behind us
	tune("Jump", "AutoGrab", 0)
	if getOn("Barracuda") then
		lookYaw = function()
			local root = rootOf()
			if not root then
				return nil
			end
			return yawOf((laneAt(root.Position))), math.rad(-40)
		end
		settle(2)
		Actions.jump()
		watch("in a hop, the view 40 degrees down", 6, function()
			return State.Mode == "Jumping" or State.Mode == "Riding"
		end)
		-- and floating after it (the sandbox doesn't fail): the view left where it was, then swung up and down
		settle(0.5)
		log("CAMTOP %s: mode now %s, we are at height %.1f", label, State.Mode, rootOf() and rootOf().Position.Y or 0)
		watch("after the hop (" .. State.Mode .. "), the view 40 degrees down", 4)
		t0 = os.clock()
		lookYaw = function()
			local root = rootOf()
			if not root then
				return nil
			end
			local along = laneAt(root.Position)
			return yawOf(along), math.rad(-65 + 110 * (0.5 - 0.5 * math.cos((os.clock() - t0) * 2 * math.pi / 4)))
		end
		watch("after the hop (" .. State.Mode .. "), looking up and down", 8)
	end
	tune("Jump", "AutoGrab", 2)
end

------------------------------------------------------------------------------------------------------------------
-- J1 (2026-11-13): the wait between fish, the air's three parts, the hook's reach by speed
local JumpController = require(Client.Controllers.JumpController)
local fxLandAt = nil -- os.clock() the server's "Land" for our own player came in: the landing animation starts
Net.Fx.OnClientEvent:Connect(function(kind, who)
	if kind == "Land" and who == player then
		fxLandAt = os.clock()
	end
end)

local function freeFishFrom(at)
	local folder = workspace:FindFirstChild("Fish")
	local list = {}
	for _, model in folder and folder:GetChildren() or {} do
		if model:IsA("Model") and State.isFreeFish(model) then
			table.insert(list, (model.PrimaryPart.Position - at).Magnitude)
		end
	end
	table.sort(list)
	return list
end
local function within(list, range)
	local n = 0
	for _, d in list do
		if d <= range then
			n += 1
		end
	end
	return n
end
local function percentile(sorted, share)
	if #sorted == 0 then
		return -1
	end
	return sorted[math.clamp(math.ceil(#sorted * share), 1, #sorted)]
end

-- SPACING: ride down the lane and look, twice a second, at how far the free fish are from the rider
local RANGES = { 40, 60, 80, 100, 120, 150, 180 }
local function phaseSpacing(id, seconds)
	if not getOn(id) then
		log("SPACING: could not get on")
		return
	end
	lookAlongLane(0)
	settle(2)
	local nearest, second = {}, {}
	local counts, none = {}, {}
	for _, r in RANGES do
		counts[r], none[r] = 0, 0
	end
	local samples = 0
	local t0 = os.clock()
	local s0, s1 = nil, nil
	while os.clock() - t0 < seconds do
		settle(0.5)
		local root = rootOf()
		if State.Mode ~= "Riding" or not root then
			log("SPACING: no longer riding (%s) after %.0f s", State.Mode, os.clock() - t0)
			break
		end
		local _, _, _, _, s = laneAt(root.Position)
		s0 = s0 or s
		s1 = s
		local list = freeFishFrom(root.Position)
		samples += 1
		table.insert(nearest, list[1] or 999)
		table.insert(second, list[2] or 999)
		for _, r in RANGES do
			local n = within(list, r)
			counts[r] += n
			if n == 0 then
				none[r] += 1
			end
		end
		if samples % 20 == 0 then
			log("SPACING .. %d samples, s %.0f, nearest now %.0f", samples, s, list[1] or -1)
		end
	end
	table.sort(nearest)
	table.sort(second)
	log(
		"SPACING %d samples over s %.0f to %.0f | nearest free fish: median %.0f, 75%% %.0f, 90%% %.0f, 95%% %.0f, worst %.0f | second nearest: median %.0f, 90%% %.0f",
		samples,
		s0 or -1,
		s1 or -1,
		percentile(nearest, 0.5),
		percentile(nearest, 0.75),
		percentile(nearest, 0.9),
		percentile(nearest, 0.95),
		nearest[#nearest] or -1,
		percentile(second, 0.5),
		percentile(second, 0.9)
	)
	local text = {}
	for _, r in RANGES do
		table.insert(
			text,
			string.format(
				"%d: %.1f fish, none in %.0f%%",
				r,
				counts[r] / math.max(samples, 1),
				100 * none[r] / math.max(samples, 1)
			)
		)
	end
	log("SPACING within | %s", table.concat(text, " | "))
end

-- AIR: one whole hop with no grab: speed across the water, height, the hook's reach and the fish inside it, every
-- 0.1 s; and how smooth: the most the rider's speed and the camera's speed change between two frames
local function airRun(label, id, angry, wait)
	tune("Angry", "Test", if angry then 1 else 0)
	if not getOn(id) then
		log("AIR %s: could not get on %s", label, tostring(id))
		return
	end
	lookAlongLane(0)
	settle(wait or 3.5)
	local kind = Config.FishById[State.Fish:GetAttribute("FishType")]
	local had = fishSpeed().Magnitude
	local root = rootOf()
	local from = root.Position
	if not Actions.jump() then
		log("AIR %s: the jump was refused", label)
		return
	end
	local began = os.clock()
	local series = {}
	local nextMark = 0
	local lastAt, lastV, lastVy = root.Position, nil, nil
	local camLast, camVel = camera.CFrame.Position, nil
	local stepFlat, stepFall, stepCam = 0, 0, 0 -- the biggest change between two frames, studs a second
	local stepFlatAt, stepFallAt, stepCamAt = 0, 0, 0
	local path = 0
	local top = 0
	local fallMost = 0
	local reachSum, reach180, reachN = { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } -- fast part, stall, fall
	local j = Config.Jump
	local fastEnd = nil
	while State.Mode == "Jumping" and os.clock() - began < 8 do
		local dt = RunService.RenderStepped:Wait()
		local t = os.clock() - began
		local at = root.Position
		local v = flat(at - lastAt) / math.max(dt, 1e-6)
		local vy = (at.Y - lastAt.Y) / math.max(dt, 1e-6)
		path += flat(at - lastAt)
		top = math.max(top, at.Y - from.Y)
		fallMost = math.max(fallMost, -vy)
		if lastV and t > 0.1 then
			if math.abs(v - lastV) > stepFlat then
				stepFlat, stepFlatAt = math.abs(v - lastV), t
			end
			if math.abs(vy - lastVy) > stepFall then
				stepFall, stepFallAt = math.abs(vy - lastVy), t
			end
		end
		lastAt, lastV, lastVy = at, v, vy
		local eye = camera.CFrame.Position
		local cv = (eye - camLast) / math.max(dt, 1e-6)
		if camVel and t > 0.1 and (cv - camVel).Magnitude > stepCam then
			stepCam, stepCamAt = (cv - camVel).Magnitude, t
		end
		camLast, camVel = eye, cv
		if State.JumpPhase == "Drop" and not fastEnd then
			fastEnd = t
		end
		if t >= nextMark then
			nextMark += 0.1
			local list = freeFishFrom(at)
			local reach = State.Reach or -1
			table.insert(
				series,
				string.format(
					"%.1f,%.0f,%.1f,%.0f,%d,%d",
					t,
					v,
					at.Y - from.Y,
					reach,
					within(list, reach),
					within(list, 180)
				)
			)
			local part = if not fastEnd then 1 elseif t < fastEnd + 0.5 then 2 else 3
			reachSum[part] += within(list, reach)
			reach180[part] += within(list, 180)
			reachN[part] += 1
		end
	end
	local window = os.clock() - began
	log(
		"AIR %s fish=%s had=%.1f | fast part ends %.2fs, window %.2fs, %.0f studs along (path %.0f), top %.1f up, ends %.1f from where it left, fastest fall %.0f st/s",
		label,
		kind.Id,
		had,
		fastEnd or -1,
		window,
		flat(root.Position - from),
		path,
		top,
		root.Position.Y - from.Y,
		fallMost
	)
	log(
		"AIR %s smoothness: biggest change between two frames: speed across %.1f st/s (at %.2fs), fall speed %.1f st/s (at %.2fs), camera %.1f st/s (at %.2fs)",
		label,
		stepFlat,
		stepFlatAt,
		stepFall,
		stepFallAt,
		stepCam,
		stepCamAt
	)
	local names = { "glide", "drop, first 0.5 s", "drop, the rest" }
	local text = {}
	for part = 1, 3 do
		local n = math.max(reachN[part], 1)
		table.insert(
			text,
			string.format(
				"%s: %.1f fish in reach now, %.1f inside 180",
				names[part],
				reachSum[part] / n,
				reach180[part] / n
			)
		)
	end
	log("AIR %s fish in reach | %s", label, table.concat(text, " | "))
	log("AIR %s t,speed,height,reach,inreach,in180: %s", label, table.concat(series, " "))
end

local function speedFish()
	local list = {}
	for _, fish in Config.Fish do
		if not Config.hasArchetype(fish, "Leaper") then
			table.insert(list, fish)
		end
	end
	table.sort(list, function(a, b)
		return a.RiddenSpeed < b.RiddenSpeed
	end)
	local slow, fast = list[1], list[#list]
	local mid = list[1]
	for _, fish in list do
		if math.abs(fish.RiddenSpeed - 75) < math.abs(mid.RiddenSpeed - 75) then
			mid = fish
		end
	end
	return slow, mid, fast
end

local function phaseAir(times)
	local saved = Config.Jump.AutoGrab
	tune("Jump", "AutoGrab", 0)
	local slow, mid, fast = speedFish()
	log(
		"AIR fish: slow %s %.0f, mid %s %.0f, fast %s %.0f",
		slow.Id,
		slow.RiddenSpeed,
		mid.Id,
		mid.RiddenSpeed,
		fast.Id,
		fast.RiddenSpeed
	)
	for i = 1, times do
		airRun("slow-angry#" .. i, slow.Id, true, 5)
		airRun("slow#" .. i, slow.Id, false)
		airRun("normal#" .. i, mid.Id, false)
		airRun("fast#" .. i, fast.Id, false)
	end
	tune("Angry", "Test", 0)
	tune("Jump", "AutoGrab", saved)
	log("AIR done")
end

-- RELOCK: land on a fish (one press to grab, none in the pull-in), then ask to hop every frame from the mount on.
-- When does the landing animation start (the server's "Land"), when does the mount come, when does the hop begin?
local function landOnce()
	if State.Mode ~= "Riding" then
		getOn(nil)
		lookAlongLane(0)
		settle(1.5)
	end
	local root = rootOf()
	local list = freeAhead(root, 40, 140)
	if #list == 0 then
		settle(1)
		list = freeAhead(root, 30, 150)
		if #list == 0 then
			getOn(nil)
			return nil
		end
	end
	local target = list[math.random(1, #list)]
	lookAt(target)
	settle(0.4)
	fxLandAt = nil
	local seen = #events
	local mark = os.clock()
	Actions.jump()
	waitFor(function()
		return os.clock() - mark > 0.3 and State.JumpTarget ~= nil
	end, 1.2)
	Actions.jump() -- the grab: one press, none in the pull-in
	return seen
end
local function jumpsDenied()
	local n = 0
	for index = 1, #events do
		if events[index].Kind == "Denied" and events[index].A == "Jump" then
			n += 1
		end
	end
	return n
end
local function phaseRelock(count)
	local touchToAnim, touchToMount, touchToHop, mountToHop = {}, {}, {}, {}
	local denied = 0
	for i = 1, count do
		local seen = landOnce()
		if seen then
			-- the touch: the first frame the pull-in is whole
			local touch = nil
			local hopAt = nil
			local t0 = os.clock()
			local deniedBefore = jumpsDenied()
			while os.clock() - t0 < 6 do
				RunService.RenderStepped:Wait()
				local u = JumpController.reel()
				if not touch and u and u >= 1 then
					touch = os.clock()
				end
				if touch and State.Mode == "Riding" then
					-- a fresh press each frame from the mount on (nothing was pressed in the pull-in)
					if Actions.jump() and State.Mode == "Jumping" then
						hopAt = os.clock()
						break
					end
				end
				if State.Mode == "Free" then
					break
				end
			end
			local mountAt = nil
			for index = seen + 1, #events do
				if events[index].Kind == "Mounted" then
					mountAt = events[index].At
					break
				end
			end
			settle(0.25)
			local refused = jumpsDenied() - deniedBefore
			denied += refused
			if touch and mountAt and hopAt then
				table.insert(touchToMount, mountAt - touch)
				table.insert(touchToHop, hopAt - touch)
				table.insert(mountToHop, hopAt - mountAt)
				if fxLandAt then
					table.insert(touchToAnim, fxLandAt - touch)
				end
				log(
					"RELOCK %d: touch -> landing animation starts %.3f s, -> mounted %.3f s, -> the next hop began %.3f s (%.3f s after the mount); server refused the hop: %d",
					i,
					if fxLandAt then fxLandAt - touch else -1,
					mountAt - touch,
					hopAt - touch,
					hopAt - mountAt,
					refused
				)
			else
				log(
					"RELOCK %d: incomplete (touch %s mount %s hop %s, mode %s)",
					i,
					tostring(touch),
					tostring(mountAt),
					tostring(hopAt),
					State.Mode
				)
			end
			waitFor(function()
				return State.Mode ~= "Jumping"
			end, 8)
			settle(0.6)
		end
	end
	table.sort(touchToAnim)
	table.sort(touchToMount)
	table.sort(touchToHop)
	table.sort(mountToHop)
	log(
		"RELOCK done (%d, Jump.Cooldown %.2f): touch to animation start median %.3f worst %.3f | touch to mount median %.3f worst %.3f | touch to next hop median %.3f, least %.3f, worst %.3f | mount to next hop median %.3f worst %.3f | hops the server refused: %d",
		#touchToHop,
		Config.Jump.Cooldown,
		median(touchToAnim),
		touchToAnim[#touchToAnim] or -1,
		median(touchToMount),
		touchToMount[#touchToMount] or -1,
		median(touchToHop),
		touchToHop[1] or -1,
		touchToHop[#touchToHop] or -1,
		median(mountToHop),
		mountToHop[#mountToHop] or -1,
		denied
	)
end

-- RATE: fish to fish as fast as presses allow, for a while: hop the first frame it is allowed, grab the first frame a
-- fish is locked and a grab counts. How many landings, and the time from one landing to the next
local function phaseRate(seconds, label)
	if not getOn(nil) then
		return
	end
	lookAlongLane(0)
	settle(2)
	local t0 = os.clock()
	local landings = {}
	local seen = #events
	local misses = 0
	while os.clock() - t0 < seconds do
		RunService.RenderStepped:Wait()
		if State.Mode == "Riding" then
			Actions.jump()
		elseif State.Mode == "Jumping" then
			if State.JumpTarget and not JumpController.reel() then
				Actions.jump()
			end
		elseif State.Mode == "Free" then
			misses += 1
			getOn(nil)
			lookAlongLane(0)
			settle(1)
		end
		while seen < #events do
			seen += 1
			if events[seen].Kind == "Mounted" and events[seen].B == true then
				table.insert(landings, events[seen].At)
			end
		end
	end
	local gaps = {}
	for index = 2, #landings do
		local gap = landings[index] - landings[index - 1]
		if gap < 3 then
			table.insert(gaps, gap)
		end
	end
	table.sort(gaps)
	log(
		"RATE %s (Cooldown %.2f): %d landings in %.0f s, %d sank | landing to landing: least %.3f, median %.3f, 90%% %.3f",
		label,
		Config.Jump.Cooldown,
		#landings,
		seconds,
		misses,
		gaps[1] or -1,
		median(gaps),
		percentile(gaps, 0.9)
	)
	waitFor(function()
		return State.Mode ~= "Jumping"
	end, 8)
end

-- SERVERREACH: the server's own check. A grab asked for straight from the remote, past what the client would allow:
-- early in the hop (fast: a long reach) and after the stall (a short one)
local function phaseServerReach(count)
	local saved = Config.Jump.AutoGrab
	tune("Jump", "AutoGrab", 0)
	local _, mid = speedFish()
	local asked, wrong = 0, 0
	for i = 1, count do
		if getOn(mid.Id) then
			lookAlongLane(0)
			settle(3)
			local late = i % 2 == 0
			local root = rootOf()
			Actions.jump()
			local began = os.clock()
			local j = Config.Jump
			-- (late: well after the stall; early: 0.3 s in)
			waitFor(function()
				if late then
					return State.JumpPhase == "Drop" and (State.Reach or 999) <= j.GrabNear + 16
				end
				return os.clock() - began > 0.3
			end, 6)
			if late then
				settle(0.45) -- (past the server's Net.ReachLag and a little)
			end
			if State.Mode == "Jumping" then
				local reach = State.Reach or 0
				local best, bestD = nil, nil
				local folder = workspace:FindFirstChild("Fish")
				-- late: a fish past the reach we have now (by more than the server's slack), but inside the old 180: to
				-- be refused. Early: the furthest fish INSIDE the reach we have (the fast part's long one): to be granted
				for _, model in folder and folder:GetChildren() or {} do
					if model:IsA("Model") and State.isFreeFish(model) then
						local d = (model.PrimaryPart.Position - root.Position).Magnitude
						if late then
							if d > reach * Config.Net.RangeSlack + 15 and d < 178 and (not bestD or d < bestD) then
								best, bestD = model, d
							end
						elseif d > 75 and d < reach - 3 and (not bestD or d > bestD) then
							best, bestD = model, d
						end
					end
				end
				if best then
					local seen = #events
					Net.Action:FireServer("Grab", best)
					settle(0.35)
					local word = "granted (no refusal came)"
					for index = seen + 1, #events do
						local e = events[index]
						if e.Kind == "Denied" and e.A == "Grab" then
							word = "refused: " .. tostring(e.B)
						end
					end
					asked += 1
					if (string.find(word, "Range") ~= nil) ~= late then
						wrong += 1
					end
					Net.Action:FireServer("CancelGrab")
					log(
						"SERVERREACH %d (%s, %.2f s in): our reach %.0f, asked the server for a fish %.0f away -> %s",
						i,
						if late then "after the stall" else "fast part",
						os.clock() - began,
						reach,
						bestD,
						word
					)
				else
					log("SERVERREACH %d: no fish at the distance wanted (reach %.0f)", i, reach)
				end
			end
			waitFor(function()
				return State.Mode ~= "Jumping"
			end, 8)
			settle(0.4)
		end
	end
	tune("Jump", "AutoGrab", saved)
	log(
		"SERVERREACH done: %d grabs asked of the server (even: past the stalled reach, to be refused; odd: inside the fast part's reach, to be granted), %d answered wrongly",
		asked,
		wrong
	)
end

------------------------------------------------------------------------------------------------------------------
local busy = false
cmd:GetPropertyChangedSignal("Value"):Connect(function()
	local words = string.split(cmd.Value, " ")
	local name = words[1]
	if busy then
		log("busy: %s ignored", name)
		return
	end
	busy = true
	task.spawn(function()
		local ok, err = xpcall(function()
			camReport("(before " .. name .. ")")
			if name == "finalsuite" then
				phaseMounts(36, true, "final code mash=true")
				camReport("mounts")
				phaseChain()
				camReport("chain")
				phaseHop()
				camReport("hop")
				phaseFair()
				camReport("fair")
				phaseWall(1)
				camReport("wall")
				phaseHopWall()
				camReport("hopwall")
				phaseRegress()
				camReport("regress")
				log("FINAL SUITE DONE (%d checks failed)", failures)
			elseif name == "glide" then
				-- glide [fish] [lead seconds]: 15 to 90 degrees into the side, steering off, hugging
				phaseGlide(words[2] or "Barracuda", tonumber(words[3]) or 3)
				log("GLIDE DONE")
			elseif name == "glideone" then
				-- glideone <angle> [fish] [lead seconds] [extras 0|1]
				glideTrace = words[6] == "1"
				glideRun(tonumber(words[2]) or 45, words[3] or "Barracuda", tonumber(words[4]) or 3, words[5] == "1")
				glideTrace = false
			elseif name == "wander" then
				-- wander [fish] [seconds] [straight seconds first]
				wander(words[2] or "Barracuda", tonumber(words[3]) or 60, tonumber(words[4]) or 1)
			elseif name == "mouth" then
				phaseMouth(
					words[2] or "Barracuda",
					if words[4] and tonumber(words[3]) then { tonumber(words[3]) } else nil
				)
				log("MOUTH DONE")
			elseif name == "hopglide" then
				phaseHopGlide(
					words[2] or "Barracuda",
					if words[4] and tonumber(words[3]) then { tonumber(words[3]) } else nil
				)
				log("HOPGLIDE DONE")
			elseif name == "pose" then
				-- pose <float|hop|ride> <pitch degrees> <seconds>: hold a view for a picture
				local pitchTo = math.rad(tonumber(words[3]) or 10)
				local function hold()
					lookYaw = function()
						local root = rootOf()
						if not root then
							return nil
						end
						return yawOf((laneAt(root.Position))), pitchTo
					end
				end
				if getOn("Barracuda") then
					hold()
					if words[2] ~= "ride" then
						tune("Jump", "AutoGrab", 0)
						settle(1.5)
						Actions.jump()
						if words[2] == "float" then
							waitFor(function()
								local root = rootOf()
								return State.Mode == "Free" and root ~= nil and root.Position.Y > -3.6
							end, 40)
						else
							settle(0.9)
						end
					end
					log(
						"POSE %s ready: mode %s, we at %.1f, camera at %.1f",
						tostring(words[2]),
						State.Mode,
						rootOf().Position.Y,
						camera.CFrame.Position.Y
					)
					settle(tonumber(words[4]) or 20)
					tune("Jump", "AutoGrab", 2)
				end
			elseif name == "camwall" then
				phaseCamWall(words[2] or "Barracuda")
				log("CAMWALL DONE")
			elseif name == "camtop" then
				phaseCamTop(words[2] or "")
				log("CAMTOP DONE")
			elseif name == "walldeep" then
				-- the walls further down: a fast fish rides straight for a while first (each run starts at the top)
				local list = pickFish()
				local fast = list[#list].Id
				for _, run in { { 20, 45 }, { 20, 15 }, { 40, 75 }, { 40, 30 }, { 60, 90 }, { 60, -45 }, { 75, 15 } } do
					wallRun(run[2], if tonumber(words[2]) then fast else words[2], false, run[1])
				end
				log("WALLDEEP DONE (%d checks failed)", failures)
			elseif name == "set" then
				-- set <Group> <Key> <value>
				tune(words[2], words[3], tonumber(words[4]))
				log("SET %s.%s = %s", words[2], words[3], tostring(Config[words[2]][words[3]]))
			elseif name == "walltrace" then
				-- walltrace <angle> <lead seconds> <trace from, seconds after the lead>: wallone, with a line every 0.12 s
				task.delay((tonumber(words[3]) or 3.5) + (tonumber(words[4]) or 0) + 1.5, function()
					tracing = true
				end)
				wallRun(tonumber(words[2]) or 45, "Barracuda", false, tonumber(words[3]) or 3.5)
				tracing = false
			elseif name == "wallone" then
				-- wallone <angle> <lead seconds> <hop 0|1> [fish]
				wallRun(
					tonumber(words[2]) or 45,
					if tonumber(words[5]) then nil else words[5],
					words[4] == "1",
					tonumber(words[3]) or 3.5
				)
			elseif name == "suite" then
				tune("Jump", "RehookGuard", 0)
				tune("Jump", "LandWait", 0)
				tune("Jump", "HopGuard", 0)
				phaseMounts(32, true, "baseline mash=true")
				tune("Jump", "RehookGuard", 0.45)
				tune("Jump", "LandWait", 0.5)
				tune("Jump", "HopGuard", 0.25)
				phaseMounts(36, true, "fixed mash=true")
				phaseChain()
				phaseHop()
				phaseFair()
				phaseWall(1)
				phaseHopWall()
				phaseRegress()
				log("SUITE DONE")
			elseif name == "probe" then
				phaseWall(1)
				phaseHopWall()
				phaseHop()
				log("PROBE DONE")
			elseif name == "cameradiag" then
				wallRun(15, "Barracuda", false)
				wallRun(45, "Barracuda", true)
				wallRun(90, "Barracuda", true)
				log("CAMERADIAG DONE")
			elseif name == "trace" then
				wallRun(15, "Barracuda", false)
				wallRun(45, "Barracuda", false)
				log("TRACE done")
			elseif name == "clear" then
				report:FireServer("__clear")
			elseif name == "hop" then
				phaseHop()
			elseif name == "spacing" then
				-- spacing [fish] [seconds]
				phaseSpacing(if words[2] and words[2] ~= "-" then words[2] else "Barracuda", tonumber(words[3]) or 60)
			elseif name == "air" then
				phaseAir(tonumber(words[2]) or 1)
			elseif name == "relock" then
				phaseRelock(tonumber(words[2]) or 12)
			elseif name == "rate" then
				phaseRate(tonumber(words[2]) or 40, words[3] or "")
			elseif name == "serverreach" then
				phaseServerReach(tonumber(words[2]) or 8)
			elseif name == "fair" then
				phaseFair()
			elseif name == "mounts" then
				-- mounts <count> <fix 0|1> <mash 0|1>
				local count = tonumber(words[2]) or 30
				local fix = words[3] ~= "0"
				local mash = words[4] == "1"
				mashEvery = tonumber(words[5]) or 0.1
				tune("Jump", "RehookGuard", if fix then 0.45 else 0)
				tune("Jump", "LandWait", if fix then 0.5 else 0)
				tune("Jump", "HopGuard", if fix then 0.25 else 0)
				tune("Angry", "Test", 0)
				phaseMounts(
					count,
					mash,
					string.format("fix=%s mash=%s every=%.2f", tostring(fix), tostring(mash), mashEvery)
				)
				mashEvery = 0.1
				tune("Jump", "RehookGuard", 0.45)
				tune("Jump", "LandWait", 0.5)
				tune("Jump", "HopGuard", 0.25)
			elseif name == "chain" then
				phaseChain()
			elseif name == "wall" then
				phaseWall(tonumber(words[2]) or 1)
			elseif name == "hopwall" then
				phaseHopWall()
			elseif name == "regress" then
				phaseRegress()
			else
				log("unknown command %s", tostring(name))
			end
		end, debug.traceback)
		if not ok then
			log("ERROR in %s: %s", tostring(name), tostring(err))
		else
			camReport(name)
			log("DONE %s (%d checks failed so far)", name, failures)
		end
		lookYaw = nil
		key = 0
		busy = false
	end)
end)
log("driver up")
