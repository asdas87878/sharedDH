-- B1 props playtest: server side (temporary; removed after the run)
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local LogService = game:GetService("LogService")

local log = Instance.new("StringValue")
log.Name = "B1Log"
log.Parent = SS
local lines = {}
local function add(text)
	table.insert(lines, string.format("%7.2f %s", os.clock() % 10000, text))
	log.Value = table.concat(lines, "\n")
end
local report = Instance.new("RemoteEvent")
report.Name = "B1Report"
report.Parent = RS
local cmd = Instance.new("StringValue")
cmd.Name = "B1Cmd"
cmd.Parent = RS
report.OnServerEvent:Connect(function(_, text)
	if text == "__clear" then
		table.clear(lines)
		log.Value = ""
		return
	end
	add("C " .. tostring(text))
end)
LogService.MessageOut:Connect(function(message, kind)
	if kind == Enum.MessageType.MessageWarning or kind == Enum.MessageType.MessageError then
		add("SERVER " .. kind.Name .. ": " .. message)
	end
end)
add("server up")
-- the server's own count of boxes out, for the driver's lines
local CollectionService = game:GetService("CollectionService")
local out = Instance.new("IntValue")
out.Name = "B1Out"
out.Parent = RS
task.spawn(function()
	while true do
		out.Value = #CollectionService:GetTagged("PropOut")
		task.wait(0.1)
	end
end)
