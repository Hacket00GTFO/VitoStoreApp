# VitoStoreApp — Cliente móvil de VITO Technologies

App móvil **Flutter** (iOS + Android) que replica el diseño y la funcionalidad del cliente del proyecto `desingVITO` (web), consumiendo el **mismo backend Express/Prisma/PostgreSQL** y consultando la **misma base de datos** (`vito_db`) vía la API REST compartida.

## Principio: una base de datos, dos clientes

La app **no tiene base de datos propia**. Tanto la web como la app consultan la misma API REST del backend Express, que opera sobre una única PostgreSQL (`vito_db`). El usuario puede elegir libremente entre usar la **web** o la **app** en cualquier momento, con los mismos datos, misma cuenta, mismos pedidos, mismo carrito y misma sesión.

## Stack

- **Flutter** 3.35+ / Dart 3.9+
- **Riverpod** (estado: auth, cart, wishlist, language)
- **dio** (HTTP + interceptores: Bearer auth, refresh single-flight, X-App-Language)
- **go_router** (navegación declarativa + guards + deep links)
- **flutter_secure_storage** (tokens en keychain/keystore)
- **socket_io_client** (chatbot en tiempo real)
- **cached_network_image** (imágenes de S3/Cloudinary)
- **flutter_stripe** (pagos)
- **lucide_icons** (mismo set de iconos que la web)
- **Montserrat** (vía google_fonts; empaquetar .ttf para producción)

## Configuración

Copia `.env.example` y configura las variables via `--dart-define`:

```bash
flutter run \
  --dart-define=API_URL=http://localhost:3001 \
  --dart-define=STRIPE_PUBLIC_KEY=pk_test_tu_clave
```

## Ejecutar

```bash
flutter pub get
flutter run
```

## Diseño

- Paleta de marca `vito-*` replicada de `tailwind.config.js` de la web.
- Material 3 con dark mode OLED-aware (true black background).
- Touch targets ≥48dp, CTA en thumb zone, estados loading/error/empty.
- Compatibilidad HIG iOS (edge-swipe, Dynamic Type, safe areas) + Material 3 Android (ripple, predictive back, font scale 200%).

## Estructura

```
lib/
├── main.dart              # Entry point + ProviderScope
├── app.dart               # MaterialApp.router + Theme
├── config/                # env, api_config, theme (AppColors, AppTheme)
├── core/                  # network (dio, interceptors), storage (secure)
├── features/              # auth, home, products, store, cart, checkout,
│                          # account, favorites, blog, contact, chatbot,
│                          # maintenance, notifications, services
├── shared/                # providers, layouts (MainShell)
└── routing/               # app_router (go_router + guards)
```

## Plan completo

Ver `C:\Users\Norbe\.devin\plans\plan-75695e3244f1957e.md` para el plan detallado (arquitectura, maquetación de pantallas, UX/UI, compatibilidad iOS/Android, BD compartida).

## Fases

- **Fase 0** (actual): scaffold, tema, capa de red, auth, routing, placeholders.
- Fase 1: auth completa (2FA, registro, verify, OAuth).
- Fase 2: home + navegación completa.
- Fase 3: catálogo, tienda, favoritos.
- Fase 4: carrito, checkout, Stripe.
- Fase 5: cuenta (UserHub), notificaciones.
- Fase 6: blog, eventos, contacto.
- Fase 7: chatbot Socket.IO.
- Fase 8: i18n + accesibilidad + tests.
- Fase 9: release (iconos, splash, firmado, stores).
