--!strict
-- Pula płynności typu constant product (x * y = k), jak w pump.fun / Raydium.
-- Klient używa tych samych wzorów do podglądu, serwer do faktycznego wykonania transakcji.

local Config = require(script.Parent.Config)

export type Pool = { Rx: number, Tokens: number }

local FEE = Config.FeeBps / 10_000

local Amm = {}

-- Cena jednego tokena w RX.
function Amm.price(pool: Pool): number
	return pool.Rx / pool.Tokens
end

function Amm.marketCapUsd(pool: Pool): number
	return Amm.price(pool) * Config.TotalSupply * Config.UsdPerRx
end

function Amm.liquidityUsd(pool: Pool): number
	return 2 * pool.Rx * Config.UsdPerRx
end

-- Ile tokenów dostaje kupujący za `rxIn` (po prowizji).
function Amm.buyQuote(pool: Pool, rxIn: number): number
	local net = rxIn * (1 - FEE)
	return pool.Tokens * net / (pool.Rx + net)
end

-- Ile RX dostaje sprzedający za `tokensIn` (po prowizji).
function Amm.sellQuote(pool: Pool, tokensIn: number): number
	local gross = pool.Rx * tokensIn / (pool.Tokens + tokensIn)
	return gross * (1 - FEE)
end

-- Wykonuje kupno na puli i zwraca liczbę tokenów.
function Amm.applyBuy(pool: Pool, rxIn: number): number
	local net = rxIn * (1 - FEE)
	local out = pool.Tokens * net / (pool.Rx + net)
	pool.Rx += net
	pool.Tokens -= out
	return out
end

-- Wykonuje sprzedaż na puli i zwraca RX po prowizji.
function Amm.applySell(pool: Pool, tokensIn: number): number
	local gross = pool.Rx * tokensIn / (pool.Tokens + tokensIn)
	pool.Tokens += tokensIn
	pool.Rx -= gross
	return gross * (1 - FEE)
end

-- Zmiana ceny (w %) spowodowana transakcją; dodatnia dla kupna, ujemna dla sprzedaży.
function Amm.priceImpact(pool: Pool, side: "Buy" | "Sell", amount: number): number
	local copy = { Rx = pool.Rx, Tokens = pool.Tokens }
	if side == "Buy" then
		Amm.applyBuy(copy, amount)
	else
		Amm.applySell(copy, amount)
	end
	return (Amm.price(copy) / Amm.price(pool) - 1) * 100
end

return table.freeze(Amm)
