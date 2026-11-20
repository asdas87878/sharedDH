--!strict
-- The tank's prompt and the moment a fish goes in, in the shop kit's look (Hugo, 2026-11-20, task s3: "make placing
-- down fishes UI cohesive with these styles"; UI.Shop, task s1). What they do is AquariumController's, unchanged:
--   TankPrompt.attach(at, onPress)   the click control on the tank's front glass (task e2: no E, no hold): a green cap
--                               saying CLICK (TAP on a phone) and a plate in the tank's Kelp with what it does ("PUT IN
--                               TANK", "RIDE A FISH") and the fish's name in its rarity colour. One click or tap on any
--                               of it does it; a refusal is said on it for a moment.
--   TankPrompt.deposited(water, count, gained, id)   the line over the tank as a fish goes in: a slate plate, the
--                               fish's name in its rarity's colour "in your tank!", and "+$12/s" in the shop's green;
--                               it rises and fades.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Kit)
local Shop = require(script.Parent.Shop)

local TankPrompt = {}

-- a fish's kind by its shown name (the prompt carries only the name)
local byName: { [string]: any } = {}
for _, kind in Config.Fish do
	byName[kind.Name] = kind
end

local function tierColour(tier: string?): Color3
	local entry = tier and Config.Tiers[tier]
	local colour = if entry then entry.Colour else Kit.White
	-- (the Secret's own colour is near black: drawn pink here)
	return if colour.R + colour.G + colour.B < 0.6 then Kit.Pink else colour
end

local function plate(parent: Instance, colour: Color3, props: { [string]: any }): Frame
	props.BackgroundColor3 = Kit.White
	props.BorderSizePixel = 0
	local frame: Frame = Kit.new("Frame", props, parent)
	Kit.corner(frame, 6)
	Kit.stroke(frame, 3, Shop.Edge)
	Kit.new("UIGradient", { Rotation = 90, Color = Shop.halves(Kit.lighter(colour, 0.22), colour, 0.46) }, frame)
	Shop.pattern(frame, "Head", 26, 0.86)
	return frame
end

local current: Control? = nil -- the control drawn last (one tank a player: their own)

export type Control = {
	Gui: BillboardGui,
	Button: TextButton, -- the whole control: one click or tap on it does the action
	press: () -> boolean, -- what a click on it does (true when it did something: shown, not a repeat)
	set: (shown: boolean, action: string, object: string) -> (),
	refused: (why: string) -> (),
	destroy: () -> (),
}

-- What a refusal says on the control (AquariumService: Ride "Denied", "Place", reason)
local WHY = {
	Far = "WALK CLOSER!",
	Gone = "THAT FISH IS GONE",
	Busy = "NOT NOW",
}

-- The control on the tank's front glass (task e2, Hugo 2026-11-20: no E, a click): a CLICK (TAP on a phone) cap and a
-- Kelp plate with what it does ("PUT IN TANK", "RIDE A FISH") and the fish's name in its rarity colour. The whole of it
-- is one button: a click or a tap calls onPress once, at once (no hold, no key). The caller says when it shows (set).
function TankPrompt.attach(at: Attachment, onPress: () -> ()): Control
	local player = Players.LocalPlayer
	local gui: BillboardGui = Kit.new("BillboardGui", {
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Name = "TankPrompt",
		Adornee = at,
		AlwaysOnTop = true,
		Active = true,
		LightInfluence = 0,
		Size = UDim2.fromOffset(300, 74),
		StudsOffset = Vector3.new(0, 3, 0),
		ResetOnSpawn = false,
		Enabled = false,
	}, player:WaitForChild("PlayerGui"))
	local holder: Frame = Kit.new("Frame", {
		Name = "Holder",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, gui)
	local pop = Kit.new("UIScale", {}, holder)

	-- the cap: a green kit button saying how (CLICK, or TAP on a phone)
	local cap = Shop.button(holder, {
		Name = "Key",
		Kind = "Cash",
		Text = "CLICK",
		TextSize = 17,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 4, 0.5, 0),
		Size = UDim2.fromOffset(62, 62),
	})
	cap.Root.ZIndex = 4
	local board = plate(holder, Shop.Heads.Kelp, {
		Name = "Board",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 76, 0.5, 0),
		Size = UDim2.new(1, -80, 0, 62),
		ZIndex = 2,
	})
	Shop.gloss(board, 0.7, 0.24)
	local action = Shop.text(board, {
		Name = "Action",
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -16, 0, 30),
		TextSize = 27,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
	})
	local object = Shop.text(board, {
		Name = "Object",
		Position = UDim2.fromOffset(10, 34),
		Size = UDim2.new(1, -16, 0, 22),
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 4,
	})
	-- one invisible button over the whole control, on top, so the cap and the plate are one target (and the press
	-- is the GUI's: the tank's own world click, TankPanel, does not see it)
	local hit: TextButton = Kit.new("TextButton", {
		Name = "Hit",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Active = true,
		ZIndex = 10,
	}, holder)
	local shown, actionText, objectText = false, "", ""
	local saying: string? = nil -- a refusal, said for a moment over the action
	local function draw()
		cap.set(if Kit.touch() then "TAP" else "CLICK")
		action.Text = saying or actionText
		action.TextColor3 = if saying then Kit.Coral else Kit.White
		local kind = byName[objectText]
		object.Text = objectText
		object.Visible = objectText ~= "" and saying == nil
		object.TextColor3 = if kind then tierColour(kind.Tier) else Kit.White
		action.Position = UDim2.fromOffset(10, if object.Visible then 4 else 16)
	end
	local last = 0
	local function activate(): boolean
		-- (one press, one action: a second within a moment is the same press)
		local now = os.clock()
		if not shown or now - last < 0.25 then
			return false
		end
		last = now
		pop.Scale = 1.12
		TweenService:Create(pop, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
		onPress()
		return true
	end
	hit.Activated:Connect(activate)
	local self: Control = {
		Gui = gui,
		Button = hit,
		press = activate,
		set = nil :: any,
		refused = nil :: any,
		destroy = nil :: any,
	}
	local touch = Kit.touch()
	function self.set(on: boolean, act: string, obj: string)
		-- (a phone's TAP or a mouse's CLICK: the last input decides, looked at each time the caller asks)
		local nowTouch = Kit.touch()
		if act ~= actionText or obj ~= objectText or nowTouch ~= touch then
			touch = nowTouch
			actionText, objectText = act, obj
			draw()
		end
		if on ~= shown then
			shown = on
			gui.Enabled = on
			if on then
				draw()
				pop.Scale = 0.8
				TweenService
					:Create(pop, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
					:Play()
			end
		end
	end
	function self.refused(why: string)
		local said = WHY[why] or "NOT NOW"
		saying = said
		draw()
		task.delay(1.6, function()
			if saying == said then
				saying = nil
				draw()
			end
		end)
	end
	function self.destroy()
		gui:Destroy()
		if current == self then
			current = nil
		end
	end
	current = self
	at.Destroying:Connect(self.destroy)
	draw()
	return self
end

-- (for Studio's tests: click our tank's control as a click does; false when it is hidden or the click a repeat)
function TankPrompt.press(): boolean
	return current ~= nil and current.press()
end

-- (for Studio's tests: the control, to read what it shows)
function TankPrompt.control(): Control?
	return current
end

function TankPrompt.deposited(water: BasePart, count: number, gained: number, id: string?)
	local kind = if id then Config.FishById[id] else nil
	local gui: BillboardGui = Kit.new("BillboardGui", {
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Name = "Deposited",
		AlwaysOnTop = true,
		LightInfluence = 0,
		Size = UDim2.fromOffset(420, 104),
		StudsOffsetWorldSpace = Vector3.new(0, -water.Size.Y / 2 + 12, 0),
		Adornee = water,
	}, nil)
	local group: CanvasGroup = Kit.new("CanvasGroup", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, gui)
	local back: Frame = Kit.new("Frame", {
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 1, -8),
		BackgroundColor3 = Shop.Body,
		BorderSizePixel = 0,
	}, group)
	Kit.corner(back, 8)
	Kit.stroke(back, 3, Shop.Edge)
	Kit.gradient(back, Kit.lighter(Shop.Body, 0.04), Kit.darker(Shop.Body, 0.12))
	Shop.pattern(back, "Body", 36, 0.9)
	-- a Kelp strip along the top, as the window's header
	plate(back, Shop.Heads.Kelp, {
		Name = "Strip",
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 0, 8),
		ZIndex = 2,
	})
	local name = if kind and count == 1 then kind.Name else string.format("+%d fish", count)
	local colour = if kind and count == 1 then tierColour(kind.Tier) else Kit.White
	Shop.text(back, {
		Position = UDim2.fromOffset(10, 14),
		Size = UDim2.new(1, -20, 0, 38),
		TextSize = 32,
		RichText = true,
		Text = string.format(
			'<font color="#%s">%s</font> in your tank!',
			colour:ToHex(),
			(string.gsub(name, "[<>&]", ""))
		),
		ZIndex = 3,
	})
	local label, holder = Shop.money(back, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 52),
		Size = UDim2.new(1, -20, 0, 38),
		TextSize = 32,
		Align = Enum.HorizontalAlignment.Center,
		ZIndex = 3,
	})
	holder.ZIndex = 3
	label.Text = "+" .. Shop.cash(gained) .. "/s"
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local rise = TweenInfo.new(2.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, rise, { StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + Vector3.new(0, 10, 0) }):Play()
	task.delay(1.8, function()
		TweenService:Create(group, TweenInfo.new(0.6), { GroupTransparency = 1 }):Play()
		task.wait(0.7)
		gui:Destroy()
	end)
end

return TankPrompt
