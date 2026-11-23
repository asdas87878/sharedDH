--!strict
-- Saving (the user, 2026-11-23: cash and Oxygen go on sale for Robux, so what is bought has to be kept). What a player
-- has is kept in a profile of ProfileStore's (Lib/ProfileStore, MadStudioRoblox, Apache-2.0: docs/licenses): one server
-- at a time holds it, saved every five minutes, as they leave and as the server closes.
--   Parts: each service that has something to keep gives it here in its Init:
--     SaveService.part(name, dump, restore)
--       dump(player)            what to keep, plain tables, numbers and text; nil while the service doesn't have them
--                               (not joined yet, gone, or no plot): what was kept before is then left as it is
--       restore(player, kept)   called once, when the profile and the service are both ready, if anything was kept; it
--                               ADDS to what the player has made in the moments before
--     Neither may yield. A restore that fails is not tried again, and that part is not written over this session.
--   A snapshot takes every part that is on together, or none of them, so coins and what they bought can't part.
--   With no parts given, nothing here does anything.
--   A profile that can't be had (another server has it, or Roblox's store is down): the player is sent off to join
--   again, as ProfileStore's own guide has it. They are never let play on a save that would be lost or written over.
--   In Studio: ProfileStore's stand-in store, in memory, gone at Stop, unless the workspace's "SaveReal" attribute is
--   set before Play (then Roblox's own, if the game's settings let Studio reach it).
--   The player's attribute "Saved" is true once their profile is in.
-- Receipts (PurchaseService) are kept in the profile's Receipts, oldest first.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ProfileStore = require(script.Parent.Parent.Lib.ProfileStore) :: any

local SaveService = {}

local STORE = "Players1"
local EVERY = 0.5 -- seconds between snapshots
local VERSION = 1

type Part = { Dump: (player: Player) -> any?, Restore: (player: Player, kept: any) -> () }
type Save = {
	Player: Player,
	Profile: any,
	On: { [string]: boolean }, -- the parts that are given back, and so may be written
	Failed: { [string]: boolean }, -- and the ones that could not be: left as they were kept
}

local parts: { [string]: Part } = {}
local order: { string } = {}
local saves: { [Player]: Save } = {}
local store: any = nil

function SaveService.part(name: string, dump: (player: Player) -> any?, restore: (player: Player, kept: any) -> ())
	assert(not parts[name], "two parts called " .. name)
	parts[name] = { Dump = dump, Restore = restore }
	table.insert(order, name)
end

-- Whether a value can be stored: no number that is not one, or endless (Roblox's store refuses the whole save)
local function sound(value: any): boolean
	local kind = type(value)
	if kind == "number" then
		return value == value and math.abs(value) < math.huge
	elseif kind == "table" then
		for _, v in value do
			if not sound(v) then
				return false
			end
		end
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
	for name, dump in now do
		save.Profile.Data.Parts[name] = dump
	end
	return true
end

-- Each part that is not on yet goes on as its service has the player, what was kept given back to it first
local function settle(save: Save)
	for _, name in order do
		if save.On[name] or save.Failed[name] then
			continue
		end
		local part = parts[name]
		local ok, has = pcall(part.Dump, save.Player)
		if not ok or has == nil then
			continue
		end
		local kept = save.Profile.Data.Parts[name]
		if kept ~= nil then
			local done, problem = pcall(part.Restore, save.Player, kept)
			if not done then
				save.Failed[name] = true
				warn(`[SaveService] {name} of {save.Player.Name} could not be given back, left as kept: {problem}`)
				continue
			end
		end
		save.On[name] = true
	end
end

local function join(player: Player)
	if saves[player] then
		return
	end
	local profile = store:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if not profile then
		if player.Parent == Players then
			player:Kick("Your save could not be loaded. Please join again.")
		end
		return
	end
	if profile.Data.Version > VERSION then
		-- (kept by a newer game than this server's: an older one never writes it)
		profile:EndSession()
		player:Kick("The game was just updated. Please join again.")
		return
	end
	if player.Parent ~= Players then
		profile:EndSession()
		return
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	local save: Save = { Player = player, Profile = profile, On = {}, Failed = {} }
	saves[player] = save
	profile.OnSave:Connect(function()
		if saves[player] == save then
			take(save)
		end
	end)
	profile.OnSessionEnd:Connect(function()
		if saves[player] == save then
			saves[player] = nil
			player:SetAttribute("Saved", nil)
			player:Kick("Your save was opened somewhere else. Please join again.")
		end
	end)
	settle(save)
	player:SetAttribute("Saved", true)
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

-- Studio's checks: the profile closed and opened again, as by leaving and coming back. The services still have the
-- player, so what is given back adds to what they hold (twice what they had: it was kept).
function SaveService.reopen(player: Player): boolean
	local save = saves[player]
	if not RunService:IsStudio() or not save then
		return false
	end
	leave(player)
	local from = os.clock()
	while save.Profile:IsActive() and os.clock() - from < 10 do
		task.wait(0.1)
	end
	player:SetAttribute("Saved", nil)
	join(player)
	return saves[player] ~= nil
end

function SaveService.Start()
	if #order == 0 then
		return
	end
	store = ProfileStore.New(STORE, { Version = VERSION, Parts = {}, Receipts = {} })
	if RunService:IsStudio() and workspace:GetAttribute("SaveReal") ~= true then
		store = store.Mock
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
		for _, save in saves do
			settle(save)
			take(save)
		end
	end
end

return SaveService
