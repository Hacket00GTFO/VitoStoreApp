import 'dart:developer' as dev;

import 'package:dio/dio.dart';

import '../../config/api_config.dart';
import '../storage/secure_storage.dart';
import 'auth_interceptor.dart';

/// Cliente HTTP central basado en dio.
///
/// Configura baseUrl, timeouts e interceptores:
/// - [AuthInterceptor]: Bearer + refresh single-flight + manejo de 429.
/// - Inyección de cabecera `X-App-Language` (vía [languageProvider]).
///
/// La app usa una instancia única (provider `dioProvider`) para compartir
/// el estado de auth y configuración.
class DioClient {
  DioClient._(this.dio);

  final Dio dio;

  /// Crea el cliente con los interceptores instalados.
  factory DioClient.create({
    required SecureStorage secureStorage,
    required Future<String> Function() currentLanguage,
  }) {
    final dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        // Trazabilidad de logs en el backend (Fase 3.5): particiona las peticiones
        // de la app en los logs del servidor (la web manda su propio header).
        'X-VITO-CLIENT': 'vito-app',
      },
    ));

    // Interceptor de idioma (X-App-Language) — se inyecta antes del auth.
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.headers[ApiConfig.languageHeader] = await currentLanguage();
          handler.next(options);
        },
      ),
    );

    // Interceptor de auth (Bearer + refresh + 429).
    dio.interceptors.add(AuthInterceptor(secureStorage));

    // Log en debug.
    dio.interceptors.add(LogInterceptor(
      request: false,
      requestHeader: false,
      responseHeader: false,
      responseBody: false,
      error: true,
      logPrint: (o) => dev.log('[dio] $o'),
    ));

    return DioClient._(dio);
  }
}
