import 'package:flutter_test/flutter_test.dart';

import 'package:vito_store_app/features/products/domain/product.dart';

void main() {
  group('Product.fromJson', () {
    test('creates a valid Product from a complete JSON map', () {
      final json = {
        'id': 'prod-1',
        'name': 'Laptop Pro 14',
        'sku': 'LAP-PRO-14',
        'description': 'Laptop de 14 pulgadas',
        'price': 18999.0,
        'currency': 'MXN',
        'imageUrl': 'https://cdn.example.com/laptop.jpg',
        'images': [
          'https://cdn.example.com/laptop-1.jpg',
          'https://cdn.example.com/laptop-2.jpg',
        ],
        'categoryId': 'cat-5',
        'categoryName': 'Laptops',
        'brand': 'VitoTech',
        'stock': 25,
        'featured': true,
        'discountPercentage': 10.0,
        'slug': 'laptop-pro-14',
      };

      final product = Product.fromJson(json);

      expect(product.id, 'prod-1');
      expect(product.name, 'Laptop Pro 14');
      expect(product.sku, 'LAP-PRO-14');
      expect(product.description, 'Laptop de 14 pulgadas');
      expect(product.price, 18999.0);
      expect(product.currency, 'MXN');
      expect(product.imageUrl, 'https://cdn.example.com/laptop.jpg');
      expect(product.categoryId, 'cat-5');
      expect(product.categoryName, 'Laptops');
      expect(product.brand, 'VitoTech');
      expect(product.stock, 25);
      expect(product.featured, isTrue);
      expect(product.discountPercentage, 10.0);
      expect(product.slug, 'laptop-pro-14');
    });

    test('resolves categoryName from nested category object', () {
      final product = Product.fromJson({
        'id': '1',
        'name': 'Mouse',
        'category': {'name': 'Perifericos'},
      });

      expect(product.categoryName, 'Perifericos');
    });

    test('resolves stock from nested inventory object', () {
      final product = Product.fromJson({
        'id': '1',
        'name': 'Mouse',
        'inventory': {'quantity': 7},
      });

      expect(product.stock, 7);
    });

    test('handles null/missing fields with defaults', () {
      final product = Product.fromJson({});

      expect(product.id, '');
      expect(product.name, '');
      expect(product.sku, isNull);
      expect(product.description, isNull);
      expect(product.price, isNull);
      expect(product.currency, 'MXN');
      expect(product.imageUrl, isNull);
      expect(product.images, isEmpty);
      expect(product.categoryId, isNull);
      expect(product.categoryName, isNull);
      expect(product.brand, isNull);
      expect(product.stock, isNull);
      expect(product.featured, isFalse);
      expect(product.discountPercentage, isNull);
      expect(product.slug, isNull);
    });

    test('normalizes imageUrl to absolute and inserts it at front of images', () {
      final product = Product.fromJson({
        'id': '1',
        'name': 'X',
        'imageUrl': 'https://cdn.example.com/main.jpg',
        'images': ['https://cdn.example.com/extra.jpg'],
      });

      expect(product.imageUrl, 'https://cdn.example.com/main.jpg');
      expect(product.images.first, 'https://cdn.example.com/main.jpg');
      expect(product.images, contains('https://cdn.example.com/extra.jpg'));
      expect(product.images.length, 2);
    });

    test('does not duplicate imageUrl when already present in images', () {
      final product = Product.fromJson({
        'id': '1',
        'name': 'X',
        'imageUrl': 'https://cdn.example.com/main.jpg',
        'images': ['https://cdn.example.com/main.jpg'],
      });

      expect(product.images.where((u) => u == 'https://cdn.example.com/main.jpg').length, 1);
    });
  });

  group('Product.hasDiscount', () {
    test('returns true when discountPercentage is set and greater than 0', () {
      final product = Product.fromJson({
        'id': '1',
        'name': 'X',
        'price': 100.0,
        'discountPercentage': 15.0,
      });

      expect(product.hasDiscount, isTrue);
    });

    test('returns false when discountPercentage is null', () {
      final product = Product.fromJson({
        'id': '1',
        'name': 'X',
        'price': 100.0,
      });

      expect(product.hasDiscount, isFalse);
    });

    test('returns false when discountPercentage is 0', () {
      final product = Product.fromJson({
        'id': '1',
        'name': 'X',
        'price': 100.0,
        'discountPercentage': 0.0,
      });

      expect(product.hasDiscount, isFalse);
    });
  });

  group('Product.finalPrice', () {
    test('returns the discounted price when hasDiscount is true', () {
      final product = Product.fromJson({
        'id': '1',
        'name': 'X',
        'price': 1000.0,
        'discountPercentage': 25.0,
      });

      expect(product.finalPrice, closeTo(750.0, 0.001));
    });

    test('returns the original price when there is no discount', () {
      final product = Product.fromJson({
        'id': '1',
        'name': 'X',
        'price': 1000.0,
      });

      expect(product.finalPrice, 1000.0);
    });

    test('returns null when price is null', () {
      final product = Product.fromJson({
        'id': '1',
        'name': 'X',
        'discountPercentage': 10.0,
      });

      expect(product.finalPrice, isNull);
    });
  });
}
