--!strict
-- How the passive archetypes are named and coloured wherever they are shown (a fish's tag, the line under the ring,
-- the word that pops up): docs/design/archetypes.md. The rules and numbers are Config.Archetype; this is only the
-- wording, in the order a fish's row lists them.
local Config = require(script.Parent.Config)

export type Info = {
	Name: string, -- on a tag
	Colour: Color3,
	Does: string, -- a few words: what it does, for the line under the ring
}

local Archetypes = {}

Archetypes.Info = {
	Fast = { Name = "FAST", Colour = Color3.fromRGB(96, 224, 255), Does = "launches on landing" },
	Predator = { Name = "PREDATOR", Colour = Color3.fromRGB(255, 96, 100), Does = "eats smaller fish" },
	Frenzy = { Name = "FRENZY", Colour = Color3.fromRGB(255, 150, 50), Does = "bites chain" },
	Breaker = { Name = "BREAKER", Colour = Color3.fromRGB(255, 205, 70), Does = "smashes props for speed" },
	Tank = { Name = "TANK", Colour = Color3.fromRGB(141, 240, 106), Does = "air lasts longer" },
	Leaper = { Name = "LEAPER", Colour = Color3.fromRGB(200, 150, 255), Does = "hops further" },
} :: { [string]: Info }

local function hex(colour: Color3): string
	return string.format(
		"#%02x%02x%02x",
		math.floor(colour.R * 255 + 0.5),
		math.floor(colour.G * 255 + 0.5),
		math.floor(colour.B * 255 + 0.5)
	)
end

local rich: { [string]: string } = {}

-- A fish's archetypes as one line of rich text, each in its colour ("" for none): "PREDATOR · BREAKER"
function Archetypes.rich(fish: Config.FishType): string
	local made = rich[fish.Archetype]
	if made then
		return made
	end
	local words = {}
	for _, id in Config.archetypesOf(fish) do
		local info = Archetypes.Info[id]
		if info then
			table.insert(words, string.format('<font color="%s">%s</font>', hex(info.Colour), info.Name))
		end
	end
	local line = table.concat(words, " · ")
	rich[fish.Archetype] = line
	return line
end

-- What a fish's archetypes do, in plain words, for the line under the ring ("" for none): "eats smaller fish, hops further"
function Archetypes.does(fish: Config.FishType): string
	local words = {}
	for _, id in Config.archetypesOf(fish) do
		local info = Archetypes.Info[id]
		if info then
			table.insert(words, info.Does)
		end
	end
	return table.concat(words, ", ")
end

return Archetypes
