import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

/// Variables de entorno inyectadas vía `--dart-define`.
///
/// Equivalente a las variables `VITE_*` de la web (sección 12 del plan).
/// Ejemplo de uso:
/// ```bash
/// flutter run --dart-define=API_URL=http://10.0.2.2:3001 \
///   --dart-define=STRIPE_PUBLIC_KEY=pk_test_...
/// ```
class Env {
  Env._();

  /// URL base del backend (sin /api).
  ///
  /// - En Android emulado, Docker expone el host en 10.0.2.2.
  /// - En iOS Simulator o desktop se usa localhost.
  /// - En Flutter Web se sirve la app desde el MISMO origen que el proxy
  ///   (`/api` lo reenvía nginx → vito-api), así que el origen es el del
  ///   navegador (incluye el host del túnel o el dominio de producción).
  ///   Si se sirve en otro host (p.ej. `flutter run -d chrome` sin proxy),
  ///   inyectar `--dart-define=API_URL=http://127.0.0.1:3001`.
  static String get apiBaseUrl {
    const override = String.fromEnvironment('API_URL');
    if (override.isNotEmpty) {
      return override;
    }

    if (kIsWeb) {
      final origin = Uri.base.origin;
      return origin.isEmpty ? 'http://localhost:3001' : origin;
    }

    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3001';
    }

    return 'http://localhost:3001';
  }

  /// Candidatos de URL del backend, en orden de preferencia, para el modo
  /// híbrido (USB → IP LAN → túnel). Se inyectan con:
  /// ```
  /// flutter run --dart-define=API_URLS=http://localhost:3001,http://192.168.1.50:3001,https://xxx.trycloudflare.com
  /// ```
  /// Al arrancar, la app prueba `/api/health` en cada uno (en paralelo) y usa
  /// el primero que responda. Si no se define, solo se usa [apiBaseUrl].
  static List<String> get apiUrlCandidates {
    const raw = String.fromEnvironment('API_URLS');
    if (raw.trim().isEmpty) return [apiBaseUrl];
    return raw
        .split(',')
        .map((e) => e.trim().replaceAll(RegExp(r'/+$'), ''))
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// Clave pública de Stripe (pk_live_* o pk_test_*).
  static const String stripePublicKey = String.fromEnvironment(
    'STRIPE_PUBLIC_KEY',
    defaultValue: '',
  );

  /// Site key de reCAPTCHA (si se usa en formularios).
  static const String recaptchaSiteKey = String.fromEnvironment(
    'RECAPTCHA_SITE_KEY',
    defaultValue: '',
  );

  /// Idioma por defecto de la app.
  static const String defaultLanguage = String.fromEnvironment(
    'APP_LANGUAGE_DEFAULT',
    defaultValue: 'es',
  );

  /// Esquema de deep links.
  static const String deepLinkScheme = String.fromEnvironment(
    'DEEP_LINK_SCHEME',
    defaultValue: 'vitoapp',
  );
}
