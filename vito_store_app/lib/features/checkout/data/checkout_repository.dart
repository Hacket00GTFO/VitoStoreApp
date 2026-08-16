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
    // El backend puede envolver en { data: {...} } o devolver directo.
    if (data is Map<String, dynamic>) {
      return data.containsKey('data') && data['data'] is Map
          ? data['data'] as Map<String, dynamic>
          : data;
    }
    return <String, dynamic>{};
  }

  /// Crea un PaymentIntent de Stripe para la orden indicada.
  ///
  /// Devuelve el `clientSecret` necesario para confirmar el pago en el cliente.
  Future<String> getStripePaymentIntent({
    required String orderId,
    required double amount,
  }) async {
    final resp = await _dio.post(ApiEndpoints.payments.stripe, data: {
      'orderId': orderId,
      'amount': amount,
    });
    final data = resp.data;
    if (data is Map<String, dynamic>) {
      final clientSecret =
          data['clientSecret'] ?? data['client_secret'] ?? data['paymentIntent'];
      return clientSecret?.toString() ?? '';
    }
    return '';
  }
}

/// Provider del repositorio de checkout.
final checkoutRepositoryProvider = Provider<CheckoutRepository>((ref) {
  return CheckoutRepository(ref.read(dioProvider));
});
