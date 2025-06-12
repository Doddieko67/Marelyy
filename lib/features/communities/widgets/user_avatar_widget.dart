import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UserAvatarWidget extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final IconData fallbackIcon;
  final Color? backgroundColor;
  final Color? iconColor;
  final String userRole; // 'owner', 'admin', 'member'
  
  const UserAvatarWidget({
    super.key,
    this.imageUrl,
    this.radius = 24,
    this.fallbackIcon = Icons.person_outline,
    this.backgroundColor,
    this.iconColor,
    this.userRole = 'member',
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bgColor, fgColor) = _getRoleColors(theme);
    
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? bgColor,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: imageUrl!,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                placeholder: (context, url) => Icon(
                  fallbackIcon,
                  color: iconColor ?? fgColor,
                  size: radius * 0.6,
                ),
                errorWidget: (context, url, error) => Icon(
                  fallbackIcon,
                  color: iconColor ?? fgColor,
                  size: radius * 0.6,
                ),
              ),
            )
          : Icon(
              fallbackIcon,
              color: iconColor ?? fgColor,
              size: radius * 0.6,
            ),
    );
  }
  
  (Color, Color) _getRoleColors(ThemeData theme) {
    switch (userRole) {
      case 'owner':
        return (
          theme.colorScheme.primary.withOpacity(0.2),
          theme.colorScheme.primary,
        );
      case 'admin':
        return (
          Colors.orange.withOpacity(0.2),
          Colors.orange.shade700,
        );
      default:
        return (
          theme.colorScheme.surfaceVariant,
          theme.colorScheme.onSurfaceVariant,
        );
    }
  }
}