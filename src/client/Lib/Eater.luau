--!strict
-- The big fish that eats you on a miss: a placeholder shark, our own chunky blocks (dark, a pale belly, glowing eyes,
-- a hinged jaw with teeth, a tail that beats), built locally on each client under the camera, so nothing replicates
-- and nothing is uploaded. Its frame faces -Z (the nose) with +Y up; the mouth sits about 0.3 of its length ahead of
-- the centre. Pose it each frame with :Set.
local Eater = {}

export type Eater = {
	Model: Model,
	Length: number,
	Mouth: number, -- how far ahead of the centre the mouth is
	Set: (self: Eater, frame: CFrame, jaw: number, tailPhase: number) -> (),
	Fade: (self: Eater, transparency: number) -> (),
	Destroy: (self: Eater) -> (),
}

type Piece = { Part: BasePart, Base: CFrame, Group: string }

local DARK = Color3.fromRGB(38, 48, 62)
local BELLY = Color3.fromRGB(96, 108, 118)
local MOUTH = Color3.fromRGB(110, 18, 28)
local TOOTH = Color3.fromRGB(245, 242, 230)
local EYE = Color3.fromRGB(255, 210, 70)

function Eater.new(length: number): Eater
	local L = length
	local model = Instance.new("Model")
	model.Name = "Eater"
	local pieces: { Piece } = {}

	local function piece(
		group: string,
		size: Vector3,
		at: CFrame,
		colour: Color3,
		wedge: boolean?,
		material: Enum.Material?
	): BasePart
		local p: BasePart = if wedge then Instance.new("WedgePart") else Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = material or Enum.Material.SmoothPlastic
		p.Color = colour
		p.Size = size
		p.Parent = model
		table.insert(pieces, { Part = p, Base = at, Group = group })
		return p
	end

	-- the body: a deep torso, a pale belly, the snout narrowing ahead
	piece("Body", Vector3.new(0.22 * L, 0.24 * L, 0.5 * L), CFrame.new(0, 0, 0), DARK)
	piece("Body", Vector3.new(0.2 * L, 0.06 * L, 0.46 * L), CFrame.new(0, -0.11 * L, 0), BELLY)
	piece("Body", Vector3.new(0.2 * L, 0.13 * L, 0.24 * L), CFrame.new(0, 0.045 * L, -0.36 * L), DARK)
	piece(
		"Body",
		Vector3.new(0.2 * L, 0.06 * L, 0.1 * L),
		CFrame.new(0, 0.08 * L, -0.53 * L) * CFrame.Angles(0, math.pi, 0),
		DARK,
		true
	)
	piece("Body", Vector3.new(0.16 * L, 0.025 * L, 0.2 * L), CFrame.new(0, -0.03 * L, -0.38 * L), TOOTH)
	-- eyes, glowing a little in the dark
	for _, side in { -1, 1 } do
		piece(
			"Body",
			Vector3.new(0.02 * L, 0.035 * L, 0.035 * L),
			CFrame.new(side * 0.1 * L, 0.06 * L, -0.4 * L),
			EYE,
			false,
			Enum.Material.Neon
		)
	end
	-- the inside of the mouth, seen when the jaw drops
	piece("Inside", Vector3.new(0.15 * L, 0.1 * L, 0.18 * L), CFrame.new(0, -0.06 * L, -0.36 * L), MOUTH)
	-- the jaw, hinged at the back of the mouth
	piece("Jaw", Vector3.new(0.18 * L, 0.06 * L, 0.24 * L), CFrame.new(0, -0.08 * L, -0.36 * L), BELLY)
	piece("Jaw", Vector3.new(0.15 * L, 0.025 * L, 0.2 * L), CFrame.new(0, -0.045 * L, -0.37 * L), TOOTH)
	-- fins
	piece(
		"Body",
		Vector3.new(0.03 * L, 0.2 * L, 0.18 * L),
		CFrame.new(0, 0.21 * L, 0.02 * L) * CFrame.Angles(0, math.pi, 0),
		DARK,
		true
	)
	for _, side in { -1, 1 } do
		piece(
			"Body",
			Vector3.new(0.2 * L, 0.02 * L, 0.12 * L),
			CFrame.new(side * 0.18 * L, -0.08 * L, -0.12 * L) * CFrame.Angles(0, side * 0.35, side * -0.4),
			DARK
		)
	end
	-- the tail on its own hinge
	piece("Tail", Vector3.new(0.1 * L, 0.12 * L, 0.26 * L), CFrame.new(0, 0.01 * L, 0.36 * L), DARK)
	piece(
		"Tail",
		Vector3.new(0.03 * L, 0.3 * L, 0.12 * L),
		CFrame.new(0, 0.08 * L, 0.53 * L) * CFrame.Angles(-0.5, 0, 0),
		DARK
	)
	piece(
		"Tail",
		Vector3.new(0.03 * L, 0.18 * L, 0.1 * L),
		CFrame.new(0, -0.07 * L, 0.52 * L) * CFrame.Angles(0.6, 0, 0),
		DARK
	)

	model.Parent = workspace.CurrentCamera

	local jawHinge = CFrame.new(0, -0.05 * L, -0.24 * L)
	local tailHinge = CFrame.new(0, 0, 0.24 * L)
	local self = {
		Model = model,
		Length = L,
		Mouth = 0.4 * L,
	} :: Eater

	function self.Set(_self: Eater, frame: CFrame, jaw: number, tailPhase: number)
		local open = math.clamp(jaw, 0, 1)
		local jawFrame = jawHinge * CFrame.Angles(-math.rad(42) * open, 0, 0) * jawHinge:Inverse()
		local insideFrame = jawHinge * CFrame.Angles(-math.rad(20) * open, 0, 0) * jawHinge:Inverse()
		local tailFrame = tailHinge * CFrame.Angles(0, math.rad(22) * math.sin(tailPhase), 0) * tailHinge:Inverse()
		local list: { BasePart } = {}
		local frames: { CFrame } = {}
		for _, p in pieces do
			local group = if p.Group == "Jaw"
				then jawFrame
				elseif p.Group == "Inside" then insideFrame
				elseif p.Group == "Tail" then tailFrame
				else CFrame.identity
			table.insert(list, p.Part)
			table.insert(frames, frame * group * p.Base)
		end
		workspace:BulkMoveTo(list, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end

	function self.Fade(_self: Eater, transparency: number)
		for _, p in pieces do
			p.Part.Transparency = transparency
		end
	end

	function self.Destroy(_self: Eater)
		model:Destroy()
	end

	return self
end

return Eater
