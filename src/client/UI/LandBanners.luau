--!strict
-- The ten lands' painted pictures (NULLROOM task g1, 2026-11-25: our own art, painted from our own captures;
-- art/ui/lands, its README has the sources), used by the Index (UI.IndexWindow): tall on the land's banner, and a
-- slice of the same picture on its tab.
-- Uploaded 2026-11-25 on the user's word ("Yes, both"; the ten files in art/ui/lands/upload, made by
-- `python tools/index/land_banners.py`). Without an id a live game shows the land's plain colours (`fill`), which always
-- lie under the picture; Studio reads the copies that `python tools/index/land_banners.py studio` puts in its content
-- folder (none there: the plain colours too).
local RunService = game:GetService("RunService")

local Kit = require(script.Parent.Kit)

local LandBanners = {}

-- rbxassetid://... by land: 1 Shallows, 2 Coral Reef, 3 Kelp Forest, 4 Shipwrecks, 5 Open Blue, 6 Twilight,
-- 7 Midnight, 8 Vents, 9 Bone Graveyard, 10 The Underworld
LandBanners.Ids = {
	"rbxassetid://86749397960198",
	"rbxassetid://125062760868935",
	"rbxassetid://75159866433385",
	"rbxassetid://105808587264414",
	"rbxassetid://81330978181108",
	"rbxassetid://102542146892153",
	"rbxassetid://118663173346835",
	"rbxassetid://98241959226257",
	"rbxassetid://105274886652095",
	"rbxassetid://99979930581147",
}
LandBanners.Studio = "rbxasset://textures/ridefish/land_banner_%02d.png"

-- A land's picture, "" where there is none
function LandBanners.image(land: number): string
	local id = LandBanners.Ids[land]
	if id and id ~= "" then
		return id
	end
	if id and RunService:IsStudio() then
		return string.format(LandBanners.Studio, land)
	end
	return ""
end

-- The plain stand-in: the land's own colour, lit at the top and deep at the foot
function LandBanners.fill(land: number): ColorSequence
	local colour = Kit.Lands[math.clamp(land, 1, #Kit.Lands)]
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, Kit.lighter(colour, 0.18)),
		ColorSequenceKeypoint.new(0.5, colour),
		ColorSequenceKeypoint.new(1, Kit.darker(colour, 0.35)),
	})
end

return LandBanners
