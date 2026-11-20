--!strict
-- The tank's prompt and the moment a fish goes in, in the shop kit's look (Hugo, 2026-11-20, task s3: "make placing
-- down fishes UI cohesive with these styles"; UI.Shop, task s1). What they do is AquariumController's, unchanged:
--   TankPrompt.attach(prompt)   draws the tank's ProximityPrompt itself (Style Custom): a key cap (E, or TAP on a
--                               phone, which presses the prompt) that fills as it is held, and a plate in the tank's
--                               Kelp with the prompt's ActionText ("Put in tank", "Ride a fish") and its ObjectText
--                               (the fish's name) in the fish's rarity colour.
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

function TankPrompt.attach(prompt: ProximityPrompt)
	prompt.Style = Enum.ProximityPromptStyle.Custom
	local player = Players.LocalPlayer
	local gui: BillboardGui = Kit.new("BillboardGui", {
		Name = "TankPrompt",
		Adornee = prompt.Parent,
		AlwaysOnTop = true,
		Active = true,
		LightInfluence = 0,
		Size = UDim2.fromOffset(300, 74),
		StudsOffset = Vector3.new(0, 3, 0),
		ResetOnSpawn = false,
		Enabled = false,
	}, player:WaitForChild("PlayerGui"))
	local pop = Kit.new("UIScale", {}, gui)
	local holder: Frame = Kit.new("Frame", {
		Name = "Holder",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, gui)
	pop.Parent = holder

	-- the key cap: a pale kit button with the key; it fills green from the foot while held
	local cap = Shop.button(holder, {
		Name = "Key",
		Kind = "Off",
		Text = "E",
		TextSize = 34,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 4, 0.5, 0),
		Size = UDim2.fromOffset(62, 62),
	})
	cap.Root.ZIndex = 4
	cap.Root.ClipsDescendants = true
	local fillBar: Frame = Kit.new("Frame", {
		Name = "Hold",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Shop.Kinds.Cash[2],
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, cap.Root)
	-- (a tap on the cap presses the prompt: a Custom prompt has no button of its own on a phone)
	cap.Root.InputBegan:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldBegin()
		end
	end)
	cap.Root.InputEnded:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldEnd()
		end
	end)

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

	local function update()
		action.Text = prompt.ActionText
		local kind = byName[prompt.ObjectText]
		object.Text = prompt.ObjectText
		object.Visible = prompt.ObjectText ~= ""
		object.TextColor3 = if kind then tierColour(kind.Tier) else Kit.White
		action.Position = UDim2.fromOffset(10, if object.Visible then 4 else 16)
	end
	prompt:GetPropertyChangedSignal("ActionText"):Connect(update)
	prompt:GetPropertyChangedSignal("ObjectText"):Connect(update)

	local hold: Tween? = nil
	local function unfill()
		if hold then
			hold:Cancel()
			hold = nil
		end
		fillBar.Size = UDim2.fromScale(1, 0)
	end
	prompt.PromptShown:Connect(function(inputType: Enum.ProximityPromptInputType)
		cap.set(if inputType == Enum.ProximityPromptInputType.Touch then "TAP" else "E")
		cap.Label.TextSize = if inputType == Enum.ProximityPromptInputType.Touch then 22 else 34
		update()
		unfill()
		gui.Enabled = true
		pop.Scale = 0.8
		TweenService:Create(pop, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end)
	prompt.PromptHidden:Connect(function()
		gui.Enabled = false
		unfill()
	end)
	prompt.PromptButtonHoldBegan:Connect(function()
		unfill()
		hold = TweenService:Create(
			fillBar,
			TweenInfo.new(math.max(prompt.HoldDuration, 0.05), Enum.EasingStyle.Linear),
			{ Size = UDim2.fromScale(1, 1) }
		);
		(hold :: Tween):Play()
	end)
	prompt.PromptButtonHoldEnded:Connect(unfill)
	prompt.Triggered:Connect(function()
		unfill()
		pop.Scale = 1.12
		TweenService:Create(pop, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end)
	prompt.Destroying:Connect(function()
		gui:Destroy()
	end)
	update()
end

function TankPrompt.deposited(water: BasePart, count: number, gained: number, id: string?)
	local kind = if id then Config.FishById[id] else nil
	local gui: BillboardGui = Kit.new("BillboardGui", {
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
