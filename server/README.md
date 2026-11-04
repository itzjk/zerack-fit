# ZERACK Fit — servidor intermedio

Cloudflare Worker que deja usar el escaneo de platos (Gemini) y la voz (Fish
Audio) sin poner ninguna clave en la app. Las claves viven como secretos del
Worker. Nada de lo que manda el usuario (fotos, textos, cuerpos) se guarda ni
se registra: en KV solo hay contadores diarios.

Para desplegarlo: [DEPLOY.md](DEPLOY.md).

## Rutas

Todas exigen `X-Device-Id` (UUID v4) salvo `/v1/health`.

| Ruta | Qué hace |
|---|---|
| `POST /v1/gemini/{model}:generateContent` | Reenvía el JSON de `generateContent` a Google con `x-goog-api-key`. Devuelve status y JSON de Google sin cambios. `{model}` debe estar en `GEMINI_MODELS`. Máximo 6 MB. Solo se aceptan `contents`, `systemInstruction`, `generationConfig`, `tools` (solo `functionDeclarations`), `toolConfig` y `safetySettings` (también en snake_case). |
| `POST /v1/tts` | `{"text": "…"}` (1–600 caracteres) → MP3 de Fish Audio (`audio/mpeg`). |
| `GET /v1/health` | `{"ok":true,"gemini":bool,"fish":bool,"models":[…]}`. No cuenta para límites. |

Errores: `{"error":{"code":"…","message":"…"}}` con estos códigos:
`bad_device` 400, `model_not_allowed` 400, `field_not_allowed` 400,
`bad_json` 400, `bad_text` 400, `origin_not_allowed` 403, `not_found` 404,
`method_not_allowed` 405, `too_large` 413, `rate_limited` 429 (con
`Retry-After` en segundos hasta la medianoche UTC), `upstream_error` 502,
`not_configured` 503. Los errores de Gemini (4xx/5xx de Google) se devuelven
tal cual; los de Fish se convierten en 502 `upstream_error`.

## Configuración

Secretos: `GEMINI_API_KEY`, `FISH_API_KEY`, opcional `FISH_VOICE_ID`.

Vars en `wrangler.toml`: `GEMINI_MODELS`, `DAILY_LIMIT` (60), `TTS_DAILY_LIMIT`
(40), `IP_DAILY_LIMIT` (300, suma Gemini y voz), `ALLOWED_ORIGINS`,
`FISH_MODEL` (`s2.1-pro`). Un límite en `0` apaga esa ruta.

KV `RATE`: claves `d:{gemini|tts}:{día}:{dispositivo}` e `ip:{día}:{hash}` (la
IP se guarda como SHA-256 recortado, nunca en claro), con TTL de 2 días. KV no
es atómico, así que con ráfagas simultáneas el conteo puede quedarse un poco
corto; para un límite anti-abuso basta.

## Desarrollo

```bash
cd server
npm install
npm run typecheck   # tsc --noEmit
npm test            # Vitest dentro del runtime de Workers; fetch a Google y Fish mockeado
cp .dev.vars.example .dev.vars   # pon claves de prueba si quieres usar `npm run dev`
npm run dev         # http://localhost:8787
```

Las pruebas no llaman a ninguna API real ni usan claves reales.
