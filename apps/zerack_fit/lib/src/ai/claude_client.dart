import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

/// Nombre del asistente en la app. Un solo lugar para cambiarlo.
const assistantName = 'ZERACK IA';

/// Configuración de acceso a la API de Claude.
///
/// La app es open source, así que **no lleva ninguna clave dentro**. Hay dos
/// modos:
/// - API directa: la persona pega su propia clave de Anthropic.
/// - Servidor intermedio: `baseUrl` apunta a un proxy del operador que agrega
///   la clave del lado del servidor y habla el mismo formato de la API.
class ClaudeConfig {
  const ClaudeConfig({this.apiKey, String? baseUrl, this.model = defaultModel})
    : baseUrl = baseUrl ?? anthropicBaseUrl;

  static const anthropicBaseUrl = 'https://api.anthropic.com';
  static const defaultModel = 'claude-opus-5-5';

  final String? apiKey;
  final String baseUrl;
  final String model;

  bool get isDirect => baseUrl == anthropicBaseUrl;

  /// Hay forma de autenticarse: clave propia o proxy.
  bool get isUsable => !isDirect || (apiKey?.isNotEmpty ?? false);
}

sealed class ClaudeException implements Exception {
  const ClaudeException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class ClaudeAuthError extends ClaudeException {
  const ClaudeAuthError(super.message);
}

class ClaudeRateLimited extends ClaudeException {
  const ClaudeRateLimited(super.message);
}

class ClaudeUnavailable extends ClaudeException {
  const ClaudeUnavailable(super.message);
}

class ClaudeBadRequest extends ClaudeException {
  const ClaudeBadRequest(super.message);
}

class ClaudeNetworkError extends ClaudeException {
  const ClaudeNetworkError(super.message);
}

/// El modelo declinó la solicitud (`stop_reason: refusal`).
class ClaudeRefusal extends ClaudeException {
  const ClaudeRefusal(super.message);
}

/// Respuesta de `POST /v1/messages`. `content` se guarda tal cual para
/// devolverlo sin cambios en el siguiente turno (requisito de la API para los
/// bloques de razonamiento).
class ClaudeMessage {
  const ClaudeMessage({required this.content, required this.stopReason});

  final List<Map<String, Object?>> content;
  final String? stopReason;

  String get text => [
    for (final b in content)
      if (b['type'] == 'text') b['text'] as String,
  ].join();

  List<Map<String, Object?>> get toolUses => [
    for (final b in content)
      if (b['type'] == 'tool_use') b,
  ];
}

/// Cliente HTTP mínimo para la API de Mensajes. Dart no tiene SDK oficial de
/// Anthropic, por eso se usa la API REST documentada.
class ClaudeClient {
  ClaudeClient({
    required http.Client httpClient,
    required this.config,
    this.timeout = const Duration(seconds: 120),
    this.maxRetries = 2,
    bool? browser,
    Future<void> Function(Duration)? sleep,
  }) : _http = httpClient,
       browser = browser ?? kIsWeb,
       _sleep = sleep ?? Future<void>.delayed;

  final http.Client _http;
  final ClaudeConfig config;
  final Duration timeout;
  final int maxRetries;

  /// Corre en un navegador (versión web). La API directa exige una cabecera
  /// explícita para aceptar llamadas desde el navegador (CORS).
  final bool browser;
  final Future<void> Function(Duration) _sleep;

  static const apiVersion = '2023-06-01';
  static const fallbackBeta = 'server-side-fallback-2026-07-01';

  Future<ClaudeMessage> create({
    required String system,
    required List<Map<String, Object?>> messages,
    List<Map<String, Object?>>? tools,
    Map<String, Object?>? outputFormat,
    String effort = 'medium',
    int maxTokens = 16000,
  }) async {
    if (!config.isUsable) {
      throw const ClaudeAuthError('Falta la clave de la API');
    }
    final body = <String, Object?>{
      'model': config.model,
      'max_tokens': maxTokens,
      // El prompt de sistema es estable: se cachea para abaratar los turnos.
      'system': [
        {
          'type': 'text',
          'text': system,
          'cache_control': {'type': 'ephemeral'},
        },
      ],
      'messages': messages,
      'tools': ?tools,
      'output_config': {'effort': effort, 'format': ?outputFormat},
      // Si los filtros de seguridad declinan, la API reintenta con el modelo
      // de respaldo recomendado. Solo en la API directa: un proxy podría no
      // aceptar el campo.
      if (config.isDirect) 'fallbacks': 'default',
    };
    final headers = {
      'content-type': 'application/json',
      'anthropic-version': apiVersion,
      if (config.apiKey?.isNotEmpty ?? false) 'x-api-key': config.apiKey!,
      if (config.isDirect) 'anthropic-beta': fallbackBeta,
      if (config.isDirect && browser)
        'anthropic-dangerous-direct-browser-access': 'true',
    };
    final uri = Uri.parse('${config.baseUrl}/v1/messages');

    for (var attempt = 0; ; attempt++) {
      final http.Response res;
      try {
        res = await _http
            .post(uri, headers: headers, body: jsonEncode(body))
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
      final retryable = code == 429 || code == 408 || code >= 500;
      if (retryable && attempt < maxRetries) {
        await _sleep(_retryAfter(res) ?? _backoff(attempt));
        continue;
      }
      final message = _errorMessage(res.body);
      throw switch (code) {
        401 || 403 => ClaudeAuthError(message),
        429 => ClaudeRateLimited(message),
        400 || 404 || 413 || 422 => ClaudeBadRequest(message),
        _ => ClaudeUnavailable(message),
      };
    }
  }

  static Duration _backoff(int attempt) =>
      Duration(milliseconds: 800 * (1 << attempt));

  static Duration? _retryAfter(http.Response res) {
    final s = int.tryParse(res.headers['retry-after'] ?? '');
    return s == null ? null : Duration(seconds: s.clamp(1, 30));
  }

  static String _errorMessage(String body) {
    try {
      final j = jsonDecode(body) as Map<String, Object?>;
      final e = j['error'] as Map<String, Object?>?;
      return (e?['message'] as String?) ?? body;
    } on Object {
      return body.isEmpty ? 'Error de la API' : body;
    }
  }

  static ClaudeMessage _parse(String body) {
    final j = jsonDecode(body) as Map<String, Object?>;
    final stop = j['stop_reason'] as String?;
    if (stop == 'refusal') {
      throw const ClaudeRefusal('La IA no pudo responder a esta solicitud');
    }
    return ClaudeMessage(
      content: (j['content'] as List<Object?>).cast<Map<String, Object?>>(),
      stopReason: stop,
    );
  }
}

/// Mensaje en español para cada error, para mostrar en la UI.
String describeClaudeError(Object e) => switch (e) {
  ClaudeAuthError() =>
    'La clave de la IA no es válida o falta. Revísala en Perfil → IA.',
  ClaudeRateLimited() => 'La IA está saturada. Intenta en un minuto.',
  ClaudeUnavailable() => 'La IA no está disponible ahora. Intenta más tarde.',
  ClaudeNetworkError() => 'No hay conexión a internet.',
  ClaudeRefusal() => 'La IA no pudo ayudar con esto.',
  ClaudeBadRequest(:final message) => 'Solicitud inválida: $message',
  _ => 'Algo salió mal: $e',
};
