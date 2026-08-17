import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'app.dart';
import 'config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
