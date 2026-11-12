server=open(__import__('os').path.join(__import__('os').path.dirname(__file__), 'server.luau')).read()
client=open(__import__('os').path.join(__import__('os').path.dirname(__file__), 'client.luau')).read()
assert ']==]' not in server and ']==]' not in client
open('/tmp/a2/install.luau','w').write('''
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer").StarterPlayerScripts
for _, parent in { SSS, SPS } do
	for _, name in { "A2Test", "A2Driver" } do
		local old = parent:FindFirstChild(name)
		if old then old:Destroy() end
	end
end
local s = Instance.new("Script")
s.Name = "A2Test"
s.Source = [==[''' + server + ''']==]
s.Parent = SSS
local l = Instance.new("LocalScript")
l.Name = "A2Driver"
l.Source = [==[''' + client + ''']==]
l.Parent = SPS
return "installed", #s.Source, #l.Source
''')
open('/tmp/a2/remove.luau','w').write('''
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer").StarterPlayerScripts
local n = 0
for _, parent in { SSS, SPS } do
	for _, name in { "A2Test", "A2Driver" } do
		local old = parent:FindFirstChild(name)
		if old then old:Destroy() n += 1 end
	end
end
return "removed", n
''')
