-- B1 props playtest: what the SERVER holds of the props while the client's test runs (p3, 2026-11-13). Run once in
-- the playtest's server (studio-run.mjs --ctx server <this file>) before the suite; it returns at once and keeps
-- counting twice a second into ServerStorage.B1Watch. The see-through, the hidden boxes and the flying copies are one
-- player's screen only if none of it is ever here: every box's Transparency as the map made it, no
-- LocalTransparencyModifier, no box added to the props folder, nothing under the server's camera. (What the server
-- does hold, and every player gets, is which boxes are out: the tag "PropOut".)
local SS = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local folder = workspace.ClaudeBlockout.Lane.Props
local parts, base = {}, {}
for _, d in folder:GetDescendants() do
	if d:IsA("BasePart") then
		table.insert(parts, d)
		base[d] = d.Transparency
	end
end
local old = SS:FindFirstChild("B1Watch")
if old then
	old:Destroy()
end
local value = Instance.new("StringValue")
value.Name = "B1Watch"
value.Parent = SS
local all = #folder:GetDescendants()
task.spawn(function()
	local samples, changed, modified, added, camera, tagged, withTags = 0, 0, 0, 0, 0, 0, 0
	while value.Parent do
		local c, m = 0, 0
		for _, part in parts do
			if part.Transparency ~= base[part] then
				c += 1
			end
			if part.LocalTransparencyModifier ~= 0 then
				m += 1
			end
		end
		samples += 1
		changed = math.max(changed, c)
		modified = math.max(modified, m)
		added = math.max(added, math.abs(#folder:GetDescendants() - all))
		local cam = workspace.CurrentCamera
		camera = math.max(camera, if cam then #cam:GetDescendants() else 0)
		local t = #CollectionService:GetTagged("PropOut")
		tagged = math.max(tagged, t)
		withTags += if t > 0 then 1 else 0
		value.Value = string.format(
			"%d looks at %d boxes | boxes whose Transparency is not the map's, most %d | boxes with a LocalTransparencyModifier, most %d | instances added to or gone from the props folder, most %d | things under the server's camera, most %d | boxes tagged out, most %d (in %d looks)",
			samples,
			#parts,
			changed,
			modified,
			added,
			camera,
			tagged,
			withTags
		)
		task.wait(0.5)
	end
end)
return string.format("watching %d boxes", #parts)
