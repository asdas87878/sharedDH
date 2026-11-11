-- Puts the game's light (Config.Look) on the open place in Studio's Edit mode, so the place looks while building as it
-- does while playing (Controllers/LookController sets the same numbers at run time), and sets the one thing a game
-- script can't: Lighting's style, Realistic. Run it again after changing Config.Look for good.
--   node tools/studio/run_luau.js <studio_id> tools/studio/look_install.luau
-- It needs the game code in the place (ReplicatedStorage.Shared). The sky shown in Edit mode is Config.Look.Sky of
-- ReplicatedStorage.Skies in name order (0 leaves the Sky that is in Lighting); the place's first sky is kept there as
-- "1 Place".
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Studio keeps a module it has read once, so a second run would get the old numbers: read a fresh copy each time.
local function fresh(module: ModuleScript): any
	local copy = module:Clone()
	copy.Name = module.Name .. "_LookInstall"
	copy.Parent = module.Parent
	local ok, result = pcall(require, copy)
	copy:Destroy()
	if not ok then
		error(result)
	end
	return result
end

local Config = fresh(ReplicatedStorage.Shared.Config)
local Look = fresh(ReplicatedStorage.Shared.Look)

local v = Config.Look
Look.apply(Lighting, v)

local styled = pcall(function()
	Lighting.LightingStyle = Enum.LightingStyle.Realistic
end)

local folder = ReplicatedStorage:FindFirstChild("Skies")
local list = {}
if folder then
	for _, child in folder:GetChildren() do
		if child:IsA("Sky") then
			table.insert(list, child)
		end
	end
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
end
local pick = list[math.floor(v.Sky + 0.5)]
local shown = "the place's own"
if v.On > 0 and pick then
	for _, child in Lighting:GetChildren() do
		if child:IsA("Sky") then
			child:Destroy()
		end
	end
	local copy = pick:Clone()
	copy.Name = "Sky"
	copy.Parent = Lighting
	shown = pick.Name
end

return string.format(
	"look installed: brightness %s, bloom %s, contrast %s, saturation %s; style Realistic %s; sky: %s (%d to choose from)",
	tostring(Lighting.Brightness),
	tostring(v.BloomSize),
	tostring(v.Contrast),
	tostring(v.Saturation),
	if styled then "set" else "NOT set (set Lighting.LightingStyle by hand)",
	shown,
	#list
)
