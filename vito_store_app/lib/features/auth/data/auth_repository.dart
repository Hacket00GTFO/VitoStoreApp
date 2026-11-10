import 'package:dio/dio.dart';

import '../../../config/api_config.dart';
import '../../auth/domain/user.dart';

/// Repositorio de autenticacion. Consume los mismos endpoints que la web
/// (`/api/account/login`, `/refresh`, `/logout`, `/me`).
class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  /// Login paso 1: email + password. Puede requerir 2FA (responde con `requiresCode`).
  Future<LoginResult> login({
    required String email,
    required String password,
    String? captchaToken,
  }) async {
    final resp = await _dio.post(ApiEndpoints.auth.login, data: {
      'email': email,
      'password': password,
      if (captchaToken != null) 'captchaToken': captchaToken,
    });
    final data = resp.data as Map<String, dynamic>;
    // Si el backend indica que requiere codigo 2FA. El backend real responde
    // 202 con `requiresLoginCode` para todo rol USER (codigo por email);
    // los otros dos nombres quedan por retrocompatibilidad.
    if (data['requiresLoginCode'] == true ||
        data['requiresCode'] == true ||
        data['verificationRequired'] == true) {
      return LoginResult(requiresCode: true, email: email);
    }
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    final tokens = (data['tokens'] ?? data['token']) as Map<String, dynamic>?;
    return LoginResult(
      user: user,
      accessToken: tokens?['accessToken'] as String?,
      refreshToken: tokens?['refreshToken'] as String?,
    );
  }

  /// Login paso 2: verificacion de codigo 2FA.
  Future<LoginResult> verifyLoginCode({required String email, required String code}) async {
    final resp = await _dio.post(ApiEndpoints.auth.loginVerify, data: {
      'email': email,
      'code': code,
    });
    final data = resp.data as Map<String, dynamic>;
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    final tokens = data['tokens'] as Map<String, dynamic>?;
    return LoginResult(
      user: user,
      accessToken: tokens?['accessToken'] as String?,
      refreshToken: tokens?['refreshToken'] as String?,
    );
  }

  /// Reenvia el codigo 2FA del login (`POST /account/login-resend`).
  Future<void> resendLoginCode(String email) async {
    await _dio.post(ApiEndpoints.auth.loginResend, data: {'email': email});
  }

  Future<void> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    await _dio.post(ApiEndpoints.auth.register, data: {
      'email': email,
      'password': password,
      if (firstName != null) 'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      if (phone != null) 'phone': phone,
    });
  }

  /// Verifica el email tras el registro.
  ///
  /// El backend responde `200 {user, tokens}`: usamos los tokens para dejar la
  /// sesión iniciada sin obligar a un segundo login.
  Future<LoginResult> verifyEmail({required String email, required String code}) async {
    final resp =
        await _dio.post(ApiEndpoints.auth.verifyEmail, data: {'email': email, 'code': code});
    final data = resp.data;
    if (data is! Map<String, dynamic>) return LoginResult();
    final tokens = data['tokens'] as Map<String, dynamic>?;
    final userJson = data['user'];
    return LoginResult(
      user: userJson is Map<String, dynamic> ? User.fromJson(userJson) : null,
      accessToken: tokens?['accessToken'] as String?,
      refreshToken: tokens?['refreshToken'] as String?,
    );
  }

  Future<void> resendVerification(String email) async {
    await _dio.post(ApiEndpoints.auth.resendVerification, data: {'email': email});
  }

  Future<void> forgotPassword(String email) async {
    await _dio.post(ApiEndpoints.auth.forgotPassword, data: {'email': email});
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _dio.post(ApiEndpoints.auth.resetPassword, data: {
      'email': email,
      'code': code,
      'newPassword': newPassword,
    });
  }

  Future<User> me() async {
    final resp = await _dio.get(ApiEndpoints.auth.me);
    return User.fromJson(resp.data as Map<String, dynamic>);
  }

  /// Logout: envia refreshToken en el body (igual que la web).
  Future<void> logout(String refreshToken) async {
    await _dio.post(ApiEndpoints.auth.logout, data: {'refreshToken': refreshToken});
  }

  /// Refresca los tokens usando el refreshToken.
  ///
  /// Consume `POST /api/account/refresh` con body `{ refreshToken }`.
  /// Devuelve nuevos accessToken y refreshToken, o null si falla.
  Future<({String accessToken, String refreshToken})?> refresh({
    required String refreshToken,
  }) async {
    final resp = await _dio.post(ApiEndpoints.auth.refresh, data: {
      'refreshToken': refreshToken,
    });
    final data = resp.data as Map<String, dynamic>;
    final tokens = data['tokens'] as Map<String, dynamic>?;
    final access = tokens?['accessToken'] as String?;
    final refresh = tokens?['refreshToken'] as String?;
    if (access != null && refresh != null) {
      return (accessToken: access, refreshToken: refresh);
    }
    return null;
  }
}

/// Resultado del flujo de login (puede requerir 2FA o devolver tokens).
class LoginResult {
  LoginResult({
    this.user,
    this.accessToken,
    this.refreshToken,
    this.requiresCode = false,
    this.email,
  });

  final User? user;
  final String? accessToken;
  final String? refreshToken;
  final bool requiresCode;
  final String? email;

  bool get hasTokens => accessToken != null && refreshToken != null;
}
