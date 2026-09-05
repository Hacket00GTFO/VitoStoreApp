import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/app_strings.dart';
import '../../../shared/widgets/state_view.dart';
import '../../cart/presentation/cart_controller.dart';
import '../../products/data/category_repository.dart';
import '../../products/domain/product.dart';
import '../../products/presentation/product_card.dart';
import '../../products/presentation/products_catalog_controller.dart';

/// Pagina de Tienda (vista ecommerce).
///
/// Barra de busqueda, filtros (drawer/sheet) y grid de productos con badges
/// de descuento. Usa [ProductRepository] via [storeCatalogProvider].
class StorePage extends ConsumerStatefulWidget {
  const StorePage({super.key});

  @override
  ConsumerState<StorePage> createState() => _StorePageState();
}

class _StorePageState extends ConsumerState<StorePage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _submitSearch() {
    final text = _searchController.text.trim();
    ref.read(storeCatalogProvider.notifier).setSearch(text.isEmpty ? null : text);
  }

  void _openFilters() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _StoreFiltersSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(storeCatalogProvider);
    final showLoading = catalog.initialLoading && catalog.error == null;
    final cartCount = ref.watch(cartControllerProvider.select((c) => c.totalQuantity));

    return Scaffold(
      appBar: AppBar(
        title: Text(ref.tr('store')),
        actions: [
          IconButton(
            tooltip: ref.tr('filters'),
            icon: const Icon(LucideIcons.slidersHorizontal),
            onPressed: _openFilters,
          ),
          IconButton(
            tooltip: ref.tr('cart'),
            icon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              child: const Icon(LucideIcons.shoppingCart),
            ),
            onPressed: () => context.push('/carrito'),
          ),
          IconButton(
            tooltip: ref.tr('favorites'),
            icon: const Icon(LucideIcons.heart),
            onPressed: () => context.push('/favoritos'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submitSearch(),
              decoration: InputDecoration(
                hintText: '${ref.tr('search')} productos...',
                prefixIcon: const Icon(LucideIcons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        tooltip: ref.tr('clearFilters'),
                        icon: const Icon(LucideIcons.x),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(storeCatalogProvider.notifier)
                              .setSearch(null);
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              ),
            ),
          ),
          Expanded(
            child: showLoading
                ? const LoadingState()
                : (catalog.error != null && catalog.items.isEmpty
                    ? ErrorState(
                        message: catalog.error!,
                        onRetry: () =>
                            ref.read(storeCatalogProvider.notifier).refresh(),
                      )
                    : (catalog.items.isEmpty
                        ? EmptyState(
                            message:
                                'No se encontraron productos para tu busqueda',
                            icon: LucideIcons.search,
                            actionLabel: ref.tr('retry'),
                            onAction: () =>
                                ref.read(storeCatalogProvider.notifier).refresh(),
                          )
                        : _StoreGrid(state: catalog))),
          ),
        ],
      ),
    );
  }
}

class _StoreGrid extends ConsumerStatefulWidget {
  const _StoreGrid({required this.state});

  final ProductsCatalogState state;

  @override
  ConsumerState<_StoreGrid> createState() => _StoreGridState();
}

class _StoreGridState extends ConsumerState<_StoreGrid> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_controller.position.pixels >=
        _controller.position.maxScrollExtent - 200) {
      ref.read(storeCatalogProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return RefreshIndicator(
      onRefresh: () => ref.read(storeCatalogProvider.notifier).refresh(),
      child: GridView.builder(
        controller: _controller,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.items.length) {
            return const Center(child: CircularProgressIndicator());
          }
          final Product p = state.items[index];
          return ProductCard(product: p);
        },
      ),
    );
  }
}

class _StoreFiltersSheet extends ConsumerWidget {
  const _StoreFiltersSheet();

  static const _sortOptions = <(String, String)>[
    ('recent', 'Mas recientes'),
    ('price-asc', 'Precio: menor a mayor'),
    ('price-desc', 'Precio: mayor a menor'),
    ('name-asc', 'Nombre: A-Z'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(storeCatalogProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.slidersHorizontal),
                const SizedBox(width: 8),
                Text(ref.tr('filters'), style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    ref.read(storeCatalogProvider.notifier).setCategory(null);
                    ref.read(storeCatalogProvider.notifier).setSort(null);
                    Navigator.pop(context);
                  },
                  child: Text(ref.tr('clearFilters')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(ref.tr('category'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            categoriesAsync.when(
              data: (cats) => Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Todas'),
                    selected: catalog.category == null,
                    onSelected: (_) {
                      ref
                          .read(storeCatalogProvider.notifier)
                          .setCategory(null);
                    },
                  ),
                  for (final c in cats)
                    ChoiceChip(
                      label: Text(c.name),
                      selected: catalog.category == c.slug ||
                          catalog.category == c.id,
                      onSelected: (_) {
                        ref
                            .read(storeCatalogProvider.notifier)
                            .setCategory(c.slug ?? c.id);
                      },
                    ),
                ],
              ),
              loading: () => const SizedBox(
                height: 32,
                width: 32,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (e, _) => Text('No se pudieron cargar categorias',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            const SizedBox(height: 16),
            Text(ref.tr('sortBy'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final (value, label) in _sortOptions)
                  ChoiceChip(
                    label: Text(label),
                    selected: catalog.sort == value,
                    onSelected: (_) {
                      ref
                          .read(storeCatalogProvider.notifier)
                          .setSort(value);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.check),
                label: const Text('Aplicar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
