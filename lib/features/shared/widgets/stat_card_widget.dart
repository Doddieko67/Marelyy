import 'package:flutter/material.dart';
import 'package:classroom_mejorado/core/constants/app_typography.dart';

class StatCardWidget extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double? percentage;
  final double width;
  final double height;

  const StatCardWidget({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.percentage,
    this.width = 150,
    this.height = 230,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.all(8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icon con fondo circular
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 52,
                ),
              ),
              
              // Value - siempre en el mismo lugar
              Text(
                value,
                style: TextStyle(
                  fontFamily: fontFamilyPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              
              // Title - siempre 2 líneas reservadas
              SizedBox(
                height: 32,
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: fontFamilyPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              // Progress area - siempre reservado (transparente si no hay progreso)
              SizedBox(
                height: 8,
                child: percentage != null
                    ? LinearProgressIndicator(
                        value: percentage! / 100,
                        backgroundColor: color.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 4,
                      )
                    : Container(), // Espacio transparente reservado
              ),
            ],
          ),
        ),
      ),
    );
  }
}