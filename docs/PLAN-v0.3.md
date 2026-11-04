# Plan v0.3 — agente, voz, escaneo sin clave y funciones avanzadas

Pedido de Itzael (2026-11-03).

1. **Agente de IA de verdad.** Conversa con el contexto completo (perfil, meta,
   chequeo, comidas, entrenos) y hace cosas en la app: anotar comida, ajustar el
   plan, abrir la sesión guiada, explicar una regla con su fuente. Siempre con
   confirmación de la persona para lo que escribe datos. No diagnostica.
2. **Voz con Fish Audio.** El agente lee en voz alta sus respuestas. La clave de
   Fish nunca va en la app ni en el repo: pasa por el servidor.
3. **Escaneo con Gemini para cualquiera, sin clave.**
   a. Arreglar el fallo: una clave de Gemini se guardaba pero se mandaba a
      Anthropic, que la rechazaba. La app detecta el proveedor por la clave y
      la valida al guardar.
   b. Servidor intermedio (Cloudflare Worker) con las claves como secretos,
      límite por dispositivo y por día, sin guardar fotos. La app lo usa por
      defecto; quien quiera puede poner su propia clave.
4. **Funciones que no tiene ninguna app de fitness.** Proponer 3, construir 2,
   con pruebas y respetando: local-first, regla con fuente, no diagnostica.

Reglas: pruebas en verde, capturas, commits a nombre del dueño sin firma de IA,
push solo de lo revisado y sin --force. Publicar Pages/APK y desplegar el
Worker necesita el OK de Itzael.
