// lib/services/file_upload_service.dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart'; // Para ImageSource si lo necesitas aquí

// Opcional: puedes definir un enum para los tipos de rutas de subida
enum FileUploadPath {
  communityAvatars,
  taskFiles,
  profilePictures,
  // Añade más según necesites
}

class FileUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker =
      ImagePicker(); // Si quieres centralizar la selección también

  // --- Método general para subir un archivo ---
  Future<String?> uploadFile({
    required File file,
    required String path, // ej: 'community_avatars' o 'task_files/taskId'
    required String fileName, // ej: 'communityId_timestamp.jpg'
  }) async {
    try {
      final ref = _storage.ref().child(path).child(fileName);
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error al subir archivo a Firebase Storage: $e');
      // Podrías lanzar una excepción personalizada o retornar null
      // throw Exception('Error al subir el archivo: $e');
      return null;
    }
  }

  // --- Método específico para seleccionar y subir una imagen de comunidad ---
  // Este combina la selección y la subida. Podrías separarlos si prefieres más granularidad.
  Future<String?> pickAndUploadCommunityImage({
    required ImageSource source,
    required String communityId, // Para nombrar el archivo
    int imageQuality = 70,
    double maxWidth = 1024,
    double maxHeight = 1024,
  }) async {
    try {
      final pickedImage = await _picker.pickImage(
        source: source,
        imageQuality: imageQuality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );

      if (pickedImage == null) {
        return null; // El usuario canceló la selección
      }

      final File imageFile = File(pickedImage.path);
      final String fileName =
          '${communityId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      return await uploadFile(
        file: imageFile,
        path: 'community_avatars', // Ruta específica en Storage
        fileName: fileName,
      );
    } catch (e) {
      print('Error en pickAndUploadCommunityImage: $e');
      return null;
    }
  }

  // --- Opcional: Borrar un archivo de Storage por su URL ---
  // Esto es más complejo porque la URL de descarga no es directamente la ruta de Storage.
  // Necesitarías almacenar la ruta completa de Storage si quieres borrar archivos eficientemente.
  // O, si solo tienes la URL de descarga, puedes usar refFromURL, pero tiene limitaciones y
  // podría no ser la mejor práctica para todos los casos de uso.
  Future<bool> deleteFileFromStorageByUrl(String fileUrl) async {
    if (fileUrl.isEmpty) return false;
    try {
      final Reference storageRef = _storage.refFromURL(fileUrl);
      await storageRef.delete();
      return true;
    } catch (e) {
      print("Error borrando archivo de Storage por URL $fileUrl: $e");
      // Posibles errores: objeto no existe, permisos, etc.
      // Si el error es 'object-not-found', podrías considerarlo un éxito de borrado (ya no está).
      if (e is FirebaseException && e.code == 'object-not-found') {
        return true;
      }
      return false;
    }
  }

  // Podrías añadir más métodos específicos aquí, por ejemplo, para subir archivos de tareas, etc.
}
