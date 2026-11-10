import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/api_config.dart';
import '../../../shared/providers/providers.dart';

/// Repositorio de checkout. Consume `/api/orders`, `/api/orders/shipping-options`
/// y `/api/payments/*` — contratos reales del backend (verificados contra
/// `vito-api` y el frontend web `services/orderService.ts`).
///
/// Flujo de compra de la web: shipping-options (con direccion estructurada) →
/// create-order (shippingAddress/billingAddress como strings + shippingDetails
/// + shippingQuoteToken) → payments/stripe/create-intent → PaymentSheet.
class CheckoutRepository {
  CheckoutRepository(this._dio);

  final Dio _dio;

  /// Obtiene las opciones de envio para una direccion estructurada.
  ///
  /// Consume `POST /api/orders/shipping-options` (requiere Bearer) con body
  /// `{shippingDetails:{recipient, phone, street, exteriorNumber,
  /// interiorNumber?, neighborhood, city, state, postalCode, country}}`.
  ///
  /// Responde `{requiresSelection, syscomOnly, baseShipping, subtotalMxn,
  /// options:[{quoteToken, kind, carrierCode, carrierName, freight, currency,
  /// freightMxn, shippingTotalMxn}]}`. Si `requiresSelection` es true hay que
  /// devolver el `quoteToken` de la opcion elegida al crear la orden.
  Future<ShippingQuotesResult> getShippingOptions({
    required ShippingDetails shippingDetails,
  }) async {
    final resp = await _dio.post(
      '${ApiEndpoints.base}/orders/shipping-options',
      data: {'shippingDetails': shippingDetails.toJson()},
    );
    final data = resp.data is Map<String, dynamic>
        ? resp.data as Map<String, dynamic>
        : const <String, dynamic>{};
    final inner = data['data'] is Map<String, dynamic>
        ? data['data'] as Map<String, dynamic>
        : data;
    final items = (inner['options'] as List?) ?? const [];
    final options =
        items.map((e) => ShippingOption.fromJson(e as Map<String, dynamic>)).toList();
    return ShippingQuotesResult(
      requiresSelection: inner['requiresSelection'] == true,
      syscomOnly: inner['syscomOnly'] == true,
      baseShipping: (inner['baseShipping'] as num?)?.toDouble() ?? 0,
      subtotalMxn: (inner['subtotalMxn'] as num?)?.toDouble() ?? 0,
      options: options,
    );
  }

  /// Crea la orden a partir del carrito actual.
  ///
  /// Contrato web verificado: `POST /api/orders` con
  /// `{shippingAddress: "texto", billingAddress: "texto", notes?,
  /// shippingDetails: {...}, shippingQuoteToken?}` →
  /// `201 {success, data:{order}}`. El backend recalcula el total (envio
  /// inclucido) y vacia el carrito en el servidor.
  Future<Map<String, dynamic>> createOrder({
    required String shippingAddress,
    required String billingAddress,
    required ShippingDetails shippingDetails,
    String? shippingQuoteToken,
    String? notes,
  }) async {
    final resp = await _dio.post(ApiEndpoints.orders, data: {
      'shippingAddress': shippingAddress,
      'billingAddress': billingAddress,
      'shippingDetails': shippingDetails.toJson(),
      if (shippingQuoteToken != null && shippingQuoteToken.isNotEmpty)
        'shippingQuoteToken': shippingQuoteToken,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
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

  /// Consulta que metodos de pago estan habilitados en el backend.
  ///
  /// Contrato real de `GET /api/payments/available`:
  /// `{data:{stripe:{isActive}, paypal:{isActive}, spei:{isActive}}}`.
  ///
  /// Ante error devuelve solo Stripe (metodo principal siempre implementado).
  Future<PaymentMethodsAvailability> getAvailablePaymentMethods() async {
    try {
      final resp = await _dio.get(ApiEndpoints.payments.available);
      final data = resp.data;
      if (data is Map<String, dynamic>) {
        final inner = data['data'];
        final source = inner is Map<String, dynamic> ? inner : data;
        bool active(Object? raw) {
          if (raw is Map) {
            return raw['isActive'] == true || raw['active'] == true || raw['enabled'] == true;
          }
          return raw == true;
        }

        return PaymentMethodsAvailability(
          stripe: active(source['stripe']),
          paypal: active(source['paypal']),
          spei: active(source['spei']),
        );
      }
      return const PaymentMethodsAvailability(stripe: true);
    } catch (_) {
      return const PaymentMethodsAvailability(stripe: true);
    }
  }
}

/// Direccion de entrega estructurada que exigen las rutas de envio/orden.
///
/// Campos espejo del `shippingDetails` de la web (`services/orderService.ts`).
class ShippingDetails {
  const ShippingDetails({
    required this.recipient,
    required this.phone,
    required this.street,
    required this.exteriorNumber,
    this.interiorNumber,
    required this.neighborhood,
    required this.city,
    required this.state,
    required this.postalCode,
    this.country = 'MEX',
  });

  final String recipient;
  final String phone;
  final String street;
  final String exteriorNumber;
  final String? interiorNumber;
  final String neighborhood;
  final String city;
  final String state;
  final String postalCode;
  final String country;

  Map<String, dynamic> toJson() => {
        'recipient': recipient,
        'phone': phone,
        'street': street,
        'exteriorNumber': exteriorNumber,
        if (interiorNumber != null && interiorNumber!.trim().isNotEmpty)
          'interiorNumber': interiorNumber,
        'neighborhood': neighborhood,
        'city': city,
        'state': state,
        'postalCode': postalCode,
        'country': country,
      };

  /// STRING legible para `shippingAddress`/`billingAddress` de la orden.
  @override
  String toString() => [
        recipient,
        '$street ${exteriorNumber.trim()}${interiorNumber != null && interiorNumber!.trim().isNotEmpty ? ' Int. ${interiorNumber!.trim()}' : ''}',
        neighborhood,
        city,
        state,
        'CP $postalCode',
        'Tel. $phone',
      ].join(', ');
}

/// Respuesta del endpoint de cotizaciones de envio.
class ShippingQuotesResult {
  const ShippingQuotesResult({
    required this.requiresSelection,
    required this.syscomOnly,
    required this.baseShipping,
    required this.subtotalMxn,
    required this.options,
  });

  final bool requiresSelection;
  final bool syscomOnly;
  final double baseShipping;
  final double subtotalMxn;
  final List<ShippingOption> options;
}

/// Opcion de envio devuelta por `POST /orders/shipping-options`.
class ShippingOption {
  const ShippingOption({
    required this.quoteToken,
    required this.carrierName,
    this.kind,
    this.carrierCode,
    this.freight,
    this.currency,
    this.freightMxn,
    this.shippingTotalMxn,
  });

  factory ShippingOption.fromJson(Map<String, dynamic> json) {
    return ShippingOption(
      quoteToken: json['quoteToken']?.toString() ?? '',
      kind: json['kind']?.toString(),
      carrierCode: json['carrierCode']?.toString(),
      carrierName: json['carrierName']?.toString() ??
          json['carrier']?.toString() ??
          'Envio',
      freight: (json['freight'] as num?)?.toDouble(),
      currency: json['currency']?.toString(),
      freightMxn: (json['freightMxn'] as num?)?.toDouble(),
      shippingTotalMxn: (json['shippingTotalMxn'] as num?)?.toDouble(),
    );
  }

  /// Token que hay que devolver en `createOrder` si `requiresSelection`.
  final String quoteToken;
  final String? kind;
  final String? carrierCode;
  final String carrierName;
  final double? freight;
  final String? currency;
  final double? freightMxn;
  final double? shippingTotalMxn;

  /// Etiqueta legible para la UI.
  String get name {
    final kindLabel = switch (kind) {
      'syscom' => 'Syscom',
      'propio' || 'local' => 'Pallets / shipments',
      _ => null,
    };
    return kindLabel == null ? carrierName : '$carrierName ($kindLabel)';
  }

  /// Costo total de envio en MXN.
  double get cost => shippingTotalMxn ?? freightMxn ?? freight ?? 0;

  /// Texto de tiempo estimado si el backend lo llega a incluir.
  String get estimatedDays => '';

  /// True cuando es una opcion sin costo cobrado.
  bool get isFree => cost <= 0;
}

/// Disponibilidad real de metodos de pago del backend.
class PaymentMethodsAvailability {
  const PaymentMethodsAvailability({
    this.stripe = false,
    this.paypal = false,
    this.spei = false,
  });

  final bool stripe;
  final bool paypal;
  final bool spei;
}

/// Provider del repositorio de checkout.
final checkoutRepositoryProvider = Provider<CheckoutRepository>((ref) {
  return CheckoutRepository(ref.read(dioProvider));
});
