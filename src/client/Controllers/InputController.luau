--!strict
-- Inputs for PC, gamepad and mobile while underwater. One button, as in the reference:
--   Jump (Space, gamepad A, the mobile jump button): on a fish or floating, jump into the flight; in the flight, drop
--   at once. On the dock, jumping is the normal jump. Nothing works while drowning.
-- Steering (the fish, and the flight) reads the move vector in RideController.
local UserInputService = game:GetService("UserInputService")

local Actions = require(script.Parent.Parent.Lib.Actions)
local State = require(script.Parent.Parent.Lib.State)

local InputController = {}

local lastJump = -math.huge

function InputController.Init()
	-- JumpRequest repeats while held; a gap means a new press
	UserInputService.JumpRequest:Connect(function()
		local t = os.clock()
		local fresh = t - lastJump > 0.2
		lastJump = t
		if fresh and State.inWater() and not State.dying() then
			Actions.jump()
		end
	end)
end

return InputController
