import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/account_repository.dart';
import '../domain/order.dart';

/// Formatea un precio en MXN.
String _formatPrice(double amount) {
  return '\$${amount.toStringAsFixed(2)} MXN';
}

/// Pagina de cuenta (UserHub).
///
/// Muestra info del usuario en el header, boton de logout y tabs:
/// Ordenes | Cotizaciones | Servicios | Facturas.
class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mi cuenta')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.userCircle, size: 64),
                const SizedBox(height: 16),
                const Text('Inicia sesion para ver tu cuenta.'),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.push('/login'),
                  child: const Text('Iniciar sesion'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi cuenta'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.bell),
            tooltip: 'Notificaciones',
            onPressed: () => context.push('/notificaciones'),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildUserHeader(context, user),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(LucideIcons.package), text: 'Ordenes'),
              Tab(icon: Icon(LucideIcons.fileText), text: 'Cotizaciones'),
              Tab(icon: Icon(LucideIcons.wrench), text: 'Servicios'),
              Tab(icon: Icon(LucideIcons.receipt), text: 'Facturas'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _OrdersTab(),
                _PlaceholderTab(
                  icon: LucideIcons.fileText,
                  message: 'Tus cotizaciones apareceran aqui.',
                ),
                _PlaceholderTab(
                  icon: LucideIcons.wrench,
                  message: 'Tus servicios apareceran aqui.',
                ),
                _PlaceholderTab(
                  icon: LucideIcons.receipt,
                  message: 'Tus facturas apareceran aqui.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserHeader(BuildContext context, User user) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              LucideIcons.userCircle,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName.isNotEmpty ? user.fullName : user.email,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.logOut, color: Colors.red),
            tooltip: 'Cerrar sesion',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesion'),
        content: const Text('Seguro que deseas cerrar sesion?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(authControllerProvider.notifier).logout();
            },
            child: const Text('Cerrar sesion'),
          ),
        ],
      ),
    );
  }
}

/// Tab de ordenes: carga la lista via [accountRepositoryProvider].
class _OrdersTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends ConsumerState<_OrdersTab> {
  Future<List<Order>>? _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = ref.read(accountRepositoryProvider).getOrders();
  }

  Future<void> _refresh() async {
    setState(() {
      _ordersFuture = ref.read(accountRepositoryProvider).getOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Order>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.alertCircle,
                      size: 48, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar ordenes',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(LucideIcons.refreshCw),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          final orders = snapshot.data ?? [];
          if (orders.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 80),
                Center(
                  child: Column(
                    children: [
                      Icon(LucideIcons.packageOpen,
                          size: 48, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 16),
                      const Text('No tienes ordenes aun.'),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () => context.go('/tienda'),
                        child: const Text('Explorar productos'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _OrderCard(order: orders[index]),
          );
        },
      ),
    );
  }
}

/// Card individual de una orden con badge de estado.
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Orden #${order.orderNumber}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                _StatusBadge(status: order.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${order.totalItems} ${order.totalItems == 1 ? 'articulo' : 'articulos'} - ${order.formattedDate}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            if (order.items.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...order.items.take(3).map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.quantity}x ${item.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Text(
                          _formatPrice(item.subtotal),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  )),
              if (order.items.length > 3)
                Text(
                  '+ ${order.items.length - 3} mas...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
            ],
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total', style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  _formatPrice(order.total),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge de color segun el estado de la orden.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = _statusInfo(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  (Color, String) _statusInfo(String status) {
    switch (status.toUpperCase()) {
      case 'DELIVERED':
        return (Colors.green, 'Entregado');
      case 'SHIPPED':
        return (Colors.blue, 'Enviado');
      case 'PROCESSING':
        return (Colors.orange, 'Procesando');
      case 'CANCELLED':
        return (Colors.red, 'Cancelado');
      case 'PENDING':
        return (Colors.grey, 'Pendiente');
      case 'PAID':
        return (Colors.green, 'Pagado');
      default:
        return (Colors.grey, status);
    }
  }
}

/// Tab placeholder para secciones aun no implementadas.
class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
