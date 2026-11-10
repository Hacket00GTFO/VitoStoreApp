import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/api_config.dart';
import '../../../shared/providers/providers.dart';
import '../domain/blog_post.dart';

/// Modelo ligero de categoria del blog (`GET /blog/categories`).
class BlogCategory {
  const BlogCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.postCount,
  });

  factory BlogCategory.fromJson(Map<String, dynamic> json) {
    final count = json['_count'];
    return BlogCategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      postCount: count is Map ? (count['posts'] as num?)?.toInt() : null,
    );
  }

  final String id;
  final String name;
  final String slug;
  final int? postCount;
}

/// Repositorio del blog. Consume `/api/blog/posts`, `/api/blog/posts/:slug` y
/// `/api/blog/categories` — contratos reales (respuestas SIN envoltorio
/// `success/data`; error como `{error}` y 404 si no existe el post).
class BlogRepository {
  BlogRepository(this._dio);

  final Dio _dio;

  /// Lista de posts con paginacion real y filtro por categoria (slug) opcional.
  ///
  /// Contrato: `GET /blog/posts?page=&limit=&category=&search=` →
  /// `{posts:[...], pagination:{page,limit,total,totalPages}}`.
  /// Por defecto el backend EXCLUYE la categoria `novedades` de la lista
  /// general (solo sale pidiendo `category=novedades`).
  /// `offset` (cursor de la UI) se convierte al `page` del backend.
  Future<({List<BlogPost> posts, int total})> listPosts({
    String? category,
    String? search,
    int limit = 20,
    int offset = 0,
  }) async {
    final page = (offset ~/ limit) + 1;
    final resp = await _dio.get(
      '${ApiEndpoints.blog}/posts',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (category != null && category.isNotEmpty) 'category': category,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final data = resp.data;
    final List<dynamic> items;
    int total;
    if (data is List) {
      items = data;
      total = items.length;
    } else if (data is Map<String, dynamic>) {
      items = (data['posts'] as List?) ?? const [];
      total =
          ((data['pagination'] as Map?)?['total'] as num?)?.toInt() ?? items.length;
    } else {
      items = const [];
      total = 0;
    }
    final posts = items
        .whereType<Map<String, dynamic>>()
        .map(BlogPost.fromJson)
        .toList();
    return (posts: posts, total: total);
  }

  /// Post individual por slug (cada consulta incrementa `views` en el BD).
  ///
  /// Contrato: `GET /blog/posts/:slug` → `{post, relatedPosts:[...3]}`.
  Future<({BlogPost post, List<BlogPost> related})> getPostDetail(
      String slug) async {
    final resp = await _dio.get('${ApiEndpoints.blog}/posts/$slug');
    final data = resp.data;
    if (data is Map<String, dynamic>) {
      final postJson = data['post'];
      if (postJson is Map<String, dynamic>) {
        final related = ((data['relatedPosts'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(BlogPost.fromJson)
            .toList();
        return (post: BlogPost.fromJson(postJson), related: related);
      }
    }
    throw Exception('Post no encontrado');
  }

  /// Categorias publicadas del blog con conteo de posts.
  ///
  /// `GET /blog/categories` → array plano
  /// `[{id, name, slug, color?, _count:{posts}}]`.
  Future<List<BlogCategory>> categories() async {
    final resp = await _dio.get('${ApiEndpoints.blog}/categories');
    final data = resp.data;
    final items = data is List ? data : const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(BlogCategory.fromJson)
        .toList();
  }
}

/// Provider del repositorio del blog.
final blogRepositoryProvider = Provider<BlogRepository>((ref) {
  return BlogRepository(ref.watch(dioProvider));
});

/// Provider de las categorias REALES del blog (backend). Antes la pagina
/// usaba una lista de nombres hardcodeada que ya no coincide con la BD
/// ('Noticias Corporativas', slugs, etc.).
final blogCategoriesProvider = FutureProvider<List<BlogCategory>>((ref) async {
  try {
    return await ref.watch(blogRepositoryProvider).categories();
  } catch (_) {
    // Sin categorias el blog sigue navegable con 'Todos'.
    return const <BlogCategory>[];
  }
});

/// Provider del texto de busqueda del blog (Riverpod 3: Notifier en vez del
/// StateProvider legacy).
class BlogSearchQuery extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? value) => state = value;
}

final blogSearchQueryProvider =
    NotifierProvider<BlogSearchQuery, String?>(BlogSearchQuery.new);

/// Provider del detalle de un post por slug (ruta /blog/:slug, deep links).
final blogPostDetailProvider = FutureProvider.autoDispose
    .family<({BlogPost post, List<BlogPost> related}), String>((ref, slug) {
  return ref.watch(blogRepositoryProvider).getPostDetail(slug);
});
