--!strict
-- Remotes del juego (ver docs/ROBLOX_ARCHITECTURE.md §3).
-- Un solo RemoteFunction "Request" (acción + payload) para todo lo que el cliente pide: así el
-- servidor valida y limita la frecuencia en un solo lugar (server/Services/Net.luau).
-- El servidor los crea con Remotes.init(); el cliente los obtiene con Remotes.get(nombre).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- C→S: Request(action, payload) → respuesta { ok: boolean, err: string?, ... }
local FUNCTIONS = { "Request" }
-- S→C: DataSync(perfil), Notify({ t = "toast"|"sound"|..., ... }), TradeEvent(estado del intercambio)
local EVENTS = { "DataSync", "Notify", "TradeEvent" }
-- C→S→C: "estoy apachurrando a X" para que los demás lo vean (baja fidelidad)
local UNRELIABLE = { "SquishBroadcast" }

local Remotes = {}

local function folder(): Folder
	local f = ReplicatedStorage:FindFirstChild("Remotes")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Remotes"
		f.Parent = ReplicatedStorage
	end
	return f :: Folder
end

local function ensure(f: Folder, className: string, name: string)
	if not f:FindFirstChild(name) then
		local r = Instance.new(className)
		r.Name = name
		r.Parent = f
	end
end

function Remotes.init()
	assert(RunService:IsServer(), "Remotes.init solo en el servidor")
	local f = folder()
	for _, n in FUNCTIONS do
		ensure(f, "RemoteFunction", n)
	end
	for _, n in EVENTS do
		ensure(f, "RemoteEvent", n)
	end
	for _, n in UNRELIABLE do
		ensure(f, "UnreliableRemoteEvent", n)
	end
end

function Remotes.get(name: string): Instance
	local f = ReplicatedStorage:WaitForChild("Remotes")
	return f:WaitForChild(name)
end

function Remotes.event(name: string): RemoteEvent
	return Remotes.get(name) :: RemoteEvent
end

function Remotes.func(name: string): RemoteFunction
	return Remotes.get(name) :: RemoteFunction
end

return Remotes
