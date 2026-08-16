import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'config/env.dart';
import 'config/theme/app_theme.dart';
import 'routing/app_router.dart';

/// Widget raíz de la app — MaterialApp.router con tema light/dark y go_router.
class VitoApp extends ConsumerStatefulWidget {
  const VitoApp({super.key});

  @override
  ConsumerState<VitoApp> createState() => _VitoAppState();
}

class _VitoAppState extends ConsumerState<VitoApp> {
  @override
  void initState() {
    super.initState();
    // Inicializar Stripe con la clave pública (si está configurada).
    if (Env.stripePublicKey.isNotEmpty) {
      Stripe.publishableKey = Env.stripePublicKey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'VITO Technologies',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
