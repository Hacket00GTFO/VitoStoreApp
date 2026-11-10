import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/api_config.dart';
import '../../../shared/providers/providers.dart';
import '../domain/product.dart';

/// Repositorio de productos. Consume `/api/products` (igual que la web).
///
/// Contrato real del backend: filtro/paginacion via `skip`, `take`,
/// `categoryId`, `q`, `inStock`, `keywords`, `sort` (name|price-asc|price-desc)
/// y `subcategory`; responde `{products, total, skip, take}`.
class ProductRepository {
  ProductRepository(this._dio);

  final Dio _dio;

  /// Lista de productos con paginacion real y filtros opcionales.
  ///
  /// `category` recibe el **slug** de la categoria y se traduce a
  /// `categoryId` (el backend ignora el antiguo `category=`).
  Future<({List<Product> products, int total})> list({
    String? category,
    String? categoryId,
    String? search,
    String? sort,
    int limit = 20,
    int offset = 0,
  }) async {
    final params = <String, dynamic>{
      'take': limit,
      'skip': offset,
      if (categoryId != null) 'categoryId': categoryId,
      if (categoryId == null && category != null) 'category': category,
      if (search != null) 'q': search,
      // `name` es el orden por defecto del backend: no enviarlo.
      if (sort != null && sort != 'name') 'sort': sort,
    };
    final resp = await _dio.get(ApiEndpoints.products, queryParameters: params);
    final data = resp.data;
    final List<dynamic> items = data is List
        ? data
        : (data is Map<String, dynamic>
            ? (data['products'] as List?) ?? (data['data'] as List?) ?? []
            : const []);
    final total = data is Map<String, dynamic>
        ? (data['total'] as num?)?.toInt() ?? items.length
        : items.length;
    final products =
        items.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
    return (products: products, total: total);
  }

  /// Producto por ID.
  Future<Product> getById(String id) async {
    final resp = await _dio.get('${ApiEndpoints.products}/$id');
    final data = resp.data;
    final json = data is Map && data.containsKey('data') ? data['data'] : data;
    return Product.fromJson(json as Map<String, dynamic>);
  }

  /// Productos destacados (para el home).
  ///
  /// El backend tiene un endpoint dedicado `GET /products/featured?limit=`
  /// (el query `featured=` de la lista se ignora).
  Future<List<Product>> featured({int limit = 10}) async {
    final resp = await _dio.get(
      '${ApiEndpoints.products}/featured',
      queryParameters: {'limit': limit},
    );
    final data = resp.data;
    final List<dynamic> items = data is List
        ? data
        : (data is Map<String, dynamic>
            ? (data['products'] as List?) ?? (data['data'] as List?) ?? []
            : const []);
    return items.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
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
