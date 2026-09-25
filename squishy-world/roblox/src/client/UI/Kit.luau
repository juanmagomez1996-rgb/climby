--!strict
-- Mini librería de UI por código (el prototipo arma su UI con HTML; aquí con Instances).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Kit = {}

export type Props = { [string]: any }

--- Kit.new("Frame", { Size = …, [Kit.children] = {…} })
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

function Kit.text(text: string, size: number, props: Props?): TextLabel
	local p: Props = {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		Font = Theme.body,
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

--- Botón redondeado con "sombra" abajo como .btn del prototipo.
function Kit.button(text: string, color: Color3?, props: Props?): TextButton
	local col = color or Theme.white
	local dark = col == Theme.white
	local p: Props = {
		AutoButtonColor = true,
		BackgroundColor3 = col,
		Text = text,
		TextSize = 16,
		Font = Theme.bodyBlack,
		TextColor3 = if dark or col == Theme.yellow or col == Theme.mint then Theme.ink else Theme.white,
		Size = UDim2.new(1, 0, 0, 40),
		RichText = true,
	}
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	local b: TextButton = Kit.new("TextButton", p, {
		Kit.corner(12),
		Kit.new("UIStroke", {
			Color = if dark then Theme.lav2 else Theme.dark(col),
			Thickness = 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
	return b
end

function Kit.setEnabled(b: GuiButton, on: boolean)
	b.Active = on
	b.AutoButtonColor = on
	local tb = b :: any
	tb.BackgroundTransparency = if on then 0 else 0.45
	if b:IsA("TextButton") then
		(b :: TextButton).TextTransparency = if on then 0 else 0.4
	end
end

function Kit.clear(parent: Instance)
	for _, ch in parent:GetChildren() do
		if not ch:IsA("UIGridStyleLayout") and not ch:IsA("UIPadding") and not ch:IsA("UICorner") then
			ch:Destroy()
		end
	end
end

function Kit.tween(inst: Instance, t: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	local tw =
		TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

local gui: ScreenGui? = nil
function Kit.root(): ScreenGui
	if gui then
		return gui
	end
	local g: ScreenGui = Kit.new("ScreenGui", {
		Name = "SquishyUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	gui = g
	return g
end

return Kit
