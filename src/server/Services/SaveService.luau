--!strict
-- Saving (the user, 2026-11-23: cash and Oxygen go on sale for Robux, so what is bought has to be kept). What a player
-- has is kept in a profile of ProfileStore's (Lib/ProfileStore, MadStudioRoblox, Apache-2.0: docs/licenses): one server
-- at a time holds it, saved every five minutes, as they leave and as the server closes.
--   Parts: what is kept, one for each service that has something to keep, given in Lib/SaveParts (which has the switch):
--     SaveService.part(name, dump, restore, ready?)
--       dump(player)            what to keep, a plain table nobody changes after, number or text; nil while the service doesn't have them
--                               (not joined yet, gone, or no plot): what was kept before is then left as it is
--       restore(player, kept)   called once, when the profile and the service are both ready, if anything was kept; it
--                               ADDS to what the player has made in the moments before; an error: it could not be
--       ready(player)           false: not now, look again (nothing is given back and nothing written meanwhile)
--     None may yield.
--   A snapshot takes every part that is on together, or none of them, so coins and what they bought can't part. One is
--   taken every half second, so a service that has let a leaving player go costs at most that.
--   With no parts given, nothing here does anything.
--   A profile that can't be had (another server has it, or Roblox's store is down) or can't be given back: the player is
--   sent off to join again, as ProfileStore's own guide has it, and what was kept stays as it was. They are never let
--   play on a save that would be lost or written over.
--   In Studio: ProfileStore's stand-in store, in memory, gone at Stop, unless the workspace's "SaveReal" attribute is
--   set before Play (then Roblox's own, if the game's settings let Studio reach it).
--   The player's attribute "Saved" .. name ("SavedTank") is true while that part is on: what is bought into it is kept.
-- Studio's checks (tools/studio/save_check.py): ServerStorage.TestSave (a BindableFunction), Invoke(player, "look") answers
-- with the profile's data and what of it was last saved, "reopen" with whether it was. It is not there in a live game.
-- Receipts (PurchaseService) are kept in the profile's Receipts, oldest first. One goes in with the first snapshot after
-- what it gave, never without it.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local ProfileStore = require(script.Parent.Parent.Lib.ProfileStore) :: any
local SaveParts = require(script.Parent.Parent.Lib.SaveParts)

local SaveService = {}

local STORE = "Players1"
local EVERY = 0.5 -- seconds between snapshots
local VERSION = 1
local KEEP = 200 -- receipts remembered in a profile
local WAIT = 120 -- seconds a profile is waited for (a store that is down; ProfileStore has no limit of its own with a Cancel)

type Part = {
	Dump: (player: Player) -> any?,
	Restore: (player: Player, kept: any) -> (),
	Ready: ((player: Player) -> boolean)?,
}
type Save = {
	Player: Player,
	Profile: any,
	On: { [string]: boolean }, -- the parts that are given back, and so may be written
	Pending: { string }, -- receipts given but in no snapshot yet
}

local parts: { [string]: Part } = {}
local order: { string } = {}
local saves: { [Player]: Save } = {}
local store: any = nil
local reopened: { [Player]: boolean } = {}

function SaveService.part(
	name: string,
	dump: (player: Player) -> any?,
	restore: (player: Player, kept: any) -> (),
	ready: ((player: Player) -> boolean)?
)
	assert(not parts[name], "two parts called " .. name)
	parts[name] = { Dump = dump, Restore = restore, Ready = ready }
	table.insert(order, name)
end

-- Whether a value can be stored: no number that is not one, or endless (Roblox's store refuses the whole save). A
-- table found sound is not looked through again (nobody changes one after giving it).
local checked: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local function sound(value: any): boolean
	local kind = type(value)
	if kind == "number" then
		return value == value and math.abs(value) < math.huge
	elseif kind == "table" then
		if checked[value] then
			return true
		end
		for _, v in value do
			if not sound(v) then
				return false
			end
		end
		checked[value] = true
		return true
	end
	return kind == "string" or kind == "boolean"
end

-- What the player has now, into their profile: every part that is on, or nothing at all (a service has already let
-- them go). Returns whether it was taken. Doesn't yield.
local function take(save: Save): boolean
	if not save.Profile:IsActive() then
		return false
	end
	local now: { [string]: any } = {}
	for name in save.On do
		local ok, dump = pcall(parts[name].Dump, save.Player)
		if not ok then
			warn(`[SaveService] {name} could not be read: {dump}`)
			return false
		elseif dump == nil then
			return false
		elseif not sound(dump) then
			warn(`[SaveService] {name} of {save.Player.Name} holds what can't be stored: not taken`)
			return false
		end
		now[name] = dump
	end
	local data = save.Profile.Data
	for name, dump in now do
		data.Parts[name] = dump
	end
	for _, id in save.Pending do
		table.insert(data.Receipts, id)
	end
	table.clear(save.Pending)
	while #data.Receipts > KEEP do
		table.remove(data.Receipts, 1)
	end
	return true
end

local function unmark(player: Player)
	for _, name in order do
		player:SetAttribute("Saved" .. name, nil)
	end
end

-- The profile let go as it was kept, and the player sent off
local function refuse(save: Save, why: string)
	if saves[save.Player] == save then
		saves[save.Player] = nil
	end
	unmark(save.Player)
	save.Profile:EndSession()
	save.Player:Kick(why)
end

-- Each part that is not on yet goes on as its service has the player, what was kept given back to it first. False: it
-- could not be, and the player is off.
local function settle(save: Save): boolean
	for _, name in order do
		local part = parts[name]
		if save.On[name] or (part.Ready and not part.Ready(save.Player)) then
			continue
		end
		local ok, has = pcall(part.Dump, save.Player)
		if not ok or has == nil then
			continue
		end
		local kept = save.Profile.Data.Parts[name]
		if kept ~= nil then
			local done, problem = pcall(part.Restore, save.Player, kept)
			if not done then
				warn(`[SaveService] {name} of {save.Player.Name} could not be given back, left as kept: {problem}`)
				refuse(save, "Your save could not be given back. It is kept as it was: please join again.")
				return false
			end
		end
		save.On[name] = true
		save.Player:SetAttribute("Saved" .. name, true)
	end
	return true
end

local function join(player: Player)
	if saves[player] then
		return
	end
	local from = os.clock()
	local profile = store:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player.Parent ~= Players or os.clock() - from > WAIT
		end,
	})
	if not profile then
		if player.Parent == Players then
			player:Kick("Your save could not be loaded. Please join again.")
		end
		return
	end
	if player.Parent ~= Players then
		profile:EndSession()
		return
	end
	profile:Reconcile()
	local data = profile.Data
	if type(data.Version) ~= "number" or type(data.Parts) ~= "table" or type(data.Receipts) ~= "table" then
		warn(`[SaveService] the save of {player.Name} is not in a shape the game knows: left as it is`)
		profile:EndSession()
		player:Kick("Your save could not be read. It is kept as it was: please join again.")
		return
	end
	if data.Version > VERSION then
		-- (kept by a newer game than this server's: an older one never writes it)
		profile:EndSession()
		player:Kick("The game was just updated. Please join again.")
		return
	end
	profile:AddUserId(player.UserId)
	local save: Save = { Player = player, Profile = profile, On = {}, Pending = {} }
	saves[player] = save
	profile.OnSave:Connect(function()
		if saves[player] == save then
			take(save)
		end
	end)
	profile.OnSessionEnd:Connect(function()
		if saves[player] == save then
			saves[player] = nil
			unmark(player)
			player:Kick("Your save was opened somewhere else. Please join again.")
		end
	end)
	settle(save)
end

local function leave(player: Player)
	local save = saves[player]
	if not save then
		return
	end
	take(save) -- (or, when a service has let them go already, as at the last look)
	saves[player] = nil
	save.Profile:EndSession()
end

-- For PurchaseService: the player's profile (nil: none, or not this server's any more), whether a part of it is on, and
-- a snapshot now
function SaveService.profileOf(player: Player): any?
	local save = saves[player]
	return if save and save.Profile:IsActive() then save.Profile else nil
end

function SaveService.isOn(player: Player, name: string): boolean
	local save = saves[player]
	return save ~= nil and save.On[name] == true
end

function SaveService.take(player: Player): boolean
	local save = saves[player]
	return save ~= nil and take(save)
end

-- For PurchaseService: whether a receipt has been given (in the profile, or about to be), and one just given, to go
-- into the profile with the snapshot that has the gift (now, unless a service can't be read: then with the next)
function SaveService.hasReceipt(player: Player, id: string): boolean
	local save = saves[player]
	return save ~= nil and (table.find(save.Profile.Data.Receipts, id) ~= nil or table.find(save.Pending, id) ~= nil)
end

function SaveService.gave(player: Player, id: string)
	local save = saves[player]
	if save then
		table.insert(save.Pending, id)
		take(save)
	end
end

-- Studio's checks: the profile closed and opened again, as by leaving and coming back. The services still have the
-- player, so what is given back adds to what they hold (twice what they had: it was kept). Once a Play, for that.
function SaveService.reopen(player: Player): boolean
	local save = saves[player]
	if not RunService:IsStudio() or not save or reopened[player] then
		return false
	end
	reopened[player] = true
	leave(player)
	local from = os.clock()
	while save.Profile:IsActive() and os.clock() - from < 10 do
		task.wait(0.1)
	end
	unmark(player)
	join(player)
	return saves[player] ~= nil
end

function SaveService.Init()
	SaveParts.join(SaveService.part)
end

function SaveService.Start()
	if #order == 0 then
		return
	end
	store = ProfileStore.New(STORE, { Version = VERSION, Parts = {}, Receipts = {} })
	if RunService:IsStudio() and workspace:GetAttribute("SaveReal") ~= true then
		store = store.Mock
	end
	if RunService:IsStudio() then
		local test = Instance.new("BindableFunction")
		test.Name = "TestSave"
		test.OnInvoke = function(player: Player, what: string)
			if what == "reopen" then
				return SaveService.reopen(player)
			end
			local save = saves[player]
			return if save then { Data = save.Profile.Data, Saved = save.Profile.LastSavedData } else nil
		end
		test.Parent = ServerStorage
	end
	ProfileStore.OnError:Connect(function(message: string, _: string, key: string)
		warn(`[SaveService] {key}: {message}`)
	end)
	Players.PlayerAdded:Connect(join)
	Players.PlayerRemoving:Connect(leave)
	for _, player in Players:GetPlayers() do
		task.spawn(join, player)
	end
	while true do
		task.wait(EVERY)
		for _, save in table.clone(saves) do
			-- (one player's fault is not the others')
			local ok, problem = pcall(function()
				if settle(save) then
					take(save)
				end
			end)
			if not ok then
				warn(`[SaveService] {save.Player.Name} was passed over: {problem}`)
			end
		end
	end
end

return SaveService
