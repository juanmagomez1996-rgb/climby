--!strict
-- Abre pantallas por nombre sin que los controladores se requieran entre sí (evita ciclos).
local Router = {}
local routes: { [string]: (any?) -> () } = {}

function Router.register(name: string, fn: (any?) -> ())
	routes[name] = fn
end

function Router.open(name: string, arg: any?)
	local fn = routes[name]
	if fn then
		fn(arg)
	else
		warn("[Router] pantalla desconocida:", name)
	end
end

return Router
