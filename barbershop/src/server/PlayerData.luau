--!strict
-- Dane gracza: kasa, liczba ostrzyżonych klientów, rebirthy i poziomy ulepszeń.
-- Zapis w DataStore; w Studio bez dostępu do API gra działa dalej, tylko bez zapisu.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

export type Data = {
	cash: number,
	shaved: number,
	rebirths: number,
	upgrades: { [string]: number },
	-- Index: ile razy ostrzyżono każdą fryzurę (przetrwa rebirth).
	styles: { [string]: number },
}

type Entry = {
	data: Data,
	-- false, gdy wczytanie się nie udało: wtedy nie nadpisujemy zapisu domyślnymi danymi.
	canSave: boolean,
	stats: { cash: NumberValue, shaved: IntValue, rebirths: IntValue },
}

local PlayerData = {}

local entries: { [Player]: Entry } = {}

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.SaveKey)
	end)
	if ok then
		store = result
	else
		warn("[BarberShop] DataStore niedostępny, postęp nie będzie zapisywany:", result)
	end
end

local function defaults(): Data
	return { cash = 0, shaved = 0, rebirths = 0, upgrades = {}, styles = {} }
end

local function sanitize(raw: any): Data
	local data = defaults()
	if type(raw) ~= "table" then
		return data
	end
	data.cash = if type(raw.cash) == "number" then math.max(0, raw.cash) else 0
	data.shaved = if type(raw.shaved) == "number" then raw.shaved else 0
	data.rebirths = if type(raw.rebirths) == "number" then raw.rebirths else 0
	if type(raw.upgrades) == "table" then
		for _, def in Config.Upgrades do
			local level = raw.upgrades[def.id]
			if type(level) == "number" then
				data.upgrades[def.id] = math.clamp(math.floor(level), 0, def.max)
			end
		end
	end
	if type(raw.styles) == "table" then
		for _, style in Config.Styles do
			local count = raw.styles[style.id]
			if type(count) == "number" then
				data.styles[style.id] = math.max(0, math.floor(count))
			end
		end
	end
	return data
end

local function key(player: Player): string
	return `player_{player.UserId}`
end

local function stat(className: string, name: string, parent: Instance): any
	local value = Instance.new(className)
	value.Name = name
	value.Parent = parent
	return value
end

function PlayerData.load(player: Player): Data
	local raw, canSave = nil, store ~= nil
	if store then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return store:GetAsync(key(player))
			end)
			if ok then
				raw = result
				break
			elseif attempt == 3 then
				warn("[BarberShop] Nie udało się wczytać danych", player.Name, result)
				canSave = false
			else
				task.wait(1)
			end
		end
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local entry: Entry = {
		data = sanitize(raw),
		canSave = canSave,
		stats = {
			cash = stat("NumberValue", "Kasa", leaderstats),
			shaved = stat("IntValue", "Klienci", leaderstats),
			rebirths = stat("IntValue", "Rebirth", leaderstats),
		},
	}
	leaderstats.Parent = player
	entries[player] = entry
	PlayerData.sync(player)
	return entry.data
end

function PlayerData.get(player: Player): Data?
	local entry = entries[player]
	return if entry then entry.data else nil
end

-- Przepisuje dane do leaderstats i atrybutów gracza (z nich czyta UI klienta).
function PlayerData.sync(player: Player)
	local entry = entries[player]
	if not entry then
		return
	end
	local data = entry.data
	entry.stats.cash.Value = data.cash
	entry.stats.shaved.Value = data.shaved
	entry.stats.rebirths.Value = data.rebirths
	player:SetAttribute("Cash", data.cash)
	player:SetAttribute("Shaved", data.shaved)
	player:SetAttribute("Rebirths", data.rebirths)
	for _, def in Config.Upgrades do
		player:SetAttribute(`Lvl_{def.id}`, data.upgrades[def.id] or 0)
	end
	for _, style in Config.Styles do
		player:SetAttribute(`Style_{style.id}`, data.styles[style.id] or 0)
	end
end

function PlayerData.addCash(player: Player, amount: number)
	local entry = entries[player]
	if entry and amount > 0 then
		entry.data.cash += amount
		PlayerData.sync(player)
	end
end

function PlayerData.save(player: Player)
	local entry = entries[player]
	if not (entry and entry.canSave and store) then
		return
	end
	local snapshot = table.clone(entry.data)
	snapshot.upgrades = table.clone(entry.data.upgrades)
	snapshot.styles = table.clone(entry.data.styles)
	local ok, err = pcall(function()
		store:UpdateAsync(key(player), function()
			return snapshot
		end)
	end)
	if not ok then
		warn("[BarberShop] Zapis nieudany", player.Name, err)
	end
end

function PlayerData.release(player: Player)
	PlayerData.save(player)
	entries[player] = nil
end

function PlayerData.start()
	task.spawn(function()
		while true do
			task.wait(60)
			for player in entries do
				task.spawn(PlayerData.save, player)
			end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				PlayerData.save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return PlayerData
