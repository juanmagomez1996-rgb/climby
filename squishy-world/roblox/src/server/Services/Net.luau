--!strict
-- Puerta de entrada de todas las peticiones del cliente (Remote "Request").
-- Cada servicio registra sus acciones con Net.on(action, handler). Aquí se valida el tipo del
-- payload y se limita la frecuencia por jugador para que nadie spamee el servidor.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

export type Handler = (player: Player, payload: { [string]: any }) -> { [string]: any }?

local Net = {}

local handlers: { [string]: Handler } = {}
local buckets: { [Player]: { tokens: number, last: number } } = {}

local RATE = 12 -- peticiones por segundo sostenidas
local BURST = 24

local function allow(player: Player): boolean
	local now = os.clock()
	local b = buckets[player]
	if not b then
		b = { tokens = BURST, last = now }
		buckets[player] = b
	end
	b.tokens = math.min(BURST, b.tokens + (now - b.last) * RATE)
	b.last = now
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

function Net.on(action: string, handler: Handler)
	assert(handlers[action] == nil, "acción repetida: " .. action)
	handlers[action] = handler
end

function Net.notify(player: Player, msg: { [string]: any })
	Remotes.event("Notify"):FireClient(player, msg)
end

function Net.toast(player: Player, text: string, big: boolean?, ms: number?)
	Net.notify(player, { t = "toast", msg = text, big = big == true, ms = ms })
end

function Net.sound(player: Player, name: string)
	Net.notify(player, { t = "sound", name = name })
end

function Net.init()
	local rf = Remotes.func("Request")
	rf.OnServerInvoke = function(player: Player, action: any, payload: any): any
		if type(action) ~= "string" then
			return { ok = false, err = "bad_action" }
		end
		if payload ~= nil and type(payload) ~= "table" then
			return { ok = false, err = "bad_payload" }
		end
		if not allow(player) then
			return { ok = false, err = "rate" }
		end
		local h = handlers[action]
		if not h then
			return { ok = false, err = "unknown_action" }
		end
		local ok, res = pcall(h, player, payload or {})
		if not ok then
			warn(string.format("[Net] %s falló para %s: %s", action, player.Name, tostring(res)))
			return { ok = false, err = "server_error" }
		end
		return res or { ok = true }
	end
	Players.PlayerRemoving:Connect(function(p)
		buckets[p] = nil
	end)
end

return Net
