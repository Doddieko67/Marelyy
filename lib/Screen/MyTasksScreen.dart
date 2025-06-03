// lib/screen/MyTasksScreen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:classroom_mejorado/theme/app_typography.dart';
import 'package:classroom_mejorado/Screen/TaskDetailScreen.dart';

enum TaskPriority { low, medium, high, urgent }

extension TaskPriorityExtension on TaskPriority {
  String get name {
    switch (this) {
      case TaskPriority.low:
        return 'Baja';
      case TaskPriority.medium:
        return 'Media';
      case TaskPriority.high:
        return 'Alta';
      case TaskPriority.urgent:
        return 'Urgente';
    }
  }

  Color getColor() {
    switch (this) {
      case TaskPriority.low:
        return Colors.green[600]!;
      case TaskPriority.medium:
        return Colors.blue[600]!;
      case TaskPriority.high:
        return Colors.orange[600]!;
      case TaskPriority.urgent:
        return Colors.red[600]!;
    }
  }

  IconData getIcon() {
    switch (this) {
      case TaskPriority.low:
        return Icons.keyboard_arrow_down;
      case TaskPriority.medium:
        return Icons.remove;
      case TaskPriority.high:
        return Icons.keyboard_arrow_up;
      case TaskPriority.urgent:
        return Icons.priority_high;
    }
  }
}

enum TaskState { toDo, doing, testing, done }

extension TaskStateExtension on TaskState {
  String get name {
    switch (this) {
      case TaskState.toDo:
        return 'Por hacer';
      case TaskState.doing:
        return 'Haciendo';
      case TaskState.testing:
        return 'Por revisar';
      case TaskState.done:
        return 'Hecho';
    }
  }

  Color getColor(BuildContext context) {
    switch (this) {
      case TaskState.toDo:
        return Colors.orange[700]!;
      case TaskState.doing:
        return Colors.blue[700]!;
      case TaskState.testing:
        return Colors.purple[700]!;
      case TaskState.done:
        return Colors.green[700]!;
    }
  }
}

class MyTasksScreen extends StatefulWidget {
  const MyTasksScreen({super.key});

  @override
  State<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends State<MyTasksScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserUid = _auth.currentUser?.uid;

    if (currentUserUid == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Mis Tareas',
            style: TextStyle(
              fontFamily: fontFamilyPrimary,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onBackground,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
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
                  Icons.login,
                  size: 60,
                  color: theme.colorScheme.primary.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Inicia sesión para ver tus tareas',
                style: TextStyle(
                  fontFamily: fontFamilyPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Necesitas estar autenticado',
                style: TextStyle(
                  fontFamily: fontFamilyPrimary,
                  fontSize: 16,
                  color: theme.colorScheme.onBackground.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Mis Tareas',
          style: TextStyle(
            fontFamily: fontFamilyPrimary,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onBackground,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collectionGroup('tasks')
            .where('assignedToId', isEqualTo: currentUserUid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
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
                    'Error al cargar tus tareas',
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
                      Icons.assignment_turned_in_outlined,
                      size: 60,
                      color: theme.colorScheme.primary.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '¡No tienes tareas asignadas!',
                    style: TextStyle(
                      fontFamily: fontFamilyPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onBackground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Parece que no hay tareas que te hayan asignado',
                    style: TextStyle(
                      fontFamily: fontFamilyPrimary,
                      fontSize: 16,
                      color: theme.colorScheme.onBackground.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
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
              final String communityId =
                  taskData['communityId'] as String? ?? 'unknown';
              final String communityName =
                  taskData['communityName'] as String? ??
                  'Comunidad Desconocida';
              final String taskId = taskDoc.id;

              final TaskState taskState = TaskState.values.firstWhere(
                (e) =>
                    e.name.toLowerCase() ==
                    (taskData['state'] as String? ?? 'toDo').toLowerCase(),
                orElse: () => TaskState.toDo,
              );

              final String priority = taskData['priority'] ?? 'Media';
              final TaskPriority taskPriority = TaskPriority.values.firstWhere(
                (e) => e.name.toLowerCase() == priority.toLowerCase(),
                orElse: () => TaskPriority.medium,
              );

              final Timestamp? dueDateTimestamp =
                  taskData['dueDate'] as Timestamp?;
              final String? description = taskData['description'];

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
                          communityId: communityId,
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
                        // Título y prioridad
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

                        // Nombre de la comunidad
                        Row(
                          children: [
                            Icon(
                              Icons.group,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                communityName,
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

                        // Descripción si existe
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

                        // Estado y fecha
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
                                taskState.name,
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
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
