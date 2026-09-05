import 'package:flutter_test/flutter_test.dart';

import 'package:vito_store_app/features/account/domain/order.dart';

void main() {
  group('Order.fromJson', () {
    test('creates a valid Order from a complete JSON map', () {
      final json = {
        'id': 42,
        'orderNumber': 'ORD-1001',
        'status': 'PAID',
        'total': 1299.50,
        'createdAt': '2024-05-10T14:30:00.000Z',
        'items': [
          {
            'productId': 'p1',
            'name': 'Router WiFi 6',
            'price': 999.0,
            'quantity': 1,
            'sku': 'RTR-W6',
            'imageUrl': 'https://example.com/img1.jpg',
          },
          {
            'product': {
              'id': 'p2',
              'name': 'Cable UTP',
              'imageUrl': 'https://example.com/img2.jpg',
              'sku': 'CBL-UTP',
            },
            'price': 150.25,
            'quantity': 2,
          },
        ],
      };

      final order = Order.fromJson(json);

      expect(order.id, '42');
      expect(order.orderNumber, 'ORD-1001');
      expect(order.status, 'PAID');
      expect(order.total, 1299.50);
      expect(order.items, hasLength(2));
      expect(order.createdAt, isNotNull);

      // First item parsed directly.
      expect(order.items[0].productId, 'p1');
      expect(order.items[0].name, 'Router WiFi 6');
      expect(order.items[0].price, 999.0);
      expect(order.items[0].quantity, 1);
      expect(order.items[0].sku, 'RTR-W6');
      expect(order.items[0].imageUrl, 'https://example.com/img1.jpg');

      // Second item resolved from nested `product` object.
      expect(order.items[1].productId, 'p2');
      expect(order.items[1].name, 'Cable UTP');
      expect(order.items[1].price, 150.25);
      expect(order.items[1].quantity, 2);
      expect(order.items[1].sku, 'CBL-UTP');
    });

    test('falls back to order_number and id when orderNumber is missing', () {
      final order = Order.fromJson({
        'id': 7,
        'order_number': 'ORD-7',
        'status': 'PENDING',
        'total': 0,
      });

      expect(order.orderNumber, 'ORD-7');

      final orderFallbackId = Order.fromJson({
        'id': 99,
        'status': 'PENDING',
        'total': 0,
      });

      expect(orderFallbackId.orderNumber, '99');
    });

    test('handles missing optional fields gracefully', () {
      final order = Order.fromJson({});

      expect(order.id, '');
      expect(order.orderNumber, '');
      expect(order.status, 'PENDING');
      expect(order.total, 0);
      expect(order.items, isEmpty);
      expect(order.createdAt, isNull);
    });

    test('parses created_at snake_case as createdAt', () {
      final order = Order.fromJson({
        'id': '1',
        'created_at': '2024-01-15T00:00:00.000Z',
      });

      expect(order.createdAt, isNotNull);
      expect(order.createdAt!.year, 2024);
    });

    test('returns null createdAt for an unparseable date', () {
      final order = Order.fromJson({
        'id': '1',
        'createdAt': 'not-a-date',
      });

      expect(order.createdAt, isNull);
    });
  });

  group('Order.formattedDate', () {
    test('returns a non-empty formatted string when createdAt is set', () {
      final order = Order.fromJson({
        'id': '1',
        'createdAt': '2024-05-10T14:30:00.000Z',
      });

      final formatted = order.formattedDate;

      expect(formatted, isNotEmpty);
      expect(formatted, isNot(equals('--')));
      // Format is dd/MM/yyyy.
      expect(RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(formatted), isTrue);
    });

    test('returns placeholder when createdAt is null', () {
      final order = Order.fromJson({'id': '1'});

      expect(order.formattedDate, '--');
    });
  });

  group('Order.totalItems', () {
    test('returns the correct count summing item quantities', () {
      final order = Order.fromJson({
        'id': '1',
        'items': [
          {'productId': 'a', 'name': 'A', 'price': 10, 'quantity': 3},
          {'productId': 'b', 'name': 'B', 'price': 20, 'quantity': 2},
          {'productId': 'c', 'name': 'C', 'price': 5, 'quantity': 1},
        ],
      });

      expect(order.totalItems, 6);
    });

    test('returns 0 when there are no items', () {
      final order = Order.fromJson({'id': '1'});

      expect(order.totalItems, 0);
    });

    test('defaults quantity to 1 when missing', () {
      final order = Order.fromJson({
        'id': '1',
        'items': [
          {'productId': 'a', 'name': 'A', 'price': 10},
          {'productId': 'b', 'name': 'B', 'price': 20},
        ],
      });

      expect(order.totalItems, 2);
    });
  });

  group('OrderItem.subtotal', () {
    test('multiplies price by quantity', () {
      final item = OrderItem.fromJson({
        'productId': 'a',
        'name': 'A',
        'price': 150.0,
        'quantity': 4,
      });

      expect(item.subtotal, 600.0);
    });
  });
}
