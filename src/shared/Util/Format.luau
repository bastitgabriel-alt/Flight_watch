--!strict
-- Mise en forme des nombres pour l'affichage : 1234 -> "1.2K"

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local Format = {}

function Format.number(value: number): string
	if value ~= value then -- NaN
		return "0"
	end
	local negative = value < 0
	local n = math.abs(value)
	if n < 1000 then
		local text = tostring(math.floor(n))
		return if negative then "-" .. text else text
	end

	local index = 1
	while n >= 1000 and index < #SUFFIXES do
		n /= 1000
		index += 1
	end
	-- 1 décimale sous 100, aucune au-dessus (ex. 1.2K, 15.3K, 152K)
	local text
	if n < 100 then
		text = string.format("%.1f", math.floor(n * 10) / 10)
		text = string.gsub(text, "%.0$", "")
	else
		text = tostring(math.floor(n))
	end
	text ..= SUFFIXES[index]
	return if negative then "-" .. text else text
end

function Format.money(value: number): string
	return "$" .. Format.number(value)
end

return Format
