--!strict
-- The lane's floor, read off the map as it is built. The map's Path attribute gives the centreline every 100 studs along
-- the design's curve, but the seabed is laid in straight slabs, so between samples, and at the foot of every drop-off,
-- the two differ: by up to 23 studs in blockout v4 (measured 2026-11-10). Fish are placed from the lane's floor and
-- don't collide, so they swam through the real one there; and the clients' "never below the lane's floor" rule sat
-- under the real floor instead of on it.
-- So the server walks the centreline every STEP studs, drops a ray onto the seabed at each point, and keeps the points
-- that matter (the ones a straight line between their neighbours would miss). The result is the lane everyone uses: the
-- server's, and the clients' through the LanePath attribute.
-- Which parts are the seabed: anything named "Seabed" or inside something named "Seabed". If the map has none, the first
-- solid thing under the centreline counts.
local HttpService = game:GetService("HttpService")

local LaneSurvey = {}

local STEP = 10 -- studs along the lane between rays (at 25 a drop-off's edge was still up to 15 studs out)
local ABOVE = 40 -- a ray starts this far above the Path's floor (lower under a roof)
local BELOW = 80 -- and looks this far below it
local KEEP = 0.5 -- a point this far (studs) off the line between its neighbours is kept

type Row = { number } -- s, x, y, z, w, c

local function isSeabed(part: Instance): boolean
	return part.Name == "Seabed" or part:FindFirstAncestor("Seabed") ~= nil
end

-- The built floor under a point of the Path, or nil when no ray finds one
local function floorAt(x: number, y: number, z: number, roof: number, params: RaycastParams, named: boolean): number?
	local top = if roof > 0 then math.clamp(roof - 2, 2, ABOVE) else ABOVE
	local from = Vector3.new(x, y + top, z)
	local reach = top + BELOW
	-- through anything that isn't seabed (a rock or a wreck lying on the centreline), a few times at most
	for _ = 1, 5 do
		local hit = workspace:Raycast(from, Vector3.new(0, -reach, 0), params)
		if not hit then
			return nil
		end
		if not named or isSeabed(hit.Instance) then
			return hit.Position.Y
		end
		reach -= (from.Y - hit.Position.Y) + 0.1
		from = hit.Position - Vector3.new(0, 0.1, 0)
		if reach <= 0 then
			return nil
		end
	end
	return nil
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- How far point p is from the straight line a to b, in the things the lane is read for: position and width
local function off(a: Row, b: Row, p: Row): number
	local span = b[1] - a[1]
	local t = if span > 0 then (p[1] - a[1]) / span else 0
	local d = Vector3.new(p[2] - lerp(a[2], b[2], t), p[3] - lerp(a[3], b[3], t), p[4] - lerp(a[4], b[4], t)).Magnitude
	return math.max(d, math.abs(p[5] - lerp(a[5], b[5], t)) * 0.5)
end

-- The Path as JSON, surveyed: nil in, or a Path that doesn't read, comes straight back
function LaneSurvey.run(pathJson: string?): string?
	if not pathJson then
		return nil
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(pathJson)
	end)
	if not ok or type(data) ~= "table" or #data < 2 then
		return pathJson
	end
	local params = RaycastParams.new()
	params.RespectCanCollide = true
	local named = workspace:FindFirstChild("Seabed", true) ~= nil

	-- every STEP studs along the centreline, with the floor from the map
	local dense: { Row } = {}
	local moved, missed = 0, 0
	for i = 1, #data - 1 do
		local a, b = data[i], data[i + 1]
		if type(a) ~= "table" or type(b) ~= "table" or type(a[5]) ~= "number" or type(b[5]) ~= "number" then
			return pathJson
		end
		local span = b[1] - a[1]
		local steps = math.max(1, math.ceil(span / STEP))
		for k = 0, if i == #data - 1 then steps else steps - 1 do
			local t = k / steps
			local ca, cb = a[6] or 0, b[6] or 0
			-- under a roof at either end: the lower of the two
			local roof = if ca > 0 and cb > 0 then math.min(ca, cb) else math.max(ca, cb)
			local x, y, z = lerp(a[2], b[2], t), lerp(a[3], b[3], t), lerp(a[4], b[4], t)
			local real = floorAt(x, y, z, roof, params, named)
			if real then
				if math.abs(real - y) > 3 then
					moved += 1
				end
				if roof > 0 then
					roof = math.max(roof - (real - y), 4)
				end
				y = real
			else
				missed += 1
			end
			table.insert(dense, { lerp(a[1], b[1], t), x, y, z, lerp(a[5], b[5], t), roof })
		end
	end

	-- keep the first and last, every point under a roof, and every point the line between its neighbours would miss
	local kept: { Row } = { dense[1] }
	local anchor = 1
	for i = 3, #dense do
		local split = false
		for j = anchor + 1, i - 1 do
			if dense[j][6] > 0 or off(dense[anchor], dense[i], dense[j]) > KEEP then
				split = true
				break
			end
		end
		if split then
			table.insert(kept, dense[i - 1])
			anchor = i - 1
		end
	end
	table.insert(kept, dense[#dense])

	for _, row in kept do
		for n = 1, 6 do
			row[n] = math.floor(row[n] * 10 + 0.5) / 10
		end
	end
	print(
		string.format(
			"[LaneSurvey] %d points of the map's Path surveyed every %d studs: %d kept; the floor was over 3 studs off at %d of %d, and not found at %d",
			#data,
			STEP,
			#kept,
			moved,
			#dense,
			missed
		)
	)
	return HttpService:JSONEncode(kept)
end

return LaneSurvey
