--!strict
-- Proste ikony rysowane z ramek, żeby nie zależeć od wgrywanych assetów.

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local create = Util.create
local Colors = Theme.Colors

local Icons = {}

local function bar(parent: Instance, center: Vector2, length: number, thickness: number, angle: number, color: Color3)
	create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(center.X, center.Y),
		Size = UDim2.fromOffset(length, thickness),
		Rotation = angle,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = parent,
	})
end

local function box(name: string, size: number, order: number?): Frame
	return create("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		LayoutOrder = order or 0,
	})
end

-- Logo RXIOM: trójkąt jak w logo Axiom.
function Icons.logo(size: number, order: number?): Frame
	local frame = box("LogoIcon", size, order)
	local t = math.max(3, size * 0.14)
	local side = size * 1.0
	local h = side * math.sqrt(3) / 2
	local top = (size - h) / 2
	local left = Vector2.new(0, top + h)
	local right = Vector2.new(side, top + h)
	local apex = Vector2.new(side / 2, top)
	bar(frame, (left + apex) / 2, side, t, -60, Colors.Text)
	bar(frame, (right + apex) / 2, side, t, 60, Colors.Text)
	bar(frame, Vector2.new(side / 2, top + h - t / 2), side, t, 0, Colors.Text)
	return frame
end

function Icons.chevronDown(size: number, color: Color3, order: number?): Frame
	local frame = box("Chevron", size, order)
	local len = size * 0.55
	local t = math.max(2, size * 0.16)
	local cy = size * 0.55
	bar(frame, Vector2.new(size * 0.5 - len * 0.35, cy - len * 0.1), len, t, 45, color)
	bar(frame, Vector2.new(size * 0.5 + len * 0.35, cy - len * 0.1), len, t, -45, color)
	return frame
end

function Icons.search(size: number, color: Color3, order: number?): Frame
	local frame = box("SearchIcon", size, order)
	local r = size * 0.62
	create("Frame", {
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(r, r),
		BackgroundTransparency = 1,
		Parent = frame,
	}, { Util.round(), Util.stroke(color, 2) })
	bar(frame, Vector2.new(size * 0.74, size * 0.74), size * 0.38, 2, 45, color)
	return frame
end

function Icons.star(size: number, color: Color3, order: number?): Frame
	local frame = box("StarIcon", size, order)
	local c = Vector2.new(size / 2, size * 0.54)
	local vertices = {}
	for i = 0, 4 do
		local rad = math.rad(i * 72 - 90)
		vertices[i] = c + Vector2.new(math.cos(rad), math.sin(rad)) * size * 0.48
	end
	-- Pentagram: każdy wierzchołek łączony z co drugim.
	for i = 0, 4 do
		local a, b = vertices[i], vertices[(i + 2) % 5]
		local d = b - a
		bar(frame, (a + b) / 2, d.Magnitude, 2, math.deg(math.atan2(d.Y, d.X)), color)
	end
	return frame
end

-- Ikona waluty w grze (odpowiednik logo SOL).
function Icons.currency(size: number, order: number?): Frame
	local frame = box("CurrencyIcon", size, order)
	local t = math.max(2, math.floor(size * 0.18))
	for i = 0, 2 do
		local y = size * (0.22 + i * 0.28)
		local b = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(size / 2, y),
			Size = UDim2.fromOffset(size * 0.9, t),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Parent = frame,
		})
		create("UIGradient", {
			Color = ColorSequence.new(Color3.fromHex("9945FF"), Color3.fromHex("14F195")),
			Parent = b,
		})
	end
	return frame
end

function Icons.dot(size: number, color: Color3, order: number?): Frame
	return create("Frame", {
		Name = "Dot",
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		LayoutOrder = order or 0,
	}, { Util.round() })
end

-- Mini wykres ceny z odcinków linii i półprzezroczystego wypełnienia.
function Icons.sparkline(points: { number }, size: Vector2, color: Color3): Frame
	local frame = create("Frame", {
		Name = "Sparkline",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size.X, size.Y),
	})
	local lo, hi = math.huge, -math.huge
	for _, v in points do
		lo = math.min(lo, v)
		hi = math.max(hi, v)
	end
	local range = if hi > lo then hi - lo else 1
	local n = #points
	local function at(i: number): Vector2
		return Vector2.new((i - 1) / (n - 1) * size.X, size.Y - (points[i] - lo) / range * size.Y)
	end
	for i = 1, n - 1 do
		local a, b = at(i), at(i + 1)
		local d = b - a
		local fillTop = math.min(a.Y, b.Y)
		local fill = create("Frame", {
			Position = UDim2.fromOffset(a.X, fillTop),
			Size = UDim2.fromOffset(d.X + 0.5, size.Y - fillTop),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Parent = frame,
		})
		create("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new(0.8, 1),
			Parent = fill,
		})
		bar(frame, (a + b) / 2, d.Magnitude + 1, 2, math.deg(math.atan2(d.Y, d.X)), color)
	end
	return frame
end

return table.freeze(Icons)
