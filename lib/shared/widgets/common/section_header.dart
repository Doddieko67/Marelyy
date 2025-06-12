import 'package:flutter/material.dart';
import 'package:classroom_mejorado/core/constants/app_typography.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? subtitle;
  final Widget? action;
  final VoidCallback? onActionPressed;
  final String? actionText;

  const SectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.action,
    this.onActionPressed,
    this.actionText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Icon(
            icon,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFamily: fontFamilyPrimary,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onBackground,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: fontFamilyPrimary,
                      color: theme.colorScheme.onBackground.withOpacity(0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) action!,
          if (onActionPressed != null && actionText != null)
            TextButton(
              onPressed: onActionPressed,
              child: Text(
                actionText!,
                style: TextStyle(
                  fontFamily: fontFamilyPrimary,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}