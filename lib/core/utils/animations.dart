import 'dart:ui';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

class AppAnimations {
  Future<T?> showAnimatedProductCreateDialog<T>(
    BuildContext context,
    Widget child,
  ) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder:
          (
            BuildContext buildContext,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
            return child;
          },
      transitionBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
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

  // ✅ VERSIÓN MEJORADA: Más rápida y suave
  static Route createFadeThroughWithBlurRoute(Widget screen) {
    const Color appMainBackgroundColor = Color(0xFF6B2F2F);

    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => screen,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // ✅ Blur más sutil y rápido
        final double maxBlur = 4.0; // Reducido de 8.0 a 4.0

        // ✅ Curva más rápida y natural
        final blurAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.fastOutSlowIn, // Más natural que easeOutCubic
        );

        final animatedBlurSigma = Tween<double>(
          begin: maxBlur,
          end: 0.0,
        ).evaluate(blurAnimation);

        // ✅ Fade más suave con curva personalizada
        final fadeAnimation = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
        );

        return FadeTransition(
          opacity: fadeAnimation,
          child: FadeThroughTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            fillColor: appMainBackgroundColor,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: animatedBlurSigma,
                sigmaY: animatedBlurSigma,
              ),
              child: child,
            ),
          ),
        );
      },
      // ✅ Duración reducida de 800ms a 350ms
      transitionDuration: const Duration(milliseconds: 350),
    );
  }

  // ✅ VERSIÓN COMPLETAMENTE NUEVA: Ultra fluida y moderna
  static Route createSmoothSlideRoute(Widget screen) {
    const Color appMainBackgroundColor = Color(0xFF6B2F2F);

    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => screen,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Animación de deslizamiento desde abajo con fade
        const begin = Offset(0.0, 0.05); // Muy sutil
        const end = Offset.zero;

        final slideAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.fastOutSlowIn,
        );

        final fadeAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );

        return SlideTransition(
          position: Tween<Offset>(
            begin: begin,
            end: end,
          ).animate(slideAnimation),
          child: FadeTransition(opacity: fadeAnimation, child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
    );
  }

  // ✅ VERSIÓN ALTERNATIVA: Escala suave (como iOS)
  static Route createScaleRoute(Widget screen) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => screen,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final scaleAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.fastOutSlowIn,
        );

        final fadeAnimation = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
        );

        return ScaleTransition(
          scale: Tween<double>(
            begin: 0.92, // Empieza un poco más pequeño
            end: 1.0,
          ).animate(scaleAnimation),
          child: FadeTransition(opacity: fadeAnimation, child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
    );
  }

  // ✅ VERSIÓN MEJORADA del simétrico
  static Route createFadeThroughWithSymmetricBlurRoute(Widget screen) {
    const Color appMainBackgroundColor = Color(0xFF6B2F2F);

    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => screen,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final double maxBlur = 3.0; // Reducido para más suavidad

        // ✅ Curva más natural
        final blurValue =
            1.0 -
            CurvedAnimation(
              parent: animation,
              curve: Curves.fastOutSlowIn, // Más natural
            ).value;

        final animatedBlurSigma = blurValue * maxBlur;

        // ✅ Fade más controlado
        final fadeAnimation = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
        );

        return FadeTransition(
          opacity: fadeAnimation,
          child: FadeThroughTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            fillColor: appMainBackgroundColor,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: animatedBlurSigma,
                sigmaY: animatedBlurSigma,
              ),
              child: child,
            ),
          ),
        );
      },
      // ✅ Duración optimizada
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 350),
    );
  }

  // ✅ BONUS: Animación tipo "Push" moderna
  static Route createModernPushRoute(Widget screen) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => screen,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Pantalla actual se desliza hacia la izquierda
        final primarySlide =
            Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-0.3, 0.0),
            ).animate(
              CurvedAnimation(
                parent: secondaryAnimation,
                curve: Curves.fastOutSlowIn,
              ),
            );

        // Nueva pantalla entra desde la derecha
        final secondarySlide =
            Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.fastOutSlowIn),
            );

        // Fade para la pantalla que sale
        final fadeOut = Tween<double>(begin: 1.0, end: 0.7).animate(
          CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOut),
        );

        return Stack(
          children: [
            // Pantalla anterior (se desliza y se desvanece)
            if (secondaryAnimation.status != AnimationStatus.dismissed)
              SlideTransition(
                position: primarySlide,
                child: FadeTransition(
                  opacity: fadeOut,
                  child: Container(), // La pantalla anterior
                ),
              ),
            // Nueva pantalla (entra deslizándose)
            SlideTransition(position: secondarySlide, child: child),
          ],
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 300),
    );
  }
}
