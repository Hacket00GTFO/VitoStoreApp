/// Modelo de servicio. Refleja el recurso `/api/services` del backend.
class Service {
  Service({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    this.slug,
    this.price,
    this.currency = 'MXN',
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      icon: json['icon']?.toString(),
      slug: json['slug']?.toString(),
      price: (json['price'] as num?)?.toDouble(),
      currency: json['currency']?.toString() ?? 'MXN',
    );
  }

  final String id;
  final String name;
  final String? description;
  final String? icon;
  final String? slug;
  final double? price;
  final String currency;
}
