--!strict
-- The movement sandbox, server side (Studio only; docs/sandbox.md): for play-testing the ride, the jump and the camera.
-- It keeps the switches as Workspace attributes (Sandbox, SandboxNoFail, SandboxEndlessAir; RideService reads them),
-- takes the tuning panel's number changes into the server's copy of Config, and resets a player to the lane's start.
-- Outside Studio it does nothing, and its remote is ignored.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local FishService = require(script.Parent.FishService)
local RideService = require(script.Parent.RideService)

local SandboxService = {}

local FLAGS = { On = "Sandbox", NoFail = "SandboxNoFail", EndlessAir = "SandboxEndlessAir" }

-- "Jump.LaunchTime" = 0.9, or "ZoneDrain.3" = 14 for a list: only numbers that are already in Config
local function tune(path: any, value: any)
	if type(path) ~= "string" or type(value) ~= "number" or value ~= value then
		return
	end
	local group, name = string.match(path, "^(%a+)%.(%w+)$")
	local key: any = tonumber(name) or name
	local tableOf = group and (Config :: any)[group]
	if type(tableOf) ~= "table" or type(tableOf[key]) ~= "number" then
		return
	end
	tableOf[key] = value
	Config.refresh()
	if group == "Spawn" then
		FishService.restock()
	elseif path == "Oxygen.StartMax" then
		RideService.readMax()
	end
end

function SandboxService.Init()
	if not RunService:IsStudio() then
		return
	end
	local s = Config.Sandbox
	workspace:SetAttribute(FLAGS.On, s.On)
	workspace:SetAttribute(FLAGS.NoFail, s.NoFail)
	workspace:SetAttribute(FLAGS.EndlessAir, s.EndlessAir)
	Net.Sandbox.OnServerEvent:Connect(function(player, kind, a, b)
		if kind == "Tune" then
			tune(a, b)
		elseif kind == "Flag" and type(a) == "string" and type(b) == "boolean" then
			local attribute = (FLAGS :: any)[a]
			if attribute then
				workspace:SetAttribute(attribute, b)
			end
		elseif kind == "Reset" then
			RideService.sandboxReset(player)
		end
	end)
end

-- The fish round the sandbox's start are kept in the Workspace from the beginning, so the first reset finds fish that
-- every machine already knows (RideService: SEAT_SETTLED)
function SandboxService.Start()
	if RunService:IsStudio() and Config.Sandbox.On then
		FishService.keepNear((RideService.sandboxStart()))
	end
end

return SandboxService
