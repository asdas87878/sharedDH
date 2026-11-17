-- Server context (task u2): wait until at least NEED fish swim in front of the player within FAR studs, then freeze
-- the mock's scene (SizeMockFreeze). Gives up after WAIT seconds and freezes anyway.
local NEED = 4
local FAR = 100
local WAIT = 40
local RS = game:GetService("ReplicatedStorage")
local plr = game:GetService("Players"):GetPlayers()[1]
RS:SetAttribute("SizeMockFreeze", 0)
local t0 = os.clock()
local best = 0
while os.clock() - t0 < WAIT do
	task.wait(0.25)
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	local folder = workspace:FindFirstChild("Fish")
	if root and folder then
		local cam = root.CFrame
		local n = 0
		for _, m in folder:GetChildren() do
			local p = m:IsA("Model") and m.PrimaryPart
			if p then
				local rel = cam:PointToObjectSpace(p.Position)
				local d = rel.Magnitude
				if d > 18 and d < FAR and rel.Z < -10 and math.abs(rel.X) < -rel.Z * 1.1 then
					n += 1
				end
			end
		end
		best = math.max(best, n)
		if n >= NEED then
			break
		end
	end
end
RS:SetAttribute("SizeMockFreeze", math.floor(os.clock() * 10) % 100000 + 1)
return "froze, best " .. best .. " after " .. math.floor(os.clock() - t0) .. " s"
