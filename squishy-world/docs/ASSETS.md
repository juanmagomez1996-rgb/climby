# ASSETS — todo lo del juego, listo para Roblox Studio

Todo salió **directamente del prototipo en ejecución**, así que las formas, colores, posiciones y
sonidos son los mismos del juego original. **Escala: 1 unidad = 1 stud** (el personaje del
prototipo mide 5.4, igual que un avatar de Roblox), así que no hay que reescalar nada.

## Inventario

| Carpeta | Qué hay | Cómo se usa en Roblox |
|---|---|---|
| `assets/world/mapa_completo.glb` | **Todo el escenario** en un solo archivo, agrupado por zona: plaza (fuente, estatua gigante, Vitrina Viral con los 13 virales, bancas, letreros), Máquinas (fábrica + 3 máquinas), Colección (pedestales, vitrinas, tablero del Índice), Tienda, Plaza de Intercambio (tablero, sombrillas), caminos, naturaleza (árboles, flores, cerca) y suelo | Importar y dejar en `Workspace.Map` con el pivote en el origen (0,0,0). Anclar todo. |
| `assets/world/zona_*.glb` | Lo mismo pero una zona por archivo (plaza, machines, collection, shop, trading, caminos, naturaleza, suelo) | Útil si el archivo completo es muy pesado para importar de una, o para editar zonas por separado. **Usa uno u otro, no ambos.** |
| `assets/world/decoracion_kenney/` | 15 modelos sueltos de naturaleza (CC0) | Para decorar más o reemplazar piezas. |
| `assets/machines/machine_m1..m3.glb` | Las 3 máquinas rellenables sueltas, centradas en el origen. Partes con nombre: `Dome` (cúpula donde se ve el squishy), `Liquid`, `Nozzle`, `Lamp`, `LockSign` | `ReplicatedStorage.Models.Machines`. El mapa ya las trae puestas; estas sirven para animarlas/clonarlas por código. |
| `assets/squishies/squishy_<id>.glb` | **Los 18 squishies rellenables** (5 animales + 13 virales) con su look base. La malla que se deforma se llama **`Body`**; cara y accesorios `Part_n`; bases que no se deforman (vaporera, pozo, palito) `Base_n` | `ReplicatedStorage.Models.Squishies.<id>`. Las variantes se hacen recoloreando `Body` (ver abajo). |
| `assets/squishies/models_info.json` | Vértices, triángulos, alto/ancho y **vértices del Body** de cada uno | Para decidir qué simplificar antes de deformar. |
| `assets/props/` | `hand_mitten.glb` (manito kawaii del lobby), `hand_finger_pointer.glb` (dedo con puño del Estudio), `candle.glb` (vela de la cera) | `ReplicatedStorage.Models.Props`. |
| `assets/characters/` | Personaje Kenney Blocky (`base.glb`, 27 animaciones) + 18 texturas de piel (CC0) | **Opcional**: en Roblox los jugadores usan su avatar. Sirve si quieres que los NPCs se vean como en el prototipo. |
| `assets/textures/tex_*.png` | Las 12 texturas procedurales de variantes: fresa, sandía, chocolate, algodón de azúcar, galaxia, lava, arcoíris, estrellas, glitch, dev (checker), fresa viral y pan con sésamo | Subir como Decals/Images y usarlas en `Body` (TextureID o SurfaceAppearance). |
| `assets/audio/*.wav` | 17 sonidos sintetizados del juego renderizados a WAV: squishy (normal/grave/agudo), pop, máquina, fanfarria, secreto, monedas, crinkle, cera (crack suave/fuerte, tink), estirar, torcer, acorde del tour y **2 loops** (llenado y espuma) | Subir como Audio. Los loops van con `Looped = true` y se les cambia volumen/tono en vivo. |
| `assets/audio/*.mp3` | 18 sonidos de interfaz Kenney (CC0): click, abrir, cerrar, premio, raro, épico, brillo, glitch, guardar, squish, error, seleccionar, moneda, subir nivel, NPC, toggle | Subir como Audio. El mapeo nombre→archivo está en `SFX.map` de `reference/src-js/game1.js`. |
| `assets/ui/icon_*.png` | Íconos del menú lateral (Inventario, Colección, Tienda, Tour, Cambios) | Subir como Images para la UI. |
| `roblox/src/shared/Config/WorldLayout.luau` | **Coordenadas exactas** de todo lo interactivo: spawn, zonas, máquinas (+ posición de la cúpula), pedestales por rareza, los 13 puestos de la Vitrina (posición, rotación, escala), estatua, mostrador de la tienda, casas de NPCs | Los scripts usan esto para saber dónde están las cosas del mapa importado. |

## Cómo importar (Studio)

1. **Archivo → Importar 3D** (3D Importer) → elegir el `.glb`.
2. En las opciones: unidad de escala en **Stud** (para que 1 unidad = 1 stud), anclar, sin
   "recentrar" para el mapa (para que quede en sus coordenadas reales).
3. Revisa una coordenada de control: la Máquina 01 debe quedar en **(0, 0, 60)** y la estatua en
   **(0, 6.25, 0)**. Si el mapa sale reflejado o rotado, corrige girando el modelo completo y
   anótalo en `docs/PROGRESS.md` → Desviaciones (y aplica lo mismo a `WorldLayout`).
4. Guarda cada cosa en su lugar: `Workspace.Map`, `ReplicatedStorage.Models.{Squishies,Machines,Props}`.
5. Sube texturas, íconos y audio con el **Asset Manager** (Bulk Import) y anota los ids en un módulo
   `Shared/Config/AssetIds.luau` (Claude Code lo crea y te pide los ids).

## Variantes (recolorear en vez de 413 modelos)

Cada squishy = 1 modelo base; la rareza/variante cambia **solo el `Body`**:
- Color, rugosidad (`r`), metal (`m`), brillo (`e` → material Neon o SurfaceAppearance emisiva),
  opacidad (`opacity` → Transparency), textura (`tex` → las PNG de `assets/textures`).
- Extras: `halo` (anillo dorado arriba), `aura` (copia escalada 1.14 transparente), `puffs`
  (nubecitas), toppers `leaf` / `drip`. Todo está en `Config/Variants.luau`.
- Los virales en variante `original` usan el look de `Species[i].orig` (ya viene pintado en el GLB).

## Límites a tener en cuenta
- Algunos virales tienen un `Body` de **4 374 vértices** (mantequilla, tostada, queso, cubo de hielo,
  por las cajas redondeadas). Para deformarlos en tiempo real conviene bajarlos a **≤ 1 500**
  (decimar en Blender o re-exportar con menos segmentos). Los animales ya están en 1 189.
- La plaza pesa más (3.6 MB) porque trae la estatua y los 13 virales en alta; si Studio se pone
  lento al importar, usa las zonas por separado.
- Colores por vértice: la corteza de la tostada y los huecos del queso los usan. Si el importador no
  los respeta, hornearlos a textura o pintarlos con `EditableMesh`.
