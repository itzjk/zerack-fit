import 'dart:convert';

import 'package:zerack_core/zerack_core.dart';

import '../data/app_state.dart';
import '../data/models.dart';
import 'backends.dart';
import 'claude_client.dart' show assistantName;
import 'rules.dart';

/// Algo que el agente propone hacer en la app.
sealed class AgentAction {
  const AgentAction();
}

/// Comida para registrar. La persona la confirma.
class FoodProposal extends AgentAction {
  const FoodProposal(this.items, {this.reason});
  final List<({Food food, double grams})> items;

  /// Por qué se propone (p. ej. "para completar tu proteína").
  final String? reason;

  Nutrients get total =>
      items.fold(Nutrients.zero, (sum, i) => sum + i.food.forGrams(i.grams));
}

/// Cambio del plan de entrenamiento. La persona lo confirma.
class PlanChangeProposal extends AgentAction {
  const PlanChangeProposal({
    required this.level,
    required this.daysPerWeek,
    required this.gymAccess,
  });
  final TrainingLevel level;
  final int daysPerWeek;
  final bool gymAccess;

  Future<void> apply(AppState state) => state.saveSettings(
    state.settings.copyWith(
      level: level,
      daysPerWeek: daysPerWeek,
      gymAccess: gymAccess,
    ),
  );
}

/// Abrir la sesión guiada de un día del plan.
class StartWorkoutAction extends AgentAction {
  const StartWorkoutAction(this.weekday, this.workout);
  final int weekday;
  final WorkoutTemplate workout;
}

/// Una regla de la app con su fuente.
class RuleCitation extends AgentAction {
  const RuleCitation(this.rule);
  final RuleInfo rule;
}

/// Un turno visible en el chat.
class ChatTurn {
  const ChatTurn.user(this.text) : fromUser = true, actions = const [];
  const ChatTurn.assistant(this.text, {this.actions = const []})
    : fromUser = false;

  final bool fromUser;
  final String text;
  final List<AgentAction> actions;

  /// La primera propuesta de comida, si hay.
  FoodProposal? get proposal {
    for (final a in actions) {
      if (a is FoodProposal) return a;
    }
    return null;
  }
}

/// Agente de ZERACK Fit: conversa, lee los datos locales con herramientas y
/// propone acciones. Funciona con Gemini, con Claude o con el servidor de
/// ZERACK, según [AgentBackend].
///
/// Solo sale del teléfono lo que las herramientas devuelven en esta
/// conversación; el historial completo nunca se envía entero.
class Assistant {
  Assistant(this._backend, this._state);

  final AgentBackend _backend;
  final AppState _state;
  final List<ChatTurn> turns = [];

  String get providerLabel => _backend.label;

  static const maxToolRounds = 6;

  static final system =
      '''
Eres $assistantName, el agente de entrenamiento y nutrición de la app ZERACK Fit. Hablas español neutro, cercano y claro. Respuestas cortas (2 a 4 frases): la app puede leerlas en voz alta, así que no uses tablas, listas largas ni markdown.

Cómo trabajas:
- Antes de cualquier consejo personal, consulta get_user_context (perfil, meta, chequeo de hoy, comidas, entrenos, plan, recuperación muscular).
- Todos los números de calorías y nutrientes salen de las herramientas (base del USDA). Nunca inventes cifras; si un alimento no está, dilo.
- Puedes HACER cosas en la app, siempre con una tarjeta que la persona confirma:
  · anotar comida: search_foods y luego propose_food_log;
  · completar la proteína del día: suggest_foods_to_complete_day;
  · ajustar el plan: propose_plan_change;
  · abrir la sesión guiada de un día: start_workout.
  Nunca digas que algo ya quedó guardado: di que te deja la tarjeta para confirmar.
- Si preguntan "¿por qué?" sobre un número o una regla, usa explain_rule y menciona la fuente.
- Antes de proponer entrenar, revisa get_muscle_recovery: si un músculo no lleva 48 h de descanso, avísalo.
- Respeta su meta de energía: nunca sugieras comer menos que su gasto en reposo. Respeta su cuestionario de seguridad: si solo puede intensidad moderada, no propongas vigoroso ni el nivel avanzado.

Límites (no negociables):
- Eres una herramienta de bienestar, no un médico. No diagnosticas, no interpretas síntomas, no indicas medicamentos ni cambias tratamientos.
- Si la persona menciona dolor en el pecho, falta de aire, mareo o desmayo, palpitaciones o cualquier síntoma preocupante: dile que deje de hacer ejercicio y busque atención médica de inmediato (911 en México). No sigas con el plan.
- Para embarazo, diabetes, hipertensión, enfermedad renal o cualquier condición médica, recomienda consultar a su médico antes de cambiar su alimentación o ejercicio.
- No hagas promesas de resultados.''';

  static const _empty = {
    'type': 'object',
    'properties': <String, Object?>{},
    'additionalProperties': false,
  };

  static final tools = <ToolSpec>[
    const ToolSpec(
      name: 'get_user_context',
      description:
          'Perfil, meta, energía y proteína objetivo, lo que comió hoy, '
          'chequeo diario, resumen semanal, cuestionario de seguridad, plan '
          'semanal, recuperación muscular y resumen de 30 días. Úsala antes '
          'de cualquier consejo personal.',
      schema: _empty,
    ),
    const ToolSpec(
      name: 'search_foods',
      description:
          'Busca alimentos en la base del USDA por nombre en español. Devuelve '
          'id, nombre, nutrientes por 100 g y porciones comunes.',
      schema: {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': 'Nombre del alimento, p. ej. "tortilla de maíz"',
          },
        },
        'required': ['query'],
        'additionalProperties': false,
      },
    ),
    const ToolSpec(
      name: 'propose_food_log',
      description:
          'Muestra una tarjeta para registrar comida; la persona la confirma. '
          'Usa ids de search_foods y gramos realistas.',
      schema: {
        'type': 'object',
        'properties': {
          'items': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'food_id': {'type': 'integer'},
                'grams': {'type': 'number'},
              },
              'required': ['food_id', 'grams'],
              'additionalProperties': false,
            },
          },
        },
        'required': ['items'],
        'additionalProperties': false,
      },
    ),
    const ToolSpec(
      name: 'suggest_foods_to_complete_day',
      description:
          'Calcula cuánta proteína y energía le faltan hoy y propone hasta 3 '
          'alimentos del USDA con gramos exactos que cubren la proteína sin '
          'pasarse de la meta. Muestra una tarjeta para confirmar.',
      schema: _empty,
    ),
    const ToolSpec(
      name: 'get_recent_history',
      description:
          'Últimos días: calorías y proteína por día, minutos de entreno y '
          'peso registrado.',
      schema: {
        'type': 'object',
        'properties': {
          'days': {'type': 'integer', 'description': 'Entre 1 y 30'},
        },
        'required': ['days'],
        'additionalProperties': false,
      },
    ),
    const ToolSpec(
      name: 'get_muscle_recovery',
      description:
          'Para cada grupo muscular: último día entrenado, series de los '
          'últimos 7 días y si ya cumplió las 48 h de descanso (ACSM 2011).',
      schema: _empty,
    ),
    const ToolSpec(
      name: 'propose_plan_change',
      description:
          'Muestra una tarjeta para cambiar el plan; la persona la confirma. '
          'Manda los tres valores (repite los actuales si no cambian). Días '
          'válidos: principiante 2–3, intermedio 3–4, avanzado 4–6.',
      schema: {
        'type': 'object',
        'properties': {
          'level': {
            'type': 'string',
            'enum': ['novice', 'intermediate', 'advanced'],
          },
          'days_per_week': {'type': 'integer'},
          'gym_access': {'type': 'boolean'},
        },
        'required': ['level', 'days_per_week', 'gym_access'],
        'additionalProperties': false,
      },
    ),
    const ToolSpec(
      name: 'start_workout',
      description:
          'Muestra el botón para abrir la sesión guiada del día indicado '
          '(1 = lunes … 7 = domingo).',
      schema: {
        'type': 'object',
        'properties': {
          'weekday': {'type': 'integer'},
        },
        'required': ['weekday'],
        'additionalProperties': false,
      },
    ),
    ToolSpec(
      name: 'explain_rule',
      description:
          'Explica una regla de la app con su fuente publicada. Úsala cuando '
          'pregunten por qué un número o una recomendación.',
      schema: {
        'type': 'object',
        'properties': {
          'rule_id': {
            'type': 'string',
            'enum': [for (final r in ruleIndex) r.id],
          },
        },
        'required': ['rule_id'],
        'additionalProperties': false,
      },
    ),
  ];

  /// Envía un mensaje y corre el ciclo de herramientas hasta la respuesta.
  Future<ChatTurn> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(text, 'text', 'vacío');
    turns.add(ChatTurn.user(trimmed));
    _backend.addUserText(trimmed);

    final actions = <AgentAction>[];
    for (var round = 0; round <= maxToolRounds; round++) {
      final step = await _backend.step(system: system, tools: tools);
      if (step.calls.isEmpty) {
        final reply = step.text.isEmpty
            ? (actions.isEmpty ? 'Listo.' : 'Te dejo la tarjeta abajo.')
            : step.text;
        final turn = ChatTurn.assistant(reply, actions: List.of(actions));
        turns.add(turn);
        return turn;
      }
      final results = <ToolResult>[];
      for (final call in step.calls) {
        final (output, isError, action) = _runTool(call.name, call.args);
        if (action != null) actions.add(action);
        results.add(ToolResult(call, output, isError: isError));
      }
      // Todos los resultados van juntos en un solo mensaje.
      _backend.addToolResults(results);
    }
    final turn = ChatTurn.assistant(
      'No pude terminar la respuesta. Intenta preguntarlo de otra forma.',
      actions: actions,
    );
    turns.add(turn);
    return turn;
  }

  (String, bool, AgentAction?) _runTool(
    String name,
    Map<String, Object?> input,
  ) {
    try {
      return switch (name) {
        'get_user_context' => (jsonEncode(userContext()), false, null),
        'search_foods' => (
          jsonEncode(_searchFoods(input['query'] as String? ?? '')),
          false,
          null,
        ),
        'propose_food_log' => _propose(input),
        'suggest_foods_to_complete_day' => _completeDay(),
        'get_recent_history' => (
          jsonEncode(
            _history(((input['days'] as num?)?.toInt() ?? 7).clamp(1, 30)),
          ),
          false,
          null,
        ),
        'get_muscle_recovery' => (jsonEncode(_recovery()), false, null),
        'propose_plan_change' => _planChange(input),
        'start_workout' => _startWorkout(input),
        'explain_rule' => _explain(input),
        _ => ('Herramienta desconocida: $name', true, null),
      };
    } on Object catch (e) {
      return ('Error: $e', true, null);
    }
  }

  static double _r(double v) => (v * 10).roundToDouble() / 10;

  Map<String, Object?> userContext() {
    final s = _state;
    final p = s.profile;
    final target = s.energyTarget;
    final protein = s.proteinRange;
    final eaten = s.todayNutrients;
    final week = s.weekSummary;
    final screening = s.screening;
    final plan = s.plan;
    final history30 = s.thirtyDaySummary();
    return {
      'fecha': s.today,
      'hoy_es': weekdayNamesEs[s.now.weekday - 1],
      if (p != null)
        'perfil': {
          'sexo': p.sex.name,
          'edad': p.ageYears,
          'peso_kg': p.weightKg,
          'estatura_cm': p.heightCm,
          'nivel_actividad': p.activity.name,
          'gasto_reposo_kcal': p.restingKcal.round(),
          'gasto_total_kcal': p.totalKcal.round(),
        },
      'meta': s.settings.goal.name,
      if (target != null) 'energia_objetivo_kcal': target.kcal.round(),
      if (protein != null)
        'proteina_objetivo_g': {
          'min': protein.minG.round(),
          'max': protein.maxG.round(),
        },
      'comido_hoy': {
        'kcal': eaten.kcal.round(),
        'proteina_g': _r(eaten.proteinG),
        'grasa_g': _r(eaten.fatG),
        'carbohidratos_g': _r(eaten.carbsG),
        'alimentos': [for (final f in s.todayFood) '${f.label} (${f.kcal})'],
      },
      'chequeo_hoy_0_100': s.todayCheckIn?.score,
      'semana': {
        'minutos_moderados_equivalentes': week.moderateEquivalentMinutes,
        'dias_de_fuerza': week.strengthDays,
        'recomendacion_oms': '150-300 min y fuerza 2+ días',
      },
      if (screening != null)
        'seguridad': {
          'resultado': screening.outcome.name,
          'puede_entrenar': screening.canTrain,
          'vigoroso_permitido': screening.outcome.allowsVigorous,
        },
      'plan_semanal': {
        'nivel': plan.level.name,
        'dias_por_semana': plan.daysPerWeek,
        'gimnasio': s.settings.gymAccess,
        'dias': [
          for (final d in plan.week)
            {
              'dia': weekdayNamesEs[d.weekday - 1],
              'sesion': d.workout?.name ?? 'Descanso',
              if (d.workout != null)
                'ejercicios': [
                  for (final e in d.workout!.exercises)
                    '${e.exercise.name}: ${e.sets}x${e.minReps}-${e.maxReps}',
                ],
            },
        ],
      },
      'recuperacion_muscular': _recovery()['grupos'],
      'historial_30_dias': ?history30,
    };
  }

  List<Map<String, Object?>> _searchFoods(String query) => [
    for (final f in _state.foods.search(query, limit: 8))
      {
        'id': f.id,
        'nombre': f.name,
        'por_100g': {
          'kcal': f.per100g.kcal,
          'proteina_g': f.per100g.proteinG,
          'grasa_g': f.per100g.fatG,
          'carbohidratos_g': f.per100g.carbsG,
        },
        'porciones': [
          for (final p in f.portions) {'porcion': p.label, 'gramos': p.grams},
        ],
      },
  ];

  (String, bool, AgentAction?) _propose(Map<String, Object?> input) {
    final items = <({Food food, double grams})>[];
    final missing = <int>[];
    for (final raw in (input['items'] as List<Object?>? ?? const [])) {
      final m = (raw as Map).cast<String, Object?>();
      final id = (m['food_id'] as num).toInt();
      final grams = (m['grams'] as num).toDouble();
      final food = _state.foods.byId(id);
      if (food == null) {
        missing.add(id);
        continue;
      }
      if (grams <= 0 || grams > 2000) {
        return ('Gramos fuera de rango para $id: $grams', true, null);
      }
      items.add((food: food, grams: grams));
    }
    if (items.isEmpty) {
      return ('Ningún id válido. Usa search_foods primero.', true, null);
    }
    final proposal = FoodProposal(items);
    final t = proposal.total;
    return (
      jsonEncode({
        'tarjeta_mostrada': true,
        'pendiente_de_confirmar': true,
        'total_kcal': t.kcal.round(),
        'total_proteina_g': _r(t.proteinG),
        if (missing.isNotEmpty) 'ids_no_encontrados': missing,
      }),
      false,
      proposal,
    );
  }

  (String, bool, AgentAction?) _completeDay() {
    final target = _state.energyTarget;
    final protein = _state.proteinRange;
    if (target == null || protein == null) {
      return ('Falta el perfil', true, null);
    }
    final eaten = _state.todayNutrients;
    final c = completeDay(
      foods: _state.foods,
      targetKcal: target.kcal,
      eatenKcal: eaten.kcal,
      minProteinG: protein.minG,
      eatenProteinG: eaten.proteinG,
    );
    final summary = {
      'faltan_kcal': c.remainingKcal.round(),
      'faltan_proteina_g': c.remainingProteinG.round(),
      'proteina_cubierta': c.proteinCovered,
      'sugerencias': [
        for (final s in c.suggestions)
          {
            'alimento': s.food.name,
            'gramos': s.grams,
            'kcal': s.nutrients.kcal.round(),
            'proteina_g': _r(s.nutrients.proteinG),
          },
      ],
      'fuente': 'ISSN 2017 (proteína) y USDA (alimentos)',
    };
    if (c.suggestions.isEmpty) return (jsonEncode(summary), false, null);
    return (
      jsonEncode({...summary, 'tarjeta_mostrada': true}),
      false,
      FoodProposal([
        for (final s in c.suggestions) (food: s.food, grams: s.grams),
      ], reason: 'Para completar tu proteína de hoy'),
    );
  }

  Map<String, Object?> _recovery() {
    final r = _state.recovery;
    return {
      'regla': '48 h entre sesiones del mismo grupo (ACSM 2011)',
      'grupos': [
        for (final g in r)
          {
            'grupo': g.group.name,
            'estado': g.status.name,
            if (g.lastTrained != null) 'ultimo': dayKey(g.lastTrained!),
            if (g.readyOn != null) 'listo_desde': dayKey(g.readyOn!),
            'series_7_dias': g.setsLast7Days,
          },
      ],
    };
  }

  (String, bool, AgentAction?) _planChange(Map<String, Object?> input) {
    final level = TrainingLevel.values.firstWhere(
      (l) => l.name == input['level'],
      orElse: () => throw ArgumentError('nivel desconocido'),
    );
    final days = (input['days_per_week'] as num).toInt();
    final gym = input['gym_access'] as bool;
    if (!level.allowsDays(days)) {
      return (
        'Días fuera de rango para ${level.name}: '
            '${level.minDays}–${level.maxDays} (ACSM 2009).',
        true,
        null,
      );
    }
    final vigorousOk = _state.screening?.outcome.allowsVigorous ?? false;
    if (level == TrainingLevel.advanced && !vigorousOk) {
      return (
        'El nivel avanzado no está disponible: su cuestionario de seguridad '
            'limita a intensidad moderada.',
        true,
        null,
      );
    }
    return (
      jsonEncode({'tarjeta_mostrada': true, 'pendiente_de_confirmar': true}),
      false,
      PlanChangeProposal(level: level, daysPerWeek: days, gymAccess: gym),
    );
  }

  (String, bool, AgentAction?) _startWorkout(Map<String, Object?> input) {
    final day = (input['weekday'] as num).toInt();
    if (day < 1 || day > 7) return ('Día fuera de 1–7', true, null);
    if (!(_state.screening?.canTrain ?? false)) {
      return (
        'No puede entrenar todavía: su cuestionario pide autorización médica.',
        true,
        null,
      );
    }
    final w = _state.plan.forWeekday(day);
    if (w == null) {
      return ('Ese día es de descanso en su plan.', true, null);
    }
    final conflicts = conflictsWith(w, _state.recovery);
    return (
      jsonEncode({
        'boton_mostrado': true,
        'sesion': w.name,
        if (conflicts.isNotEmpty)
          'aviso_sin_48h': [for (final g in conflicts) g.name],
      }),
      false,
      StartWorkoutAction(day, w),
    );
  }

  (String, bool, AgentAction?) _explain(Map<String, Object?> input) {
    final rule = ruleById(input['rule_id'] as String? ?? '');
    if (rule == null) return ('Regla desconocida', true, null);
    return (
      jsonEncode({
        'regla': rule.title,
        'explicacion': rule.summary,
        'fuente': rule.source.citation,
        if (rule.source.url != null) 'enlace': rule.source.url,
      }),
      false,
      RuleCitation(rule),
    );
  }

  Map<String, Object?> _history(int days) {
    final s = _state;
    return {
      'dias': [
        for (var i = days - 1; i >= 0; i--)
          () {
            final day = dayKey(s.now.subtract(Duration(days: i)));
            final n = s
                .foodOn(day)
                .fold(Nutrients.zero, (sum, f) => sum + f.nutrients);
            final weight = s.weights.where((w) => w.day == day);
            return {
              'dia': day,
              'kcal': n.kcal.round(),
              'proteina_g': _r(n.proteinG),
              'entrenos_min': s.workouts
                  .where((w) => w.day == day)
                  .fold<int>(0, (a, w) => a + w.minutes),
              if (weight.isNotEmpty) 'peso_kg': weight.last.kg,
            };
          }(),
      ],
    };
  }
}
