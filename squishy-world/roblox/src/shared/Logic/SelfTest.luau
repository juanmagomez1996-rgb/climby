--!strict
-- Pruebas rápidas de la lógica pura. Se corren al arrancar el servidor si Config.Game.DEBUG.
local Config = require(script.Parent.Parent.Config)
local Catalog = require(script.Parent.Catalog)
local Squishy = require(script.Parent.Squishy)

return function()
	local ok = true
	local function check(cond: boolean, msg: string)
		if not cond then
			ok = false
			warn("[SelfTest] FALLA: " .. msg)
		end
	end
	check(#Config.Species == 18, "18 especies")
	check(#Config.Rarities == 6, "6 rarezas")
	check(Catalog.indexTotal() == 413, "índice = 413 (dio " .. Catalog.indexTotal() .. ")")
	check(Squishy.xpNeed(1) == 50 and Squishy.xpNeed(3) == 110, "xpNeed")
	check(
		Squishy.name({ species = "butter", variant = "original", mutation = "normal" }) == "Barra de Mantequilla",
		"nombre viral original"
	)
	check(
		Squishy.name({ species = "cat", variant = "bubblegum", mutation = "shiny" }) == "Gato Chicle Brillante",
		"nombre con mutación"
	)
	-- distribución de rarezas con suerte 0
	local rng = Random.new(42)
	local counts = {}
	local N = 100000
	for _ = 1, N do
		local d = Squishy.generate(rng, "cat", "classic_foam", 0)
		counts[d.rarity] = (counts[d.rarity] or 0) + 1
	end
	for _, r in Config.Rarities do
		local got = (counts[r.id] or 0) / N
		check(math.abs(got - r.p) < math.max(0.004, r.p * 0.15), string.format("prob %s: %.4f vs %.4f", r.id, got, r.p))
	end
	-- llenado: ventana de PERFECTO con velocidad 1 (sirve de referencia para animar el medidor)
	local t0, t1 = nil, nil
	for i = 1, 400 do
		local t = i / 100
		local res = Squishy.fillResult(Squishy.fillProgress(t, 1))
		if res == "perfect" then
			t0 = t0 or t
			t1 = t
		end
	end
	check(t0 ~= nil, "existe ventana PERFECTO")
	print(string.format("[SelfTest] Ventana PERFECTO (velocidad 1): %.2f s → %.2f s", t0 or -1, t1 or -1))
	print(ok and "[SelfTest] ✅ todo bien" or "[SelfTest] ❌ hay fallas (ver warnings)")
	return ok
end
