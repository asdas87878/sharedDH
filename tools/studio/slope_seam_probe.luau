--!strict
-- Looks for seams in the lane's floor: rays straight down every STEP studs along the lane's line through a stretch,
-- counting where a ray lands on a tile's side (a gap between tiles) or on a step between two tiles' tops.
-- usage: node ~/Projects/studio-runner/studio-run.mjs tools/studio/slope_seam_probe.luau S0=16000 S1=16900
-- (s along the lane, read from the Dive's Path attribute). Read only: changes nothing.
local S0 = 16000
local S1 = 16900
local STEP = 0.25
local ACROSS = 0 -- studs to the right of the lane's line

local HttpService = game:GetService("HttpService")
local root = workspace:FindFirstChild("ClaudeBlockout") :: Folder
local rows = HttpService:JSONDecode(root.Dive:GetAttribute("Path")) :: { any }
local seabed = root.Lane.Seabed
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { seabed }

local function at(s: number): (Vector3, Vector3)
	for i = 1, #rows - 1 do
		local a, b = rows[i], rows[i + 1]
		if s <= b[1] then
			local u = (s - a[1]) / (b[1] - a[1])
			local pa, pb = Vector3.new(a[2], a[3], a[4]), Vector3.new(b[2], b[3], b[4])
			local d = Vector3.new(pb.X - pa.X, 0, pb.Z - pa.Z).Unit
			return pa:Lerp(pb, u), d
		end
	end
	local r = rows[#rows]
	return Vector3.new(r[2], r[3], r[4]), Vector3.zAxis
end

local sides, steps, rays, worstStep, lastY, lastPart = 0, 0, 0, 0, nil :: number?, nil :: Instance?
local lastAt: Vector3? = nil
local firstSide: string? = nil
local bigStep: string? = nil
local s = S0
while s <= S1 do
	local c, d = at(s)
	local rt = Vector3.new(d.Z, 0, -d.X)
	local o = c + rt * ACROSS + Vector3.new(0, 300, 0)
	local hit = workspace:Raycast(o, Vector3.new(0, -800, 0), params)
	rays += 1
	if hit then
		if hit.Normal.Y < 0.8 then
			sides += 1
			if not firstSide then
				local b = hit.Instance :: BasePart
				firstSide = string.format("s=%.2f at (%.2f, %.2f, %.2f) normal %s; tile at %s size %s",
					s, hit.Position.X, hit.Position.Y, hit.Position.Z, tostring(hit.Normal), tostring(b.Position), tostring(b.Size))
			end
		elseif lastY and lastPart ~= hit.Instance then
			local flat = ((hit.Position - (lastAt :: Vector3)) * Vector3.new(1, 0, 1)).Magnitude
			-- the floor falls at most flat * tan(20 degrees) between two rays (the steepest tile is under 19);
			-- anything over that, plus a hair, is a step between two tiles' tops
			local dy = math.max(0, math.abs(hit.Position.Y - lastY) - flat * 0.364)
			if dy > 0.03 then
				steps += 1
				if dy > 1 and not bigStep then
					bigStep = string.format("s=%.2f from y %.2f to %.2f (%s)", s, lastY, hit.Position.Y, tostring(hit.Position))
				end
			end
			worstStep = math.max(worstStep, dy)
		end
		lastY, lastPart, lastAt = hit.Position.Y, hit.Instance, hit.Position
	end
	s += STEP
end
return string.format("s %d..%d across %d: %d rays, %d on a tile's side (gaps), %d steps at joints (worst %.3f over the slope); first side hit: %s; first big step: %s",
	S0, S1, ACROSS, rays, sides, steps, worstStep, firstSide or "none", bigStep or "none")
