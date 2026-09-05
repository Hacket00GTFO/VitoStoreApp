import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/providers.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/user.dart';

/// Estado de autenticación.
class AuthState {
  AuthState({
    this.user,
    this.accessToken,
    this.refreshToken,
    this.status = AuthStatus.initial,
    this.error,
  });

  final User? user;
  final String? accessToken;
  final String? refreshToken;
  final AuthStatus status;
  final String? error;

  bool get isAuthenticated => user != null && accessToken != null;
  bool get isLoading => status == AuthStatus.loading;

  AuthState copyWith({
    User? user,
    String? accessToken,
    String? refreshToken,
    AuthStatus? status,
    String? error,
    bool clearUser = false,
    bool clearTokens = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      accessToken: clearTokens ? null : (accessToken ?? this.accessToken),
      refreshToken: clearTokens ? null : (refreshToken ?? this.refreshToken),
      status: status ?? this.status,
      error: error,
    );
  }
}

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

/// Controller de autenticación — replica del `AuthContext` de la web.
///
/// Usa `Notifier` (Riverpod 3.x) en vez del `StateNotifier` deprecado.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    _restoreSession();
    return AuthState(status: AuthStatus.initial);
  }

  AuthRepository get _repo => AuthRepository(ref.read(dioProvider));

  Future<void> _restoreSession() async {
    final storage = ref.read(secureStorageWrapperProvider);
    final access = await storage.getAccessToken();
    final refresh = await storage.getRefreshToken();
    if (access != null && refresh != null) {
      try {
        final user = await _repo.me();
        state = AuthState(
          user: user,
          accessToken: access,
          refreshToken: refresh,
          status: AuthStatus.authenticated,
        );
        return;
      } catch (_) {
        // El access token puede haber expirado: intentar refresh.
        try {
          final result = await _repo.refresh(refreshToken: refresh);
          if (result != null) {
            await storage.saveTokens(
              accessToken: result.accessToken,
              refreshToken: result.refreshToken,
            );
            final user = await _repo.me();
            state = AuthState(
              user: user,
              accessToken: result.accessToken,
              refreshToken: result.refreshToken,
              status: AuthStatus.authenticated,
            );
            return;
          }
        } catch (_) {}
        await storage.clearTokens();
      }
    }
    state = AuthState(status: AuthStatus.unauthenticated);
  }

  /// Login paso 1. Devuelve true si requiere código 2FA.
  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(status: AuthStatus.loading, error: null, clearUser: true, clearTokens: true);
    try {
      final result = await _repo.login(email: email, password: password);
      if (result.requiresCode) {
        state = AuthState(status: AuthStatus.unauthenticated, error: null);
        return true;
      }
      if (result.hasTokens) {
        await ref.read(secureStorageWrapperProvider).saveTokens(
              accessToken: result.accessToken!,
              refreshToken: result.refreshToken!,
            );
        state = AuthState(
          user: result.user,
          accessToken: result.accessToken,
          refreshToken: result.refreshToken,
          status: AuthStatus.authenticated,
        );
        return false;
      }
      state = AuthState(status: AuthStatus.error, error: 'Respuesta inválida del servidor');
      return false;
    } catch (e) {
      state = AuthState(status: AuthStatus.error, error: e.toString());
      return false;
    }
  }

  /// Login paso 2: verificar código 2FA.
  Future<void> verifyLoginCode({required String email, required String code}) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final result = await _repo.verifyLoginCode(email: email, code: code);
      if (result.hasTokens) {
        await ref.read(secureStorageWrapperProvider).saveTokens(
              accessToken: result.accessToken!,
              refreshToken: result.refreshToken!,
            );
        state = AuthState(
          user: result.user,
          accessToken: result.accessToken,
          refreshToken: result.refreshToken,
          status: AuthStatus.authenticated,
        );
      }
    } catch (e) {
      state = AuthState(status: AuthStatus.error, error: e.toString());
    }
  }

  /// Actualiza el usuario en el estado (tras editar perfil).
  void updateUser(User user) {
    state = state.copyWith(user: user, status: AuthStatus.authenticated);
  }

  Future<void> logout() async {
    final refresh = state.refreshToken;
    try {
      if (refresh != null) await _repo.logout(refresh);
    } catch (_) {}
    await ref.read(secureStorageWrapperProvider).clearTokens();
    state = AuthState(status: AuthStatus.unauthenticated);
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

/// Provider del repositorio de auth (para uso directo en paginas de registro/verify).
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(dioProvider));
});
