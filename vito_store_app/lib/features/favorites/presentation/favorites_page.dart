import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/app_strings.dart';
import '../../../shared/widgets/state_view.dart';
import '../../products/presentation/product_card.dart';
import 'favorites_controller.dart';

/// Pagina de Favoritos (Wishlist).
///
/// Grid de productos favoritos con estado vacio. Sincroniza con el backend
/// via [FavoritesRepository] cuando el usuario esta autenticado.
class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoriteProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(ref.tr('favorites')),
        actions: [
          IconButton(
            tooltip: ref.tr('store'),
            icon: const Icon(LucideIcons.shoppingBag),
            onPressed: () => context.push('/tienda'),
          ),
        ],
      ),
      body: StateView(
        asyncValue: favoritesAsync,
        emptyMessage:
            '${ref.tr('emptyFavorites')}\nToca el corazon en un producto para guardarlo aqui.',
        emptyIcon: LucideIcons.heart,
        emptyActionLabel: 'Explorar tienda',
        emptyAction: () => context.push('/tienda'),
        onRetry: () => ref.invalidate(favoriteProductsProvider),
        builder: (products) {
          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(favoritesProvider.notifier).refresh();
              ref.invalidate(favoriteProductsProvider);
            },
            child: GridView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return Dismissible(
                key: ValueKey(product.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  color: Theme.of(context).colorScheme.error,
                  padding: const EdgeInsets.only(right: 24),
                  child: const Icon(LucideIcons.trash2, color: Colors.white),
                ),
                onDismissed: (_) {
                  ref
                      .read(favoritesProvider.notifier)
                      .remove(product.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${product.name} quitado de favoritos'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: ProductCard(product: product),
              );
            },
            ),
          );
        },
      ),
    );
  }
}
