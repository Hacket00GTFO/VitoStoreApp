import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/api_config.dart';
import '../../../shared/providers/providers.dart';
import '../domain/product.dart';

/// Repositorio de productos. Consume `/api/products` (igual que la web).
class ProductRepository {
  ProductRepository(this._dio);

  final Dio _dio;

  /// Lista de productos con paginacion y filtros opcionales.
  Future<List<Product>> list({
    String? category,
    String? search,
    bool? featured,
    String? sort,
    int limit = 20,
    int offset = 0,
  }) async {
    final params = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      if (category != null) 'category': category,
      if (search != null) 'search': search,
      if (featured != null) 'featured': featured,
      if (sort != null) 'sort': sort,
    };
    final resp = await _dio.get(ApiEndpoints.products, queryParameters: params);
    final data = resp.data;
    final List<dynamic> items = data is List
        ? data
        : (data['data'] as List?) ?? (data['products'] as List?) ?? [];
    return items.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Producto por ID.
  Future<Product> getById(String id) async {
    final resp = await _dio.get('${ApiEndpoints.products}/$id');
    final data = resp.data;
    final json = data is Map && data.containsKey('data') ? data['data'] : data;
    return Product.fromJson(json as Map<String, dynamic>);
  }

  /// Productos destacados (para home).
  Future<List<Product>> featured({int limit = 10}) async {
    return list(featured: true, limit: limit);
  }
}

/// Provider de [ProductRepository].
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(ref.read(dioProvider));
});

/// Provider async de productos destacados (para el home).
final featuredProductsProvider = FutureProvider<List<Product>>((ref) async {
  return ref.read(productRepositoryProvider).featured(limit: 10);
});
