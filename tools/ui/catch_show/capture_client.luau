-- Temporary client script for the catch-UI option sheets (task s3). Installed into StarterPlayerScripts as
-- "ZZCatchShow" by capture.py, removed after. While ReplicatedStorage's "CatchOn" is true it draws the game's own
-- looks (Client.UI.CatchShow.preview), one per cell of the JSON in "CatchCells":
--   { x, y, w, h, s (scale), look, metres, best, list = { { Id, Tier } }, game (true: in the HUD at its own place) }
-- and stops cell i at the time "CatchTimes"[i] (seconds). Only the times change between shots, so nothing is rebuilt.
-- "CatchBack" is a backdrop picture (rbxasset://...) laid under each cell; "CatchHideHud" hides the HUD.
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
report("starting")
local client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local ok, CatchShow = pcall(require, client:WaitForChild("UI"):WaitForChild("CatchShow"))
if not ok then
	report("require: " .. tostring(CatchShow))
	return
end

local gui = Instance.new("ScreenGui")
gui.Name = "ZZCatchShow"
gui.DisplayOrder = 100
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local built: { any } = {}
local key = ""

local function rebuild(json: string)
	for _, c in built do
		c.holder:Destroy()
	end
	built = {}
	local okJson, cells = pcall(HttpService.JSONDecode, HttpService, json)
	if not okJson then
		report("json")
		return
	end
	for _, cell in cells do
		local parent: Instance = gui
		local holder: Frame
		if cell.game then
			local hud = player.PlayerGui:FindFirstChild("RideHud")
			local root = hud and hud:FindFirstChild("Root")
			if not root then
				report("no hud root")
				continue
			end
			holder = Instance.new("Frame")
			holder.Size = UDim2.fromScale(1, 1)
			holder.BackgroundTransparency = 1
			holder.Name = "ZZCatchGame"
			holder.Parent = root
			parent = holder
		else
			holder = Instance.new("Frame")
			holder.Position = UDim2.fromOffset(cell.x, cell.y)
			holder.Size = UDim2.fromOffset(cell.w, cell.h)
			holder.BackgroundColor3 = Color3.fromRGB(30, 90, 140)
			holder.BorderSizePixel = 0
			holder.ClipsDescendants = true
			holder.Parent = gui
			local scale = Instance.new("UIScale")
			scale.Scale = cell.s or 1
			scale.Parent = holder
			local back = RS:GetAttribute("CatchBack")
			if type(back) == "string" and back ~= "" then
				local image = Instance.new("ImageLabel")
				image.Size = UDim2.fromScale(1, 1)
				image.BackgroundTransparency = 1
				image.Image = back
				image.ScaleType = Enum.ScaleType.Crop
				image.ZIndex = 0
				image.Parent = holder
			end
			parent = holder
		end
		local okBuild, show = pcall(CatchShow.preview, parent, cell.look, cell.metres or 312, cell.best == true, cell.list)
		if not okBuild or not show then
			report("build: " .. tostring(show))
			continue
		end
		local root = show.root
		if cell.game then
			root.Position = CatchShow.placeOf(cell.look)
		elseif root.AnchorPoint.X == 0 then
			root.Position = UDim2.new(0, 14, 0.5, 0)
		elseif root.AnchorPoint.Y == 0 then
			root.Position = UDim2.new(0.5, 0, 0, 12)
		else
			root.Position = UDim2.fromScale(0.5, 0.5)
		end
		table.insert(built, { holder = holder, show = show })
	end
	report("built " .. #built)
end

local timesKey, times = "", {}
RunService.RenderStepped:Connect(function()
	local on = RS:GetAttribute("CatchOn") == true
	gui.Enabled = on
	local hide = on and RS:GetAttribute("CatchHideHud") == true
	for _, g in gui.Parent:GetChildren() do
		if g:IsA("ScreenGui") and g ~= gui then
			if g.Name == "RideHud" then
				-- the HUD stays on for cells in it; only its own pieces are hidden
				local root = g:FindFirstChild("Root")
				if root then
					for _, child in root:GetChildren() do
						if child:IsA("GuiObject") and child.Name ~= "ZZCatchGame" then
							if hide and child.Visible then
								child:SetAttribute("ZZWas", true)
								child.Visible = false
							elseif not hide and child:GetAttribute("ZZWas") then
								child:SetAttribute("ZZWas", nil)
								child.Visible = true
							end
						end
					end
				end
			elseif hide and g.Enabled then
				g:SetAttribute("ZZWas", true)
				g.Enabled = false
			elseif not hide and g:GetAttribute("ZZWas") then
				g:SetAttribute("ZZWas", nil)
				g.Enabled = true
			end
		end
	end
	local json = if on then (RS:GetAttribute("CatchCells") or "[]") else "[]"
	if json ~= key then
		key = json
		rebuild(json)
	end
	local tj = RS:GetAttribute("CatchTimes") or "[]"
	if tj ~= timesKey then
		timesKey = tj
		local okT, got = pcall(HttpService.JSONDecode, HttpService, tj)
		times = if okT then got else {}
	end
	for i, c in built do
		local okPose, err = pcall(c.show.pose, times[i] or 0)
		if not okPose then
			report("pose: " .. tostring(err))
			c.show.pose = function() end
		end
	end
end)
report("up")
