# Squishy World → Roblox · Paquete de porte para Claude Code

Este paquete trae **todo lo necesario para que Claude Code (en VS Code) porte Squishy World a Roblox
Studio tal como está**: instrucciones, plan por fases, especificación de cada sistema con sus
fórmulas, el prototipo completo como referencia, los modelos 3D exportados y un proyecto de Roblox
(Rojo) ya arrancado con los datos y la lógica del juego portados y probados.

## Qué hay adentro
| Carpeta / archivo | Para qué |
|---|---|
| `CLAUDE.md` | Instrucciones maestras que Claude Code lee solo al abrir la carpeta |
| `docs/PORTING_PLAN.md` | Las 12 fases (0–11) con tareas y criterios de aceptación |
| `docs/SYSTEMS_SPEC.md` | Todas las fórmulas y números (llenado, suerte, espuma, cera, manos, tour…) |
| `docs/ROBLOX_ARCHITECTURE.md` | Cliente/servidor, remotes, DataStore, deformación, rendimiento, IA |
| `docs/PROGRESS.md` | Bitácora: Claude Code la actualiza en cada sesión |
| `reference/squishy-world.html` | El juego original jugable (ábrelo en el navegador) |
| `reference/src-js/` | El código original separado por módulos |
| `reference/screenshots/` | 19 capturas de cómo debe verse cada sistema |
| **`assets/world/`** | **El escenario completo** (`mapa_completo.glb`) y cada zona por separado |
| **`assets/machines/`** | Las 3 máquinas rellenables |
| **`assets/squishies/`** | Los 18 squishies rellenables (5 animales + 13 virales) |
| `assets/props/` | Manito kawaii, dedo con puño, vela |
| `assets/characters/` | Personaje Blocky + 18 pieles (opcional, para NPCs) |
| `assets/textures/` | 12 texturas de variantes (galaxia, lava, fresa, sandía…) |
| `assets/audio/` | 35 sonidos: los del juego en WAV (incluye loops de llenado y espuma) + interfaz |
| `assets/ui/` | Íconos del menú |
| `docs/ASSETS.md` | Qué es cada asset y cómo importarlo |
| `roblox/` | Proyecto Rojo **completo**: servidor (datos, llenado, tienda, intercambios, Robux, NPCs, mundo) y cliente (HUD, máquina, revelación, inventario, tienda, índice, intercambio, compañeros) |
| `roblox/SquishyWorld.rbxlx` | El lugar ya armado: ábrelo directo en Studio |
| `docs/MONETIZATION.md` | Game Passes y Developer Products: qué hay y cómo activarlos |

## ▶️ Probar ya (sin instalar nada)

1. Abre **`roblox/SquishyWorld.rbxlx`** con doble clic (se abre en Roblox Studio).
2. **Home → Game Settings → Security → Enable Studio Access to API Services** (para que guarde
   tus datos en Studio; si no lo activas igual se juega, solo que no guarda).
3. Dale **Play**. En la Salida (View → Output) debe salir:
   `[SelfTest] ✅ todo bien` y `[Squishy World] Servidor listo ✅`.
4. Qué probar:
   - Sigue la **línea rosada** hasta las Máquinas → **E** en la Máquina 01 → mantén
     "Mantén para llenar" y suelta en la **zona verde** → te sale el Chicle Poco común → **Guardar**.
   - **I** (Inventario) → **Equipar** → el squishy te sigue. Mantén clic sobre él para apachurrarlo.
   - **T** (Tienda) → compra un relleno / mejora. Pestaña **⭐ Robux** → toca cualquier ítem: en
     Studio se **simula** la compra (monedas, poción, VIP…).
   - Plaza de Intercambio (a la derecha de la plaza): **E** sobre un NPC para cambiar, **R** para hablar.
   - Entre jugadores: **Test → Clients and Servers → 2 Players → Start**, y en uno de ellos
     menú **🤝 Cambios** → elegir al otro jugador.
   - Sal y vuelve a entrar: monedas, nivel e inventario se conservan (si activaste el paso 2).

Mientras no importes los modelos, el mapa y los squishies son **provisionales** (bloques y
bolitas con carita) en las coordenadas reales. Cuando importes `assets/` (ver `docs/ASSETS.md`) se
usan los modelos de verdad automáticamente.

Para trabajar el código con Rojo (recomendado): `cd roblox && rokit install && rojo serve` y en
Studio plugin Rojo → **Connect**. El `.rbxlx` se regenera con `rojo build -o SquishyWorld.rbxlx`.

Monetización (pases y productos con Robux): `docs/MONETIZATION.md`.

## Lo que necesitas instalar (una vez)
1. **Roblox Studio**.
2. **VS Code** + la extensión **Claude Code**.
3. **Rokit** (instalador de herramientas de Roblox): https://github.com/rojo-rbx/rokit
4. En Studio, el **plugin de Rojo** (Creator Store → "Rojo").
5. Recomendado en VS Code: extensiones **Luau Language Server**, **StyLua** y **Selene**.

## Cómo arrancar
1. Descomprime el zip y abre la carpeta `squishy-world-roblox` en VS Code.
2. Abre Claude Code y pégale esto:

   > Lee CLAUDE.md y docs/PROGRESS.md. Arranca la Fase 0 del PORTING_PLAN: deja listo el
   > proyecto Rojo y dime paso a paso qué hago yo en Studio para conectarlo e importar los modelos.

3. Cuando te diga, en una terminal: `cd roblox`, `rokit install`, `rojo serve`. En Studio: abre un
   lugar vacío (Baseplate) → plugin Rojo → **Connect**. Dale **Play** y en la Salida debe salir
   `[SelfTest] ✅ todo bien`.
4. De ahí en adelante: una fase a la vez. Pruebas lo que te diga en Studio, le das feedback y sigue.

## Ojo con esto (importante)
- **Apachurrar de verdad** usa `EditableMesh` de Roblox. En Studio funciona siempre, pero para que
  funcione en el juego **publicado** necesitas estar **verificado 13+ con ID** y activar
  **"Enable Mesh / Image APIs"** en el Creator Dashboard. Si no quieres eso, el plan trae un plan B
  con huesos (menos detalle, sin requisitos). Claude Code te va a preguntar cuál usar.
- **El chat con IA de los NPCs** no puede llevar tu API key dentro de Roblox: se hace con un proxy
  (una función en Netlify o Supabase) y todo el texto pasa por el filtro de Roblox. Hasta tenerlo,
  los NPCs usan respuestas predefinidas.
- Todo en `assets/` se importa a Studio: los `.glb` con **Archivo → Importar 3D** (escala en Stud), y
  texturas, íconos y sonidos con el **Asset Manager**. El paso a paso está en `docs/ASSETS.md`.
  Escala: 1 unidad = 1 stud, no hay que reescalar nada.
