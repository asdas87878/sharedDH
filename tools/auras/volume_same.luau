-- What Lib/AuraAround really sets, property by property, with no Studio: the module itself is run on stand-in instances
-- through a set of scenes (all twelve tiers, three details; standing, fading, a flare, put on, riding a small fish, on to a
-- giant one, the hop, its own rider's shape and the calmer one, off again) and every property, part place and Emit is
-- written down. The same file from two places means the same drawing: compare with `cmp`.
-- The last lines (they start with "used") are the pictures that were ever drawn, standing and riding.
-- usage: lune run tools/auras/volume_same.luau <place.rbxl> <out.txt> [Config.Aura.Small] (a place with no Small: leave it out)
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Harness = require("../index/harness")

local small = tonumber(process.args[3] or "0") :: number
local log: { string } = {}
local soon: { () -> () } = {}
local made: { any } = {}
local names: { [any]: string } = {}

local function word(v: any): string
	if type(v) == "number" then
		return string.format("%.9g", if v == 0 then 0 else v) -- (no -0)
	elseif type(v) == "table" then
		return names[v] or "?"
	end
	return tostring(v)
end

local methods = {
	Emit = function(self: any, n: number)
		table.insert(log, `emit {names[self]} {n}`)
	end,
	Clear = function(self: any)
		table.insert(log, `clear {names[self]}`)
	end,
	SetTextureOffset = function(self: any, v: number)
		self.TextureOffset = v
	end,
}
local Fake = {
	new = function(class: string): any
		local new = setmetatable({ Class = class }, { __index = methods :: any }) :: any
		names[new] = `{class}{#made + 1}`
		if class == "Beam" or class == "ParticleEmitter" then
			new.ZOffset = 0
		end
		table.insert(made, new)
		return new
	end,
}

local world = Harness.open(process.args[1])
world.services.RunService = {
	IsStudio = function()
		return true
	end,
}
world.globals.Instance = Fake
world.globals.task = {
	defer = function(f: any, ...: any)
		local args = table.pack(...)
		table.insert(soon, function()
			f(table.unpack(args, 1, args.n))
		end)
	end,
}
local V = world.require(world.find("ReplicatedStorage.Shared.AuraVolume"))
local Config = world.require(world.find("ReplicatedStorage.Shared.Config"))
local Around = world.require(world.find("StarterPlayer.StarterPlayerScripts.Client.Lib.AuraAround"))
local CFrame: any, Vector3: any = roblox.CFrame, roblox.Vector3
if small ~= 0 then
	Config.Aura.Small = small
end

local function mount(id: string): (any, any)
	local body = Config.FishById[id].Size
	local rig = serde.decode("json", fs.readFile(`src/shared/Creatures/{id}.json`))
	local k = body.Z / rig.Size[3]
	return body, Vector3.new(rig.Seat[1] * k, rig.Seat[2] * k + Config.Ride.SeatHeight, rig.Seat[3] * k)
end

local used: { [string]: { [string]: boolean } } = { standing = {}, riding = {} }
local errors = 0
for tier = 1, 12 do
	for detail = 1, 3 do
		table.clear(made)
		table.clear(names)
		table.clear(soon)
		local spec = V.spec(tier)
		local a = Around.build(Fake.new("Folder"), tier)
		local t = 0
		local function run(what: string, over: number, ride: any?, hold: boolean?, seen: ((number) -> number)?)
			local n = math.round(over * 20)
			for i = 1, n do
				t += 0.05
				local go, why = pcall(
					Around.step,
					a,
					t,
					CFrame.new(3, 1, t),
					ride,
					hold or false,
					if seen then seen(i / n) else 1,
					detail,
					detail == 3,
					function(part: any, at: any)
						part.CFrame = at
					end
				)
				if not go then
					errors += 1
					table.insert(log, `ERROR {why}`)
				end
				for _, f in soon do
					f()
				end
				table.clear(soon)
				table.insert(log, `-- tier {tier} detail {detail} {what} {i}`)
				for _, o in made do
					local keys: { string } = {}
					for key in o do
						table.insert(keys, key)
					end
					table.sort(keys)
					local line = names[o]
					for _, key in keys do
						line ..= ` {key}={word(o[key])}`
					end
					table.insert(log, line)
					if o.Enabled and o.Texture and i == n then
						used[if ride then "riding" else "standing"][o.Texture] = true
					end
				end
			end
		end
		local function on(id: string, eye: number?, calm: boolean?): any
			local body, seat = mount(id)
			local c = table.clone(Config.Aura)
			c.EyeCalm = if calm then 1 else c.EyeCalm
			return { At = CFrame.new(0, 4, t), Shape = V.ride(spec, body, seat, eye, c) }
		end
		run("fading in", 0.4, nil, false, function(u)
			return u
		end)
		Around.putOn(a, t)
		run("put on", 2)
		Around.flare(a, t)
		run("standing", 1)
		run("small fish", 1, on("Clownfish"))
		run("hop", 0.3, nil, true)
		run("giant", 1, on("Livyatan"))
		Around.flare(a, t)
		run("its rider's", 0.6, on("HammerheadShark", 17.7))
		run("calmer", 0.6, on("Livyatan", 17.7, true))
		run("off", 0.6)
		run("fading out", 0.4, nil, false, function(u)
			return math.max(1 - u, 0.01)
		end)
		Around.hide(a)
		run("back, riding", 0.4, on("Clownfish"))
	end
end
fs.writeFile(process.args[2], table.concat(log, "\n"))
print(`{#log} lines, {errors} errors`)
for _, when in { "standing", "riding" } do
	local list: { string } = {}
	for picture in used[when] do
		table.insert(list, (string.match(picture, "aura3_(%l+)_") :: any) or picture)
	end
	table.sort(list)
	print("used " .. when .. ": " .. table.concat(list, ", "))
end
