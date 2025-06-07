// lib/services/task_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:classroom_mejorado/utils/file_utils.dart';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Singleton pattern para tener una única instancia del servicio
  static final TaskService _instance = TaskService._internal();
  factory TaskService() => _instance;
  TaskService._internal();

  /// Obtiene los detalles de una tarea específica.
  Future<DocumentSnapshot> fetchTaskDetails(String communityId, String taskId) {
    return _firestore
        .collection('communities')
        .doc(communityId)
        .collection('tasks')
        .doc(taskId)
        .get();
  }

  /// Descarga un archivo a un directorio privado y ofrece abrirlo.
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
            onProgress(received / total);
          }
        },
      );

      onComplete();
      await OpenFilex.open(filePath);
    } catch (e) {
      onError('Error al descargar o abrir el archivo: ${e.toString()}');
    }
  }

  /// Sube un archivo a Firebase Storage.
  Future<void> uploadFile(String communityId, String taskId) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null) return;

    final file = File(result.files.single.path!);
    final fileName = result.files.single.name;
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado.');

    final fileRef = _storage.ref(
      'tasks/$communityId/$taskId/${DateTime.now().millisecondsSinceEpoch}_$fileName',
    );
    await fileRef.putFile(file);
    final downloadUrl = await fileRef.getDownloadURL();

    String uploaderName = user.displayName ?? 'Usuario';
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      uploaderName = userDoc.data()?['name'] ?? uploaderName;
    }

    await _firestore
        .collection('communities')
        .doc(communityId)
        .collection('tasks')
        .doc(taskId)
        .collection('files')
        .add({
          'name': fileName,
          'url': downloadUrl,
          'uploadedBy': user.uid,
          'uploadedByName': uploaderName,
          'uploadedAt': FieldValue.serverTimestamp(),
          'type': detectFileType(fileName),
          'size': result.files.single.size,
        });
  }

  /// Elimina un archivo de Storage y Firestore.
  Future<void> deleteFile(
    String communityId,
    String taskId,
    String fileId,
    String? fileUrl,
  ) async {
    if (fileUrl != null) {
      try {
        await _storage.refFromURL(fileUrl).delete();
      } catch (e) {
        print("Error deleting from Storage, may already be gone: $e");
      }
    }
    await _firestore
        .collection('communities')
        .doc(communityId)
        .collection('tasks')
        .doc(taskId)
        .collection('files')
        .doc(fileId)
        .delete();
  }

  /// Actualiza el estado de la tarea en Firestore.
  Future<void> updateTaskState(
    String communityId,
    String taskId,
    String newState,
  ) async {
    await _firestore
        .collection('communities')
        .doc(communityId)
        .collection('tasks')
        .doc(taskId)
        .update({'state': newState});
  }

  /// Añade un comentario a la tarea.
  Future<void> addComment(
    String communityId,
    String taskId,
    String text,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado.');

    String senderName = user.displayName ?? 'Anónimo';
    String? senderPhotoUrl = user.photoURL;
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      senderName = userDoc.data()?['name'] ?? senderName;
      senderPhotoUrl = userDoc.data()?['photoURL'] ?? senderPhotoUrl;
    }

    await _firestore
        .collection('communities')
        .doc(communityId)
        .collection('tasks')
        .doc(taskId)
        .collection('comments')
        .add({
          'text': text,
          'senderId': user.uid,
          'senderName': senderName,
          'senderImageUrl': senderPhotoUrl,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  /// Elimina una tarea y todos sus sub-documentos y archivos.
  Future<void> deleteTask(String communityId, String taskId) async {
    final taskRef = _firestore
        .collection('communities')
        .doc(communityId)
        .collection('tasks')
        .doc(taskId);

    final filesSnapshot = await taskRef.collection('files').get();
    for (var doc in filesSnapshot.docs) {
      await deleteFile(communityId, taskId, doc.id, doc.data()['url']);
    }

    final commentsSnapshot = await taskRef.collection('comments').get();
    WriteBatch batch = _firestore.batch();
    for (var doc in commentsSnapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    await taskRef.delete();
  }
}
