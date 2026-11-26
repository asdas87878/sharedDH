-- Run against a Rojo-built place with Lune. Roblox purchases and time are simulated by the offline server harness.
local Servers = require("../offline/servers")
local Harness = require("../index/harness")
local place = assert(require("@lune/process").args[1], "Pass the path to a Rojo-built place")
local ok, done = Harness.tally()

local function join(roblox: any, name: string): (any, any)
	local server = roblox.server({ NoStudio = true, Purchases = true })
	local player = server.join(name)
	roblox.pass(3)
	return server, player
end

do
	local roblox = Servers.new(place)
	local s, p = join(roblox, "starter")
	local pack = s.Products.Sections[1].Offers[1]
	s.onSale = false
	s.promptOnce(p)
	roblox.pass(1)
	ok("an off-sale offer leaves no pending prompt", #s.prompts == 0 and not p:GetAttribute("PackPendingStarter"))
	s.onSale = true
	s.promptOnce(p)
	roblox.pass(0.15)
	local prepared = roblox.kept("starter").Packs.Pending.Starter
	ok("Starter preparation is saved before Roblox is called", prepared and not prepared.Opened and #s.prompts == 0)
	s.stop()
	s, p = join(roblox, "starter")
	ok("a disconnect before the Starter prompt allows a retry after rejoin", not p:GetAttribute("PackPendingStarter"))
	s.promptOnce(p)
	s.promptOnce(p)
	ok("the prompt waits for the profile write", #s.prompts == 0 and p:GetAttribute("PackPendingStarter"))
	roblox.pass(2)
	ok(
		"two asks open one prompt with the reservation already saved",
		#s.prompts == 1
			and s.prompts[1][3].Packs.Pending.Starter.Opened == false
			and roblox.kept("starter").Packs.Pending.Starter.Opened == true
	)
	s.finishPrompt(p, 101, false)
	ok("cancellation re-enables the offer", not p:GetAttribute("PackPendingStarter"))
	s.promptOnce(p)
	roblox.pass(2)
	ok("the canceled prompt can be retried", #s.prompts == 2)
	s.finishPrompt(p, 101, true)
	s.promptOnce(p)
	roblox.pass(1)
	ok(
		"closing with OK waits for the receipt",
		#s.prompts == 2 and p:GetAttribute("PackPendingStarter") and s.coins(p) == 0
	)
	s.stop()

	s, p = join(roblox, "starter")
	s.promptOnce(p)
	roblox.pass(1)
	ok(
		"joining another server keeps the once-only offer reserved",
		#s.prompts == 0 and p:GetAttribute("PackPendingStarter")
	)
	local receipt = s.receipt(p, 101, "starter-1")
	roblox.pass(2)
	ok(
		"a saved receipt owns the pack and clears the hold",
		receipt.Decision == "Granted"
			and p:GetAttribute("PackStarter")
			and not p:GetAttribute("PackPendingStarter")
			and s.coins(p) == pack.Pack.Coins
			and roblox.kept("starter").Packs.Once.Starter
			and roblox.kept("starter").Packs.Pending.Starter == nil
	)
	s.promptOnce(p)
	local repeated = s.receipt(p, 101, "starter-1")
	roblox.pass(2)
	ok(
		"owned pack cannot prompt and replaying the receipt never grants twice",
		#s.prompts == 0 and repeated.Decision == "Granted" and s.coins(p) == pack.Pack.Coins
	)
	ok("starter had no server faults", #roblox.faults == 0, roblox.faults[1])
end

do
	local roblox = Servers.new(place)
	local s, p = join(roblox, "triple")
	s.putIn(p, "Clownfish", true)
	roblox.pass(2)
	s.stop()
	roblox.skip(3600)
	s, p = join(roblox, "triple")
	local firstDue = p:GetAttribute("OfflineOwed")
	s.ask(p, "Triple")
	roblox.pass(0.15)
	local prepared = roblox.kept("triple").Offline
	ok(
		"Claim x3 preparation is saved before Roblox is called",
		prepared.HeldOwed == firstDue and not prepared.HoldOpened and #s.prompts == 0
	)
	s.stop()
	s, p = join(roblox, "triple")
	ok(
		"a disconnect before the Claim x3 prompt keeps the reward and allows a retry",
		not p:GetAttribute("OfflineBuying") and p:GetAttribute("OfflineOwed") == firstDue
	)
	s.ask(p, "Triple")
	roblox.pass(2)
	ok(
		"Claim x3 records the reward before prompting",
		firstDue > 0 and #s.prompts == 1 and s.prompts[1][3].Offline.HeldOwed == firstDue
	)
	roblox.pass(s.Config.Offline.Hold + 1)
	s.ask(p, "Triple")
	ok(
		"an unanswered prompt stays locked after the free-claim timer",
		#s.prompts == 1 and select(2, s.answer(p)) == "Buying"
	)
	s.finishPrompt(p, 102, false)
	ok(
		"cancellation leaves the full base reward",
		not p:GetAttribute("OfflineBuying") and p:GetAttribute("OfflineOwed") == firstDue
	)
	roblox.pass(1)
	s.ask(p, "Triple")
	roblox.pass(2)
	s.finishPrompt(p, 102, true)
	s.stop()

	roblox.skip(3600)
	s, p = join(roblox, "triple")
	local nextDue = p:GetAttribute("OfflineOwed") - firstDue
	roblox.pass(s.Config.Offline.HoldJoin + 1)
	s.ask(p, "Triple")
	ok(
		"the paid lock survives a rejoin and the join timer",
		nextDue > 0 and #s.prompts == 0 and select(2, s.answer(p)) == "Buying"
	)
	local receipt = s.receipt(p, 102, "triple-1")
	roblox.pass(2)
	ok(
		"receipt triples only the reserved balance and keeps the later reward",
		receipt.Decision == "Granted"
			and s.coins(p) == firstDue * 3
			and p:GetAttribute("OfflineOwed") == nextDue
			and not p:GetAttribute("OfflineBuying")
	)
	local repeated = s.receipt(p, 102, "triple-1")
	roblox.pass(2)
	ok(
		"a receipt retry does not take the later reward",
		repeated.Decision == "Granted" and p:GetAttribute("OfflineOwed") == nextDue and s.coins(p) == firstDue * 3
	)

	s.ask(p, "Triple")
	roblox.pass(2)
	s.finishPrompt(p, 102, true)
	roblox.pass(s.Config.Offline.Hold + 1)
	s.ask(p, "Claim")
	ok(
		"the free claim remains available after its hold",
		p:GetAttribute("OfflineOwed") == nil
			and s.coins(p) == firstDue * 3 + nextDue
			and p:GetAttribute("OfflineBuying")
	)
	local late = s.receipt(p, 102, "triple-2")
	roblox.pass(2)
	ok(
		"after the free claim the late receipt pays only the remaining bonus",
		late.Decision == "Granted" and s.coins(p) == (firstDue + nextDue) * 3 and not p:GetAttribute("OfflineBuying")
	)
	ok("Claim x3 had no server faults", #roblox.faults == 0, roblox.faults[1])
end

do
	local roblox = Servers.new(place)
	local s, p = join(roblox, "credits")
	local unreserved = s.receipt(p, 102, "unreserved-x3")
	roblox.pass(2)
	ok(
		"a receipt without a reservation grants a durable prepaid claim even with no reward",
		unreserved.Decision == "Granted"
			and p:GetAttribute("OfflineOwed") == nil
			and roblox.kept("credits").Offline.Credits == 1
	)
	s.putIn(p, "Clownfish", true)
	roblox.pass(2)
	s.stop()
	roblox.skip(3600)

	s, p = join(roblox, "credits")
	local due = p:GetAttribute("OfflineOwed")
	local retry = s.receipt(p, 102, "unreserved-x3")
	roblox.pass(2)
	ok(
		"a saved receipt retry does not duplicate the credit or take the new reward",
		retry.Decision == "Granted"
			and p:GetAttribute("OfflineTripleCredits") == 1
			and p:GetAttribute("OfflineOwed") == due
	)
	s.ask(p, "Redeem")
	ok(
		"the player can redeem a prepaid x3 exactly once",
		s.coins(p) == due * 3 and p:GetAttribute("OfflineOwed") == nil and p:GetAttribute("OfflineTripleCredits") == nil
	)
	roblox.pass(2)
	s.stop()
	roblox.skip(3600)

	s, p = join(roblox, "credits")
	local later = p:GetAttribute("OfflineOwed")
	s.ask(p, "Triple")
	roblox.pass(2)
	local retired = s.receipt(p, 103, "older-x3")
	roblox.pass(2)
	ok(
		"a retired product receipt cannot take an opened reservation for the replacement product",
		retired.Decision == "Granted"
			and p:GetAttribute("OfflineBuying")
			and p:GetAttribute("OfflineOwed") == later
			and p:GetAttribute("OfflineTripleCredits") == 1
			and s.coins(p) == due * 3
	)
	local matching = s.receipt(p, 102, "replacement-x3")
	roblox.pass(2)
	ok(
		"the replacement receipt pays its reservation and leaves the retired receipt's credit intact",
		matching.Decision == "Granted"
			and not p:GetAttribute("OfflineBuying")
			and p:GetAttribute("OfflineOwed") == nil
			and p:GetAttribute("OfflineTripleCredits") == 1
			and s.coins(p) == (due + later) * 3
	)
	ok("receipt recovery had no server faults", #roblox.faults == 0, roblox.faults[1])
end

done()
