# Desplegar el servidor de ZERACK Fit

Pasos para Itzael, en orden. Todo se hace desde la carpeta `server/` del repo.
Necesitas Node 20 o más nuevo y una cuenta de Cloudflare (la gratuita sirve).

## 1. Instalar

```bash
cd ~/zerack-fit/server
npm install
```

## 2. Entrar en Cloudflare

```bash
npx wrangler login
```

Se abre el navegador; acepta. Puedes comprobarlo con `npx wrangler whoami`.

## 3. Crear el KV de contadores y pegar su id

```bash
npx wrangler kv namespace create RATE
```

La salida trae un bloque como este:

```toml
[[kv_namespaces]]
binding = "RATE"
id = "0123456789abcdef0123456789abcdef"
```

Si Wrangler pregunta si quieres que lo añada él al archivo de configuración,
responde **no** (el bloque ya existe). Abre `server/wrangler.toml`, busca
`id = "PEGA_AQUI_EL_ID_DEL_KV"` y cámbialo por el id que te dio. El id no es
secreto: se puede subir al repo.

## 4. Guardar las claves como secretos

Cada comando te pide la clave; pégala y pulsa Enter. No se ve al escribir y no
queda en ningún archivo.

```bash
npx wrangler secret put GEMINI_API_KEY
npx wrangler secret put FISH_API_KEY
```

Tu clave de Fish ya está en un archivo: puedes pasarla sin copiarla a mano
(Wrangler la lee de la entrada y no queda en el historial):

```bash
npx wrangler secret put FISH_API_KEY < ~/Documents/ZerackVoice/fish_key.txt
```

Opcional, para usar una voz concreta de Fish Audio (el id que aparece en la
página de la voz en fish.audio):

```bash
npx wrangler secret put FISH_VOICE_ID
```

Si no pones `FISH_VOICE_ID`, Fish usa su voz por defecto.

Nota: si la cuenta aún no tiene el Worker creado, el primer `secret put`
pregunta si quieres crearlo; di que sí.

## 5. Desplegar

```bash
npx wrangler deploy
```

Al terminar imprime la URL, del estilo
`https://zerack-fit-server.<tu-subdominio>.workers.dev`.

## 6. Probar

```bash
curl https://zerack-fit-server.<tu-subdominio>.workers.dev/v1/health
```

Debe responder:

```json
{"ok":true,"gemini":true,"fish":true,"models":["gemini-3.6-flash"]}
```

Si `gemini` o `fish` salen en `false`, falta ese secreto: repite el paso 4
(se aplica al momento, no hace falta volver a desplegar).

Prueba de voz (guarda un MP3; gasta una petición de Fish):

```bash
curl -X POST https://zerack-fit-server.<tu-subdominio>.workers.dev/v1/tts \
  -H "X-Device-Id: $(uuidgen | tr A-Z a-z)" \
  -H "Content-Type: application/json" \
  -d '{"text":"Hola, soy ZERACK Fit."}' \
  -o prueba.mp3
```

## 7. Decirle a la app la URL

La app lee la URL al compilar con `--dart-define=ZERACK_SERVER=…` (sin barra
final). Sin ese valor la app funciona sin servidor.

```bash
cd ~/zerack-fit/apps/zerack_fit
SERVER=https://zerack-fit-server.<tu-subdominio>.workers.dev
alias flutter=~/development/flutter/bin/flutter   # en esta Mac Flutter vive ahí

flutter run --dart-define=ZERACK_SERVER=$SERVER                  # probar
flutter build apk --release --dart-define=ZERACK_SERVER=$SERVER  # Android
flutter build ipa --release --dart-define=ZERACK_SERVER=$SERVER  # iPhone
flutter build web --release --base-href /zerack-fit/ --dart-define=ZERACK_SERVER=$SERVER  # GitHub Pages
```

Para la web: `https://itzjk.github.io` y `http://localhost:8765` ya están en
`ALLOWED_ORIGINS`. Si sirves la web desde otro origen, añádelo en
`wrangler.toml` y vuelve a hacer `npx wrangler deploy`.

## Ajustes después

- Límites y modelos: cambia las `[vars]` de `wrangler.toml` y `npx wrangler deploy`.
- Cambiar una clave: `npx wrangler secret put GEMINI_API_KEY` otra vez.
- Ver errores en vivo (no muestra contenido del usuario): `npx wrangler tail`.
