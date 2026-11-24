--!strict
-- The little submarine over the submarine stand (Hugo, 2026-11-23: "Add a little submarine over the submarine
-- stand"). Made on this machine only, from Shared/SubModels' own model (the place's meshes, or the placeholder of
-- plain parts where a PC has none), so nothing is added to the place and nothing is uploaded. It is made small, its
-- name sign and its lights taken off, and it floats between the stall's roof and the floating SUBMARINE name: a
-- gentle bob, a slow turn, the propeller turning. It touches nothing (no collision, no query, no touch, no shadow).
--   Which sub: the one this player has equipped, or the first one (tierShown).
--   Where: measured from the stand as it is in the place (Dock.Stations.Sub), never from the hub kit's numbers: over
--     the middle of the stall (its Title), CLEAR above its highest piece, and small enough to stay UNDER the name.
--   The stand is looked at once a second: the sub is made when the stand is there (it may stream in late, piece by
--     piece), moved when the stand's measure changes, made again when the stand is rebuilt, the equipped sub changes
--     or the place's meshes arrive, and taken away with the stand. Past FAR from the camera it is left still.
--   Off: SHOW false here, or Config.Sub.On 0 (no submarines in the game).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local SubModels = require(ReplicatedStorage.Shared.SubModels)

local SubStandController = {}

local SHOW = true -- false: no sub over the stand
local LONG = 8 -- studs across the circle it turns in, so about its length (the stall is about 10 wide)
local CLEAR = 2.5 -- studs between the stall's highest piece and the sub's lowest, at the bottom of its bob
local UNDER = 1 -- studs kept free under the floating name's lower edge
local LEAST = 0.5 -- squeezed under a low name it is never smaller than this share of LONG (then it meets the name)
local BOB = 0.35 -- studs up and down
local BOB_TIME = 3.2 -- seconds for one bob
local TURN_TIME = 18 -- seconds for one turn
local SPIN = 5 -- the propeller, radians a second
local FAR = 400 -- studs from the camera past which it is left still
local EVERY = 1 -- seconds between looks at the stand

type Shown = {
	Model: Model,
	Stand: Instance,
	Key: string, -- what it was made for: the tier, whether the place has its mesh, the room under the name
	Parts: { BasePart },
	Offsets: { CFrame }, -- each part against the sub's middle, at its small size
	Spins: { boolean }, -- the propeller's parts
	Low: number, -- from its middle down to its lowest point, studs
}

local shown: Shown? = nil
local spot: Vector3? = nil -- where its middle floats, at the middle of its bob
local turn = 0
local spin = 0

-- The sub to show: this player's equipped one, or the first (a fixed tier: return its number here)
local function tierShown(): number
	local equip = Players.LocalPlayer:GetAttribute("SubEquip")
	return if type(equip) == "number" and equip >= 1 then equip else 1
end

-- The stand (nil: not in the place, or not streamed in yet)
local function standOf(): Instance?
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local dock = blockout and blockout:FindFirstChild("Dock")
	local stations = dock and dock:FindFirstChild("Stations")
	return stations and stations:FindFirstChild("Sub")
end

-- Half of a part's box along the world's own axes
local function reach(cf: CFrame, size: Vector3): Vector3
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	return Vector3.new(
		math.abs(r.X) * size.X + math.abs(u.X) * size.Y + math.abs(l.X) * size.Z,
		math.abs(r.Y) * size.X + math.abs(u.Y) * size.Y + math.abs(l.Y) * size.Z,
		math.abs(r.Z) * size.X + math.abs(u.Z) * size.Y + math.abs(l.Z) * size.Z
	) / 2
end

-- The stand as it is now: the point over the stall's middle at the height of its highest piece that shows, and the
-- floating name's lower edge (nil: no name). Nil when none of the stall is there yet.
local function measure(stand: Instance): (Vector3?, number?)
	local lo: Vector3?, hi: Vector3? = nil, nil
	for _, d in stand:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Ring" and d.Name ~= "Title" and d.Transparency < 0.95 then
			local half = reach(d.CFrame, d.Size)
			lo = if lo then lo:Min(d.Position - half) else d.Position - half
			hi = if hi then hi:Max(d.Position + half) else d.Position + half
		end
	end
	if not lo or not hi then
		return nil, nil
	end
	local middle = (lo + hi) / 2
	local name = stand:FindFirstChild("Title", true)
	if not (name and name:IsA("BasePart")) then
		return Vector3.new(middle.X, hi.Y, middle.Z), nil
	end
	-- (the name is a BillboardGui sized in studs, standing on the unseen Title part: the hub kit's `title`)
	local board = name:FindFirstChildWhichIsA("BillboardGui")
	local edge = name.Position.Y
	if board then
		edge += board.StudsOffset.Y + board.StudsOffsetWorldSpace.Y - board.Size.Y.Scale / 2
	end
	return Vector3.new(name.Position.X, hi.Y, name.Position.Z), edge
end

-- Is the tier's own model in the place (Shared/SubModels takes it from there, else builds the placeholder)
local function hasMesh(tier: number): boolean
	local folder = ReplicatedStorage:FindFirstChild(SubModels.Templates)
	return folder ~= nil and folder:FindFirstChild(SubModels.style(tier).Id) ~= nil
end

local function drop()
	local s = shown
	shown = nil
	spot = nil
	if s then
		s.Model:Destroy()
	end
end

-- Put every part where the sub is now (its middle at `at`, turned `turn` about the upright, the propeller at `spin`)
local function place(s: Shown, at: Vector3)
	local frame = CFrame.new(at) * CFrame.Angles(0, turn, 0)
	local spun = CFrame.Angles(0, 0, spin) -- (a propeller's part spins about its own Z, as in SubController)
	for i, p in s.Parts do
		p.CFrame = if s.Spins[i] then frame * s.Offsets[i] * spun else frame * s.Offsets[i]
	end
end

-- The tier's model made small: as long as LONG, or smaller when `room` (the height free for it; nil: any) is less
local function build(stand: Instance, tier: number, room: number?, key: string): Shown
	local model, parts = SubModels.build(tier)
	model.Name = "StandSub"
	for _, d in model:GetDescendants() do
		-- no name over it, and no beam sweeping the hub as it turns
		if d:IsA("BillboardGui") or d:IsA("Light") then
			d:Destroy()
		end
	end
	-- its box as built (at the origin, facing -Z), and the circle it turns in about the box's middle
	local lo, hi = Vector3.one * math.huge, Vector3.one * -math.huge
	local halves: { Vector3 } = {}
	for i, p in parts do
		halves[i] = reach(p.CFrame, p.Size)
		lo = lo:Min(p.Position - halves[i])
		hi = hi:Max(p.Position + halves[i])
	end
	local middle = (lo + hi) / 2
	local round = 0.1
	for i, p in parts do
		local gap = p.Position - middle
		round = math.max(round, math.sqrt((math.abs(gap.X) + halves[i].X) ^ 2 + (math.abs(gap.Z) + halves[i].Z) ^ 2))
	end
	local tall = math.max(hi.Y - lo.Y, 0.1)
	local scale = LONG / (2 * round)
	if room then
		scale = math.min(scale, math.max(room / tall, scale * LEAST))
	end
	local offsets: { CFrame } = {}
	local spins: { boolean } = {}
	for i, p in parts do
		local rest = p.CFrame
		p.Size = p.Size * scale
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		offsets[i] = CFrame.new((rest.Position - middle) * scale) * rest.Rotation
		spins[i] = p.Name == "Prop" or p.Name == "Prop_Glow"
	end
	return {
		Model = model,
		Stand = stand,
		Key = key,
		Parts = parts,
		Offsets = offsets,
		Spins = spins,
		Low = tall * scale / 2,
	}
end

-- Once a second: is the stand there, is the sub over it still the right one, and where does it float
local function look()
	local stand = if SHOW and Config.Sub.On ~= 0 then standOf() else nil
	local roof: Vector3?, edge: number? = nil, nil
	if stand then
		roof, edge = measure(stand)
	end
	if not stand or not roof then
		drop()
		return
	end
	local room = if edge then edge - UNDER - roof.Y - CLEAR - 2 * BOB else nil
	local tier = tierShown()
	local key = `{tier}|{hasMesh(tier)}|{if room then math.round(room * 10) else -1}`
	local s = shown
	if s and s.Stand == stand and s.Key == key and s.Model.Parent ~= nil then
		spot = Vector3.new(roof.X, roof.Y + CLEAR + BOB + s.Low, roof.Z)
		return
	end
	drop()
	local made = build(stand, tier, room, key)
	local at = Vector3.new(roof.X, roof.Y + CLEAR + BOB + made.Low, roof.Z)
	place(made, at) -- (before it is in the world: never seen at the origin)
	made.Model.Parent = workspace.CurrentCamera
	shown = made
	spot = at
end

function SubStandController.Start()
	-- (the place's sub meshes are in ReplicatedStorage: made before they have arrived, it would be the placeholder)
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	local last = -math.huge
	-- (a sub equipped at the stand shows over it at once)
	Players.LocalPlayer:GetAttributeChangedSignal("SubEquip"):Connect(function()
		last = -math.huge
	end)
	RunService.RenderStepped:Connect(function(dt: number)
		local t = os.clock()
		if t - last >= EVERY then
			last = t
			look()
		end
		local s, at = shown, spot
		local camera = workspace.CurrentCamera
		if not s or not at or (camera and (camera.CFrame.Position - at).Magnitude > FAR) then
			return
		end
		turn = (turn + dt * 2 * math.pi / TURN_TIME) % (2 * math.pi)
		spin = (spin + dt * SPIN) % (2 * math.pi)
		place(s, at + Vector3.yAxis * (math.sin(t * 2 * math.pi / BOB_TIME) * BOB))
	end)
end

return SubStandController
