--!strict
-- The ride fish's keys and slot (task e3, Hugo 2026-11-20: "not holding 1 and pressing q at the same time, 1 should be
-- first inventory slot while q should be a completely seperate slot"; docs/design/equip.md).
--   1 to 9 (and the keypad's): the numbered slot's press, the same path as a click (UI.Slots.pick: the fish is held
--   over the head, AquariumController; the same slot again or an empty one puts it away). Only on the dock, never
--   while typing in a box or when the game took the key.
--   Q: a press of its own, no chord: the held fish becomes the ride fish (Action "RideEquip"; RideService decides),
--   goes into the slot at the far left and is ridden on land. With nothing held, Q rides the equipped one again.
--   The equipped slot: a click or tap is Q while a fish is held, else on or off the ride fish on land ("RideMount");
--   its cross unequips ("RideUnequip").
--   While on the land fish, AnimController poses the rider astride (task e4; the avatar's own sit animation only
--   with Config.LandRide.On 0), and a big fish holds the camera back outside its body (grade issue 8).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local FeelLog = require(script.Parent.Parent.Lib.FeelLog)
local State = require(script.Parent.Parent.Lib.State)
local Slots = require(script.Parent.Parent.UI.Slots)

local EquipController = {}

local NUMBERS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
	[Enum.KeyCode.KeypadOne] = 1,
	[Enum.KeyCode.KeypadTwo] = 2,
	[Enum.KeyCode.KeypadThree] = 3,
	[Enum.KeyCode.KeypadFour] = 4,
	[Enum.KeyCode.KeypadFive] = 5,
	[Enum.KeyCode.KeypadSix] = 6,
	[Enum.KeyCode.KeypadSeven] = 7,
	[Enum.KeyCode.KeypadEight] = 8,
	[Enum.KeyCode.KeypadNine] = 9,
}

local player = Players.LocalPlayer

local function onDock(): boolean
	return State.Mode == "Dock" and player:GetAttribute("State") == "Dock"
end

-- Q, or the equipped slot's press while holding
local function equip()
	if Config.Equip.On ~= 0 and onDock() then
		Net.Action:FireServer("RideEquip")
	end
end

-- The number key's or Q's press, as the game sees it (exposed for the scripted key test, tools/studio/e3_equip_check.py)
function EquipController.press(key: Enum.KeyCode)
	local n = NUMBERS[key]
	if n then
		if onDock() then
			Slots.pick(n)
		end
	elseif key == Enum.KeyCode.Q then
		equip()
	end
end

-- The equipped slot, from the server's attributes
local function show()
	local id = player:GetAttribute("EquippedFish")
	local kind = if type(id) == "string" then Config.FishById[id] else nil
	Slots.equipped(if kind then { Id = kind.Id, Tier = kind.Tier } else nil, player:GetAttribute("LandMounted") == true)
end

-- Sitting on the land fish: the avatar's own sit animation (its Animate script's), looped over the walk at Action
-- priority, on our own body (the Animator sends it to everyone)
local sitting: AnimationTrack? = nil
local function pose()
	-- (with the land motion on, AnimController has the whole body: no sit track under it, grade issue 6)
	local on = player:GetAttribute("LandMounted") == true and Config.LandRide.On == 0
	if on and not sitting then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		local animate = character and character:FindFirstChild("Animate")
		local folder = animate and animate:FindFirstChild("sit")
		local source = folder and folder:FindFirstChildOfClass("Animation")
		if animator and source then
			local ok, track = pcall(function()
				return animator:LoadAnimation(source)
			end)
			if ok and track then
				track.Priority = Enum.AnimationPriority.Action
				track.Looped = true
				track:Play(0.15)
				sitting = track
			end
		end
	elseif not on and sitting then
		sitting:Stop(0.15)
		sitting = nil
	end
end

-- A key press as Roblox gives it: not one the game took, nor typing in a box, nor a number the feel log's pick has
-- (while its numbered tags are up the number keys are its alone, so one press never answers both: grade issue 5).
-- Returns whether the press went on to EquipController.press (the scripted check reads that)
function EquipController.input(input: InputObject, processed: boolean): boolean
	if processed or UserInputService:GetFocusedTextBox() then
		return false
	end
	if (FeelLog.TakesNumbers or FeelLog.TakenInput == input) and NUMBERS[input.KeyCode] then
		return false
	end
	EquipController.press(input.KeyCode)
	return true
end

-- The camera on a big land fish (grade issue 8; Hugo's choice F, the size on land, is still open, so the fish keeps its
-- true size): the camera may not come in closer than the fish is big (Equip.CameraFrom x its largest side), so it
-- stays outside a giant's body instead of inside it. The fish itself never blocks the view (it takes no rays). Off the
-- fish, the player's own zoom limits come back
local zoomWas: { number }? = nil
local zoomToken = 0
local function camera()
	zoomToken += 1
	local token = zoomToken
	local on = player:GetAttribute("LandMounted") == true
	if not on then
		if zoomWas then
			player.CameraMinZoomDistance = zoomWas[1]
			player.CameraMaxZoomDistance = zoomWas[2]
			zoomWas = nil
		end
		return
	end
	task.spawn(function()
		local folder = workspace:WaitForChild("LandFish", 5)
		local model = folder and folder:WaitForChild(player.Name, 5)
		if token ~= zoomToken or not model or not model:IsA("Model") then
			return
		end
		local e = Config.Equip
		local size = model:GetExtentsSize()
		local least = math.max(size.X, size.Y, size.Z) * e.CameraFrom
		if least <= (if zoomWas then zoomWas[1] else player.CameraMinZoomDistance) then
			return -- (a small fish: the player's own zoom is fine)
		end
		if not zoomWas then
			zoomWas = { player.CameraMinZoomDistance, player.CameraMaxZoomDistance }
		end
		least = math.min(least, e.CameraMost)
		player.CameraMaxZoomDistance = math.max((zoomWas :: { number })[2], least + 20)
		player.CameraMinZoomDistance = least
	end)
end

function EquipController.Start()
	UserInputService.InputBegan:Connect(EquipController.input)
	Slots.Ride:Connect(function(what: string)
		if Config.Equip.On == 0 then
			return
		end
		if what == "Unequip" then
			Net.Action:FireServer("RideUnequip")
		elseif player:GetAttribute("HeldFish") ~= nil then
			equip()
		elseif onDock() then
			Net.Action:FireServer("RideMount")
		end
	end)
	for _, name in { "EquippedFish", "EquippedSize", "EquippedVariant", "LandMounted" } do
		player:GetAttributeChangedSignal(name):Connect(show)
	end
	player:GetAttributeChangedSignal("LandMounted"):Connect(pose)
	player:GetAttributeChangedSignal("LandMounted"):Connect(camera)
	player.CharacterAdded:Connect(function()
		sitting = nil
		pose()
		camera()
	end)
	show()
	pose()
	camera()
end

return EquipController
