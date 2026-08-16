import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../shared/widgets/state_view.dart';
import '../data/category_repository.dart';
import '../domain/product.dart';
import 'product_card.dart';
import 'products_catalog_controller.dart';

/// Pagina de catalogo de productos.
///
/// Grid con filtros (categoria, orden) en bottom sheet, pull-to-refresh e
/// infinite scroll. Usa [StateView] para loading/error/empty.
class ProductsPage extends ConsumerWidget {
  const ProductsPage({this.category, super.key});

  final String? category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Aplicar la categoria inicial pasada por ruta.
    final catalog = ref.watch(productsCatalogProvider);
    if (category != null && catalog.category != category && catalog.items.isEmpty) {
      Future.microtask(
        () => ref
            .read(productsCatalogProvider.notifier)
            .setCategory(category),
      );
    }

    final showLoading = catalog.initialLoading && catalog.error == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(catalog.category != null
            ? 'Categoria: ${catalog.category}'
            : 'Productos'),
        actions: [
          IconButton(
            tooltip: 'Favoritos',
            icon: const Icon(LucideIcons.heart),
            onPressed: () => context.push('/favoritos'),
          ),
        ],
      ),
      body: showLoading
          ? const LoadingState()
          : (catalog.error != null && catalog.items.isEmpty
              ? ErrorState(
                  message: catalog.error!,
                  onRetry: () => ref
                      .read(productsCatalogProvider.notifier)
                      .refresh(),
                )
              : (catalog.items.isEmpty
                  ? EmptyState(
                      message: 'No se encontraron productos',
                      icon: LucideIcons.packageOpen,
                      actionLabel: 'Reintentar',
                      onAction: () => ref
                          .read(productsCatalogProvider.notifier)
                          .refresh(),
                    )
                  : _ProductGrid(state: catalog))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openFilters(context, ref),
        icon: const Icon(LucideIcons.slidersHorizontal),
        label: const Text('Filtros'),
      ),
    );
  }

  void _openFilters(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _FiltersSheet(),
    );
  }
}

class _ProductGrid extends ConsumerStatefulWidget {
  const _ProductGrid({required this.state});

  final ProductsCatalogState state;

  @override
  ConsumerState<_ProductGrid> createState() => _ProductGridState();
}

class _ProductGridState extends ConsumerState<_ProductGrid> {
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
      ref.read(productsCatalogProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(productsCatalogProvider.notifier).refresh(),
      child: GridView.builder(
        controller: _controller,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
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

class _FiltersSheet extends ConsumerWidget {
  const _FiltersSheet();

  static const _sortOptions = <(String, String)>[
    ('recent', 'Mas recientes'),
    ('price-asc', 'Precio: menor a mayor'),
    ('price-desc', 'Precio: mayor a menor'),
    ('name-asc', 'Nombre: A-Z'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(productsCatalogProvider);
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
                Text('Filtros', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    ref
                        .read(productsCatalogProvider.notifier)
                        .setCategory(null);
                    ref
                        .read(productsCatalogProvider.notifier)
                        .setSort(null);
                    Navigator.pop(context);
                  },
                  child: const Text('Limpiar'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Categoria',
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
                          .read(productsCatalogProvider.notifier)
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
                            .read(
                                productsCatalogProvider.notifier)
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
            Text('Ordenar por', style: Theme.of(context).textTheme.titleMedium),
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
                          .read(productsCatalogProvider.notifier)
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
