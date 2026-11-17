-- The submarine's scripted playtest (docs/design/submarine.md), run in a playtest's server through studio-runner:
--   node ~/Projects/studio-runner/studio-run.mjs --ctx server docs/playtests/submarine/drive.luau LAND=5 FISH='""'
-- Gives the player coins (and, with FISH, that fish in their tank), buys every tier, picks the land, puts them in the
-- water past the start strip, and logs the trip every 0.25 s until they ride a fish or 40 s pass. Returns the log.
local LAND = 5
local FISH = "" -- "" (the fling) or "Id|Size|Variant" (dropped onto that fish)
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local player = Players:GetPlayers()[1]
assert(player, "no player")
local test = ServerStorage:WaitForChild("SubTest", 10)
assert(test, "no SubTest (SubService not running?)")
local character = player.Character or player.CharacterAdded:Wait()
local root = character:WaitForChild("HumanoidRootPart") :: BasePart
local lines = {}
local function log(s: string)
	table.insert(lines, s)
end
-- back on the dock first (the sandbox starts the player in the water; a previous run leaves them riding)
test:Invoke("home", player.UserId)
task.wait(1)
local state = player:GetAttribute("State")
log("start state " .. tostring(state))
local fishList = nil
if FISH ~= "" then
	local id, size, variant = string.match(FISH, "^([^|]*)|([^|]*)|(.*)$")
	fishList = { { id, size, variant } }
end
log("give " .. tostring(test:Invoke("give", player.UserId, 1e12, fishList)))
for _ = 1, 9 do
	test:Invoke("buy", player.UserId)
end
log("pick " .. tostring(test:Invoke("pick", player.UserId, LAND, FISH)))
task.wait(0.3)
local strip = workspace.ClaudeBlockout.Dock.StartStrip :: BasePart
local into = strip.Position + Vector3.new(0, 0, 30)
character:PivotTo(CFrame.lookAt(Vector3.new(into.X, -9, into.Z), Vector3.new(into.X, -9, into.Z + 10)))
local began = os.clock()
local lastPhase = nil
local sawRide = false
while os.clock() - began < 40 do
	local st = player:GetAttribute("State")
	local ph = player:GetAttribute("SubPhase")
	local p = root.Position
	if ph ~= lastPhase then
		lastPhase = ph
		log(string.format("%.2f phase %s", os.clock() - began, tostring(ph)))
	end
	table.insert(lines, string.format("%.2f %s %s pos %.0f %.0f %.0f v %.0f", os.clock() - began, tostring(st), tostring(ph), p.X, p.Y, p.Z, root.AssemblyLinearVelocity.Magnitude))
	if st == "Riding" then
		sawRide = true
		task.wait(1.5)
		local f = nil
		for _, m in workspace.Fish:GetChildren() do
			if m:GetAttribute("Rider") == player.UserId then
				f = m
			end
		end
		log(string.format("RIDING %s (%s %s) state %s oxygen %s", f and f:GetAttribute("FishType") or "?", f and tostring(f:GetAttribute("SizeTier")) or "", f and tostring(f:GetAttribute("Variant")) or "", tostring(player:GetAttribute("State")), tostring(player:GetAttribute("Oxygen"))))
		break
	end
	task.wait(0.25)
end
log("rode " .. tostring(sawRide) .. " final " .. tostring(player:GetAttribute("State")) .. " land " .. tostring(LAND))
for _, entry in game:GetService("LogService"):GetLogHistory() do
	if string.find(entry.message, "Sub", 1, true) or entry.messageType == Enum.MessageType.MessageError then
		log("LOG " .. entry.message)
	end
end
return table.concat(lines, "\n")
