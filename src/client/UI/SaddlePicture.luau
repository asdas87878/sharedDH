--!strict
-- A saddle as a picture (NULLROOM task s2): its own parts (Shared/Saddles) in a ViewportFrame, seen from the rider's
-- left and a little over it. Nothing to upload; it never moves, so it costs a drawing only when it changes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Saddles = require(ReplicatedStorage.Shared.Saddles)
local Kit = require(script.Parent.Kit)

local SaddlePicture = {}

export type Picture = {
	Frame: GuiObject,
	show: (key: string?) -> boolean, -- a design's key; nil or an unknown one: empty, and false
}

local SHAPES = {
	box = Enum.PartType.Block,
	wedge = Enum.PartType.Wedge,
	cylinder = Enum.PartType.Cylinder,
	ball = Enum.PartType.Ball,
}
local LOOK = Vector3.new(5.2, 4.6, 8.2).Unit -- from the saddle toward the eye
local FOV = 30

-- props: the frame's own (Position, Size, ZIndex ...)
function SaddlePicture.new(parent: Instance, props: { [string]: any }): Picture
	props.BackgroundTransparency = 1
	local view: ViewportFrame = Kit.new("ViewportFrame", props, parent)
	view.Ambient = Color3.fromRGB(168, 172, 184)
	view.LightColor = Color3.fromRGB(255, 250, 238)
	view.LightDirection = Vector3.new(-0.6, -1, -0.45)
	local camera = Instance.new("Camera")
	camera.FieldOfView = FOV
	camera.Parent = view
	view.CurrentCamera = camera
	local shown: string? = nil
	local held: { BasePart } = {}

	local function show(key: string?): boolean
		local parts: { Saddles.Part }? = if key then Saddles.alone(key) else nil
		if key ~= shown then
			shown = key
			view:SetAttribute("Saddle", key or "") -- (for checks, and the offline pictures)
			for _, part in held do
				part:Destroy()
			end
			table.clear(held)
			-- how far the parts reach to the sides, and up and down, as the eye sees them
			local eye = CFrame.lookAt(LOOK, Vector3.zero)
			local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
			for _, entry in (parts or {}) :: { Saddles.Part } do
				local part = Instance.new("Part")
				part.Shape = SHAPES[entry.Shape]
				part.Size = entry.Size
				part.CFrame = entry.At
				part.Color = entry.Colour
				part.Material = if entry.Neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
				part.Anchored = true
				part.CastShadow = false
				part.Parent = view
				table.insert(held, part)
				local at = eye:ToObjectSpace(entry.At)
				local x, y, z =
					at.XVector * entry.Size.X / 2, at.YVector * entry.Size.Y / 2, at.ZVector * entry.Size.Z / 2
				local reach = Vector3.new(
					math.abs(x.X) + math.abs(y.X) + math.abs(z.X),
					math.abs(x.Y) + math.abs(y.Y) + math.abs(z.Y),
					math.abs(x.Z) + math.abs(y.Z) + math.abs(z.Z)
				)
				lo, hi = lo:Min(at.Position - reach), hi:Max(at.Position + reach)
			end
			if #held > 0 then
				local middle = (lo + hi) / 2
				local size = view.Size
				-- (the frame's own shape, where it is given in points; else as if square)
				local wide = if size.X.Offset > 0 and size.Y.Offset > 0 then size.X.Offset / size.Y.Offset else 1
				local half = math.max((hi.Y - lo.Y) / 2, (hi.X - lo.X) / 2 / wide)
				local back = half / math.tan(math.rad(FOV / 2)) + (hi.Z - lo.Z) / 2
				camera.CFrame = eye * CFrame.new(middle) * CFrame.new(0, 0, back)
			end
		end
		return parts ~= nil
	end
	return { Frame = view, show = show }
end

return SaddlePicture
