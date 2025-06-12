// lib/widgets/task_detail/task_header_card.dart
import 'package:classroom_mejorado/core/constants/app_typography.dart';
import 'package:classroom_mejorado/core/utils/task_utils.dart';
import 'package:flutter/material.dart';

class TaskHeaderCard extends StatelessWidget {
  final Map<String, dynamic> taskData;

  const TaskHeaderCard({super.key, required this.taskData});

  // ... (código de _getStateColor y _getStateDisplayName que también necesita este widget)

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String taskTitle = taskData['title'] ?? 'Sin Título';
    final String taskDescription =
        taskData['description'] ?? 'Sin descripción.';
    final TaskState taskState = TaskUtils.parseTaskState(
      taskData['state'] as String?,
    );

    // Funciones helper para el color y nombre del estado
    Color getStateColor(TaskState state) {
      switch (state) {
        case TaskState.toDo:
          return Colors.grey.shade600;
        case TaskState.doing:
          return Colors.blue.shade600;
        case TaskState.underReview:
          return Colors.orange.shade600;
        case TaskState.done:
          return Colors.green.shade600;
      }
    }

    String getStateDisplayName(TaskState state) {
      switch (state) {
        case TaskState.toDo:
          return 'Por Hacer';
        case TaskState.doing:
          return 'En Progreso';
        case TaskState.underReview:
          return 'Por Revisar';
        case TaskState.done:
          return 'Completado';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: getStateColor(taskState).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: getStateColor(taskState),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  getStateDisplayName(taskState),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: fontFamilyPrimary,
                    color: getStateColor(taskState),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            taskTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontFamily: fontFamilyPrimary,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onBackground,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            taskDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: fontFamilyPrimary,
              color: theme.colorScheme.onBackground.withOpacity(0.8),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
