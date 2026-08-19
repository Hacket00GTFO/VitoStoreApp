import '../../../core/network/image_url.dart';

/// Modelo de producto. Refleja el `Product` de Prisma consumido via `/api/products`.
class Product {
  Product({
    required this.id,
    required this.name,
    this.sku,
    this.description,
    this.price,
    this.currency = 'MXN',
    this.imageUrl,
    this.images = const [],
    this.categoryId,
    this.categoryName,
    this.brand,
    this.stock,
    this.featured = false,
    this.discountPercentage,
    this.slug,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawImages = <String>[];
    if (json['images'] is List) {
      rawImages.addAll((json['images'] as List).map((e) => e.toString()));
    }
    // Normalizar cada URL relativa (/api/uploads/...) a absoluta, como hace
    // la web con `normalizeProductImageUrl` (data/products.ts).
    final images = rawImages.map(resolveImageUrl).whereType<String>().toList();
    final imageUrl = resolveImageUrl(json['imageUrl']?.toString());
    // Evitar duplicar la imageUrl principal al frente de la lista.
    if (imageUrl != null && !images.contains(imageUrl)) {
      images.insert(0, imageUrl);
    }

    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      sku: json['sku']?.toString(),
      description: json['description']?.toString(),
      price: (json['price'] as num?)?.toDouble(),
      currency: json['currency']?.toString() ?? 'MXN',
      imageUrl: imageUrl,
      images: images,
      categoryId: json['categoryId']?.toString(),
      categoryName: json['categoryName']?.toString() ?? json['category']?['name']?.toString(),
      brand: json['brand']?.toString(),
      stock: json['stock'] as int? ?? json['inventory']?['quantity'] as int?,
      featured: json['featured'] as bool? ?? false,
      discountPercentage: (json['discountPercentage'] as num?)?.toDouble(),
      slug: json['slug']?.toString(),
    );
  }

  final String id;
  final String name;
  final String? sku;
  final String? description;
  final double? price;
  final String currency;
  final String? imageUrl;
  final List<String> images;
  final String? categoryId;
  final String? categoryName;
  final String? brand;
  final int? stock;
  final bool featured;
  final double? discountPercentage;
  final String? slug;

  bool get hasDiscount => discountPercentage != null && discountPercentage! > 0;
  double? get finalPrice => hasDiscount && price != null
      ? price! * (1 - discountPercentage! / 100)
      : price;
}
