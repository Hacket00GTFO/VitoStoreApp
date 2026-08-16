import 'package:dio/dio.dart';

import '../../config/api_config.dart';
import '../storage/secure_storage.dart';
import 'api_error.dart';

/// Interceptor de autenticación.
///
/// - Inyecta `Authorization: Bearer <accessToken>` en cada petición.
/// - En 401: refresh single-flight (`POST /api/account/refresh` con body
///   `{ refreshToken }`). Si ok, reintenta la petición original; si falla,
///   marca `extra['authFailed'] = true` para que el router redirija a login.
/// - En 429: lanza [ApiError] con `retryAfterSeconds` (cooldown por endpoint).
///
/// No maneja CSRF: con Bearer (sin cookies) el backend lo omite
/// (verificado en `csrfProtectionMiddleware.ts`, sección 1.1 del plan).
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage);

  final SecureStorage _storage;

  // Single-flight refresh: evita llamadas concurrentes a /refresh.
  Future<bool>? _refreshInFlight;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers[ApiConfig.authHeader] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;

    // 429: rate limit — no reintentar, propagar con retryAfter.
    if (status == 429) {
      final retryAfter = _parseRetryAfter(err.response);
      final data = err.response?.data is Map<String, dynamic>
          ? err.response?.data as Map<String, dynamic>
          : null;
      handler.next(DioException(
        requestOptions: err.requestOptions,
        error: ApiError(
          status: 429,
          message: data?['message']?.toString() ?? 'Demasiadas solicitudes',
          messageKey: (data?['errorCode'] ?? data?['messageKey'])?.toString(),
          responseData: data,
          retryAfterSeconds: retryAfter,
        ),
        response: err.response,
        type: DioExceptionType.badResponse,
      ));
      return;
    }

    // 401: intentar refresh single-flight y reintentar.
    if (status == 401 && !_isAuthEndpoint(err.requestOptions.path)) {
      final refreshed = await _refreshTokens();
      if (refreshed) {
        try {
          final newToken = await _storage.getAccessToken();
          final cloned = err.requestOptions;
          if (newToken != null) {
            cloned.headers[ApiConfig.authHeader] = 'Bearer $newToken';
          }
          final dio = Dio();
          dio.options..baseUrl = cloned.baseUrl..connectTimeout = cloned.connectTimeout
            ..receiveTimeout = cloned.receiveTimeout;
          final resp = await dio.fetch(cloned);
          handler.resolve(resp);
          return;
        } catch (_) {
          // cae al handler.next abajo
        }
      }
      // Refresh falló: marcar para que el router redirija a login.
      err.requestOptions.extra['authFailed'] = true;
      handler.next(err);
      return;
    }

    // Cualquier otro error: normalizar a ApiError.
    final data = err.response?.data is Map<String, dynamic>
        ? err.response?.data as Map<String, dynamic>
        : null;
    handler.next(DioException(
      requestOptions: err.requestOptions,
      error: ApiError.fromResponse(status, data),
      response: err.response,
      type: err.type,
    ));
  }

  Future<bool> _refreshTokens() async {
    if (_refreshInFlight != null) return _refreshInFlight!;
    _refreshInFlight = _doRefresh();
    try {
      return await _refreshInFlight!;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<bool> _doRefresh() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final dio = Dio();
      final resp = await dio.post(
        ApiEndpoints.auth.refresh,
        data: {'refreshToken': refreshToken},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      if (resp.statusCode == 200 && resp.data != null) {
        final data = resp.data as Map<String, dynamic>;
        final tokens = data['tokens'] as Map<String, dynamic>?;
        final access = tokens?['accessToken'] as String?;
        final refresh = tokens?['refreshToken'] as String?;
        if (access != null && refresh != null) {
          await _storage.saveTokens(accessToken: access, refreshToken: refresh);
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  bool _isAuthEndpoint(String path) {
    return path.contains('/account/login') ||
        path.contains('/account/register') ||
        path.contains('/account/refresh') ||
        path.contains('/account/forgot-password') ||
        path.contains('/account/reset-password') ||
        path.contains('/account/verify-email') ||
        path.contains('/account/resend-verification');
  }

  int _parseRetryAfter(Response? resp) {
    final header = resp?.headers.value('Retry-After');
    final parsed = header != null ? int.tryParse(header) : null;
    if (parsed != null && parsed > 0) return parsed < 900 ? parsed : 900;
    return 60;
  }
}
