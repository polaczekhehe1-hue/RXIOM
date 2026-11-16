--!strict
-- Upgrades panel: one card per upgrade with an icon tile, description, level and a green coin-price button.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Icons = require(script.Parent.Icons)
local Panel = require(script.Parent.Panel)
local Theme = require(script.Parent.Theme)
local Tile = require(script.Parent.Tile)
local Util = require(script.Parent.Util)

local create = Util.create
local BuyRemote = ReplicatedStorage.Remotes.BuyUpgrade :: RemoteFunction

local ShopPanel = {}

local CARD_HEIGHT = 108

-- Przycisk z ceną: moneta po lewej, kwota obok.
function ShopPanel.priceButton(props: Tile.TileProps): (Tile.Tile, TextLabel)
	local button = Tile.new(props)
	local coinHolder = create("Frame", {
		Name = "Coin",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(props.Size.Y * 0.62, props.Size.Y * 0.62),
		ZIndex = 4,
		Parent = button.face,
	})
	Icons.coin(coinHolder)
	local text = button.text :: TextLabel
	text.Position = UDim2.fromOffset(props.Size.Y * 0.62 + 6, 0)
	text.Size = UDim2.new(1, -(props.Size.Y * 0.62 + 12), 1, 0)
	return button, text
end

function ShopPanel.new(parent: Instance, onClose: () -> (), toast: (string, boolean?) -> ()): Panel.Panel
	local player = Players.LocalPlayer
	local panel = Panel.new("Upgrades", Vector2.new(640, 560), parent, onClose)
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
			Color = Theme.Colors.Coin,
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
		local button, priceText = ShopPanel.priceButton({
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
		local coin = button.face:FindFirstChild("Coin") :: Frame

		local function refresh()
			local lvl = player:GetAttribute(`Lvl_{def.id}`) or 0
			local coins = player:GetAttribute("Coins") or 0
			local maxed = lvl >= def.max
			level.Text = if maxed then `MAX  •  {def.effect(lvl)}` else `Lv. {lvl}  •  {def.effect(lvl)} → {def.effect(lvl + 1)}`
			local cost = def.cost(lvl)
			coin.Visible = not maxed
			priceText.Text = if maxed then "MAX" else Format.compact(cost)
			local affordable = not maxed and coins >= cost
			button.setPalette(if maxed then Theme.Palettes.Gold elseif affordable then Theme.Palettes.Green else Theme.Palettes.Gray)
			button.setEnabled(not maxed)
		end
		table.insert(refreshers, refresh)
		player:GetAttributeChangedSignal(`Lvl_{def.id}`):Connect(refresh)
		refresh()
	end

	player:GetAttributeChangedSignal("Coins"):Connect(function()
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
