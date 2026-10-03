# Canales 61–85 (tercera tanda)

Mismas reglas que la tanda anterior: una mecánica que no existe en ningún otro canal, partidas
cortas, personaje de plastilina animado cuando la historia lo pide, textos dentro de su zona
segura y todo colocado sobre el suelo o la mesa del decorado (`bx`/`by`/`foot`). Cada canal
tiene un bot en `test/new_test.dart` que demuestra que se puede ganar (y que sin hacer nada,
o haciéndolo mal, se pierde).

| # | Canal | Historia | Mecánica (nueva) | Gana / pierde | Animación |
|---|---|---|---|---|---|
| 61 | EL LABERINTO DEL HÁMSTER | Bolita vuelve a su madriguera | Girar el tablero con el dedo; la bola rueda por gravedad | Bola en el agujero / tiempo | — (física) |
| 62 | FONTANERO EXPRÉS | La flor del sótano tiene sed | Tocar tuberías 3×3 para girarlas | Agua conectada / tiempo | Topo fontanero |
| 63 | HUEVOS SALTARINES | Clotilde pone huevos desde la viga | Dibujar una cama elástica (recta) para que reboten | 2–3 huevos en la cesta / huevo roto | Gallina |
| 64 | EL GATO DEL TECHO | Bigotes corre patas arriba | Tocar para invertir la gravedad (suelo ↔ techo) | Aguantar / pinchazo | Gato corriendo |
| 65 | LÁSERES DEL MUSEO | El ladrón va a por el diamante | Arrastrar entre láseres que parpadean o tienen un hueco móvil | Diamante / alarma | — |
| 66 | TARZÁN DE PLASTILINA | Chita cruza la selva | Péndulo: tocar para soltarse y caer en la siguiente liana | Última liana / al río | — |
| 67 | CRONÓMETRO A CIEGAS | El búho relojero | Parar el cronómetro en N segundos; los números se esconden al segundo | Error ≤ 0,3 s (menos en niveles altos) | Búho relojero |
| 68 | ¿DÓNDE HAY MÁS? | El mapache Glotón | Comparar dos platos de bombones de un vistazo, 3 rondas cada vez más parejas | 3 aciertos / fallo o tarde | Mapache |
| 69 | LA CAJERA DEL SÚPER | La perezosa Lola | Elegir el montón de monedas que suma el cambio | Cambio justo / otro montón | Perezosa cajera |
| 70 | ESCRIBE LA PALABRA | El loro profesor | Tocar los cubos de letras en orden (con letras trampa) | Palabra completa / letra mal | Loro profesor |
| 71 | COLOREA POR NÚMEROS | El cerdito pintor | Elegir bote y pintar cada zona con su número | Cuadro completo / color equivocado | Cerdito pintor |
| 72 | FUEGOS ARTIFICIALES | Fiesta del pueblo | Tocar cada cohete justo en lo más alto | 4–5 fuegos / 2 fallos | — (partículas) |
| 73 | ATRAPA LA GALLINA | Clotilde se escapa | Llevar la red y soltar; la gallina huye y amaga | Atrapada / tiempo | Gallina |
| 74 | EL CAMINO DEL RATÓN | Ratón Pérez busca el queso | Memorizar un camino de baldosas y repetirlo | Queso / ratonera | — |
| 75 | PELUQUERÍA GALÁCTICA | Zorg quiere el peinado de la foto | Ciclar pelo, color y gafas hasta copiar la foto | Igual que la foto / tiempo | — (piezas) |
| 76 | LA BOMBA DE BICI | El conejo ciclista tiene prisa | Bombear arriba y abajo y parar con la aguja en verde | Verde 0,9 s / reventar | Conejo ciclista |
| 77 | PARTE LA TORTILLA | Los gemelos quieren la mitad | Un solo corte deslizando | ≥ 44 % cada parte / corte torcido | — |
| 78 | CARRERA DE BAÑERAS | El capitán Patito baja el río | Río que avanza solo; mover la bañera entre rocas y troncos | Aguantar / chocar | — |
| 79 | LA FOTO DEL YETI | Nadie cree que existe | Disparar cuando el yeti está entero dentro del visor | Foto buena / cortado o vacío | Yeti caminando |
| 80 | CONSTELACIONES | El erizo astrónomo | Un trazo sin levantar el dedo por todas las estrellas (y sin tocar el meteorito) | Todas / meteorito | Erizo astrónomo |
| 81 | ENCAJA LA FIGURA | El juguete del bebé gigante | Tocar para girar, arrastrar al agujero de su forma | 3 encajadas / tiempo | — |
| 82 | EL PINGÜINO PATINADOR | Pingu tiene hambre | Deslizar: el pingüino no frena hasta chocar con un bloque | Pasar por el pez / tiempo | — |
| 83 | SUMO DE MOCHIS | Final del torneo | Empujar con física (masa y choques) al rival fuera del círculo | Rival fuera / tú fuera | — (física) |
| 84 | DESENREDA LOS CABLES | Detrás de la tele | Arrastrar enchufes hasta que ningún cable se cruce | Sin cruces / tiempo | — |
| 85 | JENGA DE GOFRES | El desayuno inestable | Quitar gofres que no sujetan (cada piso necesita el centro o los dos lados) | 3–4 quitados / derrumbe | — |

Imágenes nuevas: 25 decorados, 42 objetos y 11 animaciones (60 fotogramas a 12 fps). Recetas en
el README.
