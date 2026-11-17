--!strict
-- The wild ride on the camera (Config.Wild; the user, 2026-11-17: "making the ride feel proper, like rodeo wild
-- style, because ours is still feeling too tame, even though the speeds is technically correct ... really feel more
-- wild, untamed, and interesting, just in the way we manipulate the camera").
-- The fish itself is made wild elsewhere: its fits and its harder beat in AnimController, its pulses of speed and
-- its rising, falling, weaving line in RideController.drive. This file is what the camera does about it:
--   A FIT (State.Fitted: the fish under us bucks, thrashes, bolts, wobbles, shudders, rolls) gets a shake of its own
--     character (Config.Shake.Presets "Fit..."), rolled to the side the fit goes. A buck also knocks the view up; a
--     bolt kicks the view wider, leaves the camera behind for a moment (State.CamPull) and draws speed lines.
--     Bubbles burst from the tail.
--   THE RUMBLE of riding ("Ride"): a slow, loose sway from 25 studs a second, where the old tremble of speed only
--     began at 78: no fish of the first lands ever reached it, so their rides had a still camera.
--   THE ROLL: the view leans into a turn with the fish (State.CamRoll).
--   THE BEAT: each stroke of the tail is a faint knock.
-- Config.Wild.Amount scales all of it (0: the ride as it was before). Nothing is made per frame; a fit's shake is
-- one small table (Lib/Shake) and its bubbles are Fx's.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Feel = require(script.Parent.Parent.Lib.Feel)
local Fx = require(script.Parent.Parent.Lib.Fx)
local Shake = require(script.Parent.Parent.Lib.Shake)
local State = require(script.Parent.Parent.Lib.State)
local RideController = require(script.Parent.RideController)

local WildController = {}

local TAU = math.pi * 2
local PRESETS: { [string]: string } = {
	buck = "FitBuck",
	startle = "FitStartle",
	thrash = "FitThrash",
	bolt = "FitBolt",
	wobble = "FitWobble",
	shudder = "FitShudder",
	barrel = "FitWobble",
}

local roll = 0
local pull = 0
local lastBeat = 0

-- Counts for tests: fits so far on our own fish, and the last one's kind
WildController.Stats = { Fits = 0, Last = "" }

-- The fish under us has thrown a fit
local function fitted(kind: string, sign: number, power: number)
	local wd = Config.Wild
	local amount = math.min(wd.Amount, 2)
	WildController.Stats.Fits += 1
	WildController.Stats.Last = kind
	-- (and where a test run from outside can read it: a script sent into Play gets its own copy of this module)
	workspace.CurrentCamera:SetAttribute("WildFit", string.format("%d %s", WildController.Stats.Fits, kind))
	if amount <= 0 then
		return
	end
	if wd.Shake > 0 then
		Shake.play(PRESETS[kind] or "FitBuck", wd.Shake * math.clamp(power, 0.4, 1.6), sign)
	end
	if kind == "bolt" then
		State.FovPunch = math.max(State.FovPunch, wd.BoltFov * amount)
		pull = math.max(pull, wd.Pull * amount)
		if wd.FitRush > 0 then
			Feel.rush(wd.FitRush)
		end
		Feel.sound("Whoosh", Config.Feel.Whoosh * 0.7, Config.Feel.WhooshPitch * 1.15, 0.5)
	elseif kind == "buck" or kind == "startle" then
		-- (the view is knocked up with the heave: KickVelocity is downward)
		State.KickVelocity -= wd.BuckKick * amount * TAU * Config.Jump.LandKickRate
	end
	local fish = State.Fish
	local root = fish and fish.PrimaryPart
	if fish and root and wd.FitBubbles > 0 then
		local kindOf = Config.FishById[fish:GetAttribute("FishType") :: string]
		local long = if kindOf then Config.bodyOf(fish, kindOf).Z else 10
		Fx.burst(root.Position - root.CFrame.LookVector * (long * 0.45), wd.FitBubbles, 0, 4)
	end
end

local function step(dt: number)
	local wd = Config.Wild
	local amount = math.min(wd.Amount, 2)
	local riding = State.Mode == "Riding" and State.Fish ~= nil and amount > 0
	-- the roll into a turn
	local lean = if riding then RideController.lean() * math.rad(wd.CamRoll) * amount else 0
	roll = Ease.lerp(roll, lean, Ease.alpha(wd.CamRollEase, dt))
	State.CamRoll = if math.abs(roll) > 1e-4 then roll else 0
	-- left behind by a bolt, catching up
	pull *= math.exp(-math.max(wd.PullEase, 0.1) * dt)
	State.CamPull = if pull > 1e-3 then pull else 0
	-- the rumble of riding, by speed, a little more as the fish works harder
	local share = 0
	if riding then
		share = Ease.smoothstep(wd.RumbleFrom, wd.RumbleFull, State.Speed)
			* wd.Rumble
			* amount
			* (1 + 0.4 * math.clamp(State.RideEffort - 1, 0, 1.5))
	end
	Shake.rumble("Ride", "Ride", share)
	-- each stroke of the tail
	local beat = math.floor(State.RideBeat / TAU)
	if beat ~= lastBeat then
		lastBeat = beat
		if riding and wd.BeatKick > 0 then
			State.KickVelocity += wd.BeatKick * amount * TAU * Config.Jump.LandKickRate
		end
	end
end

function WildController.Init()
	State.Fitted.Event:Connect(fitted)
end

function WildController.Start()
	-- (before the camera's own step, RideController's, which reads State.CamRoll and State.CamPull)
	RunService:BindToRenderStep("RideWild", Enum.RenderPriority.Camera.Value - 1, step)
end

return WildController
