import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../features/chatbot/presentation/chatbot_sheet.dart';

/// Shell principal con bottom navigation (Inicio · Tienda · Cuenta · Favoritos)
/// y FAB global del chatbot.
///
/// Reglas de la skill mobile-navigation:
/// - 4 destinos de igual peso (≤5 máx).
/// - Labels siempre visibles (accesibilidad).
/// - IndexedStack implícito vía go_router ShellRoute (preserva estado de tab).
/// - Touch targets ≥48dp (Material 3 NavigationBar a 80dp).
class MainShell extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    return Scaffold(
      body: child,
      floatingActionButton: FloatingActionButton(
        onPressed: () => ChatbotSheet.show(context),
        tooltip: 'Asistente VITO',
        child: const Icon(LucideIcons.messageCircle),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_destinations[i].location),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.icon, fill: 1),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
