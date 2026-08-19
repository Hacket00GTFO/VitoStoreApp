import 'package:flutter/foundation.dart';

import '../../config/api_config.dart';

/// Normaliza una URL de imagen/media devuelta por el backend a una URL
/// absoluta apta para `CachedNetworkImage` / `Image.network` en móvil.
///
/// El backend devuelve URLs **relativas** como `/api/uploads/<file>` (ver
/// `toPublicUploadUrl` en `routes/uploads.ts`). En la web estas se resuelven
/// automáticamente contra el origin del backend; en móvil no hay origin, así
/// que hay que prefijar el host absoluto.
///
/// Comportamiento (espejo de `normalizeProductImageUrl` y `resolveUploadUrl`
/// de la web):
/// - URLs absolutas (`http://`, `https://`, `data:`, `blob:`) → tal cual.
/// - `/uploads/...` → se normaliza a `/api/uploads/...` y se prefija el origin.
/// - `/api/...` u otra ruta relativa → se prefija el origin del backend.
/// - `null` o vacío → `null`.
String? resolveImageUrl(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  // URLs absolutas: sin tocar.
  if (RegExp(r'^(https?:|data:|blob:)', caseSensitive: false).hasMatch(trimmed)) {
    return trimmed;
  }

  var path = trimmed;
  // Normalizar /uploads/ → /api/uploads/ (espejo de la web).
  if (path.startsWith('/uploads/')) {
    path = '/api$path';
  } else if (!path.startsWith('/')) {
    path = '/$path';
  }

  // Origin = baseUrl sin el sufijo /api.
  final base = ApiConfig.baseUrl;
  final origin = base.endsWith('/api') ? base.substring(0, base.length - 4) : base;
  final result = '$origin$path';
  debugPrint('[resolveImageUrl] "$raw" -> "$result"');
  return result;
}
