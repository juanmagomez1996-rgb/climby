# Una Vida en 20 Minutos

Una recreativa en la que **Ramón vive una vida entera en unos minutos**: corre por su vida saltando obstáculos y
recogiendo lo que le da salud, dinero, felicidad y relaciones; toma decisiones en cartas ilustradas cuyas
consecuencias vuelven años después; juega minijuegos en momentos clave; envejece (niño → adolescente → adulto →
maduro → anciano) acompañado de su pareja, su hija y su perro; y al morir «sale del juego» con su epitafio.

Estilo **ilustración pintada** (gouache y lápiz de color). Todo el arte está generado con Higgsfield; el proceso y
los prompts para regenerarlo con coherencia están en [ART.md](ART.md).

## Contenido

- 5 etapas con su fondo panorámico, su velocidad, su salto (doble salto de los 13 a los 44) y su música.
- 45 eventos con ilustración propia y ventanas de edad: en cada vida salen unos 25–30 y nunca en el mismo orden.
  Consecuencias diferidas, riesgos, azar que depende de las stats y eventos que solo existen si tienes pareja o hija.
- 7 minijuegos: atrapar la pelota, tocar corazones, primer baile (ritmo), lluvia de monedas, entrega urgente
  (pulsar rápido), dormir al bebé y equilibrio.
- 16 coleccionables y 16 obstáculos distintos según la etapa (ganso, facturas, piel de plátano, paloma…).
- Familia animada que acompaña a Ramón y salta los obstáculos: Lucía o Marga (jóvenes y mayores), Alba (niña y
  adulta) y el perro Tornillo.
- Equilibrado con simulación (`tools/sim.js`): muerte media ≈ 74–77 años; los objetos rinden menos cuanto más
  llena está la barra, y la felicidad y las relaciones vuelven poco a poco a su punto medio si no se cuidan.

## Estructura

```
vida/
  lib/            juego Flutter + Flame (el que se publica)
    main.dart     arranque, orientación vertical, ciclo de vida, overlays
    game.dart     runner, familia, minijuegos, dibujo y HUD (lienzo lógico 540×960)
    life.dart     reglas de la vida: años, stats, eventos, consecuencias, epitafio (sin dibujo; testeable)
    gfx.dart      sprites, texto, partículas
    ui.dart       menú, carta de decisión, pausa/ajustes y pantalla final
    audio.dart    efectos y música por etapa con fundido cruzado
    prefs.dart    récord, vidas vividas y ajustes (shared_preferences)
  html/           prototipo HTML5 jugable (misma lógica y mismos assets); html/data.js es la fuente del contenido
  assets/         arte, audio, fuentes y assets/data/life.json (exportado de html/data.js)
  tools/          pipeline de assets (Higgsfield → croma → sprites/fondos), música, simulación y capturas
  android/        proyecto Android (id com.unavida20.game)
  test/           validación de datos y simulación de vidas
```

Si cambias el contenido en `html/data.js`, regenera el JSON de Flutter: `node tools/export_data.js`.

## Probar

```bash
cd vida
flutter pub get
flutter test                 # datos completos + 40 vidas simuladas
flutter run                  # en un móvil Android o emulador
```

Prototipo HTML: `cd vida/html && python3 -m http.server` y abre `http://localhost:8000`
(`?auto=1&age=40&fast=4` empieza directamente a los 40 años y a 4× de velocidad).

## Publicar en Google Play

1. **ID de la app**: `com.unavida20.game` (en `android/app/build.gradle.kts`). Cámbialo ahora si quieres otro:
   no se puede cambiar después de publicar.
2. **Clave de subida** (solo una vez; guárdala bien):
   ```bash
   keytool -genkey -v -keystore ~/vida-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   cp android/key.properties.example android/key.properties   # y rellénalo
   ```
   `key.properties` y los `.jks` están en `.gitignore`. Sin ese archivo la release se firma con la clave de
   depuración, que Play no acepta.
3. **Iconos**: `dart run flutter_launcher_icons` (usa `store/icon_1024.png` y `store/icon_foreground.png`).
4. **Compilar**: `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab`.
5. **Versión**: sube `version:` en `pubspec.yaml` (`1.0.0+1` → `1.0.1+2`…) en cada subida.
6. **Ficha**: textos en `store/LISTING.md`, política de privacidad en `store/PRIVACY.md`. El juego no recoge datos.

## Pendiente

- Icono del lanzador, gráfico destacado y capturas para la ficha de Play.
- Probar en un móvil real (rendimiento de los sprites en gama baja, volumen de la música).
- Más eventos y minijuegos: el formato de `html/data.js` admite añadirlos sin tocar código.
