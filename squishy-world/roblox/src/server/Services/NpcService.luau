--!strict
-- 7 NPCs (NpcDefs) como personajes R15 de Roblox. Pasean cerca de su casa, dicen frases cada
-- 7–15 s, se detienen si hablas con ellos y llevan su compañero (la mitad su viral favorito).
-- Chat: respuestas predefinidas (scriptedReply de game4.js). La IA vía proxy va en la Fase 6.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Catalog = require(Shared.Logic.Catalog)
local Config = require(Shared.Config)
local Squishy = require(Shared.Logic.Squishy)
local Net = require(script.Parent.Net)
local TradeService = require(script.Parent.TradeService)

local NpcService = {}
local rng = Random.new()

type Npc = { def: any, model: Model, humanoid: Humanoid, home: Vector3, busyUntil: number }
local npcs: { [string]: Npc } = {}

-- colores de ropa pastel por NPC (el prototipo usaba pieles Kenney; aquí avatar R15)
local OUTFITS = {
	{ "#F7A7CD", "#FFFFFF" },
	{ "#A6DB8E", "#3E7D3A" },
	{ "#CDB8F2", "#FFFFFF" },
	{ "#8BC7E8", "#2F4A7A" },
	{ "#FFE38F", "#F7A7CD" },
	{ "#F8B27C", "#5A3A2A" },
	{ "#9CE0CA", "#B999E8" },
}
local SKIN = { "#F6D3B3", "#E8B894", "#C98E62", "#8D5A3B", "#F1C9A5", "#FFDFC4", "#B67A52" }

local function describe(i: number): HumanoidDescription
	local hd = Instance.new("HumanoidDescription")
	local skin = Color3.fromHex(SKIN[(i - 1) % #SKIN + 1])
	hd.HeadColor = skin
	hd.LeftArmColor = skin
	hd.RightArmColor = skin
	hd.LeftLegColor = Color3.fromHex(OUTFITS[i][2])
	hd.RightLegColor = Color3.fromHex(OUTFITS[i][2])
	hd.TorsoColor = Color3.fromHex(OUTFITS[i][1])
	hd.HeightScale = 0.95
	hd.WidthScale = 0.95
	hd.HeadScale = 1.1
	return hd
end

local function say(n: Npc, text: string, secs: number?)
	local head = n.model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local old = head:FindFirstChild("Bubble")
	if old then
		old:Destroy()
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "Bubble"
	bb.Size = UDim2.fromOffset(220, 60)
	bb.StudsOffset = Vector3.new(0, 3.2, 0)
	bb.MaxDistance = 70
	local f = Instance.new("TextLabel")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.TextColor3 = Color3.fromHex("#3A3350")
	f.Font = Enum.Font.GothamBold
	f.TextScaled = true
	f.TextWrapped = true
	f.Text = text
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 14)
	c.Parent = f
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = f
	f.Parent = bb
	bb.Parent = head
	task.delay(secs or 4, function()
		if bb.Parent then
			bb:Destroy()
		end
	end)
end

local function pick<T>(list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

local function has(t: string, words: { string }): boolean
	for _, w in words do
		if string.find(t, w, 1, true) then
			return true
		end
	end
	return false
end

--- scriptedReply(n, text) de game4.js, tal cual (detecta inglés/español).
local function scriptedReply(n: Npc, text: string): (string, string, boolean)
	local t = string.lower(text)
	local padded = " " .. string.gsub(t, "[%p]", " ") .. " "
	local en = false
	for _, w in { "hi", "hello", "hey", "trade", "want", "how", "what", "you", "your", "the", "is", "are", "thanks" } do
		if string.find(padded, " " .. w .. " ", 1, true) then
			en = true
			break
		end
	end
	if has(t, { "ñ", "á", "é", "í", "ó", "ú", "¿", "¡" }) then
		en = false
	end
	local es = not en
	local function L(e: string, sp: string): string
		return if es then sp else e
	end
	local fav = Catalog.SP[n.def.fav]
	if has(t, { "trade", "cambi", "interc" }) then
		return L("Sure! Let's see what you've got 👀", "¡Dale! Muéstrame qué tienes 👀"), "yes", true
	end
	if has(t, { "aplast", "apachurr", "squish", "slow", "suav", "sube" }) then
		return L(
			"Hold click on any squishy to squish it — press F for close-up!",
			"¡Mantén clic sobre cualquier squishy para apachurrarlo, o presiona F para verlo de cerca! Los de Miel suben lentííísimo 🍯"
		),
			"yes",
			false
	end
	if has(t, { "mantequilla", "butter", "viral", "famos" }) then
		return L(
			"The butter one is the best, it rises sooo slow 🧈",
			"¡La Barra de Mantequilla es la mejor, sube lentííísimo! 🧈 Los demás virales están en la Tienda."
		),
			"yes",
			false
	end
	if has(t, { "perfect", "tip", "how", "consejo", "truco", "cómo", "como" }) then
		return L(
			"Tip: let go right inside the green Perfect zone, it boosts your luck!",
			"Truco: suelta justo en la zona verde Perfect, ¡te sube la suerte!"
		),
			"yes",
			false
	end
	if has(t, { "legend", "secret", "secreto" }) then
		return L(
			"Legendaries are super rare… Mystery filling helps a tiny bit ✨",
			"Los legendarios son rarísimos… el relleno Mystery ayuda un poquito ✨"
		),
			"none",
			false
	end
	if string.find(t, n.def.fav, 1, true) and fav then
		return L(
			string.format("%ss are my favorite!! Got any?", fav.name),
			string.format("¡Los %s son mis favoritos! ¿Tienes alguno?", fav.name)
		),
			"yes",
			true
	end
	if es then
		return pick({
			"¡Qué buen compañero tienes!",
			"¿Ya probaste la Máquina 02?",
			"¿Quieres cambiar?",
			"¡Me encanta esta plaza!",
		}),
			pick({ "none", "yes" }),
			rng:NextNumber() < 0.3
	end
	local lines = table.clone(n.def.lines)
	for _, l in { "Nice companion!", "Have you tried Machine 02?", "Want to trade?" } do
		table.insert(lines, l)
	end
	return pick(lines), pick({ "none", "yes" }), rng:NextNumber() < 0.3
end

local function spawnNpc(i: number, def: any, folder: Folder)
	local zone = (Config.WorldLayout.zones :: any)[def.home] or Config.WorldLayout.zones.center
	local home = zone.center + Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8))
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(describe(i), Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[NpcService] no pude crear el NPC", def.name, model)
		return
	end
	model.Name = def.name
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.DisplayName = def.name
	hum.WalkSpeed = 8
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	hum.NameDisplayDistance = 60
	model:PivotTo(CFrame.new(home + Vector3.new(0, 3, 0)))
	model:SetAttribute("Npc", true)

	-- compañero: la mitad (índices pares en el prototipo, 0-based) lleva su viral favorito
	local species = if (i - 1) % 2 == 0 then def.famousFav else def.fav
	local sq =
		Squishy.generate(rng, species, "classic_foam", 0, { rarity = if (i - 1) % 2 == 0 then "common" else nil })
	model:SetAttribute(
		"Companion",
		HttpService:JSONEncode({
			id = sq.id,
			species = sq.species,
			variant = sq.variant,
			mutation = sq.mutation,
			rarity = sq.rarity,
			size = sq.size,
			name = sq.name,
			face = sq.face,
		})
	)

	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	-- #prompt del original: "Hablar con {npc}" (E) → abre el chat (el botón Cambiar está en el chat)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = "Hablar con " .. def.name
	pp.ObjectText = ""
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.MaxActivationDistance = 10
	pp.RequiresLineOfSight = false
	pp.Style = Enum.ProximityPromptStyle.Custom
	pp:SetAttribute("Kind", "npc")
	pp:SetAttribute("Id", def.name)
	pp.Parent = root
	model.Parent = folder
	root:SetNetworkOwner(nil)

	local n: Npc = { def = def, model = model, humanoid = hum, home = home, busyUntil = 0 }
	npcs[def.name] = n

	-- paseo
	task.spawn(function()
		while model.Parent do
			task.wait(rng:NextNumber(3, 7))
			if os.clock() >= n.busyUntil and hum.Health > 0 then
				local target = home + Vector3.new(rng:NextNumber(-10, 10), 0, rng:NextNumber(-10, 10))
				hum:MoveTo(target)
			end
		end
	end)
	-- burbujas
	task.spawn(function()
		local every = Config.Game.NPC_BUBBLE_EVERY
		while model.Parent do
			task.wait(rng:NextNumber(every[1], every[2]))
			if os.clock() >= n.busyUntil then
				say(n, def.lines[rng:NextInteger(1, #def.lines)], 4)
			end
		end
	end)
end

local function stopFor(n: Npc, player: Player, secs: number)
	n.busyUntil = os.clock() + secs
	local root = n.model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local char = player.Character
	local proot = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	n.humanoid:MoveTo(if root then root.Position else n.home)
	if root and proot then
		local look = Vector3.new(proot.Position.X, root.Position.Y, proot.Position.Z)
		if (look - root.Position).Magnitude > 0.1 then
			root.CFrame = CFrame.lookAt(root.Position, look)
		end
	end
end

function NpcService.init()
	local folder = Instance.new("Folder")
	folder.Name = "NPCs"
	folder.Parent = Workspace
	for i, def in Config.NpcDefs do
		task.spawn(spawnNpc, i, def, folder)
	end

	TradeService.setNpcHooks(function(name)
		local n = npcs[name]
		return if n then n.model else nil
	end, function(name, text)
		local n = npcs[name]
		if n then
			say(n, text, 4)
		end
	end)

	Net.on("npcTalk", function(player, payload)
		local n = npcs[payload.npc]
		if not n then
			return { ok = false }
		end
		stopFor(n, player, 8)
		return { ok = true }
	end)
	local lastChat: { [Player]: number } = {}
	Net.on("npcChat", function(player, payload)
		local n = npcs[payload.npc]
		local text = payload.text
		if not n or type(text) ~= "string" or #text == 0 or #text > 280 then
			return { ok = false }
		end
		if os.clock() - (lastChat[player] or 0) < 1 then
			return { ok = false, err = "rate" }
		end
		lastChat[player] = os.clock()
		-- todo texto de jugadores pasa por el filtro de Roblox
		local okF, filtered = pcall(function()
			local r = TextService:FilterStringAsync(string.sub(text, 1, 140), player.UserId)
			return r:GetNonChatStringForBroadcastAsync()
		end)
		if not okF then
			return { ok = false, err = "filtro" }
		end
		stopFor(n, player, 10)
		local reply, emote, wantsTrade = scriptedReply(n, filtered :: string)
		reply = string.sub(reply, 1, 220)
		say(n, reply, 5)
		return { ok = true, mine = filtered, say = reply, emote = emote, wantsTrade = wantsTrade }
	end)
	-- le están apachurrando el compañero: se detiene y reacciona
	Net.on("npcSquished", function(player, payload)
		local n = npcs[payload.npc]
		if not n or os.clock() < n.busyUntil - 2 then
			return { ok = false }
		end
		stopFor(n, player, 5)
		local lines = {
			"¡Oye, con cuidado! 😆",
			"¿Verdad que es suavecito?",
			"¡Jajaja, apachúrralo!",
			"Sube lentííísimo, mira 👀",
		}
		say(n, lines[rng:NextInteger(1, #lines)], 3.5)
		return { ok = true }
	end)
end

return NpcService
