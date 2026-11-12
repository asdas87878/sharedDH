--!strict
-- Taming, as this player's machine knows it: the server decides it (RideService), this only keeps what the HUD reads.
--   State.Tame      0 to 1, how far the fish under us is from being ours (the player's Tame attribute); nil off a fish
--   State.Caught    what we carry on this dive (Ride "Caught"): a new list each time it changes
--   State.Tamed     fired with the fish's id when the fish under us becomes ours (Ride "Tamed")
--   State.Strained  the fish under us is too strong for us (the Strained attribute): the meter is emptying at once
-- With Config.Tame.On at 0, Tame and Caught are nil and the HUD's tame ring and slots stay hidden.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.Lib.State)

local TameController = {}

local CHECK_EVERY = 0.5

local ids: { string } = {} -- what the server last said we carry
local shownOn = -1

local function publish()
	if Config.Tame.On == 0 then
		State.Caught = nil
		State.Tame = nil
		return
	end
	local list: { State.Caught } = {}
	for _, id in ids do
		local kind = Config.FishById[id]
		if kind then
			table.insert(list, { Id = id, Tier = kind.Tier })
		end
	end
	State.Caught = list
	local tame = State.Player:GetAttribute("Tame")
	State.Tame = if type(tame) == "number" then tame else nil
end

function TameController.Start()
	local player = State.Player
	Net.Ride.OnClientEvent:Connect(function(what: string, a: any, b: any)
		if what == "Caught" and type(a) == "table" then
			table.clear(ids)
			for _, id in a do
				if type(id) == "string" then
					table.insert(ids, id)
				end
			end
			publish()
		elseif what == "Tamed" and type(b) == "string" and Config.Tame.On ~= 0 then
			State.Tamed:Fire(b)
		end
	end)
	player:GetAttributeChangedSignal("Tame"):Connect(publish)
	player:GetAttributeChangedSignal("Strained"):Connect(function()
		State.Strained = player:GetAttribute("Strained") == true
	end)
	State.Strained = player:GetAttribute("Strained") == true
	publish()
	-- (Tame.On can be switched in the Studio sandbox's panel: looked at twice a second)
	while true do
		local on = Config.Tame.On
		if on ~= shownOn then
			shownOn = on
			publish()
		end
		task.wait(CHECK_EVERY)
	end
end

return TameController
