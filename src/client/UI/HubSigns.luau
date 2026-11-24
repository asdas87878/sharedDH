--!strict
-- The hub's signs that read differently for each player (the user's pick of 2026-11-16; docs/design/ui.md):
--   your own tank's sign says "YOUR TANK" where everyone else's says the owner's name (AquariumService makes both
--   labels on every sign's band, "Owner" shown and "Mine" hidden; this shows "Mine" on our own);
--   the Fuse stall's line says COMING SOON (it does nothing yet, and walking onto its ring answered nothing);
--   the trainer's sign is seen once, over our own ride (TrainService puts one on every plot's ride; this hides the
--   others'). A player with no plot may train anywhere, and sees them all.
-- Looked at once a second: eight plots, and a property is written only when it changes.
local Players = game:GetService("Players")

local UpgradeSign = require(script.Parent.UpgradeSign)

local HubSigns = {}

local EVERY = 1
local SOON = "COMING SOON"

local function look()
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local dock = blockout and blockout:FindFirstChild("Dock")
	local plots = dock and dock:FindFirstChild("Plots")
	if not plots then
		return
	end
	local stations = dock and dock:FindFirstChild("Stations")
	local fuse = stations and stations:FindFirstChild("Fuse")
	local sub = fuse and fuse:FindFirstChild("Sub", true)
	if sub and sub:IsA("TextLabel") and sub.Text ~= SOON then
		sub.Text = SOON
	end
	local mine = Players.LocalPlayer:GetAttribute("Plot")
	local hasPlot = type(mine) == "string"
	for _, plot in plots:GetChildren() do
		local own = hasPlot and plot.Name == mine
		local spot = plot:FindFirstChild("TrainerSpot")
		local sign = spot and spot:FindFirstChild("Sign")
		if sign and sign:IsA("BillboardGui") then
			local show = own or not hasPlot
			if sign.Enabled ~= show then
				sign.Enabled = show
			end
		end
		local board = plot:FindFirstChild("SignBoard")
		if board then
			for _, gui in board:GetChildren() do
				local root = gui:FindFirstChild("Board")
				local band = root and root:FindFirstChild("Band")
				local owner = band and band:FindFirstChild("Owner")
				local me = band and band:FindFirstChild("Mine")
				if owner and owner:IsA("TextLabel") and me and me:IsA("TextLabel") and me.Visible ~= own then
					me.Visible = own
					owner.Visible = not own
				end
			end
		end
	end
end

function HubSigns.start()
	-- the seahorse's upgrade sign on its post, beside every plot's ride, and the plot's own sign in front of the
	-- far-left end of its tank (task b1): both are UpgradeSign's
	UpgradeSign.start()
	task.spawn(function()
		while true do
			look()
			task.wait(EVERY)
		end
	end)
end

return HubSigns
