import 'package:intl/intl.dart';

/// Modelo de orden. Refleja la estructura consumida via `/api/orders`.
class Order {
  Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.total,
    this.items = const [],
    this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] as List?;
    final items = itemsRaw
            ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return Order(
      id: json['id']?.toString() ?? '',
      orderNumber: (json['orderNumber'] ?? json['order_number'] ?? json['id'])?.toString() ?? '',
      status: (json['status'] as String?) ?? 'PENDING',
      total: (json['total'] as num?)?.toDouble() ?? 0,
      items: items,
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
    );
  }

  final String id;
  final String orderNumber;
  final String status;
  final double total;
  final List<OrderItem> items;
  final DateTime? createdAt;

  /// Fecha formateada para mostrar en UI.
  String get formattedDate {
    if (createdAt == null) return '--';
    final fmt = DateFormat('dd/MM/yyyy');
    return fmt.format(createdAt!);
  }

  /// Cantidad total de productos en la orden.
  int get totalItems => items.fold(0, (sum, e) => sum + e.quantity);

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

/// Item dentro de una orden.
class OrderItem {
  OrderItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    this.imageUrl,
    this.sku,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>?;
    return OrderItem(
      productId: (json['productId'] ?? product?['id'])?.toString() ?? '',
      name: (json['name'] ?? product?['name'])?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      imageUrl: (json['imageUrl'] ?? product?['imageUrl'])?.toString(),
      sku: (json['sku'] ?? product?['sku'])?.toString(),
    );
  }

  final String productId;
  final String name;
  final double price;
  final int quantity;
  final String? imageUrl;
  final String? sku;

  double get subtotal => price * quantity;
}
