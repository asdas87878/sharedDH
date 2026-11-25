--!strict
-- Fusing's rules (Hugo, 2026-11-25; docs/design/fusing.md): three fish of one kind become one. The biggest of the three
-- stays, with its own colour and everything else of its own, and grows one size (Config.SizeOrder); the other two are
-- used up and their colours with them: nothing is inherited. Plain sums with nothing of Roblox in them, the same ones
-- for the server, which decides (AquariumService.fuse), and the window, which shows it beforehand (UI/FusePanel).
--   Biggest is by size alone, never by colour or worth. Equally big: the one put in first.
--   A fish of the top size can't grow, so three with one in them are refused ("Top").
local Config = require(script.Parent.Config)

export type Fish = { Id: string, Size: string, Variant: string }
export type Outcome = {
	Keep: number, -- which of the three stays (1 to 3)
	From: string, -- its size now
	To: string, -- and after
	Used: { number }, -- the two used up
}

local Fuse = {}

Fuse.Count = 3 -- how many go in

-- A size's place, 1 the smallest (0: not a size)
function Fuse.rank(size: string): number
	return table.find(Config.SizeOrder, size) or 0
end

-- The next size up (nil: the top one, or not a size)
function Fuse.grown(size: string): string?
	local at = Fuse.rank(size)
	return if at > 0 then Config.SizeOrder[at + 1] else nil
end

-- A fish the player would be sorry to lose by mistake: with a colour, or at least Fuse.SureSize big
function Fuse.special(fish: Fish): boolean
	local sure = Fuse.rank(Config.Fuse.SureSize)
	return fish.Variant ~= "" or (sure > 0 and Fuse.rank(fish.Size) >= sure)
end

-- Which of them is the biggest (the first of equals; nil for none)
function Fuse.biggest(list: { Fish }): number?
	local best: number? = nil
	for i, fish in list do
		if not best or Fuse.rank(fish.Size) > Fuse.rank(list[best].Size) then
			best = i
		end
	end
	return best
end

-- Why `fish` can't go in with `list` (those put in already; none: the first), or nil. "Kind": not the same kind;
-- "Size": not the same size (only with Fuse.SameSize); "Top": it can't grow, so nothing with it can ("Full": three are in)
function Fuse.refuses(list: { Fish }, fish: Fish): string?
	if not Config.FishById[fish.Id] or Fuse.rank(fish.Size) == 0 then
		return "Gone"
	end
	if not Fuse.grown(fish.Size) then
		return "Top"
	end
	local first = list[1]
	if first and first.Id ~= fish.Id then
		return "Kind"
	end
	if first and Config.Fuse.SameSize ~= 0 and first.Size ~= fish.Size then
		return "Size"
	end
	if #list >= Fuse.Count then
		return "Full"
	end
	return nil
end

-- What fusing these gives, or why they can't be: "Three" (not three of them) and Fuse.refuses' own
function Fuse.outcome(list: { Fish }): (Outcome?, string?)
	if #list ~= Fuse.Count then
		return nil, "Three"
	end
	local before: { Fish } = {}
	for _, fish in list do
		local why = Fuse.refuses(before, fish)
		if why then
			return nil, why
		end
		table.insert(before, fish)
	end
	local keep = Fuse.biggest(list) :: number
	local used = {}
	for i = 1, Fuse.Count do
		if i ~= keep then
			table.insert(used, i)
		end
	end
	local outcome: Outcome = {
		Keep = keep,
		From = list[keep].Size,
		To = Fuse.grown(list[keep].Size) :: string,
		Used = used,
	}
	return outcome, nil
end

return Fuse
