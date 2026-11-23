-- Stand-ins for Roblox's GUI, for building a window offline in Lune (NULLROOM task h2: the Index's panel).
-- Lune's own Instances know every class, property and default but have no events and nothing that runs, so each
-- stand-in here wraps a real Lune Instance: a property set goes through to it (a wrong name or a wrong type is an
-- error, as in Roblox), the tree (Parent, children), the events (Activated ...), attributes and the few things only a
-- running game knows (AbsoluteSize, ViewportSize) are kept here. Nothing is laid out or drawn: `Gui.dump` writes the
-- tree out for tools/index/panel_picture.py, which draws it.
-- usage: local Gui = require("./gui"); local gui = Gui.install(world) (a Harness world); gui.make("Frame")
local roblox = require("@lune/roblox")

local Gui = {}

local EVENTS = {
	Activated = true,
	AncestryChanged = true,
	Changed = true,
	ChildAdded = true,
	ChildRemoved = true,
	Completed = true,
	Destroying = true,
	Event = true,
	Heartbeat = true,
	InputBegan = true,
	InputChanged = true,
	InputEnded = true,
	MouseButton1Click = true,
	MouseButton1Down = true,
	MouseButton1Up = true,
	MouseEnter = true,
	MouseLeave = true,
	RenderStepped = true,
	Stepped = true,
	TouchTap = true,
}

-- What only a running game knows, and a check may set
local LIVE = {
	AbsolutePosition = (roblox :: any).Vector2.new(0, 0),
	AbsoluteSize = (roblox :: any).Vector2.new(100, 100),
	AbsoluteContentSize = (roblox :: any).Vector2.new(0, 0),
	TextBounds = (roblox :: any).Vector2.new(0, 0),
	TextFits = true,
	ViewportSize = (roblox :: any).Vector2.new(1920, 1080),
}

-- An event: Connect, Once, and Fire for the check to raise it
function Gui.signal()
	local signal = { Handlers = {} :: { any } }
	function signal.Connect(self: any, fn: (...any) -> ())
		local link = { Connected = true }
		table.insert(self.Handlers, link)
		link.Fn = fn
		function link.Disconnect(me: any)
			me.Connected = false
			local at = table.find(self.Handlers, me)
			if at then
				table.remove(self.Handlers, at)
			end
		end
		return link
	end
	function signal.Once(self: any, fn: (...any) -> ())
		local link
		link = self:Connect(function(...)
			link:Disconnect()
			fn(...)
		end)
		return link
	end
	function signal.Wait(_self: any)
		error("an offline check cannot wait on an event")
	end
	function signal.Fire(self: any, ...: any)
		for _, link in table.clone(self.Handlers) do
			if link.Connected then
				link.Fn(...)
			end
		end
	end
	return signal
end

local Fake = {}
local METHODS = {}

local function isFake(value: any): boolean
	return type(value) == "table" and getmetatable(value) == Fake
end
Gui.isFake = isFake

local function signalOf(self: any, name: string)
	local signals = rawget(self, "_signals")
	local signal = signals[name]
	if not signal then
		signal = Gui.signal()
		signals[name] = signal
	end
	return signal
end

local function make(class: string)
	return setmetatable({
		_real = roblox.Instance.new(class),
		_class = class,
		_children = {},
		_parent = nil,
		_signals = {},
		_own = {},
		_attributes = {},
		_set = {}, -- every property given a value, in order, for the dump
		_gone = false,
	}, Fake)
end

function Fake.__index(self: any, key: string): any
	local method = METHODS[key]
	if method then
		return method
	end
	if key == "Parent" then
		return rawget(self, "_parent")
	elseif key == "ClassName" then
		return rawget(self, "_class")
	end
	local own = rawget(self, "_own")[key]
	if own ~= nil then
		return own
	end
	if EVENTS[key] then
		return signalOf(self, key)
	end
	local real = rawget(self, "_real")
	local ok, value = pcall(function()
		return real[key]
	end)
	if ok then
		return value
	end
	if LIVE[key] ~= nil then
		return LIVE[key]
	end
	for _, child in rawget(self, "_children") do
		if child.Name == key then
			return child
		end
	end
	error(`{key} is not a valid member of {rawget(self, "_class")} "{real.Name}"`, 2)
end

function Fake.__newindex(self: any, key: string, value: any)
	if key == "Parent" then
		assert(value == nil or isFake(value), "Parent must be an Instance")
		assert(not rawget(self, "_gone") or value == nil, "the Parent of a destroyed Instance is locked")
		local old = rawget(self, "_parent")
		if old == value then
			return
		end
		if old then
			local list = rawget(old, "_children")
			table.remove(list, table.find(list, self) :: number)
		end
		rawset(self, "_parent", value)
		if value then
			table.insert(rawget(value, "_children"), self)
		end
		return
	end
	local real = rawget(self, "_real")
	if isFake(value) or LIVE[key] ~= nil then
		rawget(self, "_own")[key] = value
	else
		local ok, err = pcall(function()
			real[key] = value
		end)
		if not ok then
			local first = string.match(tostring(err), "^[^\n]*") or tostring(err)
			error(`{rawget(self, "_class")} "{real.Name}".{key} = {tostring(value)}: {first}`, 2)
		end
		local set = rawget(self, "_set")
		if not table.find(set, key) then
			table.insert(set, key)
		end
	end
	local signals = rawget(self, "_signals")
	local changed = signals["prop:" .. key]
	if changed then
		changed:Fire()
	end
end

function Fake.__tostring(self: any): string
	return rawget(self, "_real").Name
end

function METHODS.IsA(self: any, class: string): boolean
	return rawget(self, "_real"):IsA(class)
end
function METHODS.GetChildren(self: any): { any }
	return table.clone(rawget(self, "_children"))
end
function METHODS.GetDescendants(self: any): { any }
	local out = {}
	local function walk(at: any)
		for _, child in rawget(at, "_children") do
			table.insert(out, child)
			walk(child)
		end
	end
	walk(self)
	return out
end
function METHODS.FindFirstChild(self: any, name: string, deep: boolean?): any
	for _, child in rawget(self, "_children") do
		if child.Name == name then
			return child
		end
	end
	if deep then
		for _, child in self:GetDescendants() do
			if child.Name == name then
				return child
			end
		end
	end
	return nil
end
function METHODS.WaitForChild(self: any, name: string): any
	return assert(self:FindFirstChild(name), "an offline check cannot wait for " .. name)
end
function METHODS.FindFirstChildOfClass(self: any, class: string): any
	for _, child in rawget(self, "_children") do
		if child.ClassName == class then
			return child
		end
	end
	return nil
end
function METHODS.FindFirstChildWhichIsA(self: any, class: string): any
	for _, child in rawget(self, "_children") do
		if child:IsA(class) then
			return child
		end
	end
	return nil
end
function METHODS.FindFirstAncestorOfClass(self: any, class: string): any
	local at = self.Parent
	while at and at.ClassName ~= class do
		at = at.Parent
	end
	return at
end
function METHODS.FindFirstAncestorWhichIsA(self: any, class: string): any
	local at = self.Parent
	while at and not at:IsA(class) do
		at = at.Parent
	end
	return at
end
function METHODS.IsDescendantOf(self: any, other: any): boolean
	local at = self.Parent
	while at do
		if at == other then
			return true
		end
		at = at.Parent
	end
	return false
end
function METHODS.GetFullName(self: any): string
	local names = {}
	local at = self
	while at do
		table.insert(names, 1, at.Name)
		at = at.Parent
	end
	return table.concat(names, ".")
end
function METHODS.Destroy(self: any)
	for _, child in self:GetChildren() do
		child:Destroy()
	end
	self.Parent = nil
	rawset(self, "_gone", true)
end
function METHODS.ClearAllChildren(self: any)
	for _, child in self:GetChildren() do
		child:Destroy()
	end
end
function METHODS.GetAttribute(self: any, name: string): any
	return rawget(self, "_attributes")[name]
end
function METHODS.SetAttribute(self: any, name: string, value: any)
	local attributes = rawget(self, "_attributes")
	if attributes[name] == value then
		return
	end
	attributes[name] = value
	local changed = rawget(self, "_signals")["attr:" .. name]
	if changed then
		changed:Fire()
	end
end
function METHODS.GetPropertyChangedSignal(self: any, name: string)
	return signalOf(self, "prop:" .. name)
end
function METHODS.GetAttributeChangedSignal(self: any, name: string)
	return signalOf(self, "attr:" .. name)
end
-- (a BindableEvent's)
function METHODS.Fire(self: any, ...: any)
	signalOf(self, "Event"):Fire(...)
end

-- Puts the stand-ins into a Harness world: Instance.new, typeof, TweenInfo, and the services a window touches
-- (Players with a LocalPlayer and its PlayerGui, RunService, TweenService, TextService, UserInputService, Workspace
-- with a camera). Returns { make, player, playerGui, camera, workspace, input }.
function Gui.install(world: any)
	local player = make("Player")
	player.Name = "Tester"
	local playerGui = make("PlayerGui")
	playerGui.Parent = player
	local space = make("Workspace")
	local camera = make("Camera")
	camera.Parent = space
	space.CurrentCamera = camera

	local function new(class: string, parent: any?)
		local object = make(class)
		if parent then
			object.Parent = parent
		end
		return object
	end
	world.globals.Instance = { new = new }
	world.globals.workspace = space
	world.globals.typeof = function(value: any): string
		return if isFake(value) then "Instance" else typeof(value)
	end
	world.globals.TweenInfo = {
		new = function(...: any)
			return { ... }
		end,
	}
	local input = {
		TouchEnabled = false,
		KeyboardEnabled = true,
		MouseEnabled = true,
		GamepadEnabled = false,
		Last = (roblox :: any).Enum.UserInputType.MouseMovement,
		InputBegan = Gui.signal(),
		InputChanged = Gui.signal(),
		InputEnded = Gui.signal(),
		LastInputTypeChanged = Gui.signal(),
	}
	function input.GetLastInputType(self: any)
		return self.Last
	end
	world.services.Workspace = space
	world.services.UserInputService = input
	world.services.Players = { LocalPlayer = player, PlayerAdded = Gui.signal(), PlayerRemoving = Gui.signal() }
	world.services.RunService = {
		Heartbeat = Gui.signal(),
		RenderStepped = Gui.signal(),
		Stepped = Gui.signal(),
		IsStudio = function()
			return false
		end,
		IsClient = function()
			return true
		end,
		IsServer = function()
			return false
		end,
	}
	world.services.TweenService = {
		-- a tween lands at once
		Create = function(_self: any, object: any, _info: any, goals: { [string]: any })
			local tween = { Completed = Gui.signal() }
			function tween.Play(me: any)
				for key, value in goals do
					object[key] = value
				end
				me.Completed:Fire()
			end
			function tween.Cancel() end
			function tween.Destroy() end
			return tween
		end,
	}
	world.services.TextService = {
		-- (a rough width: about half the letter height a letter)
		GetTextSize = function(_self: any, text: string, size: number)
			return (roblox :: any).Vector2.new(#text * size * 0.55, size)
		end,
	}
	return { make = new, player = player, playerGui = playerGui, camera = camera, workspace = space, input = input }
end

----------------------------------------------------------------------------------------------------------------------
-- The tree written out, for the picture

local READ = {
	"Name",
	"Visible",
	"Enabled",
	"ZIndex",
	"LayoutOrder",
	"AnchorPoint",
	"Position",
	"Size",
	"Rotation",
	"BackgroundColor3",
	"BackgroundTransparency",
	"BorderSizePixel",
	"ClipsDescendants",
	"AutomaticSize",
	"Text",
	"TextSize",
	"TextColor3",
	"TextTransparency",
	"TextWrapped",
	"TextScaled",
	"TextXAlignment",
	"TextYAlignment",
	"Font",
	"Image",
	"ImageColor3",
	"ImageTransparency",
	"ImageRectOffset",
	"ImageRectSize",
	"ScaleType",
	"TileSize",
	"CornerRadius",
	"Thickness",
	"Color",
	"Transparency",
	"ApplyStrokeMode",
	"Scale",
	"Offset",
	"FillDirection",
	"HorizontalAlignment",
	"VerticalAlignment",
	"Padding",
	"SortOrder",
	"CellSize",
	"CellPadding",
	"FillDirectionMaxCells",
	"PaddingLeft",
	"PaddingRight",
	"PaddingTop",
	"PaddingBottom",
	"CanvasPosition",
	"ScrollBarThickness",
	"IgnoreGuiInset",
	"DisplayOrder",
}

local function plain(value: any): any
	local kind = typeof(value)
	if kind == "string" or kind == "number" or kind == "boolean" then
		return value
	elseif kind == "Vector2" then
		return { value.X, value.Y }
	elseif kind == "UDim" then
		return { value.Scale, value.Offset }
	elseif kind == "UDim2" then
		return { value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset }
	elseif kind == "Color3" then
		return { math.round(value.R * 255), math.round(value.G * 255), math.round(value.B * 255) }
	elseif kind == "EnumItem" then
		return value.Name
	elseif kind == "ColorSequence" then
		local points = {}
		for _, point in value.Keypoints do
			table.insert(points, { point.Time, plain(point.Value) })
		end
		return points
	elseif kind == "NumberSequence" then
		local points = {}
		for _, point in value.Keypoints do
			table.insert(points, { point.Time, point.Value })
		end
		return points
	end
	return nil
end

-- A stand-in and everything under it as plain tables: { Class, Props, Attributes, Children }
function Gui.dump(object: any): any
	local props = {}
	local real = rawget(object, "_real")
	for _, key in READ do
		local ok, value = pcall(function()
			return real[key]
		end)
		if ok and value ~= nil then
			props[key] = plain(value)
		end
	end
	local children = {}
	for _, child in rawget(object, "_children") do
		table.insert(children, Gui.dump(child))
	end
	return {
		Class = object.ClassName,
		Props = props,
		Attributes = table.clone(rawget(object, "_attributes")),
		Children = children,
	}
end

return Gui
