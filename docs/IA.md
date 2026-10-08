# La IA en ZERACK Fit

## Qué modelo

Claude (`claude-opus-5-5`) por la API de Mensajes de Anthropic. Dart no tiene
SDK oficial, así que `apps/zerack_fit/lib/src/ai/claude_client.dart` usa la API
REST documentada.

## Por qué no hay clave dentro de la app

La app es open source: cualquier clave embebida quedaría pública. Hay dos modos:

1. **Clave propia** (para probar): la persona pega su clave de Anthropic en
   Perfil → IA. Se guarda cifrada en el llavero (iOS) o Keystore (Android).
2. **Servidor intermedio** (para producción): ZERACK opera un proxy que recibe
   las solicitudes de la app, agrega la clave del lado del servidor y las
   reenvía a `https://api.anthropic.com/v1/messages` sin cambiar el formato. En
   Perfil → IA → Servidor se pone su URL (`https://…`). En este modo la app no
   envía el campo `fallbacks`; el proxy puede agregarlo.

Antes de lanzar al público hace falta el proxy, con límite de uso por
dispositivo para controlar el costo.

## Qué se envía

| Función | Qué sale del teléfono |
|---|---|
| Escanear plato | La foto y la lista de alimentos de la base (nombres e ids) |
| Asistente | Los mensajes y lo que consultan sus herramientas: perfil, meta, comidas, semana, plan |

Nada se envía si la persona no activa la IA (Perfil → IA, apagada por defecto).

## Cómo se evita que la IA invente números

- El escáner usa salida estructurada (JSON schema): ids del catálogo y gramos.
  La app descarta ids inexistentes y gramos fuera de 1–2000 g. Los nutrientes
  los calcula la app con el USDA.
- El asistente solo puede proponer comidas con ids de `search_foods`; la
  persona confirma antes de guardar.
- El prompt de sistema prohíbe diagnosticar y manda al 911 ante síntomas.

## Costos

La app manda el prompt de sistema con `cache_control` para que los turnos
siguientes lo lean de caché. Effort `medium`.
