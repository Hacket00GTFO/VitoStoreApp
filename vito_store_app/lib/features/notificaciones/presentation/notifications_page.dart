import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../shared/widgets/state_view.dart';
import '../data/notification_repository.dart';
import '../domain/notification_model.dart';

/// Provider que obtiene la lista de notificaciones.
final notificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  return ref.read(notificationRepositoryProvider).list();
});

/// Pagina de notificaciones.
///
/// Lista de notificaciones con estado leido/no leido. Tocar una notificacion
/// la marca como leida. Usa [StateView] para manejar loading/error/empty.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncNotifications = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            tooltip: 'Recargar',
            onPressed: () => ref.invalidate(notificationsProvider),
          ),
        ],
      ),
      body: StateView<AppNotification>(
        asyncValue: asyncNotifications,
        emptyMessage: 'No tienes notificaciones.',
        emptyIcon: LucideIcons.bellOff,
        onRetry: () => ref.invalidate(notificationsProvider),
        builder: (notifications) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(notificationsProvider),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationTile(
                notification: notification,
                onTap: () => _markAsRead(context, ref, notification),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _markAsRead(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
  ) async {
    if (notification.read) return;

    try {
      await ref.read(notificationRepositoryProvider).markAsRead(notification.id);
      // Refrescar la lista para reflejar el cambio.
      ref.invalidate(notificationsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al marcar: $e')),
        );
      }
    }
  }
}

/// Tile individual de una notificacion.
class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.read;

    return Card(
      color: isUnread
          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.15)
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Indicador de no leido.
              if (isUnread)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              else
                Icon(
                  LucideIcons.check,
                  size: 16,
                  color: Theme.of(context).colorScheme.outline,
                ),
              const SizedBox(width: 12),
              // Contenido.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight:
                                isUnread ? FontWeight.w700 : FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isUnread
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.outline,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.formattedDate,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
