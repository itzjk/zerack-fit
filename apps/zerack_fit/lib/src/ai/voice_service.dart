import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'claude_client.dart'
    show ClaudeNetworkError, ClaudeRateLimited, ClaudeUnavailable;

/// Convierte texto en voz con Fish Audio a través del servidor de ZERACK.
class VoiceService {
  VoiceService({
    required this.httpClient,
    required this.serverUrl,
    required this.deviceId,
  });

  final http.Client httpClient;
  final String serverUrl;
  final String deviceId;

  /// Límite del servidor por petición.
  static const maxChars = 600;

  /// Quita marcas de formato y recorta a frases completas.
  static String speakable(String text) {
    var t = text
        .replaceAll(RegExp(r'[*_#`>]+'), '')
        .replaceAll(RegExp(r'\[(.*?)\]\((.*?)\)'), r'$1')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (t.length <= maxChars) return t;
    t = t.substring(0, maxChars);
    final cut = t.lastIndexOf(RegExp(r'[.!?…]'));
    return cut > maxChars ~/ 2 ? t.substring(0, cut + 1) : t;
  }

  /// MP3 con la voz. Lanza las mismas excepciones que el resto de la IA.
  Future<Uint8List> synthesize(String text) async {
    final t = speakable(text);
    if (t.isEmpty) throw ArgumentError.value(text, 'text', 'vacío');
    final http.Response res;
    try {
      res = await httpClient
          .post(
            Uri.parse('$serverUrl/v1/tts'),
            headers: {
              'content-type': 'application/json',
              'x-device-id': deviceId,
            },
            body: jsonEncode({'text': t}),
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const ClaudeNetworkError('La voz tardó demasiado');
    } on http.ClientException catch (e) {
      throw ClaudeNetworkError('Sin conexión: ${e.message}');
    }
    if (res.statusCode == 200) return res.bodyBytes;
    if (res.statusCode == 429) {
      throw const ClaudeRateLimited('Llegaste al límite de voz de hoy');
    }
    throw ClaudeUnavailable('La voz no está disponible (${res.statusCode})');
  }
}
