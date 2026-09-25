--!strict
-- Ids de assets subidos con el Asset Manager (Studio → View → Asset Manager → Bulk Import).
-- Después de subir cada archivo de assets/, clic derecho → Copy Asset ID y pégalo aquí
-- como "rbxassetid://123456". Mientras esté vacío, el juego sigue funcionando sin ese asset.

local AssetIds = {
	-- assets/audio (nombres como en SFX.map de reference/src-js/game1.js)
	sounds = {
		click = "", -- click_002.mp3
		open = "", -- open_001.mp3
		close = "", -- close_002.mp3
		reward = "", -- confirmation_002.mp3
		rare = "", -- maximize_006.mp3
		epic = "", -- confirmation_004.mp3
		sparkle = "", -- glass_002.mp3
		sparkle2 = "", -- glass_005.mp3
		glitch = "", -- glitch_003.mp3
		keep = "", -- drop_002.mp3
		squish = "", -- pluck_001.mp3 (o squishy.wav)
		squish2 = "", -- pluck_002.mp3 (o squishy_agudo.wav)
		error = "", -- error_004.mp3
		select = "", -- select_003.mp3
		coin = "", -- bong_001.mp3
		levelup = "", -- switch_002.mp3
		npc = "", -- question_001.mp3
		toggle = "", -- toggle_002.mp3
		coins = "", -- monedas.wav
		pop = "", -- pop_reventon.wav
		whirr = "", -- maquina_whirr.wav
		fanfare = "", -- fanfarria.wav
		secretSting = "", -- secreto_sting.wav
		crinkle = "", -- crinkle.wav
		fillLoop = "", -- llenado_loop.wav (se reproduce en loop)
	},
	-- assets/textures (variantes)
	textures = {
		checker = "",
		cotton = "",
		drizzle = "",
		galaxy = "",
		glitch = "",
		lava = "",
		melon = "",
		rainbow = "",
		seeds = "",
		sesame = "",
		stars = "",
		strawberry = "",
	},
	-- assets/ui
	icons = {
		inv = "",
		col = "",
		shop = "",
		tour = "",
		trade = "",
	},
}

return AssetIds
