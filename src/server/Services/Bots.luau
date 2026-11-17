--!strict
-- Boty symulujące innych traderów, żeby rynek żył także przy kilku graczach na serwerze.
-- Każdy coin ma "sentyment" (losowy spacer z wygaszaniem) i słabe przyciąganie do ceny startowej,
-- dzięki czemu ceny pompują i zrzucają, ale nie uciekają w nieskończoność.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Amm = require(ReplicatedStorage.Shared.Amm)
local Config = require(ReplicatedStorage.Shared.Config)
local Market = require(script.Parent.Market)

local BASE58 = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

local Bots = {}

local rng = Random.new()
local sentiment: { [string]: number } = {}

local function walletName(): string
	local function part(n: number): string
		local chars = table.create(n)
		for i = 1, n do
			local index = rng:NextInteger(1, #BASE58)
			chars[i] = string.sub(BASE58, index, index)
		end
		return table.concat(chars)
	end
	return part(4) .. "..." .. part(4)
end

local function stepCoin(ticker: string, state: Market.CoinState, dt: number, t: number)
	local s = sentiment[ticker] or 0
	s = s * (1 - 0.06 * dt) + rng:NextNumber(-1, 1) * 0.12 * math.sqrt(dt)
	-- Rzadkie gwałtowne zwroty: pompa albo dump.
	if rng:NextNumber() < dt / 240 then
		s += if rng:NextNumber() < 0.55 then 0.35 else -0.35
	end
	s = math.clamp(s, -0.45, 0.45)
	sentiment[ticker] = s

	if rng:NextNumber() >= state.Def.Activity * dt then
		return
	end

	local pool = state.Pool
	local reversion = math.clamp(0.2 * math.log(state.InitialPrice / Amm.price(pool)), -0.35, 0.35)
	local buyChance = math.clamp(0.5 + s + reversion, 0.08, 0.92)
	-- Rozkład z długim ogonem: zwykle małe transakcje, czasem wieloryb. Duże coiny ruszają się spokojniej.
	local calm = math.clamp(1 - math.log10(state.Def.MarketCap / 1e4) * 0.22, 0.25, 1)
	local size = pool.Rx * (0.0006 + rng:NextNumber() ^ 3 * 0.015) * calm

	if rng:NextNumber() < buyChance then
		Market.executeBuy(ticker, size, walletName(), false, t)
	else
		local tokens = pool.Tokens * size / (pool.Rx - size)
		Market.executeSell(ticker, tokens, walletName(), false, t)
	end
end

function Bots.step(dt: number, t: number)
	for ticker, state in Market.all() do
		if t >= state.LaunchedAt then
			stepCoin(ticker, state, dt, t)
		end
	end
end

-- Symuluje ostatnią godzinę handlu (lub krócej, jeśli coin jest młodszy).
function Bots.warmup()
	local finish = Market.now()
	local start = finish - Config.WarmupSeconds
	local step = 0.5
	Market.setBroadcasting(false)
	local t = start
	while t < finish do
		Bots.step(step, t)
		Market.tick(t)
		t += step
	end
	Market.setBroadcasting(true)
end

return Bots
