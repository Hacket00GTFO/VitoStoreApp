import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Almacenamiento seguro de tokens y datos sensibles.
///
/// Usa `flutter_secure_storage`: Keychain (iOS) y EncryptedSharedPreferences/Keystore
/// (Android). **Nunca** usar shared_preferences para tokens (anti-patrón de la skill
/// mobile-design "Security Sins").
class SecureStorage {
  SecureStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _kAccessToken = 'vito_access_token';
  static const _kRefreshToken = 'vito_refresh_token';

  Future<String?> getAccessToken() => _storage.read(key: _kAccessToken);
  Future<String?> getRefreshToken() => _storage.read(key: _kRefreshToken);

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _kAccessToken, value: accessToken);
    await _storage.write(key: _kRefreshToken, value: refreshToken);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
  }
}
