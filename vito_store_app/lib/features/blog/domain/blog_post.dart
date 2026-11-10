import '../../../core/network/image_url.dart';

/// Modelo de post del blog.
/// Refleja el recurso `/api/blog` del backend (mismo contrato que la web).
class BlogPost {
  BlogPost({
    required this.id,
    required this.title,
    required this.slug,
    this.excerpt,
    this.content,
    this.imageUrl,
    this.author,
    this.category,
    this.publishedAt,
    this.pdfUrl,
  });

  factory BlogPost.fromJson(Map<String, dynamic> json) {
    final author = json['author'];
    final category = json['category'];
    return BlogPost(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      excerpt: json['excerpt']?.toString() ?? json['summary']?.toString(),
      content: json['content']?.toString(),
      // Normalizar URL relativa (/api/uploads/...) a absoluta, como hace la web.
      imageUrl: resolveImageUrl(json['imageUrl']?.toString() ??
          json['image']?.toString() ??
          json['coverImage']?.toString()),
      author: author is Map
          ? (author['name']?.toString() ?? author['fullName']?.toString())
          : author?.toString(),
      // El backend envia `category` como objeto {id,name,slug,color}.
      category: category is Map<String, dynamic>
          ? category['name']?.toString()
          : category?.toString() ?? json['categoryName']?.toString(),
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt'].toString())
          : (json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'].toString())
              : null),
      pdfUrl: json['pdfUrl']?.toString() ?? json['pdf']?.toString(),
    );
  }

  final String id;
  final String title;
  final String slug;
  final String? excerpt;
  final String? content;
  final String? imageUrl;
  final String? author;
  final String? category;
  final DateTime? publishedAt;
  final String? pdfUrl;

  /// Fecha formateada legible (dd/MM/yyyy).
  String get formattedDate {
    if (publishedAt == null) return '';
    final d = publishedAt!;
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    return '$day/$month/$year';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'slug': slug,
        'excerpt': excerpt,
        'content': content,
        'imageUrl': imageUrl,
        'author': author,
        'category': category,
        'publishedAt': publishedAt?.toIso8601String(),
        'pdfUrl': pdfUrl,
      };
}
