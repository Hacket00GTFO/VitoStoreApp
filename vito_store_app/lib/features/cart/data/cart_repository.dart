import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/api_config.dart';
import '../../../shared/providers/providers.dart';
import '../domain/cart_item.dart';

/// Repositorio del carrito. Consume `/api/cart` (GET, POST, PUT, DELETE).
///
/// Replica el comportamiento del `useCart` hook de la web.
class CartRepository {
  CartRepository(this._dio);

  final Dio _dio;

  /// Obtiene el carrito actual del usuario.
  Future<List<CartItem>> getCart() async {
    final resp = await _dio.get(ApiEndpoints.cart);
    final data = resp.data;
    final List<dynamic> items = data is List
        ? data
        : (data['items'] as List?) ?? (data['data'] as List?) ?? [];
    return items.map((e) => CartItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Agrega un producto al carrito (o incrementa cantidad si ya existe).
  Future<List<CartItem>> addItem({
    required String productId,
    required int quantity,
  }) async {
    final resp = await _dio.post(ApiEndpoints.cart, data: {
      'productId': productId,
      'quantity': quantity,
    });
    final data = resp.data;
    final List<dynamic> items = data is List
        ? data
        : (data['items'] as List?) ?? (data['data'] as List?) ?? [];
    return items.map((e) => CartItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Actualiza la cantidad de un item del carrito.
  Future<List<CartItem>> updateQuantity({
    required String productId,
    required int quantity,
  }) async {
    final resp = await _dio.put(ApiEndpoints.cart, data: {
      'productId': productId,
      'quantity': quantity,
    });
    final data = resp.data;
    final List<dynamic> items = data is List
        ? data
        : (data['items'] as List?) ?? (data['data'] as List?) ?? [];
    return items.map((e) => CartItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Elimina un item del carrito.
  Future<List<CartItem>> removeItem(String productId) async {
    final resp = await _dio.delete(
      ApiEndpoints.cart,
      queryParameters: {'productId': productId},
    );
    final data = resp.data;
    final List<dynamic> items = data is List
        ? data
        : (data['items'] as List?) ?? (data['data'] as List?) ?? [];
    return items.map((e) => CartItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Vacia el carrito completo.
  Future<void> clearCart() async {
    await _dio.delete(ApiEndpoints.cart);
  }
}

/// Provider del repositorio de carrito.
final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository(ref.read(dioProvider));
});
