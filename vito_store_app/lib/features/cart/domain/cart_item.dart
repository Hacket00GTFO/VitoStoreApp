/// Modelo de item del carrito.
///
/// Refleja la estructura de un item en el carrito consumido via `/api/cart`.
class CartItem {
  CartItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    this.imageUrl,
    this.sku,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>?;
    return CartItem(
      productId: (json['productId'] ?? json['id'] ?? product?['id'])?.toString() ?? '',
      name: (json['name'] ?? json['productName'] ?? product?['name'])?.toString() ?? '',
      price: (json['price'] as num? ?? (product?['price'] as num?))?.toDouble() ?? 0,
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

  /// Subtotal de este item (precio * cantidad).
  double get subtotal => price * quantity;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'price': price,
        'quantity': quantity,
        'imageUrl': imageUrl,
        'sku': sku,
      };

  CartItem copyWith({int? quantity}) {
    return CartItem(
      productId: productId,
      name: name,
      price: price,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl,
      sku: sku,
    );
  }
}
