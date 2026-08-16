import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Animaciones reutilizables que replican los keyframes de Tailwind
/// del `tailwind.config.js` de desingVITO (seccion 4.3 del plan).
///
/// - float: traslacion Y -8px en loop 4s.
/// - fade-in: opacidad 0->1 + translateY 20px, 500ms.
/// - slide-up: opacidad 0->1 + translateY 30px, 500ms.
class AppAnimations {
  AppAnimations._();

  /// Animacion float (loop infinito, 4s).
  static Widget float(Widget child, {Duration duration = const Duration(seconds: 4)}) {
    return child
        .animate(onPlay: (c) => c.loop())
        .moveY(
          begin: 0,
          end: -8,
          duration: duration,
          curve: Curves.easeInOut,
        )
        .moveY(
          begin: -8,
          end: 0,
          duration: duration,
          curve: Curves.easeInOut,
        );
  }

  /// Animacion fade-in (500ms).
  static Widget fadeIn(Widget child, {Duration duration = const Duration(milliseconds: 500), Duration delay = Duration.zero}) {
    return child
        .animate()
        .fadeIn(duration: duration, delay: delay, curve: Curves.easeOut)
        .moveY(
          begin: 20,
          end: 0,
          duration: duration,
          delay: delay,
          curve: Curves.easeOut,
        );
  }

  /// Animacion slide-up (500ms).
  static Widget slideUp(Widget child, {Duration duration = const Duration(milliseconds: 500), Duration delay = Duration.zero}) {
    return child
        .animate()
        .fadeIn(duration: duration, delay: delay, curve: Curves.easeOut)
        .moveY(
          begin: 30,
          end: 0,
          duration: duration,
          delay: delay,
          curve: Curves.easeOut,
        );
  }

  /// Lista con animacion escalonada (staggered).
  static Widget staggeredList(List<Widget> children, {Duration step = const Duration(milliseconds: 80)}) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i++)
          slideUp(children[i], delay: step * i),
      ],
    );
  }
}
