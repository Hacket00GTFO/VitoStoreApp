import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/providers.dart';

/// Repositorio de favoritos (wishlist). Consume `/api/wishlist`.
///
/// Sincroniza los productos favoritos del usuario con el backend.
/// Si el usuario no esta autenticado, las operaciones son no-op
/// (los favoritos se mantienen solo en memoria).
class FavoritesRepository {
  FavoritesRepository(this._dio);

  final Dio _dio;

  String get _endpoint => '${_dio.options.baseUrl.split('/api')[0]}/api/wishlist';

  /// Obtiene la lista de IDs de productos favoritos del backend.
  Future<List<String>> getFavoriteIds() async {
    try {
      final resp = await _dio.get(_endpoint);
      final data = resp.data;
      final List<dynamic> items = data is List
          ? data
          : (data is Map<String, dynamic>
              ? (data['data'] as List?) ?? (data['items'] as List?) ?? (data['productIds'] as List?) ?? []
              : []);
      return items.map((e) {
        if (e is String) return e;
        if (e is Map<String, dynamic>) return e['productId']?.toString() ?? e['id']?.toString() ?? '';
        return e.toString();
      }).where((id) => id.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  /// Anade un producto a favoritos en el backend.
  Future<void> addFavorite(String productId) async {
    try {
      await _dio.post(_endpoint, data: {'productId': productId});
    } catch (_) {
      // Silencioso: el estado local se actualiza de todas formas.
    }
  }

  /// Quita un producto de favoritos en el backend.
  Future<void> removeFavorite(String productId) async {
    try {
      await _dio.delete('$_endpoint/$productId');
    } catch (_) {
      // Silencioso: el estado local se actualiza de todas formas.
    }
  }

  /// Sincroniza todos los favoritos locales con el backend (bulk).
  Future<void> syncFavorites(List<String> productIds) async {
    try {
      await _dio.put(_endpoint, data: {'productIds': productIds});
    } catch (_) {
      // Silencioso.
    }
  }
}

/// Provider del repositorio de favoritos.
final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return FavoritesRepository(ref.read(dioProvider));
});
