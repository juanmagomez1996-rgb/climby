# Assets

## Generados con Higgsfield (GPT Image 2.5 y Kling 3.0)
- Personajes: imágenes realistas animadas con Kling 3.0 sobre pantalla verde, convertidas en sprite sheets con
  `tools/make_sprites.py` y luego en siluetas estilo LIMBO (cuerpo negro, un ojo blanco, la rosa roja) con
  `tools/limbo_sprites.py`. `brother.json` / `mother.json` son los atlas (el salto viene separado en `rise`, `fall`, `land`).
- Fondos monocromos: `forest_far.webp`, `cave_far.webp`, `rain_far.webp`; capas `forest_mid.webp`, `cave_ceil.webp`;
  borde de pasto `grass.png`; `house.png` (la ventana se detecta sola, ver `meta.json`); `shadow.webp`.
- `props/`: árboles, raíces, rocas, estalactitas, trampas, caja, reja, palanca, placa, cuerda, cadena, farol.
  Se generaron en hojas y se recortaron con `tools/slice_props.py`.

## CC0
- `fog.png`: "Thick Fog", OpenGameArt, https://opengameart.org/content/thick-fog (CC0), vía https://github.com/Tiddybub/2d-assets

El sonido se sintetiza en el navegador con Web Audio.
