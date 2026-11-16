--!strict
-- Panel ulepszeń: karta na każde ulepszenie z ikoną w kafelku, opisem, poziomem i zielonym przyciskiem ceny.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Panel = require(script.Parent.Panel)
local Theme = require(script.Parent.Theme)
local Tile = require(script.Parent.Tile)
local Util = require(script.Parent.Util)

local create = Util.create
local BuyRemote = ReplicatedStorage.Remotes.BuyUpgrade :: RemoteFunction

local ShopPanel = {}

local CARD_HEIGHT = 108

function ShopPanel.new(parent: Instance, onClose: () -> (), toast: (string, boolean?) -> ()): Panel.Panel
	local player = Players.LocalPlayer
	local panel = Panel.new("Ulepszenia", Vector2.new(640, 560), parent, onClose)
	local scroll = Panel.scroller(panel.body, Util.list(Enum.FillDirection.Vertical, 12, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top))

	local refreshers: { () -> () } = {}

	for order, def in Config.Upgrades do
		local card = create("Frame", {
			Name = def.id,
			BackgroundColor3 = Color3.new(1, 1, 1),
			Size = UDim2.new(1, 0, 0, CARD_HEIGHT),
			LayoutOrder = order,
			Parent = scroll,
		}, { Util.corner(12), Util.stroke(3) })

		Tile.new({
			Name = "IconTile",
			Size = Vector2.new(80, 80),
			Palette = Theme.Palettes.Cyan,
			Text = def.icon,
			TextSize = 44,
			Position = UDim2.fromOffset(12, 10),
			Parent = card,
		}).setEnabled(false)

		Util.label({
			Text = def.name,
			TextSize = 28,
			Position = UDim2.fromOffset(106, 12),
			AlignX = Enum.TextXAlignment.Left,
			Parent = card,
		})
		local level = Util.label({
			Text = "",
			TextSize = 18,
			Color = Theme.Colors.Gold,
			Position = UDim2.fromOffset(106, 46),
			AlignX = Enum.TextXAlignment.Left,
			Stroke = 2.5,
			Parent = card,
		})
		local description = Util.label({
			Text = def.description,
			TextSize = 16,
			Color = Theme.Colors.TextDark,
			Stroke = 0,
			Position = UDim2.fromOffset(106, 70),
			Size = UDim2.new(1, -290, 0, 32),
			AlignX = Enum.TextXAlignment.Left,
			Parent = card,
		})
		description.TextYAlignment = Enum.TextYAlignment.Top

		local buying = false
		local button: Tile.Tile
		button = Tile.new({
			Name = "Buy",
			Size = Vector2.new(160, 64),
			Palette = Theme.Palettes.Green,
			Text = "",
			TextSize = 28,
			Position = UDim2.new(1, -14, 0.5, -4),
			AnchorPoint = Vector2.new(1, 0.5),
			Parent = card,
			OnClick = function()
				if buying then
					return
				end
				buying = true
				local ok, message = BuyRemote:InvokeServer(def.id)
				buying = false
				toast(message, ok)
			end,
		})

		local function refresh()
			local lvl = player:GetAttribute(`Lvl_{def.id}`) or 0
			local cash = player:GetAttribute("Cash") or 0
			local maxed = lvl >= def.max
			level.Text = if maxed then `MAX  •  {def.effect(lvl)}` else `Poz. {lvl}  •  {def.effect(lvl)} → {def.effect(lvl + 1)}`
			local cost = def.cost(lvl)
			local text = button.text :: TextLabel
			text.Text = if maxed then "MAX" else Format.money(cost)
			local affordable = not maxed and cash >= cost
			button.setPalette(if maxed then Theme.Palettes.Gold elseif affordable then Theme.Palettes.Green else Theme.Palettes.Gray)
			button.setEnabled(not maxed)
		end
		table.insert(refreshers, refresh)
		player:GetAttributeChangedSignal(`Lvl_{def.id}`):Connect(refresh)
		refresh()
	end

	player:GetAttributeChangedSignal("Cash"):Connect(function()
		if panel.isOpen() then
			for _, refresh in refreshers do
				refresh()
			end
		end
	end)
	local open = panel.open
	panel.open = function()
		for _, refresh in refreshers do
			refresh()
		end
		open()
	end
	return panel
end

return ShopPanel
