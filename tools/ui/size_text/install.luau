-- Edit mode: put (or take out, REMOVE=true) the temporary ZZSizeMock LocalScript (task u2). SOURCE is set by the
-- caller (run.sh). Never save the place with it in.
local REMOVE = false
local SOURCE = ""
local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local old = sps:FindFirstChild("ZZSizeMock")
if old then
	old:Destroy()
end
if REMOVE then
	return "removed"
end
local s = Instance.new("LocalScript")
s.Name = "ZZSizeMock"
s.Source = SOURCE
s.Parent = sps
return "installed " .. #SOURCE
