import 'package:flutter/material.dart';

import '../../ai/claude_client.dart' show assistantName;
import '../../services.dart';
import '../scope.dart';

/// Muestra [child] solo si la persona dio su consentimiento y hay forma de
/// conectarse a la IA. Si no, explica qué se envía y deja activarla ahí mismo.
class AiGate extends StatefulWidget {
  const AiGate({
    super.key,
    required this.feature,
    required this.sends,
    required this.child,
  });

  /// "escanear tu comida", "usar el asistente"...
  final String feature;

  /// Qué datos salen del teléfono con esta función.
  final String sends;
  final Widget child;

  @override
  State<AiGate> createState() => _AiGateState();
}

class _AiGateState extends State<AiGate> {
  final _key = TextEditingController();

  /// `null` = disponible; 'consent' / 'key' = qué falta.
  String? _reason;
  bool _checked = false;

  /// Solo se vuelve a revisar si cambian los ajustes de la IA, no con cada
  /// dato que la persona registra (eso reiniciaría el chat).
  String? _settingsKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = AppScope.of(context).settings;
    final key = '${s.aiConsent}|${s.aiBaseUrl}';
    if (key != _settingsKey) {
      _settingsKey = key;
      _check();
    }
  }

  Future<void> _check() async {
    final reason = await ServicesScope.of(
      context,
    ).ai.unavailableReason(AppScope.of(context));
    if (mounted) {
      setState(() {
        _reason = reason;
        _checked = true;
      });
    }
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) return const Center(child: CircularProgressIndicator());
    return switch (_reason) {
      null => widget.child,
      'consent' => _consent(context),
      _ => _apiKey(context),
    };
  }

  Widget _consent(BuildContext context) {
    final state = AppScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.auto_awesome_outlined, size: 56),
        const SizedBox(height: 16),
        Text(
          'Para ${widget.feature} se usa $assistantName',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Text(
          'Cuando usas esta función, la app envía ${widget.sends} a '
          'Anthropic, el proveedor del modelo Claude, para procesarlo. Nada '
          'se envía si no la usas. El resto de tus datos se queda en este '
          'teléfono.\n\n'
          'La IA puede equivocarse: revisa siempre lo que propone. No es '
          'consejo médico.',
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('ai-consent'),
          onPressed: () async {
            await state.saveSettings(state.settings.copyWith(aiConsent: true));
          },
          child: const Text('Acepto, activar la IA'),
        ),
      ],
    );
  }

  Widget _apiKey(BuildContext context) {
    final ai = ServicesScope.of(context).ai;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.key_outlined, size: 56),
        const SizedBox(height: 16),
        Text('Conecta la IA', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        const Text(
          'ZERACK Fit es open source y no trae ninguna clave dentro. Pega tu '
          'clave de la API de Anthropic (se guarda cifrada en el llavero del '
          'teléfono) o configura un servidor en Perfil → IA.',
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('ai-key'),
          controller: _key,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Clave de API'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('ai-key-save'),
          onPressed: () async {
            await ai.setApiKey(_key.text);
            await _check();
          },
          child: const Text('Guardar clave'),
        ),
      ],
    );
  }
}
