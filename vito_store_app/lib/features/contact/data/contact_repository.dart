import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/api_config.dart';
import '../../../shared/providers/providers.dart';

/// Repositorio de contacto. Consume `POST /api/contact`
/// (mismo contrato REST que el frontend web).
class ContactRepository {
  ContactRepository(this._dio);

  final Dio _dio;

  /// Envia un mensaje de contacto al backend.
  /// Retorna `true` si el envio fue exitoso.
  Future<bool> sendMessage({
    required String name,
    required String email,
    String? phone,
    required String subject,
    required String message,
  }) async {
    final resp = await _dio.post(ApiEndpoints.contact, data: {
      'name': name,
      'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      'subject': subject,
      'message': message,
    });
    // Cualquier 2xx se considera exito.
    return resp.statusCode != null && resp.statusCode! >= 200 && resp.statusCode! < 300;
  }
}

/// Provider de [ContactRepository].
final contactRepositoryProvider = Provider<ContactRepository>((ref) {
  return ContactRepository(ref.watch(dioProvider));
});
