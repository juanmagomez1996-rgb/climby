--!strict
-- Colores y fuentes de template.html (variables CSS :root del prototipo).
local function c(h: string): Color3
	return Color3.fromHex(h)
end

local Theme = {
	ink = c("#282D3A"),
	ink2 = c("#3a4154"),
	muted = c("#6d7285"),
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
	green = c("#35b889"),
	orange = c("#e59a3c"),
	white = Color3.new(1, 1, 1),
	robux = c("#00B06F"),
	-- Lilita One → FredokaOne, Nunito → GothamBold/Black (ROBLOX_ARCHITECTURE §1)
	display = Enum.Font.FredokaOne,
	body = Enum.Font.GothamBold,
	bodyBlack = Enum.Font.GothamBlack,
}

function Theme.dark(col: Color3): Color3
	return col:Lerp(Color3.new(0, 0, 0), 0.2)
end

return Theme
