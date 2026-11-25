--!strict
-- One 3D aura as Roblox draws it (look 2; Shared/AuraVolume has every number; docs/design/auras.md): its emitters, each
-- with an unseen part that is its place round the wearer, its ribbons (Beams along a spiral of Attachments that go round),
-- and its light. All of it stands in one frame, the feet or the fish: nothing is turned to the camera as a whole and nothing
-- is pushed behind the wearer, so the body hides what is behind it and what is in front is in front.
-- AuraController places the parts (one BulkMoveTo for every aura) and says what happens: step (every frame), flare, and the
-- moment it was put on.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AuraVolume = require(ReplicatedStorage.Shared.AuraVolume)
local Auras = require(ReplicatedStorage.Shared.Auras)
local Config = require(ReplicatedStorage.Shared.Config)

local AuraAround = {}

type Piece = { Layer: AuraVolume.Layer, Part: Part, Emitter: ParticleEmitter, There: boolean, Size: Vector3 }
type Band = { Strand: AuraVolume.Strand, Joints: { Attachment }, Beams: { Beam } }
export type Around = {
	Spec: AuraVolume.Spec,
	Pieces: { Piece },
	Carrier: Part,
	Bands: { Band },
	Lamp: Part,
	Light: PointLight?,
	Clock: number, -- how long the ribbons have gone round
	Last: number?,
	Sat: number, -- 0 on foot to 1 riding, eased
	Ridden: AuraVolume.Shape?, -- how it stood when last ridden
	RiddenAt: CFrame?, -- and where, in the wearer's own frame
	Grow: number, -- as the pictures are written,
	Own: boolean,
	Seen: number, -- as the fade is written (-1: not yet)
	Running: boolean, -- its emitters let out
	Detail: number,
	Bright: number,
	FlareAt: number?,
	OnAt: number?,
	OnDone: boolean,
	PulseN: number,
}
-- Where it stands this frame, on the ride: the mount's frame (upright, or leaning with it), and its shape there (our own
-- may be the calmer one, Aura.EyeCalm)
export type Ride = { At: CFrame, Shape: AuraVolume.Shape }

-- The engine's own pictures that stand in for ours until they are uploaded (a name not here: the layer is left out). Soft
-- ones only, and none that the old look drew as a bubble or a spark
AuraAround.Standin = {
	Glow = "rbxasset://textures/particles/explosion01_implosion_main.dds",
	Ring = "rbxasset://textures/particles/forcefield_vortex_main.dds", -- (a thin circle, flat on the ground: it turns)
	Haze = "rbxasset://textures/particles/smoke_main.dds",
	Wisp = "rbxasset://textures/particles/fire_main.dds",
	Flame = "rbxasset://textures/particles/fire_main.dds",
	Mote = "rbxasset://textures/particles/explosion01_implosion_main.dds",
} :: { [string]: string }

-- Studio has the local copies (false once AuraController's preload found it has not)
AuraAround.Local = RunService:IsStudio()

-- A picture's address, and whether it is ours (a sheet of frames) or a stand-in; "" for none
function AuraAround.picture(name: string): (string, boolean)
	local id = Auras.Sheets[name]
	if id ~= "" then
		return id, true
	elseif AuraAround.Local then
		return `rbxasset://textures/ridefish/aura3_{string.lower(name)}_{Auras.SheetSet}.png`, true
	end
	return AuraAround.Standin[name] or "", false
end

local function unseen(name: string, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Parent = parent
	return p
end

local ORIENT = {
	Upright = Enum.ParticleOrientation.FacingCameraWorldUp,
	Flat = Enum.ParticleOrientation.VelocityPerpendicular,
	Along = Enum.ParticleOrientation.VelocityParallel,
	Round = Enum.ParticleOrientation.FacingCamera,
}
local SHAPE = {
	Band = Enum.ParticleEmitterShape.Disc,
	Top = Enum.ParticleEmitterShape.Disc,
	Flat = Enum.ParticleEmitterShape.Box,
	Air = Enum.ParticleEmitterShape.Cylinder,
	Wall = Enum.ParticleEmitterShape.Cylinder,
	Foot = Enum.ParticleEmitterShape.Cylinder,
}

local function emitter(l: AuraVolume.Layer, part: Part): (ParticleEmitter, boolean)
	local e = Instance.new("ParticleEmitter")
	e.Name = l.Name
	local picture, ours = AuraAround.picture(l.Picture)
	e.Texture = picture
	if ours and l.Grid > 1 then
		e.FlipbookLayout = if l.Grid == 8
			then Enum.ParticleFlipbookLayout.Grid8x8
			else Enum.ParticleFlipbookLayout.Grid4x4
		e.FlipbookMode = (Enum.ParticleFlipbookMode :: any)[l.Mode]
		e.FlipbookFramerate = NumberRange.new(l.Fps)
		e.FlipbookStartRandom = l.Mode ~= "OneShot"
	end
	e.Enabled = false
	e.Rate = 0
	e.Lifetime = NumberRange.new(l.Life[1], l.Life[2])
	e.Speed = NumberRange.new(l.Speed[1], l.Speed[2])
	e.SpreadAngle = Vector2.new(l.Spread, l.Spread)
	e.EmissionDirection = Enum.NormalId.Top
	e.Shape = SHAPE[l.Place]
	if l.Place == "Band" or l.Place == "Top" then
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.ShapePartial = l.Band
	elseif l.Place == "Wall" or l.Place == "Foot" then
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	else
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	end
	e.Orientation = ORIENT[l.Facing]
	e.Color = if l.Color == l.Color2 then ColorSequence.new(l.Color) else ColorSequence.new(l.Color, l.Color2)
	e.LightEmission = l.Emission
	e.LightInfluence = 0
	e.Brightness = l.Bright
	e.Acceleration = Vector3.new(0, l.Accel, 0)
	e.Drag = l.Drag
	e.LockedToPart = true -- (it goes with a rider at any speed)
	if l.AnyTurn then
		e.Rotation = NumberRange.new(0, 360)
	end
	if l.Turn ~= 0 then
		e.RotSpeed = NumberRange.new(-l.Turn, l.Turn)
	end
	e.Parent = part
	return e, picture ~= ""
end

local TIMES = { 0, 0.25, 0.5, 0.75, 1 }

-- Make a tier's aura in `parent`: nothing is seen of it until it is stepped
function AuraAround.build(parent: Instance, tier: number): Around
	local spec = AuraVolume.spec(tier)
	local pieces: { Piece } = {}
	for _, l in spec.Layers do
		local part = unseen(l.Name, parent)
		local e, there = emitter(l, part)
		table.insert(pieces, { Layer = l, Part = part, Emitter = e, There = there, Size = part.Size })
	end
	local carrier = unseen("Ribbons", parent)
	local bands: { Band } = {}
	local picture = AuraAround.picture("Ribbon")
	for _, s in spec.Strands do
		local joints: { Attachment } = {}
		local beams: { Beam } = {}
		for i = 1, s.Beams + 1 do
			local a = Instance.new("Attachment")
			a.Parent = carrier
			table.insert(joints, a)
			if i > 1 then
				local b = Instance.new("Beam")
				b.Name = s.Name .. (i - 1)
				b.Attachment0 = joints[i - 1]
				b.Attachment1 = a
				b.FaceCamera = true -- (the ribbon turns about its own line; the line itself goes round the wearer)
				b.Segments = 16
				b.LightInfluence = 0
				b.LightEmission = s.Emission
				b.Color = ColorSequence.new(
					s.Color:Lerp(s.Head, ((i - 2) / s.Beams) ^ 2),
					s.Color:Lerp(s.Head, ((i - 1) / s.Beams) ^ 2)
				)
				b.Texture = picture
				b.TextureMode = Enum.TextureMode.Stretch
				b.TextureLength = s.Repeat
				b.TextureSpeed = 0
				b.Transparency = NumberSequence.new(1)
				b.Parent = carrier
				table.insert(beams, b)
			end
		end
		table.insert(bands, { Strand = s, Joints = joints, Beams = beams })
	end
	local lamp = unseen("Lamp", parent)
	local light: PointLight? = nil
	if spec.Light then
		local p = Instance.new("PointLight")
		p.Color = spec.Light.Color
		p.Range = spec.Light.Range
		p.Brightness = 0
		p.Shadows = false
		p.Enabled = false
		p.Parent = lamp
		light = p
	end
	return {
		Spec = spec,
		Pieces = pieces,
		Carrier = carrier,
		Bands = bands,
		Lamp = lamp,
		Light = light,
		Clock = 0,
		Last = nil,
		Sat = 0,
		Ridden = nil,
		RiddenAt = nil,
		Grow = -1,
		Own = false,
		Seen = -1,
		Running = false,
		Detail = 0,
		Bright = -1,
		FlareAt = nil,
		OnAt = nil,
		OnDone = false,
		PulseN = 0,
	}
end

-- Its emitters (for the Studio captures' TimeScale)
function AuraAround.emitters(a: Around): { ParticleEmitter }
	local out = {}
	for _, p in a.Pieces do
		table.insert(out, p.Emitter)
	end
	return out
end

-- What is drawn of it now: its Beams and its emitters (Studio's checks)
function AuraAround.drawn(a: Around): (number, number)
	local beams, emitters = 0, 0
	for _, b in a.Bands do
		for _, beam in b.Beams do
			beams += if beam.Enabled then 1 else 0
		end
	end
	for _, p in a.Pieces do
		emitters += if p.Emitter.Enabled then 1 else 0
	end
	return beams, emitters
end

local function let(a: Around, key: string)
	for _, p in a.Pieces do
		local n = (p.Layer :: any)[key]
		if n > 0 and p.There and p.Layer.Keep <= a.Detail then
			p.Emitter:Emit(n)
		end
	end
end

-- A flare: a landing, a hop or a boost (the controller asks only for those the tier has)
function AuraAround.flare(a: Around, t: number)
	if a.Seen <= 0 or (a.FlareAt and t >= a.FlareAt and t - a.FlareAt < Config.Aura.FlareGap) then
		return
	end
	a.FlareAt = t
	let(a, "Flare")
end

-- It has just been put on: the burst (tier 10 up), or it rises
function AuraAround.putOn(a: Around, t: number)
	a.OnAt = t
	a.OnDone = false
end

-- Nothing of it is left in the world (out of range, or wholly faded): what was alive is gone at once
function AuraAround.hide(a: Around)
	if a.Running then
		a.Running = false
		for _, p in a.Pieces do
			p.Emitter.Enabled = false
			p.Emitter:Clear()
		end
		for _, b in a.Bands do
			for _, beam in b.Beams do
				beam.Enabled = false
			end
		end
	end
	a.Seen = 0
	a.Last = nil -- (back in as it stands then, not easing from where it was)
end

local function scaled(pairs: { { number } }, by: number, jitter: number): NumberSequence
	local list = {}
	for _, k in pairs do
		local v = k[2] * by
		table.insert(list, NumberSequenceKeypoint.new(k[1], v, v * jitter))
	end
	return NumberSequence.new(list)
end

local function faded(pairs: { { number } }, seen: number): NumberSequence
	local list = {}
	for _, k in pairs do
		table.insert(list, NumberSequenceKeypoint.new(k[1], 1 - (1 - k[2]) * seen))
	end
	return NumberSequence.new(list)
end

-- One frame. feet: the wearer's, upright; ride: what they ride, nil on foot; hold: nothing for now, in the hop from one
-- fish to the next (it stays as it stood, or it would shrink and swell at every hop); seen: the fade, 0 to 1 (over 0:
-- hide is for none); detail: 1 to 3; lit: its light is on. place: put a part somewhere
function AuraAround.step(
	a: Around,
	t: number,
	feet: CFrame,
	ride: Ride?,
	hold: boolean,
	seen: number,
	detail: number,
	lit: boolean,
	place: (BasePart, CFrame) -> ()
)
	local spec = a.Spec
	local c = Config.Aura
	local dt = math.clamp(t - (a.Last or t), 0, 0.2)
	local first = a.Last == nil
	a.Last = t
	a.Clock += dt * (if ride then spec.RideFast else 1)

	-- where it stands: between the feet and the mount as they are got on and off
	local toSat = if ride or (hold and a.Ridden) then 1 else 0
	if first then
		a.Sat = toSat
	else
		local most = dt / math.max(c.SeatEase, 0.01)
		a.Sat += math.clamp(toSat - a.Sat, -most, most)
	end
	if ride then
		-- (from one fish's size to the next one's over a moment, not at once)
		local to = feet:ToObjectSpace(ride.At)
		local k = if a.Ridden and a.Sat > 0 then 1 - math.exp(-dt * 2.5 / math.max(c.SeatEase, 0.01)) else 1
		local stood: AuraVolume.Shape = AuraVolume.between(a.Ridden or ride.Shape, ride.Shape, k)
		stood.Own = ride.Shape.Own
		a.Ridden = stood
		a.RiddenAt = if a.RiddenAt then a.RiddenAt:Lerp(to, k) else to
	end
	local shape = AuraVolume.foot(spec)
	local at = feet
	if a.Sat > 0 and a.Ridden and a.RiddenAt then
		local k = a.Sat * a.Sat * (3 - 2 * a.Sat)
		shape = AuraVolume.between(shape, a.Ridden, k)
		at = feet * CFrame.new():Lerp(a.RiddenAt, k)
	end

	-- the moment
	local on: number? = if a.OnAt then t - a.OnAt else nil
	if on and on > c.PutOnOver then
		a.OnAt = nil
		on = nil
	end
	local wide, bright = AuraVolume.moment(spec, t, if a.FlareAt then t - a.FlareAt else nil)
	local big = if on then AuraVolume.putOn(spec, on) else 1
	if big ~= 1 then
		shape = table.clone(shape)
		shape.X *= big
		shape.Z *= big
		shape.Height *= big
	end
	local frame = at * CFrame.new(shape.At)

	-- what is drawn of it
	local started = not a.Running
	if started or a.Detail ~= detail then
		a.Running = true
		a.Detail = detail
		for _, p in a.Pieces do
			p.Emitter.Enabled = p.There and p.Layer.Keep <= detail
		end
		for _, b in a.Bands do
			for _, beam in b.Beams do
				beam.Enabled = b.Strand.Keep <= detail
			end
		end
		a.Grow = -1
	end
	if math.abs(a.Grow - shape.Grow) > 0.06 or a.Own ~= shape.Own then
		a.Grow = shape.Grow
		a.Own = shape.Own
		for _, p in a.Pieces do
			p.Emitter.Rate = AuraVolume.rate(p.Layer, shape, detail, c)
			p.Emitter.Size = scaled(p.Layer.Size, shape.Grow, p.Layer.Jitter)
			p.Emitter.Acceleration = Vector3.new(0, p.Layer.Accel * shape.Grow, 0)
			p.Emitter.Speed = NumberRange.new(p.Layer.Speed[1] * shape.Grow, p.Layer.Speed[2] * shape.Grow)
		end
	end
	local strong = AuraVolume.strong(spec, shape, c)
	local now = math.max(AuraVolume.step(seen * strong), 1 / AuraVolume.Steps)
	if now ~= a.Seen then
		a.Seen = now
		local strength = now * spec.Strength
		for _, p in a.Pieces do
			p.Emitter.Transparency = faded(p.Layer.Fade, strength)
		end
		for _, b in a.Bands do
			local s = b.Strand
			for i, beam in b.Beams do
				local list = {}
				for _, k in TIMES do
					local f = AuraVolume.strandFade((i - 1 + k) / s.Beams)
					table.insert(list, NumberSequenceKeypoint.new(k, 1 - f * (1 - s.Transparency) * strength))
				end
				beam.Transparency = NumberSequence.new(list)
			end
		end
	end

	-- the places
	for _, p in a.Pieces do
		local l = p.Layer
		if l.Keep <= detail then
			local up, size = AuraVolume.place(l, shape)
			if (size - p.Size).Magnitude > 0.1 then
				p.Size = size
				p.Part.Size = size
			end
			-- (a long one does not turn: its length would swing out of the fish)
			local turn = if l.Spin ~= 0 and math.abs(shape.X - shape.Z) < 0.4 then l.Spin * a.Clock else 0
			place(p.Part, frame * CFrame.new(0, up, 0) * CFrame.Angles(0, turn, 0))
		end
	end
	place(a.Carrier, frame)
	for _, b in a.Bands do
		local s = b.Strand
		if s.Keep > detail then
			continue
		end
		local handles = table.create(#b.Joints) :: { number }
		for i, joint in b.Joints do
			local pos, along, handle = AuraVolume.strandAt(s, shape, i, a.Clock, t)
			local side = along:Cross(Vector3.yAxis)
			side = if side.Magnitude > 1e-3 then side.Unit else Vector3.xAxis
			joint.CFrame = CFrame.fromMatrix(pos, along, side:Cross(along).Unit, side)
			handles[i] = handle
		end
		local run = (c.Scroll * a.Clock * s.Flow) % 1
		for i, beam in b.Beams do
			beam.CurveSize0 = handles[i]
			beam.CurveSize1 = handles[i + 1]
			local w = wide * shape.Grow
			beam.Width0 = AuraVolume.strandWidth(s, (i - 1) / s.Beams) * w
			beam.Width1 = AuraVolume.strandWidth(s, i / s.Beams) * w
			beam:SetTextureOffset(run)
		end
	end
	-- the glow: the ribbons and the light swell with the pulse
	local b = math.floor(bright * 20 + 0.5) / 20
	if b ~= a.Bright then
		a.Bright = b
		for _, band in a.Bands do
			for _, beam in band.Beams do
				beam.Brightness = b
			end
		end
	end
	local light = a.Light
	local l = spec.Light
	if light and l then
		light.Enabled = lit
		if lit then
			light.Brightness = l.Bright * bright * seen
			light.Range = math.min(l.Range * shape.Grow, 45)
			place(a.Lamp, frame * CFrame.new(0, math.min(shape.Height * 0.3, 3), 0))
		end
	end

	-- what is let out at once
	if started then
		-- (its parts are in place by the end of this frame)
		task.defer(let, a, "Warm")
	end
	if on and spec.Burst and not a.OnDone and on >= 0.04 then
		a.OnDone = true
		let(a, "Burst")
	end
	local _, n = AuraVolume.pulseAt(spec, t)
	if n ~= a.PulseN then
		a.PulseN = n
		for _, p in a.Pieces do
			if p.Layer.Name == "Shock" and p.There and p.Layer.Keep <= detail then
				p.Emitter:Emit(1)
			end
		end
	end
end

return AuraAround
