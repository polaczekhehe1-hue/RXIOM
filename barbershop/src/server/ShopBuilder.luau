--!strict
-- Salon fryzjerski z klocków, wzorowany na zdjęciu referencyjnym:
-- jasna betonowa podłoga, biała i szałwiowa ściana, drewniane szafki z lustrami,
-- szare fotele na czarnych podstawach, czarne szyny z reflektorami pod sufitem i palma w doniczce.
--
-- Układ lokalny: początek w środku frontu na poziomie trawy, -Z patrzy na plac, +Z w głąb salonu.

local Blocks = require(script.Parent.Blocks)

local ShopBuilder = {}

local C = {
	Floor = Color3.fromHex("E4E2DD"),
	FloorDark = Color3.fromHex("CFCCC6"),
	WallWhite = Color3.fromHex("F1F0EC"),
	WallSage = Color3.fromHex("B7C2B1"),
	Ceiling = Color3.fromHex("F7F7F5"),
	Black = Color3.fromHex("1C1C1F"),
	Charcoal = Color3.fromHex("2B2C30"),
	Wood = Color3.fromHex("E3C493"),
	WoodDark = Color3.fromHex("C9A673"),
	Mirror = Color3.fromHex("CFDDE3"),
	Chrome = Color3.fromHex("C3C8CC"),
	Vinyl = Color3.fromHex("D7DADC"),
	Glass = Color3.fromHex("A8D2E6"),
	PotWhite = Color3.fromHex("F4F4F2"),
	Leaf = Color3.fromHex("3F8F45"),
	LeafDark = Color3.fromHex("2E6B34"),
	LeafLight = Color3.fromHex("63B45E"),
	Red = Color3.fromHex("D93B3B"),
	Blue = Color3.fromHex("2F5FD0"),
	Gold = Color3.fromHex("E2B33C"),
	Warm = Color3.fromHex("FFE6C4"),
}

local BOTTLE_COLORS = {
	Color3.fromHex("3FA7D6"),
	Color3.fromHex("F2F2F2"),
	Color3.fromHex("1C1C1F"),
	Color3.fromHex("E8A33D"),
	Color3.fromHex("7BC67E"),
	Color3.fromHex("D96C8A"),
	Color3.fromHex("C9B9A6"),
}

-- Wnętrze: x ∈ [-19.5, 19.5], z ∈ [1, 32], podłoga na y = 1, sufit na y = 15.
local HALF_WIDTH = 19.5
local BACK_Z = 32
local FLOOR_Y = 1
local CEILING_Y = 15
local DOOR_HALF = 3.5
local DOOR_TOP = 11

-- Kolejność odblokowywania foteli: naprzemiennie prawa i lewa ściana, od wejścia w głąb.
local STATION_SLOTS = {
	{ side = 1, z = 10 },
	{ side = -1, z = 10 },
	{ side = 1, z = 18 },
	{ side = -1, z = 18 },
	{ side = 1, z = 26 },
	{ side = -1, z = 26 },
}

export type Station = {
	index: number,
	model: Model,
	seat: BasePart,
	-- Pozycja korzenia klienta (stopy), gdy siedzi w fotelu.
	seatCFrame: CFrame,
	-- Gdzie stoi gracz podczas strzyżenia.
	standCFrame: CFrame,
	-- Punkty dojścia: przejście na wysokości fotela i miejsce tuż przy fotelu.
	aislePoint: Vector3,
	besidePoint: Vector3,
	prompt: ProximityPrompt,
}

export type Shop = {
	index: number,
	origin: CFrame,
	model: Model,
	stationsFolder: Folder,
	decorFolder: Folder,
	signLabel: TextLabel,
	stations: { Station },
	decorLevel: number,
	-- Punkty ścieżki klienta: przed drzwiami, w drzwiach, środek przejścia.
	doorOutside: Vector3,
	doorInside: Vector3,
	spawnCFrame: CFrame,
}

type BoxOptions = {
	Material: Enum.Material?,
	Transparency: number?,
	Reflectance: number?,
	CanCollide: boolean?,
	CastShadow: boolean?,
	Studs: boolean?,
}

-- Klocek w lokalnych współrzędnych salonu (pozycja = środek klocka).
local function box(shop: { origin: CFrame }, parent: Instance, name: string, size: Vector3, pos: Vector3, color: Color3, opts: BoxOptions?, rot: CFrame?): Part
	local o: BoxOptions = opts or {}
	return Blocks.part({
		Name = name,
		Size = size,
		CFrame = shop.origin * CFrame.new(pos) * (rot or CFrame.identity),
		Color = color,
		Parent = parent,
		Material = o.Material,
		Transparency = o.Transparency,
		Reflectance = o.Reflectance,
		CanCollide = o.CanCollide,
		CastShadow = o.CastShadow,
		Studs = o.Studs,
	})
end

local function spotLight(parent: BasePart, range: number, brightness: number)
	local light = Instance.new("SpotLight")
	-- Reflektor to walec obrócony o 90°, więc jego lokalna oś -X patrzy w dół.
	light.Face = Enum.NormalId.Left
	light.Angle = 75
	light.Range = range
	light.Brightness = brightness
	light.Color = C.Warm
	light.Shadows = true
	light.Parent = parent
end

local function buildShell(shop: Shop)
	local m = shop.model
	local shell = Blocks.folder("Shell", m)
	local height = CEILING_Y - FLOOR_Y
	local wallY = FLOOR_Y + height / 2

	-- Podłoga i ściany
	box(shop, shell, "Floor", Vector3.new(41, 1, 33), Vector3.new(0, 0.5, 16.5), C.Floor)
	box(shop, shell, "WallBack", Vector3.new(41, height, 1), Vector3.new(0, wallY, BACK_Z + 0.5), C.WallWhite)
	box(shop, shell, "WallLeft", Vector3.new(1, height, 33), Vector3.new(-20, wallY, 16.5), C.WallWhite)
	box(shop, shell, "WallRight", Vector3.new(1, height, 33), Vector3.new(20, wallY, 16.5), C.WallSage)
	box(shop, shell, "Ceiling", Vector3.new(41, 1, 33), Vector3.new(0, CEILING_Y + 0.5, 16.5), C.Ceiling)
	-- Listwy przypodłogowe
	box(shop, shell, "SkirtLeft", Vector3.new(0.2, 0.4, 31), Vector3.new(-19.4, FLOOR_Y + 0.2, 16.5), C.FloorDark, { Studs = false })
	box(shop, shell, "SkirtRight", Vector3.new(0.2, 0.4, 31), Vector3.new(19.4, FLOOR_Y + 0.2, 16.5), C.FloorDark, { Studs = false })

	-- Rozproszone światło z sufitu, żeby wnętrze nie było ciemne pod dachem.
	local fill = Instance.new("SurfaceLight")
	fill.Face = Enum.NormalId.Bottom
	fill.Range = 16
	fill.Brightness = 0.7
	fill.Angle = 90
	fill.Color = C.Warm
	fill.Shadows = false
	fill.Parent = shell:FindFirstChild("Ceiling")

	-- Front: czarny cokół, szyby z czarnymi ramami, otwór drzwiowy i pas szyldu.
	local frontZ = 0.5
	for _, sx in { -1, 1 } do
		local inner = DOOR_HALF
		local width = HALF_WIDTH - inner
		local cx = sx * (inner + width / 2)
		box(shop, shell, "Kick", Vector3.new(width, 1, 1), Vector3.new(cx, FLOOR_Y + 0.5, frontZ), C.Black)
		box(shop, shell, "Glass", Vector3.new(width, DOOR_TOP - FLOOR_Y - 1, 0.3), Vector3.new(cx, (FLOOR_Y + 1 + DOOR_TOP) / 2, frontZ), C.Glass, {
			Material = Enum.Material.Glass,
			Transparency = 0.6,
			Studs = false,
		})
		for k = 0, 3 do
			local x = sx * (inner + k * width / 3)
			box(shop, shell, "Mullion", Vector3.new(0.5, DOOR_TOP - FLOOR_Y, 1), Vector3.new(x, (FLOOR_Y + DOOR_TOP) / 2, frontZ), C.Black, { Studs = false })
		end
		box(shop, shell, "Corner", Vector3.new(1, height, 1), Vector3.new(sx * 20, wallY, frontZ), C.Black)
	end
	box(shop, shell, "Fascia", Vector3.new(41, CEILING_Y + 1 - DOOR_TOP, 1), Vector3.new(0, (DOOR_TOP + CEILING_Y + 1) / 2, frontZ), C.Charcoal)

	local sign = box(shop, shell, "Sign", Vector3.new(26, 3, 0.4), Vector3.new(0, 13, -0.2), C.Black, { Studs = false })
	shop.signLabel = Blocks.label(sign, Enum.NormalId.Front, "WOLNY LOKAL", Color3.new(1, 1, 1), Blocks.Font)

	-- Markiza w czerwono-białe pasy nad wejściem.
	for i = 0, 9 do
		local x = -10 + i * 2 + 1
		box(shop, shell, "Awning", Vector3.new(2, 0.4, 3.4), Vector3.new(x, DOOR_TOP + 0.2, -1.5), if i % 2 == 0 then C.Red else C.WallWhite, {
			Studs = false,
		}, CFrame.Angles(math.rad(-14), 0, 0))
	end

	-- Chodnik przed salonem i wycieraczka.
	box(shop, shell, "Sidewalk", Vector3.new(44, 0.4, 10), Vector3.new(0, 0.2, -5), Color3.fromHex("BDBAB3"))
	box(shop, shell, "Mat", Vector3.new(6, 0.1, 3), Vector3.new(0, FLOOR_Y + 0.05, 2.6), C.Charcoal, { Studs = false, CanCollide = false })

	-- Czarne szyny oświetleniowe z reflektorami (jak na zdjęciu), światło co drugi reflektor.
	for _, x in { -8, 0, 8 } do
		box(shop, shell, "Rail", Vector3.new(0.3, 0.3, 29), Vector3.new(x, CEILING_Y - 0.15, 16.5), C.Black, { Studs = false })
		for j, z in { 5, 11, 17, 23, 29 } do
			local head = Blocks.cylinder("Spot", 0.9, 0.6, shop.origin * CFrame.new(x, CEILING_Y - 0.75, z), C.Black, shell)
			head.CastShadow = false
			if x ~= 0 and j % 2 == 1 then
				spotLight(head, 18, 1.6)
			end
		end
	end
	-- Okrągłe punkty wpuszczone w sufit
	local rng = Random.new(shop.index)
	for _ = 1, 10 do
		local pos = shop.origin * CFrame.new(rng:NextNumber(-17, 17), CEILING_Y - 0.04, rng:NextNumber(3, 30))
		Blocks.cylinder("Dot", 0.08, 0.7, pos, C.Black, shell).CastShadow = false
	end
end

local function buildBottles(shop: Shop, parent: Instance, from: Vector3, along: Vector3, count: number, rng: Random)
	for i = 0, count - 1 do
		local h = rng:NextNumber(0.5, 1.1)
		local w = rng:NextNumber(0.3, 0.45)
		local pos = from + along * i + Vector3.new(0, h / 2, 0)
		box(shop, parent, "Bottle", Vector3.new(w, h, w), pos, BOTTLE_COLORS[rng:NextInteger(1, #BOTTLE_COLORS)], {
			Studs = false,
			CanCollide = false,
			CastShadow = false,
		})
	end
end

local function buildChair(parent: Instance, cf: CFrame): BasePart
	-- cf: środek podstawy na podłodze, -Z = przód fotela (w stronę lustra).
	Blocks.cylinder("Base", 0.35, 3.4, cf * CFrame.new(0, 0.175, 0), C.Black, parent)
	Blocks.cylinder("BaseRing", 0.1, 2.6, cf * CFrame.new(0, 0.4, 0), C.Chrome, parent, Enum.Material.Metal)
	Blocks.cylinder("Stem", 1.6, 0.7, cf * CFrame.new(0, 1.15, 0), C.Chrome, parent, Enum.Material.Metal)
	local seat = Blocks.part({ Name = "Seat", Size = Vector3.new(2.8, 0.7, 2.8), CFrame = cf * CFrame.new(0, 2.3, 0), Color = C.Vinyl, Parent = parent })
	Blocks.part({ Name = "Back", Size = Vector3.new(2.8, 3.2, 0.6), CFrame = cf * CFrame.new(0, 4.25, 1.1), Color = C.Vinyl, Parent = parent })
	Blocks.part({ Name = "BackFrame", Size = Vector3.new(2.4, 2.6, 0.2), CFrame = cf * CFrame.new(0, 4.1, 1.5), Color = C.Chrome, Material = Enum.Material.Metal, Parent = parent, Studs = false })
	for _, sx in { -1, 1 } do
		Blocks.part({ Name = "Arm", Size = Vector3.new(0.5, 0.4, 2.6), CFrame = cf * CFrame.new(sx * 1.55, 3.4, 0), Color = C.Vinyl, Parent = parent, Studs = false })
		Blocks.part({ Name = "ArmPost", Size = Vector3.new(0.3, 0.75, 0.3), CFrame = cf * CFrame.new(sx * 1.55, 2.85, -0.9), Color = C.Chrome, Material = Enum.Material.Metal, Parent = parent, Studs = false })
	end
	Blocks.part({ Name = "FootBar", Size = Vector3.new(0.3, 0.3, 1.4), CFrame = cf * CFrame.new(0, 1.3, -1.6), Color = C.Chrome, Material = Enum.Material.Metal, Parent = parent, Studs = false })
	Blocks.part({ Name = "FootRest", Size = Vector3.new(2.2, 0.2, 0.7), CFrame = cf * CFrame.new(0, 1.1, -2.3), Color = C.Chrome, Material = Enum.Material.Metal, Parent = parent, Studs = false })
	return seat
end

local function buildStation(shop: Shop, index: number): Station
	local slot = STATION_SLOTS[index]
	local s, z = slot.side, slot.z
	local model = Blocks.model(`Station{index}`, shop.stationsFolder)
	local rng = Random.new(shop.index * 100 + index)

	-- Szafka z drewna (sklejka jak na zdjęciu) z czarnym blatem i szufladami.
	local cabX = s * (HALF_WIDTH - 1.2)
	box(shop, model, "Cabinet", Vector3.new(2.4, 3.4, 5), Vector3.new(cabX, FLOOR_Y + 1.7, z), C.Wood)
	box(shop, model, "Counter", Vector3.new(2.7, 0.25, 5.2), Vector3.new(s * (HALF_WIDTH - 1.35), FLOOR_Y + 3.525, z), C.Black)
	local front = s * (HALF_WIDTH - 2.42)
	box(shop, model, "DrawerLine", Vector3.new(0.06, 0.08, 4.6), Vector3.new(front, FLOOR_Y + 2.5, z), C.WoodDark, { Studs = false })
	box(shop, model, "DoorLine", Vector3.new(0.06, 2.3, 0.08), Vector3.new(front, FLOOR_Y + 1.25, z), C.WoodDark, { Studs = false })
	box(shop, model, "Handle", Vector3.new(0.12, 0.8, 0.15), Vector3.new(front - s * 0.05, FLOOR_Y + 1.6, z + 1.8), C.Chrome, { Studs = false, Material = Enum.Material.Metal })
	-- Na blacie: maszynka i spryskiwacz
	box(shop, model, "Clipper", Vector3.new(0.5, 0.3, 1), Vector3.new(s * (HALF_WIDTH - 1.6), FLOOR_Y + 3.8, z - 1.4), C.Black, { Studs = false, CanCollide = false })
	box(shop, model, "Spray", Vector3.new(0.4, 0.9, 0.4), Vector3.new(s * (HALF_WIDTH - 0.9), FLOOR_Y + 4.1, z + 1.8), BOTTLE_COLORS[rng:NextInteger(1, #BOTTLE_COLORS)], {
		Studs = false,
		CanCollide = false,
	})

	-- Lustro z jasną ramą
	box(shop, model, "MirrorFrame", Vector3.new(0.2, 6.9, 4.6), Vector3.new(s * (HALF_WIDTH - 0.1), FLOOR_Y + 7.35, z), C.WallWhite, { Studs = false })
	box(shop, model, "Mirror", Vector3.new(0.2, 6.5, 4.2), Vector3.new(s * (HALF_WIDTH - 0.25), FLOOR_Y + 7.35, z), C.Mirror, {
		Studs = false,
		Reflectance = 0.45,
		Material = Enum.Material.Glass,
	})

	-- Drewniane półki z kosmetykami między stanowiskami
	local shelfZ = z - 4
	for i, y in { 5.2, 7.2, 9.2 } do
		box(shop, model, "Shelf", Vector3.new(1.3, 0.2, 2.6), Vector3.new(s * (HALF_WIDTH - 0.65), FLOOR_Y + y, shelfZ), C.Wood)
		buildBottles(shop, model, Vector3.new(s * (HALF_WIDTH - 0.6), FLOOR_Y + y + 0.1, shelfZ - 0.9), Vector3.new(0, 0, 0.6), 3 + (i % 2), rng)
	end
	box(shop, model, "ShelfSide", Vector3.new(1.3, 4.6, 0.2), Vector3.new(s * (HALF_WIDTH - 0.65), FLOOR_Y + 7.2, shelfZ - 1.4), C.Wood, { Studs = false })
	box(shop, model, "ShelfSide", Vector3.new(1.3, 4.6, 0.2), Vector3.new(s * (HALF_WIDTH - 0.65), FLOOR_Y + 7.2, shelfZ + 1.4), C.Wood, { Studs = false })

	-- Fotel przodem do lustra
	local chairPos = (shop.origin * CFrame.new(s * 12.8, FLOOR_Y, z)).Position
	local towardWall = shop.origin.RightVector * s
	local chairCF = CFrame.lookAt(chairPos, chairPos + towardWall)
	local seat = buildChair(model, chairCF)

	local promptAnchor = Instance.new("Attachment")
	promptAnchor.Name = "PromptAnchor"
	promptAnchor.WorldCFrame = chairCF * CFrame.new(0, 6.5, 0)
	promptAnchor.Parent = seat

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShavePrompt"
	prompt.ActionText = "Strzyż"
	prompt.ObjectText = "Klient"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = promptAnchor

	local headPos = (chairCF * CFrame.new(0, 5.65, 0.3)).Position
	local standPos = (chairCF * CFrame.new(1.6, 3, 2.9)).Position
	return {
		index = index,
		model = model,
		seat = seat,
		seatCFrame = chairCF * CFrame.new(0, 0.65, 0.3),
		standCFrame = CFrame.lookAt(standPos, Vector3.new(headPos.X, standPos.Y, headPos.Z)),
		aislePoint = (shop.origin * CFrame.new(0, FLOOR_Y, z)).Position,
		besidePoint = (chairCF * CFrame.new(0, 0, 3.4)).Position,
		prompt = prompt,
	}
end

-- Palma z wokseli: biała doniczka i liście z pochylonych klocków.
local function buildPalm(shop: Shop, parent: Instance, pos: Vector3, scale: number, seed: number)
	local rng = Random.new(seed)
	local base = shop.origin * CFrame.new(pos)
	Blocks.part({ Name = "Pot", Size = Vector3.new(2.6, 2.4, 2.6) * scale, CFrame = base * CFrame.new(0, 1.2 * scale, 0), Color = C.PotWhite, Parent = parent })
	Blocks.part({ Name = "Soil", Size = Vector3.new(2.2, 0.2, 2.2) * scale, CFrame = base * CFrame.new(0, 2.35 * scale, 0), Color = Color3.fromHex("4A3527"), Parent = parent, Studs = false })
	Blocks.part({ Name = "Stem", Size = Vector3.new(0.5, 3, 0.5) * scale, CFrame = base * CFrame.new(0, 3.8 * scale, 0), Color = Color3.fromHex("7A5A3A"), Parent = parent, Studs = false })
	local top = base * CFrame.new(0, 5.2 * scale, 0)
	local colors = { C.Leaf, C.LeafDark, C.LeafLight }
	for ring = 1, 2 do
		local count = if ring == 1 then 8 else 6
		for i = 1, count do
			local yaw = (i / count) * math.pi * 2 + ring * 0.4 + rng:NextNumber(-0.15, 0.15)
			local pitch = if ring == 1 then math.rad(-28) else math.rad(20)
			local len = (if ring == 1 then 4.2 else 3) * scale
			local leafCF = top * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0) * CFrame.new(0, 0, -len / 2)
			Blocks.part({
				Name = "Leaf",
				Size = Vector3.new(1.1 * scale, 0.2, len),
				CFrame = leafCF,
				Color = colors[rng:NextInteger(1, #colors)],
				Parent = parent,
				CanCollide = false,
				Studs = false,
			})
		end
	end
end

-- Słupek fryzjerski z wokseli w paski czerwono-biało-niebieskie.
local function buildBarberPole(parent: Instance, base: CFrame, height: number)
	local colors = { C.Red, C.WallWhite, C.Blue, C.WallWhite }
	Blocks.part({ Name = "PoleBase", Size = Vector3.new(1.4, 0.6, 1.4), CFrame = base * CFrame.new(0, 0.3, 0), Color = C.Chrome, Material = Enum.Material.Metal, Parent = parent })
	local segments = math.floor(height / 0.6)
	for i = 0, segments - 1 do
		Blocks.part({
			Name = "PoleSegment",
			Size = Vector3.new(1, 0.6, 1),
			CFrame = base * CFrame.new(0, 0.9 + i * 0.6, 0) * CFrame.Angles(0, math.rad(i * 15), 0),
			Color = colors[i % #colors + 1],
			Parent = parent,
			Studs = false,
		})
	end
	local cap = Blocks.part({ Name = "PoleCap", Size = Vector3.new(1.4, 0.6, 1.4), CFrame = base * CFrame.new(0, 0.9 + segments * 0.6, 0), Color = C.Chrome, Material = Enum.Material.Metal, Parent = parent })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromHex("FFD6D6")
	light.Range = 8
	light.Brightness = 1
	light.Parent = cap
end

local DECOR: { (shop: Shop, folder: Folder) -> () } = {
	-- 1: duża palma przy wejściu (jak na zdjęciu) i mniejsza po drugiej stronie
	function(shop, folder)
		buildPalm(shop, folder, Vector3.new(-16.5, FLOOR_Y, 3.5), 1.2, shop.index)
		buildPalm(shop, folder, Vector3.new(16.5, FLOOR_Y, 3), 0.8, shop.index + 7)
	end,
	-- 2: galeria obrazków na tylnej ścianie i ławka dla czekających
	function(shop, folder)
		local rng = Random.new(shop.index * 13)
		local art = { C.Red, C.Blue, C.Gold, C.Leaf, Color3.fromHex("E8D9C4"), C.Charcoal }
		for row = 0, 1 do
			for col = 0, 2 do
				local x = -13 + col * 3.6
				local y = FLOOR_Y + 6.5 + row * 3.4
				box(shop, folder, "Frame", Vector3.new(3, 2.8, 0.2), Vector3.new(x, y, BACK_Z - 0.1), C.Black, { Studs = false })
				box(shop, folder, "Art", Vector3.new(2.4, 2.2, 0.1), Vector3.new(x, y, BACK_Z - 0.25), art[rng:NextInteger(1, #art)], { Studs = false })
			end
		end
		box(shop, folder, "BenchSeat", Vector3.new(7, 0.6, 2), Vector3.new(-9, FLOOR_Y + 1.6, 2.4), C.Black)
		box(shop, folder, "BenchBack", Vector3.new(7, 2, 0.5), Vector3.new(-9, FLOOR_Y + 2.9, 1.5), C.Black, { Studs = false })
		for _, dx in { -3, 3 } do
			box(shop, folder, "BenchLeg", Vector3.new(0.4, 1.3, 1.6), Vector3.new(-9 + dx, FLOOR_Y + 0.65, 2.4), C.Chrome, { Studs = false, Material = Enum.Material.Metal })
		end
	end,
	-- 3: słupki fryzjerskie przy wejściu i neon OPEN w witrynie
	function(shop, folder)
		buildBarberPole(folder, shop.origin * CFrame.new(-5.2, FLOOR_Y - 0.6, -0.9), 6)
		buildBarberPole(folder, shop.origin * CFrame.new(5.2, FLOOR_Y - 0.6, -0.9), 6)
		local open = box(shop, folder, "OpenSign", Vector3.new(4, 1.6, 0.2), Vector3.new(9, FLOOR_Y + 6, 1), C.Black, { Studs = false, CanCollide = false })
		Blocks.label(open, Enum.NormalId.Front, "OPEN", Color3.fromHex("FF5A5A"), Blocks.Font)
	end,
	-- 4: regał z kosmetykami na tylnej ścianie i szachownica w przejściu
	function(shop, folder)
		local rng = Random.new(shop.index * 31)
		box(shop, folder, "DisplayBack", Vector3.new(10, 8, 0.4), Vector3.new(10, FLOOR_Y + 5, BACK_Z - 0.2), C.Wood, { Studs = false })
		for i = 0, 3 do
			local y = FLOOR_Y + 2 + i * 1.9
			box(shop, folder, "DisplayShelf", Vector3.new(10, 0.25, 1.4), Vector3.new(10, y, BACK_Z - 0.9), C.WoodDark)
			buildBottles(shop, folder, Vector3.new(5.7, y + 0.12, BACK_Z - 0.9), Vector3.new(0.75, 0, 0), 12, rng)
		end
		for gx = 0, 3 do
			for gz = 0, 11 do
				local color = if (gx + gz) % 2 == 0 then C.Charcoal else C.WallWhite
				box(shop, folder, "Tile", Vector3.new(2, 0.08, 2), Vector3.new(-3 + gx * 2, FLOOR_Y + 0.04, 6 + gz * 2), color, {
					Studs = false,
					CanCollide = false,
				})
			end
		end
	end,
	-- 5: premium — złote wykończenia, ciepłe neonowe listwy, więcej zieleni
	function(shop, folder)
		box(shop, folder, "GoldTrimTop", Vector3.new(27, 0.4, 0.5), Vector3.new(0, 14.7, -0.5), C.Gold, { Studs = false, Material = Enum.Material.Foil })
		box(shop, folder, "GoldTrimBottom", Vector3.new(27, 0.4, 0.5), Vector3.new(0, 11.3, -0.5), C.Gold, { Studs = false, Material = Enum.Material.Foil })
		for _, sx in { -1, 1 } do
			box(shop, folder, "NeonStrip", Vector3.new(0.2, 0.2, 30), Vector3.new(sx * (HALF_WIDTH - 0.15), CEILING_Y - 0.5, 16.5), C.Warm, {
				Studs = false,
				Material = Enum.Material.Neon,
				CastShadow = false,
			})
		end
		buildPalm(shop, folder, Vector3.new(-17, FLOOR_Y, 30), 1, shop.index + 19)
		buildPalm(shop, folder, Vector3.new(17, FLOOR_Y, 30), 1, shop.index + 23)
	end,
}

ShopBuilder.MaxDecor = #DECOR

function ShopBuilder.build(index: number, origin: CFrame, parent: Instance): Shop
	local model = Blocks.model(`Shop{index}`, parent)
	local shop: Shop = {
		index = index,
		origin = origin,
		model = model,
		stationsFolder = Blocks.folder("Stations", model),
		decorFolder = Blocks.folder("Decor", model),
		signLabel = nil :: any,
		stations = {},
		decorLevel = 0,
		doorOutside = (origin * CFrame.new(0, 0.4, -6)).Position,
		doorInside = (origin * CFrame.new(0, FLOOR_Y, 4)).Position,
		spawnCFrame = origin * CFrame.new(0, FLOOR_Y + 3, -7) * CFrame.Angles(0, math.pi, 0),
	}
	buildShell(shop)
	return shop
end

function ShopBuilder.setOwner(shop: Shop, ownerName: string?)
	shop.signLabel.Text = if ownerName then `{ownerName}'s Barber Shop` else "WOLNY LOKAL"
end

-- Dobudowuje brakujące stanowiska (nie przebudowuje istniejących).
function ShopBuilder.ensureStations(shop: Shop, count: number)
	for index = #shop.stations + 1, math.min(count, #STATION_SLOTS) do
		shop.stations[index] = buildStation(shop, index)
	end
end

function ShopBuilder.ensureDecor(shop: Shop, level: number)
	for i = shop.decorLevel + 1, math.min(level, #DECOR) do
		DECOR[i](shop, Blocks.folder(`Level{i}`, shop.decorFolder))
	end
	shop.decorLevel = math.max(shop.decorLevel, math.min(level, #DECOR))
end

-- Usuwa stanowiska i wystrój (np. po rebirthcie albo wyjściu właściciela).
function ShopBuilder.reset(shop: Shop)
	shop.stationsFolder:ClearAllChildren()
	shop.decorFolder:ClearAllChildren()
	table.clear(shop.stations)
	shop.decorLevel = 0
end

return ShopBuilder
