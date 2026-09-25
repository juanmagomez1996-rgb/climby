--!strict
-- Copia local del perfil que manda el servidor (DataSync) + helper para pedirle cosas.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local State = {}

State.data = nil :: any
local listeners: { (any) -> () } = {}
local readyWaiters: { thread } = {}

function State.onChange(fn: (any) -> ())
	table.insert(listeners, fn)
	if State.data then
		task.spawn(fn, State.data)
	end
end

function State.waitReady(): any
	if State.data then
		return State.data
	end
	table.insert(readyWaiters, coroutine.running())
	return coroutine.yield()
end

--- Pide algo al servidor. Devuelve la tabla de respuesta ({ ok = false } si falla la red).
function State.request(action: string, payload: { [string]: any }?): { [string]: any }
	local ok, res = pcall(function()
		return Remotes.func("Request"):InvokeServer(action, payload or {})
	end)
	if ok and type(res) == "table" then
		return res
	end
	return { ok = false, err = "red" }
end

function State.init()
	Remotes.event("DataSync").OnClientEvent:Connect(function(view)
		State.data = view
		for _, th in readyWaiters do
			task.spawn(th, view)
		end
		table.clear(readyWaiters)
		for _, fn in listeners do
			task.spawn(fn, view)
		end
	end)
end

return State
