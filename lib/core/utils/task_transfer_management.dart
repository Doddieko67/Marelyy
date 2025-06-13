// lib/utils/task_transfer_manager.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Clase utilitaria para manejar la transferencia/gestión de tareas
/// cuando un usuario abandona una comunidad
enum TaskAction { unassign, deleteAll, assignToOne, handleIndividually }

/// Resultado de la gestión de tareas
enum TaskTransferResult {
  completed, // Tareas gestionadas correctamente
  cancelled, // Usuario canceló la operación
  noTasks, // No tenía tareas asignadas
  error, // Error durante el proceso
}

class TaskTransferManager {
  /// Enum para las opciones de manejo de tareas
  /// Método principal para gestionar las tareas de un usuario que abandona una comunidad
  ///
  /// [context] - BuildContext para mostrar diálogos
  /// [communityId] - ID de la comunidad
  /// [userId] - ID del usuario que abandona (opcional, usa el usuario actual por defecto)
  /// [showSuccessMessage] - Función callback para mostrar mensajes de éxito
  /// [showErrorMessage] - Función callback para mostrar mensajes de error
  ///
  /// Retorna [TaskTransferResult] indicando el resultado de la operación
  static Future<TaskTransferResult> handleUserTasksBeforeLeaving({
    required BuildContext context,
    required String communityId,
    String? userId,
    Function(String)? showSuccessMessage,
    Function(String)? showErrorMessage,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final targetUserId = userId ?? currentUser?.uid;

      if (targetUserId == null) {
        _showMessage(showErrorMessage, 'Usuario no autenticado');
        return TaskTransferResult.error;
      }

      // Verificar si el usuario tiene tareas asignadas
      final userTasks = await FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .collection('tasks')
          .where('assignedToId', isEqualTo: targetUserId)
          .get();

      // Si no tiene tareas, retornar sin hacer nada
      if (userTasks.docs.isEmpty) {
        return TaskTransferResult.noTasks;
      }

      // Obtener miembros de la comunidad para las opciones de reasignación
      final communityDoc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .get();

      if (!communityDoc.exists) {
        _showMessage(showErrorMessage, 'Comunidad no encontrada');
        return TaskTransferResult.error;
      }

      final List<String> memberIds = List<String>.from(
        communityDoc.get('members') ?? [],
      );

      // Mostrar diálogo para elegir qué hacer con las tareas
      final taskAction = await _showTaskManagementDialog(
        context,
        userTasks.docs.length,
      );

      if (taskAction == null) {
        return TaskTransferResult.cancelled;
      }

      // Manejar las tareas según la opción elegida
      await _handleUserTasks(
        context,
        userTasks.docs,
        taskAction,
        memberIds,
        targetUserId,
        showSuccessMessage,
        showErrorMessage,
      );

      return TaskTransferResult.completed;
    } catch (e) {
      _showMessage(showErrorMessage, 'Error al gestionar tareas: $e');
      return TaskTransferResult.error;
    }
  }

  /// Mostrar diálogo para elegir qué hacer con las tareas
  static Future<TaskAction?> _showTaskManagementDialog(
    BuildContext context,
    int taskCount,
  ) async {
    return showDialog<TaskAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.task_alt, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Gestionar Tareas',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Tienes $taskCount tarea${taskCount > 1 ? 's' : ''} asignada${taskCount > 1 ? 's' : ''}. ¿Qué deseas hacer con ella${taskCount > 1 ? 's' : ''}?',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildTaskActionOption(
              context,
              TaskAction.unassign,
              Icons.person_remove,
              'Dejar sin asignar',
              'Las tareas quedarán disponibles para otros miembros',
            ),
            const SizedBox(height: 8),
            _buildTaskActionOption(
              context,
              TaskAction.deleteAll,
              Icons.delete_forever,
              'Eliminar todas',
              'Se borrarán permanentemente todas tus tareas',
            ),
            const SizedBox(height: 8),
            _buildTaskActionOption(
              context,
              TaskAction.assignToOne,
              Icons.person_add,
              'Asignar a otra persona',
              'Transferir todas las tareas a un miembro específico',
            ),
            const SizedBox(height: 8),
            _buildTaskActionOption(
              context,
              TaskAction.handleIndividually,
              Icons.tune,
              'Gestionar individualmente',
              'Elegir qué hacer con cada tarea por separado',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  /// Widget helper para las opciones de manejo de tareas
  static Widget _buildTaskActionOption(
    BuildContext context,
    TaskAction action,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(action),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Theme.of(context).colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }

  /// Manejar las tareas según la acción elegida
  static Future<void> _handleUserTasks(
    BuildContext context,
    List<QueryDocumentSnapshot> tasks,
    TaskAction action,
    List<String> memberIds,
    String currentUserId,
    Function(String)? showSuccessMessage,
    Function(String)? showErrorMessage,
  ) async {
    try {
      switch (action) {
        case TaskAction.unassign:
          await _unassignAllTasks(tasks);
          _showMessage(
            showSuccessMessage,
            '${tasks.length} tarea${tasks.length > 1 ? 's' : ''} dejada${tasks.length > 1 ? 's' : ''} sin asignar',
          );
          break;
        case TaskAction.deleteAll:
          await _deleteAllTasks(tasks);
          _showMessage(
            showSuccessMessage,
            '${tasks.length} tarea${tasks.length > 1 ? 's' : ''} eliminada${tasks.length > 1 ? 's' : ''}',
          );
          break;
        case TaskAction.assignToOne:
          await _assignAllTasksToOne(
            context,
            tasks,
            memberIds,
            currentUserId,
            showSuccessMessage,
            showErrorMessage,
          );
          break;
        case TaskAction.handleIndividually:
          await _handleTasksIndividually(
            context,
            tasks,
            memberIds,
            currentUserId,
            showSuccessMessage,
            showErrorMessage,
          );
          break;
      }
    } catch (e) {
      _showMessage(showErrorMessage, 'Error al gestionar tareas: $e');
    }
  }

  /// Dejar todas las tareas sin asignar
  static Future<void> _unassignAllTasks(
    List<QueryDocumentSnapshot> tasks,
  ) async {
    final batch = FirebaseFirestore.instance.batch();

    for (final task in tasks) {
      batch.update(task.reference, {
        'assignedToId': null,
        'assignedToName': null,
        'assignedToUser': null,
        'assignedToImageUrl': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// Eliminar todas las tareas
  static Future<void> _deleteAllTasks(List<QueryDocumentSnapshot> tasks) async {
    final batch = FirebaseFirestore.instance.batch();

    for (final task in tasks) {
      batch.delete(task.reference);
    }

    await batch.commit();
  }

  /// Asignar todas las tareas a una persona específica
  static Future<void> _assignAllTasksToOne(
    BuildContext context,
    List<QueryDocumentSnapshot> tasks,
    List<String> memberIds,
    String currentUserId,
    Function(String)? showSuccessMessage,
    Function(String)? showErrorMessage,
  ) async {
    // Obtener la lista de miembros (excluyendo al usuario actual)
    final availableMembers = memberIds
        .where((id) => id != currentUserId)
        .toList();

    if (availableMembers.isEmpty) {
      _showMessage(
        showErrorMessage,
        'No hay otros miembros disponibles para asignar las tareas',
      );
      return;
    }

    // Obtener información de los miembros
    final membersData = await _getMembersData(availableMembers);

    // Mostrar diálogo para seleccionar el miembro
    final selectedMember = await _showMemberSelectionDialog(
      context,
      membersData,
      'Seleccionar Miembro',
    );

    if (selectedMember != null) {
      final batch = FirebaseFirestore.instance.batch();

      for (final task in tasks) {
        batch.update(task.reference, {
          'assignedToId': selectedMember['uid'],
          'assignedToName': selectedMember['displayName'],
          'assignedToUser': selectedMember['displayName'],
          'assignedToImageUrl': selectedMember['photoURL'],
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      _showMessage(
        showSuccessMessage,
        '${tasks.length} tarea${tasks.length > 1 ? 's' : ''} asignada${tasks.length > 1 ? 's' : ''} a ${selectedMember['displayName']}',
      );
    }
  }

  /// Manejar tareas individualmente
  static Future<void> _handleTasksIndividually(
    BuildContext context,
    List<QueryDocumentSnapshot> tasks,
    List<String> memberIds,
    String currentUserId,
    Function(String)? showSuccessMessage,
    Function(String)? showErrorMessage,
  ) async {
    // Obtener información de los miembros disponibles
    final availableMembers = memberIds
        .where((id) => id != currentUserId)
        .toList();
    final membersData = await _getMembersData(availableMembers);

    // Mostrar diálogo para cada tarea
    for (int i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      final taskData = task.data() as Map<String, dynamic>;

      final action = await _showIndividualTaskDialog(
        context,
        taskData,
        i + 1,
        tasks.length,
        membersData.isNotEmpty,
      );

      if (action == null) return; // Usuario canceló

      if (action == 'assign' && membersData.isNotEmpty) {
        final selectedMember = await _showMemberSelectionDialog(
          context,
          membersData,
          'Asignar a:',
        );

        if (selectedMember != null) {
          await task.reference.update({
            'assignedToId': selectedMember['uid'],
            'assignedToName': selectedMember['displayName'],
            'assignedToUser': selectedMember['displayName'],
            'assignedToImageUrl': selectedMember['photoURL'],
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } else if (action == 'unassign') {
        await task.reference.update({
          'assignedToId': null,
          'assignedToName': null,
          'assignedToUser': null,
          'assignedToImageUrl': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else if (action == 'delete') {
        await task.reference.delete();
      }
    }

    _showMessage(showSuccessMessage, 'Tareas gestionadas correctamente');
  }

  /// Obtener datos de los miembros
  static Future<List<Map<String, dynamic>>> _getMembersData(
    List<String> memberIds,
  ) async {
    final membersData = <Map<String, dynamic>>[];

    for (final memberId in memberIds) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(memberId)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        membersData.add({
          'uid': memberId,
          'displayName':
              userData?['name'] ??
              userData?['displayName'] ??
              'Usuario Desconocido',
          'photoURL': userData?['photoURL'],
        });
      }
    }

    return membersData;
  }

  /// Mostrar diálogo para seleccionar un miembro
  static Future<Map<String, dynamic>?> _showMemberSelectionDialog(
    BuildContext context,
    List<Map<String, dynamic>> membersData,
    String title,
  ) async {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: membersData.map((member) {
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: member['photoURL'] != null
                    ? NetworkImage(member['photoURL'])
                    : null,
                child: member['photoURL'] == null ? Icon(Icons.person) : null,
              ),
              title: Text(member['displayName']),
              onTap: () => Navigator.of(context).pop(member),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  /// Mostrar diálogo para una tarea individual
  static Future<String?> _showIndividualTaskDialog(
    BuildContext context,
    Map<String, dynamic> taskData,
    int currentIndex,
    int totalTasks,
    bool hasMembersAvailable,
  ) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Tarea $currentIndex de $totalTasks',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    taskData['title'] ?? 'Sin título',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  if (taskData['description'] != null &&
                      taskData['description'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        taskData['description'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer.withOpacity(0.8),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('¿Qué quieres hacer con esta tarea?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('unassign'),
            child: Text('Sin asignar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('delete'),
            child: Text(
              'Eliminar',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          if (hasMembersAvailable)
            TextButton(
              onPressed: () => Navigator.of(context).pop('assign'),
              child: Text('Asignar'),
            ),
        ],
      ),
    );
  }

  /// Helper para mostrar mensajes de manera segura
  static void _showMessage(Function(String)? messageFunction, String message) {
    messageFunction?.call(message);
  }
}

/// Ejemplo de uso en tu archivo original:
///
/// ```dart
/// void _leaveCommunity() async {
///   final user = FirebaseAuth.instance.currentUser;
///   if (user == null) {
///     _showErrorMessage('Debes iniciar sesión.');
///     return;
///   }
///
///   setState(() => _isLoading = true);
///
///   try {
///     // Gestionar tareas antes de abandonar
///     final result = await TaskTransferManager.handleUserTasksBeforeLeaving(
///       context: context,
///       communityId: widget.communityId,
///       showSuccessMessage: _showSuccessMessage,
///       showErrorMessage: _showErrorMessage,
///     );
///
///     // Si se canceló la gestión de tareas, no abandonar la comunidad
///     if (result == TaskTransferManager.TaskTransferResult.cancelled) {
///       setState(() => _isLoading = false);
///       return;
///     }
///
///     // Proceder con la lógica original de abandonar la comunidad
///     // ... resto del código original ...
///
///   } catch (e) {
///     _showErrorMessage('Error al abandonar: $e');
///   } finally {
///     if (mounted) setState(() => _isLoading = false);
///   }
/// }
/// ```
