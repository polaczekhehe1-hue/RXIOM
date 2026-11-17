--!strict
-- Proste ikony rysowane z ramek, żeby nie zależeć od wgrywanych assetów.

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local create = Util.create
local Colors = Theme.Colors
local Fonts = Theme.Fonts

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

-- Odcinek od a do b.
local function line(parent: Instance, a: Vector2, b: Vector2, thickness: number, color: Color3)
	local d = b - a
	bar(parent, (a + b) / 2, d.Magnitude + thickness * 0.5, thickness, math.deg(math.atan2(d.Y, d.X)), color)
end

local function box(name: string, size: number, order: number?): Frame
	return create("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		LayoutOrder = order or 0,
	})
end

local function outline(parent: Instance, pos: Vector2, size: Vector2, color: Color3, radius: number, thickness: number?)
	return create("Frame", {
		Position = UDim2.fromOffset(pos.X, pos.Y),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
		Parent = parent,
	}, { Util.corner(radius), Util.stroke(color, thickness or 1.5) })
end

local function triangle(frame: Frame, size: number, thickness: number, color: Color3, closed: boolean)
	local h = size * math.sqrt(3) / 2
	local top = (size - h) / 2
	local left = Vector2.new(thickness / 2, top + h - thickness / 2)
	local right = Vector2.new(size - thickness / 2, top + h - thickness / 2)
	local apex = Vector2.new(size / 2, top + thickness / 2)
	line(frame, left, apex, thickness, color)
	line(frame, right, apex, thickness, color)
	if closed then
		line(frame, left, right, thickness, color)
	end
end

-- Logo RXIOM: trójkąt jak w logo Axiom.
function Icons.logo(size: number, order: number?): Frame
	local frame = box("LogoIcon", size, order)
	triangle(frame, size, math.max(3, size * 0.14), Colors.Text, true)
	return frame
end

export type Direction = "Down" | "Up" | "Left" | "Right"

function Icons.chevron(size: number, color: Color3, direction: Direction?, order: number?): Frame
	local frame = box("Chevron", size, order)
	local t = math.max(1.5, size * 0.14)
	local s = size
	local points: { Vector2 }
	local dir = direction or "Down"
	if dir == "Down" then
		points = { Vector2.new(s * 0.2, s * 0.35), Vector2.new(s * 0.5, s * 0.65), Vector2.new(s * 0.8, s * 0.35) }
	elseif dir == "Up" then
		points = { Vector2.new(s * 0.2, s * 0.65), Vector2.new(s * 0.5, s * 0.35), Vector2.new(s * 0.8, s * 0.65) }
	elseif dir == "Left" then
		points = { Vector2.new(s * 0.65, s * 0.2), Vector2.new(s * 0.35, s * 0.5), Vector2.new(s * 0.65, s * 0.8) }
	else
		points = { Vector2.new(s * 0.35, s * 0.2), Vector2.new(s * 0.65, s * 0.5), Vector2.new(s * 0.35, s * 0.8) }
	end
	line(frame, points[1], points[2], t, color)
	line(frame, points[2], points[3], t, color)
	return frame
end

function Icons.chevronDown(size: number, color: Color3, order: number?): Frame
	return Icons.chevron(size, color, "Down", order)
end

function Icons.search(size: number, color: Color3, order: number?): Frame
	local frame = box("SearchIcon", size, order)
	local r = size * 0.62
	create("Frame", {
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
		line(frame, vertices[i], vertices[(i + 2) % 5], 2, color)
	end
	return frame
end

-- Ikona waluty w grze (odpowiednik logo SOL).
function Icons.currency(size: number, order: number?): Frame
	local frame = box("CurrencyIcon", size, order)
	local t = math.max(2, math.floor(size * 0.18))
	for i = 0, 2 do
		local b = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(size / 2, size * (0.22 + i * 0.28)),
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

-- Kółko ze znakiem zapytania.
function Icons.help(size: number, color: Color3, order: number?): Frame
	local frame = box("HelpIcon", size, order)
	outline(frame, Vector2.zero, Vector2.new(size, size), color, size, 1.5)
	create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "?",
		TextSize = size * 0.7,
		FontFace = Fonts.Bold,
		TextColor3 = color,
		Parent = frame,
	})
	return frame
end

function Icons.wallet(size: number, color: Color3, order: number?): Frame
	local frame = box("WalletIcon", size, order)
	outline(frame, Vector2.new(0, size * 0.18), Vector2.new(size, size * 0.72), color, 3)
	outline(frame, Vector2.new(size * 0.55, size * 0.4), Vector2.new(size * 0.45, size * 0.28), color, 2)
	return frame
end

function Icons.pencil(size: number, color: Color3, order: number?): Frame
	local frame = box("PencilIcon", size, order)
	line(frame, Vector2.new(size * 0.2, size * 0.75), Vector2.new(size * 0.8, size * 0.15), 2, color)
	line(frame, Vector2.new(size * 0.1, size * 0.95), Vector2.new(size * 0.95, size * 0.95), 1.5, color)
	return frame
end

-- Dystrybutor paliwa (priority fee).
function Icons.gas(size: number, color: Color3, order: number?): Frame
	local frame = box("GasIcon", size, order)
	outline(frame, Vector2.new(size * 0.1, size * 0.1), Vector2.new(size * 0.5, size * 0.85), color, 2)
	line(frame, Vector2.new(size * 0.6, size * 0.3), Vector2.new(size * 0.85, size * 0.45), 1.5, color)
	line(frame, Vector2.new(size * 0.85, size * 0.45), Vector2.new(size * 0.85, size * 0.85), 1.5, color)
	return frame
end

-- Moneta (tip).
function Icons.coin(size: number, color: Color3, order: number?): Frame
	local frame = box("CoinIcon", size, order)
	create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size * 0.62),
		BackgroundTransparency = 1,
		Parent = frame,
	}, { Util.round(), Util.stroke(color, 1.5) })
	return frame
end

function Icons.warning(size: number, color: Color3, order: number?): Frame
	local frame = box("WarningIcon", size, order)
	triangle(frame, size, 1.5, color, true)
	bar(frame, Vector2.new(size / 2, size * 0.55), size * 0.28, 1.5, 90, color)
	return frame
end

function Icons.shield(size: number, color: Color3, order: number?): Frame
	local frame = box("ShieldIcon", size, order)
	local w = size * 0.8
	line(frame, Vector2.new((size - w) / 2, size * 0.15), Vector2.new((size + w) / 2, size * 0.15), 1.5, color)
	line(frame, Vector2.new((size - w) / 2, size * 0.15), Vector2.new((size - w) / 2, size * 0.5), 1.5, color)
	line(frame, Vector2.new((size + w) / 2, size * 0.15), Vector2.new((size + w) / 2, size * 0.5), 1.5, color)
	line(frame, Vector2.new((size - w) / 2, size * 0.5), Vector2.new(size / 2, size * 0.92), 1.5, color)
	line(frame, Vector2.new((size + w) / 2, size * 0.5), Vector2.new(size / 2, size * 0.92), 1.5, color)
	return frame
end

-- Slippage: ukośna kreska między dwiema kropkami (jak znak %).
function Icons.slippage(size: number, color: Color3, order: number?): Frame
	local frame = box("SlippageIcon", size, order)
	line(frame, Vector2.new(size * 0.2, size * 0.85), Vector2.new(size * 0.8, size * 0.15), 1.5, color)
	outline(frame, Vector2.new(0, 0), Vector2.new(size * 0.35, size * 0.35), color, size, 1.5)
	outline(frame, Vector2.new(size * 0.65, size * 0.65), Vector2.new(size * 0.35, size * 0.35), color, size, 1.5)
	return frame
end

function Icons.check(size: number, color: Color3, order: number?): Frame
	local frame = box("CheckIcon", size, order)
	line(frame, Vector2.new(size * 0.18, size * 0.52), Vector2.new(size * 0.42, size * 0.75), 2, color)
	line(frame, Vector2.new(size * 0.42, size * 0.75), Vector2.new(size * 0.85, size * 0.25), 2, color)
	return frame
end

function Icons.close(size: number, color: Color3, order: number?): Frame
	local frame = box("CloseIcon", size, order)
	line(frame, Vector2.new(size * 0.2, size * 0.2), Vector2.new(size * 0.8, size * 0.8), 1.5, color)
	line(frame, Vector2.new(size * 0.8, size * 0.2), Vector2.new(size * 0.2, size * 0.8), 1.5, color)
	return frame
end

-- Kwadratowa ikonka coina z inicjałami, w kolorze coina.
function Icons.token(color: Color3, ticker: string, size: number, order: number?): Frame
	local initials = string.sub(ticker, 1, 1) .. string.sub(ticker, -1)
	local frame: Frame = create("Frame", {
		Name = "TokenIcon",
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		LayoutOrder = order or 0,
	}, { Util.corner(math.max(4, size // 10)), Util.stroke(color, 2) })
	create("UIGradient", {
		Rotation = 45,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(90, 90, 90)),
		Parent = frame,
	})
	create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = initials,
		TextSize = math.floor(size * 0.4),
		FontFace = Fonts.Bold,
		TextColor3 = Colors.Background,
		Parent = frame,
	})
	return frame
end

return table.freeze(Icons)
