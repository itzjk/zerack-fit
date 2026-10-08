import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../data/app_state.dart';
import 'assistant.dart';
import 'claude_client.dart';
import 'food_scanner.dart';

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

class MemorySecretStore implements SecretStore {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String? value) async =>
      value == null ? data.remove(key) : data[key] = value;
}

/// Punto único para crear el escáner y el asistente con la configuración
/// vigente.
class AiService {
  AiService({required this.secrets, required this.httpClient});

  static const apiKeyName = 'zerack.ai.apiKey';

  final SecretStore secrets;
  final http.Client httpClient;

  Assistant? _assistant;

  Future<String?> apiKey() => secrets.read(apiKeyName);

  Future<void> setApiKey(String? key) async {
    final k = key?.trim();
    await secrets.write(apiKeyName, (k == null || k.isEmpty) ? null : k);
    _assistant = null;
  }

  Future<ClaudeClient> _client(AppState state) async {
    final s = state.settings;
    final base = s.aiBaseUrl?.trim();
    return ClaudeClient(
      httpClient: httpClient,
      config: ClaudeConfig(
        apiKey: await apiKey(),
        baseUrl: (base == null || base.isEmpty) ? null : base,
      ),
    );
  }

  /// `null` si falta consentimiento o forma de autenticarse.
  Future<String?> unavailableReason(AppState state) async {
    if (!state.settings.aiConsent) return 'consent';
    final c = await _client(state);
    return c.config.isUsable ? null : 'key';
  }

  Future<FoodScanner> scanner(AppState state) async =>
      FoodScanner(await _client(state), state.foods);

  /// Mantiene la misma conversación mientras no cambie la configuración.
  Future<Assistant> assistant(AppState state) async =>
      _assistant ??= Assistant(await _client(state), state);

  void resetConversation() => _assistant = null;
}
