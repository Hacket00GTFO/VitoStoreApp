import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../products/data/category_repository.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/category.dart';
import '../../products/domain/product.dart';
import '../../products/presentation/product_card.dart';

/// Home page completo.
///
/// SliverAppBar hero con gradiente, carrusel horizontal de productos
/// destacados, grid de categorias, grid de servicios y CTA de contacto.
/// Usa [ProductRepository.featured] y [CategoryRepository.list].
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  static const _quickServices = <_ServiceQuick>[
    _ServiceQuick(
      icon: LucideIcons.wrench,
      title: 'Soporte tecnico',
      route: '/servicios',
    ),
    _ServiceQuick(
      icon: LucideIcons.monitor,
      title: 'Instalacion',
      route: '/servicios',
    ),
    _ServiceQuick(
      icon: LucideIcons.shieldCheck,
      title: 'Garantia',
      route: '/servicios',
    ),
    _ServiceQuick(
      icon: LucideIcons.network,
      title: 'Redes',
      route: '/servicios',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featuredAsync = ref.watch(featuredProductsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(featuredProductsProvider);
          ref.invalidate(categoriesProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'VITO Technologies',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                ),
                child: const Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 56),
                    child: Text(
                      'Tecnologia que impulsa tu negocio',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Carrito',
                icon: const Icon(LucideIcons.shoppingCart, color: Colors.white),
                onPressed: () => context.push('/carrito'),
              ),
              IconButton(
                tooltip: 'Favoritos',
                icon: const Icon(LucideIcons.heart, color: Colors.white),
                onPressed: () => context.push('/favoritos'),
              ),
            ],
          ),

          // Accesos rapidos
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              delegate: SliverChildListDelegate([
                _QuickAccess(
                  icon: LucideIcons.package,
                  title: 'Productos',
                  onTap: () => context.push('/productos'),
                ),
                _QuickAccess(
                  icon: LucideIcons.wrench,
                  title: 'Servicios',
                  onTap: () => context.push('/servicios'),
                ),
                _QuickAccess(
                  icon: LucideIcons.newspaper,
                  title: 'Blog',
                  onTap: () => context.push('/blog'),
                ),
                _QuickAccess(
                  icon: LucideIcons.mail,
                  title: 'Contacto',
                  onTap: () => context.push('/contacto'),
                ),
              ]),
            ),
          ),

          // Productos destacados (carrusel horizontal)
          _SectionHeader(title: 'Productos destacados'),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 280,
              child: featuredAsync.when(
                data: (products) => products.isEmpty
                    ? const _EmptyInline(message: 'Sin productos destacados')
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: products.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final Product p = products[i];
                          return SizedBox(
                            width: 160,
                            child: ProductCard(product: p),
                          );
                        },
                      ),
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (e, _) => _EmptyInline(message: 'No se pudo cargar: $e'),
              ),
            ),
          ),

          // Categorias
          _SectionHeader(
            title: 'Categorias',
            actionLabel: 'Ver todo',
            onAction: () => context.push('/productos'),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: categoriesAsync.when(
              data: (cats) => cats.isEmpty
                  ? const SliverToBoxAdapter(
                      child: _EmptyInline(message: 'Sin categorias'))
                  : SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.1,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _CategoryTile(category: cats[i]),
                        childCount: cats.length,
                      ),
                    ),
              loading: () => const SliverToBoxAdapter(
                child: SizedBox(
                  height: 120,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (e, _) => const SliverToBoxAdapter(
                child: _EmptyInline(message: 'No se pudieron cargar categorias'),
              ),
            ),
          ),

          // Servicios (grid rapido)
          _SectionHeader(
            title: 'Servicios',
            actionLabel: 'Ver todo',
            onAction: () => context.push('/servicios'),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.4,
              ),
              delegate: SliverChildListDelegate([
                for (final s in _quickServices) _ServiceTile(service: s),
              ]),
            ),
          ),

          // CTA contacto
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Card(
                color: AppColors.primary,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(LucideIcons.headphones, color: Colors.white, size: 32),
                      const SizedBox(height: 12),
                      Text(
                        'Necesitas ayuda?',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Contacta a nuestro equipo y recibe asesoria personalizada.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 48,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                          ),
                          onPressed: () => context.push('/contacto'),
                          icon: const Icon(LucideIcons.mail),
                          label: const Text('Contactar ahora'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            if (actionLabel != null && onAction != null)
              TextButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickAccess extends StatelessWidget {
  const _QuickAccess({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final hasImage = category.icon != null && category.icon!.isNotEmpty;
    return Card(
      child: InkWell(
        onTap: () =>
            context.push('/productos/${category.slug ?? category.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (hasImage)
                CachedNetworkImage(
                  imageUrl: category.icon!,
                  height: 36,
                  width: 36,
                  errorWidget: (_, __, ___) => Icon(
                    LucideIcons.tag,
                    size: 28,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              else
                Icon(LucideIcons.tag,
                    size: 28, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 6),
              Text(
                category.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              if (category.productCount != null)
                Text(
                  '${category.productCount} productos',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                        fontSize: 10,
                      ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceQuick {
  const _ServiceQuick({
    required this.icon,
    required this.title,
    required this.route,
  });
  final IconData icon;
  final String title;
  final String route;
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service});

  final _ServiceQuick service;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () => context.push(service.route),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(service.icon,
                  size: 28, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  service.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const Icon(LucideIcons.chevronRight, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyInline extends StatelessWidget {
  const _EmptyInline({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      ),
    );
  }
}
