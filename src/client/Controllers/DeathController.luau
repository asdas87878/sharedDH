--!strict
-- Drowning (docs/design/riding-feel.md), procedural, played on every client from the server's State, DeathAt and
-- DeathThrown attributes, so friends see it too; the local victim also gets the camera, the dark and the fade. It takes
-- no input; the server sends the victim to the dock when the time is up.
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
local Fx = require(script.Parent.Parent.Lib.Fx)
local State = require(script.Parent.Parent.Lib.State)

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
	Bubbles: ParticleEmitter?,
	LastBubble: boolean,
	Sink: number,
}

local deaths: { [Player]: Death } = {}
local throwDirs: { [Player]: Vector3 } = {} -- from the ThrowOff Fx: which way the fish was swimming
local darken: ColorCorrectionEffect

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
		return if State.dying() then State.Mode else nil
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
	local d: Death = {
		Kind = kind,
		Start = start,
		Thrown = player:GetAttribute("DeathThrown") == true,
		Struggle = if player:GetAttribute("DeathQuick") == true
			then Config.Death.MissStruggle
			else Config.Death.Struggle,
		Character = character,
		At = root.CFrame,
		Look = look,
		Back = throwDirs[player] or -look,
		CamFrom = root.Position + flat(camera.Position - root.Position) * 15 + Vector3.new(0, 6, 0),
		Bubbles = nil,
		LastBubble = false,
		Sink = 0,
	}
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
	local throwT = if d.Thrown then c.Throw else 0
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
	local start = d.At.Position
	local thrownTo = start
		+ d.Back * (if d.Thrown then c.ThrowBack else 0)
		+ Vector3.new(0, if d.Thrown then 2 else 0, 0)
	local face = -d.Back -- looking back at the fish
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
		local position = thrownTo + Vector3.new(0, bob - d.Sink, 0)
		local sway = math.sin(tt * 4) * math.rad(10) * (1 - weak)
		frame = CFrame.lookAt(position, position + face) * CFrame.Angles(math.rad(20) + limp * math.rad(30), 0, sway)
	end
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
		State.FadeText = "OUT OF AIR!"
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
			drownStep(player, d, clock - d.Start, dt)
		end
	end
	for player, d in deaths do
		if player.Parent == nil then
			finish(player, d)
			deaths[player] = nil
		end
	end

	-- back from a death: the black lifts
	if not State.dying() and State.Fade > 0 then
		State.Fade = math.max(0, State.Fade - dt / 0.8)
		if State.Fade <= 0 then
			State.FadeText = ""
		end
	end
	local dark = State.Darken
	darken.Brightness = -0.28 * dark
	darken.Contrast = 0.2 * dark
	darken.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(140, 165, 205), dark)
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
