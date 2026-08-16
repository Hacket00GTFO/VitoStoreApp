import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/api_config.dart';
import '../../../shared/providers/providers.dart';
import '../domain/service.dart';

/// Repositorio de servicios. Consume `/api/services`.
class ServiceRepository {
  ServiceRepository(this._dio);

  final Dio _dio;

  Future<List<Service>> list() async {
    final resp = await _dio.get(ApiEndpoints.services);
    final data = resp.data;
    final List<dynamic> items = data is List
        ? data
        : (data['data'] as List?) ?? (data['services'] as List?) ?? [];
    return items.map((e) => Service.fromJson(e as Map<String, dynamic>)).toList();
  }
}

/// Provider de [ServiceRepository].
final serviceRepositoryProvider = Provider<ServiceRepository>((ref) {
  return ServiceRepository(ref.read(dioProvider));
});

/// Provider async de la lista de servicios.
final servicesListProvider = FutureProvider<List<Service>>((ref) async {
  return ref.read(serviceRepositoryProvider).list();
});
