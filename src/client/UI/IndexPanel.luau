--!strict
-- The Index (Hugo, 2026-11-23: "Import index system with the same ui consistent with the one my partner made"; NULLROOM
-- task h2): every kind of fish, land by land, the ones you have caught in their rarity's colour and the rest as dark
-- shapes, with a reward to claim for each new kind and for each land's whole set. The hub's Index button opens and
-- closes it (UI.HubButtons, through Shop.go("Index"): one dock window at a time; leaving the dock closes it), and so
-- does standing on the Index stall's ring and walking off it, where the map has one (Controllers/StallController;
-- Hugo, 2026-11-24).
-- This file is its door: it hears the server (the Index remote), opens the window and answers the hub and the checks.
--   UI.IndexBook     the player's Index and every sum drawn from it
--   UI.IndexWindow   the window (Hugo, 2026-11-25: "Make index ui feel more like ride a dino"; NULLROOM task i1)
--   UI.SaddlePage    the saddles: a land's reward on its banner, and the page to put one on (NULLROOM s2)
--   UI.IndexOld      the window before that, behind Config.Index.Look 0 (read as the window opens); no saddles in it
-- Nothing here decides anything: what is found and what is claimed is the server's (IndexService); a press only asks.
-- The rewards shown are Config.indexFirst and Config.indexLand, the same sums the server pays by (Config.Index: every
-- number a DRAFT). For the session only: the game has no saves yet.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Saddles = require(ReplicatedStorage.Shared.Saddles)
local State = require(script.Parent.Parent.Lib.State)
local IndexBook = require(script.Parent.IndexBook)
local IndexOld = require(script.Parent.IndexOld)
local IndexWindow = require(script.Parent.IndexWindow)
local Shop = require(script.Parent.Shop)

local IndexPanel = {}

-- The window last opened: the old one or today's
local old = false

local function isOpen(): boolean
	return if old then IndexOld.isOpen() else IndexWindow.isOpen()
end

local changed = Instance.new("BindableEvent")
-- Fired when the server has sent the Index again (something found or claimed)
IndexPanel.Changed = changed.Event

-- How many rewards wait to be claimed, as this client counts them (the server's own count is the player's
-- "IndexClaims" attribute)
function IndexPanel.waiting(): number
	if #IndexBook.Lands == 0 then
		IndexBook.roster()
	end
	return IndexBook.owedAll()
end

-- Has this kind been caught, as the server last said
function IndexPanel.found(id: string): boolean
	return IndexBook.has(id)
end

function IndexPanel.isOpen(): boolean
	return isOpen()
end

-- Test hook: only the Studio checks and the offline check (tools/index/panel_test.luau) call this. A press, as the
-- player's: "Land", n | "Kind", fish id | "Claim" | "ClaimLand" | "ClaimAll" |
-- "Saddles", true or false (the saddles' page) | "Saddle", land (its card's button there).
function IndexPanel.press(what: string, arg: any?)
	if old then
		IndexOld.press(what, arg)
	else
		IndexWindow.press(what, arg)
	end
end

-- Open or close the window. (Through Shop.go("Index"), so another dock window closes.)
function IndexPanel.open(on: boolean)
	local want = Config.Index.Look == 0
	if on and want ~= old and not isOpen() then
		-- the look was switched: the other window goes, so there is only ever one
		if old then
			IndexOld.drop()
		else
			IndexWindow.drop()
		end
		old = want
	end
	if old then
		IndexOld.open(on)
	else
		IndexWindow.open(on)
	end
end

Shop.page("Index", IndexPanel.open)

local function say(text: string, good: boolean)
	if old then
		IndexOld.say(text, good)
	else
		IndexWindow.say(text, good)
	end
end

-- (the saddle put on or taken off: the player's own attribute)
State.Player:GetAttributeChangedSignal("Saddle"):Connect(function()
	if not old and isOpen() then
		IndexWindow.paint()
	end
end)

-- The server's word: the whole Index after every change, and what a claim paid or why it was refused
Net.Index.OnClientEvent:Connect(function(what: any, a: any, b: any, c: any, d: any)
	if what == "State" and type(a) == "table" and type(b) == "table" and type(c) == "table" then
		IndexBook.read(a, b, c)
		-- (only while it is open: a catch out on a dive must not build a land's pictures behind a closed window;
		-- opening paints it, IndexPanel.open)
		if isOpen() then
			if old then
				IndexOld.paint()
			else
				IndexWindow.paint()
			end
		end
		changed:Fire()
	elseif what == "Paid" and type(a) == "number" and type(b) == "number" then
		local words = { IndexBook.oxygenText(a) .. " Oxygen" }
		if b > 0 then
			table.insert(words, "+" .. Shop.cash(b))
		end
		-- (a claimed land's saddle, by name; more than one, by how many)
		if type(d) == "table" and #d > 0 then
			table.insert(words, if #d == 1 then Saddles.nameOf(d[1]) .. "!" else `{#d} Saddles!`)
		end
		say(table.concat(words, "   "), true)
	elseif what == "Denied" and a == "Dock" then
		say("Stand on the dock to claim", false)
	elseif what == "Denied" and a == "Saddle" then
		say("Claim that land's set first", false)
	end
end)
-- (in case the server's first word went out before this was listening)
Net.Index:FireServer("Sync")

return IndexPanel
