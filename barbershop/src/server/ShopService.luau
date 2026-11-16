--!strict
-- Logika salonów: przydział działek, przychodzący klienci, sesje strzyżenia z walidacją po stronie serwera,
-- pomocnik (+1 co sekundę), ulepszenia i rebirth.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Customer = require(script.Parent.Customer)
local PlayerData = require(script.Parent.PlayerData)
local ShopBuilder = require(script.Parent.ShopBuilder)

local Remotes = ReplicatedStorage.Remotes
local SessionRemote = Remotes.Session :: RemoteEvent
local ShaveRemote = Remotes.Shave :: RemoteEvent
local StopShaveRemote = Remotes.StopShave :: RemoteEvent
local GainRemote = Remotes.Gain :: RemoteEvent
local ToastRemote = Remotes.Toast :: RemoteEvent
local BuyRemote = Remotes.BuyUpgrade :: RemoteFunction
local RebirthRemote = Remotes.Rebirth :: RemoteFunction

local WALK_SPEED = 9
-- Limit żądań golenia: kubełek tokenów (pojemność, uzupełnianie na sekundę).
local SHAVE_BURST = 12
local SHAVE_RATE = 25

type Station = ShopBuilder.Station
type Session = {
	station: Station,
	customer: Customer.Customer,
	tokens: number,
	lastRefill: number,
}
type Owned = {
	player: Player,
	shop: ShopBuilder.Shop,
	-- Klient przypisany do stanowiska (indeks stanowiska → klient).
	customers: { [number]: Customer.Customer },
	session: Session?,
	nextSpawn: number,
	helperProgress: number,
}

local ShopService = {}

local shops: { ShopBuilder.Shop } = {}
local owned: { [Player]: Owned } = {}
local promptOwners: { [ProximityPrompt]: { owner: Owned, station: Station } } = {}

local function data(player: Player): PlayerData.Data?
	return PlayerData.get(player)
end

local function hrp(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function refreshPrompt(o: Owned, station: Station)
	local c = o.customers[station.index]
	local busy = o.session ~= nil and o.session.station == station
	station.prompt.Enabled = c ~= nil and c.state == "seated" and not busy
end

local function registerStations(o: Owned)
	for _, station in o.shop.stations do
		if not promptOwners[station.prompt] then
			promptOwners[station.prompt] = { owner = o, station = station }
			station.prompt.Triggered:Connect(function(player)
				ShopService.startSession(player, station)
			end)
		end
		refreshPrompt(o, station)
	end
end

local function applyLayout(o: Owned)
	local d = data(o.player)
	if not d then
		return
	end
	ShopBuilder.ensureStations(o.shop, Config.chairCount(d.upgrades))
	ShopBuilder.ensureDecor(o.shop, d.upgrades.decor or 0)
	registerStations(o)
end

-- Kończy strzyżenie: odblokowuje postać i przywraca kamerę u klienta.
function ShopService.endSession(o: Owned)
	local session = o.session
	if not session then
		return
	end
	o.session = nil
	local root = hrp(o.player)
	if root then
		root.Anchored = false
	end
	SessionRemote:FireClient(o.player, "stop")
	refreshPrompt(o, session.station)
end

local function walkOut(o: Owned, station: Station, c: Customer.Customer)
	Customer.standUp(c, station.besidePoint)
	Customer.walk(c, { station.aislePoint, o.shop.doorInside, o.shop.doorOutside }, WALK_SPEED)
	c.model:Destroy()
end

local function finishCustomer(o: Owned, station: Station, c: Customer.Customer)
	if c.state ~= "seated" then
		return
	end
	local d = data(o.player)
	if o.session and o.session.customer == c then
		ShopService.endSession(o)
	end
	o.customers[station.index] = nil
	c.state = "leaving"
	refreshPrompt(o, station)
	if d then
		d.shaved += 1
		local tip = Config.tip(d.upgrades, d.rebirths, c.total)
		PlayerData.addCash(o.player, tip)
		PlayerData.sync(o.player)
		GainRemote:FireClient(o.player, tip, "tip", c.head.Position)
	end
	task.spawn(walkOut, o, station, c)
end

-- Usuwa podane woksele i wypłaca +1 (× mnożniki) za każdy.
local function shaveVoxels(o: Owned, station: Station, c: Customer.Customer, voxels: { BasePart }): number
	local d = data(o.player)
	if not d or #voxels == 0 then
		return 0
	end
	for _, voxel in voxels do
		voxel:Destroy()
	end
	local amount = #voxels * Config.perVoxel(d.upgrades, d.rebirths)
	PlayerData.addCash(o.player, amount)
	if #c.hair:GetChildren() == 0 then
		finishCustomer(o, station, c)
	end
	return amount
end

local function spawnCustomer(o: Owned)
	local d = data(o.player)
	if not d then
		return
	end
	local free: Station? = nil
	for _, station in o.shop.stations do
		if not o.customers[station.index] then
			free = station
			break
		end
	end
	if not free then
		return
	end
	local station = free
	local start = CFrame.lookAt(o.shop.doorOutside, o.shop.doorInside)
	local c = Customer.new(start, Config.extraHairLayers(d.upgrades), o.shop.model)
	o.customers[station.index] = c
	task.spawn(function()
		Customer.walk(c, { o.shop.doorInside, station.aislePoint, station.besidePoint }, WALK_SPEED)
		if o.customers[station.index] ~= c or not c.model.Parent then
			return
		end
		Customer.sit(c, station.seatCFrame)
		refreshPrompt(o, station)
	end)
end

local function clearCustomers(o: Owned)
	ShopService.endSession(o)
	for index, c in o.customers do
		c.model:Destroy()
		o.customers[index] = nil
	end
end

function ShopService.startSession(player: Player, station: Station)
	local entry = promptOwners[station.prompt]
	if not entry then
		return
	end
	local o = entry.owner
	if o.player ~= player then
		ToastRemote:FireClient(player, "To nie twój salon! Twój ma szyld z twoim nickiem.")
		return
	end
	local c = o.customers[station.index]
	local root = hrp(player)
	if o.session or not c or c.state ~= "seated" or not root then
		return
	end
	o.session = { station = station, customer = c, tokens = SHAVE_BURST, lastRefill = os.clock() }
	refreshPrompt(o, station)
	root.Anchored = true
	local character = player.Character :: Model
	character:PivotTo(station.standCFrame)
	SessionRemote:FireClient(player, "start", c.model)
end

local function onShave(player: Player, voxel: any)
	local o = owned[player]
	local session = o and o.session
	if not (o and session) then
		return
	end
	if typeof(voxel) ~= "Instance" or not voxel:IsA("BasePart") or voxel.Parent ~= session.customer.hair then
		return
	end

	local now = os.clock()
	session.tokens = math.min(SHAVE_BURST, session.tokens + (now - session.lastRefill) * SHAVE_RATE)
	session.lastRefill = now
	if session.tokens < 1 then
		return
	end
	session.tokens -= 1

	local d = data(player)
	if not d then
		return
	end
	-- Szeroka maszynka zbiera wszystkie woksele w promieniu od trafionego.
	local radius = Config.brushRadius(d.upgrades) * Config.VoxelSize + 0.01
	local center = voxel.Position
	local hit = {}
	for _, other in Customer.remainingHair(session.customer) do
		if (other.Position - center).Magnitude <= radius then
			table.insert(hit, other)
		end
	end
	local c = session.customer
	local amount = shaveVoxels(o, session.station, c, hit)
	if amount > 0 then
		GainRemote:FireClient(player, amount, "shave", center)
	end
end

-- Pomocnik goli losowych klientów, których gracz akurat nie strzyże.
local function runHelper(o: Owned, dt: number)
	local d = data(o.player)
	if not d then
		return
	end
	local rate = Config.helperRate(d.upgrades)
	if rate <= 0 then
		return
	end
	o.helperProgress += rate * dt
	local earned = 0
	while o.helperProgress >= 1 do
		o.helperProgress -= 1
		local targets = {}
		for _, station in o.shop.stations do
			local c = o.customers[station.index]
			if c and c.state == "seated" and not (o.session and o.session.customer == c) then
				table.insert(targets, { station = station, customer = c })
			end
		end
		if #targets == 0 then
			o.helperProgress = 0
			break
		end
		local target = targets[math.random(1, #targets)]
		local hair = Customer.remainingHair(target.customer)
		if #hair > 0 then
			earned += shaveVoxels(o, target.station, target.customer, { hair[math.random(1, #hair)] })
		end
	end
	if earned > 0 then
		GainRemote:FireClient(o.player, earned, "helper")
	end
end

local function buyUpgrade(player: Player, id: any): (boolean, string)
	local o = owned[player]
	local d = data(player)
	local def = if type(id) == "string" then Config.UpgradeById[id] else nil
	if not (o and d and def) then
		return false, "Nieznane ulepszenie"
	end
	local level = d.upgrades[def.id] or 0
	if level >= def.max then
		return false, "Maksymalny poziom"
	end
	local cost = def.cost(level)
	if d.cash < cost then
		return false, "Za mało kasy!"
	end
	d.cash -= cost
	d.upgrades[def.id] = level + 1
	PlayerData.sync(player)
	applyLayout(o)
	return true, `{def.name}: poziom {level + 1}`
end

local function rebirth(player: Player): (boolean, string)
	local o = owned[player]
	local d = data(player)
	if not (o and d) then
		return false, "Brak danych"
	end
	local cost = Config.rebirthCost(d.rebirths)
	if d.cash < cost then
		return false, "Za mało kasy na rebirth!"
	end
	d.cash = 0
	d.upgrades = {}
	d.rebirths += 1
	PlayerData.sync(player)
	clearCustomers(o)
	for _, station in o.shop.stations do
		promptOwners[station.prompt] = nil
	end
	ShopBuilder.reset(o.shop)
	applyLayout(o)
	return true, `Rebirth! Teraz zarabiasz ×{Config.multiplier(d.rebirths)}`
end

local function teleportHome(o: Owned, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root and owned[o.player] == o then
		character:PivotTo(o.shop.spawnCFrame)
	end
end

local function onPlayerAdded(player: Player)
	PlayerData.load(player)
	if not player.Parent then
		PlayerData.release(player)
		return
	end

	local shop: ShopBuilder.Shop? = nil
	local taken: { [ShopBuilder.Shop]: boolean } = {}
	for _, o in owned do
		taken[o.shop] = true
	end
	for _, candidate in shops do
		if not taken[candidate] then
			shop = candidate
			break
		end
	end
	if not shop then
		ToastRemote:FireClient(player, "Wszystkie salony są zajęte — spróbuj innego serwera.")
		return
	end

	local o: Owned = {
		player = player,
		shop = shop,
		customers = {},
		session = nil,
		nextSpawn = os.clock() + 1,
		helperProgress = 0,
	}
	owned[player] = o
	player:SetAttribute("ShopIndex", shop.index)
	ShopBuilder.setOwner(shop, player.DisplayName)
	applyLayout(o)

	player.CharacterAdded:Connect(function(character)
		ShopService.endSession(o)
		teleportHome(o, character)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if humanoid then
			humanoid.Died:Connect(function()
				ShopService.endSession(o)
			end)
		end
	end)
	if player.Character then
		task.spawn(teleportHome, o, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	local o = owned[player]
	if o then
		o.session = nil
		clearCustomers(o)
		for _, station in o.shop.stations do
			promptOwners[station.prompt] = nil
		end
		ShopBuilder.reset(o.shop)
		ShopBuilder.setOwner(o.shop, nil)
		owned[player] = nil
	end
	PlayerData.release(player)
end

function ShopService.start(builtShops: { ShopBuilder.Shop })
	shops = builtShops

	ShaveRemote.OnServerEvent:Connect(onShave)
	StopShaveRemote.OnServerEvent:Connect(function(player)
		local o = owned[player]
		if o then
			ShopService.endSession(o)
		end
	end)
	BuyRemote.OnServerInvoke = buyUpgrade
	RebirthRemote.OnServerInvoke = rebirth

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.25)
			local now = os.clock()
			local dt = now - last
			last = now
			for _, o in owned do
				local d = data(o.player)
				if d and now >= o.nextSpawn then
					o.nextSpawn = now + Config.spawnInterval(d.upgrades)
					spawnCustomer(o)
				end
				runHelper(o, dt)
			end
		end
	end)
end

return ShopService
