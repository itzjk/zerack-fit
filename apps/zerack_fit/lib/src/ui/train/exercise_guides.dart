/// Cómo se hace cada ejercicio. Texto de técnica general, no indicación
/// médica. La llave es el `id` estable del catálogo.
class ExerciseGuide {
  const ExerciseGuide(this.muscles, this.steps);
  final String muscles;
  final List<String> steps;
}

const exerciseGuides = <String, ExerciseGuide>{
  'goblet_squat': ExerciseGuide('Cuádriceps, glúteos y abdomen', [
    'Sostén una mancuerna vertical pegada al pecho.',
    'Pies al ancho de los hombros, puntas un poco hacia afuera.',
    'Baja como si te sentaras, con el pecho arriba y las rodillas siguiendo la línea de los pies.',
    'Empuja con todo el pie para volver arriba.',
  ]),
  'back_squat': ExerciseGuide('Cuádriceps, glúteos y espalda baja', [
    'Coloca la barra sobre la parte alta de la espalda, no en el cuello.',
    'Inhala, aprieta el abdomen y baja llevando la cadera atrás y abajo.',
    'Baja hasta donde mantengas la espalda neutra y los talones en el piso.',
    'Sube empujando el piso, sin que las rodillas se vayan hacia adentro.',
  ]),
  'leg_press': ExerciseGuide('Cuádriceps y glúteos', [
    'Espalda y cadera bien apoyadas en el respaldo.',
    'Pies en la plataforma al ancho de los hombros.',
    'Baja controlado hasta que la cadera empiece a despegarse; ahí regresa.',
    'Empuja sin bloquear las rodillas al final.',
  ]),
  'romanian_deadlift': ExerciseGuide('Femorales, glúteos y espalda baja', [
    'De pie con la barra frente a los muslos, rodillas apenas flexionadas.',
    'Lleva la cadera hacia atrás mientras la barra baja pegada a las piernas.',
    'Mantén la espalda neutra; detente al sentir el estiramiento detrás del muslo.',
    'Regresa empujando la cadera hacia adelante.',
  ]),
  'bench_press': ExerciseGuide('Pecho, hombro frontal y tríceps', [
    'Acostado, ojos debajo de la barra y pies firmes en el piso.',
    'Junta las escápulas y toma la barra un poco más ancho que los hombros.',
    'Baja controlado a media altura del pecho, codos a unos 45° del cuerpo.',
    'Empuja hacia arriba hasta estirar los brazos.',
  ]),
  'pushup': ExerciseGuide('Pecho, hombros, tríceps y abdomen', [
    'Manos un poco más anchas que los hombros, cuerpo en línea recta.',
    'Baja el pecho hacia el piso con los codos hacia atrás en diagonal.',
    'Empuja hasta estirar los brazos sin hundir la cadera.',
    'Si cuesta, apoya las rodillas.',
  ]),
  'lat_pulldown': ExerciseGuide('Dorsal ancho, espalda media y bíceps', [
    'Siéntate con los muslos fijos bajo el soporte.',
    'Toma la barra más ancho que los hombros.',
    'Jala la barra a la clavícula llevando los codos hacia abajo, sin balancearte.',
    'Sube controlado hasta estirar los brazos.',
  ]),
  'barbell_row': ExerciseGuide('Espalda media, dorsal y bíceps', [
    'Inclina el torso hacia adelante con la espalda neutra y rodillas flexionadas.',
    'Deja la barra colgando con los brazos estirados.',
    'Jala la barra hacia el ombligo juntando las escápulas.',
    'Baja controlado sin perder la postura.',
  ]),
  'seated_row': ExerciseGuide('Espalda media, dorsal y bíceps', [
    'Siéntate con la espalda recta y las rodillas un poco flexionadas.',
    'Toma el agarre con los brazos estirados al frente.',
    'Jala hacia el abdomen llevando los codos atrás y juntando las escápulas.',
    'Regresa sin redondear la espalda.',
  ]),
  'overhead_press': ExerciseGuide('Hombros y tríceps', [
    'De pie, la barra a la altura de los hombros, abdomen y glúteos firmes.',
    'Empuja la barra hacia arriba pasando cerca de la cara.',
    'Termina con los brazos estirados sobre la cabeza.',
    'Baja controlado sin arquear la espalda baja.',
  ]),
  'dumbbell_curl': ExerciseGuide('Bíceps', [
    'De pie, una mancuerna en cada mano y los codos pegados al cuerpo.',
    'Sube las mancuernas doblando solo el codo.',
    'Aprieta arriba un segundo.',
    'Baja despacio hasta estirar el brazo.',
  ]),
  'triceps_pushdown': ExerciseGuide('Tríceps', [
    'De pie frente a la polea alta, codos pegados al cuerpo.',
    'Empuja el agarre hacia abajo hasta estirar los brazos.',
    'Mantén los codos quietos todo el movimiento.',
    'Sube controlado hasta la altura del pecho.',
  ]),
  'plank': ExerciseGuide('Abdomen y estabilizadores del tronco', [
    'Apoya antebrazos y puntas de los pies; codos bajo los hombros.',
    'Forma una línea recta de la cabeza a los talones.',
    'Aprieta abdomen y glúteos; respira normal.',
    'Anota los segundos que aguantes con buena postura.',
  ]),
};
