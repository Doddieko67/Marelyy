// lib/utils/tasks_utils.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:classroom_mejorado/features/communities/services/community_service.dart';
import 'package:classroom_mejorado/core/services/firebase_notification_service.dart';

// --- Enums ---

enum TaskState {
  toDo,
  doing,
  underReview,
  done;

  /// TU GETTER 'name' ORIGINAL QUE FUNCIONABA (AHORA LO LLAMAREMOS displayName PARA CLARIDAD)
  /// ESTE ES EL VALOR QUE PROBABLEMENTE TIENES EN FIRESTORE (o su versión en minúsculas)
  String get displayName {
    switch (this) {
      case TaskState.toDo:
        return 'Por hacer';
      case TaskState.doing:
        return 'Haciendo';
      case TaskState.underReview:
        return 'Por revisar';
      case TaskState.done:
        return 'Hecho';
    }
  }

  /// Firestore Name: Usaremos el displayName en minúsculas, ya que eso es lo que
  /// tu parseTaskState original probablemente estaba comparando con éxito.
  String get firestoreName {
    return displayName.toLowerCase();
  }
}

enum TaskPriority {
  low,
  medium,
  high,
  urgent;

  String get displayName {
    // Similar a TaskState, para consistencia
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

  // Si también guardabas prioridades como "Baja", "Media" en Firestore,
  // puedes añadir un firestoreName aquí también, o simplemente usar displayName.
  // Por simplicidad, asumiremos que guardas el displayName para prioridades.
}

// --- Enum Extensions for UI Helpers ---

extension TaskStateUIHelpers on TaskState {
  Color getColor(BuildContext context) {
    switch (this) {
      case TaskState.toDo:
        return Colors.orange[700]!;
      case TaskState.doing:
        return Colors.blue[700]!;
      case TaskState.underReview:
        return Colors.amberAccent[700]!;
      case TaskState.done:
        return Colors.green[700]!;
    }
  }

  IconData getIcon() {
    switch (this) {
      case TaskState.toDo:
        return Icons.radio_button_unchecked;
      case TaskState.doing:
        return Icons.hourglass_empty_rounded;
      case TaskState.underReview:
        return Icons.rate_review_outlined;
      case TaskState.done:
        return Icons.check_circle_outline_rounded;
    }
  }
}

extension TaskPriorityUIHelpers on TaskPriority {
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
        return Icons.keyboard_arrow_down_rounded;
      case TaskPriority.medium:
        return Icons.remove_rounded;
      case TaskPriority.high:
        return Icons.keyboard_arrow_up_rounded;
      case TaskPriority.urgent:
        return Icons.priority_high_rounded;
    }
  }
}

// --- Utility Class for Parsing and Static Helpers ---

class TaskUtils {
  static TaskState parseTaskState(String? stateString) {
    if (stateString == null || stateString.isEmpty) {
      return TaskState.toDo;
    }
    final String cleanState = stateString.trim().toLowerCase();

    // Compara con el firestoreName (que ahora es displayName.toLowerCase())
    for (TaskState state in TaskState.values) {
      if (state.firestoreName == cleanState) {
        // ESTA ES LA COMPARACIÓN CLAVE
        return state;
      }
    }

    // Fallback para nombres de enum en inglés (si alguna vez los usaste directamente)
    // o variaciones muy comunes.
    switch (cleanState) {
      case 'todo': // Nombre literal del enum en Dart si es TaskState.toDo
      case 'to_do':
      case 'por hacer':
      case 'pending':
      case 'pendiente':
        return TaskState.toDo;
      case 'doing': // Nombre literal del enum en Dart si es TaskState.doing
      case 'in_progress':
      case 'inprogress':
      case 'haciendo':
        return TaskState.doing;
      case 'underreview': // Nombre literal del enum en Dart
      case 'under_review':
      case 'testing':
      case 'review':
      case 'por revisar':
        return TaskState.underReview;
      case 'done': // Nombre literal del enum en Dart
      case 'completed':
      case 'finished':
      case 'hecho':
      case 'completado':
        return TaskState.done;
      default:
        // Log con menos ruido - solo para desarrollo
        if (stateString?.isNotEmpty == true) {
          print(
            '⚠️ Estado desconocido en TaskUtils: "$stateString" → usando toDo por defecto',
          );
        }
        return TaskState.toDo;
    }
  }

  static TaskPriority parseTaskPriority(String? priorityString) {
    if (priorityString == null || priorityString.isEmpty) {
      return TaskPriority.medium;
    }
    final String cleanPriority = priorityString.trim().toLowerCase();

    for (TaskPriority priority in TaskPriority.values) {
      // Compara con el displayName en minúsculas
      if (priority.displayName.toLowerCase() == cleanPriority) {
        return priority;
      }
      // También comparar con el nombre del enum en Dart
      if (priority.name.toLowerCase() == cleanPriority) {
        return priority;
      }
    }
    
    // Log con menos ruido - solo para desarrollo
    if (priorityString?.isNotEmpty == true && priorityString != 'medium') {
      print(
        '⚠️ TaskUtils: Prioridad no reconocida: "$priorityString" → usando medium por defecto',
      );
    }
    return TaskPriority.medium;
  }

  static String normalizePriorityDisplayName(String? priority) {
    return parseTaskPriority(priority).displayName;
  }

  static Color getPriorityColorFromString(String priority) {
    return parseTaskPriority(priority).getColor();
  }

  static String formatFileSize(int? bytes) {
    /* ... (sin cambios) ... */
    if (bytes == null || bytes <= 0) return '0 B';
    if (bytes < 1024) return '${bytes} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  static String detectFileType(String fileName) {
    /* ... (sin cambios) ... */
    if (fileName.isEmpty) return 'file';
    final extension = fileName.contains('.')
        ? fileName.toLowerCase().split('.').last
        : '';
    const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'];
    const docExtensions = ['doc', 'docx', 'odt'];
    const sheetExtensions = ['xls', 'xlsx', 'ods', 'csv'];
    const slideExtensions = ['ppt', 'pptx', 'odp'];
    const pdfExtensions = ['pdf'];
    const archiveExtensions = ['zip', 'rar', '7z', 'tar', 'gz'];
    const audioExtensions = ['mp3', 'wav', 'ogg', 'aac', 'm4a'];
    const videoExtensions = ['mp4', 'mov', 'avi', 'mkv', 'webm', 'flv'];

    if (imageExtensions.contains(extension)) return 'image';
    if (docExtensions.contains(extension)) return 'document';
    if (sheetExtensions.contains(extension)) return 'spreadsheet';
    if (slideExtensions.contains(extension)) return 'presentation';
    if (pdfExtensions.contains(extension)) return 'pdf';
    if (archiveExtensions.contains(extension)) return 'archive';
    if (audioExtensions.contains(extension)) return 'audio';
    if (videoExtensions.contains(extension)) return 'video';
    return 'file';
  }

  // --- Firestore CRUD Operations ---

  static Future<DocumentReference?> createTask({
    required String communityId,
    required String title,
    String description = '',
    required TaskPriority priority,
    required TaskState initialState,
    String? assignedToId,
    String? assignedToName,
    String? assignedToImageUrl,
    DateTime? dueDate,
    required String creatorId,
    required String creatorName,
    String? creatorImageUrl,
    required String communityName,
    bool aiGenerated = false,
    String? aiReason,
    double? aiConfidence,
  }) async {
    try {
      final taskData = {
        'title': title.trim(),
        'description': description.trim(),
        'state': initialState
            .firestoreName, // ✅ Guardará "por hacer", "haciendo", etc.
        'priority': priority.displayName, // ✅ Guardará "Baja", "Media", etc.
        'assignedToId': assignedToId,
        'assignedToName': assignedToName,
        'assignedToUser': assignedToName,
        'assignedToImageUrl': assignedToImageUrl,
        'createdAtId': creatorId,
        'createdAtName': creatorName,
        'createdAtImageUrl': creatorImageUrl,
        'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'communityId': communityId,
        'communityName': communityName,
        if (aiGenerated) 'aiGenerated': true,
        if (aiReason != null && aiReason.isNotEmpty) 'aiReason': aiReason,
        if (aiConfidence != null) 'aiConfidence': aiConfidence,
      };
      final fieldsThatCanBeNull = [
        'dueDate',
        'assignedToId',
        'assignedToName',
        'assignedToUser',
        'assignedToImageUrl',
        'creatorImageUrl',
        'aiReason',
        'aiConfidence',
      ];
      taskData.removeWhere(
        (key, value) => value == null && !fieldsThatCanBeNull.contains(key),
      );

      final docRef = await FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .collection('tasks')
          .add(taskData);
      print('Task created with ID: ${docRef.id} in community $communityId');
      return docRef;
    } catch (e) {
      print('Error creating task in TaskUtils: $e');
      return null;
    }
  }

  static Future<bool> updateTaskDetails({
    required String communityId,
    required String taskId,
    required Map<String, dynamic> updateData,
  }) async {
    try {
      updateData['updatedAt'] = FieldValue.serverTimestamp();

      if (updateData.containsKey('priority')) {
        if (updateData['priority'] is String) {
          updateData['priority'] = parseTaskPriority(
            updateData['priority'] as String?,
          ).displayName;
        } else if (updateData['priority'] is TaskPriority) {
          updateData['priority'] =
              (updateData['priority'] as TaskPriority).displayName;
        }
      }
      if (updateData.containsKey('state')) {
        if (updateData['state'] is String) {
          updateData['state'] = parseTaskState(
            updateData['state'] as String?,
          ).firestoreName;
        } else if (updateData['state'] is TaskState) {
          updateData['state'] =
              (updateData['state'] as TaskState).firestoreName;
        }
      }

      await FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .collection('tasks')
          .doc(taskId)
          .update(updateData);
      print('Task $taskId in community $communityId updated.');
      return true;
    } catch (e) {
      print('Error updating task details in TaskUtils for $taskId: $e');
      return false;
    }
  }

  static Future<bool> updateTaskState({
    required String communityId,
    required String taskId,
    required TaskState newState,
  }) async {
    try {
      // Obtener información de la tarea antes de actualizar
      final taskDoc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .collection('tasks')
          .doc(taskId)
          .get();

      if (!taskDoc.exists) {
        throw Exception('Tarea no encontrada');
      }

      final taskData = taskDoc.data()!;
      final taskTitle = taskData['title'] ?? 'Tarea sin título';
      final previousState = parseTaskState(taskData['state']);

      // Actualizar estado de la tarea
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .collection('tasks')
          .doc(taskId)
          .update({
            'state': newState.firestoreName,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Si la tarea cambió a "under review", notificar a los admins
      if (newState == TaskState.underReview && previousState != TaskState.underReview) {
        await _notifyAdminsTaskUnderReview(
          communityId: communityId,
          taskId: taskId,
          taskTitle: taskTitle,
        );
      }

      print(
        'Task $taskId state in $communityId updated to ${newState.firestoreName}.',
      );
      return true;
    } catch (e) {
      print('Error updating task state in TaskUtils for $taskId: $e');
      return false;
    }
  }

  /// Notificar a los administradores cuando una tarea pase a revisión
  static Future<void> _notifyAdminsTaskUnderReview({
    required String communityId,
    required String taskId,
    required String taskTitle,
  }) async {
    try {
      final communityService = CommunityService();
      final notificationService = FirebaseNotificationService();
      
      // Obtener información de la comunidad
      final community = await communityService.getCommunity(communityId);
      if (community == null) return;

      // Obtener IDs de todos los administradores
      final adminIds = community.getAllAdminIds();
      
      if (adminIds.isEmpty) return;

      // Obtener tokens de notificación de los admins
      final adminTokens = <String>[];
      for (final adminId in adminIds) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(adminId)
              .get();
          
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            final token = userData['fcmToken'] as String?;
            if (token != null && token.isNotEmpty) {
              adminTokens.add(token);
            }
          }
        } catch (e) {
          print('Error obteniendo token de admin $adminId: $e');
        }
      }

      if (adminTokens.isEmpty) return;

      // Crear notificación para administradores
      final notificationData = {
        'title': '📋 Tarea lista para revisión',
        'body': '"$taskTitle" está lista para ser revisada en ${community.name}',
        'type': 'task_under_review',
        'communityId': communityId,
        'taskId': taskId,
        'communityName': community.name,
        'taskTitle': taskTitle,
        'priority': 'high',
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Enviar notificación push a todos los admins
      await notificationService.sendNotificationToMultipleTokens(
        tokens: adminTokens,
        title: notificationData['title'] as String,
        body: notificationData['body'] as String,
        data: notificationData,
      );

      // Guardar notificación en Firestore para cada admin
      for (final adminId in adminIds) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(adminId)
            .collection('notifications')
            .add({
          ...notificationData,
          'recipientId': adminId,
          'read': false,
        });
      }

      print('Notificaciones enviadas a ${adminIds.length} administradores para tarea $taskId');
    } catch (e) {
      print('Error enviando notificaciones a admins: $e');
    }
  }

  static Future<bool> deleteTask({
    /* ... (sin cambios, ya era robusto) ... */
    required String communityId,
    required String taskId,
  }) async {
    try {
      final taskRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .collection('tasks')
          .doc(taskId);
      final filesSnapshot = await taskRef.collection('files').get();
      for (var fileDoc in filesSnapshot.docs) {
        try {
          final fileData = fileDoc.data();
          final url = fileData['url'] as String?;
          if (url != null && url.isNotEmpty) {
            if (url.startsWith('gs://') ||
                url.contains('firebasestorage.googleapis.com')) {
              await FirebaseStorage.instance.refFromURL(url).delete();
              print('Deleted file from Storage: $url');
            } else {
              print('Skipping deletion of non-Firebase Storage URL: $url');
            }
          }
        } catch (e) {
          print(
            'Error deleting file from storage for task $taskId (fileId ${fileDoc.id}): $e',
          );
        }
      }
      WriteBatch batch = FirebaseFirestore.instance.batch();
      final commentsSnapshot = await taskRef.collection('comments').get();
      for (QueryDocumentSnapshot commentDoc in commentsSnapshot.docs) {
        batch.delete(commentDoc.reference);
      }
      for (QueryDocumentSnapshot fileDoc in filesSnapshot.docs) {
        batch.delete(fileDoc.reference);
      }
      batch.delete(taskRef);
      await batch.commit();
      print(
        'Task $taskId and its subcollections/files in $communityId deleted.',
      );
      return true;
    } catch (e) {
      print('Error deleting task in TaskUtils for $taskId in $communityId: $e');
      return false;
    }
  }
}
