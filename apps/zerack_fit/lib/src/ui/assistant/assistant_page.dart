import 'package:flutter/material.dart';

import '../../ai/assistant.dart';
import '../../ai/claude_client.dart';
import '../../services.dart';
import '../common/ai_gate.dart';
import '../common/portion_sheet.dart';
import '../scope.dart';

class AssistantPage extends StatelessWidget {
  const AssistantPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AiGate(
      feature: 'usar el asistente',
      sends: 'tus mensajes, tu perfil, tu meta y lo que registraste',
      child: _Chat(),
    );
  }
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
  bool _busy = false;
  String? _error;
  final Set<FoodProposal> _saved = {};

  static const _suggestions = [
    '¿Cuánta proteína me falta hoy?',
    'Desayuné 2 huevos y 2 tortillas',
    '¿Qué ceno para llegar a mi meta?',
    '¿Cómo voy esta semana?',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ServicesScope.of(context).ai.assistant(AppScope.of(context)).then((a) {
      if (mounted) setState(() => _assistant = a);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
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
      await a.send(text);
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

  Future<void> _accept(FoodProposal p) async {
    final state = AppScope.of(context);
    for (final i in p.items) {
      await state.addFoodFromDb(i.food, i.grams);
    }
    setState(() => _saved.add(p));
  }

  @override
  Widget build(BuildContext context) {
    final turns = _assistant?.turns ?? const <ChatTurn>[];
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        AppBar(
          title: const Text(assistantName),
          actions: [
            IconButton(
              tooltip: 'Nueva conversación',
              icon: const Icon(Icons.refresh),
              onPressed: () {
                final services = ServicesScope.of(context);
                services.ai.resetConversation();
                services.ai.assistant(AppScope.of(context)).then((a) {
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
                      'tu perfil, tu meta y lo que registraste hoy. No doy '
                      'consejo médico.',
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
                                SelectableText(t.text),
                                if (t.proposal != null)
                                  _ProposalCard(
                                    proposal: t.proposal!,
                                    saved: _saved.contains(t.proposal),
                                    onAccept: () => _accept(t.proposal!),
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
            child: Text(_error!, style: TextStyle(color: scheme.error)),
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

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.proposal,
    required this.saved,
    required this.onAccept,
  });
  final FoodProposal proposal;
  final bool saved;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          for (final i in proposal.items)
            Text(
              '• ${i.food.name}, ${i.grams.round()} g: '
              '${i.food.forGrams(i.grams).kcal.round()} kcal',
            ),
          const SizedBox(height: 8),
          NutrientRow(proposal.total),
          const SizedBox(height: 8),
          saved
              ? const Text('✓ Agregado a tu día')
              : FilledButton(
                  key: const Key('proposal-accept'),
                  onPressed: onAccept,
                  child: const Text('Agregar a mi día'),
                ),
          Text(
            'Nutrientes del USDA FoodData Central.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
