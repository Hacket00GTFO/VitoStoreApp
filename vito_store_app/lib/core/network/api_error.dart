/// Error normalizado de la API — equivalente al manejo de `apiRequest` de la web.
///
/// El backend devuelve errores con `messageKey`/`errorCode` para i18n.
/// Esta clase los encapsula y permite localizarlos (sección 6.2 del plan).
class ApiError implements Exception {
  ApiError({
    required this.message,
    this.status,
    this.messageKey,
    this.rawMessage,
    this.responseData,
    this.retryAfterSeconds,
  });

  factory ApiError.fromResponse(int? status, Map<String, dynamic>? data) {
    final raw = data?['error'] ?? data?['message'] ?? 'Error desconocido';
    final key = data?['errorCode'] ?? data?['messageKey'];
    return ApiError(
      status: status,
      message: raw.toString(),
      messageKey: key?.toString(),
      rawMessage: raw.toString(),
      responseData: data,
    );
  }

  final String message;
  final int? status;
  final String? messageKey;
  final String? rawMessage;
  final Map<String, dynamic>? responseData;
  final int? retryAfterSeconds;

  bool get isUnauthorized => status == 401;
  bool get isForbidden => status == 403;
  bool get isNotFound => status == 404;
  bool get isRateLimited => status == 429;
  bool get isServer => (status ?? 0) >= 500;

  @override
  String toString() => 'ApiError($status): $message${messageKey != null ? ' [$messageKey]' : ''}';
}
