import 'dart:io';

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
  /// En Android emulado, Docker expone el host en 10.0.2.2. En iOS Simulator o
  /// desktop se usa localhost. Si necesitas forzar otra URL, puedes pasar
  /// `--dart-define=API_URL=http://host.docker.internal:3001` o la IP del host.
  static String get apiBaseUrl {
    const override = String.fromEnvironment('API_URL');
    if (override.isNotEmpty) {
      return override;
    }

    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3001';
    }

    return 'http://localhost:3001';
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
