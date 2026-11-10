--!strict
-- The corkscrew dash, fish to fish: picks the fish ahead (within Dash.Range, in a Dash.Cone cone round the fish's heading,
-- or the camera's while floating) for the HUD to mark, asks the server, and on its go swims the character there along a
-- bowed path, rolling Dash.Spins turns round the line of travel on a spiral that opens and closes, head first like a
-- swimmer, easing in and out. The path ends where the saddle will be when we arrive (re-aimed every frame), and the
-- last Dash.Blend seconds blend position and turn onto the saddle, so nothing snaps. The server mounts us when the time
-- is up (and refills Oxygen); the landing ring, bubble burst and squash come from its Fx "Land" for everyone.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Net = require(ReplicatedStorage.Shared.Net)
local Actions = require(script.Parent.Parent.Lib.Actions)
local Fx = require(script.Parent.Parent.Lib.Fx)
local State = require(script.Parent.Parent.Lib.State)
local RideController = require(script.Parent.RideController)

local DashController = {}

local pendingAt = -math.huge -- a request in flight
local dashing = false
local target: Model? = nil
local started = 0
local duration = Config.Dash.Duration
local from = Vector3.zero

local function pickTarget()
	local mode = State.Mode
	local _, root = State.character()
	if (mode ~= "Riding" and mode ~= "Free") or not root then
		State.DashTarget = nil
		return
	end
	local axis = workspace.CurrentCamera.CFrame.LookVector
	local fish = State.Fish
	if mode == "Riding" and fish and fish.PrimaryPart then
		axis = fish.PrimaryPart.CFrame.LookVector
	end
	local d = Config.Dash
	State.DashTarget = State.bestInCone(root.Position, axis, d.Range, d.Cone, 0.6)
end

local function request(): boolean
	local fish = State.DashTarget
	local t = os.clock()
	if not fish or t < State.DashReadyAt or t - pendingAt < 0.4 or dashing then
		return false
	end
	pendingAt = t
	Net.Action:FireServer("Dash", fish)
	return true
end

local function stop()
	dashing = false
	target = nil
end

-- the saddle's world frame on the target, or nil if it's gone
local function saddleOf(fish: Model?): CFrame?
	local root = fish and fish.PrimaryPart
	local saddle = root and root:FindFirstChild("Saddle")
	if saddle and saddle:IsA("Attachment") then
		return saddle.WorldCFrame
	end
	return nil
end

local function step()
	if not dashing then
		return
	end
	local _, root = State.character()
	local goalFrame = saddleOf(target)
	if not root or not goalFrame then
		stop()
		return
	end
	local d = Config.Dash
	local t = os.clock() - started
	if t > duration + 1 then -- the server never answered: let its state take over
		stop()
		return
	end
	local u = math.clamp(t / duration, 0, 1)
	local e = Ease.inOutSine(u)
	local fishRoot = (target :: Model).PrimaryPart
	local fishVelocity = if fishRoot then fishRoot.AssemblyLinearVelocity else Vector3.zero
	local goal = goalFrame.Position + fishVelocity * math.max(0, duration - t)
	local span = goal - from
	local mid = (from + goal) / 2 + Vector3.new(0, math.min(d.ArcHeight, span.Magnitude * 0.15), 0)
	-- a quadratic bezier and its tangent
	local position = from * (1 - e) ^ 2 + mid * 2 * (1 - e) * e + goal * e * e
	local tangent = (mid - from) * 2 * (1 - e) + (goal - mid) * 2 * e
	if tangent.Magnitude < 0.01 then
		tangent = if span.Magnitude > 0.01 then span else goalFrame.LookVector
	end
	local path = CFrame.lookAt(position, position + tangent)
	local angle = d.Spins * 2 * math.pi * e
	local radius = d.SpiralRadius * math.sin(math.pi * u)
	local spun = path.Position + (path.RightVector * math.cos(angle) + path.UpVector * math.sin(angle)) * radius
	-- head first along the path, rolling; standing back up for the saddle near the end
	local headFirst = (1 - Ease.smoothstep(0.7, 1, u)) * math.pi / 2
	local body = CFrame.lookAt(spun, spun + tangent) * CFrame.Angles(0, 0, -angle) * CFrame.Angles(-headFirst, 0, 0)
	body = body:Lerp(goalFrame, Ease.smoothstep(duration - d.Blend, duration, t))
	root.CFrame = body
	root.AssemblyLinearVelocity = if u < 1 then tangent.Unit * span.Magnitude / duration else fishVelocity
	root.AssemblyAngularVelocity = Vector3.zero
	State.Speed = if u < 1 then span.Magnitude / duration else fishVelocity.Magnitude
end

function DashController.Init()
	Actions.dash = request
	Net.Ride.OnClientEvent:Connect(function(kind: string, a: any, b: any)
		if kind == "DashStart" then
			local _, root = State.character()
			if not root then
				return
			end
			target = a
			duration = if type(b) == "number" then b else Config.Dash.Duration
			started = os.clock()
			from = root.Position
			dashing = true
			RideController.coast(State.Fish)
			State.Fish = nil
			State.FovKick = Config.Dash.FovKick
			State.setMode("Dashing")
		elseif kind == "Mounted" then
			if dashing then
				stop()
			end
			State.DashReadyAt = os.clock() + Config.Dash.Cooldown
		elseif kind == "Denied" and a == "Dash" then
			pendingAt = -math.huge
		elseif kind == "Dismounted" and dashing and a == "Lost" then
			stop()
		end
	end)
	Net.Fx.OnClientEvent:Connect(function(kind: string, player: Player, fish: Model, time: number?)
		if typeof(player) ~= "Instance" or not player:IsA("Player") then
			return
		end
		local character = player.Character
		if kind == "Dash" and character then
			Fx.trail(character, time or Config.Dash.Duration)
		elseif kind == "Land" and typeof(fish) == "Instance" then
			local tier = Config.Tiers[fish:GetAttribute("Tier") :: string]
			Fx.landing(character, fish, State.Squash, if tier then tier.Colour else Color3.new(1, 1, 1))
			if player == State.Player then
				-- the small camera kick on our own landing
				State.shake(Config.Burst.Kick, 0.3)
				State.FovKick += 3
			end
		end
	end)
	State.ModeChanged.Event:Connect(function(mode: string)
		if dashing and mode ~= "Dashing" and mode ~= "Riding" then
			stop()
		end
	end)
end

function DashController.Start()
	RunService:BindToRenderStep("RideDash", Enum.RenderPriority.Camera.Value - 5, step)
	RunService.Heartbeat:Connect(pickTarget)
end

return DashController
