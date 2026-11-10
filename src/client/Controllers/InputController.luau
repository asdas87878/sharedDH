--!strict
-- Inputs for PC, gamepad and mobile while underwater:
--   Jump (Space, gamepad A, the mobile jump button): dash to the marked fish; with none marked, jump off into the hook
--     window; in the window, fire (the one shot).
--   Dash (E, gamepad X, a touch button): dash only. Hook (F or Q, gamepad Y, a touch button): jump off into the window,
--     always. In the window either one fires too, and so does a left click. On the dock, jumping is the normal jump.
--   Nothing works while dying (eaten or drowning): the buttons go away.
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local Actions = require(script.Parent.Parent.Lib.Actions)
local State = require(script.Parent.Parent.Lib.State)

local InputController = {}

local lastJump = -math.huge
local bound = false

local function onJump()
	if State.Mode == "Aiming" then
		Actions.fire()
	elseif State.Mode == "Riding" or State.Mode == "Free" then
		if not Actions.dash() then
			Actions.beginAim()
		end
	end
end

local function onDash(_name: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState == Enum.UserInputState.Begin then
		if State.Mode == "Aiming" then
			Actions.fire()
		else
			Actions.dash()
		end
	end
	return Enum.ContextActionResult.Sink
end

local function onHook(_name: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState == Enum.UserInputState.Begin then
		if State.Mode == "Aiming" then
			Actions.fire()
		else
			Actions.beginAim()
		end
	end
	return Enum.ContextActionResult.Sink
end

local function rebind()
	local want = State.inWater() and not State.dying()
	if want == bound then
		return
	end
	bound = want
	if want then
		ContextActionService:BindAction("RideDash", onDash, true, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
		ContextActionService:SetTitle("RideDash", "Dash")
		ContextActionService:SetPosition("RideDash", UDim2.new(1, -170, 1, -150))
		ContextActionService:BindAction("RideHook", onHook, true, Enum.KeyCode.F, Enum.KeyCode.Q, Enum.KeyCode.ButtonY)
		ContextActionService:SetTitle("RideHook", "Hook")
		ContextActionService:SetPosition("RideHook", UDim2.new(1, -110, 1, -210))
	else
		ContextActionService:UnbindAction("RideDash")
		ContextActionService:UnbindAction("RideHook")
	end
end

function InputController.Init()
	-- JumpRequest repeats while held; a gap means a new press
	UserInputService.JumpRequest:Connect(function()
		local t = os.clock()
		local fresh = t - lastJump > 0.2
		lastJump = t
		if fresh and State.inWater() and not State.dying() then
			onJump()
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.MouseButton1 and State.Mode == "Aiming" then
			Actions.fire()
		end
	end)
	State.ModeChanged.Event:Connect(rebind)
end

function InputController.Start()
	rebind()
end

return InputController
