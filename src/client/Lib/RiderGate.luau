--!strict
-- The lip's gate and a tall ride fish (2026-11-24, seen in Studio): on land the rider stands as high as the saddle, so
-- on the biggest fish their body met the gate's beam (54 to 69 studs over the floor; a Colossal Blue Whale's rider is at
-- 60): they were stopped by it and never reached the lip, or were lifted on top of it. The fish itself touches nothing.
-- So a rider that high goes through the gate, on their own machine only (it owns their body). While a dive is planned
-- and flown the gate is solid again: its rays and boxes count the gate as they always have.
-- `Config.Equip.GateFrom`: from how high a saddle (the humanoid's HipHeight, studs); 0: the gate stops a rider, as before.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local RiderGate = {}

local open = false
local beams: { BasePart } = {}

-- Whether this humanoid is high enough to meet the gate's beam (only a land fish's saddle ever is)
function RiderGate.tall(humanoid: Humanoid): boolean
	local from = Config.Equip.GateFrom
	return from > 0 and humanoid.HipHeight >= from
end

-- Let a rider through the gate (true), or make it solid again (false). Cheap to ask every frame. `root`: the rider's
function RiderGate.through(on: boolean, root: BasePart?)
	if on == open then
		return
	end
	open = on
	if on then
		-- (mounted under the beam: its top was the floor for a moment, and the humanoid threw itself up off it)
		if root and root.AssemblyLinearVelocity.Y > 0 then
			root.AssemblyLinearVelocity *= Vector3.new(1, 0, 1)
		end
		local map = workspace:FindFirstChild("ClaudeBlockout")
		local dock = map and map:FindFirstChild("Dock")
		local gate = dock and dock:FindFirstChild("Gate")
		for _, part in if gate then gate:GetDescendants() else {} do
			if part:IsA("BasePart") and part.CanCollide then
				part.CanCollide = false
				table.insert(beams, part)
			end
		end
	else
		for _, part in beams do
			part.CanCollide = true
		end
		table.clear(beams)
	end
end

return RiderGate
