--!strict
-- Profile graczy (saldo RX i pozycje) z zapisem w DataStore.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Coins = require(ReplicatedStorage.Shared.Coins)
local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Types = require(ReplicatedStorage.Shared.Types)

export type Profile = {
	Balance: number,
	Positions: { [string]: Types.Position },
	FaucetReadyAt: number,
}

local STORE_NAME = "RXIOM_Profiles_v1"
local AUTOSAVE_SECONDS = 60

local PlayerData = {}
PlayerData.Loaded = Signal.new() -- (player)

local profiles: { [Player]: Profile } = {}
-- Profil, którego nie udało się wczytać, nie jest zapisywany, żeby nie nadpisać prawdziwych danych.
local saveable: { [Player]: boolean } = {}

local store: DataStore? = nil
do
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, STORE_NAME)
	if ok then
		store = result
	else
		warn("[RXIOM] DataStore unavailable, progress will not be saved:", result)
	end
end

local function key(player: Player): string
	return "u_" .. player.UserId
end

local function finite(v: any): boolean
	return typeof(v) == "number" and v == v and math.abs(v) ~= math.huge
end

local function defaultProfile(): Profile
	return { Balance = Config.StartingBalance, Positions = {}, FaucetReadyAt = 0 }
end

local function sanitize(data: any): Profile
	if typeof(data) ~= "table" or not finite(data.Balance) then
		return defaultProfile()
	end
	local profile: Profile = {
		Balance = math.max(0, data.Balance),
		Positions = {},
		FaucetReadyAt = if finite(data.FaucetReadyAt) then data.FaucetReadyAt else 0,
	}
	if typeof(data.Positions) == "table" then
		for ticker, p in data.Positions do
			if
				Coins.ByTicker[ticker]
				and typeof(p) == "table"
				and finite(p.Tokens)
				and finite(p.BoughtRx)
				and finite(p.SoldRx)
				and p.Tokens > Config.DustTokens
			then
				local fills = {}
				if typeof(p.Fills) == "table" then
					for _, f in p.Fills do
						if
							typeof(f) == "table"
							and finite(f.T)
							and (f.Side == "Buy" or f.Side == "Sell")
							and finite(f.Price)
							and finite(f.Tokens)
						then
							table.insert(fills, { T = f.T, Side = f.Side, Price = f.Price, Tokens = f.Tokens })
						end
					end
				end
				while #fills > Config.MaxFills do
					table.remove(fills, 1)
				end
				profile.Positions[ticker] = {
					Tokens = p.Tokens,
					BoughtRx = p.BoughtRx,
					SoldRx = p.SoldRx,
					BuyTokens = if finite(p.BuyTokens) then p.BuyTokens else 0,
					BuyValue = if finite(p.BuyValue) then p.BuyValue else 0,
					Fills = fills,
				}
			end
		end
	end
	return profile
end

local function load(player: Player)
	local data: any = nil
	local ok = false
	if store then
		local attempts = if RunService:IsStudio() then 1 else 3
		for attempt = 1, attempts do
			local success, result = pcall(store.GetAsync, store, key(player))
			if success then
				data, ok = result, true
				break
			end
			warn(`[RXIOM] Failed to load data for {player.Name} (attempt {attempt}):`, result)
			if attempt < attempts then
				task.wait(attempt)
			end
		end
	end
	if player.Parent == nil then
		return
	end
	profiles[player] = sanitize(data)
	saveable[player] = ok
	if not ok then
		warn(`[RXIOM] Using a temporary profile for {player.Name}; it will not be saved.`)
	end
	PlayerData.Loaded:Fire(player)
end

local function save(player: Player)
	local profile = profiles[player]
	if not profile or not saveable[player] or not store then
		return
	end
	local payload = {
		Balance = profile.Balance,
		Positions = profile.Positions,
		FaucetReadyAt = profile.FaucetReadyAt,
	}
	local ok, err = pcall(store.UpdateAsync, store, key(player), function()
		return payload
	end)
	if not ok then
		warn(`[RXIOM] Failed to save data for {player.Name}:`, err)
	end
end

function PlayerData.get(player: Player): Profile?
	return profiles[player]
end

function PlayerData.countHolders(ticker: string): number
	local count = 0
	for _, profile in profiles do
		local position = profile.Positions[ticker]
		if position and position.Tokens > Config.DustTokens then
			count += 1
		end
	end
	return count
end

-- Zapisuje i usuwa profil gracza opuszczającego grę.
function PlayerData.release(player: Player)
	save(player)
	profiles[player] = nil
	saveable[player] = nil
end

function PlayerData.saveAll()
	local threads = 0
	for player in profiles do
		threads += 1
		task.spawn(function()
			save(player)
			threads -= 1
		end)
	end
	local deadline = os.clock() + 25
	while threads > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end

function PlayerData.start()
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for player in profiles do
				task.spawn(save, player)
			end
		end
	end)
end

return PlayerData
