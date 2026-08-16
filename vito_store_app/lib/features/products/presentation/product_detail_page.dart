import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../shared/widgets/state_view.dart';
import '../../favorites/presentation/favorites_controller.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';
import 'product_card.dart';

/// Provider que obtiene un producto por id.
final productDetailProvider =
    FutureProvider.family<Product, String>((ref, id) async {
  return ref.read(productRepositoryProvider).getById(id);
});

/// Provider de productos relacionados (misma categoria).
final relatedProductsProvider =
    FutureProvider.family<List<Product>, Product>((ref, product) async {
  if (product.categoryId == null && product.categoryName == null) {
    return <Product>[];
  }
  try {
    final list = await ref.read(productRepositoryProvider).list(
          category: product.categoryName ?? product.categoryId,
          limit: 6,
        );
    return list.where((p) => p.id != product.id).toList();
  } catch (_) {
    return <Product>[];
  }
});

/// Pagina de detalle de producto.
///
/// Galeria (PageView), nombre, SKU, precio, descripcion HTML, boton de
/// agregar al carrito, boton favorito, productos relacionados y animacion
/// Hero en la imagen principal.
class ProductDetailPage extends ConsumerWidget {
  const ProductDetailPage({
    required this.productId,
    this.category,
    super.key,
  });

  final String productId;
  final String? category;

  String get _heroTag => 'product-$productId';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productDetailProvider(productId));

    return Scaffold(
      body: productAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(productDetailProvider(productId)),
        ),
        data: (product) => _DetailContent(
          product: product,
          heroTag: _heroTag,
          relatedAsync: ref.watch(relatedProductsProvider(product)),
        ),
      ),
    );
  }
}

class _DetailContent extends ConsumerWidget {
  const _DetailContent({
    required this.product,
    required this.heroTag,
    required this.relatedAsync,
  });

  final Product product;
  final String heroTag;
  final AsyncValue<List<Product>> relatedAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(favoritesProvider);
    final isFav = favs.contains(product.id);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 360,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: _ImageGallery(product: product, heroTag: heroTag),
          ),
          actions: [
            IconButton(
              tooltip: isFav ? 'Quitar de favoritos' : 'Agregar a favoritos',
              icon: Icon(
                LucideIcons.heart,
                color: isFav
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSurface,
                fill: isFav ? 1.0 : 0.0,
              ),
              onPressed: () =>
                  ref.read(favoritesProvider.notifier).toggle(product.id),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product.categoryName != null)
                  Text(
                    product.categoryName!,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                const SizedBox(height: 4),
                Text(product.name, style: Theme.of(context).textTheme.headlineSmall),
                if (product.sku != null) ...[
                  const SizedBox(height: 4),
                  Text('SKU: ${product.sku}',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
                const SizedBox(height: 12),
                if (product.price != null)
                  Text(
                    '\$${product.price!.toStringAsFixed(2)} ${product.currency}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                if (product.brand != null) ...[
                  const SizedBox(height: 8),
                  Text('Marca: ${product.brand}',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
                if (product.stock != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    product.stock! > 0
                        ? 'Disponible (${product.stock} en stock)'
                        : 'Agotado',
                    style: TextStyle(
                      color: product.stock! > 0
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text('Descripcion',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (product.description != null &&
                    product.description!.isNotEmpty)
                  HtmlWidget(product.description!)
                else
                  Text(
                    'Sin descripcion disponible.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: product.stock != null && product.stock! <= 0
                        ? null
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Agregado al carrito (Fase 5 implementara el carrito)'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                    icon: const Icon(LucideIcons.shoppingCart),
                    label: const Text('Agregar al carrito'),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Productos relacionados',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        relatedAsync.when(
          data: (related) => related.isEmpty
              ? const SliverToBoxAdapter(child: SizedBox.shrink())
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList.separated(
                    itemCount: related.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => SizedBox(
                      height: 240,
                      child: ProductCard(product: related[i]),
                    ),
                  ),
                ),
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
        ),
      ],
    );
  }
}

class _ImageGallery extends StatefulWidget {
  const _ImageGallery({required this.product, required this.heroTag});

  final Product product;
  final String heroTag;

  @override
  State<_ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<_ImageGallery> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.product.images;
    if (images.isEmpty) {
      return Hero(
        tag: widget.heroTag,
        child: Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(
            child: Icon(LucideIcons.imageOff, size: 48),
          ),
        ),
      );
    }

    return Stack(
      children: [
        Hero(
          tag: widget.heroTag,
          child: PageView.builder(
            controller: _controller,
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => CachedNetworkImage(
              imageUrl: images[i],
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Center(child: Icon(LucideIcons.imageOff, size: 48)),
              ),
            ),
          ),
        ),
        if (images.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 8 : 6,
                  height: active ? 8 : 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}
