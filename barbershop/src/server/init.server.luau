--!strict
-- Start serwera: buduje mapę z salonami i uruchamia logikę gry.

local PlayerData = require(script.PlayerData)
local ShopService = require(script.ShopService)
local World = require(script.World)

PlayerData.start()
ShopService.start(World.build())
print("[BarberShop] Server ready")
