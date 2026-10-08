# Guía de revisión (v0.2)

## Instalar

**Android (lo más rápido):** copia `zerack-fit-0.2.0.apk` (está en
[Releases](https://github.com/itzjk/zerack-fit/releases) del repo) al teléfono
y ábrelo. Android pedirá permitir "instalar apps de origen desconocido".
Está firmado con la llave de depuración: sirve para probar, no para la Play
Store.

**iPhone:** instala Xcode desde la App Store, abre una terminal y corre:

```bash
cd ~/zerack-fit/apps/zerack_fit
~/development/flutter/bin/flutter run
```

Conecta el iPhone por cable la primera vez. Para HealthKit, Xcode pide tu
cuenta de Apple Developer.

**Web (sin teléfono):** `flutter run -d chrome`. En web no hay cámara para
pulso ni código de barras, ni Apple Health.

## Recorrido sugerido (10 minutos)

1. Acepta el aviso, llena tu perfil y el cuestionario de seguridad.
   - Prueba responder "Sí" a enfermedad sin hacer ejercicio: Entrenar debe
     quedar bloqueado.
2. **Hoy:** haz el chequeo; revisa tu meta de energía y proteína.
3. **Escanear plato:** Perfil → IA → activa y pega una clave de Anthropic
   (o usa el aviso que aparece). Toma foto de un plato. Corrige gramos, cambia
   un alimento y guarda.
4. **Buscar:** "tortilla", "frijoles", "pollo". Elige una porción.
5. **Código:** escanea un producto empacado.
6. **IA:** pregunta "¿cuánta proteína me falta hoy?" y "desayuné 2 huevos y 2
   tortillas" → confirma la propuesta.
7. **Entrenar:** empieza el entreno A, registra series, mira el descanso,
   termina. Vuelve: ahora toca B.
8. **Me siento mal:** dentro de un ejercicio, marca "mareo": la sesión se
   detiene.
9. **Progreso:** registra tu peso dos días distintos para ver la gráfica.
10. **Perfil:** cambia a "Bajar de peso" y mira cómo baja la meta en Hoy.
    Copia el respaldo y bórralo todo; importa el respaldo.

## Pendientes que necesitan tu decisión

- **Nombre del asistente.** Hoy dice "ZERACK IA" (una sola constante:
  `assistantName` en `apps/zerack_fit/lib/src/ai/claude_client.dart`).
- **Correo de contacto** en el aviso de privacidad
  (`apps/zerack_fit/assets/legal/privacidad.txt`, dice `[PENDIENTE]`).
- **Servidor intermedio para la IA** antes de publicar (ver
  [IA.md](IA.md)): sin él, cada persona necesitaría su propia clave.
- **Firma de release** para la Play Store y cuenta de Apple Developer.
- **Revisión legal** del aviso y los términos por un abogado (México).

## Qué no se pudo probar aquí

- iPhone: no hay Xcode en esta Mac; el proyecto iOS está configurado
  (permisos, HealthKit) pero no compilado.
- Cámara, flash, Health Connect y Apple Health: necesitan teléfono real. La
  lógica está probada con datos simulados.
- El escáner y el asistente con la API real: probados con respuestas
  simuladas; necesitan una clave para probar de verdad.
