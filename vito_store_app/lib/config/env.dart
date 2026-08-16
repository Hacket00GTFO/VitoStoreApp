/// Variables de entorno inyectadas vía `--dart-define`.
///
/// Equivalente a las variables `VITE_*` de la web (sección 12 del plan).
/// Ejemplo de uso:
/// ```bash
/// flutter run --dart-define=API_URL=http://localhost:3001 \
///   --dart-define=STRIPE_PUBLIC_KEY=pk_test_...
/// ```
class Env {
  Env._();

  /// URL base del backend (sin /api). Ej: http://localhost:3001 o https://vitotechnologies.com
  static const String apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:3001',
  );

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
