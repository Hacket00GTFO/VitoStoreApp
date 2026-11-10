import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/product_repository.dart';
import '../domain/product.dart';

/// Estado del catalogo paginado de productos.
class ProductsCatalogState {
  const ProductsCatalogState({
    this.items = const [],
    this.category,
    this.search,
    this.sort,
    this.limit = 20,
    this.offset = 0,
    this.total = 0,
    this.hasReachedMax = false,
    this.isLoadingMore = false,
    this.error,
    this.initialLoading = true,
  });

  final List<Product> items;
  final String? category;
  final String? search;
  final String? sort;
  final int limit;
  final int offset;
  /// Total de resultados del filtro actual (informado por el backend).
  final int total;
  final bool hasReachedMax;
  final bool isLoadingMore;
  final String? error;
  final bool initialLoading;

  ProductsCatalogState copyWith({
    List<Product>? items,
    String? category,
    String? search,
    String? sort,
    int? limit,
    int? offset,
    int? total,
    bool? hasReachedMax,
    bool? isLoadingMore,
    String? error,
    bool? initialLoading,
    bool clearError = false,
    bool clearCategory = false,
    bool clearSearch = false,
    bool clearSort = false,
  }) {
    return ProductsCatalogState(
      items: items ?? this.items,
      category: clearCategory ? null : (category ?? this.category),
      search: clearSearch ? null : (search ?? this.search),
      sort: clearSort ? null : (sort ?? this.sort),
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
      total: total ?? this.total,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      initialLoading: initialLoading ?? this.initialLoading,
    );
  }
}

/// Logica compartida del catalogo paginado (refresh, infinite scroll,
/// filtros). Se aplica como mixin sobre [Notifier] para reutilizarla en
/// multiples providers independientes (Productos y Tienda).
base mixin CatalogLogic on Notifier<ProductsCatalogState> {
  late final ProductRepository repo;

  void initCatalog() {
    repo = ref.read(productRepositoryProvider);
  }

  Future<void> refresh() async {
    state = state.copyWith(
      offset: 0,
      hasReachedMax: false,
      initialLoading: state.items.isEmpty,
      items: state.items.isEmpty ? const [] : state.items,
      clearError: true,
    );
    try {
      final (:products, :total) = await repo.list(
        categoryId: state.category,
        search: state.search,
        sort: state.sort,
        limit: state.limit,
        offset: 0,
      );
      state = ProductsCatalogState(
        items: products,
        category: state.category,
        search: state.search,
        sort: state.sort,
        limit: state.limit,
        offset: products.length,
        total: total,
        hasReachedMax: products.isEmpty || products.length >= total,
        initialLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        initialLoading: false,
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.hasReachedMax || state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final (:products, :total) = await repo.list(
        categoryId: state.category,
        search: state.search,
        sort: state.sort,
        limit: state.limit,
        offset: state.offset,
      );
      state = state.copyWith(
        items: [...state.items, ...products],
        offset: state.offset + products.length,
        total: total,
        hasReachedMax: products.isEmpty || state.items.length + products.length >= total,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  void setCategory(String? category) {
    if (category == state.category) return;
    state = state.copyWith(clearCategory: true, category: category, items: const [], offset: 0);
    refresh();
  }

  void setSearch(String? search) {
    final normalized = (search == null || search.isEmpty) ? null : search;
    if (normalized == state.search) return;
    state = state.copyWith(search: normalized, items: const [], offset: 0);
    refresh();
  }

  void setSort(String? sort) {
    if (sort == state.sort) return;
    state = state.copyWith(clearSort: true, sort: sort, items: const [], offset: 0);
    refresh();
  }
}

/// Notifier para la pagina de Productos.
final class ProductsCatalogNotifier extends Notifier<ProductsCatalogState>
    with CatalogLogic {
  @override
  ProductsCatalogState build() {
    initCatalog();
    Future.microtask(refresh);
    return const ProductsCatalogState();
  }
}

/// Notifier para la pagina de Tienda.
final class StoreCatalogNotifier extends Notifier<ProductsCatalogState>
    with CatalogLogic {
  @override
  ProductsCatalogState build() {
    initCatalog();
    Future.microtask(refresh);
    return const ProductsCatalogState();
  }
}

/// Provider del catalogo para la pagina de Productos.
final productsCatalogProvider =
    NotifierProvider<ProductsCatalogNotifier, ProductsCatalogState>(
        ProductsCatalogNotifier.new);

/// Provider del catalogo para la pagina de Tienda.
final storeCatalogProvider =
    NotifierProvider<StoreCatalogNotifier, ProductsCatalogState>(
        StoreCatalogNotifier.new);
