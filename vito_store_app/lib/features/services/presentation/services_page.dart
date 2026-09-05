import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/app_strings.dart';
import '../../../shared/widgets/state_view.dart';
import '../data/service_repository.dart';
import '../domain/service.dart';

/// Pagina de servicios.
///
/// Lista de servicios obtenidos de `/api/services` con tarjetas (icono,
/// titulo, descripcion y boton "Solicitar").
class ServicesPage extends ConsumerWidget {
  const ServicesPage({super.key});

  IconData _iconFor(String? icon) {
    switch (icon) {
      case 'wrench':
        return LucideIcons.wrench;
      case 'monitor':
        return LucideIcons.monitor;
      case 'shield':
        return LucideIcons.shieldCheck;
      case 'network':
        return LucideIcons.network;
      case 'headset':
        return LucideIcons.headphones;
      case 'truck':
        return LucideIcons.truck;
      case 'cog':
        return LucideIcons.cog;
      default:
        return LucideIcons.layoutGrid;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(servicesListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(ref.tr('services'))),
      body: StateView(
        asyncValue: servicesAsync,
        emptyMessage: 'No hay servicios disponibles por el momento.',
        emptyIcon: LucideIcons.wrench,
        emptyActionLabel: ref.tr('retry'),
        emptyAction: () => ref.invalidate(servicesListProvider),
        onRetry: () => ref.invalidate(servicesListProvider),
        builder: (services) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(servicesListProvider),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: services.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final Service s = services[index];
                return _ServiceCard(
                  service: s,
                  icon: _iconFor(s.icon),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service, required this.icon});

  final Service service;
  final IconData icon;

  void _solicitar(BuildContext context) {
    final subject = 'Solicitud de servicio: ${service.name}';
    context.push('/contacto?subject=${Uri.encodeQueryComponent(subject)}');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 24,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(service.name, style: Theme.of(context).textTheme.titleMedium),
                  if (service.description != null &&
                      service.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      service.description!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                  if (service.price != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Desde \$${service.price!.toStringAsFixed(2)} ${service.currency}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: () => _solicitar(context),
                        icon: const Icon(LucideIcons.send),
                        label: const Text('Solicitar'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
