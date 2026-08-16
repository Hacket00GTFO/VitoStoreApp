import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../shared/widgets/state_view.dart';
import '../../products/presentation/product_card.dart';
import 'favorites_controller.dart';

/// Pagina de Favoritos (Wishlist).
///
/// Grid de productos favoritos con estado vacio. Por ahora usa un provider
/// en memoria ([favoritesProvider]); la sincronizacion con backend es Fase 4+.
class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoriteProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favoritos'),
        actions: [
          IconButton(
            tooltip: 'Tienda',
            icon: const Icon(LucideIcons.shoppingBag),
            onPressed: () => context.push('/tienda'),
          ),
        ],
      ),
      body: StateView(
        asyncValue: favoritesAsync,
        emptyMessage:
            'Aun no tienes favoritos.\nToca el corazon en un producto para guardarlo aqui.',
        emptyIcon: LucideIcons.heart,
        emptyActionLabel: 'Explorar tienda',
        emptyAction: () => context.push('/tienda'),
        onRetry: () => ref.invalidate(favoriteProductsProvider),
        builder: (products) {
          return GridView.builder(
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
          );
        },
      ),
    );
  }
}
