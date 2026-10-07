import 'package:flutter/material.dart';
import 'package:zerack_core/zerack_core.dart';

import '../onboarding/onboarding_flow.dart';
import '../scope.dart';
import '../strings.dart';
import 'profile_form.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const _sources = [
    Sources.mifflin1990,
    Sources.frankenfield2005,
    Sources.fao2004,
    Sources.compendium2024,
    Sources.acsmScreening2015,
    Sources.acsmProgression2009,
    Sources.tanaka2001,
    Sources.acsmGuidelines,
    Sources.hooper1995,
  ];

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
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (c) => Scaffold(
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
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Repetir cuestionario de seguridad'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (c) => ScreeningStep(
                onDone: () {
                  if (c.mounted) Navigator.of(c).pop();
                },
              ),
            ),
          ),
        ),
        const Divider(height: 32),
        Text('Fuentes', style: text.titleMedium),
        const SizedBox(height: 4),
        const Text(
          'Cada cálculo de la app sale de una de estas publicaciones.',
        ),
        for (final s in _sources)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(s.citation, style: text.bodySmall),
          ),
        const Divider(height: 32),
        Text('Privacidad', style: text.titleMedium),
        const SizedBox(height: 4),
        const Text('Tus datos solo están en este teléfono.'),
        const SizedBox(height: 8),
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
                  'Se borra todo de este teléfono. '
                  'No se puede deshacer.',
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
            if (ok == true) await state.eraseAll();
          },
          child: const Text('Borrar todos mis datos'),
        ),
        const SizedBox(height: 24),
        Text(Es.disclaimer, style: text.bodySmall),
      ],
    );
  }
}
