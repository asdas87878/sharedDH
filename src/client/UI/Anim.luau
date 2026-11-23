--!strict
-- The UI's motion, in one place (UI review 1, the user, 2026-11-22: "we need tweens, transitions, the exclimation mark
-- which bounces up and down, on click animations correct, on hover animations correct"). Every screen opens, closes,
-- presses, hovers and pops the same way, with the reference's timings read frame by frame off the user's recording
-- (docs/design/ui-review.md, "Motion"):
--   Anim.open(gui)          a window springs out of its centre: 70% at first sight, about 104% at 0.14 s, settled by
--                           0.36 s (the user, 2026-11-23: "a bit less elastic and slightly more responsive"; near the
--                           reference's Shop, 75% to 105% in about 0.3 s, where its stall panels spring from 30%)
--   Anim.close(gui, done)   it swells to about 108% and collapses to nothing in 0.27 s; done() after (not if it was
--                           opened again meanwhile)
--   Anim.button(b, opts)    hover (grow, and a shade over the face) and press (a dip, back with a little spring)
--   Anim.bounce(mark)       the red "!": every 1.8 s a squash, a stretched hop with a wobble, a landing squash and a
--                           ring that grows and fades; while the mark is visible
--   Anim.punch(gui, s)      a quick scale up and back (a number changed, a thing arrived)
--   Anim.count(label, ...)  a number runs to its new value, fast first
--   Anim.rise(group, ...)   a pop in, a drift up and a fade out (a "+$250" over a sale)
--   Anim.toast(gui, on)     a small plate or line pops in, and shrinks away
--   Anim.stagger(cards)     a window's cards pop in one after another as it opens (grids only)
--   Anim.shine(face, ...)   a streak of light crosses a button that takes or gives money, while pressing it works
--   Anim.dim(on)            the world and the HUD darken behind a stand's window (fades 0.14 s in, 0.17 s out)
-- One rule: Anim owns the UIScale it puts on a thing ("Anim"), so don't give the same thing another UIScale. Every
-- motion can be cut off by the next one on the same thing. Nothing runs when nothing moves.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Anim = {}

-- The numbers, all here
Anim.Open = { From = 0.7, Freq = 18, Decay = 13, Time = 0.36 } -- the spring: 1 - (1 - From) e^(-Decay t) cos(Freq t)
Anim.Close = TweenInfo.new(0.27, Enum.EasingStyle.Back, Enum.EasingDirection.In)
Anim.Down = TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Anim.Up = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
Anim.Hover = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Anim.Punch = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
Anim.ToastIn = TweenInfo.new(0.17, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
Anim.ToastOut = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
Anim.DimTo = 0.5 -- how see-through the dark is at its darkest
Anim.DimIn = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Anim.DimOut = TweenInfo.new(0.17, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Anim.Bounce = { Every = 1.8, Hop = 0.45, Wobble = 16 } -- seconds apart, the hop as a share of the mark's height, degrees
-- The cards' stagger: the first starts Delay into the window's spring, the next Gap after (shrunk so the last of the
-- first Most lands within Within), each popping from From to full
Anim.Stagger = { Delay = 0.03, Gap = 0.025, Within = 0.18, Most = 12, From = 0.6 }
Anim.CardIn = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- The shine: seconds from lighting up to the first sweep, between sweeps, and a sweep's own; how often we look at
-- whether a button is lit; the streak's lean in degrees and how see-through it is
Anim.Shine = { First = 0.5, Every = 4, Time = 0.7, Look = 0.2, Lean = 20, Clear = 0.5 }

-- The one UIScale Anim puts on a thing
function Anim.scaleOf(gui: GuiObject): UIScale
	local found = gui:FindFirstChild("Anim")
	if found and found:IsA("UIScale") then
		return found
	end
	local made = Instance.new("UIScale")
	made.Name = "Anim"
	made.Parent = gui
	return made
end

-- What is moving each scale now: a newer motion takes over from an older one
local turns: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local tweens: { [Instance]: Tween } = setmetatable({}, { __mode = "k" }) :: any

local function take(thing: Instance): number
	local turn = (turns[thing] or 0) + 1
	turns[thing] = turn
	local old = tweens[thing]
	if old then
		old:Cancel()
		tweens[thing] = nil
	end
	return turn
end

local function tween(thing: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local t = TweenService:Create(thing, info, goal)
	tweens[thing] = t
	t:Play()
	return t
end

-- A spring run frame by frame from `from` to 1 (the open)
local function spring(scale: UIScale, from: number)
	local turn = take(scale)
	local o = Anim.Open
	-- the clock starts after the first frame it is drawn on, so a long one (a window just built) can't swallow the motion
	local start: number? = nil
	local drawn = false
	scale.Scale = from
	local link: RBXScriptConnection
	link = RunService.RenderStepped:Connect(function()
		if turns[scale] ~= turn then
			link:Disconnect()
			return
		end
		if not drawn then
			drawn = true
			return
		end
		local began = start or os.clock()
		start = began
		local t = os.clock() - began
		if t >= o.Time then
			scale.Scale = 1
			link:Disconnect()
			return
		end
		scale.Scale = 1 - (1 - from) * math.exp(-o.Decay * t) * math.cos(o.Freq * t)
	end)
end

function Anim.open(gui: GuiObject, from: number?)
	spring(Anim.scaleOf(gui), from or Anim.Open.From)
end

function Anim.close(gui: GuiObject, done: (() -> ())?)
	local scale = Anim.scaleOf(gui)
	local turn = take(scale)
	local t = tween(scale, Anim.Close, { Scale = 0 })
	t.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and turns[scale] == turn then
			if done then
				done()
			end
			scale.Scale = 1
		end
	end)
end

-- A quick scale up and back
function Anim.punch(gui: GuiObject, size: number?)
	local scale = Anim.scaleOf(gui)
	take(scale)
	scale.Scale = size or 1.15
	tween(scale, Anim.Punch, { Scale = 1 })
end

local function touching(): boolean
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

export type ButtonOpts = {
	Grow: number?, -- the hover's size (1: none)
	Press: number?, -- the press's size (0.94)
	Shade: GuiObject?, -- a black overlay to darken under the mouse (Anim makes it see-through)
	ShadeTo: number?, -- how dark it gets (0.12: 12% darker)
	Live: (() -> boolean)?, -- a press only dips while this says yes
}

-- Hover and press on a button. The button's own Activated stays the button's.
function Anim.button(button: GuiButton, opts: ButtonOpts?)
	local o: ButtonOpts = opts or {}
	local grow = o.Grow or 1
	local press = o.Press or 0.94
	local scale = Anim.scaleOf(button)
	local shade = o.Shade
	if shade then
		shade.BackgroundColor3 = Color3.new(0, 0, 0)
		shade.BackgroundTransparency = 1
		shade.BorderSizePixel = 0
	end
	local over, down = false, false
	local function go(info: TweenInfo)
		take(scale)
		local size = (if over and not touching() then grow else 1) * (if down then press else 1)
		tween(scale, info, { Scale = size })
		if shade then
			local dark = if over and not touching() then (o.ShadeTo or 0.12) else 0
			TweenService:Create(shade, Anim.Hover, { BackgroundTransparency = 1 - dark }):Play()
		end
	end
	button.MouseEnter:Connect(function()
		over = true
		go(Anim.Hover)
	end)
	button.MouseLeave:Connect(function()
		over, down = false, false
		go(Anim.Hover)
	end)
	button.InputBegan:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			if o.Live and not o.Live() then
				return
			end
			down = true
			go(Anim.Down)
		end
	end)
	button.InputEnded:Connect(function(input: InputObject)
		local t = input.UserInputType
		if (t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch) and down then
			down = false
			if t == Enum.UserInputType.Touch then
				over = false
			end
			go(Anim.Up)
		end
	end)
end

-- A number runs to its new value over `time`, fast first. format turns the number into the label's text.
local counting: { [Instance]: NumberValue } = setmetatable({}, { __mode = "k" }) :: any
function Anim.count(label: TextLabel, from: number, to: number, format: (number) -> string, time: number?)
	local value = counting[label]
	if not value then
		local made = Instance.new("NumberValue")
		made.Changed:Connect(function(v: number)
			local text = format(v)
			if label.Text ~= text then
				label.Text = text
			end
		end)
		counting[label] = made
		value = made
	end
	local v = value :: NumberValue
	take(v)
	v.Value = from
	label.Text = format(from)
	local t = tween(v, TweenInfo.new(time or 1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Value = to })
	t.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then
			label.Text = format(to)
		end
	end)
end

-- A pop in, a drift up and a fade out; the group is destroyed after. lift: how far up, in its parent's points.
function Anim.rise(group: CanvasGroup, lift: number?, stay: number?)
	local scale = Anim.scaleOf(group)
	scale.Scale = 0.5
	group.GroupTransparency = 0
	TweenService:Create(scale, Anim.ToastIn, { Scale = 1 }):Play()
	local up = lift or 40
	local last = stay or 0.7
	TweenService:Create(
		group,
		TweenInfo.new(last + 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = group.Position - UDim2.fromOffset(0, up) }
	):Play()
	task.delay(last, function()
		local fade = TweenService:Create(group, TweenInfo.new(0.3), { GroupTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		group:Destroy()
	end)
end

-- A plate or a line that comes and goes: pops in, shrinks away (and then is hidden)
function Anim.toast(gui: GuiObject, on: boolean)
	local scale = Anim.scaleOf(gui)
	if on then
		if gui.Visible and turns[scale] and scale.Scale >= 0.99 then
			return
		end
		take(scale)
		gui.Visible = true
		scale.Scale = 0.6
		tween(scale, Anim.ToastIn, { Scale = 1 })
	elseif gui.Visible then
		local turn = take(scale)
		local t = tween(scale, Anim.ToastOut, { Scale = 0 })
		t.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and turns[scale] == turn then
				gui.Visible = false
				scale.Scale = 1
			end
		end)
	end
end

-- A window's cards pop in one after another as it opens (the user, 2026-11-22: "Card stagger"; the transitions
-- study, docs/reference/ui-motion-and-studs.md). cards: in the order they show. Only the first screenful staggers,
-- and the gap shrinks so the last of them lands within Within; the rest are simply there. Only for cards in a
-- UIGridLayout: a grid scales a cell about its middle and leaves the others put (measured in Studio, 2026-11-22),
-- while a UIListLayout would move every card after it. A card is held at nothing only here, and each held card's
-- pop is already on its way: a newer motion on it (a reopen) takes over and sets its own size.
function Anim.stagger(cards: { GuiObject })
	local s = Anim.Stagger
	local n = math.min(#cards, s.Most)
	local gap = if n > 1 then math.min(s.Gap, s.Within / (n - 1)) else 0
	for i, card in cards do
		local scale = Anim.scaleOf(card)
		local turn = take(scale)
		if i > n then
			scale.Scale = 1
			continue
		end
		scale.Scale = 0
		task.delay(s.Delay + (i - 1) * gap, function()
			if turns[scale] ~= turn then
				return
			end
			scale.Scale = s.From
			tween(scale, Anim.CardIn, { Scale = 1 })
		end)
	end
end

-- The shine (the user, 2026-11-23: "build the shine sweep"): a streak of light crosses a face now and then while `on`
-- says yes and the face is on screen. Only for the buttons that take or give money, one to a window, so a shine always
-- means "pressing this works now". The streak lies under the words (ZIndex 1) and draws nothing between sweeps. One
-- slow look runs all of them, so a button refreshed many times a second never restarts its sweep. Off with Roblox's
-- Reduce Motion.
type Shining = { Face: GuiObject, On: () -> boolean, Streak: Frame, Slide: UIGradient, Due: number? }
local shining: { Shining } = {}

-- Is it drawn: itself and everything above it visible, its gui on
local function drawnNow(gui: Instance): boolean
	local at: Instance? = gui
	while at do
		if at:IsA("GuiObject") and not at.Visible then
			return false
		elseif at:IsA("LayerCollector") then
			return at.Enabled
		end
		at = at.Parent
	end
	return false
end

-- True while a streak is crossing: then we look every frame, so one whose button goes dead is gone by the next
local function lookShines(): boolean
	local s = Anim.Shine
	local now = os.clock()
	local crossing = false
	for i = #shining, 1, -1 do
		local one = shining[i]
		if not one.Face:IsDescendantOf(game) then
			table.remove(shining, i)
		elseif GuiService.ReducedMotionEnabled or not drawnNow(one.Face) or not one.On() then
			one.Due = nil
			one.Streak.Visible = false
		elseif not one.Due then
			one.Due = now + s.First
		elseif now >= one.Due then
			one.Due = now + s.Every
			take(one.Slide)
			one.Slide.Offset = Vector2.new(-1, 0)
			one.Streak.Visible = true
			local t = tween(
				one.Slide,
				TweenInfo.new(s.Time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ Offset = Vector2.new(1, 0) }
			)
			t.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed then
					one.Streak.Visible = false
				end
			end)
		end
		crossing = crossing or one.Streak.Visible
	end
	return crossing
end

function Anim.shine(face: GuiObject, radius: number, on: () -> boolean)
	local s = Anim.Shine
	local streak = Instance.new("Frame")
	streak.Name = "Shine"
	streak.Size = UDim2.fromScale(1, 1)
	streak.BackgroundColor3 = Color3.new(1, 1, 1)
	streak.BorderSizePixel = 0
	streak.Visible = false
	streak.ZIndex = 1
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = streak
	-- two hard-edged streaks, a wide and a thin, as the Shop header's gloss
	local thin = s.Clear + (1 - s.Clear) * 0.4
	local slide = Instance.new("UIGradient")
	slide.Rotation = s.Lean
	slide.Offset = Vector2.new(-1, 0)
	slide.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.43, s.Clear),
		NumberSequenceKeypoint.new(0.53, s.Clear),
		NumberSequenceKeypoint.new(0.54, 1),
		NumberSequenceKeypoint.new(0.57, 1),
		NumberSequenceKeypoint.new(0.575, thin),
		NumberSequenceKeypoint.new(0.6, thin),
		NumberSequenceKeypoint.new(0.605, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	slide.Parent = streak
	streak.Parent = face
	table.insert(shining, { Face = face, On = on, Streak = streak, Slide = slide, Due = nil })
	if #shining == 1 then
		task.spawn(function()
			while #shining > 0 do
				task.wait(if lookShines() then 0 else s.Look)
			end
		end)
	end
end

-- The dark behind a stand's window: over the HUD (4 to 7), under the windows (8)
local dimGui: ScreenGui? = nil
local dimFrame: Frame? = nil
function Anim.dim(on: boolean)
	if not dimGui then
		local gui = Instance.new("ScreenGui")
		gui.Name = "Dim"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 7
		gui.Enabled = true
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.new(0, 0, 0)
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.Active = false
		frame.Parent = gui
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		dimGui, dimFrame = gui, frame
	end
	local frame = dimFrame :: Frame
	take(frame)
	tween(frame, if on then Anim.DimIn else Anim.DimOut, { BackgroundTransparency = if on then Anim.DimTo else 1 })
end

-- The red "!": bounces while it is visible (a squash, a stretched hop with a wobble, a landing squash, a ring that
-- grows and fades). The mark keeps its own Size and Position between bounces; its insides should be sized by scale.
function Anim.bounce(mark: GuiObject, ringColour: Color3?)
	local size, place = mark.Size, mark.Position
	local high = size.Y.Offset
	local ring = Instance.new("Frame")
	ring.Name = "BounceRing"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(1.3, 1.3)
	ring.BackgroundTransparency = 1
	ring.ZIndex = mark.ZIndex - 1
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = ring
	local line = Instance.new("UIStroke")
	line.Color = ringColour or Color3.fromRGB(255, 214, 80)
	line.Thickness = 3
	line.Transparency = 1
	line.Parent = ring
	ring.Parent = mark
	local function sized(x: number, y: number): UDim2
		return UDim2.new(size.X.Scale * x, size.X.Offset * x, size.Y.Scale * y, size.Y.Offset * y)
	end
	local function lifted(by: number): UDim2
		return place - UDim2.fromOffset(0, by)
	end
	local running = false
	local function once()
		local function step(time: number, goal: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
			local t = TweenService:Create(
				mark,
				TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
				goal
			)
			t:Play()
			t.Completed:Wait()
		end
		-- squash on the ground (its foot stays put)
		step(0.07, { Size = sized(1.3, 0.75), Position = lifted(-high * 0.12) })
		-- the ring, as it leaves
		ring.Size = UDim2.fromScale(1.3, 1.3)
		line.Transparency = 0.1
		TweenService:Create(ring, TweenInfo.new(0.2), { Size = UDim2.fromScale(2.4, 2.4) }):Play()
		TweenService:Create(line, TweenInfo.new(0.2), { Transparency = 1 }):Play()
		-- stretched, up, tipping one way then the other
		local wob = Anim.Bounce.Wobble
		step(0.15, { Size = sized(0.85, 1.18), Position = lifted(high * Anim.Bounce.Hop), Rotation = wob })
		step(0.12, { Size = sized(1, 1), Rotation = -wob * 0.7 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		step(0.13, { Position = place, Rotation = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		-- the landing
		step(0.06, { Size = sized(1.18, 0.85), Position = lifted(-high * 0.07) })
		step(0.1, { Size = size, Position = place }, Enum.EasingStyle.Back)
	end
	local function run()
		if running then
			return
		end
		running = true
		task.spawn(function()
			while mark.Parent and mark.Visible do
				-- one bounce every Every seconds by the clock (a slow frame rate stretched waits counted in steps)
				local due = os.clock() + Anim.Bounce.Every
				once()
				while os.clock() < due and mark.Visible do
					task.wait(math.min(0.1, due - os.clock()))
				end
			end
			mark.Size, mark.Position, mark.Rotation = size, place, 0
			running = false
		end)
	end
	mark:GetPropertyChangedSignal("Visible"):Connect(function()
		if mark.Visible then
			run()
		end
	end)
	if mark.Visible then
		run()
	end
end

return Anim
