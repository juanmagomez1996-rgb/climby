--!strict
-- Números con separador de miles al estilo es-CO (1.515), como fmt() del prototipo.
local Format = {}
function Format.int(n: number): string
	local s = tostring(math.round(n))
	local neg = string.sub(s, 1, 1) == "-"
	if neg then
		s = string.sub(s, 2)
	end
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1.")))
	if string.sub(out, 1, 1) == "." then
		out = string.sub(out, 2)
	end
	return (neg and "-" or "") .. out
end
return Format
