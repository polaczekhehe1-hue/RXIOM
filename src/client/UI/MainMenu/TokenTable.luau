--!strict
-- Tabela coinów (zakładka Discover) z danymi na żywo. Kliknięcie wiersza otwiera stronę coina,
-- przycisk Buy kupuje od razu za kwotę z Quick Buy.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Coins = require(ReplicatedStorage.Shared.Coins)
local Format = require(ReplicatedStorage.Shared.Format)
local Types = require(ReplicatedStorage.Shared.Types)

local State = script.Parent.Parent.Parent.State
local Actions = require(State.Actions)
local Market = require(State.Market)
local Settings = require(State.Settings)

local UI = script.Parent.Parent
local Icons = require(UI.Icons)
local Sparkline = require(UI.Sparkline)
local Theme = require(UI.Theme)
local Util = require(UI.Util)

type CoinDef = Coins.CoinDef
type CoinSnapshot = Types.CoinSnapshot

local create = Util.create
local Colors = Theme.Colors
local Fonts = Theme.Fonts

local HEADER_HEIGHT = 48
local ROW_HEIGHT = 90

local COLUMNS = {
	{ Title = "Pair Info", Width = 0.30 },
	{ Title = "Market Cap", Width = 0.10 },
	{ Title = "Liquidity", Width = 0.08 },
	{ Title = "Volume", Width = 0.08 },
	{ Title = "TXNS", Width = 0.08 },
	{ Title = "Token Info", Width = 0.24 },
	{ Title = "Action", Width = 0.12 },
}

-- Statystyki bezpieczeństwa tokena (dekoracyjne); czerwone powyżej progu ryzyka.
local TOKEN_STATS = {
	{ Label = "Top10", Max = 40, Danger = 15 },
	{ Label = "Dev", Max = 8, Danger = 5 },
	{ Label = "Snipers", Max = 6, Danger = 3 },
	{ Label = "Insiders", Max = 30, Danger = 10 },
	{ Label = "Bundled", Max = 60, Danger = 20 },
	{ Label = "LP", Max = 70, Danger = 101 },
}

type Row = {
	Ticker: string,
	Frame: TextButton,
	Update: (coin: CoinSnapshot) -> (),
	BuyButton: TextButton,
}

local TokenTable = {}

local function cellFrames(parent: Instance): { Frame }
	local result = {}
	local x = 0
	for i, column in COLUMNS do
		result[i] = create("Frame", {
			Name = column.Title,
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(x, 0),
			Size = UDim2.fromScale(column.Width, 1),
			Parent = parent,
		})
		x += column.Width
	end
	return result
end

local function stack(cell: Frame): Frame
	local group = Util.group("Stack", 0, Util.vlist(4))
	group.AnchorPoint = Vector2.new(0, 0.5)
	group.Position = UDim2.fromScale(0, 0.5)
	group.Parent = cell
	return group
end

local function tokenInfo(cell: Frame, index: number)
	local rng = Random.new(index * 104729)
	local grid = create("Frame", {
		Name = "Grid",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, -12, 0, 56),
		BackgroundTransparency = 1,
		Parent = cell,
	}, {
		create("UIGridLayout", {
			CellSize = UDim2.new(1 / 3, -6, 0, 24),
			CellPadding = UDim2.fromOffset(6, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, stat in TOKEN_STATS do
		local value = rng:NextNumber(0, stat.Max)
		create("TextLabel", {
			Name = stat.Label,
			BackgroundColor3 = Colors.Background,
			Text = string.format('<font color="#8B8E9E">%s</font> %.2f%%', stat.Label, value),
			RichText = true,
			TextSize = 12,
			FontFace = Fonts.Medium,
			TextColor3 = if value >= stat.Danger then Colors.Red else Colors.Green,
			TextTruncate = Enum.TextTruncate.AtEnd,
			LayoutOrder = i,
			Parent = grid,
		}, { Util.corner(4), Util.stroke(Colors.Divider), Util.padding(0, 6) })
	end
end

local function buyText(amount: number): string
	return `Buy {Format.decimal(amount)} RX`
end

local function row(def: CoinDef, index: number, openCoin: (string) -> ()): Row
	local button: TextButton = create("TextButton", {
		Name = def.Ticker,
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundColor3 = Colors.Surface,
		BorderSizePixel = 0,
		Text = "",
		LayoutOrder = index,
	})
	local divider = Util.divider(false, Colors.Divider)
	divider.AnchorPoint = Vector2.new(0, 1)
	divider.Position = UDim2.fromScale(0, 1)
	divider.Parent = button
	local content = create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = button,
	}, { Util.padding(0, 0, 0, 24) })
	local cells = cellFrames(content)

	-- Pair info
	local icon = Icons.token(def.Color, def.Ticker, 62)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.fromScale(0, 0.5)
	icon.Parent = cells[1]
	local info = Util.group("Info", 0, Util.vlist(6))
	info.AnchorPoint = Vector2.new(0, 0.5)
	info.Position = UDim2.new(0, 76, 0.5, 0)
	info.Parent = cells[1]
	local title = Util.group("Title", 1, Util.hlist(6, Enum.VerticalAlignment.Bottom))
	title.Parent = info
	Util.text({ Text = def.Ticker, Size = 18, Font = Fonts.SemiBold, Order = 1, Parent = title })
	Util.text({ Text = def.Name, Size = 16, Font = Fonts.Regular, Color = Colors.TextMuted, Order = 2, Parent = title })
	local meta = Util.group("Meta", 2, Util.hlist(12))
	meta.Parent = info
	local age =
		Util.text({ Text = "", Size = 16, Font = Fonts.SemiBold, Color = Colors.Green, Order = 1, Parent = meta })
	local holders = Util.text({ Text = "", Size = 14, Color = Colors.TextMuted, Order = 2, Parent = meta })
	local spark = Sparkline.new(23, Vector2.new(92, 38))
	spark.Frame.AnchorPoint = Vector2.new(1, 0.5)
	spark.Frame.Position = UDim2.new(1, -20, 0.5, 0)
	spark.Frame.Parent = cells[1]

	-- Market cap
	local mcStack = stack(cells[2])
	local mc = Util.text({ Text = "", Size = 18, Font = Fonts.SemiBold, Order = 1, Parent = mcStack })
	local change = Util.text({ Text = "", Size = 15, Order = 2, Parent = mcStack })

	local liquidity = Util.text({ Text = "", Size = 17, Font = Fonts.SemiBold, Parent = stack(cells[3]) })
	local volume = Util.text({ Text = "", Size = 17, Font = Fonts.SemiBold, Parent = stack(cells[4]) })

	local txStack = stack(cells[5])
	local txTotal = Util.text({ Text = "", Size = 17, Font = Fonts.SemiBold, Order = 1, Parent = txStack })
	local split = Util.group("Split", 2, Util.hlist(4))
	split.Parent = txStack
	local buys = Util.text({ Text = "", Size = 15, Color = Colors.Green, Order = 1, Parent = split })
	Util.text({ Text = "/", Size = 15, Color = Colors.TextMuted, Order = 2, Parent = split })
	local sells = Util.text({ Text = "", Size = 15, Color = Colors.Red, Order = 3, Parent = split })

	tokenInfo(cells[6], index)

	local buyButton: TextButton = create("TextButton", {
		Name = "Buy",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -24, 0.5, 0),
		Size = UDim2.fromOffset(156, 42),
		BackgroundColor3 = Colors.Primary,
		Text = buyText(Settings.State.QuickBuy),
		TextSize = 16,
		FontFace = Fonts.SemiBold,
		TextColor3 = Colors.OnPrimary,
		ZIndex = 2,
		Parent = cells[7],
	}, { Util.round() })
	Util.hoverBackground(buyButton, Colors.Primary, Colors.PrimaryHover)
	local buying = false
	buyButton.Activated:Connect(function()
		if buying then
			return
		end
		buying = true
		buyButton.Text = "Buying..."
		Actions.buy(def.Ticker, Settings.State.QuickBuy)
		buying = false
		buyButton.Text = buyText(Settings.State.QuickBuy)
	end)

	Util.hoverBackground(button, Colors.Surface, Colors.SurfaceHover)
	button.Activated:Connect(function()
		openCoin(def.Ticker)
	end)

	local function update(coin: CoinSnapshot)
		local stats = coin.Stats[Settings.State.Timeframe]
		age.Text = Format.age(Market.now() - coin.LaunchedAt)
		holders.Text = Format.compact(coin.Holders) .. " holders"
		mc.Text = Format.usd(coin.MarketCap)
		liquidity.Text = Format.usd(coin.Liquidity)
		if stats then
			change.Text = Format.percent(stats.Change)
			change.TextColor3 = Util.changeColor(stats.Change)
			volume.Text = Format.usd(stats.Volume)
			txTotal.Text = Format.compact(stats.Buys + stats.Sells)
			buys.Text = Format.compact(stats.Buys)
			sells.Text = Format.compact(stats.Sells)
		end
		local points = table.clone(coin.Spark)
		table.insert(points, coin.Price)
		local first = points[1] or coin.Price
		spark.Set(points, Util.changeColor(coin.Price - first))
	end

	return { Ticker = def.Ticker, Frame = button, Update = update, BuyButton = buyButton }
end

local function header(): Frame
	local frame: Frame = create("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		BackgroundTransparency = 1,
	}, { Util.padding(0, 0, 0, 24) })
	for i, cell in cellFrames(frame) do
		local isAction = COLUMNS[i].Title == "Action"
		local label = Util.text({
			Text = COLUMNS[i].Title,
			Size = 15,
			Font = Fonts.Medium,
			Color = Colors.TextMuted,
			Parent = cell,
		})
		-- Nagłówek "Action" wyśrodkowany nad przyciskiem Buy (156 px, 24 px od prawej).
		label.AnchorPoint = Vector2.new(if isAction then 0.5 else 0, 0.5)
		label.Position = UDim2.new(if isAction then 1 else 0, if isAction then -102 else 0, 0.5, 0)
	end
	return frame
end

export type TokenTable = {
	Frame: Frame,
}

function TokenTable.new(openCoin: (ticker: string) -> ()): TokenTable
	local frame: Frame = create("Frame", {
		Name = "TokenTable",
		BackgroundColor3 = Colors.Surface,
		ClipsDescendants = true,
	}, { Util.corner(8), Util.stroke(Colors.Border) })
	header().Parent = frame
	local headerDivider = Util.divider()
	headerDivider.Position = UDim2.fromOffset(0, HEADER_HEIGHT)
	headerDivider.Parent = frame
	local list: ScrollingFrame = create("ScrollingFrame", {
		Name = "Rows",
		Position = UDim2.fromOffset(0, HEADER_HEIGHT + 1),
		Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + 1)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Colors.Border,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = frame,
	}, { Util.vlist(0, nil, Enum.VerticalAlignment.Top) })
	local empty = Util.label({
		Name = "Empty",
		Text = "No coins match your search",
		Size = 16,
		Color = Colors.TextMuted,
		AlignX = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, HEADER_HEIGHT + 1),
		FrameSize = UDim2.new(1, 0, 0, 120),
		Parent = frame,
	})

	local rows: { Row } = {}
	for i, def in Coins.List do
		local r = row(def, i, openCoin)
		r.Frame.Parent = list
		rows[i] = r
	end

	local function refresh()
		local s = Settings.State
		local query = string.lower(s.Search)
		local sortValue: { [string]: number } = {}
		local visible = 0
		for _, r in rows do
			local coin = Market.coin(r.Ticker)
			local def = Coins.ByTicker[r.Ticker]
			local matches = query == ""
				or string.find(string.lower(def.Ticker), query, 1, true) ~= nil
				or string.find(string.lower(def.Name), query, 1, true) ~= nil
			r.Frame.Visible = matches and coin ~= nil
			if coin then
				r.Update(coin)
				local stats = coin.Stats[s.Timeframe]
				sortValue[r.Ticker] = if s.Sort == "Trending" and stats then stats.Volume else coin.MarketCap
			end
			if r.Frame.Visible then
				visible += 1
			end
		end
		empty.Visible = visible == 0
		local sorted = table.clone(rows)
		table.sort(sorted, function(a, b)
			return (sortValue[a.Ticker] or 0) > (sortValue[b.Ticker] or 0)
		end)
		for i, r in sorted do
			r.Frame.LayoutOrder = i
		end
	end

	Market.Changed:Connect(refresh)
	Settings.Changed:Connect(function(key: string)
		if key == "QuickBuy" then
			for _, r in rows do
				r.BuyButton.Text = buyText(Settings.State.QuickBuy)
			end
		elseif key == "Search" or key == "Sort" or key == "Timeframe" then
			refresh()
		end
	end)
	refresh()

	return { Frame = frame }
end

return TokenTable
