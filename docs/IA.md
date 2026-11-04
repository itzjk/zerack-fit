# La IA en ZERACK Fit

## Proveedores

| Modo | Cuándo | Qué necesita la persona |
|---|---|---|
| Servidor de ZERACK (por defecto) | La app se compiló con `--dart-define=ZERACK_SERVER=…` | Nada |
| Gemini con clave propia | La persona pega una clave `AIza…` | Clave de aistudio.google.com |
| Claude con clave propia | La persona pega una clave `sk-ant-…` | Clave de Anthropic |

Prioridad: clave propia de Gemini > clave propia de Claude > servidor. El
modelo de Gemini es `gemini-3.6-flash` (`lib/src/ai/gemini_client.dart`); el de
Claude, `claude-opus-5-5`.

Al guardar una clave, la app la reconoce por su forma, la guarda en el lugar de
su proveedor y la verifica con una consulta que no gasta tokens (lista de
modelos). Si el proveedor la rechaza, lo dice.

## Por qué no hay clave dentro de la app

La app es open source y pública (GitHub Pages y APK): cualquier clave embebida
quedaría expuesta. El servidor (`server/`, Cloudflare Worker) guarda las claves
de Gemini y de Fish Audio como secretos, pone un límite por dispositivo y por
día, y no guarda fotos ni textos. Despliegue: `server/DEPLOY.md`.

## Qué se envía

| Función | Qué sale del teléfono |
|---|---|
| Escanear plato | La foto y la lista de alimentos de la base (nombres e ids) |
| Agente | Los mensajes y lo que consultan sus herramientas |
| Voz | El texto de la respuesta (solo por el servidor) |

Además, por el servidor viaja un id aleatorio del dispositivo (UUID) para el
límite diario. No identifica a la persona.

## Cómo se evita que la IA invente números

- El escáner usa salida estructurada: ids del catálogo y gramos. La app
  descarta ids inexistentes y gramos fuera de rango; los nutrientes los calcula
  con el USDA.
- El agente solo propone comidas con ids de la base y cambios de plan dentro
  de los rangos de ACSM; la persona confirma cada tarjeta.
- Las explicaciones salen de `lib/src/ai/rules.dart`, cada una con su fuente.
- El prompt prohíbe diagnosticar y manda al 911 ante síntomas.
