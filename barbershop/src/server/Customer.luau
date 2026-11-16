--!strict
-- Klient salonu: klockowy ludzik z włosami z wokseli (każdy woksel = +1 przy goleniu).
-- Ciało jest spawane do zakotwiczonego korzenia, więc ruch to tylko zmiana CFrame korzenia.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Blocks = require(script.Parent.Blocks)

export type State = "walking" | "seated" | "leaving"

export type Customer = {
	model: Model,
	root: BasePart,
	torso: BasePart,
	head: BasePart,
	hair: Folder,
	total: number,
	state: State,
	hips: { Motor6D },
	shoulders: { Motor6D },
	cape: { BasePart },
}

local Customer = {}

local SKIN = { "FFDBAC", "F1C27D", "E0AC69", "C68642", "8D5524", "5C3A21" }
local HAIR = { "1B1B1D", "3B2A20", "5A3825", "8A5A35", "D9B15A", "B5492A", "9C9C9C", "EDEDED", "2F5FD0", "D65DB1" }
local SHIRT = { "3A7BD5", "E04848", "3DBE6B", "F2B33D", "8E5BD9", "F1F0EC", "2B2C30", "E58A3C" }
local PANTS = { "2B2C30", "3E4A61", "5A4636", "1F3A5F", "6B6E73" }

local V = Config.VoxelSize
-- Środki wokseli wewnątrz obrysu głowy (2 studsy) i na jej zewnętrznej powłoce.
local INNER = { -0.75, -0.25, 0.25, 0.75 }
local FULL = { -1.25, -0.75, -0.25, 0.25, 0.75, 1.25 }
local EDGE = 1.25

local function pick(list: { string }, rng: Random): Color3
	return Color3.fromHex(list[rng:NextInteger(1, #list)])
end

-- Zbiór pozycji wokseli (względem środka głowy) bez duplikatów.
type VoxelSet = { [string]: Vector3 }

local function add(set: VoxelSet, x: number, y: number, z: number)
	set[`{x},{y},{z}`] = Vector3.new(x, y, z)
end

local function addTop(set: VoxelSet, layer: number, coords: { number })
	local y = EDGE + layer * V
	for _, x in coords do
		for _, z in coords do
			add(set, x, y, z)
		end
	end
end

local function addSides(set: VoxelSet, rows: { number })
	for _, y in rows do
		for _, z in { -0.75, -0.25, 0.25, 0.75, EDGE } do
			add(set, -EDGE, y, z)
			add(set, EDGE, y, z)
		end
		for _, x in INNER do
			add(set, x, y, EDGE)
		end
	end
end

local function addBeard(set: VoxelSet)
	for _, x in INNER do
		add(set, x, -0.75, -EDGE)
	end
	add(set, -0.75, -0.25, -EDGE)
	add(set, 0.75, -0.25, -EDGE)
	for _, y in { -0.25, -0.75 } do
		add(set, -EDGE, y, -0.75)
		add(set, EDGE, y, -0.75)
	end
end

-- Fryzury bazowe; ulepszenie "Bujne fryzury" dokłada warstwy na czubku.
-- Każda zwraca pierwszą wolną warstwę nad głową.
local STYLES: { (set: VoxelSet) -> number } = {
	-- Krótka
	function(set)
		addTop(set, 0, FULL)
		addSides(set, { 0.75 })
		return 1
	end,
	-- Klasyczna
	function(set)
		addTop(set, 0, FULL)
		addTop(set, 1, INNER)
		addSides(set, { 0.75, 0.25 })
		return 2
	end,
	-- Afro
	function(set)
		addTop(set, 0, FULL)
		addTop(set, 1, FULL)
		addTop(set, 2, INNER)
		addSides(set, { 0.75, 0.25, -0.25 })
		return 3
	end,
	-- Irokez
	function(set)
		for layer = 0, 3 do
			for _, z in FULL do
				add(set, -0.25, EDGE + layer * V, z)
				add(set, 0.25, EDGE + layer * V, z)
			end
		end
		return 4
	end,
	-- Długie
	function(set)
		addTop(set, 0, FULL)
		addSides(set, { 0.75, 0.25, -0.25, -0.75 })
		for _, x in INNER do
			add(set, x, -1.25, EDGE)
			add(set, x, -1.75, EDGE)
		end
		return 1
	end,
}

local function weld(part: BasePart, to: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = to
	w.Part1 = part
	w.Parent = part
end

local function bodyPart(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance): Part
	local part = Blocks.part({
		Name = name,
		Size = size,
		CFrame = cf,
		Color = color,
		Parent = parent,
		CanCollide = false,
		Studs = false,
	})
	part.Anchored = false
	part.Massless = true
	part.CanTouch = false
	return part
end

local function motor(name: string, torso: BasePart, limb: BasePart, c0: CFrame, c1: CFrame): Motor6D
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = torso
	m.Part1 = limb
	m.C0 = c0
	m.C1 = c1
	m.Parent = torso
	return m
end

-- Buduje klienta stojącego w `at` (stopy na ziemi, przodem w -Z).
function Customer.new(at: CFrame, extraLayers: number, parent: Instance): Customer
	local rng = Random.new()
	local model = Blocks.model("Customer", nil)

	local root = Blocks.part({ Name = "Root", Size = Vector3.new(1, 1, 1), CFrame = at, Color = Color3.new(), Transparency = 1, CanCollide = false, Parent = model })
	root.CanQuery = false
	root.CanTouch = false
	model.PrimaryPart = root

	local skin = pick(SKIN, rng)
	local torso = bodyPart("Torso", Vector3.new(2, 2, 1.2), at * CFrame.new(0, 3, 0), pick(SHIRT, rng), model)
	weld(torso, root)
	local head = bodyPart("Head", Vector3.new(2, 2, 2), at * CFrame.new(0, 5, 0), skin, model)
	weld(head, torso)

	local hips, shoulders = {}, {}
	local pants = pick(PANTS, rng)
	for i, sx in { -1, 1 } do
		local leg = bodyPart("Leg", Vector3.new(1, 2, 1), at * CFrame.new(sx * 0.5, 1, 0), pants, model)
		hips[i] = motor("Hip", torso, leg, CFrame.new(sx * 0.5, -1, 0), CFrame.new(0, 1, 0))
		local arm = bodyPart("Arm", Vector3.new(1, 2, 1), at * CFrame.new(sx * 1.5, 3, 0), skin, model)
		shoulders[i] = motor("Shoulder", torso, arm, CFrame.new(sx * 1.5, 1, 0), CFrame.new(0, 1, 0))
	end

	-- Twarz: oczy i usta (usta zasłania broda, wychodzą spod niej po goleniu).
	for _, sx in { -1, 1 } do
		local eye = bodyPart("Eye", Vector3.new(0.3, 0.4, 0.1), head.CFrame * CFrame.new(sx * 0.45, 0.15, -1.03), Color3.fromHex("1B1B1D"), model)
		weld(eye, head)
	end
	local mouth = bodyPart("Mouth", Vector3.new(0.7, 0.14, 0.1), head.CFrame * CFrame.new(0, -0.6, -1.03), Color3.fromHex("8C2F2F"), model)
	weld(mouth, head)

	local hair = Blocks.folder("Hair", model)
	local set: VoxelSet = {}
	local topLayer = STYLES[rng:NextInteger(1, #STYLES)](set)
	for layer = topLayer, topLayer + extraLayers - 1 do
		addTop(set, layer, INNER)
	end
	if rng:NextNumber() < 0.45 then
		addBeard(set)
	end

	local hairColor = pick(HAIR, rng)
	local total = 0
	for _, offset in set do
		local voxel = bodyPart("Voxel", Vector3.new(V, V, V), head.CFrame * CFrame.new(offset), Blocks.jitter(hairColor, 0.06, rng), hair)
		voxel.CastShadow = false
		weld(voxel, head)
		total += 1
	end
	model:SetAttribute("HairTotal", total)
	model.Parent = parent

	return {
		model = model,
		root = root,
		torso = torso,
		head = head,
		hair = hair,
		total = total,
		state = "walking",
		hips = hips,
		shoulders = shoulders,
		cape = {},
	}
end

local function setLimbs(c: Customer, legAngle: number, armAngle: number, sitting: boolean)
	for i, hip in c.hips do
		local sx = if i == 1 then -1 else 1
		local angle = if sitting then math.pi / 2 else legAngle * sx
		hip.C0 = CFrame.new(sx * 0.5, -1, 0) * CFrame.Angles(angle, 0, 0)
	end
	for i, shoulder in c.shoulders do
		local sx = if i == 1 then -1 else 1
		local angle = if sitting then math.rad(35) else -armAngle * sx
		shoulder.C0 = CFrame.new(sx * 1.5, 1, 0) * CFrame.Angles(angle, 0, 0)
	end
end

-- Idzie po punktach (na wysokości podłogi), kołysząc nogami. Wstrzymuje wątek do końca trasy.
function Customer.walk(c: Customer, points: { Vector3 }, speed: number)
	local phase = 0
	for _, target in points do
		local start = c.root.Position
		local flat = Vector3.new(target.X, start.Y, target.Z)
		local distance = (target - start).Magnitude
		local facing = if (flat - start).Magnitude > 0.05 then CFrame.lookAt(start, flat) - start else c.root.CFrame - c.root.Position
		local elapsed, duration = 0, distance / speed
		while elapsed < duration and c.model.Parent do
			local dt = RunService.Heartbeat:Wait()
			elapsed += dt
			phase += dt * speed * 1.4
			local alpha = math.min(elapsed / duration, 1)
			c.root.CFrame = CFrame.new(start:Lerp(target, alpha)) * facing
			setLimbs(c, math.sin(phase) * 0.6, math.sin(phase) * 0.5, false)
		end
		if not c.model.Parent then
			return
		end
		c.root.CFrame = CFrame.new(target) * facing
	end
	setLimbs(c, 0, 0, false)
end

-- Siada w fotelu i dostaje czarną pelerynę jak na zdjęciu referencyjnym.
function Customer.sit(c: Customer, seatCFrame: CFrame)
	local tween = TweenService:Create(c.root, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { CFrame = seatCFrame })
	tween:Play()
	tween.Completed:Wait()
	setLimbs(c, 0, 0, true)

	local black = Color3.fromHex("161618")
	local body = bodyPart("Cape", Vector3.new(3.1, 2.3, 1.9), seatCFrame * CFrame.new(0, 2.85, 0), black, c.model)
	local lap = bodyPart("Cape", Vector3.new(3, 0.7, 2.6), seatCFrame * CFrame.new(0, 2.2, -1.3), black, c.model)
	local front = bodyPart("Cape", Vector3.new(3, 1.6, 0.4), seatCFrame * CFrame.new(0, 1.3, -2.55), black, c.model)
	local collar = bodyPart("Collar", Vector3.new(2.2, 0.25, 1.5), seatCFrame * CFrame.new(0, 4.05, 0), Color3.fromHex("F1F0EC"), c.model)
	for _, part in { body, lap, front, collar } do
		part.CanQuery = false
		weld(part, c.torso)
		table.insert(c.cape, part)
	end
	c.state = "seated"
end

function Customer.standUp(c: Customer, at: Vector3)
	for _, part in c.cape do
		part:Destroy()
	end
	table.clear(c.cape)
	c.state = "leaving"
	setLimbs(c, 0, 0, false)
	c.root.CFrame = CFrame.new(at) * (c.root.CFrame - c.root.Position)
end

function Customer.remainingHair(c: Customer): { BasePart }
	return c.hair:GetChildren() :: any
end

return Customer
