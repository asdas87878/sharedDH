-- Feel review: the server's sample of a run (paste into the Server datamodel through the Studio MCP, in Play, after the
-- player is riding). Every 0.1 s until SECONDS or until ServerStorage.ReviewLog2 gets a "Stop" attribute: the clock
-- (os.clock, which the client shares in Studio, so hops can be matched to it), the player's state, oxygen, max oxygen,
-- the free fish within 95, 140 and 250 studs of the rider (to each fish's whole body, Config.fishGap), the rider's
-- speed, Z, place down the lane (s) and zone. The rows are written to ServerStorage.ReviewLog2 (a StringValue) every
-- 5 s and at the end; summarise them with review_summary.luau.
local SECONDS = 520
local p = game:GetService("Players"):GetPlayers()[1]
local Shared = game.ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Zones = require(Shared.Zones)
local Lane = require(Shared.Lane)
local lane = Lane.build(Zones.discover(), Zones.pathJson())
local old = game.ServerStorage:FindFirstChild("ReviewLog2")
if old then
	old:SetAttribute("Stop", true)
	old.Name = "ReviewLogOld"
end
local out = Instance.new("StringValue")
out.Name = "ReviewLog2"
out.Parent = game.ServerStorage
local lines = {}
local start = os.clock()
local lastFlush = start
task.spawn(function()
	while os.clock() - start < SECONDS and p.Parent and not out:GetAttribute("Stop") do
		local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			local n95, n140, n250 = 0, 0, 0
			for _, m in workspace.Fish:GetChildren() do
				if m:IsA("Model") and m.PrimaryPart and m:GetAttribute("Rider") == 0 then
					local g = Config.fishGap(m, hrp.Position)
					if g <= 95 then n95 += 1 end
					if g <= 140 then n140 += 1 end
					if g <= 250 then n250 += 1 end
				end
			end
			local s = Lane.project(lane, hrp.Position)
			table.insert(lines, string.format("%.2f,%s,%.1f,%.0f,%d,%d,%d,%.0f,%.0f,%.0f,%d", os.clock(), tostring(p:GetAttribute("State")),
				tonumber(p:GetAttribute("Oxygen")) or -1, tonumber(p:GetAttribute("MaxOxygen")) or -1, n95, n140, n250,
				hrp.AssemblyLinearVelocity.Magnitude, hrp.Position.Z, s, Lane.zoneAt(lane, s)))
		end
		if os.clock() - lastFlush > 5 then
			out.Value = table.concat(lines, "\n")
			lastFlush = os.clock()
		end
		task.wait(0.1)
	end
	out.Value = table.concat(lines, "\n")
	out:SetAttribute("Done", true)
end)
return string.format("sampling up to %d s from clock %.1f", SECONDS, start)
