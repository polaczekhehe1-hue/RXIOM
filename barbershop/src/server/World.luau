--!strict
-- Mapa: trawa, plac na środku z wielkim słupkiem fryzjerskim i 6 działek z salonami dookoła.

local Blocks = require(script.Parent.Blocks)
local ShopBuilder = require(script.Parent.ShopBuilder)

local World = {}

local PLOT_COUNT = 6
local PLOT_RADIUS = 70

local GRASS = Color3.fromHex("6DB24F")
local STONE = Color3.fromHex("CFCBC2")
local STONE_DARK = Color3.fromHex("B5B0A6")
local PATH = Color3.fromHex("BDBAB3")

local function tree(parent: Instance, at: Vector3, rng: Random)
	local base = CFrame.new(at)
	local height = rng:NextNumber(5, 7)
	Blocks.part({ Name = "Trunk", Size = Vector3.new(1.6, height, 1.6), CFrame = base * CFrame.new(0, height / 2, 0), Color = Color3.fromHex("7A5236"), Parent = parent })
	local greens = { Color3.fromHex("3F8F45"), Color3.fromHex("4FA54F"), Color3.fromHex("2E6B34") }
	Blocks.part({ Name = "Leaves", Size = Vector3.new(7, 4, 7), CFrame = base * CFrame.new(0, height + 1.5, 0), Color = greens[rng:NextInteger(1, 3)], Parent = parent })
	Blocks.part({ Name = "Leaves", Size = Vector3.new(4.5, 3, 4.5), CFrame = base * CFrame.new(0, height + 5, 0), Color = greens[rng:NextInteger(1, 3)], Parent = parent })
end

local function lamp(parent: Instance, at: CFrame)
	Blocks.part({ Name = "LampBase", Size = Vector3.new(1.4, 0.6, 1.4), CFrame = at * CFrame.new(0, 0.3, 0), Color = Color3.fromHex("1C1C1F"), Parent = parent })
	Blocks.part({ Name = "LampPost", Size = Vector3.new(0.5, 9, 0.5), CFrame = at * CFrame.new(0, 5, 0), Color = Color3.fromHex("1C1C1F"), Parent = parent, Studs = false })
	local bulb = Blocks.part({ Name = "LampBulb", Size = Vector3.new(1.2, 1.2, 1.2), CFrame = at * CFrame.new(0, 10, 0), Color = Color3.fromHex("FFE6B0"), Material = Enum.Material.Neon, Parent = parent, Studs = false })
	local light = Instance.new("PointLight")
	light.Range = 14
	light.Brightness = 0.8
	light.Color = Color3.fromHex("FFE6B0")
	light.Parent = bulb
end

local function plaza(parent: Instance)
	-- Szachownica z płyt, jak posadzka w starym zakładzie fryzjerskim.
	local size, tile = 48, 6
	local n = size // tile
	for x = 0, n - 1 do
		for z = 0, n - 1 do
			Blocks.part({
				Name = "PlazaTile",
				Size = Vector3.new(tile, 0.4, tile),
				CFrame = CFrame.new(-size / 2 + tile / 2 + x * tile, 0.2, -size / 2 + tile / 2 + z * tile),
				Color = if (x + z) % 2 == 0 then STONE else STONE_DARK,
				Parent = parent,
			})
		end
	end

	-- Wielki słupek fryzjerski na środku placu.
	local colors = { Color3.fromHex("D93B3B"), Color3.fromHex("F1F0EC"), Color3.fromHex("2F5FD0"), Color3.fromHex("F1F0EC") }
	Blocks.part({ Name = "Pedestal", Size = Vector3.new(6, 1.5, 6), CFrame = CFrame.new(0, 1.15, 0), Color = Color3.fromHex("2B2C30"), Parent = parent })
	for i = 0, 15 do
		Blocks.part({
			Name = "Pole",
			Size = Vector3.new(3, 1, 3),
			CFrame = CFrame.new(0, 2.4 + i, 0) * CFrame.Angles(0, math.rad(i * 12), 0),
			Color = colors[i % 4 + 1],
			Parent = parent,
			Studs = false,
		})
	end
	local cap = Blocks.part({ Name = "PoleCap", Size = Vector3.new(4, 1, 4), CFrame = CFrame.new(0, 18.4, 0), Color = Color3.fromHex("C3C8CC"), Material = Enum.Material.Metal, Parent = parent })
	local light = Instance.new("PointLight")
	light.Range = 20
	light.Brightness = 1.5
	light.Color = Color3.fromHex("FFE0E0")
	light.Parent = cap

	-- Tablica z nazwą gry nad placem.
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(26, 6)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.LightInfluence = 0
	billboard.MaxDistance = 250
	billboard.Parent = cap
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 1)
	title.FontFace = Blocks.Font
	title.Text = "+1 BARBER SHOP"
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Parent = billboard
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromHex("1C1C1F")
	stroke.Parent = title

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 0.4, 8)
	spawn.CFrame = CFrame.new(0, 0.6, 14)
	spawn.Color = STONE
	spawn.Material = Enum.Material.Plastic
	spawn.TopSurface = Enum.SurfaceType.Studs
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = parent
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
end

-- Zwraca zbudowane salony (na razie bez właścicieli).
function World.build(): { ShopBuilder.Shop }
	local map = Blocks.folder("Map", workspace)
	local shopsFolder = Blocks.folder("Shops", workspace)

	Blocks.part({ Name = "Grass", Size = Vector3.new(600, 2, 600), CFrame = CFrame.new(0, -1, 0), Color = GRASS, Parent = map })
	plaza(map)

	local rng = Random.new(42)
	local shops = {}
	for i = 1, PLOT_COUNT do
		local angle = (i - 1) / PLOT_COUNT * math.pi * 2
		local dir = Vector3.new(math.sin(angle), 0, math.cos(angle))
		local front = dir * PLOT_RADIUS
		local origin = CFrame.lookAt(front, Vector3.zero)
		shops[i] = ShopBuilder.build(i, origin, shopsFolder)

		-- Ścieżka z placu do salonu z latarniami po bokach.
		local pathStart, pathEnd = dir * 24, dir * (PLOT_RADIUS - 10)
		local length = (pathEnd - pathStart).Magnitude
		-- Ścieżka zaczyna się pod płytami placu, więc jest niższa od nich (0.3 vs 0.4), żeby nie migotała.
		local pathCF = CFrame.lookAt((pathStart + pathEnd) / 2, pathEnd) + Vector3.new(0, 0.15, 0)
		Blocks.part({ Name = "Path", Size = Vector3.new(8, 0.3, length), CFrame = pathCF, Color = PATH, Parent = map })
		for _, side in { -1, 1 } do
			lamp(map, CFrame.new(pathCF.Position + pathCF.RightVector * side * 5.5 - Vector3.new(0, 0.15, 0)))
		end

		-- Drzewa pomiędzy działkami.
		local between = angle + math.pi / PLOT_COUNT
		for _, r in { 55, 95 } do
			local jitter = Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
			tree(map, Vector3.new(math.sin(between), 0, math.cos(between)) * r + jitter, rng)
		end
	end
	return shops
end

return World
