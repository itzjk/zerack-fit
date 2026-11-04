import 'package:flutter/material.dart';

import '../../ai/claude_client.dart' show assistantName;
import '../../ai/ai_service.dart';
import '../../services.dart';
import '../scope.dart';
import '../theme/zk_widgets.dart';

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
        const ZkHeroIcon(Icons.auto_awesome_outlined),
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

  String? _keyMessage;
  bool _keyError = false;
  bool _saving = false;

  Future<void> _saveKey() async {
    final ai = ServicesScope.of(context).ai;
    setState(() {
      _saving = true;
      _keyMessage = null;
    });
    try {
      final r = await ai.setApiKey(_key.text);
      _keyMessage = r.message;
      _keyError = r.check == KeyCheck.rejected;
      if (!_keyError) await _check();
    } on UnknownKeyFormat catch (e) {
      _keyMessage = e.message;
      _keyError = true;
    } on Object catch (e) {
      _keyMessage = 'No se pudo guardar la clave en este dispositivo: $e';
      _keyError = true;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _apiKey(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const ZkHeroIcon(Icons.key_outlined),
        const SizedBox(height: 16),
        Text('Conecta la IA', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        const Text(
          'ZERACK Fit es open source y no trae ninguna clave dentro. Pega tu '
          'clave de Gemini (gratis en aistudio.google.com, empieza con AIza) '
          'o de Anthropic (empieza con sk-ant-). Se guarda solo en este '
          'teléfono. También puedes configurar el servidor de ZERACK en '
          'Perfil → IA.',
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('ai-key'),
          controller: _key,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(labelText: 'Clave de API'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('ai-key-save'),
          onPressed: _saving ? null : _saveKey,
          child: Text(_saving ? 'Comprobando…' : 'Guardar clave'),
        ),
        if (_keyMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _keyMessage!,
            key: const Key('ai-key-message'),
            style: TextStyle(color: _keyError ? scheme.error : null),
          ),
        ],
      ],
    );
  }
}
