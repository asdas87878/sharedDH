--!nocheck
-- A live test of the water's see-through (2026-11-22, the user: "experiment with a few variants of the water in its
-- transparency ... It needs to be more transparent so you can see the fish in the water"). Run on the CLIENT while
-- playing: a row of buttons at the top of the screen sets the four layers of tools/map/water_look.luau
-- (Foam glass, Water1, Water2, Water3) to each variant. Nothing is saved: gone when Play stops.
-- The share of the view that gets through is about the four see-throughs multiplied (now 0.35*0.76*0.78*0.85 = 18%).
-- usage: python C:/Users/blast/RpgGame/tools/studio/studio_mcp.py call execute_luau '{"datamodel_type":"Client",...}'
local VARIANTS = {
	{ "Now 18%", { 0.35, 0.76, 0.78, 0.85 } },
	{ "A 35%", { 0.55, 0.82, 0.86, 0.88 } },
	{ "B 50%", { 0.7, 0.88, 0.9, 0.9 } },
	{ "C 65%", { 0.82, 0.92, 0.93, 0.93 } },
	{ "D 50% no glass", { 1, 0.7, 0.85, 0.85 } },
}
local layers = workspace.ClaudeBlockout.Surface:WaitForChild("WaterLayers")
local names = { "Foam", "Water1", "Water2", "Water3" }
local gui = game.Players.LocalPlayer.PlayerGui:FindFirstChild("WaterSeeTest") or Instance.new("ScreenGui")
gui.Name = "WaterSeeTest"
gui.ResetOnSpawn = false
gui:ClearAllChildren()
local row = Instance.new("Frame")
row.Size = UDim2.fromOffset(5 * 128, 36)
row.Position = UDim2.new(0.5, -5 * 64, 0, 8)
row.BackgroundTransparency = 1
row.Parent = gui
local list = Instance.new("UIListLayout")
list.FillDirection = Enum.FillDirection.Horizontal
list.Padding = UDim.new(0, 6)
list.Parent = row
local buttons = {}
local function pick(i)
	for k, name in names do
		local p = layers:FindFirstChild(name)
		if p then
			p.Transparency = VARIANTS[i][2][k]
		end
	end
	for j, b in buttons do
		b.BackgroundColor3 = j == i and Color3.fromRGB(255, 210, 60) or Color3.fromRGB(30, 40, 60)
		b.TextColor3 = j == i and Color3.new(0, 0, 0) or Color3.new(1, 1, 1)
	end
end
for i, v in VARIANTS do
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(122, 36)
	b.Text = "Water " .. v[1]
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.Parent = row
	b.MouseButton1Click:Connect(function()
		pick(i)
	end)
	buttons[i] = b
end
gui.Parent = game.Players.LocalPlayer.PlayerGui
pick(1)
return "water see-through buttons up: " .. #VARIANTS .. " variants"
