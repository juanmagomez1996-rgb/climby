--!strict
-- Construye el modelo 3D de un squishy a partir de sus datos (Fase 3, SYSTEMS_SPEC §4 / ASSETS.md).
-- Usa ReplicatedStorage.Models.Squishies.<species> (importado de assets/squishies) y recolorea
-- solo "Body" según la variante. Si el modelo aún no está importado, arma uno provisional.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Catalog = require(Shared.Logic.Catalog)
local Config = require(Shared.Config)

local SquishyFactory = {}

-- color base cuando la variante solo trae textura (para el look provisional o sin textura subida)
local TEX_COLOR: { [string]: string } = {
	cotton = "#FFC6E5",
	melon = "#FF6F7D",
	seeds = "#FF6F91",
	strawberry = "#FF6F91",
	drizzle = "#8A5A44",
	galaxy = "#3B2A78",
	lava = "#FF5A1F",
	rainbow = "#FFD36E",
	stars = "#EEF5FF",
	glitch = "#8A5CFF",
	checker = "#E0E0E0",
	sesame = "#E6A95C",
}

export type Look = {
	color: Color3,
	tex: string?,
	material: Enum.Material,
	transparency: number,
	glow: boolean,
	extra: string?,
	topper: string?,
}

function SquishyFactory.look(speciesId: string, variantId: string): Look
	local sp = Catalog.SP[speciesId] or {}
	local v: any = Catalog.VAR[variantId] or {}
	if variantId == "original" and sp.orig then
		v = sp.orig
	end
	local tex = v.tex
	local hexc = v.c or (tex and TEX_COLOR[tex]) or "#F3E3CC"
	local mat = Enum.Material.SmoothPlastic
	if (v.m or 0) >= 0.5 then
		mat = Enum.Material.Foil
	elseif (v.e or 0) >= 0.5 then
		mat = Enum.Material.Neon
	elseif v.opacity then
		mat = Enum.Material.Glass
	end
	return {
		color = Color3.fromHex(hexc),
		tex = tex,
		material = mat,
		transparency = if v.opacity then math.clamp(1 - v.opacity, 0, 0.6) else 0,
		glow = (v.e or 0) > 0,
		extra = v.extra,
		topper = v.topper,
	}
end

local function templateFor(speciesId: string): Model?
	local models = ReplicatedStorage:FindFirstChild("Models")
	local folder = models and models:FindFirstChild("Squishies")
	local m = folder and folder:FindFirstChild(speciesId)
	if m and m:IsA("Model") then
		return m
	end
	return nil
end

-- Esfera que SÍ se puede estirar en un eje (Part.Ball siempre queda redonda)
local function ball(name: string, size: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function placeholder(speciesId: string): Model
	local model = Instance.new("Model")
	model.Name = speciesId
	local sp = Catalog.SP[speciesId] or {}
	local body = ball("Body", if sp.famous then Vector3.new(2.3, 1.6, 2.3) else Vector3.new(2.2, 1.8, 2.2))
	body.Parent = model
	-- carita kawaii
	for _, x in { -0.38, 0.38 } do
		local eye = ball("Part_eye", Vector3.new(0.22, 0.26, 0.22))
		eye.Color = Color3.fromHex("#282D3A")
		eye.CFrame = body.CFrame * CFrame.new(x, 0.12, -body.Size.Z / 2 + 0.12)
		eye.Parent = model
	end
	local blushL = Instance.new("Part")
	blushL.Name = "Part_mouth"
	blushL.Size = Vector3.new(0.3, 0.08, 0.1)
	blushL.Color = Color3.fromHex("#E57AAE")
	blushL.CFrame = body.CFrame * CFrame.new(0, -0.18, -body.Size.Z / 2 + 0.06)
	blushL.Parent = model
	-- orejitas para los animales
	if speciesId == "cat" or speciesId == "bear" or speciesId == "bunny" then
		for _, x in { -0.6, 0.6 } do
			local ear = ball(
				"Part_ear",
				if speciesId == "bunny" then Vector3.new(0.4, 1.1, 0.3) else Vector3.new(0.55, 0.55, 0.4)
			)
			ear.CFrame = body.CFrame * CFrame.new(x, body.Size.Y / 2, 0)
			ear.Parent = model
			ear:SetAttribute("TintWithBody", true)
		end
	end
	model.PrimaryPart = body
	return model
end

local function findBody(model: Model): BasePart?
	local b = model:FindFirstChild("Body", true)
	if b and b:IsA("BasePart") then
		return b
	end
	return model:FindFirstChildWhichIsA("BasePart", true)
end

--- Pinta el Body con el look de la variante.
function SquishyFactory.paint(model: Model, speciesId: string, variantId: string)
	local body = findBody(model)
	if not body then
		return
	end
	local isImported = model:GetAttribute("Imported") == true
	-- los virales 'original' importados ya vienen pintados en el GLB
	if isImported and variantId == "original" then
		return
	end
	local look = SquishyFactory.look(speciesId, variantId)
	body.Color = look.color
	body.Material = look.material
	body.Transparency = look.transparency
	local texId = look.tex and (Config.AssetIds.textures :: any)[look.tex]
	if body:IsA("MeshPart") then
		local mp = body :: MeshPart
		mp.TextureID = if texId and texId ~= "" then texId else ""
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("TintWithBody") then
			d.Color = look.color
			d.Material = look.material
		end
	end
	if look.glow then
		local l = Instance.new("PointLight")
		l.Color = look.color
		l.Range = 6
		l.Brightness = 1.2
		l.Parent = body
	end
	local _, size = model:GetBoundingBox()
	if look.extra == "halo" then
		local halo = Instance.new("Part")
		halo.Name = "Part_halo"
		halo.Shape = Enum.PartType.Cylinder
		halo.Size = Vector3.new(0.12, size.X * 0.55, size.X * 0.55)
		halo.Color = Color3.fromHex("#FFD86B")
		halo.Material = Enum.Material.Neon
		halo.CFrame = model:GetPivot() * CFrame.new(0, size.Y * 0.62, 0) * CFrame.Angles(0, 0, math.rad(90))
		halo.Parent = model
	elseif look.extra == "aura" then
		local h = Instance.new("Highlight")
		h.FillColor = Color3.fromHex("#8A5CFF")
		h.FillTransparency = 0.8
		h.OutlineColor = Color3.fromHex("#B999E8")
		h.Parent = model
	elseif look.extra == "puffs" then
		for i = 1, 3 do
			local puff = Instance.new("Part")
			puff.Name = "Part_puff"
			puff.Shape = Enum.PartType.Ball
			puff.Size = Vector3.one * (0.5 + i * 0.1)
			puff.Color = Color3.new(1, 1, 1)
			local a = i * 2.1
			puff.CFrame = model:GetPivot()
				* CFrame.new(math.cos(a) * size.X * 0.45, -size.Y * 0.3, math.sin(a) * size.Z * 0.45)
			puff.Parent = model
		end
	end
	if look.topper == "leaf" then
		local leaf = Instance.new("Part")
		leaf.Name = "Part_leaf"
		leaf.Size = Vector3.new(0.9, 0.12, 0.5)
		leaf.Color = Color3.fromHex("#5CC46C")
		leaf.CFrame = model:GetPivot() * CFrame.new(0, size.Y * 0.5, 0)
		leaf.Parent = model
	elseif look.topper == "drip" then
		local drip = Instance.new("Part")
		drip.Name = "Part_drip"
		drip.Shape = Enum.PartType.Ball
		drip.Size = Vector3.new(size.X * 0.7, 0.35, size.Z * 0.7)
		drip.Color = Color3.fromHex("#F2B33D")
		drip.Material = Enum.Material.Glass
		drip.CFrame = model:GetPivot() * CFrame.new(0, size.Y * 0.45, 0)
		drip.Parent = model
	end
end

export type BuildData = {
	species: string,
	variant: string,
	mutation: string?,
	size: number?,
	rarity: string?,
}

--- Modelo listo (anclado, sin colisión). scale extra opcional (p. ej. estatua).
function SquishyFactory.build(d: BuildData, extraScale: number?): Model
	local tpl = templateFor(d.species)
	local model: Model
	if tpl then
		model = tpl:Clone()
		model:SetAttribute("Imported", true)
	else
		model = placeholder(d.species)
	end
	model.Name = "Squishy_" .. d.species
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CastShadow = true
			p.Massless = true
		end
	end
	if not model.PrimaryPart then
		model.PrimaryPart = findBody(model)
	end
	SquishyFactory.paint(model, d.species, d.variant)
	local mut = Catalog.MUT[d.mutation or "normal"]
	local scale = (d.size or 1) * ((mut and mut.size) or 1) * (extraScale or 1)
	if math.abs(scale - 1) > 0.001 then
		model:ScaleTo(scale)
	end
	if d.mutation == "shiny" then
		local body = findBody(model)
		if body then
			local s = Instance.new("Sparkles")
			s.SparkleColor = Color3.fromHex("#FFF3B8")
			s.Parent = body
		end
	end
	model:SetAttribute("Squishy", true)
	return model
end

--- Altura del modelo (para apoyarlo en el piso).
function SquishyFactory.height(model: Model): number
	local _, size = model:GetBoundingBox()
	return size.Y
end

return SquishyFactory
