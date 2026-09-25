--!strict
-- Colores y fuentes de template.html (variables CSS :root del prototipo).
local function c(h: string): Color3
	return Color3.fromHex(h)
end

local NUNITO = "rbxasset://fonts/families/Nunito.json"

local Theme = {
	ink = c("#282D3A"),
	ink2 = c("#3a4154"),
	muted = c("#6d7285"),
	grey = c("#7a7f92"),
	paper = c("#FFFCF8"),
	lav = c("#EEE8FA"),
	lav2 = c("#DCD1F3"),
	pink = c("#F7A7CD"),
	pinkD = c("#E57AAE"),
	purple = c("#B999E8"),
	purpleD = c("#9676CF"),
	blue = c("#8BC7E8"),
	blueD = c("#5FA8D2"),
	mint = c("#9CE0CA"),
	mintD = c("#6BC4A8"),
	yellow = c("#F4D982"),
	yellowD = c("#DDB94F"),
	red = c("#FF7B8A"),
	popRed = c("#e0566b"),
	green = c("#35b889"),
	perfectLbl = c("#3faf86"),
	orange = c("#e59a3c"),
	viral = c("#a86ad0"),
	white = Color3.new(1, 1, 1),
	robux = c("#00B06F"),
	-- Lilita One → FredokaOne (no existe Lilita en Roblox); Nunito sí existe
	display = Font.fromEnum(Enum.Font.FredokaOne),
	body = Font.new(NUNITO, Enum.FontWeight.ExtraBold),
	bodyBlack = Font.new(NUNITO, Enum.FontWeight.Heavy),
	bodyBold = Font.new(NUNITO, Enum.FontWeight.Bold),
}

--- Color "D" (sombra de abajo) de cada color de botón, como .btn.pink { box-shadow: 0 4px 0 pinkD }.
function Theme.shadowOf(col: Color3): Color3
	local pairs_ = {
		{ Theme.pink, Theme.pinkD },
		{ Theme.purple, Theme.purpleD },
		{ Theme.blue, Theme.blueD },
		{ Theme.mint, Theme.mintD },
		{ Theme.yellow, Theme.yellowD },
		{ Theme.white, Theme.lav2 },
		{ Theme.lav, Theme.lav2 },
		{ Theme.paper, Theme.lav2 },
		{ Theme.ink, c("#11141c") },
	}
	for _, p in pairs_ do
		if p[1] == col then
			return p[2]
		end
	end
	return col:Lerp(Color3.new(0, 0, 0), 0.2)
end

function Theme.dark(col: Color3): Color3
	return Theme.shadowOf(col)
end

return Theme
