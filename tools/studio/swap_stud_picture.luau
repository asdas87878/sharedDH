--!nocheck
-- Swaps the map's stud picture on the loaded place without a reload (2026-11-22: round ring studs, tile2, to
-- Roblox's own square studs, tile3; ids in art/map/textures.json). Every Texture and Decal in Workspace and
-- ServerStorage whose picture is OLD gets NEW; nothing else changes (sizes, offsets, colours stay).
-- usage: node tools/studio/run_luau.js <studio_id> tools/studio/swap_stud_picture.luau [OLD=...] [NEW=...]
local OLD = "rbxassetid://124244361010023"
local NEW = "rbxassetid://80588427262742"
local n, seen = 0, 0
for _, root in { workspace, game:GetService("ServerStorage") } do
	for _, d in root:GetDescendants() do
		if d:IsA("Texture") or d:IsA("Decal") then
			seen += 1
			if d.Texture == OLD then
				d.Texture = NEW
				n += 1
			end
		end
	end
end
return string.format("stud picture swapped on %d of %d pictures", n, seen)
