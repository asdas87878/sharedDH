--!strict
-- What a Robux purchase gives (the user, 2026-11-23). Roblox calls the one ProcessReceipt here for each bought product;
-- what it gives is Shared/Products' own line for it (Gives, Amount): the client only ever asks Roblox for the prompt.
--   Each receipt is given once: its PurchaseId goes into the player's profile (SaveService) in the same snapshot as what
--   it gave, and Roblox is told "granted" only when that profile is seen saved. Every other ending (the player gone, no
--   profile, no wallet yet, the store down) is "not yet": Roblox asks again, here or when they next join.
--   A pack (Products' Pack) is given whole or not at all, when its three parts of the save are on: checked first, then
--   the coins and fish into the tank, the Oxygen, the once-only mark and the server's boost, with no yield between.
--   A pass is kept by Roblox: asked as the player joins (and again if Roblox doesn't answer), and at the purchase.
--   Claim x3 (Products.Triple, Gives "Offline") pays what the server itself has owed, times Amount, into the tank: both
--   parts of the save must be on. With nothing owed it is "not yet", never a purchase for nothing.
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
local OfflineService = require(script.Parent.OfflineService)
local PackService = require(script.Parent.PackService)
local RideService = require(script.Parent.RideService) :: any
local SaveService = require(script.Parent.SaveService)

local PurchaseService = {}

local WAIT_PROFILE = 20 -- seconds a receipt waits for the player's profile
local WAIT_SAVE = 40 -- and for the save after it

-- What an offer gives -> the giving of it (true when given; never yields). Where it is kept: Products.Part
local GIVES: { [string]: (player: Player, amount: number) -> boolean } = {
	Coins = function(player, amount)
		return AquariumService.give(player, amount) == true
	end,
	Oxygen = function(player, amount)
		return RideService.grantOxygen(player, amount) == true
	end,
	Offline = function(player, amount)
		return OfflineService.triple(player, amount) == true
	end,
}

-- A bundle: what it needs is looked at before any of it is given
local function givePack(player: Player, offer: Products.Offer): boolean
	local pack = offer.Pack :: Products.Pack
	if RideService.trainedOxygen(player) == nil or AquariumService.give(player, pack.Coins, pack.Fish) ~= true then
		return false
	end
	if RideService.grantOxygen(player, pack.Oxygen) ~= true then
		warn(`[PurchaseService] {offer.Key}: the Oxygen of {player.Name} was not given`)
	end
	if offer.Once then
		PackService.once(player, offer.Key)
	end
	PackService.boost(player, pack.Boost)
	return true
end

-- The parts of the save an offer is kept in: all must be on
local function partsOn(player: Player, offer: Products.Offer): boolean
	if offer.Pack then
		return SaveService.isOn(player, "Tank")
			and SaveService.isOn(player, "Oxygen")
			and SaveService.isOn(player, "Packs")
	end
	if offer.Gives == "Offline" and not SaveService.isOn(player, "Tank") then
		return false
	end
	local part = Products.Part[offer.Gives or ""]
	return part ~= nil and SaveService.isOn(player, part)
end

local remote: RemoteEvent
local busy: { [string]: boolean } = {} -- receipts being handled (Roblox can ask again before the answer)

local NOT_YET = Enum.ProductPurchaseDecision.NotProcessedYet
local GRANTED = Enum.ProductPurchaseDecision.PurchaseGranted

-- Whether Roblox's store is seen to have the receipt
local function saved(profile: any, id: string): boolean
	return table.find(profile.LastSavedData.Receipts or {}, id) ~= nil
end

local function handle(player: Player, offer: Products.Offer, id: string): Enum.ProductPurchaseDecision
	local give = GIVES[offer.Gives or ""]
	local amount = offer.Amount or 0
	if not offer.Pack and (not give or amount <= 0) then
		warn(`[PurchaseService] {offer.Key} was bought but says nothing to give`)
		return NOT_YET
	end
	local from = os.clock()
	local profile = SaveService.profileOf(player)
	while (not profile or not partsOn(player, offer)) and os.clock() - from < WAIT_PROFILE do
		task.wait(0.25)
		if player.Parent ~= Players then
			return NOT_YET
		end
		profile = SaveService.profileOf(player)
	end
	if not profile or not partsOn(player, offer) then
		return NOT_YET
	end
	if not SaveService.hasReceipt(player, id) then
		-- (no yield from here to the end of the block: the gift, its receipt and the snapshot are one moment)
		if not SaveService.take(player) then
			return NOT_YET
		end
		local given = if offer.Pack then givePack(player, offer) else (give :: any)(player, amount)
		if not given then
			return NOT_YET
		end
		SaveService.gave(player, id)
		remote:FireClient(player, "Got", offer.Key, amount)
	end
	local asked = false
	from = os.clock()
	while not saved(profile, id) and os.clock() - from < WAIT_SAVE do
		if not asked and profile:IsActive() and table.find(profile.Data.Receipts, id) then
			asked = true
			profile:Save()
		end
		if not profile:IsActive() and os.clock() - from > 10 then
			break
		end
		task.wait(0.2)
	end
	return if saved(profile, id) then GRANTED else NOT_YET
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

-- The passes a player owns, as they join; Roblox not answering is asked again a few times
local function passes(player: Player)
	for _, section in Products.Sections do
		for _, offer in section.Offers do
			if offer.Kind ~= "Pass" or not Products.onSale(offer) then
				continue
			end
			for try = 1, 4 do
				local ok, owns = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, offer.Id)
				end)
				if player.Parent ~= Players then
					return
				elseif ok then
					if owns and offer.Gives then
						PackService.pass(player, offer.Gives)
					end
					break
				end
				task.wait(3 * try)
			end
		end
	end
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
	Players.PlayerAdded:Connect(passes)
	for _, player in Players:GetPlayers() do
		task.spawn(passes, player)
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, id: number, bought: boolean)
		local offer = Products.byId(id, "Pass")
		if bought and offer and offer.Gives then
			PackService.pass(player, offer.Gives)
			remote:FireClient(player, "Got", offer.Key, 0)
		end
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, id: number, bought: boolean)
		local player = Players:GetPlayerByUserId(userId)
		if player and id > 0 and id == Products.Triple.Id then
			OfflineService.prompted(player, bought)
		end
	end)
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
