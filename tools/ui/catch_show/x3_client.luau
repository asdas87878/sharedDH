-- Temporary client script for task x3 (the catch screen's fish tiles: the inventory's pictures, behind the border).
-- Installed into StarterPlayerScripts as "ZZCatchX3" by x3_capture.py, removed after. Driven by ReplicatedStorage
-- attributes:
--   X3Show ("<n>|<json list>": each new value plays the real end of a dive, Banners.greatDive, with that list, and
--     fills the inventory slots with the same fish, so both show side by side)
--   X3Clock (a number: CatchShow's clock stopped there; nil: the real clock)
--   X3Phone ("<n>|<w>:<h>|<json list>": the live screen played into a frame of a phone's size, at the HUD's scale 1)
-- Reports through ReplicatedStorage.ZZCatchReport.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

local function report(text: string)
	local remote = RS:FindFirstChild("ZZCatchReport")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer(text)
	end
end
local client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local UI = client:WaitForChild("UI")
local CatchShow = require(UI:WaitForChild("CatchShow"))
local Banners = require(UI:WaitForChild("Banners"))
local Slots = require(UI:WaitForChild("Slots"))
local realClock = os.clock

local seenShow, seenPhone = nil, nil
RunService.RenderStepped:Connect(function()
	local clock = RS:GetAttribute("X3Clock")
	if type(clock) == "number" then
		CatchShow.Clock = function()
			return clock
		end
	else
		CatchShow.Clock = realClock
	end
	local show = RS:GetAttribute("X3Show")
	if show ~= seenShow then
		seenShow = show
		if type(show) == "string" then
			local list = HttpService:JSONDecode(string.match(show, "|(.*)$") :: string)
			-- (the slots too only when asked: Studio draws only so many fish pictures at once)
			pcall(Slots.update, if string.sub(show, 1, 1) == "S" then list else {})
			local ok, err = pcall(Banners.greatDive, 312, true, list)
			report("show " .. tostring(ok) .. " " .. tostring(err) .. " look " .. CatchShow.look() .. " showing " .. tostring(CatchShow.showing()))
			task.delay(1, function()
				local root = player.PlayerGui:FindFirstChild("RideHud")
				local c = root and root:FindFirstChild("CatchShow", true)
				local out = {}
				local at: Instance? = c
				while at and at ~= game do
					local vis = if at:IsA("GuiObject") then tostring(at.Visible) else at.ClassName
					table.insert(out, at.Name .. "(" .. vis .. ")")
					at = at.Parent
				end
				report("tree " .. table.concat(out, " < ") .. " showing " .. tostring(CatchShow.showing()))
			end)
		end
	end
	local phone = RS:GetAttribute("X3Phone")
	if phone ~= seenPhone then
		seenPhone = phone
		local old = player.PlayerGui:FindFirstChild("ZZPhone")
		if old then
			old:Destroy()
		end
		if type(phone) == "string" then
			local pw, ph, json = string.match(phone, "^%d+|(%d+):(%d+)|(.*)$")
			local list = HttpService:JSONDecode(json :: string)
			local g = Instance.new("ScreenGui")
			g.Name = "ZZPhone"
			g.DisplayOrder = 60
			g.IgnoreGuiInset = true
			g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
			local f = Instance.new("Frame")
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Position = UDim2.fromScale(0.5, 0.5)
			f.Size = UDim2.fromOffset(tonumber(pw) :: number, tonumber(ph) :: number)
			f.BackgroundColor3 = Color3.fromRGB(70, 150, 70)
			f.ClipsDescendants = true
			f.Parent = g
			g.Parent = player.PlayerGui
			local ok = CatchShow.play(f, CatchShow.look(), 312, true, list)
			report("phone " .. tostring(ok))
		end
	end
end)
report("x3 up")
