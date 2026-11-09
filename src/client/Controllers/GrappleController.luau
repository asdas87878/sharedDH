--!strict
-- The grapple: jumping off a fish (or the Hook button while floating) opens an aim window of Grapple.AimTime real
-- seconds. Our own view slows to Grapple.TimeScale (the camera, our float and the fish's tail beats; the world's physics
-- doesn't change), the colours cool and blur a little, and the reticle snaps to the fish nearest the aim in a
-- Grapple.Cone cone out to Grapple.Range. Fire, the hook flies out on its rope, and once the server agrees we reel in,
-- speeding up, onto the fish's saddle. The server mounts us at the end and refills Oxygen, as for a dash.
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
local holdAt: CFrame? = nil -- where we wait while the hook flies
local reelFrom: Vector3? = nil
local reelStart = math.huge
local reelTime = Config.Grapple.ReelTime
local others: { [Player]: Fx.Rope } = {}

local function stopRope()
	if rope then
		rope:Stop()
		rope = nil
	end
	target = nil
	holdAt = nil
	reelFrom = nil
	reelStart = math.huge
end

local function beginAim(): boolean
	local mode = State.Mode
	if (mode ~= "Riding" and mode ~= "Free") or os.clock() < State.GrappleReadyAt then
		return false
	end
	if mode == "Riding" then
		Net.Action:FireServer("JumpOff")
		State.Fish = nil
		RideController.pop()
	end
	State.AimEnds = os.clock() + Config.Grapple.AimTime
	State.AimTarget = nil
	State.setMode("Aiming")
	return true
end

local function fire(): boolean
	local fish = State.AimTarget
	local character, root = State.character()
	if State.Mode ~= "Aiming" or not fish or not character or not root then
		return false
	end
	local g = Config.Grapple
	Net.Action:FireServer("Grapple", fish)
	stopRope()
	target = fish
	rope = Fx.rope(character, fish, g.FlyTime)
	firedAt = os.clock()
	holdAt = root.CFrame
	State.GrappleReadyAt = firedAt + g.FlyTime + g.ReelTime + g.Cooldown
	State.AimTarget = nil
	State.setMode("Grappling")
	return true
end

local function endAimMiss()
	State.AimTarget = nil
	local server = State.Player:GetAttribute("State")
	State.setMode(if server == "Dock" or server == "PassedOut" then server else "Free")
end

local function saddleOf(fish: Model?): CFrame?
	local fishRoot = fish and fish.PrimaryPart
	local saddle = fishRoot and fishRoot:FindFirstChild("Saddle")
	if saddle and saddle:IsA("Attachment") then
		return saddle.WorldCFrame
	end
	return nil
end

local function step(dt: number)
	local mode = State.Mode
	local _, root = State.character()

	-- the slow-mo eases in fast and out a touch slower (real time)
	local aiming = mode == "Aiming"
	local goalScale = if aiming then Config.Grapple.TimeScale else 1
	State.TimeScale = Ease.lerp(State.TimeScale, goalScale, Ease.alpha(if aiming then 18 else 10, dt))
	local slow = (1 - State.TimeScale) / (1 - Config.Grapple.TimeScale)
	tint.Saturation = -0.35 * slow
	tint.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(200, 230, 255), slow)
	blur.Size = 6 * slow

	if aiming and root then
		local g = Config.Grapple
		State.AimTarget =
			State.bestInCone(root.Position, workspace.CurrentCamera.CFrame.LookVector, g.Range, g.Cone, 0.15)
		if os.clock() >= State.AimEnds then
			endAimMiss()
		end
		return
	end

	if mode ~= "Grappling" or not root then
		return
	end
	local goal = saddleOf(target)
	local t = os.clock()
	if not goal or t > firedAt + Config.Grapple.FlyTime + reelTime + 1.5 then
		stopRope()
		endAimMiss()
		return
	end
	if t < reelStart then -- the hook is still flying (or the server hasn't said yes yet): hang where we fired
		local hold = holdAt or root.CFrame
		root.CFrame = CFrame.lookAt(hold.Position, goal.Position)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		return
	end
	local start = reelFrom or root.Position
	reelFrom = start
	local u = math.clamp((t - reelStart) / reelTime, 0, 1)
	local e = Ease.inQuad(u)
	local position = start:Lerp(goal.Position, e)
	local towards = goal.Position - position
	local lean = (1 - Ease.smoothstep(0.75, 1, u)) * math.rad(70)
	local body = if towards.Magnitude > 0.1
		then CFrame.lookAt(position, goal.Position) * CFrame.Angles(-lean, 0, 0)
		else goal
	if u > 0.85 then
		body = body:Lerp(goal, (u - 0.85) / 0.15)
	end
	root.CFrame = body
	local speed = 2 * u * (goal.Position - start).Magnitude / reelTime
	root.AssemblyLinearVelocity = if towards.Magnitude > 0.1 then towards.Unit * speed else Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	State.Speed = speed
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

	Net.Ride.OnClientEvent:Connect(function(kind: string, a: any, b: any, c: any)
		if kind == "GrappleStart" then
			if State.Mode ~= "Grappling" or a ~= target then
				-- the server agreed to a grapple we'd given up on: follow it anyway
				local character, root = State.character()
				if not character or not root then
					return
				end
				stopRope()
				target = a
				rope = Fx.rope(character, a, b)
				firedAt = os.clock()
				holdAt = root.CFrame
				State.setMode("Grappling")
			end
			reelTime = if type(c) == "number" then c else Config.Grapple.ReelTime
			reelStart = math.max(os.clock(), firedAt + (if type(b) == "number" then b else Config.Grapple.FlyTime))
		elseif kind == "Mounted" or (kind == "Dismounted" and a == "Lost") then
			stopRope()
		elseif kind == "Denied" and a == "Grapple" then
			stopRope()
			if State.Mode == "Grappling" then
				endAimMiss()
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
