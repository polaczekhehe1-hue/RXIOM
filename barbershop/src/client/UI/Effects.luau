--!strict
-- Wyskakujące napisy "+1" nad włosami i duże komunikaty o napiwkach.
-- Osobny ScreenGui bez UIScale, żeby pozycje z kamery trafiały co do piksela.

local Players = game:GetService("Players")

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local Effects = {}

local gui: ScreenGui? = nil
local getScale: () -> number = function()
	return 1
end

function Effects.mount(scaleSource: () -> number)
	getScale = scaleSource
	gui = Util.create("ScreenGui", {
		Name = "Effects",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
end

-- Napis podskakuje, unosi się i znika.
function Effects.popAt(position: Vector2, text: string, color: Color3?, size: number?)
	if not gui then
		return
	end
	local s = getScale()
	local rng = Random.new()
	local label = Util.label({
		Text = text,
		TextSize = math.floor((size or 34) * s),
		Color = color or Theme.Colors.Coin,
		Stroke = math.max(2, 3.5 * s),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(position.X + rng:NextNumber(-12, 12) * s, position.Y),
		Rotation = rng:NextNumber(-10, 10),
		Parent = gui,
	})
	local scale = Util.create("UIScale", { Scale = 0.3, Parent = label })
	Util.tween(scale, Util.Pop, { Scale = 1 })
	local rise = Util.tween(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = label.Position - UDim2.fromOffset(0, 70 * s),
	})
	task.delay(0.45, function()
		Util.tween(label, TweenInfo.new(0.45), { TextTransparency = 1 })
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			Util.tween(stroke, TweenInfo.new(0.45), { Transparency = 1 })
		end
	end)
	rise.Completed:Once(function()
		label:Destroy()
	end)
end

function Effects.popWorld(worldPosition: Vector3, text: string, color: Color3?, size: number?)
	local camera = workspace.CurrentCamera
	local point, visible = camera:WorldToViewportPoint(worldPosition)
	if visible then
		Effects.popAt(Vector2.new(point.X, point.Y), text, color, size)
	end
end

-- Duży napis na środku ekranu (napiwek, rebirth).
function Effects.big(text: string, color: Color3?)
	local camera = workspace.CurrentCamera
	local center = camera.ViewportSize / 2
	Effects.popAt(Vector2.new(center.X, center.Y * 0.62), text, color or Theme.Colors.Coin, 64)
end

return Effects
