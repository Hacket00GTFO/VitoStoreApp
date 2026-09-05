import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../favorites/presentation/favorites_controller.dart';
import '../domain/product.dart';

/// Tarjeta de producto para grids y listas.
///
/// Muestra imagen (cached), nombre, precio, icono de favorito y badge de
/// descuento. El target táctil es >=48dp (InkWell envuelve toda la tarjeta).
class ProductCard extends ConsumerWidget {
  const ProductCard({
    required this.product,
    this.heroTag,
    super.key,
  });

  final Product product;
  final String? heroTag;

  String? get _image => product.images.isNotEmpty
      ? product.images.first
      : product.imageUrl;

  String _formatPrice() {
    final price = product.price;
    if (price == null) return '';
    return '\$${price.toStringAsFixed(2)}';
  }

  String? _discountLabel() {
    final d = product.discountPercentage;
    if (d == null || d <= 0) return null;
    return '-${d.toStringAsFixed(0)}%';
  }

  void _goToDetail(BuildContext context) {
    final category = product.categoryName ?? product.categoryId ?? 'producto';
    context.push('/productos/$category/${product.id}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(favoritesProvider);
    final isFav = favs.contains(product.id);
    final discount = _discountLabel();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _goToDetail(context),
        child: Semantics(
          label: '${product.name}, ${_formatPrice()}',
          button: true,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ProductImage(
                      image: _image,
                      heroTag: heroTag ?? 'product-${product.id}',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        if (product.price != null)
                          Text(
                            _formatPrice(),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (discount != null)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      discount,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 0,
                right: 0,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    icon: Icon(
                      isFav ? LucideIcons.heart : LucideIcons.heart,
                      color: isFav
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fill: isFav ? 1.0 : 0.0,
                    ),
                    tooltip: isFav ? 'Quitar de favoritos' : 'Agregar a favoritos',
                    onPressed: () =>
                        ref.read(favoritesProvider.notifier).toggle(product.id),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.image, required this.heroTag});

  final String? image;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    final url = (image != null && image!.isNotEmpty) ? image : null;
    Widget content;
    if (url == null) {
      content = Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(
          child: Icon(LucideIcons.imageOff, size: 32),
        ),
      );
    } else {
      content = CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        httpHeaders: const {'Accept': 'image/webp,image/*,*/*'},
        placeholder: (context, url) => Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (context, url, error) => Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(
            child: Icon(LucideIcons.imageOff, size: 32),
          ),
        ),
      );
    }
    return Hero(
      tag: heroTag,
      child: SizedBox(
        width: double.infinity,
        child: content,
      ),
    );
  }
}
