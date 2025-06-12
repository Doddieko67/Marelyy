import 'package:flutter/material.dart';
import 'package:classroom_mejorado/core/constants/app_typography.dart';

class RoleBadgeWidget extends StatelessWidget {
  final String role; // 'owner', 'admin', 'member'
  final double fontSize;
  final EdgeInsets? padding;
  
  const RoleBadgeWidget({
    super.key,
    required this.role,
    this.fontSize = 11,
    this.padding,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bgColor, textColor, displayName) = _getRoleProperties(theme);
    
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayName,
        style: TextStyle(
          fontFamily: fontFamilyPrimary,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
  
  (Color, Color, String) _getRoleProperties(ThemeData theme) {
    switch (role.toLowerCase()) {
      case 'owner':
        return (
          theme.colorScheme.primary.withOpacity(0.15),
          theme.colorScheme.primary,
          'Propietario',
        );
      case 'admin':
        return (
          Colors.orange.withOpacity(0.2),
          Colors.orange.shade800,
          'Administrador',
        );
      case 'member':
      default:
        return (
          theme.colorScheme.surfaceVariant.withOpacity(0.5),
          theme.colorScheme.onSurfaceVariant,
          'Miembro',
        );
    }
  }
}