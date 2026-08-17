import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/api_config.dart';
import '../../../shared/providers/providers.dart';

/// Repositorio de checkout. Consume `/api/orders` y `/api/payments/stripe`.
///
/// Replica el flujo de compra de la web: crear orden -> procesar pago.
class CheckoutRepository {
  CheckoutRepository(this._dio);

  final Dio _dio;

  /// Crea una orden a partir del carrito actual.
  ///
  /// Devuelve el mapa con `id`, `orderNumber`, `total`, etc.
  Future<Map<String, dynamic>> createOrder({
    required Map<String, dynamic> shippingAddress,
    String? paymentMethod,
    String? notes,
  }) async {
    final resp = await _dio.post(ApiEndpoints.orders, data: {
      'shippingAddress': shippingAddress,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
      if (notes != null) 'notes': notes,
    });
    final data = resp.data;
    // Contrato del backend: 201 { success, data: { order: {...} } }.
    if (data is Map<String, dynamic>) {
      final inner = data['data'];
      if (inner is Map<String, dynamic> && inner['order'] is Map) {
        return inner['order'] as Map<String, dynamic>;
      }
      if (inner is Map<String, dynamic>) return inner;
      return data;
    }
    return <String, dynamic>{};
  }

  /// Crea un PaymentIntent de Stripe para la orden indicada.
  ///
  /// Consume `POST /api/payments/stripe/create-intent` (el monto lo recalcula
  /// el backend desde la orden, siempre en MXN).
  /// Devuelve el `clientSecret` necesario para confirmar el pago en el cliente.
  Future<String> getStripePaymentIntent({
    required String orderId,
  }) async {
    final resp = await _dio.post(
      ApiEndpoints.payments.stripeCreateIntent,
      data: {'orderId': orderId},
    );
    final data = resp.data;
    if (data is Map<String, dynamic>) {
      final inner = data['data'];
      final source = inner is Map<String, dynamic> ? inner : data;
      final clientSecret = source['clientSecret'] ??
          source['client_secret'] ??
          source['paymentIntent'];
      return clientSecret?.toString() ?? '';
    }
    return '';
  }
}

/// Provider del repositorio de checkout.
final checkoutRepositoryProvider = Provider<CheckoutRepository>((ref) {
  return CheckoutRepository(ref.read(dioProvider));
});
