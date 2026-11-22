-- Shows the live black holes in Studio's EDIT mode (docs/design/cosmic.md): every part tagged "BlackHole" gets one,
-- as Controllers/BlackHoleDisplayController does in Play. Paste into the command bar; run it again to take them away.
-- The cubes go in a folder that is not saved with the place (Archivable off), and they bend by where the Edit camera
-- is, so fly round them. To see the riding view of the display by the hub:
--   workspace.CurrentCamera.CFrame = workspace.CosmicHollowDisplay.RideCamera.CFrame
local CollectionService = game:GetService("CollectionService")

local BlackHole = require(game.StarterPlayer.StarterPlayerScripts.Client.Lib.BlackHole)

if _G.BlackHolePreview then
	for _, hole in _G.BlackHolePreview.holes do
		hole:Destroy()
	end
	_G.BlackHolePreview.folder:Destroy()
	_G.BlackHolePreview = nil
	print("black hole preview: off")
	return
end

local folder = Instance.new("Folder")
folder.Name = "BlackHolePreview (not saved)"
folder.Archivable = false
folder.Parent = workspace
local holes = {}
for _, anchor in CollectionService:GetTagged("BlackHole") do
	if anchor:IsA("BasePart") then
		local function attr(name, default)
			local value = anchor:GetAttribute(name)
			return if value == nil then default else value
		end
		local hole = BlackHole.new(anchor.CFrame, {
			Scale = attr("Scale", 1.2),
			Voxel = attr("Voxel", 0.15),
			Quality = attr("Quality", "Medium"),
			Jets = attr("Jets", true),
			AutoFeed = attr("AutoFeed", 25),
			Parent = folder,
		})
		hole:Start()
		table.insert(holes, hole)
	end
end
_G.BlackHolePreview = { holes = holes, folder = folder }
print("black hole preview: " .. #holes .. " on (run again to take them away)")
