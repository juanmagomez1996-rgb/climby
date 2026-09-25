--!strict
-- Mini librería de UI por código, calcada del CSS de template.html (.btn, .tab, .coin, .pill…).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Kit = {}

export type Props = { [string]: any }

--- Kit.new("Frame", { Size = … }, { hijos })
function Kit.new(className: string, props: Props?, children: { any }?): any
	local inst: any = Instance.new(className)
	local parent = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			else
				inst[k] = v
			end
		end
	end
	if children then
		for _, ch in children do
			ch.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Kit.corner(r: number): any
	return Kit.new("UICorner", { CornerRadius = UDim.new(0, r) })
end

function Kit.round(): any
	return Kit.new("UICorner", { CornerRadius = UDim.new(1, 0) })
end

function Kit.stroke(col: Color3, t: number?): any
	return Kit.new("UIStroke", { Color = col, Thickness = t or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

function Kit.pad(px: number, py: number?): any
	local y = py or px
	return Kit.new("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, y),
		PaddingBottom = UDim.new(0, y),
	})
end

function Kit.list(dir: Enum.FillDirection?, gap: number?, align: Enum.HorizontalAlignment?): any
	return Kit.new("UIListLayout", {
		FillDirection = dir or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
	})
end

function Kit.grid(cell: UDim2, gap: number?): any
	return Kit.new("UIGridLayout", {
		CellSize = cell,
		CellPadding = UDim2.fromOffset(gap or 8, gap or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function Kit.text(text: string, size: number, props: Props?): any
	local p: Props = {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		FontFace = Theme.body,
		TextColor3 = Theme.ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		RichText = true,
		Size = UDim2.new(1, 0, 0, size + 6),
	}
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	return Kit.new("TextLabel", p)
end

--- Subtítulo h3 del panel: Lilita 17 color purpleD.
function Kit.h3(text: string, props: Props?): any
	local p: Props = { FontFace = Theme.display, TextColor3 = Theme.purpleD }
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	return Kit.text(text, 17, p)
end

--- "Sombra" sólida de abajo (box-shadow: 0 Npx 0 color) como franja bajo el borde inferior.
function Kit.shadow(parent: GuiObject, col: Color3, px: number?, radius: number?)
	local old = parent:FindFirstChild("_Shadow")
	if old then
		old:Destroy()
	end
	local h = px or 4
	local r = radius or 14
	Kit.new("Frame", {
		Name = "_Shadow",
		BackgroundColor3 = col,
		BorderSizePixel = 0,
		Position = UDim2.new(0, math.floor(r * 0.35), 1, -2),
		Size = UDim2.new(1, -math.floor(r * 0.7), 0, h + 2),
		Parent = parent,
	}, { Kit.corner(math.max(3, h)) })
end

local INK_TEXT_EXCEPT = {} :: { [Color3]: boolean }
INK_TEXT_EXCEPT[Theme.purple] = true
INK_TEXT_EXCEPT[Theme.ink] = true
INK_TEXT_EXCEPT[Theme.robux] = true

--- Botón .btn: radius 14, Nunito 900 15, fondo de color con sombra sólida abajo, texto ink
--- (blanco solo en .purple/.dark). variant: "small" | "big".
function Kit.button(text: string, color: Color3?, props: Props?, variant: string?): any
	local col = color or Theme.white
	local big = variant == "big"
	local small = variant == "small"
	local radius = if big then 18 elseif small then 11 else 14
	local p: Props = {
		AutoButtonColor = true,
		BackgroundColor3 = col,
		Text = text,
		TextSize = if big then 20 elseif small then 13 else 15,
		FontFace = if big then Theme.display else Theme.bodyBlack,
		TextColor3 = if INK_TEXT_EXCEPT[col] then Theme.white else Theme.ink,
		Size = UDim2.new(1, 0, 0, if big then 50 elseif small then 30 else 40),
		RichText = true,
	}
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	local b = Kit.new("TextButton", p, { Kit.corner(radius) })
	Kit.shadow(b, Theme.shadowOf(col), if small then 3 else 4, radius)
	-- al presionar baja 3px (como .btn:active)
	local down = false
	b.MouseButton1Down:Connect(function()
		if down then
			return
		end
		down = true
		b.Position += UDim2.fromOffset(0, 2)
	end)
	local function up()
		if down then
			down = false
			b.Position -= UDim2.fromOffset(0, 2)
		end
	end
	b.MouseButton1Up:Connect(up)
	b.MouseLeave:Connect(up)
	return b
end

--- Cambia el color de un botón ya creado (actualiza la sombra y el color del texto).
function Kit.recolor(b: any, col: Color3)
	b.BackgroundColor3 = col
	b.TextColor3 = if INK_TEXT_EXCEPT[col] then Theme.white else Theme.ink
	local sh = b:FindFirstChild("_Shadow")
	if sh then
		sh.BackgroundColor3 = Theme.shadowOf(col)
	end
end

--- Pestaña .tab: radius 11, 900 13, fondo lav; activa = ink con texto blanco; viral = #fff4fb.
function Kit.tab(text: string, on: boolean, viral: boolean?, props: Props?): any
	local p: Props = {
		AutoButtonColor = true,
		BackgroundColor3 = if on then Theme.ink elseif viral then Color3.fromHex("#fff4fb") else Theme.lav,
		TextColor3 = if on then Theme.white else Theme.ink,
		Text = text,
		TextSize = 13,
		FontFace = Theme.bodyBlack,
		RichText = true,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
	}
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	return Kit.new("TextButton", p, { Kit.corner(11), Kit.pad(12, 0) })
end

--- Moneda .coin: círculo con gradiente #fff3b8 → #f4c542 → #d19b1c (el emoji 🪙 sale en cuadrito).
function Kit.coin(size: number, props: Props?): any
	local p: Props = {
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(size, size),
	}
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	return Kit.new("Frame", p, {
		Kit.round(),
		Kit.new("UIGradient", {
			Rotation = 60,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHex("#fff3b8")),
				ColorSequenceKeypoint.new(0.55, Color3.fromHex("#f4c542")),
				ColorSequenceKeypoint.new(1, Color3.fromHex("#d19b1c")),
			}),
		}),
	})
end

--- Botón de precio: [moneda] 1.500 centrado.
function Kit.priceButton(amount: string, color: Color3, props: Props?): any
	local b = Kit.button("", color, props)
	local row = Kit.new("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 18),
		Parent = b,
	}, { Kit.list(Enum.FillDirection.Horizontal, 5) });
	(row:FindFirstChildOfClass("UIListLayout") :: UIListLayout).VerticalAlignment = Enum.VerticalAlignment.Center
	Kit.coin(14, { LayoutOrder = 1, Parent = row })
	Kit.text(amount, 15, {
		FontFace = Theme.bodyBlack,
		TextColor3 = b.TextColor3,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 18),
		TextWrapped = false,
		LayoutOrder = 2,
		Parent = row,
	})
	return b
end

--- Estrella dibujada (★/☆ salen en cuadrito): ⭐ emoji, apagada = transparente.
function Kit.star(on: boolean, size: number, props: Props?): any
	local p: Props = {
		Text = "⭐",
		TextTransparency = if on then 0 else 0.65,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(size + 4, size + 4),
	}
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	return Kit.text("⭐", size, p)
end

function Kit.setEnabled(b: GuiButton, on: boolean)
	b.Active = on
	b.AutoButtonColor = on
	local tb = b :: any
	tb.BackgroundTransparency = if on then 0 else 0.45
	if b:IsA("TextButton") then
		(b :: TextButton).TextTransparency = if on then 0 else 0.45
	end
	for _, d in b:GetDescendants() do
		if d:IsA("TextLabel") then
			d.TextTransparency = if on then 0 else 0.45
		elseif d:IsA("Frame") then
			d.BackgroundTransparency = if on then 0 else 0.45
		end
	end
end

function Kit.clear(parent: Instance)
	for _, ch in parent:GetChildren() do
		if not ch:IsA("UIGridStyleLayout") and not ch:IsA("UIPadding") and not ch:IsA("UICorner") then
			ch:Destroy()
		end
	end
end

function Kit.tween(
	inst: Instance,
	t: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
)
	local tw = TweenService:Create(
		inst,
		TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		goal
	)
	tw:Play()
	return tw
end

--- Primera palabra cortada a n caracteres (UTF-8 seguro; "Común" → "Comú").
function Kit.shortName(name: string, n: number): string
	local w = string.match(name, "^%S+") or name
	local cut = utf8.offset(w, n + 1)
	return if cut then string.sub(w, 1, cut - 1) else w
end

local guis: { [string]: ScreenGui } = {}
--- ScreenGui principal (respeta la barra de Roblox) o "full" (pantalla completa: revelación, tour…).
function Kit.root(kind: string?): ScreenGui
	local k = kind or "main"
	local g = guis[k]
	if g then
		return g
	end
	local ng: ScreenGui = Kit.new("ScreenGui", {
		Name = if k == "main" then "SquishyUI" else "SquishyUI_" .. k,
		ResetOnSpawn = false,
		IgnoreGuiInset = k ~= "main",
		DisplayOrder = if k == "main" then 1 elseif k == "modal" then 2 else 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	guis[k] = ng
	return ng
end

return Kit
