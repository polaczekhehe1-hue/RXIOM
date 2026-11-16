--!strict
-- Górny pasek: logo, nawigacja, wyszukiwarka, Deposit, portfel, avatar.

local Players = game:GetService("Players")

local UI = script.Parent.Parent
local Icons = require(UI.Icons)
local Theme = require(UI.Theme)
local Util = require(UI.Util)

local create = Util.create
local Colors = Theme.Colors
local Fonts = Theme.Fonts

local NAV_ITEMS = { "Discover", "Pulse", "Trackers", "Perpetuals", "Predictions", "Portfolio", "Rewards" }

local TopBar = {}
TopBar.Height = 64

local function logo(): Frame
	local frame = Util.group("Logo", 1, Util.hlist(10))
	Icons.logo(24, 1).Parent = frame
	Util.text({ Text = "RXIOM", Size = 26, Font = Fonts.Bold, Order = 2, Parent = frame })
	return frame
end

local function nav(): Frame
	local frame = Util.group("Nav", 2, Util.hlist(4))
	local buttons: { TextButton } = {}

	local function setActive(active: TextButton)
		for _, b in buttons do
			Util.tween(b, { TextColor3 = if b == active then Colors.Primary else Colors.Text })
		end
	end

	for i, name in NAV_ITEMS do
		local button: TextButton = create("TextButton", {
			Name = name,
			AutoButtonColor = false,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 36),
			BackgroundColor3 = Colors.Elevated,
			BackgroundTransparency = 1,
			Text = name,
			TextSize = 17,
			FontFace = Fonts.SemiBold,
			TextColor3 = if i == 1 then Colors.Primary else Colors.Text,
			LayoutOrder = i,
			Parent = frame,
		}, { Util.padding(0, 12), Util.corner(8) })
		Util.hoverBackground(button, Colors.Elevated, Colors.Elevated, 1)
		button.Activated:Connect(function()
			setActive(button)
		end)
		table.insert(buttons, button)
	end
	return frame
end

local function searchBox(): (Frame, TextBox)
	local box = create("Frame", {
		Name = "Search",
		Size = UDim2.fromOffset(206, 40),
		BackgroundColor3 = Colors.Background,
		LayoutOrder = 1,
	}, { Util.round(), Util.stroke(Colors.Border), Util.padding(0, 10, 0, 14) })
	local icon = Icons.search(16, Colors.Text)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.fromScale(0, 0.5)
	icon.Parent = box
	local input: TextBox = create("TextBox", {
		Name = "Input",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(26, 0),
		Size = UDim2.new(1, -56, 1, 0),
		ClearTextOnFocus = false,
		Text = "",
		PlaceholderText = "Search by token or CA",
		PlaceholderColor3 = Colors.TextMuted,
		TextColor3 = Colors.Text,
		TextSize = 15,
		FontFace = Fonts.Regular,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = box,
	})
	create("TextLabel", {
		Name = "Shortcut",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(22, 22),
		BackgroundTransparency = 1,
		Text = "/",
		TextSize = 13,
		FontFace = Fonts.Medium,
		TextColor3 = Colors.Text,
		Parent = box,
	}, { Util.corner(6), Util.stroke(Colors.Border) })
	box.MouseEnter:Connect(function()
		Util.tween(box, { BackgroundColor3 = Colors.Surface })
	end)
	box.MouseLeave:Connect(function()
		Util.tween(box, { BackgroundColor3 = Colors.Background })
	end)
	return box, input
end

local function pillButton(name: string, order: number, width: number?): TextButton
	return create("TextButton", {
		Name = name,
		AutoButtonColor = false,
		AutomaticSize = if width then Enum.AutomaticSize.None else Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(width or 0, 40),
		BackgroundColor3 = Colors.Elevated,
		Text = "",
		LayoutOrder = order,
	}, { Util.round() })
end

local function depositButton(): TextButton
	local button = pillButton("Deposit", 2)
	button.BackgroundColor3 = Colors.Primary
	button.Text = "Deposit"
	button.TextSize = 16
	button.FontFace = Fonts.SemiBold
	button.TextColor3 = Colors.Text
	Util.padding(0, 18).Parent = button
	Util.hoverBackground(button, Colors.Primary, Colors.PrimaryHover)
	return button
end

local function favoritesButton(): TextButton
	local button = pillButton("Favorites", 3, 40)
	local star = Icons.star(18, Colors.Text)
	star.AnchorPoint = Vector2.new(0.5, 0.5)
	star.Position = UDim2.fromScale(0.5, 0.5)
	star.Parent = button
	Util.hoverBackground(button, Colors.Elevated, Colors.Border)
	return button
end

local function walletButton(): (TextButton, TextLabel)
	local button = pillButton("Wallet", 4)
	Util.padding(0, 14).Parent = button
	Util.hlist(8).Parent = button
	Icons.currency(16, 1).Parent = button
	local balance = Util.text({ Text = "0", Size = 17, Font = Fonts.SemiBold, Order = 2, Parent = button })
	Icons.chevronDown(12, Colors.TextMuted, 3).Parent = button
	Util.hoverBackground(button, Colors.Elevated, Colors.Border)
	return button, balance
end

local function avatar(): ImageLabel
	local image: ImageLabel = create("ImageLabel", {
		Name = "Avatar",
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = Colors.Elevated,
		LayoutOrder = 5,
	}, { Util.round() })
	task.spawn(function()
		local player = Players.LocalPlayer
		local ok, content = pcall(
			Players.GetUserThumbnailAsync,
			Players,
			player.UserId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size100x100
		)
		if ok then
			image.Image = content
		end
	end)
	return image
end

export type TopBar = {
	Frame: Frame,
	Search: TextBox,
	Balance: TextLabel,
	SetInsets: (left: number, right: number) -> (),
}

function TopBar.new(): TopBar
	local frame: Frame = create("Frame", {
		Name = "TopBar",
		Size = UDim2.new(1, 0, 0, TopBar.Height),
		BackgroundColor3 = Colors.Background,
		BorderSizePixel = 0,
	})
	create("Frame", {
		Name = "Divider",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Colors.Border,
		BorderSizePixel = 0,
		Parent = frame,
	})
	local inner: Frame = create("Frame", {
		Name = "Inner",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = frame,
	})
	local padding = Util.padding(0, 24) :: UIPadding
	padding.Parent = inner

	local left = Util.group("Left", 0, Util.hlist(32))
	left.AnchorPoint = Vector2.new(0, 0.5)
	left.Position = UDim2.fromScale(0, 0.5)
	left.Parent = inner
	logo().Parent = left
	nav().Parent = left

	local right = Util.group("Right", 0, Util.hlist(12, nil, Enum.HorizontalAlignment.Right))
	right.AnchorPoint = Vector2.new(1, 0.5)
	right.Position = UDim2.fromScale(1, 0.5)
	right.Parent = inner
	local search, input = searchBox()
	search.Parent = right
	depositButton().Parent = right
	favoritesButton().Parent = right
	local wallet, balance = walletButton()
	wallet.Parent = right
	avatar().Parent = right

	return {
		Frame = frame,
		Search = input,
		Balance = balance,
		-- Odsuwa treść od przycisków Robloxa (menu, czat) w lewym górnym rogu.
		SetInsets = function(leftInset: number, rightInset: number)
			padding.PaddingLeft = UDim.new(0, math.max(24, leftInset))
			padding.PaddingRight = UDim.new(0, math.max(24, rightInset))
		end,
	}
end

return TopBar
