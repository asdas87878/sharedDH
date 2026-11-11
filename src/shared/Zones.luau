--!strict
-- The dive's zones as the code sees them: a frame on the lane's floor at each zone's middle (+Z down the lane, +Y up off
-- the floor), its length and width, and the real-ocean depth the gauge shows.
-- The server reads them from the map (any instance with a "DiveZones" attribute, else Workspace.ClaudeBlockout.Dive or
-- Workspace.Map.Dive: one child per zone, "01_SHALLOWS" and so on, each holding a BasePart named "Floor"; a zone may set
-- "ZoneName" and "Metres" attributes) and falls back to blockout v2's numbers (art/blockout/v2_zones.json). It publishes
-- them to clients as JSON (Net.Folder's "Zones" attribute).
local HttpService = game:GetService("HttpService")

export type Zone = {
	Index: number,
	Name: string,
	Metres: number, -- the depth the gauge shows where the zone begins
	NextMetres: number, -- and where it ends
	Frame: CFrame,
	Length: number,
	Width: number,
}

local Zones = {}

Zones.BottomMetres = 10935 -- the Challenger Deep, at the end of the last zone

-- Blockout v2 (art/blockout/v2_zones.json), lane widths from tools/studio/claude_blockout.luau
local ORIGIN = Vector3.new(3000, 0, 0)
-- stylua: ignore
local FALLBACK: { { any } } = {
	{ "SHALLOWS", 0, -30, 260, -56.19, 1260, 260 },
	{ "CORAL REEF", 10, -76.19, 1260, -163.49, 3760, 220 },
	{ "KELP FOREST", 40, -203.49, 3760, -290.79, 6260, 240 },
	{ "SHIPWRECKS", 80, -330.79, 6260, -418.09, 8760, 260 },
	{ "OPEN BLUE", 150, -568.09, 8760, -655.39, 11260, 400 },
	{ "TWILIGHT", 200, -735.39, 11260, -822.70, 13760, 200 },
	{ "MIDNIGHT", 1000, -902.70, 13760, -990.00, 16260, 240 },
	{ "VENTS", 2000, -1070.00, 16260, -1157.30, 18760, 220 },
	{ "BONE GRAVEYARD", 4000, -1237.30, 18760, -1324.60, 21260, 320 },
	{ "THE UNDERWORLD", 6000, -1524.60, 21260, -1611.90, 23760, 140 },
}

local function fallbackMetres(name: string, index: number): number
	for _, row in FALLBACK do
		if row[1] == name then
			return row[2]
		end
	end
	local row = FALLBACK[math.min(index, #FALLBACK)]
	return row[2]
end

local function link(list: { Zone }): { Zone }
	for i, zone in list do
		zone.Index = i
		local nextZone = list[i + 1]
		zone.NextMetres = if nextZone then nextZone.Metres else Zones.BottomMetres
	end
	return list
end

function Zones.fallback(): { Zone }
	local list: { Zone } = {}
	for _, row in FALLBACK do
		local a = ORIGIN + Vector3.new(0, row[3], row[4])
		local b = ORIGIN + Vector3.new(0, row[5], row[6])
		local mid = (a + b) / 2
		-- lookAt points -Z at its target, so look back up the lane to get +Z down it
		table.insert(list, {
			Index = 0,
			Name = row[1],
			Metres = row[2],
			NextMetres = 0,
			Frame = CFrame.lookAt(mid, mid - (b - a).Unit),
			Length = (b - a).Magnitude,
			Width = row[7],
		})
	end
	return link(list)
end

local function findDive(): Instance?
	for _, d in workspace:GetDescendants() do
		if d:GetAttribute("DiveZones") then
			return d
		end
	end
	for _, path in { { "ClaudeBlockout", "Dive" }, { "Map", "Dive" } } do
		local at: Instance? = workspace
		for _, name in path do
			at = if at then at:FindFirstChild(name) else nil
		end
		if at then
			return at
		end
	end
	return nil
end

-- Server only: the zones from the map, else the fallback
function Zones.discover(): { Zone }
	local dive = findDive()
	if not dive then
		warn("[Zones] no dive markers in Workspace, using blockout v2's numbers")
		return Zones.fallback()
	end
	local children = dive:GetChildren()
	table.sort(children, function(a, b)
		return a.Name < b.Name
	end)
	local list: { Zone } = {}
	for _, child in children do
		local floor = child:FindFirstChild("Floor")
		if floor and floor:IsA("BasePart") then
			local name = child:GetAttribute("ZoneName")
			local zoneName = if type(name) == "string" then name else (string.gsub(child.Name, "^%d+_", ""))
			local metres = child:GetAttribute("Metres")
			table.insert(list, {
				Index = 0,
				Name = zoneName,
				Metres = if type(metres) == "number" then metres else fallbackMetres(zoneName, #list + 1),
				NextMetres = 0,
				Frame = floor.CFrame * CFrame.new(0, floor.Size.Y / 2, 0),
				Length = floor.Size.Z,
				Width = floor.Size.X,
			})
		end
	end
	if #list == 0 then
		warn("[Zones] " .. dive:GetFullName() .. " has no zone floors, using blockout v2's numbers")
		return Zones.fallback()
	end
	-- make sure every frame's +Z points on down the lane
	if #list >= 2 and (list[2].Frame.Position - list[1].Frame.Position):Dot(list[1].Frame.ZVector) < 0 then
		for _, zone in list do
			zone.Frame *= CFrame.Angles(0, math.pi, 0)
		end
	end
	return link(list)
end

-- Server only: the lane's exact centreline as JSON, if the map's dive folder carries one (v3's "Path", or "LanePath")
function Zones.pathJson(): string?
	local dive = findDive()
	if not dive then
		return nil
	end
	for _, name in { "Path", "LanePath" } do
		local json = dive:GetAttribute(name)
		if type(json) == "string" then
			return json
		end
	end
	return nil
end

-- Server only: the big solid things standing in the lane (the map's "BigAssets" attribute on the dive folder: JSON rows
-- of world x, z and radius), for the herd to steer round. Empty with none.
function Zones.bigAssets(): { { number } }
	local dive = findDive()
	local json = dive and dive:GetAttribute("BigAssets")
	if type(json) ~= "string" then
		return {}
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(json)
	end)
	local out = {}
	if ok and type(data) == "table" then
		for _, row in data do
			if
				type(row) == "table"
				and type(row[1]) == "number"
				and type(row[2]) == "number"
				and type(row[3]) == "number"
			then
				table.insert(out, row)
			end
		end
	end
	return out
end

function Zones.encode(list: { Zone }): string
	local out = {}
	for _, zone in list do
		table.insert(out, {
			N = zone.Name,
			M = zone.Metres,
			L = zone.Length,
			W = zone.Width,
			C = { zone.Frame:GetComponents() },
		})
	end
	return HttpService:JSONEncode(out)
end

function Zones.decode(json: string): { Zone }
	local ok, data = pcall(function()
		return HttpService:JSONDecode(json)
	end)
	if not ok or type(data) ~= "table" then
		return Zones.fallback()
	end
	local list: { Zone } = {}
	for _, row in data do
		table.insert(list, {
			Index = 0,
			Name = row.N,
			Metres = row.M,
			NextMetres = 0,
			Frame = CFrame.new(table.unpack(row.C)),
			Length = row.L,
			Width = row.W,
		})
	end
	return link(list)
end

-- A point in a zone: x across the lane, h above its floor, s along it from the middle
function Zones.point(zone: Zone, x: number, h: number, s: number): Vector3
	return (zone.Frame * CFrame.new(x, 0, s)).Position + Vector3.new(0, h, 0)
end

-- The zone a point is in (nil before the first one, at the dock), how far along it (0 to 1), and the gauge's depth
function Zones.locate(list: { Zone }, position: Vector3): (Zone?, number, number)
	local best: Zone? = nil
	local bestU = 0
	local bestHeight = math.huge
	for _, zone in list do
		local p = zone.Frame:PointToObjectSpace(position)
		if math.abs(p.Z) <= zone.Length / 2 and math.abs(p.Y) < bestHeight then
			best = zone
			bestU = (p.Z + zone.Length / 2) / zone.Length
			bestHeight = math.abs(p.Y)
		end
	end
	if not best and #list > 0 then
		local last = list[#list]
		local p = last.Frame:PointToObjectSpace(position)
		if p.Z > last.Length / 2 then
			return last, 1, last.NextMetres
		end
		-- between two lands (on a waving lane their boxes don't meet end to end): the nearer one. Before the first
		-- land (the dock, the lagoon) there is still none.
		local first = list[1]
		if first.Frame:PointToObjectSpace(position).Z >= -first.Length / 2 then
			local gap = math.huge
			for _, zone in list do
				local along = zone.Frame:PointToObjectSpace(position).Z
				local over = math.abs(along) - zone.Length / 2
				if over < gap then
					gap = over
					best = zone
					bestU = if along < 0 then 0 else 1
				end
			end
		end
	end
	if not best then
		return nil, 0, 0
	end
	return best, bestU, best.Metres + (best.NextMetres - best.Metres) * bestU
end

return Zones
