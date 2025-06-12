import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' hide Task;
import 'package:classroom_mejorado/features/tasks/models/task_model.dart';
import 'package:classroom_mejorado/core/utils/task_utils.dart' as task_utils;
import 'package:classroom_mejorado/core/services/trash_service.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class TaskService {
  static final TaskService _instance = TaskService._internal();
  factory TaskService() => _instance;
  TaskService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TrashService _trashService = TrashService();

  // Obtener tareas de una comunidad
  Stream<List<Task>> getCommunityTasks(String communityId, {TaskFilter? filter}) {
    return _firestore
        .collection('communities')
        .doc(communityId)
        .collection('tasks')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      var tasks = snapshot.docs
          .map((doc) => Task.fromFirestore(doc, communityId))
          .toList();
      
      if (filter != null) {
        tasks = tasks.where((task) => filter.matches(task)).toList();
      }
      
      return tasks;
    });
  }

  // Obtener tareas del usuario actual
  Stream<List<Task>> getUserTasks({TaskFilter? filter}) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collectionGroup('tasks')
        .where('assignedTo', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      var tasks = snapshot.docs
          .map((doc) {
            // Extraer el communityId desde la ruta del documento
            final pathSegments = doc.reference.path.split('/');
            final communityId = pathSegments[1]; // communities/{communityId}/tasks/{taskId}
            return Task.fromFirestore(doc, communityId);
          })
          .toList();
      
      if (filter != null) {
        tasks = tasks.where((task) => filter.matches(task)).toList();
      }
      
      return tasks;
    });
  }

  // Obtener una tarea específica
  Future<Task?> getTask(String communityId, String taskId) async {
    try {
      final doc = await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('tasks')
          .doc(taskId)
          .get();
      
      if (doc.exists) {
        return Task.fromFirestore(doc, communityId);
      }
      return null;
    } catch (e) {
      throw Exception('Error al obtener la tarea: $e');
    }
  }

  // Stream de una tarea específica
  Stream<Task?> getTaskStream(String communityId, String taskId) {
    return _firestore
        .collection('communities')
        .doc(communityId)
        .collection('tasks')
        .doc(taskId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return Task.fromFirestore(doc, communityId);
      }
      return null;
    });
  }

  // Crear nueva tarea
  Future<String> createTask(Task task) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final taskData = task.copyWith(
        createdBy: user.uid,
        createdByName: user.displayName ?? 'Usuario',
        createdAt: DateTime.now(),
      );

      final docRef = await _firestore
          .collection('communities')
          .doc(task.communityId)
          .collection('tasks')
          .add(taskData.toFirestore());

      return docRef.id;
    } catch (e) {
      throw Exception('Error al crear la tarea: $e');
    }
  }

  // Actualizar tarea
  Future<void> updateTask(String communityId, String taskId, Map<String, dynamic> updates) async {
    try {
      await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('tasks')
          .doc(taskId)
          .update(updates);
    } catch (e) {
      throw Exception('Error al actualizar la tarea: $e');
    }
  }

  // Actualizar estado de tarea
  Future<void> updateTaskStatus(String communityId, String taskId, task_utils.TaskState newStatus) async {
    try {
      await updateTask(communityId, taskId, {'state': newStatus.name.toLowerCase()});
    } catch (e) {
      throw Exception('Error al actualizar el estado de la tarea: $e');
    }
  }

  // Asignar tarea a usuario
  Future<void> assignTask(String communityId, String taskId, String userId, String userName) async {
    try {
      await updateTask(communityId, taskId, {
        'assignedTo': userId,
        'assignedToName': userName,
      });
    } catch (e) {
      throw Exception('Error al asignar la tarea: $e');
    }
  }

  // Eliminar tarea
  Future<void> deleteTask(String communityId, String taskId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      // Verificar permisos - solo el creador o admin puede eliminar
      final task = await getTask(communityId, taskId);
      if (task == null) throw Exception('Tarea no encontrada');

      final memberDoc = await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .doc(user.uid)
          .get();

      final userRole = memberDoc.data()?['role'] ?? 'member';
      
      if (task.createdBy != user.uid && userRole != 'admin' && userRole != 'owner') {
        throw Exception('No tienes permisos para eliminar esta tarea');
      }

      // Eliminar comentarios de la tarea
      final commentsSnapshot = await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('tasks')
          .doc(taskId)
          .collection('comments')
          .get();

      for (var commentDoc in commentsSnapshot.docs) {
        await commentDoc.reference.delete();
      }

      // Eliminar la tarea
      await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('tasks')
          .doc(taskId)
          .delete();
    } catch (e) {
      throw Exception('Error al eliminar la tarea: $e');
    }
  }

  // Obtener tareas con fechas de entrega para calendario
  Future<Map<DateTime, List<Task>>> getTasksForCalendar(String communityId) async {
    try {
      final snapshot = await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('tasks')
          .get();

      Map<DateTime, List<Task>> tasksByDate = {};

      for (var doc in snapshot.docs) {
        final task = Task.fromFirestore(doc, communityId);
        
        if (task.dueDate != null) {
          final normalizedDate = DateTime(
            task.dueDate!.year,
            task.dueDate!.month,
            task.dueDate!.day,
          );

          if (tasksByDate[normalizedDate] == null) {
            tasksByDate[normalizedDate] = [];
          }
          tasksByDate[normalizedDate]!.add(task);
        }
      }

      // Ordenar tareas por hora dentro de cada día
      tasksByDate.forEach((date, tasks) {
        tasks.sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
      });

      return tasksByDate;
    } catch (e) {
      throw Exception('Error al obtener tareas para calendario: $e');
    }
  }

  // Obtener tareas que vencen hoy
  Future<List<Task>> getTasksDueToday(String communityId) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('tasks')
          .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .where('dueDate', isLessThan: Timestamp.fromDate(tomorrow))
          .get();

      return snapshot.docs
          .map((doc) => Task.fromFirestore(doc, communityId))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener tareas de hoy: $e');
    }
  }

  // Obtener tareas vencidas
  Future<List<Task>> getOverdueTasks(String communityId) async {
    try {
      final now = DateTime.now();

      final snapshot = await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('tasks')
          .where('dueDate', isLessThan: Timestamp.fromDate(now))
          .where('state', whereNotIn: ['done', 'completed'])
          .get();

      return snapshot.docs
          .map((doc) => Task.fromFirestore(doc, communityId))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener tareas vencidas: $e');
    }
  }

  // Obtener comentarios de una tarea
  Stream<List<TaskComment>> getTaskComments(String communityId, String taskId) {
    return _firestore
        .collection('communities')
        .doc(communityId)
        .collection('tasks')
        .doc(taskId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TaskComment.fromFirestore(doc))
          .toList();
    });
  }

  // Agregar comentario a tarea
  Future<void> addTaskComment(String communityId, String taskId, String content) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final comment = TaskComment(
        id: '',
        content: content,
        authorId: user.uid,
        authorName: user.displayName ?? 'Usuario',
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('tasks')
          .doc(taskId)
          .collection('comments')
          .add(comment.toFirestore());
    } catch (e) {
      throw Exception('Error al agregar comentario: $e');
    }
  }

  // Obtener estadísticas globales de tareas
  Future<Map<String, dynamic>> getGlobalTaskStats() async {
    try {
      final snapshot = await _firestore.collectionGroup('tasks').get();
      
      int totalTasks = snapshot.docs.length;
      int completedTasks = 0;
      int activeTasks = 0;
      Map<String, int> tasksByStatus = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final status = data['state'] as String? ?? 'toDo';
        
        tasksByStatus[status] = (tasksByStatus[status] ?? 0) + 1;
        
        if (status == 'done' || status == 'completed') {
          completedTasks++;
        } else {
          activeTasks++;
        }
      }

      return {
        'totalTasks': totalTasks,
        'completedTasks': completedTasks,
        'activeTasks': activeTasks,
        'tasksByStatus': tasksByStatus,
      };
    } catch (e) {
      throw Exception('Error al obtener estadísticas globales: $e');
    }
  }

  // Obtener tareas recientes de una comunidad
  Future<List<Task>> getRecentTasks(String communityId, {int limit = 5}) async {
    try {
      final snapshot = await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('tasks')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => Task.fromFirestore(doc, communityId))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener tareas recientes: $e');
    }
  }

  // Buscar tareas
  Future<List<Task>> searchTasks(String communityId, String query) async {
    try {
      final snapshot = await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('tasks')
          .get();

      final queryLower = query.toLowerCase();
      
      return snapshot.docs
          .map((doc) => Task.fromFirestore(doc, communityId))
          .where((task) =>
              task.title.toLowerCase().contains(queryLower) ||
              task.description.toLowerCase().contains(queryLower))
          .toList();
    } catch (e) {
      throw Exception('Error al buscar tareas: $e');
    }
  }

  // Download file method
  Future<void> downloadFile({
    required String url,
    required String fileName,
    required Function(double) onProgress,
    required Function() onComplete,
    required Function(String) onError,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      
      final dio = Dio();
      await dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            onProgress(progress);
          }
        },
      );
      
      onComplete();
      
      // File downloaded successfully - could add platform-specific opening logic here
      print('File downloaded to: $filePath');
      
    } catch (e) {
      onError(e.toString());
    }
  }

  // Delete file method
  Future<void> deleteFile(String communityId, String taskId, String fileId, String fileUrl) async {
    try {
      // Obtener información del archivo antes de eliminarlo
      final fileDoc = await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('tasks')
          .doc(taskId)
          .collection('files')
          .doc(fileId)
          .get();

      if (!fileDoc.exists) {
        throw Exception('Archivo no encontrado');
      }

      final fileData = fileDoc.data()!;
      final fileName = fileData['name'] ?? 'archivo_sin_nombre';
      
      // Delete from Firestore first
      await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('tasks')
          .doc(taskId)
          .collection('files')
          .doc(fileId)
          .delete();

      // Move to trash and delete from Firebase Storage
      if (fileUrl.isNotEmpty && 
          (fileUrl.startsWith('gs://') || fileUrl.contains('firebasestorage.googleapis.com'))) {
        try {
          final storageRef = FirebaseStorage.instance.refFromURL(fileUrl);
          final filePath = storageRef.fullPath;
          
          // Mover a papelera con metadatos completos
          await _trashService.deleteFile(
            filePath: filePath,
            fileName: fileName,
            communityId: communityId,
            taskId: taskId,
            additionalMetadata: {
              'fileId': fileId,
              'originalUrl': fileUrl,
              'fileType': fileData['type'] ?? 'unknown',
              'fileSize': fileData['size'] ?? 0,
              'uploadedBy': fileData['uploadedBy'],
              'uploadedAt': fileData['uploadedAt'],
              'context': 'task_file',
            },
          );
        } catch (e) {
          print('Error moving file to trash: $e');
          // Si falla mover a papelera, intentar eliminación directa
          try {
            final storageRef = FirebaseStorage.instance.refFromURL(fileUrl);
            await storageRef.delete();
          } catch (deleteError) {
            print('Error deleting file from storage: $deleteError');
          }
        }
      }
    } catch (e) {
      throw Exception('Error al eliminar archivo: $e');
    }
  }
}