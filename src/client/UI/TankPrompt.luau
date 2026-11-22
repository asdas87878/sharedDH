--!strict
-- The moment a fish goes in, in the shop kit's look (Hugo, 2026-11-20, task s3: "make placing down fishes UI cohesive
-- with these styles"; UI.Shop, task s1):
--   TankPrompt.deposited(water, count, gained, id)   the line over the tank as a fish goes in, formatted as the
--                               reference's (UI review 1, 2026-11-22): a studded slate plate, "<Name> is in your tank!"
--                               with the name in the cash green, and a green "+$12/s!" chip under it; it pops in,
--                               rises and fades.
-- (The click control on the tank's glass, "CLICK / PUT IN TANK" and "RIDE A FISH", is gone: Hugo, 2026-11-20, task c1:
-- a click on the tank opens its popup, UI.TankPanel, where fish are put in and a tank fish is ridden.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Anim = require(script.Parent.Anim)
local Kit = require(script.Parent.Kit)
local Shop = require(script.Parent.Shop)

local TankPrompt = {}

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
	Kit.corner(back, Shop.Round.Card)
	Kit.stroke(back, 3, Shop.Edge)
	Kit.gradient(back, Kit.lighter(Shop.Body, 0.04), Kit.darker(Shop.Body, 0.12))
	Shop.pattern(back, "Body")
	local one = kind ~= nil and count == 1
	local name = if one then (kind :: any).Name else string.format("%d fish", count)
	Shop.text(back, {
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(1, -20, 0, 38),
		TextSize = 32,
		RichText = true,
		Text = string.format(
			'<font color="#%s">%s</font> %s in your tank!',
			Shop.Money:ToHex(),
			(string.gsub(name, "[<>&]", "")),
			if one then "is" else "are"
		),
		ZIndex = 3,
	})
	-- the chip: what it earns, on a green pill
	local chip: Frame = Kit.new("Frame", {
		Name = "Chip",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 50),
		Size = UDim2.fromOffset(170, 38),
		BackgroundColor3 = Kit.White,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, back)
	Kit.corner(chip, 999)
	Kit.stroke(chip, 3, Shop.Edge)
	Kit.new("UIGradient", { Rotation = 90, Color = Shop.halves(Shop.Kinds.Cash[1], Shop.Kinds.Cash[2]) }, chip)
	Shop.text(chip, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 28,
		Text = "+" .. Shop.cash(gained) .. "/s!",
		ZIndex = 4,
	})
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	Anim.punch(group, 0.5)
	local rise = TweenInfo.new(2.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, rise, { StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + Vector3.new(0, 10, 0) }):Play()
	task.delay(1.8, function()
		TweenService:Create(group, TweenInfo.new(0.6), { GroupTransparency = 1 }):Play()
		task.wait(0.7)
		gui:Destroy()
	end)
end

return TankPrompt
