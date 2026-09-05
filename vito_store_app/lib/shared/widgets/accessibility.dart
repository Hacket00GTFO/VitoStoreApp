import 'package:flutter/material.dart';

/// Helpers de accesibilidad para la app movil de VITO Technologies.
///
/// Facilita el cumplimiento de HIG (iOS) y Material 3 (Android):
/// - Labels semánticos para lectores de pantalla (VoiceOver / TalkBack).
/// - Touch targets >= 48dp.
/// - Exclusiones semánticas para elementos decorativos.
class Accessibility {
  Accessibility._();

  /// Envuelve un widget con un label semántico para lectores de pantalla.
  ///
  /// Uso tipico: iconos, botones sin texto, imagenes decorativas.
  static Widget labeled({
    required String label,
    required Widget child,
    bool button = false,
    bool enabled = true,
    bool excludeSemantics = false,
  }) {
    return Semantics(
      label: label,
      button: button,
      enabled: enabled,
      excludeSemantics: excludeSemantics,
      child: child,
    );
  }

  /// Marca un widget como decorativo (oculto para lectores de pantalla).
  static Widget decorative(Widget child) {
    return Semantics(
      excludeSemantics: true,
      label: '',
      child: child,
    );
  }

  /// Asegura que un widget tenga un tamano minimo de touch target (48dp).
  ///
  /// Envuelve el widget en un SizedBox con min 48x48 centrado.
  static Widget minTouchTarget(Widget child, {double minSize = 48.0}) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minSize,
        minHeight: minSize,
      ),
      child: Center(child: child),
    );
  }

  /// Envuelve una imagen con un label semántico descriptivo.
  static Widget imageLabel({
    required String label,
    required Widget child,
  }) {
    return Semantics(
      label: label,
      image: true,
      child: child,
    );
  }
}

/// Extension para agregar labels semánticos a widgets de forma fluida.
extension AccessibilityExtension on Widget {
  /// Agrega un label semántico al widget.
  Widget semLabel(String label, {bool button = false}) {
    return Semantics(label: label, button: button, child: this);
  }

  /// Marca el widget como decorativo (oculto para lectores de pantalla).
  Widget decorative() {
    return Semantics(excludeSemantics: true, child: this);
  }
}
