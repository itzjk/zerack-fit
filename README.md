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

## Principios

1. **Sin fuente no hay regla.**
2. **Local-first:** sin cuenta ni servidor obligatorios.
3. **Estimar, no diagnosticar:** los números se muestran como estimaciones.
4. **Ante la duda, lo seguro:** el motor nunca sube cargas ni intensidad sin
   respaldo.

## Desarrollo

```bash
cd packages/zerack_core
dart pub get
dart test
```

## Licencia

[MIT](LICENSE) © ZERACK
