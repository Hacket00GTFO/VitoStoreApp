import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/api_config.dart';
import '../../../shared/providers/providers.dart';
import '../domain/cart_item.dart';

/// Totales del carrito calculados por el backend (conversión USD→MXN).
///
/// Espejo del objeto `totals` que devuelve `cartService.getCart` en la API.
class CartTotals {
  const CartTotals({
    this.subtotalUSD = 0,
    this.subtotalMXN = 0,
    this.subtotalUSDInMXN = 0,
    this.totalMXN = 0,
    this.exchangeRate = 1,
    this.itemCount = 0,
    this.breakdown = '',
  });

  factory CartTotals.fromJson(Map<String, dynamic> json) {
    return CartTotals(
      subtotalUSD: (json['subtotalUSD'] as num?)?.toDouble() ?? 0,
      subtotalMXN: (json['subtotalMXN'] as num?)?.toDouble() ?? 0,
      subtotalUSDInMXN: (json['subtotalUSDInMXN'] as num?)?.toDouble() ?? 0,
      totalMXN: (json['totalMXN'] as num?)?.toDouble() ?? 0,
      exchangeRate: (json['exchangeRate'] as num?)?.toDouble() ?? 1,
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
      breakdown: json['breakdown']?.toString() ?? '',
    );
  }

  final double subtotalUSD;
  final double subtotalMXN;
  final double subtotalUSDInMXN;

  /// Total del carrito en MXN (subtotal MXN + USD convertido).
  final double totalMXN;
  final double exchangeRate;
  final int itemCount;
  final String breakdown;
}

/// Snapshot completo del carrito: items + totales calculados en el backend.
class CartSnapshot {
  const CartSnapshot({required this.items, required this.totals});

  final List<CartItem> items;
  final CartTotals totals;

  static const empty =
      CartSnapshot(items: [], totals: CartTotals());
}

/// Repositorio del carrito. Consume `/api/cart` (GET, POST, PATCH, DELETE).
///
/// Replica el comportamiento del `CartContext` de la web (mismos endpoints):
/// - `GET    /api/cart`                    → `{ cart: { items }, totals }`
/// - `POST   /api/cart/items`              → `{ productId, quantity }`
/// - `PATCH  /api/cart/items/:productId`   → `{ quantity }`
/// - `DELETE /api/cart/items/:productId`
/// - `DELETE /api/cart`                    → vaciar
class CartRepository {
  CartRepository(this._dio);

  final Dio _dio;

  CartSnapshot _parse(dynamic data) {
    if (data is! Map<String, dynamic>) return CartSnapshot.empty;
    final cart = data['cart'] as Map<String, dynamic>?;
    final rawItems = (cart?['items'] as List?) ?? const [];
    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map(CartItem.fromJson)
        .toList();
    final totals = data['totals'] is Map<String, dynamic>
        ? CartTotals.fromJson(data['totals'] as Map<String, dynamic>)
        : const CartTotals();
    return CartSnapshot(items: items, totals: totals);
  }

  /// Obtiene el carrito actual del usuario.
  Future<CartSnapshot> getCart() async {
    final resp = await _dio.get(ApiEndpoints.cart);
    return _parse(resp.data);
  }

  /// Agrega un producto al carrito (o incrementa cantidad si ya existe).
  Future<CartSnapshot> addItem({
    required String productId,
    required int quantity,
  }) async {
    final resp = await _dio.post('${ApiEndpoints.cart}/items', data: {
      'productId': productId,
      'quantity': quantity,
    });
    return _parse(resp.data);
  }

  /// Actualiza la cantidad de un item del carrito.
  Future<CartSnapshot> updateQuantity({
    required String productId,
    required int quantity,
  }) async {
    final resp = await _dio.patch(
      '${ApiEndpoints.cart}/items/$productId',
      data: {'quantity': quantity},
    );
    return _parse(resp.data);
  }

  /// Elimina un item del carrito.
  Future<CartSnapshot> removeItem(String productId) async {
    final resp = await _dio.delete('${ApiEndpoints.cart}/items/$productId');
    return _parse(resp.data);
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
