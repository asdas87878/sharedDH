--!strict
-- One trail's pieces (docs/design/fish-trails.md; the numbers: Shared/FishTrails): two invisible parts that follow a fish, with
-- every emitter, ribbon and front sheet on them. A rig is made once and dressed again for each fish it is given, and nothing
-- is made while it runs. It stands outside the fish's model, so nothing that looks over a fish's own pieces (the angry look,
-- the fails) ever finds it. FishTrailController owns the rigs.
-- In this file: the pictures and the making, dressing it for a fish, our own fish's drift, and each frame.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FishTrails = require(ReplicatedStorage.Shared.FishTrails)

local FishTrailRig = {}

-- (Roblox's own pictures, in every install)
local PICTURES = "rbxasset://textures/particles/"
local SMOKE = PICTURES .. "smoke_main.dds"
local SOFT = PICTURES .. "explosion01_implosion_main.dds"
local RING = PICTURES .. "explosion01_shockwave_main.dds"
local STAR = PICTURES .. "sparkles_main.dds"

local BUBBLE = Color3.fromRGB(225, 248, 255)
local WHITE = Color3.new(1, 1, 1)
local TAU = math.pi * 2

export type Curl = { Trail: Trail, A: Attachment, B: Attachment, Side: number, Half: number }
export type Rig = {
	Body: Part, -- the fish's box
	Low: Part, -- a flat box low behind it
	LowAt: CFrame, -- where, from the fish's middle
	Ribbon: Trail,
	RibbonA: Attachment,
	RibbonB: Attachment,
	Curls: { Curl }, -- left, right, and the glowing pair
	Haze: ParticleEmitter,
	Rolls: { ParticleEmitter }, -- left, right
	RollAt: { Attachment },
	Bubbles: ParticleEmitter,
	Storm: ParticleEmitter,
	Glow: ParticleEmitter,
	Rings: ParticleEmitter,
	RingAt: Attachment,
	Glints: ParticleEmitter,
	Fronts: { Beam },
	FrontAt: { Attachment }, -- nose and side, left and right
	Rates: { [ParticleEmitter]: number }, -- each layer's rate at whole speed (0: not in this step)
	RibbonsOn: { [Trail]: number }, -- each ribbon's life in this step (0: not in it)
	Dress: Dress?,
	Change: { [string]: any }, -- what its archetypes do to it
	On: boolean,
	Share: number, -- the last share of whole speed the rates were set for
	Gone: number, -- the last LocalTransparencyModifier set
	Drift: number, -- our own fish: the forward speed and life last set
	Far: number,
}

-- What a rig is dressed with
export type Dress = {
	Step: number,
	Size: Vector3, -- the body's width, height and length
	Main: Color3,
	Glow: Color3,
	Variant: string,
	Own: boolean, -- the fish we ride
	Back: number, -- our own fish: how far behind its middle the camera is, studs
	Rate: number, -- the level's
	Water: Color3,
	Archetypes: { string },
	Mark: string, -- all of it but Back and Water in one word: a rig is dressed again only when it changes
}

----------------------------------------------------------------------------------------------------------------------
-- Making

local function make(class: string, name: string, parent: Instance): any
	local thing = Instance.new(class)
	thing.Name = name
	thing.Parent = parent
	return thing
end

local function block(name: string, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.one
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.CFrame = CFrame.new(0, -5000, 0)
	part.Parent = parent
	return part
end

local function emitter(name: string, parent: Instance, picture: string): ParticleEmitter
	local e: ParticleEmitter = make("ParticleEmitter", name, parent)
	e.Enabled = false
	e.Rate = 0
	e.Texture = picture
	e.LightInfluence = 0
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	return e
end

local function ribbon(name: string, parent: Instance, a: Attachment, b: Attachment): Trail
	local t: Trail = make("Trail", name, parent)
	t.Enabled = false
	t.Attachment0 = a
	t.Attachment1 = b
	t.FaceCamera = true
	t.Texture = SOFT
	t.TextureMode = Enum.TextureMode.Stretch
	t.LightInfluence = 0
	t.MinLength = 0.4
	return t
end

function FishTrailRig.new(parent: Instance): Rig
	local body = block("Body", parent)
	local low = block("Low", parent)
	local ribbonA: Attachment = make("Attachment", "RibbonA", body)
	local ribbonB: Attachment = make("Attachment", "RibbonB", body)

	local curls: { Curl } = {}
	for i = 1, 4 do
		local a: Attachment = make("Attachment", "CurlA" .. i, body)
		local b: Attachment = make("Attachment", "CurlB" .. i, body)
		curls[i] = {
			Trail = ribbon("Curl" .. i, body, a, b),
			A = a,
			B = b,
			Side = if i % 2 == 1 then -1 else 1,
			Half = if i > 2 then math.pi else 0,
		}
	end

	local haze = emitter("Haze", low, SMOKE)
	haze.Rotation = NumberRange.new(0, 360)
	haze.RotSpeed = NumberRange.new(-30, 30)
	local rollAt: { Attachment }, rolls: { ParticleEmitter } = {}, {}
	for i = 1, 2 do
		rollAt[i] = make("Attachment", "RollAt" .. i, body)
		local roll = emitter("Roll" .. i, rollAt[i], SMOKE)
		roll.Rotation = NumberRange.new(0, 360)
		roll.RotSpeed = if i == 1 then NumberRange.new(60, 130) else NumberRange.new(-130, -60)
		roll.EmissionDirection = Enum.NormalId.Front
		roll.SpreadAngle = Vector2.new(14, 14)
		rolls[i] = roll
	end

	local bubbles = emitter("Bubbles", low, RING)
	local storm = emitter("Storm", body, RING)
	for _, e in { bubbles, storm } do
		e.Brightness = 3.5
		e.LightEmission = 0.4
		e.Color = ColorSequence.new(BUBBLE)
	end

	local glow = emitter("Glow", low, SOFT)
	glow.LightEmission = 0.9
	local ringAt: Attachment = make("Attachment", "RingAt", body)
	local rings = emitter("Rings", ringAt, RING)
	rings.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	rings.EmissionDirection = Enum.NormalId.Back
	rings.Speed = NumberRange.new(1)
	rings.SpreadAngle = Vector2.zero
	rings.Brightness = 3
	rings.LightEmission = 0.5
	local glints = emitter("Glints", body, STAR)
	glints.LightEmission = 1
	glints.Speed = NumberRange.new(0.5, 2)
	glints.SpreadAngle = Vector2.new(180, 180)

	local frontAt: { Attachment }, fronts: { Beam } = {}, {}
	for i = 1, 2 do
		local nose: Attachment = make("Attachment", "Nose" .. i, body)
		local side: Attachment = make("Attachment", "Side" .. i, body)
		frontAt[i * 2 - 1], frontAt[i * 2] = nose, side
		local beam: Beam = make("Beam", "Front" .. i, body)
		beam.Enabled = false
		beam.Attachment0 = nose
		beam.Attachment1 = side
		beam.FaceCamera = true
		beam.Segments = 12
		beam.Texture = SOFT
		beam.TextureMode = Enum.TextureMode.Stretch
		beam.TextureLength = 1
		beam.TextureSpeed = 0
		beam.LightInfluence = 0
		beam.LightEmission = 0.6
		beam.Brightness = 1.5
		fronts[i] = beam
	end

	return {
		Body = body,
		Low = low,
		LowAt = CFrame.identity,
		Ribbon = ribbon("Ribbon", body, ribbonA, ribbonB),
		RibbonA = ribbonA,
		RibbonB = ribbonB,
		Curls = curls,
		Haze = haze,
		Rolls = rolls,
		RollAt = rollAt,
		Bubbles = bubbles,
		Storm = storm,
		Glow = glow,
		Rings = rings,
		RingAt = ringAt,
		Glints = glints,
		Fronts = fronts,
		FrontAt = frontAt,
		Rates = {},
		RibbonsOn = {},
		Dress = nil,
		Change = {},
		On = false,
		Share = -1,
		Gone = 0,
		Drift = -1,
		Far = -1,
	}
end

----------------------------------------------------------------------------------------------------------------------
-- Dressing it for a fish

local function keys(...: number): NumberSequence
	local list = { ... }
	local points = {}
	for i = 1, #list, 2 do
		table.insert(points, NumberSequenceKeypoint.new(list[i], math.clamp(list[i + 1], 0, 100)))
	end
	return NumberSequence.new(points)
end

local function solid(see: number): NumberSequence
	return keys(0, 1, 0.12, 1 - see, 0.5, 1 - see * 0.65, 1, 1)
end

local function puff(
	rig: Rig,
	e: ParticleEmitter,
	p: FishTrails.Puff?,
	size: number,
	see: number,
	life: number,
	rate: number
)
	if not p then
		rig.Rates[e] = 0
		return
	end
	rig.Rates[e] = p.Rate * rate
	e.Lifetime = NumberRange.new(p.Life * life * 0.8, p.Life * life * 1.2)
	e.Size = NumberSequence.new(p.From * size, p.To * size)
	e.Transparency = solid(math.min(1, p.See * see))
end

local function ribbonOf(rig: Rig, t: Trail, r: FishTrails.Ribbon?, life: number, see: number)
	if not r then
		rig.RibbonsOn[t] = 0
		return
	end
	rig.RibbonsOn[t] = r.Life * life
	t.Lifetime = r.Life * life
	t.Transparency = keys(0, 1 - r.See * see, 0.55, 1 - r.See * see * 0.55, 1, 1)
	t.WidthScale = keys(0, 1, 1, 0.35)
end

-- The haze's colour: white water, toward the land's, then toward the fish's own
local function milk(d: Dress, own: number): Color3
	local water = d.Water
	local bright = math.clamp(water.R * 0.3 + water.G * 0.59 + water.B * 0.11, 0, 1)
	return WHITE:Lerp(water, FishTrails.Water + FishTrails.WaterDark * (1 - bright) ^ 2):Lerp(d.Main, own)
end

local function rainbow(): ColorSequence
	local points = {}
	for i, colour in FishTrails.Rainbow do
		points[i] = ColorSequenceKeypoint.new((i - 1) / (#FishTrails.Rainbow - 1), colour)
	end
	return ColorSequence.new(points)
end
local RAINBOW = rainbow()

local function changeOf(d: Dress): { [string]: any }
	local all: { [string]: any } = {}
	for _, id in d.Archetypes do
		for key, value in (FishTrails.Archetypes[id] or {}) :: { [string]: any } do
			all[key] = value
		end
	end
	return all
end

-- The colours alone (the water changes from land to land)
function FishTrailRig.colour(rig: Rig)
	local d = rig.Dress
	if not d then
		return
	end
	local recipe = FishTrails.Recipes[d.Step]
	local variant = FishTrails.Variants[d.Variant]
	local own = if variant then math.max(recipe.Own, FishTrails.VariantOwn) else recipe.Own
	local haze = milk(d, own)
	local change = rig.Change
	rig.Haze.Color = ColorSequence.new(haze:Lerp(WHITE, 0.25), haze)
	for _, roll in rig.Rolls do
		roll.Color = ColorSequence.new(haze)
	end
	rig.Rings.Color = ColorSequence.new(haze:Lerp(WHITE, 0.3))
	rig.Glow.Color = ColorSequence.new(d.Glow)
	rig.Glints.Color = ColorSequence.new(d.Glow:Lerp(WHITE, 0.35))
	local plain = d.Variant == "Rainbow"
	rig.Ribbon.Color = if plain then RAINBOW else ColorSequence.new(haze:Lerp(WHITE, 0.3), haze)
	rig.Ribbon.LightEmission = if d.Step >= 5 then 0.35 else 0.15
	for i, curl in rig.Curls do
		local edge: Color3 = change.Edge
			or (if i > 2 then d.Glow else haze:Lerp(d.Glow, 0.15 * math.max(0, d.Step - 3)))
		curl.Trail.Color = if plain then RAINBOW else ColorSequence.new(edge:Lerp(WHITE, 0.35), edge)
		curl.Trail.LightEmission = if i > 2 then 0.9 else 0.3
	end
	for _, beam in rig.Fronts do
		beam.Color = ColorSequence.new(WHITE, haze)
	end
end

function FishTrailRig.dress(rig: Rig, d: Dress)
	rig.Dress = d
	rig.Change = changeOf(d)
	rig.Share, rig.Drift, rig.Far = -1, -1, -1
	local recipe = FishTrails.Recipes[d.Step]
	local change = rig.Change
	local w, h, l = d.Size.X, d.Size.Y, d.Size.Z
	local across = math.sqrt(w * h)
	local size = math.min(FishTrails.PuffMost, FishTrails.PuffBase * (w * h) ^ FishTrails.PuffGrow)
	local see, life, rate = 1, 1, d.Rate
	local back = l / 2
	if d.Own then
		size = math.min(size, FishTrails.OwnPuff)
		see, life, rate = FishTrails.OwnSee, FishTrails.OwnLife, rate * FishTrails.OwnRate
		back = math.min(back, math.max(1, d.Back * FishTrails.OwnAt))
	end
	local thick = size * (change.Haze or 1)

	rig.Body.Size = Vector3.new(math.max(0.5, w * 0.9), math.max(0.5, h * 0.9), math.max(0.5, l * 0.9))
	rig.Low.Size =
		Vector3.new(math.max(1, w * (if d.Own then 1.5 else 1.1)), math.max(0.5, h * 0.25), math.max(1, size * 0.5))
	rig.LowAt = CFrame.new(0, -h * (if d.Own then 0.45 else 0.25), back)

	puff(rig, rig.Haze, recipe.Haze, thick, see, life, rate)
	puff(rig, rig.Bubbles, recipe.Bubbles, size, 1, if d.Own then life else 1, rate)
	puff(rig, rig.Storm, recipe.Storm, size, 1, if d.Own then life else 1, rate)
	puff(rig, rig.Glow, recipe.Glow, size, see, life, rate)
	puff(rig, rig.Rings, if d.Own then nil else recipe.Rings, size, 1, 1, rate)
	puff(rig, rig.Glints, if FishTrails.Variants[d.Variant] then FishTrails.Glints else nil, size, 1, 1, rate)
	for _, roll in rig.Rolls do
		puff(rig, roll, recipe.Roll, thick, see, life, rate / 2)
	end
	-- glow goes from bright to nothing, with no slow start
	if recipe.Glow then
		rig.Glow.Transparency = keys(0, 1 - recipe.Glow.See * see, 1, 1)
	end
	if recipe.Rings then
		rig.Rings.Transparency = keys(0, 1, 0.15, 1 - recipe.Rings.See, 1, 1)
	end

	-- the drift of what is thrown: left hanging in the water, or (our own fish) sent on with it (FishTrailRig.own)
	rig.Haze.EmissionDirection = if d.Own then Enum.NormalId.Front else Enum.NormalId.Back
	rig.Haze.Speed = NumberRange.new(1, 3 + size * 0.4)
	rig.Haze.SpreadAngle = if d.Own then Vector2.new(6, 12) else Vector2.new(25, 40)
	rig.Haze.Drag = if d.Own then 0 else 1.5
	rig.Haze.Acceleration = if d.Own then Vector3.new(0, -3, 0) else Vector3.new(0, 0.6, 0)
	rig.Glow.EmissionDirection = rig.Haze.EmissionDirection
	rig.Glow.Speed = NumberRange.new(0, 2)
	rig.Glow.SpreadAngle = Vector2.new(8, 8)
	local rise = Vector3.new(0, 4 + size * 0.5 + (change.Jet or 0), 0)
	for _, e in { rig.Bubbles, rig.Storm } do
		e.EmissionDirection = rig.Haze.EmissionDirection
		e.Speed = NumberRange.new(1, 3 + size)
		e.SpreadAngle = if d.Own then Vector2.new(8, 8) else Vector2.new(70, 70)
		e.Drag = if d.Own then 0 else 1
		e.Acceleration = rise
	end
	for i, at in rig.RollAt do
		local side = if i == 1 then -1 else 1
		local from = Vector3.new(side * w * 0.5, -h * 0.15, if d.Own then math.min(l * 0.15, back) else l * 0.15)
		at.CFrame = CFrame.lookAt(from, from + Vector3.new(side, -0.15, 0.35))
		rig.Rolls[i].Speed = NumberRange.new(size * 0.9, size * 1.6)
		rig.Rolls[i].Drag = if d.Own then 0 else 2
	end
	rig.RingAt.CFrame = CFrame.new(0, 0, l / 2)

	-- ribbons
	local long, wide = change.Life or 1, change.Wide or 1
	ribbonOf(rig, rig.Ribbon, recipe.Ribbon, long, if d.Own then FishTrails.OwnTail else 1)
	local half = math.clamp(recipe.Ribbon.Wide * wide * across, 0.4, 7) / 2
	rig.RibbonA.Position = Vector3.new(0, half, back)
	rig.RibbonB.Position = Vector3.new(0, -half, back)
	local curls = if d.Step >= (change.Curls or 0) then recipe.Curl else nil
	local curls2 = if d.Step >= (change.Curls or 0) then recipe.CurlGlow else nil
	for i, curl in rig.Curls do
		ribbonOf(rig, curl.Trail, if i > 2 then curls2 else curls, long, 1)
	end
	FishTrailRig.twist(rig, 0)

	-- the pressure front
	local front = recipe.Front
	if not front and change.Front and d.Step >= change.Front then
		front = FishTrails.Recipes[5].Front
	end
	for i, beam in rig.Fronts do
		rig.Fronts[i].Enabled = false
		if front then
			local side = if i == 1 then -1 else 1
			local out = w * 0.5 + across * 0.35
			local drop = if d.Own then -h * 0.25 else 0
			local nose, hip = rig.FrontAt[i * 2 - 1], rig.FrontAt[i * 2]
			nose.CFrame = CFrame.fromMatrix(Vector3.new(0, drop, -l / 2 - 0.4), Vector3.xAxis * side, Vector3.yAxis)
			hip.CFrame = CFrame.fromMatrix(Vector3.new(out * side, drop, -l * 0.05), Vector3.zAxis, Vector3.yAxis)
			beam.CurveSize0 = out * 0.9
			beam.CurveSize1 = l * 0.25
			beam.Width0 = front.Wide * across * 0.35
			beam.Width1 = front.Wide * across
			beam.Transparency = keys(0, 1, 0.18, 1 - front.See * see, 0.6, 1 - front.See * see * 0.6, 1, 1)
		end
		beam:SetAttribute("Here", front ~= nil)
	end
	FishTrailRig.colour(rig)
end

----------------------------------------------------------------------------------------------------------------------
-- Our own fish: what it throws is sent on at a share of its speed, so it slides back slowly beside it, and is gone before it
-- reaches the camera. Called a few times a second; sets nothing for a small change.
function FishTrailRig.own(rig: Rig, speed: number, back: number)
	local d = rig.Dress
	if
		not d
		or not d.Own
		or rig.Drift > 0 and math.abs(speed - rig.Drift) < rig.Drift * 0.1 and math.abs(back - rig.Far) < 2
	then
		return
	end
	rig.Drift, rig.Far = speed, back
	local recipe = FishTrails.Recipes[d.Step]
	local carry = math.max(1, speed * FishTrails.OwnCarry)
	local room = math.max(2, (back - rig.LowAt.Z) * (1 - FishTrails.OwnClear))
	local most = room / math.max(1, speed - carry)
	local function set(e: ParticleEmitter, p: FishTrails.Puff?, spread: number)
		if p then
			local life = math.min(p.Life * FishTrails.OwnLife, most)
			e.Lifetime = NumberRange.new(life * 0.75, life)
			e.Speed = NumberRange.new(carry * (1 - spread), carry)
		end
	end
	set(rig.Haze, recipe.Haze, 0.08)
	set(rig.Glow, recipe.Glow, 0.02)
	set(rig.Bubbles, recipe.Bubbles, 0.12)
	set(rig.Storm, recipe.Storm, 0.12)
	local w, h = d.Size.X, d.Size.Y
	for i, at in rig.RollAt do
		local side = if i == 1 then -1 else 1
		local dir = Vector3.new(side * math.min(16, 4 + w * 0.5), -math.min(4, h * 0.2), -carry)
		at.CFrame = CFrame.lookAt(at.Position, at.Position + dir)
		set(rig.Rolls[i], recipe.Roll, 0.05)
		rig.Rolls[i].Speed = NumberRange.new(dir.Magnitude)
		rig.Rolls[i].SpreadAngle = Vector2.new(3, 3)
	end
	-- its ribbons end before the camera too
	for trail, life in rig.RibbonsOn do
		if life > 0 then
			local at = if trail == rig.Ribbon then rig.LowAt.Z else 0
			trail.Lifetime = math.clamp((back - at) * (1 - FishTrails.OwnClear) / math.max(1, speed), 0.05, life)
		end
	end
end

----------------------------------------------------------------------------------------------------------------------
-- Each frame

-- Where the curls' ends are at this time
function FishTrailRig.twist(rig: Rig, now: number)
	local d = rig.Dress
	if not d then
		return
	end
	local recipe = FishTrails.Recipes[d.Step]
	local w, h, l = d.Size.X, d.Size.Y, d.Size.Z
	local across = math.sqrt(w * h)
	local change = rig.Change
	for i, curl in rig.Curls do
		local r = if i > 2 then recipe.CurlGlow else recipe.Curl
		if r and rig.RibbonsOn[curl.Trail] > 0 then
			local half = math.clamp(r.Wide * (change.Wide or 1) * across, 0.25, 4) / 2
			local middle = Vector3.new(curl.Side * (w * 0.5 + r.Round * across), -h * 0.05, l * 0.08)
			local out = Vector3.yAxis
			if r.Twist > 0 then
				local turn = (now * r.Twist * (change.Twist or 1) * TAU + curl.Half) * curl.Side
				out = Vector3.new(math.cos(turn), math.sin(turn), 0)
				middle += out * r.Round * across
			end
			curl.A.Position = middle + out * half
			curl.B.Position = middle - out * half
		end
	end
end

-- Whether it is thrown at all, and how strongly (0 to 1, the share of whole speed)
function FishTrailRig.strength(rig: Rig, share: number)
	local on = share > 0
	if on and rig.On and math.abs(share - rig.Share) < 0.06 then
		return
	end
	rig.On, rig.Share = on, share
	for e, rate in rig.Rates do
		e.Rate = rate * share
		e.Enabled = on and rate > 0
	end
	for trail, life in rig.RibbonsOn do
		trail.Enabled = on and life > 0
	end
	for _, beam in rig.Fronts do
		beam.Enabled = on and beam:GetAttribute("Here") == true
	end
end

-- How see-through all of it is, on top of its own (0 to 1)
function FishTrailRig.fade(rig: Rig, gone: number)
	if math.abs(gone - rig.Gone) < 0.02 and (gone > 0 or rig.Gone == 0) then
		return
	end
	rig.Gone = gone
	for e in rig.Rates do
		e.LocalTransparencyModifier = gone
	end
	for trail in rig.RibbonsOn do
		trail.LocalTransparencyModifier = gone
	end
	for _, beam in rig.Fronts do
		beam.LocalTransparencyModifier = gone
	end
end

-- Wipe the ribbons (a rig that goes to another fish draws no streak across to it)
function FishTrailRig.wipe(rig: Rig)
	for trail in rig.RibbonsOn do
		trail:Clear()
	end
end

-- A puff of bubbles
function FishTrailRig.burst(rig: Rig)
	local d = rig.Dress
	if not d then
		return
	end
	local p = FishTrails.Recipes[d.Step].Bubbles
	rig.Bubbles:Emit(math.max(2, math.ceil(p.Rate * p.Life * FishTrails.BurstShare * d.Rate)))
end

return FishTrailRig
