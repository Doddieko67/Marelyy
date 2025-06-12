import 'package:flutter/material.dart';
import 'package:classroom_mejorado/core/constants/app_typography.dart';
import 'package:classroom_mejorado/features/communities/models/community_model.dart';
import 'package:intl/intl.dart';

class MemberCard extends StatelessWidget {
  final CommunityMember member;
  final VoidCallback? onTap;
  final bool showActions;
  final VoidCallback? onPromote;
  final VoidCallback? onRemove;

  const MemberCard({
    super.key,
    required this.member,
    this.onTap,
    this.showActions = false,
    this.onPromote,
    this.onRemove,
  });

  String _getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return 'Propietario';
      case 'admin':
        return 'Administrador';
      case 'member':
        return 'Miembro';
      default:
        return role;
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return Colors.purple;
      case 'admin':
        return Colors.blue;
      case 'member':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return Icons.admin_panel_settings;
      case 'admin':
        return Icons.admin_panel_settings;
      case 'member':
        return Icons.person;
      default:
        return Icons.person;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Fecha desconocida';
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleColor = _getRoleColor(member.role);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: member.profileImageUrl?.isNotEmpty == true
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.network(
                        member.profileImageUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            _getRoleIcon(member.role),
                            color: roleColor,
                            size: 24,
                          );
                        },
                      ),
                    )
                  : Icon(
                      _getRoleIcon(member.role),
                      color: roleColor,
                      size: 24,
                    ),
            ),
            const SizedBox(width: 12),
            
            // Información del miembro
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontFamily: fontFamilyPrimary,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (member.email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      member.email,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: fontFamilyPrimary,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: roleColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getRoleDisplayName(member.role),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: fontFamilyPrimary,
                            color: roleColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (member.joinedAt != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(member.joinedAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: fontFamilyPrimary,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            
            // Acciones
            if (showActions && member.role != 'owner') ...[
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'promote':
                      onPromote?.call();
                      break;
                    case 'remove':
                      onRemove?.call();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (member.role == 'member')
                    PopupMenuItem(
                      value: 'promote',
                      child: Row(
                        children: [
                          Icon(Icons.arrow_upward, size: 16),
                          const SizedBox(width: 8),
                          Text('Promover a Admin'),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(Icons.remove_circle_outline, size: 16, color: Colors.red),
                        const SizedBox(width: 8),
                        Text('Remover', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}