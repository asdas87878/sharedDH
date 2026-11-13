--!strict
-- Keeping what our own client moves in open water. The fish we ride and the jump's flight don't collide with the map
-- (fish are CanCollide false, and the flight is placed by CFrame), so nothing in the engine stops them going through the
-- sea floor, a bank or a rock. This does, with two rules that hold each other up:
--   1. Rays that start where we are now, which is open water. A ray that starts inside a part doesn't see that part, so a
--      floor check from a point already under the floor finds nothing: that was the "flown under the map" bug (the ridden
--      fish steered into a bank, 2026-11-10). So we look sideways before moving sideways, and only then down.
--   2. The lane itself, from the map's centreline (the same Lane the server builds): its floor is a floor even if every
--      ray misses, and its edge (plus Ride.LaneMargin) is as far out as we go. This also brings us back up if we ever do
--      end up under it.
-- Rays hit only what is solid (RespectCanCollide): not fish, light shafts, markers or the sheet of water at the surface.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Lane = require(ReplicatedStorage.Shared.Lane)
local Net = require(ReplicatedStorage.Shared.Net)
local Zones = require(ReplicatedStorage.Shared.Zones)
local State = require(script.Parent.State)

local Course = {}

local LOOK_AHEAD = 0.12 -- seconds of travel a velocity is checked over
local WALL = 0.5 -- a surface whose normal points up less than this is a wall; flatter, it is floor
local DOWN = 260 -- how far down the floor is looked for
local RISE = 3 -- from this far above the point
local PUSH = 6 -- how hard we are pushed back from the floor, a roof or the surface (studs a second for each stud)
local PUSH_MAX = 60
local STEP = 10 -- something in the way that ends within this far above us, with open water over it, is a step: climbed
local LEDGE = 12 -- and has this much open water on past its face, at that height
local STEP_SOFT = 4 -- and one that ends within this much of that is part wall to the wall ride's look-ahead
local EDGE = 6 -- past the lane's own edge our way out is taken over this many studs
local OPEN = 240 -- with no wall of the map's own within this far out past the lane's edge, the edge itself is the wall
local SLIVER = 3 -- this much of a boundary box's end showing at its corner is a joint between pieces, not a wall

local lane: Lane.Lane? = nil
local laneZones: { Zones.Zone }? = nil
local lastS: number? = nil

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true
local begun = false
local throughLast: boolean? = nil -- what Course.begin was last asked for (it is done again when a character appears)

-- the last survey: the lane's floor there (nil off the lane), how far outside the lane's edge (negative inside), and the
-- way out across it
local laneFloor: number? = nil
local outside = -math.huge
local outward = Vector3.xAxis
local alongHere = Vector3.zAxis -- the lane's own way there,
local slope = 0 -- and how fast its edge moves out (in, negative) going down it: studs across for each stud along
local floorHere: number? = nil -- and what the ray down found

local function getLane(): Lane.Lane?
	if lane and laneZones == State.Zones then
		return lane
	end
	if #State.Zones == 0 then
		return nil
	end
	local json = Net.Folder:GetAttribute("LanePath")
	lane = Lane.build(State.Zones, if type(json) == "string" and json ~= "" then json else nil)
	laneZones = State.Zones
	lastS = nil
	return lane
end

-- Call when we start moving something ourselves (a mount, a jump): the rays skip every character and the camera's own
-- effects. `throughProps`: they skip the map's props too (a ridden fish that breaks them swims through: Config.Props).
function Course.begin(throughProps: boolean?)
	throughLast = throughProps
	local list: { Instance } = { workspace.CurrentCamera }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local surface = blockout and blockout:FindFirstChild("Surface")
	if surface then
		table.insert(list, surface)
	end
	local laneFolder = blockout and blockout:FindFirstChild("Lane")
	local props = laneFolder and laneFolder:FindFirstChild("Props")
	if throughProps and props then
		table.insert(list, props)
	end
	params.FilterDescendantsInstances = list
	lastS = nil
	begun = true
end

-- Where a point is against the lane (kept for the calls below)
local function locate(at: Vector3)
	laneFloor = nil
	outside = -math.huge
	local l = getLane()
	if not l then
		return
	end
	local s, off = Lane.project(l, at, lastS)
	if lastS and off > 500 then
		s, off = Lane.project(l, at)
	end
	lastS = s
	local centre, along, width = Lane.at(l, s)
	if s <= 0 and (at - centre):Dot(along) < 0 then
		-- behind the lane's start: the lagoon, with no edge to keep to
		return
	end
	local right = along:Cross(Vector3.yAxis)
	local across = (at - centre):Dot(right)
	laneFloor = centre.Y
	outside = math.abs(across) - (width / 2 + Config.Ride.LaneMargin)
	outward = if across >= 0 then right else -right
	alongHere = along
	local _, _, widthOn = Lane.at(l, s + 12)
	slope = if s + 12 <= l.Length then (widthOn - width) / 24 else 0
end

-- Whether the map has a wall of its own out past the lane's edge from the point last surveyed (the lane's walls,
-- the terraces behind them, the cliffs, the unseen barrier: since grey-box 9 every edge has one). Where it has, that
-- wall is the edge, and the surveyed line is not one: the line is drawn from a width taken every 24 studs along a
-- middle, so it stands up to 40 studs inside the real walls in places (measured 2026-11-13: 26 past it with the wall
-- still 13 away), and where the lane bends it jumps. Held to it there, we rode an unseen wall in open water and
-- were thrown inward when it jumped. It still holds wherever the map has nothing to stop us.
local walledAt: Vector3? = nil
local walledHere = false
local function walled(from: Vector3): boolean
	if walledAt ~= from then
		walledAt = from
		local hit = workspace:Raycast(from, outward * OPEN, params)
		walledHere = hit ~= nil and hit.Normal.Y < WALL
	end
	return walledHere
end

-- (from a little above the point: we are held a clearance above the floor, so that is still open water, and a point
-- that has dipped under a thin crust still finds it. `rise`: from that far above instead, over a step)
local function rayFloor(x: number, y: number, z: number, rise: number?): number?
	local hit = workspace:Raycast(Vector3.new(x, y + (rise or RISE), z), Vector3.new(0, -DOWN, 0), params)
	return if hit then hit.Position.Y else nil
end

-- Whether what a flat ray met (`length` along `dir` from `from`) is only a step: open water over us and over it,
-- STEP higher, for LEDGE on past its face (room for a body to go up onto it; a narrow lip with a wall close behind
-- is that wall). The ground on top of a low wall, a terrace's edge, the next slab along a wall's top (grey-box 14
-- on: the lane's sides step up in terraces). A fish goes up over a step (the floor rule lifts it); it rides a wall.
-- The same question, asked the same way, by the look-ahead (Course.feel) and by the hard rule
-- (Course.clearVelocity): asked over different lengths, one called the hub floor's front a step and let the fish
-- up to it, and the other called it a wall and stopped it there (measured 2026-11-13).
local function isStep(from: Vector3, dir: Vector3, length: number): boolean
	local up = Vector3.new(0, STEP, 0)
	if workspace:Raycast(from, up, params) then
		return false
	end
	return workspace:Raycast(from + up, dir * (length + LEDGE), params) == nil
end

local function higher(a: number?, b: number?): number?
	if a and b then
		return math.max(a, b)
	end
	return a or b
end

-- The lane's own floor under a point (the server's survey of the built seabed), or nil off the lane. No rays: it is
-- right wherever the point is, in open water or not.
function Course.laneFloor(at: Vector3): number?
	locate(at)
	return laneFloor
end

-- The floor under a point in open water: the solid thing below it, and never lower than the lane's own floor
function Course.floor(at: Vector3): number?
	if not begun then
		Course.begin(throughLast)
	end
	locate(at)
	floorHere = rayFloor(at.X, at.Y, at.Z)
	return higher(floorHere, laneFloor)
end

-- The map's boundary is short boxes laid along a curve (Lane/Walls, Lane/Barrier, the ground on top in Lane/Ground;
-- each box's X is across the wall, its Z along it). Where two meet at a bend a ray can catch a sliver of one box's
-- END instead of its broad face: a wall square across our way that isn't there, which threw the wall ride into the
-- next box's face (a stall, measured 2026-11-12). So an end met within SLIVER of the box's corner on our side counts
-- as that box's broad face. More of an end than that is a real corner (the wall steps in), and keeps its own way
-- out, as does everything that isn't the boundary.
local function wallNormal(hit: RaycastResult, from: Vector3): Vector3?
	local n = Vector3.new(hit.Normal.X, 0, hit.Normal.Z)
	local part = hit.Instance
	if Config.Wall.On ~= 0 and part:IsA("BasePart") then
		local map = workspace:FindFirstChild("ClaudeBlockout")
		local laneFolder = map and map:FindFirstChild("Lane")
		local folder = part.Parent
		if
			laneFolder
			and folder
			and folder.Parent == laneFolder
			and (folder.Name == "Walls" or folder.Name == "Barrier" or folder.Name == "Ground")
			and math.abs(part.CFrame.LookVector:Dot(hit.Normal)) > 0.7
		then
			local broad = part.CFrame.RightVector
			local side = if broad:Dot(from - part.Position) < 0 then -1 else 1
			local depth = part.Size.X / 2 - side * part.CFrame:PointToObjectSpace(hit.Position).X
			if depth <= SLIVER then
				n = Vector3.new(broad.X, 0, broad.Z) * side
			end
		end
	end
	return if n.Magnitude > 0.01 then n.Unit else nil
end

-- How far above `from` a thing met by a flat ray ends, when it is a step (isStep): its top, found from above. For
-- the wall ride's look-ahead, which takes a step that is nearly too high to climb as nearly a wall (Course.feel).
local function stepRise(from: Vector3, dir: Vector3, hit: RaycastResult): number
	local over = Vector3.new(hit.Position.X + dir.X * 0.5, from.Y + STEP + 0.5, hit.Position.Z + dir.Z * 0.5)
	local top = workspace:Raycast(over, Vector3.new(0, -STEP - 1, 0), params)
	return if top then math.clamp(top.Position.Y - from.Y, 0, STEP) else STEP
end

-- Feeling for a wall ahead (the wall ride's look-ahead, Lib/WallRide): from `from` (in open water) the flat way `dir`
-- (unit), as far as `reach`. Back come the wall's own way out, back into the open water (flat, unit), how far
-- `from` is from the wall's face, measured square to it, and how much of a wall it is (1: a wall); or nil with no
-- wall that near.
-- `steps`: what is only a step (isStep) is no wall (the ridden fish goes up over it: Course.clearVelocity), and the
-- look goes on over it, from a step higher: the next terrace's wall behind a low one is seen before the climb, and
-- comes back as a second wall (the three values again), counted by as much as we would get over the step. A step within STEP_SOFT of too high to climb is part wall
-- already (its share comes back as the third value): the lane's terraces often end right at that height, and as we
-- rose and sank a little beside one it was a wall one frame and nothing the next (measured 2026-11-13: the way we
-- went thrown 20 to 30 degrees in a frame, 2,850 studs down).
function Course.feel(
	from: Vector3,
	dir: Vector3,
	reach: number,
	steps: boolean?
): (Vector3?, number, number, Vector3?, number, number)
	if not begun then
		Course.begin(throughLast)
	end
	local origin = from
	local low: Vector3?, lowFar: number, lowShare: number = nil, 0, 0
	local over = 1 -- how much of us gets over the steps looked over so far: what is behind them counts by that much
	for _ = 1, 3 do
		local hit = workspace:Raycast(origin, dir * reach, params)
		if not hit or hit.Normal.Y >= WALL then
			break
		end
		local n = wallNormal(hit, origin)
		if not n then
			break
		end
		local far = math.max((origin - hit.Position):Dot(n), 0)
		if steps and isStep(origin, dir, (hit.Position - origin).Magnitude) then
			local rise = stepRise(origin, dir, hit)
			local u = math.clamp((rise - (STEP - STEP_SOFT)) / STEP_SOFT, 0, 1)
			local share = u * u * (3 - 2 * u)
			if not low and share > 0.01 then
				low, lowFar, lowShare = n, far, share * over
			end
			over *= 1 - share
			if over < 0.01 then
				break
			end
			origin += Vector3.new(0, STEP, 0)
		elseif low then
			return low, lowFar, lowShare, n, far, over
		else
			return n, far, over, nil, 0, 0
		end
	end
	return low, lowFar, lowShare, nil, 0, 0
end

-- The lane's own edge as a wall, for the same look-ahead: its way back in, and how far inside it `from` is (negative
-- beyond it); nil off the lane (the lagoon behind its start) and where the map has its own wall out there (`walled`:
-- that wall is felt for like any other). Where the lane narrows or widens the edge is not
-- along the lane: its way back in leans up or down the lane by as much (so a neck's edge is seen coming, as a
-- wall's is, and not met side on).
function Course.edge(from: Vector3): (Vector3?, number)
	locate(from)
	if not begun then
		Course.begin(throughLast)
	end
	if laneFloor and outside > -OPEN and not walled(from) then
		local normal = (-outward + alongHere * slope).Unit
		return normal, -outside / math.sqrt(1 + slope * slope)
	end
	return nil, 0
end

-- A velocity for something at `from` (in open water) that keeps it there: what would take it into a wall, the floor, a
-- roof, the air above the surface or out past the lane's edge is taken out, and it is pushed back from the floor and the
-- surface. `clearance` is how near the floor it may come, `reach` how far ahead of `from` its body goes.
-- Call Course.floor(from) first in the same frame: this uses what it found.
function Course.clearVelocity(from: Vector3, velocity: Vector3, clearance: number, reach: number): Vector3
	local v = velocity
	local flat = Vector3.new(v.X, 0, v.Z)
	local run = flat.Magnitude
	local ahead = from
	local aheadRise: number? = nil
	local climb = 0
	if run > 0.1 then
		local dir = flat / run
		local length = run * LOOK_AHEAD + reach
		local hit = workspace:Raycast(from, dir * length, params)
		if hit and hit.Normal.Y < WALL and isStep(from, dir, hit.Distance) then
			-- a step: its top is the floor a moment ahead, and the floor rule below takes us up over it
			ahead = hit.Position + dir
			aheadRise = STEP
		elseif hit and hit.Normal.Y < WALL then
			-- a wall: slide along it
			local n = wallNormal(hit, from)
			if n then
				local into = v:Dot(n)
				if into < 0 then
					v -= n * into
				end
			end
		elseif hit then
			-- a floor that rises to our height just ahead (a ramp): climb with it
			climb = run * math.sqrt(math.max(0, 1 - hit.Normal.Y ^ 2)) / hit.Normal.Y
		else
			ahead = from + dir * (run * LOOK_AHEAD)
		end
	end
	-- the lane's edge, where the map has no wall of its own beyond it (`walled`): no further out, and eased back in
	-- from beyond it. (Our way out is taken over the first EDGE
	-- studs past it, not all at the line: where the lane bends, the nearest point of its middle can jump along it
	-- and put us some studs outside in one frame, with the real wall still well off; taken at once, that threw the
	-- way we go round by up to 12 degrees in a frame, measured 2026-11-13. The map's own walls and its barrier are
	-- the hard edge; the wall ride (Lib/WallRide, Course.edge) rides this line before it is ever crossed.)
	if outside > 0 and not walled(from) then
		v -= outward * (math.max(v:Dot(outward), 0) * math.min(outside / EDGE, 1) + math.min(outside * 2, 30))
	end
	-- the floor, here and a moment ahead (so a rising floor is met before we are in it)
	local floor = higher(
		higher(floorHere, if ahead ~= from then rayFloor(ahead.X, from.Y, ahead.Z, aheadRise) else nil),
		laneFloor
	)
	if floor then
		-- never sinking faster than brings us to the clearance line (so we slow on the way down, however fast we came
		-- or long the frame), and pushed back up from under it
		local room = from.Y - (floor + clearance)
		v = Vector3.new(v.X, math.max(v.Y, math.min(-room * PUSH, PUSH_MAX)), v.Z)
	end
	if climb > 0 and climb > v.Y then
		v = Vector3.new(v.X, math.min(climb, PUSH_MAX), v.Z)
	end
	-- the surface, and any roof just over us
	local top = Config.Oxygen.SurfaceY - Config.Ride.Ceiling
	if v.Y > 0 then
		local roof = workspace:Raycast(from, Vector3.new(0, clearance + v.Y * LOOK_AHEAD + 2, 0), params)
		if roof then
			v = Vector3.new(v.X, 0, v.Z)
		end
	end
	if from.Y > top then
		v = Vector3.new(v.X, math.min(v.Y, math.max((top - from.Y) * PUSH, -PUSH_MAX)), v.Z)
	end
	return v
end

-- A step from `from` (in open water) toward `to` that stays in open water: stopped by a wall (sliding along it), kept
-- `clearance` above the floor under where it ends, under any roof, and inside the lane's edge. For what we place
-- ourselves each frame (the flight).
function Course.clearMove(from: Vector3, to: Vector3, clearance: number): Vector3
	if not begun then
		Course.begin(throughLast)
	end
	local step = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	for _ = 1, 2 do
		local length = step.Magnitude
		if length < 0.001 then
			break
		end
		local hit = workspace:Raycast(from, step / length * (length + 2), params)
		if not hit or hit.Normal.Y >= WALL then
			break
		end
		local n = wallNormal(hit, from)
		if not n then
			step = Vector3.zero
			break
		end
		step -= n * math.min(0, step:Dot(n))
	end
	-- the second try may still run into a corner: then we don't move across at all
	if step.Magnitude >= 0.001 then
		local blocked = workspace:Raycast(from, step.Unit * (step.Magnitude + 2), params)
		if blocked and blocked.Normal.Y < WALL then
			local normal = wallNormal(blocked, from)
			if not normal or step:Dot(normal) < -0.01 then
				step = Vector3.zero
			end
		end
	end
	local x, z = from.X + step.X, from.Z + step.Z
	local ended = Vector3.new(x, from.Y, z)
	locate(ended)
	if outside > 0 and not walled(ended) then
		-- past the lane's edge: no further out
		local out = step:Dot(outward)
		if out > 0 then
			step -= outward * out
			x, z = from.X + step.X, from.Z + step.Z
		end
	end
	local y = to.Y
	if y > from.Y then
		local roof = workspace:Raycast(from, Vector3.new(0, y - from.Y + 2, 0), params)
		if roof then
			y = math.max(from.Y, roof.Position.Y - 2)
		end
	end
	-- the column we end in is open at the height we came from, so a ray down from there can't start inside anything
	local floor = higher(rayFloor(x, from.Y, z), laneFloor)
	if floor then
		y = math.max(y, floor + clearance)
	end
	return Vector3.new(x, y, z)
end

-- A character that appears after the rays' list was made (a player who joined, or anyone's respawn) is solid to them
-- until the list is made again: so it is, the next time a floor or a move is asked for.
local function stale()
	begun = false
end
local function watch(player: Player)
	player.CharacterAdded:Connect(stale)
end
for _, player in Players:GetPlayers() do
	watch(player)
end
Players.PlayerAdded:Connect(watch)

return Course
