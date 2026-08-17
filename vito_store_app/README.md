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
  --dart-define=API_URL=http://10.0.2.2:3001 \
  --dart-define=STRIPE_PUBLIC_KEY=pk_test_tu_clave
```

> Si usas Docker en Windows/macOS, para Android emulado la ruta correcta es `http://10.0.2.2:3001`; para iOS Simulator o desktop suele ser `http://localhost:3001`; para un dispositivo físico usa la IP del host del equipo.

## Acceso remoto (Cloudflare Tunnel)

Para usar la app de forma remota (dispositivo físico fuera de tu red, demos, pruebas) sin exponer puertos ni configurar un dominio, el repo incluye un contenedor **Cloudflare Quick Tunnel** propio de VitoStoreApp que expone `vito-api:3001` por HTTPS.

Requisito: el stack backend (`desingVITO/backend`) debe estar corriendo, ya que el túnel se une a su red Docker `backend_vito-network` como red externa.

```bash
# Desde la raíz del repo VitoStoreApp
docker compose -f docker-compose.cloudflared.yml up -d
```

Obtén la URL pública generada:

```powershell
# Opción 1: script (muestra la URL y el comando flutter run listo)
.\scripts\get-tunnel-url.ps1

# Opción 2: manual, busca la línea https://*.trycloudflare.com
docker logs vitostore-cloudflared
```

Corre la app apuntando al túnel:

```bash
flutter run --dart-define=API_URL=https://xxxx.trycloudflare.com
```

> **Importante (Quick Tunnel):** la URL `trycloudflare.com` es aleatoria y **cambia cada vez que el contenedor reinicia**. Tras un reinicio, vuelve a correr `get-tunnel-url.ps1` y recompila la app con la nueva URL. Para una URL fija se puede migrar a un Named Tunnel con token de Cloudflare Zero Trust.
>
> El nombre de la red externa (`backend_vito-network`) depende de la carpeta `backend` del proyecto desingVITO; si ese stack se levanta con otro nombre de proyecto (`docker compose -p ...`), ajusta el nombre de la red en `docker-compose.cloudflared.yml`.

Para detener solo el túnel (sin afectar el backend):

```bash
docker compose -f docker-compose.cloudflared.yml down
```

### Generar APK con acceso remoto

La URL del túnel se embebe en el APK en tiempo de compilación vía `--dart-define`, así que el APK funciona desde **cualquier dispositivo con internet**, sin configuración adicional:

```bash
# 1. Asegúrate de que el túnel esté corriendo y obtén la URL actual
.\scripts\get-tunnel-url.ps1

# 2. Compila el APK release con esa URL
cd vito_store_app
flutter build apk --release --dart-define=API_URL=https://xxxx.trycloudflare.com
```

El APK queda en `build/app/outputs/flutter-apk/app-release.apk`, listo para instalar en cualquier Android (`adb install` o copiándolo al dispositivo).

> **Advertencia:** el APK queda ligado a la URL del túnel del momento del build. Si el contenedor `vitostore-cloudflared` reinicia, la URL cambia y el APK deja de conectar — habría que recompilar con la nueva URL. Para distribuir APKs sin recompilar, migra a un **Named Tunnel** (URL fija con tu dominio, requiere cuenta Cloudflare Zero Trust).
>
> El permiso `android.permission.INTERNET` ya está declarado en `android/app/src/main/AndroidManifest.xml`, por lo que el build release puede salir a internet sin cambios extra. Al ser HTTPS (túnel Cloudflare), no se requiere `usesCleartextTraffic`.

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
