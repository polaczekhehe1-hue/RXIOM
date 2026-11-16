--!strict
-- Pasek pod nawigacją: zakładki (Top, Trending...), przedziały czasu, Quick Buy i presety P1-P3.

local UI = script.Parent.Parent
local Icons = require(UI.Icons)
local Theme = require(UI.Theme)
local Util = require(UI.Util)

local create = Util.create
local Colors = Theme.Colors
local Fonts = Theme.Fonts

type Tab = { Name: string, Badge: string?, Dropdown: boolean? }

local TABS: { Tab } = {
	{ Name = "Top" },
	{ Name = "Trending", Dropdown = true },
	{ Name = "Radar", Badge = "NEW" },
	{ Name = "Callouts" },
	{ Name = "Streamers", Badge = "NEW" },
}
local TIMEFRAMES = { "1m", "5m", "30m", "1h", "24h" }
local PRESETS = { "P1", "P2", "P3" }

local FilterBar = {}
FilterBar.Height = 72

-- Grupa przycisków, z których tylko jeden jest aktywny.
local function segmented(
	parent: Instance,
	labels: { string },
	activeIndex: number,
	size: number,
	activeColor: Color3,
	idleColor: Color3,
	onSelect: ((string) -> ())?
): { TextButton }
	local buttons: { TextButton } = {}
	for i, label in labels do
		local button: TextButton = create("TextButton", {
			Name = label,
			AutoButtonColor = false,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 32),
			BackgroundTransparency = 1,
			Text = label,
			TextSize = size,
			FontFace = Fonts.Medium,
			TextColor3 = if i == activeIndex then activeColor else idleColor,
			LayoutOrder = i,
			Parent = parent,
		}, { Util.padding(0, 8) })
		button.Activated:Connect(function()
			for _, b in buttons do
				Util.tween(b, { TextColor3 = if b == button then activeColor else idleColor })
			end
			if onSelect then
				onSelect(label)
			end
		end)
		table.insert(buttons, button)
	end
	return buttons
end

local function badge(text: string): TextLabel
	return create("TextLabel", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, 2),
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		BackgroundColor3 = Color3.fromHex("2A2312"),
		Text = text,
		TextSize = 10,
		FontFace = Fonts.Bold,
		TextColor3 = Color3.fromHex("E6B54A"),
	}, { Util.corner(4), Util.padding(1, 5) })
end

local function tabs(): Frame
	local frame = Util.group("Tabs", 1, Util.hlist(28))
	local buttons: { TextButton } = {}
	local active: TextButton? = nil
	for i, tab in TABS do
		local button: TextButton = create("TextButton", {
			Name = tab.Name,
			AutoButtonColor = false,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 40),
			BackgroundTransparency = 1,
			Text = "",
			LayoutOrder = i,
			Parent = frame,
		})
		-- Odznaka "NEW" leży poza list layoutem, żeby mogła wisieć nad napisem.
		local content = Util.group("Content", 0, Util.hlist(6))
		content.Size = UDim2.fromOffset(0, 40)
		content.AutomaticSize = Enum.AutomaticSize.X
		content.Parent = button
		local label = Util.text({
			Text = tab.Name,
			Size = 24,
			Font = Fonts.Medium,
			Color = if i == 1 then Colors.Text else Colors.TextMuted,
			Order = 1,
			Parent = content,
		})
		if tab.Dropdown then
			Icons.chevronDown(14, Colors.TextMuted, 2).Parent = content
		end
		if tab.Badge then
			badge(tab.Badge).Parent = button
		end
		button.Activated:Connect(function()
			active = button
			for _, b in buttons do
				local l = b:FindFirstChild("Text", true) :: TextLabel
				Util.tween(l, { TextColor3 = if b == button then Colors.Text else Colors.TextMuted })
			end
		end)
		button.MouseEnter:Connect(function()
			if active ~= button then
				Util.tween(label, { TextColor3 = Color3.fromHex("B4B7C5") })
			end
		end)
		button.MouseLeave:Connect(function()
			if active ~= button then
				Util.tween(label, { TextColor3 = Colors.TextMuted })
			end
		end)
		if i == 1 then
			active = button
		end
		table.insert(buttons, button)
	end
	return frame
end

local function quickBuy(onAmountChanged: (number) -> ()): Frame
	local box = create("Frame", {
		Name = "QuickBuy",
		Size = UDim2.fromOffset(200, 40),
		BackgroundColor3 = Colors.Background,
		LayoutOrder = 2,
	}, { Util.round(), Util.stroke(Colors.Border), Util.padding(0, 14) })
	Util.text({ Text = "Quick Buy", Size = 16, Font = Fonts.Medium, Color = Colors.TextMuted }).Parent = box
	local input: TextBox = create("TextBox", {
		Name = "Amount",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(80, 0),
		Size = UDim2.new(1, -104, 1, 0),
		ClearTextOnFocus = false,
		Text = "0",
		TextSize = 17,
		FontFace = Fonts.SemiBold,
		TextColor3 = Colors.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = box,
	})
	local icon = Icons.currency(16)
	icon.AnchorPoint = Vector2.new(1, 0.5)
	icon.Position = UDim2.fromScale(1, 0.5)
	icon.Parent = box

	-- Label "Quick Buy" ma AutomaticSize, więc wyśrodkuj go pionowo.
	local label = box:FindFirstChild("Text") :: TextLabel
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.fromScale(0, 0.5)

	input.FocusLost:Connect(function()
		local amount = tonumber(input.Text)
		if not amount or amount < 0 then
			amount = 0
		end
		local value = amount :: number
		input.Text = tostring(value)
		onAmountChanged(value)
	end)
	return box
end

local function presets(): Frame
	local frame: Frame = create("Frame", {
		Name = "Presets",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 40),
		BackgroundColor3 = Colors.Background,
		LayoutOrder = 3,
	}, { Util.round(), Util.stroke(Colors.Border), Util.hlist(0), Util.padding(0, 6) })
	segmented(frame, PRESETS, 1, 15, Colors.Primary, Colors.Text)
	return frame
end

export type FilterBar = {
	Frame: Frame,
}

function FilterBar.new(onQuickBuyChanged: (number) -> ()): FilterBar
	local frame: Frame = create("Frame", {
		Name = "FilterBar",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, FilterBar.Height),
	})

	local left = tabs()
	left.AnchorPoint = Vector2.new(0, 0.5)
	left.Position = UDim2.fromScale(0, 0.5)
	left.Parent = frame

	local right = Util.group("Right", 0, Util.hlist(14, nil, Enum.HorizontalAlignment.Right))
	right.AnchorPoint = Vector2.new(1, 0.5)
	right.Position = UDim2.fromScale(1, 0.5)
	right.Parent = frame

	local times = Util.group("Timeframes", 1, Util.hlist(4))
	times.Parent = right
	segmented(times, TIMEFRAMES, 2, 17, Colors.Primary, Colors.Text)

	quickBuy(onQuickBuyChanged).Parent = right
	presets().Parent = right

	return { Frame = frame }
end

return FilterBar
