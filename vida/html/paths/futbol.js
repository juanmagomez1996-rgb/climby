// Camino de vida: FÚTBOL (vocación 1 de 10). Se desbloquea jugando al fútbol en el descampado.
// Etapas: cantera (13–19) y Primera División (20–44). Finales: leyenda, entrenador de barrio, juerguista.
(L => {
  L.partners['Vanesa'] = 'vanesa';
  L.paths.futbol = {
    name: 'Futbolista', icon: 'soccerball', moments: ['penaltis', 'penaltis', 'canasta'],
    hint: 'Pista: juega mucho al fútbol de pequeño.',
    fallback: { juerga: 'juerga', _: 'entrenador' },   // final si no llegó al punto de giro
    stages: {
      1: { bg: 'bgf_cantera', sprite: 'ramon1_futbol', name: 'LA CANTERA',
           spawn: { pick: { soccerball: 4, energy: 2, star: 2, heart: 2, jersey: 1 }, haz: { cone: 3, defender: 2, homework: 1, puddle: 1 }, gap: [0.95, 1.7] } },
      2: { bg: 'bgf_estadio', sprite: 'ramon2_futbol', name: 'PRIMERA DIVISIÓN', speed: 280,
           spawn: { pick: { soccerball: 3, goldboot: 1, medal: 2, jersey: 2, energy: 2, coin: 3, beer: 1 }, haz: { defender: 4, yellowcard: 2, redcard: 1, flashcam: 2 }, gap: [0.85, 1.5] } },
    },
    branches: {
      leyenda: { name: 'Leyenda del fútbol', icon: 'cup', epitaph: 'Ganó todo lo que se podía ganar.',
        stages: { 3: { bg: 'bgf_tv', sprite: 'ramon3_tv', name: 'LEYENDA EN LA TELE',
          spawn: { pick: { mic: 3, goldboot: 1, coin: 3, heart: 2, medal: 1 }, haz: { flashcam: 3, tvcamera: 2, bills: 1 }, gap: [1.0, 1.8] } } } },
      entrenador: { name: 'Entrenador de barrio', icon: 'whistle', epitaph: 'Enseñó a chutar a medio barrio.',
        stages: { 3: { bg: 'bgf_barrio', sprite: 'ramon3_coach', name: 'ENTRENADOR DE BARRIO',
          spawn: { pick: { whistle: 3, soccerball: 3, heart: 3, apple: 2 }, haz: { cone: 3, puddle: 2, rock: 2 }, gap: [1.0, 1.8] } } } },
      juerga: { name: 'El Juerguista', icon: 'beer', epitaph: 'Nunca dejó que nadie pagara una ronda.',
        stages: { 3: { bg: 'bgf_bar', sprite: 'ramon3_bar', name: 'EL BAR DE LA PEÑA',
          spawn: { pick: { beer: 3, coin: 3, heart: 2, burger: 2 }, haz: { bills: 3, coffee: 2, banana: 2 }, gap: [1.0, 1.8] } } } },
    },
  };
  L.events.push(
    { id: 'ojeador', ages: [11, 14], key: 1, need: ['futbolin'], not: ['career'], q: 'Un ojeador del CD Río Chico te ve jugar en el descampado. Quiere ficharte para la cantera.', o: [
      { t: 'Firmo con mi mejor letra', fx: [5, 0, 10, 3], path: 'futbol', tag: 'entró en la cantera del Río Chico' },
      { t: 'Prefiero jugar con mis amigos', fx: [0, 0, 2, 5], later: { at: 40, t: 'Ves un partido del Río Chico. Podrías haber sido tú.', fx: [0, 0, -4, 0] } }] },
    { id: 'debut', ages: [17, 18], key: 1, need: ['futbol'], q: 'Debut con el primer equipo. Minuto 89, penalti a favor.', o: [
      { t: 'Lo tiro yo', game: 'penaltis', gameTitle: '¡PENALTI EN TU DEBUT!', single: 1,
        win: { fx: [0, 6, 12, 5], m: '¡GOOOL! El estadio corea tu nombre.', tag: 'marcó en su debut', flag: 'crack' },
        lose: { fx: [0, 0, -8, 0], m: 'Al palo. Sales en todos los memes.' } },
      { t: 'Se lo dejo al capitán', fx: [0, 0, -3, 5], m: 'El capitán marca y te dedica el gol.' }] },
    { id: 'fichaje', ages: [22, 24], key: 1, need: ['futbol'], q: 'El club más grande del mundo te ofrece un contrato millonario. Tu club de toda la vida te pide que te quedes.', o: [
      { t: 'Me voy al gigante', fx: [0, 30, 6, -6], flag: 'figura', tag: 'fichó por el club más grande del mundo' },
      { t: 'Me quedo en casa', fx: [0, 8, 6, 10], flag: 'fiel', tag: 'fue fiel a su club de toda la vida', later: { in: 20, t: 'Tu club retira tu dorsal. La grada canta tu nombre.', fx: [0, 0, 10, 8] } }] },
    { id: 'vanesa', ages: [25, 29], key: 1, need: ['futbol'], not: ['pareja'], q: 'Vanesa, la reportera de la tele, te pide una entrevista… y tu número.', o: [
      { t: 'Le das tu número', fx: [0, 0, 10, 12], flag: 'pareja', partner: 'Vanesa', tag: 'se enamoró de Vanesa, la reportera' },
      { t: 'Solo la entrevista', fx: [0, 0, -2, -3] }] },
    { id: 'vanesa2', img: 'vanesa', ages: [25, 29], need: ['futbol', 'pareja'], q: 'Vanesa, la reportera de la tele, te pide una entrevista… y tu número. {p} lo ve todo en directo.', o: [
      { t: 'Le dices que ya tienes a {p}', fx: [0, 0, 3, 10], tag: 'le fue fiel a {p}' },
      { t: 'Te vas a cenar con Vanesa', fx: [0, 0, 8, -18], m: '{p} rompe contigo en la portada de todas las revistas.', partner: 'Vanesa', tag: 'dejó a su pareja por Vanesa' }] },
    { id: 'noches', ages: [26, 32], need: ['futbol'], q: 'Discotecas, coches y relojes de oro… o casa, entreno y sopa.', o: [
      { t: 'Vivir a tope', fx: [-8, -15, 12, 3], flag: 'juerga', tag: 'se compró tres deportivos' },
      { t: 'Casa, entreno y sopa', fx: [8, 5, -2, 3], flag: 'serio' }] },
    { id: 'mundial', ages: [29, 31], key: 1, need: ['futbol'], q: 'Final del Mundial. Tanda de penaltis. Te toca el último.', o: [
      { t: 'Voy yo', game: 'penaltis', gameTitle: '¡EL PENALTI DEL MUNDIAL!', single: 1,
        win: { fx: [0, 20, 20, 10], flag: 'campeon', m: '¡CAMPEONES DEL MUNDO! Te llevan a hombros.', tag: 'ganó un Mundial' },
        lose: { fx: [0, 0, -15, -5], m: 'Lo para el portero. Te persigue en sueños.' } },
      { t: 'Que lo tire otro', fx: [0, 0, -6, 0], m: 'El otro falla. Nadie te lo reprocha. En voz alta.' }] },
    { id: 'lesion', ages: [33, 35], key: 1, need: ['futbol'], q: 'Rotura de ligamentos a los 34. Tu rodilla y tú tenéis que hablar.', o: [
      { t: 'Vuelvo más fuerte que nunca', chance: { p: 0.45, stat: 0, flag: 'serio',
        ok: { fx: [0, 10, 12, 5], branch: 'leyenda', m: 'Vuelves, ganas otra liga y te retiras como una leyenda.' },
        ko: { fx: [-10, 0, -8, 0], branch: 'entrenador', m: 'La rodilla dice que no. Los niños del barrio dicen que sí.' } } },
      { t: 'Me retiro y entreno a los niños del barrio', fx: [0, -5, 6, 10], branch: 'entrenador' },
      { t: 'Me retiro a disfrutar de la vida', fx: [-5, 5, 10, 5], branch: 'juerga' }] },
    { id: 'estatua', ages: [48, 56], key: 1, need: ['futbol_leyenda'], q: 'Tu club inaugura una estatua tuya. Te han puesto la nariz aún más grande.', o: [
      { t: 'Lloras en directo', fx: [0, 0, 12, 8], tag: 'tiene una estatua (con narizota)' },
      { t: 'Pides que te la retoquen', fx: [0, -3, -3, -2], m: 'Ahora la estatua parece otro señor.' }] },
    { id: 'alevines', ages: [48, 56], key: 1, need: ['futbol_entrenador'], q: 'Tus alevines llegan a la final del torneo del barrio. Penalti en el último minuto.', o: [
      { t: 'Que lo tire el más pequeño', game: 'penaltis', gameTitle: '¡EL PENALTI DE LOS ALEVINES!', single: 1,
        win: { fx: [0, 0, 14, 12], m: 'El más pequeño marca. Lloras más que él.', tag: 'ganó el torneo del barrio con sus alevines' },
        lose: { fx: [0, 0, 4, 10], m: 'Falla, pero os invitáis a helado igual.' } },
      { t: 'Le das la charla de tu vida', fx: [0, 0, 6, 8] }] },
    { id: 'hacienda', ages: [48, 56], key: 1, need: ['futbol_juerga'], q: 'El bar va fatal y Hacienda llama a la puerta.', o: [
      { t: 'Subastas tu bota de oro', fx: [0, 25, -8, 0], tag: 'subastó su bota de oro' },
      { t: 'Partido benéfico con los viejos amigos', game: 'penaltis', gameTitle: '¡PARTIDO BENÉFICO!',
        win: { fx: [0, 20, 10, 10], m: 'Llenas el estadio. El bar se salva.' },
        lose: { fx: [0, 5, 2, 8], m: 'Os ahogáis a los diez minutos, pero se recauda algo.' } }] },
    { id: 'homenaje_leyenda', ages: [70, 80], key: 1, need: ['futbol_leyenda'], q: 'El estadio entero te hace un homenaje. Setenta mil personas gritan tu nombre.', o: [
      { t: 'Das la vuelta al campo', fx: [-2, 0, 15, 10], tag: 'dio la última vuelta al estadio' },
      { t: 'Saludas desde el palco', fx: [0, 0, 8, 5] }] },
    { id: 'homenaje_entrenador', ages: [70, 80], key: 1, need: ['futbol_entrenador'], q: 'Tus antiguos alevines, ya mayores, te hacen un pasillo en el campo de tierra.', o: [
      { t: 'Pasas entre ellos', fx: [0, 0, 15, 15], tag: 'recibió el pasillo de sus alevines' },
      { t: 'Les pitas un último entrenamiento', fx: [2, 0, 10, 12] }] },
    { id: 'homenaje_juerga', ages: [70, 80], key: 1, need: ['futbol_juerga'], q: 'Tus parroquianos te regalan una placa: «Al mejor camarero que nunca cobró».', o: [
      { t: 'Invitas a una ronda', fx: [-2, -5, 12, 12], tag: 'invitó a la última ronda' },
      { t: 'Cuelgas la placa junto a las camisetas', fx: [0, 0, 8, 6] }] },
  );
})(window.LIFE);
