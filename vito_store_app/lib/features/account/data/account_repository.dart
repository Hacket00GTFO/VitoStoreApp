import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/api_config.dart';
import '../../../shared/providers/providers.dart';
import '../domain/order.dart';

/// Repositorio de cuenta. Consume `/api/orders`, `/api/account/me`.
///
/// Maneja ordenes del usuario, perfil y actualizacion de datos.
class AccountRepository {
  AccountRepository(this._dio);

  final Dio _dio;

  /// Lista de ordenes del usuario autenticado.
  Future<List<Order>> getOrders() async {
    final resp = await _dio.get(ApiEndpoints.orders);
    final data = resp.data;
    final List<dynamic> items = data is List
        ? data
        : (data['data'] as List?) ?? (data['orders'] as List?) ?? [];
    return items.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
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
  /// Devuelve el perfil actualizado como mapa.
  Future<Map<String, dynamic>> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    final resp = await _dio.put(ApiEndpoints.profile, data: {
      if (firstName != null) 'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      if (phone != null) 'phone': phone,
    });
    final data = resp.data;
    if (data is Map<String, dynamic>) {
      return data.containsKey('data') && data['data'] is Map
          ? data['data'] as Map<String, dynamic>
          : data;
    }
    return <String, dynamic>{};
  }
}

/// Provider del repositorio de cuenta.
final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(ref.read(dioProvider));
});
