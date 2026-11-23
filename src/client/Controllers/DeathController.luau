--!strict
-- Drowning (docs/design/riding-feel.md), procedural, played on every client from the server's State, DeathAt and
-- DeathThrown attributes, so friends see it too; the local victim also gets the camera, the dark and the fade. It takes
-- no input; the server sends the victim to the dock when the time is up. That is the fail (Hugo, 2026-11-18): it fades
-- out (Death.DrownFade), the black holds at the dock (Death.HoldBlack) and lifts (Death.FadeIn); the dive's catch is
-- kept (RideService). With Death.On 0 or the sandbox's NoFail there is none: you are left floating.
--   Out of Oxygen on a fish, it bucks and throws you up and back, tumbling (Death.Throw; the buck itself is
--   AnimController's, on the fish), then you struggle with a steady stream of bubbles from the mouth (Death.Struggle),
--   weaken as they thin out (Death.Weak), go still and sink with the last bubble (Death.Still), and it fades out. A jump
--   that comes down on nothing drowns the same way, without the throw.
-- The local victim's client moves its own root (it owns the character), so the throw and the sink replicate.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Net = require(ReplicatedStorage.Shared.Net)
local Course = require(script.Parent.Parent.Lib.Course)
local Fx = require(script.Parent.Parent.Lib.Fx)
local Shake = require(script.Parent.Parent.Lib.Shake)
local State = require(script.Parent.Parent.Lib.State)
local Underwater = require(script.Parent.Parent.Lib.Underwater)

local DeathController = {}

type Death = {
	Kind: string,
	Start: number, -- os.clock() it began here
	Thrown: boolean,
	Struggle: number, -- how long the struggle lasts (short after a jump that sank)
	Character: Model,
	At: CFrame, -- the victim's root when it began
	Look: Vector3, -- the victim's flat heading then
	Back: Vector3, -- the throw's flat direction
	CamFrom: Vector3, -- where the drowning shot watches from
	CamOffset: Vector3, -- a loose body's shot: where it starts, off the body
	CamAt: Vector3?, -- and where it is: held, turning to follow, only drawn after it past 34 studs
	Bubbles: ParticleEmitter?,
	LastBubble: boolean,
	Sink: number,
	-- thrown as a ragdoll (Config.Fail.Ragdoll, FailController): the seconds it still flies loose as this begins (the
	-- throw is the physics', not ours), and the body's turn as it got its joints back, eased out of
	Loose: number?,
	Settle: CFrame?,
	-- (Death.UnderWater) when the drown took the body over (seconds in), the speed it carried on, the way it has been
	-- moved out off the strip, and the height it was eased down from
	SettleAt: number,
	Carry: Vector3,
	Carried: Vector3,
	Shift: Vector3,
	TopFrom: number,
	Under: boolean,
}

local deaths: { [Player]: Death } = {}
local throwDirs: { [Player]: Vector3 } = {} -- from the ThrowOff Fx: which way the fish was swimming
local darken: ColorCorrectionEffect
local blackSince: number? = nil -- os.clock() the death ended with the screen still black (Death.HoldBlack)

local function flat(v: Vector3): Vector3
	local f = v * Vector3.new(1, 0, 1)
	return if f.Magnitude > 0.01 then f.Unit else Vector3.new(0, 0, -1)
end

local function rootOf(character: Model?): BasePart?
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- The death a player is in: ours from our own Mode
local function kindOf(player: Player): string?
	if player == State.Player then
		-- (a fail's outcome, "Failing", is FailController's; only its drown after is ours)
		return if State.Mode == "Drowning" then State.Mode else nil
	end
	local state = player:GetAttribute("State")
	return if state == "Drowning" then state else nil
end

local function begin(player: Player, kind: string): Death?
	local character = player.Character
	local root = rootOf(character)
	if not character or not root then
		return nil
	end
	-- the server's start, if it said so already; else now
	local start = os.clock()
	local at = player:GetAttribute("DeathAt")
	if type(at) == "number" then
		start = math.min(start, os.clock() - math.max(0, workspace:GetServerTimeNow() - at))
	end
	local camera = workspace.CurrentCamera.CFrame
	local look = flat(root.CFrame.LookVector)
	local thrown = player:GetAttribute("DeathThrown") == true
	local left = player:GetAttribute("DeathLoose")
	local ragdolled = thrown and type(left) == "number"
	-- (after a fail's own shot the camera stays where it is: one move, held, no second swing; FailController)
	local fromFail = player == State.Player and State.DeathCam ~= nil
	local d: Death =
		{
			Kind = kind,
			Start = start,
			Thrown = thrown,
			Struggle = if player:GetAttribute("DeathQuick") == true
				then Config.Death.MissStruggle
				else Config.Death.Struggle,
			Character = character,
			At = root.CFrame,
			Look = look,
			Back = throwDirs[player] or -look,
			CamFrom = if fromFail
				then camera.Position
				else root.Position
					+ flat(camera.Position - root.Position) * (if ragdolled then 24 else 15)
					+ Vector3.new(0, if ragdolled then 8 else 6, 0),
			Bubbles = nil,
			LastBubble = false,
			Sink = 0,
			Loose = if ragdolled then left :: number else nil,
			Settle = nil,
			CamOffset = Vector3.zero,
			CamAt = nil,
			SettleAt = 0,
			Carry = Vector3.zero,
			Carried = Vector3.zero,
			Shift = Vector3.zero,
			TopFrom = root.Position.Y,
			Under = Underwater.on(),
		}
	if ragdolled then
		-- a loose body is followed, from the side the shot already is, no further than 26 studs (one push in, eased
		-- by the camera)
		local away = camera.Position - root.Position
		local length = math.clamp(away.Magnitude, 14, 26)
		local dir = if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 0.3, 1).Unit
		if not fromFail then
			-- a plain throw goes back the way we came, at the camera behind us: the shot is taken from the side of
			-- it instead (the side the camera was on), so the body crosses the frame
			local side = d.Back:Cross(Vector3.yAxis)
			side = if side.Magnitude > 0.01 then side.Unit else Vector3.xAxis
			if side:Dot(away) < 0 then
				side = -side
			end
			dir = (side + d.Back * 0.35 + Vector3.new(0, 0.4, 0)).Unit
			length = 30
		end
		d.CamOffset = dir * length
	end
	throwDirs[player] = nil
	d.Bubbles = Fx.mouthBubbles(character)
	State.DeathStart[player] = start
	State.DeathThrown[player] = d.Thrown
	State.DeathStruggle[player] = d.Struggle
	return d
end

local function finish(player: Player, d: Death)
	if d.Bubbles then
		local mouth = d.Bubbles.Parent
		d.Bubbles.Enabled = false
		task.delay(2.5, function()
			if mouth then
				mouth:Destroy()
			end
		end)
		d.Bubbles = nil
	end
	State.DeathStart[player] = nil
	State.DeathThrown[player] = nil
	State.DeathStruggle[player] = nil
	if player == State.Player then
		State.DeathCam = nil
		State.Darken = 0
		State.Vignette = 0
	end
end

local function drownStep(player: Player, d: Death, t: number, dt: number)
	local c = Config.Death
	local mine = player == State.Player
	local throwT = if d.Thrown then (d.Loose or c.Throw) else 0
	local tt = t - throwT -- into the drown proper
	local s, w, still = d.Struggle, c.Weak, c.Still

	-- the bubbles from the mouth: steady, thinning, then the last one
	local bubbles = d.Bubbles
	if bubbles then
		if tt < 0 then
			bubbles.Rate = 6
		elseif tt < s then
			bubbles.Rate = 14
		elseif tt < s + w then
			bubbles.Rate = Ease.lerp(14, 1.5, (tt - s) / w)
		else
			bubbles.Rate = 0
			if not d.LastBubble and tt >= s + w + still * 0.4 then
				d.LastBubble = true
				bubbles:Emit(1)
			end
		end
	end

	if not mine then
		return
	end
	local _, root = State.character()
	if not root then
		return
	end
	local total = throwT + s + w + still
	if t >= total - 0.15 then
		-- done: hold still in the black and leave the root alone for the server's move to the dock
		root.AssemblyLinearVelocity = Vector3.zero
		State.Fade = 1
		return
	end
	-- (Death.UnderWater: the body still loose, its joints not back yet, a moment longer: never moved by us while the
	-- physics still has it)
	local loose = d.Loose ~= nil and tt < 0
	if d.Loose and d.Under and not d.Settle and not loose then
		loose = d.Character:GetAttribute("Ragdoll") ~= nil and tt < c.HandWait
	end
	if loose then
		-- flying loose: the physics has the body (FailController); only the shot follows it
		-- held where it is, turning to follow the body, so the throw is seen to go; drawn after it only when far
		local at = d.CamAt or (root.Position + d.CamOffset)
		local off = at - root.Position
		if off.Magnitude > 34 then
			at = root.Position + off.Unit * 34
		end
		d.CamAt = at
		State.DeathCam = {
			Position = at,
			Focus = root.Position + Vector3.new(0, 1, 0),
		}
		State.Vignette = 0
		State.Darken = 0.35 * Ease.smoothstep(throwT, total, t)
		return
	end
	if d.Loose and not d.Settle then
		-- the joints are back: the drown goes on from where the body came to rest, turning upright gently, and the
		-- shot stays where it was following from
		d.CamFrom = d.CamAt or (root.Position + d.CamOffset)
		d.At = root.CFrame
		d.Settle = root.CFrame.Rotation
		d.Back = Vector3.zero
		d.Look = flat(root.CFrame.LookVector)
		d.SettleAt = t
		d.Carry = if d.Under then root.AssemblyLinearVelocity else Vector3.zero
		d.TopFrom = root.Position.Y
	end
	local since = t - d.SettleAt
	if d.Under then
		-- the body's own speed carried on, dying away (no stop dead as the joints come back)
		d.Carried += d.Carry * dt
		d.Carry *= math.exp(-c.Carry * dt)
	end
	local start = d.At.Position
	local thrownTo = start
		+ d.Back * (if d.Thrown then c.ThrowBack else 0)
		+ Vector3.new(0, if d.Thrown and not d.Loose then 2 else 0, 0)
	local face = if d.Loose then d.Look else -d.Back -- looking back at the fish
	local frame: CFrame
	if tt < 0 then
		-- up and back, a full backflip, landing tilted back
		local u = t / throwT
		local e = Ease.outQuad(u)
		local position = start:Lerp(thrownTo, e) + Vector3.new(0, 4 * math.sin(math.pi * math.min(1, u * 1.15)), 0)
		local flip = (math.pi * 2 + math.rad(20)) * (1 - (1 - u) ^ 3)
		frame = CFrame.lookAt(position, position + face) * CFrame.Angles(flip, 0, math.rad(25) * math.sin(math.pi * u))
	else
		-- sinking slowly, then faster as they go limp, tilting back
		local weak = Ease.smoothstep(s, s + w, tt)
		local limp = Ease.smoothstep(s + w * 0.5, s + w + still, tt)
		local speed = Ease.lerp(0.5, 1.4, weak) + 0.8 * limp
		d.Sink += speed * dt
		local bob = math.sin(tt * 6) * 0.35 * (1 - weak)
		if d.Under then
			bob *= Ease.smoothstep(0, math.max(c.Upright, 0.05), since)
		end
		local position = thrownTo + Vector3.new(0, bob - d.Sink, 0)
		local sway = math.sin(tt * 4) * math.rad(10) * (1 - weak)
		frame = CFrame.lookAt(position, position + face) * CFrame.Angles(math.rad(20) + limp * math.rad(30), 0, sway)
		if d.Settle then
			-- (Death.UnderWater: turned upright from the moment it was taken over, not from the throw's planned end)
			local turn = if d.Under
				then Ease.smoothstep(0, math.max(c.Upright, 0.05), since)
				else Ease.smoothstep(0, 0.6, tt)
			frame = CFrame.new(frame.Position) * d.Settle:Lerp(frame.Rotation, turn)
		end
	end
	if d.Under then
		-- (Death.UnderWater) under the water: the carried speed, moved out off the strip, and kept Death.UnderBy under
		-- Oxygen.SurfaceY, eased down there from where it was over Death.SinkIn (never a snap)
		local position = frame.Position + d.Carried
		local out = Underwater.outward()
		if out and Underwater.groundAbove(position + d.Shift) and position.Y > Config.Depth.SurfaceY - c.StripDepth then
			d.Shift += out * c.StripOut * dt
		end
		position += d.Shift
		local top = Underwater.top()
		local cap = Ease.lerp(math.max(d.TopFrom, top), top, Ease.smoothstep(0, math.max(c.SinkIn, 0.05), since))
		if position.Y > cap then
			position = Vector3.new(position.X, cap, position.Z)
		end
		frame = CFrame.new(position) * frame.Rotation
	end
	-- (never into the floor or through a wall: the throw and the sink kept in open water, and the sinking stops on
	-- the floor, the body lying there)
	local kept = Course.clearMove(root.Position, frame.Position, 2.2)
	if kept.Y > frame.Position.Y + 0.05 then
		d.Sink = math.max(0, d.Sink - (kept.Y - frame.Position.Y))
	end
	frame = CFrame.new(kept) * frame.Rotation
	root.CFrame = frame
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero

	State.DeathCam = {
		Position = d.CamFrom + Vector3.new(0, t * 0.8, 0),
		Focus = root.Position + Vector3.new(0, 1, 0),
	}
	State.Vignette = math.clamp((t - throwT) / (s + w + still), 0, 1)
	State.Darken = 0.35 * Ease.smoothstep(throwT, total, t)
	local fadeFrom = total - 0.15 - c.DrownFade
	if t >= fadeFrom then
		State.Fade = math.clamp((t - fadeFrom) / c.DrownFade, 0, 1)
		State.FadeText = if State.Player:GetAttribute("DeathQuick") == true
			then "MISSED THE FISH!"
			else Config.Fail.Breath
	end
end

local function step(dt: number)
	local clock = os.clock()
	for _, player in Players:GetPlayers() do
		local kind = kindOf(player)
		local d: Death? = deaths[player]
		if d and (kind ~= d.Kind or d.Character ~= player.Character) then
			finish(player, d)
			deaths[player] = nil
			d = nil
		end
		if kind and not d then
			d = begin(player, kind)
			deaths[player] = d
		end
		if d then
			-- (Studio only, for capturing it frame by frame: workspace's DeathClock, seconds into the drown)
			local held = if RunService:IsStudio() then workspace:GetAttribute("DeathClock") else nil
			drownStep(player, d, if type(held) == "number" and held >= 0 then held else clock - d.Start, dt)
		end
	end
	for player, d in deaths do
		if player.Parent == nil then
			finish(player, d)
			deaths[player] = nil
		end
	end

	-- back from a death (the fail: Config.Death): the black holds a moment at the dock, so the move home isn't seen,
	-- then lifts
	if State.dying() then
		blackSince = nil
	elseif State.Fade > 0 then
		blackSince = blackSince or clock
	end
	local held = blackSince ~= nil and clock - (blackSince :: number) >= Config.Death.HoldBlack
	if not State.dying() and State.Fade > 0 and held then
		State.Fade = math.max(0, State.Fade - dt / math.max(Config.Death.FadeIn, 0.05))
		if State.Fade <= 0 then
			State.FadeText = ""
		end
	end
	local dark = State.Darken
	darken.Brightness = -0.28 * dark
	darken.Contrast = 0.2 * dark
	darken.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(140, 165, 205), dark)
end

-- Test hook: only the Studio checks call this (tools/studio/fail_eat_check.py). The drown playing for `player` now, as
-- plain values (nil: none): whether the drown has taken the body over yet, when, and the height it is kept under.
function DeathController.probe(player: Player): { [string]: any }?
	local d = deaths[player]
	if not d then
		return nil
	end
	return {
		Kind = d.Kind,
		Thrown = d.Thrown,
		Loose = d.Loose,
		Settled = d.Settle ~= nil,
		SettleAt = d.SettleAt,
		TopFrom = d.TopFrom,
		Top = Underwater.top(),
		Shift = d.Shift,
		Under = d.Under,
		Ragdoll = d.Character:GetAttribute("Ragdoll") ~= nil,
	}
end

function DeathController.Init()
	darken = Instance.new("ColorCorrectionEffect")
	darken.Name = "DeathDarken"
	darken.Parent = Lighting
	Net.Fx.OnClientEvent:Connect(function(kind: string, player: Player, fish: Model)
		if kind ~= "ThrowOff" or typeof(player) ~= "Instance" or typeof(fish) ~= "Instance" then
			return
		end
		local root = fish.PrimaryPart
		if root then
			State.Buck[fish] = os.clock()
			if player == State.Player then
				Shake.play("Thrown")
			end
			-- thrown back the way the fish came, so it swims on out from under you
			throwDirs[player] = -flat(root.CFrame.LookVector)
			Fx.sound("Splash", root)
		end
	end)
end

function DeathController.Start()
	RunService:BindToRenderStep("RideDeath", Enum.RenderPriority.Camera.Value - 3, step)
end

return DeathController
