import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/api_config.dart';
import '../../../shared/providers/providers.dart';
import '../domain/category.dart';

/// Repositorio de categorias. Consume `/api/categories` (igual que la web).
class CategoryRepository {
  CategoryRepository(this._dio);

  final Dio _dio;

  /// Lista de categorias.
  Future<List<Category>> listCategories() async {
    final resp = await _dio.get(ApiEndpoints.categories);
    final data = resp.data;
    final List<dynamic> items = data is List
        ? data
        : (data['data'] as List?) ?? (data['categories'] as List?) ?? [];
    return items.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
  }
}

/// Provider de [CategoryRepository].
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.read(dioProvider));
});

/// Provider async que entrega la lista de categorias.
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  return ref.read(categoryRepositoryProvider).listCategories();
});
