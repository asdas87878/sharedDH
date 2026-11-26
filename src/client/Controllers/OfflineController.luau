--!strict
-- Offline rewards on the player's own machine (Hugo, 2026-11-25; NULLROOM task o1; Config.Offline): shows UI.OfflinePanel
-- by itself once a visit, when the player has spawned, stands on the dock and nothing else is on the screen; asks the
-- server for the claim and says what came back. Closed with the X (or by another window, or a dive), what is owed stays
-- as the small CLAIM by the dock's buttons, and on the next join it is there again: the server keeps it (OfflineService).
-- Nothing here decides an amount: it is the player's "OfflineOwed" attribute, the server's.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Net = require(game:GetService("ReplicatedStorage").Shared.Net)
local Products = require(game:GetService("ReplicatedStorage").Shared.Products)
local State = require(script.Parent.Parent.Lib.State)
local Anim = require(script.Parent.Parent.UI.Anim)
local CatchShow = require(script.Parent.Parent.UI.CatchShow)
local DockNotes = require(script.Parent.Parent.UI.DockNotes)
local OfflinePanel = require(script.Parent.Parent.UI.OfflinePanel)
local Shop = require(script.Parent.Parent.UI.Shop)
local TankPanel = require(script.Parent.Parent.UI.TankPanel)
local SoundController = require(script.Parent.SoundController)

local OfflineController = {}

local EVERY = 0.25 -- seconds between looks
local ANSWER = 4 -- seconds an ask waits for its answer before CLAIM can be pressed again
local WHY: { [string]: string } = {
	Save = "Your save is still loading, try again",
	Tank = "You need a tank first. It is kept for you",
	Buying = "Claim x3 is being bought, one moment",
	Sale = "Claim x3 is unavailable",
	Credit = "You already have a prepaid x3 claim",
}

local shown = false -- it has come up by itself this visit
local clearSince = math.huge
local askedAt = -math.huge

-- The player has spawned and stands on the dock with nothing else on the screen
local function clear(): boolean
	local player = State.Player
	local _, root, humanoid = State.character()
	return State.Mode == "Dock"
		and root ~= nil
		and humanoid ~= nil
		and humanoid.Health > 0
		and Shop.Page == nil
		and Anim.Windows == 0
		and not TankPanel.isOpen()
		and State.FadeText == ""
		and State.Fade <= 0.02
		and not CatchShow.showing()
		and player:GetAttribute("TankRide") == nil
		and player:GetAttribute("TrainerRide") == nil
end

-- One look (and what the offline check calls)
function OfflineController.look(now: number)
	local owed = OfflinePanel.owed()
	if Shop.Page == "Offline" and (owed < 1 or TankPanel.isOpen()) then
		Shop.go(nil)
	end
	if askedAt > -math.huge and now - askedAt >= ANSWER then
		-- (no answer: what is owed is as the server says, so it can simply be asked again)
		askedAt = -math.huge
		OfflinePanel.claiming(false)
	end
	if owed < 1 or not clear() then
		clearSince = math.huge
	else
		clearSince = math.min(clearSince, now)
		if not shown and now - clearSince >= Config.Offline.Settle then
			shown = true
			Shop.go("Offline")
		end
	end
	OfflinePanel.chip(owed >= 1 and State.Mode == "Dock" and shown and Shop.Page ~= "Offline")
end

function OfflineController.Start()
	local remote = Net.Folder:WaitForChild("Offline") :: RemoteEvent
	OfflinePanel.Pressed:Connect(function()
		askedAt = os.clock()
		OfflinePanel.claiming(true)
		local player = State.Player
		local credits = player:GetAttribute("OfflineTripleCredits")
		local useCredit = player:GetAttribute("OfflineBuying") ~= true and type(credits) == "number" and credits > 0
		remote:FireServer(if useCredit then "Redeem" else "Claim")
	end)
	if Products.onSale(Products.Triple) then
		OfflinePanel.Triple:Connect(function()
			askedAt = os.clock()
			OfflinePanel.claiming(true)
			remote:FireServer("Triple")
		end)
		task.spawn(function()
			local ok, info = pcall(function()
				return game:GetService("MarketplaceService"):GetProductInfo(Products.Triple.Id, Enum.InfoType.Product)
			end)
			local robux = if ok and info then info.PriceInRobux else nil
			if type(robux) == "number" then
				OfflinePanel.price(robux)
			end
		end)
	end
	remote.OnClientEvent:Connect(function(what: any, a: any)
		askedAt = -math.huge
		OfflinePanel.claiming(false)
		if what == "Paid" and type(a) == "number" then
			SoundController.play("Claim")
			DockNotes.note("+" .. Shop.cash(a), "From your tank, while you were away", true)
		elseif what == "Credit" then
			DockNotes.note("Claim x3 saved", "Use it on your next Welcome Back reward", true)
		elseif what == "Denied" and WHY[a] then
			OfflinePanel.say(WHY[a])
		end
	end)
	State.Player:GetAttributeChangedSignal("OfflineOwed"):Connect(function()
		OfflinePanel.paint()
		OfflineController.look(os.clock())
	end)
	State.Player:GetAttributeChangedSignal("OfflineBuying"):Connect(function()
		askedAt = -math.huge
		OfflinePanel.claiming(false)
	end)
	State.Player:GetAttributeChangedSignal("OfflineTripleCredits"):Connect(OfflinePanel.paint)
	while true do
		OfflineController.look(os.clock())
		task.wait(EVERY)
	end
end

return OfflineController
