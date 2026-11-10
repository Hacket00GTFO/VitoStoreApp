import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/account/presentation/account_page.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/forgot_password_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/register_page.dart';
import '../features/auth/presentation/reset_password_page.dart';
import '../features/auth/presentation/verify_account_page.dart';
import '../features/blog/presentation/blog_page.dart';
import '../features/blog/presentation/blog_post_page.dart';
import '../features/cart/presentation/cart_page.dart';
import '../features/checkout/presentation/checkout_page.dart';
import '../features/contact/presentation/contact_page.dart';
import '../features/cotizaciones/presentation/quote_form_page.dart';
import '../features/favorites/presentation/favorites_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/maintenance/data/maintenance_status.dart';
import '../features/maintenance/presentation/maintenance_page.dart';
import '../features/notificaciones/presentation/notifications_page.dart';
import '../features/products/presentation/product_detail_page.dart';
import '../features/products/presentation/products_page.dart';
import '../features/services/presentation/services_page.dart';
import '../features/store/presentation/store_page.dart';
import '../shared/layouts/main_shell.dart';

/// Router global de la app (go_router) con guards de auth y bottom nav.
///
/// Estructura (sección 7 del plan):
/// - [ShellRoute] con [MainShell] (bottom nav) para: Home, Tienda, Cuenta, Favoritos.
/// - Rutas anidadas para drill-down (productos, blog, etc.).
/// - Guards: redirige a /login si requiere auth y no está autenticado.
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);
  // Estado de mantenimiento: el redirect global reacciona a su refresco.
  final maintenance = ref.watch(maintenanceStatusProvider).value;

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final isLoading = authState.status == AuthStatus.initial ||
          authState.status == AuthStatus.loading;
      final path = state.uri.path;

      // Rutas que requieren auth.
      const protectedPaths = [
        '/checkout',
        '/checkout/success',
        '/perfil',
        '/mis-transacciones',
        '/historial',
        '/mi-historial',
        '/notificaciones',
      ];
      final requiresAuth = protectedPaths.any(path.startsWith);

      // Si está cargando la sesión inicial, no redirigir aún.
      if (isLoading) return null;

      // Modo mantenimiento: redirigir todo (excepto la propia pantalla) a
      // /maintenance; al salir del modo, el refresco del provider regresa.
      if (maintenance != null && maintenance.blocksStore && path != '/maintenance') {
        return '/maintenance';
      }
      if (maintenance != null && !maintenance.blocksStore && path == '/maintenance') {
        return '/';
      }

      if (requiresAuth && !isAuthenticated) {
        // Guardar destino para redirigir tras login.
        return '/login?redirect=${Uri.encodeComponent(state.uri.toString())}';
      }

      // Si ya autenticado e intenta ir a login/register, ir al home.
      if (isAuthenticated && (path == '/login' || path == '/register')) {
        return '/';
      }
      return null;
    },
    routes: [
      // Splash inicial / carga de sesión.
      GoRoute(
        path: '/splash',
        builder: (context, state) => const _SplashScreen(),
      ),
      // Mantenimiento.
      GoRoute(
        path: '/maintenance',
        builder: (context, state) => const MaintenancePage(),
      ),
      // Auth (fuera del shell).
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterPage()),
      GoRoute(path: '/verify-account', builder: (context, state) => const VerifyAccountPage()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordPage()),
      GoRoute(path: '/reset-password', builder: (context, state) => const ResetPasswordPage()),

      // Shell con bottom nav (Inicio · Tienda · Cuenta · Favoritos).
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomePage()),
          GoRoute(path: '/tienda', builder: (context, state) => const StorePage()),
          GoRoute(
            path: '/mis-transacciones',
            builder: (context, state) => const AccountPage(),
          ),
          GoRoute(path: '/favoritos', builder: (context, state) => const FavoritesPage()),
        ],
      ),

      // Rutas fuera del shell (drill-down).
      GoRoute(path: '/nosotros', builder: (context, state) => const _PlaceholderPage(title: 'Nosotros')),
      GoRoute(path: '/productos', builder: (context, state) => const ProductsPage()),
      GoRoute(
        path: '/productos/:category',
        builder: (context, state) => ProductsPage(
          category: state.pathParameters['category'],
        ),
      ),
      GoRoute(
        path: '/productos/:category/:id',
        builder: (context, state) => ProductDetailPage(
          productId: state.pathParameters['id'] ?? '',
          category: state.pathParameters['category'],
        ),
      ),
      GoRoute(path: '/servicios', builder: (context, state) => const ServicesPage()),
      // Formulario de cotizacion especializada (Fase 2.2). Sin auth guard: si
      // hay sesion envia a POST /specialized-quotes y si no, al fallback
      // publico /specialized-quotes/public (el prefill usa datos disponibles).
      GoRoute(
        path: '/cotizador',
        builder: (context, state) => QuoteFormPage(
          initialServiceType: state.uri.queryParameters['serviceType'],
          initialServiceName: state.uri.queryParameters['serviceName'],
        ),
      ),
      GoRoute(path: '/carrito', builder: (context, state) => const CartPage()),
      GoRoute(path: '/checkout', builder: (context, state) => const CheckoutPage()),
      GoRoute(path: '/checkout/success', builder: (context, state) => const CheckoutPage(success: true)),
      GoRoute(path: '/blog', builder: (context, state) => const BlogPage()),
      // Detalle por slug: entrada para deep links (vitoapp:///blog/<slug>).
      GoRoute(
        path: '/blog/:slug',
        builder: (context, state) =>
            BlogPostBySlugPage(slug: state.pathParameters['slug'] ?? ''),
      ),
      GoRoute(
        path: '/contacto',
        builder: (context, state) => ContactPage(
          initialSubject: state.uri.queryParameters['subject'],
        ),
      ),
      GoRoute(path: '/notificaciones', builder: (context, state) => const NotificationsPage()),
      GoRoute(
        path: '/historial',
        builder: (context, state) => const _PlaceholderPage(title: 'Historial'),
      ),
      GoRoute(
        path: '/seguimiento',
        builder: (context, state) => const _PlaceholderPage(title: 'Seguimiento de pedido'),
      ),
    ],
    errorBuilder: (context, state) => _PlaceholderPage(title: 'Ruta no encontrada: ${state.path}'),
  );
});

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '$title\n\n(Placeholder — se implementa en fases posteriores)',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
