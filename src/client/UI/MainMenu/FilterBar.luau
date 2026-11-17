--!strict
-- Pasek pod nawigacją: zakładki (Top, Trending...), przedziały czasu, Quick Buy i presety P1-P3.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local Settings = require(script.Parent.Parent.Parent.State.Settings)

local UI = script.Parent.Parent
local Icons = require(UI.Icons)
local Theme = require(UI.Theme)
local Toast = require(UI.Toast)
local Util = require(UI.Util)

local create = Util.create
local Colors = Theme.Colors
local Fonts = Theme.Fonts

type Tab = { Name: string, Badge: string?, Dropdown: boolean?, Sort: ("Top" | "Trending")? }

local TABS: { Tab } = {
	{ Name = "Top", Sort = "Top" },
	{ Name = "Trending", Dropdown = true, Sort = "Trending" },
	{ Name = "Radar", Badge = "NEW" },
	{ Name = "Callouts" },
	{ Name = "Streamers", Badge = "NEW" },
}
local PRESETS = { "P1", "P2", "P3" }

local FilterBar = {}
FilterBar.Height = 72

-- Grupa przycisków, z których tylko jeden jest aktywny.
local function segmented(
	parent: Instance,
	labels: { string },
	isActive: (string) -> boolean,
	size: number,
	onSelect: ((string) -> ())?
): () -> ()
	local buttons: { TextButton } = {}
	local function refresh()
		for _, b in buttons do
			Util.tween(b, { TextColor3 = if isActive(b.Name) then Colors.Primary else Colors.Text })
		end
	end
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
			TextColor3 = if isActive(label) then Colors.Primary else Colors.Text,
			LayoutOrder = i,
			Parent = parent,
		}, { Util.padding(0, 8) })
		button.Activated:Connect(function()
			if onSelect then
				onSelect(label)
			end
			refresh()
		end)
		table.insert(buttons, button)
	end
	return refresh
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
	local labels: { [string]: TextLabel } = {}

	local function isActive(tab: Tab): boolean
		return tab.Sort ~= nil and tab.Sort == Settings.State.Sort
	end
	local function refresh()
		for _, tab in TABS do
			Util.tween(labels[tab.Name], { TextColor3 = if isActive(tab) then Colors.Text else Colors.TextMuted })
		end
	end

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
			Color = if isActive(tab) then Colors.Text else Colors.TextMuted,
			Order = 1,
			Parent = content,
		})
		labels[tab.Name] = label
		if tab.Dropdown then
			Icons.chevronDown(14, Colors.TextMuted, 2).Parent = content
		end
		if tab.Badge then
			badge(tab.Badge).Parent = button
		end
		button.Activated:Connect(function()
			if tab.Sort then
				Settings.set("Sort", tab.Sort)
			else
				Toast.show(`{tab.Name} is coming soon`, "Info")
			end
		end)
		button.MouseEnter:Connect(function()
			if not isActive(tab) then
				Util.tween(label, { TextColor3 = Color3.fromHex("B4B7C5") })
			end
		end)
		button.MouseLeave:Connect(function()
			if not isActive(tab) then
				Util.tween(label, { TextColor3 = Colors.TextMuted })
			end
		end)
	end
	Settings.Changed:Connect(function(key: string)
		if key == "Sort" then
			refresh()
		end
	end)
	return frame
end

local function quickBuy(): Frame
	local box = create("Frame", {
		Name = "QuickBuy",
		Size = UDim2.fromOffset(200, 40),
		BackgroundColor3 = Colors.Background,
		LayoutOrder = 2,
	}, { Util.round(), Util.stroke(Colors.Border), Util.padding(0, 14) })
	Util.label({
		Text = "Quick Buy",
		Size = 16,
		Color = Colors.TextMuted,
		FrameSize = UDim2.new(0, 76, 1, 0),
		Parent = box,
	})
	local input: TextBox = create("TextBox", {
		Name = "Amount",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(80, 0),
		Size = UDim2.new(1, -104, 1, 0),
		ClearTextOnFocus = false,
		Text = Format.decimal(Settings.State.QuickBuy),
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

	input.FocusLost:Connect(function()
		local amount = tonumber(input.Text)
		if not amount or amount ~= amount or amount < 0 or amount == math.huge then
			amount = Settings.State.QuickBuy
		end
		local value = amount :: number
		input.Text = Format.decimal(value)
		Settings.set("QuickBuy", value)
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
	local active = "P1"
	segmented(
		frame,
		PRESETS,
		function(label)
			return label == active
		end,
		15,
		function(label)
			active = label
		end
	)
	return frame
end

export type FilterBar = {
	Frame: Frame,
}

function FilterBar.new(): FilterBar
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
	local keys = {}
	for i, timeframe in Config.Timeframes do
		keys[i] = timeframe.Key
	end
	segmented(
		times,
		keys,
		function(label)
			return label == Settings.State.Timeframe
		end,
		17,
		function(label)
			Settings.set("Timeframe", label)
		end
	)

	quickBuy().Parent = right
	presets().Parent = right

	return { Frame = frame }
end

return FilterBar
