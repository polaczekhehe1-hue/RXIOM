print("[RXIOM] Client script started")

-- Moduły z ReplicatedStorage mogą jeszcze nie dotrzeć do klienta w chwili startu skryptu.
if not game:IsLoaded() then
	game.Loaded:Wait()
end

local MainMenu = require(script.UI.MainMenu)

MainMenu.mount()
print("[RXIOM] Main menu loaded")
