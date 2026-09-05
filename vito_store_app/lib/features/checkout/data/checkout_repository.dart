import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/api_config.dart';
import '../../../shared/providers/providers.dart';

/// Repositorio de checkout. Consume `/api/orders`, `/api/payments/*` y
/// `/api/shipping/options`.
///
/// Replica el flujo de compra de la web: crear orden -> procesar pago.
/// Soporta Stripe, MercadoPago y SPEI.
class CheckoutRepository {
  CheckoutRepository(this._dio);

  final Dio _dio;

  /// Crea una orden a partir del carrito actual.
  ///
  /// Devuelve el mapa con `id`, `orderNumber`, `total`, etc.
  Future<Map<String, dynamic>> createOrder({
    required Map<String, dynamic> shippingAddress,
    String? paymentMethod,
    String? shippingMethodId,
    String? notes,
  }) async {
    final resp = await _dio.post(ApiEndpoints.orders, data: {
      'shippingAddress': shippingAddress,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
      if (shippingMethodId != null) 'shippingMethodId': shippingMethodId,
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

  /// Crea una preferencia de MercadoPago para la orden indicada.
  ///
  /// Consume `POST /api/payments/mercadopago/create-preference`.
  /// Devuelve el `initPoint` (URL de checkout de MercadoPago) y el `preferenceId`.
  Future<MercadoPagoResult> getMercadoPagoPreference({
    required String orderId,
  }) async {
    final resp = await _dio.post(
      '${ApiEndpoints.payments.mercadopago}/create-preference',
      data: {'orderId': orderId},
    );
    final data = resp.data;
    if (data is Map<String, dynamic>) {
      final inner = data['data'];
      final source = inner is Map<String, dynamic> ? inner : data;
      return MercadoPagoResult(
        preferenceId: source['preferenceId']?.toString() ?? '',
        initPoint: source['initPoint']?.toString() ??
            source['sandboxInitPoint']?.toString() ??
            '',
      );
    }
    return const MercadoPagoResult(preferenceId: '', initPoint: '');
  }

  /// Genera datos para pago SPEI (transferencia bancaria).
  ///
  /// Consume `POST /api/payments/spei/create`.
  /// Devuelve el CLABE, banco receptor, monto y concepto de referencia.
  Future<SpeiResult> getSpeiPaymentData({
    required String orderId,
  }) async {
    final resp = await _dio.post(
      '${ApiEndpoints.base}/payments/spei/create',
      data: {'orderId': orderId},
    );
    final data = resp.data;
    if (data is Map<String, dynamic>) {
      final inner = data['data'];
      final source = inner is Map<String, dynamic> ? inner : data;
      return SpeiResult(
        clabe: source['clabe']?.toString() ?? '',
        bank: source['bank']?.toString() ?? 'STP',
        reference: source['reference']?.toString() ?? orderId,
        amount: (source['amount'] as num?)?.toDouble() ?? 0,
        concept: source['concept']?.toString() ?? 'Pago orden $orderId',
      );
    }
    return SpeiResult(clabe: '', bank: '', reference: '', amount: 0, concept: '');
  }

  /// Obtiene las opciones de envio disponibles para una direccion.
  ///
  /// Consume `POST /api/shipping/options` con el codigo postal y la direccion.
  /// Devuelve una lista de metodos con id, nombre, costo y tiempo estimado.
  Future<List<ShippingOption>> getShippingOptions({
    required String zipCode,
  }) async {
    try {
      final resp = await _dio.post(
        '${ApiEndpoints.base}/shipping/options',
        data: {'zipCode': zipCode},
      );
      final data = resp.data;
      final List<dynamic> items = data is List
          ? data
          : (data is Map<String, dynamic>
              ? (data['data'] as List?) ?? (data['options'] as List?) ?? []
              : []);
      return items
          .map((e) => ShippingOption.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Si el backend no tiene endpoint de shipping, devolver opcion por defecto.
      return [
        ShippingOption(
          id: 'standard',
          name: 'Envio estandar',
          cost: 0,
          estimatedDays: '3-5 dias habiles',
        ),
      ];
    }
  }

  /// Consulta que metodos de pago estan habilitados en el backend.
  ///
  /// Consume `GET /api/payments/available`. Devuelve un set de strings
  /// como {'stripe', 'mercadopago', 'spei'}.
  Future<Set<String>> getAvailablePaymentMethods() async {
    try {
      final resp = await _dio.get(ApiEndpoints.payments.available);
      final data = resp.data;
      if (data is Map<String, dynamic>) {
        final inner = data['data'];
        final source = inner is Map<String, dynamic> ? inner : data;
        final methods = source['methods'] as List?;
        if (methods != null) {
          return methods.map((e) => e.toString().toLowerCase()).toSet();
        }
      }
      return {'stripe'};
    } catch (_) {
      return {'stripe'};
    }
  }
}

/// Opcion de envio devuelta por el backend.
class ShippingOption {
  const ShippingOption({
    required this.id,
    required this.name,
    required this.cost,
    required this.estimatedDays,
  });

  final String id;
  final String name;
  final double cost;
  final String estimatedDays;

  factory ShippingOption.fromJson(Map<String, dynamic> json) {
    return ShippingOption(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Envio',
      cost: (json['cost'] as num?)?.toDouble() ?? 0,
      estimatedDays: json['estimatedDays']?.toString() ??
          json['estimated_days']?.toString() ??
          '3-5 dias habiles',
    );
  }
}

/// Resultado de la preferencia de MercadoPago.
class MercadoPagoResult {
  const MercadoPagoResult({
    required this.preferenceId,
    required this.initPoint,
  });

  final String preferenceId;
  final String initPoint;

  bool get isValid => initPoint.isNotEmpty;
}

/// Resultado del pago SPEI.
class SpeiResult {
  const SpeiResult({
    required this.clabe,
    required this.bank,
    required this.reference,
    required this.amount,
    required this.concept,
  });

  final String clabe;
  final String bank;
  final String reference;
  final double amount;
  final String concept;

  bool get isValid => clabe.isNotEmpty;
}

/// Provider del repositorio de checkout.
final checkoutRepositoryProvider = Provider<CheckoutRepository>((ref) {
  return CheckoutRepository(ref.read(dioProvider));
});
