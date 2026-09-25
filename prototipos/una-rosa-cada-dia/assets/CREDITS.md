# Assets

## Generados con Higgsfield
- Personajes: imágenes con GPT Image 2.5; animaciones con Kling 3.0 (idle, correr, saltar, caminar) sobre pantalla verde.
- `brother.png` / `mother.png`: sprite sheets (una fila por animación) creados con `tools/make_sprites.py`
  (extrae cuadros, quita el verde, elige el tramo que mejor hace loop, alinea los pies y mide el collider).
  `brother.json` / `mother.json` son los atlas: tamaño de cuadro, ancla, altura del cuerpo y cuadros por animación
  (el salto viene separado en `rise`, `fall` y `land`).
- Fondos (`*_far.webp`, `*_mid.webp`), `house.webp`, `ground.webp`, `shadow.webp`: GPT Image 2.5.
  `meta.json` guarda la posición de la ventana de la casa, detectada automáticamente.

## CC0
- `fog.png`: "Thick Fog", OpenGameArt, https://opengameart.org/content/thick-fog (CC0), vía https://github.com/Tiddybub/2d-assets

El sonido se sintetiza en el navegador con Web Audio.
