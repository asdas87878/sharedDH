-- Try the voxel black hole (src/client/Lib/BlackHole.luau, docs/design/cosmic.md).
-- Run this ON THE CLIENT while playing: paste it into the command bar with the view set to Client, or put it in a
-- LocalScript. It makes one black hole 40 studs in front of the camera, big enough to walk round, and feeds it a star
-- every 25 seconds. Fly round it and move in and out: the far side of the disc should rise over the ball and tuck
-- under it, and the arc should tighten as you back away.
--   _G.BlackHole:Feed()      feed it now
--   _G.BlackHole:Destroy()   take it away
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local BlackHole = require(Players.LocalPlayer.PlayerScripts.Client.Lib.BlackHole)

if _G.BlackHole then
	_G.BlackHole:Destroy()
end
local camera = Workspace.CurrentCamera
local at = camera.CFrame.Position + camera.CFrame.LookVector * 40
local hole = BlackHole.new(CFrame.new(at), {
	Scale = 1.5, -- a ball about 8 studs across, a disc about 27
	Voxel = 0.3,
	Quality = "Medium", -- "Low" 1,200 disc cubes, "Medium" 2,400, "High" 4,000
	AutoFeed = 25,
})
hole:Start()
_G.BlackHole = hole
