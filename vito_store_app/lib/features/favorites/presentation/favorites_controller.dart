import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product.dart';
import '../data/favorites_repository.dart';

/// Controlador de favoritos (wishlist) con sincronizacion al backend.
///
/// - Mantiene un Set de IDs en memoria para acceso inmediato (UI responsiva).
/// - Cuando el usuario esta autenticado, sincroniza con el backend via
///   [FavoritesRepository] (POST/DELETE /api/wishlist).
/// - Al iniciar sesion, carga los favoritos del backend.
/// - Si no esta autenticado, opera solo en memoria.
class FavoritesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    // Cargar favoritos del backend si el usuario esta autenticado.
    Future.microtask(_syncFromBackend);
    return <String>{};
  }

  FavoritesRepository get _repo =>
      ref.read(favoritesRepositoryProvider);

  bool _isAuthenticated() =>
      ref.read(authControllerProvider).isAuthenticated;

  Future<void> _syncFromBackend() async {
    if (!_isAuthenticated()) return;
    try {
      final ids = await _repo.getFavoriteIds();
      if (ids.isNotEmpty) {
        state = {...state, ...ids};
      }
    } catch (_) {}
  }

  bool isFavorite(String id) => state.contains(id);

  void toggle(String id) {
    final next = Set<String>.from(state);
    if (!next.add(id)) {
      next.remove(id);
      // Remover del backend.
      if (_isAuthenticated()) _repo.removeFavorite(id);
    } else {
      // Agregar al backend.
      if (_isAuthenticated()) _repo.addFavorite(id);
    }
    state = next;
  }

  void remove(String id) {
    final next = Set<String>.from(state)..remove(id);
    state = next;
    if (_isAuthenticated()) _repo.removeFavorite(id);
  }

  /// Recarga los favoritos desde el backend (pull-to-refresh).
  Future<void> refresh() async {
    await _syncFromBackend();
  }
}

/// Provider de ids de productos favoritos.
final favoritesProvider =
    NotifierProvider<FavoritesNotifier, Set<String>>(FavoritesNotifier.new);

/// Provider async que resuelve los [Product] favoritos actuales consultando
/// el repositorio por cada id. Se invalida cuando cambian los ids.
final favoriteProductsProvider = FutureProvider<List<Product>>((ref) async {
  final ids = ref.watch(favoritesProvider);
  final repo = ref.read(productRepositoryProvider);
  final products = <Product>[];
  for (final id in ids) {
    try {
      products.add(await repo.getById(id));
    } catch (_) {
      // Si un producto ya no existe, se omite silenciosamente.
    }
  }
  return products;
});
