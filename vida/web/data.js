// Una Vida en 20 Minutos — contenido del juego (declarativo, portable a Flutter).
// fx = [Salud, Dinero, Felicidad, Relaciones]
// Evento: { id, ages:[min,max], key (obligatorio si se cumple), need/not: [flags], q, o:[opciones] }
// Opción: { t, fx, m (mensaje), tag (momento notable), flag, unflag, partner,
//           later:{in|at, t, fx, unflag, cause}, risk:{p, fx, t, cause},
//           chance:{p, stat, ok:{fx,m,flag,partner,later}, ko:{...}} }
// {p} se sustituye por el nombre de la pareja y {h} por el de la hija.
window.LIFE = {
  stats: ['Salud', 'Dinero', 'Felicidad', 'Relaciones'],
  start: [75, 15, 60, 50],

  stages: [
    { from: 0, name: 'INFANCIA', bg: 'bg_0', sprite: 'ramon0', speed: 190, jump: 980, dbl: false },
    { from: 13, name: 'ADOLESCENCIA', bg: 'bg_1', sprite: 'ramon1', speed: 235, jump: 1020, dbl: true },
    { from: 20, name: 'VIDA ADULTA', bg: 'bg_2', sprite: 'ramon2', speed: 260, jump: 1000, dbl: true },
    { from: 45, name: 'MADUREZ', bg: 'bg_3', sprite: 'ramon3', speed: 230, jump: 930, dbl: false },
    { from: 65, name: 'VEJEZ', bg: 'bg_4', sprite: 'ramon4', speed: 170, jump: 820, dbl: false },
  ],

  // Objetos que se recogen (stat: índice, v: valor; neg: efecto secundario)
  pickups: {
    apple: { fx: [3, 0, 0, 0] }, carrot: { fx: [3, 0, 0, 0] },
    coin: { fx: [0, 2, 0, 0] }, bill: { fx: [0, 4, 0, 0] },
    star: { fx: [0, 0, 3, 0] }, ball: { fx: [1, 0, 3, 0] }, balloon: { fx: [0, 0, 3, 0], fly: 1 },
    heart: { fx: [0, 0, 0, 3] }, letter: { fx: [0, 0, 1, 3] }, flowers: { fx: [0, 0, 1, 4] },
    trophy: { fx: [0, 2, 4, 0] }, book: { fx: [0, 2, 1, 0] }, clock: { fx: [1, 0, 2, 0] },
    lollipop: { fx: [-2, 0, 4, 0], treat: 1 }, cake: { fx: [-2, 0, 4, 1], treat: 1 }, burger: { fx: [-3, 0, 4, 0], treat: 1 },
  },
  // Obstáculos (h: altura aproximada en px del juego; air: vuela a media altura)
  hazards: {
    puddle: { fx: [-2, 0, -2, 0], h: 22, w: 90, msg: '¡Chof!' },
    rock: { fx: [-5, 0, -1, 0], h: 52, w: 64, msg: '¡Au!' },
    goose: { fx: [-2, 0, -4, 0], h: 80, w: 80, msg: '¡Un ganso!' },
    duck: { fx: [0, 0, -2, 0], h: 44, w: 48, msg: '¡Cuac!' },
    homework: { fx: [0, 0, -5, 0], h: 84, w: 66, msg: 'Deberes...' },
    skate: { fx: [-4, 0, -1, 0], h: 30, w: 86, msg: '¡Patinazo!' },
    cone: { fx: [-3, 0, -1, 0], h: 72, w: 56, msg: '¡Cono!' },
    bills: { fx: [0, -7, -2, 0], h: 44, w: 84, msg: 'Facturas' },
    coffee: { fx: [0, -1, -3, 0], h: 36, w: 90, msg: 'Café derramado' },
    briefcase: { fx: [0, 0, -4, -2], h: 60, w: 70, msg: 'Más trabajo' },
    banana: { fx: [-6, 0, -1, 0], h: 26, w: 70, msg: '¡Plátano!' },
    wetfloor: { fx: [-5, 0, 0, 0], h: 84, w: 56, msg: 'Suelo mojado' },
    cactus: { fx: [-4, 0, -1, 0], h: 76, w: 56, msg: '¡Pincha!' },
    pigeon: { fx: [0, 0, -3, 0], h: 50, w: 74, air: 1, msg: 'Paloma' },
    storm: { fx: [-1, 0, -5, 0], h: 60, w: 90, air: 1, msg: 'Nubarrón' },
    plane: { fx: [0, 0, -2, 0], h: 40, w: 70, air: 1, msg: 'Avioncito' },
  },
  // Qué aparece en cada etapa (pesos)
  spawn: [
    { pick: { apple: 3, ball: 3, star: 3, heart: 2, lollipop: 2, carrot: 2, coin: 1, balloon: 2 }, haz: { puddle: 3, rock: 2, goose: 2, duck: 2 }, gap: [1.1, 1.9] },
    { pick: { star: 3, heart: 3, letter: 2, coin: 2, burger: 2, book: 2, apple: 1 }, haz: { homework: 3, skate: 3, rock: 1, cone: 2, plane: 2 }, gap: [0.95, 1.7] },
    { pick: { coin: 4, bill: 2, heart: 2, star: 2, apple: 2, flowers: 1, burger: 1 }, haz: { bills: 3, briefcase: 2, cone: 2, wetfloor: 2, coffee: 2, pigeon: 2 }, gap: [0.9, 1.6] },
    { pick: { apple: 3, carrot: 3, bill: 2, heart: 2, trophy: 1, cake: 2, burger: 2, clock: 1 }, haz: { cactus: 2, banana: 3, bills: 2, storm: 2, coffee: 1 }, gap: [1.0, 1.8] },
    { pick: { heart: 3, letter: 3, flowers: 2, star: 2, apple: 2, cake: 2, clock: 1 }, haz: { banana: 3, wetfloor: 2, pigeon: 2, puddle: 2, duck: 1 }, gap: [1.3, 2.2] },
  ],

  // Momentos de acción (minijuegos cortos)
  moments: [
    { id: 'pelota', ages: [4, 12], title: '¡ATRAPA LA PELOTA!', hint: 'Toca la pelota' },
    { id: 'corazones', ages: [13, 40], title: '¡TOCA LOS CORAZONES!', hint: 'Toca todos los corazones' },
    { id: 'ritmo', ages: [15, 35], title: '¡PRIMER BAILE!', hint: 'Toca cuando el aro cierre' },
    { id: 'monedas', ages: [20, 64], title: '¡COGE LAS MONEDAS!', hint: 'Toca las monedas' },
    { id: 'informe', ages: [22, 62], title: '¡ENTREGA URGENTE!', hint: '¡Toca rápido, rápido!' },
    { id: 'bebe', ages: [32, 38], need: ['hija'], title: '¡DUERME AL BEBÉ!', hint: 'Toca a izquierda o derecha para acunar' },
    { id: 'equilibrio', ages: [13, 99], title: '¡MANTÉN EL EQUILIBRIO!', hint: 'Toca izquierda o derecha' },
  ],

  events: [
    // ---------- INFANCIA ----------
    { id: 'cole', ages: [6, 7], key: 1, q: 'Primer día de cole. ¿Con quién te sientas?', o: [
      { t: 'Con el niño raro que come pegamento', fx: [0, 0, 5, 10], tag: 'se sentó con el niño raro', later: { at: 26, t: 'El niño raro ahora es millonario. Te invita a su yate.', fx: [0, 15, 10, 5] } },
      { t: 'Solo, al fondo, junto a la ventana', fx: [0, 0, -3, -8], later: { at: 30, t: 'Sigues eligiendo la mesa del fondo. En todo.', fx: [0, 0, -5, -5] } }] },
    { id: 'diente', ages: [6, 8], q: 'Se te cae un diente. ¿Qué haces con él?', o: [
      { t: 'Debajo de la almohada', fx: [0, 2, 4, 0], m: 'El Ratoncito te deja una moneda y una nota con faltas.' },
      { t: 'Lo vendes en el patio', fx: [0, 4, 2, -3], tag: 'vendió un diente en el patio', later: { in: 30, t: 'Tu olfato para los negocios sigue intacto.', fx: [0, 10, 0, 0] } }] },
    { id: 'tardes', ages: [8, 10], key: 1, q: '¿Qué haces por las tardes?', o: [
      { t: 'Fútbol en el descampado', fx: [10, 0, 5, 5], tag: 'jugó al fútbol en el descampado', risk: { p: 0.25, fx: [-15, 0, -5, 0], t: 'Te rompes la pierna. Vas escayolado a tu cumple.', cause: 'una patada mal dada' } },
      { t: 'Clases de piano', fx: [0, -3, 3, 0], tag: 'aprendió piano', later: { at: 50, t: 'Tocas el piano en una boda. Llora todo el mundo.', fx: [0, 0, 12, 10] } },
      { t: 'Videojuegos hasta las tantas', fx: [-5, 0, 10, 0], later: { at: 35, t: 'Sigues siendo imbatible al Blorptris. No sirve de nada.', fx: [0, 0, 5, 0] } }] },
    { id: 'hamster', ages: [7, 10], q: 'Te toca llevarte a casa el hámster de la clase.', o: [
      { t: 'Lo cuidas como a un hijo', fx: [0, 0, 6, 6], tag: 'cuidó del hámster de la clase' },
      { t: 'Lo dejas en la terraza', fx: [0, 0, -4, -6], m: 'El hámster ha visto cosas. Ya no es el mismo.' }] },
    { id: 'bici', ages: [8, 11], q: 'Tu padre le quita los ruedines a tu bici.', o: [
      { t: '¡Pedaleas sin miedo!', fx: [5, 0, 8, 0], tag: 'aprendió a montar en bici', risk: { p: 0.3, fx: [-8, 0, -3, 0], t: 'Te comes una farola.', cause: 'una farola' } },
      { t: 'Te niegas en redondo', fx: [0, 0, -3, 0], later: { in: 20, t: 'Sigues sin saber montar en bici. Lo ocultas bien.', fx: [0, 0, -3, 0] } }] },
    { id: 'lentejas', ages: [7, 11], q: 'En el comedor hay lentejas.', o: [
      { t: 'Te las comes todas', fx: [6, 0, -2, 0] },
      { t: 'Las escondes en la servilleta', fx: [-3, 0, 3, 0], m: 'La servilleta pesa sospechosamente.' }] },
    { id: 'campamento', ages: [10, 12], q: '¿Te vas de campamento de verano?', o: [
      { t: '¡Sí!', fx: [3, -3, 8, 8], tag: 'fue de campamento y lloró la primera noche' },
      { t: 'Me quedo con la abuela', fx: [0, 0, 3, 5], later: { in: 25, t: 'Aún haces las croquetas con la receta de la abuela.', fx: [0, 0, 8, 3] } }] },

    // ---------- ADOLESCENCIA ----------
    { id: 'pelo', ages: [13, 15], q: '¿Te tiñes el pelo de azul?', o: [
      { t: 'Sí, azul eléctrico', fx: [0, 0, 8, 2], m: 'Tu madre llora. Tú brillas.' },
      { t: 'Mejor no', fx: [0, 0, -2, 0] }] },
    { id: 'banda', ages: [14, 17], q: 'Tus amigos montan un grupo de música.', o: [
      { t: 'Tocas la batería', fx: [-2, 0, 10, 8], tag: 'tocó la batería en Los Grapas', later: { in: 25, t: 'Los Grapas se reúnen para un concierto. Sois horribles. Es precioso.', fx: [0, 0, 10, 8] } },
      { t: 'Llevas las camisetas', fx: [0, 5, 3, 3] }] },
    { id: 'examen', ages: [15, 16], key: 1, q: 'Mañana hay examen. ¿Estudias o te vas de fiesta?', o: [
      { t: 'Estudio', fx: [0, 0, -5, -3], tag: 'estudió la noche del examen', later: { at: 30, t: 'Aquel examen te abrió una puerta. Una pequeña.', fx: [0, 20, 0, 0] } },
      { t: 'Fiesta', fx: [-5, 0, 10, 10], tag: 'se fue de fiesta la noche del examen', later: { at: 45, t: 'Aquella fiesta sigue siendo tu mejor recuerdo.', fx: [0, 0, 8, 0] } }] },
    { id: 'lucia', ages: [16, 18], key: 1, q: '¿Le pides salir a Lucía?', o: [
      { t: 'Sí, con una flor del parque', tag: 'le pidió salir a Lucía', chance: { p: 0.4, stat: 3,
        ok: { fx: [0, 0, 15, 15], flag: 'pareja', partner: 'Lucía', m: 'Lucía dice que sí. Te tiembla todo.' },
        ko: { fx: [0, 0, -15, -5], m: 'Te dice que no. Delante de todos.', later: { at: 60, t: 'Ves a Lucía en el súper. Te saluda con cariño.', fx: [0, 0, 6, 0] } } } },
      { t: 'Ni de broma', fx: [0, 0, -5, 0], tag: 'nunca le pidió salir a Lucía', later: { at: 62, t: 'Aún piensas en Lucía a veces.', fx: [0, 0, -10, 0] } }] },
    { id: 'heladeria', ages: [16, 18], q: 'Te ofrecen curro de verano en una heladería.', o: [
      { t: 'Aceptas', fx: [-2, 8, 3, 3], tag: 'vendió helados un verano entero' },
      { t: 'Verano de siesta', fx: [3, 0, 6, 0] }] },
    { id: 'carnet', ages: [18, 19], q: 'Examen práctico del carnet de conducir.', o: [
      { t: 'Te presentas', chance: { p: 0.55, stat: 0,
        ok: { fx: [0, -5, 8, 0], m: '¡Aprobado a la primera!', flag: 'carnet' },
        ko: { fx: [0, -8, -6, 0], m: 'Te subes a una rotonda. Literalmente.' } } },
      { t: 'Paso, voy en bus', fx: [0, 3, 0, 0] }] },
    { id: 'insti', ages: [18, 19], key: 1, q: 'Se acaba el instituto. ¿Y ahora?', o: [
      { t: 'Universidad', fx: [0, -10, 0, 5], tag: 'fue a la universidad', later: { at: 28, t: 'El título por fin sirve para algo.', fx: [0, 25, 5, 0] } },
      { t: 'Aceptas el trabajo de alfombras', fx: [-3, 15, -3, 0], tag: 'aceptó el trabajo de alfombras', later: { at: 45, t: 'Eres el rey de las alfombras del barrio.', fx: [0, 15, 5, 5] } },
      { t: 'Te vas a viajar sin un duro', fx: [0, -15, 15, 5], tag: 'se fue a viajar sin un duro' }] },

    // ---------- VIDA ADULTA ----------
    { id: 'perro', ages: [22, 26], key: 1, q: 'Un perro te sigue hasta casa.', o: [
      { t: 'Te lo quedas. Se llama Tornillo.', fx: [3, -5, 10, 5], flag: 'perro', tag: 'adoptó a Tornillo', later: { in: 13, t: 'Tornillo se muere de viejo. Lo enterráis bajo el limonero.', fx: [0, 0, -15, 0], unflag: 'perro' } },
      { t: 'Lo devuelves a la calle', fx: [0, 0, -3, 0], later: { in: 16, t: 'Ves un perro igualito. Te mira raro.', fx: [0, 0, -5, 0] } }] },
    { id: 'gimnasio', ages: [22, 40], q: 'Te apuntas al gimnasio en enero.', o: [
      { t: 'Vas todos los días', fx: [12, -4, 3, 0], tag: 'fue al gimnasio más de una semana' },
      { t: 'Pagas y no vas', fx: [0, -8, -2, 0], m: 'Tu cuota paga los músculos de otros.' }] },
    { id: 'viaje', ages: [23, 40], q: 'Oferta de última hora: viaje a Islandia.', o: [
      { t: 'Vas', fx: [0, -12, 14, 4], tag: 'vio auroras boreales' },
      { t: 'Te quedas', fx: [0, 3, -3, 0] }] },
    { id: 'boda', ages: [27, 30], key: 1, need: ['pareja'], q: '{p} quiere casarse contigo.', o: [
      { t: '¡Sí, quiero!', fx: [0, -10, 15, 15], flag: 'casado', tag: 'se casó con {p}' },
      { t: 'Todavía no...', fx: [0, 0, -5, -15], chance: { p: 0.5, stat: 3,
        ok: { m: '{p} espera. Pero lo apunta.' },
        ko: { unflag: 'pareja', m: '{p} se va. Se lleva la tostadora.' } } }] },
    { id: 'app', ages: [27, 31], key: 1, not: ['pareja'], q: 'Una app de citas te empareja con Marga.', o: [
      { t: 'Quedas con ella', tag: 'quedó con Marga', chance: { p: 0.6, stat: 3,
        ok: { fx: [0, -3, 12, 15], flag: 'pareja', partner: 'Marga', m: 'Marga se ríe de tus chistes. De todos.' },
        ko: { fx: [0, -3, -8, 0], m: 'Marga va al baño y no vuelve.' } } },
      { t: 'Mejor solo', fx: [0, 0, -5, -8] }] },
    { id: 'piso', ages: [28, 34], q: '¿Compras piso o sigues de alquiler?', o: [
      { t: 'Hipoteca a 30 años', fx: [0, -20, 5, 0], tag: 'se hipotecó 30 años', later: { in: 30, t: 'Terminas de pagar el piso. Lo celebras con una croqueta.', fx: [0, 15, 10, 0] } },
      { t: 'Sigo de alquiler', fx: [0, -5, 0, 0], later: { in: 8, t: 'El casero sube el alquiler. Otra vez.', fx: [0, -10, -4, 0] } }] },
    { id: 'hijos', ages: [31, 34], key: 1, need: ['pareja'], q: '¿Tener hijos?', o: [
      { t: 'Sí, una niña: Alba', fx: [-5, -20, 12, 10], flag: 'hija', tag: 'tuvo una hija, Alba', later: { at: 58, t: 'Alba te llama solo para hablar.', fx: [0, 0, 15, 10] } },
      { t: 'Mejor una planta', fx: [0, 0, 3, 0], tag: 'cuidó de una planta 23 años', flag: 'planta', later: { at: 55, t: 'La planta sigue viva. Es tu mayor logro.', fx: [0, 0, 5, 0] } }] },
    { id: 'plantavecina', ages: [31, 35], not: ['pareja'], q: 'Tu vecina se muda y te deja una planta.', o: [
      { t: 'La cuidas', fx: [0, 0, 4, 2], flag: 'planta', tag: 'adoptó una planta' },
      { t: 'La olvidas en la escalera', fx: [0, 0, -2, -2] }] },
    { id: 'reunion', ages: [26, 44], q: 'Reunión a las 18:55 que podría haber sido un correo.', o: [
      { t: 'Participas con entusiasmo', fx: [-3, 5, -5, 0] },
      { t: 'Finges que se te va la conexión', fx: [0, 0, 6, 0], risk: { p: 0.3, fx: [0, -8, -3, 0], t: 'Te pillan. La conexión eras tú.' } }] },
    { id: 'mudanza', ages: [26, 44], q: 'Un amigo te pide ayuda con la mudanza. Un quinto sin ascensor.', o: [
      { t: 'Ayudas', fx: [-6, 0, 0, 12], tag: 'subió un sofá a un quinto sin ascensor' },
      { t: 'Tienes «un compromiso»', fx: [0, 0, 0, -8] }] },
    { id: 'ascenso', ages: [35, 38], key: 1, q: 'Tu jefa te ofrece un ascenso... a cambio de tus fines de semana.', o: [
      { t: 'Aceptas', fx: [-10, 25, -5, -15], tag: 'trabajó todos los fines de semana', flag: 'curro' },
      { t: 'Rechazas', fx: [0, -5, 5, 5] }] },
    { id: 'funcion', ages: [38, 41], need: ['hija'], q: '{h} tiene función de fin de curso. Hace de árbol.', o: [
      { t: 'Vas y lo grabas todo', fx: [0, -2, 8, 12], tag: 'no se perdió la función del árbol' },
      { t: 'Tienes reunión', fx: [0, 5, -6, -12], later: { in: 12, t: '{h} te recuerda lo del árbol en tu cumpleaños.', fx: [0, 0, -5, -5] } }] },
    { id: 'crisis', ages: [40, 43], key: 1, q: 'Crisis de los 40.', o: [
      { t: 'Te compras una moto roja', fx: [0, -15, 15, 0], tag: 'se compró una moto roja', risk: { p: 0.3, fx: [-30, 0, -5, 0], t: 'Te la pegas con la moto. Tres meses en el hospital.', cause: 'la moto roja' } },
      { t: 'Corres una maratón', fx: [15, 0, 5, 0], tag: 'corrió una maratón' },
      { t: 'Lo aceptas y ya', fx: [0, 0, -5, 5] }] },

    // ---------- MADUREZ ----------
    { id: 'cuñado', ages: [45, 48], key: 1, q: 'Tu cuñado te propone invertir en criptopatatas.', o: [
      { t: 'Meto todos mis ahorros', tag: 'lo metió todo en criptopatatas', chance: { p: 0.45,
        ok: { fx: [0, 40, 10, 0], m: '¡Las criptopatatas se disparan! Eres rico.' },
        ko: { fx: [-5, -40, -10, 0], m: 'Las criptopatatas eran patatas.', cause: 'el disgusto de las criptopatatas' } } },
      { t: 'Ni un euro', fx: [0, 0, 0, -5], m: 'Tu cuñado deja de hablarte. Ganas algo.' }] },
    { id: 'tatuaje', ages: [46, 50], need: ['hija'], q: '{h} quiere hacerse un tatuaje.', o: [
      { t: 'La acompañas', fx: [0, -3, 6, 10], tag: 'acompañó a {h} a tatuarse' },
      { t: 'Se lo prohíbes', fx: [0, 0, -3, -8], m: '{h} se lo hace igual. Es un dibujo tuyo.' }] },
    { id: 'analitica', ages: [45, 58], q: 'El médico te manda una analítica.', o: [
      { t: 'Vas en ayunas', fx: [6, 0, -1, 0] },
      { t: 'Ya iré', fx: [-4, 0, 0, 0], later: { in: 8, t: 'Aquella analítica habría venido bien.', fx: [-10, 0, 0, 0], cause: 'la analítica que nunca se hizo' } }] },
    { id: 'huerto', ages: [47, 60], q: '¿Montas un huerto en el patio?', o: [
      { t: 'Sí', fx: [8, 2, 8, 3], tag: 'cultivó tomates feos y deliciosos' },
      { t: 'Compro los tomates', fx: [0, -2, 0, 0] }] },
    { id: 'antiguos', ages: [48, 58], q: 'Cena de antiguos alumnos.', o: [
      { t: 'Vas', fx: [0, 0, 6, 8], m: 'Todos están calvos. Tú también.' },
      { t: 'No vas', fx: [0, 0, -2, -3] }] },
    { id: 'croquetas', ages: [52, 55], key: 1, q: 'El médico dice: menos croquetas.', o: [
      { t: 'Le haces caso', fx: [12, 0, -5, 0] },
      { t: 'Una croqueta más no mata', fx: [-8, 0, 8, 0], tag: 'no renunció a las croquetas', later: { in: 11, t: 'Las croquetas pasan factura.', fx: [-25, 0, 0, 0], cause: 'las croquetas' } }] },
    { id: 'prejubila', ages: [52, 60], not: ['jubilado'], q: 'Reestructuración en la empresa. Te ofrecen prejubilarte.', o: [
      { t: 'Aceptas', fx: [3, 10, 4, 0], flag: 'jubilado', tag: 'se prejubiló' },
      { t: 'Te quedas', fx: [-4, 6, -3, 0] }] },
    { id: 'bodahija', ages: [56, 60], need: ['hija'], q: '{h} se casa. Quiere bailar contigo.', o: [
      { t: 'Bailas fatal pero feliz', fx: [0, -8, 15, 12], tag: 'bailó en la boda de {h}' },
      { t: 'Te da vergüenza', fx: [0, -8, -5, -10] }] },
    { id: 'nieto', ages: [60, 64], need: ['hija'], q: '¡Vas a ser abuelo!', o: [
      { t: 'Te ofreces a cuidarlo', fx: [-3, 0, 12, 12], flag: 'nieto', tag: 'cuidó de su nieto' },
      { t: 'Solo los domingos', fx: [0, 0, 5, 3], flag: 'nieto' }] },
    { id: 'jubila', ages: [63, 66], key: 1, not: ['jubilado'], q: '¿Te jubilas ya?', o: [
      { t: 'Sí, a mirar obras', fx: [5, -10, 10, 5], flag: 'jubilado', tag: 'miró obras con pasión' },
      { t: 'Sigo currando', fx: [-10, 15, -5, -5] }] },

    // ---------- VEJEZ ----------
    { id: 'aquagym', ages: [66, 80], q: 'Aquagym en el polideportivo.', o: [
      { t: 'Te apuntas', fx: [8, -2, 6, 6] },
      { t: 'Prefieres supervisar obras', fx: [0, 0, 4, 0], tag: 'supervisó catorce obras sin cobrar' }] },
    { id: 'tablet', ages: [67, 80], q: 'Te regalan una tablet.', o: [
      { t: 'Aprendes a hacer videollamadas', fx: [0, 0, 6, 10], tag: 'aprendió a hacer videollamadas' },
      { t: 'La usas de tabla de cortar', fx: [0, 0, 2, 0] }] },
    { id: 'baile', ages: [69, 72], key: 1, q: 'Hay baile en el centro de mayores.', o: [
      { t: '¡A bailar!', fx: [3, 0, 12, 10], tag: 'bailó un pasodoble', risk: { p: 0.25, fx: [-20, 0, 0, 0], t: 'Te rompes la cadera en un pasodoble.', cause: 'un pasodoble' } },
      { t: 'Sofá y tele', fx: [-5, 0, -3, -5] }] },
    { id: 'bingo', ages: [70, 88], q: 'Bingo en el centro de mayores.', o: [
      { t: 'Juegas tres cartones', chance: { p: 0.3,
        ok: { fx: [0, 20, 10, 0], m: '¡BINGO! Te llevas un jamón.' },
        ko: { fx: [0, -2, -1, 0], m: 'Te falta un número. Siempre te falta un número.' } } },
      { t: 'Solo vas por la merienda', fx: [0, 0, 3, 4] }] },
    { id: 'parejamuere', ages: [74, 79], need: ['pareja'], auto: { t: '{p} se va antes que tú. La casa suena distinta.', fx: [-5, 0, -20, -10], unflag: 'pareja' } },
    { id: 'amigo', ages: [76, 78], key: 1, q: 'Un viejo amigo te escribe después de 40 años.', o: [
      { t: 'Le llamas', fx: [0, 0, 10, 15], tag: 'volvió a llamar a un viejo amigo' },
      { t: 'Mañana', fx: [0, 0, -8, -5], later: { in: 3, t: 'Tu amigo ha muerto. El mañana no llegó.', fx: [0, 0, -15, -5] } }] },
    { id: 'memorias', ages: [75, 90], q: 'Te proponen escribir tus memorias.', o: [
      { t: 'Las escribes', fx: [0, 3, 10, 4], tag: 'escribió sus memorias (nadie las leyó)' },
      { t: 'Bastante tuve con vivirlas', fx: [0, 0, 2, 0] }] },
    { id: 'ahorros', ages: [82, 86], key: 1, q: '¿Qué haces con tus ahorros?', o: [
      { t: 'Repartirlos en vida', fx: [0, -30, 10, 15], tag: 'lo repartió todo en vida' },
      { t: 'Un crucero', fx: [0, -25, 15, 0], tag: 'se fue de crucero' },
      { t: 'Bajo el colchón', fx: [0, 0, -3, -3] }] },
  ],
};
