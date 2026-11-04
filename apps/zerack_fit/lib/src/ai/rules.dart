import 'package:zerack_core/zerack_core.dart';

/// Regla de la app explicada en una frase, con su fuente publicada. El
/// agente la usa para responder "¿por qué?" sin inventar.
class RuleInfo {
  const RuleInfo(this.id, this.title, this.summary, this.source);
  final String id;
  final String title;
  final String summary;
  final Source source;
}

const ruleIndex = <RuleInfo>[
  RuleInfo(
    'energia_reposo',
    'Gasto en reposo',
    'Se calcula con la ecuación de Mifflin-St Jeor con tu sexo, peso, '
        'estatura y edad. Suele acertar dentro de ±10 %.',
    Sources.mifflin1990,
  ),
  RuleInfo(
    'gasto_total',
    'Gasto total del día',
    'Es el gasto en reposo multiplicado por tu nivel de actividad física '
        '(1.53, 1.76 o 2.25).',
    Sources.fao2004,
  ),
  RuleInfo(
    'deficit',
    'Meta para bajar de peso',
    'Resta 500 kcal a tu gasto total, el extremo bajo del rango de 500 a '
        '1000 que recomienda ACSM. La app nunca baja de tu gasto en reposo.',
    Sources.acsmWeightLoss2001,
  ),
  RuleInfo(
    'proteina',
    'Proteína del día',
    'Para quien hace ejercicio se recomiendan de 1.4 a 2.0 g por kg de peso '
        'al día.',
    Sources.issnProtein2017,
  ),
  RuleInfo(
    'progresion',
    'Cuándo subir el peso',
    'Si haces 1 o 2 repeticiones más del objetivo en dos sesiones seguidas '
        'con el mismo peso, sube de 2 a 10 %.',
    Sources.acsmProgression2009,
  ),
  RuleInfo(
    'plan_semanal',
    'Días por semana',
    'Principiante 2–3 días, intermedio 3–4 y avanzado 4–6, con rutinas '
        'divididas cuando entrenas 4 días o más.',
    Sources.acsmProgression2009,
  ),
  RuleInfo(
    'recuperacion',
    'Descanso entre sesiones',
    'Deja al menos 48 horas antes de volver a trabajar el mismo grupo '
        'muscular.',
    Sources.acsmQuantity2011,
  ),
  RuleInfo(
    'screening',
    'Cuestionario de seguridad',
    'Decide si necesitas autorización médica antes de entrenar según si ya '
        'haces ejercicio, si tienes enfermedad cardiovascular, metabólica o '
        'renal, y si tienes síntomas.',
    Sources.acsmScreening2015,
  ),
  RuleInfo(
    'actividad_oms',
    'Actividad semanal',
    'Los adultos deberían hacer de 150 a 300 minutos moderados a la semana '
        '(los vigorosos cuentan doble) y fuerza 2 días o más.',
    Sources.who2020,
  ),
  RuleInfo(
    'chequeo_diario',
    'Nota del día',
    'Sale del cuestionario de Hooper: sueño, estrés, cansancio y dolor '
        'muscular. Compárala contigo mismo, no con otras personas.',
    Sources.hooper1995,
  ),
  RuleInfo(
    'alimentos',
    'De dónde salen las calorías',
    'De la base FoodData Central del Departamento de Agricultura de EE. UU. '
        '(USDA). La IA solo reconoce el alimento y estima los gramos.',
    Sources.usdaSrLegacy,
  ),
  RuleInfo(
    'pulso_maximo',
    'Pulso máximo estimado',
    'Se estima como 208 − 0.7 × tu edad.',
    Sources.tanaka2001,
  ),
];

RuleInfo? ruleById(String id) {
  for (final r in ruleIndex) {
    if (r.id == id) return r;
  }
  return null;
}
