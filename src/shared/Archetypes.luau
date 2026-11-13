--!strict
-- How the passive archetypes are shown (a fish's tag, the line under the ring, the word that pops up):
-- docs/design/archetypes.md. The rules and numbers are Config.Archetype; this is only the look, in the order a fish's
-- row lists them. On a tag and under the ring each archetype is its icon, not its word (Hugo, 2026-11-13: the icons he
-- picked from docs/attachments/archetype-icons-draft-1.png, cut by art/ui/archetypes/cut_icons.py); the pop-up words
-- (CHOMP!, SMASH!, ...) keep Name's colours.
local Config = require(script.Parent.Config)

export type Info = {
	Name: string, -- its word (no longer on a tag: the icon is)
	Colour: Color3,
	Icon: string, -- the picture on a tag and under the ring
	Does: string, -- a few words: what it does, for the line under the ring
}

local Archetypes = {}

-- Where the icons come from. Not uploaded yet: no upload route works on Hugo's PC (no Open Cloud key, Handoff
-- 2026-11-12), so they are pictures in Studio's own content folder there (cut_icons.py --install), which show in
-- Studio on that PC only. Once uploaded, their ids go in UPLOADED ("rbxassetid://..."), and every PC shows them.
local UPLOADED: { [string]: string } = {}
local function icon(name: string): string
	return UPLOADED[name] or ("rbxasset://ridefish/ui/archetypes/" .. name .. ".png")
end

Archetypes.Info = {
	Fast = { Name = "FAST", Colour = Color3.fromRGB(96, 224, 255), Icon = icon("fast"), Does = "launches on landing" },
	Predator = {
		Name = "PREDATOR",
		Colour = Color3.fromRGB(255, 96, 100),
		Icon = icon("predator"),
		Does = "eats smaller fish",
	},
	Frenzy = { Name = "FRENZY", Colour = Color3.fromRGB(255, 150, 50), Icon = icon("frenzy"), Does = "bites chain" },
	Breaker = {
		Name = "BREAKER",
		Colour = Color3.fromRGB(255, 205, 70),
		Icon = icon("breaker"),
		Does = "smashes props for speed",
	},
	Tank = { Name = "TANK", Colour = Color3.fromRGB(141, 240, 106), Icon = icon("tank"), Does = "air lasts longer" },
	Leaper = { Name = "LEAPER", Colour = Color3.fromRGB(200, 150, 255), Icon = icon("leaper"), Does = "hops further" },
} :: { [string]: Info }

local lines: { [string]: string } = {}

-- A fish's archetypes as the line of icons stands for them: its known ids, comma-separated ("" for none),
-- "Predator,Frenzy". What Archetypes.icons draws (a tag's line, and the ring's: HudController hands it on as View.Kind)
function Archetypes.line(fish: Config.FishType): string
	local made = lines[fish.Archetype]
	if made then
		return made
	end
	local known = {}
	for _, id in Config.archetypesOf(fish) do
		if Archetypes.Info[id] then
			table.insert(known, id)
		end
	end
	local line = table.concat(known, ",")
	lines[fish.Archetype] = line
	return line
end
Archetypes.rich = Archetypes.line -- (its old name, which HudController still calls: the words became icons)

-- Fills a row (a Frame with a horizontal UIListLayout) with one icon per archetype of a line from Archetypes.line,
-- each size points square, side by side; spare icons are hidden. Returns how many show (0 for none)
function Archetypes.icons(row: Frame, line: string, size: number): number
	local ids = if line == "" then {} else string.split(line, ",")
	local slots: { ImageLabel } = {}
	for _, child in row:GetChildren() do
		if child:IsA("ImageLabel") then
			table.insert(slots, child)
		end
	end
	table.sort(slots, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i, id in ids do
		local slot = slots[i]
		if not slot then
			slot = Instance.new("ImageLabel")
			slot.Name = "Archetype"
			slot.BackgroundTransparency = 1
			slot.ScaleType = Enum.ScaleType.Fit
			slot.LayoutOrder = i
			slot.Parent = row
			slots[i] = slot
		end
		slot.Size = UDim2.fromOffset(size, size)
		slot.Image = Archetypes.Info[id].Icon
		slot.Visible = true
	end
	for i = #ids + 1, #slots do
		slots[i].Visible = false
	end
	return #ids
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
