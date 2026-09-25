# ROBLOX_ARCHITECTURE — cómo se arma Squishy World en Roblox

## 1. Estructura (Rojo)

```
roblox/
  default.project.json
  rokit.toml  selene.toml  stylua.toml
  src/
    shared/                      → ReplicatedStorage.Shared
      Config/                    datos del juego (autogenerados del prototipo)
      Types.luau                 tipos: SquishyData, PlayerData, WaxState…
      Remotes.luau               nombres y creación de RemoteEvents/Functions
      Util/                      Spline (Catmull-Rom), Damp, Random con semilla, Format es-CO
      Logic/                     reglas puras sin Roblox: Rarity, Value, Naming, Quests, Index
    server/                      → ServerScriptService.Server
      Main.server.luau
      Services/  DataService, EconomyService, FillService, InventoryService, ShopService,
                 QuestService, TradeService, NpcService, WorldBuilder, AiChatService
    client/                      → StarterPlayer.StarterPlayerScripts.Client
      Main.client.luau
      Controllers/ UIController, HudController, MachineController, RevealController,
                   InventoryController, ShopController, IndexController, QuestController,
                   SquishController (manos en el mundo + apuntar + fantasma), StudioController,
                   TourController, CameraController, AudioController, TutorialController
      Engine/      SquishyFactory, DeformEngine, WaxEngine, HandRig, Silhouette
```
Modelos importados (a mano en Studio, ver §5) → `ReplicatedStorage.Models`.
UI: construida por código (como el prototipo) o en Studio; en cualquier caso fiel a `template.html`
(fuentes: usar `Enum.Font.FredokaOne`/`GothamBlack` como equivalentes de Lilita One/Nunito; colores exactos).

## 2. Qué corre dónde

| Servidor (autoridad) | Cliente (visual/input) |
|---|---|
| Datos del jugador, guardado | Toda la UI, toasts, tutorial |
| Tirada de rareza/variante/mutación/valor | Animación del medidor y la revelación |
| **Tiempo del llenado** (marca `start` y `release` con `os.clock()` del server y calcula `p`) | Deformación de espuma (DeformEngine) |
| Monedas, XP, niveles, compras, mejoras | Cera: pedazos, grietas, caída (WaxEngine) |
| Inventario, vender, equipar, favoritos | Manos, apuntar, fantasma, cámara de amasar |
| Misiones y recompensas | Estudio Squish |
| Intercambios (NPC y jugador↔jugador) | Tour cinemático |
| NPCs: movimiento, compañeros, frases, re-encerar | Sonido y vibración |
| Chat IA (HttpService → proxy) | Envío de "estoy apachurrando a X" (para que los demás lo vean) |

El llenado: el cliente anima el medidor con la misma fórmula, pero el **resultado lo decide el
servidor** con sus propios tiempos (tolerancia ±80 ms por ping). Nunca confiar en `p` del cliente.

## 3. Remotes (en `Shared/Remotes.luau`)

| Remote | Dir | Payload |
|---|---|---|
| `FillStart` | C→S | `{ machineId, speciesId, fillingId }` |
| `FillRelease` | C→S | `{}` → respuesta `FillResult { result, squishy? , popped }` |
| `RevealDecision` | C→S | `{ squishyId, keep: boolean }` |
| `InventoryAction` | C→S | `{ action = "equip"/"fav"/"sell"/"sellDupes", id? }` |
| `ShopBuy` | C→S | `{ kind = "filling"/"mold"/"upgrade", id }` |
| `QuestClaim` (auto) | S→C | estado de misión |
| `DataSync` | S→C | parche del perfil (monedas, xp, inventario…) |
| `WaxSave` | C→S | `{ squishyId, wax }` (debounce 2 s; validar tamaños: ≤6 capas, ids < 80) |
| `TradeRequest/Offer/Accept` | ambos | flujo de 2 pasos con confirmación y re-validación en servidor |
| `NpcChat` | C→S | `{ npcId, text }` → respuesta filtrada |
| `SquishBroadcast` | C→S→C | `UnreliableRemoteEvent`: `{ targetId, point, depth }` a 10 Hz para que otros vean el hundimiento (baja fidelidad) |
| `NpcReact` | S→C | burbuja del NPC cuando le apachurran el squishy |

Validar todo en servidor (tipos, rangos, pertenencia, rate limit).

## 4. Datos del jugador (DataStore)

Usar **ProfileStore** (loleris, vía Wally) o `DataStoreService` con `UpdateAsync` + bloqueo de sesión.
Esquema (equivale a `freshState()` de `game4.js`):
```lua
{
  version = 1, coins = 500, xp = 0, level = 1,
  inventory = { SquishyData }, equipped = nil | id,
  fillings = { "classic_foam", "pink_foam", "blue_foam" }, molds = { "butter" },
  upgrades = { fillSpeed = 1, luck = 0, storage = 0 },
  discovered = { ["cat|pink"] = true, ... }, quest = { i = 1, p = 0 },
  stats = { fills, perfect, sold, trades, squishes, bestRise, waxCracked },
  tutorial = 0, tourSeen = false, tipSquish = false, lastMold = "cat",
}
SquishyData = { id, species, rarity, variant, filling, mutation, face, size, value, name,
                dateFound, fav, wax = nil | { list = { { c, s, b = {ids} } } } }
```
Límite de inventario por `Upgrades.storage.caps`. Migrar versiones con una función `migrate(profile)`.

## 5. Modelos y assets

1. Todo está en `assets/` (ver `docs/ASSETS.md`): mapa completo y por zonas, máquinas, 18
   squishies (`Body` = malla deformable), props, personajes, texturas, audio e íconos. Importar con el
   **3D Importer** (escala Stud, 1 unidad = 1 stud) y guardar en `Workspace.Map` y
   `ReplicatedStorage.Models.{Squishies,Machines,Props}`. Cara y accesorios soldados con `WeldConstraint`.
2. **Presupuesto de malla**: Roblox limita triángulos por malla (revisar el límite actual) y la
   deformación cuesta por vértice. `assets/squishies/models_info.json` muestra que algunos virales pasan de 10 k
   vértices (butter, burger, toast, catpaw por las cajas redondeadas de 26 segmentos). Para el
   **cuerpo deformable** usa versiones de **≤ 1 500 vértices** (re-exportar con menos segmentos o
   decimar en Blender) y deja el detalle en partes no deformables.
3. Colores por vértice: tostada (corteza) y queso (huecos) los usan. Si el importador no los trae,
   hornear a textura en Blender o aplicarlos con `EditableMesh` (colores por vértice).
4. Variantes: recolorear `Body` (Color/Material/`SurfaceAppearance`); texturas del prototipo
   (galaxia, lava, arcoíris, sandía, fresa, sésamo, glitch…) → exportar los canvas como PNG y subirlas.
5. Personajes: avatares R15 de Roblox para jugadores; NPCs como Rigs R15 con ropa/colores que
   recuerden a los del prototipo. Decoración: `models/world/*.glb` (Kenney, CC0).
6. Audio: `assets/audio/` ya trae los 35 sonidos (WAV + MP3). Subirlos y mapear ids en `AssetIds.luau`.

## 6. Deformación de espuma en Roblox (lo más delicado)

**Opción A (recomendada): `EditableMesh`** — fiel al prototipo.
- Crear desde la malla del `Body` con `AssetService:CreateEditableMeshAsync(...)`, mostrarla con
  `AssetService:CreateMeshPartAsync(...)` y aplicarla a la parte. **Verifica la API actual en la
  documentación de Roblox** (ha cambiado de nombre varias veces).
- Requisitos para juegos **publicados**: el dueño debe estar verificado **13+ con ID** y activar
  **"Enable Mesh / Image APIs"** en el Creator Dashboard. En Studio funciona sin eso.
- Hay **presupuesto de memoria en el cliente**: crear solo 1–2 EditableMesh a la vez (el squishy
  que se apachurra y el del Estudio) y **destruirlas** al terminar el slow rise.
- `SetPosition` por vértice es caro: vértices ≤ 1 500, actualizar a 30 Hz, tocar solo los
  vértices afectados (dentro de 3·r de alguna fuente) y el inflado a menor frecuencia. Si Roblox
  saca operaciones en bloque (buffers) para EditableMesh, migrar a eso.
- Normales: recalcular solo en los vértices tocados (o dejar que el motor las recalcule si la API lo permite).

**Opción B (plan B sin verificación): huesos.** Rigging en Blender de cada cuerpo con una malla de
12–24 huesos repartidos en la superficie; un hundimiento mueve los huesos cercanos hacia adentro
con la misma fórmula gaussiana. Menos detalle, mucho más barato y sin requisitos.

**Opción C (mínima):** solo squash/stretch con `Size`/escala + partículas. Úsala como fallback
automático si falla la creación de EditableMesh (presupuesto agotado).

Implementar `DeformEngine` con una interfaz común (`press`, `drag`, `release`, `setAxis`, `update`)
para que A/B/C sean intercambiables.

## 7. Presupuestos de rendimiento (móvil primero)

- 1 squishy deformándose a la vez en el mundo (+1 en el Estudio). Resto: solo squash con escala.
- Silueta para las manos: calcularla desde el arreglo de vértices del DeformEngine (sin raycasts),
  cada frame está bien con ≤ 1 500 vértices.
- Cera: pedazos como MeshParts estáticas creadas una vez por capa (vía EditableMesh →
  `CreateMeshPartAsync`, o precalculadas). Al soltarse: desanclar y dejar que la física de Roblox
  los tire, fade con `Transparency`, `Debris` a los 4.2 s. Máximo 160 vivos, 64 por capa.
- NPCs: `Humanoid:MoveTo` en servidor; compañeros animados en cliente (CFrame lerp).
- Nada de `while true` sin `task.wait`; usar `RunService.RenderStepped/Heartbeat`.

## 8. Chat con IA de los NPCs

- `HttpService` (servidor) → **tu proxy** (p. ej. función en Netlify o Supabase Edge) → API de Claude.
  La API key vive solo en el proxy. Prompt: el de `aiReply()` en `game4.js` (persona + reglas +
  datos del juego en español), respuesta JSON `{ say, emote, wantsTrade }`.
- Filtrar entrada y salida con `TextService:FilterStringAsync` para el jugador que lo ve.
- Rate limit por jugador (p. ej. 1 mensaje / 3 s), timeout 6 s → fallback a `scriptedReply`.
- Público infantil: respetar las normas de Roblox para chat y menores; si hay dudas, dejar solo
  respuestas predefinidas + frases rápidas.

## 9. Cámara

- Jugador: cámara normal de Roblox (Custom) para que se sienta nativo.
- Apuntar, cámara de amasar, Estudio y Tour: `CameraType = Scriptable` con el mismo suavizado
  (`damp`). Al volver: dejar la cámara **exactamente** en la pose que tenía la cámara Custom antes
  de empezar y luego pasar a `Custom` (así no hay salto; así lo hace el tour del prototipo).
- Fantasma: `LocalTransparencyModifier` en las partes de los personajes que tapen.

## 10. Estudio Squish

Sala aislada lejos del mapa (p. ej. en `(0, -500, 0)`) con su plato, luces propias y cámara
Scriptable; o `ViewportFrame` (más simple, pero sin sombras). El squishy del Estudio es una copia
local (cliente) del dato del jugador/NPC; al cerrar se guarda la cera si el squishy es propio.
