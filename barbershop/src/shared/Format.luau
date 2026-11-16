--!strict
-- Formatowanie liczb do UI: 14200 -> "14.2K".

local Format = {}

local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi" }

function Format.compact(n: number): string
	if n ~= n or n == math.huge then
		return "∞"
	end
	local abs = math.abs(n)
	if abs < 1000 then
		return tostring(math.floor(n))
	end
	local tier = math.min(math.floor(math.log10(abs) / 3), #SUFFIXES)
	local value = n / 1000 ^ tier
	local text = if math.abs(value) >= 100 then string.format("%d", math.floor(value)) else string.format("%.3g", value)
	return text .. SUFFIXES[tier]
end

function Format.money(n: number): string
	return "$" .. Format.compact(n)
end

return Format
