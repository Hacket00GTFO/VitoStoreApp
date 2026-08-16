import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Pantalla de mantenimiento — replica del MaintenanceScreen de la web.
/// Se muestra cuando GET /api/health indica modo mantenimiento.
class MaintenancePage extends StatelessWidget {
  const MaintenancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.wrench, size: 64, color: Color(0xFF0066CC)),
                const SizedBox(height: 24),
                Text(
                  'Sitio en mantenimiento',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'Estamos realizando mejoras. Volveremos pronto.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {},
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
