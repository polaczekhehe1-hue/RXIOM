--!strict
-- Budowanie z klocków. Wszystko jest zakotwiczone, a większe płaskie elementy dostają klasyczne studsy.

export type PartProps = {
	Name: string?,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3,
	Parent: Instance,
	Material: Enum.Material?,
	Shape: Enum.PartType?,
	Transparency: number?,
	Reflectance: number?,
	CanCollide: boolean?,
	CastShadow: boolean?,
	Studs: boolean?,
}

local Blocks = {}

function Blocks.part(p: PartProps): Part
	local part = Instance.new("Part")
	part.Name = p.Name or "Block"
	part.Anchored = true
	if p.Shape then
		part.Shape = p.Shape
	end
	part.Size = p.Size
	part.CFrame = p.CFrame
	part.Color = p.Color
	local studs = if p.Studs == nil then p.Shape == nil and p.Size.X >= 1 and p.Size.Z >= 1 else p.Studs
	-- Powierzchnie Studs są wyraźnie widoczne tylko na zwykłym Plastic (na SmoothPlastic prawie znikają).
	part.Material = p.Material or (if studs then Enum.Material.Plastic else Enum.Material.SmoothPlastic)
	part.Transparency = p.Transparency or 0
	part.Reflectance = p.Reflectance or 0
	part.CanCollide = if p.CanCollide == nil then true else p.CanCollide
	part.CastShadow = if p.CastShadow == nil then true else p.CastShadow
	part.TopSurface = if studs then Enum.SurfaceType.Studs else Enum.SurfaceType.Smooth
	part.BottomSurface = if studs then Enum.SurfaceType.Inlet else Enum.SurfaceType.Smooth
	part.Parent = p.Parent
	return part
end

-- Pionowy walec (Roblox trzyma oś walca w X, więc obracamy go o 90°).
function Blocks.cylinder(name: string, height: number, diameter: number, cf: CFrame, color: Color3, parent: Instance, material: Enum.Material?): Part
	return Blocks.part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = cf * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Material = material,
		Parent = parent,
	})
end

function Blocks.model(name: string, parent: Instance?): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

function Blocks.folder(name: string, parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

-- Lekko losowy odcień, żeby wokselowe powierzchnie nie były płaskie.
function Blocks.jitter(color: Color3, amount: number, rng: Random): Color3
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, s, math.clamp(v + rng:NextNumber(-amount, amount), 0, 1))
end

-- Napis na ścianie części, np. szyld.
function Blocks.label(part: BasePart, face: Enum.NormalId, text: string, color: Color3, font: Font): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Label"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.3
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = font
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.12, 0)
	padding.PaddingBottom = UDim.new(0.12, 0)
	padding.PaddingLeft = UDim.new(0.04, 0)
	padding.PaddingRight = UDim.new(0.04, 0)
	padding.Parent = label
	return label
end

Blocks.Font = Font.new("rbxasset://fonts/families/FredokaOne.json")

return Blocks
