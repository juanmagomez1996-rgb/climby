--!strict
-- Avisos arriba al centro (toast() del prototipo: máximo 4, entran bajando y se van solos).
-- .toast: paper, radius 16, Nunito 900 15, sombra abajo · .toast.big: igual pero Lilita 24.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)

local Toast = {}
local holder: Frame? = nil
local order = 0

local function getHolder(): Frame
	if holder then
		return holder
	end
	local h: Frame = Kit.new("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 18),
		Size = UDim2.new(0, 540, 0, 300),
		ZIndex = 50,
		Parent = Kit.root("toast"),
	}, { Kit.list(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center) })
	holder = h
	return h
end

function Toast.show(msg: string, big: boolean?, ms: number?)
	local h = getHolder()
	order += 1
	local wrap: CanvasGroup = Kit.new("CanvasGroup", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		LayoutOrder = order,
		GroupTransparency = 1,
		Parent = h,
	})
	local t: Frame = Kit.new("Frame", {
		BackgroundColor3 = Theme.paper,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		Position = UDim2.fromOffset(0, -14),
		Parent = wrap,
	}, {
		Kit.corner(16),
		if big then Kit.pad(26, 14) else Kit.pad(18, 10),
		Kit.new("UISizeConstraint", { MaxSize = Vector2.new(520, 220) }),
		Kit.text(msg, if big then 24 else 15, {
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			TextXAlignment = Enum.TextXAlignment.Center,
			FontFace = if big then Theme.display else Theme.bodyBlack,
			TextColor3 = Theme.ink,
		}),
	})
	-- margen para la sombra
	Kit.new("UIPadding", { PaddingBottom = UDim.new(0, 6), Parent = wrap })
	Kit.shadow(t, Color3.fromRGB(207, 208, 214), 5, 16)
	Kit.tween(wrap, 0.3, { GroupTransparency = 0 })
	Kit.tween(t, 0.3, { Position = UDim2.fromOffset(0, 0) })
	local kids = {}
	for _, ch in h:GetChildren() do
		if ch:IsA("CanvasGroup") then
			table.insert(kids, ch)
		end
	end
	table.sort(kids, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #kids > 4 do
		local first = table.remove(kids, 1)
		if first then
			first:Destroy()
		end
	end
	task.delay((ms or 2600) / 1000, function()
		if wrap.Parent then
			Kit.tween(wrap, 0.35, { GroupTransparency = 1 })
			Kit.tween(t, 0.35, { Position = UDim2.fromOffset(0, -10) })
			task.delay(0.4, function()
				wrap:Destroy()
			end)
		end
	end)
end

function Toast.init()
	Remotes.event("Notify").OnClientEvent:Connect(function(msg)
		if type(msg) == "table" and msg.t == "toast" and type(msg.msg) == "string" then
			Toast.show(msg.msg, msg.big, msg.ms)
		end
	end)
end

return Toast
