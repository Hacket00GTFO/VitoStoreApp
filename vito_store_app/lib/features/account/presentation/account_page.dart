import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
              children: const [
                _OrdersTab(),
                _QuotesTab(),
                _ServicesTab(),
                _InvoicesTab(),
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
            icon: const Icon(LucideIcons.edit),
            tooltip: 'Editar perfil',
            onPressed: () => _showEditProfileDialog(context, user),
          ),
          IconButton(
            icon: const Icon(LucideIcons.keyRound),
            tooltip: 'Cambiar contrasena',
            onPressed: () => _showChangePasswordDialog(context),
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

  void _showEditProfileDialog(BuildContext context, User user) {
    final firstNameCtrl = TextEditingController(text: user.firstName ?? '');
    final lastNameCtrl = TextEditingController(text: user.lastName ?? '');
    final phoneCtrl = TextEditingController(text: user.phone ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar perfil'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: firstNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: Icon(LucideIcons.user),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: lastNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Apellidos',
                  prefixIcon: Icon(LucideIcons.user),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Telefono',
                  prefixIcon: Icon(LucideIcons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final updated = await ref
                    .read(accountRepositoryProvider)
                    .updateProfile(
                      firstName: firstNameCtrl.text.trim(),
                      lastName: lastNameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                    );
                final newUser = User(
                  id: user.id,
                  email: user.email,
                  role: user.role,
                  firstName: (updated['firstName'] as String?) ??
                      (firstNameCtrl.text.trim().isEmpty
                          ? user.firstName
                          : firstNameCtrl.text.trim()),
                  lastName: (updated['lastName'] as String?) ??
                      (lastNameCtrl.text.trim().isEmpty
                          ? user.lastName
                          : lastNameCtrl.text.trim()),
                  phone: (updated['phone'] as String?) ??
                      (phoneCtrl.text.trim().isEmpty
                          ? user.phone
                          : phoneCtrl.text.trim()),
                  emailVerified: user.emailVerified,
                );
                ref.read(authControllerProvider.notifier).updateUser(newUser);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Perfil actualizado')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar contrasena'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentCtrl,
                decoration: const InputDecoration(
                  labelText: 'Contrasena actual',
                  prefixIcon: Icon(LucideIcons.lock),
                ),
                obscureText: true,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nueva contrasena',
                  prefixIcon: Icon(LucideIcons.lock),
                ),
                obscureText: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  if (v.length < 6) return 'Minimo 6 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmCtrl,
                decoration: const InputDecoration(
                  labelText: 'Confirmar contrasena',
                  prefixIcon: Icon(LucideIcons.lock),
                ),
                obscureText: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  if (v != newCtrl.text) return 'No coinciden';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.of(ctx).pop();
              try {
                await ref.read(accountRepositoryProvider).changePassword(
                      currentPassword: currentCtrl.text,
                      newPassword: newCtrl.text,
                    );
                // El backend revoca las sesiones al cambiar contrasena:
                // limpiar tokens locales y mandar a login. El aviso se muestra
                // ANTES del logout porque el redirect del router puede
                // desmontar esta pagina y dejar el context sin mounted.
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Contrasena actualizada. Inicia sesion de nuevo.')),
                  );
                }
                await ref.read(authControllerProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

/// Refresca el historial unificado (pull-to-refresh de los 4 tabs).
///
/// Captura el error: el fallo ya se refleja via AsyncValue (pantalla de
/// error del tab); dejarlo escapar provocaria una excepcion async no
/// manejada por RefreshIndicator.
Future<void> _refreshHistory(WidgetRef ref) async {
  try {
    ref.invalidate(accountHistoryProvider);
    await ref.read(accountHistoryProvider.future);
  } catch (_) {
    // El error se muestra con el estado de error del provider.
  }
}

/// Pantalla de carga compartida por los tabs del historial.
class _TabLoadingView extends StatelessWidget {
  const _TabLoadingView();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

/// Pantalla de error con Reintentar (invalida el historial unificado).
class _TabErrorView extends ConsumerWidget {
  const _TabErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.alertCircle,
              size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => ref.invalidate(accountHistoryProvider),
            icon: const Icon(LucideIcons.refreshCw),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

/// Pantalla vacia compartida por los tabs del historial.
class _TabEmptyView extends StatelessWidget {
  const _TabEmptyView({required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            children: [
              Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
              Text(message),
              if (action != null) ...[
                const SizedBox(height: 20),
                action!,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Tab de ordenes: consume el historial unificado ([accountHistoryProvider]).
class _OrdersTab extends ConsumerWidget {
  const _OrdersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHistory = ref.watch(accountHistoryProvider);
    return RefreshIndicator(
      onRefresh: () => _refreshHistory(ref),
      child: asyncHistory.when(
        // Default (skipLoadingOnRefresh): durante el pull-to-refresh se
        // conserva la data actual hasta que llega la nueva (sin flash).
        loading: () => const _TabLoadingView(),
        error: (_, __) => const _TabErrorView(message: 'Error al cargar ordenes'),
        data: (history) {
          final orders = history.orders.map(Order.fromJson).toList();
          if (orders.isEmpty) {
            return _TabEmptyView(
              icon: LucideIcons.packageOpen,
              message: 'No tienes ordenes aun.',
              action: FilledButton(
                onPressed: () => context.go('/tienda'),
                child: const Text('Explorar productos'),
              ),
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
                          item.subtotalLabel,
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
      case 'REJECTED':
        return (Colors.red, 'Rechazada');
      case 'PENDING':
        return (Colors.grey, 'Pendiente');
      case 'PAID':
        return (Colors.green, 'Pagado');
      case 'IN_REVIEW':
        return (Colors.orange, 'En revision');
      case 'APPROVED':
        return (Colors.green, 'Aprobada');
      case 'IN_PROGRESS':
        return (Colors.blue, 'En progreso');
      case 'COMPLETED':
        return (Colors.green, 'Completada');
      case 'REVIEWING':
        return (Colors.orange, 'En revision');
      case 'QUOTED':
        return (Colors.teal, 'Cotizada');
      case 'ACCEPTED':
        return (Colors.green, 'Aceptada');
      default:
        return (Colors.grey, status);
    }
  }
}

/// Tab de cotizaciones: consume el historial unificado.
class _QuotesTab extends ConsumerWidget {
  const _QuotesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHistory = ref.watch(accountHistoryProvider);
    return RefreshIndicator(
      onRefresh: () => _refreshHistory(ref),
      child: asyncHistory.when(
        loading: () => const _TabLoadingView(),
        error: (_, __) =>
            const _TabErrorView(message: 'Error al cargar cotizaciones'),
        data: (history) {
          final quotes = history.specializedQuotes;
          if (quotes.isEmpty) {
            return const _TabEmptyView(
              icon: LucideIcons.fileText,
              message: 'No tienes cotizaciones aun.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: quotes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _QuoteCard(quote: quotes[index]),
          );
        },
      ),
    );
  }
}

/// Card individual de una cotizacion (row de `SpecializedQuote` proyectada).
class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.quote});

  final Map<String, dynamic> quote;

  @override
  Widget build(BuildContext context) {
    final number =
        (quote['quoteNumber'] ?? quote['number'] ?? '-').toString();
    final status = (quote['status'] ?? 'PENDING').toString();
    final date = (quote['date'] ?? quote['createdAt'] ?? '').toString();
    final serviceName = (quote['serviceName'] ?? '').toString();
    // SpecializedQuote no tiene `total`: el monto esta en finalCost (cuando
    // el admin lo define) o estimatedCost; Decimal de Prisma llega como String.
    final totalValue = quote['finalCost'] ?? quote['estimatedCost'];
    final total = double.tryParse('${totalValue ?? ''}') ?? 0.0;

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
                    'Cotizacion #$number',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                _StatusBadge(status: status),
              ],
            ),
            if (serviceName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                serviceName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'Solicitada: $date',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  total > 0 ? 'Total' : 'Monto sin definir',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (total > 0)
                  Text(
                    _formatPrice(total),
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

/// Tab de servicios: consume el historial unificado.
class _ServicesTab extends ConsumerWidget {
  const _ServicesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHistory = ref.watch(accountHistoryProvider);
    return RefreshIndicator(
      onRefresh: () => _refreshHistory(ref),
      child: asyncHistory.when(
        loading: () => const _TabLoadingView(),
        error: (_, __) =>
            const _TabErrorView(message: 'Error al cargar servicios'),
        data: (history) {
          final services = history.serviceRequests;
          if (services.isEmpty) {
            return const _TabEmptyView(
              icon: LucideIcons.wrench,
              message: 'No tienes servicios solicitados aun.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: services.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _ServiceCard(service: services[index]),
          );
        },
      ),
    );
  }
}

/// Card individual de un servicio (row de `ServiceRequest` proyectada).
class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service});

  final Map<String, dynamic> service;

  @override
  Widget build(BuildContext context) {
    // El nombre del servicio vive en la relacion `service.name` (la row no
    // trae un campo `name` propio).
    final related = service['service'] is Map<String, dynamic>
        ? service['service'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final name =
        (service['name'] ?? service['serviceName'] ?? related['name'] ?? 'Servicio')
            .toString();
    final number =
        (service['requestNumber'] ?? service['number'] ?? '').toString();
    final status = (service['status'] ?? 'PENDING').toString();
    final date =
        (service['dateRequested'] ?? service['createdAt'] ?? '').toString();

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
                    name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                _StatusBadge(status: status),
              ],
            ),
            if (number.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Folio: $number',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (date.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Solicitado: $date',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tab de facturas: consume el historial unificado.
class _InvoicesTab extends ConsumerWidget {
  const _InvoicesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHistory = ref.watch(accountHistoryProvider);
    return RefreshIndicator(
      onRefresh: () => _refreshHistory(ref),
      child: asyncHistory.when(
        loading: () => const _TabLoadingView(),
        error: (_, __) =>
            const _TabErrorView(message: 'Error al cargar facturas'),
        data: (history) {
          final invoices = history.invoiceRequests;
          if (invoices.isEmpty) {
            return const _TabEmptyView(
              icon: LucideIcons.receipt,
              message: 'No tienes facturas aun.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: invoices.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _InvoiceCard(invoice: invoices[index]),
          );
        },
      ),
    );
  }
}

/// Card individual de una solicitud de factura (`InvoiceRequest` proyectada).
class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice});

  final Map<String, dynamic> invoice;

  @override
  Widget build(BuildContext context) {
    // InvoiceRequest no trae monto ni numero de factura (aun no emitida):
    // tiene folio de solicitud `requestNumber` y datos fiscales.
    final number = (invoice['invoiceNumber'] ??
            invoice['requestNumber'] ??
            invoice['number'] ??
            '-')
        .toString();
    final status = (invoice['status'] ?? 'PENDING').toString();
    final date = (invoice['date'] ?? invoice['createdAt'] ?? '').toString();
    final fiscalName = (invoice['fiscalName'] ?? '').toString();
    final fiscalRfc = (invoice['fiscalRFC'] ?? '').toString();
    final type = (invoice['invoiceType'] ?? '').toString();

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
                    'Factura #$number',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                _StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 8),
            if (date.isNotEmpty)
              Text(
                'Solicitada: $date',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            if (fiscalName.isNotEmpty || fiscalRfc.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                [
                  if (fiscalName.isNotEmpty) fiscalName,
                  if (fiscalRfc.isNotEmpty) 'RFC: $fiscalRfc',
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (type.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Tipo: ${type.toLowerCase().contains('credit') ? 'Credito' : 'Publico general'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
