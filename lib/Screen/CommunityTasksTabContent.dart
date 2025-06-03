// lib/screen/CommunityTasksTabContent.dart (Modificado)
import 'package:classroom_mejorado/Screen/TaskDetailScreen.dart';
import 'package:classroom_mejorado/Screen/NewTaskScreen.dart'; // Importar la nueva pantalla
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:classroom_mejorado/theme/app_typography.dart';

// Definimos los estados de las tareas (ya debe estar en este archivo)
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
    final theme = Theme.of(context);
    switch (this) {
      case TaskState.toDo:
        return Colors.orange[700]!; // Color para "Por hacer"
      case TaskState.doing:
        return Colors.blue[700]!; // Color para "En progreso"
      case TaskState.testing:
        return Colors.purple[700]!; // Color para "Revisado"
      case TaskState.done:
        return Colors.green[700]!; // Color para "Hecho"
    }
  }
}

class CommunityTasksTabContent extends StatefulWidget {
  final String communityId;

  const CommunityTasksTabContent({super.key, required this.communityId});

  @override
  State<CommunityTasksTabContent> createState() =>
      _CommunityTasksTabContentState();
}

class _CommunityTasksTabContentState extends State<CommunityTasksTabContent> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('communities')
                  .doc(widget.communityId)
                  .collection('tasks')
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
                    child: Text(
                      'Error al cargar las tareas: ${snapshot.error}', // Traducido
                      style: TextStyle(color: theme.colorScheme.error),
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
                          '¡No hay tareas aún!', // Ya estaba en español
                          style: TextStyle(
                            fontFamily: fontFamilyPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onBackground,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Crea tu primera tarea para empezar', // Ya estaba en español
                          style: TextStyle(
                            fontFamily: fontFamilyPrimary,
                            fontSize: 16,
                            color: theme.colorScheme.onBackground.withOpacity(
                              0.7,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => NewTaskScreen(
                                  communityId: widget.communityId,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: Text(
                            'Crear primera tarea', // Ya estaba en español
                            style: TextStyle(
                              fontFamily: fontFamilyPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary
                                .withValues(alpha: 0.6),
                            foregroundColor: theme.colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
                    final taskData =
                        tasks[index].data() as Map<String, dynamic>;
                    final taskId = tasks[index].id;
                    final String title =
                        taskData['title'] ?? 'Sin Título'; // Traducido
                    final TaskState state = TaskState.values.firstWhere(
                      (e) =>
                          e.name
                              .toLowerCase() == // TaskState.name ya está en español
                          (taskData['state'] as String? ??
                                  'por hacer') // Comparar con el valor en español de Firestore o el predeterminado
                              .toLowerCase(),
                      orElse: () => TaskState.toDo,
                    );
                    final String? assignedToUser = taskData['assignedToUser'];
                    final String? priority =
                        taskData['priority']; // Ya está en español ('Baja', 'Media', 'Alta', 'Urgente')

                    return Card(
                      color: theme.colorScheme.surface,
                      margin: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                      child: InkWell(
                        onTap: () {
                          // ¡Navegar a TaskDetailScreen!
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
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontFamily: fontFamilyPrimary,
                                            color: theme.colorScheme.onSurface,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  if (priority != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getPriorityColor(
                                          priority,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _getPriorityColor(
                                            priority,
                                          ).withOpacity(0.3),
                                        ),
                                      ),
                                      child: Text(
                                        priority, // Ya está en español
                                        style: TextStyle(
                                          fontFamily: fontFamilyPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: _getPriorityColor(priority),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: state
                                          .getColor(context)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: state
                                            .getColor(context)
                                            .withOpacity(0.3),
                                      ),
                                    ),
                                    child: Text(
                                      state.name, // Ya está en español
                                      style: TextStyle(
                                        fontFamily: fontFamilyPrimary,
                                        fontSize: 12,
                                        color: state.getColor(context),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (assignedToUser != null)
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.person,
                                          size: 16,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          assignedToUser,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                fontFamily: fontFamilyPrimary,
                                                color:
                                                    theme.colorScheme.primary,
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navegar a la nueva pantalla de crear tarea
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  NewTaskScreen(communityId: widget.communityId),
            ),
          );
        },
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.6),
        foregroundColor: theme.colorScheme.onPrimary,
        icon: const Icon(Icons.add),
        label: Text(
          'Nueva Tarea', // Ya estaba en español
          style: TextStyle(
            fontFamily: fontFamilyPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'baja':
        return Colors.green[600]!;
      case 'media':
        return Colors.blue[600]!;
      case 'alta':
        return Colors.orange[600]!;
      case 'urgente':
        return Colors.red[600]!;
      default:
        return Colors.grey[600]!;
    }
  }
}
