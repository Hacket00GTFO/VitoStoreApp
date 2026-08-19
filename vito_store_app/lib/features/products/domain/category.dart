import '../../../core/network/image_url.dart';

/// Modelo de categoria. Refleja el `Category` de Prisma.
class Category {
  Category({
    required this.id,
    required this.name,
    this.slug,
    this.icon,
    this.productCount,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString(),
      // Normalizar URL relativa de icono (/api/uploads/...) a absoluta.
      icon: resolveImageUrl(json['icon']?.toString()),
      productCount: json['productCount'] as int? ?? json['_count']?['products'] as int?,
    );
  }

  final String id;
  final String name;
  final String? slug;
  final String? icon;
  final int? productCount;
}
