--!strict
-- Styl UI wzorowany na kafelkach z Pet Simulatora: nasycone kolory, cegiełkowa faktura,
-- gruby czarny obrys, ciemniejszy spód (efekt 3D) i biały napis Fredoka z czarnym konturem.

local Theme = {}

export type Palette = {
	top: Color3,
	bottom: Color3,
	brick: Color3,
	shadow: Color3,
}

local function palette(top: string, bottom: string, brick: string, shadow: string): Palette
	return table.freeze({
		top = Color3.fromHex(top),
		bottom = Color3.fromHex(bottom),
		brick = Color3.fromHex(brick),
		shadow = Color3.fromHex(shadow),
	})
end

Theme.Palettes = table.freeze({
	Cyan = palette("5FE1FF", "2CC3F0", "1A9FD3", "137FAE"),
	Green = palette("86F06E", "3FCB3C", "2A9F2C", "208425"),
	Purple = palette("D99BFF", "A855F0", "8636CF", "6524A3"),
	Red = palette("FF8A7A", "EC4141", "C42D2D", "991F1F"),
	Gold = palette("FFE778", "F7BC2E", "D69618", "A86F0C"),
	Gray = palette("D3D7DD", "A3A9B2", "8A9099", "6E737B"),
	Panel = palette("7FE6FF", "3CC8F2", "22A7DA", "137FAE"),
	Card = palette("F4FCFF", "D9F3FF", "BCE6F7", "8CC6DE"),
})

Theme.Colors = table.freeze({
	Outline = Color3.fromHex("111114"),
	White = Color3.new(1, 1, 1),
	Text = Color3.new(1, 1, 1),
	TextDark = Color3.fromHex("1B2B3A"),
	Money = Color3.fromHex("7CFF6B"),
	Gold = Color3.fromHex("FFD84A"),
})

Theme.Font = Font.new("rbxasset://fonts/families/FredokaOne.json")

-- Grubości obrysów w pikselach projektu (skalowane razem z UIScale).
Theme.Stroke = table.freeze({
	Tile = 3.5,
	Text = 3,
	Icon = 3,
	Panel = 5,
})

-- Rozdzielczość projektu; HUD skaluje się do wysokości ekranu.
Theme.DesignHeight = 900

return table.freeze(Theme)
