/// Modelo de item del carrito.
///
/// Refleja la estructura de un item en el carrito consumido via `/api/cart`:
/// `{ id, cartId, productId, quantity, currency, product: {...} }`.
class CartItem {
  CartItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    this.currency = 'MXN',
    this.imageUrl,
    this.sku,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>?;

    // Precio efectivo: replica `getEffectivePublishedPrice` del backend
    // (descuento solo aplica si hay stock).
    final currency = (json['currency'] ??
            product?['currencySource'] ??
            product?['currency'] ??
            'MXN')
        .toString();
    double price = (product?['price'] as num? ?? json['price'] as num?)
            ?.toDouble() ??
        0;
    final discount =
        (product?['discountPercent'] as num?)?.toDouble() ?? 0;
    final stock =
        (product?['inventory']?['stock'] as num?)?.toInt() ?? 0;
    if (discount > 0 && stock > 0) {
      price = double.parse((price * (1 - discount / 100)).toStringAsFixed(2));
    }

    // Imagen: el producto puede traer `images` (array) o `imageUrl`.
    String? imageUrl;
    final images = product?['images'];
    if (images is List && images.isNotEmpty) {
      imageUrl = images.first?.toString();
    }
    imageUrl ??= (json['imageUrl'] ?? product?['imageUrl'])?.toString();

    return CartItem(
      productId:
          (json['productId'] ?? json['id'] ?? product?['id'])?.toString() ?? '',
      name: (json['name'] ?? json['productName'] ?? product?['name'])
              ?.toString() ??
          '',
      price: price,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      currency: currency,
      imageUrl: imageUrl,
      sku: (json['sku'] ?? product?['sku'])?.toString(),
    );
  }

  final String productId;
  final String name;

  /// Precio unitario efectivo en la divisa [currency] del producto.
  final double price;
  final int quantity;
  final String currency;
  final String? imageUrl;
  final String? sku;

  /// Subtotal de este item (precio * cantidad), en [currency].
  double get subtotal => price * quantity;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'price': price,
        'quantity': quantity,
        'currency': currency,
        'imageUrl': imageUrl,
        'sku': sku,
      };

  CartItem copyWith({int? quantity}) {
    return CartItem(
      productId: productId,
      name: name,
      price: price,
      quantity: quantity ?? this.quantity,
      currency: currency,
      imageUrl: imageUrl,
      sku: sku,
    );
  }
}
