import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'app.dart';
import 'config/api_config.dart';
import 'config/env.dart';
import 'core/network/base_url_resolver.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Modo híbrido: resolver qué backend alcanza este dispositivo
  // (USB → IP LAN → túnel) antes de construir la app.
  final candidates = Env.apiUrlCandidates;
  debugPrint('[main] Candidatos API: $candidates');
  ApiConfig.resolvedBaseUrl =
      await BaseUrlResolver.resolve(candidates);
  debugPrint('[main] resolvedBaseUrl = ${ApiConfig.resolvedBaseUrl}');
  debugPrint('[main] ApiConfig.baseUrl = ${ApiConfig.baseUrl}');

  // Stripe: solo si se inyectó la publishable key vía --dart-define.
  if (Env.stripePublicKey.isNotEmpty) {
    Stripe.publishableKey = Env.stripePublicKey;
    await Stripe.instance.applySettings();
  }

  runApp(
    const ProviderScope(
      child: VitoApp(),
    ),
  );
}
