import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/api_config.dart';
import '../../../shared/providers/providers.dart';
import '../domain/blog_post.dart';

/// Repositorio del blog. Consume `/api/blog` y `/api/blog/:slug`
/// (mismo contrato REST que el frontend web).
class BlogRepository {
  BlogRepository(this._dio);

  final Dio _dio;

  /// Lista de posts con paginacion y filtro por categoria opcional.
  Future<List<BlogPost>> listPosts({
    String? category,
    int limit = 20,
    int offset = 0,
  }) async {
    final params = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      if (category != null && category.isNotEmpty) 'category': category,
    };
    final resp = await _dio.get(ApiEndpoints.blog, queryParameters: params);
    final data = resp.data;
    final List<dynamic> items = data is List
        ? data
        : (data['data'] as List?) ?? (data['posts'] as List?) ?? [];
    return items.map((e) => BlogPost.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Post individual por slug.
  Future<BlogPost> getPost(String slug) async {
    final resp = await _dio.get('${ApiEndpoints.blog}/$slug');
    final data = resp.data;
    final json = data is Map && data.containsKey('data') ? data['data'] : data;
    return BlogPost.fromJson(json as Map<String, dynamic>);
  }
}

/// Provider de [BlogRepository].
final blogRepositoryProvider = Provider<BlogRepository>((ref) {
  return BlogRepository(ref.watch(dioProvider));
});
