--!strict
-- The moment a fish goes in, in the shop kit's look (Hugo, 2026-11-20, task s3: "make placing down fishes UI cohesive
-- with these styles"; UI.Shop, task s1):
--   TankPrompt.deposited(water, count, gained, id)   the line over the tank as a fish goes in: a slate plate, the
--                               fish's name in its rarity's colour "in your tank!", and "+$12/s" in the shop's green;
--                               it rises and fades.
-- (The click control on the tank's glass, "CLICK / PUT IN TANK" and "RIDE A FISH", is gone: Hugo, 2026-11-20, task c1:
-- a click on the tank opens its popup, UI.TankPanel, where fish are put in and a tank fish is ridden.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Kit)
local Shop = require(script.Parent.Shop)

local TankPrompt = {}

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
