import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/api_config.dart';
import '../../../shared/providers/providers.dart';
import '../domain/order.dart';

/// Repositorio de cuenta. Consume `/api/orders`, `/specialized-quotes/my-quotes`,
/// `/invoices/my-invoices`, `/account/me`, `/account/change-password` y
/// `/history/services` (rutas reales del backend).
///
/// Maneja ordenes, cotizaciones, facturas, servicios del usuario,
/// perfil, actualizacion de datos y cambio de contrasena.
class AccountRepository {
  AccountRepository(this._dio);

  final Dio _dio;

  /// Lista de ordenes del usuario autenticado.
  ///
  /// Contrato real de `GET /orders`: `{ success, data: { orders: [...],
  /// pagination: {...} } }` (el envoltorio `data` anidado era el que rompia
  /// el parseo anterior con un TypeError).
  Future<List<Order>> getOrders() async {
    final resp = await _dio.get(ApiEndpoints.orders);
    final data = resp.data;
    List<dynamic> items = const [];
    if (data is List) {
      items = data;
    } else if (data is Map<String, dynamic>) {
      final inner = data['data'];
      if (inner is Map<String, dynamic>) {
        items = (inner['orders'] as List?) ?? const [];
      } else if (data['orders'] is List) {
        items = data['orders'] as List;
      } else if (data['data'] is List) {
        items = data['data'] as List;
      }
    }
    return items.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Lista de cotizaciones especializadas propias.
  ///
  /// `GET /quotes` no existe: la ruta real es `GET /specialized-quotes/my-quotes`
  /// (responde array plano o `{data:[...]}`).
  Future<List<Map<String, dynamic>>> getQuotes() async {
    final resp = await _dio.get('${ApiEndpoints.specializedQuotes}/my-quotes');
    return _unwrapList(resp.data, 'quotes');
  }

  /// Lista de facturas del usuario autenticado.
  ///
  /// `GET /invoices` no existe: la ruta real es `GET /invoices/my-invoices`.
  Future<List<Map<String, dynamic>>> getInvoices() async {
    final resp = await _dio.get('${ApiEndpoints.invoices}/my-invoices');
    return _unwrapList(resp.data, 'invoices');
  }

  /// Servicios solicitados por el usuario.
  ///
  /// `GET /services/user` interpreta "user" como slug (404): la ruta real es
  /// `GET /history/services`, que responde `{services:[...]}` dentro del
  /// historial unificado.
  Future<List<Map<String, dynamic>>> getUserServices() async {
    try {
      final resp = await _dio.get('${ApiEndpoints.base}/history/services');
      return _unwrapList(resp.data, 'services');
    } catch (_) {
      return [];
    }
  }

  /// Historial unificado del usuario (`GET /history`).
  ///
  /// Contrato real (verificado): `{ success, data: { orders, serviceRequests,
  /// specializedQuotes, invoiceRequests, summary } }` — una sola llamada
  /// entrega todas las colecciones de la pantalla de cuenta.
  Future<AccountHistory> getHistory() async {
    final resp = await _dio.get(ApiEndpoints.history);
    final data = resp.data;
    if (data is Map<String, dynamic>) {
      final inner = data['data'];
      if (inner is Map<String, dynamic>) return AccountHistory.fromJson(inner);
      return AccountHistory.fromJson(data);
    }
    return const AccountHistory();
  }

  /// Normaliza una respuesta que puede ser array plano o `{data:[...]}` /
  /// `{campo:[...]}` al formato `List<Map<String, dynamic>>`.
  List<Map<String, dynamic>> _unwrapList(dynamic data, String key) {
    List<dynamic> items = const [];
    if (data is List) {
      items = data;
    } else if (data is Map<String, dynamic>) {
      final inner = data['data'];
      if (inner is List) {
        items = inner;
      } else if (data[key] is List) {
        items = data[key] as List;
      } else if (inner is Map<String, dynamic> && inner[key] is List) {
        items = inner[key] as List;
      }
    }
    return items.whereType<Map<String, dynamic>>().toList();
  }

  /// Obtiene el perfil del usuario autenticado.
  Future<Map<String, dynamic>> getProfile() async {
    final resp = await _dio.get(ApiEndpoints.profile);
    final data = resp.data;
    if (data is Map<String, dynamic>) {
      return data.containsKey('data') && data['data'] is Map
          ? data['data'] as Map<String, dynamic>
          : data;
    }
    return <String, dynamic>{};
  }

  /// Actualiza el perfil del usuario.
  ///
  /// Devuelve el perfil actualizado como mapa. Los campos vacios se omiten
  /// (el backend marca strings vacios como invalidos).
  Future<Map<String, dynamic>> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    final resp = await _dio.put(ApiEndpoints.profile, data: {
      if (firstName != null && firstName.trim().isNotEmpty)
        'firstName': firstName.trim(),
      if (lastName != null && lastName.trim().isNotEmpty)
        'lastName': lastName.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
    });
    final data = resp.data;
    if (data is Map<String, dynamic>) {
      return data.containsKey('data') && data['data'] is Map
          ? data['data'] as Map<String, dynamic>
          : data;
    }
    return <String, dynamic>{};
  }

  /// Cambia la contrasena del usuario autenticado.
  ///
  /// Contrato real: `POST /account/change-password` con
  /// `{currentPassword, newPassword, confirmPassword}` (el backend cierra las
  /// sesiones activas). `PUT /account/me/password` no existe.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _dio.post('${ApiEndpoints.base}/account/change-password', data: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
      'confirmPassword': newPassword,
    });
  }
}

/// Historial unificado del usuario (`GET /history`).
///
/// Una sola llamada entrega todas las colecciones: evita 4 requests
/// independientes al abrir la pantalla de cuenta (megaplan Fase 2.5).
class AccountHistory {
  const AccountHistory({
    this.orders = const [],
    this.serviceRequests = const [],
    this.specializedQuotes = const [],
    this.invoiceRequests = const [],
    this.summary = const {},
  });

  factory AccountHistory.fromJson(dynamic raw) {
    if (raw is! Map<String, dynamic>) return const AccountHistory();
    List<Map<String, dynamic>> listOfMaps(List<dynamic>? items) =>
        items?.whereType<Map<String, dynamic>>().toList() ?? const <Map<String, dynamic>>[];
    return AccountHistory(
      orders: listOfMaps(raw['orders'] as List?),
      serviceRequests: listOfMaps(raw['serviceRequests'] as List?),
      specializedQuotes: listOfMaps(raw['specializedQuotes'] as List?),
      invoiceRequests: listOfMaps(raw['invoiceRequests'] as List?),
      summary: raw['summary'] is Map<String, dynamic>
          ? raw['summary'] as Map<String, dynamic>
          : const <String, dynamic>{},
    );
  }

  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> serviceRequests;
  final List<Map<String, dynamic>> specializedQuotes;
  final List<Map<String, dynamic>> invoiceRequests;
  final Map<String, dynamic> summary;
}

/// Provider del repositorio de cuenta.
final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(ref.read(dioProvider));
});

/// Historial unificado compartido por los 4 tabs de la pantalla de cuenta.
///
/// Una sola peticion `GET /history` alimenta Ordenes, Cotizaciones,
/// Servicios y Facturas (megaplan Fase 2.5). Pull-to-refresh o el boton
/// Reintentar invalidan este provider: NO hay futures por tab.
final accountHistoryProvider = FutureProvider<AccountHistory>((ref) {
  return ref.watch(accountRepositoryProvider).getHistory();
});
