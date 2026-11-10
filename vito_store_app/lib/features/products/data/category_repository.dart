import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/api_config.dart';
import '../../../shared/providers/providers.dart';
import '../domain/category.dart';

/// Repositorio de categorias de productos.
///
/// El backend no publica una lista de categorias (`GET /products/categories`
/// es solo ADMIN y `GET /categories` no existe), por lo que se replica la
/// lista estatica del catálogo (`productCategories` de la web) y se enriquece
/// con los conteos reales de `GET /products/counts` → `{total, byCategory}`.
///
/// El filtro de la tienda usa `?categoryId=<id>`; los ids del catalogo
/// estatico coinciden con los de la BD (verificado contra el backend real).
class CategoryRepository {
  CategoryRepository(this._dio);

  final Dio _dio;

  /// Lista de categorias con conteo de productos (0 si la categoria aun no
  /// tiene productos publicados; en ese caso `productCount` queda null para
  /// que la UI no muestre "0 productos").
  Future<List<Category>> listCategories() async {
    final counts = <String, int>{};
    try {
      final resp = await _dio.get('${ApiEndpoints.products}/counts');
      final data = resp.data;
      if (data is Map<String, dynamic>) {
        final raw = data['byCategory'];
        if (raw is Map) {
          raw.forEach((key, value) {
            final n = value is num ? value.toInt() : int.tryParse('$value');
            if (key is String && n != null) counts[key] = n;
          });
        }
      }
    } on DioException {
      // Sin conteos la UI sigue funcional con la lista estatica.
    }
    return [
      for (final base in productCategories)
        Category(
          id: base.id,
          name: base.name,
          slug: base.slug,
          description: base.description,
          productCount: (counts[base.id] ?? 0) == 0
              ? null
              : counts[base.id],
        ),
    ];
  }
}

/// Provider de [CategoryRepository].
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.read(dioProvider));
});

/// Provider async que entrega la lista de categorias con conteos reales.
final categoriesProvider = FutureProvider<List<Category>>((ref) {
  return ref.read(categoryRepositoryProvider).listCategories();
});
