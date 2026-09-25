# PROGRESS — bitácora del porte (Claude Code la actualiza al final de cada sesión)

## Estado actual
- Fases **0–6 jugables** (servidor completo + UI + monetización). Falta la parte "visual pesada":
  7 (espuma con EditableMesh + manos), 8 (Estudio), 9 (Cera), 10 (Tour), 11 (pulido/publicación).
- Última sesión: 2026-09-25 — primera versión completa armada en Rojo. Sin probar todavía en Studio
  (se validó con luau-lsp en modo estricto, StyLua y `rojo build`).

## Hecho
- **Servidor** (`roblox/src/server/Services`):
  - `Net`: un solo RemoteFunction `Request(action, payload)` con validación y rate limit.
  - `DataService`: DataStore con candado de sesión (UpdateAsync), autoguardado 60 s, BindToClose,
    migración (`Logic/Profile.migrate`). En Studio sin API → perfil en memoria.
  - `Economy`: monedas, XP/niveles (con toasts de molde/máquina desbloqueados), misiones en cadena +
    infinitas, leaderstats (Monedas, Nivel).
  - `FillService`: llenado autoritativo con tiempos del servidor (±80 ms + ping), under/perfect/over/POP,
    primer llenado garantizado Chicle Poco común, relleno Misterio (100/uso), revelación pendiente
    (Guardar/Vender), si te vas con uno pendiente se guarda o se vende.
  - `InventoryService`: equipar (atributo `Companion`), favorito, vender, vender repetidos, capacidad,
    apachurrones (+2 XP cada 15), pasos del tutorial.
  - `ShopService`: moldes virales, rellenos, mejoras (Velocidad, Suerte, Espacio).
  - `TradeService`: con NPC (igual que el prototipo) y **jugador↔jugador** con doble confirmación,
    re-validación y cambio atómico + guardado inmediato de los dos.
  - `MonetizationService`: 4 Game Passes + 5 Developer Products, ProcessReceipt idempotente,
    simulación en Studio (ver `docs/MONETIZATION.md`).
  - `WorldBuilder`: ProximityPrompts en máquinas, tienda, índice, tablero de intercambio; spawn;
    iluminación pastel, nubes. **Mapa provisional** con bloques si no hay `Workspace.Map`.
  - `NpcService`: 7 NPCs **R15 con HumanoidDescription** (personajes de Roblox), pasean, burbujas,
    "Hablar" (respuestas predefinidas), "Cambiar", compañero (la mitad su viral favorito),
    reaccionan cuando les apachurras el squishy.
- **Cliente** (`roblox/src/client`): HUD (logo, monedas, nivel/XP, menú lateral, misión, ayuda,
  pociones/VIP), Máquina (moldes, virales, rellenos, probabilidades, medidor con zonas, mantener y
  soltar, squishy creciendo en la cúpula), Revelación, Inventario, Tienda (+ ⭐ Robux), Índice 413
  con siluetas, Intercambio NPC y con jugadores, Compañeros de todos (jugadores y NPCs), Apachurrar
  mínimo (Opción C: squash & stretch con slow rise de 2 fases) **con los brazos de tu avatar R15
  agarrándolo (IKControl, `AvatarHands.luau`)**, Tutorial con rayo guía rosado.
- `SquishyFactory`: usa `ReplicatedStorage.Models.Squishies.<id>` si existe; si no, un squishy
  provisional (bolita con carita y orejas). Recolorea solo `Body` según la variante.

## Siguiente
1. Yeison prueba en Studio (ver README → "Probar ya") y da feedback.
2. Importar los assets (docs/ASSETS.md): mapa → `Workspace.Map`, squishies/máquinas/props →
   `ReplicatedStorage.Models.*`, sonidos/texturas/íconos → `Config/AssetIds.luau`.
3. Crear pases y productos y pegar los ids (docs/MONETIZATION.md).
4. Fase 7: DeformEngine con EditableMesh (preguntar lo de la verificación 13+/ID) + manos.

## Desviaciones respecto al prototipo (y por qué)
- Personajes: jugadores con su avatar de Roblox; NPCs como R15 (HumanoidDescription con ropa pastel)
  en vez del Blocky de Kenney — pedido de Yeison.
- Cámara: se usa la cámara normal de Roblox; el panel de la máquina no mueve la cámara (el prototipo
  la encuadraba). Se puede agregar en el pulido.
- Apachurrar: por ahora squash & stretch del modelo (Opción C); la espuma real llega en la Fase 7.
- Manos: en vez de las manitos kawaii (`hand_mitten.glb`) se usan los brazos del avatar de Roblox
  con IKControl (pedido de Yeison). Si te lejos, el personaje camina hasta el squishy. R6: sin brazos.
  Por ahora el IK solo lo ve quien apachurra (los demás ven el squishy aplastarse cuando llegue SquishBroadcast).
- Chat con NPCs: respuestas predefinidas (sin IA) hasta tener el proxy.
- Misiones: `quest.i` es 1-based en Luau (el prototipo usa 0-based).

## Monetización (nuevo, no estaba en el prototipo)
- Ver `docs/MONETIZATION.md`. Efectos en `Config/Monetization.luau → EFFECTS`.

## Bugs conocidos
- (ninguno reportado todavía — falta la primera prueba en Studio)

## Decisiones
- Deformación: Opción A (EditableMesh) con fallback B/C — confirmar con Yeison si ya tiene la verificación 13+/ID.
- Un solo RemoteFunction `Request` en vez de muchos remotes: validación y rate limit centralizados.
- Compañeros dibujados en cada cliente a partir del atributo `Companion` (JSON) → cero tráfico por frame.
