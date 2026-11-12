-- A2 archetype playtest: the client driver (temporary; removed after the run)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LogService = game:GetService("LogService")
local player = Players.LocalPlayer
local report = RS:WaitForChild("A2Report")
local ask = RS:WaitForChild("A2Ask")
local cmd = RS:WaitForChild("A2Cmd")
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
local Net = require(RS.Shared:WaitForChild("Net"))
local camera = workspace.CurrentCamera

local function rootOf()
	local _, root = State.character()
	return root
end

-- steering: toward a point (the fish follows the view), or a held key
local steerTo = nil -- Vector3 or Model
local aimPitch = nil
local key = 0
local trueMove = RideController.moveVector
RideController.moveVector = function()
	if key ~= 0 then
		return Vector3.new(key, 0, 0)
	end
	return Vector3.zero
end
RunService:BindToRenderStep("A2Steer", Enum.RenderPriority.Camera.Value - 20, function()
	local root = rootOf()
	local target = steerTo
	if typeof(target) == "Instance" then
		target = target.PrimaryPart and target.PrimaryPart.Position or nil
	end
	if root and target then
		local from = if aimPitch == "camera" then camera.CFrame.Position else root.Position
		local d = target - from
		if d.Magnitude > 1 then
			local yaw = math.atan2(-d.X, -d.Z)
			local pitch = if aimPitch == "camera" then math.asin(math.clamp(d.Unit.Y, -1, 1)) else math.rad(-12)
			RideController.look(yaw, pitch)
		end
	elseif type(aimPitch) == "number" then
		RideController.look(State.Heading, math.rad(aimPitch))
	end
end)

-- what the server tells us
local events = {}
Net.Ride.OnClientEvent:Connect(function(kind, a, b, c, d, e)
	if kind == "Boost" or kind == "Crashed" or kind == "Mounted" or kind == "Denied" then
		table.insert(events, { At = os.clock(), Kind = kind, A = a, B = b, C = c, D = d, E = e })
	end
end)
local function since(at, kind, a)
	for i = #events, 1, -1 do
		local e = events[i]
		if e.At < at then
			break
		end
		if e.Kind == kind and (a == nil or e.A == a) then
			return e
		end
	end
	return nil
end
-- every upward step of the Oxygen attribute, as a share of the max
local lastOxygen = player:GetAttribute("Oxygen") or 0
local gains = {}
player:GetAttributeChangedSignal("Oxygen"):Connect(function()
	local now = player:GetAttribute("Oxygen")
	local max = player:GetAttribute("MaxOxygen") or 1
	if now > lastOxygen then
		table.insert(gains, { At = os.clock(), Gain = (now - lastOxygen) / max, From = lastOxygen / max })
	elseif now < lastOxygen - max * 0.02 then
		table.insert(gains, { At = os.clock(), Gain = (now - lastOxygen) / max, From = lastOxygen / max })
	end
	lastOxygen = now
end)
local function gainSince(at)
	for i = #gains, 1, -1 do
		if gains[i].At >= at - 0.05 then
			return gains[i]
		end
	end
	return nil
end

local function speedNow()
	local fish = State.Fish
	local root = fish and fish.PrimaryPart
	return root and root.AssemblyLinearVelocity.Magnitude or 0
end

-- median and max of our fish's speed over `time` seconds, on this machine; with the server's own path speed
local function measure(time)
	local server, serverMedian
	local done = false
	task.spawn(function()
		server, serverMedian = ask:InvokeServer("speed", time)
		done = true
	end)
	local samples = {}
	local t0 = os.clock()
	while os.clock() - t0 < time do
		RunService.RenderStepped:Wait()
		table.insert(samples, speedNow())
	end
	table.sort(samples)
	local t1 = os.clock()
	while not done and os.clock() - t1 < 2 do
		task.wait()
	end
	return samples[math.max(1, #samples // 2)], samples[#samples], server or -1, serverMedian or -1
end

local function ride(id, variant, max)
	variant = variant or ""
	steerTo = nil
	aimPitch = nil
	key = 0
	if max then
		ask:InvokeServer("max", max)
	end
	for attempt = 1, 3 do
		Net.Sandbox:FireServer("Ride", id, variant)
		local t0 = os.clock()
		while os.clock() - t0 < 14 do
			task.wait(0.1)
			local f = State.Fish
			if State.Mode == "Riding" and f and f:GetAttribute("FishType") == id and Config.variantOf(f) == variant and os.clock() - State.MountedAt < 1 then
				return f
			end
		end
		log("ride %s %s: attempt %d did not seat (mode %s)", id, variant, attempt, State.Mode)
	end
	return nil
end

local function expectSpeed(id, variant)
	return Config.speedOf(Config.FishById[id], variant or "")
end

-- phase: the steady ridden speed of a fish
local function speedPhase(id, variant, max)
	local fish = ride(id, variant, max)
	if not fish then
		log("SPEED %s %s: FAILED to ride", id, variant or "")
		return nil
	end
	task.wait(3.6)
	local t0 = os.clock()
	local median, most, server, serverMedian = measure(1.5)
	local crashed = since(t0 - 3, "Crashed")
	log(
		"SPEED %s%s archetype=[%s] expect=%.1f client_median=%.1f client_max=%.1f server_path=%.1f server_median=%.1f%s",
		id,
		if variant and variant ~= "" then "(" .. variant .. ")" else "",
		Config.archetypeOf(fish),
		expectSpeed(id, variant),
		median,
		most,
		server,
		serverMedian,
		if crashed then " (crashed during the window)" else ""
	)
	return fish
end

-- the nearest free fish ahead that this fish could eat (by Predator.Prey) or, with `any`, any free fish
local function preyAhead(fish, any)
	local root = fish.PrimaryPart
	local kind = Config.FishById[fish:GetAttribute("FishType")]
	local longest = kind.Size.Z * Config.Archetype.Predator.Prey
	local look = root.CFrame.LookVector
	local best, bestD = nil, 220
	for _, m in workspace.Fish:GetChildren() do
		local r = m.PrimaryPart
		local k = Config.FishById[m:GetAttribute("FishType")]
		if m ~= fish and r and k and State.isFreeFish(m) and (any or k.Size.Z <= longest) then
			local d = r.Position - root.Position
			local n = d.Magnitude
			if n < bestD and d:Dot(look) > 0.3 * n and math.abs(d.Y) < 5 then
				best, bestD = m, n
			end
		end
	end
	return best
end

-- phase: steer into fish for `time` seconds and log every bite
local function eatPhase(fish, label, time, wantBites)
	local id = fish:GetAttribute("FishType")
	local ridden = expectSpeed(id, Config.variantOf(fish))
	local t0 = os.clock()
	local seen = #events
	local bites = 0
	local before1, parked1 = ask:InvokeServer("count")
	while os.clock() - t0 < time and bites < wantBites and State.Mode == "Riding" do
		steerTo = preyAhead(fish, false)
		RunService.RenderStepped:Wait()
		for i = seen + 1, #events do
			local e = events[i]
			if e.Kind == "Boost" and e.A == "Eat" then
				bites += 1
				local at = e.At
				-- the burst: the most the fish goes in the next 0.8 s
				local most = 0
				local t1 = os.clock()
				while os.clock() - t1 < 0.8 do
					RunService.RenderStepped:Wait()
					steerTo = preyAhead(fish, false)
					most = math.max(most, speedNow())
				end
				local gain = gainSince(at)
				log(
					"EAT %s #%d burst=x%.2f for %.1fs oxygen=+%.0f%% stacks=%d | measured: top speed %.1f = x%.2f of %.1f, meter %s (from %.0f%%), t=+%.1fs",
					label,
					bites,
					e.B,
					e.C,
					e.D * 100,
					e.E,
					most,
					most / ridden,
					ridden,
					if gain then string.format("%+.1f%%", gain.Gain * 100) else "no step seen",
					if gain then gain.From * 100 else -1,
					at - t0
				)
			end
		end
		seen = #events
	end
	steerTo = nil
	local after1, parked2 = ask:InvokeServer("count")
	log("EAT %s: %d bites in %.1f s; fish in the water %d -> %d, parked %d -> %d; %s", label, bites, os.clock() - t0, before1, after1, parked1, parked2, ask:InvokeServer("attrs"))
	return bites
end

-- phase: steer into the nearest prop ahead and log what it costs or pays
local function propPhase(fish, label)
	local id = fish:GetAttribute("FishType")
	local ridden = expectSpeed(id, Config.variantOf(fish))
	local at, size, boxes, name = ask:InvokeServer("prop", 90)
	if not at then
		log("PROP %s: no prop found ahead", label)
		return
	end
	local root = fish.PrimaryPart
	log("PROP %s: heading for %s (%d boxes, %.0f x %.0f x %.0f) %.0f studs away", label, name, boxes, size.X, size.Y, size.Z, (at - root.Position).Magnitude)
	steerTo = at
	local t0 = os.clock()
	local seen = #events
	local got = nil
	while os.clock() - t0 < 16 and not got and State.Mode == "Riding" do
		RunService.RenderStepped:Wait()
		for i = seen + 1, #events do
			local e = events[i]
			if (e.Kind == "Boost" and e.A == "Smash") or e.Kind == "Crashed" then
				got = e
			end
		end
		seen = #events
		if ((at - root.Position) * Vector3.new(1, 0, 1)).Magnitude < 6 and not got then
			-- through the middle of it with nothing said: wait a moment more, then give up
			task.wait(0.6)
			for i = seen + 1, #events do
				local e = events[i]
				if (e.Kind == "Boost" and e.A == "Smash") or e.Kind == "Crashed" then
					got = e
				end
			end
			break
		end
	end
	steerTo = nil
	if not got then
		log("PROP %s: reached it and nothing was said (no boxes within reach?)", label)
		return
	end
	local least, most = math.huge, 0
	local t1 = os.clock()
	while os.clock() - t1 < 0.7 do
		RunService.RenderStepped:Wait()
		local s = speedNow()
		least = math.min(least, s)
		most = math.max(most, s)
	end
	local gain = gainSince(got.At)
	if got.Kind == "Boost" then
		log(
			"PROP %s: SMASH paid: burst=x%.2f for %.1fs oxygen=+%.0f%% boxes=%d | measured: speed %.1f to %.1f (x%.2f to x%.2f of %.1f), meter %s; %s",
			label,
			got.B,
			got.C,
			got.D * 100,
			got.E,
			least,
			most,
			least / ridden,
			most / ridden,
			ridden,
			if gain then string.format("%+.1f%%", gain.Gain * 100) else "no step seen",
			ask:InvokeServer("attrs")
		)
	else
		log(
			"PROP %s: CRASHED keep=x%.2f | measured: speed %.1f to %.1f (x%.2f to x%.2f of %.1f), meter %s",
			label,
			got.A,
			least,
			most,
			least / ridden,
			most / ridden,
			ridden,
			if gain then string.format("%+.1f%%", gain.Gain * 100) else "no step seen"
		)
	end
end

-- phase: the drain and where the fish turns angry
local function drainPhase(id, max)
	local fish = ride(id, "", max)
	if not fish then
		log("DRAIN %s: FAILED to ride", id)
		return
	end
	task.wait(0.5)
	local drain = player:GetAttribute("Drain")
	local kind = Config.FishById[id]
	local t0 = os.clock()
	local angryAt = nil
	while os.clock() - t0 < 14 do
		RunService.RenderStepped:Wait()
		if fish:GetAttribute("Angry") == true then
			angryAt = player:GetAttribute("Oxygen") / player:GetAttribute("MaxOxygen")
			break
		end
	end
	local slowed = 0
	if angryAt then
		task.wait(0.9)
		slowed = speedNow()
	end
	log(
		"DRAIN %s (%s, [%s]) max=%d: Drain attribute=%.1f a second (rarity alone would be %.1f); turned angry with %.0f%% of the meter left after %.1f s, style=%s, speed then %.1f of %.1f",
		id,
		kind.Tier,
		kind.Archetype,
		max,
		drain or -1,
		Config.drain(1, kind.Tier),
		(angryAt or -1) * 100,
		os.clock() - t0 + 0.5,
		tostring(fish:GetAttribute("AngryStyle")),
		slowed,
		expectSpeed(id, "")
	)
	-- the hop still works on an angry fish
	local ok = Actions.jump()
	task.wait(0.15)
	log("DRAIN %s: hop off the angry fish: asked=%s mode=%s", id, tostring(ok), State.Mode)
end

-- phase: land on a fish of this kind (put ahead of us) and log the speed through the landing
local function landPhase(id, max)
	local fish = ride(id, "", max)
	if not fish then
		log("LAND %s: FAILED to ride", id)
		return
	end
	local ridden = expectSpeed(id, "")
	for attempt = 1, 4 do
		task.wait(1.6)
		if State.Mode ~= "Riding" then
			fish = ride(id, "", max)
			task.wait(1.6)
		end
		local target = ask:InvokeServer("spawn", id, "", 75)
		task.wait(1.3)
		if not target or not target.PrimaryPart then
			log("LAND %s: the fish put ahead did not reach us", id)
			continue
		end
		steerTo = target
		aimPitch = "camera"
		local t0 = os.clock()
		Actions.jump()
		local landed = nil
		while os.clock() - t0 < 5 do
			RunService.RenderStepped:Wait()
			local e = since(t0, "Mounted")
			if e and e.B == true then
				landed = e
				break
			end
			if State.Mode == "Free" then
				break
			end
		end
		steerTo = nil
		aimPitch = nil
		if landed and State.Fish == target then
			local m0 = State.MountedAt
			local least, most, mostAt = math.huge, 0, 0
			local at02, at09 = 0, 0
			local final = 0
			local series = {}
			local nextAt = 0
			while os.clock() - m0 < 5 do
				RunService.RenderStepped:Wait()
				local t = os.clock() - m0
				local s = speedNow()
				if t >= nextAt then
					nextAt += 0.25
					local r = State.Fish and State.Fish.PrimaryPart
					table.insert(series, string.format("%.0f", s))
				end
				if t > 0.12 and t < 0.5 then
					least = math.min(least, s)
				end
				if t > 0.3 and s > most then
					most, mostAt = s, t
				end
				if t < 0.25 then
					at02 = s
				end
				final = s
			end
			log(
				"LAND %s [%s]: landed after %.2f s in the air; dips to %.1f (x%.2f of %.1f) in the first half second; tops at %.1f (x%.2f) %.2f s after the landing; %.1f (x%.2f) at 5 s",
				id,
				Config.FishById[id].Archetype,
				landed.At - t0,
				least,
				least / ridden,
				ridden,
				most,
				most / ridden,
				mostAt,
				final,
				final / ridden
			)
			log("LAND %s series every 0.25 s: %s; crashed=%s angry=%s", id, table.concat(series, " "), tostring(since(m0, "Crashed") ~= nil), tostring(State.Fish and State.Fish:GetAttribute("Angry")))
			return
		else
			log("LAND %s: attempt %d landed on %s, not the fish put ahead (mode %s)", id, attempt, State.Fish and State.Fish:GetAttribute("FishType") or "nothing", State.Mode)
		end
	end
end

-- phase: the hop off a fish: window, height, glide speed
local function hopPhase(id, max)
	local fish = ride(id, "", max)
	if not fish then
		log("HOP %s: FAILED to ride", id)
		return
	end
	-- swim on a while first: deeper water, so the hop's top is not cut short by the surface
	task.wait(7)
	if State.Mode ~= "Riding" then
		log("HOP %s: no longer riding before the hop (%s)", id, State.Mode)
		return
	end
	local root = rootOf()
	local y0 = root.Position.Y
	local ridden = expectSpeed(id, "")
	aimPitch = 35 -- looking up: nothing to lock, so the whole hop is flown
	local t0 = os.clock()
	local ok = Actions.jump()
	RunService.RenderStepped:Wait()
	local window = State.WindowLeft
	local top, glide, flown = 0, 0, 0
	local glideAt = Config.Jump.LaunchTime + 0.9
	while os.clock() - t0 < 6 and State.Mode == "Jumping" do
		RunService.RenderStepped:Wait()
		local t = os.clock() - t0
		top = math.max(top, root.Position.Y - y0)
		if t >= glideAt and glide == 0 then
			glide = State.Speed
		end
		flown = t
		if t > 2.6 then
			aimPitch = -35 -- now look down at the herd: grab whatever is there
		end
	end
	aimPitch = nil
	local apexMul, airMul, extra = Config.hopOf(Config.FishById[id])
	local roof = Config.Oxygen.SurfaceY - Config.Jump.Ceiling
	log(
		"HOP %s [%s]: asked=%s window=%.2f s (expect %.2f); rose %.1f studs (expect %.1f; left at y=%.1f, the surface allows %.1f); glide speed %.1f (expect %.1f); in the air %.2f s, then %s",
		id,
		Config.FishById[id].Archetype,
		tostring(ok),
		window or -1,
		Config.Jump.Window + extra,
		top,
		Config.Jump.Apex * apexMul + Config.Jump.FloatRise,
		y0,
		roof - y0,
		glide,
		Config.Jump.AirShare * ridden * airMul,
		flown,
		State.Mode
	)
end

-- phase: A held for a second (the control pass measured 129 degrees)
local function steerPhase(id)
	local fish = ride(id, "", 100000)
	if not fish then
		return
	end
	task.wait(2.5)
	local h0 = State.Heading
	key = -1
	task.wait(1)
	key = 0
	local turned = math.deg(State.Heading - h0)
	task.wait(0.5)
	log("STEER %s: A held 1 s turned us %.0f degrees (the control pass measured 129), %.0f more after letting go", id, turned, math.deg(State.Heading - h0) - turned)
end

local function run(name, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		log("PHASE %s ERROR: %s", name, tostring(err))
	end
end

local PHASES = {}
PHASES.speeds = function()
	for _, row in { { "Clownfish", "" }, { "Clownfish", "Gold" }, { "Clownfish", "Rainbow" }, { "ReefShark", "" }, { "ReefShark", "Gold" }, { "HumpheadWrasse", "" }, { "Swordfish", "" }, { "Swordfish", "Rainbow" }, { "Dolphin", "" }, { "GiantSeaBass", "" }, { "Megalodon", "" }, { "Dunkleosteus", "" } } do
		speedPhase(row[1], row[2], 10000000)
	end
end
PHASES.eat = function()
	local fish = speedPhase("ReefShark", "", 180 * 25)
	if fish then
		log("PREYTEST %s", tostring(ask:InvokeServer("preytest")))
		eatPhase(fish, "ReefShark", 40, 3)
		-- the hop still works in the middle of a burst
		local ok = Actions.jump()
		task.wait(0.15)
		log("EAT ReefShark: hop right after a bite: asked=%s mode=%s", tostring(ok), State.Mode)
	end
	-- a plain fish never eats
	local plain = ride("Clownfish", "", 100000)
	if plain then
		local t0 = os.clock()
		local touched = 0
		while os.clock() - t0 < 12 do
			steerTo = preyAhead(plain, true)
			RunService.RenderStepped:Wait()
			if steerTo and (steerTo.PrimaryPart.Position - plain.PrimaryPart.Position).Magnitude < 6 then
				touched += 1
			end
		end
		steerTo = nil
		log("EAT Clownfish (plain): %d frames within 6 studs of another fish, bites=%s", touched, tostring(since(t0, "Boost") ~= nil))
	end
end
PHASES.frenzy = function()
	local fish = ride("Megalodon", "", 600 * 40)
	if fish then
		task.wait(2)
		eatPhase(fish, "Megalodon", 45, 6)
	end
end
PHASES.props = function()
	for _, row in { { "HumpheadWrasse", 180 * 30 }, { "Clownfish", 40 * 30 }, { "Dunkleosteus", 600 * 30 } } do
		local fish = ride(row[1], "", row[2])
		if fish then
			task.wait(2.5)
			propPhase(fish, row[1])
		end
	end
end
PHASES.combo = function()
	local fish = ride("Dunkleosteus", "", 600 * 80)
	if fish then
		eatPhase(fish, "Dunkleosteus", 14, 2)
		if State.Mode == "Riding" then
			propPhase(fish, "Dunkleosteus")
		end
	end
end
PHASES.drain = function()
	drainPhase("GiantSeaBass", 650)
	drainPhase("Seahorse", 1000)
	drainPhase("Clownfish", 400)
end
PHASES.land = function()
	landPhase("Swordfish", 10000000)
	landPhase("Clownfish", 10000000)
end
PHASES.hop = function()
	hopPhase("Dolphin", 10000000)
	hopPhase("Clownfish", 10000000)
end
PHASES.steer = function()
	steerPhase("Clownfish")
	steerPhase("ReefShark")
end
-- for the pictures: ride a fish and keep doing its thing, words held longer so a still can catch them
PHASES.photo_eat = function()
	Config.ArchetypeFeel.WordTime = 3
	local fish = ride("Megalodon", "", 600 * 60)
	if fish then
		task.wait(2)
		eatPhase(fish, "photo", 40, 30)
	end
end
PHASES.photo_smash = function()
	Config.ArchetypeFeel.WordTime = 3
	local fish = ride("HumpheadWrasse", "", 180 * 60)
	if fish then
		task.wait(2)
		propPhase(fish, "photo")
	end
end
PHASES.photo_tags = function()
	local fish = ride("ReefShark", "", 180 * 200)
	task.wait(0.5)
	local list = { "GiantSeaBass", "HumpheadWrasse", "Archelon", "Dunkleosteus", "Dolphin" }
	for i = 1, #list do
		ask:InvokeServer("spawn", list[i], "", 45 + i * 22)
	end
	log("photo_tags placed")
	task.wait(12)
end

local busy = false
cmd.Changed:Connect(function(value)
	local name = string.match(value, "^([%w_]+)")
	local phase = PHASES[name]
	if not phase or busy then
		return
	end
	busy = true
	log("BEGIN %s", name)
	Net.Sandbox:FireServer("Flag", "EndlessAir", false)
	task.wait(0.3)
	run(name, phase)
	log("END %s", name)
	busy = false
end)
log("driver ready, mode %s", State.Mode)
