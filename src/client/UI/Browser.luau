--!strict
-- Okno "przeglądarki", w którym gracz ogląda rxiom.pro: pasek kart i pasek adresu jak w Chrome.
-- Rysowane w prawdziwych pikselach (bez UIScale), żeby zawsze pasowało do przycisków Robloxa,
-- które pełnią tu rolę przycisków okna: pasek kart ma ich wysokość, a karta zaczyna się obok nich.

local Icons = require(script.Parent.Icons)
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local create = Util.create
local Colors = Theme.Colors
local Fonts = Theme.Fonts

local MIN_STRIP_HEIGHT = 40
local TOOLBAR_HEIGHT = 44
local TAB_WIDTH = 260

export type Callbacks = {
	Back: () -> (),
	Forward: () -> (),
	Refresh: () -> (),
}

export type Browser = {
	Frame: Frame,
	SetPage: (title: string, path: string) -> (),
	SetHistory: (canBack: boolean, canForward: boolean) -> (),
	-- `left`: gdzie kończą się przyciski Robloxa, `topbarHeight`: ich obszar w pionie (piksele ekranu).
	-- Zwraca wysokość całego okna przeglądarki.
	Layout: (left: number, topbarHeight: number) -> number,
}

local Browser = {}

local function toolButton(name: string, order: number): TextButton
	local button: TextButton = create("TextButton", {
		Name = name,
		AutoButtonColor = false,
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = Colors.ChromeField,
		BackgroundTransparency = 1,
		Text = "",
		LayoutOrder = order,
	}, { Util.round() })
	Util.hoverBackground(button, Colors.ChromeField, Colors.ChromeField, 1)
	return button
end

local function center(icon: Frame, parent: Instance)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Parent = parent
end

function Browser.new(callbacks: Callbacks): Browser
	local frame: Frame = create("Frame", {
		Name = "Browser",
		Size = UDim2.new(1, 0, 0, MIN_STRIP_HEIGHT + TOOLBAR_HEIGHT),
		BackgroundColor3 = Colors.ChromeStrip,
		BorderSizePixel = 0,
		ZIndex = 10,
	})

	-- Pasek kart
	local strip: Frame = create("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, MIN_STRIP_HEIGHT),
		Parent = frame,
	})
	local stripPadding = Util.padding(8, 0, 0, 10) :: UIPadding
	stripPadding.Parent = strip
	local tabs = Util.group("List", 0, Util.hlist(4, Enum.VerticalAlignment.Bottom))
	tabs.AutomaticSize = Enum.AutomaticSize.X
	tabs.Size = UDim2.fromScale(0, 1)
	tabs.Parent = strip

	local tab: Frame = create("Frame", {
		Name = "Tab",
		Size = UDim2.new(0, TAB_WIDTH, 1, 0),
		BackgroundColor3 = Colors.ChromeBar,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		Parent = tabs,
	}, { Util.corner(10) })
	-- Kwadratowe dolne rogi: karta przechodzi płynnie w pasek adresu.
	create("Frame", {
		Name = "Base",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 12),
		BackgroundColor3 = Colors.ChromeBar,
		BorderSizePixel = 0,
		Parent = tab,
	})
	local tabContent = create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = tab,
	}, { Util.padding(0, 12, 0, 14) })
	local favicon = create("Frame", {
		Name = "Favicon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = Colors.ChromeStrip,
		Parent = tabContent,
	}, { Util.corner(5) })
	center(Icons.logo(10), favicon)
	local title = Util.label({
		Name = "Title",
		Text = "RXIOM",
		Size = 15,
		Font = Fonts.Medium,
		Position = UDim2.fromOffset(30, 0),
		FrameSize = UDim2.new(1, -56, 1, 0),
		Parent = tabContent,
	})
	local closeIcon = Icons.close(12, Colors.TextMuted)
	closeIcon.AnchorPoint = Vector2.new(1, 0.5)
	closeIcon.Position = UDim2.fromScale(1, 0.5)
	closeIcon.Parent = tabContent

	create("TextLabel", {
		Name = "NewTab",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 34, 1, 0),
		Text = "+",
		TextSize = 22,
		FontFace = Fonts.Regular,
		TextColor3 = Colors.TextMuted,
		LayoutOrder = 2,
		Parent = tabs,
	})

	-- Pasek adresu na całą szerokość
	local toolbar: Frame = create("Frame", {
		Name = "Toolbar",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, TOOLBAR_HEIGHT),
		BackgroundColor3 = Colors.ChromeBar,
		BorderSizePixel = 0,
		Parent = frame,
	})
	local divider = Util.divider()
	divider.AnchorPoint = Vector2.new(0, 1)
	divider.Position = UDim2.fromScale(0, 1)
	divider.Parent = toolbar

	local nav = Util.group("Nav", 0, Util.hlist(4))
	nav.AnchorPoint = Vector2.new(0, 0.5)
	nav.Position = UDim2.new(0, 10, 0.5, 0)
	nav.Parent = toolbar
	local backButton = toolButton("Back", 1)
	local backIcon = Icons.arrow(16, Colors.Text, "Left")
	center(backIcon, backButton)
	backButton.Parent = nav
	local forwardButton = toolButton("Forward", 2)
	local forwardIcon = Icons.arrow(16, Colors.Text, "Right")
	center(forwardIcon, forwardButton)
	forwardButton.Parent = nav
	local refreshButton = toolButton("Refresh", 3)
	center(Icons.refresh(16, Colors.Text, Colors.ChromeBar), refreshButton)
	refreshButton.Parent = nav

	local address: Frame = create("Frame", {
		Name = "Address",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 124, 0.5, 0),
		Size = UDim2.new(1, -136, 0, 32),
		BackgroundColor3 = Colors.ChromeField,
		Parent = toolbar,
	}, { Util.round(), Util.padding(0, 16) })
	local lock = Icons.lock(13, Colors.TextMuted)
	lock.AnchorPoint = Vector2.new(0, 0.5)
	lock.Position = UDim2.fromScale(0, 0.5)
	lock.Parent = address
	local url: TextLabel = create("TextLabel", {
		Name = "Url",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(24, 0),
		Size = UDim2.new(1, -24, 1, 0),
		RichText = true,
		Text = "",
		TextSize = 15,
		FontFace = Fonts.Regular,
		TextColor3 = Colors.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = address,
	})

	backButton.Activated:Connect(callbacks.Back)
	forwardButton.Activated:Connect(callbacks.Forward)
	refreshButton.Activated:Connect(callbacks.Refresh)

	local function setIconColor(icon: Frame, enabled: boolean)
		for _, part in icon:GetChildren() do
			if part:IsA("Frame") then
				part.BackgroundColor3 = if enabled then Colors.Text else Colors.TextDim
			end
		end
	end

	return {
		Frame = frame,
		SetPage = function(pageTitle: string, path: string)
			title.Text = pageTitle
			url.Text = `<font color="#FFFFFF">{Theme.Site}</font>{path}`
		end,
		SetHistory = function(canBack: boolean, canForward: boolean)
			setIconColor(backIcon, canBack)
			setIconColor(forwardIcon, canForward)
			backButton.Active = canBack
			forwardButton.Active = canForward
		end,
		Layout = function(left: number, topbarHeight: number): number
			local stripHeight = math.max(MIN_STRIP_HEIGHT, math.ceil(topbarHeight))
			strip.Size = UDim2.new(1, 0, 0, stripHeight)
			-- Górny margines karty jak margines przycisków Robloxa, żeby ich górne krawędzie się zgadzały.
			stripPadding.PaddingTop = UDim.new(0, math.clamp(math.round(stripHeight * 0.2), 6, 12))
			stripPadding.PaddingLeft = UDim.new(0, math.max(10, math.ceil(left)))
			local total = stripHeight + TOOLBAR_HEIGHT
			frame.Size = UDim2.new(1, 0, 0, total)
			return total
		end,
	}
end

return Browser
