--!strict
-- Tryb strzyżenia: kamera robi zbliżenie na głowę klienta, gracz przytrzymuje przycisk
-- i jeździ kursorem/palcem po włosach. Trafione woksele chowają się od razu lokalnie,
-- a serwer usuwa je naprawdę i wypłaca +1 za każdy.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ShaveRemote = ReplicatedStorage.Remotes.Shave :: RemoteEvent
local StopShaveRemote = ReplicatedStorage.Remotes.StopShave :: RemoteEvent

export type Hooks = {
	setActive: (active: boolean) -> (),
	setProgress: (remaining: number, total: number) -> (),
}

local ShaveController = {}

-- Klient wysyła mniej niż serwer akceptuje (25/s), żeby nie tracić trafień na limicie.
local SEND_INTERVAL = 1 / 20
-- Lustro jest ~6.5 studsa od głowy, więc kamera musi zostać bliżej, żeby nie wejść w ścianę.
local DISTANCE = 5.5
local HEIGHT = 1.4
local ROTATE_SPEED = 2.2
local ZOOM_TIME = 0.45

local hooks: Hooks
local active = false
local customer: Model? = nil
local hair: Instance? = nil
local total = 0
local yaw = 0
local rotateInput: { [number]: true } = {}
local pressing = false
-- Pozycja wskaźnika w przestrzeni GUI (bez paska Robloxa), wspólna dla myszy i dotyku.
local pointer: Vector2? = nil
local lastSend = 0
local pending: { [Instance]: number } = {}
local zoomStart = 0
local fromCFrame = CFrame.identity
local connections: { RBXScriptConnection } = {}

local function headCenter(): Vector3?
	local head = customer and customer:FindFirstChild("Head") :: BasePart?
	return if head then head.Position + Vector3.new(0, 0.6, 0) else nil
end

local function targetCFrame(center: Vector3): CFrame
	local offset = CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(-14), 0, 0) * Vector3.new(0, 0, DISTANCE)
	local position = center + offset + Vector3.new(0, HEIGHT * 0.3, 0)
	return CFrame.lookAt(position, center)
end

local function setCharacterHidden(hidden: boolean)
	local character = Players.LocalPlayer.Character
	if not character then
		return
	end
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") or part:IsA("Decal") then
			(part :: any).LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

local function updateProgress()
	if hair then
		local remaining = 0
		for _, voxel in hair:GetChildren() do
			if not pending[voxel] then
				remaining += 1
			end
		end
		hooks.setProgress(remaining, total)
	end
end

local function tryShave(screen: Vector2)
	if not (hair and active) then
		return
	end
	local now = os.clock()
	if now - lastSend < SEND_INTERVAL then
		return
	end
	local camera = workspace.CurrentCamera
	local ray = camera:ScreenPointToRay(screen.X, screen.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { customer :: Model }
	local result = workspace:Raycast(ray.Origin, ray.Direction * 40, params)
	local voxel = result and result.Instance
	if not (voxel and voxel.Parent == hair and not pending[voxel]) then
		return
	end
	lastSend = now
	pending[voxel] = now
	-- Ukryty woksel nie może zasłaniać tych pod spodem, zanim serwer go usunie.
	voxel.LocalTransparencyModifier = 1
	voxel.CanQuery = false
	ShaveRemote:FireServer(voxel)
	updateProgress()
end

local function step(dt: number)
	if not active then
		return
	end
	local center = headCenter()
	if not center then
		return
	end
	local direction = (if rotateInput[1] then 1 else 0) - (if rotateInput[-1] then 1 else 0)
	yaw += direction * ROTATE_SPEED * dt

	local camera = workspace.CurrentCamera
	local target = targetCFrame(center)
	local t = math.clamp((os.clock() - zoomStart) / ZOOM_TIME, 0, 1)
	local eased = 1 - (1 - t) ^ 3
	camera.CFrame = if t < 1 then fromCFrame:Lerp(target, eased) else target
	camera.Focus = CFrame.new(center)

	-- Jeśli serwer odrzucił trafienie (limit), przywróć widoczność wokselu.
	local now = os.clock()
	for voxel, sentAt in pending do
		if not voxel.Parent then
			pending[voxel] = nil
		elseif now - sentAt > 0.6 then
			local part = voxel :: BasePart
			part.LocalTransparencyModifier = 0
			part.CanQuery = true
			pending[voxel] = nil
			updateProgress()
		end
	end

	if pressing and pointer then
		tryShave(pointer)
	end
end

function ShaveController.start(model: Model, standCFrame: CFrame)
	if active then
		ShaveController.stop()
	end
	customer = model
	hair = model:WaitForChild("Hair", 5)
	if not hair then
		return
	end
	active = true
	total = (model:GetAttribute("HairTotal") :: number?) or #hair:GetChildren()
	table.clear(pending)
	table.clear(rotateInput)

	-- Kamera startuje od strony gracza, lekko z boku twarzy klienta.
	local center = headCenter() :: Vector3
	local fromPlayer = standCFrame.Position - center
	yaw = math.atan2(fromPlayer.X, fromPlayer.Z)

	local camera = workspace.CurrentCamera
	fromCFrame = camera.CFrame
	zoomStart = os.clock()
	camera.CameraType = Enum.CameraType.Scriptable
	setCharacterHidden(true)
	hooks.setActive(true)
	updateProgress()

	table.insert(connections, hair.ChildRemoved:Connect(function(voxel)
		pending[voxel] = nil
		updateProgress()
	end))
	RunService:BindToRenderStep("BarberShave", Enum.RenderPriority.Camera.Value + 1, step)
end

function ShaveController.stop()
	if not active then
		return
	end
	active = false
	pressing = false
	RunService:UnbindFromRenderStep("BarberShave")
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	customer, hair = nil, nil
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	setCharacterHidden(false)
	hooks.setActive(false)
end

function ShaveController.exit()
	StopShaveRemote:FireServer()
	ShaveController.stop()
end

function ShaveController.rotate(direction: number, held: boolean)
	if held then
		rotateInput[direction] = true
	else
		rotateInput[direction] = nil
	end
end

function ShaveController.init(h: Hooks)
	hooks = h
	local function isPointer(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if not active then
			return
		end
		if isPointer(input) and not processed then
			pressing = true
			pointer = Vector2.new(input.Position.X, input.Position.Y)
		elseif input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then
			rotateInput[1] = true
		elseif input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then
			rotateInput[-1] = true
		elseif input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Escape then
			ShaveController.exit()
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			pointer = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if isPointer(input) then
			pressing = false
		elseif input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.Left then
			rotateInput[1] = nil
		elseif input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Right then
			rotateInput[-1] = nil
		end
	end)
end

return ShaveController
