import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/app_strings.dart';
import '../../../shared/widgets/state_view.dart';
import '../data/blog_repository.dart';
import '../domain/blog_post.dart';
import 'blog_card.dart';
import 'blog_post_page.dart';

/// Provider asincrono del listado de posts (categoria = SLUG del backend;
/// no el nombre). El backend aplica paginacion y excluye 'novedades' de la
/// lista general. Si el backend no reporta categorias, los chips se ocultan
/// y el listado sale completo ('Todos').
final blogPostsProvider =
    FutureProvider.autoDispose.family<List<BlogPost>, String?>((ref, slug) async {
  final repo = ref.watch(blogRepositoryProvider);
  final search = ref.watch(blogSearchQueryProvider);
  final (:posts, total: _) =
      await repo.listPosts(category: slug, search: search);
  return posts;
});

/// Pagina de blog. Listado de posts filtrable por categoria con chips.
/// Soporta pull-to-refresh y maneja loading/error/empty/content con StateView.
class BlogPage extends ConsumerStatefulWidget {
  const BlogPage({super.key});

  @override
  ConsumerState<BlogPage> createState() => _BlogPageState();
}

class _BlogPageState extends ConsumerState<BlogPage> {
  String? _selectedSlug;

  Future<void> _refresh() async {
    ref.invalidate(blogPostsProvider(_selectedSlug));
    await ref.read(blogPostsProvider(_selectedSlug).future);
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(blogPostsProvider(_selectedSlug));
    final categoriesAsync = ref.watch(blogCategoriesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(ref.tr('blog'))),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Column(
          children: [
            // Chips de categoria reales del backend.
            SizedBox(
              height: 48,
              child: categoriesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (categories) {
                  final chips = <Widget>[
                    _categoryChip('Todos', null),
                    ...categories.map((c) => _categoryChip(c.name, c.slug)),
                  ];
                  return ListView(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    children: chips,
                  );
                },
              ),
            ),
            Expanded(
              child: StateView<BlogPost>(
                asyncValue: postsAsync,
                onRetry: _refresh,
                emptyMessage: 'No hay posts disponibles',
                emptyIcon: LucideIcons.fileText,
                builder: (posts) => ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return BlogCard(
                      post: post,
                      onTap: () => _openPost(context, post),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryChip(String label, String? slug) {
    final selected = _selectedSlug == slug;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() => _selectedSlug = slug);
        },
        selectedColor: theme.colorScheme.primaryContainer,
        labelStyle: TextStyle(
          color: selected
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  void _openPost(BuildContext context, BlogPost post) {
    // Abrimos la pagina de detalle directamente (la ruta /blog/:slug no esta
    // registrada en el router, asi que usamos Navigator.push).
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BlogPostPage(post: post)),
    );
  }
}
