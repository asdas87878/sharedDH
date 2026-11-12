--!strict
-- A creature's picture, as the reference has in its slots and on its catch banner. Ours is the creature's own model
-- drawn in a small window (a ViewportFrame), so no picture is uploaded: the model comes from
-- ReplicatedStorage.FishModels (or .Creatures) when it is there, else from a fish of that kind swimming in the world
-- (the one just tamed always is). A kind's model is copied and cleaned once and kept; a window gets a copy of that
-- when its creature changes, never per frame. A window that is not changing costs nothing to draw.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Kit)

local Portrait = {}

export type Portrait = {
	Frame: ViewportFrame,
	show: (id: string?) -> boolean, -- false when that creature has no model to draw yet
}

local FOV = 22
-- from in front and a little above, the head to the left (a creature's head is toward -Z)
local FROM = Vector3.new(-1, 0.3, -0.55).Unit

local masters: { [string]: Model } = {}
local views: { [string]: CFrame } = {}

local function find(id: string): Model?
	local kind = Config.FishById[id]
	for _, folderName in { "FishModels", "Creatures" } do
		local folder = ReplicatedStorage:FindFirstChild(folderName)
		if folder then
			local found = folder:FindFirstChild(id) or (kind and folder:FindFirstChild(kind.Name))
			if found and found:IsA("Model") then
				return found
			end
		end
	end
	local wild = workspace:FindFirstChild("Fish")
	if wild then
		for _, fish in wild:GetChildren() do
			if fish:IsA("Model") and fish:GetAttribute("FishType") == id then
				return fish
			end
		end
	end
	return nil
end

-- The kept copy of a kind: only what draws (parts, their meshes and textures), set at the middle, unturned
local function master(id: string): Model?
	local kept = masters[id]
	if kept then
		return kept
	end
	local source = find(id)
	if not source then
		return nil
	end
	local was = source.Archivable
	source.Archivable = true
	local copy = source:Clone()
	source.Archivable = was
	if not copy then
		return nil
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		elseif
			not (
				d:IsA("DataModelMesh")
				or d:IsA("Decal")
				or d:IsA("SurfaceAppearance")
				or d:IsA("Model")
				or d:IsA("Folder")
			)
		then
			d:Destroy()
		end
	end
	copy:PivotTo(CFrame.new())
	local box, size = copy:GetBoundingBox()
	local centre = box.Position
	-- far enough back that the whole creature is in the window
	local distance = (size.Magnitude / 2) / math.tan(math.rad(FOV / 2)) * 0.9
	views[id] = CFrame.lookAt(centre + FROM * distance, centre)
	masters[id] = copy
	return copy
end

function Portrait.new(parent: Instance, props: { [string]: any }): Portrait
	props.BackgroundTransparency = 1
	props.Ambient = Color3.fromRGB(190, 195, 205)
	props.LightColor = Color3.fromRGB(255, 255, 255)
	props.LightDirection = Vector3.new(0.5, -1, 0.4)
	local frame: ViewportFrame = Kit.new("ViewportFrame", props, parent)
	local camera: Camera = Kit.new("Camera", { FieldOfView = FOV }, frame)
	frame.CurrentCamera = camera

	local shownId: string? = nil
	local shown: Model? = nil
	local function show(id: string?): boolean
		if id == shownId then
			return true
		end
		if shown then
			shown:Destroy()
			shown = nil
		end
		shownId = nil
		if not id then
			return true
		end
		local source = master(id)
		if not source then
			return false -- (not remembered: the next call looks again)
		end
		local copy = source:Clone()
		copy.Parent = frame
		camera.CFrame = views[id]
		shown = copy
		shownId = id
		return true
	end
	return { Frame = frame, show = show }
end

return Portrait
