# Kinetic Arena — prototipo 3D

Idea 1 de *Pulso Vibranium* llevada a 3D realista. Cada salto (y cada golpe recibido) carga el traje con
energía cinética; con **E** haces un súper salto y al aterrizar levantas una onda de columnas de basalto
que destruye a los drones. Abre `index.html` desde un servidor HTTP (por ejemplo `python3 -m http.server`
dentro de esta carpeta): los GLB no cargan con `file://`.

## Controles
| Tecla | Acción |
|---|---|
| WASD / flechas | Moverse |
| Espacio | Saltar (mantener = saltos seguidos) |
| E / Shift | Súper salto (desde 40 de energía) |
| C | Mostrar/ocultar colliders |

En móvil aparecen joystick y botones **Saltar** / **Pulso**.

## Assets (generados con Higgsfield)
| Archivo | Origen | Notas |
|---|---|---|
| `assets/models/hero.glb` | Imagen GPT Image 2.5 → Meshy image-to-3D con rig + clip *Idle* | ~21k tris, texturas PBR 1536 px |
| `assets/models/hero_run.glb` / `hero_jump.glb` / `hero_hit.glb` | Meshy 3D Rigging sobre el héroe (clips *run_fast_3_inplace*, *Regular_Jump*, *Hit_Reaction*) | Solo animación (texturas eliminadas); se reasignan al esqueleto del héroe |
| `assets/models/drone.glb` | Imagen → Meshy image-to-3D | ~8k tris |
| `assets/models/pillar.glb` | Imagen → Meshy image-to-3D | ~7.5k tris |
| `assets/models/wave_block.glb` | Imagen → Meshy image-to-3D (low poly) | Se instancia miles de veces en la onda |
| `assets/models/crystal.glb` | Imagen → Meshy image-to-3D | Brotan en el borde de la súper onda |
| `assets/textures/floor.jpg`, `sky.jpg` | GPT Image 2.5 | Suelo tileable y panorama del cielo (también se usa como mapa de entorno PBR) |
| `assets/concept/*.jpg` | Imágenes de concepto originales (reducidas) | |

Los GLB originales pesaban 9–14 MB; `tools/optimize_glb.py` reescala y recomprime las texturas (≈1–2 MB cada uno).

## Spritesheets (`assets/sprites/`)
Cada PNG tiene su `.json` con los rectángulos de cada fotograma (`frames`) y `meta` (tamaño de celda, filas, columnas, fps, loop).

| Sheet | Contenido |
|---|---|
| `hero_idle`, `hero_run`, `hero_jump`, `hero_hit` | Render del héroe 3D animado: **8 direcciones** (filas S, SO, O, NO, N, NE, E, SE) × 6–8 fotogramas, celdas de 256 px, fondo transparente. `meta.pivot` = pies. Útiles para una versión 2D (p. ej. Flame en la app de Flutter). |
| `drone_spin` | Dron girando, 16 fotogramas de 128 px |
| `vfx_shockwave` | Anillo de energía que se expande (se proyecta en el suelo) |
| `vfx_impact` | Chispa de impacto |
| `vfx_explosion` | Explosión del dron |
| `vfx_aura` | Aura en bucle alrededor del héroe cargado |

Regenerar:
```sh
python3 tools/make_vfx_sheets.py      # VFX procedurales
node tools/render_sprites.js          # héroe + dron desde los GLB (Playwright + Chromium)
```

## Física y colliders
Sin motor de física externo; todo está en `game.html` (sección *Mundo y colliders*):
- **Jugador:** cápsula vertical (radio 0.38 m, alto 1.8 m). Choca de lado con pilares y plataformas, y puede aterrizar sobre las plataformas.
- **Pilares:** cilindros. **Plataformas:** cajas AABB. **Bordes:** límites de la arena.
- **Drones:** esferas; chocan con el escenario y entre sí, y rodean los obstáculos.
- **Daño:** distancia cápsula–esfera (si saltas por encima de un dron, no te toca).
- **Onda:** golpea a los drones cuando el frente pasa por ellos; los bloques no aparecen dentro de los pilares.

Pulsa **C** en el juego para ver los colliders (verde = estáticos, amarillo = dinámicos).

## FX de la onda
Columnas de basalto 3D instanciadas que suben en secuencia · muro de energía aditivo que acompaña al frente ·
chispas y polvo GPU · anillo en el suelo (spritesheet) · luz puntual · cristales 3D que brotan en la súper onda ·
bloom (UnrealBloomPass) · temblor de cámara.

Si el servidor no sirve `.glb` (como el Artifact publicado), el juego busca `<modelo>.glb.b64.txt` y lo decodifica en memoria;
para generarlos: `for f in assets/models/*.glb; do base64 -w0 $f > $f.b64.txt; done`.

`game.html` es la versión publicada como Artifact (sin `<html>/<head>`); `tools/build_index.sh` genera `index.html`.
