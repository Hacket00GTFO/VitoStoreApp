# Manual de despliegue — VitoStoreApp

## Requisitos previos

- Flutter SDK 3.35+ / Dart 3.9+
- Android Studio (o Xcode en macOS para iOS)
- Backend `desingVITO/backend` corriendo (Express + Prisma + PostgreSQL `vito_db`)
- Cuenta de Stripe (para pagos con tarjeta)
- Cuenta de Apple Developer (para App Store) y/o Google Play Console (para Play Store)

## 1. Configuración de entorno

Copia `.env.example` y configura las variables:

```bash
cp vito_store_app/.env.example vito_store_app/.env
```

Variables necesarias (se inyectan vía `--dart-define`):

| Variable | Descripción | Ejemplo |
|---|---|---|
| `API_URL` | URL base del backend | `http://10.0.2.2:3001` (emulador Android) |
| `API_URLS` | Lista de URLs candidatas (modo híbrido) | `http://localhost:3001,http://192.168.1.50:3001,https://xxx.trycloudflare.com` |
| `STRIPE_PUBLIC_KEY` | Publishable key de Stripe | `pk_test_xxx` o `pk_live_xxx` |

## 2. Conexión al backend

### Opción A: USB (desarrollo local, sin internet)

```powershell
.\scripts\connect-usb.ps1 -Run
```

### Opción B: IP LAN (misma red WiFi)

```powershell
.\scripts\connect-ip.ps1 -Run
```

### Opción C: Túnel Cloudflare (remoto, cualquier red)

```bash
# 1. Levantar el túnel
docker compose -f docker-compose.cloudflared.yml up -d

# 2. Obtener la URL
.\scripts\get-tunnel-url.ps1

# 3. Compilar con la URL del túnel
flutter run --dart-define=API_URL=https://xxxx.trycloudflare.com
```

### Opción D: Modo híbrido (USB + LAN + túnel)

```powershell
.\scripts\connect-hybrid.ps1 -Run
```

## 3. Generar APK de release (Android)

```bash
# 1. Asegurar dependencias
cd vito_store_app
flutter pub get

# 2. Compilar APK release
flutter build apk --release \
  --dart-define=API_URL=https://api.tudominio.com \
  --dart-define=STRIPE_PUBLIC_KEY=pk_live_xxx

# 3. El APK queda en:
# build/app/outputs/flutter-apk/app-release.apk
```

### Firmado del APK

1. Generar keystore (una sola vez):

```bash
keytool -genkey -v -keystore ~/vito-upload-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias vito
```

2. Configurar `android/key.properties`:

```properties
storePassword=********
keyPassword=********
keyAlias=vito
storeFile=/path/to/vito-upload-key.jks
```

3. Referenciar en `android/app/build.gradle`:

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

## 4. Generar IPA de release (iOS)

> Requiere macOS con Xcode.

```bash
cd vito_store_app

# 1. Instalar dependencias
flutter pub get

# 2. Compilar iOS
flutter build ipa --release \
  --dart-define=API_URL=https://api.tudominio.com \
  --dart-define=STRIPE_PUBLIC_KEY=pk_live_xxx

# 3. El IPA queda en:
# build/ios/ipa/vito_store_app.ipa
```

### Firmado y App Store

1. Abrir `ios/Runner.xcworkspace` en Xcode.
2. Configurar Signing & Capabilities:
   - Team: Apple Developer Team
   - Bundle Identifier: `com.vitotechnologies.storeapp`
3. Crear App Store Connect record.
4. Subir con `flutter build ipa` + Transporter o `xcrun altool --upload-app`.

## 5. Iconos de la app

### Generar iconos automáticamente

Usar [flutter_launcher_icons](https://pub.dev/packages/flutter_launcher_icons):

```yaml
# flutter_launcher_icons.yaml
flutter_icons:
  android: true
  ios: true
  image_path: "assets/icon/vito-icon.png"
  adaptive_icon_background: "#0066CC"
  adaptive_icon_foreground: "assets/icon/vito-icon-foreground.png"
```

```bash
dart run flutter_launcher_icons
```

### Icono requerido

- PNG 1024x1024 px para el icono base.
- Foreground PNG 1024x1024 con padding para Android adaptive icons.

## 6. Splash screen nativo

### Android (`android/app/src/main/res/drawable/launch_background.xml`)

Configurar con el color de marca `#0066CC` y logo centrado.

### iOS (`ios/Runner/Assets.xcassets/LaunchImage.imageset`)

Reemplazar las imágenes de launch con el logo de VITO sobre fondo azul.

## 7. Publicación

### Google Play Store

1. Crear cuenta de Google Play Console ($25 USD una sola vez).
2. Crear aplicación con package `com.vitotechnologies.storeapp`.
3. Subir `app-release.aab` (Android App Bundle):

```bash
flutter build appbundle --release \
  --dart-define=API_URL=https://api.tudominio.com \
  --dart-define=STRIPE_PUBLIC_KEY=pk_live_xxx
```

4. Completar ficha de Play Store (descripción, screenshots, política de privacidad).
5. Enviar a revisión.

### Apple App Store

1. Crear cuenta de Apple Developer ($99 USD/año).
2. Crear App ID y Provisioning Profile en developer.apple.com.
3. Crear app en App Store Connect.
4. Subir IPA via Transporter o `xcrun altool`.
5. Completar ficha de App Store (descripción, screenshots, política de privacidad).
6. Enviar a revisión.

## 8. Variables de producción

Para producción, usar:

- `API_URL`: URL pública del backend (ej. `https://api.vitotechnologies.com`)
- `STRIPE_PUBLIC_KEY`: `pk_live_xxx` (clave de producción de Stripe)
- HTTPS obligatorio (no cleartext traffic)

## 9. Verificación pre-release

- [ ] `flutter analyze` sin errores ni warnings
- [ ] `flutter test` — todos los tests pasan
- [ ] Probar en dispositivo físico (Android e iOS)
- [ ] Probar flujo completo: login → catálogo → carrito → checkout → cuenta
- [ ] Probar notificaciones push
- [ ] Probar chatbot en tiempo real
- [ ] Verificar dark mode
- [ ] Verificar accesibilidad (VoiceOver / TalkBack)
- [ ] Sin `debugPrint` en código de release
- [ ] Sin `debugShowCheckedModeBanner`
- [ ] Iconos y splash screen configurados
- [ ] Keystore configurado y APK firmado
- [ ] Política de privacidad publicada

## 10. Rollback

Si hay problemas en producción:

1. **Android**: Revertir a la versión anterior en Play Console (promover versión anterior).
2. **iOS**: Usar "Phased Release" en App Store Connect para pausar el rollout.
3. **Backend**: Mantener compatibilidad de API — la app no rompe si el backend agrega campos nuevos.
