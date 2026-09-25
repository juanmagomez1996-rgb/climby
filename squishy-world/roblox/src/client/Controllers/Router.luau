--!strict
-- Abre pantallas por nombre sin que los controladores se requieran entre sí (evita ciclos).
local Modal = require(script.Parent.Parent.UI.Modal)
local Toast = require(script.Parent.Parent.UI.Toast)

local Router = {}
-- estas se pueden abrir aunque haya algo en curso (no reemplazan la ventana actual)
local OVERLAYS = { reveal = true, confirm = true, tutorialEquip = true }
local routes: { [string]: (any?) -> () } = {}

function Router.register(name: string, fn: (any?) -> ())
	routes[name] = fn
end

function Router.open(name: string, arg: any?)
	local fn = routes[name]
	if not OVERLAYS[name] then
		local why = Modal.blocked()
		if why then
			Toast.show(why)
			return
		end
	end
	if fn then
		fn(arg)
	else
		warn("[Router] pantalla desconocida:", name)
	end
end

return Router
