--!strict
-- Helpery do budowania UI w kodzie.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Util = {}

-- `children` jest typu { any }, bo tablice w Luau są inwariantne.
function Util.create(className: string, props: { [string]: any }, children: { any }?): any
	local instance = Instance.new(className :: any)
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

local create = Util.create

function Util.corner(radius: number): UICorner
	return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

function Util.round(): UICorner
	return create("UICorner", { CornerRadius = UDim.new(1, 0) })
end

-- Obrys ramki (Border) albo konturu tekstu (Contextual).
function Util.stroke(thickness: number?, color: Color3?, forText: boolean?): UIStroke
	return create("UIStroke", {
		Color = color or Theme.Colors.Outline,
		Thickness = thickness or Theme.Stroke.Tile,
		LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = if forText then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border,
	})
end

function Util.gradient(top: Color3, bottom: Color3): UIGradient
	return create("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = 90,
	})
end

function Util.padding(top: number, right: number?, bottom: number?, left: number?): UIPadding
	local r = right or top
	return create("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, r),
		PaddingBottom = UDim.new(0, bottom or top),
		PaddingLeft = UDim.new(0, left or r),
	})
end

function Util.list(direction: Enum.FillDirection, spacing: number, halign: Enum.HorizontalAlignment?, valign: Enum.VerticalAlignment?): UIListLayout
	return create("UIListLayout", {
		FillDirection = direction,
		Padding = UDim.new(0, spacing),
		HorizontalAlignment = halign or Enum.HorizontalAlignment.Center,
		VerticalAlignment = valign or Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

export type LabelProps = {
	Text: string,
	TextSize: number,
	Color: Color3?,
	Stroke: number?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	AlignX: Enum.TextXAlignment?,
	Order: number?,
	ZIndex: number?,
	Rotation: number?,
	Parent: Instance?,
}

-- Biały napis Fredoka z czarnym konturem — podstawowy tekst w całym UI.
function Util.label(p: LabelProps): TextLabel
	local auto = p.Size == nil
	return create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		AutomaticSize = if auto then Enum.AutomaticSize.XY else Enum.AutomaticSize.None,
		Size = p.Size or UDim2.new(),
		Position = p.Position or UDim2.new(),
		AnchorPoint = p.AnchorPoint or Vector2.zero,
		FontFace = Theme.Font,
		Text = p.Text,
		TextSize = p.TextSize,
		TextColor3 = p.Color or Theme.Colors.Text,
		TextXAlignment = p.AlignX or Enum.TextXAlignment.Center,
		TextWrapped = not auto,
		LayoutOrder = p.Order or 0,
		ZIndex = p.ZIndex or 1,
		Rotation = p.Rotation or 0,
		Parent = p.Parent,
	}, if (p.Stroke or Theme.Stroke.Text) > 0 then { Util.stroke(p.Stroke or Theme.Stroke.Text, nil, true) } else nil)
end

function Util.tween(instance: Instance, info: TweenInfo, props: { [string]: any }): Tween
	local tween = TweenService:Create(instance, info, props)
	tween:Play()
	return tween
end

Util.Quick = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Util.Pop = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

return table.freeze(Util)
