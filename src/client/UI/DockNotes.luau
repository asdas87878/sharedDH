--!strict
-- The dock's lines in the middle of the screen, formatted as the reference's deposit (UI review 1, the user,
-- 2026-11-22: "if we have a deposit fish UI, make sure its formatted liek ride a dino"):
--   DockNotes.carrying(on)   "GO TO YOUR TANK TO DEPOSIT" low in the middle while this player carries a catch on the
--                            dock and no window is up (Controllers/StallController asks every look)
--   DockNotes.full(line)     a pink "TANK FULL!" pill and one short line under it, popping in (0.17 s), gone after 2 s
-- (The line over the tank as a fish goes in is UI.TankPrompt's.)
local Players = game:GetService("Players")

local Anim = require(script.Parent.Anim)
local Kit = require(script.Parent.Kit)
local Shop = require(script.Parent.Shop)

local DockNotes = {}

local CARRY_AT = 0.686 -- the reference's: the line's middle, down the screen
local FULL_AT = 0.6
local FULL_STAY = 2

local gui: ScreenGui? = nil
local carry: TextLabel
local full: Frame
local fullLine: TextLabel
local fullAt = -math.huge
local carryOn = false

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
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	carry = Shop.text(root, {
		Name = "Carry",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, CARRY_AT),
		Size = UDim2.fromOffset(700, 40),
		TextSize = 30,
		Text = "GO TO YOUR TANK TO DEPOSIT",
		Visible = false,
	})
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
	Kit.new("UIGradient", {
		Rotation = 90,
		Color = Shop.halves(Color3.fromRGB(255, 120, 190), Color3.fromRGB(226, 52, 140)),
	}, pill)
	Shop.text(pill, { Size = UDim2.fromScale(1, 1), TextSize = 32, Text = "TANK FULL!", ZIndex = 2 })
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

function DockNotes.carrying(on: boolean)
	if on == carryOn then
		return
	end
	carryOn = on
	if not gui then
		if not on then
			return
		end
		build()
	end
	Anim.toast(carry, on)
end

function DockNotes.full(line: string)
	if not gui then
		build()
	end
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
