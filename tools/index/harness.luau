-- Runs the game's own modules offline in Lune, for checks that need no Studio (NULLROOM task h2: the Index).
-- It reads a place built by Rojo (`rojo build -o place.rbxl`), so `script`, `script.Parent` and
-- `game:GetService("ReplicatedStorage").Shared` are the real tree, and loads a ModuleScript's Source with its own
-- `require`. Lune's Roblox library has no events and no running services, so a check gives its own stand-ins:
--   world.services[name]   what game:GetService(name) returns in place of the place's own (Players, RunService ...)
--   world.stubs[fullName]  what require returns for that module in place of loading it (a service not under test)
--   world.globals[name]    a global every loaded module sees in place of Lune's (os, Instance, workspace ...)
-- usage, from a check: local Harness = require("./harness"); local world = Harness.open(placePath)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local Harness = {}

-- The Roblox datatypes a module may name
local TYPES = {
	"Axes",
	"BrickColor",
	"CFrame",
	"Color3",
	"ColorSequence",
	"ColorSequenceKeypoint",
	"Enum",
	"Faces",
	"Font",
	"NumberRange",
	"NumberSequence",
	"NumberSequenceKeypoint",
	"PhysicalProperties",
	"Ray",
	"Rect",
	"Region3",
	"Region3int16",
	"UDim",
	"UDim2",
	"Vector2",
	"Vector2int16",
	"Vector3",
	"Vector3int16",
}

function Harness.open(placePath: string)
	local place = roblox.deserializePlace(fs.readFile(placePath))
	local world = {
		place = place,
		services = {} :: { [string]: any },
		stubs = {} :: { [string]: any },
		globals = {} :: { [string]: any },
		warnings = {} :: { string },
		loaded = {} :: { [string]: any },
	}

	local game = {}
	function game.GetService(_self: any, name: string): any
		return world.services[name] or place:GetService(name)
	end
	function game.FindFirstChild(_self: any, name: string): any
		return place:FindFirstChild(name)
	end
	world.game = game

	local function environment(module: any): { [string]: any }
		local env: { [string]: any } = {
			game = game,
			workspace = world.services.Workspace or place:GetService("Workspace"),
			script = module,
			Instance = roblox.Instance,
			task = task,
			warn = function(...: any)
				local parts = {}
				for _, part in { ... } do
					table.insert(parts, tostring(part))
				end
				table.insert(world.warnings, table.concat(parts, " "))
			end,
		}
		for _, name in TYPES do
			env[name] = (roblox :: any)[name]
		end
		env.require = function(target: any): any
			return world.require(target)
		end
		for name, value in world.globals do
			env[name] = value
		end
		return env
	end

	-- require, as a module in the place sees it: a ModuleScript of the place (loaded once), or a stand-in
	function world.require(module: any): any
		local name = module:GetFullName()
		local stub = world.stubs[name]
		if stub ~= nil then
			return stub
		end
		local had = world.loaded[name]
		if had ~= nil then
			return had
		end
		local chunk = luau.load(module.Source, { debugName = name, environment = environment(module) })
		local result = chunk()
		world.loaded[name] = result
		return result
	end

	-- A module by its path in the place: "ReplicatedStorage.Shared.Config"
	function world.find(path: string): any
		local at: any = nil
		for part in string.gmatch(path, "[^%.]+") do
			at = if at then at:FindFirstChild(part) else place:GetService(part)
			assert(at, "nothing at " .. path .. " (" .. part .. ")")
		end
		return at
	end

	return world
end

-- A check's own tally: ok(what, condition) prints a line, and done() ends the run with the count (exit 1 on a fail)
function Harness.tally()
	local passed, failed = 0, 0
	local function ok(what: string, condition: any, detail: any?)
		if condition then
			passed += 1
			print("  ok    " .. what)
		else
			failed += 1
			print("  FAIL  " .. what .. (if detail ~= nil then "  (" .. tostring(detail) .. ")" else ""))
		end
	end
	local function done()
		print(string.format("%d passed, %d failed", passed, failed))
		if failed > 0 then
			require("@lune/process").exit(1)
		end
	end
	return ok, done
end

return Harness
