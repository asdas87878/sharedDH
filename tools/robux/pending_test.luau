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
	s.promptOnce(p)
	ok("the prompt waits for the profile write", #s.prompts == 0 and p:GetAttribute("PackPendingStarter"))
	roblox.pass(2)
	ok(
		"two asks open one prompt with the reservation already saved",
		#s.prompts == 1 and s.prompts[1][3].Packs.Pending.Starter ~= nil
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

done()
