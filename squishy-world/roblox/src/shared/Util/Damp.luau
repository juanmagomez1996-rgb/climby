--!strict
-- Suavizado exponencial independiente del FPS, igual que damp() del prototipo.
local Damp = {}
function Damp.number(a: number, b: number, k: number, dt: number): number
	return a + (b - a) * (1 - math.exp(-k * dt))
end
function Damp.vector(a: Vector3, b: Vector3, k: number, dt: number): Vector3
	return a:Lerp(b, 1 - math.exp(-k * dt))
end
function Damp.smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end
return Damp
