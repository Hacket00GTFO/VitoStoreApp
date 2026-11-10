import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/maintenance_status.dart';

/// Pantalla de mantenimiento — replica del MaintenanceScreen de la web.
///
/// Se muestra cuando `GET /api/health` expone `maintenance.active` (o cuando
/// una respuesta 503 lo indica). El botón Reintentar reconsulta el estado
/// real del backend; si ya salió del modo mantenimiento, el redirect del
/// router vuelve automáticamente a la app.
class MaintenancePage extends ConsumerWidget {
  const MaintenancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(maintenanceStatusProvider);
    final message = statusAsync.value?.message ??
        'Estamos realizando mejoras. Volveremos pronto.';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.wrench,
                    size: 64, color: Color(0xFF0066CC)),
                const SizedBox(height: 24),
                Text(
                  'Sitio en mantenimiento',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(maintenanceStatusProvider),
                  icon: const Icon(LucideIcons.refreshCw),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
