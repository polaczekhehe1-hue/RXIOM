--!strict
-- Rebirth panel: resets coins and upgrades in exchange for a permanent earnings multiplier.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Icons = require(script.Parent.Icons)
local Panel = require(script.Parent.Panel)
local ShopPanel = require(script.Parent.ShopPanel)
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local RebirthRemote = ReplicatedStorage.Remotes.Rebirth :: RemoteFunction

local RebirthPanel = {}

function RebirthPanel.new(parent: Instance, onClose: () -> (), onDone: (string, boolean) -> ()): Panel.Panel
	local player = Players.LocalPlayer
	local panel = Panel.new("Rebirth", Vector2.new(480, 440), parent, onClose)
	local body = panel.body

	local iconHolder = Util.create("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(96, 96),
		Parent = body,
	})
	Icons.rebirth(iconHolder)

	local multi = Util.label({
		Text = "",
		TextSize = 44,
		Color = Theme.Colors.Coin,
		Position = UDim2.new(0.5, 0, 0, 112),
		AnchorPoint = Vector2.new(0.5, 0),
		Stroke = 4,
		Parent = body,
	})
	Util.label({
		Text = "You lose your coins and shop upgrades,\nbut earn more for every hair forever!",
		TextSize = 18,
		Color = Theme.Colors.TextDark,
		Stroke = 0,
		Size = UDim2.new(1, -40, 0, 50),
		Position = UDim2.new(0.5, 0, 0, 170),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = body,
	})

	local busy = false
	local button, priceText = ShopPanel.priceButton({
		Name = "Rebirth",
		Size = Vector2.new(260, 74),
		Palette = Theme.Palettes.Red,
		Text = "",
		TextSize = 30,
		Position = UDim2.new(0.5, 0, 1, -18),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = body,
		OnClick = function()
			if busy then
				return
			end
			busy = true
			local ok, message = RebirthRemote:InvokeServer()
			busy = false
			onDone(message, ok)
		end,
	})

	local function refresh()
		local rebirths = player:GetAttribute("Rebirths") or 0
		local coins = player:GetAttribute("Coins") or 0
		local cost = Config.rebirthCost(rebirths)
		multi.Text = `×{Config.multiplier(rebirths)}  →  ×{Config.multiplier(rebirths + 1)}`
		priceText.Text = Format.compact(cost)
		button.setPalette(if coins >= cost then Theme.Palettes.Red else Theme.Palettes.Gray)
	end
	player:GetAttributeChangedSignal("Coins"):Connect(refresh)
	player:GetAttributeChangedSignal("Rebirths"):Connect(refresh)
	refresh()
	return panel
end

return RebirthPanel
