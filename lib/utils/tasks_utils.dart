// lib/utils/tasks_utils.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
        return TaskState.toDo;
      case 'doing': // Nombre literal del enum en Dart si es TaskState.doing
      case 'in_progress':
      case 'inprogress':
        return TaskState.doing;
      case 'underreview': // Nombre literal del enum en Dart
      case 'under_review':
      case 'testing':
      case 'review':
        return TaskState.underReview;
      case 'done': // Nombre literal del enum en Dart
      case 'completed':
      case 'finished':
        return TaskState.done;
      default:
        print(
          '⚠️ TaskUtils: Estado no reconocido: "$stateString" → usando TaskState.toDo',
        );
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
      // Opcional: comparar con el nombre del enum en Dart si también lo usas
      // if (priority.name.toLowerCase() == cleanPriority) { // priority.name es 'low', 'medium', etc.
      //   return priority;
      // }
    }
    print(
      '⚠️ TaskUtils: Prioridad no reconocida: "$priorityString" → usando TaskPriority.medium',
    );
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
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .collection('tasks')
          .doc(taskId)
          .update({
            'state': newState
                .firestoreName, // ✅ Guardará "por hacer", "haciendo", etc.
            'updatedAt': FieldValue.serverTimestamp(),
          });
      print(
        'Task $taskId state in $communityId updated to ${newState.firestoreName}.',
      );
      return true;
    } catch (e) {
      print('Error updating task state in TaskUtils for $taskId: $e');
      return false;
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
