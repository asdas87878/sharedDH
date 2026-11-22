--!strict
-- Live black holes on display (docs/design/cosmic.md, "Where it goes on a big fish"): every part tagged "BlackHole" gets
-- one (Lib/BlackHole: voxel cubes made on this client, their light bent by where the camera stands), at the part's
-- CFrame: the disc lies in the part's XZ plane, the jets up its Y axis. The part itself is an invisible anchor.
-- Settings come from the part's attributes, each optional: Scale, Voxel, Quality ("Tiny", "Low", "Medium", "High"),
-- Jets (bool), AutoFeed (seconds between feeds, 0 none). A hole that streams out or loses its tag is taken away.
-- The anchor stays still: a hole that rides a fish wants Follow and a lower Quality (see Lib/BlackHole's cost notes).
local CollectionService = game:GetService("CollectionService")

local BlackHole = require(script.Parent.Parent.Lib.BlackHole)

local TAG = "BlackHole"

local BlackHoleDisplayController = {}

local holes: { [Instance]: any } = {}

local function add(anchor: Instance)
	if holes[anchor] or not anchor:IsA("BasePart") then
		return
	end
	local function attr(name: string, default: any): any
		local value = anchor:GetAttribute(name)
		return if value == nil then default else value
	end
	local hole = BlackHole.new(anchor.CFrame, {
		Scale = attr("Scale", 1.2),
		Voxel = attr("Voxel", 0.15),
		Quality = attr("Quality", "Medium"),
		Jets = attr("Jets", true),
		AutoFeed = attr("AutoFeed", 25),
	})
	hole:Start()
	holes[anchor] = hole
end

local function remove(anchor: Instance)
	local hole = holes[anchor]
	if hole then
		holes[anchor] = nil
		hole:Destroy()
	end
end

function BlackHoleDisplayController.Start()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)
	for _, anchor in CollectionService:GetTagged(TAG) do
		add(anchor)
	end
end

return BlackHoleDisplayController
