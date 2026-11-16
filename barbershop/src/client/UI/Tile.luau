--!strict
-- Kafelek w stylu referencji: kolorowa ściana z teksturą wytłoczonych kwadratów, gruby czarny obrys,
-- ciemniejszy spód (wciska się przy kliknięciu), opcjonalna poświata i napis wystający z dolnej krawędzi.

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
	-- Tekstura kwadratów; wyłączana w krótkotrwałych elementach (komunikaty), bo to sporo ramek.
	Pattern: boolean?,
	Glow: Color3?,
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

-- Tekstura z przycisku Rebirth: siatka zaokrąglonych, lekko wypukłych kwadratów
-- (jasna płytka + cień przesunięty w prawo-dół). `size` to rozmiar rodzica w pikselach projektu.
function Tile.pattern(parent: Instance, size: Vector2, cell: number, inset: number): Frame
	local area = size - Vector2.new(inset * 2, inset * 2)
	local holder = create("Frame", {
		Name = "Pattern",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(inset, inset),
		Size = UDim2.fromOffset(area.X, area.Y),
		ClipsDescendants = true,
		Parent = parent,
	})
	local square = math.floor(cell * 0.64)
	local cols = math.ceil(area.X / cell)
	local rows = math.ceil(area.Y / cell)
	-- Siatka wyśrodkowana, żeby brzegi były symetryczne.
	local ox = (area.X - cols * cell) / 2 + (cell - square) / 2
	local oy = (area.Y - rows * cell) / 2 + (cell - square) / 2
	local radius = UDim.new(0, math.max(2, math.floor(square * 0.22)))
	local shift = math.max(1, math.floor(square * 0.12))
	for r = 0, rows - 1 do
		for c = 0, cols - 1 do
			local x, y = ox + c * cell, oy + r * cell
			create("Frame", {
				Name = "Shade",
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.85,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(x + shift, y + shift),
				Size = UDim2.fromOffset(square, square),
				Parent = holder,
			}, { create("UICorner", { CornerRadius = radius }) })
			create("Frame", {
				Name = "Plate",
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.78,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(x, y),
				Size = UDim2.fromOffset(square, square),
				Parent = holder,
			}, { create("UICorner", { CornerRadius = radius }) })
		end
	end
	return holder
end

-- Miękka poświata z kilku półprzezroczystych warstw za kafelkiem.
local function glow(parent: Instance, size: Vector2, color: Color3, corner: number)
	for i, transparency in { 0.55, 0.75, 0.88 } do
		local grow = i * 7
		create("Frame", {
			Name = "Glow",
			BackgroundColor3 = color,
			BackgroundTransparency = transparency,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(-grow, -grow),
			Size = UDim2.fromOffset(size.X + grow * 2, size.Y + grow * 2),
			ZIndex = 0,
			Parent = parent,
		}, { Util.corner(corner + grow) })
	end
end

function Tile.new(p: TileProps): Tile
	local size = p.Size
	local depth = p.Depth or math.max(4, math.floor(size.Y * 0.08))
	local corner = p.Corner or math.max(6, math.floor(size.Y * 0.12))
	local outline = math.max(3, math.floor(size.Y * 0.045 + 0.5))
	local palette = p.Palette
	local enabled = true

	local root: Frame = create("Frame", {
		Name = p.Name or "Tile",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size.X, size.Y + depth),
		Position = p.Position or UDim2.new(),
		AnchorPoint = p.AnchorPoint or Vector2.zero,
		LayoutOrder = p.Order or 0,
		Parent = p.Parent,
	})
	local scale = create("UIScale", { Parent = root })

	if p.Glow then
		glow(root, Vector2.new(size.X, size.Y + depth), p.Glow, corner)
	end

	local shadow = create("Frame", {
		Name = "Shadow",
		BackgroundColor3 = palette.shadow,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, depth),
		Size = UDim2.fromOffset(size.X, size.Y),
		ZIndex = 1,
		Parent = root,
	}, { Util.corner(corner), Util.stroke(outline) })

	local gradient = Util.gradient(palette.top, palette.bottom) :: UIGradient
	local face: TextButton = create("TextButton", {
		Name = "Face",
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(size.X, size.Y),
		ZIndex = 2,
		Parent = root,
	}, { Util.corner(corner), Util.stroke(outline), gradient })

	if p.Pattern ~= false then
		Tile.pattern(face, size, math.max(16, math.floor(math.min(size.X, size.Y) / 5)), 3)
	end

	-- Jaśniejszy pasek u góry daje wrażenie wypukłości.
	create("Frame", {
		Name = "Shine",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(corner * 0.6, 3),
		Size = UDim2.new(1, -corner * 1.2, 0, math.max(3, math.floor(size.Y * 0.05))),
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
			TextSize = p.LabelSize or math.floor(size.Y * 0.3),
			Position = UDim2.new(0.5, 0, 1, -math.floor(size.Y * 0.04)),
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

	return {
		root = root,
		face = face,
		label = label,
		text = text,
		setPalette = function(next: Theme.Palette)
			palette = next
			shadow.BackgroundColor3 = next.shadow
			gradient.Color = ColorSequence.new(next.top, next.bottom)
		end,
		setEnabled = function(value: boolean)
			enabled = value
			face.Active = value
		end,
	}
end

return Tile
