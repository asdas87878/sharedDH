-- The hub's signs in three styles, for pictures to pick from (docs/design/ui.md, "The hub's signs: options",
-- 2026-11-16). Run in Studio's Edit mode with STYLE "A", "B" or "C"; "" takes it all away again and shows the
-- place's own station names. It builds only stand-ins in Workspace.UiOptions and "UiMock" signs on the tank boards:
-- nothing of the map's is changed but the old names' Enabled, which "" puts back. Never saved with the place.
local STYLE = "A"

local INK = Color3.fromRGB(16, 36, 63)
local DEEP = Color3.fromRGB(10, 24, 44)
local WHITE = Color3.new(1, 1, 1)
local STUDS = "rbxassetid://124244361010023" -- the map's stud tile, uploaded long ago

local dock = workspace.ClaudeBlockout.Dock
local old = workspace:FindFirstChild("UiOptions")
if old then
	old:Destroy()
end
for _, d in dock.Plots:GetDescendants() do
	if d.Name == "UiMock" then
		d:Destroy()
	end
end
for _, s in dock.Stations:GetChildren() do
	local title = s:FindFirstChild("Title")
	local gui = title and title:FindFirstChild("Name")
	if gui and gui:IsA("BillboardGui") then
		gui.Enabled = STYLE == ""
	end
end
if STYLE == "" then
	return "restored"
end

local folder = Instance.new("Folder")
folder.Name = "UiOptions"
folder.Parent = workspace

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function lighter(c, a)
	return c:Lerp(WHITE, a)
end
local function darker(c, a)
	return c:Lerp(Color3.new(0, 0, 0), a)
end
local function words(parent, text, font, colour, pos, size, edge)
	local label = new("TextLabel", {
		BackgroundTransparency = 1,
		Position = pos,
		Size = size,
		Font = font,
		Text = text,
		TextColor3 = colour,
		TextScaled = true,
		ZIndex = 3,
	}, parent)
	new("UIStroke", { Thickness = edge, Color = INK, LineJoinMode = Enum.LineJoinMode.Round }, label)
	return label
end

-- One sign's face, on a frame that fills its gui: title, a small line under it, the thing's own colour
local function face(root, title, sub, colour)
	if STYLE == "A" then
		-- the HUD's panel: dark blue, a little see-through, a darker copy under it, studs on the header only
		local shadow = new(
			"Frame",
			{
				Position = UDim2.fromScale(0, 0.08),
				Size = UDim2.fromScale(1, 0.92),
				BackgroundColor3 = darker(DEEP, 0.5),
				BackgroundTransparency = 0.25,
				BorderSizePixel = 0,
			},
			root
		)
		new("UICorner", { CornerRadius = UDim.new(0.16, 0) }, shadow)
		local plate = new(
			"Frame",
			{
				Size = UDim2.fromScale(1, 0.92),
				BackgroundColor3 = DEEP,
				BackgroundTransparency = 0.12,
				BorderSizePixel = 0,
				ZIndex = 2,
			},
			root
		)
		new("UICorner", { CornerRadius = UDim.new(0.16, 0) }, plate)
		new("UIStroke", { Thickness = 3, Color = INK }, plate)
		local head = new(
			"Frame",
			{
				Position = UDim2.fromScale(0.03, 0.06),
				Size = UDim2.fromScale(0.94, 0.2),
				BackgroundColor3 = colour,
				BorderSizePixel = 0,
				ZIndex = 2,
			},
			plate
		)
		new("UICorner", { CornerRadius = UDim.new(0.4, 0) }, head)
		new("UIGradient", { Color = ColorSequence.new(lighter(colour, 0.25), colour), Rotation = 90 }, head)
		new(
			"ImageLabel",
			{
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image = STUDS,
				ImageTransparency = 0.55,
				ScaleType = Enum.ScaleType.Tile,
				TileSize = UDim2.fromScale(0.09, 1),
				ZIndex = 2,
			},
			head
		)
		words(
			plate,
			title,
			Enum.Font.FredokaOne,
			WHITE,
			UDim2.fromScale(0.06, 0.29),
			UDim2.fromScale(0.88, if sub ~= "" then 0.42 else 0.62),
			2.5
		)
		if sub ~= "" then
			words(
				plate,
				sub,
				Enum.Font.FredokaOne,
				lighter(colour, 0.55),
				UDim2.fromScale(0.06, 0.72),
				UDim2.fromScale(0.88, 0.2),
				1.5
			)
		end
	elseif STYLE == "B" then
		-- the gate's sign everywhere: white Luckiest Guy on a board in the thing's own colour, a white rim
		local shadow = new(
			"Frame",
			{
				Position = UDim2.fromScale(0, 0.08),
				Size = UDim2.fromScale(1, 0.92),
				BackgroundColor3 = darker(colour, 0.6),
				BorderSizePixel = 0,
			},
			root
		)
		new("UICorner", { CornerRadius = UDim.new(0.1, 0) }, shadow)
		local board = new(
			"Frame",
			{ Size = UDim2.fromScale(1, 0.92), BackgroundColor3 = colour, BorderSizePixel = 0, ZIndex = 2 },
			root
		)
		new("UICorner", { CornerRadius = UDim.new(0.1, 0) }, board)
		new("UIStroke", { Thickness = 4, Color = WHITE }, board)
		new(
			"UIGradient",
			{ Color = ColorSequence.new(lighter(colour, 0.18), darker(colour, 0.12)), Rotation = 90 },
			board
		)
		words(
			board,
			title,
			Enum.Font.LuckiestGuy,
			WHITE,
			UDim2.fromScale(0.06, if sub ~= "" then 0.1 else 0.16),
			UDim2.fromScale(0.88, if sub ~= "" then 0.56 else 0.7),
			3
		)
		if sub ~= "" then
			words(
				board,
				sub,
				Enum.Font.LuckiestGuy,
				lighter(colour, 0.8),
				UDim2.fromScale(0.06, 0.7),
				UDim2.fromScale(0.88, 0.2),
				1.5
			)
		end
	else
		-- words like the fish tags: no plate, Gotham Black in the thing's colour, lighter at the top, a thick dark edge
		local label = words(
			root,
			title,
			Enum.Font.GothamBlack,
			WHITE,
			UDim2.fromScale(0, 0.02),
			UDim2.fromScale(1, if sub ~= "" then 0.66 else 0.9),
			3.5
		)
		new(
			"UIGradient",
			{ Color = ColorSequence.new(lighter(colour, 0.7), lighter(colour, 0.1)), Rotation = 90 },
			label
		)
		if sub ~= "" then
			words(root, sub, Enum.Font.FredokaOne, WHITE, UDim2.fromScale(0, 0.7), UDim2.fromScale(1, 0.26), 2)
		end
	end
end

local function floating(part, lift, wide, high, far, title, sub, colour)
	local gui = new("BillboardGui", {
		Name = title,
		Adornee = part,
		Size = UDim2.fromScale(wide, high), -- in studs: it keeps its size in the world, so far ones are small
		StudsOffsetWorldSpace = Vector3.new(0, lift, 0),
		MaxDistance = far,
		LightInfluence = 0,
	}, folder)
	face(new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui), title, sub, colour)
end

-- the stations: each name over its own stall, letters about 5 studs tall as the old names had. Three stations stand
-- one behind the other as seen from the spawn (Auras, the submarine, the Index), so the further ones sit higher;
-- only moving a station would part them for good (the map's, not the signs')
local STATIONS = {
	Sell = { "SELL", "fish for coins", Color3.fromRGB(232, 62, 62), -6 },
	Fuse = { "FUSE", "two fish into one", Color3.fromRGB(58, 112, 224), -6 },
	Auras = { "AURAS", "ride for longer", Color3.fromRGB(186, 72, 232), -6 },
	Sub = { "SUBMARINE", "skip to a deeper land", Color3.fromRGB(34, 168, 196), 12 },
	Index = { "INDEX", "every fish you have met", Color3.fromRGB(240, 164, 36), 4 },
}
for name, s in STATIONS do
	local station = dock.Stations:FindFirstChild(name)
	local title = station and station:FindFirstChild("Title")
	if title then
		floating(title, s[4], 30, 11, 420, s[1], s[2], s[3])
	end
end

-- the trainer: named on your own plot only, above the model, with what it gives
local mine = dock.Plots:FindFirstChild("Plot2")
local spot = mine and mine:FindFirstChild("TrainerSpot")
if spot then
	floating(spot, 21, 17, 6.4, 220, "TRAIN", "stand on it: more Oxygen", Color3.fromRGB(51, 200, 240))
end

-- the tanks' signs: yours says so
for _, plot in dock.Plots:GetChildren() do
	local board = plot:FindFirstChild("SignBoard")
	if board then
		local own = plot.Name == "Plot2"
		for _, side in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local gui = new(
				"SurfaceGui",
				{
					Name = "UiMock",
					Face = side,
					SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
					PixelsPerStud = 24,
					LightInfluence = 0,
				},
				board
			)
			local root = new(
				"Frame",
				{
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = if STYLE == "B"
						then Color3.fromRGB(30, 140, 255)
						elseif STYLE == "A" then DEEP
						else Color3.fromRGB(24, 32, 52),
					BorderSizePixel = 0,
				},
				gui
			)
			local font = if STYLE == "A"
				then Enum.Font.FredokaOne
				elseif STYLE == "B" then Enum.Font.LuckiestGuy
				else Enum.Font.GothamBlack
			if own then
				local band = new(
					"Frame",
					{
						Size = UDim2.fromScale(1, 0.3),
						BackgroundColor3 = if STYLE == "B" then WHITE else Color3.fromRGB(255, 200, 50),
						BorderSizePixel = 0,
					},
					root
				)
				if STYLE == "A" then
					new(
						"ImageLabel",
						{
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							Image = STUDS,
							ImageTransparency = 0.55,
							ScaleType = Enum.ScaleType.Tile,
							TileSize = UDim2.fromScale(0.05, 1),
						},
						band
					)
				end
				new(
					"TextLabel",
					{
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
						Font = font,
						Text = "YOUR TANK",
						TextScaled = true,
						TextColor3 = if STYLE == "B" then Color3.fromRGB(30, 140, 255) else INK,
						ZIndex = 2,
					},
					band
				)
				new(
					"TextLabel",
					{
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.03, 0.33),
						Size = UDim2.fromScale(0.94, 0.64),
						Font = font,
						Text = "$4.4 a second",
						TextScaled = true,
						TextColor3 = WHITE,
					},
					root
				)
			else
				new(
					"TextLabel",
					{
						BackgroundTransparency = 0.999,
						Position = UDim2.fromScale(0.05, 0.2),
						Size = UDim2.fromScale(0.9, 0.6),
						Font = font,
						Text = "FREE TANK",
						TextScaled = true,
						TextColor3 = WHITE,
						TextTransparency = 0.35,
					},
					root
				)
			end
		end
	end
end
return "built " .. STYLE
