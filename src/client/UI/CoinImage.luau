--!strict
-- Obrazek monety RXI. Kolejność źródeł:
-- 1. Theme.CoinImageAssetId, jeśli grafika jest wgrana na Roblox (działa wszędzie),
-- 2. EditableImage z pikseli zapisanych w CoinImageData (Studio od razu; w opublikowanej grze
--    trzeba włączyć Game Settings → Security → Allow Mesh / Image APIs),
-- 3. nil, a wtedy Icons rysuje zastępczą monetę z ramek.

local AssetService = game:GetService("AssetService")

local CoinImageData = require(script.Parent.CoinImageData)
local Theme = require(script.Parent.Theme)

local CoinImage = {}

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local decodeTable: { [number]: number } = {}
for i = 1, #ALPHABET do
	decodeTable[string.byte(ALPHABET, i)] = i - 1
end

-- Surowe piksele RGBA (Size.X * Size.Y * 4 bajtów).
function CoinImage.pixels(): buffer
	local text = CoinImageData.Base64
	local size = CoinImageData.Size
	local out = buffer.create(size.X * size.Y * 4)
	local outIndex = 0
	local bits, value = 0, 0
	for i = 1, #text do
		local digit = decodeTable[string.byte(text, i)]
		if digit then
			value = bit32.bor(bit32.lshift(value, 6), digit)
			bits += 6
			if bits >= 8 then
				bits -= 8
				buffer.writeu8(out, outIndex, bit32.band(bit32.rshift(value, bits), 0xFF))
				outIndex += 1
				value = bit32.band(value, bit32.lshift(1, bits) - 1)
			end
		end
	end
	assert(outIndex == buffer.len(out), "Coin image data has the wrong size")
	return out
end

local cached: Content? = nil
local failed = false

-- Wspólna treść dla wszystkich ikon (jeden EditableImage, mało pamięci).
function CoinImage.content(): Content?
	if cached or failed then
		return cached
	end
	if Theme.CoinImageAssetId > 0 then
		cached = Content.fromAssetId(Theme.CoinImageAssetId)
		return cached
	end
	local ok, result = pcall(function()
		local size = CoinImageData.Size
		local image = AssetService:CreateEditableImage({ Size = size })
		image:WritePixelsBuffer(Vector2.zero, size, CoinImage.pixels())
		return Content.fromObject(image)
	end)
	if ok then
		cached = result
	else
		failed = true
		warn(
			"[RXIOM] Could not create the RXI coin image. In a published game enable "
				.. "Game Settings → Security → Allow Mesh / Image APIs, or set Theme.CoinImageAssetId.",
			result
		)
	end
	return cached
end

return CoinImage
