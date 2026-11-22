--!nocheck
-- Takes the shine off the map (2026-11-22, the user: "get rid of the reflection coming off the ground ... its deffo the
-- sun aswell"): every SmoothPlastic part of the map (ClaudeBlockout, FarView) without a material variant becomes
-- Plastic, which catches far less of the sun; Neon and glass are left alone. And the sky's reflection off
-- (Lighting.EnvironmentSpecularScale 0, as Config.Look.EnvSpecular now says). The loaders make Plastic from now on.
-- usage: node tools/studio/run_luau.js <studio_id> tools/studio/matte_map.luau ['FROM="SmoothPlastic"'] ['TO="Plastic"']
local FROM = "SmoothPlastic"
local TO = "Plastic"
game:GetService("Lighting").EnvironmentSpecularScale = 0
local n = 0
for _, name in { "ClaudeBlockout", "FarView" } do
	local root = workspace:FindFirstChild(name)
	if root then
		for _, p in root:GetDescendants() do
			if p:IsA("BasePart") and p.Material == Enum.Material[FROM] and p.MaterialVariant == "" then
				p.Material = Enum.Material[TO]
				n += 1
			end
		end
	end
end
return string.format("%d map parts %s to %s; EnvironmentSpecularScale 0", n, FROM, TO)
