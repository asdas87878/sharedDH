--!strict
-- The Oxygen ring's damage trail (task t1), captured frame by frame: a copy of the game's own UI/Rings (a clone of the
-- ModuleScript, so its state is its own; it shares Kit and so Kit.RingLook) is drawn where the real ring sits, on a
-- clock of its own: ReplicatedStorage "TrailT" (seconds), so each picture is one exact moment however slow the shot.
-- The real ring is hidden while it shows. Installed into StarterPlayerScripts by trail_capture.py.
--   TrailRun (number): a new scenario (a fresh ring); TrailMode: Kit.RingLook.TickTrail; TrailScript: JSON
--   { max, start, events = { {t, from, to}, ... } }; TrailT: the moment to draw
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local ui = client:WaitForChild("UI")
local Kit = require(ui:WaitForChild("Kit")) :: any

local gui: ScreenGui? = nil
local rings: any = nil
local run = -1
local plan: any = nil
local fired = 0

local function amountAt(t: number): number
	local amount = plan.start
	for _, e in plan.events do
		if e[1] <= t then
			amount = e[3]
		end
	end
	return amount
end

local view = {
	Follow = false,
	X = 0,
	Y = 0,
	Wide = 0,
	High = 0,
	Fraction = 1,
	Amount = 0,
	Max = 1,
	RedAt = 0,
	Seconds = 5,
	Name = "",
	Tier = "",
	Note = "",
	NoteSub = "",
	Warn = false,
	Tame = nil :: number?,
	Ready = 1,
	Strained = false,
	Low = false,
	Kind = "",
	Endless = false,
}

local function fresh()
	if gui then
		gui:Destroy()
	end
	local old = ui:FindFirstChild("ZZRingsCapture")
	if old then
		old:Destroy()
	end
	local copy = (ui :: any).Rings:Clone()
	copy.Name = "ZZRingsCapture"
	copy.Parent = ui
	rings = require(copy) :: any
	local made = Instance.new("ScreenGui")
	made.Name = "ZZTrail"
	made.ResetOnSpawn = false
	made.DisplayOrder = 6
	made.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	made.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = made
	-- the HUD's own scale, so the copy is the real ring's size
	local hud = playerGui:FindFirstChild("RideHud")
	local real = hud and hud:FindFirstChild("Root")
	local realScale = real and real:FindFirstChildOfClass("UIScale")
	local scale = Instance.new("UIScale")
	scale.Scale = if realScale then realScale.Scale else 1
	scale.Parent = root
	made.Parent = playerGui
	rings.build(root)
	rings.place(false)
	gui = made
	fired = 0
end

RunService:BindToRenderStep("ZZTrail", Enum.RenderPriority.Last.Value + 5, function()
	local want = ReplicatedStorage:GetAttribute("TrailRun")
	if typeof(want) ~= "number" or want <= 0 then
		if gui then
			gui:Destroy()
			gui = nil
		end
		return
	end
	if want ~= run then
		run = want
		plan = HttpService:JSONDecode(ReplicatedStorage:GetAttribute("TrailScript") :: string)
		Kit.RingLook.TickTrail = ReplicatedStorage:GetAttribute("TrailMode") :: number
		fresh()
	end
	local hud = playerGui:FindFirstChild("RideHud")
	local realRings = hud and hud:FindFirstChild("Rings", true)
	if realRings and realRings:IsA("Frame") then
		realRings.Visible = false
	end
	local t = (ReplicatedStorage:GetAttribute("TrailT") :: number?) or 0
	-- the drops up to now, each heard at its own moment
	while plan.events[fired + 1] and plan.events[fired + 1][1] <= t do
		local e = plan.events[fired + 1]
		fired += 1
		rings.lose(e[1], e[2], e[3])
	end
	local root = (gui :: ScreenGui):FindFirstChildOfClass("Frame") :: Frame
	local s = (root:FindFirstChildOfClass("UIScale") :: UIScale).Scale
	view.Wide = root.AbsoluteSize.X / s
	view.High = root.AbsoluteSize.Y / s
	view.Max = plan.max
	view.Amount = amountAt(t)
	view.Fraction = view.Amount / plan.max
	view.Low = view.Amount < plan.max / 3
	rings.update(t, view)
end)
