import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cart_repository.dart';
import '../domain/cart_item.dart';

/// Estado del carrito.
class CartState {
  CartState({
    this.items = const [],
    this.isLoading = false,
    this.isUpdating = false,
    this.error,
  });

  final List<CartItem> items;
  final bool isLoading;
  final bool isUpdating;
  final String? error;

  /// Cantidad total de items (suma de cantidades).
  int get totalQuantity => items.fold(0, (sum, e) => sum + e.quantity);

  /// Monto total del carrito (suma de subtotales).
  double get totalAmount => items.fold(0.0, (sum, e) => sum + e.subtotal);

  /// Subtotal (sin envio/impuestos).
  double get subtotal => totalAmount;

  bool get isEmpty => items.isEmpty;

  CartState copyWith({
    List<CartItem>? items,
    bool? isLoading,
    bool? isUpdating,
    String? error,
  }) {
    return CartState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isUpdating: isUpdating ?? this.isUpdating,
      error: error,
    );
  }
}

/// Controller del carrito. Usa `Notifier` (Riverpod 3.x).
///
/// Replica el `useCart` hook de la web: load, add, update, remove, clear.
class CartController extends Notifier<CartState> {
  @override
  CartState build() {
    // Carga automatica al construir el provider.
    Future.microtask(() => load());
    return CartState(isLoading: true);
  }

  CartRepository get _repo => ref.read(cartRepositoryProvider);

  /// Carga el carrito desde el backend.
  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await _repo.getCart();
      state = CartState(items: items);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Agrega un producto al carrito.
  Future<void> addProduct({required String productId, int quantity = 1}) async {
    state = state.copyWith(isUpdating: true, error: null);
    try {
      final items = await _repo.addItem(productId: productId, quantity: quantity);
      state = CartState(items: items);
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
      final items =
          await _repo.updateQuantity(productId: productId, quantity: quantity);
      state = CartState(items: items);
    } catch (e) {
      state = state.copyWith(isUpdating: false, error: e.toString());
    }
  }

  /// Elimina un item del carrito.
  Future<void> remove(String productId) async {
    state = state.copyWith(isUpdating: true, error: null);
    try {
      final items = await _repo.removeItem(productId);
      state = CartState(items: items);
    } catch (e) {
      state = state.copyWith(isUpdating: false, error: e.toString());
    }
  }

  /// Vacia el carrito completo.
  Future<void> clear() async {
    state = state.copyWith(isUpdating: true, error: null);
    try {
      await _repo.clearCart();
      state = CartState(items: []);
    } catch (e) {
      state = state.copyWith(isUpdating: false, error: e.toString());
    }
  }
}

/// Provider del controller del carrito.
final cartControllerProvider =
    NotifierProvider<CartController, CartState>(CartController.new);
