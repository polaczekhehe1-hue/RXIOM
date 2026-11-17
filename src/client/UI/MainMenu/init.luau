--!strict
-- Główny interfejs RXIOM (wzorowany na axiom.trade): górny pasek, strony Discover / coin / Portfolio,
-- dolny pasek i powiadomienia.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local UI = script.Parent
local Theme = require(UI.Theme)
local Toast = require(UI.Toast)
local Util = require(UI.Util)

local BottomBar = require(script.BottomBar)
local CoinView = require(script.CoinView)
local FilterBar = require(script.FilterBar)
local PortfolioPage = require(script.PortfolioPage)
local TokenTable = require(script.TokenTable)
local TopBar = require(script.TopBar)

local create = Util.create

local CONTENT_PADDING = 32

local MainMenu = {}

local function hideDefaultCoreGui()
	for _, kind in { Enum.CoreGuiType.Backpack, Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Health } do
		StarterGui:SetCoreGuiEnabled(kind, false)
	end
end

function MainMenu.mount(): ScreenGui
	hideDefaultCoreGui()

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui: ScreenGui = create("ScreenGui", {
		Name = "RXIOM",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	create("Frame", {
		Name = "Background",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Background,
		BorderSizePixel = 0,
		Parent = gui,
	})

	-- Layout projektowany pod Theme.DesignSize i skalowany UIScale do ekranu.
	local root: Frame = create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local uiScale: UIScale = create("UIScale", { Parent = root })

	local content: Frame = create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, TopBar.Height),
		Size = UDim2.new(1, 0, 1, -(TopBar.Height + BottomBar.Height)),
		Parent = root,
	}, { Util.padding(16, CONTENT_PADDING, 16, CONTENT_PADDING) })

	local pages: { [string]: GuiObject } = {}
	local topBar: TopBar.TopBar
	local coinView: CoinView.CoinView
	local portfolioPage: PortfolioPage.PortfolioPage

	local function show(name: string)
		for pageName, page in pages do
			page.Visible = pageName == name
		end
		topBar.SetActive(if name == "Portfolio" then "Portfolio" else "Discover")
	end

	local function openCoin(ticker: string)
		show("Coin")
		coinView.Open(ticker)
	end

	local navigation: TopBar.Navigation = {
		Discover = function()
			show("Discover")
		end,
		Portfolio = function()
			show("Portfolio")
			portfolioPage.Refresh()
		end,
	}

	topBar = TopBar.new(navigation)
	topBar.Frame.Parent = root

	-- Discover: filtry + tabela coinów
	local discover: Frame = create("Frame", {
		Name = "Discover",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = content,
	})
	FilterBar.new().Frame.Parent = discover
	local tokenTable = TokenTable.new(openCoin)
	tokenTable.Frame.Position = UDim2.fromOffset(0, FilterBar.Height)
	tokenTable.Frame.Size = UDim2.new(1, 0, 1, -FilterBar.Height)
	tokenTable.Frame.Parent = discover
	pages.Discover = discover

	coinView = CoinView.new(navigation.Discover)
	coinView.Frame.Parent = content
	pages.Coin = coinView.Frame

	portfolioPage = PortfolioPage.new(openCoin)
	portfolioPage.Frame.Parent = content
	pages.Portfolio = portfolioPage.Frame

	BottomBar.new().Frame.Parent = root
	Toast.mount(root, BottomBar.Height + 16)

	show("Discover")

	local function relayout()
		local viewport = gui.AbsoluteSize
		if viewport.X <= 0 or viewport.Y <= 0 then
			return
		end
		local design = Theme.DesignSize
		local scale = math.clamp(math.min(viewport.X / design.X, viewport.Y / design.Y), 0.5, 2)
		uiScale.Scale = scale
		root.Size = UDim2.fromOffset(viewport.X / scale, viewport.Y / scale)

		local inset = GuiService.TopbarInset
		topBar.SetInsets(inset.Min.X / scale + 8, math.max(0, viewport.X - inset.Max.X) / scale)
	end

	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(relayout)
	relayout()

	return gui
end

return MainMenu
