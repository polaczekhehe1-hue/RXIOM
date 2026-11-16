--!strict
-- Kafelek w stylu referencji: kolorowa ściana z cegiełkami, gruby czarny obrys,
-- ciemniejszy spód pod spodem (wciska się przy kliknięciu) i napis wystający z dolnej krawędzi.

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local create = Util.create

export type TileProps = {
	Name: string?,
	Size: Vector2,
	Palette: Theme.Palette,
	Label: string?,
	LabelSize: number?,
	Icon: ((container: Frame) -> ())?,
	IconScale: number?,
	Text: string?,
	TextSize: number?,
	Corner: number?,
	Depth: number?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Order: number?,
	Parent: Instance?,
	OnClick: (() -> ())?,
}

export type Tile = {
	root: Frame,
	face: TextButton,
	label: TextLabel?,
	text: TextLabel?,
	setPalette: (palette: Theme.Palette) -> (),
	setEnabled: (enabled: boolean) -> (),
}

local Tile = {}

-- Faktura cegieł: poziome fugi co wiersz i przesunięte pionowe spoiny.
function Tile.bricks(parent: Instance, color: Color3, rows: number, inset: number): Frame
	local holder = create("Frame", {
		Name = "Bricks",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(inset, inset),
		Size = UDim2.new(1, -inset * 2, 1, -inset * 2),
		ClipsDescendants = true,
		Parent = parent,
	})
	local h = 1 / rows
	for r = 0, rows - 1 do
		if r > 0 then
			create("Frame", {
				Name = "Joint",
				BackgroundColor3 = color,
				BackgroundTransparency = 0.45,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0, r * h),
				Size = UDim2.new(1, 0, 0, 2),
				Parent = holder,
			})
		end
		local joints: { number } = if r % 2 == 0 then { 0.22, 0.78 } else { 0.08, 0.5, 0.92 }
		for _, x in joints do
			create("Frame", {
				Name = "Joint",
				BackgroundColor3 = color,
				BackgroundTransparency = 0.45,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(x, r * h),
				Size = UDim2.new(0, 2, h, 0),
				Parent = holder,
			})
		end
	end
	return holder
end

function Tile.new(p: TileProps): Tile
	local depth = p.Depth or math.max(4, math.floor(p.Size.Y * 0.07))
	local corner = p.Corner or math.max(6, math.floor(p.Size.Y * 0.08))
	local palette = p.Palette
	local enabled = true

	local root: Frame = create("Frame", {
		Name = p.Name or "Tile",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(p.Size.X, p.Size.Y + depth),
		Position = p.Position or UDim2.new(),
		AnchorPoint = p.AnchorPoint or Vector2.zero,
		LayoutOrder = p.Order or 0,
		Parent = p.Parent,
	})
	local scale = create("UIScale", { Parent = root })

	local shadow = create("Frame", {
		Name = "Shadow",
		BackgroundColor3 = palette.shadow,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, depth),
		Size = UDim2.fromOffset(p.Size.X, p.Size.Y),
		Parent = root,
	}, { Util.corner(corner), Util.stroke() })

	local gradient = Util.gradient(palette.top, palette.bottom) :: UIGradient
	local face: TextButton = create("TextButton", {
		Name = "Face",
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(p.Size.X, p.Size.Y),
		ZIndex = 2,
		Parent = root,
	}, { Util.corner(corner), Util.stroke(), gradient })
	local bricks = Tile.bricks(face, palette.brick, math.max(3, math.floor(p.Size.Y / 18)), 4)

	-- Jaśniejszy pasek u góry daje wrażenie wypukłości.
	local shine = create("Frame", {
		Name = "Shine",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.75,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(5, 4),
		Size = UDim2.new(1, -10, 0, math.max(3, math.floor(p.Size.Y * 0.06))),
		Parent = face,
	}, { Util.round() })

	if p.Icon then
		local s = p.IconScale or 0.78
		local container = create("Frame", {
			Name = "Icon",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, if p.Label then 0.44 else 0.5),
			Size = UDim2.fromScale(s, s),
			Parent = face,
		}, { create("UIAspectRatioConstraint", { AspectRatio = 1 }) })
		p.Icon(container)
	end

	local text: TextLabel? = nil
	if p.Text then
		text = Util.label({
			Text = p.Text,
			TextSize = p.TextSize or 28,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 3,
			Parent = face,
		})
	end

	local label: TextLabel? = nil
	if p.Label then
		label = Util.label({
			Text = p.Label,
			TextSize = p.LabelSize or math.floor(p.Size.Y * 0.3),
			Position = UDim2.new(0.5, 0, 1, -math.floor(p.Size.Y * 0.04)),
			AnchorPoint = Vector2.new(0.5, 0.55),
			ZIndex = 5,
			Stroke = 3.5,
			Parent = face,
		})
	end

	local function setPressed(pressed: boolean)
		Util.tween(face, Util.Quick, { Position = UDim2.fromOffset(0, if pressed then depth * 0.7 else 0) })
	end

	face.MouseEnter:Connect(function()
		if enabled then
			Util.tween(scale, Util.Quick, { Scale = 1.06 })
		end
	end)
	face.MouseLeave:Connect(function()
		Util.tween(scale, Util.Quick, { Scale = 1 })
		setPressed(false)
	end)
	face.MouseButton1Down:Connect(function()
		if enabled then
			setPressed(true)
		end
	end)
	face.MouseButton1Up:Connect(function()
		setPressed(false)
	end)
	face.Activated:Connect(function()
		if enabled and p.OnClick then
			p.OnClick()
		end
	end)

	local tile: Tile = {
		root = root,
		face = face,
		label = label,
		text = text,
		setPalette = function(next: Theme.Palette)
			palette = next
			shadow.BackgroundColor3 = next.shadow
			gradient.Color = ColorSequence.new(next.top, next.bottom)
			for _, joint in bricks:GetChildren() do
				(joint :: Frame).BackgroundColor3 = next.brick
			end
		end,
		setEnabled = function(value: boolean)
			enabled = value
			face.Active = value
		end,
	}
	shine.Visible = true
	return tile
end

return Tile
