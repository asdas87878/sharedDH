-- Feel review: keeps every [FeelHop] line of this Play session with the clock it came at, and the frame rate every 2 s
-- (Client datamodel, in Play, before the presses). LogService's own history drops old lines on a long run, so a
-- 100-hop test needs this. Lines land in LocalPlayer.HopLogT ("clock|json"), frame rates in LocalPlayer.FpsLog;
-- hop_summary.luau reads them.
local LogService = game:GetService("LogService")
local RunService = game:GetService("RunService")
local lp = game:GetService("Players").LocalPlayer
for _, name in { "HopLogT", "FpsLog" } do
	local old = lp:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end
local store = Instance.new("StringValue")
store.Name = "HopLogT"
store.Parent = lp
local fpsStore = Instance.new("StringValue")
fpsStore.Name = "FpsLog"
fpsStore.Parent = lp
local hops = {}
LogService.MessageOut:Connect(function(msg)
	local json = string.match(msg, "^%[FeelHop%] (.+)$")
	if json and store.Parent then
		table.insert(hops, string.format("%.2f|%s", os.clock(), json))
		store.Value = table.concat(hops, "\n")
	end
end)
local frames, since = 0, os.clock()
local fps = {}
RunService.RenderStepped:Connect(function()
	frames += 1
	local now = os.clock()
	if now - since >= 2 and fpsStore.Parent then
		table.insert(fps, string.format("%.0f", frames / (now - since)))
		fpsStore.Value = table.concat(fps, ",")
		frames, since = 0, now
	end
end)
return string.format("collecting from clock %.1f", os.clock())
