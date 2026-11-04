import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_state.dart';
import 'assistant.dart';
import 'backends.dart';
import 'claude_client.dart';
import 'food_scanner.dart';
import 'gemini_client.dart';
import 'voice_service.dart';

/// Guarda secretos fuera del JSON de datos (llavero de iOS / Keystore de
/// Android).
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
}

class SecureSecretStore implements SecretStore {
  const SecureSecretStore([this._storage = const FlutterSecureStorage()]);
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String? value) => value == null
      ? _storage.delete(key: key)
      : _storage.write(key: key, value: value);
}

/// Preferencias locales simples. En la versión web el almacenamiento
/// "seguro" también vive en el navegador, así que no se pierde seguridad.
class PrefsSecretStore implements SecretStore {
  PrefsSecretStore([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();
  final SharedPreferencesAsync _prefs;

  @override
  Future<String?> read(String key) => _prefs.getString('secret.$key');

  @override
  Future<void> write(String key, String? value) => value == null
      ? _prefs.remove('secret.$key')
      : _prefs.setString('secret.$key', value);
}

/// Usa [primary] y, si falla (p. ej. el navegador bloquea WebCrypto en modo
/// privado), cae a [fallback] en lugar de perder la clave.
class FallbackSecretStore implements SecretStore {
  FallbackSecretStore(this.primary, this.fallback);
  final SecretStore primary;
  final SecretStore fallback;

  @override
  Future<String?> read(String key) async {
    try {
      final v = await primary.read(key);
      if (v != null) return v;
    } on Object {
      // Cae al respaldo.
    }
    return fallback.read(key);
  }

  @override
  Future<void> write(String key, String? value) async {
    try {
      await primary.write(key, value);
      // Limpia una copia vieja del respaldo para no leer un valor viejo.
      await fallback.write(key, null);
    } on Object {
      await fallback.write(key, value);
    }
  }
}

class MemorySecretStore implements SecretStore {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String? value) async =>
      value == null ? data.remove(key) : data[key] = value;
}

/// URL del servidor de ZERACK compilada en la app con
/// `--dart-define=ZERACK_SERVER=https://…`. Vacía = sin servidor.
const zerackServerFromBuild = String.fromEnvironment('ZERACK_SERVER');

enum AiProvider { gemini, anthropic, zerackServer }

/// Por dónde va la IA ahora.
class AiRoute {
  const AiRoute(this.provider, {this.key, this.serverUrl});
  final AiProvider provider;
  final String? key;
  final String? serverUrl;

  String get label => switch (provider) {
    AiProvider.gemini => 'Gemini (tu clave)',
    AiProvider.anthropic => 'Claude (tu clave)',
    AiProvider.zerackServer => 'Servidor de ZERACK',
  };
}

/// Resultado de guardar una clave.
enum KeyCheck {
  /// El proveedor la aceptó.
  valid,

  /// Se guardó, pero el proveedor la rechazó (mal copiada o desactivada).
  rejected,

  /// Se guardó; no se pudo comprobar (sin internet).
  unverified,
}

class KeySaveResult {
  const KeySaveResult(this.provider, this.check);
  final AiProvider provider;
  final KeyCheck check;

  String get message {
    final who = provider == AiProvider.gemini ? 'Gemini' : 'Anthropic';
    return switch (check) {
      KeyCheck.valid => 'Clave de $who guardada y verificada.',
      KeyCheck.rejected =>
        'La clave se guardó, pero $who la rechazó. Revisa que esté completa '
            'y activa.',
      KeyCheck.unverified =>
        'Clave de $who guardada. No pude comprobarla porque no hay conexión.',
    };
  }
}

/// La clave no tiene forma de Gemini ni de Anthropic.
class UnknownKeyFormat implements Exception {
  const UnknownKeyFormat();
  String get message =>
      'No reconozco esta clave. Pega una de Gemini (empieza con AIza) o de '
      'Anthropic (empieza con sk-ant-).';
}

/// Punto único para crear el escáner, el agente y la voz con la
/// configuración vigente.
class AiService {
  AiService({
    required this.secrets,
    required this.httpClient,
    this.buildServerUrl = zerackServerFromBuild,
    Random? random,
  }) : _random = random ?? Random.secure();

  static const apiKeyName = 'zerack.ai.apiKey';
  static const geminiKeyName = 'zerack.ai.geminiKey';
  static const deviceIdName = 'zerack.deviceId';

  final SecretStore secrets;
  final http.Client httpClient;
  final String buildServerUrl;
  final Random _random;

  Assistant? _assistant;

  /// Clave de Anthropic (nombre histórico de la llave).
  Future<String?> apiKey() => secrets.read(apiKeyName);
  Future<String?> geminiKey() => secrets.read(geminiKeyName);

  /// Servidor vigente: el de Perfil, si la persona puso uno; si no, el de la
  /// compilación.
  String? serverUrl(AppState state) {
    final custom = state.settings.aiBaseUrl?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    return buildServerUrl.isEmpty ? null : buildServerUrl;
  }

  /// Id aleatorio del dispositivo para el límite diario del servidor. No
  /// identifica a la persona.
  Future<String> deviceId() async {
    final existing = await secrets.read(deviceIdName);
    if (existing != null && existing.isNotEmpty) return existing;
    final b = List<int>.generate(16, (_) => _random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40; // versión 4
    b[8] = (b[8] & 0x3f) | 0x80; // variante
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    final id =
        '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
    await secrets.write(deviceIdName, id);
    return id;
  }

  /// Gemini con clave propia > Claude con clave propia > servidor de ZERACK.
  Future<AiRoute?> route(AppState state) async {
    final gemini = await geminiKey();
    if (gemini != null && gemini.isNotEmpty) {
      return AiRoute(AiProvider.gemini, key: gemini);
    }
    final anthropic = await apiKey();
    if (anthropic != null && anthropic.isNotEmpty) {
      return AiRoute(AiProvider.anthropic, key: anthropic);
    }
    final server = serverUrl(state);
    if (server != null) {
      return AiRoute(AiProvider.zerackServer, serverUrl: server);
    }
    return null;
  }

  /// Guarda la clave en el lugar de su proveedor y la verifica con una
  /// consulta que no gasta tokens.
  Future<KeySaveResult> setApiKey(String? key, {bool verify = true}) async {
    final k = key?.trim() ?? '';
    _assistant = null;
    if (k.isEmpty) {
      await secrets.write(apiKeyName, null);
      await secrets.write(geminiKeyName, null);
      return const KeySaveResult(AiProvider.gemini, KeyCheck.unverified);
    }
    final AiProvider provider;
    if (looksLikeGeminiKey(k)) {
      provider = AiProvider.gemini;
      await secrets.write(geminiKeyName, k);
    } else if (looksLikeAnthropicKey(k)) {
      provider = AiProvider.anthropic;
      await secrets.write(apiKeyName, k);
    } else {
      throw const UnknownKeyFormat();
    }
    if (!verify) return KeySaveResult(provider, KeyCheck.unverified);
    return KeySaveResult(provider, await _verify(provider, k));
  }

  Future<KeyCheck> _verify(AiProvider provider, String key) async {
    final (uri, headers) = switch (provider) {
      AiProvider.gemini => (
        Uri.parse('${GeminiDirect.baseUrl}/v1beta/models/$geminiModel'),
        {'x-goog-api-key': key},
      ),
      _ => (
        Uri.parse('${ClaudeConfig.anthropicBaseUrl}/v1/models?limit=1'),
        {
          'x-api-key': key,
          'anthropic-version': ClaudeClient.apiVersion,
          if (kIsWeb) 'anthropic-dangerous-direct-browser-access': 'true',
        },
      ),
    };
    try {
      final res = await httpClient
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) return KeyCheck.valid;
      if (res.statusCode == 400 ||
          res.statusCode == 401 ||
          res.statusCode == 403) {
        return KeyCheck.rejected;
      }
      return KeyCheck.unverified;
    } on Object {
      return KeyCheck.unverified;
    }
  }

  /// `null` si está lista; si no, 'consent' o 'key'.
  Future<String?> unavailableReason(AppState state) async {
    if (!state.settings.aiConsent) return 'consent';
    return await route(state) == null ? 'key' : null;
  }

  Future<GeminiClient> _gemini(AiRoute r) async => GeminiClient(
    httpClient: httpClient,
    access: r.provider == AiProvider.gemini
        ? GeminiDirect(r.key!)
        : GeminiViaServer(baseUrl: r.serverUrl!, deviceId: await deviceId()),
  );

  Future<AiBackend> _backend(AppState state) async {
    final r = await route(state);
    if (r == null) throw const ClaudeAuthError('Falta configurar la IA');
    if (r.provider == AiProvider.anthropic) {
      return ClaudeBackend(
        ClaudeClient(
          httpClient: httpClient,
          config: ClaudeConfig(apiKey: r.key),
        ),
      );
    }
    return GeminiBackend(await _gemini(r), label: r.label);
  }

  Future<FoodScanner> scanner(AppState state) async =>
      FoodScanner(await _backend(state), state.foods);

  /// Mantiene la misma conversación mientras no cambie la configuración.
  Future<Assistant> assistant(AppState state) async =>
      _assistant ??= Assistant(await _backend(state), state);

  /// Voz del agente: solo por el servidor (la clave de Fish nunca va en la
  /// app). `null` si no hay servidor.
  Future<VoiceService?> voice(AppState state) async {
    final server = serverUrl(state);
    if (server == null) return null;
    return VoiceService(
      httpClient: httpClient,
      serverUrl: server,
      deviceId: await deviceId(),
    );
  }

  void resetConversation() => _assistant = null;
}
