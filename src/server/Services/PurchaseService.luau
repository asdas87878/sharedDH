--!strict
-- What a Robux purchase gives (the user, 2026-11-23). Roblox calls the one ProcessReceipt here for each bought product;
-- what it gives is Shared/Products' own line for it (Gives, Amount): the client only ever asks Roblox for the prompt.
--   Each receipt is given once: its PurchaseId goes into the player's profile (SaveService) in the same moment as what
--   it gave, and Roblox is told "granted" only when that profile is seen saved. Every other ending (the player gone, no
--   profile, no wallet yet, the store down) is "not yet": Roblox asks again, here or when they next join.
--   Coins need a tank of their own (the wallet): without one nothing is given until they have one.
-- The remote "Purchase" tells the buyer's machine ("Got", the offer's key, the amount).
-- Studio's checks: ServerStorage.TestReceipt (a BindableFunction), Invoke(player, offer, purchase id) runs a made-up
-- receipt for an offer (a table as in Products) and answers with the decision's name. It is not there in a live game.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Products = require(ReplicatedStorage.Shared.Products)
local AquariumService = require(script.Parent.AquariumService) :: any
local RideService = require(script.Parent.RideService) :: any
local SaveService = require(script.Parent.SaveService)

local PurchaseService = {}

local KEEP = 200 -- receipts remembered in a profile
local WAIT_PROFILE = 20 -- seconds a receipt waits for the player's profile
local WAIT_SAVE = 40 -- and for the save after it

-- What an offer gives -> the save's part it lives in, and the giving of it (true when given; never yields)
local GIVES: { [string]: { Part: string, Give: (player: Player, amount: number) -> boolean } } = {
	Coins = {
		Part = "Tank",
		Give = function(player, amount)
			return AquariumService.give(player, amount) == true
		end,
	},
	Oxygen = {
		Part = "Oxygen",
		Give = function(player, amount)
			return RideService.grantOxygen(player, amount) == true
		end,
	},
}

local remote: RemoteEvent
local busy: { [string]: boolean } = {} -- receipts being handled (Roblox can ask again before the answer)

local NOT_YET = Enum.ProductPurchaseDecision.NotProcessedYet
local GRANTED = Enum.ProductPurchaseDecision.PurchaseGranted

local function handle(player: Player, offer: Products.Offer, id: string): Enum.ProductPurchaseDecision
	local gives = if offer.Gives then GIVES[offer.Gives] else nil
	local amount = offer.Amount
	if not gives or not amount or amount <= 0 then
		warn(`[PurchaseService] {offer.Key} was bought but says nothing to give`)
		return NOT_YET
	end
	local from = os.clock()
	local profile = SaveService.profileOf(player)
	while (not profile or not SaveService.isOn(player, gives.Part)) and os.clock() - from < WAIT_PROFILE do
		task.wait(0.25)
		if player.Parent ~= Players then
			return NOT_YET
		end
		profile = SaveService.profileOf(player)
	end
	if not profile or not SaveService.isOn(player, gives.Part) then
		return NOT_YET
	end
	local receipts = profile.Data.Receipts
	if not table.find(receipts, id) then
		-- (no yield from here to the end of the block: the gift, its receipt and the snapshot are one moment)
		if not SaveService.take(player) or not gives.Give(player, amount) then
			return NOT_YET
		end
		table.insert(receipts, id)
		while #receipts > KEEP do
			table.remove(receipts, 1)
		end
		SaveService.take(player)
		remote:FireClient(player, "Got", offer.Key, amount)
	end
	if not table.find(profile.LastSavedData.Receipts, id) and profile:IsActive() then
		profile:Save()
	end
	from = os.clock()
	while not table.find(profile.LastSavedData.Receipts, id) and os.clock() - from < WAIT_SAVE do
		if not profile:IsActive() and os.clock() - from > 10 then
			break
		end
		task.wait(0.2)
	end
	return if table.find(profile.LastSavedData.Receipts, id) then GRANTED else NOT_YET
end

local function receipt(player: Player?, offer: Products.Offer?, id: string): Enum.ProductPurchaseDecision
	if not player or not offer or busy[id] then
		return NOT_YET
	end
	busy[id] = true
	local ok, decision = pcall(handle, player, offer, id)
	busy[id] = nil
	if not ok then
		warn(`[PurchaseService] a receipt of {player.Name} failed: {decision}`)
		return NOT_YET
	end
	return decision
end

function PurchaseService.Init()
	local existing = Net.Folder:FindFirstChild("Purchase")
	if existing and existing:IsA("RemoteEvent") then
		remote = existing
	else
		remote = Instance.new("RemoteEvent")
		remote.Name = "Purchase"
		remote.Parent = Net.Folder
	end
end

function PurchaseService.Start()
	MarketplaceService.ProcessReceipt = function(info): Enum.ProductPurchaseDecision
		local offer = Products.byId(info.ProductId)
		if not offer then
			warn(`[PurchaseService] a product that is not in Products was bought: {info.ProductId}`)
		end
		return receipt(Players:GetPlayerByUserId(info.PlayerId), offer, info.PurchaseId)
	end
	if RunService:IsStudio() then
		local test = Instance.new("BindableFunction")
		test.Name = "TestReceipt"
		test.OnInvoke = function(player: Player, offer: Products.Offer, id: string)
			return receipt(player, offer, id).Name
		end
		test.Parent = ServerStorage
	end
end

return PurchaseService
