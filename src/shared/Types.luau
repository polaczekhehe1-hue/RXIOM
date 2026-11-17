--!strict
-- Struktury danych przesyłane między serwerem a klientem.

export type Side = "Buy" | "Sell"

export type TimeframeStats = {
	Volume: number, -- $
	Buys: number,
	Sells: number,
	Change: number, -- %
}

-- Świeca: ceny w RX za token; T to początek okresu (czas serwera).
export type Candle = { T: number, O: number, H: number, L: number, C: number }

export type CoinSnapshot = {
	Ticker: string,
	Price: number,
	PoolRx: number,
	PoolTokens: number,
	MarketCap: number,
	Liquidity: number,
	Holders: number,
	LaunchedAt: number,
	Stats: { [string]: TimeframeStats },
	Candle: Candle,
	Spark: { number },
}

export type TradeEvent = {
	Ticker: string,
	Side: Side,
	Rx: number,
	Tokens: number,
	MarketCap: number,
	Trader: string,
	IsPlayer: boolean,
	Time: number,
}

export type MarketSnapshot = {
	Time: number,
	Coins: { [string]: CoinSnapshot },
	Trades: { TradeEvent },
}

-- Wykonana transakcja gracza; Price to średnia cena wykonania (RX za token) bez prowizji.
export type Fill = {
	T: number,
	Side: Side,
	Price: number,
	Tokens: number,
}

-- BuyTokens/BuyValue liczą średnią cenę wejścia (BuyValue / BuyTokens) dla bieżącej pozycji.
export type Position = {
	Tokens: number,
	BoughtRx: number,
	SoldRx: number,
	BuyTokens: number,
	BuyValue: number,
	Fills: { Fill },
}

-- Zlecenie z warunkiem na market cap ($). Above/Below: wykonaj, gdy MC >= Above lub MC <= Below.
-- Środki są rezerwowane przy złożeniu: Rx + Fees dla kupna, Tokens dla sprzedaży.
export type LimitOrder = {
	Id: number,
	Ticker: string,
	Side: Side,
	Rx: number,
	Tokens: number,
	Fees: number,
	Above: number?,
	Below: number?,
	CreatedAt: number,
}

export type PortfolioState = {
	Balance: number,
	Positions: { [string]: Position },
	Orders: { LimitOrder },
	FaucetReadyAt: number,
}

-- Amount: RX przy kupnie, procent posiadanych tokenów przy sprzedaży.
export type TradeRequest = {
	Ticker: string,
	Side: Side,
	Amount: number,
	ExpectedOut: number,
	Slippage: number,
	PriorityFee: number,
	Tip: number,
	Bracket: { TakeProfit: number, StopLoss: number }?,
}

export type LimitRequest = {
	Ticker: string,
	Side: Side,
	Amount: number,
	TriggerMc: number,
	PriorityFee: number,
	Tip: number,
}

export type ActionResult = {
	Ok: boolean,
	Error: string?,
	Rx: number?,
	Tokens: number?,
}

export type Notice = { Kind: "Success" | "Error" | "Info", Text: string }

export type InitialState = {
	Market: MarketSnapshot,
	Trades: { [string]: { TradeEvent } },
	Portfolio: PortfolioState?,
}

return {}
