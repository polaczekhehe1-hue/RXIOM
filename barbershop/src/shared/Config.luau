--!strict
-- Balans gry. Serwer używa tych wzorów do walidacji, klient do wyświetlania cen i efektów.

export type UpgradeDef = {
	id: string,
	name: string,
	icon: string,
	description: string,
	max: number,
	cost: (level: number) -> number,
	-- Efekt na danym poziomie, np. "+3 / włos".
	effect: (level: number) -> string,
}

local Config = {}

-- Rozmiar jednego woksela włosów; głowa klienta ma 2×2×2 studsy.
Config.VoxelSize = 0.5
Config.MaxChairs = 6
Config.SaveKey = "BarberShop_v1"

local function geometric(base: number, growth: number): (number) -> number
	return function(level: number): number
		return math.floor(base * growth ^ level)
	end
end

local function steps(list: { number }): (number) -> number
	return function(level: number): number
		return list[level + 1] or math.huge
	end
end

-- Kolejność na liście = kolejność w sklepie z ulepszeniami.
Config.Upgrades = {
	{
		id = "clippers",
		name = "Clippers",
		icon = "✂️",
		description = "Every hair you shave gives +1 more coin.",
		max = 100,
		cost = geometric(30, 1.45),
		effect = function(level: number): string
			return `+{1 + level} / hair`
		end,
	},
	{
		id = "chairs",
		name = "Chairs",
		icon = "💺",
		description = "A new station: serve more customers at once.",
		max = Config.MaxChairs - 1,
		cost = geometric(60, 3.2),
		effect = function(level: number): string
			return `{1 + level} chair(s)`
		end,
	},
	{
		id = "brush",
		name = "Wide Trimmer",
		icon = "🪒",
		description = "Shave several hairs with one swipe.",
		max = 3,
		cost = steps({ 250, 2500, 25000 }),
		effect = function(level: number): string
			return if level == 0 then "1 hair" else `radius {level}`
		end,
	},
	{
		id = "decor",
		name = "Decor",
		icon = "🪴",
		description = "A nicer shop: customers come more often and tip more.",
		max = 5,
		cost = geometric(120, 4),
		effect = function(level: number): string
			return `level {level}`
		end,
	},
	{
		id = "hair",
		name = "Bushy Hair",
		icon = "💇",
		description = "Customers come in with more hair to shave.",
		max = 3,
		cost = geometric(400, 5),
		effect = function(level: number): string
			return `+{level} layer(s)`
		end,
	},
	{
		id = "helper",
		name = "Helper",
		icon = "👷",
		description = "A hired barber shaves customers for you every second.",
		max = 10,
		cost = geometric(750, 2.1),
		effect = function(level: number): string
			return `{level} hair/s`
		end,
	},
} :: { UpgradeDef }

Config.UpgradeById = {} :: { [string]: UpgradeDef }
for _, def in Config.Upgrades do
	Config.UpgradeById[def.id] = def
end

export type Levels = { [string]: number }

local function level(levels: Levels, id: string): number
	return levels[id] or 0
end

-- Mnożnik z rebirthów: 0 → ×1, 1 → ×2, ...
function Config.multiplier(rebirths: number): number
	return 1 + rebirths
end

-- Rdzeń mechaniki +1: każdy zgolony woksel to +1 (razy ulepszenia i rebirthy).
function Config.perVoxel(levels: Levels, rebirths: number): number
	return (1 + level(levels, "clippers")) * Config.multiplier(rebirths)
end

function Config.chairCount(levels: Levels): number
	return math.min(1 + level(levels, "chairs"), Config.MaxChairs)
end

-- Promień pędzla w wokselach (0 = pojedynczy włos).
function Config.brushRadius(levels: Levels): number
	return level(levels, "brush")
end

function Config.extraHairLayers(levels: Levels): number
	return level(levels, "hair")
end

function Config.helperRate(levels: Levels): number
	return level(levels, "helper")
end

-- Sekundy między kolejnymi klientami.
function Config.spawnInterval(levels: Levels): number
	return math.max(1.5, 6 - level(levels, "decor"))
end

-- Napiwek za skończone strzyżenie, zależny od liczby włosów i wystroju.
function Config.tip(levels: Levels, rebirths: number, hairCount: number): number
	local rate = 0.2 + 0.15 * level(levels, "decor")
	return math.floor(hairCount * Config.perVoxel(levels, rebirths) * rate)
end

function Config.rebirthCost(rebirths: number): number
	return math.floor(25000 * 4 ^ rebirths)
end

return Config
