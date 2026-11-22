--!strict
-- The look of the light while playing: keeps Lighting, our bloom and colour effects and the sky at Config.Look's numbers
-- (Shared/Look does the setting). It looks four times a second for a number that changed, so the N panel's Look rows
-- show at once; nothing is done in a frame where nothing changed. Look.On 0 shows Roblox's plain lighting, to compare.
-- All of it is on this player's machine only. docs/design/lighting.md.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Look = require(ReplicatedStorage.Shared.Look)

local LookController = {}

local CHECK_EVERY = 0.25
local SKY = "LookSky"
local FAR = "FarView" -- the later lands' far view as models (the map's, Workspace.FarView)

local last: { [string]: number } = {}
local ownSky: Sky? = nil -- the place's own sky, held while one of ours is shown
local shownSky = -1
local farHidden = false -- the far view's models hidden on this machine (the painted one shows instead)
local farWatched: Instance? = nil

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
		-- (its own back face, to go back to from the painted far view)
		copy:SetAttribute("SkyboxBkOwn", copy.SkyboxBk)
		copy.Parent = Lighting
	elseif ownSky then
		(ownSky :: Sky).Parent = Lighting
		ownSky = nil
	end
end

-- Whether this machine draws too near for the far view's models (Look.VistaLowest, Look.VistaTouch). In Studio the
-- workspace's "LookVista" (true or false) decides, to see both.
local function drawsNear(): boolean
	if RunService:IsStudio() then
		local forced = workspace:GetAttribute("LookVista")
		if type(forced) == "boolean" then
			return forced
		end
	end
	local v = Config.Look :: { [string]: number }
	local level = UserSettings().GameSettings.SavedQualityLevel.Value -- 0 Automatic, else 1 to 10
	if level >= 1 then
		return level <= (v.VistaLowest or 0)
	end
	-- (Automatic: the level Roblox picks is for its own scripts only, so a phone or tablet is taken to draw near)
	return (v.VistaTouch or 0) > 0 and UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function setFarHidden(far: Instance, hidden: boolean)
	for _, d in far:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

-- The far view: the models where this machine draws far, else the painted one on the sky's back face (its
-- "SkyboxBkVista") with the models hidden here, so the two never show at once. Cheap when nothing changed.
local function applyVista()
	local ours = Lighting:FindFirstChild(SKY)
	local vista = if ours then ours:GetAttribute("SkyboxBkVista") else nil
	local painted = type(vista) == "string" and vista ~= "" and (Config.Look :: any).On > 0 and drawsNear()
	if ours and ours:IsA("Sky") then
		local own = ours:GetAttribute("SkyboxBkOwn")
		local want = if painted then vista else own
		if type(want) == "string" and ours.SkyboxBk ~= want then
			ours.SkyboxBk = want
		end
	end
	local far = workspace:FindFirstChild(FAR)
	if far and far ~= farWatched then
		-- (it may come in after us, and a part added to it later is hidden with the rest)
		farWatched = far
		farHidden = not painted
		far.DescendantAdded:Connect(function(d: Instance)
			if farHidden and d:IsA("BasePart") then
				d.LocalTransparencyModifier = 1
			end
		end)
	end
	if far and farHidden ~= painted then
		farHidden = painted
		setFarHidden(far, painted)
	end
end

local function apply()
	local v = Config.Look :: { [string]: number }
	Look.apply(Lighting, v)
	-- (switched off: the place's first sky, the plain one, when the folder has it)
	showSky(if v.On > 0 then math.floor(v.Sky + 0.5) else 1)
	-- the sky tipped toward the lane, so its clouds sit down on the far land (Look.SkyTilt)
	local ours = Lighting:FindFirstChild(SKY)
	if ours and ours:IsA("Sky") then
		ours.SkyboxOrientation = Vector3.new(if v.On > 0 then v.SkyTilt or 0 else 0, 0, 0)
	end
	applyVista()
end

function LookController.Start()
	changed()
	apply()
	-- (the player can change the graphics quality mid-game, from Roblox's menu)
	UserSettings().GameSettings:GetPropertyChangedSignal("SavedQualityLevel"):Connect(applyVista)
	if RunService:IsStudio() then
		workspace:GetAttributeChangedSignal("LookVista"):Connect(applyVista)
	end
	while true do
		task.wait(CHECK_EVERY)
		if changed() then
			apply()
		elseif farWatched == nil and workspace:FindFirstChild(FAR) then
			-- (the far view came in after the look was set)
			applyVista()
		end
	end
end

return LookController
