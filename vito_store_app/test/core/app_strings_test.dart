import 'package:flutter_test/flutter_test.dart';

import 'package:vito_store_app/core/i18n/app_strings.dart';

void main() {
  group('AppStrings.get', () {
    test('returns the Spanish string for the "es" locale', () {
      final value = AppStrings.get('login', 'es');

      expect(value, 'Iniciar sesion');
    });

    test('returns the English string for the "en" locale', () {
      final value = AppStrings.get('login', 'en');

      expect(value, 'Sign in');
    });

    test('defaults to the "es" locale when no locale is provided', () {
      final value = AppStrings.get('home');

      expect(value, 'Inicio');
    });

    test('returns the key itself for unknown keys', () {
      final key = 'thisKeyDoesNotExist';

      expect(AppStrings.get(key, 'es'), key);
      expect(AppStrings.get(key, 'en'), key);
    });

    test('returns different strings for es and en for the same key', () {
      final es = AppStrings.get('cart', 'es');
      final en = AppStrings.get('cart', 'en');

      expect(es, 'Carrito');
      expect(en, 'Cart');
      expect(es, isNot(equals(en)));
    });
  });

  group('AppStrings.all', () {
    test('returns a non-empty map for the "es" locale', () {
      final map = AppStrings.all('es');

      expect(map, isNotEmpty);
      expect(map, isA<Map<String, String>>());
      expect(map['appTitle'], 'VITO Technologies');
    });

    test('returns a non-empty map for the "en" locale', () {
      final map = AppStrings.all('en');

      expect(map, isNotEmpty);
      expect(map, isA<Map<String, String>>());
      expect(map['appTitle'], 'VITO Technologies');
    });

    test('falls back to Spanish map for unknown locale', () {
      final map = AppStrings.all('fr');

      expect(map, isNotEmpty);
      expect(map['login'], 'Iniciar sesion');
    });
  });

  group('locale parity', () {
    test('all keys in _es have corresponding keys in _en', () {
      final es = AppStrings.all('es');
      final en = AppStrings.all('en');

      final missingInEn = es.keys.where((k) => !en.containsKey(k)).toList();

      expect(
        missingInEn,
        isEmpty,
        reason: 'Keys missing in _en: $missingInEn',
      );
    });

    test('all keys in _en have corresponding keys in _es', () {
      final es = AppStrings.all('es');
      final en = AppStrings.all('en');

      final missingInEs = en.keys.where((k) => !es.containsKey(k)).toList();

      expect(
        missingInEs,
        isEmpty,
        reason: 'Keys missing in _es: $missingInEs',
      );
    });

    test('both locales have the same number of keys', () {
      final es = AppStrings.all('es');
      final en = AppStrings.all('en');

      expect(es.length, en.length);
    });
  });
}
