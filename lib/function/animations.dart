import 'dart:ui';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
// Asegúrate de que la ruta de importación sea correcta según la estructura de tu proyecto.
// Si 'fairbas' es el nombre de tu paquete (como se ve en main.dart):

class AppAnimations {
  Future<T?> showAnimatedProductCreateDialog<T>(
    BuildContext context,
    Widget child,
  ) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.6), // CORREGIDO
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder:
          (
            BuildContext buildContext,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
            // ProductCreateWidget se encarga de construir el contenido del diálogo.
            // Ya que ProductCreateWidget devuelve un AlertDialog, esto funcionará.
            return child;
          },
      transitionBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child, // Este 'child' es el ProductCreateWidget
          ) {
            // --- Tu animación: Scale (Zoom) y Fade In ---
            return ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.elasticOut,
              ),
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeIn,
                ),
                child: child,
              ),
            );
          },
    );
  }

  static Route createFadeThroughWithBlurRoute(Widget screen) {
    const Color appMainBackgroundColor = Color(0xFF6B2F2F);

    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => screen,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Define la intensidad máxima del blur al inicio
        final double maxBlur = 8.0; // Ajusta este valor si es necesario

        // Anima el valor del sigma del blur de 'maxBlur' a 0.0
        final blurAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves
              .easeOutCubic, // Curva para que el blur se disipe rápidamente
        );
        final animatedBlurSigma = Tween<double>(
          begin: maxBlur,
          end: 0.0,
        ).evaluate(blurAnimation);

        return FadeThroughTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          // CLAVE para evitar el flash: Define el color de fondo de la transición.
          // Este color se mostrará detrás de la pantalla que se está animando.
          // Asegúrate de que coincida con el color de fondo de tus Scaffolds.
          fillColor: appMainBackgroundColor, // Usa el color principal de tu app
          child: ImageFiltered(
            // Aplica el filtro de imagen (blur) al contenido de la nueva pantalla
            imageFilter: ImageFilter.blur(
              sigmaX: animatedBlurSigma,
              sigmaY: animatedBlurSigma,
            ),
            child: child, // Este 'child' es la nueva pantalla
          ),
        );
      },
      // Ajusta la duración de la transición. 400-500ms es un buen rango.
      transitionDuration: const Duration(milliseconds: 800),
      // transitionDuration: const Duration(milliseconds: 500), // Si quieres que sea un poco más lento
    );
  }

  static Route createFadeThroughWithSymmetricBlurRoute(Widget screen) {
    // Definimos el color de fondo principal de tu aplicación aquí.
    // Esto es CRÍTICO para evitar el flash blanco.
    const Color appMainBackgroundColor = Color(
      0xFF6B2F2F,
    ); // Ajusta si tu color es diferente

    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => screen,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final double maxBlur = 8.0; // Intensidad máxima del blur

        // La magia está aquí:
        // Cuando `animation.value` va de 0.0 a 1.0 (PUSH, entrada de la nueva pantalla),
        // `(1.0 - animation.value)` va de 1.0 a 0.0. Así, `animatedBlurSigma` va de `maxBlur` a `0.0`.
        //
        // Cuando `animation.value` va de 1.0 a 0.0 (POP, salida de la pantalla actual),
        // `(1.0 - animation.value)` va de 0.0 a 1.0. Así, `animatedBlurSigma` va de `0.0` a `maxBlur`.
        //
        // ¡Esto nos da blur-in en push y blur-out en pop con la misma lógica!
        final blurValue =
            1.0 -
            CurvedAnimation(
              parent: animation,
              curve: Curves
                  .easeOutCubic, // Curva para la disipación/aplicación del blur
            ).value;

        final animatedBlurSigma = blurValue * maxBlur;

        return FadeThroughTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          // Rellena el fondo con el color principal de la aplicación para evitar el flash
          fillColor: appMainBackgroundColor,
          child: ImageFiltered(
            // Aplica el filtro de imagen (blur) al contenido de la pantalla
            imageFilter: ImageFilter.blur(
              sigmaX: animatedBlurSigma,
              sigmaY: animatedBlurSigma,
            ),
            child:
                child, // Este 'child' es la pantalla que está entrando/saliendo
          ),
        );
      },
      // Duración de la transición. 400ms es un buen balance.
      transitionDuration: const Duration(milliseconds: 800),
      // reverseTransitionDuration: const Duration(milliseconds: 400), // Opcional: si quieres una duración diferente para el pop
    );
  }

  // Puedes añadir más métodos para otros diálogos animados aquí si lo necesitas.
}
