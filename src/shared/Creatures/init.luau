--!strict
-- What the game knows about each modelled creature, by the Id it has in Config's fish table: its parts and where they
-- hinge, the rider's seat, which parts glow, and its swim as keyed turns. One JSON module per creature beside this file,
-- written by tools/creatures/collect.py from the creature chat's exports (art/creatures/<Folder>/game); don't edit them
-- by hand. The meshes are not here: they are uploaded and sit in ReplicatedStorage.FishModels.<Id> in the place.
-- Everything is in the creature's own space: studs, +Y up, the head toward -Z, the bounding box's middle at the origin.
local Creatures = {}

export type Rig = {
	Name: string,
	Size: { number }, -- x, y, z
	Seat: { number }, -- the point on its back the rider sits at
	Parts: { { any } }, -- { name, parent ("" for the first), pivot x, y, z }, parents before children
	Glow: { string }, -- parts that are Neon
	Moments: number, -- keys in one swim cycle
	Keys: { [string]: { number } }, -- part -> x, y, z, w for each moment, end to end: its turn about its pivot
}

local cache: { [string]: Rig | false } = {}
local swims: { [string]: { [string]: { CFrame } } } = {}

function Creatures.get(id: string): Rig?
	local found = cache[id]
	if found == nil then
		local module = script:FindFirstChild(id)
		local data: any = nil
		if module and module:IsA("ModuleScript") then
			local ok, result = pcall(require, module)
			if ok and type(result) == "table" and type(result.Parts) == "table" then
				data = result
			end
		end
		found = data or false
		cache[id] = found
	end
	return if found then found else nil
end

-- A creature's swim, ready to play: for each moving part, its turn at each moment of the cycle
function Creatures.swim(id: string): { [string]: { CFrame } }?
	local made = swims[id]
	if made then
		return made
	end
	local rig = Creatures.get(id)
	if not rig or rig.Moments < 2 then
		return nil
	end
	local out: { [string]: { CFrame } } = {}
	for part, numbers in rig.Keys do
		local frames = table.create(rig.Moments)
		for m = 0, rig.Moments - 1 do
			local i = m * 4
			frames[m + 1] = CFrame.new(0, 0, 0, numbers[i + 1], numbers[i + 2], numbers[i + 3], numbers[i + 4])
		end
		out[part] = frames
	end
	swims[id] = out
	return out
end

return Creatures
