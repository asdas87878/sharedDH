--!strict
-- Builds a wild fish: the model from ReplicatedStorage.FishModels.<Id> (or .<Name>) when there is one, else a chunky
-- placeholder out of parts in the type's colours. Either way the fish is one unanchored, non-colliding assembly round an
-- invisible Root (the PrimaryPart) with:
--   Root.Center: the movers' attachment; Root.Saddle: where the rider sits
--   Swim (LinearVelocity) and Turn (AlignOrientation) on the Root, which whoever owns it drives
--   Motor6Ds the client animates: SwayJoint (Root -> body), and on the placeholder TailJoint, FinL, FinR
-- Imported models should face -Z; they're scaled so their longest side is the type's length.
-- A modelled creature (one with an entry in Shared.Creatures) is a rig: a MeshPart per part, named as its entry names
-- them, joined parent to child by a Motor6D "Rig_<part>" at the part's pivot; the client turns those through the
-- creature's keyed swim. The model's "Rig" attribute is the creature's Id.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Creatures = require(ReplicatedStorage.Shared.Creatures)

local FishModel = {}

FishModel.Tag = "Fish"

local function basePart(model: Model, name: string, size: Vector3, cf: CFrame, colour: Color3, class: string?): BasePart
	local p = Instance.new((class or "Part") :: any) :: BasePart
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = false
	p.Parent = model
	return p
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

-- A Motor6D between two parts at a joint given in world space (the parts are built in place)
local function motor(name: string, a: BasePart, b: BasePart, joint: CFrame): Motor6D
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = a
	m.Part1 = b
	m.C0 = a.CFrame:Inverse() * joint
	m.C1 = b.CFrame:Inverse() * joint
	m.Parent = a
	return m
end

local function makeRoot(model: Model, at: CFrame): BasePart
	local root = basePart(model, "Root", Vector3.new(1, 1, 1), at, Color3.new(1, 1, 1))
	root.Transparency = 1
	root.Massless = false
	model.PrimaryPart = root
	return root
end

local function finish(model: Model, root: BasePart, fish: Config.FishType, top: number)
	local center = Instance.new("Attachment")
	center.Name = "Center"
	center.Parent = root
	local saddle = Instance.new("Attachment")
	saddle.Name = "Saddle"
	saddle.Position = Vector3.new(0, top + Config.Ride.SeatHeight, -fish.Size.Z * 0.04)
	saddle.Parent = root

	local swim = Instance.new("LinearVelocity")
	swim.Name = "Swim"
	swim.Attachment0 = center
	swim.RelativeTo = Enum.ActuatorRelativeTo.World
	swim.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	swim.MaxForce = math.huge
	swim.VectorVelocity = Vector3.zero
	swim.Parent = root

	local turn = Instance.new("AlignOrientation")
	turn.Name = "Turn"
	turn.Mode = Enum.OrientationAlignmentMode.OneAttachment
	turn.Attachment0 = center
	turn.MaxTorque = math.huge
	turn.MaxAngularVelocity = 6
	turn.Responsiveness = 14
	turn.CFrame = root.CFrame.Rotation
	turn.Parent = root

	model.Name = fish.Name
	model:SetAttribute("FishType", fish.Id)
	model:SetAttribute("Tier", fish.Tier)
	model:SetAttribute("Required", fish.Required)
	model:SetAttribute("Rider", 0)
	model:SetAttribute("Reserved", 0)
	CollectionService:AddTag(model, FishModel.Tag)
end

local function placeholder(fish: Config.FishType): Model
	local model = Instance.new("Model")
	local W, H, L = fish.Size.X, fish.Size.Y, fish.Size.Z
	local root = makeRoot(model, CFrame.identity)
	local shape = fish.Shape

	-- body proportions by shape
	local bodyL = L * 0.62
	local bodyH, bodyW = H, W
	if shape == "Round" then
		bodyL = L * 0.7
	elseif shape == "Flat" or shape == "Eel" then
		bodyL = L * 0.75
	end
	local bodyZ = -L * 0.06
	local body = basePart(model, "Body", Vector3.new(bodyW, bodyH, bodyL), CFrame.new(0, 0, bodyZ), fish.Body)
	if shape == "Round" then
		(body :: Part).Shape = Enum.PartType.Ball
		body.Size = Vector3.new(H, H, H)
	end
	motor("SwayJoint", root, body, CFrame.new(0, 0, bodyZ - bodyL * 0.2))
	local front = bodyZ - bodyL / 2
	local back = bodyZ + bodyL / 2

	-- belly, snout
	if fish.Belly ~= fish.Body and shape ~= "Round" then
		weld(
			body,
			basePart(
				model,
				"Belly",
				Vector3.new(bodyW * 1.02, bodyH * 0.28, bodyL * 0.92),
				CFrame.new(0, -bodyH * 0.37, bodyZ),
				fish.Belly
			)
		)
	end
	if shape ~= "Round" and shape ~= "Flat" then
		local snoutL = if shape == "Shark" or shape == "Eel" then L * 0.16 else L * 0.12
		weld(
			body,
			basePart(
				model,
				"Snout",
				Vector3.new(bodyW * 0.78, bodyH * 0.66, snoutL),
				CFrame.new(0, -bodyH * 0.08, front - snoutL / 2 + 0.05),
				fish.Body
			)
		)
		front -= snoutL
	end

	-- tail: a stalk on a joint, then the fin plate
	local stalkL = if shape == "Flat" then L * 0.3 else L * 0.16
	local stalkW = if shape == "Flat" then 0.5 else bodyW * 0.42
	local stalkH = if shape == "Flat" then 0.5 else bodyH * 0.48
	local stalk = basePart(
		model,
		"Tail",
		Vector3.new(stalkW, stalkH, stalkL),
		CFrame.new(0, 0, back + stalkL / 2 - 0.1),
		fish.Body
	)
	motor("TailJoint", body, stalk, CFrame.new(0, 0, back - 0.1))
	if shape ~= "Flat" then
		local finH = if shape == "Shark" then bodyH * 1.5 elseif shape == "Eel" then bodyH * 0.8 else bodyH * 1.15
		local finL = L * 0.14
		local tailFin = basePart(
			model,
			"TailFin",
			Vector3.new(0.3, finH, finL),
			CFrame.new(0, if shape == "Shark" then bodyH * 0.15 else 0, back + stalkL + finL / 2 - 0.3),
			fish.Fin
		)
		weld(stalk, tailFin)
	end

	-- dorsal fin (a wedge, its slope facing back), pectoral fins on joints
	if shape ~= "Flat" then
		local dorsalH = if shape == "Shark" then bodyH * 0.75 elseif shape == "Eel" then bodyH * 0.25 else bodyH * 0.4
		local dorsalL = if shape == "Eel" then bodyL * 0.85 else bodyL * 0.45
		local dorsal = basePart(
			model,
			"Dorsal",
			Vector3.new(0.35, dorsalH, dorsalL),
			CFrame.new(0, bodyH / 2 + dorsalH / 2 - 0.1, bodyZ + bodyL * 0.05) * CFrame.Angles(0, math.pi, 0),
			fish.Fin,
			"WedgePart"
		)
		weld(body, dorsal)
		if fish.Pattern == "Tips" and fish.PatternColour then
			weld(
				dorsal,
				basePart(
					model,
					"DorsalTip",
					Vector3.new(0.4, dorsalH * 0.25, dorsalL * 0.25),
					dorsal.CFrame * CFrame.new(0, dorsalH * 0.37, dorsalL * 0.37) * CFrame.Angles(0, 0, 0),
					fish.PatternColour,
					"WedgePart"
				)
			)
		end
	end
	local finSpan = if shape == "Flat" then W * 0.5 elseif shape == "Shark" then W * 0.9 else W * 0.5
	local finDepth = if shape == "Flat" then bodyL * 0.7 else L * 0.13
	for side = -1, 1, 2 do
		local edge = (if shape == "Round" then H / 2 else bodyW / 2) - 0.2
		local fin = basePart(
			model,
			if side < 0 then "FinLeft" else "FinRight",
			Vector3.new(finSpan, 0.3, finDepth),
			CFrame.new(side * (edge + finSpan / 2), -bodyH * (if shape == "Flat" then 0 else 0.2), bodyZ - bodyL * 0.12),
			fish.Fin
		)
		motor(if side < 0 then "FinL" else "FinR", body, fin, CFrame.new(side * edge, fin.Position.Y, fin.Position.Z))
	end

	-- eyes: a white square and a black one on each side, near the front
	local eyeSize = math.clamp(math.min(H, L) * 0.24, 0.7, 2.4)
	local eyeX = (if shape == "Round" then H / 2 * 0.8 else bodyW / 2) + 0.05
	local eyeY = if shape == "Flat" then bodyH / 2 else bodyH * 0.14
	local eyeZ = front + (if shape == "Round" then H * 0.35 else L * 0.11)
	for side = -1, 1, 2 do
		local white = basePart(
			model,
			"Eye",
			Vector3.new(0.2, eyeSize, eyeSize),
			CFrame.new(side * eyeX, eyeY, eyeZ),
			Color3.new(1, 1, 1)
		)
		weld(body, white)
		local pupil = basePart(
			model,
			"Pupil",
			Vector3.new(0.2, eyeSize * 0.55, eyeSize * 0.55),
			CFrame.new(side * (eyeX + 0.06), eyeY, eyeZ - eyeSize * 0.1),
			Color3.fromRGB(15, 15, 20)
		)
		weld(body, pupil)
	end

	-- pattern
	local count = fish.PatternCount or 0
	local colour = fish.PatternColour
	if colour and (fish.Pattern == "Stripes" or fish.Pattern == "Bands") then
		local thick = if fish.Pattern == "Bands" then bodyL * 0.09 else bodyL * 0.05
		for i = 1, count do
			local z = bodyZ - bodyL / 2 + bodyL * (i - 0.5) / count
			weld(
				body,
				basePart(model, "Stripe", Vector3.new(bodyW * 1.04, bodyH * 1.02, thick), CFrame.new(0, 0, z), colour)
			)
			if fish.Pattern == "Bands" then -- a clownfish's black edge either side of each white band
				for edge = -1, 1, 2 do
					weld(
						body,
						basePart(
							model,
							"BandEdge",
							Vector3.new(bodyW * 1.03, bodyH * 1.01, thick * 0.25),
							CFrame.new(0, 0, z + edge * thick * 0.6),
							Color3.fromRGB(20, 20, 20)
						)
					)
				end
			end
		end
	elseif colour and fish.Pattern == "Spots" then
		local rng = Random.new(#fish.Id)
		local r = if shape == "Round" then H / 2 else math.min(bodyW, bodyH) / 2
		for _ = 1, if shape == "Round" then 14 else 8 do
			local spot = basePart(model, "Spot", Vector3.new(0.6, 0.6, 0.6), CFrame.identity, colour)
			if shape == "Round" then
				local dir = rng:NextUnitVector()
				spot.Size = Vector3.new(0.4, 0.4, 0.9) -- the puffer's spikes
				spot.CFrame = CFrame.lookAt(dir * r, dir * (r + 1)) * CFrame.new(0, 0, 0.2)
				spot.CFrame += Vector3.new(0, 0, bodyZ)
			else
				local side = if rng:NextNumber() < 0.5 then -1 else 1
				spot.CFrame = CFrame.new(
					side * (bodyW / 2 + 0.02),
					rng:NextNumber(-r, r) * 0.7,
					bodyZ + rng:NextNumber(-bodyL, bodyL) * 0.4
				)
				spot.Size = Vector3.new(0.1, 0.7, 0.7)
			end
			weld(body, spot)
		end
	end

	finish(model, root, fish, if shape == "Round" then H / 2 else bodyH / 2)
	return model
end

local function fromTemplate(template: Model, fish: Config.FishType): Model
	local model = template:Clone()
	local _, extents = model:GetBoundingBox()
	local longest = math.max(extents.X, extents.Y, extents.Z)
	if longest > 0 then
		model:ScaleTo(model:GetScale() * fish.Size.Z / longest)
	end
	local box, size = model:GetBoundingBox()
	local parts: { BasePart } = {}
	local biggest: BasePart? = nil
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			if not biggest or d.Size.Magnitude > biggest.Size.Magnitude then
				biggest = d
			end
		elseif d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			d:Destroy()
		end
	end
	local root = makeRoot(model, box)
	for _, p in parts do
		p.Anchored = false
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.CastShadow = false
	end
	local body = biggest :: BasePart
	local tail = model:FindFirstChild("Tail", true)
	for _, p in parts do
		if p == body then
			motor("SwayJoint", root, body, box)
		elseif p == tail then
			motor("TailJoint", body, p, p.CFrame * CFrame.new(0, 0, -p.Size.Z / 2))
		else
			weld(body, p)
		end
	end
	finish(model, root, fish, size.Y / 2)
	return model
end

-- The world box round a model's parts, axis by axis (a model's own bounding box turns with its pivot; this doesn't)
local function worldBox(parts: { BasePart }): (Vector3, Vector3)
	local lo = Vector3.new(math.huge, math.huge, math.huge)
	local hi = -lo
	for _, p in parts do
		local half = p.Size / 2
		for sx = -1, 1, 2 do
			for sy = -1, 1, 2 do
				for sz = -1, 1, 2 do
					local corner = p.CFrame * Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)
					lo = lo:Min(corner)
					hi = hi:Max(corner)
				end
			end
		end
	end
	return lo, hi
end

-- A modelled creature: the template's parts joined as its entry in Shared.Creatures says. The template must stand as
-- it was exported: unturned, the head toward -Z.
local function fromRig(template: Model, fish: Config.FishType, rig: Creatures.Rig): Model
	local model = template:Clone()
	local parts: { BasePart } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		elseif d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			d:Destroy()
		end
	end
	assert(#parts > 0, "the model has no parts")
	-- to the type's length, whatever size the import came in at
	local lo, hi = worldBox(parts)
	local length = hi.Z - lo.Z
	assert(length > 0, "the model has no length")
	model:ScaleTo(model:GetScale() * fish.Size.Z / length)
	lo, hi = worldBox(parts)
	local centre = (lo + hi) / 2
	local k = fish.Size.Z / rig.Size[3] -- creature studs to ours

	local root = makeRoot(model, CFrame.new(centre))
	local byName: { [string]: BasePart } = {}
	for _, p in parts do
		byName[p.Name] = p
		p.Anchored = false
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.CastShadow = false
		if p:IsA("MeshPart") then
			-- the colours are in the mesh (vertex colours): a white part shows them as they are
			p.Color = Color3.new(1, 1, 1)
			p.Material = Enum.Material.SmoothPlastic
		end
	end
	local joined: { [BasePart]: boolean } = {}
	for _, row in rig.Parts do
		local name, parentName = row[1] :: string, row[2] :: string
		local part = byName[name]
		assert(part, "the model has no part named " .. name)
		local parent = if parentName == "" then root else byName[parentName]
		assert(parent, name .. "'s parent " .. parentName .. " is missing")
		local pivot = centre + Vector3.new(row[3], row[4], row[5]) * k
		motor("Rig_" .. name, parent, part, CFrame.new(pivot))
		joined[part] = true
	end
	for _, name in rig.Glow do
		local part = byName[name]
		if part then
			part.Material = Enum.Material.Neon
		end
	end
	-- what the entry doesn't hinge rides on its part (<Part>_Glow on <Part>), or on the first part
	local first = byName[rig.Parts[1][1] :: string]
	for _, p in parts do
		if not joined[p] then
			weld(byName[(string.gsub(p.Name, "_Glow$", ""))] or first, p)
		end
	end
	finish(model, root, fish, rig.Seat[2] * k)
	local saddle = root:FindFirstChild("Saddle") :: Attachment
	saddle.Position = Vector3.new(rig.Seat[1], rig.Seat[2], rig.Seat[3]) * k + Vector3.new(0, Config.Ride.SeatHeight, 0)
	model:SetAttribute("Rig", fish.Id)
	return model
end

local function findTemplate(fish: Config.FishType): Model?
	for _, folderName in { "FishModels", "Creatures" } do
		local folder = ReplicatedStorage:FindFirstChild(folderName)
		if folder then
			local found = folder:FindFirstChild(fish.Id) or folder:FindFirstChild(fish.Name)
			if found and found:IsA("Model") then
				return found
			end
		end
	end
	return nil
end

function FishModel.build(fish: Config.FishType): Model
	local template = findTemplate(fish)
	if template then
		local rig = Creatures.get(fish.Id)
		local ok, result
		if rig then
			ok, result = pcall(fromRig, template, fish, rig)
		else
			ok, result = pcall(fromTemplate, template, fish)
		end
		if ok then
			return result
		end
		warn("[FishModel] couldn't use the model for " .. fish.Id .. ": " .. tostring(result))
	end
	return placeholder(fish)
end

return FishModel
