import 'package:flutter_test/flutter_test.dart';

import 'package:vito_store_app/features/checkout/data/checkout_repository.dart';

void main() {
  group('ShippingOption.fromJson', () {
    test('crea una opcion completa desde el JSON del backend', () {
      final json = {
        'quoteToken': 'tok_abc123',
        'kind': 'syscom',
        'carrierCode': 'FEDEX',
        'carrierName': 'FedEx',
        'freight': 149.50,
        'currency': 'MXN',
        'freightMxn': 149.50,
        'shippingTotalMxn': 149.50,
      };

      final option = ShippingOption.fromJson(json);

      expect(option.quoteToken, 'tok_abc123');
      expect(option.kind, 'syscom');
      expect(option.carrierCode, 'FEDEX');
      expect(option.carrierName, 'FedEx');
      expect(option.shippingTotalMxn, 149.50);
      // name agrega la etiqueta del kind.
      expect(option.name, 'FedEx (Syscom)');
      // cost usa shippingTotalMxn → freightMxn → freight → 0 en ese orden.
      expect(option.cost, 149.50);
      expect(option.isFree, isFalse);
    });

    test('usa defaults cuando faltan campos', () {
      final option = ShippingOption.fromJson({});

      expect(option.quoteToken, '');
      expect(option.name, 'Envio');
      expect(option.cost, 0);
      expect(option.isFree, isTrue);
    });

    test('carrier fallback desde `carrier` snake/alias', () {
      final option = ShippingOption.fromJson({'carrier': 'Estafeta'});

      expect(option.carrierName, 'Estafeta');
    });

    test('kind propio/local se etiqueta como Pallets / shipments', () {
      final option = ShippingOption.fromJson({
        'carrierName': 'Vito',
        'kind': 'propio',
      });

      expect(option.name, 'Vito (Pallets / shipments)');
    });

    test('coerce de freight numérico a double dé problema', () {
      final option = ShippingOption.fromJson({'freightMxn': 55});

      expect(option.freightMxn, 55.0);
      expect(option.cost, 55.0);
    });

    test('estimatedDays ya no viene del backend (contrato real)', () {
      final option = ShippingOption.fromJson({'quoteToken': 't'});

      expect(option.estimatedDays, '');
    });
  });

  group('ShippingDetails', () {
    test('toJson emite los 9 campos del contrato del backend', () {
      const details = ShippingDetails(
        recipient: 'Cliente',
        phone: '5512345678',
        street: 'Reforma',
        exteriorNumber: '12',
        neighborhood: 'Centro',
        city: 'CDMX',
        state: 'CMX',
        postalCode: '06000',
      );

      final json = details.toJson();

      expect(json, {
        'recipient': 'Cliente',
        'phone': '5512345678',
        'street': 'Reforma',
        'exteriorNumber': '12',
        'neighborhood': 'Centro',
        'city': 'CDMX',
        'state': 'CMX',
        'postalCode': '06000',
        'country': 'MEX', // default: el backend valida toUpperCase()=='MEX'
      });
    });

    test('intentalNumber vacio se omite del JSON', () {
      const details = ShippingDetails(
        recipient: 'C',
        phone: '5512345678',
        street: 'S',
        exteriorNumber: '1',
        interiorNumber: '',
        neighborhood: 'N',
        city: 'C',
        state: 'S',
        postalCode: '01000',
      );

      expect(details.toJson().containsKey('interiorNumber'), isFalse);
    });

    test('toString produce el shippingAddress legible de la orden', () {
      const details = ShippingDetails(
        recipient: 'Cliente',
        phone: '5512345678',
        street: 'Reforma',
        exteriorNumber: '12',
        neighborhood: 'Centro',
        city: 'CDMX',
        state: 'CMX',
        postalCode: '06000',
      );

      expect(details.toString(),
          'Cliente, Reforma 12, Centro, CDMX, CMX, CP 06000, Tel. 5512345678');
    });
  });

  group('ShippingQuotesResult', () {
    test('expone requiresSelection y opciones', () {
      const result = ShippingQuotesResult(
        requiresSelection: true,
        syscomOnly: false,
        baseShipping: 20,
        subtotalMxn: 1000,
        options: [ShippingOption(quoteToken: 't1', carrierName: 'FedEx')],
      );

      expect(result.requiresSelection, isTrue);
      expect(result.options.single.quoteToken, 't1');
    });
  });

  group('PaymentMethodsAvailability', () {
    test('defaults desactivados', () {
      const avail = PaymentMethodsAvailability();

      expect(avail.stripe, isFalse);
      expect(avail.paypal, isFalse);
      expect(avail.spei, isFalse);
    });

    test('constructor const', () {
      const avail = PaymentMethodsAvailability(stripe: true, spei: true);

      expect(avail.stripe, isTrue);
      expect(avail.spei, isTrue);
      expect(avail.paypal, isFalse);
    });
  });
}
