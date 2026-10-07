# ZERACK Fit

Entrenamiento que se adapta a tu salud. Open source, **local-first** (tus datos
de salud se quedan en tu teléfono) y con **cada regla respaldada por una fuente
publicada**.

> ZERACK es una herramienta de entrenamiento y bienestar. **No diagnostica ni
> trata enfermedades** y no sustituye a un profesional de la salud. Si sientes
> dolor en el pecho, mareo o falta de aire anormal, detente y busca atención.

## Estado

Fase 1 en construcción. Hoy existe el núcleo (`packages/zerack_core`), Dart
puro y con pruebas:

- **Energía:** gasto en reposo (Mifflin-St Jeor), gasto total (PAL FAO 2004) y
  calorías por actividad (Compendium 2024).
- **Screening:** algoritmo ACSM 2015 que decide si hace falta autorización
  médica antes de entrenar.
- **Seguridad:** signos de alarma que detienen la sesión.
- **Progresión:** regla ACSM 2009 para subir cargas.
- **Pulso:** pulso máximo (Tanaka) y zonas por reserva (Karvonen).
- **Readiness:** chequeo diario con el índice de Hooper.

Todas las fuentes están en [SOURCES.md](SOURCES.md).

Y la app (`apps/zerack_fit`, Flutter) ya tiene:

- Aviso de bienestar, perfil y cuestionario de seguridad ACSM al entrar.
- **Hoy:** chequeo diario con nota de 0 a 100 y energía del día como rango,
  más registro manual de calorías comidas.
- **Entrenar:** 8 ejercicios base, registro de series, sugerencia de carga
  automática y botón **"Me siento mal"** que detiene la sesión ante signos de
  alarma. Si el screening pide autorización médica, Entrenar queda bloqueado
  hasta que la persona la confirme.
- **Perfil:** editar datos, repetir el cuestionario, ver las fuentes y borrar
  todo del teléfono.

## Principios

1. **Sin fuente no hay regla.**
2. **Local-first:** sin cuenta ni servidor obligatorios.
3. **Estimar, no diagnosticar:** los números se muestran como estimaciones.
4. **Ante la duda, lo seguro:** el motor nunca sube cargas ni intensidad sin
   respaldo.

## Desarrollo

Núcleo:

```bash
cd packages/zerack_core
dart pub get
dart test
```

App:

```bash
cd apps/zerack_fit
flutter pub get
flutter test
flutter run            # iPhone necesita Xcode; Android necesita Android Studio
flutter run -d chrome  # versión web para probar rápido
```

## Licencia

[MIT](LICENSE) © ZERACK
