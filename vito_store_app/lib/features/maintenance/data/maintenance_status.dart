import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/api_config.dart';
import '../../../shared/providers/providers.dart';

/// Estado de mantenimiento expuesto por el backend en `GET /api/health`
/// (`data.maintenance = {active, message, scopes:{store,cart,checkout,faqs}}`).
///
/// La app lo consulta al arrancar (y al "Reintentar" de la pantalla de
/// mantenimiento) para redirigir sin necesidad de esperar un 503.
class MaintenanceStatus {
  const MaintenanceStatus({
    required this.active,
    this.message,
    this.scopes = const <String, bool>{},
  });

  factory MaintenanceStatus.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MaintenanceStatus(active: false);
    final scopesRaw = json['scopes'];
    final scopes = <String, bool>{
      if (scopesRaw is Map)
        for (final entry in scopesRaw.entries)
          if (entry.key is String) (entry.key as String): entry.value == true,
    };
    final active = json['active'] == true;
    return MaintenanceStatus(
      active: active,
      message: active ? (json['message']?.toString()) : null,
      scopes: scopes,
    );
  }

  final bool active;
  final String? message;
  final Map<String, bool> scopes;

  /// true si el store (catálogo/tienda) esta bloqueado.
  bool get blocksStore => active && (scopes['store'] ?? false);

  static const MaintenanceStatus ok = MaintenanceStatus(active: false);
}

/// Provider async del estado de mantenimiento (autoDispose: se reconsulta al
/// invalidar, p.ej. con el botón Reintentar).
final maintenanceStatusProvider =
    FutureProvider.autoDispose<MaintenanceStatus>((ref) async {
  try {
    final resp = await ref.read(dioProvider).get('${ApiEndpoints.base}/health');
    final data = resp.data;
    if (data is Map<String, dynamic>) {
      final inner = data['data'];
      if (inner is Map<String, dynamic>) {
        return MaintenanceStatus.fromJson(
            inner['maintenance'] as Map<String, dynamic>?);
      }
    }
    return MaintenanceStatus.ok;
  } catch (_) {
    // Sin /health no asumimos mantenimiento (la app necesita el backend
    // para TODO, si no hay backend ya verá errores en la llamada activa).
    return MaintenanceStatus.ok;
  }
});
