--!strict
-- Wykres świecowy market capu. Pozycje w skali (0..1), więc działa przy każdym rozmiarze i UIScale.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Types = require(ReplicatedStorage.Shared.Types)
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

type Candle = Types.Candle

local create = Util.create
local Colors = Theme.Colors
local Fonts = Theme.Fonts

local AXIS_WIDTH = 76
local GRID_LINES = 5
local MIN_SLOTS = 60

export type Chart = {
	Frame: Frame,
	-- `scale` przelicza cenę świecy na wartość na osi (market cap w $).
	Set: (candles: { Candle }, scale: number) -> (),
}

local Chart = {}

function Chart.new(maxCandles: number): Chart
	local frame: Frame = create("Frame", {
		Name = "Chart",
		BackgroundColor3 = Colors.Surface,
		ClipsDescendants = true,
	}, { Util.corner(8), Util.stroke(Colors.Border) })

	local plot: Frame = create("Frame", {
		Name = "Plot",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 16),
		Size = UDim2.new(1, -(AXIS_WIDTH + 12), 1, -32),
		Parent = frame,
	})
	local axis: Frame = create("Frame", {
		Name = "Axis",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 16),
		Size = UDim2.new(0, AXIS_WIDTH, 1, -32),
		Parent = frame,
	})

	local gridLabels: { TextLabel } = {}
	for i = 1, GRID_LINES do
		local y = (i - 1) / (GRID_LINES - 1)
		create("Frame", {
			Name = "Grid",
			Position = UDim2.fromScale(0, y),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = Colors.Divider,
			BorderSizePixel = 0,
			Parent = plot,
		})
		gridLabels[i] = Util.label({
			Text = "",
			Size = 12,
			Color = Colors.TextDim,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 8, y, 0),
			FrameSize = UDim2.new(1, -8, 0, 14),
			Parent = axis,
		})
	end

	local candleFrames: { { Wick: Frame, Body: Frame } } = {}
	for i = 1, maxCandles do
		local wick = create("Frame", {
			Name = "Wick" .. i,
			AnchorPoint = Vector2.new(0.5, 0),
			BorderSizePixel = 0,
			Visible = false,
			Parent = plot,
		})
		local body = create("Frame", {
			Name = "Body" .. i,
			AnchorPoint = Vector2.new(0.5, 0),
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 2,
			Parent = plot,
		})
		candleFrames[i] = { Wick = wick, Body = body }
	end

	local lastLine: Frame = create("Frame", {
		Name = "LastPrice",
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Colors.Green,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = plot,
	})
	local lastLabel: TextLabel = create("TextLabel", {
		Name = "LastPriceLabel",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(4, 0),
		Size = UDim2.new(1, -4, 0, 20),
		BackgroundColor3 = Colors.Green,
		Text = "",
		TextSize = 12,
		FontFace = Fonts.SemiBold,
		TextColor3 = Colors.Background,
		ZIndex = 4,
		Parent = axis,
	}, { Util.corner(4) })

	local empty = Util.label({
		Name = "Empty",
		Text = "Loading chart...",
		Size = 15,
		Color = Colors.TextMuted,
		AlignX = Enum.TextXAlignment.Center,
		Parent = plot,
	})

	local function set(candles: { Candle }, scale: number)
		local count = math.min(#candles, maxCandles)
		empty.Visible = count == 0
		lastLine.Visible = count > 0
		lastLabel.Visible = count > 0
		if count == 0 then
			for _, c in candleFrames do
				c.Wick.Visible = false
				c.Body.Visible = false
			end
			return
		end
		local first = #candles - count + 1
		local lo, hi = math.huge, -math.huge
		for i = first, #candles do
			lo = math.min(lo, candles[i].L)
			hi = math.max(hi, candles[i].H)
		end
		local pad = math.max((hi - lo) * 0.08, hi * 0.002)
		lo, hi = lo - pad, hi + pad
		local range = hi - lo
		local function y(v: number): number
			return (hi - v) / range
		end

		-- Stała liczba slotów, żeby przy małej historii świece nie były rozciągnięte; wyrównanie do prawej.
		local slots = math.max(count, MIN_SLOTS)
		local slot = 1 / slots
		for i, frames in candleFrames do
			local index = first + i - 1
			local candle = candles[index]
			local visible = i <= count and candle ~= nil
			frames.Wick.Visible = visible
			frames.Body.Visible = visible
			if visible then
				local x = (slots - count + i - 0.5) * slot
				local color = if candle.C >= candle.O then Colors.Green else Colors.Red
				frames.Wick.BackgroundColor3 = color
				frames.Wick.Position = UDim2.fromScale(x, y(candle.H))
				frames.Wick.Size = UDim2.new(0, 1, (candle.H - candle.L) / range, 0)
				local top = math.max(candle.O, candle.C)
				local bottom = math.min(candle.O, candle.C)
				frames.Body.BackgroundColor3 = color
				frames.Body.Position = UDim2.fromScale(x, y(top))
				frames.Body.Size = UDim2.new(slot * 0.7, 0, (top - bottom) / range, 1)
			end
		end

		for i, label in gridLabels do
			local v = hi - (i - 1) / (GRID_LINES - 1) * range
			label.Text = Format.usd(v * scale)
		end

		local last = candles[#candles]
		local color = if last.C >= candles[first].O then Colors.Green else Colors.Red
		lastLine.Position = UDim2.fromScale(0, y(last.C))
		lastLine.BackgroundColor3 = color
		lastLabel.Position = UDim2.new(0, 4, y(last.C), 0)
		lastLabel.BackgroundColor3 = color
		lastLabel.Text = Format.usd(last.C * scale)
	end

	return { Frame = frame, Set = set }
end

return Chart
