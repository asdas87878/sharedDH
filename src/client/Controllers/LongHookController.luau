--!strict
-- The long hook (Config.Long; the user, 2026-11-18: "add an extra camera feature plus anything else to make hooking
-- onto a far away fish feel really far away and satisfying"). How long a hook is comes from the gap at the grab
-- (Config.longOf, State.ReelFar: nothing under Long.From studs, all of it at Long.Full), so an ordinary hop is as it
-- was. What a long one gets:
--   THE LONG SHOT, the camera: as the hook flies out the camera pulls back and the view widens, so the gap is seen
--     (State.CamLong, State.FovLong, read by RideController's camera); as the rope hauls you in the view narrows hard
--     and the camera falls behind you (its own follow, which a faster pull-in outruns); at the touch it holds still
--     for a beat (State.CamHoldUntil, set by JumpController with the landing), then snaps wide, knocked and shaken
--     harder, and swoops in after you.
--   THE RUSH: the rope's rush rises in pitch and loudness as you are hauled in, and stops dead at the touch, which
--     lands with a deep thud.
--   THE WORD: "LONG HOOK!", "HUGE HOOK!", "MEGA HOOK!" by the gap, with how far it was, and "BEST!" when it is your
--     longest this session. In the HUD's own letters (UI/Kit); it slides and fades, its text never changes size.
-- The harder landing itself (its snap, knock, shake and bubbles) is in JumpController's touch, where the landing is.
-- Made once: two sounds and one small screen of words; nothing per frame or per hook.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local FeelLog = require(script.Parent.Parent.Lib.FeelLog)
local Spring = require(script.Parent.Parent.Lib.Spring)
local State = require(script.Parent.Parent.Lib.State)
local Kit = require(script.Parent.Parent.UI.Kit)
local JumpController = require(script.Parent.JumpController)

local LongHookController = {}

local rush: Sound
local thud: Sound
local rushOn = false
local back, backSpeed = 0, 0 -- the camera's pull back, on its own spring

-- the word
local gui: ScreenGui
local holder: Frame
local scale: UIScale
local word: TextLabel
local wordShadow: TextLabel
local far: TextLabel
local best: TextLabel
local labels: { TextLabel } = {}
local strokes: { UIStroke } = {}
local shownAt = -math.huge
local longest = 0

-- Counts for tests (a script sent into Play gets its own copy of this module: the camera's attributes too)
LongHookController.Stats = { Long = 0, Last = "" }

local COLOURS: { [string]: Color3 } = {
	["LONG HOOK!"] = Kit.Sun,
	["HUGE HOOK!"] = Kit.Coral,
	["MEGA HOOK!"] = Kit.Pink,
}

local function build()
	rush = Instance.new("Sound")
	rush.Name = "LongHookRush"
	rush.SoundId = "rbxasset://sounds/action_falling.ogg"
	rush.Volume = 0
	rush.Parent = SoundService
	thud = Instance.new("Sound")
	thud.Name = "LongHookThud"
	thud.SoundId = "rbxasset://sounds/action_jump_land.mp3"
	thud.PlaybackSpeed = 0.42
	thud.Parent = SoundService

	gui = Instance.new("ScreenGui")
	gui.Name = "LongHook"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 4
	gui.Enabled = false
	holder = Kit.new("Frame", {
		Name = "Word",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.27),
		Size = UDim2.fromOffset(460, 120),
		BackgroundTransparency = 1,
	}, gui)
	scale = Kit.new("UIScale", {}, holder)
	local wordProps = {
		Name = "Big",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(1, 0, 0, 56),
		TextSize = 52,
		ZIndex = 3,
	}
	-- (a drop shadow under it, as the HUD's headings have)
	local under = table.clone(wordProps)
	under.Name = "Shadow"
	under.Position = UDim2.new(0.5, 0, 0, 4)
	under.TextColor3 = Kit.Ink
	under.ZIndex = 2
	wordShadow = Kit.text(under, holder)
	word = Kit.text(wordProps, holder)
	far = Kit.text({
		Name = "Far",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.new(1, 0, 0, 28),
		TextSize = 26,
		ZIndex = 3,
	}, holder)
	best = Kit.text({
		Name = "Best",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.new(1, 0, 0, 24),
		TextSize = 22,
		TextColor3 = Kit.Good,
		Text = "BEST!",
		ZIndex = 3,
	}, holder)
	labels = { word, wordShadow, far, best }
	for _, label in labels do
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			table.insert(strokes, stroke)
		end
	end
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- How much of the word's words to show: one scale for the screen it is on, never changed while it shows
local function fit()
	local size = workspace.CurrentCamera.ViewportSize
	scale.Scale = math.clamp(math.min(size.X / 1280, size.Y / 720), 0.6, 1.4)
end

local function show(gap: number)
	local l = Config.Long
	local pick: string? = nil
	for _, row in l.Words do
		if gap >= (row[1] :: number) then
			pick = row[2] :: string
		end
	end
	if not pick then
		return
	end
	local beat = l.Best > 0 and longest > 0 and gap > longest
	longest = math.max(longest, gap)
	word.Text = pick
	wordShadow.Text = pick
	word.TextColor3 = COLOURS[pick] or Kit.Sun
	far.Text = string.format("%d STUDS", math.floor(gap + 0.5))
	best.Visible = beat
	fit()
	shownAt = os.clock()
	gui.Enabled = true
	LongHookController.Stats.Long += 1
	LongHookController.Stats.Last = pick
	workspace.CurrentCamera:SetAttribute(
		"LongHook",
		string.format("%d %s %d", LongHookController.Stats.Long, pick, gap)
	)
end

-- The word over time: up into place quickly and a little past it, held, then faded (it slides and tilts, nothing grows)
local function wordStep()
	if not gui.Enabled then
		return
	end
	local l = Config.Long
	local t = os.clock() - shownAt
	local life = math.max(l.WordTime, 0.3)
	if t >= life then
		gui.Enabled = false
		return
	end
	local rise = Ease.smoothstep(0, 0.16, t)
	local over = math.sin(math.clamp(t / 0.32, 0, 1) * math.pi) * 0.012 * (1 - Ease.smoothstep(0.16, 0.32, t))
	holder.Position = UDim2.fromScale(0.5, 0.27 + 0.05 * (1 - rise) - over)
	holder.Rotation = -4 - 5 * (1 - rise)
	local fade = Ease.smoothstep(life - 0.3, life, t)
	local hide = math.max(1 - Ease.smoothstep(0, 0.08, t), fade)
	for _, label in labels do
		label.TextTransparency = hide
	end
	for _, stroke in strokes do
		stroke.Transparency = hide
	end
end

local function step(dt: number)
	local l = Config.Long
	local farNow = State.ReelFar
	local reeling = State.Reeling and State.Mode == "Jumping" and farNow > 0
	local u = if reeling then (JumpController.reel()) else nil
	-- the long shot: back and wide while the hook flies out (the pull-in's creep), then narrowing hard as it hauls
	local wantBack, fov = 0, 0
	if reeling and u then
		local early = Ease.smoothstep(0, 0.12, u) * (1 - Ease.smoothstep(0.3, 0.65, u))
		wantBack = l.Back * farNow * early
		fov = farNow * (l.Wide * early + Config.Jump.ReelFov * l.Narrow * u ^ Config.Jump.ReelFovCurve)
	end
	back, backSpeed = Spring.number(back, wantBack, backSpeed, if wantBack > back then 0.08 else 0.18, dt)
	State.CamLong = if math.abs(back) > 1e-3 then back else 0
	State.FovLong = fov
	-- the rush: rising as you are hauled in
	if reeling and u and l.Rush > 0 then
		if not rushOn then
			rushOn = true
			rush.TimePosition = 0
			rush:Play()
		end
		rush.PlaybackSpeed = 0.7 + 1.4 * u ^ 1.5
		rush.Volume = l.Rush * math.min(farNow, 1.5) * (0.35 + 0.65 * u)
	elseif rushOn then
		-- (cut at the touch, or the hook lost: a quick fade, not a click)
		rush.Volume *= math.exp(-30 * dt)
		if rush.Volume < 0.01 then
			rush:Stop()
			rushOn = false
		end
	end
	wordStep()
end

-- Our own pull-in has touched its fish
local function touched(gap: number, farNow: number, speed: number)
	local l = Config.Long
	if farNow <= 0 then
		return
	end
	if l.Thud > 0 then
		thud.Volume = l.Thud * math.min(farNow, 1.5)
		thud.TimePosition = 0
		thud:Play()
	end
	FeelLog.event("long", { Gap = gap, Far = farNow, Arrive = speed })
	show(gap)
end

function LongHookController.Start()
	-- (made here, not in Init: the screen waits for the player's PlayerGui)
	build()
	State.Touched.Event:Connect(touched)
	-- (before the camera's own step, RideController's, which reads State.CamLong and State.FovLong)
	RunService:BindToRenderStep("LongHook", Enum.RenderPriority.Camera.Value - 2, step)
end

return LongHookController
