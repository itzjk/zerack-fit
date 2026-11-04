/**
 * ZERACK Fit — servidor intermedio.
 *
 * Reenvía el escaneo de platos a Gemini y la voz a Fish Audio usando claves
 * guardadas como secretos del Worker, para que la app no tenga que llevar
 * ninguna. Nunca guarda ni registra fotos, textos ni cuerpos: lo único que
 * escribe en KV son contadores diarios (id de dispositivo aleatorio y un hash
 * de la IP).
 */

export interface Env {
  RATE: KVNamespace;
  GEMINI_API_KEY?: string;
  FISH_API_KEY?: string;
  FISH_VOICE_ID?: string;
  FISH_MODEL?: string;
  GEMINI_MODELS?: string;
  DAILY_LIMIT?: string;
  TTS_DAILY_LIMIT?: string;
  IP_DAILY_LIMIT?: string;
  ALLOWED_ORIGINS?: string;
}

export const GEMINI_BASE = "https://generativelanguage.googleapis.com/v1beta/models";
export const FISH_TTS_URL = "https://api.fish.audio/v1/tts";

const DEFAULT_MODELS = "gemini-3.6-flash";
const DEFAULT_ORIGINS = "https://itzjk.github.io,http://localhost:8765";
const DEFAULT_FISH_MODEL = "s2.1-pro";
const DEFAULTS = { gemini: 60, tts: 40, ip: 300 } as const;

export const MAX_GEMINI_BODY = 6 * 1024 * 1024; // 6 MB
const MAX_TTS_BODY = 16 * 1024;
const MAX_TTS_CHARS = 600;
const COUNTER_TTL_SECONDS = 2 * 24 * 60 * 60; // ~2 días

/** Llaves de primer nivel que acepta el reenvío a Gemini (y su forma snake_case). */
const ALLOWED_GEMINI_FIELDS = new Set([
  "contents",
  "systemInstruction",
  "system_instruction",
  "generationConfig",
  "generation_config",
  "tools",
  "toolConfig",
  "tool_config",
  "safetySettings",
  "safety_settings",
]);
/** Dentro de cada herramienta solo se permiten declaraciones de funciones (las ejecuta la app). */
const ALLOWED_TOOL_FIELDS = new Set(["functionDeclarations", "function_declarations"]);

const UUID_V4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const GEMINI_ROUTE = /^\/v1\/gemini\/([^/:]+):generateContent$/;

type Kind = "gemini" | "tts";

// ---------------------------------------------------------------------------
// Utilidades
// ---------------------------------------------------------------------------

function list(value: string | undefined, fallback: string): string[] {
  const raw = value === undefined || value.trim() === "" ? fallback : value;
  return raw
    .split(",")
    .map((s) => s.trim().replace(/\/+$/, ""))
    .filter(Boolean);
}

function limit(value: string | undefined, fallback: number): number {
  if (value === undefined || value.trim() === "") return fallback;
  const n = Number(value);
  return Number.isInteger(n) && n >= 0 ? n : fallback;
}

function hasSecret(value: string | undefined): value is string {
  return typeof value === "string" && value.length > 0;
}

export function utcDay(now: Date): string {
  return now.toISOString().slice(0, 10);
}

/** Segundos que faltan hasta la próxima medianoche UTC (mínimo 1). */
export function secondsUntilUtcMidnight(now: Date): number {
  const next = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1);
  return Math.max(1, Math.ceil((next - now.getTime()) / 1000));
}

async function sha256Hex(text: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** Lee el cuerpo sin pasar de `max` bytes. Devuelve null si es más grande. */
async function readLimited(request: Request, max: number): Promise<Uint8Array | null> {
  const declared = request.headers.get("Content-Length");
  if (declared !== null && Number(declared) > max) return null;
  if (!request.body) return new Uint8Array(0);

  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > max) {
      await reader.cancel();
      return null;
    }
    chunks.push(value);
  }
  const out = new Uint8Array(total);
  let offset = 0;
  for (const c of chunks) {
    out.set(c, offset);
    offset += c.byteLength;
  }
  return out;
}

function parseJson(bytes: Uint8Array): unknown {
  try {
    return JSON.parse(new TextDecoder().decode(bytes));
  } catch {
    return undefined;
  }
}

function isPlainObject(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

// ---------------------------------------------------------------------------
// Respuestas y CORS
// ---------------------------------------------------------------------------

function corsHeaders(origin: string | null): Headers {
  const h = new Headers({ Vary: "Origin" });
  if (origin !== null) {
    h.set("Access-Control-Allow-Origin", origin);
    h.set("Access-Control-Expose-Headers", "Retry-After");
  }
  return h;
}

function withHeaders(base: Headers, extra?: HeadersInit): Headers {
  const h = new Headers(base);
  if (extra) new Headers(extra).forEach((v, k) => h.set(k, v));
  return h;
}

function errorResponse(
  cors: Headers,
  status: number,
  code: string,
  message: string,
  extra?: HeadersInit,
): Response {
  const headers = withHeaders(cors, extra);
  headers.set("Content-Type", "application/json; charset=utf-8");
  return new Response(JSON.stringify({ error: { code, message } }), { status, headers });
}

function jsonResponse(cors: Headers, body: unknown): Response {
  const headers = withHeaders(cors, { "Content-Type": "application/json; charset=utf-8" });
  return new Response(JSON.stringify(body), { status: 200, headers });
}

// ---------------------------------------------------------------------------
// Límites
// ---------------------------------------------------------------------------

/**
 * Comprueba y suma el contador del dispositivo (por ruta) y el de la IP
 * (ambas rutas). Devuelve una respuesta 429 si alguno ya llegó a su tope.
 *
 * KV no es atómico: con ráfagas concurrentes el contador puede quedarse algo
 * corto. Para un límite anti-abuso de este tamaño basta.
 */
async function rateLimit(
  env: Env,
  cors: Headers,
  kind: Kind,
  deviceId: string,
  ip: string,
): Promise<Response | null> {
  const now = new Date();
  const day = utcDay(now);
  const deviceLimit = kind === "gemini" ? limit(env.DAILY_LIMIT, DEFAULTS.gemini) : limit(env.TTS_DAILY_LIMIT, DEFAULTS.tts);
  const ipLimit = limit(env.IP_DAILY_LIMIT, DEFAULTS.ip);

  const deviceKey = `d:${kind}:${day}:${deviceId}`;
  const ipKey = `ip:${day}:${(await sha256Hex(ip)).slice(0, 32)}`;

  const [deviceRaw, ipRaw] = await Promise.all([env.RATE.get(deviceKey), env.RATE.get(ipKey)]);
  const deviceCount = Number(deviceRaw ?? 0) || 0;
  const ipCount = Number(ipRaw ?? 0) || 0;

  if (deviceCount >= deviceLimit || ipCount >= ipLimit) {
    const what = kind === "gemini" ? "escaneos" : "lecturas en voz";
    const message =
      deviceCount >= deviceLimit
        ? `Llegaste al límite diario de ${what} (${deviceLimit}). Se reinicia a medianoche UTC.`
        : `Se alcanzó el límite diario de peticiones desde tu red (${ipLimit}). Se reinicia a medianoche UTC.`;
    return errorResponse(cors, 429, "rate_limited", message, {
      "Retry-After": String(secondsUntilUtcMidnight(now)),
    });
  }

  await Promise.all([
    env.RATE.put(deviceKey, String(deviceCount + 1), { expirationTtl: COUNTER_TTL_SECONDS }),
    env.RATE.put(ipKey, String(ipCount + 1), { expirationTtl: COUNTER_TTL_SECONDS }),
  ]);
  return null;
}

// ---------------------------------------------------------------------------
// Rutas
// ---------------------------------------------------------------------------

function health(env: Env, cors: Headers): Response {
  return jsonResponse(cors, {
    ok: true,
    gemini: hasSecret(env.GEMINI_API_KEY),
    fish: hasSecret(env.FISH_API_KEY),
    models: list(env.GEMINI_MODELS, DEFAULT_MODELS),
  });
}

/** Devuelve el nombre del campo prohibido, o null si el cuerpo es aceptable. */
export function forbiddenGeminiField(body: Record<string, unknown>): string | null {
  for (const key of Object.keys(body)) {
    if (!ALLOWED_GEMINI_FIELDS.has(key)) return key;
  }
  // Una sola respuesta por petición: varias candidatas multiplican el costo.
  for (const cfgKey of ["generationConfig", "generation_config"]) {
    const cfg = body[cfgKey];
    if (cfg === undefined) continue;
    if (!isPlainObject(cfg)) return cfgKey;
    for (const countKey of ["candidateCount", "candidate_count"]) {
      const n = cfg[countKey];
      if (n !== undefined && n !== 1) return `${cfgKey}.${countKey}`;
    }
  }
  const tools = body.tools;
  if (tools === undefined) return null;
  if (!Array.isArray(tools)) return "tools";
  for (const tool of tools) {
    if (!isPlainObject(tool)) return "tools";
    for (const key of Object.keys(tool)) {
      if (!ALLOWED_TOOL_FIELDS.has(key)) return `tools.${key}`;
    }
  }
  return null;
}

async function gemini(
  request: Request,
  env: Env,
  cors: Headers,
  rawModel: string,
  deviceId: string,
  ip: string,
): Promise<Response> {
  let model: string;
  try {
    model = decodeURIComponent(rawModel);
  } catch {
    model = rawModel;
  }
  const models = list(env.GEMINI_MODELS, DEFAULT_MODELS);
  if (!models.includes(model)) {
    return errorResponse(cors, 400, "model_not_allowed", `El modelo «${model}» no está permitido. Usa: ${models.join(", ")}.`);
  }
  if (!hasSecret(env.GEMINI_API_KEY)) {
    return errorResponse(cors, 503, "not_configured", "El escaneo con Gemini no está configurado en este servidor.");
  }

  const bytes = await readLimited(request, MAX_GEMINI_BODY);
  if (bytes === null) {
    return errorResponse(cors, 413, "too_large", "La petición supera los 6 MB. Reduce el tamaño de la foto.");
  }
  const body = parseJson(bytes);
  if (!isPlainObject(body)) {
    return errorResponse(cors, 400, "bad_json", "El cuerpo debe ser un objeto JSON de generateContent.");
  }
  const forbidden = forbiddenGeminiField(body);
  if (forbidden !== null) {
    return errorResponse(cors, 400, "field_not_allowed", `El campo «${forbidden}» no está permitido en este servidor.`);
  }

  const limited = await rateLimit(env, cors, "gemini", deviceId, ip);
  if (limited) return limited;

  let upstream: Response;
  try {
    upstream = await fetch(`${GEMINI_BASE}/${encodeURIComponent(model)}:generateContent`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": env.GEMINI_API_KEY },
      body: bytes,
    });
  } catch {
    return errorResponse(cors, 502, "upstream_error", "No se pudo contactar con Gemini. Inténtalo de nuevo.");
  }

  // Solo se copian el tipo de contenido y el cuerpo: ninguna cabecera de Google.
  const headers = withHeaders(cors, {
    "Content-Type": upstream.headers.get("Content-Type") ?? "application/json; charset=utf-8",
  });
  return new Response(upstream.body, { status: upstream.status, headers });
}

async function tts(request: Request, env: Env, cors: Headers, deviceId: string, ip: string): Promise<Response> {
  const bytes = await readLimited(request, MAX_TTS_BODY);
  if (bytes === null) {
    return errorResponse(cors, 413, "too_large", "La petición de voz es demasiado grande.");
  }
  const body = parseJson(bytes);
  const text = isPlainObject(body) ? body.text : undefined;
  const length = typeof text === "string" ? [...text.trim()].length : 0;
  if (typeof text !== "string" || length < 1 || length > MAX_TTS_CHARS) {
    return errorResponse(cors, 400, "bad_text", `El texto debe tener entre 1 y ${MAX_TTS_CHARS} caracteres.`);
  }
  if (!hasSecret(env.FISH_API_KEY)) {
    return errorResponse(cors, 503, "not_configured", "La voz con Fish Audio no está configurada en este servidor.");
  }

  const limited = await rateLimit(env, cors, "tts", deviceId, ip);
  if (limited) return limited;

  const payload: Record<string, unknown> = { text: text.trim(), format: "mp3", mp3_bitrate: 128 };
  if (hasSecret(env.FISH_VOICE_ID)) payload.reference_id = env.FISH_VOICE_ID.trim();

  let upstream: Response;
  try {
    upstream = await fetch(FISH_TTS_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${env.FISH_API_KEY}`,
        "Content-Type": "application/json",
        model: env.FISH_MODEL?.trim() || DEFAULT_FISH_MODEL,
      },
      body: JSON.stringify(payload),
    });
  } catch {
    return errorResponse(cors, 502, "upstream_error", "No se pudo contactar con Fish Audio. Inténtalo de nuevo.");
  }

  if (!upstream.ok) {
    // No se reenvía el cuerpo de Fish: la app espera audio o nuestro formato de error.
    await upstream.body?.cancel();
    return errorResponse(cors, 502, "upstream_error", `Fish Audio respondió con un error (${upstream.status}).`);
  }

  const headers = withHeaders(cors, { "Content-Type": "audio/mpeg", "Cache-Control": "no-store" });
  return new Response(upstream.body, { status: 200, headers });
}

// ---------------------------------------------------------------------------
// Entrada
// ---------------------------------------------------------------------------

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const origin = request.headers.get("Origin");
    const origins = list(env.ALLOWED_ORIGINS, DEFAULT_ORIGINS);

    // Sin Origin (apps nativas, curl) siempre pasa; con Origin tiene que estar en la lista.
    if (origin !== null && !origins.includes(origin)) {
      return errorResponse(new Headers({ Vary: "Origin" }), 403, "origin_not_allowed", "Este origen no puede usar el servidor.");
    }
    const cors = corsHeaders(origin);

    if (request.method === "OPTIONS") {
      const headers = withHeaders(cors, {
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, X-Device-Id",
        "Access-Control-Max-Age": "86400",
      });
      return new Response(null, { status: 204, headers });
    }

    const path = url.pathname;
    const geminiMatch = GEMINI_ROUTE.exec(path);
    const known = path === "/v1/health" || path === "/v1/tts" || geminiMatch !== null;
    if (!known) {
      return errorResponse(cors, 404, "not_found", "Ruta no encontrada.");
    }

    if (path === "/v1/health") {
      if (request.method !== "GET") return errorResponse(cors, 405, "method_not_allowed", "Usa GET.", { Allow: "GET" });
      return health(env, cors);
    }
    if (request.method !== "POST") {
      return errorResponse(cors, 405, "method_not_allowed", "Usa POST.", { Allow: "POST" });
    }

    const deviceId = request.headers.get("X-Device-Id")?.trim() ?? "";
    if (!UUID_V4.test(deviceId)) {
      return errorResponse(cors, 400, "bad_device", "Falta la cabecera X-Device-Id o no es un UUID v4 válido.");
    }
    const device = deviceId.toLowerCase();
    const ip = request.headers.get("CF-Connecting-IP") ?? "unknown";

    if (geminiMatch !== null) return gemini(request, env, cors, geminiMatch[1] ?? "", device, ip);
    return tts(request, env, cors, device, ip);
  },
} satisfies ExportedHandler<Env>;
