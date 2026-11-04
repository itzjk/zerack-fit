import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'claude_client.dart'
    show
        ClaudeAuthError,
        ClaudeBadRequest,
        ClaudeNetworkError,
        ClaudeRateLimited,
        ClaudeRefusal,
        ClaudeUnavailable;

/// Modelo de Gemini que usa la app. Un solo lugar para cambiarlo; el servidor
/// de ZERACK debe tenerlo en su lista `GEMINI_MODELS`.
const geminiModel = 'gemini-3.6-flash';

/// Cómo llega la app a Gemini.
sealed class GeminiAccess {
  const GeminiAccess();
}

/// Con la clave propia de la persona, directo a Google.
class GeminiDirect extends GeminiAccess {
  const GeminiDirect(this.apiKey);
  final String apiKey;

  static const baseUrl = 'https://generativelanguage.googleapis.com';
}

/// Por el servidor de ZERACK: la clave vive allá como secreto y la app solo
/// manda su id de dispositivo para el límite diario.
class GeminiViaServer extends GeminiAccess {
  const GeminiViaServer({required this.baseUrl, required this.deviceId});
  final String baseUrl;
  final String deviceId;
}

/// Respuesta de `generateContent`. `content` se guarda tal cual para
/// devolverlo en el siguiente turno (incluye las firmas de razonamiento).
class GeminiResponse {
  const GeminiResponse({required this.content, required this.finishReason});

  final Map<String, Object?> content;
  final String? finishReason;

  List<Map<String, Object?>> get parts =>
      (content['parts'] as List<Object?>? ?? const [])
          .cast<Map<String, Object?>>();

  String get text => [
    for (final p in parts)
      if (p['text'] is String && p['thought'] != true) p['text'] as String,
  ].join();

  List<({String name, Map<String, Object?> args})> get functionCalls => [
    for (final p in parts)
      if (p['functionCall'] case final Map<String, Object?> call)
        (
          name: call['name'] as String,
          args: (call['args'] as Map?)?.cast<String, Object?>() ?? const {},
        ),
  ];
}

class GeminiClient {
  GeminiClient({
    required http.Client httpClient,
    required this.access,
    this.model = geminiModel,
    this.timeout = const Duration(seconds: 90),
    this.maxRetries = 2,
    Future<void> Function(Duration)? sleep,
  }) : _http = httpClient,
       _sleep = sleep ?? Future<void>.delayed;

  final http.Client _http;
  final GeminiAccess access;
  final String model;
  final Duration timeout;
  final int maxRetries;
  final Future<void> Function(Duration) _sleep;

  Uri get _uri => switch (access) {
    GeminiDirect() => Uri.parse(
      '${GeminiDirect.baseUrl}/v1beta/models/$model:generateContent',
    ),
    GeminiViaServer(:final baseUrl) => Uri.parse(
      '$baseUrl/v1/gemini/$model:generateContent',
    ),
  };

  Map<String, String> get _headers => {
    'content-type': 'application/json',
    ...switch (access) {
      GeminiDirect(:final apiKey) => {'x-goog-api-key': apiKey},
      GeminiViaServer(:final deviceId) => {'x-device-id': deviceId},
    },
  };

  Future<GeminiResponse> generate(Map<String, Object?> body) async {
    for (var attempt = 0; ; attempt++) {
      final http.Response res;
      try {
        res = await _http
            .post(_uri, headers: _headers, body: jsonEncode(body))
            .timeout(timeout);
      } on TimeoutException {
        if (attempt < maxRetries) {
          await _sleep(_backoff(attempt));
          continue;
        }
        throw const ClaudeNetworkError('La IA tardó demasiado en responder');
      } on http.ClientException catch (e) {
        if (attempt < maxRetries) {
          await _sleep(_backoff(attempt));
          continue;
        }
        throw ClaudeNetworkError('Sin conexión: ${e.message}');
      }

      final code = res.statusCode;
      if (code == 200) return _parse(res.body);
      final (errCode, message) = _error(res.body);
      // El límite diario del servidor no se arregla reintentando.
      final serverLimit = errCode == 'rate_limited';
      final retryable =
          !serverLimit && (code == 429 || code == 408 || code >= 500);
      if (retryable && attempt < maxRetries) {
        await _sleep(_backoff(attempt));
        continue;
      }
      throw switch (code) {
        _ when _isBadKey(code, message) => ClaudeAuthError(message),
        401 || 403 => ClaudeAuthError(message),
        429 => ClaudeRateLimited(message),
        400 || 404 || 413 => ClaudeBadRequest(message),
        _ => ClaudeUnavailable(message),
      };
    }
  }

  static bool _isBadKey(int code, String message) =>
      code == 400 && message.toLowerCase().contains('api key');

  static Duration _backoff(int attempt) =>
      Duration(milliseconds: 800 * (1 << attempt));

  /// Lee `{"error":{"code","message","status"}}` de Google o del servidor.
  static (String?, String) _error(String body) {
    try {
      final e = (jsonDecode(body) as Map<String, Object?>)['error'] as Map?;
      final code = e?['code'];
      return (code is String ? code : null, (e?['message'] as String?) ?? body);
    } on Object {
      return (null, body.isEmpty ? 'Error de la API' : body);
    }
  }

  static GeminiResponse _parse(String body) {
    final j = jsonDecode(body) as Map<String, Object?>;
    final feedback = j['promptFeedback'] as Map?;
    if (feedback?['blockReason'] != null) {
      throw const ClaudeRefusal('La IA no pudo responder a esta solicitud');
    }
    final candidates = (j['candidates'] as List<Object?>? ?? const []);
    if (candidates.isEmpty) {
      throw const ClaudeUnavailable('La IA no devolvió respuesta');
    }
    final c = candidates.first as Map<String, Object?>;
    final reason = c['finishReason'] as String?;
    if (reason == 'SAFETY' || reason == 'PROHIBITED_CONTENT') {
      throw const ClaudeRefusal('La IA no pudo responder a esta solicitud');
    }
    final content =
        (c['content'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{'role': 'model', 'parts': <Object?>[]};
    return GeminiResponse(content: content, finishReason: reason);
  }
}

/// Convierte un JSON Schema (como el de las herramientas de Claude) al
/// subconjunto OpenAPI que acepta Gemini: tipos en mayúsculas y sin
/// `additionalProperties` ni `strict`.
Map<String, Object?> toGeminiSchema(Map<String, Object?> schema) {
  final out = <String, Object?>{};
  for (final e in schema.entries) {
    switch (e.key) {
      case 'additionalProperties' || 'strict' || r'$schema':
        continue;
      case 'type':
        out['type'] = (e.value as String).toUpperCase();
      case 'properties':
        out['properties'] = {
          for (final p in (e.value as Map).cast<String, Object?>().entries)
            p.key: toGeminiSchema((p.value as Map).cast<String, Object?>()),
        };
      case 'items':
        out['items'] = toGeminiSchema((e.value as Map).cast<String, Object?>());
      default:
        out[e.key] = e.value;
    }
  }
  return out;
}

/// Mira si una clave tiene la forma de una de Google AI Studio.
bool looksLikeGeminiKey(String key) =>
    RegExp(r'^AIza[0-9A-Za-z_\-]{30,}$').hasMatch(key.trim());

/// Mira si una clave tiene la forma de una de Anthropic.
bool looksLikeAnthropicKey(String key) => key.trim().startsWith('sk-ant-');
