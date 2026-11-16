--!strict
-- Okno w stylu kafelków: niebieska ściana z cegiełkami, gruby obrys, tytuł wystający nad krawędź
-- i czerwony kafelek zamykania w rogu. Wnętrze to jasna karta, do której panele dokładają treść.

local Icons = require(script.Parent.Icons)
local Theme = require(script.Parent.Theme)
local Tile = require(script.Parent.Tile)
local Util = require(script.Parent.Util)

local create = Util.create

export type Panel = {
	root: Frame,
	body: Frame,
	isOpen: () -> boolean,
	open: () -> (),
	close: () -> (),
}

local Panel = {}

local DEPTH = 8

function Panel.new(title: string, size: Vector2, parent: Instance, onClose: () -> ()): Panel
	local palette = Theme.Palettes.Panel
	local root: Frame = create("Frame", {
		Name = title,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 10),
		Size = UDim2.fromOffset(size.X, size.Y + DEPTH),
		Visible = false,
		ZIndex = 10,
		Parent = parent,
	})
	local scale = create("UIScale", { Parent = root })

	create("Frame", {
		Name = "Shadow",
		BackgroundColor3 = palette.shadow,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, DEPTH),
		Size = UDim2.fromOffset(size.X, size.Y),
		Parent = root,
	}, { Util.corner(16), Util.stroke(Theme.Stroke.Panel) })
	local face = create("Frame", {
		Name = "Face",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(size.X, size.Y),
		Parent = root,
	}, { Util.corner(16), Util.stroke(Theme.Stroke.Panel), Util.gradient(palette.top, palette.bottom) })
	Tile.bricks(face, palette.brick, math.floor(size.Y / 34), 6)

	local body: Frame = create("Frame", {
		Name = "Body",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(18, 56),
		Size = UDim2.new(1, -36, 1, -74),
		Parent = face,
	}, {
		Util.corner(12),
		Util.stroke(Theme.Stroke.Tile),
		Util.gradient(Theme.Palettes.Card.top, Theme.Palettes.Card.bottom),
	})

	Util.label({
		Text = title,
		TextSize = 52,
		Position = UDim2.new(0.5, 0, 0, 6),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = -2,
		Stroke = 4.5,
		ZIndex = 5,
		Parent = face,
	})

	Tile.new({
		Name = "Close",
		Size = Vector2.new(60, 60),
		Palette = Theme.Palettes.Red,
		Icon = Icons.cross,
		IconScale = 0.62,
		Position = UDim2.new(1, 14, 0, -14),
		AnchorPoint = Vector2.new(1, 0),
		Parent = face,
		OnClick = onClose,
	}).root.ZIndex = 6

	local open = false
	local panel: Panel = {
		root = root,
		body = body,
		isOpen = function()
			return open
		end,
		open = function()
			open = true
			root.Visible = true
			scale.Scale = 0.6
			Util.tween(scale, Util.Pop, { Scale = 1 })
		end,
		close = function()
			open = false
			local tween = Util.tween(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.6 })
			tween.Completed:Once(function()
				if not open then
					root.Visible = false
				end
			end)
		end,
	}
	return panel
end

-- Przewijana lista na treść panelu z grubym paskiem przewijania.
function Panel.scroller(body: Frame, layout: Instance): ScrollingFrame
	return create("ScrollingFrame", {
		Name = "Scroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 10,
		ScrollBarImageColor3 = Theme.Palettes.Panel.shadow,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = body,
	}, { layout, Util.padding(14, 18, 14, 14) })
end

return Panel
