--!strict
-- Tabela coinów w stylu zakładki Discover na Axiom.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = script.Parent.Parent
local Icons = require(UI.Icons)
local Theme = require(UI.Theme)
local Util = require(UI.Util)
local Coins = require(ReplicatedStorage.Shared.Coins)

type Coin = Coins.Coin

local create = Util.create
local Colors = Theme.Colors
local Fonts = Theme.Fonts

type Column = { Title: string, Width: number, Build: (cell: Frame, coin: Coin, index: number) -> () }

local HEADER_HEIGHT = 48
local ROW_HEIGHT = 90

local TokenTable = {}

local function changeColor(n: number): Color3
	return if n >= 0 then Colors.Green else Colors.Red
end

local function sparkPoints(coin: Coin, index: number): { number }
	local rng = Random.new(index * 7919)
	local points, v = {}, 1
	local drift = if coin.Change >= 0 then 0.06 else -0.06
	for i = 1, 24 do
		v += drift + rng:NextNumber(-0.12, 0.12)
		points[i] = v
	end
	return points
end

local function icon(coin: Coin): Frame
	local initials = string.sub(coin.Ticker, 1, 1) .. string.sub(coin.Ticker, -1)
	local frame: Frame = create("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(62, 62),
		BackgroundColor3 = coin.Color,
	}, { Util.corner(6), Util.stroke(coin.Color, 2) })
	create("UIGradient", {
		Rotation = 45,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(90, 90, 90)),
		Parent = frame,
	})
	create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = initials,
		TextSize = 24,
		FontFace = Fonts.Bold,
		TextColor3 = Colors.Background,
		Parent = frame,
	})
	return frame
end

local function pairInfo(cell: Frame, coin: Coin, index: number)
	icon(coin).Parent = cell
	local info = Util.group("Info", 0, Util.vlist(6))
	info.AnchorPoint = Vector2.new(0, 0.5)
	info.Position = UDim2.new(0, 76, 0.5, 0)
	info.Parent = cell

	local title = Util.group("Title", 1, Util.hlist(6, Enum.VerticalAlignment.Bottom))
	title.Parent = info
	Util.text({ Text = coin.Ticker, Size = 18, Font = Fonts.SemiBold, Order = 1, Parent = title })
	Util.text({ Text = coin.Name, Size = 16, Font = Fonts.Regular, Color = Colors.TextMuted, Order = 2, Parent = title })

	local meta = Util.group("Meta", 2, Util.hlist(12))
	meta.Parent = info
	Util.text({ Text = coin.AgeText, Size = 16, Font = Fonts.SemiBold, Color = Colors.Green, Order = 1, Parent = meta })
	Util.text({
		Text = Util.compact(coin.Holders) .. " holders",
		Size = 14,
		Color = Colors.TextMuted,
		Order = 2,
		Parent = meta,
	})

	local chart = Icons.sparkline(sparkPoints(coin, index), Vector2.new(92, 38), changeColor(coin.Change))
	chart.AnchorPoint = Vector2.new(1, 0.5)
	chart.Position = UDim2.new(1, -20, 0.5, 0)
	chart.Parent = cell
end

local function stack(cell: Frame, spacing: number?): Frame
	local group = Util.group("Stack", 0, Util.vlist(spacing or 4))
	group.AnchorPoint = Vector2.new(0, 0.5)
	group.Position = UDim2.fromScale(0, 0.5)
	group.Parent = cell
	return group
end

local function marketCap(cell: Frame, coin: Coin)
	local s = stack(cell)
	Util.text({ Text = "$" .. Util.compact(coin.MarketCap), Size = 18, Font = Fonts.SemiBold, Order = 1, Parent = s })
	Util.text({
		Text = Util.percent(coin.Change),
		Size = 15,
		Color = changeColor(coin.Change),
		Order = 2,
		Parent = s,
	})
end

local function money(field: "Liquidity" | "Volume"): (Frame, Coin) -> ()
	return function(cell, coin)
		local s = stack(cell)
		local value = if field == "Liquidity" then coin.Liquidity else coin.Volume
		Util.text({ Text = "$" .. Util.compact(value), Size = 17, Font = Fonts.SemiBold, Parent = s })
	end
end

local function txns(cell: Frame, coin: Coin)
	local s = stack(cell)
	Util.text({ Text = Util.compact(coin.Buys + coin.Sells), Size = 17, Font = Fonts.SemiBold, Order = 1, Parent = s })
	local split = Util.group("Split", 2, Util.hlist(4))
	split.Parent = s
	Util.text({ Text = Util.compact(coin.Buys), Size = 15, Color = Colors.Green, Order = 1, Parent = split })
	Util.text({ Text = "/", Size = 15, Color = Colors.TextMuted, Order = 2, Parent = split })
	Util.text({ Text = Util.compact(coin.Sells), Size = 15, Color = Colors.Red, Order = 3, Parent = split })
end

-- Statystyki bezpieczeństwa tokena; czerwone powyżej progu ryzyka.
local TOKEN_STATS = {
	{ Label = "Top10", Max = 40, Danger = 15 },
	{ Label = "Dev", Max = 8, Danger = 5 },
	{ Label = "Snipers", Max = 6, Danger = 3 },
	{ Label = "Insiders", Max = 30, Danger = 10 },
	{ Label = "Bundled", Max = 60, Danger = 20 },
	{ Label = "LP", Max = 70, Danger = 101 },
}

local function tokenInfo(cell: Frame, _coin: Coin, index: number)
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
		local color = if value >= stat.Danger then Colors.Red else Colors.Green
		create("TextLabel", {
			Name = stat.Label,
			BackgroundColor3 = Colors.Background,
			Text = string.format('<font color="#8B8E9E">%s</font> %.2f%%', stat.Label, value),
			RichText = true,
			TextSize = 12,
			FontFace = Fonts.Medium,
			TextColor3 = color,
			TextTruncate = Enum.TextTruncate.AtEnd,
			LayoutOrder = i,
			Parent = grid,
		}, { Util.corner(4), Util.stroke(Colors.Divider), Util.padding(0, 6) })
	end
end

local buyButtons: { TextButton } = {}

local function buyText(amount: number): string
	return string.format("Buy %s %s", tostring(amount), Theme.Currency)
end

local function action(cell: Frame, coin: Coin)
	local button: TextButton = create("TextButton", {
		Name = "Buy",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -24, 0.5, 0),
		Size = UDim2.fromOffset(156, 42),
		BackgroundColor3 = Colors.Primary,
		Text = buyText(0),
		TextSize = 16,
		FontFace = Fonts.SemiBold,
		TextColor3 = Colors.Text,
		Parent = cell,
	}, { Util.round() })
	Util.hoverBackground(button, Colors.Primary, Colors.PrimaryHover)
	button.Activated:Connect(function()
		-- Kupowanie dojdzie razem z logiką ekonomii.
		print(`[RXIOM] Buy clicked: {coin.Ticker}`)
	end)
	table.insert(buyButtons, button)
end

local COLUMNS: { Column } = {
	{ Title = "Pair Info", Width = 0.30, Build = pairInfo },
	{ Title = "Market Cap", Width = 0.10, Build = marketCap },
	{ Title = "Liquidity", Width = 0.08, Build = money("Liquidity") },
	{ Title = "Volume", Width = 0.08, Build = money("Volume") },
	{ Title = "TXNS", Width = 0.08, Build = txns },
	{ Title = "Token Info", Width = 0.24, Build = tokenInfo },
	{ Title = "Action", Width = 0.12, Build = action },
}

local function cells(parent: Instance, build: (cell: Frame, column: Column) -> ())
	local x = 0
	for _, column in COLUMNS do
		local cell: Frame = create("Frame", {
			Name = column.Title,
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(x, 0),
			Size = UDim2.fromScale(column.Width, 1),
			Parent = parent,
		})
		build(cell, column)
		x += column.Width
	end
end

local function row(coin: Coin, index: number): TextButton
	local button: TextButton = create("TextButton", {
		Name = coin.Ticker,
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundColor3 = Colors.Surface,
		BorderSizePixel = 0,
		Text = "",
		LayoutOrder = index,
	})
	create("Frame", {
		Name = "Divider",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Colors.Divider,
		BorderSizePixel = 0,
		Parent = button,
	})
	local content = create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = button,
	}, { Util.padding(0, 0, 0, 24) })
	cells(content, function(cell, column)
		column.Build(cell, coin, index)
	end)
	Util.hoverBackground(button, Colors.Surface, Colors.SurfaceHover)
	return button
end

local function header(): Frame
	local frame: Frame = create("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		BackgroundTransparency = 1,
	}, { Util.padding(0, 0, 0, 24) })
	cells(frame, function(cell, column)
		local isAction = column.Title == "Action"
		local label = Util.text({
			Text = column.Title,
			Size = 15,
			Font = Fonts.Medium,
			Color = Colors.TextMuted,
			Parent = cell,
		})
		-- Nagłówek "Action" wyśrodkowany nad przyciskiem Buy (156 px, 24 px od prawej).
		label.AnchorPoint = Vector2.new(if isAction then 0.5 else 0, 0.5)
		label.Position = UDim2.new(if isAction then 1 else 0, if isAction then -102 else 0, 0.5, 0)
	end)
	return frame
end

export type TokenTable = {
	Frame: Frame,
	SetQuickBuy: (amount: number) -> (),
}

function TokenTable.new(): TokenTable
	local frame: Frame = create("Frame", {
		Name = "TokenTable",
		BackgroundColor3 = Colors.Surface,
		ClipsDescendants = true,
	}, { Util.corner(8), Util.stroke(Colors.Border) })
	header().Parent = frame
	create("Frame", {
		Name = "HeaderDivider",
		Position = UDim2.fromOffset(0, HEADER_HEIGHT),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Colors.Border,
		BorderSizePixel = 0,
		Parent = frame,
	})
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
	for i, coin in Coins do
		row(coin, i).Parent = list
	end

	return {
		Frame = frame,
		SetQuickBuy = function(amount: number)
			for _, button in buyButtons do
				button.Text = buyText(amount)
			end
		end,
	}
end

return TokenTable
