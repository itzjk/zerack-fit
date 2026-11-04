# ZERACK Fit personal (en tu Mac, sin poner claves en la app)

**Un comando:**

```bash
zsh ~/zerack-fit/server/personal.sh
```

Abre http://localhost:8765 en tu navegador. La app usa el servidor local
(`localhost:8787`) con tus claves, así que **no te pide ninguna**. Nada se
publica.

- Voz (Fish): lee tu clave de `~/Documents/ZerackVoice/fish_key.txt`.
- Gemini (escaneo y agente): guarda tu clave en
  `~/Documents/ZerackVoice/gemini_key.txt` (o corre
  `GEMINI_FILE=/ruta/a/tu_clave zsh ~/zerack-fit/server/personal.sh`).
- Las claves quedan solo en `server/.dev.vars`, que git ignora.

**Al abrirla la primera vez:** acepta el aviso, pon tu peso, estatura, sexo y
edad (18), elige tu nivel y responde el cuestionario de seguridad. En Perfil →
Meta y plan elige "Bajar de peso" o "Mantener" según el cambio que buscas.

## Pendiente
- No pude cargar tus claves yo: el sistema me bloquea leer archivos de claves.
  Por eso el script lo hace al correrlo tú.
- Perfil precargado (nombre, horario 3:38 a. m., huevos antes del gym): no dio
  tiempo; la app te pregunta tus datos una vez al abrirla.
