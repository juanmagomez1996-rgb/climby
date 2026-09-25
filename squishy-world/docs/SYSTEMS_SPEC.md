# SYSTEMS_SPEC — Squishy World (todo lo que hay que portar)

Todas las cifras salen del prototipo (`reference/src-js/`). Posiciones exactas del mundo: `Config/WorldLayout.luau`. Unidades: las del prototipo
(1 unidad ≈ 1 stud; un squishy mide ~2). Tiempos en segundos. `damp(a,b,k,dt) = lerp(a,b,1-exp(-k·dt))`.

---

## 1. Bucle principal del juego

Elegir molde → elegir relleno → **llenar** (mantener y soltar) → **revelación** (rareza) →
guardar/vender → equipar compañero → **apachurrar** todo → ganar monedas/XP → mejorar máquina y
comprar rellenos/moldes → repetir. Social: ver, apachurrar e intercambiar con otros jugadores.

Estado inicial (`GameConfig.START`): 500 monedas, nivel 1, 20 de espacio, molde viral `butter` gratis.

## 2. Progresión

- `xpNeed(lvl) = 50 + (lvl − 1) · 30`. Al subir se puede subir varios niveles seguidos.
- XP: +1 por cada llenado; +`Rarities[i].xp` al revelar (5/10/25/80/250/1000);
  +2 cada 15 apachurrones; +4 al quitar toda la cera en el mundo, +5 en el Estudio.
- Moldes normales se desbloquean por nivel (`Species.unlockLevel`: Rana 3, Conejo 5, Blob 8).
- Moldes virales (`Species.famous`) se **compran** en la Tienda (`price`); `butter` gratis.
- Máquinas: 01 nivel 1, 02 nivel 5 (+15% suerte), 03 nivel 10 (+30% suerte, mutaciones ×1.8).
- Espacio: `Upgrades.storage.caps[nivelUpgrade]` = 20, 30, 50, 75, 100, 150.

## 3. Llenado (máquina)

- Tiempo base 3.2 s: `time = 3.2 / (1 + 0.2·(fillSpeed − 1))`.
- Mientras se mantiene: `p += dt / time · (1 + p · 0.35)` (acelera al final).
- Al soltar: si `p < 0.35` → "Sigue manteniendo…" (no cuenta).
  `p < 0.80` = **under** ("Le faltó"), `0.80–0.90` = **perfect** ("¡PERFECTO!"), `> 0.90` = **over** ("Se pasó").
  Si `p ≥ 1.16` → **¡POP!** se revienta y se pierde.
- Procesado 2.1 s → revelación. Relleno Misterio cuesta 100 por uso.
- Referencia (velocidad 1): la ventana PERFECTO va de **2.25 s a 2.49 s** de mantener (lo calcula `Logic/SelfTest`).

## 4. Suerte, rareza, variante, mutación, valor

```
L = upgrades.luck·0.06 + machine.luck + filling.luck + {perfect:+0.25, under:−0.15, over:−0.10}; L = max(0, L)
peso[r] = r.p · (1 + L · LUCK_TIER_BOOST[tier(r)]) · (r = secret y filling.secretX ? secretX : 1)
LUCK_TIER_BOOST = {0, 0.5, 1, 1.5, 2, 2.5}   -- Común..Secreto
```
- Probabilidades base: Común .65, Poco común .22, Raro .08, Épico .035, Legendario .014, Secreto .001.
- **Variante**: si el molde es viral y salió Común → `original`. Si no: del pool de esa rareza; si el
  relleno tiene `bias` y hay coincidencias, 55% de elegir entre las favorecidas.
- **Mutación**: pesos `normal = p`, otras `p · machine.mutX · filling.mut[id]`.
  Brillante ×2 valor, Gigante ×1.5 (tamaño 1.3), Mini ×1.3 (tamaño 0.7).
- `size = random(0.95, 1.08)`; cara aleatoria (happy ×3, wink, sleepy, surprised).
- `value = round(species.baseValue · rarity.mult · mutation.mult · size)`.
- **Nombre**: `Especie + " " + Variante (se omite si es viral 'original') + " " + Mutación`.
  Ej.: "Gato Chicle Brillante", "Barra de Mantequilla", "Dona Glaseada Oro".
- **Índice**: 18 especies × sus variantes (normales: 28; virales: `original` + 20) = **413**.

## 5. Inventario, tienda, índice, misiones, intercambio

- Inventario: filtros por rareza y favoritos; equipar (compañero que te sigue), favorito, vender,
  "Vender repetidos" (conserva la mejor copia de cada especie|variante), botón 🖐️ Apachurrar.
- Tienda, 3 pestañas: **✨ Moldes Virales**, **Rellenos**, **Mejoras** (Velocidad, Suerte, Espacio;
  costos en `Upgrades`).
- Misiones: lista `Quests` en orden; al acabarla, infinitas:
  `goal = 5 + k·5` llenados, `reward = 500 + k·250`.
- Intercambio (con NPCs en el prototipo; en Roblox **también entre jugadores reales**):
  `ratio = valorMío / valorSuyo`. ≥ 1.15 "súper trato" (acepta), ≥ 0.8 "justo" (acepta), < 0.8 pide más.
  Oferta del NPC: busca un squishy de valor ≈ `valorMío · random(0.85, 1.35)` (60 intentos).

## 6. NPCs ("otros jugadores" simulados)

7 definidos en `NpcDefs` (casa, especie favorita, viral favorito, personalidad, frases).
- Pasean cerca de su casa, burbuja cada 7–15 s, se detienen si hablas con ellos o si les
  apachurras el squishy. Reaccionan con frases (`NPC_SQUISH_LINES` / `NPC_WAX_LINES` en game6.js).
- La mitad (índices pares) lleva su **viral favorito**; 1 de cada 3 lo lleva **encerado** (1–3 capas
  de colores al azar). Cuando le quitas toda la cera: dice una frase y a los 25 s le echa cera nueva.
- Chat con IA (ver arquitectura §8); si no hay IA → respuestas predefinidas (`scriptedReply` en game4.js).
- En Roblox los NPCs **se mantienen** (le dan vida al server vacío) y además hay jugadores reales.

## 7. FÍSICA DE ESPUMA v2 (el corazón del juego) — `game2b.js`

Todo en el **espacio local del squishy**. Por squishy: centro `C`, caja `size`, `ymin`, `ref = max(0.6, max(size)/2)`, `area` (suma de triángulos).
- `rise` (segundos de slow rise) = `species.rise` (virales) o 3.2, × `filling.riseMul` (× 1.15 si Gigante).
- `soft` = `species.soft` (virales) o 1, × `filling.softMul`.

**Fuentes** (una por dedo/pulgar/palma que aprieta): `{c, n, dir, r, max, depth, f, s, target, held, rate, kind}`.
- Hundir (`dent`): `r = ref·(0.30 + 0.10·soft)` (×1.1 Gigante), `max = min(ref·0.56·soft, minDim(size)·0.42)`.
- Estirar (`pull`): `r = ref·(0.36 + 0.08·soft)`, `max = ref·0.75·soft`.
- Mientras se sostiene (`dent`): `target += dt·max·(2.8·force·(1−target/max)^1.25 + 0.05)·stiff` (rigidez progresiva; `stiff` viene de la cera, 1 sin cera).
  `depth = damp(depth, target, rate or 14)`; al sostener, `f = 0.35·depth`, `s = 0.65·depth`.
- Al soltar, **recuperación en dos fases**: `tauS = max(0.15, rise/3)`, `tauF = 0.05 + rise·0.02`;
  `f −= f·min(1,dt/tauF)`, `s −= s·min(1,dt/tauS)`, `depth = f + s`. Se borra cuando `depth ≤ 0.002`.
  Rebote al soltar si estaba > 25% hundido: squash de `−0.1·(depth/max)·clamp(2.6/rise, 0.25, 1.3)`.
- **Arrastrar**: si el punto nuevo está a más de `0.42·r` del centro de la fuente, la vieja se suelta
  (queda subiendo) y nace otra con `depth·0.88` → **rastro de huellas**. Máximo 30 fuentes.

**Por vértice** (posición base `P`, dirección desde el centro `ĉ`):
```
para cada fuente s:  re = r·(0.8 + 0.45·min(1, depth/max)),  d² = |P − c|²,  si d² > 9·re² → ignorar
  g = smoothstep(clamp((ĉ·n + 0.2)/0.65, 0, 1))                      -- solo el lado que toca
  w = exp(−d²/re²)
  dent: desplaza n · (−depth·w + depth·0.18·(exp(−d²/(3.2·re²)) − w))·g   -- hundimiento + bordecito
  pull: desplaza dir · depth·w·g
volumen: vol = Σ(±)depth·re²·1.3 (pull resta 0.7) ; b0 = clamp(vol/area·1.9, −0.08·ref, 0.24·ref)
  inflado: + ĉ·b0·max(0, 1 − 1.4·dent − pull)  (y ×0.6)
palma (flat, ×0.62):  y = ymin + (y−ymin)(1−k);  xz ×(1 + k·0.62·sin(clamp(t/H)·0.9π + 0.15))
apretón 2 manos (pinch, ×0.62): x ×(1 − k(0.75+0.25·mid)), y ×(1 + 0.5k), z ×(1 + k(0.3+0.25·mid)), mid = sin(t/H·π)
torcer (twist): ángulo = twist·t (t = altura normalizada) alrededor del eje Y
piso: y = max(y, ymin)  (se desparrama en la mesa)
sombreado (color de vértice): 1 − clamp(0.4·dent − 0.12·pull + extras, …) en [0.52, 1.1]
```
Palma/apretón/torcer son "ejes" `{v, f, s, hold, target, rate}` con la misma recuperación de 2 fases.
Recalcular normales y **promediar las costuras** (vértices duplicados en la misma posición).

## 8. CERA DE VELA v2 — `game2c.js`

- Cada vertida = **una capa nueva encima** (hasta 6), de cualquier color (`WaxColors`; Arcoíris =
  pastel al azar por pedazo). Grosor por capa `0.04·ref`; la capa k se desplaza sobre la suma de
  las anteriores. Crece en `pourTime` (1.8 s), queda caliente y se enfría en 2.4 s (brillo → lechosa).
- Pedazos: Voronoi sobre la superficie, `K = clamp(area·15, 24, 64)` semillas por área con peso
  aleatorio 0.75–1.25 (bordes irregulares). Vecinos por aristas compartidas (por posición).
- **Una sola superficie de doble cara** (sin paredes ni contornos: al partirse no deja bordes).
- Estrés por pedazo: `st = Σ (0.25 + depth/max)·exp(−d²/(2r²))·(held?1:0.35)·(pull?1.3:1)`;
  global: palma ×0.35, apretón ×0.6, torcer ×0.5. **Exposición** = 0.22 si algún pedazo de una capa
  de afuera que lo tapa sigue pegado, si no 1.
  `integ −= st·dt·4.2·exp` y `−= global·dt·2.0·exp`.
- Etapas: `integ < 0.78` agrietado (se aparta 0.004·ref, **blanqueo** 14%), `< 0.4` suelto
  (0.02·ref, blanqueo 30%), `≤ 0` **se desprende**: vecinos −0.07 (cascada), sale volando con
  `v = normal·rand(1, 2.6)·s + up·rand(0.8, 2.4)·s`, gravedad `19.6·s`, rebote 0.26, fricción 0.7,
  giro aleatorio, se desvanece de 3 a 4.2 s. Máximo 160 pedazos vivos.
- Rigidez que siente el dedo: por cada capa que cubre el punto: sana ×0.2, agrietada ×0.45, suelta
  ×0.78 (mín 0.02); caliente ×0.7. Toque: `−(0.3·force·(1 − d²/R²) + 0.04)·exp`. Golpe (smash):
  `−(0.07 + 0.2·altura)·rand(0.6,1.4)·exp`.
- Sonido con presupuesto (un crack cada 35–65 ms): transiente seco agudo + cuerpo medio + golpe grave
  si es grande; más capas = más fuerte. "Tink" al caer. Vibración corta en móvil.
- Guardado (en squishies propios): `wax = { list = { {c = color, s = semilla, b = {ids rotos}}, … } }`.

## 9. Apachurrar en el mundo — manos que rodean el contorno (`game6.js`, `WorldPress`)

- Mantener clic sobre cualquier squishy (propio, de otro jugador, Vitrina, estatua) a < 34 studs.
- El dueño y su squishy **se detienen** mientras lo apachurras. Cámara de amasar:
  `dist = max(3.4, (h + w)·0.5·escala·2.3 + 1.2)·zoom`, altura `dist·0.55`, desde tu lado.
  **Arrastrar a los lados = girar alrededor** (`orb += dx·0.0055`, suavizado 5), **arriba/abajo = mover
  las manos por el borde**, rueda = zoom 0.65–1.7.
- **Silueta cada frame**: con los vértices YA deformados, proyectar al plano de cámara, 72 sectores
  angulares, el más lejano por sector. Camino de −35° a 215° cada 5°. Normal = 0.4·normal del vértice
  + 0.6·dirección radial. Curvatura = ángulo entre normales vecinas (±2).
- Ángulo de manos: `a = clamp(mid + amp·sin(0.55t − π/2) + usuario·amp, −25°, 62°)`; izquierda `π − a`, derecha `a`.
- Contacto: rayo diagonal desde tu lado `normalize(−0.65·n + 0.55·F)` → punto real. La palma
  empuja una fuente `dent` (force 0.6, rate 4) que viaja por el borde; objetivo
  `max·(0.5 + 0.16·sin(2.2t + fase))·rampa(1.2 s)·min(1, 0.3 + stiff)`. Apretón suave de las 2 manos (pinch 0.3).
- Mano: palma contra la superficie, pulgar hacia la cámara, dedos siguiendo el contorno; curvatura
  → dedos `0.2 + clamp(1.4·k, 0, 0.9)`. Escala `0.88·escalaSquishy`, separadas mínimo `1.0·escalaMano`,
  un poquito hacia la cámara (`−0.32·F`). Suavizado posición 7, rotación 5.5. Entran/salen suave.
- **Fantasma**: cualquier personaje entre la cámara y el objetivo (o a < 4.5 de la cámara) baja a
  opacidad 0.2 (suave, damp 10).

## 10. Modo apuntar (`Aim`)

Clic derecho sostenido o **Q**. Cámara al hombro (look desplazado 3.0 a la derecha, distancia 9),
jugador semitransparente (1 − 0.62·aimK). Retícula con imán: candidatos a < 34 studs, radio
proyectado + 120 px (22 px sin apuntar), puntaje `max(0, d − 0.6·rad) + 1.2·dist − 45 (si ya era
el objetivo) + 60 (estatua)`. Anillo rosado en el piso bajo el objetivo, etiqueta con nombre, dueño y
"🕯️ encerado". Ayuda de puntería: gira la cámara `yaw += diff·min(1, 2.2dt)` si |diff| < 0.5 rad.

## 11. Estudio Squish (F sobre un squishy)

Escena aparte (en Roblox: `ViewportFrame` a pantalla completa **o** una sala aislada con cámara
propia — ver arquitectura). Plato pastel, cámara orbital (clic derecho), rueda = zoom 4.2–11.
- Modos (1–4): 👆 Dedo (multitouch, rastro), 🤏 Estirar (dos deditos en pinza jalan), 🌀 Torcer
  (arrastrar horizontal: `twist = clamp(dx·0.006, −1.4, 1.4)`), 💥 Golpe (palmazo: flat 0.95 con rate 32
  por 0.12 s + sacudida de cámara + smash de cera; cooldown 0.18 s).
- Espacio = palma (mano desde arriba), Q = apretar con las 2 manos (manos a los lados).
- Cronómetro de slow rise: al soltar todo con `maxDepth > 0.08`, cuenta hasta `< 0.03`.
  ≥ 6 s "¡slow rise brutal! 🐢✨", ≥ 3.5 "¡bien slow! ✨", si no "rebotón 😄". Récord personal.
- Panel: Suavidad (●●●●○ = round(soft·3.3)), Slow rise, Relleno, Tipo viral, Apachurrones, Cera.
- 🕯️ Cera (C): colores, "Echar capa N encima", pila de capas, "Quitar cera". Vela que se inclina,
  chorro, gotitas, vapor al enfriar, aviso "¡La cera ya está dura!".
- El dedo sale de un **puño** (mano con pulgar y muñeca), cortico y gordito — nada de palitos.

## 12. Tour de bienvenida (`game7.js`)

Primera vez al darle Jugar (y con el botón 🎬 Tour). ~61.5 s, barras de cine, HUD oculto,
controles bloqueados, Esc/Enter/Espacio o "Saltar tour ⏭" saltan al aterrizaje.
- Cámara en **una sola curva Catmull-Rom (centrípeta)** de posición y otra de mirada, con 18 puntos
  clave (tiempos y coordenadas en `Tour.build()`), velocidad pareja con suavizado en cada punto.
- Tarjetas: título gigante SQUISHY WORLD → 1 Máquinas → 2 Vitrina Viral → 3 Tienda → 4 Colección →
  5 Otros jugadores → 6 Tus retos (vista de mapa con pines + panel de retos: misión actual, rarezas,
  meta nivel 10 / Mega Llenadora / Secreto / Índice, extra cera) → "Y este eres tú 👋" (el personaje saluda).
- Rutas brillantes con flechitas que avanzan en el piso desde la plaza hasta cada zona; anillo
  dorado en la Vitrina; en el mapa todas a la vez.
- **Aterrizaje sin salto**: los últimos 2.5 s se mezclan con la pose en vivo de la cámara normal
  (smoothstep); al terminar la cámara queda exactamente ahí (diferencia 0).

## 13. Mundo

- Plaza circular radio 30 con fuente (radio 10.8) y **estatua** gigante de squishy (escala 3.4).
- **Vitrina Viral**: los 13 virales en pedestales en anillo de radio 15.6 alrededor de la fuente,
  con placa de nombre; letrero "✨ Vitrina Viral ✨".
- Zonas (centro): Máquinas (0, 58), Colección (0, −58), Tienda (−58, 0), Plaza de Intercambio (58, 0).
  Caminos en cruz desde la plaza. Naturaleza Kenney alrededor. Radio del mundo 92.
- Máquinas con cúpula donde se ve el squishy llenándose; letrero de nivel requerido si está bloqueada.
- Colección: pedestales con tus mejores squishies + tablero "Índice Squishy".

## 14. Audio

Todo sintetizado en el prototipo (Web Audio). En Roblox: subir SFX equivalentes (squish suave,
crinkle, pop, sparkle, coins, levelup, crack de cera, tink, creak, squeak, chime) y un loop de
"espuma" cuyo volumen/tono sigue la velocidad del hundimiento (`foamSet(level, bright)`).
