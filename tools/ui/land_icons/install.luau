-- Edit mode: put (or take out, REMOVE=true) the temporary ZZShotCam LocalScript. SOURCE is set by the caller.
local REMOVE = false
local SOURCE = ""
local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local old = sps:FindFirstChild("ZZShotCam")
if old then
	old:Destroy()
end
if REMOVE then
	return "removed"
end
local s = Instance.new("LocalScript")
s.Name = "ZZShotCam"
s.Source = SOURCE
s.Parent = sps
return "installed " .. #SOURCE
