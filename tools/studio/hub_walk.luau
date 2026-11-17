--!nocheck
-- The hub's walks, timed in Play (the user, 2026-11-17: "a base scale reduction of the hub ... and possibly a slight
-- movement speed increase, verify my numbers with gameplay"). Run in the Client datamodel while playing, standing in
-- the hub. It turns the player's own controls off, walks the character in straight lines with Humanoid:Move (the
-- default controls would cancel MoveTo), from the spawn and from each tank's collect pad, at each SPEEDS, and turns
-- the controls back on. Prints one line a walk: its length, the time and whether it got there.
-- The reference's, measured (docs/reference/ride-a-dino-map.md): 28 studs a second; own pen to the start, 4 seconds.
local SPEEDS = { 28, 32 }

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
-- this game has no default PlayerModule (its own controllers move the player); where there is one, it is turned off
local module = player.PlayerScripts:FindFirstChild("PlayerModule")
local controls = if module then require(module):GetControls() else { Disable = function() end, Enable = function() end }
local character = player.Character
local humanoid = character:FindFirstChildOfClass("Humanoid")
local root = character.PrimaryPart
local dock = workspace.ClaudeBlockout.Dock

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end
local spawn = dock.DockSpawn.Position
local strip = dock.StartStrip.Position
local strip_edge = Vector3.new(strip.X, 0, strip.Z - dock.StartStrip.Size.Z / 2 + 2) -- just onto the strip
local places = { { "spawn", spawn } }
for _, plot in dock.Plots:GetChildren() do
	table.insert(places, { plot.Name, plot.CollectPad.Position })
end
table.sort(places, function(a, b)
	return a[1] < b[1]
end)
local function ring(name)
	return dock.Stations[name].Ring.Position
end

local function put(at)
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = CFrame.new(Vector3.new(at.X, 4, at.Z))
	task.wait(0.4)
end

-- walk straight at `to`; the time to come within 3 studs, or nil if it stops dead (something in the way)
local function walk(to, speed)
	humanoid.WalkSpeed = speed
	local t0, still, last = os.clock(), 0, root.Position
	while true do
		local d = flat(to) - flat(root.Position)
		if d.Magnitude < 3 then
			break
		end
		humanoid:Move(d.Unit, false)
		local dt = RunService.Heartbeat:Wait()
		if (flat(root.Position) - flat(last)).Magnitude < speed * dt * 0.2 then
			still += dt
		else
			still = 0
		end
		last = root.Position
		if still > 1 or os.clock() - t0 > 30 then
			humanoid:Move(Vector3.zero, false)
			return nil, (flat(to) - flat(root.Position)).Magnitude
		end
	end
	humanoid:Move(Vector3.zero, false)
	return os.clock() - t0
end

local out = {}
controls:Disable()
local ok, err = pcall(function()
	for _, speed in SPEEDS do
		local routes = {
			{ "spawn to the start strip", spawn, strip_edge },
			{ "spawn to SELL", spawn, ring("Sell") },
			{ "spawn to FUSE", spawn, ring("Fuse") },
			{ "spawn to INDEX", spawn, ring("Index") },
		}
		for _, p in places do
			if p[1] ~= "spawn" then
				table.insert(routes, { p[1] .. " (its pad) to the start strip", p[2], strip_edge })
			end
		end
		for _, r in routes do
			put(r[2])
			local t, left = walk(r[3], speed)
			local length = (flat(r[3]) - flat(r[2])).Magnitude
			table.insert(out, string.format("%d/s  %-38s %4.0f studs  %s", speed, r[1], length,
				if t then string.format("%.1f s", t) else string.format("STOPPED %.0f short", left)))
		end
	end
end)
controls:Enable()
humanoid.WalkSpeed = SPEEDS[1]
if not ok then
	table.insert(out, "FAILED: " .. tostring(err))
end
return table.concat(out, "\n")
