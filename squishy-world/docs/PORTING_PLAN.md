# PORTING_PLAN — Squishy World → Roblox (fase por fase)

Regla: una fase a la vez. Al terminar cada una, Claude Code le dice a Yeison **qué probar en
Studio**, Yeison lo prueba y da el visto bueno. Luego se actualiza `docs/PROGRESS.md`.

---

## Fase 0 — Proyecto y assets
- [ ] `rokit install`, `rojo serve`, conectar el plugin de Rojo en Studio.
- [ ] `Main.server.luau` y `Main.client.luau` cargan `Shared.Config` e imprimen un resumen
      (18 especies, 6 rarezas, 12 rellenos, índice = 413).
- [ ] Guiar a Yeison con `docs/ASSETS.md` para importar TODO: `assets/world/mapa_completo.glb` →
      `Workspace.Map`; squishies, máquinas y props → `ReplicatedStorage.Models`; texturas, íconos y
      audio con el Asset Manager → crear `Shared/Config/AssetIds.luau` con los ids.
- [ ] Verificar coordenadas de control (Máquina 01 en (0,0,60), estatua en (0,6.25,0)) contra
      `WorldLayout.luau`. Revisar vértices del `Body` vs `models_info.json` y anotar cuáles hay que
      simplificar para deformar (≤ 1 500).
**Acepta si**: en Play se ve el print con los conteos correctos, el mapa se ve como en las
capturas y los 18 squishies se ven bien.

## Fase 1 — El mundo
- [ ] El mapa ya viene importado (Fase 0). `WorldBuilder` solo **conecta la lógica**: colisiones,
      spawn, zonas de interacción (ProximityPrompt / "E") en máquinas, tienda, índice, NPCs y
      Vitrina, usando `WorldLayout.luau`.
- [ ] Animaciones del escenario que había en el prototipo: agua y chorros de la fuente, estatua que
      respira, letreros de nivel bloqueado en las máquinas, cúpulas.
- [ ] Iluminación y cielo parecidos al prototipo (cielo pastel, luz cálida, nubes de Roblox).
**Acepta si**: caminando se reconoce el mapa de las capturas `05-plaza-vitrina` y `02-tour-maquinas`.

## Fase 2 — Datos, economía y HUD
- [ ] `DataService` con el esquema de ROBLOX_ARCHITECTURE §4 (+ migración), guardado automático.
- [ ] HUD: logo, monedas, nivel + barra de XP, menú lateral (Inventario, Colección, Tienda, Tour,
      Cambios), tarjeta de misión, barra de ayuda. Formato de números es-CO.
- [ ] `Logic/Rarity`, `Logic/Value`, `Logic/Naming`, `Logic/Index` puros y con pruebas rápidas
      (ej.: 100 000 tiradas con L=0 → proporciones ≈ probabilidades base).
**Acepta si**: al reentrar se conservan monedas/nivel; las pruebas de rareza pasan.

## Fase 3 — Fábrica de squishies
- [ ] `SquishyFactory.build(data)` → clona el modelo, aplica variante (color/material/textura),
      mutación (Brillante = brillo/partículas, Gigante 1.3, Mini 0.7), cara, halo/aura/extras.
- [ ] Miniaturas con `ViewportFrame` (encuadre por medidas del modelo).
- [ ] Compañero que te sigue (equipado) con saltito y respiración (squash idle).
**Acepta si**: se ven iguales que en el prototipo 5 variantes de ejemplo por rareza.

## Fase 4 — Máquina, llenado y revelación
- [ ] Panel "Crea un Squishy": moldes normales + fila "✨ Moldes virales" (candado con precio),
      rellenos (candado → Tienda), probabilidades, botón "Mantén para llenar", medidor con zonas.
- [ ] `FillService` con tiempos del servidor (SYSTEMS_SPEC §3), resultado under/perfect/over/POP.
- [ ] Squishy dentro de la cúpula tomando color; revelación con fanfarria por rareza, "Te salió…",
      badges (nuevo, viral, valor), Guardar / Vender.
**Acepta si**: 20 llenados seguidos se sienten igual que en el HTML y el servidor decide el resultado.

## Fase 5 — Inventario, tienda, índice, misiones, tutorial
- [ ] Inventario (filtros, detalle, equipar, favorito, vender, vender repetidos, 🖐️ Apachurrar).
- [ ] Tienda 3 pestañas; Índice 413 con siluetas "???"; misiones en orden + infinitas.
- [ ] Tutorial de 5 pasos con flecha guía rosada (como `Tut` en game5.js).
**Acepta si**: se puede jugar el bucle completo de nivel 1 a 5 sin el HTML al lado.

## Fase 6 — NPCs y social
- [ ] 7 NPCs (NpcDefs) paseando con su compañero (la mitad viral, 1/3 encerado), burbujas, se
      detienen al hablarles, reaccionan al apachurrarles el squishy.
- [ ] Chat: primero respuestas predefinidas; luego IA vía proxy (ROBLOX_ARCHITECTURE §8).
- [ ] Intercambio con NPC (medidor, reglas 1.15 / 0.8) y **jugador↔jugador** con doble confirmación.
**Acepta si**: dos cuentas en un servidor de prueba pueden intercambiar sin duplicar ni perder items.

## Fase 7 — Física de espuma + apachurrar en el mundo
- [ ] `DeformEngine` (Opción A EditableMesh, con B/C de respaldo) portando SYSTEMS_SPEC §7 al pie de
      la letra: fuentes, rigidez progresiva, 2 fases, inflado, palma/apretón/torcer, piso, sombreado.
- [ ] Manos kawaii que **rodean la silueta** (SYSTEMS_SPEC §9), cámara de amasar con giro y zoom,
      el dueño se detiene, fantasma de personajes, pistas en pantalla.
- [ ] Modo apuntar (§10) con retícula imán, anillo, etiqueta y ayuda de puntería.
- [ ] `SquishBroadcast` para que los demás vean el hundimiento (baja fidelidad).
**Acepta si**: comparando con `16-mundo-manos`, `17/18-manos-contorno` se ve y se siente igual;
mínimo 50 FPS en un celular de gama media apachurrando.

## Fase 8 — Estudio Squish
- [ ] Sala/visor con plato, cámara orbital, modos Dedo/Estirar/Torcer/Golpe, Palma (Espacio),
      Apretar (Q), multitouch, cronómetro de slow rise + récord, panel de stats, dedo con puño.
**Acepta si**: capturas `09`–`12` se reproducen; el slow rise de la Mantequilla ≈ 10 s.

## Fase 9 — Cera de vela
- [ ] `WaxEngine` (SYSTEMS_SPEC §8): capas acumulables de colores, vela que la echa, enfriado,
      grietas por blanqueo (sin contornos), cascada, pedazos que caen, sonido con presupuesto,
      guardado de la cera en squishies propios, NPCs encerados que se re-enceran.
**Acepta si**: capturas `13`–`15`; 3 capas se rompen de afuera hacia adentro.

## Fase 10 — Tour de bienvenida
- [ ] `TourController` (SYSTEMS_SPEC §12) con las mismas curvas, tarjetas, rutas brillantes, mapa
      con pines, panel de retos, saludo final y aterrizaje sin salto. Botón 🎬 Tour y saltar.
**Acepta si**: se ve como `01`–`04-tour-*` y al terminar la cámara no brinca.

## Fase 11 — Pulido y publicación
- [ ] Controles táctiles (mantener = amasar, botón de apuntar, botón F), audio completo, ajustes.
- [ ] Pase de rendimiento, pruebas con 10+ jugadores, logs de errores.
- [ ] Checklist de publicación: verificación 13+/ID y "Enable Mesh / Image APIs" (si Opción A),
      HttpService habilitado (si IA), permisos de DataStore, clasificación de edad.
