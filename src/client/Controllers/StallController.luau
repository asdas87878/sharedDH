--!strict
-- The dock's windows and what opens them (UI review 1, the user, 2026-11-22: "the shop button opens up the sell dinos
-- and auras UI's. This is wrong, they should pop up when you stand on the stands corresponding to them in game. The
-- shop UI is a seperate thing"; docs/design/ui-review.md):
--   Sell, Auras and the submarine shop open when this player stands on the stall's floor ring (Dock/Stations/Sell,
--   Auras and Sub, the hub kit's Ring, the one the place's HubLife fills in while stood on) and close when they walk
--   off it (the sub shop too since 2026-11-23, Hugo: "you dont have to hold e but you should just be able to stand on
--   the circle for the ui to pop up, closing when walking off it"). The edge to leave is a little wider than the one
--   to come in, so standing on the line doesn't flicker. Closing one with its X keeps it shut until the player steps
--   off and on again.
--   The Index does the same on its own ring, Dock/Stations/Index (Hugo, 2026-11-24: "Integrate ui popup when you stand
--   on index as well"), as well as by its hub button (UI.HubButtons): walking off the ring closes it however it was
--   opened. The station is the lighthouse with the open book. It was deleted by hand on 2026-11-23; Hugo's saved place
--   has it again (read offline 2026-11-25). With no ring there, nothing happens. Config.Index.On 0 stops the ring as
--   it stops the button. The ring opens whichever window gave Shop.page("Index") its opener. Walked offline by
--   tools/index/ring_test.luau.
--   The Fuse machine does the same on its ring, Dock/Stations/Fuse (Hugo, 2026-11-25; docs/design/fusing.md), while
--   Config.Fuse.On is not 0. No ring in the place: nothing happens.
--   A ring the player is put down on (a spawn, the way back from a dive: the hub kit's Fuse ring lies on the spawn)
--   opens nothing until they step off it and on again.
--   The hub's Shop button opens the Shop (UI.ShopScreen), and closes it again. A stat row's plus button opens it at what
--   is sold of that row: the coins' at Cash, the Oxygen's at Oxygen (the user, 2026-11-23).
--   Leaving the dock closes them all. One dock window at a time (UI.Shop.go).
--   While this player carries a catch on the dock and no window is up, "GO TO YOUR TANK TO DEPOSIT" (UI.DockNotes).
-- Only the screen: nothing here is trusted by the server (it sells, and will sell auras, by its own checks; a sub is
-- bought and equipped only within Config.Sub.Near of the stand, SubService).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.Parent.Lib.State)
local CatchShow = require(script.Parent.Parent.UI.CatchShow)
local DockNotes = require(script.Parent.Parent.UI.DockNotes)
local HubButtons = require(script.Parent.Parent.UI.HubButtons)
local Shop = require(script.Parent.Parent.UI.Shop)
local ShopScreen = require(script.Parent.Parent.UI.ShopScreen)
local StatRows = require(script.Parent.Parent.UI.StatRows)
local TankPanel = require(script.Parent.Parent.UI.TankPanel)
require(script.Parent.Parent.UI.AuraShop) -- (each window gives Shop its opener as it is required)
require(script.Parent.Parent.UI.FusePanel)
require(script.Parent.Parent.UI.IndexPanel)
require(script.Parent.Parent.UI.SellFish)
require(script.Parent.Parent.UI.SubPanel)

local StallController = {}

local STALLS = { "Sell", "Auras", "Sub", "Index", "Fuse" } -- a stall's name under Dock/Stations is its window's name in Shop.go
local SOLD = { Oxygen = "Oxygen", Coins = "Cash" } :: { [string]: string } -- a stat row's section in the Shop
local OUT = 2.5 -- studs past the ring's edge before walking off closes the window
local HIGH = 14 -- how far above or below the ring still counts (as HubLife's)
local EVERY = 0.05 -- seconds between looks

local inside: { [string]: boolean } = {}
local body: Model? = nil -- the character as of the last look on the dock (nil: not on it)

-- The stall's ring (nil: not in the place, or not streamed in yet)
local function ringOf(name: string): BasePart?
	local blockout = workspace:FindFirstChild("ClaudeBlockout")
	local dock = blockout and blockout:FindFirstChild("Dock")
	local stations = dock and dock:FindFirstChild("Stations")
	local stall = stations and stations:FindFirstChild(name)
	local ring = stall and (stall:FindFirstChild("Ring") or (stall:IsA("Model") and stall.PrimaryPart))
	return if ring and ring:IsA("BasePart") then ring else nil
end

-- Is this player on the ring: within its edge, or within its edge and OUT when already on it
local function standing(ring: BasePart, already: boolean): boolean
	local character = Players.LocalPlayer.Character
	local root = character and character.PrimaryPart
	if not root then
		return false
	end
	local d = root.Position - ring.Position
	local reach = ring.Size.X / 2 + (if already then OUT else 0)
	return d.X * d.X + d.Z * d.Z < reach * reach and math.abs(d.Y) < HIGH
end

-- Does this stall's ring open anything (the Index's only while the Index is on, as its button; the Fuse machine's while
-- fusing is)
local function live(name: string): boolean
	if name == "Fuse" then
		return Config.Fuse.On ~= 0
	end
	return name ~= "Index" or Config.Index.On ~= 0
end

local function look()
	local docked = State.Mode == "Dock" and not State.Player:GetAttribute("TankRide")
	local character = Players.LocalPlayer.Character
	local here = if docked and character and character.PrimaryPart then character else nil
	local put = here ~= body -- (put down on the dock since the last look)
	body = here
	for _, name in STALLS do
		local ring = ringOf(name)
		local was = inside[name] == true
		local now = here ~= nil and live(name) and ring ~= nil and standing(ring :: BasePart, was)
		if now ~= was then
			inside[name] = now
			if now and not put then
				Shop.go(name)
			elseif not now and Shop.Page == name then
				Shop.go(nil)
			end
		end
	end
	local caught = State.Caught
	-- (the end of a dive has the screen first: the black, the fail's words, the catch)
	local ending = State.FadeText ~= "" or State.Fade > 0.02 or CatchShow.showing()
	local carries = caught ~= nil and #caught > 0
	DockNotes.carrying(docked and carries and Shop.Page == nil and not TankPanel.isOpen() and not ending)
end

function StallController.Start()
	HubButtons.Pressed:Connect(function(name: string)
		if name == "Shop" then
			Shop.go(if Shop.Page == "Shop" then nil else "Shop")
		end
	end)
	StatRows.Pressed:Connect(function(name: string)
		HubButtons.shopSeen()
		ShopScreen.goTo(SOLD[name])
	end)
	State.ModeChanged.Event:Connect(function(mode: string)
		if mode ~= "Dock" then
			Shop.go(nil)
		end
	end)
	local last = 0
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		if t - last < EVERY then
			return
		end
		last = t
		look()
	end)
end

return StallController
