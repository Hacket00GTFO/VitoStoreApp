import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/api_config.dart';
import '../../../shared/providers/providers.dart';
import '../domain/notification_model.dart';

/// Repositorio de notificaciones. Consume `/api/notifications`.
///
/// Replica el `useNotifications` hook de la web.
class NotificationRepository {
  NotificationRepository(this._dio);

  final Dio _dio;

  /// Lista de notificaciones del usuario autenticado.
  Future<List<AppNotification>> list() async {
    final resp = await _dio.get(ApiEndpoints.notifications);
    final data = resp.data;
    final List<dynamic> items = data is List
        ? data
        : (data['data'] as List?) ?? (data['notifications'] as List?) ?? [];
    return items
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Marca una notificacion como leida.
  Future<void> markAsRead(String id) async {
    await _dio.put('${ApiEndpoints.notifications}/$id/read');
  }
}

/// Provider del repositorio de notificaciones.
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.read(dioProvider));
});
