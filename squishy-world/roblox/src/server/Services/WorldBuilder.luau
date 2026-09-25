--!strict
-- Conecta la lógica al mapa (Fase 1): puntos de interacción (ProximityPrompt), spawn e iluminación.
-- Si todavía no importaste assets/world/mapa_completo.glb a Workspace.Map, construye un mapa
-- provisional con bloques en las MISMAS coordenadas de WorldLayout para poder jugar ya.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)

local L = Config.WorldLayout
local WorldBuilder = {}

local function hex(h: string): Color3
	return Color3.fromHex(h)
end

local function part(props: { [string]: any }, parent: Instance): BasePart
	local p: BasePart
	if props.Shape == "Cylinder" or props.Shape == "Ball" then
		local pp = Instance.new("Part")
		pp.Shape = if props.Shape == "Ball" then Enum.PartType.Ball else Enum.PartType.Cylinder
		p = pp
	else
		p = Instance.new("Part")
	end
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Color = props.Color or Color3.new(1, 1, 1)
	p.Size = props.Size or Vector3.one
	p.CFrame = props.CFrame or CFrame.new()
	p.Name = props.Name or "Part"
	p.Transparency = props.Transparency or 0
	p.CanCollide = props.CanCollide ~= false
	p.Parent = parent
	return p
end

local function label(adornee: BasePart, text: string, color: Color3, offset: number, size: number?)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(size or 260, 56)
	bb.StudsOffsetWorldSpace = Vector3.new(0, offset, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 140
	bb.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = Color3.new(1, 1, 1)
	local st = Instance.new("UIStroke")
	st.Color = color:Lerp(Color3.new(0, 0, 0), 0.35)
	st.Thickness = 3
	st.Parent = t
	t.Parent = bb
	bb.Parent = adornee
end

local function flatCyl(
	pos: Vector3,
	radius: number,
	height: number,
	color: Color3,
	parent: Instance,
	name: string
): BasePart
	return part({
		Shape = "Cylinder",
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Name = name,
	}, parent)
end

local function buildPlaceholder(): Model
	local map = Instance.new("Model")
	map.Name = "Map"
	-- suelo
	flatCyl(Vector3.new(0, -0.5, 0), L.worldRadius, 1, hex("#A6DB8E"), map, "Ground")
	flatCyl(Vector3.new(0, 0.05, 0), L.plazaRadius, 0.2, hex("#F3E3CC"), map, "Plaza")
	-- fuente + estatua
	flatCyl(Vector3.new(0, 0.6, 0), L.fountainRadius, 1.2, hex("#FFFFFF"), map, "Fountain")
	flatCyl(Vector3.new(0, 1.05, 0), L.fountainRadius - 0.8, 0.2, hex("#8BC7E8"), map, "Water").Material =
		Enum.Material.Glass
	part({
		Shape = "Ball",
		Size = Vector3.new(7, 6, 7),
		CFrame = CFrame.new(L.statue.pos),
		Color = hex("#FFE38F"),
		Name = "Statue",
	}, map)
	-- caminos en cruz
	for _, dir in { Vector3.new(1, 0, 0), Vector3.new(0, 0, 1) } do
		part({
			Size = if dir.X ~= 0 then Vector3.new(170, 0.2, 7) else Vector3.new(7, 0.2, 170),
			CFrame = CFrame.new(0, 0.02, 0),
			Color = hex("#F4E6CF"),
			Name = "Path",
		}, map)
	end
	-- zonas
	for key, z in L.zones :: any do
		if key ~= "center" then
			local pad = flatCyl(z.center + Vector3.new(0, 0.08, 0), 16, 0.2, z.color, map, "Zone_" .. key)
			label(pad, z.label, z.color, 13, 320)
		end
	end
	-- máquinas
	for _, m in L.machines do
		local def
		for _, md in Config.Machines do
			if md.id == m.id then
				def = md
			end
		end
		local color = hex(def.color)
		local body = part({
			Size = Vector3.new(6, 4.2, 5),
			CFrame = CFrame.new(m.pos + Vector3.new(0, 2.1, 0)),
			Color = color,
			Name = "Machine_" .. m.id,
		}, map)
		part({
			Shape = "Ball",
			Size = Vector3.new(4.2, 4.2, 4.2),
			CFrame = CFrame.new(m.dome),
			Color = Color3.new(1, 1, 1),
			Transparency = 0.7,
			Material = Enum.Material.Glass,
			CanCollide = false,
			Name = "Dome_" .. m.id,
		}, map)
		label(body, def.name, color, 7.2)
	end
	-- tienda
	local counter = part({
		Size = Vector3.new(4, 3, 10),
		CFrame = CFrame.new(L.shopCounter + Vector3.new(0, 1.5, 0)),
		Color = hex("#F4D982"),
		Name = "ShopCounter",
	}, map)
	label(counter, "🛒 Tienda", hex("#F4D982"), 5)
	-- colección: pedestales + tablero del Índice
	for _, pd in L.pedestals do
		local r
		for _, rr in Config.Rarities do
			if rr.id == pd.rarity then
				r = rr
			end
		end
		flatCyl(pd.pos - Vector3.new(0, 2.2, 0), 1.6, 4.4, hex(r.color), map, "Pedestal_" .. pd.rarity)
	end
	local board = part({
		Size = Vector3.new(12, 7, 0.6),
		CFrame = CFrame.new(0, 3.5, -70),
		Color = hex("#B999E8"),
		Name = "IndexBoard",
	}, map)
	label(board, "📖 Índice Squishy", hex("#B999E8"), 5)
	-- plaza de intercambio
	local tb = part({
		Size = Vector3.new(0.6, 6, 10),
		CFrame = CFrame.new(66, 3, 0),
		Color = hex("#8BC7E8"),
		Name = "TradeBoard",
	}, map)
	label(tb, "🤝 Plaza de Intercambio", hex("#8BC7E8"), 5)
	-- Vitrina Viral: pedestales
	for _, v in L.vitrina do
		flatCyl(v.pos - Vector3.new(0, 0.7, 0), 1.3, 1.4, hex("#FFFFFF"), map, "Vitrina_" .. v.species)
	end
	map.Parent = Workspace
	return map
end

local function prompt(pos: Vector3, kind: string, id: string, action: string, object: string, folder: Instance)
	local anchor = Instance.new("Part")
	anchor.Name = kind .. "_" .. id
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = pos
	anchor:SetAttribute("Kind", kind)
	anchor:SetAttribute("Id", id)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = action
	pp.ObjectText = object
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.MaxActivationDistance = Config.Game.INTERACT_DIST + 3
	pp.RequiresLineOfSight = false
	pp.Style = Enum.ProximityPromptStyle.Custom -- se dibuja como el #prompt del original (Interact.luau)
	pp.Parent = anchor
	anchor.Parent = folder
end

function WorldBuilder.build()
	local map = Workspace:FindFirstChild("Map")
	if not map then
		warn(
			"[WorldBuilder] No hay Workspace.Map: construyo el mapa provisional (importa mapa_completo.glb cuando puedas)"
		)
		-- el Baseplate queda al mismo nivel del suelo y parpadea (z-fighting)
		local bp = Workspace:FindFirstChild("Baseplate")
		if bp then
			bp:Destroy()
		end
		map = buildPlaceholder()
	else
		for _, d in map:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
	end

	-- spawn: el Baseplate de Studio trae uno en (0,0,0) = encima de la fuente/estatua → moverlo
	for _, d in Workspace:GetDescendants() do
		if d:IsA("SpawnLocation") then
			-- mirando hacia las Máquinas (+Z), como el original
			d.CFrame = CFrame.new(L.spawn + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, math.pi, 0)
			d.Transparency = 1
			d.CanCollide = false
			local decal = d:FindFirstChildOfClass("Decal")
			if decal then
				decal:Destroy()
			end
		end
	end
	if not Workspace:FindFirstChildWhichIsA("SpawnLocation", true) then
		local sp = Instance.new("SpawnLocation")
		sp.Anchored = true
		sp.Size = Vector3.new(6, 0.4, 6)
		sp.CFrame = CFrame.new(L.spawn + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, math.pi, 0)
		sp.Transparency = 1
		sp.CanCollide = false
		sp.Duration = 0
		sp.Parent = Workspace
	end

	-- puntos de interacción
	local folder = Instance.new("Folder")
	folder.Name = "Interact"
	for _, m in L.machines do
		local def
		for _, md in Config.Machines do
			if md.id == m.id then
				def = md
			end
		end
		prompt(
			m.pos + Vector3.new(0, 3, -3),
			"machine",
			m.id,
			if m.id == "m1" then "Usar la Máquina Squishy" else "Usar " .. def.name,
			"",
			folder
		)
	end
	prompt(L.shopCounter + Vector3.new(2.5, 3, 0), "shop", "shop", "Abrir la Tienda", "", folder)
	prompt(Vector3.new(0, 3, -67), "index", "index", "Abrir el Índice Squishy", "", folder)
	prompt(Vector3.new(64, 3, 0), "tradeBoard", "board", "Cambiar con jugadores", "", folder)
	folder.Parent = Workspace

	-- iluminación pastel (cielo claro, luz cálida)
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(150, 140, 165)
	Lighting.OutdoorAmbient = Color3.fromRGB(190, 180, 200)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local a = Instance.new("Atmosphere")
		a.Density = 0.28
		a.Haze = 1.2
		a.Color = Color3.fromRGB(255, 225, 240)
		a.Decay = Color3.fromRGB(190, 170, 230)
		a.Parent = Lighting
	end
	if not Workspace.Terrain:FindFirstChildOfClass("Clouds") then
		local c = Instance.new("Clouds")
		c.Cover = 0.55
		c.Density = 0.6
		c.Color = Color3.fromRGB(255, 245, 250)
		c.Parent = Workspace.Terrain
	end
end

return WorldBuilder
