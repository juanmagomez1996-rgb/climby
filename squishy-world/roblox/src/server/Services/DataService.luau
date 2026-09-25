--!strict
-- Guardado del perfil (DataStore) con bloqueo de sesión, autoguardado y migración.
-- Esquema: docs/ROBLOX_ARCHITECTURE.md §4 (Types.PlayerData). Clave: "u_<UserId>".
-- En Studio sin "Enable Studio Access to API Services" usa un perfil en memoria (no se guarda).
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Profile = require(Shared.Logic.Profile)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)

local DataService = {}

local STORE_NAME = "SquishyWorld_v1"
local AUTOSAVE_EVERY = 60
local LOCK_EXPIRE = 60 * 10 -- un servidor caído suelta el candado a los 10 min
local MAX_RECEIPTS = 60

type Entry = {
	data: Types.PlayerData,
	loaded: boolean,
	dirty: boolean,
	syncQueued: boolean,
	offline: boolean,
	savedReceipts: { [string]: boolean }, -- recibos que YA están en el DataStore
}

local entries: { [Player]: Entry } = {}
local loadedCallbacks: { (Player, Types.PlayerData) -> () } = {}
local viewProviders: { (Player, { [string]: any }) -> () } = {}
local releasingCallbacks: { (Player, Types.PlayerData) -> () } = {}

local store: DataStore? = nil
do
	local ok, res = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = res
	else
		warn("[DataService] DataStore no disponible (¿Studio sin acceso a API?). Se juega sin guardar:", res)
	end
end

local jobId = game.JobId ~= "" and game.JobId or ("studio-" .. HttpService:GenerateGUID(false))

local function key(player: Player): string
	return "u_" .. player.UserId
end

local function retry<T>(fn: () -> T, tries: number): (boolean, any)
	local ok, res = false, nil
	for i = 1, tries do
		ok, res = pcall(fn)
		if ok then
			return true, res
		end
		task.wait(math.min(8, 1.5 ^ i))
	end
	return false, res
end

-- Carga con candado: si otro servidor lo tiene reciente, reintenta; si está vencido, lo toma.
local function loadRaw(player: Player): (boolean, any, boolean)
	local s = store
	if not s then
		return true, nil, true
	end
	for attempt = 1, 6 do
		local blocked = false
		local ok, res = pcall(function()
			return s:UpdateAsync(key(player), function(old: any)
				old = old or {}
				local lock = old.lock
				if lock and lock.job ~= jobId and os.time() - (lock.t or 0) < LOCK_EXPIRE then
					blocked = true
					return nil -- no escribir
				end
				old.lock = { job = jobId, t = os.time() }
				return old
			end)
		end)
		if ok and not blocked then
			return true, res and res.data or nil, false
		end
		if not ok then
			warn("[DataService] error cargando", player.Name, res)
			if RunService:IsStudio() then
				-- lugar publicado pero sin "Studio Access to API Services": jugar sin guardar
				warn("[DataService] Studio sin acceso a DataStore: se juega sin guardar")
				return true, nil, true
			end
		end
		if attempt == 6 and blocked then
			-- último intento: robar el candado (el otro servidor probablemente murió)
			local ok2, res2 = pcall(function()
				return s:UpdateAsync(key(player), function(old: any)
					old = old or {}
					old.lock = { job = jobId, t = os.time() }
					return old
				end)
			end)
			if ok2 then
				return true, res2 and res2.data or nil, false
			end
		end
		task.wait(attempt * 1.5)
	end
	return false, nil, false
end

local function saveRaw(player: Player, e: Entry, release: boolean): boolean
	local s = store
	if e.offline or not s then
		return true
	end
	local data = e.data
	-- recortar recibos viejos (solo se necesitan los últimos para no dar dos veces la misma compra)
	while #data.receipts > MAX_RECEIPTS do
		table.remove(data.receipts, 1)
	end
	local rejected = false
	local snapshot = table.clone(data.receipts)
	local ok, err = retry(function()
		rejected = false
		return s:UpdateAsync(key(player), function(old: any)
			old = old or {}
			if old.lock and old.lock.job ~= jobId and os.time() - (old.lock.t or 0) < LOCK_EXPIRE then
				rejected = true
				return nil -- otro servidor se lo quedó: no pisar sus datos
			end
			old.data = data
			old.lock = if release then nil else { job = jobId, t = os.time() }
			return old
		end)
	end, 3)
	if not ok then
		warn("[DataService] no se pudo guardar", player.Name, err)
		return false
	end
	if rejected then
		warn("[DataService] otro servidor tiene el candado de", player.Name, "— no se guardó")
		return false
	end
	e.dirty = false
	for _, r in snapshot do
		e.savedReceipts[r] = true
	end
	return true
end

local function buildView(player: Player, e: Entry): { [string]: any }
	local view: { [string]: any } = table.clone(e.data :: any)
	view.receipts = nil
	view.serverTime = os.time()
	for _, fn in viewProviders do
		fn(player, view)
	end
	return view
end

--- Llamar cuando cambia algo del perfil: marca para guardar y manda DataSync (agrupado por frame).
function DataService.changed(player: Player)
	local e = entries[player]
	if not e or not e.loaded then
		return
	end
	e.dirty = true
	if e.syncQueued then
		return
	end
	e.syncQueued = true
	task.defer(function()
		e.syncQueued = false
		if entries[player] == e and player.Parent then
			Remotes.event("DataSync"):FireClient(player, buildView(player, e))
		end
	end)
end

function DataService.get(player: Player): Types.PlayerData?
	local e = entries[player]
	return if e and e.loaded then e.data else nil
end

function DataService.isLoaded(player: Player): boolean
	local e = entries[player]
	return e ~= nil and e.loaded
end

function DataService.waitFor(player: Player, timeout: number?): Types.PlayerData?
	local t0 = os.clock()
	while player.Parent and os.clock() - t0 < (timeout or 30) do
		local d = DataService.get(player)
		if d then
			return d
		end
		task.wait(0.1)
	end
	return nil
end

--- ¿Este recibo ya quedó guardado en el DataStore? (offline = siempre sí)
function DataService.receiptSaved(player: Player, purchaseId: string): boolean
	local e = entries[player]
	if not e then
		return false
	end
	return e.offline or store == nil or e.savedReceipts[purchaseId] == true
end

--- Guarda ya (se usa después de una compra con Robux antes de confirmar el recibo).
function DataService.saveNow(player: Player): boolean
	local e = entries[player]
	if not e or not e.loaded then
		return false
	end
	return saveRaw(player, e, false)
end

function DataService.onLoaded(fn: (Player, Types.PlayerData) -> ())
	table.insert(loadedCallbacks, fn)
	for p, e in entries do
		if e.loaded then
			task.spawn(fn, p, e.data)
		end
	end
end

--- Antes de soltar el perfil (el jugador se va): p. ej. guardar el squishy pendiente de la máquina.
function DataService.onReleasing(fn: (Player, Types.PlayerData) -> ())
	table.insert(releasingCallbacks, fn)
end

--- Permite a otros servicios agregar campos calculados al DataSync (capacidad, pases…).
function DataService.addViewProvider(fn: (Player, { [string]: any }) -> ())
	table.insert(viewProviders, fn)
end

local function onPlayerAdded(player: Player)
	local ok, raw, offline = loadRaw(player)
	if not player.Parent then
		-- se fue mientras cargaba: soltar el candado sin tocar sus datos
		local s = store
		if ok and not offline and s then
			pcall(function()
				s:UpdateAsync(key(player), function(old: any)
					if old and old.lock and old.lock.job == jobId then
						old.lock = nil
						return old
					end
					return nil
				end)
			end)
		end
		return
	end
	if not ok then
		player:Kick("No pudimos cargar tus datos. Vuelve a entrar en un momento 🙏")
		return
	end
	local e: Entry = {
		data = Profile.migrate(raw),
		loaded = true,
		dirty = false,
		syncQueued = false,
		offline = offline,
		savedReceipts = {},
	}
	for _, r in e.data.receipts do
		e.savedReceipts[r] = true
	end
	entries[player] = e
	for _, fn in loadedCallbacks do
		task.spawn(fn, player, e.data)
	end
	DataService.changed(player)
end

local function onPlayerRemoving(player: Player)
	local e = entries[player]
	if not e then
		return
	end
	if e.loaded then
		for _, fn in releasingCallbacks do
			pcall(fn, player, e.data)
		end
		saveRaw(player, e, true)
	end
	entries[player] = nil
end

function DataService.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayerAdded, p)
	end
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_EVERY)
			for p, e in entries do
				-- se guarda en cada pasada (aunque no haya cambios) para renovar el candado de sesión
				if e.loaded then
					task.spawn(saveRaw, p, e, false)
				end
			end
		end
	end)
	game:BindToClose(function()
		if RunService:IsStudio() and not store then
			return
		end
		local pending = 0
		for p, e in entries do
			pending += 1
			task.spawn(function()
				for _, fn in releasingCallbacks do
					pcall(fn, p, e.data)
				end
				saveRaw(p, e, true)
				pending -= 1
			end)
		end
		local t0 = os.clock()
		while pending > 0 and os.clock() - t0 < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService
