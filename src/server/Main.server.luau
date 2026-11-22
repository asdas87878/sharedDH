--!strict
-- Loads every ModuleScript in Services/: Init on all of them first (setup, must not yield), then Start each in its
-- own thread. A module that fails to load, or whose Init fails, is reported in the output ("[Main]", with where it
-- failed) and left out, so one broken module does not stop the ones after it.
local services = script.Parent:FindFirstChild("Services")
if not services then
	return
end

-- Calls f(...). True and what it returned, or false after warning what went wrong and where.
local function guarded(what: string, f: (...any) -> ...any, ...: any): (boolean, any)
	return xpcall(f, function(problem: any)
		warn(`[Main] {what} failed: {debug.traceback(tostring(problem), 2)}`)
	end, ...)
end

local loaded: { { Name: string, Module: any } } = {}
for _, module in services:GetChildren() do
	if module:IsA("ModuleScript") then
		local ok, service = guarded(`loading {module.Name}`, require :: any, module)
		if ok then
			table.insert(loaded, { Name = module.Name, Module = service })
		end
	end
end
local ready = {}
for _, entry in loaded do
	local init = entry.Module.Init
	if not init or guarded(`{entry.Name}.Init`, init) then
		table.insert(ready, entry.Module)
	end
end
for _, service in ready do
	if service.Start then
		task.spawn(service.Start)
	end
end
