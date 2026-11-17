-- Server context (task u2): find the densest knot of fish (the most others within 70 studs), aim the mock's camera at
-- it from behind along the lane (DIR) and freeze the scene there. BACK/UP: the camera's distance behind and above.
local DIR = { 0, 0, 1 }
local BACK = 60
local UP = 14
local NEAR = nil
local USE_PLAYER = true -- {x, y, z}: only fish within 600 studs of here
local RS = game:GetService("ReplicatedStorage")
local folder = workspace:FindFirstChild("Fish")
local fish = {}
for _, m in folder:GetChildren() do
	local p = m:IsA("Model") and m.PrimaryPart
	if p and (not NEAR or (p.Position - Vector3.new(NEAR[1], NEAR[2], NEAR[3])).Magnitude < 600) then
		table.insert(fish, p.Position)
	end
end
local best, bestN = nil, -1
for _, a in fish do
	local n = 0
	for _, b in fish do
		if (a - b).Magnitude < 70 then
			n += 1
		end
	end
	if n > bestN then
		best, bestN = a, n
	end
end
if not best then
	return "no fish"
end
local dir = Vector3.new(DIR[1], DIR[2], DIR[3]).Unit
-- seen from the player's side when DIR is not given (the herd is mostly ahead of the player)
local plr = game:GetService("Players"):GetPlayers()[1]
local root = plr and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
if USE_PLAYER and root then
	local flat = (best - root.Position) * Vector3.new(1, 0.25, 1)
	if flat.Magnitude > 1 then
		dir = flat.Unit
	end
end
local eye = best - dir * BACK + Vector3.new(0, UP, 0)
RS:SetAttribute("SizeMockCam", CFrame.lookAt(eye, best + dir * 25))
task.wait(0.8)
RS:SetAttribute("SizeMockFreeze", math.floor(os.clock() * 10) % 100000 + 1)
task.wait(0.3)
RS:SetAttribute("SizeMockCam", nil)
return "froze on a knot of " .. bestN .. " of " .. #fish
