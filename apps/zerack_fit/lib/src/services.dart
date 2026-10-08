import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'ai/ai_service.dart';
import 'data/off_client.dart';
import 'health/health_service.dart';

/// Servicios externos (red, IA, salud del sistema). Todos opcionales para la
/// persona y reemplazables en pruebas.
class Services {
  Services({
    required this.ai,
    required this.openFoodFacts,
    required this.health,
  });

  factory Services.platform() {
    final client = http.Client();
    return Services(
      ai: AiService(secrets: const SecureSecretStore(), httpClient: client),
      openFoodFacts: OpenFoodFactsClient(client),
      health: PlatformHealthBridge(),
    );
  }

  final AiService ai;
  final OpenFoodFactsClient openFoodFacts;
  final HealthBridge health;
}

class ServicesScope extends InheritedWidget {
  const ServicesScope({
    super.key,
    required this.services,
    required super.child,
  });

  final Services services;

  static Services of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ServicesScope>()!.services;

  @override
  bool updateShouldNotify(ServicesScope old) => services != old.services;
}
