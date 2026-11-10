import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/api_config.dart';
import '../../../shared/providers/providers.dart';
import '../domain/notification_model.dart';

/// Repositorio de notificaciones. Consume `/api/notifications`.
///
/// Contratos reales del backend:
/// - `GET /` → `{success, data, unreadCount, pagination}`
/// - `PATCH /:id/read` (PUT no existe)
/// - `PATCH /mark-all-read`
/// - `GET /unread-count` → `{success, count}`
class NotificationRepository {
  NotificationRepository(this._dio);

  final Dio _dio;

  /// Lista de notificaciones del usuario autenticado.
  Future<List<AppNotification>> list() async {
    final resp = await _dio.get(ApiEndpoints.notifications);
    final data = resp.data;
    List<dynamic> items = const [];
    if (data is List) {
      items = data;
    } else if (data is Map<String, dynamic>) {
      final inner = data['data'];
      if (inner is List) {
        items = inner;
      } else if (data['notifications'] is List) {
        items = data['notifications'] as List;
      } else if (inner is Map<String, dynamic>) {
        items = (inner['data'] as List?) ?? (inner['notifications'] as List?) ?? const [];
      }
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList();
  }

  /// Numero de notificaciones no leidas (GET /unread-count).
  Future<int> unreadCount() async {
    final resp = await _dio.get('${ApiEndpoints.notifications}/unread-count');
    final data = resp.data;
    if (data is Map<String, dynamic>) {
      return (data['count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  /// Marca una notificacion como leida (`PATCH /:id/read`).
  Future<void> markAsRead(String id) async {
    await _dio.patch('${ApiEndpoints.notifications}/$id/read');
  }

  /// Marca todas como leidas (`PATCH /mark-all-read`).
  Future<int> markAllRead() async {
    final resp = await _dio.patch('${ApiEndpoints.notifications}/mark-all-read');
    final data = resp.data;
    if (data is Map<String, dynamic>) {
      return (data['count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }
}

/// Provider del repositorio de notificaciones.
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.read(dioProvider));
});

/// Badge global: numero de notificaciones sin leer.
///
/// Se refresca cada 2 minutos, y machaca manualmente al invalidar (p.ej. al
/// marcar como leida desde la pantalla de notificaciones). Con la sesion
/// cerrada devuelve 0 silenciosamente (401 => catch).
class UnreadCountNotifier extends Notifier<int> {
  Timer? _timer;

  @override
  int build() {
    Future.microtask(_refresh);
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => _refresh());
    ref.onDispose(() => _timer?.cancel());
    return 0;
  }

  NotificationRepository get _repo =>
      ref.read(notificationRepositoryProvider);

  Future<void> _refresh() async {
    try {
      final count = await _repo.unreadCount();
      if (count != state) state = count;
    } catch (_) {
      // Sin sesion o sin red: mantener 0 sin ensuciar la UI.
    }
  }

  /// Forza el recuento (tras marcar como leidas).
  void recount() => _refresh();
}

final unreadCountProvider =
    NotifierProvider<UnreadCountNotifier, int>(UnreadCountNotifier.new);
