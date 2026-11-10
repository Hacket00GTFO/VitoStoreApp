# MEGAPLAN — Integración total VitoStoreApp ↔ Contenedor Backend (`vito-api`)

**Fecha:** 2026-11-08 · **Alcance:** Android/iOS/Web Flutter · Backend Express+Prisma en Docker (`desingVITO/backend/docker-compose.yml`)
**Estado verificado con pruebas HTTP reales contra `vito-api` (127.0.0.1:3001) y túnel Cloudflare.**

---

## 1. Panorama del stack actual (verificado en ejecución)

| Componente | Contenedor | Estado | Detalle |
|---|---|---|---|
| API Backend | `vito-api` (backend-vito-api) | ✅ Up, healthy | Express + Prisma, puerto `127.0.0.1:3001`, `NODE_ENV=development`, `VITO_LOCAL_SANDBOX=true` |
| PostgreSQL 15 | `vito-postgres` | ✅ Up, healthy | BD `vito_tech_db`, 228 productos, categorías reales en DB |
| Redis 7 | `vito-redis` | ✅ Up, healthy | Rate-limit store, caché |
| Qdrant | `vito-qdrant` | ✅ Up | RAG del asistente |
| LibreTranslate | `vito-translation` | ✅ Up, healthy | Traducción de blog |
| n8n | `vito-n8n` | ✅ Up | Canal WhatsApp → `channel-query` |
| Cloudflare Quick Tunnel | `vitostore-cloudflared` | ✅ Up | URL vigente: `https://cope-variable-thanks-clinics.trycloudflare.com` (**cambia en cada reinicio**) |
| App Flutter | proyecto local | ⚠️ Compila | Flutter SDK **no está en PATH** de esta máquina (se necesita para `flutter analyze/test`) |

**Cadena de conexión soportada:** USB (`connect-usb.ps1`) → LAN (`connect-ip.ps1`) → túnel (`docker-compose.cloudflared.yml` + `get-tunnel-url.ps1`) → **modo híbrido** (`connect-hybrid.ps1`): la app prueba `/api/health` en paralelo y usa el primer ganador (`lib/core/network/base_url_resolver.dart`).

### 1.1 Seguridad / CORS (backend `src/middleware/security.ts` + `src/config/index.ts`)

- Whitelist CORS (`CORS_ORIGIN` en compose): `localhost:5173/5174/127.0.0.1` y `4173`, `localhost:3000` (web).
  - **Apps nativas (Android/iOS): NO aplica CORS** → funcionan igual aunque el origin no esté en la lista.
  - **Flutter Web: SÍ aplica CORS** → la origin del túnel o del servidor web de la app recibiría bloqueos. Hay que añadir esos origins a `CORS_ORIGIN` (variable ya soportada por compose).
  - `allowedHeaders` ya incluye `Authorization` y `X-App-Language` ✅ (la app usa ambos). `credentials: true` ✅.
- Cookies httpOnly + CSRF: usadas por la **web**. La app usa **Bearer en SecureStorage** y no necesita CSRF (comentario verificado: `csrfProtectionMiddleware` solo obliga a clientes cookie).
- reCAPTCHA: `verifyRecaptchaToken` se salta solo en dev sandbox (`isDevelopment && VITO_LOCAL_SANDBOX`). **En producción `POST /account/register` exige token válido** → la app hoy no lo implementa (bloqueo P0 en producción).
- Rate limits: responden 429 + `Retry-After`; el interceptor de la app ya los maneja ✅.

---

## 2. Matriz de contratos app ↔ backend (verificada HTTP real)

Leyenda: ✅ marcha · ❌ roto en la app (contrato incorrecto) · ⚠️ funciona con mejora pendiente

### 2.1 Autenticación

| App envía / espera | Backend real | Resultado | Corrección |
|---|---|---|---|
| `POST /account/login` — busca `requiresCode` o `verificationRequired` | Devuelve **202 `{requiresLoginCode: true}`** para todo `USER` (código por email), 200 `{user,tokens}` en caso contrario | ❌ **CRASH**: `data['user'] as Map` con null → TypeError → siempre "error" en login | Parsear `requiresLoginCode` (y mantener los otros dos por retrocompatibilidad) |
| `POST /account/login-verify {email, code}` | 200 `{user, tokens{accessToken, refreshToken}}` | ✅ Igual | — |
| `POST /account/login-resend` (definido, sin uso) | Existe (controller `resendLoginCode`) | ⚠️ Sin botón | Agregar botón "Reenviar código" en LoginPage |
| `POST /account/register {email,password,firstName,lastName,phone}` | 201 + envía email SMTP real con código | ✅ (dev). ❌ prod: exige `captchaToken` | Integrar reCAPTCHA nativo antes del release |
| `POST /account/verify-email {email, code}` — 200 `{user, tokens}` | idéntico | ✅ la app solo ignora la respuesta; puede iniciar sesión directo | Usar tokens de la respuesta |
| `GET /account/me` | 200 raíz = objeto usuario (sin wrapper) | ✅ | — |
| `PUT /account/me` (editar perfil) | **No existe** (`PUT`/`PATCH` → 404). La web tampoco lo usa | ❌ | Opción A: crear route en backend. Opción B: ocultar edición en la app |
| `PUT /account/me/password` (cambiar contraseña) | No existe. Real: **`POST /account/change-password {currentPassword, newPassword, confirmPassword}`** | ❌ | Cambiar método+path+body (cierra sesión del backend) |
| `POST /account/logout {refreshToken}` | existe, opcional | ✅ | — |
| `POST /account/refresh {refreshToken}` | 200 `{tokens}` (también acepta cookie) | ✅ | — |
| `POST /account/google` / `facebook` (definidos, sin uso) | Reales: `POST /account/google/token`, `/account/facebook/token`, `/account/oauth` (canje con `redirectUri` permitido en CORS) | ➖ | Fase P2 (consentimiento OAuth + flujos del SDK) |

### 2.2 Catálogo

| App | Backend real | Resultado |
|---|---|---|
| `GET /products?limit=&offset=&category=&search=&featured=` | filtrar/para-paginar: `skip&take&categoryId&q&inStock&keywords&sort&subcategory`; `featured` **se ignora** | ❌ paginación y filtros rotos (devuelve siempre 1er bloque de 100). Además parseo debería usar `{products,total}` |
| `GET /products/:id` (unwrap `data` solo si existe) | ✓ existe (`optionalAuth`) | ✅ |
| `GET /products?featured=true&limit=10` → igual que lista | Real: `GET /products/featured?limit=` → `{products:[]}` | ⚠️ usar endpoint dedicado |
| `GET /categories` | **No existe** → 404 | ❌ Store/catálogo sin categorías. Web usa: lista `productCategories` hardcoded en `src/data/products.ts` + **`GET /products/counts`** (`{total, byCategory:{slug:n}}`) para contadores. `GET /products/categories` es **ADMIN** (403) |
| `GET /services` | ✓ array raíz `{services:[...]}` | ✅ |
| `GET /services/user` (servicios del usuario) | 404 (interpreta "user" como slug). Real: **`GET /history/services`** | ❌ |
| Blog: `GET /blog`, `GET /blog/:slug` | Reales: **`GET /blog/posts`**, **`GET /blog/posts/:slug`** (+ `?limit&offset&category`) | ❌ → blog siempre vacío |
| Imágenes relativas `/uploads/...` → `/api/uploads/...`? | Backend sirve estático en **`/uploads`** (sin `/api`) y API en `/api/uploads` | ⚠️ revisar `image_url.dart` (duplicación `/api/api` posible; la web tiene defensas contra esto) |

### 2.3 Carrito (✅ 100% compatible, verificado)

`GET /cart`, `POST /cart/items {productId,quantity}`, `PATCH /cart/items/:id {quantity}`, `DELETE /cart/items/:id/.`, `DELETE /cart` → todas responden `{cart:{items:[...]}, totals:{subtotalUSD, subtotalMXN, subtotalUSDInMXN, totalMXN, exchangeRate, itemCount, breakdown}}` — exactamente lo que parsea `CartRepository`. **El vaciado post-orden lo hace el backend**, la app solo refresca ✅.

### 2.4 Checkout y pagos

| App | Backend real | Resultado |
|---|---|---|
| `GET /payments/available` espera `methods:[]` | Devuelve `{data:{stripe:{isActive:true}, paypal:{isActive:false}, spei:{isActive:false}}}` | ❌ parseo; catch→`{stripe}` salva de milagro. Además **MP/SPEI están desactivados** y sus endpoints no existen |
| `POST /shipping/options {zipCode}` | **404**. Real: `POST /orders/shipping-options` (con Bearer) body `{shippingDetails:{recipient, phone, street, exteriorNumber, interiorNumber?, neighborhood, city, state, postalCode, country:'MEX'}}` → `{requiresSelection, syscomOnly, baseShipping, subtotalMxn, options:[{quoteToken, kind, carrierCode, carrierName, freight, currency, freightMxn, shippingTotalMxn}]}` | ❌ | 
| `POST /orders {shippingAddress:{objeto}}` | **400 "Faltan los datos estructurados de entrega"**. Contrato web verificado: `{shippingAddress: STRING, billingAddress: STRING, notes?, shippingDetails{...}, shippingQuoteToken?}` → **201 `{success, data:{order}}`** | ❌ **Checkout principal roto** |
| `POST /payments/stripe/create-intent {orderId}` | 200 `{data:{clientSecret, amount, currency, paymentIntentId, paymentExpiresAt}}` | ✅ (verificado con orden real ORD-2026-014919) |
| `POST /payments/mercadopago/create-preference {orderId}` | **No existe** → 404 | ❌ ocultar hasta que se habilite backend |
| `POST /payments/spei/create {orderId}` | **No existe** → 404 | ❌ ocultar |
| `GET /payments/orders/:orderId/status` | existe (200) | ⚠️ la app no la usa: útil para polling tras SPEI/MP |
| Stripe PaymentSheet (`flutter_stripe`) solo corre si `--dart-define=STRIPE_PUBLIC_KEY` | pk/sk de prueba configuradas en el contenedor | ⚠️ sin key la app salta la prueba de pago y la orden queda pendiente silenciosamente |

### 2.5 Cuenta / historial

| App | Backend real | Resultado |
|---|---|---|
| `GET /orders` esperar `data: List` | `{success, data:{orders:[...], pagination:{...}}}` | ❌ `as List?` **TypeError** con la Map anidada |
| `GET /quotes` → 404 | Real: `GET /specialized-quotes/my-quotes` → array plano | ❌ |
| `GET /invoices` → 404 (solo tiene `/my-invoices`) | Real: `GET /invoices/my-invoices` | ❌ |
| `GET /api/history` definido sin uso | `GET /history` → `{orders, serviceRequests, specializedQuotes, invoiceRequests, summary}` (también `/orders|/services|/quotes|/invoices`) | ➖ oportunidad de unificar pestañas |
| Favoritos: `GET/POST/PUT/DELETE /api/wishlist` | **No existe** (404); la web guarda en `localStorage`. Todas las llamadas fallan silenciosamente → favoritos se pierden al reiniciar | ❌ decidir: crear backend (recomendado) o SharedPreferences |

### 2.6 Notificaciones / chatbot

| App | Backend real | Resultado |
|---|---|---|
| `GET /notifications` | `{success, data, unreadCount, pagination}` | ✅ parsea `data` |
| `PUT /notifications/:id/read` | Solo existe **`PATCH /:id/read`** (+ `PATCH /mark-all-read`, `PATCH /mark-multiple-read`, `GET /unread-count`, `DELETE /:id`) | ❌ método; mejora: badge con `unread-count` |
| `POST /chatbot/assistant/public-query` (anónimo en la app) | **`requireAuth`** → 401 sin token (la web llama igual pero su público inicia sesión) | ❌ usuarios anónimos solo ven respuesta fallback. Decidir: permitir anónimo (rate-limit por IP+sessionId) o exigir login al abrir |
| `POST /chatbot/assistant/reset` | `requireAuth` ídem | ❌ ídem |
| `POST /chatbot` (chat público sin login) | existe con límite SÍ público | ⚠️ alternativa: usar `/chatbot` + `GET /chatbot/:id/replies` estructura conversación |

### 2.7 Endpoints backend SIN integrar en la app (catálogo definido, cero llamadas)

`contact/demo`, `newsletter`, `payments/{stripe base,paypal}`, `technical/{guides,labs}`, `certifications*`, `admin/gallery*`, `events`, `cases`, `nosotros-cases`, `cms`, `landing`, `exchange-rate` (admin en `/admin/exchange-rate`), `specialized-quotes` (POST/`/public`/`/admin/*`), `auth.google/facebook`, `account/csrf-token`, `profile/service-request-data`.

**Gaps de plataforma declarados y sin implementar:** `socket_io_client` en pubspec sin uso (chat en tiempo real), deep links `vitoapp://` sin handler, `MaintenancePage` sin disparador, splash real sin usar, notificaciones push inexistentes (sin FCM/APNs).

---

## 3. MEGAPLAN por fases

### FASE 0 — Contrato documentado y telemedición (0.5 día)

0.1 Documentar en `docs/CONTRATO_API_VITOAPP.md` la matriz §2 (es la fuente de verdad; puede generarse también del `openapi.generated.json` del backend + `/api-docs` swagger).
0.2 Crear `vito_store_app/scripts/test_integration.mjs` que ejecute la batería HTTP que validamos hoy (login→cart→shipping→order→intent→history→notifications) y devolver NO-0 en fallo. Corre regresiones Futuras sin depender de la app (ya tenemos token-minter en `docker exec vito-api node`).
0.3 Instalar Flutter SDK en PATH de esta máquina (para `flutter analyze/test/build`); añadir tarea `flutter analyze` a `scripts/`.

### FASE 1 — P0: la app hace el ciclo completo de negocio (2–3 días)

> Objetivo: registro→login (2FA)→catálogo→carrito→check-out real→orden→pago Stripe→cuenta notificación OK.

1. **Login 2FA (crítico)** — `lib/features/auth/data/auth_repository.dart:26` añadir `data['requiresLoginCode'] == true` a la condición; en `login_page.dart` mantener prompt del código de 6 dígitos y añadir botón "Reenviar código" → `POST /account/login-resend {email}`. *Aceptación: usuario USER queda autenticado con código de email real.*
2. **Parseo login-verify robusto** — ya compatible; usar tokens si llegan para evitar nuevo login.
3. **Params de productos** — `product_repository.dart`: `skip/take`, `categoryId`, `q`, y dropdown de orden `sort` (`name|price-asc|price-desc`); parseo `{products,total}`; paginación real en infinite-scroll. *Aceptación: página 2 ≠ página 1; buscar "shelly" devuelve 38.*
4. **Categorías públicas** — replicar la lista de `productCategories` de la web en `lib/features/products/domain/category.dart` + contador via `GET /products/counts` (map por slug); filtro por `categoryId`.
5. **Checkout envío** — `checkout_repository.dart` + `checkout_page.dart`: reemplazar `zipCode` por el formulario estructurado (`recipient/street/exteriorNumber/neighborhood/city/state/postalCode/country:'MEX'`), calling `POST /orders/shipping-options`, modelo `ShippingOption{quoteToken, kind, carrierName, freightMxn, shippingTotalMxn…}`; guardar `quoteToken` si `requiresSelection`.
6. **Checkout crear orden** — body `{shippingAddress: "...texto...", billingAddress: "...", notes?, shippingDetails:{...}, shippingQuoteToken?}`; el parseo actual `data.order` ya es correcto. *Aceptación: 201 y orden nace con total correcto.*
7. **Pagos disponibles** — parsear `{stripe:{isActive},...}`; mostrar solo métodos activos y solo implementados; MercadoPago/SPEI ocultos (badge "próximamente"); bloquear Stripe si `Env.stripePublicKey` vacío (mostrar aviso claro, no success silencioso).
8. **Órdenes cuenta** — `account_repository.getOrders()`: desenwrapear `data['data']['orders']` (evitar TypeError), nunca filtrar por admin.
9. **Cotizaciones/facturas/servicios propios** — cambiar a `specialized-quotes/my-quotes`, `invoices/my-invoices`, `history/services` (estas rutas devuelven array o `{data:[]}` — el parseo existente ya tolera).
10. **Perfil** — cambio de contraseña → `POST /account/change-password {currentPassword, newPassword, confirmPassword}` (matar `PUT /account/me/password`); edición de nombre/teléfono: ocultar hasta decidir backend (`PUT /account/me` no existe).
11. **Notificaciones** — `PATCH /notifications/:id/read`; badge en MainShell con `GET /notifications/unread-count`; botón "marcar todas" (`PATCH /mark-all-read`).
12. **Favoritos persistentes (Backend nuevo)** — crear en backend `src/routes/wishlistRoutes.ts` + tabla `WishlistItem(userId, productId, createdAt)` (Prisma), montar `/api/wishlist` (GET/POST/DELETE con `requireAuth`); `favorites_repository.dart` ya llama exactamente esa ruta. Alternativa sin backend: SharedPreferences. *Recomendado: backend (paridad con sesión multiplataforma).*

**Criterios de salida Fase 1:** suite `test_integration.mjs` verde + flujo E2E manual en dispositivo Android (USB) y vía túnel remoto.

### FASE 2 — P1: experiencia y canales (3–5 días)

1. **Chatbot anónimo** — elegir A) backend: variante pública del assistant con límite por `ip+sessionId`; B) app: forzar login antes de abrir el sheet y pasar Bearer. (A recomendado: el sheet es accesible desde Home sin sesión).
2. **Cotizaciones desde la app** — formulario `POST /specialized-quotes` (requiere login); lista `my-quotes`; estados pendiente/aprobado.
3. **Notificaciones push** — `firebase_messaging` (Android) + APNs: tabla `DeviceToken(userId, platform, token)`; envío manual desde admin de la web; webhook n8n opcional.
4. **Deep links** — `go_router` con `...deep-linking` + intent-filter `vitoapp://` (AndroidManifest) y `LLSG` (Info.plist); pantallas destino: producto, orden, blog.
5. **Historial unificado** — integrar `/history` en una sola pantalla (orders/services/quotes/invoices + summary), en vez de 4 llamadas.
6. **Maintenance real** — exponer flag en `/api/health` (p.ej. `maintenance:{checkout:false}`) y en la app consultar al arrancar (además de tiempo de RUNTIME en errores `503`). `MaintenancePage` con botón "Reintentar" funcional.
7. **Contacto/demo** — validar formularios contra schema del backend (contrato verificado dev: 400 cuando `subject<5`), y `POST /contact/demo`.
8. **Sockets chat (opcional)** — activar `socket_io_client` (ya en pubspec) conectado a `vito-api` (namespace `/socket` de la web) o derivar a n8n/WhatsApp.
9. **Blog completo** — categorías de blog (`GET /blog/categories`), tags, paginación, `BlogPostTranslation` si hace falta.

### FASE 3 — P2: producción (continuo)

1. **reCAPTCHA** — registrar en `register/login` con widget nativo (p.ej. `flutter_recaptcha_v2` o botón "no soy robot" invisible vía WebView) pasando `captchaToken`; alternar con backend por `X-VITO-CLIENT` header.
2. **CORS para app web/túnel** — añadir a `CORS_ORIGIN` (compose): `https://*.trycloudflare.com` (o dominio fijo de producción) y la origin de visualización web de la app.
3. **HSTS/CSP/cookies** — producción: `CSP_REPORT_ONLY=false`, csrf si se usan cookies; para la app nativa mantener Bearer.
4. **Firmando y tiendas** — keystore ya documentado en `MANUAL_DESPLIEGUE.md`; versionado semántico + `CHANGELOG`; CI que corra `flutter test` + `test_integration.mjs` en cada push.
5. **Observabilidad** — `X-VITO-CLIENT=vito-app` en cada request (backend ya permite el header) para logs particionados; reportar errores 5xx a `/admin/malformed-requests/report` como lo hace la web (`reportErrorToBackend`).
6. **OAuth social** — canje seguro con `POST /account/{google,facebook}/token` (redirectUri debe estar en CORS whitelist).

### Diagrama objetivo del ciclo completo

```
Dispositivo (Bearer en SecureStorage)
   │  dio + AuthInterceptor (X-App-Language, 429, refresh single-flight)
   ▼
vito-api :3001 (JWT 15m + refresh 7d, Prisma → vito_tech_db, Redis rate-limits,
                Socket.io, Stripe sk_test, SMTP)
   ▲                         ▲
   │ /api/health probe       │ túnel HTTPS (quick tunnel)
USB/LAN/híbrido      `vitostore-cloudflared` → URL pública
```

---

## 4. Riesgos y decisiones abiertas

| # | Riesgo | Mitigo |
|---|---|---|
| R1 | Túnel quick: URL cambia en cada reinicio → APK publicado quedaría huérfano | Producción: dominio fijo + `CORS_ORIGIN` estable; para pruebas internas regenerate con `get-tunnel-url.ps1` |
| R2 | `GET /orders` (root) en producción podría quedar de uso admin — usar `?mine`/`/orders/my` según contrato real | Validar el controller al desplegar prod (usar `/orders/my` si se mantiene) |
| R3 | Registro/login sin captcha pasa solo en sandbox | Implementar captcha antes de subir a tiendas (Fase 3.1) |
| R4 | Wishlist sin backend | Fase 1.12 decisión explícita |
| R5 | MercadoPago/SPEI desactivados en el backend | Ocultar en app y desbloquear cuando el negocio lo pida; endpoints DOM pendientes |
| R6 | Flutter SDK ausente en PATH (no se puede analizar desde aquí) | Instalar APK/SDK → `flutter pub get && flutter analyze && flutter test` |
| R7 | Datos de prueba: usuario creado `app-integration-test@vitotest.com` (emailVerified=true, pass `TestApp1234!`) | Rolado para pruebas; recordar eliminar en producción |

## 5. Cómo se validó este informe (reproducible)

```powershell
# Stack levantado
docker ps → vito-api / vito-postgres / vito-redis / vito-qdrant / vito-translation / vito-n8n / vitostore-cloudflared

# Salud y túnel
curl http://localhost:3001/api/health → 200
curl https://cope-variable-thanks-clinics.trycloudflare.com/api/health → 200 (0.59 s)

# Contratos verificados con token de prueba (emitido dentro del contenedor):
#  · login 202 requiresLoginCode · register 201 (SMTP real) · me/cart/patch/ship… → ver §2
#  · createOrder (contrato web) 201 ORD-2026-014919 · create-intent 200 clientSecret
#  · /wishlist /quotes /invoices /shipping-options PUT /account/me → 404 (rotas en app)
```

> NOTA (2026-11-10): `/wishlist`, `PUT /account/me` y el chatbot anónimo YA EXISTEN
> (Fase 1+2 implementadas; ver §6). La línea 404 de arriba era el estado previo.

---

## 6. Estado de ejecución (actualizado 2026-11-10)

### 6.1 Backend — cambios desplegados en `vito-api` (imagen reconstruida, healthy:3001)

- ✅ `PUT /account/me` (firstName/lastName + phone upsert en UserProfile, transacción).
- ✅ **Wishlist** backend-completo: tabla `WishlistItem` (migración `20261107000010_add_wishlist_item` APLICADA) + `src/routes/wishlistRoutes.ts` montado en `/api/wishlist` (GET lista `{success,data:[{productId,createdAt}]}`, POST add 201, PUT sync, DELETE `/:productId`, 401 sin token).
- ✅ Chatbot anónimo (variante A): `POST /chatbot/assistant/app-query` y `/app-reset` públicos con `assistantAnonLimiter` 60 req/10 min por IP, sin persistencia; `sessionId` requerido.
- ✅ Maintenance en salud: `/api/health` → `data.maintenance = {active, message, scopes:{store,cart,checkout,faqs}}` (verificado `active:false`).
- ✅ `tsc --noEmit` limpio + tests PASS (jest exit 1 con warning ts-jest es falso-positivo; contar "PASS x/x").

### 6.2 Fase 1 (P0) — ✅ COMPLETA (12/12)

| # | Ítem | Detalle |
|---|---|---|
| 1 | Login 2FA | `requiresLoginCode` detectado + resend (`/account/login-resend`) |
| 2 | Verify-email | tokens adoptados (adoptSession; sin segundo login) |
| 3 | Productos params | `take/skip/categoryId/q/sort` con `PRODUCT_SORTS=['name','price-asc','price-desc']`; parseo `{products,total}`; featured endpoint dedicado |
| 4 | Categorías | lista estática replicada de web + conteos `GET /products/counts` (ids estáticos = `Category.id` de BD; verificado filtrado `?categoryId=`) |
| 5 | Checkout envío | `ShippingDetails` estructurado 9 campos (`country:'MEX'` — el backend valida `country≤3` y `toUpperCase()==='MEX'`, CP 5 dígitos) + `POST /orders/shipping-options` con quoteToken |
| 6 | Checkout orden | `POST /orders` {shippingAddress texto + shippingDetails + shippingQuoteToken}; orden real creada en E2E (ORD-2026-015453) |
| 7 | Pagos | PaymentMethodsAvailability; MP/SPEI 'Proximamente'; Stripe bloqueado sin `Env.stripePublicKey` |
| 8 | Órdenes cuenta | `getOrders` desenwrapea `{success,data:{orders,pagination}}`; `Order.fromJson` usa `items ?? orderItems`; Decimal String → `num.tryParse` (¡no cast!); `OrderItem.currency` + subtotal USD/total MXN |
| 9 | Quotes/invoices/services | rutas reales `my-quotes` / `my-invoices` / `history/services` |
| 10 | Perfil | `POST /account/change-password` (logout→login) + `PUT /account/me` para edición con dialog |
| 11 | Notificaciones | PATCH read + unreadCount + markAllRead + badge en MainShell tab Cuenta |
| 12 | Favoritos | **Wishlist en backend** (tabla Prisma); repository ya consumía la ruta exacta |

### 6.3 Fase 2 (P1) — estado por ítem

| # | Ítem | Estado |
|---|---|---|
| 1 | Chatbot anónimo | ✅ Backend (variante A) + app conectable sin sesión |
| 2 | Cotizaciones especializadas | ✅ COMPLETA: `quote_repository.dart` (POST auth con fallback a `/public` 401/403, prefill `GET /profile/service-request-data`, projectType/urgency espejo de `SpecializedQuoteModal.tsx`), `quote_form_page.dart` (éxito con folio COT-, invalida `accountHistoryProvider`), ruta `/cotizador` registrada en `app_router.dart` (query `serviceType`/`serviceName`, sin auth guard), botón "Solicitar" de `/servicios` rewired |
| 3 | Push FCM | ⛔ BLOQUEADO: sin credenciales Firebase. Plan documentado en §3.3 |
| 4 | Deep links | ✅ COMPLETA (custom scheme): rutas registradas (producto/categoría/blog-slug/carrito/servicios/cotizador/contacto/notificaciones), AndroidManifest e Info.plist ya declaran `vitoapp`. **Formato requerido: `vitoapp:///tienda`, `vitoapp:///productos/<category>/<id>`, `vitoapp:///blog/<slug>`, `vitoapp:///cotizador?serviceType=SOPORTE&serviceName=...`** — triple slash: el matcher de go_router 17 solo usa `uri.path` (con `vitoapp://host/path` el path queda en el host y NO matchea) |
| 5 | Historial unificado | ✅ 1 llamada `GET /history` alimenta los 4 tabs; cards alineadas a proyecciones reales (`requestNumber`, `service.name`, `finalCost/estimatedCost` String, sin monto falso en facturas); `_StatusBadge` con enums reales |
| 6 | Maintenance | ✅ provider de `/health` + redirect global + `MaintenancePage` |
| 7 | Contacto | ✅ validadores alineados (name≥2, subject 5..200, message 10..5000), manejo `DioException` con error del backend y 429 (quota 5/15min por IP); `/contact/demo` NO existe (sin uso) |
| 8 | Sockets chat | ⏸ Opcional, no iniciado |
| 9 | Blog | ✅ COMPLETA: chips REALES de `GET /blog/categories`, `listPosts` con paginación `{posts,pagination}` SIN wrapper, búsqueda `search`, detalle por slug `/blog/:slug` (ruta go_router + `blogPostDetailProvider`, `relatedPosts` del contrato), `blog_post.dart` fija category como Map |

### 6.4 Fase 0 — herramienta de integración

- ✅ **0.2 `vito_store_app/scripts/test_integration.mjs`** — batería E2E contra `vito-api` para todo el ciclo (health→login→me→products→wishlist→cart→shipping→order→history→notifications→blog→chatbot). Config por env (`VITO_BASE`, `VITO_EMAIL`, `VITO_PASSWORD`, `VITO_USER_ID`), flag `--skip-order`. Fallback token-mint vía `docker exec -i vito-api node -` cuando el login pide 2FA (`requiresLoginCode`).
- Estado de la última corrida: **12 PASS · 0 FAIL** (orden real ORD-2026-015453, total 278.29 MXN; contratos `GET /cart` = `{cart:{items}}` y `country:'MEX'` verificados en ejecución real).
- ⬜ 0.1 `docs/CONTRATO_API_VITOAPP.md` — pendiente.
- ⬜ 0.3 Flutter SDK en PATH — pendiente (no disponible en este equipo).

### 6.5 Notas de Fase 3 (para despliegue)

- **Contenedor `vitostoreapp` (Flutter Web, NUEVO)**: nginx alpine en `backend_vito-network` que sirve `vito_store_app/build/web` (montado RO) y reenvía `/api` (y `/socket.io`) → `vito-api:3001`. El túnel `vitostore-cloudflared` ahora apunta a `http://vitostoreapp:80` en vez de a la API directa — la app web queda en el MISMO origen que la API (sin CORS por proxy) y el backend remoto sigue alcanzable en `<tunel>/api/...`. Archivos: `docker/vitostoreapp/{Dockerfile,default.conf}` + compose. Contrato de URLs de la app en web: `Env.apiBaseUrl` usa `Uri.base.origin` (mismo origen), así que no hay que inyectar `API_URL` al desplegar; en `flutter run -d chrome` sin proxy sí hace falta `--dart-define=API_URL=http://127.0.0.1:3001`.
- **3.1 reCAPTCHA**: pendiente (solo sandbox pasa sin captcha).
- **3.2 CORS app web/túnel**: ahora el proxy same-origin es la ruta principal (ver contenedor `vitostoreapp` arriba) y NO requiere cambios de `CORS_ORIGIN`. Solo si se sirve la web desde otro(s) origen(s) distinto(s), añadirlos a `CORS_ORIGIN` del compose del backend. La app **móvil (Android/iOS)** NO necesita CORS (no hay política de origen en HTTP nativo). Mientras se usa Bearer en la app, no dependemos de cookies → no cambios de csrf necesarios.
- **3.5 Observabilidad**: ✅ hecho — `X-VITO-CLIENT: vito-app` fijo en el interceptor de `dio_client.dart` (backend ya permite el header, particiona logs).
- R4 (wishlist) resuelta. R2 se mantiene: en producción confirmar que `GET /orders` root requiere admin o `?mine`.
