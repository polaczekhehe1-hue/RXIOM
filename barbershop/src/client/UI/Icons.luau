--!strict
-- Ikony rysowane z ramek (bez zewnętrznych assetów). Każda funkcja wypełnia kwadratowy kontener;
-- współrzędne są w skali kontenera. Kontur złożonych kształtów = czarna warstwa pod kolorową.

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local create = Util.create
local OUTLINE = Theme.Colors.Outline

local Icons = {}

type RectOpts = {
	Rotation: number?,
	Corner: number?,
	Stroke: number?,
	ZIndex: number?,
	Transparency: number?,
	Square: boolean?,
	Gradient: { Color3 }?,
}

-- Prostokąt o środku w (x, y); Square = rozmiar liczony tylko względem szerokości.
local function rect(parent: Instance, x: number, y: number, w: number, h: number, color: Color3, o: RectOpts?): Frame
	local opts: RectOpts = o or {}
	local children = {}
	if opts.Corner then
		table.insert(children, create("UICorner", { CornerRadius = UDim.new(opts.Corner, 0) }))
	end
	if opts.Stroke then
		table.insert(children, Util.stroke(opts.Stroke))
	end
	if opts.Gradient then
		table.insert(children, Util.gradient(opts.Gradient[1], opts.Gradient[2]))
	end
	return create("Frame", {
		Name = "Shape",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(w, h),
		SizeConstraint = if opts.Square then Enum.SizeConstraint.RelativeXX else Enum.SizeConstraint.RelativeXY,
		BackgroundColor3 = if opts.Gradient then Color3.new(1, 1, 1) else color,
		BackgroundTransparency = opts.Transparency or 0,
		BorderSizePixel = 0,
		Rotation = opts.Rotation or 0,
		ZIndex = opts.ZIndex or 1,
		Parent = parent,
	}, children)
end
Icons.rect = rect

local function group(parent: Instance, name: string, rotation: number?): Frame
	return create("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Rotation = rotation or 0,
		Parent = parent,
	})
end

-- Trójkąt zwrócony w górę: górna połowa obróconego kwadratu przycięta ramką.
local function triangleUp(parent: Instance, cx: number, baseY: number, width: number, color: Color3, zindex: number, clipBelow: number)
	local clip = create("Frame", {
		Name = "TriangleClip",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, baseY + clipBelow),
		ZIndex = zindex,
		Parent = parent,
	})
	local side = width / math.sqrt(2)
	create("Frame", {
		Name = "Diamond",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(cx, baseY / (baseY + clipBelow)),
		Size = UDim2.fromScale(side, side),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Rotation = 45,
		Parent = clip,
	})
end

-- Gruba strzałka w górę (ulepszenia).
function Icons.arrowUp(parent: Instance, color: Color3?)
	local fill = color or Color3.fromHex("8CFF5A")
	local g = group(parent, "ArrowUp")
	local t = 0.07
	triangleUp(g, 0.5, 0.5, 0.86 + t * 2.8, OUTLINE, 1, t)
	rect(g, 0.5, 0.7, 0.38 + t * 2, 0.5 + t * 2, OUTLINE, { ZIndex = 1, Corner = 0.12 })
	triangleUp(g, 0.5, 0.5, 0.86, fill, 2, 0)
	rect(g, 0.5, 0.7, 0.38, 0.5, fill, { ZIndex = 2, Corner = 0.08 })
	rect(g, 0.42, 0.68, 0.08, 0.32, Color3.new(1, 1, 1), { ZIndex = 3, Corner = 0.5, Transparency = 0.45 })
end

-- Klejnot z błyskiem (rebirth).
function Icons.gem(parent: Instance, color: Color3?)
	local g = group(parent, "Gem")
	local fill = color or Color3.fromHex("E07BFF")
	rect(g, 0.5, 0.5, 0.6, 0.6, fill, { Rotation = 45, Square = true, Corner = 0.12, Stroke = Theme.Stroke.Icon, Gradient = { Color3.fromHex("F6C9FF"), fill } })
	rect(g, 0.42, 0.42, 0.18, 0.18, Color3.new(1, 1, 1), { Rotation = 45, Square = true, Corner = 0.2, Transparency = 0.25 })
	-- Iskierka w rogu
	rect(g, 0.82, 0.18, 0.06, 0.22, Color3.new(1, 1, 1), { Corner = 0.5, Stroke = 2 })
	rect(g, 0.82, 0.18, 0.22, 0.06, Color3.new(1, 1, 1), { Corner = 0.5, Stroke = 2, Square = true })
end

-- Złota moneta z dolarem (licznik kasy).
function Icons.coin(parent: Instance)
	local g = group(parent, "Coin")
	rect(g, 0.5, 0.5, 0.86, 0.86, Theme.Colors.Gold, { Corner = 0.5, Stroke = Theme.Stroke.Icon, Gradient = { Color3.fromHex("FFF09A"), Color3.fromHex("F5B52A") } })
	rect(g, 0.5, 0.5, 0.62, 0.62, Color3.fromHex("F0A91E"), { Corner = 0.5, Transparency = 0.2 })
	Util.label({
		Text = "$",
		TextSize = 10,
		Size = UDim2.fromScale(0.8, 0.8),
		Position = UDim2.fromScale(0.5, 0.52),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Stroke = 2,
		Parent = g,
	}).TextScaled = true
end

-- Krzyżyk (zamykanie / wyjście).
function Icons.cross(parent: Instance, color: Color3?)
	local g = group(parent, "Cross")
	local fill = color or Color3.new(1, 1, 1)
	for _, angle in { 45, -45 } do
		rect(g, 0.5, 0.5, 0.86, 0.28, OUTLINE, { Rotation = angle, Square = true, Corner = 0.4, ZIndex = 1 })
	end
	for _, angle in { 45, -45 } do
		rect(g, 0.5, 0.5, 0.74, 0.16, fill, { Rotation = angle, Square = true, Corner = 0.5, ZIndex = 2 })
	end
end

-- Nożyczki (podpowiedź strzyżenia).
function Icons.scissors(parent: Instance)
	local g = group(parent, "Scissors", -20)
	local blade = Color3.fromHex("E6ECF2")
	local handle = Color3.fromHex("FF5A5A")
	rect(g, 0.5, 0.32, 0.16, 0.62, blade, { Rotation = 22, Corner = 0.5, Stroke = Theme.Stroke.Icon })
	rect(g, 0.5, 0.32, 0.16, 0.62, blade, { Rotation = -22, Corner = 0.5, Stroke = Theme.Stroke.Icon })
	for _, x in { 0.3, 0.7 } do
		rect(g, x, 0.74, 0.32, 0.32, handle, { Corner = 0.5, Stroke = Theme.Stroke.Icon, Square = true })
		rect(g, x, 0.74, 0.14, 0.14, Color3.fromHex("8A1C1C"), { Corner = 0.5, Square = true })
	end
	rect(g, 0.5, 0.52, 0.1, 0.1, OUTLINE, { Corner = 0.5, Square = true })
end

return table.freeze(Icons)
