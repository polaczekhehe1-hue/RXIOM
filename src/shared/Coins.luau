--!strict
-- Tymczasowe coiny do podglądu UI. Zostaną podmienione na docelową listę nazw.

export type Coin = {
	Ticker: string,
	Name: string,
	Color: Color3,
	AgeText: string,
	MarketCap: number,
	Change: number,
	Liquidity: number,
	Volume: number,
	Buys: number,
	Sells: number,
	Holders: number,
}

local function coin(
	ticker: string,
	name: string,
	hex: string,
	age: string,
	mc: number,
	change: number,
	liq: number,
	vol: number,
	buys: number,
	sells: number,
	holders: number
): Coin
	return table.freeze({
		Ticker = ticker,
		Name = name,
		Color = Color3.fromHex(hex),
		AgeText = age,
		MarketCap = mc,
		Change = change,
		Liquidity = liq,
		Volume = vol,
		Buys = buys,
		Sells = sells,
		Holders = holders,
	})
end

local Coins: { Coin } = {
	coin("COIN1", "Placeholder One", "F5C542", "38m", 117_000, 21.73, 14_200, 68_200, 878, 610, 1082),
	coin("COIN2", "Placeholder Two", "526FFF", "10m", 30_300, 289.5, 7_030, 42_600, 366, 396, 200),
	coin("COIN3", "Placeholder Three", "2FE3AC", "22d", 14_500_000, 1.67, 213_000, 14_800, 103, 108, 31281),
	coin("COIN4", "Placeholder Four", "EC397A", "1m", 14_000, 538.1, 3_540, 50_100, 842, 601, 237),
	coin("COIN5", "Placeholder Five", "A855F7", "3mo", 12_400_000, -4.21, 241_000, 22_400, 267, 138, 80492),
	coin("COIN6", "Placeholder Six", "F7931A", "4m", 26_800, 692.5, 5_790, 262_000, 2990, 2760, 386),
	coin("COIN7", "Placeholder Seven", "38BDF8", "2m", 9_600, 336.8, 2_550, 56_900, 967, 709, 226),
	coin("COIN8", "Placeholder Eight", "84CC16", "3m", 11_900, -12.4, 3_100, 24_400, 413, 236, 150),
}

return table.freeze(Coins)
