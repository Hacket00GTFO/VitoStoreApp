import 'package:flutter_test/flutter_test.dart';

import 'package:vito_store_app/features/checkout/data/checkout_repository.dart';

void main() {
  group('ShippingOption.fromJson', () {
    test('creates a valid ShippingOption from a complete JSON map', () {
      final json = {
        'id': 'express',
        'name': 'Envio express',
        'cost': 149.50,
        'estimatedDays': '1-2 dias habiles',
      };

      final option = ShippingOption.fromJson(json);

      expect(option.id, 'express');
      expect(option.name, 'Envio express');
      expect(option.cost, 149.50);
      expect(option.estimatedDays, '1-2 dias habiles');
    });

    test('handles missing fields with defaults', () {
      final option = ShippingOption.fromJson({});

      expect(option.id, '');
      expect(option.name, 'Envio');
      expect(option.cost, 0);
      expect(option.estimatedDays, '3-5 dias habiles');
    });

    test('falls back to estimated_days snake_case', () {
      final option = ShippingOption.fromJson({
        'id': 'standard',
        'name': 'Estandar',
        'estimated_days': '5-7 dias',
      });

      expect(option.estimatedDays, '5-7 dias');
    });

    test('uses default estimatedDays when both camelCase and snake_case missing', () {
      final option = ShippingOption.fromJson({
        'id': 'standard',
        'name': 'Estandar',
      });

      expect(option.estimatedDays, '3-5 dias habiles');
    });

    test('coerces numeric id to string', () {
      final option = ShippingOption.fromJson({
        'id': 10,
        'name': 'X',
        'cost': 0,
      });

      expect(option.id, '10');
    });
  });

  group('MercadoPagoResult.isValid', () {
    test('returns true when initPoint is non-empty', () {
      const result = MercadoPagoResult(
        preferenceId: 'pref-123',
        initPoint: 'https://mp.com/checkout/abc',
      );

      expect(result.isValid, isTrue);
    });

    test('returns false when initPoint is empty', () {
      const result = MercadoPagoResult(preferenceId: 'pref-123', initPoint: '');

      expect(result.isValid, isFalse);
    });

    test('returns false when both fields are empty', () {
      const result = MercadoPagoResult(preferenceId: '', initPoint: '');

      expect(result.isValid, isFalse);
    });
  });

  group('SpeiResult.isValid', () {
    test('returns true when clabe is non-empty', () {
      const result = SpeiResult(
        clabe: '012180012345678901',
        bank: 'STP',
        reference: 'REF-001',
        amount: 1500.0,
        concept: 'Pago orden 1',
      );

      expect(result.isValid, isTrue);
    });

    test('returns false when clabe is empty', () {
      const result = SpeiResult(
        clabe: '',
        bank: 'STP',
        reference: 'REF-001',
        amount: 1500.0,
        concept: 'Pago orden 1',
      );

      expect(result.isValid, isFalse);
    });

    test('returns false when all fields are empty/zero', () {
      const result = SpeiResult(
        clabe: '',
        bank: '',
        reference: '',
        amount: 0,
        concept: '',
      );

      expect(result.isValid, isFalse);
    });
  });
}
