--!strict
-- The ten lands' painted pictures (NULLROOM task g1, 2026-11-25: our own art, painted from our own captures;
-- art/ui/lands, its README has the sources), used by the Index (UI.IndexWindow): tall on the land's banner, and a
-- slice of the same picture on its tab.
-- NOT UPLOADED YET: each id below waits for Hugo's yes (the ten files in art/ui/lands/upload, made by
-- `python tools/index/land_banners.py`). Until then a live game shows the land's plain colours (`fill`), which always
-- lie under the picture; Studio reads the copies that `python tools/index/land_banners.py studio` puts in its content
-- folder (none there: the plain colours too).
local RunService = game:GetService("RunService")

local Kit = require(script.Parent.Kit)

local LandBanners = {}

-- rbxassetid://... by land: 1 Shallows, 2 Coral Reef, 3 Kelp Forest, 4 Shipwrecks, 5 Open Blue, 6 Twilight,
-- 7 Midnight, 8 Vents, 9 Bone Graveyard, 10 The Underworld
LandBanners.Ids = { "", "", "", "", "", "", "", "", "", "" }
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
