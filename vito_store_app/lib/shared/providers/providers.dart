import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/env.dart';
import '../../core/network/dio_client.dart';
import '../../core/storage/secure_storage.dart';

/// Provider de [FlutterSecureStorage].
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
});

/// Provider de [SecureStorage] (wrapper sobre FlutterSecureStorage).
final secureStorageWrapperProvider = Provider<SecureStorage>((ref) {
  return SecureStorage(ref.watch(secureStorageProvider));
});

/// Provider del idioma actual (persistido en shared_preferences).
///
/// Usa `Notifier` (Riverpod 3.x) en vez del `StateNotifier` deprecado.
final languageProvider =
    NotifierProvider<LanguageNotifier, String>(LanguageNotifier.new);

/// Provider de [Dio]. Depende de secureStorage y language.
final dioProvider = Provider<Dio>((ref) {
  final secureStorage = ref.watch(secureStorageWrapperProvider);
  final language = ref.watch(languageProvider);
  final client = DioClient.create(
    secureStorage: secureStorage,
    currentLanguage: () async => language,
  );
  return client.dio;
});

/// Notifier de idioma — persiste en shared_preferences (no sensible).
class LanguageNotifier extends Notifier<String> {
  @override
  String build() {
    _load();
    return Env.defaultLanguage;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_language');
    if (saved != null) state = saved;
  }

  Future<void> setLanguage(String lang) async {
    state = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', lang);
  }
}
