import { env as bindings, exports as workerExports } from "cloudflare:workers";
import { afterEach, beforeEach, describe, expect, it, type MockInstance, vi } from "vitest";
import worker, { FISH_TTS_URL, GEMINI_BASE, MAX_GEMINI_BODY, secondsUntilUtcMidnight, type Env } from "../src/handler";
import * as entry from "../src/index";

// Claves falsas: nunca se llama a las APIs reales.
const GEMINI_KEY = "test-gemini-key-000";
const FISH_KEY = "test-fish-key-000";
const BASE = "https://server.test";

function makeEnv(overrides: Partial<Env> = {}): Env {
  return {
    RATE: (bindings as unknown as Env).RATE,
    GEMINI_API_KEY: GEMINI_KEY,
    FISH_API_KEY: FISH_KEY,
    GEMINI_MODELS: "gemini-2.5-flash",
    DAILY_LIMIT: "60",
    TTS_DAILY_LIMIT: "40",
    IP_DAILY_LIMIT: "300",
    ALLOWED_ORIGINS: "https://itzjk.github.io,http://localhost:8765",
    FISH_MODEL: "s2.1-pro",
    ...overrides,
  };
}

let ipCounter = 0;
function freshIp(): string {
  ipCounter += 1;
  return `10.0.${Math.floor(ipCounter / 250)}.${ipCounter % 250}`;
}

interface Opts {
  method?: string;
  device?: string | null;
  origin?: string;
  ip?: string;
  body?: BodyInit | null;
  headers?: Record<string, string>;
}

function req(path: string, opts: Opts = {}): Request {
  const headers = new Headers(opts.headers);
  const device = opts.device === undefined ? crypto.randomUUID() : opts.device;
  if (device !== null) headers.set("X-Device-Id", device);
  if (opts.origin) headers.set("Origin", opts.origin);
  headers.set("CF-Connecting-IP", opts.ip ?? freshIp());
  if (opts.body !== undefined && opts.body !== null && !headers.has("Content-Type")) {
    headers.set("Content-Type", "application/json");
  }
  return new Request(`${BASE}${path}`, {
    method: opts.method ?? (opts.body !== undefined ? "POST" : "GET"),
    headers,
    body: opts.body ?? null,
  });
}

const GEMINI_PATH = "/v1/gemini/gemini-2.5-flash:generateContent";
const okGeminiBody = {
  contents: [{ role: "user", parts: [{ text: "¿Qué hay en este plato?" }, { inlineData: { mimeType: "image/jpeg", data: "AAAA" } }] }],
  systemInstruction: { parts: [{ text: "Eres un nutricionista." }] },
  generationConfig: { responseMimeType: "application/json" },
  tools: [{ functionDeclarations: [{ name: "log_meal", parameters: { type: "object" } }] }],
  toolConfig: { functionCallingConfig: { mode: "AUTO" } },
  safetySettings: [],
};

let fetchSpy: MockInstance<typeof fetch>;

beforeEach(() => {
  fetchSpy = vi.spyOn(globalThis, "fetch").mockImplementation(async (input) => {
    throw new Error(`Llamada de red no esperada: ${String(input instanceof Request ? input.url : input)}`);
  });
});

afterEach(() => {
  vi.restoreAllMocks();
});

function mockGemini(status = 200, payload: unknown = { candidates: [{ content: { parts: [{ text: "{}" }] } }] }) {
  fetchSpy.mockImplementation(async () =>
    new Response(JSON.stringify(payload), {
      status,
      headers: { "Content-Type": "application/json; charset=UTF-8", "x-goog-api-key": "eco-que-no-debe-salir", "X-Google-Internal": "1" },
    }),
  );
}

function mockFish(status = 200) {
  fetchSpy.mockImplementation(async () =>
    status === 200
      ? new Response(new Uint8Array([0x49, 0x44, 0x33, 0x04]), { status: 200 })
      : new Response(JSON.stringify({ status, message: "fallo" }), { status, headers: { "Content-Type": "application/json" } }),
  );
}

async function errorCode(res: Response): Promise<string | undefined> {
  const json = (await res.json()) as { error?: { code?: string } };
  return json.error?.code;
}

// ---------------------------------------------------------------------------

describe("X-Device-Id", () => {
  it("rechaza peticiones sin la cabecera", async () => {
    const res = await worker.fetch(req(GEMINI_PATH, { device: null, body: JSON.stringify(okGeminiBody) }), makeEnv());
    expect(res.status).toBe(400);
    expect(await errorCode(res)).toBe("bad_device");
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it("rechaza ids que no son UUID v4", async () => {
    for (const bad of ["abc", "00000000-0000-0000-0000-000000000000", "6ba7b810-9dad-11d1-80b4-00c04fd430c8"]) {
      const res = await worker.fetch(req("/v1/tts", { device: bad, body: JSON.stringify({ text: "hola" }) }), makeEnv());
      expect(res.status).toBe(400);
      expect(await errorCode(res)).toBe("bad_device");
    }
    expect(fetchSpy).not.toHaveBeenCalled();
  });
});

describe("health", () => {
  it("responde sin X-Device-Id y no cuenta para límites", async () => {
    const ip = freshIp();
    const env = makeEnv({ IP_DAILY_LIMIT: "1", GEMINI_MODELS: "gemini-2.5-flash, gemini-3.6-flash" });
    for (let i = 0; i < 3; i++) {
      const res = await worker.fetch(req("/v1/health", { device: null, ip }), env);
      expect(res.status).toBe(200);
      expect(await res.json()).toEqual({ ok: true, gemini: true, fish: true, models: ["gemini-2.5-flash", "gemini-3.6-flash"] });
    }
    // Health no consumió el cupo de la IP: la primera petición real pasa.
    mockGemini();
    const res = await worker.fetch(req(GEMINI_PATH, { ip, body: JSON.stringify(okGeminiBody) }), env);
    expect(res.status).toBe(200);
  });

  it("indica qué secretos faltan y usa el modelo por defecto", async () => {
    const env = makeEnv({ GEMINI_API_KEY: undefined, FISH_API_KEY: "", GEMINI_MODELS: undefined });
    const res = await worker.fetch(req("/v1/health", { device: null }), env);
    expect(await res.json()).toEqual({ ok: true, gemini: false, fish: false, models: ["gemini-3.6-flash"] });
  });
});

describe("POST /v1/gemini/{model}:generateContent", () => {
  it("reenvía a Google con x-goog-api-key y devuelve status y JSON sin cambios", async () => {
    const payload = { candidates: [{ content: { parts: [{ text: '{"kcal":520}' }] } }], usageMetadata: { totalTokenCount: 9 } };
    mockGemini(200, payload);
    const body = JSON.stringify(okGeminiBody);
    const res = await worker.fetch(req(GEMINI_PATH, { body }), makeEnv());

    expect(res.status).toBe(200);
    expect(await res.json()).toEqual(payload);
    expect(res.headers.get("x-goog-api-key")).toBeNull();
    expect(res.headers.get("X-Google-Internal")).toBeNull();
    expect(res.headers.get("Content-Type")).toContain("application/json");

    expect(fetchSpy).toHaveBeenCalledTimes(1);
    const [url, init] = fetchSpy.mock.calls[0]!;
    expect(url).toBe(`${GEMINI_BASE}/gemini-2.5-flash:generateContent`);
    expect(url).toBe("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent");
    const headers = new Headers(init?.headers);
    expect(headers.get("x-goog-api-key")).toBe(GEMINI_KEY);
    expect(init?.method).toBe("POST");
    expect(new TextDecoder().decode(init?.body as Uint8Array)).toBe(body);
  });

  it("pasa los errores de Google con su status", async () => {
    mockGemini(429, { error: { code: 429, message: "Resource exhausted", status: "RESOURCE_EXHAUSTED" } });
    const res = await worker.fetch(req(GEMINI_PATH, { body: JSON.stringify(okGeminiBody) }), makeEnv());
    expect(res.status).toBe(429);
    expect(((await res.json()) as { error: { status: string } }).error.status).toBe("RESOURCE_EXHAUSTED");
  });

  it("acepta llaves en snake_case", async () => {
    mockGemini();
    const body = { contents: [], system_instruction: { parts: [] }, generation_config: {}, tool_config: {}, safety_settings: [] };
    const res = await worker.fetch(req(GEMINI_PATH, { body: JSON.stringify(body) }), makeEnv());
    expect(res.status).toBe(200);
  });

  it("rechaza modelos fuera de GEMINI_MODELS", async () => {
    for (const model of ["gemini-2.5-pro", "gemini-2.5-flash%2F..%2Fx", "models%2Fgemini-2.5-flash"]) {
      const res = await worker.fetch(req(`/v1/gemini/${model}:generateContent`, { body: JSON.stringify(okGeminiBody) }), makeEnv());
      expect(res.status).toBe(400);
      expect(await errorCode(res)).toBe("model_not_allowed");
    }
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it("rechaza campos de primer nivel no permitidos", async () => {
    for (const extra of [{ cachedContent: "cachedContents/x" }, { labels: {} }]) {
      const res = await worker.fetch(req(GEMINI_PATH, { body: JSON.stringify({ ...okGeminiBody, ...extra }) }), makeEnv());
      expect(res.status).toBe(400);
      expect(await errorCode(res)).toBe("field_not_allowed");
    }
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it("rechaza herramientas de servidor (googleSearch, codeExecution, urlContext)", async () => {
    for (const tool of [{ googleSearch: {} }, { codeExecution: {} }, { urlContext: {} }, { google_search: {} }]) {
      const body = { contents: [], tools: [{ functionDeclarations: [] }, tool] };
      const res = await worker.fetch(req(GEMINI_PATH, { body: JSON.stringify(body) }), makeEnv());
      expect(res.status).toBe(400);
      expect(await errorCode(res)).toBe("field_not_allowed");
    }
    const notArray = await worker.fetch(req(GEMINI_PATH, { body: JSON.stringify({ tools: { googleSearch: {} } }) }), makeEnv());
    expect(await errorCode(notArray)).toBe("field_not_allowed");
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it("solo permite una candidata por petición", async () => {
    for (const cfg of [{ generationConfig: { candidateCount: 4 } }, { generation_config: { candidate_count: 2 } }]) {
      const res = await worker.fetch(req(GEMINI_PATH, { body: JSON.stringify({ contents: [], ...cfg }) }), makeEnv());
      expect(res.status).toBe(400);
      expect(await errorCode(res)).toBe("field_not_allowed");
    }
    mockGemini(200, { candidates: [] });
    const one = await worker.fetch(
      req(GEMINI_PATH, { body: JSON.stringify({ contents: [], generationConfig: { candidateCount: 1, temperature: 0.2 } }) }),
      makeEnv(),
    );
    expect(one.status).toBe(200);
  });

  it("rechaza JSON inválido", async () => {
    const res = await worker.fetch(req(GEMINI_PATH, { body: "no es json" }), makeEnv());
    expect(res.status).toBe(400);
    expect(await errorCode(res)).toBe("bad_json");
  });

  it("rechaza cuerpos de más de 6 MB con 413", async () => {
    const big = JSON.stringify({ contents: [{ parts: [{ inlineData: { mimeType: "image/jpeg", data: "A".repeat(MAX_GEMINI_BODY) } }] }] });
    const res = await worker.fetch(req(GEMINI_PATH, { body: big }), makeEnv());
    expect(res.status).toBe(413);
    expect(await errorCode(res)).toBe("too_large");
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it("rechaza por Content-Length declarado sin leer el cuerpo", async () => {
    const res = await worker.fetch(
      req(GEMINI_PATH, { body: "{}", headers: { "Content-Length": String(MAX_GEMINI_BODY + 1) } }),
      makeEnv(),
    );
    expect(res.status).toBe(413);
  });

  it("devuelve 503 not_configured si falta GEMINI_API_KEY", async () => {
    const res = await worker.fetch(req(GEMINI_PATH, { body: JSON.stringify(okGeminiBody) }), makeEnv({ GEMINI_API_KEY: undefined }));
    expect(res.status).toBe(503);
    expect(await errorCode(res)).toBe("not_configured");
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it("devuelve 502 upstream_error si falla la red, sin filtrar la clave", async () => {
    fetchSpy.mockImplementation(async () => {
      throw new Error(`connect ECONNREFUSED key=${GEMINI_KEY}`);
    });
    const res = await worker.fetch(req(GEMINI_PATH, { body: JSON.stringify(okGeminiBody) }), makeEnv());
    expect(res.status).toBe(502);
    const text = await res.text();
    expect(text).toContain("upstream_error");
    expect(text).not.toContain(GEMINI_KEY);
    expect(text).not.toContain("ECONNREFUSED");
  });

  it("rechaza métodos que no son POST", async () => {
    const res = await worker.fetch(req(GEMINI_PATH, { method: "GET" }), makeEnv());
    expect(res.status).toBe(405);
  });
});

describe("límites diarios", () => {
  it("corta por dispositivo con 429 y Retry-After", async () => {
    mockGemini();
    const device = crypto.randomUUID();
    const env = makeEnv({ DAILY_LIMIT: "3" });
    for (let i = 0; i < 3; i++) {
      const ok = await worker.fetch(req(GEMINI_PATH, { device, body: JSON.stringify(okGeminiBody) }), env);
      expect(ok.status).toBe(200);
    }
    const res = await worker.fetch(req(GEMINI_PATH, { device, body: JSON.stringify(okGeminiBody) }), env);
    expect(res.status).toBe(429);
    const json = (await res.json()) as { error: { code: string; message: string } };
    expect(json.error.code).toBe("rate_limited");
    expect(json.error.message).toMatch(/límite diario/);
    const retry = Number(res.headers.get("Retry-After"));
    expect(Number.isInteger(retry)).toBe(true);
    expect(retry).toBeGreaterThan(0);
    expect(retry).toBeLessThanOrEqual(86400);
    expect(retry).toBe(secondsUntilUtcMidnight(new Date()));
    expect(fetchSpy).toHaveBeenCalledTimes(3);

    // El mismo dispositivo aún tiene su cupo de voz aparte.
    mockFish();
    const voice = await worker.fetch(req("/v1/tts", { device, body: JSON.stringify({ text: "hola" }) }), env);
    expect(voice.status).toBe(200);
  });

  it("corta la voz con TTS_DAILY_LIMIT", async () => {
    mockFish();
    const device = crypto.randomUUID();
    const env = makeEnv({ TTS_DAILY_LIMIT: "2" });
    for (let i = 0; i < 2; i++) {
      expect((await worker.fetch(req("/v1/tts", { device, body: JSON.stringify({ text: "uno" }) }), env)).status).toBe(200);
    }
    const res = await worker.fetch(req("/v1/tts", { device, body: JSON.stringify({ text: "uno" }) }), env);
    expect(res.status).toBe(429);
    expect(await errorCode(res)).toBe("rate_limited");
    expect(res.headers.get("Retry-After")).toMatch(/^\d+$/);
  });

  it("corta por IP sumando Gemini y voz aunque cambie el dispositivo", async () => {
    const ip = freshIp();
    const env = makeEnv({ IP_DAILY_LIMIT: "3" });
    mockGemini();
    expect((await worker.fetch(req(GEMINI_PATH, { ip, body: JSON.stringify(okGeminiBody) }), env)).status).toBe(200);
    expect((await worker.fetch(req(GEMINI_PATH, { ip, body: JSON.stringify(okGeminiBody) }), env)).status).toBe(200);
    mockFish();
    expect((await worker.fetch(req("/v1/tts", { ip, body: JSON.stringify({ text: "hola" }) }), env)).status).toBe(200);

    const res = await worker.fetch(req("/v1/tts", { ip, body: JSON.stringify({ text: "hola" }) }), env);
    expect(res.status).toBe(429);
    expect(await errorCode(res)).toBe("rate_limited");
    expect(Number(res.headers.get("Retry-After"))).toBeGreaterThan(0);

    // Otra IP sigue pudiendo.
    expect((await worker.fetch(req("/v1/tts", { body: JSON.stringify({ text: "hola" }) }), env)).status).toBe(200);
  });

  it("no guarda la IP en claro ni contenido del usuario en KV", async () => {
    mockGemini();
    const ip = "203.0.113.77";
    const device = crypto.randomUUID();
    await worker.fetch(req(GEMINI_PATH, { ip, device, body: JSON.stringify(okGeminiBody) }), makeEnv());
    const keys = (await makeEnv().RATE.list()).keys.map((k) => k.name);
    expect(keys.some((k) => k.includes(device))).toBe(true);
    expect(keys.some((k) => k.includes(ip))).toBe(false);
    for (const k of keys) {
      const value = await makeEnv().RATE.get(k);
      expect(value).toMatch(/^\d+$/);
    }
  });

  it("calcula los segundos hasta medianoche UTC", () => {
    expect(secondsUntilUtcMidnight(new Date("2026-11-03T23:59:30Z"))).toBe(30);
    expect(secondsUntilUtcMidnight(new Date("2026-11-03T00:00:00Z"))).toBe(86400);
    expect(secondsUntilUtcMidnight(new Date("2026-12-31T12:00:00.500Z"))).toBe(43200);
  });
});

describe("POST /v1/tts", () => {
  it("llama a Fish Audio y devuelve audio/mpeg", async () => {
    mockFish();
    const res = await worker.fetch(req("/v1/tts", { body: JSON.stringify({ text: "  Buen trabajo, sigue así.  " }) }), makeEnv({ FISH_VOICE_ID: "voz-123" }));
    expect(res.status).toBe(200);
    expect(res.headers.get("Content-Type")).toBe("audio/mpeg");
    expect(new Uint8Array(await res.arrayBuffer())).toEqual(new Uint8Array([0x49, 0x44, 0x33, 0x04]));

    const [url, init] = fetchSpy.mock.calls[0]!;
    expect(url).toBe(FISH_TTS_URL);
    expect(url).toBe("https://api.fish.audio/v1/tts");
    const headers = new Headers(init?.headers);
    expect(headers.get("Authorization")).toBe(`Bearer ${FISH_KEY}`);
    expect(headers.get("Content-Type")).toBe("application/json");
    expect(headers.get("model")).toBe("s2.1-pro");
    expect(JSON.parse(init?.body as string)).toEqual({
      text: "Buen trabajo, sigue así.",
      format: "mp3",
      mp3_bitrate: 128,
      reference_id: "voz-123",
    });
  });

  it("no manda reference_id si no hay FISH_VOICE_ID", async () => {
    mockFish();
    await worker.fetch(req("/v1/tts", { body: JSON.stringify({ text: "hola" }) }), makeEnv());
    const body = JSON.parse(fetchSpy.mock.calls[0]![1]?.body as string) as Record<string, unknown>;
    expect(body).not.toHaveProperty("reference_id");
  });

  it("rechaza texto vacío, ausente, no string o de más de 600 caracteres", async () => {
    const bads = [{}, { text: "" }, { text: "   " }, { text: 42 }, { text: "a".repeat(601) }, "hola"];
    for (const bad of bads) {
      const res = await worker.fetch(req("/v1/tts", { body: JSON.stringify(bad) }), makeEnv());
      expect(res.status).toBe(400);
      expect(await errorCode(res)).toBe("bad_text");
    }
    const notJson = await worker.fetch(req("/v1/tts", { body: "{" }), makeEnv());
    expect(await errorCode(notJson)).toBe("bad_text");
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it("acepta exactamente 600 caracteres (incluidos acentos y emoji)", async () => {
    mockFish();
    const text = "á".repeat(599) + "💪";
    const res = await worker.fetch(req("/v1/tts", { body: JSON.stringify({ text }) }), makeEnv());
    expect(res.status).toBe(200);
  });

  it("devuelve 503 not_configured si falta FISH_API_KEY", async () => {
    const res = await worker.fetch(req("/v1/tts", { body: JSON.stringify({ text: "hola" }) }), makeEnv({ FISH_API_KEY: undefined }));
    expect(res.status).toBe(503);
    expect(await errorCode(res)).toBe("not_configured");
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it("devuelve 502 si Fish falla por red o responde con error", async () => {
    fetchSpy.mockImplementation(async () => {
      throw new TypeError("network down");
    });
    const down = await worker.fetch(req("/v1/tts", { body: JSON.stringify({ text: "hola" }) }), makeEnv());
    expect(down.status).toBe(502);
    expect(await errorCode(down)).toBe("upstream_error");

    mockFish(402);
    const paid = await worker.fetch(req("/v1/tts", { body: JSON.stringify({ text: "hola" }) }), makeEnv());
    expect(paid.status).toBe(502);
    const text = await paid.text();
    expect(text).toContain("upstream_error");
    expect(text).not.toContain(FISH_KEY);
  });
});

describe("CORS", () => {
  it("permite orígenes de ALLOWED_ORIGINS y responde al preflight", async () => {
    const pre = await worker.fetch(
      req("/v1/tts", {
        method: "OPTIONS",
        device: null,
        origin: "https://itzjk.github.io",
        headers: { "Access-Control-Request-Method": "POST", "Access-Control-Request-Headers": "content-type,x-device-id" },
      }),
      makeEnv(),
    );
    expect(pre.status).toBe(204);
    expect(pre.headers.get("Access-Control-Allow-Origin")).toBe("https://itzjk.github.io");
    expect(pre.headers.get("Access-Control-Allow-Methods")).toContain("POST");
    const allowed = (pre.headers.get("Access-Control-Allow-Headers") ?? "").toLowerCase();
    expect(allowed).toContain("content-type");
    expect(allowed).toContain("x-device-id");

    mockFish();
    const res = await worker.fetch(req("/v1/tts", { origin: "http://localhost:8765", body: JSON.stringify({ text: "hola" }) }), makeEnv());
    expect(res.status).toBe(200);
    expect(res.headers.get("Access-Control-Allow-Origin")).toBe("http://localhost:8765");
    expect(res.headers.get("Access-Control-Expose-Headers")).toContain("Retry-After");
  });

  it("incluye CORS también en los errores", async () => {
    const res = await worker.fetch(req(GEMINI_PATH, { origin: "https://itzjk.github.io", device: null, body: "{}" }), makeEnv());
    expect(res.status).toBe(400);
    expect(res.headers.get("Access-Control-Allow-Origin")).toBe("https://itzjk.github.io");
  });

  it("niega orígenes que no están en la lista con 403", async () => {
    for (const method of ["OPTIONS", "POST"]) {
      const res = await worker.fetch(
        req("/v1/tts", { method, origin: "https://evil.example", body: method === "POST" ? JSON.stringify({ text: "hola" }) : null }),
        makeEnv(),
      );
      expect(res.status).toBe(403);
      expect(res.headers.get("Access-Control-Allow-Origin")).toBeNull();
    }
    const health = await worker.fetch(req("/v1/health", { device: null, origin: "null" }), makeEnv());
    expect(health.status).toBe(403);
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it("deja pasar peticiones sin Origin (apps nativas) sin cabeceras CORS", async () => {
    mockFish();
    const res = await worker.fetch(req("/v1/tts", { body: JSON.stringify({ text: "hola" }) }), makeEnv());
    expect(res.status).toBe(200);
    expect(res.headers.get("Access-Control-Allow-Origin")).toBeNull();
  });
});

describe("rutas desconocidas", () => {
  it("devuelve 404", async () => {
    const res = await worker.fetch(req("/v1/otra", { method: "POST", body: "{}" }), makeEnv());
    expect(res.status).toBe(404);
    expect(await errorCode(res)).toBe("not_found");
  });
});

describe("integración con el binding real", () => {
  it("el Worker se carga con la configuración de wrangler.toml", async () => {
    const res = await worker.fetch(req("/v1/health", { device: null }), bindings as unknown as Env);
    expect(res.status).toBe(200);
    const json = (await res.json()) as { ok: boolean; models: string[]; gemini: boolean; fish: boolean };
    expect(json.ok).toBe(true);
    expect(json.models).toContain("gemini-3.6-flash");
    // En las pruebas no hay secretos.
    expect(json.gemini).toBe(false);
    expect(json.fish).toBe(false);
  });
});

describe("punto de entrada", () => {
  it("solo exporta el handler por defecto (workerd trata las demás exportaciones como entrypoints)", () => {
    expect(Object.keys(entry)).toEqual(["default"]);
  });

  it("el Worker principal responde de verdad a través de su binding", async () => {
    const res = await (workerExports as unknown as { default: Fetcher }).default.fetch("https://server.test/v1/health");
    expect(res.status).toBe(200);
    expect(((await res.json()) as { ok: boolean }).ok).toBe(true);
  });
});
