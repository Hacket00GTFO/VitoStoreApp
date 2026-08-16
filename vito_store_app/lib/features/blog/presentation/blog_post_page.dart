import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/blog_post.dart';

/// Vista de detalle de un post del blog.
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
