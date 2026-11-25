--!strict
-- The endless Underworld in a place that streams (Workspace.StreamingEnabled; Config.Endless, docs/design/endless.md). A
-- player's machine shows the parts of the last stretch at later laps (client/Controllers/EndlessController), far from
-- where the server has them, so streaming would never send them there, or take them away. So the stretch's parts are held
-- for each player who has come near it, and only for them: whoever stays higher up streams the map as before.
--   Holding is a thing of Models: each prop is one already, the parts of every other folder go into one Model there
--   (Endless.Stretch). A model held whole says how many parts it has (Endless.Held), so a machine can tell when it has
--   all of them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Endless = require(ReplicatedStorage.Shared.Endless)

local Stretch = {}

local models: { Model } = {}
local held: { [Player]: boolean } = {}

-- The stretch's things made ready to be held; how many things and parts there are
function Stretch.make(laneFolder: Instance): (number, number)
	local units, parts = 0, 0
	for _, group in laneFolder:GetChildren() do
		local rest: { Instance } = {}
		for _, child in group:GetChildren() do
			local unit = Endless.unit(child)
			if unit and Endless.belongs(group.Name, child.Name, unit.Z) then
				units += 1
				parts += #unit.Parts
				if child:IsA("Model") then
					child:SetAttribute(Endless.Held, #unit.Parts)
				end
				if group.Name == "Props" and child:IsA("Model") then
					-- (the props stay where they are: everything looks for them in that folder)
					child.ModelStreamingMode = Enum.ModelStreamingMode.PersistentPerPlayer
					table.insert(models, child)
				else
					table.insert(rest, child)
				end
			end
		end
		if #rest > 0 then
			local model = Instance.new("Model")
			model.Name = Endless.Stretch
			model.ModelStreamingMode = Enum.ModelStreamingMode.PersistentPerPlayer
			for _, child in rest do
				child.Parent = model
			end
			model.Parent = group
			table.insert(models, 1, model)
		end
	end
	return units, parts
end

local function hold(player: Player)
	for i, model in models do
		if not player.Parent then
			return
		end
		model:AddPersistentPlayer(player)
		if i % 40 == 0 then
			task.wait()
		end
	end
end

-- Whoever comes near it has it from then on, until they leave the game
function Stretch.start()
	Players.PlayerRemoving:Connect(function(player)
		held[player] = nil
	end)
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if
					not held[player]
					and root
					and root:IsA("BasePart")
					and root.Position.Z > Config.Endless.From - Config.Endless.Hold
				then
					held[player] = true
					task.spawn(hold, player)
				end
			end
			task.wait(0.5)
		end
	end)
end

return Stretch
