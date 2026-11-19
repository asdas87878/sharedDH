--!strict
-- The dive's zones as the code sees them: a frame on the lane's floor at each zone's middle (+Z down the lane, +Y up off
-- the floor), its length and width, and the depth where it starts.
-- The server reads them from the map (any instance with a "DiveZones" attribute, else Workspace.ClaudeBlockout.Dive or
-- Workspace.Map.Dive: one child per zone, "01_SHALLOWS" and so on, each holding a BasePart named "Floor"; a zone may set
-- "ZoneName") and falls back to grey-box 15's lands (tools/studio/greybox/00_start.luau). It publishes them to clients
-- as JSON (Net.Folder's "Zones" attribute).
-- The gauge (Hugo, 2026-11-19, "every stud is a meter"): metres are how far below the sea's surface you are, one a
-- stud (Config.Depth, Config.metresAt). A land's Metres is the depth of the lane's floor where it starts, worked out
-- from its marker; the map's old "Metres" attribute (real-ocean depths, 0 to 6,000 m) is no longer read.
local HttpService = game:GetService("HttpService")

local Config = require(script.Parent.Config)

export type Zone = {
	Index: number,
	Name: string,
	Metres: number, -- the depth of the lane's floor where the zone begins (metres = studs below the surface)
	NextMetres: number, -- and where it ends (the next zone's start; the last zone's own end)
	Frame: CFrame,
	Length: number,
	Width: number,
}

local Zones = {}

-- Grey-box 15 (tools/studio/greybox/00_start.luau): each land's name, the floor's start (x, y, z) and end, its width
-- stylua: ignore
local FALLBACK: { { any } } = {
	{ "SHALLOWS", 3000.0, -46.0, 0.0, 3009.5, -80.5, 984.0, 185.4 },
	{ "CORAL REEF", 3008.3, -81.5, 1008.0, 2746.4, -189.3, 3449.5, 279.1 },
	{ "KELP FOREST", 2754.4, -190.5, 3477.0, 2879.6, -321.6, 5896.4, 364.2 },
	{ "SHIPWRECKS", 2879.6, -321.6, 5896.4, 2537.2, -495.9, 8332.6, 378.3 },
	{ "OPEN BLUE", 2548.5, -497.6, 8357.4, 2283.3, -738.9, 10775.0, 448.3 },
	{ "TWILIGHT", 2290.0, -740.9, 10798.8, 2822.4, -957.3, 13204.0, 513.3 },
	{ "MIDNIGHT", 2821.2, -959.7, 13229.4, 3032.2, -1219.2, 15659.6, 559.8 },
	{ "VENTS", 3042.3, -1221.9, 15684.2, 3329.8, -1564.0, 18112.2, 595.7 },
	{ "BONE GRAVEYARD", 3313.4, -1566.9, 18135.9, 3166.9, -1873.7, 20619.8, 669.8 },
	{ "THE UNDERWORLD", 3166.9, -1873.7, 20619.8, 3000.8, -2223.9, 23073.6, 765.7 },
}

-- The depth of a zone's floor at its start (s = -1) or its end (s = 1)
local function floorMetres(zone: Zone, s: number): number
	return Config.metresAt((zone.Frame * CFrame.new(0, 0, s * zone.Length / 2)).Position.Y)
end

local function link(list: { Zone }): { Zone }
	for i, zone in list do
		zone.Index = i
		local nextZone = list[i + 1]
		zone.Metres = floorMetres(zone, -1)
		zone.NextMetres = if nextZone then floorMetres(nextZone, -1) else floorMetres(zone, 1)
	end
	return list
end

function Zones.fallback(): { Zone }
	local list: { Zone } = {}
	for _, row in FALLBACK do
		local a = Vector3.new(row[2], row[3], row[4])
		local b = Vector3.new(row[5], row[6], row[7])
		local mid = (a + b) / 2
		-- lookAt points -Z at its target, so look back up the lane to get +Z down it
		table.insert(list, {
			Index = 0,
			Name = row[1],
			Metres = 0,
			NextMetres = 0,
			Frame = CFrame.lookAt(mid, mid - (b - a).Unit),
			Length = (b - a).Magnitude,
			Width = row[8],
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
		warn("[Zones] no dive markers in Workspace, using grey-box 15's lands")
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
			table.insert(list, {
				Index = 0,
				Name = zoneName,
				Metres = 0,
				NextMetres = 0,
				Frame = floor.CFrame * CFrame.new(0, floor.Size.Y / 2, 0),
				Length = floor.Size.Z,
				Width = floor.Size.X,
			})
		end
	end
	if #list == 0 then
		warn("[Zones] " .. dive:GetFullName() .. " has no zone floors, using grey-box 15's lands")
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

-- The zone a point is in (nil before the first one, at the dock), how far along it (0 to 1), and the gauge's metres:
-- how far below the surface the point is, one a stud (0 at the dock)
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
			return last, 1, Config.metresAt(position.Y)
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
	return best, bestU, Config.metresAt(position.Y)
end

return Zones
