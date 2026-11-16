--!strict
-- Ikony rysowane z ramek (bez zewnętrznych assetów). Każda funkcja wypełnia kwadratowy kontener;
-- współrzędne są w skali kontenera. Kontur = czarna warstwa (ZIndex 1) pod kolorową (ZIndex 2+).
-- Łuki i trójkąty nie używają UIStroke, bo jego grubość nieprzewidywalnie skaluje się pod UIScale.

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
	Gradient: { Color3 }?,
}

-- Prostokąt o środku w (x, y); oba wymiary liczone względem szerokości kontenera.
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
		SizeConstraint = Enum.SizeConstraint.RelativeXX,
		BackgroundColor3 = if opts.Gradient then Color3.new(1, 1, 1) else color,
		BackgroundTransparency = opts.Transparency or 0,
		BorderSizePixel = 0,
		Rotation = opts.Rotation or 0,
		ZIndex = opts.ZIndex or 1,
		Parent = parent,
	}, children)
end

local function circle(parent: Instance, x: number, y: number, d: number, color: Color3, z: number, gradient: { Color3 }?): Frame
	return rect(parent, x, y, d, d, color, { Corner = 0.5, ZIndex = z, Gradient = gradient })
end

-- Odcinek o danej grubości między dwoma punktami.
local function segment(parent: Instance, x1: number, y1: number, x2: number, y2: number, width: number, color: Color3, z: number, round: boolean?): Frame
	local dx, dy = x2 - x1, y2 - y1
	local length = math.sqrt(dx * dx + dy * dy)
	return rect(parent, (x1 + x2) / 2, (y1 + y2) / 2, length, width, color, {
		Rotation = math.deg(math.atan2(dy, dx)),
		ZIndex = z,
		Corner = if round then 0.5 else nil,
	})
end

-- Łuk z gęsto nałożonych kółek (gładsza krawędź niż z odcinków); kąty w stopniach,
-- zgodnie z ruchem wskazówek zegara od osi +X.
local function arc(parent: Instance, cx: number, cy: number, r: number, width: number, from: number, to: number, color: Color3, z: number)
	local length = math.rad(math.abs(to - from)) * r
	local steps = math.max(2, math.ceil(length / (width * 0.15)))
	for i = 0, steps do
		local a = math.rad(from + (to - from) * i / steps)
		circle(parent, cx + r * math.cos(a), cy + r * math.sin(a), width, color, z)
	end
end

-- Trójkąt równoramienny prostokątny: środek podstawy w (x, y), wierzchołek w kierunku `angle` (stopnie, 0 = w prawo).
-- Kwadrat obrócony o 45° z gradientem przezroczystości ucinającym połowę — działa przy każdym obrocie.
local function triangle(parent: Instance, x: number, y: number, base: number, angle: number, color: Color3, z: number): Frame
	local side = base / math.sqrt(2)
	return create("Frame", {
		Name = "Triangle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(side, side),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Rotation = 45 + angle + 90,
		ZIndex = z,
		Parent = parent,
	}, {
		create("UIGradient", {
			Rotation = 45,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(0.501, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
end

-- Trójkąt z czarnym konturem.
local function outlinedTriangle(parent: Instance, x: number, y: number, base: number, angle: number, color: Color3, outline: number)
	local a = math.rad(angle)
	triangle(parent, x - math.cos(a) * outline, y - math.sin(a) * outline, base + outline * 4.8, angle, OUTLINE, 1)
	triangle(parent, x, y, base, angle, color, 4)
end

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

-- Złota moneta jak na arkuszu referencyjnym: pomarańczowy brzeg, jasna tarcza i wklęsły środek z półksiężycem.
function Icons.coin(parent: Instance)
	local g = group(parent, "Coin")
	circle(g, 0.52, 0.53, 0.9, Color3.fromHex("E8890C"), 1)
	circle(g, 0.48, 0.48, 0.86, Color3.fromHex("FFC21F"), 2, { Color3.fromHex("FFD95A"), Color3.fromHex("FCB21B") })
	circle(g, 0.44, 0.47, 0.56, Color3.fromHex("FFDB5E"), 3)
	circle(g, 0.5, 0.49, 0.54, Color3.fromHex("F3A112"), 4, { Color3.fromHex("EE9A0E"), Color3.fromHex("F7AE1C") })
	rect(g, 0.27, 0.25, 0.12, 0.07, Color3.new(1, 1, 1), { Corner = 0.5, Rotation = -40, ZIndex = 5, Transparency = 0.35 })
end

-- Dwie strzałki w kółko (rebirth): górna połowa jasnoniebieska, dolna czerwona, gruby czarny kontur.
function Icons.rebirth(parent: Instance)
	local g = group(parent, "Rebirth")
	local cx, cy, r, w, o = 0.5, 0.5, 0.26, 0.21, 0.05
	local blue = Color3.fromHex("CBEFFF")
	local blueShade = Color3.fromHex("8FD3F2")
	local red = Color3.fromHex("F23F4C")
	local redShade = Color3.fromHex("C42736")

	-- Niebieska strzałka: od lewej-góry przez górę do prawej, grot w dół.
	-- Czerwona: od prawej-dołu przez dół do lewej, grot w górę.
	local halves = {
		{ from = 250, to = 385, color = blue, shade = blueShade },
		{ from = 70, to = 205, color = red, shade = redShade },
	}
	for _, h in halves do
		arc(g, cx, cy, r, w + o * 2, h.from - 4, h.to, OUTLINE, 1)
	end
	for _, h in halves do
		arc(g, cx, cy, r, w, h.from, h.to, h.color, 2)
		-- Cień po wewnętrznej stronie i blask po zewnętrznej, jak wypukły klocek.
		arc(g, cx, cy, r - w * 0.32, w * 0.3, h.from + 3, h.to, h.shade, 3)
		arc(g, cx, cy, r + w * 0.3, w * 0.16, h.from + 8, h.to - 6, Color3.new(1, 1, 1), 3)
	end
	for _, h in halves do
		local a = math.rad(h.to)
		local x, y = cx + r * math.cos(a), cy + r * math.sin(a)
		-- Kierunek zgodny z ruchem wskazówek zegara to kąt łuku + 90°.
		outlinedTriangle(g, x, y, w * 2.1, h.to + 90, h.color, o)
	end
end

-- Nożyczki jak na referencji: jasnoniebieskie, zaostrzone ostrza, grube czerwone uchwyty,
-- niebieska śrubka, iskierka i kropelki.
function Icons.scissors(parent: Instance)
	local g = group(parent, "Scissors")
	local o = 0.045
	local red = Color3.fromHex("F03A3A")
	local blade = Color3.fromHex("CFEAFF")
	local bladeShade = Color3.fromHex("86BFF0")
	local pivotX, pivotY = 0.52, 0.47
	local bladeWidth = 0.17

	local blades = {
		-- Ostrze do prawego-górnego rogu, uchwyt po lewej
		{ tipX = 0.9, tipY = 0.15, handleX = 0.2, handleY = 0.64 },
		-- Ostrze w górę, uchwyt na dole
		{ tipX = 0.4, tipY = 0.05, handleX = 0.62, handleY = 0.8 },
	}

	-- Uchwyty: kontur, potem czerwień
	for _, b in blades do
		segment(g, pivotX, pivotY, b.handleX, b.handleY, 0.12 + o * 2, OUTLINE, 1, true)
		arc(g, b.handleX, b.handleY, 0.12, 0.1 + o * 2, 0, 360, OUTLINE, 1)
	end
	segment(g, 0.14, 0.74, 0.1, 0.86, 0.06 + o * 2, OUTLINE, 1, true)
	circle(g, 0.1, 0.88, 0.1 + o * 2, OUTLINE, 1)
	for _, b in blades do
		segment(g, pivotX, pivotY, b.handleX, b.handleY, 0.12, red, 2, true)
		arc(g, b.handleX, b.handleY, 0.12, 0.1, 0, 360, red, 2)
	end
	segment(g, 0.14, 0.74, 0.1, 0.86, 0.06, red, 2, true)
	circle(g, 0.1, 0.88, 0.1, red, 2)

	-- Ostrza: prostokąt od tyłu śrubki + trójkątny czubek
	for i, b in blades do
		local dx, dy = b.tipX - pivotX, b.tipY - pivotY
		local len = math.sqrt(dx * dx + dy * dy)
		local ux, uy = dx / len, dy / len
		local bodyEnd = len - bladeWidth / 2
		local backX, backY = pivotX - ux * 0.08, pivotY - uy * 0.08
		local endX, endY = pivotX + ux * bodyEnd, pivotY + uy * bodyEnd
		local angle = math.deg(math.atan2(uy, ux))
		segment(g, backX - ux * o, backY - uy * o, endX, endY, bladeWidth + o * 2, OUTLINE, 1)
		circle(g, backX, backY, bladeWidth + o * 2, OUTLINE, 1)
		triangle(g, endX + ux * o * 0.4, endY + uy * o * 0.4, bladeWidth + o * 2, angle, OUTLINE, 1)
		triangle(g, endX, endY, bladeWidth, angle, blade, 2 + i)
		segment(g, backX, backY, endX, endY, bladeWidth, blade, 2 + i)
		circle(g, backX, backY, bladeWidth, blade, 2 + i)
		-- Ciemniejsza krawędź tnąca
		local nx, ny = -uy * bladeWidth * 0.28, ux * bladeWidth * 0.28
		segment(g, pivotX + nx + ux * 0.06, pivotY + ny + uy * 0.06, endX + nx, endY + ny, bladeWidth * 0.26, bladeShade, 2 + i)
	end

	-- Śrubka
	circle(g, pivotX, pivotY, 0.12 + o * 2, OUTLINE, 6)
	circle(g, pivotX, pivotY, 0.12, Color3.fromHex("8EC9F5"), 7)
	circle(g, pivotX, pivotY, 0.05, Color3.new(1, 1, 1), 8)

	-- Iskierka i czarne kropelki
	for _, rot in { 0, 90 } do
		rect(g, 0.33, 0.1, 0.17, 0.065, OUTLINE, { Rotation = rot, Corner = 0.5, ZIndex = 1 })
	end
	for _, rot in { 0, 90 } do
		rect(g, 0.33, 0.1, 0.13, 0.03, Color3.new(1, 1, 1), { Rotation = rot, Corner = 0.5, ZIndex = 2 })
	end
	circle(g, 0.9, 0.36, 0.06, OUTLINE, 1)
	circle(g, 0.94, 0.45, 0.045, OUTLINE, 1)
	segment(g, 0.33, 0.85, 0.39, 0.82, 0.035, OUTLINE, 1, true)
end

-- Gruba strzałka w górę (ulepszenia).
function Icons.arrowUp(parent: Instance, color: Color3?)
	local fill = color or Color3.fromHex("8CFF5A")
	local g = group(parent, "ArrowUp")
	local o = 0.06
	outlinedTriangle(g, 0.5, 0.48, 0.84, -90, fill, o)
	rect(g, 0.5, 0.69, 0.38 + o * 2, 0.44 + o * 2, OUTLINE, { ZIndex = 1, Corner = 0.15 })
	rect(g, 0.5, 0.68, 0.38, 0.44, fill, { ZIndex = 2, Corner = 0.1 })
	rect(g, 0.42, 0.66, 0.07, 0.28, Color3.new(1, 1, 1), { ZIndex = 5, Corner = 0.5, Transparency = 0.45 })
end

-- Krzyżyk (zamykanie / wyjście).
function Icons.cross(parent: Instance, color: Color3?)
	local g = group(parent, "Cross")
	local fill = color or Color3.new(1, 1, 1)
	for _, angle in { 45, -45 } do
		rect(g, 0.5, 0.5, 0.86, 0.28, OUTLINE, { Rotation = angle, Corner = 0.4, ZIndex = 1 })
	end
	for _, angle in { 45, -45 } do
		rect(g, 0.5, 0.5, 0.74, 0.16, fill, { Rotation = angle, Corner = 0.5, ZIndex = 2 })
	end
end

return table.freeze(Icons)
