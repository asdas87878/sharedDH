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
--   While on the land fish, the player's own body sits (the avatar's own sit animation, looped over the walk); its
--   body moves with the humanoid. Land movement by body type is E4's.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
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
	local on = player:GetAttribute("LandMounted") == true
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

function EquipController.Start()
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		EquipController.press(input.KeyCode)
	end)
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
	player.CharacterAdded:Connect(function()
		sitting = nil
		pose()
	end)
	show()
	pose()
end

return EquipController
