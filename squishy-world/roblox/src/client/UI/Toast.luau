--!strict
-- Avisos arriba al centro (toast() del prototipo: máximo 4, se van solos).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)

local Toast = {}
local holder: Frame? = nil

local function getHolder(): Frame
	if holder then
		return holder
	end
	local h: Frame = Kit.new("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.new(0, 520, 0, 300),
		ZIndex = 50,
		Parent = Kit.root(),
	}, { Kit.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center) })
	holder = h
	return h
end

function Toast.show(msg: string, big: boolean?, ms: number?)
	local h = getHolder()
	local t: Frame = Kit.new("Frame", {
		BackgroundColor3 = if big then Theme.ink else Theme.paper,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		ZIndex = 50,
		Parent = h,
	}, {
		Kit.corner(16),
		Kit.pad(16, 9),
		Kit.stroke(if big then Theme.pink else Theme.lav2, 2),
		Kit.new("UISizeConstraint", { MaxSize = Vector2.new(500, 200) }),
		Kit.text(msg, if big then 19 else 15, {
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.fromOffset(0, 0),
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = if big then Theme.display else Theme.body,
			TextColor3 = if big then Theme.white else Theme.ink,
			ZIndex = 51,
		}),
	})
	local kids = {}
	for _, ch in h:GetChildren() do
		if ch:IsA("Frame") then
			table.insert(kids, ch)
		end
	end
	while #kids > 4 do
		local first = table.remove(kids, 1)
		if first then
			first:Destroy()
		end
	end
	task.delay((ms or 2600) / 1000, function()
		if t.Parent then
			t:Destroy()
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
