--!strict
-- The look of the light while playing: keeps Lighting, our bloom and colour effects and the sky at Config.Look's numbers
-- (Shared/Look does the setting). It looks four times a second for a number that changed, so the N panel's Look rows
-- show at once; nothing is done in a frame where nothing changed. Look.On 0 shows Roblox's plain lighting, to compare.
-- All of it is on this player's machine only. docs/design/lighting.md.
-- The far view (the land that only frames the map, past the gate) is for above the water: while the camera is under
-- the surface it is hidden on this machine (Look.FarUnder), as it stands over the lane and was seen overhead from below.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Look = require(ReplicatedStorage.Shared.Look)

local LookController = {}

local CHECK_EVERY = 0.25
local SKY = "LookSky"
-- the later lands' far view as models (the map's): Workspace.FarView, or, ungrouped, the folders it was built of
local FAR = { "FarView", "Part1", "Part2", "Part3", "Part4" }
local FAR_BACK = 0.4 -- seconds over the surface before the far view is back (a bob at the surface doesn't flicker it)

local last: { [string]: number } = {}
local ownSky: Sky? = nil -- the place's own sky, held while one of ours is shown
local shownSky = -1
local farPainted = false -- the painted far view shows instead of the models
local farUnder = false -- the camera is under the surface
local farHidden = false -- the far view's models are hidden on this machine (either of those)
local farWatched: { [Instance]: RBXScriptConnection } = {}
local underAt = -math.huge -- os.clock() the camera was last under

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

-- Whether this is a piece of the far view (a folder by one of those plain names, with its blocks in it)
local function isFar(thing: Instance): boolean
	return table.find(FAR, thing.Name) ~= nil and (thing:IsA("Folder") or thing:IsA("Model"))
end

-- A piece of the far view that came in: hidden with the rest, and what is added to it later too (it is streamed)
local function watchFar(far: Instance)
	if farWatched[far] or not isFar(far) then
		return
	end
	farWatched[far] = far.DescendantAdded:Connect(function(d: Instance)
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = if farHidden then 1 else 0
		end
	end)
	if farHidden then
		setFarHidden(far, true)
	end
end

local function showFar()
	local hidden = farPainted or (farUnder and Config.Look.FarUnder == 0)
	if hidden ~= farHidden then
		farHidden = hidden
		for far in farWatched do
			setFarHidden(far, hidden)
		end
	end
end

-- Where the camera is against the sea's surface, every frame: cheap, the parts are only touched at a change
local function watchSurface()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local under = camera.CFrame.Position.Y < Config.Depth.SurfaceY
	local now = os.clock()
	if under then
		underAt = now
	elseif now - underAt < FAR_BACK then
		return
	end
	if under ~= farUnder then
		farUnder = under
		showFar()
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
	farPainted = painted
	showFar()
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
	-- (the far view may come in after us, or go)
	workspace.ChildAdded:Connect(watchFar)
	workspace.ChildRemoved:Connect(function(thing: Instance)
		local watched = farWatched[thing]
		if watched then
			watched:Disconnect()
			farWatched[thing] = nil
		end
	end)
	for _, thing in workspace:GetChildren() do
		watchFar(thing)
	end
	changed()
	apply()
	-- (the player can change the graphics quality mid-game, from Roblox's menu)
	UserSettings().GameSettings:GetPropertyChangedSignal("SavedQualityLevel"):Connect(applyVista)
	if RunService:IsStudio() then
		workspace:GetAttributeChangedSignal("LookVista"):Connect(applyVista)
	end
	RunService.RenderStepped:Connect(watchSurface)
	while true do
		task.wait(CHECK_EVERY)
		if changed() then
			apply()
		end
	end
end

return LookController
