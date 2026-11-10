import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/api_config.dart';
import '../../../shared/providers/providers.dart';

/// Datos de contacto precargados para formularios
/// (`GET /api/profile/service-request-data` — ruta real del backend).
class QuoteContactData {
  const QuoteContactData({
    this.clientName,
    this.clientEmail,
    this.clientPhone,
    this.companyName,
  });

  factory QuoteContactData.fromJson(Map<String, dynamic> json) {
    return QuoteContactData(
      clientName: json['clientName']?.toString(),
      clientEmail: json['clientEmail']?.toString(),
      clientPhone: json['clientPhone']?.toString(),
      // UserProfile.companyName puede llegar a null.
      companyName: json['companyName']?.toString(),
    );
  }

  final String? clientName;
  final String? clientEmail;
  final String? clientPhone;
  final String? companyName;
}

/// Datos de una cotizacion especializada creada (minimo para mostrar el folio).
class CreatedQuote {
  const CreatedQuote({required this.quoteNumber});

  factory CreatedQuote.fromJson(Map<String, dynamic> json) {
    return CreatedQuote(
      quoteNumber: json['quoteNumber']?.toString() ?? '',
    );
  }

  final String quoteNumber;
}

/// Repositorio de cotizaciones especializadas.
///
/// Contratos reales del backend (`specializedQuotes.ts`):
/// - `GET  /specialized-quotes/my-quotes`      → array de cotizaciones propias
/// - `POST /specialized-quotes`                → requiere Bearer (usuario logeado)
/// - `POST /specialized-quotes/public`         → sin sesion (espacio limitado)
/// - Ambos devuelven 201 con el objeto directo `{quoteNumber, status, ...}`
///   (SIN envoltorio success/data).
class QuoteRepository {
  QuoteRepository(this._dio);

  final Dio _dio;

  /// Contacto de la sesion actual (para prellenar el formulario). Si falla
  /// devuelve vacio: el formulario funciona igual.
  Future<QuoteContactData> contactData() async {
    try {
      final resp =
          await _dio.get(ApiEndpoints.profileServiceRequestData);
      final data = resp.data;
      if (data is Map<String, dynamic>) {
        final inner = data['data'];
        if (inner is Map<String, dynamic>) return QuoteContactData.fromJson(inner);
        return QuoteContactData.fromJson(data);
      }
      return const QuoteContactData();
    } catch (_) {
      return const QuoteContactData();
    }
  }

  /// Crea una cotizacion especializada.
  ///
  /// [authenticated] selecciona el endpoint: con sesion `POST /specialized-quotes`
  /// o el publico `/specialized-quotes/public` (con rate limit por IP).
  /// Los tipos validos: SOPORTE | INFRAESTRUCTURA | ESPECIALIZADAS | ELEVACION.
  /// Devuelve [CreatedQuote] con el folio asignado (COT-2026-XXXX).
  Future<CreatedQuote> createQuote({
    required String serviceType,
    required String serviceName,
    required String clientName,
    required String clientEmail,
    String? clientPhone,
    String? companyName,
    String? description,
    String? projectType,
    String? urgency,
    String? budget,
    String? preferredDate,
    String? location,
    bool authenticated = true,
  }) async {
    final body = <String, dynamic>{
      'serviceType': serviceType,
      'serviceName': serviceName,
      'clientName': clientName,
      'clientEmail': clientEmail,
      if (clientPhone != null && clientPhone.trim().isNotEmpty)
        'clientPhone': clientPhone.trim(),
      if (companyName != null && companyName.trim().isNotEmpty)
        'companyName': companyName.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (projectType != null && projectType.trim().isNotEmpty)
        'projectType': projectType.trim(),
      if (urgency != null && urgency.trim().isNotEmpty)
        'urgency': urgency.trim(),
      if (budget != null && budget.trim().isNotEmpty) 'budget': budget.trim(),
      'preferredDate':
          preferredDate != null && preferredDate.isNotEmpty ? preferredDate : null,
      if (location != null && location.trim().isNotEmpty)
        'location': location.trim(),
    };

    final endpoint = authenticated
        ? ApiEndpoints.specializedQuotes
        : '${ApiEndpoints.specializedQuotes}/public';

    try {
      final resp = await _dio.post(endpoint, data: body);
      final data = resp.data;
      if (data is Map<String, dynamic>) {
        final inner = data['data'];
        if (inner is Map<String, dynamic> && inner['quoteNumber'] != null) {
          return CreatedQuote.fromJson(inner);
        }
        return CreatedQuote.fromJson(data);
      }
      throw Exception('Respuesta invalida del servidor');
    } on DioException catch (e) {
      // Fallback: si el token expiro y el usuario sigue en el formulario,
      // intentamos la variante publica (mismo formulario, tope por IP).
      final status = e.response?.statusCode;
      if (authenticated && (status == 401 || status == 403)) {
        try {
          final resp = await _dio.post(
            '${ApiEndpoints.specializedQuotes}/public',
            data: body,
          );
          final data = resp.data;
          if (data is Map<String, dynamic>) {
            return CreatedQuote.fromJson(data);
          }
        } on DioException {
          // Cascada al rethrow: se reporta el error autenticado original.
        }      }
      rethrow;
    }
  }
}

/// Provider del repositorio de cotizaciones especializadas.
final quoteRepositoryProvider = Provider<QuoteRepository>((ref) {
  return QuoteRepository(ref.read(dioProvider));
});

/// Provider de los datos de contacto precargados (autoDispose para que
/// recargue cada vez que se abre el formulario).
final quoteContactDataProvider =
    FutureProvider.autoDispose<QuoteContactData>((ref) {
  return ref.watch(quoteRepositoryProvider).contactData();
});
