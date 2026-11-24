--!strict
-- A great fish leaping out of the sea past the gate now and then, as seen from the hub (Config.HubLeap; the play passes,
-- 2026-11-24: nothing in a new player's first view was a fish, in a game about riding them).
-- A copy of the creature's own model (ReplicatedStorage.FishModels), still and anchored, moved along an arc across the
-- opening with a splash going out and coming in. Only on this machine, only while we are on the dock: nothing is a
-- fish anyone can ride, nothing is sent.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Splash = require(script.Parent.Parent.Lib.Splash)
local State = require(script.Parent.Parent.Lib.State)

local HubLeapController = {}

type Leap = { Model: Model, From: Vector3, To: Vector3, At: number, Out: boolean, In: boolean }

local leap: Leap? = nil
local nextAt = 0
local turn = 0
local ready: { [string]: Model } = {} -- one copy of each kind, kept

local function copyOf(id: string): Model?
	if ready[id] then
		return ready[id]
	end
	local folder = ReplicatedStorage:FindFirstChild("FishModels")
	local found = folder and folder:FindFirstChild(id)
	if not found or not found:IsA("Model") then
		return nil
	end
	local model = found:Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.CastShadow = false
		elseif d:IsA("Script") or d:IsA("Motor6D") or d:IsA("Trail") then
			d:Destroy()
		end
	end
	model:ScaleTo(Config.HubLeap.Length / math.max(select(2, model:GetBoundingBox()).Z, 1))
	ready[id] = model
	return model
end

local function finish(l: Leap)
	l.Model.Parent = nil
	leap = nil
	nextAt = os.clock() + Config.HubLeap.Every
end

-- The gate's spot: the dock's spawn looks at it (nil: no such map)
local function gate(): CFrame?
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local dock = blockout and blockout:FindFirstChild("Dock")
	local spawn = dock and dock:FindFirstChild("DockSpawn")
	local strip = dock and dock:FindFirstChild("StartStrip")
	if not spawn or not spawn:IsA("BasePart") or not strip or not strip:IsA("BasePart") then
		return nil
	end
	local to = Vector3.new(strip.Position.X, 0, strip.Position.Z)
	local from = Vector3.new(spawn.Position.X, 0, spawn.Position.Z)
	return CFrame.lookAt(to, to + (to - from))
end

local function start(now: number)
	local c = Config.HubLeap
	local at = gate()
	turn += 1
	local model = copyOf(c.Kinds[(turn - 1) % #c.Kinds + 1])
	if not at or not model then
		nextAt = now + c.Every
		return
	end
	local way = if turn % 2 == 0 then 1 else -1
	local y = Config.Depth.SurfaceY - c.Under
	local from = (at * CFrame.new(-way * c.Across / 2, 0, -c.Out)).Position
	local to = (at * CFrame.new(way * c.Across / 2, 0, -c.Out - c.Away)).Position
	leap = {
		Model = model,
		From = Vector3.new(from.X, y, from.Z),
		To = Vector3.new(to.X, y, to.Z),
		At = now,
		Out = false,
		In = false,
	}
	model.Parent = workspace.CurrentCamera
end

local function step()
	local c = Config.HubLeap
	local now = os.clock()
	local l = leap
	if not l then
		if State.Mode == "Dock" and now >= nextAt and c.On ~= 0 then
			start(now)
		end
		return
	end
	local t = (now - l.At) / c.Time
	if t >= 1 or State.Mode ~= "Dock" then
		finish(l)
		return
	end
	-- an arc, its nose along the way it is going
	local function spot(x: number): Vector3
		return l.From:Lerp(l.To, x) + Vector3.new(0, 4 * x * (1 - x) * (c.High + c.Under), 0)
	end
	local p = spot(t)
	local ahead = spot(t + 0.02)
	l.Model:PivotTo(CFrame.lookAt(p, ahead) * CFrame.Angles(0, 0, math.rad(c.Roll) * math.sin(math.pi * t)))
	local over = p.Y > Config.Depth.SurfaceY
	if over and not l.Out then
		l.Out = true
		Splash.play(Vector3.new(p.X, Config.Depth.SurfaceY, p.Z), (l.To - l.From).Unit, c.Splash)
	elseif l.Out and not over and not l.In then
		l.In = true
		Splash.play(Vector3.new(p.X, Config.Depth.SurfaceY, p.Z), (l.To - l.From).Unit, c.Splash)
	end
end

function HubLeapController.Start()
	if Config.HubLeap.On == 0 then
		return
	end
	nextAt = os.clock() + Config.HubLeap.First
	RunService.RenderStepped:Connect(step)
end

return HubLeapController
