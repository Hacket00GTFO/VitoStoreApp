import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../shared/widgets/state_view.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../cart/presentation/cart_controller.dart';
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

class _DetailContent extends ConsumerStatefulWidget {
  const _DetailContent({
    required this.product,
    required this.heroTag,
    required this.relatedAsync,
  });

  final Product product;
  final String heroTag;
  final AsyncValue<List<Product>> relatedAsync;

  @override
  ConsumerState<_DetailContent> createState() => _DetailContentState();
}

class _DetailContentState extends ConsumerState<_DetailContent> {
  int _quantity = 1;
  bool _added = false;

  Product get product => widget.product;
  String get heroTag => widget.heroTag;

  Future<void> _addToCart() async {
    final ref = this.ref;
    final auth = ref.read(authControllerProvider);
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Inicia sesion para agregar productos al carrito'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Iniciar sesion',
            onPressed: () => context.push(
              '/login?redirect=${Uri.encodeComponent('/productos/${product.categoryName ?? product.categoryId ?? 'producto'}/${product.id}')}',
            ),
          ),
        ),
      );
      return;
    }
    await ref.read(cartControllerProvider.notifier).addProduct(
          productId: product.id,
          quantity: _quantity,
        );
    if (!mounted) return;
    // Verificar si hubo error en la operacion del carrito.
    final cartState = ref.read(cartControllerProvider);
    if (cartState.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al agregar al carrito: ${cartState.error}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }
    setState(() => _added = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_quantity == 1
            ? '${product.name} agregado al carrito'
            : '$_quantity x ${product.name} agregados al carrito'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Ver carrito',
          onPressed: () => context.push('/carrito'),
        ),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _added = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final favs = ref.watch(favoritesProvider);
    final isFav = favs.contains(product.id);
    final cart = ref.watch(cartControllerProvider);
    final outOfStock = product.stock != null && product.stock! <= 0;

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
                // Stepper de cantidad + boton agregar al carrito.
                Row(
                  children: [
                    _QtyStepper(
                      value: _quantity,
                      minValue: 1,
                      maxValue: (product.stock != null && product.stock! > 0)
                          ? product.stock!
                          : 99,
                      onChanged: outOfStock
                          ? null
                          : (v) => setState(() => _quantity = v),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: outOfStock || cart.isUpdating
                              ? null
                              : _addToCart,
                          icon: _added
                              ? const Icon(LucideIcons.check)
                              : (cart.isUpdating
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(LucideIcons.shoppingCart)),
                          label: Text(_added
                              ? 'Agregado'
                              : (cart.isUpdating
                                  ? 'Agregando...'
                                  : 'Agregar al carrito')),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Productos relacionados',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        widget.relatedAsync.when(
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
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => _openFullScreen(context, images, i),
              child: CachedNetworkImage(
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
        ),
        // Indicador de zoom (toca para ampliar).
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.zoomIn, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text('Toca para ampliar',
                    style: TextStyle(color: Colors.white, fontSize: 11)),
              ],
            ),
          ),
        ),
        if (images.length > 1) ...[
          // Contador de imagenes (i+1 / N).
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${_index + 1} / ${images.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
          // Dots indicator.
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
      ],
    );
  }

  void _openFullScreen(BuildContext context, List<String> images, int initial) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => _FullScreenImageViewer(
          images: images,
          initialIndex: initial,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }
}

/// Visor full-screen de imagenes con zoom/pan (InteractiveViewer) y swipe
/// horizontal entre imagenes. Replica el lightbox del ProductDetailPage web.
class _FullScreenImageViewer extends StatefulWidget {
  const _FullScreenImageViewer({required this.images, required this.initialIndex});

  final List<String> images;
  final int initialIndex;

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late final PageController _controller;
  late int _index;
  final _transformationControllers = <int, TransformationController>{};

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.images.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final c in _transformationControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TransformationController _controllerFor(int i) {
    return _transformationControllers.putIfAbsent(i, TransformationController.new);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => InteractiveViewer(
              transformationController: _controllerFor(i),
              minScale: 0.8,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: widget.images[i],
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(LucideIcons.imageOff, size: 64, color: Colors.white54),
                ),
              ),
            ),
          ),
          // Barra superior con cierre y contador.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.x, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    if (widget.images.length > 1)
                      Text(
                        '${_index + 1} / ${widget.images.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stepper de cantidad (+/-) con valor minimo y maximo.
/// Touch targets >=36dp (compacto para fila de accion de producto).
class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.onChanged,
  });

  final int value;
  final int minValue;
  final int maxValue;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = onChanged == null;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(context, LucideIcons.minus, () => onChanged?.call((value - 1).clamp(minValue, maxValue)), disabled),
          SizedBox(
            width: 36,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          _btn(context, LucideIcons.plus, () => onChanged?.call((value + 1).clamp(minValue, maxValue)), disabled),
        ],
      ),
    );
  }

  Widget _btn(BuildContext context, IconData icon, VoidCallback? onTap, bool disabled) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Material(
        color: Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: disabled ? null : onTap,
          child: Icon(icon, size: 16),
        ),
      ),
    );
  }
}
