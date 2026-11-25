--!strict
-- One flame aura as Roblox draws it: the Beams and the ParticleEmitters of a tier (Shared/AuraFlame has every number;
-- docs/design/auras.md). The Beams hang between Attachments on one unseen part that stands at the wearer's feet and is
-- turned to the camera about the upright (a Beam faces the camera by itself, but its ends do not); the emitters each have
-- a part, their cylinder, that does not turn. AuraController places the parts (one BulkMoveTo for every aura), and says
-- what happens: step (every frame), flare, and the moment it was put on.
-- The two that could not be checked offline are dials, read live: which way a Beam runs its picture (Config.Aura.Turn,
-- Scroll) and which way ZOffset pushes (Behind).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AuraFlame = require(ReplicatedStorage.Shared.AuraFlame)
local Auras = require(ReplicatedStorage.Shared.Auras)
local Config = require(ReplicatedStorage.Shared.Config)

local AuraBeams = {}

type Body = {
	Layer: AuraFlame.Layer,
	Joints: { Attachment },
	Beams: { Beam },
	Feet: { Attachment },
	Tops: { Attachment },
	Tips: { Beam },
	BodyAt: number, -- the strength last written (a hundredth)
	TipAt: number,
}
type Wave = { Foot: Attachment, Top: Attachment, Beam: Beam }
export type Flame = {
	Spec: AuraFlame.Spec,
	Card: Part, -- the Beams' part
	Bodies: { Body },
	Waves: { Wave },
	Parts: { Part }, -- the emitters' parts,
	Emitters: { ParticleEmitter }, -- one to a part
	Clock: number, -- how long the pictures have run
	Last: number?,
	Seat: number, -- 0 standing to 1 seated, eased
	FlareAt: number?,
	OnAt: number?, -- put on just now
	OnDone: boolean, -- the burst has been let out
	Extras: number, -- the emitters' share of their rate
	ShortAt: number,
	Turn: number,
	Behind: number,
}

local GLOW = "rbxasset://textures/particles/explosion01_implosion_main.dds"
local BEAM_PICTURES = { Flame = true, Tip = true, Streaks = true }

-- Every picture has an id: a live game can draw the flame
function AuraBeams.uploaded(): boolean
	for _, id in Auras.Pictures do
		if id == "" then
			return false
		end
	end
	return true
end

-- A picture's address: the uploaded one, or Studio's local copy (tools/auras/flame_pics.py)
function AuraBeams.picture(name: string): string
	if name == "Glow" then
		return GLOW
	elseif AuraBeams.uploaded() then
		return Auras.Pictures[name]
	elseif not RunService:IsStudio() then
		return ""
	end
	local file = `rbxasset://textures/ridefish/aura_{string.lower(name)}_{Auras.PictureSet}`
	return if BEAM_PICTURES[name] then `{file}_t{math.floor(Config.Aura.Turn) % 4}.png` else file .. ".png"
end

local function unseen(name: string, size: Vector3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Transparency = 1
	p.Size = size
	p.Parent = parent
	return p
end

local function point(parent: Instance): Attachment
	local a = Instance.new("Attachment")
	a.Parent = parent
	return a
end

local function beam(
	name: string,
	from: Attachment,
	to: Attachment,
	picture: string,
	color: Color3,
	emission: number,
	parent: Instance
): Beam
	local b = Instance.new("Beam")
	b.Name = name
	b.Attachment0 = from
	b.Attachment1 = to
	b.FaceCamera = true
	b.LightInfluence = 0
	b.LightEmission = emission
	b.Brightness = 1
	b.Color = ColorSequence.new(color)
	b.CurveSize0 = 0
	b.CurveSize1 = 0
	b.Segments = 10
	b.TextureSpeed = 0 -- (the controller sets where the picture stands: every Beam of a body as one)
	b:SetAttribute("Picture", picture)
	b.Texture = AuraBeams.picture(picture)
	b.Parent = parent
	return b
end

local function keys(pairs: { { number } }, envelope: number?): NumberSequence
	local list = {}
	for _, k in pairs do
		table.insert(list, NumberSequenceKeypoint.new(k[1], k[2], k[2] * (envelope or 0)))
	end
	return NumberSequence.new(list)
end

-- Make a tier's flame in `parent`
function AuraBeams.build(parent: Instance, tier: number): Flame
	local spec = AuraFlame.spec(tier)
	local card = unseen("Flame", Vector3.new(0.4, 0.4, 0.4), parent)
	local profile = AuraFlame.Profile
	local bodies: { Body } = {}
	local waves: { Wave } = {}
	for _, l in spec.Layers do
		local b: Body = {
			Layer = l,
			Joints = {},
			Beams = {},
			Feet = {},
			Tops = {},
			Tips = {},
			BodyAt = -1,
			TipAt = -1,
		}
		for _ in profile do
			local joint = point(card)
			-- (each Beam leaves and meets its joints straight up, so the two at a joint share one level edge: run straight
			-- between bending joints they left a thin gap on one side and a bright line on the other, 2026-11-25)
			joint.Axis = Vector3.yAxis
			joint.SecondaryAxis = -Vector3.xAxis
			table.insert(b.Joints, joint)
		end
		for i = 1, #profile - 1 do
			local made = beam(l.Name .. i, b.Joints[i], b.Joints[i + 1], l.Picture, l.Color, l.Emission, card)
			made.TextureMode = Enum.TextureMode.Wrap
			made.Segments = 20 -- (the first piece of each leaves the joint nearer to straight up)
			table.insert(b.Beams, made)
		end
		for i = 1, #l.Tips do
			local foot, top = point(card), point(card)
			local made = beam(l.Name .. "Tip" .. i, foot, top, "Tip", l.Color, l.Emission, card)
			made.TextureMode = Enum.TextureMode.Stretch -- (the blade once along it, whatever its length)
			made.TextureLength = 1
			table.insert(b.Feet, foot)
			table.insert(b.Tops, top)
			table.insert(b.Tips, made)
		end
		table.insert(bodies, b)
		local w = spec.Wave
		if w and l.Name == "Flame" then
			for i = 1, w.Count do
				local foot, top = point(card), point(card)
				local made = beam("Wave" .. i, foot, top, "Flame", w.Color, w.Emission, card)
				made.TextureMode = Enum.TextureMode.Wrap
				made.Enabled = false
				table.insert(waves, { Foot = foot, Top = top, Beam = made })
			end
		end
	end
	local parts: { Part } = {}
	local emitters: { ParticleEmitter } = {}
	for _, e in spec.Extras do
		local part = unseen(e.Name, Vector3.new(e.Radius * 2, e.Height, e.Radius * 2), parent)
		local em = Instance.new("ParticleEmitter")
		em.Name = e.Name
		em.Texture = AuraBeams.picture(e.Picture)
		em.Rate = e.Rate
		em.Lifetime = NumberRange.new(e.Life[1], e.Life[2])
		em.Speed = NumberRange.new(e.Speed[1], e.Speed[2])
		em.SpreadAngle = Vector2.new(e.Spread, e.Spread)
		em.EmissionDirection = Enum.NormalId.Top
		em.Shape = Enum.ParticleEmitterShape.Cylinder
		em.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		em.Size = keys(e.Size, e.SizeJitter)
		em.Transparency = keys(e.Fade)
		em.Color = ColorSequence.new(e.Color)
		em.LightEmission = e.Emission
		em.LightInfluence = 0
		em.Brightness = 1
		em.Acceleration = Vector3.new(0, e.Accel, 0)
		em.Drag = e.Drag
		em.LockedToPart = true
		em.ZOffset = -(e.Radius + AuraFlame.Push)
		if e.Upright then
			em.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		end
		if e.Spin then
			em.Rotation = NumberRange.new(0, 360)
		end
		em.Parent = part
		table.insert(parts, part)
		table.insert(emitters, em)
	end
	return {
		Spec = spec,
		Card = card,
		Bodies = bodies,
		Waves = waves,
		Parts = parts,
		Emitters = emitters,
		Clock = 0,
		Last = nil,
		Seat = 0,
		FlareAt = nil,
		OnAt = nil,
		OnDone = false,
		Extras = -1,
		ShortAt = -1,
		Turn = Config.Aura.Turn,
		Behind = math.huge, -- (written by the first step)
	}
end

local function let(flame: Flame, key: string)
	for i, e in flame.Spec.Extras do
		local n = (e :: any)[key]
		if n > 0 then
			flame.Emitters[i]:Emit(n)
		end
	end
end

-- A flare: a landing, a hop or a boost (the controller asks only for those the tier has)
function AuraBeams.flare(flame: Flame, t: number)
	if flame.FlareAt and t >= flame.FlareAt and t - flame.FlareAt < Config.Aura.FlareGap then
		return
	end
	flame.FlareAt = t
	let(flame, "Flare")
end

-- It has just been put on: the burst (tier 10 up), or it rises
function AuraBeams.putOn(flame: Flame, t: number)
	flame.OnAt = t
	flame.OnDone = false
end

-- (the strengths are few, so their sequences are kept: a hundred a Beam at most)
local function written(strength: number): number
	return math.floor(strength * 50 + 0.5)
end

local function wide(b: Beam, w0: number, w1: number)
	if math.abs(b.Width0 - w0) > 0.005 then
		b.Width0 = w0
	end
	if math.abs(b.Width1 - w1) > 0.005 then
		b.Width1 = w1
	end
end

-- Where the picture stands on a Beam that starts `from` repeats up the body, the body's picture having run `run`
local function offset(b: Beam, run: number, from: number)
	b:SetTextureOffset((Config.Aura.Scroll * (run - from)) % 1)
end

local TIMES = { 0, 0.25, 0.5, 0.75, 1 }

local function fadeBody(body: Body, scale: number, strength: number)
	local profile = AuraFlame.Profile
	for i, b in body.Beams do
		local q0, q1 = profile[i][1], profile[i + 1][1]
		local list = {}
		for _, k in TIMES do
			local f = AuraFlame.fade(body.Layer, q0 + (q1 - q0) * k, scale)
			table.insert(list, NumberSequenceKeypoint.new(k, 1 - f * strength))
		end
		b.Transparency = NumberSequence.new(list)
	end
end

-- One frame. base: the feet, upright; toCam: the flat way to the camera; riding: sat on a fish. put: place a part
function AuraBeams.step(
	flame: Flame,
	t: number,
	base: CFrame,
	toCam: Vector3,
	riding: boolean,
	place: (BasePart, CFrame) -> ()
)
	local spec = flame.Spec
	local c = Config.Aura
	local dt = math.clamp(t - (flame.Last or t), 0, 0.2)
	flame.Last = t
	flame.Clock += dt * (if riding then spec.RideFast else 1)
	-- the dials, when they are turned in Studio
	if flame.Turn ~= c.Turn then
		flame.Turn = c.Turn
		for _, d in flame.Card:GetChildren() do
			if d:IsA("Beam") then
				d.Texture = AuraBeams.picture(d:GetAttribute("Picture") :: string)
			end
		end
	end
	if flame.Behind ~= c.Behind then
		flame.Behind = c.Behind
		for _, body in flame.Bodies do
			for _, b in body.Beams do
				b.ZOffset = AuraFlame.Behind * c.Behind
			end
			for _, b in body.Tips do
				b.ZOffset = AuraFlame.Behind * c.Behind
			end
		end
		for _, w in flame.Waves do
			w.Beam.ZOffset = AuraFlame.Behind * c.Behind
		end
		for i, e in spec.Extras do
			flame.Emitters[i].ZOffset = -(e.Radius + AuraFlame.Push) * c.Behind
		end
	end

	-- the moment
	local on: number? = if flame.OnAt then t - flame.OnAt else nil
	if on and on > c.PutOnOver then
		flame.OnAt = nil
		on = nil
	elseif on and spec.Burst and not flame.OnDone and on >= 0.04 then
		-- (its parts are in place by now: they are placed after the frame that makes them)
		flame.OnDone = true
		let(flame, "Burst")
	end
	local m = AuraFlame.moment(spec, t, if flame.FlareAt then t - flame.FlareAt else nil, on)
	local toSeat = if riding then 1 else 0
	if dt == 0 and flame.ShortAt < 0 then
		flame.Seat = toSeat -- (its first frame: already as it is sat)
	else
		local most = dt / math.max(c.SeatEase, 0.01)
		flame.Seat += math.clamp(toSeat - flame.Seat, -most, most)
	end
	local short = 1 + (AuraFlame.Seated - 1) * flame.Seat
	local foot = AuraFlame.Base + (AuraFlame.SeatBase - AuraFlame.Base) * flame.Seat

	-- the parts
	local at = base.Position
	place(flame.Card, CFrame.lookAlong(at + Vector3.new(0, foot, 0), -toCam))
	local resized = math.abs(flame.ShortAt - short) > 0.02 or (flame.ShortAt ~= short and short == 1)
	if resized then
		flame.ShortAt = short
	end
	for i, e in spec.Extras do
		if resized then
			flame.Parts[i].Size = Vector3.new(e.Radius * 2, e.Height * short, e.Radius * 2)
		end
		place(flame.Parts[i], CFrame.new(at + Vector3.new(0, e.At * short + foot - AuraFlame.Base, 0)))
	end
	if flame.Extras ~= m.Seen then
		flame.Extras = m.Seen
		for i, e in spec.Extras do
			flame.Emitters[i].Rate = e.Rate * m.Seen
		end
	end

	-- the Beams
	local profile = AuraFlame.Profile
	for _, body in flame.Bodies do
		local l = body.Layer
		local high = AuraFlame.height(l, m, short, t)
		local w = l.Width * m.Wide
		local bodyStrength, tipStrength = AuraFlame.strength(spec, l, m, t)
		for i, p in profile do
			body.Joints[i].Position = Vector3.new(AuraFlame.bend(l, p[1], t), p[1] * high, 0)
		end
		-- (a repeat is as tall as the flame is: the picture stretches with it, so it stays joined)
		local length = l.Repeat * m.High * short
		local repeats = high / length
		local run = AuraFlame.scroll(spec, l, flame.Clock, t)
		for i, b in body.Beams do
			wide(b, profile[i][2] * w, profile[i + 1][2] * w)
			local curve = (profile[i + 1][1] - profile[i][1]) * high / 3
			if math.abs(b.CurveSize0 - curve) > 0.005 then
				b.CurveSize0 = curve
				b.CurveSize1 = curve
			end
			if math.abs(b.TextureLength - length) > 0.005 then
				b.TextureLength = length
			end
			offset(b, run, profile[i][1] * repeats)
		end
		local now = written(bodyStrength)
		if now ~= body.BodyAt then
			body.BodyAt = now
			fadeBody(body, spec.Scale, now / 50)
		end
		for i, b in body.Tips do
			local from, to, tw = AuraFlame.tongue(l, i, w, high, t)
			body.Feet[i].Position = Vector3.new(from.X, from.Y, 0)
			body.Tops[i].Position = Vector3.new(to.X, to.Y, 0)
			wide(b, tw, tw)
		end
		local tipNow = written(tipStrength)
		if tipNow ~= body.TipAt then
			body.TipAt = tipNow
			local seq = NumberSequence.new(1 - tipNow / 50)
			for _, b in body.Tips do
				b.Transparency = seq
			end
		end
		if l.Name == "Flame" then
			for i, wave in flame.Waves do
				local q0, middle, q1 = AuraFlame.waveAt(spec, i, t)
				wave.Beam.Enabled = q0 ~= nil
				if q0 then
					wave.Foot.Position = Vector3.new(AuraFlame.bend(l, q0, t), q0 * high, 0)
					wave.Top.Position = Vector3.new(AuraFlame.bend(l, q1, t), q1 * high, 0)
					wide(wave.Beam, AuraFlame.outline(q0) * w, AuraFlame.outline(q1) * w)
					wave.Beam.TextureLength = length
					offset(wave.Beam, 0, (q0 - (middle - (spec.Wave :: any).Half)) * repeats)
					local list = {}
					for _, k in TIMES do
						local f = AuraFlame.waveFade(spec, l, middle, q0 + (q1 - q0) * k)
						table.insert(list, NumberSequenceKeypoint.new(k, 1 - f * m.Seen))
					end
					wave.Beam.Transparency = NumberSequence.new(list)
				end
			end
		end
	end
end

return AuraBeams
