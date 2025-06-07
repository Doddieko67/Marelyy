// lib/widgets/task_detail/task_comments_section.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:classroom_mejorado/theme/app_typography.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TaskCommentsSection extends StatelessWidget {
  final String communityId;
  final String taskId;
  final VoidCallback onAddComment;

  const TaskCommentsSection({
    super.key,
    required this.communityId,
    required this.taskId,
    required this.onAddComment,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Comentarios",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontFamily: fontFamilyPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                onPressed: onAddComment,
                icon: Icon(
                  Icons.add_comment_outlined,
                  color: theme.colorScheme.primary,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('communities')
              .doc(communityId)
              .collection('tasks')
              .doc(taskId)
              .collection('comments')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Text("No hay comentarios. ¡Sé el primero!");
            }
            final comments = snapshot.data!.docs;
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: comments.length,
              itemBuilder: (context, index) =>
                  _buildCommentItem(context, comments[index]),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCommentItem(BuildContext context, DocumentSnapshot commentDoc) {
    final theme = Theme.of(context);
    final data = commentDoc.data() as Map<String, dynamic>;
    final senderName = data['senderName'] ?? 'Anónimo';
    final commentText = data['text'] ?? '';
    final senderImageUrl = data['senderImageUrl'] as String?;
    final timestamp = data['timestamp'] as Timestamp?;
    String formattedTime = timestamp != null
        ? DateFormat('dd MMM, HH:mm').format(timestamp.toDate())
        : '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundImage: senderImageUrl != null
                ? CachedNetworkImageProvider(senderImageUrl)
                : null,
            child: senderImageUrl == null
                ? const Icon(Icons.person_outline)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      senderName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(formattedTime, style: theme.textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 4),
                Text(commentText, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
