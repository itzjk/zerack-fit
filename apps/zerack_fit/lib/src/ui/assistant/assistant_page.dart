import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../ai/assistant.dart';
import '../../ai/claude_client.dart';
import '../../ai/voice_service.dart';
import '../../data/models.dart' show weekdayNamesEs;
import '../../services.dart';
import '../common/ai_gate.dart';
import '../common/portion_sheet.dart';
import '../scope.dart';
import '../strings.dart';
import '../train/workout_page.dart';

class AssistantPage extends StatelessWidget {
  const AssistantPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AiGate(
      feature: 'usar el agente',
      sends: 'tus mensajes, tu perfil, tu meta y lo que registraste',
      child: _Chat(),
    );
  }
}

/// Reproduce MP3. Interfaz para poder probar sin audio real.
abstract interface class AudioOut {
  Future<void> play(List<int> mp3);
  Future<void> stop();
}

class _PlayerOut implements AudioOut {
  AudioPlayer? _player;

  @override
  Future<void> play(List<int> mp3) async {
    final p = _player ??= AudioPlayer();
    await p.stop();
    await p.play(BytesSource(Uint8List.fromList(mp3), mimeType: 'audio/mpeg'));
  }

  @override
  Future<void> stop() async => _player?.stop();
}

/// Permite inyectar un reproductor falso en pruebas.
class AudioScope extends InheritedWidget {
  const AudioScope({super.key, required this.out, required super.child});
  final AudioOut out;

  static AudioOut? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AudioScope>()?.out;

  @override
  bool updateShouldNotify(AudioScope old) => out != old.out;
}

class _Chat extends StatefulWidget {
  const _Chat();

  @override
  State<_Chat> createState() => _ChatState();
}

class _ChatState extends State<_Chat> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Assistant? _assistant;
  VoiceService? _voice;
  AudioOut _audio = _PlayerOut();
  bool _busy = false;
  String? _error;
  ChatTurn? _speaking;
  final Set<AgentAction> _done = {};

  static const _suggestions = [
    '¿Cuánta proteína me falta hoy?',
    'Desayuné 2 huevos y 2 tortillas',
    'Completa mi proteína de hoy',
    '¿Qué músculos puedo entrenar hoy?',
    '¿Por qué mi meta es de esas calorías?',
    'Quiero entrenar 4 días',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ai = ServicesScope.of(context).ai;
    final state = AppScope.of(context);
    final injected = AudioScope.maybeOf(context);
    if (injected != null) _audio = injected;
    if (_assistant == null) {
      ai.assistant(state).then((a) {
        if (mounted) setState(() => _assistant = a);
      });
      ai.voice(state).then((v) {
        if (mounted) setState(() => _voice = v);
      });
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _audio.stop();
    super.dispose();
  }

  Future<void> _speak(ChatTurn t) async {
    final v = _voice;
    if (v == null) return;
    setState(() => _speaking = t);
    try {
      await _audio.play(await v.synthesize(t.text));
    } on Object catch (e) {
      if (mounted) setState(() => _error = describeClaudeError(e));
    } finally {
      if (mounted) setState(() => _speaking = null);
    }
  }

  Future<void> _send(String text) async {
    final a = _assistant;
    if (a == null || _busy || text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    _input.clear();
    try {
      final turn = await a.send(text);
      if (mounted && AppScope.of(context).settings.voiceReplies) {
        // Sin await: la voz no bloquea el chat.
        _speak(turn);
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = describeClaudeError(e));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.animateTo(
              _scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  Future<void> _run(AgentAction action) async {
    final state = AppScope.of(context);
    switch (action) {
      case FoodProposal(:final items):
        for (final i in items) {
          await state.addFoodFromDb(i.food, i.grams);
        }
      case PlanChangeProposal():
        await action.apply(state);
      case StartWorkoutAction(:final workout):
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => WorkoutPage(template: workout),
          ),
        );
        return;
      case RuleCitation():
        return;
    }
    if (mounted) setState(() => _done.add(action));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final turns = _assistant?.turns ?? const <ChatTurn>[];
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(assistantName),
              if (_assistant != null)
                Text(
                  _assistant!.providerLabel,
                  key: const Key('agent-provider'),
                  style: text.bodySmall,
                ),
            ],
          ),
          actions: [
            if (_voice != null)
              IconButton(
                key: const Key('voice-toggle'),
                tooltip: state.settings.voiceReplies
                    ? 'Silenciar respuestas'
                    : 'Leer respuestas en voz alta',
                icon: Icon(
                  state.settings.voiceReplies
                      ? Icons.volume_up
                      : Icons.volume_off_outlined,
                ),
                onPressed: () {
                  final on = !state.settings.voiceReplies;
                  if (!on) _audio.stop();
                  state.saveSettings(state.settings.copyWith(voiceReplies: on));
                },
              ),
            IconButton(
              tooltip: 'Nueva conversación',
              icon: const Icon(Icons.refresh),
              onPressed: () {
                final ai = ServicesScope.of(context).ai;
                ai.resetConversation();
                ai.assistant(state).then((a) {
                  if (mounted) setState(() => _assistant = a);
                });
              },
            ),
          ],
        ),
        Expanded(
          child: turns.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const Text(
                      'Pregúntame sobre tu comida o tu entrenamiento. Conozco '
                      'tu perfil, tu meta, tu chequeo y lo que registraste. '
                      'Puedo anotar comida, ajustar tu plan, abrir tu sesión '
                      'y explicarte cada regla con su fuente. No doy consejo '
                      'médico.',
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in _suggestions)
                          ActionChip(label: Text(s), onPressed: () => _send(s)),
                      ],
                    ),
                  ],
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: turns.length,
                  itemBuilder: (_, i) {
                    final t = turns[i];
                    return Align(
                      alignment: t.fromUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Card(
                          color: t.fromUser
                              ? scheme.primaryContainer
                              : scheme.surfaceContainerHighest,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: SelectableText(t.text)),
                                    if (!t.fromUser && _voice != null)
                                      IconButton(
                                        key: Key('speak-$i'),
                                        tooltip: 'Escuchar',
                                        visualDensity: VisualDensity.compact,
                                        icon: Icon(
                                          _speaking == t
                                              ? Icons.graphic_eq
                                              : Icons.volume_up_outlined,
                                          size: 18,
                                        ),
                                        onPressed: () => _speak(t),
                                      ),
                                  ],
                                ),
                                for (final a in t.actions)
                                  _ActionCard(
                                    action: a,
                                    done: _done.contains(a),
                                    onRun: () => _run(a),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _error!,
              key: const Key('agent-error'),
              style: TextStyle(color: scheme.error),
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('chat-input'),
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _send,
                    decoration: const InputDecoration(
                      hintText: 'Escribe tu pregunta',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  key: const Key('chat-send'),
                  onPressed: _busy ? null : () => _send(_input.text),
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.action,
    required this.done,
    required this.onRun,
  });
  final AgentAction action;
  final bool done;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget button(String key, String label, String doneLabel) => done
        ? Row(
            key: Key('$key-done'),
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 18),
              const SizedBox(width: 6),
              Text(doneLabel),
            ],
          )
        : FilledButton(key: Key(key), onPressed: onRun, child: Text(label));

    final List<Widget> body = switch (action) {
      FoodProposal(:final items, :final reason, :final total) => [
        if (reason != null) Text(reason, style: text.labelLarge),
        for (final i in items)
          Text(
            '• ${i.food.name}, ${i.grams.round()} g: '
            '${i.food.forGrams(i.grams).kcal.round()} kcal',
          ),
        const SizedBox(height: 8),
        NutrientRow(total),
        const SizedBox(height: 8),
        button('proposal-accept', 'Agregar a mi día', 'Agregado a tu día'),
        Text('Nutrientes del USDA FoodData Central.', style: text.bodySmall),
      ],
      PlanChangeProposal(:final level, :final daysPerWeek, :final gymAccess) =>
        [
          Text('Nuevo plan', style: text.labelLarge),
          Text(
            '${Es.level(level)} · $daysPerWeek días por semana · '
            '${gymAccess ? 'gimnasio' : 'en casa'}',
          ),
          const SizedBox(height: 8),
          button('plan-accept', 'Aplicar plan', 'Plan aplicado'),
          Text('Frecuencias de ACSM 2009.', style: text.bodySmall),
        ],
      StartWorkoutAction(:final weekday, :final workout) => [
        Text(
          '${weekdayNamesEs[weekday - 1]}: ${workout.name}',
          style: text.labelLarge,
        ),
        Text('${workout.exercises.length} ejercicios'),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const Key('workout-open'),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Empezar sesión guiada'),
          onPressed: onRun,
        ),
      ],
      RuleCitation(:final rule) => [
        Text(rule.title, style: text.labelLarge),
        Text(rule.summary),
        const SizedBox(height: 4),
        Text(
          'Fuente: ${rule.source.citation}',
          key: Key('rule-${rule.id}'),
          style: text.bodySmall,
        ),
      ],
    };
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [const Divider(), ...body],
      ),
    );
  }
}
