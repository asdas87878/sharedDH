--!strict
-- The dock's lines in the middle of the screen, formatted as the reference's deposit (UI review 1, the user,
-- 2026-11-22: "if we have a deposit fish UI, make sure its formatted liek ride a dino"):
--   DockNotes.carrying(on)   "GO TO YOUR TANK TO DEPOSIT" low in the middle while this player carries a catch on the
--                            dock and no window is up (Controllers/StallController asks every look)
--   DockNotes.words(text)    what that line says instead (LessonController; nil: its own words)
--   DockNotes.lesson(text)   the line whether or not they carry anything, with these words (LessonController; nil: not).
--                            Words between stars are on a sticker (our "go here / press this"), in either (UI/Sticker).
--   DockNotes.full(line)     a pink "TANK FULL!" pill and one short line under it, popping in (0.17 s), gone after 2 s
--   DockNotes.note(word, line, good)   the same with other words: green (good) or pink
--   DockNotes.goal(text)     a smaller line under the caption's place (Controllers/GoalController; nil: none)
--   DockNotes.waiting()      whether the line and the goal can still come or are up (else what they say is not asked for)
-- The line and the goal only come after a respawn, the first spawn's too, once, for Config.DockLine.Hold seconds, and fade
-- (Hugo, 2026-11-25; Lib/RespawnLine says when): what the calls above say is kept, and shown only then.
-- (The line over the tank as a fish goes in is UI.TankPrompt's.)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local RespawnLine = require(script.Parent.Parent.Lib.RespawnLine)
local State = require(script.Parent.Parent.Lib.State)
local Anim = require(script.Parent.Anim)
local CatchShow = require(script.Parent.CatchShow)
local Kit = require(script.Parent.Kit)
local Shop = require(script.Parent.Shop)
local Sticker = require(script.Parent.Sticker)

local DockNotes = {}

local CARRY = "GO TO YOUR *TANK* TO DEPOSIT"
local CARRY_AT = 0.686 -- the reference's: the line's middle, down the screen
local FULL_AT = 0.6
local FULL_STAY = 2
local GOAL_AT = 0.755
local SIDE = 24 -- the lines keep this far from the screen's sides, points
local PINK = { Color3.fromRGB(255, 120, 190), Color3.fromRGB(226, 52, 140) }
local GREEN = { Color3.fromRGB(150, 236, 92), Color3.fromRGB(44, 174, 62) }

local gui: ScreenGui? = nil
local carry: Sticker.Sticker
local full: Frame
local fullLine: TextLabel
local fullPill: Frame
local fullWord: TextLabel
local fullFill: UIGradient
local goal: Sticker.Sticker
local goalText: string? = nil
local scaleNow = 1
local wideNow = 1000 -- the widest a line may be
local fullAt = -math.huge
local carryOn = false
local carryWords = CARRY
local lessonWords: string? = nil
local showing = RespawnLine.new()
local running: RBXScriptConnection? = nil
local drawn: Sticker.Sticker? = nil -- the one of the two that is up
local drawnWords = ""

local function build()
	local g: ScreenGui = Kit.new("ScreenGui", {
		Name = "DockNotes",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 6,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, Players.LocalPlayer:WaitForChild("PlayerGui"))
	local root: Frame = Kit.new("Frame", { Name = "Root", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, g)
	-- (text in the window's points: as tall as a 720p screen's)
	local scale: UIScale = Kit.new("UIScale", {}, root)
	local function fit()
		local camera = workspace.CurrentCamera
		local s = if camera then math.clamp(camera.ViewportSize.Y / 720, 0.6, 1.5) else 1
		scale.Scale = s
		root.Size = UDim2.fromScale(1 / s, 1 / s)
		scaleNow = s
		wideNow = if camera then math.max(camera.ViewportSize.X / s - SIDE * 2, 100) else 1000
		drawnWords = "" -- (laid out again)
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	local function made(name: string, at: number): Sticker.Sticker
		return Sticker.new(root, {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, at),
			Visible = false,
		})
	end
	carry = made("Carry", CARRY_AT)
	goal = made("Goal", GOAL_AT)
	full = Kit.new("Frame", {
		Name = "Full",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, FULL_AT),
		Size = UDim2.fromOffset(520, 92),
		BackgroundTransparency = 1,
		Visible = false,
	}, root)
	local pill: Frame = Kit.new("Frame", {
		Name = "Pill",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(250, 50),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
	}, full)
	Kit.corner(pill, 999)
	Kit.stroke(pill, 3, Shop.Edge)
	fullFill = Kit.new("UIGradient", { Rotation = 90, Color = Shop.halves(PINK[1], PINK[2]) }, pill)
	fullPill = pill
	fullWord = Shop.text(pill, { Size = UDim2.fromScale(1, 1), TextSize = 32, Text = "TANK FULL!", ZIndex = 2 })
	fullLine = Shop.text(full, {
		Name = "Line",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 0, 0, 30),
		TextSize = 24,
		Text = "",
	})
	gui = g
end

-- What there is to say: the lesson's words first, else the catch's, else the goal
local function saying(): (string?, boolean)
	local words = lessonWords or (if carryOn then carryWords else nil)
	if words then
		return words, false
	end
	return goalText, true
end

local function show(which: Sticker.Sticker?)
	if drawn and drawn ~= which then
		drawn.Root.Visible = false
	end
	drawn = which
	drawnWords = ""
	if which then
		which.Root.Visible = true
	end
end

-- Each frame while a line can still come or is up
local function step()
	local words, isGoal = saying()
	local docked = State.Mode == "Dock"
	-- (the black, the last words and the catch have the screen first, and so has a note; nothing to see yet before our body)
	local noted = gui ~= nil and full.Visible
	local clear = docked
		and State.FadeText == ""
		and State.Fade <= 0.02
		and not CatchShow.showing()
		and State.Player.Character ~= nil
		and not noted
	local d = Config.DockLine
	local on, seeThrough = RespawnLine.step(showing, os.clock(), docked, clear, words ~= nil and not noted, d)
	if showing.Stage == "Open" then
		if not gui then
			build()
		end
		if words then
			local which = if isGoal then goal else carry
			if drawn ~= which then
				show(which)
			end
			if words ~= drawnWords then
				drawnWords = words
				local size = math.max(if isGoal then d.GoalSize else d.Size, d.Least / scaleNow)
				which.set(words, size, wideNow, d.Stroke)
				which.Root:SetAttribute("Words", (string.gsub(words, "%*", "")))
			end
		end
		if drawn then
			drawn.pose(on, seeThrough)
		end
	elseif showing.Stage == "Done" then
		show(nil)
		if running then
			running:Disconnect()
			running = nil
		end
	end
end

-- (the first spawn, a new body, and home from a dive)
local function respawned()
	RespawnLine.respawned(showing)
	show(nil)
	if not running then
		running = RunService.RenderStepped:Connect(step)
	end
end

function DockNotes.Start()
	State.Player.CharacterAdded:Connect(respawned)
	Net.Ride.OnClientEvent:Connect(function(what: string)
		if what == "Respawned" then
			respawned()
		end
	end)
	respawned()
end

function DockNotes.waiting(): boolean
	return showing.Stage ~= "Done"
end

function DockNotes.carrying(on: boolean)
	carryOn = on
end

function DockNotes.lesson(text: string?)
	lessonWords = text
end

function DockNotes.words(text: string?)
	carryWords = text or CARRY
end

function DockNotes.goal(text: string?)
	goalText = text
end

function DockNotes.full(line: string)
	DockNotes.note("TANK FULL!", line, false)
end

function DockNotes.note(word: string, line: string, good: boolean)
	if not gui then
		build()
	end
	local tones = if good then GREEN else PINK
	fullFill.Color = Shop.halves(tones[1], tones[2])
	fullWord.Text = word
	fullPill.Size = UDim2.fromOffset(math.max(250, 60 + #word * 20), 50)
	fullLine.Text = line
	fullAt = os.clock()
	if full.Visible then
		Anim.punch(full, 1.1)
	else
		Anim.toast(full, true)
	end
	local stamp = fullAt
	task.delay(FULL_STAY, function()
		if fullAt == stamp then
			Anim.toast(full, false)
		end
	end)
end

return DockNotes
