--!strict
-- Małe helpery do budowania UI w kodzie.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Util = {}

-- `children` jest typu { any }, bo tablice w Luau są inwariantne ({ UICorner } nie pasuje do { Instance }).
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

function Util.corner(radius: number): Instance
	return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

function Util.round(): Instance
	return create("UICorner", { CornerRadius = UDim.new(1, 0) })
end

function Util.stroke(color: Color3?, thickness: number?, transparency: number?): Instance
	return create("UIStroke", {
		Color = color or Theme.Colors.Border,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Util.padding(top: number, right: number?, bottom: number?, left: number?): Instance
	local r = right or top
	return create("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, r),
		PaddingBottom = UDim.new(0, bottom or top),
		PaddingLeft = UDim.new(0, left or r),
	})
end

function Util.hlist(spacing: number, valign: Enum.VerticalAlignment?, halign: Enum.HorizontalAlignment?): Instance
	return create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, spacing),
		VerticalAlignment = valign or Enum.VerticalAlignment.Center,
		HorizontalAlignment = halign or Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function Util.vlist(spacing: number, halign: Enum.HorizontalAlignment?, valign: Enum.VerticalAlignment?): Instance
	return create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, spacing),
		HorizontalAlignment = halign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = valign or Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

export type TextProps = {
	Text: string,
	Size: number?,
	Font: Font?,
	Color: Color3?,
	Order: number?,
	AlignX: Enum.TextXAlignment?,
	Parent: Instance?,
}

-- TextLabel dopasowujący szerokość do treści.
function Util.text(p: TextProps): TextLabel
	return create("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		Text = p.Text,
		TextSize = p.Size or 14,
		FontFace = p.Font or Theme.Fonts.Medium,
		TextColor3 = p.Color or Theme.Colors.Text,
		TextXAlignment = p.AlignX or Enum.TextXAlignment.Left,
		LayoutOrder = p.Order or 0,
		Parent = p.Parent,
	})
end

-- Przezroczysty kontener z automatycznym rozmiarem.
function Util.group(name: string, order: number?, layout: Instance?): Frame
	return create("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		LayoutOrder = order or 0,
	}, if layout then { layout } else nil)
end

local HOVER_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function Util.tween(instance: Instance, props: { [string]: any })
	TweenService:Create(instance, HOVER_INFO, props):Play()
end

-- Zmienia kolor tła przycisku po najechaniu myszką.
function Util.hoverBackground(button: GuiButton, normal: Color3, hover: Color3, normalTransparency: number?)
	local t = normalTransparency or 0
	button.MouseEnter:Connect(function()
		Util.tween(button, { BackgroundColor3 = hover, BackgroundTransparency = 0 })
	end)
	button.MouseLeave:Connect(function()
		Util.tween(button, { BackgroundColor3 = normal, BackgroundTransparency = t })
	end)
end

-- Skraca liczby w stylu Axiom: 14200 -> "14.2K".
function Util.compact(n: number): string
	local abs = math.abs(n)
	local suffix, div = "", 1
	if abs >= 1e9 then
		suffix, div = "B", 1e9
	elseif abs >= 1e6 then
		suffix, div = "M", 1e6
	elseif abs >= 1e3 then
		suffix, div = "K", 1e3
	end
	local v = n / div
	local s = if math.abs(v) >= 100 or div == 1 then string.format("%d", math.round(v)) else string.format("%.3g", v)
	return s .. suffix
end

function Util.percent(n: number): string
	return string.format("%s%.2f%%", if n > 0 then "+" else "", n)
end

return table.freeze(Util)
