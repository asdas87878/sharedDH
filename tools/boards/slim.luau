-- A saved place made small before Lune unpacks it (NULLROOM task l1): the hub's place holds 174,000 things, and unpacked
-- with every property it takes several GB. A .rbxl is a list of chunks, one for each property of each class; those that
-- are not asked for are left out, so what is left has its tree, its names and those properties alone.
-- usage: roblox.deserializePlace(slim(fs.readFile(path), { "Name", "CFrame", "Size" }))
local serde = require("@lune/serde")

local HEADER = 32 -- the file's own, before the first chunk
local CHUNK = 16 -- a chunk's: its name, its packed and unpacked length, four empty bytes

return function(bytes: string, keep: { string }): string
	assert(string.sub(bytes, 1, 8) == "<roblox!", "not a binary place")
	local wanted: { [string]: boolean } = {}
	for _, name in keep do
		wanted[name] = true
	end
	local out = { string.sub(bytes, 1, HEADER) }
	local at = HEADER + 1
	while at <= #bytes do
		local kind = string.sub(bytes, at, at + 3)
		local packed, whole = string.unpack("<I4I4", bytes, at + 4)
		local length = if packed == 0 then whole else packed
		local keepIt = true
		if kind == "PROP" then
			local body = string.sub(bytes, at + CHUNK, at + CHUNK + length - 1)
			if packed ~= 0 then
				if string.byte(body, 1) == 0x28 and string.sub(body, 2, 4) == "\xb5\x2f\xfd" then
					body = serde.decompress("zstd", body)
				else
					-- (Lune wants the length before the lz4 itself)
					body = serde.decompress("lz4", string.pack("<I4", whole) .. body)
				end
			end
			-- the class's number, then the property's name
			keepIt = wanted[(string.unpack("<s4", body, 5))] == true
		end
		if keepIt then
			table.insert(out, string.sub(bytes, at, at + CHUNK + length - 1))
		end
		at += CHUNK + length
	end
	return table.concat(out)
end
