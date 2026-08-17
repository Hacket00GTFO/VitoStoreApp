import 'env.dart';

/// Configuración de la API — espejo de `src/config/api.ts` de la web.
///
/// Centraliza la URL base y el catálogo de endpoints para que la app consuma
/// exactamente los mismos recursos REST que el frontend web (sección 6.1 del plan).
class ApiConfig {
  ApiConfig._();

  /// URL base normalizada a `.../api`.
  static String get baseUrl {
    final trimmed = Env.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return trimmed.endsWith('/api') ? trimmed : '$trimmed/api';
  }

  /// Esquema de deep links.
  static String get deepLinkScheme => Env.deepLinkScheme;

  // Cabeceras
  static const String languageHeader = 'X-App-Language';
  static const String authHeader = 'Authorization';

  // Nombres de cookies (para referencia; la app usa Bearer, no cookies)
  static const String accessTokenCookie = 'vito_access_token';
  static const String refreshTokenCookie = 'vito_refresh_token';
}

/// Catálogo de endpoints REST (traducción 1:1 de `API_ENDPOINTS` de la web).
class ApiEndpoints {
  ApiEndpoints._();

  static String get base => ApiConfig.baseUrl;

  // --- Autenticación ---
  static final auth = _AuthEndpoints();

  // --- Contacto ---
  static String get contact => '$base/contact';
  static String get contactDemo => '$base/contact/demo';

  // --- Newsletter ---
  static String get newsletter => '$base/newsletter';

  // --- Cotizaciones ---
  static String get quotes => '$base/quotes';

  // --- Productos, servicios, categorías ---
  static String get products => '$base/products';
  static String get services => '$base/services';
  static String get categories => '$base/categories';

  // --- Carrito y órdenes ---
  static String get cart => '$base/cart';
  static String get orders => '$base/orders';

  // --- Pagos ---
  static final payments = _PaymentEndpoints();

  // --- Blog ---
  static String get blog => '$base/blog';

  // --- Salud ---
  static String get health => '$base/health';

  // --- Guías técnicas ---
  static final technical = _TechnicalEndpoints();

  // --- Certificaciones ---
  static final certifications = _CertificationEndpoints();

  // --- Galería (admin) ---
  static final gallery = _GalleryEndpoints();

  // --- Notificaciones ---
  static String get notifications => '$base/notifications';

  // --- Eventos ---
  static String get events => '$base/events';

  // --- Casos de éxito ---
  static String get cases => '$base/cases';
  static String get nosotrosCases => '$base/nosotros-cases';

  // --- CMS / Landing / Exchange rate ---
  static String get cms => '$base/cms';
  static String get landing => '$base/landing';
  static String get exchangeRate => '$base/exchange-rate';

  // --- Chatbot ---
  static String get chatbot => '$base/chatbot';
  static String get chatbotAssistantQuery => '$base/chatbot/assistant/public-query';
  static String get chatbotAssistantReset => '$base/chatbot/assistant/reset';

  // --- Cotizaciones especializadas ---
  static String get specializedQuotes => '$base/specialized-quotes';

  // --- Facturas ---
  static String get invoices => '$base/invoices';

  // --- Perfil / Historial ---
  static String get profile => '$base/account/me';
  static String get history => '$base/history';
}

class _AuthEndpoints {
  const _AuthEndpoints();
  String get login => '${ApiEndpoints.base}/account/login';
  String get loginVerify => '${ApiEndpoints.base}/account/login-verify';
  String get loginResend => '${ApiEndpoints.base}/account/login-resend';
  String get register => '${ApiEndpoints.base}/account/register';
  String get verifyEmail => '${ApiEndpoints.base}/account/verify-email';
  String get resendVerification => '${ApiEndpoints.base}/account/resend-verification';
  String get forgotPassword => '${ApiEndpoints.base}/account/forgot-password';
  String get resetPassword => '${ApiEndpoints.base}/account/reset-password';
  String get logout => '${ApiEndpoints.base}/account/logout';
  String get refresh => '${ApiEndpoints.base}/account/refresh';
  String get csrfToken => '${ApiEndpoints.base}/account/csrf-token';
  String get me => '${ApiEndpoints.base}/account/me';
  String get google => '${ApiEndpoints.base}/account/google';
  String get facebook => '${ApiEndpoints.base}/account/facebook';
}

class _PaymentEndpoints {
  const _PaymentEndpoints();
  String get stripe => '${ApiEndpoints.base}/payments/stripe';
  String get stripeCreateIntent =>
      '${ApiEndpoints.base}/payments/stripe/create-intent';
  String get available => '${ApiEndpoints.base}/payments/available';
  String get mercadopago => '${ApiEndpoints.base}/payments/mercadopago';
  String get paypal => '${ApiEndpoints.base}/payments/paypal';
}

class _TechnicalEndpoints {
  const _TechnicalEndpoints();
  String get guides => '${ApiEndpoints.base}/technical/guides';
  String get labs => '${ApiEndpoints.base}/technical/labs';
}

class _CertificationEndpoints {
  const _CertificationEndpoints();
  String get base => '${ApiEndpoints.base}/certifications';
  String get admin => '${ApiEndpoints.base}/certifications/admin';
  String get resources => '${ApiEndpoints.base}/certifications/resources';
}

class _GalleryEndpoints {
  const _GalleryEndpoints();
  String get base => '${ApiEndpoints.base}/admin/gallery';
  String get upload => '${ApiEndpoints.base}/admin/gallery/upload';
  String get reorder => '${ApiEndpoints.base}/admin/gallery/reorder';
  String product(String productId) => '${ApiEndpoints.base}/admin/gallery/product/$productId';
  String assign(String id) => '${ApiEndpoints.base}/admin/gallery/$id/assign';
  String cover(String id) => '${ApiEndpoints.base}/admin/gallery/$id/cover';
  String byId(String id) => '${ApiEndpoints.base}/admin/gallery/$id';
}
