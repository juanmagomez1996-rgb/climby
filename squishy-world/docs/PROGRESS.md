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

## Bloque 1 de igualación (2026-09-25) — interfaz y controles como el original
- Base de UI calcada del CSS: botones con sombra sólida abajo y texto ink, pestañas activas en ink,
  moneda dibujada (UIGradient) en vez de 🪙, cerrar "×" en vez de ✕, ⭐ en vez de ★/☆, Nunito real.
- HUD: logo blanco con sombra rosada, píldoras oscuras arriba a la derecha ("Nivel N", XP mint→azul),
  menú lateral paper con íconos PNG (`AssetIds.icons`; emoji de respaldo), orden I/C/B/🎬/T + Robux,
  misión con "Muéstrame", barra de ayuda abajo a la izquierda, chat de Roblox abajo a la derecha.
- Teclas: I, C, B (tienda), T (guía a la Plaza), Esc (cerrar), Espacio (llenar), Shift (correr 22).
  Caminar 13, sin salto, FOV 58, zoom 7–24 (empieza en 14). Spawn mirando a las Máquinas.
- Aviso de interacción propio (#prompt) con los textos del original ("Usar la Máquina Squishy",
  "… — requiere nivel N", "Abrir la Tienda", "Abrir el Índice Squishy", "Hablar con X").
- Máquina: "1. Elige el molde / 2. Elige el relleno / 3. Mantén para llenar — suelta en la zona
  Perfecto", 5 columnas, silueta en moldes bloqueados, chips de relleno, medidor y etiquetas exactas,
  arreglado el corte UTF-8 de "Común"/"Épico".
- Inventario, Tienda, Índice, Chat con NPC (nuevo, con respuestas predefinidas filtradas),
  Cambio con NPC (2 columnas, "Pedir otra cosa", Cancelar/Aceptar) rehechos con el layout original.
- Revelación: fondos oscuros por rareza, pop, glitch + pantallazo negro en Secreto, partículas,
  badges blancos/amarillo, Secreto ya no suena con fanfarria.
- Tutorial: textos exactos, paso 0→1 al caminar, "Bienvenido de vuelta", pulso en Inventario,
  chevron + flecha en el piso. Silencio guardado en el perfil.

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
  con IKControl (pedido de Yeison). Si está lejos, el personaje camina hasta el squishy. R6: sin brazos.
  Por ahora el IK solo lo ve quien apachurra (los demás ven el squishy aplastarse cuando llegue SquishBroadcast).
- Chat con NPCs: respuestas predefinidas (sin IA) hasta tener el proxy.
- Misiones: `quest.i` es 1-based en Luau (el prototipo usa 0-based).

## Monetización (nuevo, no estaba en el prototipo)
- Ver `docs/MONETIZATION.md`. Efectos en `Config/Monetization.luau → EFFECTS`.

## Bugs conocidos
- (ninguno reportado todavía — falta la primera prueba en Studio)

## Revisión de código (2026-09-25) — ya corregido
- Apachurrar hundía el squishy en el piso (pivote releído cada frame) → pivote fijo al empezar.
- Bolitas provisionales no se aplastaban (Part.Ball es siempre redonda) → Block + SpecialMesh esfera.
- Tolerancia del llenado permitía elegir PERFECTO con un cliente modificado → 40 ms (+ poco ping).
- Guardado "exitoso" aunque otro servidor tuviera el candado; recibos confirmados sin estar
  guardados → se detecta el rechazo y solo se confirma un recibo ya guardado.
- Candado de sesión vencía con jugadores quietos → se renueva en cada autoguardado (60 s).
- Studio con lugar publicado sin acceso a API expulsaba al jugador → juega sin guardar.
- Spawn del Baseplate encima de la estatua + z-fighting → se mueve el spawn y se quita el Baseplate.
- Letreros de nivel con StreamingEnabled, compañeros girando 360°, fuga de conexiones en ventanas,
  límite de ítems saltable con tablas raras, y abrir otra ventana cancelaba intercambios/llenados
  (ahora se bloquea con un aviso).

## Decisiones
- Deformación: Opción A (EditableMesh) con fallback B/C — confirmar con Yeison si ya tiene la verificación 13+/ID.
- Un solo RemoteFunction `Request` en vez de muchos remotes: validación y rate limit centralizados.
- Compañeros dibujados en cada cliente a partir del atributo `Companion` (JSON) → cero tráfico por frame.
