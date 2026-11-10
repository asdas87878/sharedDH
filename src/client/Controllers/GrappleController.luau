--!strict
-- The hook window (round 2, docs/design/riding-feel.md). Jumping off a fish (or the Hook button while floating) opens it
-- at once on our side for Grapple.AimTime real seconds; the server opens its own and owns the outcome. Our view slows
-- to Grapple.TimeScale (the camera, our float and the fish's tail beats; the world's physics doesn't change), easing in
-- over Grapple.SlowIn, and the colours cool and blur a little. The reticle snaps to the best fish in a Grapple.Cone cone
-- out to Grapple.Range and holds it (sticky). One shot: on a fish, the hook flies out over Grapple.FlyTime and we reel in
-- over Grapple.ReelTime on an ease-in curve, aimed at where the saddle will be when we arrive (re-aimed every frame),
-- the last Grapple.Blend seconds blending position and turn onto it; the slow-mo eases back over Grapple.SlowOut. A shot
-- at nothing, or the window running out, is a miss: the eater (DeathController) takes over.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Net = require(ReplicatedStorage.Shared.Net)
local Actions = require(script.Parent.Parent.Lib.Actions)
local Fx = require(script.Parent.Parent.Lib.Fx)
local State = require(script.Parent.Parent.Lib.State)
local RideController = require(script.Parent.RideController)

local GrappleController = {}

local tint: ColorCorrectionEffect
local blur: BlurEffect

local rope: Fx.Rope? = nil
local target: Model? = nil
local firedAt = 0
local holdAt: CFrame? = nil -- where we hang while the hook flies
local wasAiming = false
local leftAimAt = -math.huge -- os.clock() the window ended (the shot, or the miss)
local leftScale = 1 -- the time scale then
local others: { [Player]: Fx.Rope } = {}

local function stopRope()
	if rope then
		rope:Stop()
		rope = nil
	end
	target = nil
	holdAt = nil
end

local function beginAim(): boolean
	local mode = State.Mode
	if mode ~= "Riding" and mode ~= "Free" then
		return false
	end
	if mode == "Riding" then
		RideController.coast(State.Fish)
		State.Fish = nil
		RideController.pop()
	end
	Net.Action:FireServer("JumpOff")
	State.AimEnds = os.clock() + Config.Grapple.AimTime
	State.AimTarget = nil
	State.setMode("Aiming")
	return true
end

-- A shot at nothing or the window running out: tell the server at once, and the eater comes
local function miss()
	Net.Action:FireServer("Grapple", nil)
	State.AimTarget = nil
	State.setMode("Eaten")
end

local function fire(): boolean
	if State.Mode ~= "Aiming" then
		return false
	end
	local fish = State.AimTarget
	local character, root = State.character()
	if not fish or not character or not root then
		miss()
		return true
	end
	local g = Config.Grapple
	Net.Action:FireServer("Grapple", fish)
	stopRope()
	target = fish
	rope = Fx.rope(character, fish, g.FlyTime)
	firedAt = os.clock()
	holdAt = root.CFrame
	State.AimTarget = nil
	State.setMode("Grappling")
	return true
end

local function saddleOf(fish: Model?): CFrame?
	local fishRoot = fish and fish.PrimaryPart
	local saddle = fishRoot and fishRoot:FindFirstChild("Saddle")
	if saddle and saddle:IsA("Attachment") then
		return saddle.WorldCFrame
	end
	return nil
end

-- The slow-mo: eases in while aiming, and back to 1x over SlowOut from the shot (or Death.Darken from a miss)
local function timeScaleStep(dt: number)
	local g = Config.Grapple
	local aiming = State.Mode == "Aiming"
	if aiming then
		wasAiming = true
		State.TimeScale = math.max(g.TimeScale, State.TimeScale - (1 - g.TimeScale) * dt / g.SlowIn)
	else
		if wasAiming then
			wasAiming = false
			leftAimAt = os.clock()
			leftScale = State.TimeScale
		end
		local length = if State.Mode == "Eaten" then Config.Death.Darken else g.SlowOut
		local u = (os.clock() - leftAimAt) / length
		State.TimeScale = Ease.lerp(leftScale, 1, Ease.smoothstep(0, 1, u))
	end
	local slow = (1 - State.TimeScale) / (1 - g.TimeScale)
	tint.Saturation = -0.35 * slow
	tint.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(200, 230, 255), slow)
	blur.Size = 6 * slow
end

local function step(dt: number)
	timeScaleStep(dt)
	local mode = State.Mode
	local _, root = State.character()
	local g = Config.Grapple

	if mode == "Aiming" then
		if root then
			State.AimTarget = State.bestInCone(
				root.Position,
				workspace.CurrentCamera.CFrame.LookVector,
				g.Range,
				g.Cone,
				0.15,
				State.AimTarget,
				g.Sticky
			)
		end
		if os.clock() >= State.AimEnds then
			miss()
		end
		return
	end

	if mode ~= "Grappling" or not root then
		return
	end
	local goal = saddleOf(target)
	local t = os.clock()
	if not goal or t > firedAt + g.FlyTime + g.ReelTime + 1.5 then
		-- the fish went, or the server never answered: its state takes over
		stopRope()
		return
	end
	local hold = holdAt or root.CFrame
	local reelStart = firedAt + g.FlyTime
	if t < reelStart then -- the hook is still flying: hang where we fired, turning to the fish
		root.CFrame = CFrame.lookAt(hold.Position, goal.Position)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		return
	end
	local u = math.clamp((t - reelStart) / g.ReelTime, 0, 1)
	-- aim at where the saddle will be on arrival
	local fishRoot = (target :: Model).PrimaryPart
	local fishVelocity = if fishRoot then fishRoot.AssemblyLinearVelocity else Vector3.zero
	local arriveIn = math.max(0, reelStart + g.ReelTime - t)
	local predicted = goal.Position + fishVelocity * arriveIn
	local start = hold.Position
	local position = start:Lerp(predicted, Ease.inQuad(u))
	local towards = predicted - position
	local lean = (1 - Ease.smoothstep(0.6, 1, u)) * math.rad(70)
	local body = if towards.Magnitude > 0.1
		then CFrame.lookAt(position, predicted) * CFrame.Angles(-lean, 0, 0)
		else goal
	-- the last part blends position and turn onto the saddle itself
	local blendFrom = 1 - g.Blend / g.ReelTime
	body = body:Lerp(goal, Ease.smoothstep(blendFrom, 1, u))
	root.CFrame = body
	local speed = 2 * u * (predicted - start).Magnitude / g.ReelTime
	root.AssemblyLinearVelocity = if u < 1 and towards.Magnitude > 0.1
		then towards.Unit * speed + fishVelocity * u
		else fishVelocity
	root.AssemblyAngularVelocity = Vector3.zero
	State.Speed = if u < 1 then speed else fishVelocity.Magnitude
end

function GrappleController.Init()
	Actions.beginAim = beginAim
	Actions.fire = fire

	tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "GrappleSlowMo"
	tint.Parent = Lighting
	blur = Instance.new("BlurEffect")
	blur.Name = "GrappleSlowMo"
	blur.Size = 0
	blur.Parent = Lighting

	Net.Ride.OnClientEvent:Connect(function(kind: string, a: any)
		if kind == "Mounted" or (kind == "Dismounted" and a == "Lost") then
			stopRope()
		elseif kind == "Denied" and a == "Grapple" then
			-- the server wouldn't allow the shot: that's a miss, and it has already sent the eater
			stopRope()
			if State.Mode == "Grappling" or State.Mode == "Aiming" then
				State.setMode("Eaten")
			end
		end
	end)
	Net.Fx.OnClientEvent:Connect(function(kind: string, player: Player, fish: Model, flyTime: number?, reel: number?)
		if kind ~= "Grapple" or player == State.Player or typeof(player) ~= "Instance" then
			return
		end
		local character = player.Character
		if not character or typeof(fish) ~= "Instance" then
			return
		end
		local old = others[player]
		if old then
			old:Stop()
		end
		local fly = flyTime or Config.Grapple.FlyTime
		local other = Fx.rope(character, fish, fly)
		others[player] = other
		task.delay(fly + (reel or Config.Grapple.ReelTime) + 0.05, function()
			if others[player] == other then
				others[player] = nil
			end
			other:Stop()
		end)
	end)
	State.ModeChanged.Event:Connect(function(mode: string)
		if mode ~= "Grappling" and rope then
			stopRope()
		end
	end)
end

function GrappleController.Start()
	RunService:BindToRenderStep("RideGrapple", Enum.RenderPriority.Camera.Value - 4, step)
end

return GrappleController
