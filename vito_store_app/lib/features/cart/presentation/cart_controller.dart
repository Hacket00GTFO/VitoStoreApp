import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/cart_repository.dart';
import '../domain/cart_item.dart';

/// Estado del carrito.
class CartState {
  CartState({
    this.items = const [],
    this.totals = const CartTotals(),
    this.isLoading = false,
    this.isUpdating = false,
    this.error,
  });

  final List<CartItem> items;

  /// Totales calculados por el backend (conversión USD→MXN incluida).
  final CartTotals totals;
  final bool isLoading;
  final bool isUpdating;
  final String? error;

  /// Cantidad total de items (suma de cantidades).
  int get totalQuantity =>
      totals.itemCount > 0 ? totals.itemCount : items.fold(0, (s, e) => s + e.quantity);

  /// Monto total del carrito en MXN (segun backend; incluye conversion USD).
  double get totalAmount => totals.totalMXN;

  /// Subtotal en MXN (sin envio; la API ya incluye IVA en los precios).
  double get subtotal => totals.totalMXN;

  bool get isEmpty => items.isEmpty;

  CartState copyWith({
    List<CartItem>? items,
    CartTotals? totals,
    bool? isLoading,
    bool? isUpdating,
    String? error,
  }) {
    return CartState(
      items: items ?? this.items,
      totals: totals ?? this.totals,
      isLoading: isLoading ?? this.isLoading,
      isUpdating: isUpdating ?? this.isUpdating,
      error: error,
    );
  }
}

/// Controller del carrito. Usa `Notifier` (Riverpod 3.x).
///
/// Replica el `CartContext` de la web: solo carga si hay sesión activa y se
/// recarga automáticamente cuando cambia el estado de autenticación.
class CartController extends Notifier<CartState> {
  @override
  CartState build() {
    // Reacciona a login/logout: al autenticarse carga el carrito; al cerrar
    // sesión vuelve al estado vacío sin llamar al backend.
    final isAuthenticated = ref.watch(
      authControllerProvider.select((s) => s.isAuthenticated),
    );
    if (!isAuthenticated) {
      return CartState();
    }
    Future.microtask(() => load());
    return CartState(isLoading: true);
  }

  CartRepository get _repo => ref.read(cartRepositoryProvider);

  /// Carga el carrito desde el backend.
  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final snapshot = await _repo.getCart();
      state = CartState(items: snapshot.items, totals: snapshot.totals);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Agrega un producto al carrito.
  Future<void> addProduct({required String productId, int quantity = 1}) async {
    state = state.copyWith(isUpdating: true, error: null);
    try {
      final snapshot = await _repo.addItem(productId: productId, quantity: quantity);
      state = CartState(items: snapshot.items, totals: snapshot.totals);
    } catch (e) {
      state = state.copyWith(isUpdating: false, error: e.toString());
    }
  }

  /// Actualiza la cantidad de un item.
  Future<void> updateQty({required String productId, required int quantity}) async {
    if (quantity <= 0) {
      await remove(productId);
      return;
    }
    state = state.copyWith(isUpdating: true, error: null);
    try {
      final snapshot =
          await _repo.updateQuantity(productId: productId, quantity: quantity);
      state = CartState(items: snapshot.items, totals: snapshot.totals);
    } catch (e) {
      state = state.copyWith(isUpdating: false, error: e.toString());
    }
  }

  /// Elimina un item del carrito.
  Future<void> remove(String productId) async {
    state = state.copyWith(isUpdating: true, error: null);
    try {
      final snapshot = await _repo.removeItem(productId);
      state = CartState(items: snapshot.items, totals: snapshot.totals);
    } catch (e) {
      state = state.copyWith(isUpdating: false, error: e.toString());
    }
  }

  /// Vacia el carrito completo.
  Future<void> clear() async {
    state = state.copyWith(isUpdating: true, error: null);
    try {
      await _repo.clearCart();
      state = CartState(items: const [], totals: const CartTotals());
    } catch (e) {
      state = state.copyWith(isUpdating: false, error: e.toString());
    }
  }
}

/// Provider del controller del carrito.
final cartControllerProvider =
    NotifierProvider<CartController, CartState>(CartController.new);
