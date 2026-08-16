import 'package:flutter/material.dart';

/// Paleta de marca de VITO Technologies.
///
/// Replica exacta de los tokens del `tailwind.config.js` de desingVITO
/// (sección 4.1 del plan). Estos colores son compartidos por light y dark mode;
/// los ajustes específicos de dark mode (OLED-aware) están en [AppTheme].
class AppColors {
  AppColors._();

  // Marca (light mode — idénticos a la web)
  static const Color primary = Color(0xFF0066CC); // vito-blue
  static const Color primaryDark = Color(0xFF004499); // vito-dark-blue
  static const Color background = Color(0xFFF8F9FA); // vito-gray
  static const Color onDarkMuted = Color(0xFFCBD5E1); // vito-on-dark-muted
  static const Color soft = Color(0xFFBFDBFE); // vito-soft
  static const Color softStrong = Color(0xFF93C5FD); // vito-soft-strong

  // Texto
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF6C757D); // vito-dark-gray

  // Superficies
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFF1F5F9);

  // Semánticos (light)
  static const Color error = Color(0xFFDC2626);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color info = Color(0xFF0EA5E9);

  // --- Dark mode (OLED-aware, skill mobile-color-system) ---
  static const Color darkBackground = Color(0xFF000000); // true black, máx. ahorro OLED
  static const Color darkSurface = Color(0xFF121212); // evita black smear
  static const Color darkSurfaceElevated = Color(0xFF1E1E1E);
  static const Color darkPrimary = Color(0xFF5BB0FF); // aclarado para contraste sobre oscuro
  static const Color darkTextPrimary = Color(0xFFE5E7EB); // no blanco puro
  static const Color darkTextSecondary = Color(0xFF9CA3AF);
  static const Color darkError = Color(0xFFF87171);
  static const Color darkSuccess = Color(0xFF4ADE80);
  static const Color darkWarning = Color(0xFFFBBF24);
  static const Color darkInfo = Color(0xFF38BDF8);
}
