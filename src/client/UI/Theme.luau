--!strict
-- Kolory i fonty wzorowane na axiom.trade (ciemny motyw).

local Theme = {}

Theme.Colors = table.freeze({
	Background = Color3.fromHex("06070B"),
	Surface = Color3.fromHex("0B0C11"),
	SurfaceHover = Color3.fromHex("12131A"),
	Elevated = Color3.fromHex("16171E"),
	Border = Color3.fromHex("1E2029"),
	Divider = Color3.fromHex("15161C"),

	Text = Color3.fromHex("FCFCFC"),
	TextMuted = Color3.fromHex("8B8E9E"),
	TextDim = Color3.fromHex("5C5F6E"),

	Primary = Color3.fromHex("526FFF"),
	PrimaryHover = Color3.fromHex("6A83FF"),
	Green = Color3.fromHex("2FE3AC"),
	Red = Color3.fromHex("EC397A"),
	Yellow = Color3.fromHex("F5C542"),
	Orange = Color3.fromHex("F7931A"),
})

local FAMILY = "rbxasset://fonts/families/BuilderSans.json"

Theme.Fonts = table.freeze({
	Regular = Font.new(FAMILY, Enum.FontWeight.Regular),
	Medium = Font.new(FAMILY, Enum.FontWeight.Medium),
	SemiBold = Font.new(FAMILY, Enum.FontWeight.SemiBold),
	Bold = Font.new(FAMILY, Enum.FontWeight.Bold),
})

-- Rozdzielczość, pod którą projektowany jest layout; UI skaluje się względem niej.
Theme.DesignSize = Vector2.new(1600, 860)

-- Waluta w grze (odpowiednik SOL na Axiom).
Theme.Currency = "RX"

return table.freeze(Theme)
