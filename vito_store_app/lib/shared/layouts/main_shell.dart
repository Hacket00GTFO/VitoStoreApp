import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../features/chatbot/presentation/chatbot_sheet.dart';
import '../../features/notificaciones/data/notification_repository.dart';

/// Shell principal con bottom navigation (Inicio · Tienda · Cuenta · Favoritos)
/// y FAB global del chatbot.
///
/// Reglas de la skill mobile-navigation:
/// - 4 destinos de igual peso (≤5 máx).
/// - Labels siempre visibles (accesibilidad).
/// - IndexedStack implícito vía go_router ShellRoute (preserva estado de tab).
/// - Touch targets ≥48dp (Material 3 NavigationBar a 80dp).
class MainShell extends ConsumerWidget {
  const MainShell({required this.child, super.key});

  final Widget child;

  static const _destinations = [
    (icon: LucideIcons.home, label: 'Inicio', location: '/'),
    (icon: LucideIcons.shoppingBag, label: 'Tienda', location: '/tienda'),
    (icon: LucideIcons.user, label: 'Cuenta', location: '/mis-transacciones'),
    (icon: LucideIcons.heart, label: 'Favoritos', location: '/favoritos'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (var i = _destinations.length - 1; i >= 0; i--) {
      if (location.startsWith(_destinations[i].location)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = _currentIndex(context);
    // Badge de notificaciones sin leer sobre el tab de Cuenta
    // (acceso a /notificaciones). El provider consulta /unread-count.
    final unread = ref.watch(unreadCountProvider);
    return Scaffold(
      body: child,
      floatingActionButton: Semantics(
        label: 'Asistente VITO',
        button: true,
        child: FloatingActionButton(
          onPressed: () => ChatbotSheet.show(context),
          tooltip: 'Asistente VITO',
          child: const Icon(LucideIcons.messageCircle),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_destinations[i].location),
        destinations: [
          for (var i = 0; i < _destinations.length; i++)
            NavigationDestination(
              icon: i == 2 && unread > 0
                  ? Badge(
                      isLabelVisible: true,
                      label: Text(unread > 99 ? '99+' : '$unread'),
                      child: Icon(_destinations[i].icon),
                    )
                  : Icon(_destinations[i].icon),
              selectedIcon: i == 2 && unread > 0
                  ? Badge(
                      isLabelVisible: true,
                      label: Text(unread > 99 ? '99+' : '$unread'),
                      child: Icon(_destinations[i].icon, fill: 1),
                    )
                  : Icon(_destinations[i].icon, fill: 1),
              label: _destinations[i].label,
            ),
        ],
      ),
    );
  }
}
