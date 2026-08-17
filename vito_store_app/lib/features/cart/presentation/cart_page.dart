import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../shared/widgets/state_view.dart';
import 'cart_controller.dart';
import '../domain/cart_item.dart';

/// Formatea un precio con su divisa (MXN por defecto).
String _formatPrice(double amount, [String currency = 'MXN']) {
  return '\$${amount.toStringAsFixed(2)} $currency';
}

/// Pagina de carrito.
///
/// Lista de items con steppers de cantidad, boton de eliminar, resumen
/// (subtotal + total) y boton de checkout. Estado vacio con CTA.
class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carrito'),
        actions: [
          if (cart.items.isNotEmpty && !cart.isUpdating)
            IconButton(
              icon: const Icon(LucideIcons.trash2),
              tooltip: 'Vaciar carrito',
              onPressed: () => _confirmClear(context, ref),
            ),
        ],
      ),
      body: _buildBody(context, ref, cart),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, CartState cart) {
    if (cart.isLoading) {
      return const LoadingState(message: 'Cargando carrito...');
    }

    if (cart.error != null && cart.items.isEmpty) {
      return ErrorState(
        message: cart.error!,
        onRetry: () => ref.read(cartControllerProvider.notifier).load(),
      );
    }

    if (cart.isEmpty) {
      return EmptyState(
        icon: LucideIcons.shoppingCart,
        message: 'Tu carrito esta vacio',
        actionLabel: 'Explorar productos',
        onAction: () => context.go('/tienda'),
      );
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(cartControllerProvider.notifier).load(),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: cart.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _CartItemTile(
                  item: cart.items[index],
                  isUpdating: cart.isUpdating,
                  onIncrement: (item) => ref
                      .read(cartControllerProvider.notifier)
                      .updateQty(productId: item.productId, quantity: item.quantity + 1),
                  onDecrement: (item) => ref
                      .read(cartControllerProvider.notifier)
                      .updateQty(productId: item.productId, quantity: item.quantity - 1),
                  onRemove: (item) =>
                      ref.read(cartControllerProvider.notifier).remove(item.productId),
                );
              },
            ),
          ),
        ),
        _CartSummary(cart: cart),
      ],
    );
  }

  void _confirmClear(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vaciar carrito'),
        content: const Text('Seguro que deseas vaciar el carrito?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(cartControllerProvider.notifier).clear();
            },
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );
  }
}

/// Tile individual de un item del carrito.
class _CartItemTile extends StatelessWidget {
  const _CartItemTile({
    required this.item,
    required this.isUpdating,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  final CartItem item;
  final bool isUpdating;
  final ValueChanged<CartItem> onIncrement;
  final ValueChanged<CartItem> onDecrement;
  final ValueChanged<CartItem> onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen del producto.
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 72,
                height: 72,
                child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                    ? Image.network(
                        item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholderImage(context),
                      )
                    : _placeholderImage(context),
              ),
            ),
            const SizedBox(width: 12),
            // Info del producto.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.sku != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'SKU: ${item.sku}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _formatPrice(item.price, item.currency),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  // Stepper de cantidad.
                  Row(
                    children: [
                      _qtyButton(
                        context,
                        icon: LucideIcons.minus,
                        onTap: isUpdating ? null : () => onDecrement(item),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: SizedBox(
                          width: 32,
                          child: Text(
                            '${item.quantity}',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ),
                      _qtyButton(
                        context,
                        icon: LucideIcons.plus,
                        onTap: isUpdating ? null : () => onIncrement(item),
                      ),
                      const Spacer(),
                      Text(
                        _formatPrice(item.subtotal, item.currency),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Boton eliminar.
            IconButton(
              icon: const Icon(LucideIcons.x, size: 20),
              color: Theme.of(context).colorScheme.error,
              onPressed: isUpdating ? null : () => onRemove(item),
              tooltip: 'Eliminar',
            ),
          ],
        ),
      ),
    );
  }

  Widget _qtyButton(BuildContext context, {required IconData icon, VoidCallback? onTap}) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Material(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
        ),
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Icon(icon, size: 16),
        ),
      ),
    );
  }

  Widget _placeholderImage(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        LucideIcons.image,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }
}

/// Resumen del carrito con subtotal, total y boton de checkout.
class _CartSummary extends StatelessWidget {
  const _CartSummary({required this.cart});

  final CartState cart;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _summaryRow(context, 'Subtotal', _formatPrice(cart.subtotal)),
            const SizedBox(height: 8),
            _summaryRow(
              context,
              'Total (${cart.totalQuantity} ${cart.totalQuantity == 1 ? 'articulo' : 'articulos'})',
              _formatPrice(cart.totalAmount),
              isTotal: true,
            ),
            if (cart.totals.subtotalUSD > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Incluye conversion USD→MXN @ ${cart.totals.exchangeRate}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: cart.isUpdating
                    ? null
                    : () => context.push('/checkout'),
                icon: const Icon(LucideIcons.creditCard),
                label: const Text('Proceder al checkout'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(BuildContext context, String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? Theme.of(context).textTheme.titleMedium
              : Theme.of(context).textTheme.bodyMedium,
        ),
        Text(
          value,
          style: isTotal
              ? Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)
              : Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
