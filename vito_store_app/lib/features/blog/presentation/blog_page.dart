import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/i18n/app_strings.dart';
import '../../../shared/widgets/state_view.dart';
import '../data/blog_repository.dart';
import '../domain/blog_post.dart';
import 'blog_card.dart';
import 'blog_post_page.dart';

/// Categorias disponibles para filtrar el blog (espejo de la web).
const List<String> blogCategories = [
  'Novedades',
  'Noticias',
  'Casos de exito',
  'Guias',
  'Eventos',
];

/// Provider asincrono del listado de posts, dependiente de la categoria activa.
final blogPostsProvider =
    FutureProvider.autoDispose.family<List<BlogPost>, String?>((ref, category) async {
  final repo = ref.watch(blogRepositoryProvider);
  return repo.listPosts(category: category);
});

/// Pagina de blog. Listado de posts filtrable por categoria con chips.
/// Soporta pull-to-refresh y maneja loading/error/empty/content con StateView.
class BlogPage extends ConsumerStatefulWidget {
  const BlogPage({super.key});

  @override
  ConsumerState<BlogPage> createState() => _BlogPageState();
}

class _BlogPageState extends ConsumerState<BlogPage> {
  String? _selectedCategory;

  Future<void> _refresh() async {
    ref.invalidate(blogPostsProvider(_selectedCategory));
    await ref.read(blogPostsProvider(_selectedCategory).future);
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(blogPostsProvider(_selectedCategory));

    return Scaffold(
      appBar: AppBar(title: Text(ref.tr('blog'))),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Column(
          children: [
            // Chips de categoria
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  _categoryChip(context, 'Todos', null),
                  ...blogCategories.map((c) => _categoryChip(context, c, c)),
                ],
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

  Widget _categoryChip(BuildContext context, String label, String? value) {
    final selected = _selectedCategory == value;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() => _selectedCategory = value);
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
