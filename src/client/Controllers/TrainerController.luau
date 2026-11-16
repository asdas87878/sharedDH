--!strict
-- The toy rides on the plots rock while their owner trains (TrainService: the owner's "Training" attribute; the plot's
-- "Owner" attribute is their user id). Only on this machine, and only the rides near enough to see: the ride is a
-- handful of anchored parts, turned about its foot.
-- The rock is a stand-in for sitting on it: the bought trainer (docs/Refinement.md, stream 2) seats you.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local TrainerController = {}

local SEE = 260 -- studs: rides further than this from the camera are left alone
local BEAT = 2.4 -- rocks a second
local SWING = math.rad(11)
local LOOK_EVERY = 0.5

type Ride = { Model: Model, Plot: Instance, Rest: CFrame, Foot: Vector3, Moved: boolean }

local rides: { Ride } = {}
local lookedAt = -math.huge

local function gather()
	table.clear(rides)
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local dock = blockout and blockout:FindFirstChild("Dock")
	local plots = dock and dock:FindFirstChild("Plots")
	if not plots then
		return
	end
	for _, plot in plots:GetChildren() do
		local ride = plot:FindFirstChild("TrainerRide")
		local spot = plot:FindFirstChild("TrainerSpot")
		if ride and ride:IsA("Model") and spot and spot:IsA("BasePart") then
			local rest = ride:GetPivot()
			table.insert(rides, {
				Model = ride,
				Plot = plot,
				Rest = rest,
				-- it rocks about where it meets the pad
				Foot = Vector3.new(rest.Position.X, spot.Position.Y + spot.Size.Y / 2, rest.Position.Z),
				Moved = false,
			})
		end
	end
end

local function step()
	local now = os.clock()
	if #rides == 0 then
		-- (the map's parts may arrive after we start)
		if now - lookedAt >= LOOK_EVERY then
			lookedAt = now
			gather()
		end
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	for _, ride in rides do
		local rocking = false
		if (ride.Foot - eye).Magnitude < SEE then
			local owner = ride.Plot:GetAttribute("Owner")
			local player = if type(owner) == "number" then Players:GetPlayerByUserId(owner) else nil
			rocking = player ~= nil and player:GetAttribute("Training") == true
		end
		if rocking then
			local swing = math.sin(now * BEAT * math.pi * 2) * SWING
			local turn = CFrame.new(ride.Foot) * CFrame.Angles(swing, 0, 0) * CFrame.new(-ride.Foot)
			ride.Model:PivotTo(turn * ride.Rest)
			ride.Moved = true
		elseif ride.Moved then
			ride.Model:PivotTo(ride.Rest)
			ride.Moved = false
		end
	end
end

function TrainerController.Start()
	RunService.Heartbeat:Connect(step)
end

return TrainerController
