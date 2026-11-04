#!/bin/zsh
# ZERACK Fit personal para Itzael: servidor local con TUS claves + la app.
# Uso:  zsh ~/zerack-fit/server/personal.sh
# Las claves se leen de tus archivos y quedan solo en server/.dev.vars
# (ignorado por git). Nada se publica.
set -e
cd "$(dirname "$0")"
FISH_FILE=~/Documents/ZerackVoice/fish_key.txt
GEMINI_FILE=${GEMINI_FILE:-~/Documents/ZerackVoice/gemini_key.txt}
{
  [ -f "$FISH_FILE" ] && printf 'FISH_API_KEY=%s\n' "$(tr -d '\r\n' < "$FISH_FILE")"
  [ -f "$GEMINI_FILE" ] && printf 'GEMINI_API_KEY=%s\n' "$(tr -d '\r\n' < "$GEMINI_FILE")"
} > .dev.vars
chmod 600 .dev.vars
[ -f "$GEMINI_FILE" ] || echo "Falta la clave de Gemini: guárdala en $GEMINI_FILE (o GEMINI_FILE=ruta zsh personal.sh)."
[ -d node_modules ] || npm install --silent
npx wrangler dev --port 8787 --local >/tmp/zerack-fit-server.log 2>&1 &
SERVER_PID=$!
python3 -m http.server 8765 --directory .personal-web >/dev/null 2>&1 &
WEB_PID=$!
trap 'kill $SERVER_PID $WEB_PID 2>/dev/null' EXIT INT TERM
sleep 4
open http://localhost:8765
echo "ZERACK Fit abierto en http://localhost:8765 (Ctrl+C para cerrar)."
wait
