// lib/screen/CommunityTasksTabContent.dart - CORREGIDO Y SINCRONIZADO
import 'package:classroom_mejorado/Screen/TaskDetailScreen.dart';
import 'package:classroom_mejorado/Screen/NewTaskScreen.dart';
import 'package:classroom_mejorado/utils/tasks_utils.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:classroom_mejorado/theme/app_typography.dart';

class CommunityTasksTabContent extends StatefulWidget {
  final String communityId;

  const CommunityTasksTabContent({super.key, required this.communityId});

  @override
  State<CommunityTasksTabContent> createState() =>
      _CommunityTasksTabContentState();
}

class _CommunityTasksTabContentState extends State<CommunityTasksTabContent> {
  // ✅ FUNCIÓN MEJORADA PARA MAPEAR ESTADOS CON RETROCOMPATIBILIDAD (IGUAL QUE MyTasksScreen)
  TaskState _parseTaskState(String? stateString) {
    if (stateString == null || stateString.isEmpty) {
      return TaskState.toDo;
    }

    final String stateLower = stateString.toLowerCase();

    // Mapeo directo por nombre del enum
    for (TaskState state in TaskState.values) {
      if (state.name.toLowerCase() == stateLower) {
        return state;
      }
    }

    // ✅ RETROCOMPATIBILIDAD: Mapear valores antiguos
    switch (stateLower) {
      case 'testing': // Valor antiguo -> nuevo valor
        return TaskState.underReview;
      case 'todo':
      case 'to_do':
        return TaskState.toDo;
      case 'inprogress':
      case 'in_progress':
        return TaskState.doing;
      case 'review':
      case 'under_review':
        return TaskState.underReview;
      case 'completed':
      case 'finished':
        return TaskState.done;
      default:
        print(
          '⚠️ Estado desconocido en CommunityTasks: $stateString - usando toDo por defecto',
        );
        return TaskState.toDo;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection('tasks')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Cargando tareas...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: fontFamilyPrimary,
                      color: theme.colorScheme.onBackground.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.error_outline,
                      size: 60,
                      color: theme.colorScheme.error.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Error al cargar las tareas',
                    style: TextStyle(
                      fontFamily: fontFamilyPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Intenta de nuevo más tarde',
                    style: TextStyle(
                      fontFamily: fontFamilyPrimary,
                      fontSize: 16,
                      color: theme.colorScheme.onBackground.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.assignment_outlined,
                      size: 60,
                      color: theme.colorScheme.primary.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '¡No hay tareas aún!',
                    style: TextStyle(
                      fontFamily: fontFamilyPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onBackground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Crea tu primera tarea para empezar',
                    style: TextStyle(
                      fontFamily: fontFamilyPrimary,
                      fontSize: 16,
                      color: theme.colorScheme.onBackground.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              NewTaskScreen(communityId: widget.communityId),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: Text(
                      'Crear primera tarea',
                      style: TextStyle(
                        fontFamily: fontFamilyPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ],
              ),
            );
          }

          final tasks = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final taskDoc = tasks[index];
              final taskData = taskDoc.data() as Map<String, dynamic>;
              final String taskTitle = taskData['title'] ?? 'Tarea sin título';
              final String taskId = taskDoc.id;

              // ✅ USAR LA FUNCIÓN MEJORADA DE MAPEO DE ESTADOS (EN LUGAR DEL firstWhere PROBLEMÁTICO)
              final TaskState taskState = _parseTaskState(
                taskData['state'] as String?,
              );

              final String priority = taskData['priority'] ?? 'Media';
              final TaskPriority taskPriority = TaskPriority.values.firstWhere(
                (e) => e.name.toLowerCase() == priority.toLowerCase(),
                orElse: () => TaskPriority.medium,
              );

              final Timestamp? dueDateTimestamp =
                  taskData['dueDate'] as Timestamp?;
              final String? description = taskData['description'];

              // ✅ Información del asignado
              final String assignedToName =
                  taskData['assignedToName'] ?? 'Sin asignar';

              return Card(
                color: theme.colorScheme.surface,
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => TaskDetailScreen(
                          communityId: widget.communityId,
                          taskId: taskId,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ✅ Título y prioridad (igual estilo MyTasks)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                taskTitle,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontFamily: fontFamilyPrimary,
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: taskPriority.getColor().withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: taskPriority.getColor().withOpacity(
                                    0.3,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    taskPriority.getIcon(),
                                    size: 12,
                                    color: taskPriority.getColor(),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    priority,
                                    style: TextStyle(
                                      fontFamily: fontFamilyPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: taskPriority.getColor(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // ✅ Asignado a (específico para CommunityTasks)
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Asignado a: $assignedToName',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontFamily: fontFamilyPrimary,
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        // ✅ Descripción si existe (igual estilo MyTasks)
                        if (description != null && description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: fontFamilyPrimary,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.7,
                              ),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],

                        const SizedBox(height: 12),

                        // ✅ Estado y fecha (igual estilo MyTasks)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: taskState
                                    .getColor(context)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: taskState
                                      .getColor(context)
                                      .withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                taskState.displayName,
                                style: TextStyle(
                                  fontFamily: fontFamilyPrimary,
                                  fontSize: 12,
                                  color: taskState.getColor(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (dueDateTimestamp != null)
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.6),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat(
                                      'dd MMM yyyy',
                                    ).format(dueDateTimestamp.toDate()),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontFamily: fontFamilyPrimary,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.6),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),

                        // ✅ DEBUG: Mostrar estado raw de la base de datos (TEMPORAL)
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  NewTaskScreen(communityId: widget.communityId),
            ),
          );
        },
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        icon: const Icon(Icons.add),
        label: Text(
          'Nueva Tarea',
          style: TextStyle(
            fontFamily: fontFamilyPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 4,
      ),
    );
  }
}
