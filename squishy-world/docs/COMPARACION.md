# COMPARACIÓN — Original (HTML) vs Roblox, cosa por cosa

Auditoría del 2026-09-25 contra `reference/src-js/` + `template.html` + capturas.
Regla: **todo igual al original, menos los personajes** (avatares de Roblox, y los brazos del avatar
en vez de las manitos). La monetización con Robux y el intercambio entre jugadores son **extras**.

Leyenda: ✅ igual · 🟡 distinto · ❌ falta · 🔁 reemplazado a propósito

## Resumen

| Área | Elementos revisados | ✅ | 🟡 | ❌ | Lo más grave |
|---|---|---|---|---|---|
| 1. Mundo y cámara | 94 | 3 | 45 | 46 | Mapa provisional (sin fábrica, tienda, arcos, árboles…); FOV 70 vs 58, caminar 16 vs 13, sin correr, con salto |
| 2. Interfaz | 125 | 11 | 55 | 63 | Íconos emoji en vez de los PNG; glifos en cuadrito (🪙 ✕ ★ ●); HUD tapado por Roblox; textos de secciones distintos |
| 3. Sistemas y reglas | 169 | 77 | 62 | 36 | Reglas OK; falta feedback de máquina, chat NPC, pedestales, tutorial completo, teclas (B/T/F/Q/Esc/Shift) |
| 4. Visual, física, audio | 206 | 35 | 61 | 130 | Squishies provisionales; sin espuma real, apuntar, Estudio, cera, tour; audio sin ids |
| **Total** | **594** | **126** | **223** | **275** | |

## Orden de trabajo propuesto

1. **Interfaz y controles** (lo que más se nota): glifos, HUD como el original (píldoras oscuras arriba
   a la derecha, íconos PNG), textos exactos, B/T/F/Q/Esc/Shift, cámara FOV 58 y zoom 7–24,
   caminar 13 / correr 22 / sin salto, prompts con los textos originales.
2. **Mundo 1:1**: reconstruir `game3.js` pieza por pieza con Parts (≈85 %) + importar la naturaleza
   Kenney; Vitrina con los 13 virales y estatua apachurrable; cielo, niebla y luces.
3. **Squishies de verdad**: importar los 18 GLB, caras (feliz/guiño/dormido/sorprendido), variantes
   con textura, efectos por rareza, revelación con fondos y partículas.
4. **Máquina con feedback** (cámara, sacudida, lámpara, líquido, chorro, POP) + audio completo.
5. **NPCs** (chat, reglas de paseo, cera) + pedestales + tutorial completo.
6. Fases 7–10: espuma con EditableMesh, apuntar, fantasma, Estudio, cera, tour.

---

# 01 — Mundo, escena, movimiento y cámara: prototipo vs Roblox

Fuentes: `reference/src-js/game3.js` (G3), `game4.js` (G4), `game5.js` (G5), `game1.js` (G1).
Roblox: `roblox/src/server/Services/WorldBuilder.luau` (WB), `shared/Config/WorldLayout.luau` (WL),
`client/Controllers/Tutorial.luau` (TUT), `server/Services/NpcService.luau` (NPC).
Unidades: 1 unidad del prototipo = 1 stud (WL:2). Medidas de altura reales sacadas del
`assets/world/mapa_completo.glb` (bbox por nodo).

Estado actual en Roblox: `SquishyWorld.rbxlx` **no trae `Workspace.Map`** (solo scripts), así que
siempre corre `buildPlaceholder()` (WB:81-180): ~40 Parts planos, sin texto 3D, sin decoración.

## Tabla

| # | Elemento | Original (qué es, números/colores exactos, archivo:línea) | Roblox ahora | Estado | Qué hacer |
|---|---|---|---|---|---|
| **ESCENA / RENDER** ||||||
| 1 | Cielo | Esfera r400, degradado vertical: arriba `#8fc8f0`, abajo `#fbe9f3`, `h = clamp(y·1.6+0.15)`; sin niebla (G3:16-23) | Skybox por defecto de Roblox (no se crea `Sky`) | ❌ | Crear `Sky` con 6 caras PNG generadas con la misma fórmula (subir 6 imágenes), `CelestialBodiesShown=false`, `StarCount=0` |
| 2 | Nubes | 14 grupos × 4 icosaedros low-poly (detalle 0) r 8–14, separados 11 en x; anillo r 170–240, altura 55–90, miran al centro; blanco `#ffffff`, emissive 0.35, flatShading (G3:25-30) | `Clouds` volumétricas de Terrain (Cover 0.55, Density 0.6, `#FFF5FA`) (WB:279-285) | 🟡 | Quitar `Clouds`. Subir 1 MeshPart icosaedro (20 caras) y clonarlo 56 veces con las mismas reglas (color blanco, Material SmoothPlastic, sin sombra) |
| 3 | Niebla | `THREE.Fog('#d8ecfa', 110, 230)` (G3:12) | `Atmosphere` Density 0.28, Haze 1.2, Color `#FFE1F0` (rosado), Decay `#BEAAE6` (WB:271-278) | 🟡 | Sin `Atmosphere` (anula la niebla clásica) → `Lighting.FogColor=#d8ecfa`, `FogStart=110`, `FogEnd=230` |
| 4 | Luz hemisférica | `HemisphereLight('#f4f0ff' cielo, '#a9b99a' suelo, 0.62)` (G3:32) | `Ambient (150,140,165)`, `OutdoorAmbient (190,180,200)` (WB:267-268) | 🟡 | `OutdoorAmbient ≈ #f4f0ff·0.62`, `Ambient` bajo; `EnvironmentDiffuseScale=0`, `EnvironmentSpecularScale=0` (three no tiene env map) |
| 5 | Luz ambiente | `AmbientLight('#ffffff', 0.08)` (G3:33) | incluida en Ambient | 🟡 | Sumarla al ambient de arriba |
| 6 | Sol | `DirectionalLight('#fff1e0', 0.85)` en (40,70,30) → elevación ≈54.5°, azimut desde +x/+z; sigue al jugador (G3:34-38, G4:183) | `ClockTime=14.5`, `Brightness=2.2` (WB:265-266), dirección arbitraria | 🟡 | `ColorShift_Top=#fff1e0`; calcular `ClockTime`+`GeographicLatitude` para que la dirección del sol sea normalize(40,70,30); ajustar `Brightness`/`ExposureCompensation` comparando con las capturas |
| 7 | Sombras | PCFSoft, mapa 2048, caja ±60, bias −0.0006 (G3:10,36-37) | Sombras por defecto | 🟡 | `Lighting.Technology=ShadowMap` (o Future), `ShadowSoftness≈0.2`, `GlobalShadows=true` |
| 8 | Materiales | `MeshStandardMaterial` roughness 0.85 por defecto, metalness 0, colores planos; sRGB (G3:42) | `SmoothPlastic` (WB:31) | ✅ | Mantener SmoothPlastic; “emissive” → subir un poco el color o `Neon` solo donde brilla (lámpara, rims) |
| 9 | Cámara near/far | near 0.3, far 500 (G3:13) | Roblox sin límite práctico | ✅ | — (la niebla oculta lo lejano) |
| **SUELO / PLAZA / CAMINOS** ||||||
| 10 | Suelo | Círculo **r260**, textura pasto 256² `#b6dd9a` + 900 motas 3px `rgba(150,205,120,.55)`/`rgba(200,235,170,.5)`, repeat 26×26 (≈20 studs por tile) (G3:152-155) | Cilindro **r92** `#A6DB8E` liso, sin textura (WB:85); fuera de r92 hay **vacío** | 🟡 | Cilindro r260 (1 Part, tamaño 520 OK) color `#b6dd9a` + `Texture` pasto (subir PNG) `StudsPerTile=20` |
| 11 | Baldosas de la plaza | Círculo r30 a y0.04, textura 256² `#eadfd2` con líneas `#d6c7b6` 6px cada 64px, repeat 10 → baldosa ≈1.5 studs (G3:158-161) | Cilindro r30 `#F3E3CC` liso (WB:86) | 🟡 | Color `#eadfd2` + `Texture` baldosas (subir PNG) `StudsPerTile=6` |
| 12 | Aro de la plaza | Anillo 29.5–31.5 `#e7b9d3` a y0.05 (G3:162) | No existe | ❌ | Cilindro r31.5 rosado debajo + baldosa r29.5 encima (simula el aro) |
| 13 | Caminos | 4 planos **12 × 40** con la textura de baldosas, centro a 0.52·zona (=30.16 del centro), van de r10 a r50, y0.03 (G3:164-166) | 2 barras **170 × 7** `#F4E6CF` que cruzan TODO el mapa (atraviesan la fuente) (WB:99-106) | 🟡 | 4 Parts 12×0.1×40 en (0,±30.16)/(±30.16,0), textura baldosas |
| 14 | Pisos de zona | Círculo **r26** baldosas en cada zona, y0.035 (G3:167) | Cilindro **r16** color de la zona (WB:110) | 🟡 | r26, textura baldosas color `#eadfd2` |
| 15 | Aro de zona | Anillo 25.4–26.6 color de zona (`#F7A7CD` Máq., `#B999E8` Col., `#F4D982` Tienda, `#8BC7E8` Interc.) (G3:168, 143-146) | Incluido como disco entero r16 | 🟡 | Cilindro r26.6 color zona + pad r25.4 encima |
| 16 | Límite del mundo | Clamp circular r92 del jugador (G3:82, G1:17) + cerca visual r94 | Nada: se puede caer al vacío en r92 | ❌ | Muro invisible (anillo de Parts `CanCollide`, Transparency 1) en r92 |
| 17 | Colisiones | Colisionadores 2D (círculos/cajas) por objeto; decoración (flores/arbustos) sin colisión (G3:63-83) | Colisión física de cada Part | 🟡 | Decoración `CanCollide=false`; agregar Parts invisibles con los mismos radios (fuente 10.8, bancas 2.6, máquinas 5.2 + caja 3.6, etc.) |
| **CENTRO: FUENTE / ESTATUA / VITRINA** ||||||
| 18 | Taza de la fuente | Cilindro r_top 10 / r_bot 10.6, alto 1.6, y0.8, `#f6f1ea` rough 0.8, 40 lados (G3:188-189) | Cilindro r10.8 alto 1.2 blanco (WB:88) | 🟡 | Cono truncado 10→10.6 (MeshPart) o cilindro r10.3; alto 1.6, `#f6f1ea` |
| 19 | Agua | Disco r9.2 a y1.45, `#9fd8f2`, rough 0.15, opacidad 0.85 (G3:190-191) | Disco r10 alto 0.2 a y1.05 `#8BC7E8` Glass (WB:89) | 🟡 | r9.2, y1.45, `#9fd8f2`, Transparency 0.15, SmoothPlastic/Glass |
| 20 | Columna central | Cono truncado r3.2/3.8 alto 4.5 a y3.4 `#f7c6dc` (G3:192) | No existe | ❌ | MeshPart cono truncado o cilindro r3.5 |
| 21 | Plato superior | Cilindro r4.2 alto 0.7 a y5.9 `#f6f1ea` (G3:193) | No existe | ❌ | Part cilindro |
| 22 | Chorros de agua | 8 esferas r0.35 `#c6ecff` opac. 0.75; parábola: radio 4.3+ph·3.5, y 1.6+sin(ph·π)·4, ph=(t·0.8+i/8)%1 (G3:201-202) | No existe | ❌ | 8 Parts bola animadas en cliente (RenderStepped) con la misma fórmula |
| 23 | Estatua | Squishy gato, variante pink, rareza rare, cara happy, **escala 3.4** en (0,6.25,0); mide 9.8 ancho × 5.9 alto (cima y12.2); se apachurra (G3:196-198) | Bola 7×6×7 `#FFE38F` amarilla, no apachurrable (WB:91-97) | ❌ | Construirla con `SquishyFactory` (cat/pink) × 3.4 y registrarla como apachurrable (pitch 0.6) |
| 24 | Logo flotante | Plano 22×5.5 “Squishy World” blanco (Lilita 120) a y24, flota ±0.5·sin(t), siempre mira a la cámara + sombra `#E57AAE` 22.8×6.2 desplazada (0.25,−0.25) (G3:204-208) | No existe en 3D (solo HUD 2D) | ❌ | `BillboardGui` con tamaño en studs (UDim2 22×5.5 scale) a y24 + texto sombra rosado |
| 25 | Bancas de la plaza | 4 bancas (i impar de 8: 45°,135°,225°,315°) a r22, rot a+π. Asiento 6×0.5×1.8 `#e8b98a` y1.6; respaldo 6×1.6×0.4 y2.8 z−0.8; patas 0.5×1.6×1.6 `#8a7fa8` x±2.5 y0.8; col. r2.6 (G3:210-218) | No existen | ❌ | 4 Parts cada una (procedural exacto) |
| 26 | Macetas del aro | 8 `pot_large` alto 2.2 + `plant_bushDetailed` alto 2.4 a y1.7, en r30, ángulo i·45°+22.5°; col. r1.5 (G3:364) | No existen | ❌ | Modelos Kenney (GLB) |
| 27 | Pedestales Vitrina | 13 en anillo **r15.6**, ángulo (i+0.5)/13·2π; cono truncado r1.25/1.4 alto 1.3 `#FFFCF8` + aro r1.35 alto 0.18 color cíclico `#F7A7CD,#8BC7E8,#F4D982,#B999E8,#9CE0CA,#F8B27C` a y1.36; col. r1.5 (G3:373-381) | Cilindro r1.3 alto 1.4 blanco, sin aro de color (WB:175-177) | 🟡 | Agregar aro de color, radios exactos |
| 28 | Placas de nombre Vitrina | Plano 2.3×0.62 en local (0,0.7,1.33), fondo `#FFFCF8`, borde color del pedestal, Nunito 900 38px (30 si >16 letras) (G3:379-380) | No existen | ❌ | `SurfaceGui` en Part delgado con TextLabel + UIStroke |
| 29 | Squishies de la Vitrina | 13 virales ‘original’ en y1.45, escala min(1.05, 2.4/max(h, w·0.9)), rotY=a; apachurrables (G3:382-385) | No se colocan (solo las coords en WL:26-40) | ❌ | Instanciarlos con SquishyFactory en WL.vitrina y registrarlos como apachurrables |
| 30 | Letrero “✨ Vitrina Viral ✨” | Plano 9×1.8 en (0,2.55,10.75) mirando +z, fondo `#FFFCF8`, borde `#F7A7CD`, Lilita 64 (G3:388-389) | No existe | ❌ | Part + SurfaceGui |
| **ARCOS DE ENTRADA (×4)** ||||||
| 31 | Pilares | En cada zona a 32 del centro, rotados hacia la zona; 2 cilindros r0.9/1.1 alto 13 color de zona a x±8, y6.5; bases r1.6 alto 0.8 blanco; col. r1.3 (G3:174-179) | No existen | ❌ | Procedural (cono truncado leve o cilindro r1.0) |
| 32 | Viga + letrero | Caja 19×2.6×1.6 blanco a y13.3; letrero 15×2.4 en ambas caras (z±0.82) con el nombre de la zona, Lilita 92, fondo color zona, texto `#282D3A` (G3:180-183) | `BillboardGui` flotante a y13 sobre el disco (WB:111), texto blanco con borde | 🟡 | Viga + 2 SurfaceGui; quitar billboards |
| **ZONA MÁQUINAS (centro 0,58)** ||||||
| 33 | Pared del fondo | Caja 64×16×2 `#fff5fa` en (0,8,80) (G3:263-264) | No existe | ❌ | Part |
| 34 | Paredes laterales | 2 cajas 2×16×26 en x±31, z68 (G3:265) | No existen | ❌ | Parts |
| 35 | Techo en zigzag | 5 lamas 12.4×1×28 en x −24..24 (paso 12), y21, z67, alternando `#ffffff`/`#F7A7CD`, rotZ ∓0.18 (G3:267) | No existe | ❌ | Parts rotados |
| 36 | Columnas | 4 cilindros r0.8 alto 21 `#B999E8` en x±30, z55 y z79 (G3:268) | No existen | ❌ | Parts |
| 37 | Tuberías | 4 cilindros r0.6 largo 60 horizontales, y 4/6.6/9.2/11.8, z78.6, colores `#8BC7E8,#9CE0CA,#F4D982,#B999E8` (G3:270) | No existen | ❌ | Parts |
| 38 | Banda transportadora + cajas | Caja 40×1.5×4 `#3a4154` en (0,0.75,74); 6 cubos 2.4 (rosa/amarillo/menta) a y2.7 que avanzan +2 st/s y vuelven de x+19 a −19 (G3:272-273) | No existen | ❌ | Parts + animación cliente |
| 39 | Máquina: base | Ubicación m1 (0,0,60), m2 (−17,0,62), m3 (17,0,62). Aro r4.6/5 alto 1.2 blanco y0.6; cuerpo r4/4.3 alto 4.5 color máquina (`#F7A7CD`,`#8BC7E8`,`#B999E8`) y3.4; aro r4.3 alto 0.5 blanco y5.8 (G3:224-226, G1:136-140) | Caja **6×4.2×5** color máquina (WB:123-128) | 🟡 | Cilindros exactos (base cónica leve → MeshPart o GLB) |
| 40 | Máquina: cúpula | Semiesfera r3.7 `#e8f6ff` opac. 0.28 a y6.05 (G3:228-229) | Bola entera 4.2 (r2.1) blanca Transp. 0.7 Glass (WB:129-138) | 🟡 | Bola r3.7 centrada en y6.05: la mitad inferior queda escondida dentro del cuerpo (r4.3) → se ve igual que la semiesfera |
| 41 | Máquina: torre + tanque | Caja 3.4×12×3.4 color máquina en local (0,6,+5.2); tubo abierto r1.6 alto 6 transp. 0.35 a y15.2; líquido r1.45 `#F7A7CD` a y12.7 (animado); aros r1.8 alto 0.5 a y12.1 y y18.4 (G3:231-235) | No existe → la máquina mide **8** en vez de **19.6** | ❌ | Parts (el tubo abierto ≈ cilindro Transparency 0.65) |
| 42 | Máquina: brazo + boquilla + chorro | Brazo 1×1×5.4 `#3a4154` en (0,12.4,2.3); boquilla cono r0.5→0.25 alto 2.8 en (0,10.6,0); chorro r0.22 `#F7A7CD` emissive (oculto hasta llenar) (G3:237-240) | No existe | ❌ | Brazo Part; boquilla MeshPart cono; chorro Part cilindro |
| 43 | Máquina: lámpara | Esfera r0.7 blanca emissive `#ffe08a` 0.4 en (0,18.9,5.2) (G3:242-243) | No existe | ❌ | Bola + PointLight suave / Neon tenue |
| 44 | Máquina: botones | 3 cilindros r0.35 alto 0.3 `#FF7B8A,#F4D982,#9CE0CA` en x −1.1/0/1.1, y3.8, z−4.15 (G3:245) | No existen | ❌ | Parts |
| 45 | Máquina: placa | Plano 6×1.9 en (0,2.3,−4.35): nombre (Lilita 58) + subtítulo (Nunito 800 34), fondo `#FFFCF8` (G3:247-248) | `BillboardGui` flotante a y7.2 (WB:139) | 🟡 | SurfaceGui fijo en el frente |
| 46 | Máquina: letrero de bloqueo | Plano 6×2 fondo `#282D3A` texto blanco “🔒 Requiere nivel N” (Lilita 50) en (0,9,−0.5), solo m2/m3 (G3:250-254) | Lo maneja otro sistema/no está en el placeholder | 🟡 | SurfaceGui en (0,9,−0.5) de cada máquina bloqueada |
| 47 | Punto de interacción máquina | pos+(0,0,−5), radio 9+1=10 (G5:63) | Prompt en pos+(0,3,−3), `MaxActivationDistance` 12 (3D) (WB:257) | 🟡 | Anchor en (x,0.?,z−5) y distancia 10 |
| **ZONA COLECCIÓN (centro 0,−58)** ||||||
| 48 | Piso del pabellón | Cono truncado r22/22.5 alto 1 `#f0e9fb` en (0,0.5,−62) (G3:284) | No existe | ❌ | Cilindro r22.25 |
| 49 | Pared del fondo | Caja 46×14×2 `#efe6fb` en (0,7,−78) (G3:285) | No existe | ❌ | Part |
| 50 | Columnas Kenney | 6 `statue_column` alto 12 en x −20..20 (paso 8), z−76 (G3:286) | No existen | ❌ | GLB `decoracion_kenney/statue_column.glb` |
| 51 | Tablero del Índice | Plano 16×7 `#B999E8`, “Índice Squishy” (Lilita 80, blanco) + “Presiona E para abrir tu álbum” (Nunito 800 36) en (0,8,−76.9) pegado a la pared; interacción en (0,0,−72) radio 11 (G3:288-290, G5:65) | Caja 12×7×0.6 en (0,3.5,**−70**) + billboard “📖 Índice Squishy”; prompt (0,3,−67) (WB:159-165, 260) | 🟡 | Mover a (0,8,−76.9), 16×7, SurfaceGui con los 2 textos; prompt en (0,*,−72) |
| 52 | Pedestales de rareza | 6 en arco (a=(i−2.5)/5·2.2; x=13·sin a, z=−56−9·cos a); cono truncado blanco r2.2/2.6 alto 3.2 a y2.6; aro r2.3 alto 0.4 color rareza emissive 0.25 a y4.25; squishy en y4.45; col. r2.7 (G3:292-301) | Cilindro r1.6 alto 4.4 **todo del color de la rareza** (WB:150-158) | 🟡 | Blanco + aro de color, radios exactos |
| 53 | Etiquetas de rareza | Plano 3.4×0.9 a y2.2 frente al pedestal, fondo color rareza, texto blanco Lilita 66 (G3:296-297) | No existen | ❌ | SurfaceGui |
| 54 | Vitrinas de vidrio | Tubo abierto r2.1 alto 4.6 `#eef8ff` opac. 0.18 a y6.75 (G3:298-299) | No existen | ❌ | Cilindro Transparency 0.82, CanCollide false |
| **ZONA TIENDA (centro −58,0)** ||||||
| 55 | Mostrador | Grupo en (−64,0,0) rotY 90°: caja 22×4×5 **`#9CE0CA`** (menta) → largo sobre z; tapa 23×0.6×6 blanca a y4.3 (G3:309-311) | Caja 4×3×10 **`#F4D982`** en (−60,1.5,0) (WB:142-147) | 🟡 | Tamaño/color/posición exactos |
| 56 | Pared trasera | 22×14×1.5 `#fff8e6` → mundo (−70,7,0) (G3:312) | No existe | ❌ | Part |
| 57 | Postes | 2 cilindros r0.5 alto 13 blancos → mundo (−65.8,6.5,±10.5) (G3:313) | No existen | ❌ | Parts |
| 58 | Toldo a rayas | Caja 24×0.5×8 `#F4D982`, cara superior con 8 franjas `#F4D982`/`#ffffff`; local (0,13.3,−1.6), rotX 0.22 (G3:315-317) | No existe | ❌ | 8 Parts de franjas (o Texture) inclinados |
| 59 | Letrero tienda | Plano 12×3 “Rellenos, Moldes y Mejoras” Lilita 50, fondo `#FFFCF8` borde `#F4D982`, → mundo (−67,16,0) mirando a la plaza (G3:318-319) | Billboard “🛒 Tienda” (WB:148) | 🟡 | SurfaceGui con el texto exacto |
| 60 | Estantes + frascos | 3 repisas 18×0.4×1.4 `#e8b98a` a y5.8/8.4/11 (mundo x−69); 7 frascos por repisa r0.55 alto 1.6 color del relleno `FILLINGS[(i+r·4)%n]` + tapa r0.6 alto 0.3 blanca (G3:321) | No existen | ❌ | Procedural con los colores de `Fillings.luau` |
| 61 | Leña Kenney | `log_stack` alto 2.6 en (−54,0,16) rot 0.4; col. r2.2 (G3:365) | No existe | ❌ | GLB |
| 62 | Punto de la tienda | (−60,0,0) radio 9 (G3:323, G5:64) | Prompt en (−57.5,3,0) dist 12 (WB:259) | 🟡 | (−60,*,0), dist 9 |
| **ZONA INTERCAMBIO (centro 58,0)** ||||||
| 63 | Tablero | Plano 14×5 `#8BC7E8`, “Intercambios” (Lilita 80) + “Habla con los jugadores: [E]” (Nunito 40), blanco, en (77,7,0) mirando a −x; 2 postes r0.5 alto 9 en (77.2,4.5,±6.5) (G3:330-333) | Caja 0.6×6×10 en (**66**,3,0) + billboard “🤝 Plaza de Intercambio” (WB:167-173) | 🟡 | Posición/tamaño/textos exactos |
| 64 | Interacción del tablero | **No existe** en el original (solo NPCs, máquinas, tienda, índice) (G5:60-67) | Prompt extra “Intercambiar” en (64,3,0) (WB:261) | 🟡 | Quitarlo para igualar (o anotarlo como desviación) |
| 65 | Mesas de intercambio | 4 en (52,−10),(52,10),(66,−12),(66,12): tapa r2.4 alto 0.4 blanca y3; pata r0.4/0.6 alto 3 `#8BC7E8`; col. r2.6 (G3:335-339) | No existen | ❌ | Parts |
| 66 | Sombrillas | Cono r4.5 alto 2 **8 lados** a y9.5, color al azar de `#F7A7CD,#8BC7E8,#F4D982,#9CE0CA`; palo r0.18 alto 7 blanco y6.2 (G3:337-338) | No existen | ❌ | MeshPart cono octogonal (o GLB `zona_trading`) |
| 67 | Bancas intercambio | 2 bancas en (72,−18) rot 0.2π y (72,18) rot 0.8π (G3:341) | No existen | ❌ | Igual que fila 25 |
| **NATURALEZA (Kenney)** ||||||
| 68 | Anillo de árboles | 46 árboles (`tree_default/oak/fat/detailed` cíclico) a r 98–120, alto 14–23, `seeded(42)` (G3:349-352) | No existen | ❌ | GLB `zona_naturaleza.glb` (posiciones ya horneadas) |
| 69 | Cerca | 60 `fence_simple` alto 2.6 en r94, escala x·1.9 (G3:354) | No existe | ❌ | GLB |
| 70 | Árboles entre zonas | 4 diagonales × 3 árboles a d 44/59/74 ±3, alto 13–19, col. r1.4 (G3:356-358) | No existen | ❌ | GLB + colisionador r1.4 |
| 71 | Arbustos | 4×7 `plant_bushLarge/Detailed` alto 2.6–4.2, d 36–81 (G3:359) | No existen | ❌ | GLB, CanCollide false |
| 72 | Flores | 4×10 `flower_red/yellow/purpleA` alto 1.4–2.0, d 33–83 (G3:360) | No existen | ❌ | GLB, CanCollide false |
| 73 | Rocas | 4 `rock_largeA` alto 4 a d70 (ángulo diagonal +0.12), col. r3 (G3:361) | No existen | ❌ | GLB |
| 74 | Letrero Kenney | `sign` alto 4 en (18,0,26) rot 0.8π (G3:366) | No existe | ❌ | GLB |
| **FLECHA GUÍA** ||||||
| 75 | Chevrón 3D | Cono r1.4 alto 2.6 **4 lados** `#FF7BB5` invertido, gira 2 rad/s, sube/baja ±0.8; objetivo: máquina m1 y13, tienda y9, intercambio (58,10,0), índice (0,12,−72) (G5:34-44,52) | No existe; el objetivo es el **centro de la zona** (TUT:16-23) | ❌ | MeshPart pirámide + mismos objetivos |
| 76 | Flecha en el piso | Cono 3 lados r0.7 alto 2.2 opac. 0.85 a 4.2 delante del jugador (pulsa ±0.4), visible si d>14; se apaga a d<12 salvo máquinas (G5:36-37,47-54) | `Beam` con chispitas del jugador al centro de la zona, se apaga a d<14 (TUT:27-80) | 🟡 | Reemplazar Beam por la flechita triangular + reglas de visibilidad exactas |
| **JUGADOR / CÁMARA** ||||||
| 77 | Tamaño del jugador | Kenney Blocky × `PLAYER.scale 2` = **5.4 alto**, 3.2 ancho (G1:15, G3:115) | Avatar Roblox (R15 ≈5.2–5.5; Rthro hasta ~7) | 🟡 (intencional) | Game Settings → Avatar → escala fija (Height 1.0, sin Rthro alto) para que todos midan ≈5.3 |
| 78 | Velocidad caminar | `walk 13` (G1:15, G4:146) | `WalkSpeed` por defecto **16** (no se toca) | 🟡 | `Humanoid.WalkSpeed = 13` |
| 79 | Correr | `Shift` → `run 22`, anima sprint (G4:145-146) | No existe | ❌ | Controlador cliente: LeftShift → WalkSpeed 22 |
| 80 | Salto | **No hay salto** (espacio solo sirve en la máquina) (G4:91-94) | Salto por defecto (JumpHeight 7.2) → se puede subir a la fuente/estatua | 🟡 | `StarterPlayer.CharacterJumpHeight = 0` (o `JumpPower 0`) |
| 81 | Giro del personaje | Giro suavizado `turn 12` hacia la dirección de avance (G4:150-152) | AutoRotate de Roblox (instantáneo) | 🟡 | Aceptable; opcional suavizar |
| 82 | Radio colisión jugador | 1.3 (G1:15) | Cápsula Humanoid ≈1 de radio | ✅ | — |
| 83 | FOV | **58°** vertical (G3:13) | **70°** (default) | 🟡 | `Camera.FieldOfView = 58` |
| 84 | Distancia cámara | inicio **14**, rueda 7–24 (`deltaY·0.01`) (G1:16, G4:128) | inicio 12.5, zoom **0.5–128** | 🟡 | `CameraMinZoomDistance=7`, `CameraMaxZoomDistance=24`, arrancar en 14 |
| 85 | Altura de mira | Mira a pies + **5.2** (G1:16, G4:169) | Mira a la cabeza (~+4.5) | 🟡 | Cámara propia o `Humanoid.CameraOffset=(0,~0.7,0)` |
| 86 | Pitch | inicio **0.28 rad (16°)**, rango −0.25…1.05 rad (−14°…60°); nunca bajo y1.2 (G1:16, G4:171-173) | −80°…80° libres | 🟡 | Cámara Scriptable que porte `updateCamera` (G4:163-184) |
| 87 | Sensibilidad / teclas | 0.0026 rad/px; ←/→ giran 2.2 rad/s (G1:16, G4:129,134-135) | Defaults de Roblox | 🟡 | Portar en la cámara propia |
| 88 | Suavizado | damp k=14 (overrides k=4/6) (G4:176-178) | Cámara rígida | 🟡 | Idem |
| 89 | Orientación al aparecer | Spawn (0,0,20), yaw 0 → mira a **+z (Máquinas)**, cámara en (0,9.1,6.5) (G4:83, 171-173) | SpawnLocation mira a −z (hacia la fuente) (WB:225-245) | 🟡 | Rotar el spawn 180° (`CFrame.Angles(0, math.pi, 0)`) |
| 90 | Cámara de máquina | Override pos (x+8.5, 11, z−17), look (x+4.2, 6.5, z) (G5:118) | No se mueve (desviación documentada) | 🟡 | Incluir en la cámara propia |
| 91 | Modo apuntar | Cámara se acerca a 9 y al hombro derecho 3 (G4:167-172) | Ver auditoría de apachurrar | 🟡 | Idem |
| **NPC / COMPAÑERO (solo lo que toca al mundo)** ||||||
| 92 | Velocidad NPC | 5 st/s (G4:257) | WalkSpeed 8 (NPC:119) | 🟡 | 5 |
| 93 | Área de paseo NPC | Aparecen ±10 del centro de la zona, pasean ±15 cada 3–8 s (G4:234,265) | Aparecen ±8, pasean ±10 cada 3–7 s (NPC:108,168-170) | 🟡 | Igualar números |
| 94 | Compañero | Al lado 3.2 + 1.6 atrás; salto 0.6 (caminar, freq 9) / 1.1 (correr, freq 13) (G4:211-219) | offset 3.2, salto 0.45 freq 9 (Companion:33-139) | 🟡 | Agregar 1.6 atrás y los saltos exactos |

## Por qué se ve pequeño

La escala absoluta **es la misma** (1 unidad = 1 stud; el Blocky mide 5.4 y un avatar ~5.3).
Lo que cambia es todo lo que rodea al personaje:

1. **Falta todo lo alto.** En el placeholder lo más alto mide 7–8 studs (bola-estatua, cajas de
   máquina de 4.2 + cúpula). En el original: máquinas **19.6**, arcos **14.6**, fábrica **22.6**,
   tienda **17.5**, pared de colección **14**, árboles **14–23**, logo a **24**. Sin referencias
   verticales el avatar parece gigante y el mapa un tapete.
2. **Cámara más abierta.** FOV 70 vs 58: tan(35°)/tan(29°) = 1.26 → todo se ve **~21% más chico**
   en pantalla. Además Roblox deja alejar la cámara hasta 128 (el original: máx. 24).
3. **Más rápido.** WalkSpeed 16 vs 13 (+23%), sin la diferencia caminar/correr → las distancias
   se recorren antes.
4. **Horizonte cortado.** Suelo r92 que termina en vacío, sin árboles ni cerca; el original tiene
   pasto hasta r260, anillo de 46 árboles a r98–120 y niebla desde 110.
5. **Piezas encogidas.** Pisos de zona r16 (orig. 26), caminos de 7 de ancho (orig. 12), pedestales
   r1.6 (orig. 2.2–2.6), mostrador 4×10 (orig. 22 de largo), tablero de intercambio a x66 (orig. 77).
6. **Letreros Billboard** de tamaño en píxeles: no escalan con la distancia como los letreros 3D
   del original, y rompen la lectura de tamaño.

**Recomendación:** NO reescalar el mundo (rompe WorldLayout y todos los números). Hacer:
`FieldOfView=58`, zoom 7–24 (inicio 14), mira a +5.2, pitch 0.28 con límites −0.25…1.05,
`WalkSpeed 13` + Shift 22, sin salto, escala de avatar fija ≈1.0, y construir el mapa completo
(con alturas reales). Con eso el tamaño percibido queda igual al del prototipo.

## Recomendación de construcción

**Se puede hacer ~85% procedural 1:1 con Parts** (todo lo de game3.js son cajas, cilindros,
esferas, planos con texto y conos), con estas excepciones:

- **Necesitan malla (GLB o MeshPart subido):**
  - Toda la naturaleza Kenney (46+12 árboles, 60 cercas, 28 arbustos, 40 flores, 4 rocas,
    8 macetas, leña, letrero) y las 6 `statue_column` → importar `assets/world/zona_naturaleza.glb`
    (posiciones de `seeded(42)` ya horneadas; portar el RNG sería otro camino) y
    `decoracion_kenney/statue_column.glb`.
  - Conos truncados (taza 10→10.6, columna 3.2→3.8, base/cuerpo de máquina, pedestales,
    Vitrina 1.25→1.4, pilares 0.9→1.1, pata de mesa, boquilla 0.5→0.25), conos de pocas caras
    (sombrillas 8 lados, chevrón 4, flecha 3) e icosaedro de nubes: Roblox no tiene esas formas.
    Opción A: subir 5–6 mallas unitarias (cono truncado por proporción, cono N lados, icosaedro)
    y escalarlas. Opción B: usar las piezas del GLB por zona. Opción C (rápida): cilindro con el
    radio promedio (diferencia <0.3 studs, casi invisible).
  - Estatua y squishies de la Vitrina: **no** del GLB (serían estáticos); generarlos con
    `SquishyFactory` para que se puedan apachurrar.
- **Texturas:** pasto y baldosas → subir 2 PNG (256²) y usar `Texture` con StudsPerTile 20 y 6.
  Toldo → 8 franjas. Letreros → `SurfaceGui` (Lilita One no está en Roblox: usar FredokaOne;
  Nunito sí existe).
- **Semiesfera de cúpula y tubos abiertos:** se resuelven con bola/cilindro transparentes
  (la mitad inferior queda oculta dentro del cuerpo).

**Camino más corto y fiel:** importar `assets/world/mapa_completo.glb` como `Workspace.Map`
(150k triángulos, 383 mallas, ninguna >8.1k tris → importable; coordenadas idénticas al
prototipo). Después, en `WorldBuilder`: (1) borrar/ocultar la estatua y los 13 squishies del GLB
y poner los de `SquishyFactory`; (2) decoración con `CanCollide=false` y agregar colisionadores
invisibles con los radios de game3.js; (3) muro invisible en r92; (4) revisar transparencias
(cúpulas 0.72, tanques 0.65, vitrinas 0.82, agua 0.15) y emisivos que el importador pierde;
(5) cielo/niebla/luces de las filas 1–7; (6) nubes (icosaedro). Si el importador da problemas
con textos, rehacer solo los letreros con SurfaceGui.
Si se prefiere 100% código: reemplazar `buildPlaceholder()` por un constructor que siga
game3.js línea por línea (filas 10–67) e importar solo la naturaleza Kenney.

---

# 02 · Interfaz — original (three.js) vs port Roblox

Fuente de verdad: `reference/src-js/template.html` (HTML+CSS), `game5.js` (HUD, máquina, revelación, inventario, tienda, índice, chat, trade, misiones, tutorial), `game6.js` (#sqHint, #pressDot, #reticle, Estudio), `game7.js` (tour). Capturas: `reference/screenshots/01..08`.
Port: `roblox/src/client/UI/{Kit,Theme,Modal,Toast}.luau`, `roblox/src/client/Controllers/*.luau` (+ textos de prompts/burbujas en `server/Services/{WorldBuilder,NpcService}.luau`).

Abreviaturas: T = template.html, G5/G6/G7 = game5/6/7.js. Rutas Roblox relativas a `roblox/src/client/`.
Paleta CSS (T:12-14): ink #282D3A · ink2 #3a4154 · paper #FFFCF8 · lav #EEE8FA · lav2 #DCD1F3 · pink #F7A7CD · pinkD #E57AAE · purple #B999E8 · purpleD #9676CF · blue #8BC7E8 · blueD #5FA8D2 · mint #9CE0CA · mintD #6BC4A8 · yellow #F4D982 · yellowD #DDB94F · red #FF7B8A. Gris texto secundario #6d7285 / #7a7f92.
Fuentes: display = Lilita One, body = Nunito 600-900 (T:9,15-16).

## Tabla

| # | Elemento | Original (texto/colores/tamaño exactos, archivo:línea) | Roblox ahora (archivo) | Estado | Qué hacer |
|---|---|---|---|---|---|
| 1 | Fuentes | Lilita One (títulos) y Nunito 900 (todo lo demás) (T:9,15-16) | FredokaOne / GothamBold / GothamBlack (UI/Theme.luau:30-32) | 🟡 | Lilita One no existe en Roblox, FredokaOne vale. Para el cuerpo usa **Nunito**, que sí está en Roblox (`Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Heavy)`), en vez de Gotham. Confírmalo en Studio. |
| 2 | Paleta de colores | Variables :root (T:11-14) | Theme.luau:8-27 copia la paleta bien. Agrega green #35b889, orange #e59a3c y robux #00B06F | ✅ | Agrega `grey = #7a7f92` y `popRed = #e0566b`, que el original usa en la máquina (G5:146,200,211; T:370). |
| 3 | Botón base `.btn` | radius 14, padding 10/18, Nunito 900 15px, fondo de color con **sombra sólida abajo** `0 4px 0 <colorD>`. Al presionar baja 3px (T:26-38). El texto es **ink en todas las variantes** menos `.purple` y `.dark`, que van en blanco (T:34-35) | Kit.button: radius 12, **UIStroke de 2px alrededor** (sin sombra abajo), texto de 16px. El texto sale blanco en todo lo que no sea blanco, amarillo o mint (Kit.luau:131-158) | 🟡 | Cambia el borde por un Frame "sombra" del color D, 4px más abajo y detrás del botón, y quita el UIStroke. Anima 3px hacia abajo al presionar. Deja el texto en ink también para **pink** y **blue**; así los botones rosados (llenar, comprar) quedan con texto oscuro como en la captura 07. radius 14, TextSize 15. |
| 4 | Variantes del botón | `.small` 7/12 13px r11 · `.big` Lilita 20px padding 14/26 r18 (T:37-38) | No hay variantes; cada llamada pone su tamaño a mano | 🟡 | Agrega `Kit.button(..., {variant="small"/"big"})`. `big` va en display 20: Guardar, Vender, Aceptar y Jugar. |
| 5 | Botón deshabilitado | opacity .45 + grayscale(.5) (T:36) | Kit.setEnabled: BackgroundTransparency .45, texto .4 (Kit.luau:160-168) | ✅ | — |
| 6 | Posición del HUD / área segura | `#hud` a pantalla completa. No hay nada nativo encima del logo (T:41-42) | La ScreenGui usa `IgnoreGuiInset=true` y la barra de arriba empieza en y=12 (Kit.luau:193, Hud.luau:42). **Los botones CoreGui de Roblox y el chat tapan el logo y las píldoras** | ❌ | Pon el HUD en su propia ScreenGui con `IgnoreGuiInset=false`, o suma `GuiService.TopbarInset`/`GetGuiInset()` al Y. Deja `IgnoreGuiInset=true` solo para la revelación, el tour y los fondos oscuros. Lleva el chat a otro lado con `TextChatService.ChatWindowConfiguration.HorizontalAlignment=Right` y `VerticalAlignment=Bottom` (esa esquina está vacía en el original). |
| 7 | Logo `#logo` | "Squishy World", Lilita 22px **blanco** con text-shadow `0 3px 0 #E57AAE` y `0 0 14px rgba(0,0,0,.15)`. Va en left 16/top 16 (+4px de padding), fila `#topLeft` (T:82-83,340; capturas 05/06) | FredokaOne **30px color pinkD** sin sombra, en (14,12), en la misma fila horizontal que las monedas y el nivel (Hud.luau:46-53) | ❌ | Texto blanco de 22px con una copia pinkD desplazada 3px hacia abajo detrás (eso imita el text-shadow). Ubícalo a la derecha de los botones de Roblox: `x = GuiService.TopbarInset.Min.X + 8`, centrado en la topbar, o debajo de ella. Sácalo de la fila de las píldoras. |
| 8 | Grupo `#stats` (monedas, nivel, mute) | **Arriba a la derecha**: top 16, right 16, gap 10, en este orden: monedas, nivel, 🔊 (T:43,341-345) | Todo va en una fila que arranca a la **izquierda** después del logo: logo, monedas, nivel, poción, mute (Hud.luau:40-100) | ❌ | Pasa las píldoras a una fila anclada arriba a la derecha (`AnchorPoint(1,0)`, `Position(1,-16,0,16+inset)`), con `HorizontalAlignment.Right`. |
| 9 | Píldora `.pill` (fondo) | fondo **oscuro rgba(40,45,58,.82)**, texto blanco, radius 16, padding 8/14, Nunito 900 17px, backdrop blur (T:44) | Fondo **paper #FFFCF8** con borde lav2 y radius 20 (Hud.luau:20-27) | ❌ | BackgroundColor3 = ink con BackgroundTransparency .18, texto blanco, UICorner 16, sin stroke. |
| 10 | Moneda `.coin` | Círculo de 22x22 con `radial-gradient(circle at 35% 30%, #fff3b8, #f4c542 55%, #d19b1c)` y sombra inset abajo (T:45,342) | Emoji "🪙" en TextLabel de 22px (Hud.luau:55). **Sale como cuadrito** | ❌ | Haz un Frame 22x22 con UICorner(1,0) y un UIGradient de ColorSequence #fff3b8→#f4c542(.55)→#d19b1c, rotado unos 45° (o un ImageLabel con una PNG de la moneda). Ponlo en `Kit.coin(size)` y úsalo en el HUD, la Tienda (14px) y los Cambios. |
| 11 | Número de monedas `#coins` | Nunito 900 17px blanco, formato es-CO `1.515` (T:44; G5:11) | FredokaOne 20 ink (Hud.luau:56-61). Format.int con punto de miles | 🟡 | Nunito Heavy 17 en blanco. |
| 12 | Animación `bump` de monedas | escala 1→1.12→1 en .35s (T:50-51; G5:16) | UIScale 1.12→1 en .25s (Hud.luau:209-213) | ✅ | Opcional: .35s. |
| 13 | Píldora de nivel `#lvlPill` | Columna con min-width 130 y padding 7/14. Fila: "**Nivel** N" 14px a la izquierda y "x/y XP" 12px con opacidad .7 a la derecha (T:46-47,343) | "**Nv** 1" en FredokaOne 18 más "0/50 XP" gris, píldora paper de 210 de ancho (Hud.luau:62-75) | ❌ | El texto debe decir "Nivel 1" (no "Nv 1"), en Nunito 14 blanco, y el XP en 12px blanco con transparencia .3. Ancho de unos 130-150. |
| 14 | Barra XP `#xpbar` | alto 7, radius 5, fondo rgba(255,255,255,.18); relleno `linear-gradient(90deg,#9CE0CA,#8BC7E8)` con transición de .4s (T:48-49) | alto 8, fondo lav, relleno **purple** sólido sin animar (Hud.luau:76-86,218) | ❌ | Fondo blanco con transparencia .82 y relleno blanco con un UIGradient mint→blue. Kit.tween .4s al cambiar el ancho. |
| 15 | Botón de sonido `#muteBtn` | `.iconBtn` 40x40, radius 13, fondo paper .9, sombra `0 4px 0 rgba(40,45,58,.15)`, 18px. Alterna 🔊/🔇 (T:84,344; G5:13) | Kit.button blanco 40x40 con "🔊"/"🔇" (Hud.luau:95-100). El estado no se guarda | 🟡 | Los emojis (Unicode 6) se ven bien. Solo falta el estilo del iconBtn y guardar `muted` en el perfil, como `S.muted`. |
| 16 | Menú lateral `#sideMenu` (contenedor) | left 16, **centrado vertical**, gap 10. 5 botones (T:53,346-352) | left 14, centrado, gap 10. **5 botones pero no son los mismos** (Hud.luau:103-116) | 🟡 | Ver filas 17-22. |
| 17 | Botón lateral `.side` (estilo) | 74x70, radius 20, **fondo paper rgba(255,252,248,.92)** igual para todos, sombra `0 5px 0 rgba(40,45,58,.18)`. Ícono de 30x30 arriba, etiqueta Nunito 900 **11px** ink abajo, gap 3 (T:54-57). Si la altura es menor de 800: 64x60 con ícono de 24 (T:235) | 86x70 con **fondo de color distinto en cada botón** (rosado, morado, amarillo, azul, verde), texto blanco o ink según el caso, emoji de 26px más la etiqueta de 12 en RichText (Hud.luau:118-124) | ❌ | Fondo paper igual para todos, texto ink de 11px, y un ImageLabel de 30x30 arriba con el PNG. |
| 18 | Íconos del menú | SVG inline (T:347-351) que son los mismos que `assets/ui/icon_{inv,col,shop,tour,trade}.png`: maletín rosado, cuadrícula morada, tiendita amarilla y mint, claqueta amarilla, flechas de intercambio azul y rosada | Emojis 🎒 📖 🛒 🤝 ⭐ (Hud.luau:111-115). Los PNG existen pero `AssetIds.icons` está vacío y ningún código los usa (shared/Config/AssetIds.luau:48-54) | ❌ | Sube los 5 PNG, llena `AssetIds.icons` y úsalos en ImageLabels. **Esto es lo de "no entiendo los íconos"**: el dueño espera los dibujos del original, no emojis. |
| 19 | Atajo `kbd` en la esquina del botón | Arriba a la derecha (top 4, right 6), 10px, opacidad .45: "I", "C", "B", "🎬", "T" (T:58,347-351) | No se muestra | ❌ | TextLabel de 10px con transparencia .55 en la esquina. |
| 20 | Lista y orden de los botones | Inventario (I) · Colección (C) · **Tienda (B)** · **Tour (🎬)** · **Cambios (T)** (T:347-351) | Inventario (I) · Colección (C) · **Tienda (T)** · Cambios (sin tecla) · **Robux ⭐** (nuevo) (Hud.luau:110-116) | ❌ | Tienda va con **B** y Cambios con **T**. Falta el botón **Tour**. El botón Robux es un agregado de monetización: si se queda, que tenga el mismo estilo paper y un ícono propio, y anótalo en Desviaciones. |
| 21 | Acción de "Cambios" | Lleva a la Plaza con `guideTo('trading')` y el toast "Sigue la flecha hasta la Plaza de Intercambio" (G5:679) | Abre el modal "Cambiar con jugadores" (Hud.luau:114; Trade.luau:328) | 🟡 | Hazlo como el original: guía más toast. El modal de jugadores puede abrirse desde el tablero de la Plaza. |
| 22 | Pulso `.side.pulse` | Anillo rosado rgba(247,167,205,.9) que se expande 10px y se desvanece cada 1.1s. Sale en Inventario durante el tutorial paso 4 (T:59-60; G5:602) y en el botón Cambiar del chat (G5:496) | No existe (Tutorial.luau:344-349 solo muestra toasts) | ❌ | UIStroke rosado que se anime con un tween de Thickness 0→10 y Transparency 0→1 en bucle. Quítalo al abrir el inventario (G5:349). |
| 23 | Tarjeta de misión `#questCard` (caja) | right 16, top **92**, ancho **250**, fondo paper .93, radius 18, padding 12/14/13, sombra `0 5px 0 rgba(40,45,58,.15)` (T:62). Si la altura es menor de 800: top 84, ancho 230 (T:235) | right 14, top 70, 260x108 fijo, borde lav2 (Hud.luau:152-158) | 🟡 | Top = inset + 76 (debajo de las píldoras), ancho 250, sombra abajo, sin stroke. AutomaticSize Y. |
| 24 | Título de la misión | `<h4>` "**Misión**" en Lilita 15px color **purpleD #9676CF** (T:63,353) | "📜 MISIÓN" en GothamBlack 12px color pinkD (Hud.luau:159) | ❌ | Texto "Misión" en display 15, color #9676CF, sin emoji y sin mayúsculas. |
| 25 | Texto de la misión `#questTitle` | Nunito 900 15px, line-height 1.25 (T:64) | GothamBlack 16 (Hud.luau:160-166) | 🟡 | 15px. |
| 26 | Barra de la misión | alto 9, radius 6, fondo lav, relleno mint, margen 8/0/5, transición .3s (T:65-66) | alto 10, lav y mint, sin animar (Hud.luau:167-177) | 🟡 | 9px y tween .3s. |
| 27 | Meta de la misión `#questMeta` | Flex space-between, 12px 800 #6d7285: a la izquierda "`p / goal`" y a la derecha "`Premio: N monedas`" (T:67; G5:587) | Un solo texto "p / goal · Premio: N monedas" (Hud.luau:223) | 🟡 | Dos labels, uno alineado a la izquierda y otro a la derecha. |
| 28 | Botón "Muéstrame" `#questGuide` | btn small (lav) "Muéstrame". Llama a `guideTo(q.target)` y se oculta si la misión no tiene target (T:353; G5:588-590) | **No existe** | ❌ | Agrégalo y conéctalo a `Tutorial.guideTo(q.target)`. |
| 29 | Misión con ventana abierta | Sigue visible debajo del overlay (el panel de la máquina queda encima) | Se oculta con cualquier modal abierto (Hud.luau:202-204) | 🟡 | Aceptable. Si quieres igualarlo, déjala visible. |
| 30 | Aviso de interacción `#prompt` | Abajo al centro (bottom 120), fondo rgba(40,45,58,.88), radius 14, padding 10/16, Nunito 900 16 blanco. Tecla "E" en una ficha blanca con fuente display y sombra `0 3px 0 #b7bccb`. Si está bloqueado, el fondo cambia a rgba(120,70,80,.88) (T:70-72,354) | ProximityPrompt **estilo Default de Roblox** (server/Services/WorldBuilder.luau:193-199; NpcService.luau:144-157) | ❌ | Usa `Style = Custom` y dibuja tú el prompt en `PromptShown`/`PromptHidden`, con este estilo. |
| 31 | Textos del prompt | "Usar la Máquina Squishy" (m1) / "Usar {nombre}" · "{nombre} — requiere nivel N" (bloqueado) · "Abrir la Tienda" · "Abrir el Índice Squishy" · "Hablar con {npc}" (G5:75-78) | ActionText "Usar"/"Comprar"/"Ver"/"Intercambiar" + ObjectText (WorldBuilder.luau:257-261). En los NPC hay **dos** prompts: "Cambiar" (E) y "Hablar" (R) (NpcService.luau:155-156) | ❌ | Usa exactamente los textos del original. En el NPC va un solo prompt "Hablar con X" que abre el chat, y el botón "Cambiar" queda dentro del chat (filas 70-72). |
| 32 | Contenedor de toasts `#toasts` | top **18**, centrado, gap 8, máximo 4 (T:74; G5:8) | y=70, ancho 520, gap 6, máximo 4 (UI/Toast.luau:17-24) | 🟡 | y = inset + 18 está bien (70 queda debajo de la topbar). Gap 8. Pon `LayoutOrder` incremental a cada toast, porque hoy todos tienen 0 y el orden puede salir mal. |
| 33 | Toast normal `.toast` | fondo paper, radius 16, padding 10/18, Nunito 900 15, sombra `0 5px 0 rgba(40,45,58,.15)`, máximo 520, centrado (T:75) | paper con borde lav2 y padding 16/9, GothamBold 15 (Toast.luau:29-47) | 🟡 | Quita el borde, pon la sombra abajo, padding 18/10 y fuente 900. |
| 34 | Toast grande `.toast.big` | **El mismo fondo paper** con texto ink, Lilita **24px**, padding 14/26 (T:76). Captura 05 | Fondo **ink oscuro**, borde rosado, texto blanco de 19px (Toast.luau:29,37,39-44) | ❌ | Fondo paper, texto ink, display 24. |
| 35 | Animación de los toasts | Entra con toastIn (sube desde -14px y aparece) en .3s y sale con toastOut (-10px y se desvanece) en .35s (T:77-79) | Aparece y desaparece de golpe (Toast.luau:60-64) | ❌ | Haz el tween de posición y transparencia al entrar y al salir (con un CanvasGroup es fácil). |
| 36 | Barra de ayuda `#helpBar` | Abajo a la izquierda (left 16, bottom 14), 12px 800 rgba(40,45,58,.7) sobre una píldora paper .7 con radius 10. Texto: "WASD moverse · Shift correr · Mouse / ← → cámara · E interactuar · Clic sostenido = apachurrar · Clic derecho / Q = apuntar · F de cerca" (T:81,356) | Centrada abajo, 13px ink2 con contorno blanco y sin fondo. Texto: "E usar · Mantén clic sobre un squishy para apachurrarlo · I inventario · T tienda" (Hud.luau:186-199) | ❌ | Copia el texto del original tal cual (quita lo que todavía no exista, como Q/F, y anótalo). Posición abajo a la izquierda con la píldora. Revisa que ← → se vean (fila G-9). |
| 37 | Overlay de las ventanas `.overlay` | Fondo rgba(40,45,58,.35) con blur de 2px detrás de Inventario, Tienda, Índice, NPC y Trade. Al hacer clic fuera se cierra (T:93; G5:102) | Sin oscurecer y sin blur (Modal.luau) | ❌ | Frame a pantalla completa en ink con transparencia .65 más un `BlurEffect` Size≈4 en Lighting mientras haya un modal (menos en la máquina). Que el clic en el fondo cierre. |
| 38 | Panel `.panel` | fondo paper, **radius 26**, sombra `0 8px 0 rgba(40,45,58,.18)` + `0 20px 60px`, max-height 88vh (T:94) | radius 22 con **stroke lav2 de 3px** (Modal.luau:61-73) | 🟡 | radius 26, sin stroke y con un Frame de sombra 8px abajo (ink con transparencia .82). |
| 39 | Encabezado del panel `h2` | Lilita 28, letter-spacing .5, padding 18/22/10 (T:95-96) | display 28 en (22,14) (Modal.luau:86-92) | ✅ | — |
| 40 | Subtítulo del panel `h3` | Lilita 17 color **purpleD #9676CF** (T:97) | No existe como estilo. Las secciones usan 15px en ink (Machine.luau:480-484) | ❌ | Agrega `Kit.h3(text)` en display 17 color #9676CF. |
| 41 | Botón cerrar `.close` | 40x40, radius 13, **fondo lav #EEE8FA**, glifo "✕" 20px 900, sombra `0 3px 0 lav2` (T:98) | Kit.button("✕") blanco de 38x38 con TextSize 18 (Modal.luau:93-101). **El "✕" sale como cuadrito** | ❌ | Fondo lav de 40x40 con radius 13 y sombra abajo. Cambia el glifo por **"×" (U+00D7)** en GothamBlack/Nunito 26, que sí existe en la fuente, o dibuja dos Frames de 3x18 rotados ±45° en ink. |
| 42 | Pestañas `.tab` | radius 11, padding 7/12, 900 13px, fondo **lav**. Activa: **fondo ink y texto blanco**. Pestaña viral sin activar: #fff4fb (T:100-102,247) | Kit.button blanco con borde. Activa en rosado (Inventario, Tienda) o morado (Índice) (Inventory.luau:175; Shop.luau:148; Index.luau:359) | ❌ | Haz un `Kit.tab(label, on, viral)` con los colores del original. Se ve en las capturas 07 y 08: la activa es negra. |
| 43 | Panel de la máquina `#machinePanel` | Pegado a la derecha (right 18, centrado vertical), **ancho 430** (390 si la pantalla mide menos de 1400px), max-height 92vh, **sin overlay** (T:105-106,234) | Modal de 470x660 anclado a la derecha (Machine.luau:447-466) | 🟡 | Ancho 430 y alto hasta el 92% del viewport. |
| 44 | Título de la máquina `#mTitle` | "Crea un Squishy" (m1) o el nombre de la máquina (T:362; G5:113) | Igual (Machine.luau:447) | ✅ | — |
| 45 | Info de la máquina `.machineInfo` | 13px 800 #6d7285: "Máquina 01 · Llenadora Básica[ · +N% suerte][ · más mutaciones]" (T:128; G5:114) | Igual (Machine.luau:470-477) | ✅ | — |
| 46 | Sección 1 | h3 "**1. Elige el molde**" (T:365) | "Moldes" en display 15 ink (Machine.luau:501) | ❌ | Texto exacto con el estilo h3 (fila 40). |
| 47 | Cuadrícula de moldes `.molds` | **5 columnas** 1fr con gap 8. Botón: fondo lav, radius 16, borde transparente de 3px, padding 6/2/7. Imagen de 56 (48 si la pantalla mide menos de 1400) y nombre Nunito 900 12px (T:107-109,234) | Celdas fijas de 92x92 que en 470px dan 4 columnas. Fondo blanco, o rosado si está elegido (Machine.luau:136-139,492-497) | 🟡 | Usa UIGridLayout con CellSize de escala 1/5 (menos el gap). Fondo lav. |
| 48 | Molde elegido `.mold.on` | Borde **ink de 3px** y fondo **blanco** (T:110; captura 06) | Fondo **rosado** (Machine.luau:136) | ❌ | UIStroke ink de 3px y fondo blanco. |
| 49 | Molde bloqueado | La imagen se ve como **silueta** (`brightness(0) opacity(.25)`). Ficha `.lk` centrada a **top 22px**, 11px, fondo ink, texto blanco, radius 8: "Nv N" o "🛒 {precio}" (T:111-112; G5:126). Captura 06 | Ficha arriba a la izquierda (4,4) y el botón completo con transparencia .35 (Machine.luau:155-166) | 🟡 | Muestra la miniatura como silueta (el mismo `Thumb.make(...,true)` del Índice) y centra la ficha sobre la imagen. 🛒 se ve bien. |
| 50 | Encabezado de virales `.viralH` | h4 "✨ Moldes virales" en 14px (negrita del navegador), color #a86ad0, margen 10/0/6 (T:244,365) | Texto igual en display 15 con color #a86ad0 (Machine.luau:502) | 🟡 | Nunito 900 14. |
| 51 | Fila de virales `.molds.viralRow` | Scroll propio con **max-height 190**. Fondo de cada viral: gradiente de #fff a #fff4fb. Orden: primero los que tienes y luego por precio (T:245-246; G5:130) | Sin scroll propio y sin gradiente. El orden sí está bien (Machine.luau:204-213) | 🟡 | Mete los virales en un ScrollingFrame de alto 190 y ponles UIGradient blanco→#fff4fb. |
| 52 | Sección 2 | h3 "**2. Elige el relleno**" (T:366) | "Relleno" (Machine.luau:503) | ❌ | Texto exacto. |
| 53 | Chips de relleno `.fill` | Flex-wrap de **ancho automático**, fondo lav, radius 13, padding 6/10/6/7, 900 13px. Círculo `.sw` de 20x20 al 50% con sombra inset. Sufijos: " (N)" en small si es Misterio y " 🔒" si no lo tienes. Elegido: borde ink y fondo blanco. Bloqueado: opacidad .5 (T:113-117; G5:131-134) | Celda fija de 128x34 en 12px. Color de fondo blanco o rosado. El cuadrito de color mide 12px con radius 6 y **se monta sobre el texto centrado** (Machine.luau:216-235). Agrega " (gratis 👑)" para VIP | 🟡 | UIListLayout horizontal con Wraps=true, AutomaticSize X, círculo de 20px a la izquierda y el texto alineado a la izquierda después del círculo. Colores como el original. |
| 54 | Sección 3 | h3 "**3. Mantén para llenar — suelta en la zona Perfecto**" (T:367) | "Probabilidades" en 13 muted (Machine.luau:506) | ❌ | Texto exacto. Quita "Probabilidades". |
| 55 | Probabilidades `.odds` | 6 chips `flex:1` que llenan el ancho con gap 4, radius 8, padding 3/0, **10.5px** 900 blanco sobre el color de la rareza. Texto `name.split(' ')[0].slice(0,4)` + " %": "Comú 65%", "Poco 22%", "Raro 8%", "Épic 3.5%", "Lege 1.4%", "Secr 0.1%". Tooltip con el % Perfect (G5:137; T:126-127) | Chips de 62x20 con **`string.sub(r.name,1,4)` por bytes**: "Común" se corta en "Com"+byte suelto (**UTF-8 roto, sale cuadrito o �**) y "Épico" queda "Épi" (Machine.luau:260-276). Tampoco corta en el espacio | ❌ | Usa `utf8.offset`: toma la primera palabra con `string.match(name,"^%S+")` y corta 4 caracteres con `string.sub(w,1,(utf8.offset(w,5) or #w+1)-1)`. Chips con escala 1/6. Sin radius 8 no se parecen. |
| 56 | Medidor `.gauge` | alto 30, radius 15, fondo #e9e4f2. Zonas: [0,perf0] #e9e4f2 · [perf0,perf1] **#9CE0CA** · [perf1,.97·pop] **#ffd9a8** · [.97·pop,pop] **#ff9aa8**. `.prog` rgba(40,45,58,**.08**) (T:118-121; G5:141) | Zonas y colores iguales. `prog` en **rosado con transparencia .55**, que se ve como un relleno rosado fuerte (Machine.luau:515-541) | 🟡 | Pon prog en ink con transparencia .92. |
| 57 | Aguja `.needle` | Ancho 5, se sale 2px arriba y abajo, ink, radius 3, **anillo blanco de 2px** (`box-shadow 0 0 0 2px #fff`) (T:120) | 4px sin anillo. El ClipsDescendants del gauge la corta (Machine.luau:542-548) | 🟡 | Ancho 5 con UIStroke blanco de 2px. Sácala del frame que recorta para que sobresalga. |
| 58 | Etiquetas del medidor `.glabels` | Flex **space-between**, 11px 900 #7a7f92: "Le falta" · "**Perfecto**" (#3faf86) · "Se pasa" · "**¡Pop!**" (#e0566b) (T:122,370) | Colocadas en la fracción de cada zona, todas en gris. Dice "¡**POP!**" en mayúsculas (Machine.luau:555-569) | 🟡 | 4 labels repartidos a lo ancho (UIListLayout con `HorizontalFlex=SpaceBetween`), con los colores y el texto "¡Pop!". |
| 59 | Botón de llenar `#holdBtn` | btn pink a todo el ancho, **Lilita 26px**, padding 18, radius 20, letter-spacing 1. Mientras se mantiene baja 3px y escala a .99. Texto "Mantén para llenar", y **"Llenando… ¡suelta!" mientras el estado sea filling** (T:123-124,371; G5:144) | Alto 56, display 20, texto blanco (Machine.luau:571-577,280) | 🟡 | Display 26 en **ink**, alto unos 66, radius 20 y efecto de presión. |
| 60 | Resultado `#fillResult` | Alto 26, display 20, centrado. "Le faltó" #7a7f92 · "¡PERFECTO!" #35b889 · "Se pasó" #e59a3c · "¡POP! Se reventó — demasiado lleno." #e0566b · "Sigue manteniendo…" #7a7f92 · "Inventario lleno (N). Vende algunos squishies primero." #e0566b en **Nunito 900 15** (G5:146,193,200,211) | Los textos están bien. Colores: muted #6d7285 y **Theme.red #FF7B8A** para POP e inventario lleno (Machine.luau:283-286,297-300,318,362) | 🟡 | Usa #7a7f92 y #e0566b. El aviso de inventario lleno va en body 15. |
| 61 | Inventario: panel | `min(980,94vw)` x `min(660,88vh)` (T:131) | 900x580 (Inventory.luau:216-222) | 🟡 | 980x660 con UIScale para pantallas chicas. |
| 62 | Inventario: encabezado | "Inventario " + `#invCount` "N/cap" en **18px con opacidad .55** junto al título. A la derecha, "Vender repetidos" (btn small yellow) y ✕ (T:377) | El contador va a mano en (150,-46) en display 16 muted. El botón está bien (Inventory.luau:223-236) | 🟡 | Pon el contador pegado al título (TextBounds) en 18px con transparencia .45. |
| 63 | Inventario: pestañas | "Todos", Común… Secreto, "**★ Favoritos**" (G5:352) | Los textos coinciden. Activa en rosado. **★ puede salir como cuadrito** (Inventory.luau:266) | ❌ | Estilo de la fila 42 y cambia el glifo (G-4). |
| 64 | Inventario: cuadrícula `.grid` | **4 columnas** 1fr con gap 10 y columna de detalle de **290** (T:132-133) | Cartas fijas de 104x128 (salen unas 5 columnas) y detalle de 266 (Inventory.luau:282-295) | 🟡 | Columna de detalle de 290 y 4 columnas con escala 1/4. |
| 65 | Inventario: carta `.card` | Fondo blanco, radius 18, borde transparente de 3px, sombra `0 4px 0 lav2`, imagen cuadrada de hasta 120, nombre 12.5 900. Rareza `.rr` en **chip de ancho automático** de 11px con radius 7, padding 1/8 y texto blanco. **Elegida: borde ink** (T:134-141; G5:356) | Elegida = fondo **lav** sin borde ink. El chip de rareza ocupa todo el ancho (Inventory.luau:24-54) | 🟡 | Stroke ink de 3px en la elegida, chip con AutomaticSize X y sombra lav2 abajo. |
| 66 | Carta: favorito y equipado | **★ arriba a la derecha** (top 6, right 8, 15px) · "**Equipado**" arriba a la izquierda (top 6, left 8, 10px 900) en ficha **ink** con texto blanco (T:138-139) | ★ arriba a la **izquierda** en yellowD · "Equipado" arriba a la **derecha** en ficha **mintD** (Inventory.luau:55-75) | ❌ | Invierte las posiciones y usa ficha ink. Cambia ★ (G-4). |
| 67 | Inventario vacío `.empty` | "Nada con este filtro." / "Aún no tienes squishies. ¡Ve a las Máquinas y llena el primero!" (G5:357), 800 #7a7f92, centrado | Los textos están bien. Va alineado a la izquierda y en 400px (Inventory.luau:191-199) | 🟡 | Centrado. |
| 68 | Detalle `.detail` | Fondo lav, radius 20, padding 16, gap 8. Imagen de **190x190**. Nombre `.dn` en display **24**. Chip de rareza (radius 8, padding 2/10). Filas `.kv` **space-between** en 14px (etiqueta 800, valor **900**): Encontrado / Valor / Relleno / Tamaño / Copias. Fecha con `toLocaleDateString('es-CO',{day:'numeric',month:'short',year:'numeric'})`, por ejemplo "25 sept 2026" (T:142-146; G5:365-371) | Imagen de 150 de alto, nombre display 20. Filas como un solo texto "etiqueta   **valor**" en 13px. Fecha en formato **dd/mm/YYYY** (Inventory.luau:94-130) | 🟡 | Dos labels por fila (etiqueta a la izquierda, valor a la derecha en 14px). Imagen de 190 y nombre de 24. Fecha "D mes AAAA" con los meses abreviados en español ("ene", "feb", … "sept", … "dic"). |
| 69 | Detalle: botones | "**🖐️ Apachurrar**" (btn purple, abre el Estudio) · fila "Equipar"/"Quitar" (mint) + "☆ Favorito"/"★ Quitar fav" · "Vender por N" (yellow, deshabilitado si es favorito o está equipado) (G5:372-374) | Falta **🖐️ Apachurrar**. Los demás botones y textos están bien (Inventory.luau:137-151) | ❌ | Agrega el botón morado (aunque sea para la versión mínima de apachurrar mientras llega el Estudio). Cambia ★/☆ (G-4). |
| 70 | Tienda: panel | `min(760,94vw)`. La cuadrícula es auto-fill con minmax(200px), unas 3 columnas y gap 12 (T:152-153) | 860x560 con celdas de 260x150 y gap 10 (Shop.luau:269-300) | 🟡 | Ancho 760, celdas de 1/3 y gap 12. |
| 71 | Tienda: pestañas | "✨ Moldes Virales" · "Rellenos" · "Mejoras". Por defecto "Rellenos". La activa en ink (G5:408; captura 07) | Las mismas más "**⭐ Robux**" (agregado). La activa en rosado o verde (Shop.luau:26-31,147-150) | 🟡 | Estilo de la fila 42. La pestaña Robux es una desviación: documéntala. |
| 72 | Tienda: tarjeta `.item` | Blanca, radius 18, padding 14, sombra `0 4px 0 lav2`, gap 6. Título `.t` en **Nunito 900 16** con la miniatura de 58 **en línea a la izquierda**. Descripción `.d` 12.5 700 #6d7285 + `<b>` en ink ("Slow rise Xs · suave") (T:154-156; G5:412) | Borde lav2 en vez de sombra. Título en **FredokaOne**. La descripción va toda en muted, y la línea en negrita también (Shop.luau:43-59) | 🟡 | Título en body 900 16. La línea en negrita va en `<font color="#282D3A">`. Sombra abajo. |
| 73 | Tienda: botón de precio | "btn pink" con el círculo `.coin` de 14px + " 600" y **texto ink**. Si ya es tuyo: "Tuyo" (lav, deshabilitado). Mejora al máximo: "Nivel máximo". Mejoras en btn **mint** (G5:413,419,427) | "**🪙** 600". **La moneda sale como cuadrito** y el texto sale en blanco (Shop.luau:162,181,216) | ❌ | `Kit.coin(14)` + el número. Texto ink (fila 3). |
| 74 | Tienda: ícono de relleno | Círculo `.sw` de **26x26** (radius 50%) del color del relleno (G5:418) | Cuadrado de 54x54 con radius 14 (Shop.luau:188-189) | 🟡 | Círculo de 26 junto al título. |
| 75 | Tienda: nivel de mejora `.lv` | Fila de **segmentos** de 7px de alto con radius 4 y gap 3, `flex:1`: llenos en mint, vacíos en lav (T:157-159; G5:426) | Texto "●●○○" dentro de la descripción (Shop.luau:210). **● y ○ pueden salir como cuadritos** | ❌ | Frames reales (UIListLayout horizontal), uno por cada costo. |
| 76 | Tienda: íconos de mejora | Sin ícono, solo el título (G5:426) | Agrega ⚡ 🍀 🎒 de 30px (Shop.luau:223) | 🟡 | Quítalos para que quede como el original. |
| 77 | Índice: panel | `min(900,94vw)` x `min(660,88vh)` (T:162) | 900x580 (Index.luau:420-426) | 🟡 | Alto 660. |
| 78 | Índice: cabecera `.idxHead` | `.bigCount` "N / 413" en **Lilita 30** + "descubiertos — las siluetas siguen siendo un misterio" en 900 #6d7285 (unos 16px), gap 14 (T:168-169; G5:453). Captura 08 | Un solo label en display 20 con el subtítulo en RichText de 13 (Index.luau:337-341) | 🟡 | Dos labels: 30 display y 16 body 900 gris. |
| 79 | Índice: pestañas de especie | **Horizontales con wrap** encima de la cuadrícula: "Gato 0/28", "✨ Barra de Mantequilla 0/21"… Contador con opacidad .6. Los virales llevan fondo #fff4fb y la activa va en ink (G5:454; captura 08) | **Columna vertical** de 230px a la izquierda. La activa va en **morado** (Index.luau:343-368,428) | ❌ | Fila con wrap (UIListLayout Wraps=true) encima de la cuadrícula, con el estilo de pestaña de la fila 42. |
| 80 | Índice: celda `.idx` | auto-fill minmax(**104**) con gap 9, fondo blanco, radius 15, **borde superior de 5px del color de la rareza** y sombra `0 3px 0 lav2`. Imagen de 84. Nombre 11.5 900. Desconocido: "???" en #a7abb9 con silueta (T:163-167; G5:458) | Celdas de 100x112 con **stroke de 2px alrededor** del color de la rareza (Index.luau:388-411) | 🟡 | Barra de color de 5px arriba (Frame aparte) en vez del stroke, y sombra lav2 abajo. |
| 81 | Chat con NPC `#npcWrap` (panel) | Panel de `min(560)` x `min(560)`. Encabezado: avatar `.npcAv` de 48 con la miniatura del squishy + nombre (h2 24) + "Presumiendo: {squishy} · {rareza}" (12.5 800 #6d7285). A la derecha: "**🖐️ Apachurrar**" (btn small purple) · "**Cambiar**" (btn small mint) · ✕ (T:172-174,393; G5:474-476) | **No existe**. "Hablar" (R) solo hace que el servidor ponga una burbuja (Interact.luau:39-40; NpcService.luau:219-229) | ❌ | Construye el panel de chat. |
| 82 | Chat: mensajes | `.msg` con máximo 80%, padding 9/13, radius 16, 700 14.5. Los del NPC en lav a la izquierda (esquina inferior izquierda de 5), los tuyos en ink con texto blanco a la derecha. "escribiendo…" con opacidad .6. Saludo: "¡Holi! Soy X 👋" / "¡Hola! ¡Mucho gusto!" / "¡Ey! ¿Quieres ver mi X? Puedes apachurrarlo 😄" (T:175-179; G5:473,480) | No existe | ❌ | ScrollingFrame con burbujas alineadas a cada lado. |
| 83 | Chat: barra de escritura y nota | Input con borde lav2 de 3px, radius 14 y placeholder "**Escribe algo…**" (máx. 140) + "**Enviar**" (btn purple). `.aiNote` en 11px 800 #8b90a3: "Los jugadores de aquí funcionan con Claude: chatea, pide tips o negocia." / "Chat en modo offline (respuestas predefinidas)." (T:180-182,396; G5:476) | No existe | ❌ | TextBox + botón, y el texto se filtra con TextService. |
| 84 | Burbuja del NPC `.bubble` | Blanca, radius 13, padding 6/11, **800 13px en ink**, sombra `0 3px 0`, una sola línea con máximo 260 y **piquito** abajo (T:89-90) | BillboardGui de 220x60 con **TextScaled**, GothamBold #3A3350 y sin piquito (NpcService.luau:59-80) | 🟡 | TextSize 13 fijo con AutomaticSize y un triángulo abajo (ImageLabel o Frame rotado). Color ink. |
| 85 | Nombre del NPC `.tag` | Blanco 900 13px con text-shadow `0 1px 3px rgba(0,0,0,.55)` (T:88) | Humanoid.DisplayName con el estilo por defecto de Roblox (NpcService.luau:118-121) | 🟡 | Aceptable. Para igualarlo: BillboardGui con texto blanco de 13 y TextStroke con transparencia .45. |
| 86 | Trade NPC: panel y título | `min(960)` x `min(640)`. "**Cambio con** {npc}" (T:185,400) | 900x600. "**Intercambio con** {npc}" (Trade.luau:112-115) | 🟡 | Título exacto. |
| 87 | Trade NPC: columnas `.tcol` | **Dos columnas lav** (radius 20, padding 14). Izquierda: h3 "**Tu oferta**" + valor a la derecha, 3 slots, "**Elige hasta 3 squishies**" (12px 800 #6d7285) y miniGrid de tu inventario. Derecha: h3 "**Su oferta**" + valor, slot, "**Medidor del trato**", barra, pista y botón "**Pedir otra cosa**" (T:186-187,401-405) | Una columna a la izquierda con el mensaje, "Tu oferta N 🪙", las cartas, "{npc} ofrece N 🪙", la barra, la pista y los botones. A la derecha, las cartas de 104x128 del inventario, sin fondo lav (Trade.luau:125-231) | ❌ | Rehazlo con el layout del original: 2 columnas lav, los textos exactos y el inventario dentro de la columna izquierda. |
| 88 | Trade: slots `.slot` | flex 1, min-height 120, **borde punteado lav2 de 3px**, fondo blanco .6, texto 12px 900 #8b90a3 "**Vacío**" / "**Esperando tu oferta…**". Lleno: borde sólido con imagen de 74 y el nombre. En el suyo, la rareza en su color (T:188-191; G5:528-529) | Frame semitransparente con stroke sólido y "Vacío". El slot de ellos no dice "Esperando tu oferta…" (Trade.luau:40-54,155) | 🟡 | Borde punteado: no existe nativo, así que usa un ImageLabel 9-slice punteado o déjalo sólido y anótalo. Agrega el texto "Esperando tu oferta…". |
| 89 | Trade: miniaturas `.mini` | Mínimo 78px con gap 7, imagen de 60, 10.5 900. Elegida con **borde mintD de 3px** (T:192-195) | Cartas grandes de inventario (104x128). La elegida en lav (Trade.luau:70,88) | 🟡 | Carta mini de 78 con stroke mintD. |
| 90 | Trade: valores | "N 🪙" a la derecha del h3 (G5:530): el original **sí** usa 🪙, pero en el navegador se ve | "N 🪙" (Trade.luau:133,151,264,274): **cuadrito** | ❌ | `Kit.coin(14)` a la derecha del número. |
| 91 | Trade: medidor `.fairness` | Alto 12, radius 7, **fondo blanco**. Relleno de ancho `clamp(ratio/1.5)`: **#FFC83A** si es ≥1.15, **#9CE0CA** si es ≥0.8 y **#ff9aa8** si es menos. Pistas: "Súper trato para ellos: van a decir que sí." / "Cambio justo: seguramente aceptan." / "Quieren más. Agrega otro squishy." (T:196-197; G5:531-533) | Colores y textos iguales. Fondo lav, sin transición (Trade.luau:157-179) | 🟡 | Fondo blanco, tween .3s y la etiqueta "Medidor del trato". |
| 92 | Trade: pie `.tradeFoot` | Mensaje en 900: "Elige lo que quieres ofrecer." / `{npc}: "¿Qué tal mi X?"` / `"Bueno, ¿y este?"`. Botones "**Cancelar**" (btn) y "**Aceptar**" (btn **mint big**) (T:198-199,407; G5:510,543,546) | Mensaje arriba. Botones "**¿Y otro? (N)**" y "**Proponer cambio**". No hay Cancelar (Trade.luau:131,185-190) | ❌ | Textos "Pedir otra cosa", "Cancelar" y "Aceptar" (big mint) en el pie. |
| 93 | Trade entre jugadores (sala, solicitud, lista) | No existe en el original (es un trade simulado con NPC) | Agregado: "Cambiar con jugadores", tarjeta "X quiere intercambiar contigo 🤝", sala con 👍 ✅ (Trade.luau:236-405) | 🟡 | Es una desviación válida para multijugador. Dale el mismo estilo que la fila 87. ✅ y 👍 se ven bien. Anótalo en PROGRESS. |
| 94 | Confirmación "Vender repetidos" | `confirm()` del navegador: "¿Vender N repetido(s) por X monedas? Te quedas con la mejor copia de cada uno." (G5:399) | Dialog propio con "Sí"/"Cancelar" y el mismo texto (Dialog.luau; Inventory.luau:242-252) | ✅ | Estilo: fondo oscurecido en ink en vez de negro. |
| 95 | Revelación: fondo por rareza | `#reveal` con **fondos oscuros radiales**. Base (Común y Poco común): `radial-gradient(circle at 50% 45%, rgba(40,45,58,.35), rgba(20,22,30,.82))`. **rare**: rgba(92,168,255,.45)→rgba(15,25,50,.84) 70%. **epic**: rgba(180,92,255,.5)→rgba(30,15,50,.86). **legendary**: rgba(255,214,90,.75)→rgba(120,70,10,.85). **secret**: #07060c (T:202-206) | **Rosado claro #FFF6FB** casi opaco para todas las rarezas, salvo el secreto (Reveal.luau:43-51) | ❌ | Frame a pantalla completa con un UIGradient radial (Roblox no tiene radial: usa una imagen de viñeta radial blanca teñida con ImageColor3 o varios Frames). Colores exactos por rareza. |
| 96 | Revelación: "Te salió…" `#revGot` | Lilita **26** en **blanco** con opacidad .9 y letter-spacing 1 (T:208) | display 22 en ink (Reveal.luau:62-68) | ❌ | Blanco, 26, transparencia .1. |
| 97 | Revelación: escenario 3D `#revStage` | `min(420, 60vh)` cuadrado. El squishy **escala 0→1.15→1** entre 0.55 y 1.1s y **oscila** en Y con `sin(t*.9)*.5` (no da vueltas completas). El legendario hace zoom 7.4→6.2 (T:209; G5:305-310) | ViewportFrame de 340. Crece desde t=0 en .5s y **gira sin parar** con `t*0.9` (Reveal.luau:69-121) | 🟡 | Tamaño `min(420, 0.6*vpY)`. Mismo retraso de 0.55s y curva 0→1.15→1. La rotación va `Angles(0, math.sin(t*0.9)*0.5, 0)`. |
| 98 | Revelación: rareza `#revRarity` | Lilita **64** (50 si la altura es menor de 800), letter-spacing 2, color de la rareza, text-shadow `0 5px 0 rgba(0,0,0,.25)`. Animación **popIn** .6s `cubic-bezier(.2,1.6,.4,1)` 0→1.15→1. Textos "¡Común!"… y "¡SECRETO ENCONTRADO!" (T:210,217-218; G5:277) | display 44 con **contorno blanco** y sin pop (Reveal.luau:76-85,130) | ❌ | 64px sin contorno, con una copia negra al 75% desplazada 5px detrás, y UIScale con tween Back 0→1.15→1. |
| 99 | Revelación: glitch del secreto | `#revRarity` y `#revName` con **glitch** 0.5s infinito: sombras #ff2a6d/#05d9e8 de ±3px, saltos de ±2px y clip (T:219-220) | No existe | ❌ | Dos copias del texto (magenta y cian) desplazadas ±3px que alternan cada 0.25s, más un jitter de posición. |
| 100 | Revelación: pantallazo negro | `.blackout` negro a pantalla completa por 0.9s (opaco hasta el 55% y luego se desvanece) + "secretSting" (T:221-222; G5:272) | Solo el sonido y el fondo #07060c (Reveal.luau:123-125) | ❌ | Frame negro con ZIndex encima que se desvanece de .55 a .9s. |
| 101 | Revelación: nombre `#revName` | Lilita **30** en **blanco**, margin-top 4 (T:211) | display 24 en ink (Reveal.luau:86-92) | ❌ | Blanco, 30. |
| 102 | Revelación: badges `.badge` | radius 10, padding 4/10, 900 13px. Normal: **fondo blanco y texto ink**. `.new`: **fondo yellow #F4D982**. Textos "¡Squishy nuevo descubierto!", {mutación}, "✨ Viral", "Vale N monedas" (T:212-214; G5:279-282) | Nuevo en **pinkD con texto blanco**, mutación en morado, Viral en yellowD y el valor en paper (Reveal.luau:132-160) | 🟡 | Todas blancas con texto ink, y "nuevo" en amarillo con texto ink. |
| 103 | Revelación: botones | "Guardar" (btn **mint big**) · "Vender +N" (btn **yellow big**), min-width 150, gap 14. Guardar se deshabilita si el inventario está lleno. `visibility:hidden` hasta el beat (T:215-216,417; G5:284-286) | 190x52 en **GothamBlack 20**. Textos correctos (Reveal.luau:164-174) | 🟡 | Fuente display 20 (big) y gap 14. |
| 104 | Revelación: partículas `#revealFx` | Canvas 2D desde tier ≥ 2. rare: 40 chispas #bfe0ff/#fff/#4C9BFF. epic: 80 chispas #e2c6ff/#A95CFF/#fff. legendary: 140 entre confeti y estrellas #FFC83A/#FF8FA3/#8BE3A5/#8BC7E8/#fff/#B999E8, más rápidas. secret: 120 rayitas glitch #000/#ff2a6d/#05d9e8 (G5:293-301,313-322) | No existen | ❌ | Partículas en UI: Frames pequeños con tween, o CanvasGroup. Mismos colores y cantidades. |
| 105 | Revelación: emote legendario | El personaje hace `emote-yes` (G5:287) | Nada | 🟡 | Opcional: animación de celebración del avatar. |
| 106 | Pedestales de la Colección | Muestran el mejor squishy que tengas de cada rareza, girando. Si no tienes, un holograma "**?**" de 150px en el color de la rareza que flota (G5:609-622) | Solo cilindros de color (server/Services/WorldBuilder.luau:150-157) | ❌ | Agrega el modelo o el BillboardGui "?" por rareza, que se actualice con el inventario. |
| 107 | Letrero de máquina bloqueada | La malla LockSign del modelo con "Requiere nivel N" (G5:108; capturas 02 y 06: "🔒 Requiere nivel 5") | BillboardGui "🔒 Nivel N" en FredokaOne 20 sobre ink (Interact.luau:319-334) | 🟡 | Texto "Requiere nivel N", o usa la parte `LockSign` del .glb (docs/ASSETS.md:14). |
| 108 | Marcador de guía (tutorial y Muéstrame) | **Chevron**: cono de 4 lados invertido #FF7BB5 que gira y sube y baja sobre el objetivo. **Flecha en el piso**: cono de 3 lados que orbita al jugador apuntando al objetivo y se oculta a menos de 14. Se apaga a menos de 12 (salvo en las máquinas) (G5:34-54) | Beam con textura de chispas desde el jugador hasta el centro de la zona (Tutorial.luau:258-311) | 🟡 | Dos Parts tipo cono (MeshPart o SpecialMesh) con las mismas animaciones. Quita el Beam. |
| 109 | Toasts del tutorial | Paso 0: "¡Bienvenido a Squishy World!" (big, 3.5s) y luego "Hagamos tu primer squishy. Sigue la flecha rosada hasta las Máquinas. 🖐️ Por el camino, mantén clic sobre los squishies **de la Vitrina Viral** para apachurrarlos." (5.5s). Paso 5: "Tu squishy ya te sigue. ¡Mantén clic encima para apachurrarlo, **o presiona F para verlo de cerca**!" (G5:597-599) | Al texto del paso 0 le falta "de la Vitrina Viral". Al del paso 5 le falta la parte de F (Tutorial.luau:321-340) | 🟡 | Copia el texto exacto (lo de F cuando exista el Estudio). |
| 110 | Toast de bienvenida al volver | "¡Bienvenido de vuelta a Squishy World!" (big) y guía a las máquinas si el tutorial va en menos de 5 (G5:705) | No existe | ❌ | Mostrarlo al entrar si `tutorial>0`. |
| 111 | Pantalla de inicio `#intro` | Pantalla completa con `radial-gradient(#fff 0, #f3ecff 45%, #d9ecf8 100%)`. `h1` "Squishy World" en Lilita **46-92px** color **pink #F7A7CD** con sombra `0 6px 0 #E57AAE`, **rotado -2°**. `#loadTxt` en 900 purpleD: "Cargando el lobby…" → "Llena squishies, colecciona los raros, apachúrralos y presúmelos." o "¡Bienvenido de vuelta! Tu progreso está guardado." (T:225-232,460-465; G5:694) | No existe | ❌ | Hazla como pantalla de carga propia (`ReplicatedFirst` + `RemoveDefaultLoadingScreen`). |
| 112 | Intro: chips de teclas y Jugar | Chips blancos (radius 11, padding 6/11, 900 13, sombra lav2): "WASD moverse", "Shift correr", "Mouse o ← → mirar", "E interactuar", "Clic sostenido = apachurrar", "Clic derecho / Q = apuntar", "F apachurrar de cerca", "I inventario", "Esc soltar mouse". Botón "**Jugar**" (btn pink big) (T:463-464) | No existe | ❌ | Igual que la fila anterior. |
| 113 | Pista de apachurrar `#sqHint` | Abajo al centro (bottom **64**), fondo blanco .94, radius 16, padding 8/14, 800 14px, sombra `0 6px 18px`. Ficha de tecla `.key` en #282D3A con texto blanco y radius 7. El dueño en `.own` #8a8fa3. Textos: "🖐️ **Mantén clic** para apachurrar · **clic derecho / Q** apuntar · [F] de cerca: **{nombre}** {dueño}" / "🎯 **Clic** para apachurrar · …" / "**Clic derecho / Q** apuntar · [F] de cerca: …" / "🎯 Apunta a cualquier squishy (el tuyo, el de tus amigos o la vitrina)" / mientras amasa: "🖐️ Mueve el mouse **a los lados** para girar · **arriba/abajo** para mover las manos por el borde · rueda = zoom" (T:239-241; G6:113-120; captura 05) | No existe (Squish.luau no tiene UI) | ❌ | Label con RichText abajo al centro que se actualice en RenderStepped con el squishy más cercano o el apuntado. Pon solo las partes que ya existan (Mantén clic) y agrega las demás cuando lleguen F y Q. |
| 114 | Punto de presión `#pressDot` | Círculo de 34px con `radial-gradient(rgba(255,143,200,.55), rgba(255,143,200,.1))`, borde **#FF8FC8 de 3px** y pulso .6s entre .8 y 1.05 (T:242-243) | No existe | ❌ | Frame circular que sigue al mouse mientras apachurras, con UIStroke #FF8FC8 y tween de escala. |
| 115 | Retícula `#reticle` | Círculo de 44 con borde blanco .9 de 3px, sombra `0 0 0 2px rgba(40,45,58,.25)` y 4 marquitas de 4x9. **lock**: borde #FF7BB5, escala 1.25 y glow. **press**: escala .7. Etiqueta `#retLabel`: nombre en 900 13 #282D3A con halo blanco y dueño en 11.5 #8a5a7a (+ " · 🕯️ encerado") (T:268-277; G6:104-107) | No existe | ❌ | Fase de "apuntar": Frame con UIStroke y 4 Frames, siguiendo al objetivo con `WorldToViewportPoint`. Anillo #FF7BB5 en el piso bajo el objetivo (G6:109-111). |
| 116 | Estudio Squish `#studio` | Pantalla completa (fondo radial #fff8fc→#fde6f2→#e7defa) con nombre (Lilita 34), rareza, estadísticas (Suavidad ●●●), modos 👆 Dedo / 🤏 Estirar / 🌀 Torcer / 💥 Golpe, cera 🕯️, botones "✋ Aplastar con la palma", "🤲 Apretar con las dos manos", "🕯️ Cera", "🔄", "Salir" y la ayuda (T:248-292,422-449) | No existe (TODO Fase 8-10, Main.client.luau:50) | ❌ | Fuera del alcance de esta fase, pero ojo con los glifos de la sección G (🤏 es Unicode 12). |
| 117 | Tour: barras de cine | `#tour .bar` arriba y abajo en #1d1a26, altura 0→**9vh** en .8s `cubic-bezier(.2,.8,.2,1)`. El HUD se desvanece en .5s (`body.cine`) (T:295-300) | No existe | ❌ | Dos Frames que crecen con tween y el HUD con fade. |
| 118 | Tour: "Saltar tour ⏭" | Arriba a la derecha (right 18, top 9vh+14), píldora blanca .88, radius 999, padding 9/16, 900 14 #282D3A, sombra `0 4px 0 rgba(0,0,0,.15)`. Aparece a los .6s. Esc, Enter o Espacio también lo saltan (T:301-302,457; G7:173) | No existe | ❌ | Botón con el mismo estilo. "⏭" (U+23ED) está en riesgo: ver G-10. |
| 119 | Tour: tarjeta `#tourCard` | Abajo a la izquierda (left 5vw, bottom 9vh+26), máximo 620, blanca .93, radius 24, padding 18/22. `.num` círculo de 48 con `linear-gradient(135deg,#FF8FC8,#B999E8)`, número Lilita 24 blanco y sombra `0 4px 0 #c46fa6`. h2 en Lilita 32 #282D3A. p en 800 16 #5b6073. Entra subiendo 24px y escalando de .97 a 1 (T:303-307; capturas 02 y 03) | No existe | ❌ | Tarjeta con UIGradient en el número y RichText para los `<b>`. |
| 120 | Tour: tarjeta grande (título y final) | Centrada, sin fondo. h2 de **44-96px blanco** con sombra `0 5px 0 #E57AAE` + glow. p en blanco de 16-22 con sombra. "SQUISHY WORLD" / "Llena, colecciona y apachurra los squishies más suaves del mundo ✨" · "Y este eres tú 👋" / "Tu aventura empieza ahora. ¡A llenar squishies!" (arriba al 24%) (T:308-311,328; G7:47,54; captura 01) | No existe | ❌ | Label grande blanco con una copia pinkD desplazada 5px. |
| 121 | Tour: textos de las tarjetas 1-6 | "Las Máquinas", "La Vitrina Viral", "La Tienda", "Tu Colección", "Los otros jugadores", "Tus retos", con los textos exactos de G7:48-53 (con `<b>`) | No existe | ❌ | Copiarlos tal cual. |
| 122 | Tour: puntos `#tourDots` | Abajo al centro. Puntos de 10px blancos .35; el activo es #FF8FC8 de 26x10 con radius 6 (T:312-314) | No existe | ❌ | 6 Frames con tween de tamaño. |
| 123 | Tour: panel "Tus retos" `#tourRetos` | A la derecha (4vw, top 9vh+60), 360 de ancho, blanco .95, radius 22. h3 "🎯 Tus retos" (Lilita 24). Filas con ícono de 20px: 📜 "Misión actual: …" · 🌈 "Rarezas" con chips de color (11px 900 blanco) separados por "›" y "El Secreto sale 1 de cada 1.000 llenados" · 🏆 "Meta: …" · 🕯️ "Extra: …" (T:315-323; G7:139-145; captura 03) | No existe | ❌ | Panel con esos emojis (todos Unicode ≤ 7, se ven bien). |
| 124 | Tour: pines del mapa `#tourPins` | Gota rotada -45° de 46px, blanca (la de "Tú" en #FF8FC8), emoji de 26px y etiqueta ink 13 900 en píldora. Rebota cada 1.6s. 🏭 Máquinas, ✨ Vitrina Viral, 🛍️ Tienda, 🏆 Colección, 🤝 Jugadores, ⭐ Tú (T:324-331; G7:150-152) | No existe | ❌ | BillboardGuis con AlwaysOnTop o Frames proyectados. |
| 125 | Temporizador de poción, moldes de oro y VIP | No existe en el original | Píldora "🧪 m:ss  🌟 xN  👑 VIP" en la barra de arriba (Hud.luau:87-94,226-247) | 🟡 | Agregado de monetización: mismo estilo de píldora oscura. **🧪 en riesgo** (G-6). Ponlo debajo de las píldoras de la derecha. |

## Glifos que salen como cuadritos

Contexto: Roblox pinta los emojis con su propia fuente de emoji, que no está al día. Por la captura del dueño, 🪙 (Emoji 13.0, 2020) sale como cuadrito, así que todo lo de **Emoji 12 en adelante** hay que tratarlo como riesgoso. Los **símbolos que no son emoji** (dingbats y figuras geométricas como ✕ ★ ☆ ● ○ ⏭) dependen de que la fuente del texto (Gotham o Fredoka) los tenga, y en general **no los tiene**. Lo seguro son los caracteres de Latin-1 y Windows-1252: `— … · × ñ á é í ó ú ¡ ¿`.

| # | Glifo | Código / versión | Dónde está en Roblox | Qué usaba el original | Reemplazo |
|---|---|---|---|---|---|
| G-1 | 🪙 | U+1FA99, Emoji 13.0 → **cuadrito (confirmado)** | Hud.luau:55 · Shop.luau:162,181,216 · Trade.luau:133,151,264,274 · shared/Config/Monetization.luau:38,73 (y MonetizationService.luau:131 lo mete en toasts) | Un círculo CSS `.coin` (T:45) en el HUD y la Tienda. En el Trade el original sí usaba 🪙 (G5:530) | `Kit.coin(size)`: Frame circular con UIGradient #fff3b8→#f4c542→#d19b1c (o PNG). En los toasts o textos que no puedan llevar imagen, escribe "monedas". En Monetization pon 💰 (Unicode 6) o un ícono de imagen. |
| G-2 | ✕ | U+2715 dingbat → **cuadrito (confirmado)** | UI/Modal.luau:93 (el botón cerrar de **todas** las ventanas) | "✕" en `.close` (T:362,377,383,388,393,400) | "×" (U+00D7, Latin-1) en 24-26px, o una X dibujada con 2 Frames rotados ±45°. |
| G-3 | Común cortado por bytes | `string.sub("Común",1,4)` = "Com"+0xC3 → **byte UTF-8 suelto (cuadrito o �)** | Machine.luau:263 (chips de probabilidad) | "Comú", "Poco", "Raro", "Épic", "Lege", "Secr" (G5:137) | Cortar con `utf8.offset` (fila 55). |
| G-4 | ★ ☆ | U+2605 / U+2606, símbolos, no están en Gotham → **riesgo alto** (☆ casi seguro sale cuadrito) | Inventory.luau:56,143,266 | ★ y ☆ en texto (G5:352,356,373) | ★ → "⭐" (U+2B50, emoji 5.1, se ve bien) o un ImageLabel de estrella. ☆ → la misma estrella en gris o contorno (ImageLabel), o el texto "Favorito" sin símbolo. |
| G-5 | ● ○ | U+25CF / U+25CB → **riesgo alto** | Shop.luau:210 (nivel de mejoras) | El original no usaba glifos: barras `.lv i` (T:157-159). Solo el Estudio usa ● (G6:437) | Frames de 7px de alto en mint y lav (fila 75). En el Estudio (futuro), círculos hechos con Frame. |
| G-6 | 🧪 | U+1F9EA, Emoji 11.0 → **riesgo medio** | Hud.luau:234 · Monetization.luau:100 | No existe (es un agregado) | "⚗️" (U+2697) también es dudoso. Mejor un ícono de imagen o "🍀" (Unicode 6), que ya se usa para la suerte. |
| G-7 | 🧈 | U+1F9C8, Emoji 12.0 → **riesgo alto** | server/Services/NpcService.luau:99 · shared/Config/NpcDefs.luau:51 (burbujas y chat) | 🧈 también (G1:166, G4:326) | Quítalo del texto de Roblox o cámbialo por "✨". |
| G-8 | 🤏 | U+1F90F, Emoji 12.0 → **riesgo alto** | (todavía no está; va en el botón "Estirar" del Estudio) | T:428, G6:473 | Cuando se porte el Estudio: un ícono de imagen o "✌️" o "👌" (Unicode 1-6). |
| G-9 | ← → | U+2190 / U+2192, flechas. No son emoji: dependen de la fuente → **verificar** | Shop.luau:202-208 ("Guarda 20 → 30"). Faltan en la ayuda y la intro | Se usan en la ayuda (T:356), la intro (T:463) y las mejoras (G5:425) | Pruébalo en Studio con GothamBold y Nunito. Si sale cuadrito: "->" o "›" (U+203A, que sí está en Windows-1252). |
| G-10 | ⏭ | U+23ED, Emoji 6.0 (dibujado como símbolo) → **riesgo medio** | (todavía no está; va en "Saltar tour ⏭") | T:457 | "»" (U+00BB, Latin-1) o "Saltar tour ›". |
| G-11 | 🫶 | U+1FAF6, Emoji 14.0 → **cuadrito seguro** | No aparece hoy en el código Roblox ni en el original | — | No lo uses. |
| G-12 | ✓ | U+2713 dingbat → **riesgo alto** | (todavía no está; es "rota ✓" en la cera del Estudio, G6:604) | G6:604 | "✅" (Unicode 6) o sin símbolo. |
| G-13 | ☁️ | U+2601+FE0F, Unicode 1.1 con presentación de emoji → probablemente se ve | shared/Config/NpcDefs.luau:30 | G1:164 | Verificar. Si falla: "💭". |
| G-14 | ⚡ 🍀 🎒 🌟 👑 💰 🏦 📖 📜 ⭐ 🤝 🛒 🔒 ✨ 🔊 🔇 👍 ✅ 🖐️ 👀 😆 💖 🙏 🐸 💕 | Emoji 1.0-9.0 → **se ven bien** | Hud, Shop, Machine, Trade, Monetization, NpcService | — | No hace falta cambiarlos por el glifo. Donde el original usaba **imágenes** (los íconos del menú lateral, fila 18) hay que usar las imágenes, no emojis. En la Tienda, quita ⚡ 🍀 🎒 (fila 76). |

---

# 03 — Sistemas de juego y flujo: original (three.js) vs port Roblox

Rutas abreviadas:
- Original: `g1` = reference/src-js/game1.js, `g4` = game4.js, `g5` = game5.js, `g6` = game6.js, `g7` = game7.js, `tpl` = template.html, `SPEC` = docs/SYSTEMS_SPEC.md
- Roblox: `sh/` = roblox/src/shared, `S/` = roblox/src/server/Services, `C/` = roblox/src/client/Controllers, `UI/` = roblox/src/client/UI

Estado: ✅ igual · 🟡 distinto · ❌ falta · ➕ extra (solo en Roblox, monetización/plataforma)

## A. Estado inicial, progresión y economía

| # | Sistema / regla | Original (números/textos exactos, archivo:línea) | Roblox ahora (archivo:línea) | Estado | Qué hacer |
|---|---|---|---|---|---|
| 1 | Estado inicial | coins 500, level 1, xp 0, fillings classic/pink/blue, molds ['butter'], upgrades {fillSpeed:1,luck:0,storage:0}, quest {i:0,p:0}, stats {fills,perfect,sold,trades,squishes,bestRise}, tutorial 0, lastMold 'cat', lastFill 'pink_foam', muted false (g4:5-15) | Igual con quest.i=1 (base 1), más waxCracked, tourSeen, tipSquish, firstDone, luckUntil, legendFills, receipts, robuxSpent, pending (sh/Logic/Profile.luau:12-39) | ✅ (+➕ campos de Robux) | Nada. **Falta `muted`** (ver #104) |
| 2 | Curva de XP | `xpNeed = 50 + (lvl-1)*30` (g4:39) | Igual (sh/Logic/Squishy.luau:135-137) | ✅ | — |
| 3 | Subir varios niveles seguidos | `while (S.xp >= xpNeed)` (g5:19-26) | Igual `while` (S/Economy.luau:107-137) | ✅ | — |
| 4 | Toast de subir de nivel | playSound('levelup') + `¡Subiste de nivel! Ahora eres nivel N` big 3200 ms (g5:21) | Igual (S/Economy.luau:117-118) | ✅ | — (pero ver #105: los sonidos no suenan) |
| 5 | Toast de molde desbloqueado | a los 900 ms `¡Nuevo molde desbloqueado: X!` big 3200 (g5:22) | `task.delay(0.9)` mismo texto (S/Economy.luau:119-125) | ✅ | — |
| 6 | Toast de máquina abierta | a los 1600 ms `¡Máquina 02 (Llenadora Brillante) ya está abierta!` big 3200 (g5:23) | `task.delay(1.6)` mismo texto (S/Economy.luau:126-132) | ✅ | — |
| 7 | Misión de nivel al subir | `questEvent('level', S.level, true)` + refreshMachineLocks (g5:24-25) | questEvent igual (S/Economy.luau:133); letreros 🔒 se actualizan con DataSync (C/Interact.luau:50-89) | ✅ | — |
| 8 | Fuentes de XP | +rarity.xp al revelar (5/10/25/80/250/1000); +1 por POP; +2 cada 15 apachurrones; +4 al quitar toda la cera en el mundo (g5:212,223; g6:37,40) | rarity.xp y POP ✅ (S/FillService.luau:158,227); +2/15 ✅ con límite 0.25 s entre apachurrones (S/InventoryService.luau:216-232); cera ❌ | 🟡 | Portar XP +4 por cera cuando exista la cera; revisar que el límite de 0.25 s no se coma apachurrones legítimos |
| 9 | addCoins | suma sin límite y hace "bump" de la píldora (g5:16) | suma con `max(0, floor())` y bump con UIScale 1.12 (S/Economy.luau:40-48; C/Hud.luau:206-214) | ✅ | — |
| 10 | Monedas ganadas (vender, misiones) | valor exacto | `earnCoins` × multiplicador (Monedas x2 / VIP +10%) (S/Economy.luau:51-55) | ➕ | Extra de monetización; sin pases da igual |
| 11 | Capacidad | `UPGRADES.storage.caps[S.upgrades.storage]` 20/30/50/75/100/150 (g4:38) | caps[storage+1] + 50 si tiene Mochila Gigante (S/InventoryService.luau:20-26) | ✅ (+➕) | — |

## B. Máquina y llenado

| # | Sistema / regla | Original | Roblox ahora | Estado | Qué hacer |
|---|---|---|---|---|---|
| 12 | Abrir máquina bloqueada | playSound('error') + toast `Llega a nivel N para usar la Máquina 0X` (g5:84) | error + toast `Máquina 0X se abre en el nivel N` (C/Machine.luau:431-435) | 🟡 | Cambiar el texto al del original |
| 13 | Texto del prompt de interacción | `Usar la Máquina Squishy` (m1) / `Usar Máquina 02`; bloqueada: `Máquina 02 — requiere nivel 5` (g5:75); `Abrir la Tienda`, `Abrir el Índice Squishy`, `Hablar con X` (g5:76-78) | ProximityPrompt `Usar` + `Máquina 01`, `Comprar`/`Tienda`, `Ver`/`Índice Squishy`, NPC `Cambiar` (E) y `Hablar` (R) (S/WorldBuilder.luau:257-261; S/NpcService.luau:157-158) | 🟡 | Poner ActionText/ObjectText con los textos exactos; mostrar "— requiere nivel N" cuando está bloqueada; un solo prompt NPC `Hablar con X` |
| 14 | Distancia de interacción | INTERACT_DIST 9; máquina medida en `m.pos+(0,0,-5)` con −1; índice −2; NPC −1.5 (g5:61-66) | MaxActivationDistance 12 en `m.pos+(0,3,-3)`; NPC 10 (S/WorldBuilder.luau:197,257; S/NpcService.luau:149) | 🟡 | Ajustar posiciones/distancias a las del original |
| 15 | Título y subtítulo del panel | `Crea un Squishy` (m1) o nombre; info `Máquina 02 · Llenadora Brillante · +15% suerte · más mutaciones` (g5:113-114) | Igual (C/Machine.luau:447,470-477) | ✅ | — |
| 16 | Encabezados del panel | `1. Elige el molde`, `✨ Moldes virales`, `2. Elige el relleno`, `3. Mantén para llenar — suelta en la zona Perfecto` (tpl:363-365) | `Moldes`, `✨ Moldes virales`, `Relleno`, `Probabilidades` (C/Machine.luau:501-506) | 🟡 | Copiar los encabezados exactos |
| 17 | Molde/relleno por defecto | molde = lastMold si disponible si no 'cat'; relleno = lastFill si lo tiene si no 'classic_foam' (g5:110-111) | Igual (C/Machine.luau:441-442) | ✅ | — |
| 18 | Override del tutorial | `if (Tut.step <= 2) { cat, pink_foam }` (g5:112) | `if d.tutorial <= 2` igual (C/Machine.luau:443-446) | ✅ | — |
| 19 | Guardar lastMold/lastFill | se guarda **al hacer clic** en el molde/relleno (g5:153,159) | se guarda solo al empezar a llenar (S/FillService.luau:127-128) | 🟡 | Guardar al elegir (o aceptar la diferencia: solo afecta si cierras sin llenar) |
| 20 | Botones de molde bloqueado | etiqueta `🛒 600` (viral) o `Nv 3`; toast `El molde X se compra en la Tienda (N monedas)` / `El molde X se desbloquea en el nivel N` + error (g5:126,152) | Igual (C/Machine.luau:155-178) | ✅ | — |
| 21 | Orden de virales | disponibles primero, luego por precio (g5:130) | Igual (C/Machine.luau:204-210) | ✅ | — |
| 22 | Relleno no comprado | ` 🔒`; toast `X se vende en la Tienda (N monedas)` + error; Misterio muestra ` (100)` (g5:133,158) | Igual; VIP muestra ` (gratis 👑)` (C/Machine.luau:218-243) | ✅ (+➕) | — |
| 23 | Barra de probabilidades | etiqueta `r.name.split(' ')[0].slice(0,4)` → `Comú`, `Poco`, `Raro`, `Épic`, `Lege`, `Secr`; % entero si tier≤2, 1 decimal si >2; tooltip con % normal y % Perfect (g5:135-137) | `string.sub(r.name,1,4)` por **bytes**: `Común`→`Com`+byte roto, `Épico`→`Épi`; `Poco común`→`Poco` ok; sin tooltip Perfect (C/Machine.luau:258-277) | 🟡 (bug UTF-8) | Usar `utf8` (p. ej. primera palabra y `utf8.offset` a 4 caracteres); agregar tooltip/hover con % Perfect |
| 24 | Medidor: zonas | 0–0.8 `#e9e4f2`, 0.8–0.9 `#9CE0CA`, 0.9–1.1252 `#ffd9a8`, 1.1252–1.16 `#ff9aa8` (g5:141) | Igual (C/Machine.luau:515-534) | ✅ | — |
| 25 | Etiquetas bajo el medidor | `Le falta`, `Perfecto` (verde #3faf86), `Se pasa`, `¡Pop!` (rojo #e0566b) (tpl:368) | `Le falta`, `Perfecto`, `Se pasa`, `¡POP!` todas grises (C/Machine.luau:555-569) | 🟡 | `¡Pop!` y colores verde/rojo |
| 26 | Texto del botón | `Llenando… ¡suelta!` mientras state==filling; si no `Mantén para llenar`; deshabilitado en processing/reveal (g5:143-144) | Cambia solo si `filling and holding` (C/Machine.luau:280-281) | 🟡 | Usar `Fill.state == "filling"` como el original |
| 27 | Inventario lleno | `Inventario lleno (N). Vende algunos squishies primero.` rojo, botón deshabilitado; holdStart → error (g5:145-146,183) | Igual (C/Machine.luau:279-287,383-386; S/FillService.luau:113-121) | ✅ | — |
| 28 | Relleno Misterio | cobra 100 al empezar; si no alcanza error + `El relleno Misterio cuesta 100 monedas por llenado` (g5:184) | Igual en servidor; gratis con VIP (S/FillService.luau:122-126) | ✅ (+➕) | — |
| 29 | Fórmula de llenado | `time = 3.2/(1+0.2(fillSpeed-1))`; `p += dt/time·(1+0.35p)` (g5:635-636) | Igual en cliente (C/Machine.luau:643-650) y servidor integra a 120 Hz (sh/Logic/Squishy.luau:158-167) | ✅ | — |
| 30 | minCommit | soltar con p<0.35 → `Sigue manteniendo…` gris y se puede volver a mantener (g5:193) | Igual; servidor conserva `held` (S/FillService.luau:162-164; C/Machine.luau:361-364) | ✅ | — |
| 31 | Umbrales | under <0.8, perfect 0.8–0.9 (incl.), over >0.9, POP ≥1.16 (g5:195,637) | Igual (sh/Logic/Squishy.luau:140-155) | ✅ | — |
| 32 | Resultado: textos/colores | `Le faltó` #7a7f92, `¡PERFECTO!` #35b889, `Se pasó` #e59a3c (g5:200) | mismos textos con Theme.muted/green/orange (C/Machine.luau:296-302) | ✅ | Verificar que los colores del Theme sean esos hex |
| 33 | Perfecto | playSound('sparkle'), stats.perfect++, questEvent('perfect') al soltar (g5:202) | Igual (S/FillService.luau:167-170; C/Machine.luau:303-305) | ✅ | — |
| 34 | Procesado | 2.1 s, playSound('whirr'), `m.shake = 2.1` (g5:203-204) | 2.1 s y 'whirr' ✅; **sin sacudida** (C/Machine.luau:306-311) | 🟡 | Ver #37 |
| 35 | POP | playSound('pop'), `cam.shake=0.35`, burst de 40 partículas color relleno, borra squishy interior, `¡POP! Se reventó — demasiado lleno.` rojo, addXP(1), stats.fills++, vuelve a idle a los 1.4 s (g5:206-214) | pop, texto, XP 1, fills, 1.4 s ✅; **sin temblor de cámara ni partículas** (C/Machine.luau:314-329; S/FillService.luau:155-161) | 🟡 | Agregar shake de cámara 0.35 s (±0.15) y ParticleEmitter burst de 40 |
| 36 | Primer llenado garantizado | si `!S.firstDone`: uncommon, variante bubblegum, mutation normal, face happy, suerte 0 (g5:218) | Igual (S/FillService.luau:173-181) | ✅ | — |
| 37 | Sacudida de la máquina | durante 2.1 s: `x = pos.x + sin(T·60)·0.12`, `rot.z = sin(T·45)·0.012`, el squishy interior gira `dt·8` (g5:644-645) | No existe | ❌ | Animar el modelo de la máquina en cliente mientras state=="processing" |
| 38 | Lámpara con color de rareza | emissive = color de rareza, intensidad 1.4; a los 3 s vuelve a `#ffe08a` 0.4 (g5:224-225) | No existe | ❌ | PointLight/Neon en la lámpara con el color de rareza 3 s |
| 39 | Líquido del tanque | `setLiquid(m, 1 - min(p,1)·0.8)`; altura `max(0.05, level·5.6)`, y=12.4+h/2; color del relleno (g5:169-173,640) | No existe | ❌ | Parte "Liquid" escalada según p y teñida con el color del relleno |
| 40 | Chorro (stream) | visible solo mientras se mantiene; color/emissive del relleno (g5:188,191,641) | No existe | ❌ | Beam/Part visible mientras `Fill.holding` |
| 41 | Squishy dentro de la cúpula | variante 'white', cara sleepy, tinte del relleno, opacidad 0.55→1 (`0.55+min(p,1)·0.45`), escala `(0.35+min(p,1.2)·0.6)·fitK` con temblor sin(T·30)·0.02 y squish(0.15) aleatorio al mantener (g5:162-170,639) | variante classic/original teñida, escala `0.35+0.65·min(1.1,p)`, sin opacidad, sin fitK ni temblor (C/Machine.luau:92-114,651-653) | 🟡 | Usar la fórmula exacta y transparencia 0.45→0 |
| 42 | Sonido de llenado | synth: sierra 90 Hz + LFO; `fillSet(p)`: freq `90+160p`, filtro `400+1600p` (g1:237-251) | loop "fillLoop" sin cambio de tono (C/Machine.luau:397; Audio.luau loop) | 🟡 | Subir PlaybackSpeed con p (≈1→2.8) |
| 43 | Cámara al abrir la máquina | `cam.override = pos (m.x+8.5, 11, m.z-17), look (m.x+4.2, 6.5, m.z)`, damp k=4 (g5:118; g4:176) | No hay (cámara normal) | ❌ | Cámara Scriptable con esos puntos y damp 4; restaurar al cerrar |
| 44 | Colocar al jugador | `player.pos = (m.x-1.5, 0, m.z-7.5)`, yaw 0 (g5:119) | No se mueve | ❌ | PivotTo del personaje al abrir |
| 45 | Mantener con Espacio | `UI.open==='machine' && k===' '` → holdStart; keyup → holdEnd (g4:94,105) | Solo el botón con mouse/dedo (C/Machine.luau:578-586) | ❌ | ContextActionService Space → holdStart/holdEnd |
| 46 | Soltar al perder foco | `blur` → holdEnd (g4:106) | MouseLeave del botón → holdEnd (C/Machine.luau:582-586) | 🟡 | Aceptable; agregar `WindowFocusReleased` |
| 47 | Cerrar durante llenado/procesado | `closeUI` no hace nada si filling/processing (g5:92) | Router bloquea con toast `Termina de llenar primero`, pero la ✕ del modal **sí cierra** y manda fillCancel (pierde los 100 del Misterio) (C/Machine.luau:452-465,629-634; UI/Modal.luau:100) | 🟡 | Que la ✕/Esc no cierren en filling/processing, sin toast (el original es silencioso) |
| 48 | Autoridad | todo en cliente | Servidor mide tiempo, valida distancia 28, nivel, molde, relleno (S/FillService.luau:79-230) | ➕ | Extra de plataforma (anti-trampa) |
| 49 | Suerte total | `upg.luck·0.06 + machine.luck + filling.luck + {perfect +0.25, under −0.15, over −0.10}`, max 0 (g4:40-44) | Igual (sh/Logic/Squishy.luau:12-23) + pase Súper Suerte +0.25 y Poción +0.5 (S/FillService.luau:61-77) | ✅ (+➕) | — |
| 50 | Pesos de rareza | `p·(1+L·[0,.5,1,1.5,2,2.5][tier])·secretX` (g4:45-47) | Igual (sh/Logic/Squishy.luau:25-36) | ✅ | — |
| 51 | Variante | viral+común → 'original'; si hay bias, 55% entre favorecidas (g4:60-61) | Igual (sh/Logic/Squishy.luau:93-107) | ✅ | — |
| 52 | Mutación | normal=p, resto `p·mutX·fil.mut[id]` (g4:63-66) | Igual (sh/Logic/Squishy.luau:108-116) | ✅ | — |
| 53 | Cara, tamaño, valor, nombre | caras happy×3/wink/sleepy/surprised; size rand(0.95,1.08) 2 dec; `round(base·mult·mutMult·size)`; nombre Especie + Variante (no 'original' viral) + Mutación (g4:67-68; g2:243-248) | Igual (sh/Logic/Squishy.luau:57-74,117-131) | ✅ | — |
| 54 | forceLegendary (debug L) | tecla L con DEBUG → siguiente llenado Legendario (g4:52,57,102) | No existe; existe el producto "Molde de Oro" (legendFills) (S/FillService.luau:182-190) | ❌ / ➕ | Agregar teclas debug K/L/R solo en Studio si se quiere paridad |
| 55 | XP y misiones del llenado | en finishFill (tras 2.1 s): stats.fills++, questEvent fill, getUncommon/Rare/Epic por tier, addXP (g5:220-223) | stats.fills al soltar; quests/XP con `task.delay(2.1)` (S/FillService.luau:205-228) | ✅ | — |

## C. Revelación, guardar/vender

| # | Sistema / regla | Original | Roblox ahora | Estado | Qué hacer |
|---|---|---|---|---|---|
| 56 | Descubrimiento | isNew calculado al revelar; `S.discovered[key]=1` y questEvent('index', total, true) (g5:264,290) | marcado al soltar en servidor; index quest tras 2.1 s (S/FillService.luau:201-203,224-226) | ✅ | — |
| 57 | Texto inicial | `Te salió…`; rareza/nombre/badges/botones ocultos (g5:266) | Igual (C/Reveal.luau:62-105) | ✅ | — |
| 58 | Retraso por rareza | 650 ms; secreto 900 ms (g5:274) | Igual (C/Reveal.luau:126) | ✅ | — |
| 59 | Texto de rareza | `¡Raro!` con color; secreto `¡SECRETO ENCONTRADO!`; animación "pop" (g5:277) | Textos iguales; sin animación pop (C/Reveal.luau:130) | 🟡 | Tween de escala en la etiqueta |
| 60 | Badges | `¡Squishy nuevo descubierto!`, nombre de mutación, `✨ Viral`, `Vale N monedas` (g5:279-282) | Igual (C/Reveal.luau:145-154) | ✅ | — |
| 61 | Botones | `Guardar` / `Vender +N`; Guardar deshabilitado si inventario lleno (g5:284-285; tpl:417) | Igual (C/Reveal.luau:162-173) | ✅ | — |
| 62 | Animación del squishy | aparece desde t=0.55 s durante 0.55 s: 0→1.15→1; base ×1.3 Gigante / ×0.7 Mini; `rot.y = sin(t·0.9)·0.5` (vaivén) (g5:306-308) | crece desde t=0 en 0.5 s con ease-out y **gira completo** `t·0.9` (C/Reveal.luau:110-121) | 🟡 | Copiar la curva y el vaivén exactos |
| 63 | Zoom Legendario | cámara `lerp(7.4, 6.2, (t−0.6)/1.2)·zk`; normal 7.2·zk (g5:269,309) | No existe | ❌ | Mover la cámara del ViewportFrame igual |
| 64 | Partículas de revelación | rare 40, epic 80, legendary 140 (confeti + estrellas), secret 120 (glitch); colores por rareza (g5:293-301) | No existe | ❌ | Partículas 2D (frames animados) con esas cantidades/colores |
| 65 | Sonidos al revelar | común reward; poco común reward+sparkle2; raro rare+sparkle; épico epic+sparkle; **legendario** fanfare + emote-yes del jugador; **secreto: ninguno** en ese momento (solo secretSting al inicio) (g5:272,287) | tier≥4 → fanfare (**también suena en secreto**); sin emote (C/Reveal.luau:204-217) | 🟡 | `tier == 4` solo; animar emote "yes" del personaje en legendario |
| 66 | Apagón del Secreto | div `.blackout` 1 s + secretSting; luego fondo del reveal con clase secret (g5:272) | todo el overlay negro fijo (C/Reveal.luau:43-47,123-125) | 🟡 | Frame negro 1 s y luego el fondo de secreto del CSS |
| 67 | Guardar | push, 'keep', toast `X guardado en tu inventario`, si tut≤3 → 4 (g5:325-329) | Igual (S/FillService.luau:239-249) | ✅ | — |
| 68 | Vender en la revelación | addCoins, stats.sold++, sonido 'coins', **sin toast**; sellDupe si ya tenía copia (g5:331-333) | igual + toast `Vendido por N monedas` (S/FillService.luau:250-265) | 🟡 | Quitar el toast para igualar |
| 69 | Rama tutorial al vender | si tut≤3: toast `Tip: ¡guarda el primero para poder equiparlo!`, regala un uncommon bubblegum, tut→4 (g5:334) | Igual (S/FillService.luau:266-277) | ✅ | — |
| 70 | endReveal | vuelve a la máquina (idle, gauge 0), `pedestalsDirty`, y **si tut==4: closeUI() (cierra la máquina) + promptEquip()** (g5:337-343) | revealDone ✅; tutorialEquip solo si se **guardó** (no al vender); no cierra la máquina; no pedestales (C/Reveal.luau:183-189) | 🟡 | Llamar tutorialEquip también tras vender, cerrar el modal de la máquina, refrescar pedestales |
| 71 | Squishy pendiente al salir | se pierde | se guarda en `pending` y se re-muestra/auto-guarda (S/FillService.luau:293-304; C/Reveal.luau:224-229) | ➕ | Extra razonable |

## D. Inventario, tienda, índice

| # | Sistema / regla | Original | Roblox ahora | Estado | Qué hacer |
|---|---|---|---|---|---|
| 72 | Orden | valor desc, luego dateFound desc (g5:354) | Igual (C/Inventory.luau:177-183) | ✅ | — |
| 73 | Pestañas/filtros | `Todos`, 6 rarezas, `★ Favoritos` (g5:351-352) | Igual (C/Inventory.luau:260-281) | ✅ | — |
| 74 | Vacío | `Nada con este filtro.` / `Aún no tienes squishies. ¡Ve a las Máquinas y llena el primero!` (g5:357) | Igual (C/Inventory.luau:191-199) | ✅ | — |
| 75 | Contador | `N/cap` junto al título (g5:353) | Igual (C/Inventory.luau:173) | ✅ | — |
| 76 | Detalle: filas | Encontrado (fecha es-CO `25 sept 2026`), Valor `N monedas`, Relleno, Tamaño `x.xx×`, Copias (g5:367-371) | Fecha `%d/%m/%Y`; resto igual (C/Inventory.luau:117-123) | 🟡 | Formatear fecha "d mmm aaaa" en español |
| 77 | Botón `🖐️ Apachurrar` | abre el Estudio con ese squishy (g5:372,375) | No existe | ❌ | Depende del Estudio Squish (fase 8) |
| 78 | Equipar | `Equipar`/`Quitar`; 'select'; toast `¡X te está siguiendo!`; tut 4→5 (g5:376) | Igual (C/Inventory.luau:137-155; S/InventoryService.luau:193-202) | ✅ | — |
| 79 | Favorito | `☆ Favorito`/`★ Quitar fav`, 'toggle' (g5:373,377) | Igual (C/Inventory.luau:142-159) | ✅ | — |
| 80 | Vender uno | `Vender por N`, deshabilitado si fav o equipado; toast `Vendido por N monedas`, 'coins', sellDupe si había >1 copia (g5:374,380-391) | Igual (S/InventoryService.luau:94-118) | ✅ | — |
| 81 | Vender repetidos | agrupa por especie\|variante, conserva la mejor (fav > equipado > valor); si no hay: toast `No tienes repetidos para vender` + error; confirm `¿Vender N repetido(s) por N monedas? Te quedas con la mejor copia de cada uno.` (g5:394-400) | Igual (S/InventoryService.luau:120-149,169-185; C/Inventory.luau:237-253) | ✅ | — |
| 82 | Pulso del botón Inventario | promptEquip agrega `.pulse` a bInv; se quita al abrir el inventario en paso 4 (g5:349,602) | No existe | ❌ | Animar el botón lateral "Inventario" en paso 4 |
| 83 | Tienda: pestañas | `✨ Moldes Virales`, `Rellenos`, `Mejoras`; por defecto `fillings` y se recuerda (g5:405,408) | Igual + `⭐ Robux` (C/Shop.luau:22-31) | ✅ (+➕) | — |
| 84 | Tienda: moldes | desc + `Slow rise Ns · súper suave/suave/firme` (≥1.2/≥1); botón `Tuyo` o precio; deshabilitado si tuyo o sin monedas (g5:410-414) | Igual (C/Shop.luau:152-171) | ✅ | — |
| 85 | Tienda: rellenos | solo price>0; desc; mismo botón (g5:416-420) | Igual (C/Shop.luau:172-191) | ✅ | — |
| 86 | Tienda: mejoras | `Guarda 20 → 30`, `+0% suerte → +6%`, `Velocidad 1 → 2`; 5 puntos; `Nivel máximo` (g5:422-428) | Igual (C/Shop.luau:192-224) | ✅ | — |
| 87 | Compras: toasts y sonidos | relleno: coins + `¡Relleno X desbloqueado!` big; molde: coins+sparkle + `¡Molde viral X desbloqueado! Úsalo en cualquier máquina.` big 3200; mejora: levelup + `¡Velocidad mejorada!` big; upFill quest (g5:434-441) | Igual (S/ShopService.luau:21-75) | ✅ | Extra: toast `No te alcanzan las monedas` si falla (C/Shop.luau:93-101) 🟡 menor |
| 88 | Índice | `N / 413` + `descubiertos — las siluetas siguen siendo un misterio`; pestañas `✨ Nombre c/total`; `???` si no; borde color rareza; por defecto 'cat'; render progresivo de 6 en 6 (g5:448-465) | Igual (pestañas verticales) (C/Index.luau:22-107) | ✅ | — |

## E. Misiones y guía

| # | Sistema / regla | Original | Roblox ahora | Estado | Qué hacer |
|---|---|---|---|---|---|
| 89 | Lista de misiones | 10 misiones (fill3, unc, dupe, speed, perfect, lvl3, rare, trade, idx15, epic) con metas/premios/targets (g1:148-159) | Igual (sh/Config/Quests.luau) | ✅ | — |
| 90 | Cadena infinita | `Llena 5+k·5 squishies`, premio 500+k·250 (g5:569-570) | Igual (sh/Logic/Quests.luau:14-23) | ✅ | — |
| 91 | questEvent + auto-completar | suma/abs; toast a los 400 ms `Misión completa: X · +N monedas` big 3200 + reward; siguiente level/index se precarga y se completa a los 600 ms (g5:572-583) | Igual (S/Economy.luau:67-105) | ✅ | — |
| 92 | Tarjeta de misión | `Misión`, título, barra, `p / goal`, `Premio: N monedas`, botón `Muéstrame` si hay target (g5:584-589; tpl:353) | `📜 MISIÓN`, `p / goal · Premio: N monedas`; **sin botón Muéstrame**; se oculta con ventanas abiertas (C/Hud.luau:151-183,201-203) | 🟡 | Agregar botón `Muéstrame` → guideTo(q.target) |
| 93 | Guía: objetivo por zona | machines = máquina 1 y=13; shop = mostrador y=9; trading = (58,10,0); collection = tablero índice y=12 (g5:38-44) | centro de la zona (y=0) (C/Tutorial.luau:16-23) | 🟡 | Usar los mismos puntos |
| 94 | Guía: chevrón + flecha en el piso | cono rosado #FF7BB5 que sube y baja (sin(t·3)·0.8) y gira (t·2); flecha en el piso a 4.2 del jugador (oscila sin(t·5)·0.4) visible si d>14 (g5:34-37,46-54) | Beam con textura de chispas del jugador a la zona, oculto si d<14 (C/Tutorial.luau:27-79) | 🟡 | Chevrón 3D sobre el objetivo + flecha de piso |
| 95 | Guía: se apaga al llegar | si d<12 y key≠'machines' → se borra el objetivo (g5:50) | Nunca se apaga sola | ❌ | Portar la regla |
| 96 | Guía a la Plaza | tecla T o botón `Cambios` → `guideTo('trading', 'Ve a la Plaza de Intercambio')` / `'Sigue la flecha hasta la Plaza de Intercambio'` (g4:100; g5:679) | T abre la Tienda; `Cambios` abre intercambio entre jugadores (C/Hud.luau:110-116) | 🟡 | Ver #118 |

## F. Tutorial (pasos 0–5)

| # | Sistema / regla | Original | Roblox ahora | Estado | Qué hacer |
|---|---|---|---|---|---|
| 97 | Paso 0: bienvenida | tras Jugar (y tour): `¡Bienvenido a Squishy World!` big 3500; a 1.2 s `Hagamos tu primer squishy. Sigue la flecha rosada hasta las Máquinas. 🖐️ Por el camino, mantén clic sobre los squishies de la Vitrina Viral para apachurrarlos.` 5500; guía a máquinas (g5:597) | Igual pero **sin "de la Vitrina Viral"** y sale al cargar datos (C/Tutorial.luau:88-99) | 🟡 | Texto exacto |
| 98 | Paso 0→1 | avanza cuando el jugador se aleja >4 de (0,0,20) (g4:155) | Pide paso 1 al instante (C/Tutorial.luau:99) | 🟡 | Avanzar al moverse >4 studs del spawn |
| 99 | Paso 3 al abrir máquina | si <3: tut=3, borra guía, toast `El molde Gato y la Espuma Rosa están listos. ¡Mantén el botón y suelta en la zona verde Perfecto!` 5000 (g5:601) | Igual (C/Machine.luau:598-605; C/Tutorial.luau:102-103) | ✅ | — |
| 100 | Paso 4: promptEquip | `¡Squishy nuevo! Ahora equípalo.` big 3200; a 1.4 s `Abre tu Inventario (I) y presiona Equipar.`; pulso en bInv (g5:602) | toasts iguales; sin pulso; solo tras Guardar (C/Tutorial.luau:112-117) | 🟡 | Ver #70 y #82 |
| 101 | Paso 5 | `Tu squishy ya te sigue. ¡Mantén clic encima para apachurrarlo, o presiona F para verlo de cerca!` 4500; a 2.8 s `Las misiones de la derecha dan monedas. ¡A jugar!`; borra guía (g5:599) | Sin `, o presiona F para verlo de cerca` (C/Tutorial.luau:104-110) | 🟡 | Texto exacto (cuando exista F) |
| 102 | Volver a entrar | `¡Bienvenido de vuelta a Squishy World!` big; si quest con target y tut<5 → guía a máquinas; si tut==4 → promptEquip (g5:705-706) | No existe (shown=-1 ignora 4) | ❌ | Portar el flujo de regreso |
| 103 | Consejo al primer apachurrón | `¡Eso! Las manos le van dando la vuelta al squishy. Mueve el mouse a los lados para guiarlas. Clic derecho = apuntar · F = de cerca.` 5200, una vez (`S.tipSquish`) (g6:233) | Campo tipSquish existe pero no se usa | ❌ | Mostrar el toast la primera vez |

## G. Audio y HUD

| # | Sistema / regla | Original | Roblox ahora | Estado | Qué hacer |
|---|---|---|---|---|---|
| 104 | Silencio (mute) | 🔊/🔇, se **guarda** en `S.muted` (g5:13,680) | Botón funciona pero no se guarda (C/Hud.luau:95-100; sh/Types.luau sin muted) | 🟡 | Guardar `muted` en el perfil |
| 105 | Archivos de sonido | 18 clips Kenney (click, open, close, reward, rare, epic, sparkle, sparkle2, glitch, keep, squish, squish2, error, select, coin, levelup, npc, toggle) + synth (squishy, pop, whirr, fanfare, secretSting, coins) (g1:192-236) | **Todos los ids vacíos → no suena nada** (sh/Config/AssetIds.luau:8-34) | ❌ | Subir los audios y pegar los rbxassetid |
| 106 | Sonido al cerrar ventana | closeUI → playSound('close') (g5:99) | Modal.close sin sonido (UI/Modal.luau:33-51) | ❌ | Audio.play("close") |
| 107 | Sonido al abrir ventana | openOverlay → 'open' (g5:89) | Cada pantalla toca "open" ✅ | ✅ | — |
| 108 | Sonido de apachurrar | synth 'squishy' (ruido + tono 420·pitch + pluck), pitch 0.6 en estatua (g1:230; g4:195) | clip squish/squish2 con pitch 0.9–1.1 (C/Squish.luau:140) | 🟡 | Hacer un clip "squishy" equivalente |
| 109 | Toasts | máx 4, 2600 ms por defecto, fade-out 400 ms (g5:5-9) | máx 4, 2600 ms, sin fade (UI/Toast.luau:29-67) | ✅ | Fade opcional |
| 110 | Píldora de nivel | `Nivel N` + `xp/need XP` (tpl:343) | `Nv N` (C/Hud.luau:63) | 🟡 | `Nivel N` |
| 111 | Barra de ayuda | `WASD moverse · Shift correr · Mouse / ← → cámara · E interactuar · Clic sostenido = apachurrar · Clic derecho / Q = apuntar · F de cerca` (tpl:356) | `E usar · Mantén clic sobre un squishy para apachurrarlo · I inventario · T tienda` (C/Hud.luau:186) | 🟡 | Texto del original (quitando lo que no aplique) |
| 112 | Pantalla de inicio | intro con `Squishy World`, `Cargando el lobby…` → `¡Bienvenido de vuelta! Tu progreso está guardado.` / `Llena squishies, colecciona los raros, apachúrralos y presúmelos.`, teclas y botón `Jugar` (g5:694-695; tpl:460-465) | No existe | ❌ | Pantalla de inicio con esos textos |
| 113 | Tour de bienvenida + botón 🎬 Tour | primera vez tras Jugar; botón Tour (g7; g5:709; tpl:350) | No existe (TODO fase 8–10) (C/../Main.client.luau:50) | ❌ | Fase pendiente |
| 114 | Menú lateral | Inventario (I), Colección (C), Tienda (B), 🎬 Tour, Cambios (T) (tpl:347-351) | Inventario, Colección, Tienda, Cambios (jugadores), ⭐ Robux (C/Hud.luau:110-116) | 🟡 (+➕) | Agregar Tour; corregir atajos |

## H. Controles

| # | Sistema / regla | Original | Roblox ahora | Estado | Qué hacer |
|---|---|---|---|---|---|
| 115 | E interactuar | tecla E → interact() + animación interact-right (g4:96; g5:81-88) | ProximityPrompt E ✅; sin animación (C/Interact.luau:19-45) | ✅ | Animación opcional |
| 116 | I inventario | `i` (g4:97) | `I` (toggle) (C/Hud.luau:136-149) | ✅ | — |
| 117 | C colección | `c` → índice (g4:98) | `C` (C/Hud.luau:112) | ✅ | — |
| 118 | B tienda / T guía a plaza | `b` → tienda; `t` → guía a la Plaza (g4:99-100) | `T` → tienda; B y guía no existen (C/Hud.luau:113) | 🟡 | B = tienda, T = guideTo('trading') con toast |
| 119 | Esc | cierra la ventana abierta (no el reveal); en input quita foco (g4:89,93) | No hay atajo Esc para cerrar | ❌ | Esc → Modal.close (respetando #47) |
| 120 | F de cerca / Q apuntar / clic derecho | F abre Estudio del squishy más cercano (<10) o toast `Acércate a un squishy (tuyo, de otro jugador o de la Vitrina Viral) y presiona F` + error; Q/clic derecho = modo apuntar (g6:320-338) | No existen | ❌ | Fases de Estudio/Apuntar |
| 121 | Moverse / correr | walk 13, run 22 con Shift, giro 12 (g1:15; g4:133-161) | Humanoid por defecto (16), sin Shift (no se cambia WalkSpeed) | 🟡 | WalkSpeed 13 y sprint 22 con Shift |
| 122 | Cámara | dist 14 (7–24 con rueda), pitch 0.28, ←/→ giran 2.2 rad/s (g1:16; g4:128,134-135) | Cámara por defecto de Roblox | 🟡 | CameraMin/MaxZoomDistance 7/24 y giro con flechas (si se busca paridad) |
| 123 | Teclas debug | K +1000, L legendario, R reset con confirm `¿Borrar todo el progreso de Squishy World?` (g4:101-103) | No existen (DEBUG=true en config) | ❌ | Solo en Studio |
| 124 | Móvil / táctil | sin controles específicos (holdBtn con pointer events funciona con dedo) | joystick de Roblox; toque para apachurrar; botón de llenar con MouseButton1Down (C/Squish.luau:168-186; C/Machine.luau:578) | ✅ (+➕) | Probar que el botón de llenado responda a toque sostenido |
| 125 | Clic fuera cierra ventana | mousedown en el fondo del overlay → closeUI (g5:102) | No | 🟡 | Opcional |

## I. NPCs, chat e intercambio

| # | Sistema / regla | Original | Roblox ahora | Estado | Qué hacer |
|---|---|---|---|---|---|
| 126 | Posición inicial | casa ± 10 (g4:234) | casa ± 8 (S/NpcService.luau:108) | 🟡 | ±10 |
| 127 | Paseo | espera inicial 1–4 s; al llegar espera 3–8 s; destino casa ± 15; velocidad 5; 25% emote (yes/interact/pick-up); si se atasca 6 s re-apunta (g4:246,259-268) | cada 3–7 s destino casa ± 10; WalkSpeed 8; sin emotes (S/NpcService.luau:119,165-174) | 🟡 | Radio ±15, espera 3–8 al llegar, velocidad 5, emotes 25% |
| 128 | Se detiene cerca del jugador | si hablando, jugador a <7 o le apachurran el squishy: se queda idle mirando al jugador (g4:254-257) | solo `stopFor` 8 s al hablar / 5 s al apachurrar; no por cercanía (S/NpcService.luau:187-199,224,236) | 🟡 | Parar y mirar al jugador si está a <7 |
| 129 | Burbujas | cada 7–15 s; solo si no está hablando, jugador a <60 y 70% de probabilidad; dura 4 s (g4:278) | cada 7–15 s, siempre (sin distancia ni 70%), 4 s (S/NpcService.luau:176-184) | 🟡 | Agregar el 70% |
| 130 | Etiqueta de nombre | visible a <70 (g4:287) | DisplayName a 60 (S/NpcService.luau:121) | 🟡 | 70 |
| 131 | Compañero del NPC: especie | índice par (0-based) → famousFav; si no 60% fav, 40% cat/bear/frog/bunny (g4:240) | par → famousFav, impar → siempre fav (S/NpcService.luau:126) | 🟡 | 60/40 |
| 132 | Compañero del NPC: rareza y relleno | rareza entre común..legendario con pesos 0.3/0.3/0.25/0.1/0.05; relleno classic/pink/cloud/honey al azar (g4:238,241) | pares forzado común; impares con la tirada normal (L=0); relleno classic_foam (S/NpcService.luau:127-128) | 🟡 | Portar pesos y rellenos |
| 133 | 1 de cada 3 encerado | `i % 3 === 1` → 1+(i%3) capas de colores al azar (g4:242) | No existe | ❌ | Con la fase de cera |
| 134 | Re-encerar a los 25 s | al quitarle toda la cera: `¡Le quitaste toda la cera! 😂 Ahorita le echo más`; a los 25 s 1–3 capas y `Listo, le eché N capa(s) de cera 🕯️ ¡Rómpela!` (g6:41-44,672) | No existe | ❌ | Con la fase de cera |
| 135 | Compañero del NPC: seguir | lado 2.8, damp 4, salto `|sin(t·5+yaw)|·0.3` (g4:272-274) | mismo seguimiento que el jugador (offset 3.2, lerp 5, hop 0.45) (C/Companion.luau:122-143) | 🟡 | Parámetros propios para NPC |
| 136 | Reacción al apachurrar su squishy | `NPC_SQUISH_LINES` (7 frases: `¡Jajaja, qué suave!`, `Oye, ¡ese es mío! 😆`…) o `NPC_WAX_LINES` si tiene cera; burbuja 3.5 s; cooldown 9 s; emote yes/interact (g6:9-10,32-36) | 4 frases propias (`¡Oye, con cuidado! 😆`…), 3.5 s, sin emote, cooldown por busyUntil (S/NpcService.luau:231-245) | 🟡 | Usar las 7 frases originales, cooldown 9 s y emote |
| 137 | Ventana de chat | `Hablar con X` abre panel: avatar, nombre, `Presumiendo: <squishy> · <rareza>`, saludo al azar (`¡Holi! Soy X 👋` / `¡Hola! ¡Mucho gusto!` / `¡Ey! ¿Quieres ver mi X? Puedes apachurrarlo 😄`), log, input `Escribe algo…` (140), `Enviar`, nota IA/offline, botones `🖐️ Apachurrar` y `Cambiar` (g5:471-502; tpl:392-397) | No hay ventana: `Hablar` (R) hace que el NPC diga una frase al azar en burbuja 6 s (S/NpcService.luau:219-229; C/Interact.luau:39-41) | ❌ | Portar el panel de chat completo (TextBox + log) |
| 138 | Nota de modo | `Los jugadores de aquí funcionan con Claude: chatea, pide tips o negocia.` / `Chat en modo offline (respuestas predefinidas).` / al negar: `Chat con IA apagado (sin permiso). Usando respuestas predefinidas.` (g5:476,489) | No existe | ❌ | Con el panel |
| 139 | IA (Claude) | prompt con persona/juego/colección, JSON {say, emote, wantsTrade}, 30 palabras, reglas de seguridad (g4:305-318) | No (fase 6, proxy) | ❌ | Pendiente (o dejar solo scriptedReply) |
| 140 | scriptedReply: idioma | inglés si contiene `hi|hello|hey|trade|want|how|what|you|your|the|is|are|thanks` y **no** tiene `ñáéíóú¿¡` (g4:321) | No hay detección (ignora el texto) (S/NpcService.luau:91-104) | ❌ | Portar tal cual |
| 141 | scriptedReply: reglas por palabra | `trade|cambi|interc` → `¡Dale! Muéstrame qué tienes 👀` (yes, wantsTrade); `aplast|apachurr|squish|slow|suav|sube` → tip de apachurrar; `mantequilla|butter|viral|famos` → Mantequilla; `perfect|tip|how|consejo|truco|cómo|como` → `Truco: suelta justo en la zona verde Perfect, ¡te sube la suerte!`; `legend|secret|secreto` → `…el relleno Mystery ayuda un poquito ✨`; fav → `¡Los X son mis favoritos! ¿Tienes alguno?` (wantsTrade); resto: 4 frases al azar, wantsTrade 30% (g4:324-331) | elige al azar entre 8 frases sin mirar lo escrito; texto `Misterio` en vez de `Mystery` (S/NpcService.luau:91-104) | ❌ | Portar reglas y textos exactos |
| 142 | Respuesta: efectos | recorta a 220; burbuja 5 s; 'npc' vol 0.35; emote yes/no/wave; `escribiendo…` mientras espera (g5:480,492-497) | burbuja 6 s, 'npc' (S/NpcService.luau:226-227) | 🟡 | 5 s, emotes, indicador |
| 143 | wantsTrade | **no abre el intercambio**: hace pulsar el botón `Cambiar` 4 s (g5:496) | No existe | ❌ | Pulso del botón Cambiar |
| 144 | Entrada al intercambio | desde el chat con `Cambiar` (g5:501) | prompt `Cambiar` (E) directo en el NPC (S/NpcService.luau:157) | 🟡 | Entrar desde el panel de chat |
| 145 | NPC quieto durante el intercambio | `n.talking = true` hasta cerrar (g5:509,97) | No se detiene durante el intercambio | ❌ | stopFor mientras la sesión npcTrade esté abierta |
| 146 | Intercambio: títulos y botones | `Cambio con X`, `Tu oferta`/`Su oferta` con valor `N 🪙`, `Elige hasta 3 squishies`, `Medidor del trato`, `Pedir otra cosa`, `Cancelar`, `Aceptar`, slots `Vacío` / `Esperando tu oferta…` (tpl:400-407; g5:528-530) | `Intercambio con X`, `Tu oferta`, `X ofrece`, `¿Y otro? (N)`, `Proponer cambio`; sin `Esperando tu oferta…`, sin `Cancelar` (C/Trade.luau:112-192) | 🟡 | Copiar textos exactos |
| 147 | Mensaje inicial | `Elige lo que quieres ofrecer.` o `¡Todavía no tienes nada para cambiar!` si inventario vacío (g5:510) | solo el primero (C/Trade.luau:119) | 🟡 | Agregar el caso vacío |
| 148 | Algoritmo de oferta | target = myVal·rand(0.85,1.35); 60 intentos; rareza peso 1 si `|ln(20·mult/target)|<1.6` si no 0.02; especie 50% fav / 50% cualquiera; classic_foam, L=0; la más cercana (g5:513-524) | Igual (S/TradeService.luau:91-131) | ✅ | — |
| 149 | Elegir ofertas | máx 3, equipado excluido, sin equipado → `No tienes squishies para ofrecer (el equipado se queda contigo).`; exceso → error; click → re-oferta + `X: "¿Qué tal mi Y?"` (g5:534-544) | Igual (C/Trade.luau:60-99; S/TradeService.luau:170-178) | ✅ | — |
| 150 | Pedir otra | máx 3 (deshabilitado sin ofertas); 'select'; `X: "Bueno, ¿y este?"` (g5:537,546) | Igual (S/TradeService.luau:179-185; C/Trade.luau:193-204) | ✅ | — |
| 151 | Medidor y pistas | ancho ratio/1.5; ≥1.15 `#FFC83A` `Súper trato para ellos: van a decir que sí.`; ≥0.8 `#9CE0CA` `Cambio justo: seguramente aceptan.`; si no `#ff9aa8` `Quieren más. Agrega otro squishy.` (g5:531-533) | Igual (C/Trade.luau:157-179) | ✅ | — |
| 152 | Aceptar | acepta si myVal ≥ 0.8·theirVal; nuevo id/fecha; `Nuevo en tu Índice: X`; trades++, quest trade + index; reward+coins; emote yes; burbuja `¡Trato hecho! 🤝`/`¡Un gusto cambiar contigo!`/`GG, ¡buen cambio!`; toast `¡Intercambio listo! Recibiste X` big; pedestales; cierra (g5:547-557) | Igual salvo emote y pedestales (S/TradeService.luau:186-217) | 🟡 | Emote yes; refrescar pedestales |
| 153 | Rechazo | error + emote no + `X: "Mmm, eso no alcanza para mi Y."` (g5:559) | mismo texto + error; además burbuja `Mmm…`; sin emote (S/TradeService.luau:197-200; C/Trade.luau:212-216) | 🟡 | Quitar burbuja extra, agregar emote no |
| 154 | Intercambio entre jugadores reales | no existe | solicitud, sala, hasta 6, Listo + Confirmar (S/TradeService.luau:225-464; C/Trade.luau:236-451) | ➕ | Extra de plataforma (SPEC §5 lo pide) |

## J. Compañero, pedestales, apachurrar, bucle principal

| # | Sistema / regla | Original | Roblox ahora | Estado | Qué hacer |
|---|---|---|---|---|---|
| 155 | Compañero: posición | lado `(-cos yaw, 0, sin yaw)·3.2` + atrás 1.6 (g4:212-214) | `root.CFrame * (3.2·0.55, 0, 3.2)` = 1.76 al lado, 3.2 atrás (C/Companion.luau:128) | 🟡 | offset lado 3.2 y atrás 1.6 |
| 156 | Compañero: suavizado | damp k=5 en x/z (g4:216) | damp 5 (C/Companion.luau:131) | ✅ | — |
| 157 | Compañero: salto | si velocidad>3: `|sin(t·9)|·0.6` caminando, `|sin(t·13)|·1.1` corriendo; quieto: `sin(t·4)·0.08+0.08` (g4:218) | moviendo `|sin(t·9)|·0.45`; quieto respiración de escala (C/Companion.luau:136-140) | 🟡 | Fórmula exacta |
| 158 | Compañero: hacia dónde mira | dirección de movimiento; quieto mira a la cámara; giro dt·6 (g4:220-221) | copia el yaw del dueño (C/Companion.luau:132-135) | 🟡 | Portar |
| 159 | Compañero: escala | ×0.95 (g4:204) | ×1 | 🟡 | ×0.95 |
| 160 | Compañero quieto al apachurrarlo | `heldBy` → no se mueve (g4:211) | `Companion.frozen` (C/Companion.luau:127) | ✅ | — |
| 161 | Pedestales de la Colección | por rareza el de **mayor valor** del inventario, escala 1.1·min(1, 2.4/max(h, 0.9w)), gira dt·0.6, apachurrable ('Tu colección'); si no hay: holograma `?` color rareza flotando (sin(T·2)·0.2) (g5:608-623,651) | Solo cilindros de color; no muestran squishies (S/WorldBuilder.luau:149-158) | ❌ | Cliente que refresque pedestales cuando cambie el inventario |
| 162 | Qué se puede apachurrar | todos los clickables: compañero, NPCs, estatua (pitch 0.6), pedestales, Vitrina Viral, a <34 (g6:11-13) | solo carpeta Companions (jugadores y NPC) (C/Squish.luau:99-126) | 🟡 | Incluir estatua, vitrina y pedestales |
| 163 | Guardado | debounce 0.4 s en localStorage tras cada cambio (g4:36; g5:654) | DataStore cada 60 s + al salir + tras compras/intercambios (S/DataService.luau:19,351-360) | ➕ | Plataforma; aceptable |
| 164 | Carga/migración | species/variant desconocidos → cat/classic, renombra; molds incluye butter (g4:22-34) | Igual (sh/Logic/Profile.luau:42-77) | ✅ | — |
| 165 | Reset | debug R o resetGame() (g4:35) | No existe | ❌ | Acción de reset solo en Studio |
| 166 | Posición al volver | con save y tut≥1 aparece en (0,0,18); si no (0,0,20) (g4:83; g5:690) | siempre spawn (0,0,20) (sh/Config/WorldLayout.luau:7) | 🟡 | Menor |
| 167 | Calidad adaptativa | si <45 FPS en 3 s: pixelRatio×0.75 → sombras 1024 → 0.75 (g5:659-672) | Roblox lo maneja solo | ✅ (N/A) | — |
| 168 | Shake de cámara general | `cam.shake` suma ±0.15 aleatorio (g4:180) | No existe | ❌ | Ver #35 |
| 169 | Monetización (resumen extra) | — | Pases: Monedas x2 (199), Súper Suerte +0.25 (349), Mochila Gigante +50 (149), VIP (399: Misterio gratis, +10% monedas); productos: monedas 2.500/12.000/60.000, Poción de Suerte +0.5 15 min, Molde de Oro (llenado Legendario); pestaña ⭐ Robux, botón ⭐ Robux, píldora de boosts (sh/Config/Monetization.luau; S/MonetizationService.luau; C/Shop.luau:225-262; C/Hud.luau:226-247) | ➕ | Extra a propósito |

---

# 04 — Auditoría VISUAL: squishies, espuma, apachurrar, apuntar, fantasma, Estudio, cera, tour, audio, partículas

Original = `reference/src-js/*.js` (líneas `archivo:línea`). Roblox = `roblox/src/...`.
Excepción aceptada por el dueño: personajes = avatares Roblox, y las "manos" que apachurran = brazos del avatar (no las manitos kawaii). Todo lo demás debe ser idéntico.

Resumen del estado de Roblox: el squishy es un **placeholder** (bola + 2 ojos + barrita de boca) salvo que se hayan importado a mano los GLB a `ReplicatedStorage.Models.Squishies.<id>` (el código lo soporta, pero no hay forma de verificarlo desde el repo). **No existen** en el código: caras por tipo, deformación de espuma (solo squash por escala), apuntar, fantasma, Estudio Squish, cera, tour, bucle de espuma, partículas/bursts ni efectos de revelación (`Main.client.luau:49-50` lo marca como TODO Fase 7-10).

Leyenda: ✅ igual · 🟡 distinto · ❌ falta · 🔁 reemplazado a propósito

## A. Especies: forma del cuerpo (placeholder vs original vs GLB)

Placeholder Roblox (`Engine/SquishyFactory.luau:89-122`): esfera `SpecialMesh` 2.2×1.8×2.2 (virales 2.3×1.6×2.3), 2 ojos esfera #282D3A en x=±0.38 y=0.12, "boca" = barra 0.3×0.08×0.1 #E57AAE, orejas-bola para cat/bear/bunny. Sin mejillas, sin brillo en los ojos, sin cola.
GLB (`assets/squishies/squishy_<id>.glb`): nodos `Body` + `Part_n` (+ `Base_n` que no se deforman), con UV y la cara "happy" horneada. `SquishyFactory.build` los usa si existen (`:66-74`, `:222-230`).

| # | Elemento | Original (números exactos, archivo:línea) | Roblox ahora | Estado | Qué hacer |
|---|---|---|---|---|---|
| 1 | Cuerpo base de animales | Esfera 40×28 deformada: `y<-0.5 → y=-0.5+(y+0.5)·0.35` (base plana de mochi), escala por especie, base gordita `×(1+0.06·max(0,-y))` en x/z (game2.js:40-60) | Bola SpecialMesh sin base plana | 🟡 | Importar los GLB (Body 1 189 vértices); el placeholder solo sirve de respaldo |
| 2 | Gato (cat) | sx/sy/sz 1.08/0.92/1.0; 2 orejas cono r0.3 h0.5 en (±0.5,0.8,-0.05) rot z ∓0.38 + interior rosa #FFB8CF cono 0.17×0.3; cola toroide 0.28/0.07 arco 1.1π en (0.55,-0.15,-0.8) (game2.js:43-45,129-134) | Bola + 2 orejas-bola 0.55×0.55×0.4 del color del cuerpo, sin interior rosa, sin cola | ❌ (placeholder) / ✅ si GLB `squishy_cat.glb` (13 mallas, h 1.78 w 2.21) | Importar GLB; verificar que `Part_n` (orejas/cola) se tiñan con la variante (hoy solo se tiñe `Body`, ver fila 32) |
| 3 | Oso (bear) | 1.1/0.96/1.02; orejas bola (0.3,0.3,0.2) en (±0.64,0.7,-0.05) + interior accent (0.17,0.17,0.1); hocico accent (0.3,0.22,0.2) en (0,-0.15,0.93); nariz #1f1b24 (0.09,0.065,0.06) en (0,-0.08,1.1); colita (0.16) en (0,-0.3,-0.98); eyeY 0.16; boca en y -0.3 (game2.js:135-138,171-173) | Bola + orejas-bola; sin hocico, nariz, cola ni interior de oreja | ❌ / ✅ GLB (15 mallas) | Importar GLB; `accent` (mint `#fff`) y hocico deben recolorearse (fila 33) |
| 4 | Rana (frog) | 1.28/0.76/1.06; bultos de ojos bola (0.34,0.3,0.3) en (±0.46,0.6,0.18); ojo ×1.25 en (±0.46,0.64,0.44); brillo en (±0.46+0.05,0.71,0.58); cara "frog": sonrisa ancha toroide r0.2 + mejillas en ±0.62 (game2.js:139-145,175-178) | Bola genérica con ojos al frente, sin bultos | ❌ / ✅ GLB (10 mallas) | Importar GLB |
| 5 | Conejo (bunny) | 1.0/0.98/0.98; orejas bola (0.2,0.62,0.13) en (±0.3,1.35,-0.05) rot z ∓0.14 + interior rosa (0.11,0.46,0.06); cola blanca #ffffff rough 0.9 (0.22) en (0,-0.25,-0.98) (game2.js:146-151) | Bola + orejas 0.4×1.1×0.3 en ±0.6 | 🟡 / ✅ GLB (h 2.66) | Importar GLB; cola blanca NO se debe teñir |
| 6 | Blob | 0.98/1.0/0.98 + punta: `y>0: y·=1+0.45y², xz·=1-0.38y²`; rizo toroide 0.16/0.07 arco 1.5π en (0.06,1.48,0) rot z 0.6; eyeY 0.18 eyeX 0.28 (game2.js:50,152-154) | Bola redonda, sin punta ni rizo | ❌ / ✅ GLB (h 2.48) | Importar GLB |
| 7 | Mantequilla (butter) | Superelipsoide 1.2×0.62×0.78 p0.3 en y0.62; papel dorado #E9C766 metal 0.5 (0.44 ancho) en x0.84; banda azul #4F86E8 en x0.5; rizo toroide accent 0.17/0.075 arco 1.55π en (-0.5,1.3,0.05); cara en (-0.32,0.66) escala 1.0 (game2b.js:101-108). rise 7.5 soft 1.15 (game1.js:47) | Bola 2.3×1.6×2.3 | ❌ / ✅ GLB (Body **4 374** vért.) | Importar GLB y **decimar Body a ≤1 500** antes de deformar (ASSETS.md) |
| 8 | Tostada (toast) | Superelipsoide 1.0×0.98×0.3 p[0.42,0.5,0.35] con copete `y+=0.1t³`; **colores por vértice** corteza #C98B4E → miga #F8E1AE; cuadrito de mantequilla #FFE38F en (0.22,1.42,0.33) rot 0.18 (game2b.js:109-121) | Bola | ❌ / 🟡 GLB (trae COLOR_0; Roblox no pinta colores por vértice del importador) | Hornear corteza/miga a textura en Blender o pintar con EditableMesh; decimar (4 374) |
| 9 | Queso (cheese) | Cuña 1.25×0.62×0.95 p0.28 con taper `0.2+0.8·(oz+1)/2`; 11 huecos (seed 21) hundidos 16% y oscurecidos por vértice `[sh,sh·0.96,sh·0.85]` (game2b.js:122-135) | Bola | ❌ / 🟡 GLB (COLOR_0 perdido) | Igual que tostada: hornear sombreado de huecos a textura; decimar |
| 10 | Fresa (strawberry) | Perfil en gota (t<0.72: `(t/0.72)^0.62`), textura `strawberry`; 7 hojas cono 0.16×0.6 #5BBF6A en y2.1; tallo #4E9A4C (game2b.js:136-147) | Bola | ❌ / ✅ GLB (trae imagen) | Importar GLB; subir `tex_strawberry.png` |
| 11 | Cubo de hielo (icecube) | Cubo redondeado 0.95 p0.22, opacity 0.72 rough 0.06 #BFF0FF; 6 burbujas blancas opacity 0.55 (seed 33) (game2b.js:148-154, game1.js:51) | Bola Glass transp 0.28 | ❌ / ✅ GLB (4 374) | Importar + decimar |
| 12 | Huevo frito (egg) | Clara 1.35×0.15×1.15 ondulada `1+0.09sin(5a+0.5)+0.06sin(3a+2)`; yema #FFB320 0.56×0.44 en (0.12,0.26,0.08); cara en la yema escala 0.62 (game2b.js:155-163) | Bola | ❌ / ✅ GLB | Importar |
| 13 | Dumpling | 1.15×0.78 con 11 pliegues `0.07sin(11a)`; vaporera de bambú (cilindro 1.52/1.48 h0.46 #D8B06A, 2 aros #B8893F, piso #C99A52) **noDeform** (game2b.js:164-177) | Bola | ❌ / ✅ GLB (`Base_0..3`) | Importar; `Base_n` NO deforman |
| 14 | Dango | Palito #D6AE77 h3.05 (noDeform); 3 bolas 0.52×0.47: verde #B6E3A0 y0.72, **main** y1.64, rosa #FFB3C7 y2.56 (game2b.js:178-186) | Bola | ❌ / ✅ GLB (Body = bola del medio) | Importar |
| 15 | Rana en el pozo (frogwell) | Cuerpo 1.0×0.78×0.92; bultos de ojo **main**; panza #E3F6CF; pozo 2×12 piedras 0.64×0.34×0.36 en 3 tonos, radio 1.3 (noDeform); cara 'frog' (game2b.js:187-203) | Bola | ❌ / 🟡 GLB (bultos `Part_n` no se tiñen) | Importar; marcar bultos con `TintWithBody` |
| 16 | Dona (donut) | Masa toroide 0.75/0.42 #E3A86A; glaseado **main** con borde ondulado `-0.02+0.09sin(7u)+0.05sin(13u+1)`; 26 chispitas 6 colores (seed 41) (game2b.js:204-224) | Bola | ❌ / ✅ GLB (35 mallas) | Importar |
| 17 | Uvas (grapes) | **9 uvas todas `main`** (radios 0.5/0.4); tallo #7A5A3A; hoja #78C267 (game2b.js:225-234) | Bola | ❌ / 🟡 GLB: `Body` = 1 sola uva (609 vért.), las otras 8 son `Part_n` y no se recolorean | Marcar las 8 uvas `TintWithBody` (y deformarlas también) |
| 18 | Hamburguesa (burger) | Pan abajo #E2A459, carne #6E4129, queso #FFC53A girado 45°, lechuga #86CF57 ondulada, pan arriba **main** con textura `sesame` (game2b.js:235-243) | Bola | ❌ / ✅ GLB (trae imagen) | Importar; subir `tex_sesame.png` |
| 19 | Pata de gato (catpaw) | Cuerpo 1.1×0.62×1.0 base plana; 4 deditos rosa #FF9EC4 + almohadilla; **sin cara** (game2b.js:244-252) | Bola con ojos | ❌ / ✅ GLB | Importar; el placeholder no debería ponerle ojos |
| 20 | Estatua de la plaza | `buildSquishy(cat, pink, happy)` escala 3.4 en (0,6.25,0), apachurrable (pitch 0.6) (game3.js:195-198) | `Part` Ball 7×6×7 #FFE38F sin cara, no es squishy (`server/Services/WorldBuilder.luau:91-97`) | ❌ | Construir con `SquishyFactory.build({species="cat",variant="pink"}, 3.4)` y hacerlo apachurrable |
| 21 | Vitrina Viral | 13 virales `original` sobre pedestales, apachurrables, ownerLabel "Vitrina Viral" (game3.js:385) | Solo pedestales (`WorldBuilder.luau:174-177`), sin squishies | ❌ | Poner los 13 modelos en `WorldLayout.vitrina` y meterlos en la lista de objetivos |

## B. Caras kawaii (por tipo de cara)

| # | Elemento | Original | Roblox ahora | Estado | Qué hacer |
|---|---|---|---|---|---|
| 22 | Ojo | Esfera r0.13 #1f1b24 rough 0.18, escala (1,1.12,0.6), sobre la superficie en (±eyeX, eyeY) = (±0.32, 0.08) (game2.js:62,77,165) | Esfera 0.22×0.26×0.22 #282D3A | 🟡 | Usar la cara del GLB o replicar tamaños/color |
| 23 | Brillo del ojo | Esfera r0.045 blanca en (x+0.045, y+0.06) (game2.js:63,166) | No hay | ❌ | Agregar (viene en GLB) |
| 24 | Mejillas (blush) | Círculo r0.11 #ff8fb1 opacity 0.55 en (±(eyeX+0.17), eyeY-0.17) (game2.js:64,79,168) | No hay | ❌ | Agregar (viene en GLB) |
| 25 | Cara `happy` (×3 de probabilidad) | Sonrisa toroide r0.075 tubo 0.022 arco π, #3a2630, en y = eyeY-0.14 (oso: y -0.3) (game2.js:65,170-174) | Barra rosa #E57AAE | 🟡 | GLB trae happy; en placeholder cambiar a arco oscuro |
| 26 | Cara `wink` | Ojo derecho (s=1) reemplazado por párpado toroide r0.09 girado π (game2.js:162-163) | No existe (se ignora `data.face`) | ❌ | Tener piezas de ojo abierto/párpado y cambiarlas según `face` (el GLB solo trae happy) |
| 27 | Cara `sleepy` | Ambos ojos = párpados (game2.js:162) | No existe | ❌ | Igual que wink |
| 28 | Cara `surprised` | Boca "O" toroide r0.045 tubo 0.02 sin girar (game2.js:68,170-172) | No existe | ❌ | Pieza de boca O intercambiable |
| 29 | Cara `frog` | Sonrisa ancha r0.2 + mejillas en ±0.62; se usa en rana y frogwell SIN importar `data.face` (game2.js:176-177, game2b.js:86-89) | No existe | ❌ / ✅ GLB | Mantener regla: rana ignora el tipo de cara |
| 30 | Cara en virales (`placeFace`) | Raycast a la superficie real, escala por molde (butter 1.0, egg 0.62, dango 0.8, donut 0.72, grapes 0.75…), ojos en ±0.28, mejillas ±0.45 (game2b.js:73-97) | Ojos fijos al frente de la bola | ❌ / 🟡 GLB (solo happy) | Igual que 26-28, por molde |
| 31 | Silueta del Índice ("???") | Material único #c9c3d8, sin cara ni extras (game2.js:84,158,182) | Todas las partes #C9C4D8, borra luces/sparkles/highlight (`Thumb.luau:18-30`), pero la cara (`Part_eye`, etc.) queda visible pintada de gris | 🟡 | Ocultar piezas de cara/extras en modo silueta |

## C. Variantes (look del cuerpo) y extras

`SquishyFactory.look` (`:39-64`) mapea: m≥0.5 → Foil; e≥0.5 → Neon; opacity → Glass con transparencia `clamp(1-opacity,0,0.6)`; `r` (rugosidad) se ignora; `e>0` añade `PointLight` (rango 6, brillo 1.2). Texturas: `AssetIds.textures.*` están **todas vacías** → se usa `TEX_COLOR`.

| # | Elemento | Original | Roblox ahora | Estado | Qué hacer |
|---|---|---|---|---|---|
| 32 | Recolor de variante en virales | Se cambia `c.main` → todas las piezas que lo usan (uvas ×9, bultos de frogwell, pan de arriba, glaseado…) + `accent = lighter(c,0.35)` (game2b.js:255-260) | Solo `Body` + partes con `TintWithBody` (que solo pone el placeholder) (`SquishyFactory.luau:144-157`) | 🟡 | En Studio marcar con atributo `TintWithBody` cada `Part_n` que en el original usa `main`; `TintWithAccent` para accent |
| 33 | Color `accent` | `look.accent` o `lighter(c,0.5)` en orejas internas/hocico del oso; mint usa `#fff` (game2.js:114-115) | No existe | ❌ | Recolorear partes accent |
| 34 | Variantes comunes (8) | classic #F3E3CC, pink #F7A7CD, blue #8BC7E8, yellow #F4D982, green #A6DB8E, purple #B999E8, orange #F8B27C, white #F8F6F2, rough 0.55 (game1.js:66-71, game2.js:87) | Mismos hex, SmoothPlastic | ✅ | — |
| 35 | Rugosidad `r` | Chicle `r 0.38`, Nube `r 0.95`, Hielo `r 0.12`, Miel `r 0.22`, Oro `r 0.26`, Vacío `r 0.3` (game1.js:74-97) | Rugosidad ignorada (todo SmoothPlastic/Foil/Glass) | 🟡 | `SurfaceAppearance` o `MaterialVariant` con roughness equivalente |
| 36 | Texturas de variante | 12: seeds, melon, drizzle, cotton, galaxy, lava, rainbow, stars, glitch, checker, strawberry, sesame; canvas 256×128, color del material a blanco cuando hay tex (game2.js:14-36,88; game2b.js:5-14) | `AssetIds.textures` vacío → color plano de `TEX_COLOR`; además `body.Color` = color de la variante (no blanco) | ❌ | Subir `assets/textures/tex_*.png`, pegar ids; con textura poner Color blanco |
| 37 | Color de respaldo de texturas | melon base verde #7BCB6A (franja roja abajo); glitch base #20202a; checker #FF00DC/#111; lava #2b1a1a (game2.js:17-35) | `TEX_COLOR`: melon #FF6F7D, glitch #8A5CFF, checker #E0E0E0, lava #FF5A1F (`SquishyFactory.luau:14-27`) | 🟡 | Solo importa mientras no haya texturas; alinear o subir texturas |
| 38 | Emisivo `e` | `emissive = c`, intensidad `e·0.6` (con textura: emissiveMap, `e·0.7`) — neón 0.85, galaxia 0.55, lava 1, celestial 0.35, glitch 0.4, dev 0.15 (game2.js:89) | e≥0.5 → material Neon (tapa la textura); e<0.5 → solo PointLight que ilumina el entorno | 🟡 | SurfaceAppearance con `EmissiveMaskContent`/ `Emissive` (nuevo) o Neon solo para `neon`; no usar Neon con textura |
| 39 | Transparencia | ice 0.86, crystal 0.74, icecube 0.72 → `opacity` (game2.js:90) | Glass + transparencia 0.14/0.26/0.28 | 🟡 | Aceptable; Glass cambia refracción — preferir SmoothPlastic + Transparency |
| 40 | Metal | golden m0.8 (Foil); crystal m0.1 | Foil para golden; crystal ignorado | 🟡 | SurfaceAppearance metalness |
| 41 | Cristal `flat: true` | Icosaedro detalle 2 con flatShading (look facetado) (game2.js:46,87) | Cuerpo liso | ❌ | Malla facetada alterna para `crystal` |
| 42 | Anim `neon` | `emissive.setHSL((t·0.15)%1, 0.9, 0.55)` cada frame (game2.js:225) | No existe | ❌ | Ciclar `Color` HSV en RenderStepped (solo squishies visibles) |
| 43 | Anim `glitch` | cada `rand(0.05,0.4)` s: 30% salto x ±0.08, offset de textura aleatorio, emisivo 1.2 (20%) o 0.3 (game2.js:226) | No existe | ❌ | Offset de pivote + `Texture`/UV offset o cambio de color |
| 44 | Extra `halo` | Toroide R0.55 tubo 0.05 #FFE38A (basic), horizontal, y = sy+0.55 (conejo +1.1; virales `dims.h+0.35`), gira `rot.z += dt` (1 rad/s) (game2.js:74,82,186,194,227) | Cilindro **Neon macizo** (disco, no anillo) Ø size.X·0.55 #FFD86B a size.Y·0.62, quieto (`:166-174`) | 🟡 | Anillo (mesh toroide o 2 cilindros), color #FFE38A, altura exacta y giro 1 rad/s |
| 45 | Extra `aura` | Copia del cuerpo ×1.14, #7B3CFF opacity 0.28, BackSide; **solo animales** (game2.js:83,187) | `Highlight` fill #8A5CFF transp 0.8 + contorno #B999E8; también en virales | 🟡 | Clonar Body ×1.14 transp 0.72 color #7B3CFF; no aplicar a virales |
| 46 | Extra `puffs` (Nube) | 7 bolas blancas rough 1 escala (0.3,0.22,0.3) en radio 0.95/0.9, y -0.42; solo animales (game2.js:185) | 3 bolas 0.6–0.8 en ángulos i·2.1 a -0.3·h; también virales | 🟡 | 7 bolas con números exactos |
| 47 | Topper `leaf` (Fresa) | 5 conos r0.12 h0.34 #5BBF6A en círculo r0.12 arriba (y=sy+0.02), inclinados 1.2 rad; solo animales (game2.js:183) | 1 placa 0.9×0.12×0.5 #5CC46C | 🟡 | 5 conos |
| 48 | Topper `drip` (Miel) | 6 gotas (0.12,0.2,0.12) #FFB21E rough 0.15 en radio 0.7, y 0.45 (game2.js:184) | 1 disco aplanado #F2B33D Glass | 🟡 | 6 gotas |
| 49 | Toppers/extras en virales | puffs/leaf/drip/aura solo en animales; en virales solo halo (game2.js:181-195) | Se aplican a todos | 🟡 | Condicionar por `sp.famous` |
| 50 | Variante `original` de virales | `Object.assign({id:'original'}, spd.orig)` (game2.js:109) | GLB importado: no se toca; placeholder: usa `sp.orig` | ✅ | — |

## D. Mutaciones, chispitas y tamaño

| # | Elemento | Original | Roblox ahora | Estado | Qué hacer |
|---|---|---|---|---|---|
| 51 | Shiny material | `roughness×0.35`, `metalness+0.25` (game2.js:91) | Sin cambio de material | ❌ | SurfaceAppearance/Reflectance ~0.25 |
| 52 | Chispitas shiny | 14 puntos blancos size 0.12 opacity 0.9 orbitando: radio rand(0.9,1.5), alto rand(-0.3,1.6), vel rand(0.6,1.6), bob `sin(2t+i)·0.15` (game2.js:201-207,230-233) | `Sparkles` por defecto #FFF3B8 (`SquishyFactory.luau:249-256`) | 🟡 | 14 billboards/partes pequeñas orbitando con esos números (o ParticleEmitter en órbita) |
| 53 | Chispitas por rareza (tier≥2) | `4 + tier·2` puntos (Raro 8, Épico 10, Leg. 12, Secreto 14) del color de la rareza (game2.js:202-205) | No existe | ❌ | Mismo sistema que 52 con `R[rarity].color` |
| 54 | Big / Tiny | escala 1.3 / 0.7 × `data.size` (game2.js:197, game1.js:114-115) | `ScaleTo(size·mut.size)` (`:244-248`) | ✅ | — |
| 55 | Compañero ×0.95 | `root.scale.multiplyScalar(0.95)` (game4.js:204) | No aplica 0.95 | 🟡 | `extraScale = 0.95` en Companion |

## E. Animación idle del squishy (resorte squash & stretch)

| # | Elemento | Original | Roblox ahora | Estado | Qué hacer |
|---|---|---|---|---|---|
| 56 | Resorte | `k=180, c=11`, `vy += (k(1-sy) - c·vy)dt` (game2.js:220) | No existe | ❌ | Portar a un `SquishyAnim.update(dt)` común |
| 57 | Respiración | `idle = sin(3.2t)·0.025`, escala `(xz, y, xz)` con `xz = 1+(1-y)·0.55`, pivote en la base (game2.js:221-223) | Compañero: solo sube/baja el pivote `lift·(1+sin(2.4t)·0.03)` (no escala) (`Companion.luau:137-140`) | 🟡 | Escalar desde la base con 3.2 Hz·0.025 |
| 58 | Balanceo | `inner.rotation.z = sin(2.1t)·0.03` (game2.js:224) | No existe | ❌ | Añadir |
| 59 | Rebote al caminar | `moving·abs(sin(10t))·0.08` en la escala (game2.js:221) | No existe (solo salto de posición) | ❌ | Añadir |
| 60 | Salto del compañero | Caminar: `abs(sin(9t))·0.6`; correr: `abs(sin(13t))·1.1`; quieto: `sin(4t)·0.08+0.08`; mira hacia donde va o a la cámara (game4.js:217-221) | `abs(sin(9t))·0.45` al moverse, 0 quieto; mira como el dueño (`Companion.luau:136-139`) | 🟡 | Números exactos, variante de correr, y orientación |
| 61 | Posición del compañero | `lado·3.2 + atrás·1.6` (game4.js:212-214) | `CFrame.new(3.2·0.55, 0, 3.2)` = 1.76 lado, 3.2 atrás | 🟡 | `(3.2, 0, 1.6)` relativo al jugador |
| 62 | Clic simple = `squish(1)` | `sy = 1-0.38`, `vy = -1.5` + `playSound('squishy')` (game2.js:216, game4.js:189-196) | Solo existe el mantener-clic | 🟡 | Tap corto → squash de resorte |

## F. Física de espuma v2 (deformación) — `game2b.js:272-448`

Roblox: `Controllers/Squish.luau` = "Opción C": escala Size/CFrame de TODAS las partes desde la base, sin deformación local.

| # | Elemento | Original | Roblox ahora | Estado | Qué hacer |
|---|---|---|---|---|---|
| 63 | Qué se deforma | Todas las mallas del `inner` salvo `noDeform`/cera (cara, orejas, bolas incluidas) (game2b.js:286-307) | Todo el modelo escalado en bloque (incluye `Base_n` como vaporera/pozo/palito) | 🟡 | Excluir `Base_n`; con EditableMesh deformar Body y mover `Part_n` con el desplazamiento en su centro |
| 64 | Radio de hundimiento | `r = ref·(0.30+0.10·soft)·(1.1 Gigante)`, `ref = max(0.6, maxDim/2)` (game2b.js:409) | No hay fuentes locales | ❌ | DeformEngine con EditableMesh |
| 65 | Profundidad máx. | `max = min(ref·0.56·soft, minDim·0.42)` (game2b.js:410) | `max = min(0.45, 0.3·soft+0.1)` como fracción de escala (inventado) (`Squish.luau:198`) | 🟡 | Usar la fórmula real en studs |
| 66 | Rigidez progresiva | `target += dt·max·(2.8·force·(1-fill)^1.25 + 0.05)·stiff` (game2b.js:332) | Igual con force 0.6, sin `stiff` (`Squish.luau:201`) | 🟡 | OK la fórmula; falta `stiff` de cera |
| 67 | depth damp | `damp(depth, target, rate or 14)` (dent), 18 (pull); `f=0.35d, s=0.65d` (game2b.js:334) | damp 14, f/s 0.35/0.65 | ✅ | En el mundo el original usa rate 4 (game6.js:271,274) → poner 4 |
| 68 | Recuperación 2 fases | `tauS = max(0.15, rise/3)`, `tauF = 0.05+rise·0.02`; borra ≤0.002 (game2b.js:323-336) | Igual (`Squish.luau:207-217`) | ✅ | — |
| 69 | `rise` / `soft` | `rise = (viral? sp.rise : 3.2)·fil.riseMul·(Gigante 1.15)`; `soft = (viral? sp.soft:1)·fil.softMul` (game2.js:213-214) | Solo especie; ignora relleno y Gigante (`Squish.luau:41-46`) | 🟡 | Leer `filling` y `mutation` del JSON del compañero |
| 70 | Rebote al soltar | Si `depth/max > 0.25`: `squish(-0.1·deep·clamp(2.6/rise,0.25,1.3))` (resorte) (game2b.js:442) | Resta a `f` (queda negativo = estira) con umbral 0.25·0.45 (`Squish.luau:160-163`) | 🟡 | Usar resorte (fila 56) |
| 71 | Perfil gaussiano + borde | `w = exp(-d²/re²)`; dent `n·(-d·w + d·0.18(exp(-d²/3.2re²)-w))·g`, `re = r(0.8+0.45·min(1,d/max))`, corte `d² > 9re²`, filtro de lado `g = smoothstep((ĉ·n+0.2)/0.65)` (game2b.js:354-374) | No existe | ❌ | EditableMesh: por vértice cada frame (≤1 500 vért.) |
| 72 | Conservación de volumen | `b0 = clamp(vol/area·1.9, -0.08ref, 0.24ref)`, infla `ĉ·b0·max(0,1-1.4dent-pull)` (y×0.6) (game2b.js:354-355,375) | Squash `xz = 1+k·0.62` global | 🟡 | Portar |
| 73 | Sombreado por vértice | `sh = clamp(1-shade, 0.52, 1.1)` con `shade = min(0.42, 0.4dent) - min(0.12,0.12pull) + ejes` (game2b.js:377-385) | No existe | ❌ | `EditableMesh` colores por vértice (o `SetColor`); si no, omitir y anotar |
| 74 | Normales + costuras | `computeVertexNormals` + `fixSeams` (promedia duplicados por posición 1e-4) (game2b.js:19-36,388) | — | ❌ | EditableMesh: recalcular normales de vértices tocados; soldar duplicados al crear |
| 75 | Palma (flat) | `k=0.62·v`; `y = ymin+(y-ymin)(1-k)`; xz `×(1+k·0.62·sin(clamp(t/H)·0.9π+0.15))` (game2b.js:378) | No existe | ❌ | Eje global (sirve también con escala si no hay EditableMesh) |
| 76 | Apretón (pinch) | `x×(1-k(0.75+0.25mid))`, `y×(1+0.5k)`, `z×(1+k(0.3+0.25mid))` (game2b.js:379) | No existe | ❌ | Portar |
| 77 | Torcer (twist) | ángulo `tw·t` alrededor de Y, t = altura normalizada (game2b.js:380) | No existe | ❌ | Portar |
| 78 | Piso | `y = max(y, ymin)` (game2b.js:381) | Escala desde la base (no atraviesa) | ✅ | — |
| 79 | Arrastrar = rastro | Si se mueve > `0.42·r`: suelta la fuente vieja y crea otra con `depth·0.88`, `target·0.9`; máx 30 fuentes (game2b.js:406,428-438) | No existe | ❌ | Portar |
| 80 | Estirar (pull) | `r = ref(0.36+0.08soft)`, `max = ref·0.75·soft`; `target = min(max, 0.85L)·(1-0.35·min(1,L/2max))`, dir `+0.25n` (game2b.js:416-426) | No existe | ❌ | Portar (Estudio) |
| 81 | Requisitos EditableMesh | — | — | ❌ | `AssetService:CreateEditableMeshAsync(Content.fromUri(body.MeshId))` + `CreateMeshPartAsync` y `ApplyMesh`; guardar `P` (base) y `PN` (normales) en tablas/`buffer`; actualizar solo vértices dentro de `3·re` a ~30 Hz; máx 1-2 EditableMesh vivas (el que aprietas + Estudio), destruir al terminar el slow rise; **Body ≤ 1 500 vértices** (decimar butter/toast/cheese/icecube 4 374, dumpling 2 665); dueño verificado 13+ con ID y "Enable Mesh/Image APIs" para publicado; fallback automático a la Opción C si falla la creación; virales multi-malla (uvas 9, dango 3, hamburguesa 5 capas) necesitan una EditableMesh por pieza o deformación rígida de las `Part_n` |

## G. Apachurrar en el mundo (manos alrededor del contorno) — `game6.js:143-318`

| # | Elemento | Original | Roblox ahora | Estado | Qué hacer |
|---|---|---|---|---|---|
| 82 | Objetivos | Compañeros (tuyo, NPCs), Vitrina (13), estatua; distancia ≤ 34 al punto tocado (game6.js:11-14,222) | Solo carpeta `Companions` (`Squish.luau:99-126`), 34 studs al pivote | 🟡 | Añadir vitrina + estatua |
| 83 | Manos | 2 manitos kawaii (`makeMitten`, piel #F4C7A1, puño #F7A7CD) (game6.js:146-160) | Brazos R15 del avatar con `IKControl` Position, SmoothTime 0.08, peso damp 8 (`AvatarHands.luau:260-304,379-381`) | 🔁 | Pedido del dueño; R6 sin brazos (anotado) |
| 84 | Silueta cada frame | Vértices ya deformados, 72 sectores, camino −35°…215° cada 5°, normal `0.4·n + 0.6·radial`, curvatura ±2 (game6.js:183-208) | No existe: manos a los lados de la caja `±max(X,Z)/2·(1+0.62k)·(0.95-0.5k)`, y = `cy + h(0.1-0.3k)` (`AvatarHands.luau:357-376`) | 🟡 | Calcular silueta desde vértices (o bbox proyectada) y colocar las manos IK sobre ella |
| 85 | Recorrido de las manos | `a = clamp(mid + amp·sin(0.55t-π/2) + usuario·amp, -25°, 62°)`; izq `π-a`, der `a` (game6.js:243-247) | Fijas a los lados | ❌ | Portar el vaivén lento por el borde |
| 86 | Contacto real | Rayo diagonal `normalize(-0.65n + 0.55F)` desde tu lado; fuente `dent` force 0.6 rate 4 que viaja; objetivo `max(0.5+0.16sin(2.2t+fase))·rampa(1.2s)·min(1,0.3+stiff)` (game6.js:264-274) | Una sola "profundidad" global | ❌ | Con DeformEngine |
| 87 | Apretón suave de fondo | `squishAxis(pinch, true, 0.3, 2)` (game6.js:230) | No | ❌ | Añadir |
| 88 | Escala/posición de mano | `hs = 0.88·escala`, offset `(0.2+0.9(1-vis))·hs` por la normal y `-0.32·hs·F`; separación mínima `1.0·hs`; lerp pos 7, slerp rot 5.5; entrada `vis += 3.2dt`; salida 0.4 s (game6.js:256-305) | IK con SmoothTime 0.08 y peso damp 8 | 🔁/🟡 | Aplicar suavizados 7/5.5 al target del IK, separación mínima |
| 89 | Dedos curvados | `curl = 0.2 + clamp(1.4k, 0, 0.9)` + `0.08sin(2.2t+fase+0.35j)` (game6.js:284-285) | R15 no tiene dedos | 🔁 | Aceptar; opcional rotar la mano (`IKControl` Type Transform) según la normal |
| 90 | Personaje camina hacia el squishy | No: el jugador no se mueve; la cámara se acerca | `hum:MoveTo` si está a > REACH 3.2+1.2 (`AvatarHands.luau:327-336`) y gira el HRP | 🔁 | Consecuencia de usar brazos; documentado en PROGRESS |
| 91 | Cámara de amasar | `dist = max(3.4, (h+w)·0.5·s·2.3+1.2)·zoom`, altura `0.55·dist`, mira `C-0.1s`, k=6 (game6.js:175-179,253) | Cámara normal de Roblox | ❌ | Cámara Scriptable mientras amasas |
| 92 | Girar/mover manos con el mouse | `orbT += dx·0.0055` (damp 5); `aUserT = clamp(aUserT - dy·0.006, -0.9, 0.9)` (game6.js:237-241,252) | No | ❌ | Portar |
| 93 | Zoom rueda | `zoom = clamp(zoom + dY·0.0012, 0.65, 1.7)` (game6.js:320) | No | ❌ | Portar |
| 94 | El dueño se detiene | `sq.heldBy='player'`; compañero/NPC quieto (game4.js:211, game6.js:229) | `Companion.frozen = m` + `npcSquished` al server | 🟡 | Verificar que el NPC deje de caminar |
| 95 | Frases del dueño | `NPC_SQUISH_LINES` (7) / `NPC_WAX_LINES` (4), cooldown 9 s, emote (game6.js:9-10,32-36) | Server `npcSquished` | 🟡 | Revisar que use las mismas 11 frases y cooldown 9 s |
| 96 | Toast de primera vez | "¡Eso! Las manos le van dando la vuelta al squishy. Mueve el mouse a los lados para guiarlas. Clic derecho = apuntar · F = de cerca." 5.2 s (game6.js:233) | No | ❌ | Añadir (flag en perfil) |
| 97 | Pista inferior mientras amasas | "🖐️ Mueve el mouse **a los lados** para girar · **arriba/abajo** para mover las manos por el borde · rueda = zoom" (+ cera) (game6.js:114) | No | ❌ | Añadir |
| 98 | Contar apachurrón | `countSquish()` al empezar y 30% al arrastrar; +2 XP cada 15 (game6.js:37,232,272) | `State.request("squish")` al empezar | 🟡 | Agregar conteo durante el arrastre |
| 99 | Visible para otros | (un jugador) | `SquishBroadcast` declarado pero sin uso (`shared/Remotes.luau:14`) | ❌ | Opcional multijugador |

## H. Modo apuntar (Aim) — `game6.js:50-122`

| # | Elemento | Original | Roblox ahora | Estado | Qué hacer |
|---|---|---|---|---|---|
| 100 | Activación | Clic derecho sostenido (pointer lock) o **Q** sostenido (game6.js:319-338) | No existe | ❌ | `ContextActionService` Q + MouseButton2 (quitarle la rotación de cámara mientras apunta) |
| 101 | Cámara al hombro | `aimK = damp(→1, 7)`; look desplazado 3.0 a la derecha, distancia 9 (SYSTEMS_SPEC §10) | No | ❌ | Cámara scriptable o `CameraOffset` del Humanoid |
| 102 | Jugador semitransparente | opacidad `1 - 0.62·aimK` (game6.js:78) | No | ❌ | `LocalTransparencyModifier` |
| 103 | Imán de objetivo | Candidatos ≤ 34, radio proyectado + 120 px (22 sin apuntar); puntaje `max(0,d-0.6rad) + 1.2dist - 45 (actual) + 60 (estatua)` (game6.js:53-67) | No | ❌ | Portar |
| 104 | Retícula | Div `#reticle` que sigue al objetivo con damp 16 (30 sin objetivo), clases lock/press, oculta mientras amasas (game6.js:98-106) | No | ❌ | ImageLabel + estilos de template.html |
| 105 | Etiqueta de retícula | `<b>nombre</b><span>dueño · 🕯️ encerado</span>` (game6.js:107) | No | ❌ | Añadir |
| 106 | Anillo en el piso | RingGeometry(0.8,1) #FF7BB5 opacity 0.8, y+0.06, escala `w·0.62·s·(1+0.06sin(6T))` (game6.js:109-111) | No | ❌ | Mesh de anillo o 2 cilindros + `SurfaceGui` |
| 107 | Ayuda de puntería | `yaw += diff·min(1, 2.2dt)` si abs(diff) < 0.5 rad (game6.js:100-103) | No | ❌ | Portar |
| 108 | Pistas | "🎯 **Clic** para apachurrar · …", "🖐️ **Mantén clic** para apachurrar · **clic derecho / Q** apuntar · …", "**F** de cerca: nombre", "🎯 Apunta a cualquier squishy (el tuyo, el de tus amigos o la vitrina)" (game6.js:113-120) | No | ❌ | Textos idénticos |
| 109 | Cursor | `pointer` sobre objetivo (game6.js:121) | No | ❌ | `Mouse.Icon` |
| 110 | F = Estudio | Abre Estudio con el objetivo o el más cercano ≤ 10; si no: toast "Acércate a un squishy (tuyo, de otro jugador o de la Vitrina Viral) y presiona F" + error (game6.js:332-336) | No | ❌ | Con el Estudio |

## I. Fantasma de personajes — `game6.js:71-89,123-130`

| # | Elemento | Original | Roblox ahora | Estado | Qué hacer |
|---|---|---|---|---|---|
| 111 | Quién | Tú + NPCs dueños del objetivo o a < 9 del objetivo (game6.js:75-76) | No existe | ❌ | Incluir jugadores reales cercanos también |
| 112 | Oclusión | Muestras a alturas 1.4 / 3.2 / 4.8, radio 2.3 al segmento cámara→objetivo (t<0.97) → opacidad 0.2 (game6.js:79-84) | No | ❌ | Portar (avatares R15: poner `LocalTransparencyModifier` en todas las BaseParts/Accessories/Decals) |
| 113 | Cerca de la cámara | < 4.5 → 0.25 (game6.js:86) | No | ❌ | Portar |
| 114 | Suavizado | `damp(op, want, 10)`, `depthWrite` solo > 0.95 (game6.js:124-127) | No | ❌ | damp 10 |

## J. Estudio Squish — `game6.js:340-664`

| # | Elemento | Original | Roblox ahora | Estado | Qué hacer |
|---|---|---|---|---|---|
| 115 | Escena | Hemi #fff/#c9b8e6 0.85, direccional #fff4ea 0.85 en (3,7,5) con sombras, rim #ffd6f2 0.45; plato cilindro 3.3/3.5 h0.26 #FFF4FA + aro toroide 3.32/0.07 #F7A7CD (game6.js:390-396) | No existe | ❌ | Sala aislada (sombras) o ViewportFrame (sin sombras) |
| 116 | Cámara | FOV 36; yaw 0.3, pitch 0.4, dist 7.2; clic derecho orbita (`yaw -= dx·0.008`, `pitch += dy·0.006` clamp −0.1…1.2); rueda `dist += dY·0.004` clamp 4.2…11; mira a `h·0.45` (game6.js:397,410,431,517,610-613) | No | ❌ | Portar |
| 117 | Encaje | `fit = 2.7 / max(h, 0.95w)` (game6.js:428) | No | ❌ | Portar |
| 118 | Girar auto (🔄) | `yaw += 0.6dt` si no hay dedos (game6.js:609) | No | ❌ | Portar |
| 119 | Modo 👆 Dedo | Multitouch, `squishPress` force 1, dedo de puño (cilindro 0.17/0.18, puño superelipsoide 0.34×0.3×0.27, uña #FBE3D6, nudillo #E5AE88), hover opacidad 0.35, `placeFinger` lift 0.17, lerp 16 / slerp 10, sonido squishy pitch rand(0.95,1.2) vol 0.5 (game6.js:344-360,508-513,553-557) | No | ❌ | Dedo: usar `assets/props/hand_finger_pointer.glb` o la mano del avatar (pedido: brazos del avatar) |
| 120 | Modo 🤏 Estirar | `squishPull`, 2 dedos en pinza escala 0.85 separados ±0.13, creak cada 0.12 de cambio, al soltar creak 0.5 + squishy 1.4/0.35 (game6.js:504-507,526,548,620-627) | No | ❌ | Portar |
| 121 | Modo 🌀 Torcer | `twist = clamp(dx·0.006, ±1.4)` rate 10, squeak 0.7 cada 0.12, al soltar squeak 0.5 (game6.js:499,519-520,537) | No | ❌ | Portar |
| 122 | Modo 💥 Golpe | Cooldown 0.18; flat 0.95 rate 32 por 0.12 s; sacudida 0.18 s ±0.06; squishy 0.62 vol 1 + tono 95 Hz 0.12 s; `waxSmash(1)`; vibrar 20 (game6.js:538-544,612-614) | No | ❌ | Portar |
| 123 | Espacio = palma | flat hold target 1 rate 4; mano plana (palma superelipsoide 0.62×0.15×0.62 + 4 dedos) arriba en `top+0.17+(1-vis)·1.2`, gira con twist; squishy pitch 0.75 vol 0.8 (game6.js:361-369,479-487,637-640) | No | ❌ | Mano del avatar o `hand_mitten`/palma; ver con el dueño |
| 124 | Q = apretar 2 manos | pinch hold; manos a los lados `±(halfW(1-0.62pinch)+0.17+(1-vis)1.2)`, altura `h·0.5(1+0.2pinch)`; squishy pitch 0.9 (game6.js:641-647) | No | ❌ | Igual |
| 125 | Visibilidad de manos | `palmVis` damp 8 (30 en golpe), 1 al sostener / 0.4 si flat > 0.05 (game6.js:638-641) | No | ❌ | Portar |
| 126 | Botones y teclas | Dedo/Estirar/Torcer/Golpe, "Aplastar con la palma", "Apretar con las dos manos", Cera, 🔄, Salir; teclas Esc, Espacio, Q, 1-4, C (game6.js:411-420,460-468; screenshot 09) | No | ❌ | UI idéntica a template.html |
| 127 | Ayuda por modo | 4 textos exactos + "Clic derecho = girar · rueda = zoom · **Espacio** palma · **Q** apretar · **1-4** modos · **C** cera" (game6.js:471-476) | No | ❌ | Copiar textos |
| 128 | Panel de datos | Suavidad `●` = `clamp(round(soft·3.3),1,5)`/5, Slow rise `rise.toFixed(1)` s, Relleno, Tipo ✨ Viral, Apachurrones, Cera (game6.js:436-442) | No | ❌ | Portar |
| 129 | Cronómetro slow rise | Arranca si nada sostenido y `maxDepth > 0.08`; termina `< 0.03`; "Volvió a su forma en X s" + ≥6 "¡slow rise brutal! 🐢✨", ≥3.5 "¡bien slow! ✨", si no "rebotón 😄"; récord `bestRise` + sparkle (game6.js:552,652-661) | No (solo existe `stats.bestRise` en Profile) | ❌ | Portar; guardar récord en server |
| 130 | Mutación en Estudio | big/tiny → normal, conserva shiny y chispitas (game6.js:427) | — | ❌ | Portar |
| 131 | Al abrir/cerrar | abre: `playSound('open')`, ownerReact a los 300 ms; cerrar: suelta todo, foamStop, guarda cera en inventario, `refreshCompanion` si equipado, `close` (game6.js:446-458) | — | ❌ | Portar |

## K. Cera de vela v2 — `game2c.js` + Estudio (`game6.js:558-605`)

Roblox: solo existen los datos (`Config/WaxColors.luau`, `GameConfig.WAX = {MAX_LAYERS=6, THICK=0.04}`, `Types.WaxState`). Ninguna lógica ni visual.

| # | Elemento | Original | Roblox ahora | Estado | Qué hacer |
|---|---|---|---|---|---|
| 132 | Colores | blanca #F6EFE3, rosa #FFC3DA, lila #DCCBFF, menta #BFEFDC, miel #FFD27A, cielo #BFE0FF, arcoíris = HSL(rand, 0.75, 0.82) por pedazo (game2c.js:10-14,101) | Datos iguales | ✅ datos / ❌ uso | — |
| 133 | Capas | Máx 6, grosor `0.04·ref`, cada capa sobre la suma de las anteriores (game2c.js:16,43-44,58) | Solo constantes | ❌ | Portar |
| 134 | Vertido/enfriado | `grow += dt/pourTime` (1.6 por defecto, 1.8 Estudio); `hot -= dt/2.4`; opacidad `0.3+0.6grow`; emisivo #ff9a4a `hot·0.3`; roughness `0.05+0.17(1-hot)` (game2c.js:59-60,187-189) | No | ❌ | Portar |
| 135 | Pedazos Voronoi | `K = round(clamp(area·15, 24, 64))` semillas por área, peso 0.75–1.25; vecinos por aristas (pos ×600); cáscara de una cara doble (game2c.js:76-121) | No | ❌ | Precalcular con EditableMesh → `CreateMeshPartAsync` una vez por capa (o precalcular offline por molde) |
| 136 | Etapas | integ < 0.78 agrietado (sep 0.004ref, blanqueo 14%); < 0.4 suelto (0.02ref, 30%); ≤ 0 se cae (game2c.js:201-213) | No | ❌ | Portar |
| 137 | Estrés | `Σ(0.25+d/max)·exp(-d²/2r²)·(held?1:0.35)·(pull?1.3:1)`; palma 0.35, apretón 0.6, torcer 0.5; `integ -= st·dt·4.2·exp` y `global·dt·2.0·exp`; exposición 0.22 si tapado (game2c.js:144,194-200) | No | ❌ | Portar |
| 138 | Rigidez al dedo | por capa que cubre: [0.2, 0.45, 0.78, 1]; caliente ×0.7; mín 0.02 (game2c.js:147-157) | No | ❌ | Portar (`stiff` de fila 66) |
| 139 | Toque / golpe | tap `-(0.3force(1-d²/R²)+0.04)·exp`, R = 1.35r; smash `-(0.07+0.2·altura)·rand(0.6,1.4)·exp` (game2c.js:158-169) | No | ❌ | Portar |
| 140 | Desprendimiento | vecinos −0.07 (cascada); vel `n·rand(1,2.6)·s + up·rand(0.8,2.4)·s`; gravedad 19.6s; rebote 0.26; fricción 0.7; giro rand(3,10) (×0.55 al tocar piso); fade 3→4.2 s; máx 160 vivos (game2c.js:170-182,227-239) | No | ❌ | Partes sueltas con física propia o desancladas + Debris 4.2 s |
| 141 | Sonido de cera | presupuesto 35–65 ms; `waxCrack(min(1, 0.35+0.12s+0.2big), min(3, capas))` + `waxTink` si se cayó; tink 50% al tocar piso; vibración 16/7 (game2c.js:217-224,234) | No | ❌ | `cera_crack_suave/fuerte.wav`, `cera_tink.wav` |
| 142 | Todo roto | +1 `waxCracked`; mundo +4 XP reward, NPC dice "¡Le quitaste toda la cera! 😂 Ahorita le echo más" y re-encera a los 25 s con 1–3 capas al azar ("Listo, le eché k capa(s) de cera 🕯️ ¡Rómpela!"); si no, toast "¡Toda la cera fuera! 🕯️💥 +4 XP"; Estudio +5 XP + reward + sparkle + toast (game6.js:43-48,430,673) | No | ❌ | Portar (XP en server) |
| 143 | NPCs encerados | 1 de cada 3 lleva su viral encerado con 1–3 capas (SYSTEMS_SPEC §6) | `NpcService` no pone cera | ❌ | Agregar `wax` al JSON del compañero NPC |
| 144 | Guardado | `wax = {list = {{c, s, b}}}` solo si no está roto; se guarda al terminar de amasar y al cerrar el Estudio (game2c.js:240-245, game6.js:38-42) | Tipo `WaxState` existe | ❌ uso | Remote para guardar la cera del squishy propio |
| 145 | Panel de cera (C) | Botones de color, "🕯️ Echar capa N encima" / "Ya tiene 6 capas", pila de capas, "Quitar cera", textos de estado (Echando cera… / Enfriando… 🌬️ / Lista… / ¡Limpio!…) (game6.js:559-568) | No | ❌ | UI idéntica |
| 146 | Vela y chorro | Vela cil. 0.3/0.32 h1.2 del color, charco emisivo 0.25, mecha, llama #FFB347 escala y `2.2+0.3sin(30t)`; pos en espiral `a = p·3.2π`, radio 0.28w/0.22w, altura h+1.25, rot z 2.2; chorro cil. 0.035/0.05 hasta la superficie (raycast) (game6.js:370-378,581-592) | No | ❌ | `assets/props/candle.glb` |
| 147 | Gotitas y vapor | Gotas r0.05 a 25/s, vida 0.35, gravedad 9; vapor r0.08–0.16 blanco 0.5 a 14/s mientras `hot>0.25`, sube 0.7/s, escala `1+1.5t`, vida 1.1 (game6.js:590-601) | No | ❌ | ParticleEmitters con esos números |
| 148 | Aviso "dura" | sparkle2 + toast "🕯️ ¡La cera ya está dura! Apriétala o dale golpes para que haga CRACK" 3.2 s (game6.js:602) | No | ❌ | Portar |
| 149 | Sonido de verter | `open` + ruido 1.6 s 900 Hz (game6.js:575) | No | ❌ | Falta WAV (no hay archivo de "verter"); usar noise horneado o crear uno |

## L. Tour cinemático — `game7.js`

Roblox: no existe (solo `tourSeen` en Profile y el handler en `InventoryService.luau:246`).

| # | Elemento | Original | Roblox ahora | Estado | Qué hacer |
|---|---|---|---|---|---|
| 150 | Curva de cámara | 18 puntos (t=0 (0,105,165)→… 61.5 pose final), Catmull-Rom **centrípeta** para posición y mirada (game7.js:22-44) | No | ❌ | Implementar Catmull-Rom centrípeta en Luau con los mismos puntos (coordenadas de `WorldLayout`) |
| 151 | Velocidad | `e = smoothstep(l)·0.35 + l·0.65` por tramo (game7.js:96-101) | No | ❌ | Portar |
| 152 | Aterrizaje sin salto | Últimos 2.5 s: mezcla smoothstep con `followPose()`; al final cámara exacta (game7.js:108-110,164) | No | ❌ | Con la cámara de Roblox: terminar en su CFrame actual y devolver `CameraType.Custom` |
| 153 | Tarjetas | 8 tarjetas con tiempos exactos y textos ("SQUISHY WORLD", 1 Las Máquinas … 6 Tus retos, "Y este eres tú 👋") (game7.js:46-55) | No | ❌ | Copiar textos literales |
| 154 | Rutas brillantes | 4 tiras (18→48 en cada eje) ancho 2.2 con textura de flecha (repeat L/2.2, avanza 1.4/s) + glow ancho 3.4; colores #F7A7CD, #B999E8, #F4D982, #8BC7E8; opacidad 0.95/0.45, damp 3 (game7.js:58-78,116-119) | No | ❌ | Parts + `Texture` con `OffsetStudsU` animado |
| 155 | Anillo Vitrina | Ring 14.2–17 #FFE38A, opacidad `0.55·(0.8+0.2sin(4t))` (game7.js:80-81,119) | No | ❌ | Portar |
| 156 | Pines del mapa + panel de retos | 6 pines (🏭 ✨ 🛍️ 🏆 🤝 ⭐Tú) + panel con misión actual, rarezas, meta, extra cera (game7.js:139-160) | No | ❌ | BillboardGuis + Frame |
| 157 | Saludo final | t > 58.5: `emote-yes` + `pop` (game7.js:122) | No | ❌ | Animación de saludo (wave) del avatar |
| 158 | Acordes | Inicio [523,659,784,1047] vol 0.07, 0.09 s entre notas; tarjeta grande [659,784,988], normal [784,988] vol 0.05 + `select` (game7.js:93-95,137) | No | ❌ | `tour_acorde.wav` (y otro para las tarjetas) |
| 159 | Saltar | Esc / Enter / Espacio / botón "Saltar tour ⏭" → `t = total-2.6` + click (game7.js:161,173-174) | No | ❌ | Portar |
| 160 | Barras de cine / HUD oculto | `body.cine`, HUD oculto, controles bloqueados (game7.js:90, SYSTEMS_SPEC §12) | No | ❌ | Portar |
| 161 | Botón 🎬 Tour y primera vez | `bTour` y al darle Jugar si no lo ha visto (game7.js:175) | Solo el flag en server; ícono `AssetIds.icons.tour` vacío | ❌ | Botón en HUD + disparo inicial |

## M. Partículas / bursts / efectos

| # | Elemento | Original | Roblox ahora | Estado | Qué hacer |
|---|---|---|---|---|---|
| 162 | Burst de POP | 40 puntos size 0.55 del color del relleno (`color3`), vel `(rand(-1,1), rand(0.3,1.6), rand(-1,1))·rand(6,14)`, gravedad 20, piso 0.2, vida 1.2 con fade (game5.js:209,230-246) | No (`Machine.luau:314-320` solo sonido) | ❌ | `ParticleEmitter:Emit(40)` con esos números |
| 163 | Sacudida de cámara en POP | `cam.shake = 0.35` (game5.js:208) | No | ❌ | Portar |
| 164 | FX de revelación | Solo tier ≥ 2: raro 40 (chispas #bfe0ff/#fff/#4C9BFF), épico 80, legendario 140 (confeti + estrellas, 6 colores, vy −5), secreto 120 (glitch #000/#ff2a6d/#05d9e8); vida 1.2–2.6 (game5.js:294-322) | No | ❌ | Frames 2D animados en el overlay |
| 165 | Animación del squishy en revelación | Escala `0→1.15→1` entre t=0.55 y 1.1 s, `rot.y = sin(0.9t)·0.5` (vaivén), `sq.update` idle; big 1.3/tiny 0.7; legendario zoom 7.4→6.2; cámara FOV 32 (game5.js:303-311) | Crece desde t=0 en 0.5 s con bamboleo, gira sin parar `t·0.9`, mutación forzada a normal en Thumb (`Reveal.luau:254-268`, `Thumb.luau:15`) | 🟡 | Igualar curva, vaivén y tamaño por mutación |
| 166 | Secreto | Div negro 1 s + secretSting (game5.js:272) | Fondo negro todo el tiempo | 🟡 | Solo 1 s de apagón |
| 167 | Sonido por rareza | tier 4 (Legendario) = fanfare + emote; **secreto (tier 5) no suena fanfare** (game5.js:287) | `tier >= 4` → fanfare (también secreto) (`Reveal.luau:362-364`) | 🟡 | `tier == 4` |
| 168 | Luz de la máquina | Lámpara emisiva color de rareza 1.4 por 3 s (game5.js:223-224) | (auditoría de máquina) | — | — |

## N. Miniaturas (Thumbs) — `game2.js:254-279`

| # | Elemento | Original | Roblox ahora | Estado | Qué hacer |
|---|---|---|---|---|---|
| 169 | Cámara | FOV 30; `dist = max(1.1h, 0.95w)·2.0+0.6`; pos `(0.26d, 0.55h+0.22d, d)`; mira `(0, 0.45h, 0)` (game2.js:263,272-273) | FOV 30; `dist = max(X,Y,Z)·2.1`; pos `centro + (0.25d, 0.35d, -d)` (`Thumb.luau:32-39`) | 🟡 | Fórmula exacta; verificar que el frente del GLB mire a −Z en Roblox |
| 170 | Luces | Hemi #fff/#c8bde0 0.9 + direccional 0.9 en (2,4,5) (game2.js:261-262) | Ambient (200,195,210), LightDirection (−0.4,−1,−0.6) | 🟡 | Ajustar dirección a (−2,−4,−5) normalizada |
| 171 | Clave de caché | species/variant/mutation/face/silueta; conserva shiny y cara (game2.js:266-269) | Siempre `mutation="normal"`, sin cara, sin caché | 🟡 | Pasar shiny y face; cachear si hay muchos |

## O. Audio — mapa de SFX (`game1.js:190-285`) y disparadores

`Controllers/Audio.luau`: `Audio.play(name, pitch)` con volumen fijo 0.6 (sin parámetro de vol), `Audio.loop(name, on)`. Todos los ids de `AssetIds.sounds` están **vacíos** → hoy no suena nada.

| # | SFX | Archivo (assets/audio) | Dónde suena en el original | Roblox: id / disparador | Estado | Qué hacer |
|---|---|---|---|---|---|---|
| 172 | click | click_002.mp3 | tabs, selección, skip tour, chat (game5.js:153-546, game7.js:161) | clave `click` ✓; Inventory/Shop/Index/Trade/Machine/Hud | ✅ mapa / id vacío | Pegar id |
| 173 | open | open_001.mp3 | abrir overlay, Estudio, verter cera, inicio (game5.js:89,703; game6.js:446,575) | `open` ✓; usado en paneles | 🟡 | Falta en Estudio/cera |
| 174 | close | close_002.mp3 | cerrar overlay/Estudio, quitar cera (game5.js:99; game6.js:419,457) | `close` ✓; no se usa en ningún controller | 🟡 | Tocar al cerrar Modal |
| 175 | reward | confirmation_002.mp3 | revelación tier 0-1, misión, trato, cera rota (game5.js:287,555,576; game6.js:44,430) | `reward` ✓; Reveal + server | 🟡 | Falta cera rota |
| 176 | rare | maximize_006.mp3 | revelación tier 2 | `rare` ✓ Reveal | ✅ | — |
| 177 | epic | confirmation_004.mp3 | revelación tier 3; capa de `fanfare` | `epic` ✓ | ✅ | — |
| 178 | sparkle | glass_002.mp3 | perfecto, tier 2-3, molde comprado, récord slow rise, cera rota Estudio (game5.js:202,287,435; game6.js:430,659) | `sparkle` ✓ Machine/Reveal/Shop | 🟡 | Falta récord y cera |
| 179 | sparkle2 | glass_005.mp3 | tier 1; "cera dura" (game5.js:287; game6.js:602) | `sparkle2` ✓ Reveal | 🟡 | Falta cera |
| 180 | glitch | glitch_003.mp3 | dentro de secretSting (rate 0.6 y 1.3) (game1.js:234) | `glitch` ✓ (sin uso; horneado en secreto_sting.wav) | ✅ | — |
| 181 | keep | drop_002.mp3 | Guardar en revelación (game5.js:327) | `keep` ✓ vía server `FillService.luau:245` | ✅ | — |
| 182 | squish | pluck_001.mp3 | capa de `squishy` (rate pitch·rand(0.9,1.1), vol 0.5) (game1.js:230) | `squish` ✓; Squish.luau lo usa **solo** (sin ruido ni tono) | 🟡 | Usar `squishy.wav` completo |
| 183 | squish2 | pluck_002.mp3 | No se usa en el original | Squish.luau lo usa si `soft ≥ 1.1` (inventado) (`Squish.luau:146`) | 🟡 | Quitar esa regla |
| 184 | error | error_004.mp3 | errores varios (game5.js; game6.js:335) | `error` ✓ | ✅ | — |
| 185 | select | select_003.mp3 | equipar, reroll, modos Estudio, color de cera, tarjetas del tour (game5.js:376,546; game6.js:417,477; game7.js:137) | `select` ✓ | 🟡 | Falta Estudio/tour |
| 186 | coin | bong_001.mp3 | capa de `coins` | `coin` ✓ (sin uso directo) | ✅ | — |
| 187 | levelup | switch_002.mp3 | subir nivel, mejora (game5.js:21,440) | `levelup` ✓ server | ✅ | — |
| 188 | npc | question_001.mp3 | respuesta de chat vol 0.35 (game5.js:494) | `npc` ✓ (sin vol 0.35) | 🟡 | Añadir parámetro volumen a `Audio.play` |
| 189 | toggle | toggle_002.mp3 | favorito, 🔄 del Estudio (game5.js:377; game6.js:414) | `toggle` ✓ | 🟡 | Falta Estudio |
| 190 | squishy (synth: ruido 0.22 s 1400 Hz + tono 420·pitch + pluck) | squishy.wav / squishy_grave.wav / squishy_agudo.wav | mundo pitch rand(0.9,1.15) vol 0.6 (estatua 0.6); clic 1/0.6; palma 0.75; apretar 0.9; torcer 1.1; estirar 1.25; dedo rand(0.95,1.2); golpe 0.62 vol 1; soltar estirar 1.4 (game4.js:195; game6.js:231,483,499,507,512,541,548) | **No hay clave** en AssetIds | ❌ | Agregar `squishy`, `squishyLow`, `squishyHigh` y usarlas con PlaybackSpeed |
| 191 | pop | pop_reventon.wav | POP de máquina; saludo del tour (game5.js:208; game7.js:122) | `pop` ✓ Machine | 🟡 | Falta tour |
| 192 | whirr | maquina_whirr.wav | procesado (game5.js:203) | `whirr` ✓ Machine | ✅ | — |
| 193 | fanfare | fanfarria.wav | Legendario (game5.js:287) | `fanfare` ✓ (también en secreto: fila 167) | 🟡 | Ver fila 167 |
| 194 | secretSting | secreto_sting.wav | Secreto (game5.js:272) | `secretSting` ✓ Reveal | ✅ | — |
| 195 | coins | monedas.wav | vender, comprar, trato (game5.js:332,388,434) | `coins` ✓ server | ✅ | — |
| 196 | fillStart/fillSet/fillStop | llenado_loop.wav | Mientras llenas; `freq = 90+160p`, filtro `400+1600p`, entrada 0.08 s, salida 0.1 s (game1.js:237-251) | `fillLoop` ✓ on/off; **sin fillSet** | 🟡 | `PlaybackSpeed = 1 + p·(160/90)` aprox. y ecualizador |
| 197 | foamSet / foamStop | espuma_loop.wav | Mientras amasas: `vol = min(0.55, 0.5·lvl)` (τ 0.05), `bandpass = 700+1500·bright+900·lvl`; mundo `lvl = abs(Δdepth)/dt + 0.003·speed`, bright 0.55; Estudio `·1.4 + 0.004·spd + 0.06 (palma/apretón)`, bright 0.35/0.7; se apaga tras 90 frames quieto (game1.js:252-272; game6.js:297-298,650-651) | **No hay clave ni uso** | ❌ | Agregar `foamLoop` y controlar Volume/PlaybackSpeed/EqualizerSoundEffect cada frame |
| 198 | waxCrack | cera_crack_suave.wav / cera_crack_fuerte.wav | cera (fila 141) | No hay clave | ❌ | Agregar 2 claves; elegir por `v` y volumen `0.75+0.25·capas` |
| 199 | waxTink | cera_tink.wav | pedazo que cae (fila 141) | No hay clave | ❌ | Agregar |
| 200 | creak | estirar_creak.wav | Estirar (game6.js:526,548) | No hay clave | ❌ | Agregar |
| 201 | squeak | torcer_squeak.wav | Torcer (game6.js:520,537) | No hay clave | ❌ | Agregar |
| 202 | crinkle | crinkle.wav | Rastro al arrastrar (35% mundo 0.35; Estudio 0.7), al soltar si maxDepth > 0.5/0.55 (game6.js:272,314,549,631) | `crinkle` ✓ en AssetIds, **nunca se reproduce** | ❌ | Llamarlo en esos puntos |
| 203 | tour chord | tour_acorde.wav | Tour (fila 158) | No hay clave | ❌ | Agregar |
| 204 | golpe grave (tono 95 Hz 0.12 s) y verter (ruido 1.6 s) | sin archivo | Estudio (game6.js:541,575) | — | ❌ | Renderizar 2 WAV extra o aproximar con squishy_grave |
| 205 | Volumen por llamada | `vol` por llamada (def. 0.8) × master 0.7 (game1.js:199,211) | Volumen fijo 0.6 (`Audio.luau:24`) | 🟡 | `Audio.play(name, pitch, vol)` con `0.7·vol` |
| 206 | Mute | `SFX.muted` + botón 🔊 | `Audio.muted` existe | ✅ | Verificar botón en HUD (otra auditoría) |

## Prioridad sugerida
1. Importar los 18 GLB (y marcar `TintWithBody`/`TintWithAccent`), subir 12 texturas y 35 sonidos, completar `AssetIds` con las claves faltantes (filas 190, 197-203).
2. Caras por tipo (26-30) y extras exactos (44-49, 51-53), resorte idle (56-59).
3. DeformEngine con EditableMesh (63-81) + manos del avatar sobre la silueta (84-93) + bucle de espuma (197).
4. Apuntar + fantasma (100-114), Estudio (115-131), Cera (132-149), Tour (150-161), bursts/FX (162-167).
