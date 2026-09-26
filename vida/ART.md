# Arte, animación y sonido — Una Vida en 20 Minutos

Estilo aprobado: **ilustración pintada de libro infantil** (gouache y lápiz de color, contornos marrones limpios,
paleta cálida y nostálgica, grano de papel). Todo se generó con **Higgsfield** usando siempre imágenes de
referencia para mantener la coherencia. El registro de cada trabajo (nombre → job → URL original) está en
`tools/jobs.tsv`; `tools/pull.py` vuelve a descargar los originales en `raw/` (carpeta ignorada por git).

Coste aproximado hasta ahora: ~380 créditos (Nano Banana 2 ≈ 1,5 por imagen; Kling 3.0 std 3 s sin sonido ≈ 3,75 por clip).

## Cadena de producción

| Paso | Herramienta | Salida |
|---|---|---|
| Pruebas de estilo (A plastilina, **B pintado**, C pixel) | `nano_banana_2` | `art_tests/` |
| Láminas maestras: Ramón en 5 edades y familia | `nano_banana_2` + referencia `B_pintado_ramon` | `raw/sheet_*.png` |
| Perfiles para animar (fondo verde #00FF00) | `nano_banana_2` + recorte de la lámina maestra | `raw/side_*.png` |
| Ciclos de andar | `kling3_0` (std, 3 s, sin sonido, **mismo fotograma inicial y final**) | `raw/vid_*.mp4` |
| Hoja de sprites | `tools/sheet.py` (croma, periodo del ciclo, 16 fotogramas) | `assets/chars/*.webp/.json` |
| Objetos y obstáculos (láminas 4×4 en verde) | `nano_banana_2` | `tools/items.py` → `assets/items/` |
| Fondos panorámicos por etapa (21:9) | `nano_banana_2`, luego reparación de la unión | `tools/bg.py` → `assets/bg/` |
| Viñetas de las cartas (16:9 → 2:1) | `nano_banana_2` + Ramón en su edad (+ lámina de familia) | `tools/vignettes.py`, `tools/ui.py` → `assets/ev/` |
| Logo | `nano_banana_pro` (mejor texto) en verde | `assets/ui/logo.webp` |
| Lápida final, portada | `nano_banana_2` | `assets/bg/tomb.webp`, `assets/bg/title.webp` |
| Música | síntesis propia (`tools/music.py`, numpy) | `assets/audio/music_*.mp3` |

Referencias subidas a Higgsfield (media_id) que se reutilizan en los prompts:

| Referencia | media_id |
|---|---|
| Ramón 7 años (recorte de la lámina) | `c3760cd5-7f4c-40be-97fb-b9e3f1238a70` |
| Ramón 16 años | `b6f189cc-956d-4ad6-83cd-6cc9c5d29626` |
| Ramón 30 años | `f6dd23e6-ba14-4b8f-90de-347d24c14cf1` |
| Ramón 50 años | `4f8c085b-448c-46c2-877d-c7d3bae81d49` |
| Ramón 80 años | `ccaa5e90-a81f-4ee0-89ae-55fb91b39d45` |
| Lámina de familia (job) | `c35360f0-998c-490d-827d-7bec48a2a164` |
| Lámina de Ramón (job) | `750ae631-92d8-4ca5-b774-c3efa849b564` |
| Prueba de estilo aprobada (job) | `c40d8e29-9af3-43ac-9340-86a2a7c5ad7f` |
| Parque pintado (job, referencia de fondos) | `68795ba1-03dc-49a7-bc93-a73d5119665b` |

## Personajes (descripción canónica)

- **Ramón** — siempre la misma nariz grande, redonda y sonrosada, cara redonda, pelo castaño.
  - 7 años: pelo castaño revuelto, sonrisa mellada, camiseta verde lima, pantalón corto azul, zapatillas rojas.
  - 16 años: flequillo largo, pecas, sudadera rosa, cascos al cuello, vaqueros, zapatillas blancas.
  - 30 años: pelo corto, bigote castaño, camisa azul remangada, pantalón gris, zapatos marrones.
  - 50 años: algo rechoncho, entradas canosas, bigote gris, gafas redondas, chaleco morado sobre camisa lila.
  - 80 años: encorvado, calvo con mechones blancos, gran bigote blanco, gafas redondas, rebeca beige, bastón.
- **Lucía** — ~30: pelo largo ondulado caoba, vestido verde oliva, rebeca mostaza. ~70: moño plateado, rebeca verde, gafas con cadena.
- **Marga** — ~30: pelo negro rizado corto, gafas rojas redondas, camiseta de rayas mostaza, falda turquesa, zapatillas blancas.
- **Alba** (hija) — 6 años: dos coletas, peto naranja, camiseta amarilla. 28 años: melena corta, chaqueta naranja.
- **Tornillo** (perro) — mestizo pequeño y desgreñado, canela y blanco, una oreja caída y otra de pie, collar rojo.

## Segunda tanda (misma estética y edades)

Para que todos los personajes compartan estilo se pasa **siempre** la lámina de Ramón (`750ae631…`) como segunda
referencia, además de la del propio personaje, y se pide «same line thickness, same simple rounded face shape».

| Personaje | Edades con animación |
|---|---|
| Ramón | bebé (0–3), niño, adolescente, adulto, maduro, anciano + **salto** de cada edad (`*_jump`) |
| Lucía / Marga | ~30, ~50 y ~70 (`lucia`, `lucia_mid`, `lucia_old`; `marga`, `marga_mid`, `marga_old`) |
| Alba | niña, adolescente, adulta y ~45 (`alba`, `alba_teen`, `alba_adult`, `alba_mid`) |
| Tornillo | cachorro, adulto y viejo (`dog_puppy`, `dog`, `dog_old`) |
| Vecinos del fondo | abuela con carrito, oficinista, niña con globo, corredor (`npc_*`), generados por parejas y separados con `sheet.py --xr` |

- **Saltos**: Kling con el perfil como primer y último fotograma y «crouches, then does one big jump… lands back in exactly the same
  spot». `tools/jump.py` detecta el despegue y el aterrizaje, alinea los pies (la altura la pone la física) y guarda en el JSON
  los fotogramas en el aire (`air0`, `air1`) y la altura de referencia (`ref`).
- **Objetos de minijuegos** (`items_mini`): canasta, balón, coche, tarta grande, vela, ramo, pez, corcho, mariposa, pájaro,
  hoja, pétalo, marco de foto, cometa, sonajero y barca.

## Plantillas de prompt

**Lámina maestra** (21:9, 2k, referencia = prueba aprobada):
> Character model sheet in exactly the same hand-painted storybook style as the reference image (gouache and colored pencil,
> visible brush strokes and paper grain, warm nostalgic palette, gentle clean brown outlines). The same original character Ramón
> shown at five ages standing in a row… [descripciones de arriba] …No text, no labels, no numbers.

**Perfil para animar** (3:4, referencia = recorte de su edad):
> The exact same character as the reference image ([descripción]), same hand-painted storybook gouache and colored pencil style
> with clean brown outlines, now shown in strict side profile view facing right, full body head to toe, mid-stride walking pose.
> Isolated on a perfectly flat solid pure green (#00FF00) background, no shadow, no ground, no paper texture on the background,
> character fully inside the frame with margin. No text.

**Ciclo de andar** (Kling 3.0, start_image = end_image = el perfil):
> 2D hand-painted cartoon animation. The [boy/man/woman…] walks in place with a [cheerful bouncy / brisk / slow shuffling…] walk
> cycle, like on a treadmill: legs step and arms swing naturally, the body stays in exactly the same spot in the center of the
> frame, facing right in side profile. Locked static camera, no camera movement, no zoom. The background stays a perfectly flat
> solid pure green, no shadows, no ground. Smooth seamless looping walk cycle.

(Si el MCP sugiere el preset «IN THE DARK», hay que rechazarlo con `declined_preset_id`.)

**Fondo de etapa** (21:9, 2k, referencia = parque pintado):
> Wide side-scrolling game background panorama, same hand-painted storybook gouache and colored pencil style as the reference,
> flat side view (no perspective), horizontally seamless tileable composition. [Etapa…]. The bottom 18% of the image is a flat,
> uniform [suelo] running the full width (the walking ground), with nothing standing on it. Empty scene, no people, no text.

Etapas: infancia (barrio soleado con parque y colegio), adolescencia (calle al atardecer rosa con instituto, cancha, quiosco, cine),
vida adulta (centro de ciudad nublado, oficinas, banco, café, metro, grúas), madurez (barrio residencial en otoño, vallas blancas,
limonero, huerto), vejez (paseo marítimo al atardecer, faro, templete, bancos, hojas).

**Reparación de la unión del bucle**: se desplaza la imagen media anchura (`np.roll`) para que la unión quede en el centro, se sube
y se pide: «Edit this exact image. There is a hard vertical seam in the exact middle… Repaint only the central area so the scene
flows naturally… Keep the left third and right third of the image completely unchanged». `tools/bg.py` pega solo la franja
central repintada, con bordes difuminados, así que los extremos casan al píxel.

**Láminas de objetos** (1:1, 2k, fondo verde): «Game item sprite sheet in exactly the same hand-painted storybook gouache… A 4 by 4
grid of 16 separate objects, each centered in its own cell… wide empty gaps… Background: perfectly flat solid pure green (#00FF00),
no shadows, no texture, no grid lines, no text». Los nombres por celda están en `tools/items.py`.

**Viñetas de cartas**: prefijo común en `tools/vignettes.py` (`STYLE`) + escena de cada evento. Si una falla (a veces filtran
escenas con niños en pijama o médicos), basta con reformularla.

## Música y efectos

Los modelos de música y efectos de Higgsfield (`sonilo_music`, `mirelo_text_to_audio`) solo se permiten dentro de su propio
generador de juegos web, así que la música es **original y sintetizada** en `tools/music.py`: un tema en bucle por etapa
(caja de música, guitarra punteada, piano y bajo andante, guitarra cálida con campanitas, vals de acordeón) y otro para el epitafio.
Los efectos se sintetizan en tiempo real (WebAudio en la versión HTML).

## Fuentes

- Chewy (Font Diner) — Apache License 2.0.
- Patrick Hand (Patrick Wagesreiter) — SIL Open Font License 1.1.
Ambas permiten uso comercial y se distribuyen dentro del juego (`assets/fonts/`).
