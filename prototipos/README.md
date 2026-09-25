# Laboratorio de Gases: prototipos

Tres prototipos jugables en HTML5, cada uno en 2D (canvas, sin dependencias) y en 3D (`*-3d.html`, Three.js r128 desde cdnjs, estilo plastilina). La lógica y los controles son los mismos en ambas versiones. El sonido está sintetizado con WebAudio. Abre `index.html` en el navegador para empezar.

| Archivo | Juego | Controles |
|---|---|---|
| `ascensor.html` | **Ascensor Apestoso**: deducción social en un edificio de 30 pisos | Mantén el botón o Espacio para soltar; toca a un pasajero para señalarle |
| `jetpack.html` | **Jetpack de Emergencia**: runner infinito con un solo tanque de gas | Espacio: saltar/planear · →: dash · ←: frenar |
| `duelo.html` | **Duelo de Presión**: 2 jugadores en local o contra la CPU | Rosa: W/S y D · Azul: ↑/↓ y ← · Táctil: una mitad de pantalla por jugador |

## Ascensor Apestoso: reglas del prototipo

- Hay 5 pasajeros y uno es el impostor. Su **presión** sube sola y con retortijones aleatorios. Si llega a 100, **explota** y pierden todos.
- Soltar gas baja la presión. Lo fuerte que suena depende de dos cosas:
  - La **aguja del esfínter**: en verde suena poco, en los extremos suena mucho.
  - El **ruido ambiente**: el ding del piso, las toses (se ven venir con un «…»), los estornudos, el móvil o los crujidos del ascensor.
- Lo que se oye reparte **sospecha**. Un pedo fuerte se localiza fácil; uno flojo se reparte entre los que están cerca.
- El **olor** se acumula y solo se ventila cuando se abren las puertas.
- Hay votación si alguien llega a 100 de sospecha o el olor pasa de 92. El más votado se baja; si es el impostor, pierde.
- **Señalar** a alguien (cada 7 s) le sube la sospecha. Si no huele a nada, el que queda raro eres tú.
- **Modo pasajero**: un bot es el impostor y tú tienes 2 acusaciones. Pistas: quién suda (hay sudores falsos), dónde aparece el «prrt» (con más error cuanto más flojo) y quién pone cara de alivio.

### Siguiente paso: multijugador online (4–8 personas)

- El servidor tiene la autoridad (Firebase Realtime DB, Supabase Realtime o un WebSocket en Node). Guarda el piso, el ruido, el olor, la presión del impostor y las sospechas.
- Cada cliente solo envía `hold on/off`, `point(target)` y `vote(target)`. El servidor calcula lo que se oye y lo difunde **sin revelar la fuente exacta**: solo una posición aproximada del «prrt».
- Los ruidos de NPC (toses, móvil) pasan a ser acciones de los jugadores: cualquiera puede toser a propósito para tapar a alguien o para despistar.
- Variante: 2 impostores en partidas de 8 personas.

## Jetpack de Emergencia: ajustes

- Saltar es gratis. Planear cuesta ~20/s, el dash 25 de golpe y frenar ~22/s. En el suelo se recupera 3/s y cada frijol da +12.
- Cajas (150 px): no se pueden saltar, solo romper con dash. Prensas: frena y cruza cuando estén arriba. Huecos grandes: salto y planeo.
- Encaja con Climby: el mismo sistema de tanque se podría usar como impulso en la escalada.

## Duelo de Presión: ajustes

- Mantén para cargar (gasta tanque) y suelta para disparar en cono. Si te pasas de 1 s de carga al máximo, «se te escapa» y quedas aturdido 1,3 s.
- Portería: el 60 % central de cada pared lateral. Gana el primero en llegar a 5.
- **Micrófono**: soplar da un empuje continuo. Requiere abrir el archivo desde `localhost` o `https`, porque el navegador no da el micrófono a `file://` ni a la vista previa de claude.ai. Por ejemplo: `cd prototipos && python3 -m http.server`.
