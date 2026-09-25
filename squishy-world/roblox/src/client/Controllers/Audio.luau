--!strict
-- Sonidos (SFX.map del prototipo → Config.AssetIds.sounds). Si un id está vacío, no suena y ya.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Audio = {}
local cache: { [string]: Sound } = {}
Audio.muted = false

local function get(name: string): Sound?
	local id = (Config.AssetIds.sounds :: any)[name]
	if not id or id == "" then
		return nil
	end
	local cached = cache[name]
	if cached then
		return cached
	end
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s.Volume = 0.6
	s.Parent = SoundService
	cache[name] = s
	return s
end

function Audio.play(name: string, pitch: number?)
	if Audio.muted then
		return
	end
	local s = get(name)
	if s then
		s.PlaybackSpeed = pitch or 1
		SoundService:PlayLocalSound(s)
	end
end

--- Loop (p. ej. llenado). Devuelve el Sound para cambiarle volumen/tono en vivo.
function Audio.loop(name: string, on: boolean): Sound?
	local s = get(name)
	if not s then
		return nil
	end
	s.Looped = true
	if on and not Audio.muted then
		if not s.IsPlaying then
			s:Play()
		end
	else
		s:Stop()
	end
	return s
end

function Audio.init()
	Remotes.event("Notify").OnClientEvent:Connect(function(msg)
		if type(msg) == "table" and msg.t == "sound" then
			Audio.play(msg.name)
		end
	end)
end

return Audio
