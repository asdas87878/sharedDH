--!strict
-- A fish that comes into the water where it can be seen fades in. Since 2026-11-16 fish are made only well away from
-- every player (Config.Spawn.SightClear, 500 studs along the lane) and come back into the water 700 studs off, but
-- the water's fog only ends at 1,550, so both can still be seen arriving; and at the lane's very start, where the herd
-- begins and players stand, fish come in at the gate in plain sight (FishService: the entry). Each popped out of
-- nothing; here it takes TIME to show.
-- Only on this machine (LocalTransparencyModifier), so nothing is sent and the fish's own look is never changed.
local RunService = game:GetService("RunService")

local ArriveController = {}

local NEAR = 1000 -- studs from the camera: nearer than this, a new fish fades in
local TIME = 0.6 -- seconds

local arriving: { [Model]: number } = {} -- fish -> os.clock() it came
local stepping: RBXScriptConnection? = nil

local function show(model: Model, hidden: number)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = hidden
		end
	end
end

local function step()
	local now = os.clock()
	local any = false
	for model, at in arriving do
		local t = (now - at) / TIME
		if t >= 1 or not model.Parent then
			arriving[model] = nil
			if model.Parent then
				show(model, 0)
			end
		else
			any = true
			show(model, 1 - t * t)
		end
	end
	if not any and stepping then
		stepping:Disconnect()
		stepping = nil
	end
end

local function came(child: Instance)
	local camera = workspace.CurrentCamera
	if not child:IsA("Model") or not camera then
		return
	end
	-- (a moment for its parts to arrive)
	task.defer(function()
		local root = child.PrimaryPart
		if not root or not child.Parent then
			return
		end
		if (root.Position - camera.CFrame.Position).Magnitude > NEAR then
			return
		end
		arriving[child] = os.clock()
		show(child, 1)
		if not stepping then
			stepping = RunService.RenderStepped:Connect(step)
		end
	end)
end

function ArriveController.Start()
	local folder = workspace:WaitForChild("Fish", 30)
	if folder then
		-- (the fish already there when we join are not new)
		folder.ChildAdded:Connect(came)
	end
end

return ArriveController
