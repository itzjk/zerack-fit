import 'dart:convert';

import 'package:zerack_core/zerack_core.dart';

import '../data/app_state.dart';
import '../data/models.dart';
import 'claude_client.dart';

/// Propuesta de comida que el asistente arma y la persona confirma.
class FoodProposal {
  const FoodProposal(this.items);
  final List<({Food food, double grams})> items;

  Nutrients get total =>
      items.fold(Nutrients.zero, (sum, i) => sum + i.food.forGrams(i.grams));
}

/// Un turno visible en el chat.
class ChatTurn {
  const ChatTurn.user(this.text) : fromUser = true, proposal = null;
  const ChatTurn.assistant(this.text, {this.proposal}) : fromUser = false;

  final bool fromUser;
  final String text;
  final FoodProposal? proposal;
}

/// Asistente con herramientas que leen los datos locales de la persona.
///
/// Solo se envía a la API lo que las herramientas devuelven en cada
/// conversación; el historial completo nunca sale del teléfono.
class Assistant {
  Assistant(this._client, this._state);

  final ClaudeClient _client;
  final AppState _state;

  /// Historial en el formato de la API. Solo se agrega al final: el contenido
  /// de cada respuesta se devuelve tal cual.
  final List<Map<String, Object?>> _messages = [];
  final List<ChatTurn> turns = [];

  static const maxToolRounds = 6;

  static const system =
      '''
Eres $assistantName, el asistente de entrenamiento y nutrición de la app ZERACK Fit. Hablas español neutro, cercano y claro, en respuestas cortas.

Cómo trabajas:
- Antes de dar un consejo personal, consulta get_user_context para conocer el perfil, la meta, lo que comió hoy y su entrenamiento.
- Todos los números de calorías y nutrientes salen de las herramientas (base del USDA). Nunca inventes cifras nutricionales; si un alimento no está, dilo.
- Cuando la persona diga qué comió o quiera registrar algo, busca con search_foods y arma la propuesta con propose_food_log. La persona confirma en la app; no digas que ya quedó guardado.
- Ajusta las recomendaciones a su peso, estatura, edad, meta y gasto estimado. Respeta su meta diaria de energía: nunca sugieras comer menos que su gasto en reposo.
- Para entrenamiento, respeta el resultado de su cuestionario de seguridad: si solo puede intensidad moderada, no propongas trabajo vigoroso.

Límites (no negociables):
- Eres una herramienta de bienestar, no un médico. No diagnosticas, no interpretas síntomas, no indicas medicamentos ni cambias tratamientos.
- Si la persona menciona dolor en el pecho, falta de aire, mareo o desmayo, palpitaciones o cualquier síntoma preocupante: dile que deje de hacer ejercicio y busque atención médica de inmediato (911 en México). No sigas con el plan.
- Para embarazo, diabetes, hipertensión, enfermedad renal o cualquier condición médica, recomienda consultar a su médico antes de cambiar su alimentación o ejercicio.
- No hagas promesas de resultados.''';

  static final tools = <Map<String, Object?>>[
    {
      'name': 'get_user_context',
      'description':
          'Devuelve el perfil, la meta, la energía y proteína objetivo, lo '
          'que comió hoy, el chequeo diario, el resumen semanal de actividad, '
          'el resultado del cuestionario de seguridad y el próximo '
          'entrenamiento. Úsala antes de cualquier consejo personal.',
      'input_schema': {
        'type': 'object',
        'properties': <String, Object?>{},
        'additionalProperties': false,
      },
      'strict': true,
    },
    {
      'name': 'search_foods',
      'description':
          'Busca alimentos en la base del USDA de la app por nombre en '
          'español. Devuelve id, nombre, nutrientes por 100 g y porciones '
          'comunes en gramos.',
      'input_schema': {
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
      'strict': true,
    },
    {
      'name': 'propose_food_log',
      'description':
          'Muestra a la persona una propuesta de comida para registrar. Ella '
          'la confirma o la descarta en la app. Usa ids de search_foods y '
          'gramos realistas.',
      'input_schema': {
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
      'strict': true,
    },
    {
      'name': 'get_recent_history',
      'description':
          'Resumen de los últimos días: calorías y proteína por día, '
          'entrenamientos y peso registrado.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'days': {'type': 'integer', 'description': 'Entre 1 y 30'},
        },
        'required': ['days'],
        'additionalProperties': false,
      },
      'strict': true,
    },
  ];

  /// Envía un mensaje y corre el ciclo de herramientas hasta la respuesta.
  Future<ChatTurn> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(text, 'text', 'vacío');
    turns.add(ChatTurn.user(trimmed));
    _messages.add({'role': 'user', 'content': trimmed});

    FoodProposal? proposal;
    for (var round = 0; round <= maxToolRounds; round++) {
      final res = await _client.create(
        system: system,
        messages: _messages,
        tools: tools,
      );
      _messages.add({'role': 'assistant', 'content': res.content});

      final uses = res.toolUses;
      if (res.stopReason != 'tool_use' || uses.isEmpty) {
        final reply = res.text.trim().isEmpty
            ? (proposal == null ? 'Listo.' : 'Te dejo la propuesta abajo.')
            : res.text.trim();
        final turn = ChatTurn.assistant(reply, proposal: proposal);
        turns.add(turn);
        return turn;
      }

      final results = <Map<String, Object?>>[];
      for (final use in uses) {
        final (output, isError, p) = _runTool(
          use['name'] as String,
          (use['input'] as Map?)?.cast<String, Object?>() ?? const {},
        );
        proposal = p ?? proposal;
        results.add({
          'type': 'tool_result',
          'tool_use_id': use['id'],
          'content': output,
          if (isError) 'is_error': true,
        });
      }
      // Todos los resultados van juntos en un solo mensaje.
      _messages.add({'role': 'user', 'content': results});
    }
    final turn = ChatTurn.assistant(
      'No pude terminar la respuesta. Intenta preguntarlo de otra forma.',
      proposal: proposal,
    );
    turns.add(turn);
    return turn;
  }

  (String, bool, FoodProposal?) _runTool(
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
        'get_recent_history' => (
          jsonEncode(
            _history(((input['days'] as num?)?.toInt() ?? 7).clamp(1, 30)),
          ),
          false,
          null,
        ),
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
    final next = s.nextWorkout;
    return {
      'fecha': s.today,
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
      'proximo_entreno': {
        'nombre': next.name,
        'ejercicios': [
          for (final e in next.exercises)
            '${e.exercise.name}: ${e.sets}x${e.minReps}-${e.maxReps}',
        ],
      },
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

  (String, bool, FoodProposal?) _propose(Map<String, Object?> input) {
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
        'mostrado_al_usuario': true,
        'pendiente_de_confirmar': true,
        'total_kcal': t.kcal.round(),
        'total_proteina_g': _r(t.proteinG),
        if (missing.isNotEmpty) 'ids_no_encontrados': missing,
      }),
      false,
      proposal,
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
