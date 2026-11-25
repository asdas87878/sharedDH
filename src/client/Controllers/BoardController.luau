--!strict
-- The hub's leaderboards (Hugo, 2026-11-25; NULLROOM task l1; docs/design/leaderboards.md): builds the row of boards on
-- this machine only, as KeeperController builds the shopkeepers, so nothing is added to the place and nothing is
-- uploaded. What they look like is Shared/Boards, what is written on them UI/BoardPanel, who is on them the server's
-- LeaderboardService (remote Boards).
--   Where: Config.Boards (X, Z, Face, Pitch, Turn, Scale), measured from Dock.HubFloor as it is in the place. Looked at
--     once a second, and made again when any of it changes (the style too), so a number can be tuned while playing.
--   Solid: one unseen block for each board and the bed (players stop at them); everything else touches nothing.
--   Moving: the emblem bobs and looks about, its small bubbles rise; inside Boards.Animate only. Past Boards.Hide the
--     row is out of the world.
--   Cost: 75 to 145 plain parts a board by the style and emblem (a whole row: 282, 397, 338 for styles 1, 2, 3),
--     up to 30 of them moving; two small lights a board, no shadows.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Boards = require(ReplicatedStorage.Shared.Boards)
local Config = require(ReplicatedStorage.Shared.Config)
local Keepers = require(ReplicatedStorage.Shared.Keepers)
local Net = require(ReplicatedStorage.Shared.Net)
local BoardPanel = require(script.Parent.Parent.UI.BoardPanel)

local BoardController = {}

local FOLDER = "Boards" -- their folder in the workspace
local BACK = 0.95 -- a hidden row comes back inside this share of Boards.Hide
local EVERY = 1 -- seconds between looks

type Mover = { Part: BasePart, Offset: CFrame, Bubble: number }
type Shown = {
	Def: any,
	Foot: CFrame, -- the board's own space in the world
	Emblem: CFrame, -- the emblem's middle in the world, at rest
	Panel: BoardPanel.Panel,
	Parts: { BasePart }, -- the emblem's
	Offsets: { CFrame },
	CFrames: { CFrame },
	Bubbles: { Mover },
}

local folder: Folder? = nil
local model: Model? = nil
local shown: { Shown } = {}
local key = ""
local middle = Vector3.zero
local state: any = nil
local since = math.huge
local clock = 0

local function floorPart(): BasePart?
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local dock = blockout and blockout:FindFirstChild("Dock")
	local floor = dock and dock:FindFirstChild("HubFloor", true)
	return if floor and floor:IsA("BasePart") then floor else nil
end

local function style(): number
	local asked = if RunService:IsStudio() then workspace:GetAttribute("BoardStyle") else nil
	return Boards.style(asked or Config.Boards.Style)
end

local function listed(): { any }
	local out = {}
	for _, def in Config.Boards.List do
		if def.On ~= 0 then
			table.insert(out, def)
		end
	end
	return out
end

local function make(piece: Boards.Piece, at: CFrame, scale: number): BasePart
	local part = Instance.new("Part")
	part.Name = piece.Move or "Frame"
	part.Shape = if piece.Shape == "Ball"
		then Enum.PartType.Ball
		elseif piece.Shape == "Cylinder" then Enum.PartType.Cylinder
		else Enum.PartType.Block
	part.Size = piece.Size * scale
	part.Color = piece.Color
	part.Material = if piece.Glow then Enum.Material.Neon else Enum.Material.Plastic
	part.Transparency = piece.Clear or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.CFrame = at
	if piece.Light then
		local light = Instance.new("PointLight")
		light.Range = piece.Light * scale
		light.Brightness = 0.8
		light.Color = piece.Color
		light.Shadows = false
		light.Parent = part
	end
	return part
end

-- A piece's place in the world, its space and its size
local function place(space: CFrame, piece: CFrame, scale: number): CFrame
	return space * (piece.Rotation + piece.Position * scale)
end

local function solid(size: Vector3, at: CFrame, parent: Instance)
	local part = Instance.new("Part")
	part.Name = "Solid"
	part.Size = size
	part.CFrame = at
	part.Transparency = 1
	part.Anchored = true
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = parent
end

local function clear()
	for _, s in shown do
		s.Panel.Gui:Destroy()
	end
	table.clear(shown)
	if model then
		model:Destroy()
		model = nil
	end
	key = ""
end

-- What the server last said about a board
local function boardOf(id: string): any
	for _, board in if state then state.Boards else {} do
		if board.Id == id then
			return board
		end
	end
	return nil
end

local function own(def: any): number
	local value = Players.LocalPlayer:GetAttribute("Board" .. def.Id)
	return if type(value) == "number" then value else 0
end

local function fill(s: Shown)
	BoardPanel.show(s.Panel, boardOf(s.Def.Id), if state then state.Next else 0, own(s.Def))
end

local function build(row: CFrame, looks: number, defs: { any }): Model
	local c = Config.Boards
	local scale = c.Scale
	local made = Instance.new("Model")
	made.Name = "Row"
	for _, piece in Boards.bed(looks, (#defs - 1) * c.Pitch) do
		local part = make(piece, place(row, piece.At, scale), scale)
		part.CanCollide = piece.Size.Y >= Boards.Bed.Height or piece.Size.X >= Boards.Bed.Depth
		if piece.Shape == "Block" then
			-- the hub's studs on its top
			local texture = Instance.new("Texture")
			texture.Name = "Studs"
			texture.Texture = Keepers.Look.Stud
			texture.Face = Enum.NormalId.Top
			texture.StudsPerTileU, texture.StudsPerTileV = 16, 16
			texture.OffsetStudsU = 8
			texture.Parent = part
		end
		part.Parent = made
	end
	middle = (row * CFrame.new(0, 12 * scale, 0)).Position
	for i, at in Boards.places(#defs, c.Pitch * scale, c.Turn) do
		local def = defs[i]
		local foot = row * at
		local panel = Boards.Panel
		local glass = Instance.new("Part")
		glass.Name = "Glass" .. def.Id
		glass.Size = Vector3.new(panel.Width, panel.Height, 0.1) * scale
		glass.CFrame = foot * CFrame.new(0, (panel.Bottom + panel.Height / 2) * scale, (panel.Front - 0.05) * scale)
		glass.Color = Color3.fromRGB(16, 40, 66)
		glass.Material = Enum.Material.Plastic
		glass.Anchored = true
		glass.CanCollide = false
		glass.CanTouch = false
		glass.CanQuery = true -- (a finger on the list has to find it)
		glass.CastShadow = false
		glass.Parent = made
		local s: Shown = {
			Def = def,
			Foot = foot,
			Emblem = foot * CFrame.new(0, Boards.Emblem.Y * scale, 0),
			Panel = BoardPanel.make(def, glass),
			Parts = {},
			Offsets = {},
			CFrames = {},
			Bubbles = {},
		}
		for _, piece in Boards.board(looks, def.Emblem, i, i == #defs) do
			local where = place(foot, piece.At, scale)
			local part = make(piece, where, scale)
			if piece.Move == "Emblem" then
				table.insert(s.Parts, part)
				table.insert(s.Offsets, s.Emblem:ToObjectSpace(where))
				table.insert(s.CFrames, where)
			elseif piece.Move == "Bubble" then
				table.insert(s.Bubbles, { Part = part, Offset = where, Bubble = #s.Bubbles + 1 })
			end
			part.Parent = made
		end
		local b = Boards.Solid
		solid(Vector3.new(b.Width, b.Height, b.Depth) * scale, foot * CFrame.new(0, b.Height / 2 * scale, 0), made)
		table.insert(shown, s)
		fill(s)
	end
	made.Parent = folder
	return made
end

-- Looks at where the row stands and how it looks: makes it, makes it again, or takes it away
local function look()
	local c = Config.Boards
	local floor = if c.On ~= 0 then floorPart() else nil
	local defs = listed()
	if not floor or #defs == 0 then
		clear()
		return
	end
	local row = Boards.row(floor.CFrame, floor.Size, c.X, c.Z, c.Face)
	local looks = style()
	local names = {}
	for _, def in defs do
		table.insert(names, def.Id .. def.Title .. def.Line .. def.Emblem)
	end
	local now = `{row} {looks} {c.Pitch} {c.Turn} {c.Scale} {c.Rows} {table.concat(names, ",")}`
	if now ~= key then
		clear()
		key = now
		model = build(row, looks, defs)
	end
end

local function animate(s: Shown, index: number)
	local at = s.Emblem * Boards.emblemAt(index, clock)
	for i, offset in s.Offsets do
		s.CFrames[i] = at * offset
	end
	workspace:BulkMoveTo(s.Parts, s.CFrames, Enum.BulkMoveMode.FireCFrameChanged)
	for _, bubble in s.Bubbles do
		local up, size = Boards.bubbleAt(bubble.Bubble + index * 0.3, clock)
		bubble.Part.CFrame = bubble.Offset + Vector3.new(0, up, 0)
		bubble.Part.Transparency = 1 - 0.65 * size
	end
end

local function step(dt: number)
	clock += math.min(dt, 0.1)
	since += dt
	local each = since >= EVERY
	if each then
		since = 0
		look()
	end
	local camera = workspace.CurrentCamera
	local row = model
	if not (camera and row) then
		return
	end
	local eye = camera.CFrame.Position
	local far = (eye - middle).Magnitude
	if row.Parent == nil then
		if far < Config.Boards.Hide * BACK then
			row.Parent = folder
		end
	elseif far > Config.Boards.Hide then
		row.Parent = nil
	end
	if each and row.Parent ~= nil then
		local character = Players.LocalPlayer.Character
		local root = character and character.PrimaryPart
		local now = workspace:GetServerTimeNow()
		for _, s in shown do
			local off = if root
				then Vector3.new(root.Position.X - s.Foot.X, 0, root.Position.Z - s.Foot.Z).Magnitude
				else math.huge
			BoardPanel.near(s.Panel, off <= Config.Boards.ScrollNear)
			BoardPanel.tick(s.Panel, now)
			BoardPanel.own(s.Panel, own(s.Def))
		end
	end
	if row.Parent ~= nil and far <= Config.Boards.Animate then
		for i, s in shown do
			animate(s, i)
		end
	end
end

-- Test hooks: only tools/boards/board_test.luau calls these
BoardController.Test = {
	step = step,
	shown = function(): { Shown }
		return shown
	end,
}

function BoardController.Start()
	if Config.Boards.On == 0 then
		return
	end
	folder = Instance.new("Folder");
	(folder :: Folder).Name = FOLDER;
	(folder :: Folder).Parent = workspace
	RunService.Heartbeat:Connect(step)
	local remote = Net.Folder:WaitForChild("Boards") :: RemoteEvent
	remote.OnClientEvent:Connect(function(what: any, sent: any)
		if what == "State" and type(sent) == "table" then
			state = sent
			for _, s in shown do
				fill(s)
			end
		end
	end)
	remote:FireServer("Sync")
end

return BoardController
