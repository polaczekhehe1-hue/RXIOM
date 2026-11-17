--!strict
-- Obsługa transakcji graczy: market buy/sell z kontrolą slippage, zlecenia limit i TP/SL, faucet.
-- Serwer jest jedynym źródłem prawdy; klient wysyła tylko intencję i oczekiwany wynik.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Coins = require(ReplicatedStorage.Shared.Coins)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Amm = require(ReplicatedStorage.Shared.Amm)
local Market = require(script.Parent.Market)
local PlayerData = require(script.Parent.PlayerData)

type Profile = PlayerData.Profile
type LimitOrder = Types.LimitOrder
type ActionResult = Types.ActionResult

local Trading = {}

local orders: { [Player]: { LimitOrder } } = {}
local recentActions: { [Player]: { number } } = {}
local nextOrderId = 0

local function fail(message: string): ActionResult
	return { Ok = false, Error = message }
end

local function finite(v: any): boolean
	return typeof(v) == "number" and v == v and math.abs(v) ~= math.huge
end

local function oneOf(options: { number }, v: any): boolean
	if not finite(v) then
		return false
	end
	for _, option in options do
		if math.abs(option - v) < 1e-9 then
			return true
		end
	end
	return false
end

-- Prosty limiter: najwyżej TradeRateLimit akcji w ciągu ostatniej sekundy.
local function allowAction(player: Player): boolean
	local now = os.clock()
	local list = recentActions[player] or {}
	recentActions[player] = list
	while list[1] and now - list[1] > 1 do
		table.remove(list, 1)
	end
	if #list >= Config.TradeRateLimit then
		return false
	end
	table.insert(list, now)
	return true
end

local function portfolio(player: Player): Types.PortfolioState?
	local profile = PlayerData.get(player)
	if not profile then
		return nil
	end
	return {
		Balance = profile.Balance,
		Positions = profile.Positions,
		Orders = orders[player] or {},
		FaucetReadyAt = profile.FaucetReadyAt,
		Wallet = profile.Wallet,
	}
end

local function pushPortfolio(player: Player)
	local state = portfolio(player)
	if state then
		Remotes.PortfolioChanged:FireClient(player, state)
	end
end

local function notify(player: Player, kind: "Success" | "Error" | "Info", text: string)
	Remotes.Notify:FireClient(player, { Kind = kind, Text = text })
end

local function position(profile: Profile, ticker: string): Types.Position
	local existing = profile.Positions[ticker]
	if existing then
		return existing
	end
	local created = { Tokens = 0, BoughtRx = 0, SoldRx = 0, BuyTokens = 0, BuyValue = 0, Fills = {} }
	profile.Positions[ticker] = created
	return created
end

local FEE = Config.FeeBps / 10_000

-- Zapisuje wejście/wyjście do historii pozycji (znaczniki na wykresie, średnia cena wejścia).
-- `poolRx` to RX, które faktycznie weszły do puli / z niej wyszły, czyli bez prowizji.
local function recordFill(p: Types.Position, side: Types.Side, poolRx: number, tokens: number)
	if tokens <= 0 then
		return
	end
	local price = poolRx / tokens
	table.insert(p.Fills, { T = Market.now(), Side = side, Price = price, Tokens = tokens })
	while #p.Fills > Config.MaxFills do
		table.remove(p.Fills, 1)
	end
	if side == "Buy" then
		p.BuyTokens += tokens
		p.BuyValue += tokens * price
	end
end

local function hasOrdersFor(player: Player, ticker: string): boolean
	local list = orders[player]
	if not list then
		return false
	end
	for _, order in list do
		if order.Ticker == ticker then
			return true
		end
	end
	return false
end

-- Usuwa pustą pozycję, chyba że jakieś zlecenie wciąż trzyma jej tokeny.
local function cleanup(player: Player, profile: Profile, ticker: string)
	local p = profile.Positions[ticker]
	if p and p.Tokens <= Config.DustTokens and not hasOrdersFor(player, ticker) then
		profile.Positions[ticker] = nil
	end
end

local function traderName(player: Player): string
	return player.DisplayName
end

local function addOrder(player: Player, order: LimitOrder): boolean
	local list = orders[player] or {}
	orders[player] = list
	if #list >= Config.MaxOpenOrders then
		return false
	end
	table.insert(list, order)
	return true
end

local function newOrderId(): number
	nextOrderId += 1
	return nextOrderId
end

-- Zwraca zarezerwowane środki zlecenia.
local function refund(profile: Profile, order: LimitOrder)
	if order.Side == "Buy" then
		profile.Balance += order.Rx + order.Fees
	else
		position(profile, order.Ticker).Tokens += order.Tokens
	end
end

local function validateFees(request: any): string?
	if not oneOf(Config.PriorityFeeOptions, request.PriorityFee) then
		return "Invalid priority fee"
	end
	if not oneOf(Config.TipOptions, request.Tip) then
		return "Invalid tip"
	end
	return nil
end

local function sellTokens(p: Types.Position?, percent: number): number
	if not p or p.Tokens <= Config.DustTokens then
		return 0
	end
	-- 100% sprzedaje wszystko co do jednostki, bez pyłu po zaokrągleniach.
	return if percent >= 100 then p.Tokens else p.Tokens * percent / 100
end

local function submitTrade(player: Player, request: any): ActionResult
	if not allowAction(player) then
		return fail("Too many requests, slow down")
	end
	local profile = PlayerData.get(player)
	if not profile then
		return fail("Your data is still loading")
	end
	if typeof(request) ~= "table" or typeof(request.Ticker) ~= "string" then
		return fail("Invalid request")
	end
	local ticker: string = request.Ticker
	if not Coins.ByTicker[ticker] or not Market.get(ticker) then
		return fail("Unknown coin")
	end
	if request.Side ~= "Buy" and request.Side ~= "Sell" then
		return fail("Invalid side")
	end
	if not finite(request.Amount) or request.Amount <= 0 then
		return fail("Enter an amount")
	end
	if not finite(request.ExpectedOut) or request.ExpectedOut < 0 then
		return fail("Invalid quote")
	end
	if not oneOf(Config.SlippageOptions, request.Slippage) then
		return fail("Invalid slippage")
	end
	local feeError = validateFees(request)
	if feeError then
		return fail(feeError)
	end

	local state = Market.get(ticker) :: Market.CoinState
	local fees: number = request.PriorityFee + request.Tip
	local minOut = request.ExpectedOut * (1 - request.Slippage / 100)

	if request.Side == "Buy" then
		local rx: number = request.Amount
		if rx < Config.MinTradeRx then
			return fail(`Minimum buy is {Config.MinTradeRx} {Config.Currency}`)
		end
		if rx + fees > profile.Balance + 1e-9 then
			return fail("Insufficient balance")
		end
		local quote = Amm.buyQuote(state.Pool, rx)
		if quote < minOut then
			return fail("Price moved more than your slippage")
		end

		local tokens = Market.executeBuy(ticker, rx, traderName(player), true)
		profile.Balance = math.max(0, profile.Balance - rx - fees)
		local p = position(profile, ticker)
		p.Tokens += tokens
		p.BoughtRx += rx + fees
		recordFill(p, "Buy", rx * (1 - FEE), tokens)

		local bracket = request.Bracket
		if typeof(bracket) == "table" and finite(bracket.TakeProfit) and finite(bracket.StopLoss) then
			local tp = math.clamp(bracket.TakeProfit, 1, 100_000)
			local sl = math.clamp(bracket.StopLoss, 1, 99)
			local mc = Market.marketCap(ticker)
			local order: LimitOrder = {
				Id = newOrderId(),
				Ticker = ticker,
				Side = "Sell",
				Rx = 0,
				Tokens = tokens,
				Fees = fees,
				Above = mc * (1 + tp / 100),
				Below = mc * (1 - sl / 100),
				CreatedAt = Market.now(),
			}
			if addOrder(player, order) then
				p.Tokens -= tokens
			else
				notify(player, "Error", "TP/SL not set: too many open orders")
			end
		end

		pushPortfolio(player)
		return { Ok = true, Rx = rx, Tokens = tokens }
	end

	local percent: number = math.min(request.Amount, 100)
	local p = profile.Positions[ticker]
	local tokens = sellTokens(p, percent)
	if tokens <= Config.DustTokens or not p then
		return fail("You don't hold this coin")
	end
	local quote = Amm.sellQuote(state.Pool, tokens)
	if quote < minOut then
		return fail("Price moved more than your slippage")
	end
	if quote <= fees then
		return fail("Amount too small to cover fees")
	end

	local received = Market.executeSell(ticker, tokens, traderName(player), true)
	local rx = received - fees
	recordFill(p, "Sell", received / (1 - FEE), tokens)
	p.Tokens -= tokens
	p.SoldRx += rx
	profile.Balance += rx
	cleanup(player, profile, ticker)
	pushPortfolio(player)
	return { Ok = true, Rx = rx, Tokens = tokens }
end

local function placeLimitOrder(player: Player, request: any): ActionResult
	if not allowAction(player) then
		return fail("Too many requests, slow down")
	end
	local profile = PlayerData.get(player)
	if not profile then
		return fail("Your data is still loading")
	end
	if typeof(request) ~= "table" or typeof(request.Ticker) ~= "string" or not Market.get(request.Ticker) then
		return fail("Unknown coin")
	end
	if request.Side ~= "Buy" and request.Side ~= "Sell" then
		return fail("Invalid side")
	end
	if not finite(request.Amount) or request.Amount <= 0 then
		return fail("Enter an amount")
	end
	if not finite(request.TriggerMc) or request.TriggerMc <= 0 then
		return fail("Enter a trigger market cap")
	end
	local feeError = validateFees(request)
	if feeError then
		return fail(feeError)
	end
	if #(orders[player] or {}) >= Config.MaxOpenOrders then
		return fail(`You can have at most {Config.MaxOpenOrders} open orders`)
	end

	local ticker: string = request.Ticker
	local fees: number = request.PriorityFee + request.Tip
	local trigger: number = request.TriggerMc
	local above = if trigger >= Market.marketCap(ticker) then trigger else nil
	local below = if above then nil else trigger
	local order: LimitOrder = {
		Id = newOrderId(),
		Ticker = ticker,
		Side = request.Side,
		Rx = 0,
		Tokens = 0,
		Fees = fees,
		Above = above,
		Below = below,
		CreatedAt = Market.now(),
	}

	if request.Side == "Buy" then
		local rx: number = request.Amount
		if rx < Config.MinTradeRx then
			return fail(`Minimum buy is {Config.MinTradeRx} {Config.Currency}`)
		end
		if rx + fees > profile.Balance + 1e-9 then
			return fail("Insufficient balance")
		end
		profile.Balance = math.max(0, profile.Balance - rx - fees)
		order.Rx = rx
	else
		local p = profile.Positions[ticker]
		local tokens = sellTokens(p, math.min(request.Amount, 100))
		if tokens <= Config.DustTokens or not p then
			return fail("You don't hold this coin")
		end
		p.Tokens -= tokens
		order.Tokens = tokens
	end

	addOrder(player, order)
	pushPortfolio(player)
	return { Ok = true, Rx = order.Rx, Tokens = order.Tokens }
end

local function cancelLimitOrder(player: Player, id: any): ActionResult
	local profile = PlayerData.get(player)
	local list = orders[player]
	if not profile or not list or typeof(id) ~= "number" then
		return fail("Order not found")
	end
	for i, order in list do
		if order.Id == id then
			table.remove(list, i)
			refund(profile, order)
			cleanup(player, profile, order.Ticker)
			pushPortfolio(player)
			return { Ok = true }
		end
	end
	return fail("Order not found")
end

local function claimFaucet(player: Player): ActionResult
	local profile = PlayerData.get(player)
	if not profile then
		return fail("Your data is still loading")
	end
	local now = os.time()
	if now < profile.FaucetReadyAt then
		return fail(`Next deposit available in {Format.age(profile.FaucetReadyAt - now)}`)
	end
	profile.Balance += Config.Faucet.Amount
	profile.FaucetReadyAt = now + Config.Faucet.Cooldown
	pushPortfolio(player)
	return { Ok = true, Rx = Config.Faucet.Amount }
end

local function fill(player: Player, profile: Profile, order: LimitOrder)
	local def = Coins.ByTicker[order.Ticker]
	if order.Side == "Buy" then
		local tokens = Market.executeBuy(order.Ticker, order.Rx, traderName(player), true)
		local p = position(profile, order.Ticker)
		p.Tokens += tokens
		p.BoughtRx += order.Rx + order.Fees
		recordFill(p, "Buy", order.Rx * (1 - FEE), tokens)
		notify(player, "Success", `Limit buy filled: +{Format.compact(tokens)} {def.Ticker}`)
	else
		-- Etykietę liczymy przed sprzedażą, bo sama sprzedaż obniża market cap.
		local label = if order.Above and order.Below
			then (if Market.marketCap(order.Ticker) >= order.Above then "Take profit" else "Stop loss")
			else "Limit sell"
		local received = Market.executeSell(order.Ticker, order.Tokens, traderName(player), true)
		local rx = math.max(0, received - order.Fees)
		local p = position(profile, order.Ticker)
		recordFill(p, "Sell", received / (1 - FEE), order.Tokens)
		p.SoldRx += rx
		profile.Balance += rx
		notify(player, "Success", `{label} filled: {Format.compact(order.Tokens)} {def.Ticker} for {Format.rx(rx)}`)
	end
end

-- Wykonuje zlecenia, których warunek na market cap został spełniony.
function Trading.checkOrders()
	for player, list in orders do
		local profile = PlayerData.get(player)
		if not profile then
			continue
		end
		local changed = false
		for i = #list, 1, -1 do
			local order = list[i]
			local mc = Market.marketCap(order.Ticker)
			local hit = (order.Above ~= nil and mc >= order.Above) or (order.Below ~= nil and mc <= order.Below)
			if hit then
				table.remove(list, i)
				fill(player, profile, order)
				cleanup(player, profile, order.Ticker)
				changed = true
			end
		end
		if changed then
			pushPortfolio(player)
		end
	end
end

-- Oddaje środki z otwartych zleceń, żeby trafiły do zapisu (zlecenia nie są zapisywane).
function Trading.refundOrders(player: Player)
	local profile = PlayerData.get(player)
	local list = orders[player]
	if profile and list then
		for _, order in list do
			refund(profile, order)
		end
	end
	orders[player] = nil
end

function Trading.start()
	Market.setHolderCounter(PlayerData.countHolders)

	Remotes.SubmitTrade.OnServerInvoke = submitTrade
	Remotes.PlaceLimitOrder.OnServerInvoke = placeLimitOrder
	Remotes.CancelLimitOrder.OnServerInvoke = cancelLimitOrder
	Remotes.ClaimFaucet.OnServerInvoke = claimFaucet
	Remotes.GetCandles.OnServerInvoke = function(_player: Player, ticker: any)
		return if typeof(ticker) == "string" then Market.candles(ticker) else {}
	end
	Remotes.Login.OnServerInvoke = function(player: Player): Types.LoginResult
		local profile = PlayerData.waitFor(player, 15)
		if not profile then
			return { Ok = false, Error = "Your data is still loading, try again" }
		end
		local wallet, isNew = PlayerData.ensureWallet(profile)
		pushPortfolio(player)
		return { Ok = true, Wallet = wallet, New = isNew }
	end
	Remotes.GetInitialState.OnServerInvoke = function(player: Player): Types.InitialState
		return {
			Market = Market.snapshot(),
			Trades = Market.recentTrades(),
			Portfolio = portfolio(player),
		}
	end

	PlayerData.Loaded:Connect(pushPortfolio)
	Players.PlayerRemoving:Connect(function(player)
		Trading.refundOrders(player)
		recentActions[player] = nil
		PlayerData.release(player)
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			Trading.refundOrders(player)
		end
		PlayerData.saveAll()
	end)
end

return Trading
