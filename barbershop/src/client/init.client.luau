--!strict
-- Start klienta: HUD, efekty "+1" i obsługa trybu strzyżenia.

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Format"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Effects = require(script.UI.Effects)
local Hud = require(script.UI.Hud)
local Theme = require(script.UI.Theme)
local ShaveController = require(script.ShaveController)

local hud = Hud.mount({
	onExit = ShaveController.exit,
	onRotate = ShaveController.rotate,
})
Effects.mount(hud.scale)

ShaveController.init({
	setActive = hud.setShaveMode,
	setProgress = hud.setProgress,
})

local SessionRemote = Remotes:WaitForChild("Session") :: RemoteEvent
local GainRemote = Remotes:WaitForChild("Gain") :: RemoteEvent
local ToastRemote = Remotes:WaitForChild("Toast") :: RemoteEvent

SessionRemote.OnClientEvent:Connect(function(action: string, model: Model?, standCFrame: CFrame?)
	if action == "start" and model and standCFrame then
		ShaveController.start(model, standCFrame)
	else
		ShaveController.stop()
	end
end)

GainRemote.OnClientEvent:Connect(function(amount: number, kind: string, position: Vector3?)
	local text = "+" .. Format.compact(amount)
	if kind == "shave" and position then
		Effects.popWorld(position, text)
	elseif kind == "tip" then
		Effects.big(`Tip! +{Format.compact(amount)} Coins`)
	elseif kind == "helper" then
		Effects.popAt(hud.cashAnchor() + Vector2.new(0, 40 * hud.scale()), text, Theme.Colors.Coin, 26)
	end
end)

ToastRemote.OnClientEvent:Connect(function(message: string)
	hud.toast(message)
end)

print("[BarberShop] Client ready")
