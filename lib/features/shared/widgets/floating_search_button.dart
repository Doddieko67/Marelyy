import 'package:flutter/material.dart';
import 'package:classroom_mejorado/core/constants/app_colors.dart';
import 'package:classroom_mejorado/features/search/screens/global_search_screen.dart';

class FloatingSearchButton extends StatelessWidget {
  final bool showLabel;
  final EdgeInsetsGeometry? margin;
  
  const FloatingSearchButton({
    super.key,
    this.showLabel = false,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(right: 16, bottom: 80),
      child: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) {
                return const GlobalSearchScreen();
              },
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                const begin = Offset(1.0, 0.0);
                const end = Offset.zero;
                const curve = Curves.easeInOut;

                var tween = Tween(begin: begin, end: end).chain(
                  CurveTween(curve: curve),
                );

                return SlideTransition(
                  position: animation.drive(tween),
                  child: child,
                );
              },
            ),
          );
        },
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        elevation: 8,
        icon: const Icon(Icons.search, size: 24),
        label: showLabel 
            ? const Text(
                'Buscar',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              )
            : const SizedBox.shrink(),
        heroTag: 'floating_search_button',
      ),
    );
  }
}