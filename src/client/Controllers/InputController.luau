--!strict
-- Inputs for PC, gamepad and mobile while underwater. One button, as in the reference:
--   Jump (Space, gamepad A, the mobile jump button): on a fish or floating, leave into the hop; in the hop, grab the
--   locked fish. In the hop a left click, E and gamepad X grab too. On the dock, jumping is the normal jump. Nothing
--   works while drowning.
-- Steering (A and D only: the fish, the hop and floating) reads the move vector in RideController.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Actions = require(script.Parent.Parent.Lib.Actions)
local State = require(script.Parent.Parent.Lib.State)

local InputController = {}

local lastJump = -math.huge
-- The fresh-press rule on a key (Hugo, 2026-11-13: the wait between fish is nearly nothing now, so a HELD Space must
-- never count as a second press, whatever the frame rate does): Space and gamepad A are armed by going down, and
-- one press is one jump request. A held key repeats JumpRequest every frame; while the key is down those repeats are
-- not presses, however long the gap between two of them (a hitch). And a real second press counts however soon
-- after the first. The mobile button has no key to read: there a gap of Jump.InputGap is a new press, as before.
local armed = false -- Space or gamepad A went down and hasn't been used by a jump request yet
local keySeen = false -- we have seen one of them go down at all (until then the gap rule decides, as before)

local function jumpKeyDown(): boolean
	return UserInputService:IsKeyDown(Enum.KeyCode.Space)
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA)
end

function InputController.Init()
	local function act()
		if State.inWater() and not State.dying() then
			Actions.jump()
		end
	end
	-- JumpRequest repeats while held; a new press of the key, or (with no key down) a gap, means a new press
	UserInputService.JumpRequest:Connect(function()
		local t = os.clock()
		local gap = t - lastJump > Config.Jump.InputGap
		lastJump = t
		if keySeen and jumpKeyDown() then
			if armed then
				armed = false
				act()
			elseif gap then
				-- (the key's own word can come after the request it caused: look again when this frame's input is
				-- through. Still not armed then: a held key after a hitch, not a press)
				RunService.Heartbeat:Once(function()
					if armed then
						armed = false
						act()
					end
				end)
			end
			return
		end
		armed = false
		if gap then
			act()
		end
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			armed = true
			keySeen = true
		end
		if processed or State.Mode ~= "Jumping" then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.KeyCode == Enum.KeyCode.E
			or input.KeyCode == Enum.KeyCode.ButtonX
		then
			Actions.jump()
		end
	end)
end

return InputController
