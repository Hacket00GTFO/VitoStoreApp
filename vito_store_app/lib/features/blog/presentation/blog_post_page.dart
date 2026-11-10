import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/blog_repository.dart';
import '../domain/blog_post.dart';

/// Vista de detalle de un post del blog ya cargado (desde el listado).
/// Muestra imagen hero, titulo, autor, fecha, contenido HTML y enlace a PDF.
class BlogPostPage extends StatelessWidget {
  const BlogPostPage({required this.post, super.key});

  final BlogPost post;

  Future<void> _openPdf(BuildContext context) async {
    final url = post.pdfUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el documento PDF')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero image como SliverAppBar flexible.
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            leading: IconButton(
              icon: const Icon(LucideIcons.arrowLeft),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: (post.imageUrl != null && post.imageUrl!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: post.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(LucideIcons.imageOff,
                            size: 40, color: theme.colorScheme.outline),
                      ),
                    )
                  : Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(LucideIcons.newspaper,
                          size: 40, color: theme.colorScheme.outline),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.category != null && post.category!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        post.category!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    post.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(LucideIcons.user, size: 14, color: theme.colorScheme.outline),
                      const SizedBox(width: 4),
                      Text(post.author ?? 'VITO Technologies',
                          style: theme.textTheme.bodySmall),
                      const SizedBox(width: 12),
                      if (post.formattedDate.isNotEmpty) ...[
                        Icon(LucideIcons.calendar, size: 14, color: theme.colorScheme.outline),
                        const SizedBox(width: 4),
                        Text(post.formattedDate, style: theme.textTheme.bodySmall),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (post.excerpt != null && post.excerpt!.isNotEmpty) ...[
                    Text(
                      post.excerpt!,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (post.content != null && post.content!.isNotEmpty)
                    HtmlWidget(
                      post.content!,
                      textStyle: theme.textTheme.bodyMedium,
                    )
                  else
                    Text(
                      'Contenido no disponible.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  if (post.pdfUrl != null && post.pdfUrl!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => _openPdf(context),
                      icon: const Icon(LucideIcons.fileDown),
                      label: const Text('Descargar PDF'),
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Detalle por SLUG, habilitando la ruta navegable `/blog/:slug`.
/// Es la entrada requerida por deep links (`vitoapp:///blog/<slug>`) y por
/// compartir posts: consulta `GET /blog/posts/:slug` (incrementa views y
/// trae `relatedPosts`) y renderiza la misma vista que [BlogPostPage].
class BlogPostBySlugPage extends ConsumerWidget {
  const BlogPostBySlugPage({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(blogPostDetailProvider(slug));
    return detailAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Articulo')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.newspaper,
                  size: 48, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
              const Text('No se pudo conectar con el servidor.'),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => ref.invalidate(blogPostDetailProvider(slug)),
                icon: const Icon(LucideIcons.refreshCw),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
      data: (detail) => BlogPostPage(post: detail.post),
    );
  }
}
