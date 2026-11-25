--!strict
-- What to aim for next, on the dock (the second hunt, 2026-11-24: once the lesson is over nothing says what the coins
-- are for). One small line under the caption's place (UI.DockNotes.goal): the cheapest thing to buy when the coins reach
-- it, else how far they are from it: the seahorse's next level, the tank's next stage, and the next submarine once the
-- fish of the land it goes to can be held. (Nothing of the Index's rewards: its button's red "!" is all, the user,
-- 2026-11-25.)
-- Not while the lesson runs, a catch is carried, a window is open, or the player rides something.
-- Also the word as the tank goes up a stage.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.Lib.State)
local CatchShow = require(script.Parent.Parent.UI.CatchShow)
local DockNotes = require(script.Parent.Parent.UI.DockNotes)
local Kit = require(script.Parent.Parent.UI.Kit)
local Shop = require(script.Parent.Parent.UI.Shop)
local TankPanel = require(script.Parent.Parent.UI.TankPanel)

local GoalController = {}

local EVERY = 0.25
local SETTLE = 1.5 -- on the dock this long, with nothing else up, before it shows, seconds

local clearSince = math.huge

local function number(name: string): number
	local value = State.Player:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

type Goal = { Price: number, Go: string, Next: string }

-- What there is to buy
local function goals(): { Goal }
	local list: { Goal } = {}
	local level = number("TrainerLevel")
	local train = Config.Train.Levels[level + 1]
	if train and level > 0 and Config.Train.Free ~= 1 then
		table.insert(list, { Price = train.Price, Go = "*UPGRADE* YOUR SEAHORSE", Next = "NEXT SEAHORSE" })
	end
	local plots = Config.PlotUpgrades
	local stage = plots.Stages[number("PlotStage") + 1]
	if stage and plots.On ~= 0 and plots.Free ~= 1 then
		table.insert(list, { Price = stage.Price, Go = "*UPGRADE* YOUR TANK", Next = "BIGGER TANK" })
	end
	local sub = number("SubTier") + 1
	local price = Config.Sub.Prices[sub]
	if price and Config.Sub.On ~= 0 and Config.Sub.Free ~= 1 and number("MaxOxygen") >= Config.indexGoal(sub + 1) then
		table.insert(
			list,
			{ Price = price, Go = `*BUY* THE SUB TO LAND {sub + 1}`, Next = `THE SUB TO LAND {sub + 1}` }
		)
	end
	return list
end

local function words(): string?
	local coins = number("Coins")
	local best: Goal? = nil
	for _, goal in goals() do
		if not best or goal.Price < best.Price then
			best = goal
		end
	end
	if not best then
		return nil
	elseif coins >= best.Price then
		return `{best.Go}  *{Shop.cash(best.Price)}*`
	end
	return `{best.Next}  *{Shop.cash(coins)} / {Shop.cash(best.Price)}*`
end

local function clear(): boolean
	local player = State.Player
	local caught = State.Caught
	return State.Mode == "Dock"
		and player:GetAttribute("Lesson") == nil
		and not (caught ~= nil and #caught > 0)
		and Shop.Page == nil
		and not TankPanel.isOpen()
		and State.FadeText == ""
		and State.Fade <= 0.02
		and not CatchShow.showing()
		and player:GetAttribute("TankRide") == nil
		and player:GetAttribute("TrainerRide") == nil
		and player:GetAttribute("Training") ~= true
end

function GoalController.Start()
	Net.Ride.OnClientEvent:Connect(function(what: string, stage: any, gain: any)
		if what == "PlotUp" and type(stage) == "number" then
			local line = `+{Config.PlotUpgrades.Slots} earning fish`
			if type(gain) == "number" and gain > 0 then
				line ..= `   +{Kit.rate(gain)}`
			end
			DockNotes.note(`TANK STAGE {stage}!`, line, true)
		elseif what == "NoPlot" then
			DockNotes.note("SERVER FULL!", "The next free tank is yours", false)
		end
	end)
	while true do
		local now = os.clock()
		if not clear() then
			clearSince = math.huge
			DockNotes.goal(nil)
		else
			clearSince = math.min(clearSince, now)
			DockNotes.goal(if now - clearSince >= SETTLE then words() else nil)
		end
		task.wait(EVERY)
	end
end

return GoalController
