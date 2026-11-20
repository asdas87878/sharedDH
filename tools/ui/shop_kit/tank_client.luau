-- Task s3's capture client (a temporary LocalScript in StarterPlayerScripts, put there by s3_capture.py and taken out
-- after). It shows the tank's screens on this client only, with sample fish written into this client's copies of the
-- player's TankList, Hands and TankEarning (the server's are untouched). The workspace's "TankShot" says which:
--   "list"     the popup: 3 of 4 earning, 4 stored, 2 in the hands
--   "rarity"   the same, sorted by rarity
--   "full"     4 of 4 earning (the stored cards' buttons FULL) and the refusal's toast
--   "empty"    no fish
--   "prompt"   the popup shut, two fish carried: the tank's prompt (and the sign over the tank)
--   "deposit"  the line over the tank as a fish goes in
--   ""         all shut
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local UI = client:WaitForChild("UI")
task.wait(2)
local Config = require(ReplicatedStorage.Shared.Config)
local State = require(client.Lib.State)
local TankPanel = require(UI.TankPanel)
local TankPrompt = require(UI.TankPrompt)
local report = ReplicatedStorage:FindFirstChild("ZZShopReport")

-- one fish of each tier, in the roster's order
local byTier: { [string]: { string } } = {}
for _, kind in Config.Fish do
	byTier[kind.Tier] = byTier[kind.Tier] or {}
	table.insert(byTier[kind.Tier], kind.Id)
end
local function pick(tier: string, n: number): string
	local t = byTier[tier] or byTier.Common
	return t[((n - 1) % #t) + 1]
end

local function water(): BasePart?
	local plot = workspace.ClaudeBlockout.Dock.Plots:FindFirstChild(player:GetAttribute("Plot") or "")
	local w = plot and plot:FindFirstChild("TankWater")
	return if w and w:IsA("BasePart") then w else nil
end

local function set(earning: number, rows: { any }, hands: { any })
	player:SetAttribute("TankEarning", earning)
	player:SetAttribute("TankList", HttpService:JSONEncode(rows))
	player:SetAttribute("Hands", HttpService:JSONEncode(hands))
end

local LIST = {
	{ "a", pick("Mythic", 1), "Huge", "Gold", 1 },
	{ "b", pick("Epic", 1), "Giant", "", 1 },
	{ "c", pick("Rare", 1), "Big", "Rainbow", 1 },
	{ "d", pick("Legendary", 1), "Colossal", "", 0 },
	{ "e", pick("Uncommon", 1), "Normal", "Silver", 0 },
	{ "f", pick("Common", 2), "Tiny", "", 0 },
	{ "g", pick("Secret", 1), "Normal", "", 0 },
}
local HANDS = { { pick("Epic", 2), "Normal", "" }, { pick("Common", 3), "Big", "Gold" } }

local function camAtTank()
	local w = water()
	local cam = workspace.CurrentCamera
	local _, root = State.character()
	if w and root then
		cam.CameraType = Enum.CameraType.Scriptable
		local to = (Vector3.new(w.Position.X, root.Position.Y, w.Position.Z) - root.Position).Unit
		cam.CFrame =
			CFrame.lookAt(root.Position - to * 5 + Vector3.new(0, 6, 0), root.Position + to * 14 + Vector3.new(0, 1, 0))
	end
end

workspace:GetAttributeChangedSignal("TankShot"):Connect(function()
	local shot = workspace:GetAttribute("TankShot") or ""
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	TankPanel.toggle(false)
	State.Caught = nil
	if shot == "list" or shot == "rarity" then
		set(4, { LIST[1], LIST[2], LIST[3], LIST[4], LIST[5], LIST[6], LIST[7] }, HANDS)
		TankPanel.sort(if shot == "rarity" then "Rarity" else "Income")
		TankPanel.toggle(true)
	elseif shot == "full" then
		local rows = table.clone(LIST)
		rows[4] = { "d", pick("Legendary", 1), "Colossal", "", 1 }
		set(4, rows, {})
		TankPanel.sort("Income")
		TankPanel.toggle(true)
		task.wait(0.3)
		TankPanel.notice("THE TANK IS FULL: UNEQUIP ONE FIRST")
	elseif shot == "empty" then
		set(4, {}, {})
		TankPanel.toggle(true)
	elseif shot == "prompt" then
		set(4, { LIST[1], LIST[2] }, HANDS)
		local list = {}
		for _, h in HANDS do
			table.insert(list, { Id = h[1], Tier = Config.FishById[h[1]].Tier })
		end
		State.Caught = list
		camAtTank()
	elseif shot == "deposit" then
		camAtTank()
		task.wait(1.6) -- (so the line is up, not yet fading, when the shot is taken)
		local w = water()
		if w then
			local id = pick("Epic", 2)
			TankPrompt.deposited(w, 1, Config.incomeOf(Config.FishById[id], "Normal", ""), id)
		end
	end
	if report then
		report:FireServer("shot " .. tostring(shot) .. " open=" .. tostring(TankPanel.isOpen()))
	end
end)
if report then
	report:FireServer("tank client ready")
end
