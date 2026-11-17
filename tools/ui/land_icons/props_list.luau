-- Edit mode: every big prop on the lane: name, centre, size (for choosing the land-icon framings). JSON out.
local HttpService = game:GetService("HttpService")
local props = workspace:FindFirstChild("ClaudeBlockout")
props = props and props:FindFirstChild("Lane")
props = props and props:FindFirstChild("Props")
if not props then
	return "no props folder"
end
local out = {}
for _, m in props:GetChildren() do
	if m:IsA("Model") then
		local cf, size = m:GetBoundingBox()
		table.insert(out, {
			n = m:GetAttribute("PropName") or m.Name,
			p = { math.floor(cf.X), math.floor(cf.Y), math.floor(cf.Z) },
			s = { math.floor(size.X), math.floor(size.Y), math.floor(size.Z) },
		})
	end
end
return HttpService:JSONEncode(out)
