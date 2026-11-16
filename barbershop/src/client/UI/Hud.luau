--!strict
-- HUD: licznik kasy i klientów, kafelki Ulepsz/Rebirth po lewej, komunikaty u góry
-- oraz osobny zestaw kontrolek w trybie strzyżenia (wyjście, obrót głowy, pasek włosów).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Format = require(ReplicatedStorage.Shared.Format)
local Icons = require(script.Parent.Icons)
local Panel = require(script.Parent.Panel)
local RebirthPanel = require(script.Parent.RebirthPanel)
local ShopPanel = require(script.Parent.ShopPanel)
local Theme = require(script.Parent.Theme)
local Tile = require(script.Parent.Tile)
local Util = require(script.Parent.Util)

local create = Util.create

export type Callbacks = {
	onExit: () -> (),
	onRotate: (direction: number, held: boolean) -> (),
}

export type Hud = {
	gui: ScreenGui,
	scale: () -> number,
	toast: (message: string, ok: boolean?) -> (),
	setShaveMode: (enabled: boolean) -> (),
	setProgress: (remaining: number, total: number) -> (),
	cashAnchor: () -> Vector2,
}

local Hud = {}

-- Licznik: kafelek z ikoną po lewej i dużą liczbą obok.
local function counter(parent: Instance, name: string, palette: Theme.Palette, size: Vector2, order: number, icon: (Frame) -> ()): TextLabel
	local tile = Tile.new({ Name = name, Size = size, Palette = palette, Order = order, Parent = parent })
	tile.setEnabled(false)
	local iconHolder = create("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, size.Y / 2 - 2, 0.5, 0),
		Size = UDim2.fromOffset(size.Y + 6, size.Y + 6),
		ZIndex = 4,
		Parent = tile.face,
	})
	icon(iconHolder)
	return Util.label({
		Text = "0",
		TextSize = math.floor(size.Y * 0.56),
		Position = UDim2.new(0, size.Y + 10, 0.5, 0),
		Size = UDim2.new(1, -size.Y - 22, 1, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		AlignX = Enum.TextXAlignment.Left,
		ZIndex = 4,
		Stroke = 3.5,
		Parent = tile.face,
	})
end

local function hideCoreGui()
	for _, kind in { Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Health } do
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, kind, false)
	end
end

function Hud.mount(callbacks: Callbacks): Hud
	hideCoreGui()
	local player = Players.LocalPlayer
	local gui: ScreenGui = create("ScreenGui", {
		Name = "BarberHud",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local root = create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})
	local uiScale = create("UIScale", { Parent = root })
	local camera = workspace.CurrentCamera
	local function updateScale()
		local viewport = camera.ViewportSize
		uiScale.Scale = math.clamp(math.min(viewport.Y / Theme.DesignHeight, viewport.X / 1000), 0.45, 1.4)
		-- Przy UIScale treść musi zajmować ekran w jednostkach "przed skalowaniem".
		root.Size = UDim2.fromScale(1 / uiScale.Scale, 1 / uiScale.Scale)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	updateScale()

	-- Liczniki w lewym górnym rogu, pod przyciskiem menu Robloxa.
	local stats = create("Frame", {
		Name = "Stats",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 70),
		Size = UDim2.fromOffset(300, 160),
		Parent = root,
	}, { Util.list(Enum.FillDirection.Vertical, 12, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
	local cashLabel = counter(stats, "Coins", Theme.Palettes.Gold, Vector2.new(270, 72), 1, Icons.coin)
	local shavedLabel = counter(stats, "Shaved", Theme.Palettes.Cyan, Vector2.new(210, 54), 2, Icons.scissors)

	-- Menu po lewej: kafelki jak na referencji.
	local panels: { Panel.Panel } = {}
	local function closeAll()
		for _, p in panels do
			if p.isOpen() then
				p.close()
			end
		end
	end
	local function toggle(p: Panel.Panel)
		local wasOpen = p.isOpen()
		closeAll()
		if not wasOpen then
			p.open()
		end
	end

	local toastHolder = create("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 74),
		Size = UDim2.fromOffset(600, 200),
		ZIndex = 50,
		Parent = root,
	}, { Util.list(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top) })

	local function toast(message: string, ok: boolean?)
		local tile = Tile.new({
			Name = "Toast",
			Size = Vector2.new(math.clamp(#message * 13 + 60, 240, 600), 56),
			Palette = if ok == false then Theme.Palettes.Red elseif ok == true then Theme.Palettes.Green else Theme.Palettes.Cyan,
			Text = message,
			Pattern = false,
			TextSize = 24,
			Parent = toastHolder,
		})
		tile.setEnabled(false)
		local s = create("UIScale", { Scale = 0.5, Parent = tile.face })
		Util.tween(s, Util.Pop, { Scale = 1 })
		task.delay(2.2, function()
			Util.tween(s, TweenInfo.new(0.15), { Scale = 0 }).Completed:Once(function()
				tile.root:Destroy()
			end)
		end)
	end

	local upgradePanel: Panel.Panel
	local rebirthPanel: Panel.Panel
	upgradePanel = ShopPanel.new(root, function()
		upgradePanel.close()
	end, toast)
	rebirthPanel = RebirthPanel.new(root, function()
		rebirthPanel.close()
	end, function(message, ok)
		toast(message, ok)
		if ok then
			rebirthPanel.close()
		end
	end)
	table.insert(panels, upgradePanel)
	table.insert(panels, rebirthPanel)

	local menu = create("Frame", {
		Name = "Menu",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 24, 0.55, 0),
		Size = UDim2.fromOffset(130, 300),
		Parent = root,
	}, { Util.list(Enum.FillDirection.Vertical, 26, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	Tile.new({
		Name = "Upgrades",
		Size = Vector2.new(118, 118),
		Palette = Theme.Palettes.Green,
		Icon = function(c)
			Icons.arrowUp(c)
		end,
		IconScale = 0.66,
		Label = "Upgrades",
		LabelSize = 30,
		Order = 1,
		Parent = menu,
		OnClick = function()
			toggle(upgradePanel)
		end,
	})
	-- Rebirth 1:1 z referencji: czerwony kafelek z teksturą, strzałki w kółko i czerwona poświata, bez napisu.
	Tile.new({
		Name = "Rebirth",
		Size = Vector2.new(118, 118),
		Palette = Theme.Palettes.Red,
		Icon = Icons.rebirth,
		IconScale = 0.9,
		Glow = Theme.Colors.Glow,
		Order = 2,
		Parent = menu,
		OnClick = function()
			toggle(rebirthPanel)
		end,
	})

	-- Tryb strzyżenia: wyjście, obrót głowy i pasek pozostałych włosów.
	local shaveBar = create("Frame", {
		Name = "ShaveControls",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(620, 200),
		Visible = false,
		Parent = root,
	})
	local progressBack = create("Frame", {
		Name = "Progress",
		BackgroundColor3 = Theme.Palettes.Gray.shadow,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(440, 40),
		Parent = shaveBar,
	}, { Util.round(), Util.stroke() })
	local progressFill = create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 1),
		Parent = progressBack,
	}, { Util.round(), Util.gradient(Theme.Palettes.Green.top, Theme.Palettes.Green.bottom) })
	local progressLabel = Util.label({
		Text = "",
		TextSize = 24,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = progressBack,
	})

	local controls = create("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(620, 130),
		Parent = shaveBar,
	}, { Util.list(Enum.FillDirection.Horizontal, 22, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom) })

	local function rotateTile(text: string, direction: number, order: number)
		local tile = Tile.new({
			Name = "Rotate",
			Size = Vector2.new(84, 84),
			Palette = Theme.Palettes.Cyan,
			Text = text,
			TextSize = 46,
			Order = order,
			Parent = controls,
		})
		tile.face.MouseButton1Down:Connect(function()
			callbacks.onRotate(direction, true)
		end)
		tile.face.MouseButton1Up:Connect(function()
			callbacks.onRotate(direction, false)
		end)
		tile.face.MouseLeave:Connect(function()
			callbacks.onRotate(direction, false)
		end)
	end
	rotateTile("◀", 1, 1)
	Tile.new({
		Name = "Exit",
		Size = Vector2.new(110, 110),
		Palette = Theme.Palettes.Red,
		Icon = function(c)
			Icons.cross(c)
		end,
		IconScale = 0.5,
		Label = "Exit",
		LabelSize = 30,
		Order = 2,
		Parent = controls,
		OnClick = callbacks.onExit,
	})
	rotateTile("▶", -1, 3)

	local hint = Util.label({
		Text = "Hold and swipe over the hair!",
		TextSize = 30,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 120),
		Visible = false,
		Parent = root,
	})

	player:GetAttributeChangedSignal("Coins"):Connect(function()
		cashLabel.Text = Format.compact(player:GetAttribute("Coins") or 0)
	end)
	player:GetAttributeChangedSignal("Shaved"):Connect(function()
		shavedLabel.Text = Format.compact(player:GetAttribute("Shaved") or 0)
	end)
	cashLabel.Text = Format.compact(player:GetAttribute("Coins") or 0)
	shavedLabel.Text = Format.compact(player:GetAttribute("Shaved") or 0)

	return {
		gui = gui,
		scale = function()
			return uiScale.Scale
		end,
		toast = toast,
		setShaveMode = function(enabled: boolean)
			closeAll()
			menu.Visible = not enabled
			shaveBar.Visible = enabled
			hint.Visible = enabled
		end,
		setProgress = function(remaining: number, total: number)
			local done = total - remaining
			progressLabel.Text = `Shaved {done}/{total}`
			Util.tween(progressFill, Util.Quick, { Size = UDim2.fromScale(math.max(done / math.max(total, 1), 0.06), 1) })
		end,
		cashAnchor = function()
			return cashLabel.AbsolutePosition + cashLabel.AbsoluteSize / 2
		end,
	}
end

return Hud
