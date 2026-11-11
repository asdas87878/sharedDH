--!strict
-- The look of the light while playing: keeps Lighting, our bloom and colour effects and the sky at Config.Look's numbers
-- (Shared/Look does the setting). It looks four times a second for a number that changed, so the N panel's Look rows
-- show at once; nothing is done in a frame where nothing changed. Look.On 0 shows Roblox's plain lighting, to compare.
-- All of it is on this player's machine only. docs/design/lighting.md.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Look = require(ReplicatedStorage.Shared.Look)

local LookController = {}

local CHECK_EVERY = 0.25
local SKY = "LookSky"

local last: { [string]: number } = {}
local ownSky: Sky? = nil -- the place's own sky, held while one of ours is shown
local shownSky = -1

local function changed(): boolean
	local any = false
	for name, value in Config.Look :: { [string]: number } do
		if last[name] ~= value then
			last[name] = value
			any = true
		end
	end
	return any
end

-- The skies to choose from, in name order (Studio-owned: ReplicatedStorage.Skies, each a Sky)
local function skies(): { Sky }
	local list: { Sky } = {}
	local folder = ReplicatedStorage:FindFirstChild("Skies")
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
	return list
end

local function showSky(index: number)
	if index == shownSky then
		return
	end
	shownSky = index
	local ours = Lighting:FindFirstChild(SKY)
	if ours then
		ours:Destroy()
	end
	local pick = if index >= 1 then skies()[index] else nil
	if pick then
		if not ownSky then
			local own = Lighting:FindFirstChildOfClass("Sky")
			if own then
				ownSky = own
				own.Parent = nil
			end
		end
		local copy = pick:Clone()
		copy.Name = SKY
		copy.Parent = Lighting
	elseif ownSky then
		(ownSky :: Sky).Parent = Lighting
		ownSky = nil
	end
end

local function apply()
	local v = Config.Look :: { [string]: number }
	Look.apply(Lighting, v)
	-- (switched off: the place's first sky, the plain one, when the folder has it)
	showSky(if v.On > 0 then math.floor(v.Sky + 0.5) else 1)
end

function LookController.Start()
	changed()
	apply()
	while true do
		task.wait(CHECK_EVERY)
		if changed() then
			apply()
		end
	end
end

return LookController
