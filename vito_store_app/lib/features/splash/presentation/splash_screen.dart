import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../auth/presentation/auth_controller.dart';

/// Splash screen inicial. Muestra logo mientras se restaura la sesion.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final auth = ref.watch(authControllerProvider);

    // Una vez que el estado de auth se resuelve, redirigir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      if (auth.status == AuthStatus.authenticated) {
        context.go('/');
      } else if (auth.status == AuthStatus.unauthenticated) {
        context.go('/');
      } else if (auth.status == AuthStatus.error) {
        context.go('/login');
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0066CC),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo placeholder (reemplazar con SVG oficial de VITO).
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                LucideIcons.cpu,
                size: 64,
                color: Color(0xFF0066CC),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'VITO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            const Text(
              'Technologies',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
