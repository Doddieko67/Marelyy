import 'package:flutter/material.dart';
import 'package:classroom_mejorado/core/constants/app_typography.dart';
import 'package:classroom_mejorado/features/communities/models/community_model.dart';
import 'package:intl/intl.dart';

class CommunityCard extends StatelessWidget {
  final Community community;
  final DateTime? lastVisit;
  final VoidCallback? onTap;
  final bool isLoading;

  const CommunityCard({
    super.key,
    required this.community,
    this.lastVisit,
    this.onTap,
    this.isLoading = false,
  });

  String _formatLastVisit(DateTime? lastVisit) {
    if (lastVisit == null) {
      return 'Nunca';
    }

    final now = DateTime.now();
    final difference = now.difference(lastVisit);

    if (difference.inDays < 1) {
      return DateFormat('HH:mm:ss').format(lastVisit);
    } else {
      return DateFormat('dd/MM/yyyy').format(lastVisit);
    }
  }

  Widget _buildDefaultAvatar(ThemeData theme) {
    return Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.group, size: 32, color: theme.colorScheme.primary),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastVisitText = _formatLastVisit(lastVisit);

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: community.imageUrl.isNotEmpty
                      ? Image.network(
                          community.imageUrl,
                          width: 74,
                          height: 74,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildDefaultAvatar(theme);
                          },
                        )
                      : _buildDefaultAvatar(theme),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            community.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontFamily: fontFamilyPrimary,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (community.description.isNotEmpty) ...[
                      Text(
                        community.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: fontFamilyPrimary,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        Icon(
                          Icons.people,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${community.memberCount} ${community.memberCount == 1 ? 'miembro' : 'miembros'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: fontFamilyPrimary,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: Colors.purpleAccent.shade200.withValues(
                            alpha: 0.7,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: isLoading
                              ? Container(
                                  height: 12,
                                  width: 60,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.outline
                                        .withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                )
                              : Text(
                                  lastVisitText,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontFamily: fontFamilyPrimary,
                                    color: Colors.purpleAccent.shade200
                                        .withValues(alpha: 0.7),
                                    fontWeight: FontWeight.w400,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}