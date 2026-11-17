-- Measures how bunched the herd is round a rider (2026-11-17, the user: "needs less bunching to make it more
-- difficult to get from animal to animal"). Run in Play on the Server through the Studio connector's execute_luau
-- (paste the file): it drops the player in at the gate, lets the dive seat them, then reads the herd twice a second
-- for 20 seconds of riding and returns one block of text.
--   targets ahead: free fish ahead of the rider within 60, 100 and 150 studs (a hop's reach is 60 to 150)
--   the nearest free fish ahead
--   clumps: among the free fish within 300 studs, how far each is from its nearest neighbour, and how many pairs are
--   within 30 studs of each other
local Players = game:GetService("Players")
local t0 = os.clock()
while #Players:GetPlayers() == 0 and os.clock() - t0 < 15 do
	task.wait(0.2)
end
local player = Players:GetPlayers()[1]
local char = player.Character or player.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart", 10)
task.wait(7)
local folder = workspace.Fish
char:PivotTo(CFrame.lookAt(Vector3.new(3000, 3, 4), Vector3.new(3000, 3, 100)))
root.AssemblyLinearVelocity = Vector3.new(0, 0, 10)
local t1 = os.clock()
while player:GetAttribute("State") ~= "Riding" and os.clock() - t1 < 8 do
	task.wait(0.05)
end
local rodeAfter = os.clock() - t1
local uid = player.UserId
local looks, in60, in100, in150, nearSum, none100 = 0, 0, 0, 0, 0, 0
local nnSum, nnCount, pairs30, near300 = 0, 0, 0, 0
for _ = 1, 40 do
	task.wait(0.5)
	if player:GetAttribute("State") ~= "Riding" then
		break
	end
	looks += 1
	local here = root.Position
	local free = {}
	for _, m in folder:GetChildren() do
		local r = m:IsA("Model") and m.PrimaryPart
		if r and m:GetAttribute("Rider") == 0 then
			local d = (r.Position - here).Magnitude
			if d < 300 then
				table.insert(free, r.Position)
			end
		end
	end
	local nearest, a, b, c = 1e9, 0, 0, 0
	for _, at in free do
		if at.Z > here.Z then
			local d = (at - here).Magnitude
			nearest = math.min(nearest, d)
			if d <= 60 then
				a += 1
			end
			if d <= 100 then
				b += 1
			end
			if d <= 150 then
				c += 1
			end
		end
	end
	in60 += a
	in100 += b
	in150 += c
	if b == 0 then
		none100 += 1
	end
	if nearest < 1e9 then
		nearSum += nearest
	end
	near300 += #free
	for i, p in free do
		local best = 1e9
		for j, q in free do
			if i ~= j then
				local d = (p - q).Magnitude
				best = math.min(best, d)
				if j > i and d <= 30 then
					pairs30 += 1
				end
			end
		end
		if best < 1e9 then
			nnSum += best
			nnCount += 1
		end
	end
end
local n = math.max(looks, 1)
return string.format(
	"riding after %.2f s; %d looks, rider at z %.0f\nfree fish ahead: within 60 studs %.1f, within 100 %.1f, within 150 %.1f; none within 100 in %d%% of looks\nnearest free fish ahead: %.0f studs on average\nfree fish within 300 studs: %.1f; each one's nearest neighbour %.0f studs away on average; pairs within 30 studs of each other: %.1f",
	rodeAfter,
	looks,
	root.Position.Z,
	in60 / n,
	in100 / n,
	in150 / n,
	100 * none100 / n,
	nearSum / n,
	near300 / n,
	nnSum / math.max(nnCount, 1),
	pairs30 / n
)
