--!strict
-- Panel rebirthu: reset kasy i ulepszeń w zamian za stały mnożnik zarobków.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Icons = require(script.Parent.Icons)
local Panel = require(script.Parent.Panel)
local Theme = require(script.Parent.Theme)
local Tile = require(script.Parent.Tile)
local Util = require(script.Parent.Util)

local RebirthRemote = ReplicatedStorage.Remotes.Rebirth :: RemoteFunction

local RebirthPanel = {}

function RebirthPanel.new(parent: Instance, onClose: () -> (), onDone: (string, boolean) -> ()): Panel.Panel
	local player = Players.LocalPlayer
	local panel = Panel.new("Rebirth", Vector2.new(480, 440), parent, onClose)
	local body = panel.body

	local gemHolder = Util.create("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(90, 90),
		Parent = body,
	})
	Icons.gem(gemHolder)

	local multi = Util.label({
		Text = "",
		TextSize = 44,
		Color = Theme.Colors.Gold,
		Position = UDim2.new(0.5, 0, 0, 112),
		AnchorPoint = Vector2.new(0.5, 0),
		Stroke = 4,
		Parent = body,
	})
	Util.label({
		Text = "Tracisz kasę i ulepszenia salonu,\nale na zawsze zarabiasz więcej za każdy włos!",
		TextSize = 18,
		Color = Theme.Colors.TextDark,
		Stroke = 0,
		Size = UDim2.new(1, -40, 0, 50),
		Position = UDim2.new(0.5, 0, 0, 170),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = body,
	})

	local busy = false
	local button = Tile.new({
		Name = "Rebirth",
		Size = Vector2.new(260, 74),
		Palette = Theme.Palettes.Purple,
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
		local cash = player:GetAttribute("Cash") or 0
		local cost = Config.rebirthCost(rebirths)
		multi.Text = `×{Config.multiplier(rebirths)}  →  ×{Config.multiplier(rebirths + 1)}`
		local text = button.text :: TextLabel
		text.Text = `Rebirth  {Format.money(cost)}`
		button.setPalette(if cash >= cost then Theme.Palettes.Purple else Theme.Palettes.Gray)
	end
	player:GetAttributeChangedSignal("Cash"):Connect(refresh)
	player:GetAttributeChangedSignal("Rebirths"):Connect(refresh)
	refresh()
	return panel
end

return RebirthPanel
