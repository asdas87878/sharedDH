--!nocheck
local b = workspace:FindFirstChild("MapBench")
for _, d in b:GetDescendants() do
	if d.Name == "DockSpawn" then
		d:Destroy()
	end
end
local dive = b:FindFirstChild("Dive")
if dive then
	dive:Destroy()
end
b:SetAttribute("Build", "a bench, not the map")
return "bench cleaned: no spawn, no path"
