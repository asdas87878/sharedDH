"""For when the Rojo plugin isn't connected (after a Studio restart, until the user presses Connect): writes a Luau file
that sets the Source of the named scripts in the open place from the repo's files. Run that file with run_luau.js.
usage: python tools/studio/push_scripts.py <repo> <out.luau> <src-relative path>=<Studio path, dots> ...
  e.g. python tools/studio/push_scripts.py . /tmp/push.luau \\
         src/client/Controllers/HudController.luau=StarterPlayer.StarterPlayerScripts.Client.Controllers.HudController
       node tools/studio/run_luau.js <studio_id> /tmp/push.luau
A script that isn't in the place yet is made (a ModuleScript; a LocalScript for .client.luau, a Script for
.server.luau) when its parent is there.
"""
import io
import json
import sys

repo, out = sys.argv[1], sys.argv[2]
items = []
for pair in sys.argv[3:]:
    rel, where = pair.split("=")
    src = io.open(repo + "/" + rel, encoding="utf-8", newline="").read().replace("\r\n", "\n")
    kind = "LocalScript" if rel.endswith(".client.luau") else "Script" if rel.endswith(".server.luau") else "ModuleScript"
    items.append({"path": where.split("."), "source": src, "class": kind})

blob = json.dumps(items)
assert "]==]" not in blob
luau = """local HttpService = game:GetService("HttpService")
local items = HttpService:JSONDecode([==[%s]==])
local out = {}
for _, item in items do
	local at = game
	for i, name in item.path do
		local parent = at
		at = if i == 1 then game:GetService(name) else at:FindFirstChild(name)
		if not at then
			if i == #item.path then
				at = Instance.new(item.class)
				at.Name = name
				at.Parent = parent
			else
				error("no " .. table.concat(item.path, "."))
			end
		end
	end
	at.Source = item.source
	table.insert(out, table.concat(item.path, ".") .. " " .. #at.Source)
end
return table.concat(out, "; ")
""" % blob
io.open(out, "w", encoding="utf-8", newline="\n").write(luau)
print("written", len(luau))
