--!strict
-- Główne menu RXIOM (wzorowane na zakładce Discover z axiom.trade).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local UI = script.Parent
local Theme = require(UI.Theme)
local Util = require(UI.Util)

local BottomBar = require(script.BottomBar)
local FilterBar = require(script.FilterBar)
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

	local topBar = TopBar.new()
	topBar.Frame.Parent = root

	local tokenTable = TokenTable.new()
	local filterBar = FilterBar.new(tokenTable.SetQuickBuy)

	create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, TopBar.Height),
		Size = UDim2.new(1, 0, 1, -(TopBar.Height + BottomBar.Height)),
		Parent = root,
	}, {
		Util.padding(0, CONTENT_PADDING, 16, CONTENT_PADDING),
		filterBar.Frame,
		tokenTable.Frame,
	})
	tokenTable.Frame.Position = UDim2.fromOffset(0, FilterBar.Height)
	tokenTable.Frame.Size = UDim2.new(1, 0, 1, -FilterBar.Height)

	BottomBar.new().Frame.Parent = root

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
