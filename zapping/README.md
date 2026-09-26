# Zapping Infinito

Microjuegos de 4–5 segundos en una tele de otra dimensión, con estética de **plastilina realista** (stop-motion).
Versión Flutter + Flame del prototipo `prototypes/03-zapping.html`, lista para preparar su publicación en Google Play.

- 30 canales (microjuegos), cada uno con una mecánica distinta, + un jefe cada 10 canales.
- 4 vidas; cada 5 canales todo va más rápido.
- Solo vertical, táctil, sin anuncios, sin permisos y sin recogida de datos.

## Arte y animación

Todos los gráficos se generaron con **Higgsfield** a partir de una hoja de personajes de referencia para que el estilo sea uniforme:

| Tipo | Modelo | Dónde |
|---|---|---|
| Personajes, objetos, botones, logo, tele (fondo transparente) | GPT Image 2.5 | `assets/images/*.webp` |
| 13 fondos de canal (dioramas de plastilina) | GPT Image 2.5 | `assets/images/bg_*.webp` |
| 15 animaciones en bucle (Tito, Glotón, reportero, chef, presentador, Botón, Dormilón, jefe, maestro de kung-fu, funcionario, pastelero, equilibrista, bailarín, vaca alienígena y rival de ping-pong) | MiniMax H3 Max (vídeo con el mismo fotograma inicial y final) → croma y hoja de sprites de 60 fotogramas a 12 fps | `assets/images/anim_*.webp` |
| Icono y gráfico destacado | GPT Image 2.5 | `store/` |

Encima de eso, el código añade animación procedimental: "hervido" de stop-motion a 12 fps (`boil()` en `lib/gfx.dart`), estiramientos y aplastamientos, y partículas de bolitas de plastilina.
Los efectos de sonido están sintetizados (`assets/audio/*.wav`).

## Estructura

```
lib/
  main.dart      arranque, orientación, entrada táctil y overlays
  game.dart      bucle de partida (sintonía → juego → resultado), tele, HUD y efectos CRT
  channels.dart  canales 1–12 + el jefe
  channels2.dart canales 13–30 (deslizar, tirachinas, trazar, memoria, contar, apilar,
                 mantener y soltar, encontrar el raro, topos, cortar, equilibrio, pilotar,
                 ritmo, clasificar, girar, frotar, rodear y rebotar)
  gfx.dart       sprites, animaciones, texto, formas de plastilina y partículas
  ui.dart        menú, pausa y fin de partida
  sfx.dart       efectos de sonido y vibración
  prefs.dart     récord y ajustes
```

El juego se dibuja en un lienzo lógico de 540×960 que se escala para encajar en cualquier pantalla.

## Probar

```bash
cd zapping
flutter pub get
flutter run            # en un móvil o emulador Android
flutter test
```

El sandbox (probar un canal con vidas infinitas; se repite al terminar y las flechas del marcador pasan
al anterior o al siguiente) está oculto en el menú por ahora. Para abrirlo directamente en un canal:
`flutter run --dart-define=PRACTICE=4` (índice desde 0; el 30 es el jefe).

Para ver todos los canales en orden sin perder vidas (útil para capturas):
`flutter run --dart-define=TOUR=true` (añade `--dart-define=TOUR_FROM=12` para empezar por el canal 13).

## Cómo encajan las piezas

- **Fondos**: se generan vacíos y con el suelo en una altura conocida; `bx()`/`by()` en `Channel` convierten
  una fracción del decorado a pantalla, así cada personaje se apoya en su suelo, mesa o escenario.
- **Sombras de contacto** (`Gfx.shadow`) bajo todo lo que pisa el suelo.
- **Estados de reacción** (gana/pierde) generados con el personaje como referencia y recortados con la misma
  caja que su versión base (o que su animación), para que al cambiar de estado no se mueva de sitio.
- **Botones**: el texto solo ocupa la cara plana de la plastilina (`kButtonFace`) y se encoge hasta caber.
- **Pantalla**: el contenido se pinta en `ZappingGame.bleed`, algo más grande que el hueco de la tele; el marco
  opaco tapa lo que sobra, así nunca queda una rendija en las esquinas.

## Letras e interfaz de plastilina

Todo el texto (juego, HUD y menús) usa una fuente hecha de sprites: `assets/images/font.webp` con sus
métricas en `lib/font_data.dart` (A–Z, Ñ, vocales con tilde, 0–9 y signos). `Gfx.text` coloca cada letra
con un pequeño temblor de stop-motion a 12 fps y la tiñe del color pedido; en Flutter se usa `ClayText`.
También son sprites las barras (`bar_*`), las placas (`panel_*`, estiradas en 9 trozos), las marcas de acierto
y fallo, la vida perdida, la nota musical y los iconos redondos (`ico_*`).

## Publicar en Google Play

1. **ID de la app**: es `com.zappinginfinito.game` (en `android/app/build.gradle.kts`). Cámbialo ahora si quieres otro: no se puede cambiar después de publicar.
2. **Clave de subida** (solo una vez; guárdala bien):
   ```bash
   keytool -genkey -v -keystore ~/zapping-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   cp android/key.properties.example android/key.properties   # y rellénalo
   ```
   `key.properties` y los `.jks` están en `.gitignore`. Sin ese archivo, la build de release se firma con la clave de depuración, que Play no acepta.
3. **Compilar el bundle**:
   ```bash
   flutter build appbundle --release
   # → build/app/outputs/bundle/release/app-release.aab
   ```
4. **Versión**: sube `version:` en `pubspec.yaml` (`1.0.0+1` → `1.0.1+2`…) en cada subida; el número tras `+` es el `versionCode`.
5. **Ficha de Play Console**: textos en `store/LISTING.md`; icono 512×512, gráfico destacado 1024×500 y 8 capturas de 1080×2340 en `store/`.
6. **Contenido de la app**: la política de privacidad está en `store/PRIVACY.md` (publícala en una URL, por ejemplo con GitHub Pages). Seguridad de los datos: la app no recoge ni comparte datos.

Para regenerar los iconos del lanzador: `dart run flutter_launcher_icons`.
