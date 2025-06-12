import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Servicio para manejar la papelera de archivos eliminados
class TrashService {
  static final TrashService _instance = TrashService._internal();
  factory TrashService() => _instance;
  TrashService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Mover archivo a la papelera antes de eliminarlo
  Future<bool> moveToTrash({
    required String originalPath,
    required String fileName,
    required String communityId,
    String? taskId,
    String? messageId,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Obtener referencia del archivo original
      final originalRef = _storage.ref(originalPath);
      
      // Crear nuevo path en la papelera
      final trashPath = 'trash/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final trashRef = _storage.ref(trashPath);

      // Copiar archivo a la papelera
      final downloadUrl = await originalRef.getDownloadURL();
      
      // Crear metadatos del archivo en la papelera
      final trashMetadata = {
        'originalPath': originalPath,
        'trashPath': trashPath,
        'fileName': fileName,
        'downloadUrl': downloadUrl,
        'deletedBy': user.uid,
        'deletedByEmail': user.email,
        'deletedByName': user.displayName ?? user.email?.split('@')[0] ?? 'Usuario desconocido',
        'deletedAt': FieldValue.serverTimestamp(),
        'communityId': communityId,
        if (taskId != null) 'taskId': taskId,
        if (messageId != null) 'messageId': messageId,
        'type': _getFileType(fileName),
        'reason': 'user_deletion',
        'canRestore': true,
        'autoDeleteAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 30)), // Auto-eliminar en 30 días
        ),
        ...?additionalMetadata,
      };

      // Guardar metadatos en Firestore
      await _firestore.collection('trash').add(trashMetadata);

      print('Archivo movido a papelera: $fileName');
      return true;
    } catch (e) {
      print('Error moviendo archivo a papelera: $e');
      return false;
    }
  }

  /// Eliminar archivo y moverlo a papelera
  Future<bool> deleteFile({
    required String filePath,
    required String fileName,
    required String communityId,
    String? taskId,
    String? messageId,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    try {
      // Primero mover a papelera
      final movedToTrash = await moveToTrash(
        originalPath: filePath,
        fileName: fileName,
        communityId: communityId,
        taskId: taskId,
        messageId: messageId,
        additionalMetadata: additionalMetadata,
      );

      if (!movedToTrash) return false;

      // Después eliminar el archivo original
      await _storage.ref(filePath).delete();
      
      print('Archivo eliminado y movido a papelera: $fileName');
      return true;
    } catch (e) {
      print('Error eliminando archivo: $e');
      return false;
    }
  }

  /// Restaurar archivo desde la papelera
  Future<bool> restoreFile(String trashDocId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Obtener documento de la papelera
      final trashDoc = await _firestore.collection('trash').doc(trashDocId).get();
      if (!trashDoc.exists) return false;

      final data = trashDoc.data()!;
      final originalPath = data['originalPath'] as String;
      final trashPath = data['trashPath'] as String;
      final downloadUrl = data['downloadUrl'] as String;

      // Verificar permisos (solo quien eliminó o admins pueden restaurar)
      final deletedBy = data['deletedBy'] as String;
      final communityId = data['communityId'] as String;
      
      if (user.uid != deletedBy) {
        // Verificar si es admin de la comunidad
        // Aquí podrías agregar lógica para verificar permisos de admin
      }

      // Crear registro de restauración
      await _firestore.collection('trash').doc(trashDocId).update({
        'restoredBy': user.uid,
        'restoredByEmail': user.email,
        'restoredByName': user.displayName ?? user.email?.split('@')[0] ?? 'Usuario desconocido',
        'restoredAt': FieldValue.serverTimestamp(),
        'status': 'restored',
      });

      print('Archivo restaurado desde papelera');
      return true;
    } catch (e) {
      print('Error restaurando archivo: $e');
      return false;
    }
  }

  /// Obtener archivos en la papelera
  Stream<List<Map<String, dynamic>>> getTrashFiles({
    String? communityId,
    String? deletedByUserId,
  }) {
    Query query = _firestore.collection('trash')
        .where('canRestore', isEqualTo: true)
        .orderBy('deletedAt', descending: true);

    if (communityId != null) {
      query = query.where('communityId', isEqualTo: communityId);
    }

    if (deletedByUserId != null) {
      query = query.where('deletedBy', isEqualTo: deletedByUserId);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Eliminar permanentemente de la papelera
  Future<bool> deletePermanently(String trashDocId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Obtener documento de la papelera
      final trashDoc = await _firestore.collection('trash').doc(trashDocId).get();
      if (!trashDoc.exists) return false;

      final data = trashDoc.data()!;
      final trashPath = data['trashPath'] as String?;

      // Eliminar archivo físico de la papelera
      if (trashPath != null) {
        try {
          await _storage.ref(trashPath).delete();
        } catch (e) {
          print('Archivo ya no existe en Storage: $e');
        }
      }

      // Marcar como eliminado permanentemente en lugar de eliminar el documento
      await _firestore.collection('trash').doc(trashDocId).update({
        'permanentlyDeletedBy': user.uid,
        'permanentlyDeletedByEmail': user.email,
        'permanentlyDeletedAt': FieldValue.serverTimestamp(),
        'status': 'permanently_deleted',
        'canRestore': false,
      });

      print('Archivo eliminado permanentemente de la papelera');
      return true;
    } catch (e) {
      print('Error eliminando permanentemente: $e');
      return false;
    }
  }

  /// Limpiar archivos expirados automáticamente
  Future<void> cleanExpiredFiles() async {
    try {
      final now = Timestamp.now();
      
      // Buscar archivos que ya expiraron
      final expiredFiles = await _firestore
          .collection('trash')
          .where('autoDeleteAt', isLessThan: now)
          .where('canRestore', isEqualTo: true)
          .get();

      for (var doc in expiredFiles.docs) {
        await deletePermanently(doc.id);
      }

      print('Limpieza automática completada: ${expiredFiles.docs.length} archivos eliminados');
    } catch (e) {
      print('Error en limpieza automática: $e');
    }
  }

  /// Determinar tipo de archivo por extensión
  String _getFileType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    
    const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];
    const documentExtensions = ['pdf', 'doc', 'docx', 'txt', 'rtf'];
    const videoExtensions = ['mp4', 'avi', 'mov', 'wmv', 'flv'];
    const audioExtensions = ['mp3', 'wav', 'aac', 'ogg'];
    
    if (imageExtensions.contains(extension)) return 'image';
    if (documentExtensions.contains(extension)) return 'document';
    if (videoExtensions.contains(extension)) return 'video';
    if (audioExtensions.contains(extension)) return 'audio';
    
    return 'file';
  }

  /// Obtener estadísticas de la papelera
  Future<Map<String, dynamic>> getTrashStats({String? communityId}) async {
    try {
      Query query = _firestore.collection('trash')
          .where('canRestore', isEqualTo: true);

      if (communityId != null) {
        query = query.where('communityId', isEqualTo: communityId);
      }

      final snapshot = await query.get();
      
      int totalFiles = snapshot.docs.length;
      Map<String, int> filesByType = {};
      int totalSize = 0;
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final type = data['type'] as String? ?? 'file';
        filesByType[type] = (filesByType[type] ?? 0) + 1;
        
        // Si tienes información de tamaño, súmala aquí
        final size = data['size'] as int? ?? 0;
        totalSize += size;
      }

      return {
        'totalFiles': totalFiles,
        'filesByType': filesByType,
        'totalSize': totalSize,
      };
    } catch (e) {
      print('Error obteniendo estadísticas de papelera: $e');
      return {
        'totalFiles': 0,
        'filesByType': <String, int>{},
        'totalSize': 0,
      };
    }
  }
}