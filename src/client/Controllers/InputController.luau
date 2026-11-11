--!strict
-- Inputs for PC, gamepad and mobile while underwater. One button, as in the reference:
--   Jump (Space, gamepad A, the mobile jump button): on a fish or floating, leave into the hop; in the hop, grab the
--   locked fish. In the hop a left click, E and gamepad X grab too. On the dock, jumping is the normal jump. Nothing
--   works while drowning.
-- Steering (A and D only: the fish, the hop and floating) reads the move vector in RideController.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local UserInputService = game:GetService("UserInputService")

local Actions = require(script.Parent.Parent.Lib.Actions)
local State = require(script.Parent.Parent.Lib.State)

local InputController = {}

local lastJump = -math.huge

function InputController.Init()
	-- JumpRequest repeats while held; a gap means a new press
	UserInputService.JumpRequest:Connect(function()
		local t = os.clock()
		local fresh = t - lastJump > Config.Jump.InputGap
		lastJump = t
		if fresh and State.inWater() and not State.dying() then
			Actions.jump()
		end
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
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
