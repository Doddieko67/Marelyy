import 'package:flutter/material.dart';
import 'package:classroom_mejorado/core/constants/app_typography.dart';
import 'package:classroom_mejorado/features/communities/widgets/user_avatar_widget.dart';
import 'package:classroom_mejorado/features/communities/widgets/role_badge_widget.dart';

class MemberListCard extends StatelessWidget {
  final String userId;
  final String name;
  final String? email;
  final String? imageUrl;
  final String role; // 'owner', 'admin', 'member'
  final bool isSelf;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsets? margin;
  
  const MemberListCard({
    super.key,
    required this.userId,
    required this.name,
    this.email,
    this.imageUrl,
    required this.role,
    this.isSelf = false,
    this.trailing,
    this.onTap,
    this.margin,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: margin ?? const EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 8,
      ),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: UserAvatarWidget(
              imageUrl: imageUrl,
              radius: 24,
              userRole: role,
            ),
            title: Text(
              '$name${isSelf ? " (Tú)" : ""}',
              style: TextStyle(
                fontFamily: fontFamilyPrimary,
                fontWeight: role == 'owner' 
                    ? FontWeight.bold 
                    : FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (email != null && email!.isNotEmpty) ...[
                  Text(
                    email!,
                    style: TextStyle(
                      fontFamily: fontFamilyPrimary,
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                RoleBadgeWidget(role: role),
              ],
            ),
            trailing: trailing ?? _buildDefaultTrailing(theme),
          ),
        ),
      ),
    );
  }
  
  Widget? _buildDefaultTrailing(ThemeData theme) {
    switch (role) {
      case 'owner':
        return Icon(
          Icons.star_rounded,
          color: Colors.amber.shade600,
          size: 22,
        );
      case 'admin':
        return Icon(
          Icons.admin_panel_settings_rounded,
          color: Colors.orange.shade700,
          size: 20,
        );
      default:
        return null;
    }
  }
}