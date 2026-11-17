--!strict
-- Coiny dostępne na rynku. Nazwy to zaślepki do podmiany na docelową listę.
-- MarketCap i Liquidity (w $) wyznaczają startową pulę płynności; Activity to średnia liczba
-- transakcji botów na sekundę.

export type CoinDef = {
	Ticker: string,
	Name: string,
	Color: Color3,
	Age: number,
	MarketCap: number,
	Liquidity: number,
	Holders: number,
	Activity: number,
}

local MINUTE, DAY = 60, 86400

local function coin(
	ticker: string,
	name: string,
	hex: string,
	age: number,
	marketCap: number,
	liquidity: number,
	holders: number,
	activity: number
): CoinDef
	return table.freeze({
		Ticker = ticker,
		Name = name,
		Color = Color3.fromHex(hex),
		Age = age,
		MarketCap = marketCap,
		Liquidity = liquidity,
		Holders = holders,
		Activity = activity,
	})
end

local List: { CoinDef } = {
	coin("COIN1", "Placeholder One", "F5C542", 38 * MINUTE, 117_000, 14_200, 1082, 1.4),
	coin("COIN2", "Placeholder Two", "526FFF", 10 * MINUTE, 30_300, 7_030, 200, 1.1),
	coin("COIN3", "Placeholder Three", "2FE3AC", 22 * DAY, 14_500_000, 213_000, 31281, 0.8),
	coin("COIN4", "Placeholder Four", "EC397A", 1 * MINUTE, 14_000, 3_540, 237, 1.6),
	coin("COIN5", "Placeholder Five", "A855F7", 90 * DAY, 12_400_000, 241_000, 80492, 0.6),
	coin("COIN6", "Placeholder Six", "F7931A", 4 * MINUTE, 26_800, 5_790, 386, 1.8),
	coin("COIN7", "Placeholder Seven", "38BDF8", 2 * MINUTE, 9_600, 2_550, 226, 1.2),
	coin("COIN8", "Placeholder Eight", "84CC16", 3 * MINUTE, 11_900, 3_100, 150, 1.0),
}

local ByTicker: { [string]: CoinDef } = {}
for _, def in List do
	ByTicker[def.Ticker] = def
end

return table.freeze({
	List = table.freeze(List),
	ByTicker = table.freeze(ByTicker),
})
