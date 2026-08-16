import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../products/data/product_repository.dart';
import '../../products/domain/product.dart';

/// Controlador de favoritos en memoria (Set de ids).
///
/// La sincronizacion con el backend (wishlist API) es Fase 4+.
/// Por ahora se mantiene un estado simple en memoria que sobrevive mientras
/// la app esta viva (Riverpod lo conserva).
class FavoritesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  bool isFavorite(String id) => state.contains(id);

  void toggle(String id) {
    final next = Set<String>.from(state);
    if (!next.add(id)) {
      next.remove(id);
    }
    state = next;
  }

  void remove(String id) {
    final next = Set<String>.from(state)..remove(id);
    state = next;
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
