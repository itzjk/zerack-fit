import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zerack_core/zerack_core.dart';

import '../../ai/claude_client.dart' show assistantName, ClaudeConfig;
import '../../services.dart';
import '../common/text_prompt.dart';
import '../onboarding/onboarding_flow.dart';
import '../scope.dart';
import '../strings.dart';
import 'legal_page.dart';
import 'profile_form.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  void _push(BuildContext context, Widget Function(BuildContext) page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: page));

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = state.profile!;
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Perfil', style: text.headlineSmall),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('${Es.sex(p.sex)}, ${p.ageYears} años'),
          subtitle: Text(
            '${Es.kg(p.weightKg)} · ${p.heightCm.round()} cm · '
            '${Es.activity(p.activity)}',
          ),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () => _push(
            context,
            (c) => Scaffold(
              appBar: AppBar(title: const Text('Editar perfil')),
              body: ProfileForm(
                initial: p,
                onSaved: (np) async {
                  await state.saveProfile(np);
                  if (c.mounted) Navigator.of(c).pop();
                },
              ),
            ),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Repetir cuestionario de seguridad'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _push(
            context,
            (c) => ScreeningStep(
              onDone: () {
                if (c.mounted) Navigator.of(c).pop();
              },
            ),
          ),
        ),
        const Divider(height: 32),
        const _GoalsSection(),
        const Divider(height: 32),
        const _AiSection(),
        const Divider(height: 32),
        const _HealthSection(),
        const Divider(height: 32),
        const _DataSection(),
        const Divider(height: 32),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Aviso de privacidad'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _push(context, (_) => const LegalPage(LegalDoc.privacy)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Términos de uso'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _push(context, (_) => const LegalPage(LegalDoc.terms)),
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Fuentes'),
          subtitle: const Text('Cada cálculo sale de una publicación'),
          children: [
            for (final s in Sources.all)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(s.citation, style: text.bodySmall),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(Es.disclaimer, style: text.bodySmall),
        const SizedBox(height: 8),
        Text(
          'ZERACK Fit es open source (MIT): github.com/itzjk/zerack-fit',
          style: text.bodySmall,
        ),
      ],
    );
  }
}

class _GoalsSection extends StatelessWidget {
  const _GoalsSection();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.settings;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Meta y plan', style: text.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<WeightGoal>(
          key: const Key('goal-choice'),
          segments: [
            for (final g in WeightGoal.values)
              ButtonSegment(value: g, label: Text(Es.goal(g))),
          ],
          selected: {s.goal},
          onSelectionChanged: (v) =>
              state.saveSettings(s.copyWith(goal: v.first)),
        ),
        const SizedBox(height: 4),
        Text(
          'Bajar de peso resta 500 kcal a tu gasto (ACSM 2001) sin pasar de '
          'tu gasto en reposo.',
          style: text.bodySmall,
        ),
        const SizedBox(height: 12),
        SegmentedButton<TrainingLevel>(
          key: const Key('level-choice'),
          segments: [
            for (final l in TrainingLevel.values)
              ButtonSegment(value: l, label: Text(Es.level(l))),
          ],
          selected: {s.level},
          onSelectionChanged: (v) =>
              state.saveSettings(s.copyWith(level: v.first)),
        ),
        const SizedBox(height: 12),
        SegmentedButton<int>(
          key: const Key('days-choice'),
          segments: const [
            ButtonSegment(value: 2, label: Text('2 días')),
            ButtonSegment(value: 3, label: Text('3 días')),
          ],
          selected: {s.daysPerWeek},
          onSelectionChanged: (v) =>
              state.saveSettings(s.copyWith(daysPerWeek: v.first)),
        ),
        SwitchListTile(
          key: const Key('gym-switch'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Entreno en gimnasio'),
          subtitle: const Text('Apágalo si entrenas en casa con mancuernas'),
          value: s.gymAccess,
          onChanged: (v) => state.saveSettings(s.copyWith(gymAccess: v)),
        ),
      ],
    );
  }
}

class _AiSection extends StatefulWidget {
  const _AiSection();

  @override
  State<_AiSection> createState() => _AiSectionState();
}

class _AiSectionState extends State<_AiSection> {
  bool? _hasKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ServicesScope.of(context).ai.apiKey().then((k) {
      if (mounted) setState(() => _hasKey = k != null && k.isNotEmpty);
    });
  }

  Future<String?> _ask(String title, String label, {bool secret = false}) =>
      showTextPrompt(context, title: title, label: label, secret: secret);

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final ai = ServicesScope.of(context).ai;
    final s = state.settings;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(assistantName, style: text.titleMedium),
        SwitchListTile(
          key: const Key('ai-switch'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Usar IA'),
          subtitle: const Text(
            'Escaneo de platos y asistente. Envía a Anthropic solo lo '
            'necesario cuando los usas.',
          ),
          value: s.aiConsent,
          onChanged: (v) {
            ai.resetConversation();
            state.saveSettings(s.copyWith(aiConsent: v));
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Clave de la API de Anthropic'),
          subtitle: Text(
            _hasKey == true ? 'Guardada en el llavero' : 'Sin clave',
          ),
          trailing: _hasKey == true
              ? TextButton(
                  onPressed: () async {
                    await ai.setApiKey(null);
                    if (mounted) setState(() => _hasKey = false);
                  },
                  child: const Text('Quitar'),
                )
              : const Icon(Icons.chevron_right),
          onTap: () async {
            final k = await _ask('Clave de API', 'sk-ant-…', secret: true);
            if (k == null || k.trim().isEmpty) return;
            await ai.setApiKey(k);
            if (mounted) setState(() => _hasKey = true);
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Servidor (opcional)'),
          subtitle: Text(s.aiBaseUrl ?? ClaudeConfig.anthropicBaseUrl),
          trailing: s.aiBaseUrl == null
              ? const Icon(Icons.chevron_right)
              : TextButton(
                  onPressed: () {
                    ai.resetConversation();
                    state.saveSettings(s.copyWith(aiBaseUrl: () => null));
                  },
                  child: const Text('Quitar'),
                ),
          onTap: () async {
            final url = await _ask('Servidor', 'https://…');
            final u = Uri.tryParse(url?.trim() ?? '');
            if (u == null || u.scheme != 'https' || u.host.isEmpty) return;
            ai.resetConversation();
            await state.saveSettings(
              s.copyWith(
                aiBaseUrl: () => u.toString().replaceAll(RegExp(r'/$'), ''),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _HealthSection extends StatefulWidget {
  const _HealthSection();

  @override
  State<_HealthSection> createState() => _HealthSectionState();
}

class _HealthSectionState extends State<_HealthSection> {
  String? _status;

  Future<void> _toggle(bool on) async {
    final state = AppScope.of(context);
    final health = ServicesScope.of(context).health;
    if (!on) {
      await state.saveSettings(state.settings.copyWith(healthSync: false));
      return;
    }
    final ok = await health.requestAccess();
    if (!mounted) return;
    if (!ok) {
      setState(
        () => _status =
            'No se dio el permiso o falta la app Health Connect en Android.',
      );
      return;
    }
    await state.saveSettings(state.settings.copyWith(healthSync: true));
    await _import();
  }

  Future<void> _import() async {
    final state = AppScope.of(context);
    final health = ServicesScope.of(context).health;
    try {
      final snap = await health.read(DateTime.now());
      final parts = <String>[];
      if (snap.weightKg != null) {
        await state.logWeight((snap.weightKg! * 10).roundToDouble() / 10);
        parts.add('peso ${Es.kg(snap.weightKg!)}');
      }
      if (snap.stepsToday != null) parts.add('${snap.stepsToday} pasos hoy');
      if (snap.restingHr != null) {
        parts.add('pulso en reposo ${snap.restingHr!.round()} lpm');
      }
      if (mounted) {
        setState(
          () => _status = parts.isEmpty
              ? 'Conectado. Aún no hay datos para leer.'
              : 'Leído: ${parts.join(', ')}.',
        );
      }
    } on Object {
      if (mounted) setState(() => _status = 'No pude leer los datos.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final health = ServicesScope.of(context).health;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Apple Health / Health Connect', style: text.titleMedium),
        SwitchListTile(
          key: const Key('health-switch'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Sincronizar'),
          subtitle: Text(
            health.supported
                ? 'Lee peso, pasos y pulso en reposo; guarda tus entrenos y '
                      'tu peso. Galaxy Watch llega vía Health Connect.'
                : 'Disponible en iPhone y Android.',
          ),
          value: state.settings.healthSync,
          onChanged: health.supported ? _toggle : null,
        ),
        if (state.settings.healthSync)
          TextButton.icon(
            icon: const Icon(Icons.sync),
            label: const Text('Leer ahora'),
            onPressed: _import,
          ),
        if (_status != null) Text(_status!, key: const Key('health-status')),
      ],
    );
  }
}

class _DataSection extends StatelessWidget {
  const _DataSection();

  Future<void> _import(BuildContext context) async {
    final state = AppScope.of(context);
    final raw = await showTextPrompt(
      context,
      title: 'Importar respaldo',
      hint: 'Pega aquí el respaldo (JSON)',
      confirm: 'Reemplazar mis datos',
      maxLines: 8,
      fieldKey: const Key('import-input'),
      confirmKey: const Key('import-confirm'),
    );
    if (raw == null || !context.mounted) return;
    try {
      await state.importJson(raw);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Respaldo importado')));
      }
    } on FormatException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tus datos', style: text.titleMedium),
        const SizedBox(height: 4),
        const Text('Se guardan solo en este teléfono.'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const Key('export'),
              icon: const Icon(Icons.copy),
              label: const Text('Copiar respaldo'),
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: state.exportJson()),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Respaldo copiado. Pégalo en una nota o correo.',
                      ),
                    ),
                  );
                }
              },
            ),
            OutlinedButton.icon(
              key: const Key('import'),
              icon: const Icon(Icons.paste),
              label: const Text('Importar'),
              onPressed: () => _import(context),
            ),
            OutlinedButton(
              key: const Key('erase-all'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Borrar todos mis datos'),
                    content: const Text(
                      'Se borra todo de este teléfono, incluida la clave de '
                      'la IA. No se puede deshacer.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(c).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        key: const Key('erase-yes'),
                        onPressed: () => Navigator.of(c).pop(true),
                        child: const Text('Borrar'),
                      ),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  final ai = ServicesScope.of(context).ai;
                  await ai.setApiKey(null);
                  ai.resetConversation();
                  await state.eraseAll();
                }
              },
              child: const Text('Borrar todo'),
            ),
          ],
        ),
      ],
    );
  }
}
