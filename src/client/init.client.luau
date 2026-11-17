--!strict
print("[RXIOM] Client script started")

-- Moduły z ReplicatedStorage mogą jeszcze nie dotrzeć do klienta w chwili startu skryptu.
if not game:IsLoaded() then
	game.Loaded:Wait()
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Market = require(script.State.Market)
local Portfolio = require(script.State.Portfolio)
local MainMenu = require(script.UI.MainMenu)
local Toast = require(script.UI.Toast)

local initial: Types.InitialState = Remotes.GetInitialState:InvokeServer()
Market.start(initial)
Portfolio.start(initial.Portfolio)

MainMenu.mount()

Remotes.Notify.OnClientEvent:Connect(function(notice: Types.Notice)
	Toast.show(notice.Text, notice.Kind)
end)

print("[RXIOM] Main menu loaded")
