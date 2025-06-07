// lib/screen/TaskDetailScreen.dart - CON DESCARGA REAL DE ARCHIVOS Y DETECCIÓN AUTOMÁTICA
//
// ✅ PERMISOS PARA COMPLETAR TAREAS:
// - Administradores globales (role: "admin" en colección users)
// - Propietarios de la comunidad (ownerId en colección communities)
//
// ✅ PERMISOS REQUERIDOS EN ANDROID (android/app/src/main/AndroidManifest.xml):
// <uses-permission android:name="android.permission.INTERNET" />
// <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
// <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
// <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />
//
// ✅ DEPENDENCIAS REQUERIDAS EN pubspec.yaml:
// dio: ^5.4.0
// path_provider: ^2.1.2
// permission_handler: ^11.3.0
// file_picker: ^6.1.1
// url_launcher: ^6.1.9
// firebase_storage: ^11.6.0
// cached_network_image: ^3.3.0

import 'package:cached_network_image/cached_network_image.dart';
import 'package:classroom_mejorado/widgets/task_detail/task_files_section.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:classroom_mejorado/theme/app_typography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:classroom_mejorado/utils/tasks_utils.dart' as task_utils;
import 'dart:io';

class TaskDetailScreen extends StatefulWidget {
  final String communityId;
  final String taskId;

  const TaskDetailScreen({
    super.key,
    required this.communityId,
    required this.taskId,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen>
    with TickerProviderStateMixin {
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _editTitleController = TextEditingController();
  final TextEditingController _editDescriptionController =
      TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  late Future<DocumentSnapshot> _taskFuture;
  late AnimationController _addCommentAnimationController;
  late Animation<double> _addCommentAnimation;

  // Estados
  bool _isAddingComment = false;
  bool _isEditingTask = false;
  bool _isDeletingTask = false;
  bool _isUploadingFile = false;
  bool _isDownloadingAll = false;
  Map<String, double> _downloadProgress = {}; // Para progreso individual

  // Variables para edición de la tarea
  String _editPriority = 'Media';
  DateTime? _editDueDate;
  String? _editAssignedToId;
  String? _editAssignedToName;
  String? _editAssignedToImageUrl;
  List<Map<String, dynamic>> _editCommunityMembers = [];
  bool _fetchingEditMembers = true;

  @override
  void initState() {
    super.initState();
    _taskFuture = _fetchTaskDetails();

    _addCommentAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _addCommentAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _addCommentAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _editTitleController.dispose();
    _editDescriptionController.dispose();
    _commentFocusNode.dispose();
    _addCommentAnimationController.dispose();
    // ✅ LIMPIAR PROGRESO DE DESCARGA AL SALIR
    _downloadProgress.clear();
    super.dispose();
  }

  // ✅ FUNCIÓN: Normalizar prioridad
  String _normalizePriority(String? priority) {
    if (priority == null || priority.isEmpty) return 'Media';

    switch (priority.toLowerCase().trim()) {
      case 'baja':
      case 'low':
        return 'Baja';
      case 'media':
      case 'medium':
        return 'Media';
      case 'alta':
      case 'high':
        return 'Alta';
      case 'urgente':
      case 'urgent':
        return 'Urgente';
      default:
        return 'Media';
    }
  }

  Future<DocumentSnapshot> _fetchTaskDetails() async {
    return await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('tasks')
        .doc(widget.taskId)
        .get();
  }

  // ✅ FUNCIÓN PARA FORMATEAR TAMAÑO DE ARCHIVO
  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes == 0) return '';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  // ✅ FUNCIÓN PARA DETECTAR TIPO DE ARCHIVO AUTOMÁTICAMENTE
  String _detectFileType(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'];
    return imageExtensions.contains(extension) ? 'image' : 'file';
  }

  // ✅ FUNCIÓN MEJORADA PARA MAPEAR ESTADOS CON RETROCOMPATIBILIDAD (IGUAL QUE MyTasksScreen)
  task_utils.TaskState _parseTaskState(String? stateString) {
    if (stateString == null || stateString.isEmpty) {
      return task_utils.TaskState.toDo;
    }

    final String stateLower = stateString.toLowerCase();

    // Mapeo directo por nombre del enum
    for (task_utils.TaskState state in task_utils.TaskState.values) {
      if (state.name.toLowerCase() == stateLower) {
        return state;
      }
    }

    // ✅ RETROCOMPATIBILIDAD: Mapear valores antiguos
    switch (stateLower) {
      case 'testing': // Valor antiguo -> nuevo valor
        return task_utils.TaskState.underReview;
      case 'todo':
      case 'to_do':
      case 'por hacer': // ✅ NUEVO: Compatibilidad con texto en español
        return task_utils.TaskState.toDo;
      case 'inprogress':
      case 'in_progress':
      case 'haciendo': // ✅ NUEVO: Compatibilidad con texto en español
        return task_utils.TaskState.doing;
      case 'review':
      case 'under_review':
      case 'por revisar': // ✅ NUEVO: Compatibilidad con texto en español
        return task_utils.TaskState.underReview;
      case 'completed':
      case 'finished':
      case 'hecho': // ✅ NUEVO: Compatibilidad con texto en español
        return task_utils.TaskState.done;
      default:
        print(
          '⚠️ Estado desconocido en TaskDetailScreen: $stateString - usando toDo por defecto',
        );
        return task_utils.TaskState.toDo;
    }
  }

  Future<bool> _isUserCommunityOwner() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;

      final communityDoc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .get();

      if (!communityDoc.exists) return false;

      final ownerId = communityDoc.get('ownerId') as String?;
      return ownerId == currentUser.uid;
    } catch (e) {
      print('Error checking community owner: $e');
      return false;
    }
  }

  // ✅ FUNCIÓN PARA VERIFICAR SI EL USUARIO ES ADMIN (mantiene la funcionalidad original)
  Future<bool> _isUserAdmin() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) return false;

      final userData = userDoc.data() as Map<String, dynamic>;
      final role = userData['role'] as String?;

      return role?.toLowerCase() == 'admin';
    } catch (e) {
      print('Error checking admin role: $e');
      return false;
    }
  }

  // ✅ FUNCIÓN HÍBRIDA: Verificar si puede completar tareas (admin O propietario)
  Future<bool> _canCompleteTask() async {
    // Verificar si es admin global O propietario de la comunidad
    final isAdmin = await _isUserAdmin();
    final isOwner = await _isUserCommunityOwner();

    return isAdmin || isOwner;
  }

  // ✅ NUEVAS FUNCIONES PARA MANEJO DE ARCHIVOS (SIN PREGUNTAR TIPO)
  Future<void> _uploadFile() async {
    try {
      setState(() {
        _isUploadingFile = true;
      });

      // Elegir archivo directamente sin preguntar tipo
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowedExtensions: null,
      );

      if (result == null) {
        setState(() {
          _isUploadingFile = false;
        });
        return;
      }

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;

      // ✅ DETECTAR TIPO AUTOMÁTICAMENTE
      final fileType = _detectFileType(fileName);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnackBar('Usuario no autenticado', isError: true);
        setState(() {
          _isUploadingFile = false;
        });
        return;
      }

      // Subir archivo a Firebase Storage
      final storageRef = FirebaseStorage.instance.ref();
      final fileRef = storageRef.child(
        'tasks/${widget.communityId}/${widget.taskId}/${DateTime.now().millisecondsSinceEpoch}_$fileName',
      );

      final uploadTask = fileRef.putFile(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Obtener datos del usuario para el nombre
      String uploaderName = user.displayName ?? 'Usuario';
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          uploaderName =
              userData['name'] ?? userData['displayName'] ?? uploaderName;
        }
      } catch (e) {
        print('Error getting user data: $e');
      }

      // Guardar información del archivo en Firestore
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('tasks')
          .doc(widget.taskId)
          .collection('files')
          .add({
            'name': fileName,
            'url': downloadUrl,
            'uploadedBy': user.uid,
            'uploadedByName': uploaderName,
            'uploadedAt': FieldValue.serverTimestamp(),
            'type': fileType, // ✅ TIPO DETECTADO AUTOMÁTICAMENTE
            'size': result.files.single.size,
          });

      _showSnackBar('✓ Archivo subido correctamente', isError: false);

      // Refrescar detalles de la tarea
      setState(() {
        _taskFuture = _fetchTaskDetails();
      });
    } catch (e) {
      print('Error uploading file: $e');
      _showSnackBar('Error al subir archivo: $e', isError: true);
    } finally {
      setState(() {
        _isUploadingFile = false;
      });
    }
  }

  // ✅ FUNCIÓN PARA REEMPLAZAR ARCHIVO (SIN PREGUNTAR TIPO)
  Future<void> _replaceFile(String fileId, String currentFileName) async {
    try {
      // Confirmar reemplazo
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Reemplazar archivo'),
          content: Text('¿Quieres reemplazar "$currentFileName"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
              ),
              child: Text('Reemplazar'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Elegir nuevo archivo
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowedExtensions: null,
      );

      if (result == null) return;

      setState(() {
        _isUploadingFile = true;
      });

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;

      // ✅ DETECTAR TIPO AUTOMÁTICAMENTE
      final fileType = _detectFileType(fileName);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnackBar('Usuario no autenticado', isError: true);
        setState(() {
          _isUploadingFile = false;
        });
        return;
      }

      // Obtener el documento del archivo actual para eliminar el archivo anterior
      final fileDoc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('tasks')
          .doc(widget.taskId)
          .collection('files')
          .doc(fileId)
          .get();

      String? oldUrl;
      if (fileDoc.exists) {
        final data = fileDoc.data() as Map<String, dynamic>;
        oldUrl = data['url'] as String?;
      }

      // Subir nuevo archivo
      final storageRef = FirebaseStorage.instance.ref();
      final fileRef = storageRef.child(
        'tasks/${widget.communityId}/${widget.taskId}/${DateTime.now().millisecondsSinceEpoch}_$fileName',
      );

      final uploadTask = fileRef.putFile(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Obtener datos del usuario
      String uploaderName = user.displayName ?? 'Usuario';
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          uploaderName =
              userData['name'] ?? userData['displayName'] ?? uploaderName;
        }
      } catch (e) {
        print('Error getting user data: $e');
      }

      // Actualizar documento en Firestore
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('tasks')
          .doc(widget.taskId)
          .collection('files')
          .doc(fileId)
          .update({
            'name': fileName,
            'url': downloadUrl,
            'uploadedBy': user.uid,
            'uploadedByName': uploaderName,
            'uploadedAt': FieldValue.serverTimestamp(),
            'type': fileType, // ✅ TIPO DETECTADO AUTOMÁTICAMENTE
            'size': result.files.single.size,
          });

      // Eliminar archivo anterior del Storage
      if (oldUrl != null) {
        try {
          await FirebaseStorage.instance.refFromURL(oldUrl).delete();
        } catch (e) {
          print('Error deleting old file: $e');
        }
      }

      _showSnackBar('✓ Archivo reemplazado correctamente', isError: false);
    } catch (e) {
      print('Error replacing file: $e');
      _showSnackBar('Error al reemplazar archivo: $e', isError: true);
    } finally {
      setState(() {
        _isUploadingFile = false;
      });
    }
  }

  // Elimina estas importaciones si ya no son necesarias
  // import 'package:permission_handler/permission_handler.dart';
  // import 'dart:io';

  // ... (otras importaciones y el resto de tu código) ...

  // Dentro de _TaskDetailScreenState

  // ✅ FUNCIÓN MEJORADA PARA DESCARGAR ARCHIVO REALMENTE (SIN PEDIR PERMISOS)
  Future<void> _downloadFile(String url, String fileName) async {
    try {
      // ✅ ELIMINADO: No se necesitan permisos de almacenamiento para guardar en la carpeta de la app.
      // if (Platform.isAndroid) {
      //   final status = await Permission.storage.request();
      //   if (!status.isGranted) {
      //     _showSnackBar('Permisos de almacenamiento requeridos', isError: true);
      //     return;
      //   }
      // }

      setState(() {
        _downloadProgress[fileName] = 0.0;
      });

      // Obtener directorio de documentos de la aplicación (almacenamiento privado)
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';

      // Verificar si el archivo ya existe
      final existingFile = File(filePath);
      if (await existingFile.exists()) {
        final shouldReplace = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Archivo ya existe'),
            content: Text('¿Quieres reemplazar "$fileName"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Reemplazar'),
              ),
            ],
          ),
        );

        if (shouldReplace != true) {
          setState(() {
            _downloadProgress.remove(fileName);
          });
          return;
        }
      }

      // Descargar archivo con Dio
      final dio = Dio();
      await dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            setState(() {
              _downloadProgress[fileName] = progress;
            });
          }
        },
      );

      setState(() {
        _downloadProgress.remove(fileName);
      });

      _showSnackBar(
        '✓ $fileName descargado en: ${directory.path}', // ✅ Mensaje actualizado a la ruta real
        isError: false,
      );

      // ✅ Opcional: Abrir el archivo después de descargar usando open_filex
      final shouldOpen = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Descarga completa'),
          content: Text('¿Quieres abrir "$fileName"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Abrir'),
            ),
          ],
        ),
      );

      if (shouldOpen == true) {
        try {
          await OpenFilex.open(filePath); // ✅ USO DE open_filex
        } catch (e) {
          print('Error al intentar abrir archivo: $e');
          _showSnackBar(
            'No se pudo abrir el archivo. Asegúrate de tener una app compatible. Path: $filePath',
            isError: true,
          );
        }
      }
    } catch (e) {
      setState(() {
        _downloadProgress.remove(fileName);
      });
      print('Error downloading file: $e');
      _showSnackBar('Error al descargar: ${e.toString()}', isError: true);
    }
  }

  // ✅ NUEVA FUNCIÓN PARA DESCARGAR TODOS LOS ARCHIVOS (AHORA SIN REQUERIR PERMISOS)
  Future<void> _downloadAllFiles() async {
    try {
      // Obtener lista de archivos
      final filesSnapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('tasks')
          .doc(widget.taskId)
          .collection('files')
          .get();

      if (filesSnapshot.docs.isEmpty) {
        _showSnackBar('No hay archivos para descargar', isError: true);
        return;
      }

      // Confirmar descarga múltiple
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Descargar todos los archivos'),
          content: Text(
            '¿Quieres descargar ${filesSnapshot.docs.length} archivo(s)?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: Text('Descargar todos'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // ✅ ELIMINADO: No se necesitan permisos de almacenamiento para guardar en la carpeta de la app.
      // if (Platform.isAndroid) {
      //   final status = await Permission.storage.request();
      //   if (!status.isGranted) {
      //     _showSnackBar('Permisos de almacenamiento requeridos', isError: true);
      //     return;
      //   }
      // }

      setState(() {
        _isDownloadingAll = true;
      });

      // Obtener directorio de documentos de la aplicación (almacenamiento privado)
      final directory = await getApplicationDocumentsDirectory();

      // Crear carpeta específica para esta tarea
      final taskFolder = Directory('${directory.path}/Tarea_${widget.taskId}');
      if (!await taskFolder.exists()) {
        await taskFolder.create(recursive: true);
      }

      final dio = Dio();
      int completedDownloads = 0;
      int totalFiles = filesSnapshot.docs.length;

      // Descargar archivos uno por uno
      for (final fileDoc in filesSnapshot.docs) {
        try {
          final fileData = fileDoc.data() as Map<String, dynamic>;
          final fileName = fileData['name'] ?? 'archivo_${fileDoc.id}';
          final fileUrl = fileData['url'] ?? '';

          if (fileUrl.isEmpty) continue;

          final filePath = '${taskFolder.path}/$fileName';

          setState(() {
            _downloadProgress[fileName] = 0.0;
          });

          await dio.download(
            fileUrl,
            filePath,
            onReceiveProgress: (received, total) {
              if (total != -1) {
                final progress = received / total;
                setState(() {
                  _downloadProgress[fileName] = progress;
                });
              }
            },
          );

          setState(() {
            _downloadProgress.remove(fileName);
          });

          completedDownloads++;
        } catch (e) {
          print('Error downloading file: $e');
          final fileName = fileDoc.data()['name'] ?? 'archivo_${fileDoc.id}';
          setState(() {
            _downloadProgress.remove(fileName);
          });
        }
      }

      setState(() {
        _isDownloadingAll = false;
      });

      if (completedDownloads > 0) {
        _showSnackBar(
          '✓ $completedDownloads de $totalFiles archivos descargados en: ${taskFolder.path}', // ✅ Mensaje actualizado
          isError: false,
        );
      } else {
        _showSnackBar('No se pudo descargar ningún archivo', isError: true);
      }
    } catch (e) {
      setState(() {
        _isDownloadingAll = false;
        _downloadProgress.clear();
      });
      print('Error downloading all files: $e');
      _showSnackBar(
        'Error al descargar archivos: ${e.toString()}',
        isError: true,
      );
    }
  }

  // ✅ FUNCIÓN PARA MOSTRAR VISTA PREVIA DE IMAGEN (USANDO open_filex para la descarga)
  void _showImagePreview(String imageUrl, String fileName) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        fileName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontFamily: fontFamilyPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      style: IconButton.styleFrom(
                        backgroundColor: theme.colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Imagen
              Flexible(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => Container(
                        height: 200,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 200,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: theme.colorScheme.error,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Error al cargar imagen',
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Botones de acción
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _downloadFile(imageUrl, fileName),
                        icon: const Icon(Icons.download),
                        label: const Text('Descargar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  } // ✅ FUNCIÓN PARA ELIMINAR ARCHIVO

  Future<void> _deleteFile(
    String fileId,
    String fileName,
    String? fileUrl,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar archivo'),
        content: Text('¿Estás seguro de que quieres eliminar "$fileName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Eliminar archivo del Storage
      if (fileUrl != null) {
        try {
          await FirebaseStorage.instance.refFromURL(fileUrl).delete();
        } catch (e) {
          print('Error deleting file from storage: $e');
        }
      }

      // Eliminar documento de Firestore
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('tasks')
          .doc(widget.taskId)
          .collection('files')
          .doc(fileId)
          .delete();

      _showSnackBar('✓ Archivo eliminado correctamente', isError: false);
    } catch (e) {
      print('Error deleting file: $e');
      _showSnackBar('Error al eliminar archivo: $e', isError: true);
    }
  }

  // ✅ FUNCIÓN PARA VERIFICAR SI HAY ARCHIVOS SUBIDOS
  Future<bool> _hasUploadedFiles() async {
    try {
      final filesSnapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('tasks')
          .doc(widget.taskId)
          .collection('files')
          .limit(1)
          .get();

      return filesSnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking files: $e');
      return false;
    }
  }

  // ✅ FUNCIÓN ACTUALIZADA PARA VALIDAR TRANSICIONES DE ESTADO CON ROLES HÍBRIDOS
  Future<bool> _canTransitionToState(
    task_utils.TaskState currentState,
    task_utils.TaskState targetState,
  ) async {
    switch (targetState) {
      case task_utils.TaskState.toDo:
        return true; // Siempre se puede volver a "Por Hacer"

      case task_utils.TaskState.doing:
        return currentState == task_utils.TaskState.toDo ||
            currentState == task_utils.TaskState.underReview;

      case task_utils.TaskState.underReview:
        return currentState ==
            task_utils.TaskState.doing; // Solo desde "En Progreso"

      case task_utils.TaskState.done:
        // ✅ ADMINS GLOBALES O PROPIETARIOS DE LA COMUNIDAD PUEDEN COMPLETAR
        if (currentState != task_utils.TaskState.underReview) return false;
        return await _canCompleteTask();
    }
  }

  // ✅ FUNCIÓN ACTUALIZADA PARA MOSTRAR DIÁLOGO DE CAMBIO DE ESTADO CON VALIDACIÓN DE ADMIN
  void _showChangeStatusDialog(task_utils.TaskState currentTaskState) async {
    final theme = Theme.of(context);
    int selectedStateIndex = task_utils.TaskState.values.indexOf(
      currentTaskState,
    );
    PageController pageController = PageController(
      initialPage: selectedStateIndex,
    );

    // Verificar si hay archivos subidos y si puede completar tareas
    final hasFiles = await _hasUploadedFiles();
    final canComplete = await _canCompleteTask();
    final isAdmin = await _isUserAdmin();
    final isOwner = await _isUserCommunityOwner();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateInsideDialog) {
            task_utils.TaskState selectedState =
                task_utils.TaskState.values[selectedStateIndex];

            // ✅ VALIDACIONES MEJORADAS CON CONTROL HÍBRIDO (ADMIN O PROPIETARIO)
            bool canApplyState = true;
            String? validationMessage;

            if (selectedState == task_utils.TaskState.underReview &&
                !hasFiles) {
              canApplyState = false;
              validationMessage =
                  'Debes subir un archivo para activar "Por Revisar"';
            } else if (selectedState == task_utils.TaskState.done) {
              if (currentTaskState != task_utils.TaskState.underReview) {
                canApplyState = false;
                validationMessage =
                    'Debes pasar por "Por Revisar" antes de completar';
              } else if (!canComplete) {
                canApplyState = false;
                validationMessage =
                    'Solo administradores o propietarios de la comunidad pueden marcar tareas como completadas';
              }
            } else {
              // Validar otras transiciones
              switch (selectedState) {
                case task_utils.TaskState.doing:
                  if (currentTaskState != task_utils.TaskState.toDo &&
                      currentTaskState != task_utils.TaskState.underReview) {
                    canApplyState = false;
                    validationMessage =
                        'Solo se puede pasar a "En Progreso" desde "Por Hacer" o "Por Revisar"';
                  }
                  break;
                case task_utils.TaskState.underReview:
                  if (currentTaskState != task_utils.TaskState.doing) {
                    canApplyState = false;
                    validationMessage =
                        'Solo se puede pasar a "Por Revisar" desde "En Progreso"';
                  }
                  break;
                default:
                  break;
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              contentPadding: const EdgeInsets.all(24),
              title: Text(
                'Cambiar Estado',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontFamily: fontFamilyPrimary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              content: SizedBox(
                width: 300,
                height: 400, // ✅ AUMENTÉ LA ALTURA PARA MÁS INFORMACIÓN
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),

                    // ✅ MOSTRAR INFORMACIÓN DEL USUARIO SI ES RELEVANTE
                    if (selectedState == task_utils.TaskState.done)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: canComplete
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: canComplete
                                ? Colors.green.withOpacity(0.3)
                                : Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              canComplete
                                  ? (isAdmin
                                        ? Icons.admin_panel_settings
                                        : Icons.star)
                                  : Icons.person,
                              color: canComplete
                                  ? (isAdmin
                                        ? Colors.green.shade700
                                        : Colors.blue.shade700)
                                  : Colors.orange.shade700,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              canComplete
                                  ? (isAdmin && isOwner
                                        ? 'Admin y Propietario'
                                        : isAdmin
                                        ? 'Administrador'
                                        : 'Propietario de Comunidad')
                                  : 'Usuario Regular',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: fontFamilyPrimary,
                                color: canComplete
                                    ? (isAdmin
                                          ? Colors.green.shade700
                                          : Colors.blue.shade700)
                                    : Colors.orange.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Carrusel de estados
                    SizedBox(
                      height: 180,
                      child: PageView.builder(
                        controller: pageController,
                        onPageChanged: (index) {
                          setStateInsideDialog(() {
                            selectedStateIndex = index;
                          });
                        },
                        itemCount: task_utils.TaskState.values.length,
                        itemBuilder: (context, index) {
                          task_utils.TaskState state =
                              task_utils.TaskState.values[index];
                          bool isSelected = index == selectedStateIndex;
                          Color stateColor = _getStateColor(state, theme);
                          IconData stateIcon = _getStateIcon(state);

                          // ✅ DETERMINAR SI EL ESTADO ESTÁ HABILITADO
                          bool isEnabled = true;
                          if (state == task_utils.TaskState.underReview &&
                              !hasFiles) {
                            isEnabled = false;
                          } else if (state == task_utils.TaskState.done &&
                              (!canComplete ||
                                  currentTaskState !=
                                      task_utils.TaskState.underReview)) {
                            isEnabled = false;
                          } else if (state == task_utils.TaskState.doing &&
                              currentTaskState != task_utils.TaskState.toDo &&
                              currentTaskState !=
                                  task_utils.TaskState.underReview) {
                            isEnabled = false;
                          } else if (state ==
                                  task_utils.TaskState.underReview &&
                              currentTaskState != task_utils.TaskState.doing) {
                            isEnabled = false;
                          }

                          return Opacity(
                            opacity: isEnabled ? 1.0 : 0.4,
                            child: Container(
                              margin: EdgeInsets.symmetric(
                                horizontal: isSelected ? 8 : 16,
                                vertical: isSelected ? 8 : 16,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    stateColor.withOpacity(
                                      isSelected ? 0.2 : 0.1,
                                    ),
                                    stateColor.withOpacity(
                                      isSelected ? 0.1 : 0.05,
                                    ),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: stateColor.withOpacity(
                                    isSelected ? 0.6 : 0.3,
                                  ),
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: stateColor.withOpacity(0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: isSelected ? 60 : 50,
                                    height: isSelected ? 60 : 50,
                                    decoration: BoxDecoration(
                                      color: stateColor,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: stateColor.withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Icon(
                                          stateIcon,
                                          color: Colors.white,
                                          size: isSelected ? 30 : 25,
                                        ),
                                        if (!isEnabled)
                                          Positioned(
                                            bottom: 2,
                                            right: 2,
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.lock,
                                                color: Colors.white,
                                                size: 12,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _getStateDisplayName(state),
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontFamily: fontFamilyPrimary,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                          color: stateColor,
                                          fontSize: isSelected ? 18 : 16,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Indicadores de página
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        task_utils.TaskState.values.length,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: selectedStateIndex == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: selectedStateIndex == index
                                ? _getStateColor(
                                    task_utils.TaskState.values[index],
                                    theme,
                                  )
                                : theme.colorScheme.outline.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ✅ MENSAJE DE VALIDACIÓN MEJORADO
                    if (validationMessage != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.error.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber,
                              color: theme.colorScheme.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                validationMessage,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontFamily: fontFamilyPrimary,
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.swipe,
                              size: 16,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.7,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Desliza para cambiar',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: fontFamilyPrimary,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.7,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancelar',
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 150,
                      child: ElevatedButton(
                        onPressed:
                            canApplyState && selectedState != currentTaskState
                            ? () {
                                _updateTaskState(
                                  task_utils
                                      .TaskState
                                      .values[selectedStateIndex],
                                );
                                Navigator.of(context).pop();
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getStateColor(selectedState, theme),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Aplicar',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ✅ FUNCIONES ACTUALIZADAS PARA LOS NUEVOS ESTADOS
  IconData _getStateIcon(task_utils.TaskState state) {
    switch (state) {
      case task_utils.TaskState.toDo:
        return Icons.radio_button_unchecked;
      case task_utils.TaskState.doing:
        return Icons.hourglass_empty;
      case task_utils.TaskState.underReview:
        return Icons.rate_review;
      case task_utils.TaskState.done:
        return Icons.check_circle;
      default:
        return Icons.circle;
    }
  }

  Color _getStateColor(task_utils.TaskState state, ThemeData theme) {
    switch (state) {
      case task_utils.TaskState.toDo:
        return Colors.grey.shade600;
      case task_utils.TaskState.doing:
        return Colors.blue.shade600;
      case task_utils.TaskState.underReview:
        return Colors.orange.shade600;
      case task_utils.TaskState.done:
        return Colors.green.shade600;
      default:
        return theme.colorScheme.primary;
    }
  }

  String _getStateDisplayName(task_utils.TaskState state) {
    switch (state) {
      case task_utils.TaskState.toDo:
        return 'Por Hacer';
      case task_utils.TaskState.doing:
        return 'En Progreso';
      case task_utils.TaskState.underReview:
        return 'Por Revisar';
      case task_utils.TaskState.done:
        return 'Completado';
      default:
        return state.name;
    }
  }

  void _updateTaskState(task_utils.TaskState newState) async {
    try {
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('tasks')
          .doc(widget.taskId)
          .update({'state': newState.name.toLowerCase()});

      if (mounted) {
        _showSnackBar(
          '✓ Estado actualizado a ${_getStateDisplayName(newState)}',
          isError: false,
        );
        setState(() {
          _taskFuture = _fetchTaskDetails();
        });
      }
    } catch (e) {
      if (mounted) {
        print('Error updating task state: $e');
        _showSnackBar('Error al actualizar: $e', isError: true);
      }
    }
  }

  // ✅ RESTO DE FUNCIONES (mantengo las existentes)
  Future<void> _fetchCommunityMembersForEdit(
    Function(void Function()) setModalState,
  ) async {
    setModalState(() {
      _fetchingEditMembers = true;
      _editCommunityMembers = [];
    });

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showSnackBar('Usuario no autenticado.', isError: true);
      setModalState(() => _fetchingEditMembers = false);
      return;
    }

    try {
      final communityDoc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .get();

      if (!communityDoc.exists) {
        _showSnackBar('Comunidad no encontrada.', isError: true);
        setModalState(() => _fetchingEditMembers = false);
        return;
      }

      final List<String> memberUids = List<String>.from(
        communityDoc.get('members') ?? [],
      );
      List<Map<String, dynamic>> membersData = [];

      if (memberUids.isNotEmpty) {
        final QuerySnapshot userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: memberUids)
            .get();

        for (var doc in userQuery.docs) {
          if (doc.exists) {
            final userData = doc.data() as Map<String, dynamic>;
            membersData.add({
              'uid': doc.id,
              'displayName':
                  userData['name'] ??
                  userData['displayName'] ??
                  'Usuario Desconocido',
              'photoURL': userData['photoURL'],
            });
          }
        }
      }

      setModalState(() {
        _editCommunityMembers = membersData;
        _fetchingEditMembers = false;

        if (_editAssignedToId != null &&
            _editCommunityMembers.any(
              (member) => member['uid'] == _editAssignedToId,
            )) {
          // Si el ID asignado ya existe en la lista, no cambiar nada
        } else if (currentUser.uid != null &&
            _editCommunityMembers.any(
              (member) => member['uid'] == currentUser.uid,
            )) {
          final currentMemberData = _editCommunityMembers.firstWhereOrNull(
            (member) => member['uid'] == currentUser.uid,
          );
          _editAssignedToId = currentMemberData?['uid'] as String?;
          _editAssignedToName = currentMemberData?['displayName'] as String?;
          _editAssignedToImageUrl = currentMemberData?['photoURL'] as String?;
        } else if (_editCommunityMembers.isNotEmpty) {
          _editAssignedToId = _editCommunityMembers.first['uid'] as String;
          _editAssignedToName =
              _editCommunityMembers.first['displayName'] as String;
          _editAssignedToImageUrl =
              _editCommunityMembers.first['photoURL'] as String?;
        } else {
          _editAssignedToId = null;
          _editAssignedToName = 'Nadie';
          _editAssignedToImageUrl = null;
        }
      });
    } catch (e) {
      _showSnackBar(
        'Error al cargar miembros de la comunidad: $e',
        isError: true,
      );
      setModalState(() => _fetchingEditMembers = false);
    }
  }

  void _showDeleteTaskDialog() {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Eliminar Tarea',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontFamily: fontFamilyPrimary,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Estás seguro de que quieres eliminar esta tarea?',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: fontFamilyPrimary,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.error.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Esta acción no se puede deshacer. Se eliminarán todos los comentarios y archivos asociados.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: fontFamilyPrimary,
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isDeletingTask
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            _deleteTask();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isDeletingTask
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Eliminar',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _deleteTask() async {
    setState(() {
      _isDeletingTask = true;
    });

    try {
      final taskRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('tasks')
          .doc(widget.taskId);

      // Eliminar archivos de Storage
      final filesSnapshot = await taskRef.collection('files').get();
      for (var fileDoc in filesSnapshot.docs) {
        try {
          final fileData = fileDoc.data();
          final url = fileData['url'] as String?;
          if (url != null) {
            await FirebaseStorage.instance.refFromURL(url).delete();
          }
        } catch (e) {
          print('Error deleting file: $e');
        }
      }

      // Eliminar comentarios y archivos en lotes
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

      if (mounted) {
        _showSnackBar('✓ Tarea eliminada correctamente', isError: false);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        print('Error deleting task: $e');
        _showSnackBar('Error al eliminar: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingTask = false;
        });
      }
    }
  }

  void _showAddCommentDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        // ✅ Usamos StatefulBuilder aquí
        builder: (BuildContext context, StateSetter setModalState) {
          bool _isSubmittingComment =
              false; // ✅ Estado de carga local del diálogo

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Agregar Comentario',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontFamily: fontFamilyPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _commentController,
                    maxLines: 4,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Escribe tu comentario aquí...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            _commentController.clear();
                            Navigator.pop(context);
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancelar',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isSubmittingComment
                              ? null // ✅ Deshabilita el botón si está cargando
                              : () async {
                                  if (_commentController.text.trim().isEmpty) {
                                    _showSnackBar(
                                      'El comentario no puede estar vacío',
                                      isError: true,
                                    );
                                    return;
                                  }

                                  setModalState(() {
                                    // ✅ Actualiza el estado local
                                    _isSubmittingComment = true;
                                  });

                                  final success =
                                      await _addComment(); // ✅ Llama a la función principal
                                  if (success && mounted) {
                                    Navigator.pop(context);
                                  } else {
                                    setModalState(() {
                                      _isSubmittingComment =
                                          false; // ✅ Vuelve a habilitar si falla
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child:
                              _isSubmittingComment // ✅ Muestra spinner local
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  'Publicar',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ✅ FUNCION: _addComment (Ahora retorna un bool e no afecta el estado global _isAddingComment)
  Future<bool> _addComment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Debes iniciar sesión para comentar', isError: true);
      return false;
    }

    try {
      final creatorDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      String senderName =
          user.displayName ?? user.email?.split('@')[0] ?? 'Anónimo';
      String? senderPhotoUrl = user.photoURL;

      if (creatorDoc.exists) {
        final creatorData = creatorDoc.data() as Map<String, dynamic>;
        senderName =
            creatorData['name'] ?? creatorData['displayName'] ?? senderName;
        senderPhotoUrl = creatorData['photoURL'] ?? senderPhotoUrl;
      }

      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('tasks')
          .doc(widget.taskId)
          .collection('comments')
          .add({
            'text': _commentController.text.trim(),
            'senderId': user.uid,
            'senderName': senderName,
            'senderImageUrl': senderPhotoUrl,
            'timestamp': FieldValue.serverTimestamp(),
          });

      _commentController.clear();

      if (mounted) {
        _showSnackBar('✓ Comentario agregado', isError: false);
      }
      return true;
    } catch (e) {
      if (mounted) {
        print('Error adding comment: $e');
        _showSnackBar('Error al agregar comentario: $e', isError: true);
      }
      return false;
    }
  }

  void _showEditTaskDialog(Map<String, dynamic> taskData) {
    _editTitleController.text = taskData['title'] ?? '';
    _editDescriptionController.text = taskData['description'] ?? '';
    _editAssignedToId = taskData['assignedToId'] as String?;
    _editAssignedToName = taskData['assignedToName'] as String?;
    _editAssignedToImageUrl = taskData['assignedToImageUrl'] as String?;
    _editPriority = _normalizePriority(taskData['priority']);
    _editDueDate = taskData['dueDate'] != null
        ? (taskData['dueDate'] as Timestamp).toDate()
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          if (_editCommunityMembers.isEmpty && _fetchingEditMembers) {
            _fetchCommunityMembersForEdit(setModalState);
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Editar Tarea',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontFamily: fontFamilyPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                            style: IconButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildEditField(
                          'Título',
                          _editTitleController,
                          'Título de la tarea',
                          icon: Icons.title,
                        ),
                        const SizedBox(height: 20),

                        _buildEditField(
                          'Descripción',
                          _editDescriptionController,
                          'Descripción de la tarea',
                          maxLines: 4,
                          icon: Icons.description,
                        ),
                        const SizedBox(height: 20),

                        Text(
                          'Asignar a',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontFamily: fontFamilyPrimary,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onBackground,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _fetchingEditMembers
                            ? Center(
                                child: CircularProgressIndicator(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              )
                            : _editCommunityMembers.isEmpty
                            ? Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline.withOpacity(0.2),
                                  ),
                                ),
                                child: Text(
                                  'No hay miembros en esta comunidad para asignar.',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        fontFamily: fontFamilyPrimary,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.7),
                                      ),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline.withOpacity(0.2),
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: _editAssignedToId,
                                    icon: Icon(
                                      Icons.arrow_drop_down,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    onChanged: (String? newValue) {
                                      setModalState(() {
                                        _editAssignedToId = newValue;
                                        final selectedMember =
                                            _editCommunityMembers
                                                .firstWhereOrNull(
                                                  (member) =>
                                                      member['uid'] == newValue,
                                                );
                                        if (selectedMember != null) {
                                          _editAssignedToName =
                                              selectedMember['displayName']
                                                  as String;
                                          _editAssignedToImageUrl =
                                              selectedMember['photoURL']
                                                  as String?;
                                        } else {
                                          _editAssignedToName = 'Nadie';
                                          _editAssignedToImageUrl = null;
                                        }
                                      });
                                    },
                                    items: _editCommunityMembers
                                        .map<DropdownMenuItem<String>>((
                                          member,
                                        ) {
                                          return DropdownMenuItem<String>(
                                            value: member['uid'] as String,
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 16,
                                                  backgroundImage:
                                                      member['photoURL'] !=
                                                              null &&
                                                          (member['photoURL']
                                                                  as String)
                                                              .isNotEmpty
                                                      ? NetworkImage(
                                                          member['photoURL']
                                                              as String,
                                                        )
                                                      : null,
                                                  child:
                                                      (member['photoURL'] ==
                                                              null ||
                                                          (member['photoURL']
                                                                  as String)
                                                              .isEmpty)
                                                      ? Icon(
                                                          Icons.person,
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onPrimary,
                                                        )
                                                      : null,
                                                  backgroundColor:
                                                      Theme.of(context)
                                                          .colorScheme
                                                          .primary
                                                          .withOpacity(0.2),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  member['displayName']
                                                      as String,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyLarge
                                                      ?.copyWith(
                                                        fontFamily:
                                                            fontFamilyPrimary,
                                                        color: Theme.of(
                                                          context,
                                                        ).colorScheme.onSurface,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          );
                                        })
                                        .toList(),
                                  ),
                                ),
                              ),
                        const SizedBox(height: 20),

                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outline.withOpacity(0.3),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  8,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.flag,
                                      size: 20,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Prioridad',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            fontFamily: fontFamilyPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  12,
                                ),
                                child: DropdownButtonFormField<String>(
                                  value: _editPriority,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  items: task_utils.TaskPriority.values
                                      .map(
                                        (priority) => DropdownMenuItem(
                                          value: priority.name,
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 12,
                                                height: 12,
                                                decoration: BoxDecoration(
                                                  color: priority.getColor(),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(priority.name),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setModalState(() {
                                      _editPriority = value ?? 'Media';
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outline.withOpacity(0.3),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _editDueDate ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (date != null) {
                                setModalState(() {
                                  _editDueDate = date;
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 20,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Fecha límite',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelLarge
                                              ?.copyWith(
                                                fontFamily: fontFamilyPrimary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _editDueDate != null
                                              ? DateFormat(
                                                  'dd MMM yyyy',
                                                ).format(_editDueDate!)
                                              : 'Seleccionar fecha',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: _editDueDate != null
                                                    ? Theme.of(
                                                        context,
                                                      ).colorScheme.onSurface
                                                    : Theme.of(context)
                                                          .colorScheme
                                                          .onSurface
                                                          .withOpacity(0.6),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_editDueDate != null)
                                    IconButton(
                                      onPressed: () {
                                        setModalState(() {
                                          _editDueDate = null;
                                        });
                                      },
                                      icon: const Icon(Icons.clear),
                                      iconSize: 20,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancelar',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isEditingTask
                              ? null
                              : () {
                                  _updateTask();
                                  Navigator.pop(context);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isEditingTask
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  'Guardar',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEditField(
    String label,
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    IconData? icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontFamily: fontFamilyPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                hintStyle: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              style: TextStyle(
                fontFamily: fontFamilyPrimary,
                fontSize: 16,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'baja':
        return task_utils.TaskPriority.low.getColor();
      case 'media':
        return task_utils.TaskPriority.medium.getColor();
      case 'alta':
        return task_utils.TaskPriority.high.getColor();
      case 'urgente':
        return task_utils.TaskPriority.urgent.getColor();
      default:
        return task_utils.TaskPriority.medium.getColor();
    }
  }

  void _updateTask() async {
    if (_editTitleController.text.trim().isEmpty) {
      _showSnackBar('El título no puede estar vacío', isError: true);
      return;
    }

    setState(() {
      _isEditingTask = true;
    });

    try {
      Map<String, dynamic> updateData = {
        'title': _editTitleController.text.trim(),
        'description': _editDescriptionController.text.trim(),
        'priority': _editPriority,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      updateData['assignedToId'] = _editAssignedToId;
      updateData['assignedToName'] = _editAssignedToName;
      updateData['assignedToImageUrl'] = _editAssignedToImageUrl;

      if (_editDueDate != null) {
        updateData['dueDate'] = Timestamp.fromDate(_editDueDate!);
      } else {
        updateData['dueDate'] = null;
      }

      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('tasks')
          .doc(widget.taskId)
          .update(updateData);

      if (mounted) {
        _showSnackBar('✓ Tarea actualizada correctamente', isError: false);
        setState(() {
          _taskFuture = _fetchTaskDetails();
        });
      }
    } catch (e) {
      if (mounted) {
        print('Error updating task: $e');
        _showSnackBar('Error al actualizar: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isEditingTask = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildDetailItem({
    required BuildContext context,
    IconData? icon,
    String? imageUrl,
    required String title,
    required String subtitle,
    Color? iconBgColor,
    Color? statusColor,
  }) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.secondary,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            )
          else if (icon != null)
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color:
                    iconBgColor ?? theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: statusColor ?? theme.colorScheme.primary,
                size: 24,
              ),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontFamily: fontFamilyPrimary,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onBackground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: fontFamilyPrimary,
                    color: theme.colorScheme.onBackground.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(BuildContext context, DocumentSnapshot commentDoc) {
    final theme = Theme.of(context);
    final data = commentDoc.data() as Map<String, dynamic>;
    final String senderName = data['senderName'] ?? 'Anónimo';
    final String commentText = data['text'] ?? '';
    final String senderImageUrl = data['senderImageUrl'] ?? '';
    final Timestamp? timestamp = data['timestamp'] as Timestamp?;

    String formattedTime = '';
    if (timestamp != null) {
      final now = DateTime.now();
      final commentDate = timestamp.toDate();
      final diff = now.difference(commentDate);

      if (diff.inDays > 0) {
        formattedTime = '${diff.inDays}d';
      } else if (diff.inHours > 0) {
        formattedTime = '${diff.inHours}h';
      } else if (diff.inMinutes > 0) {
        formattedTime = '${diff.inMinutes}m';
      } else {
        formattedTime = 'ahora';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: senderImageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: senderImageUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.secondary,
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  )
                : Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary,
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      senderName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: fontFamilyPrimary,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onBackground,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formattedTime,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: fontFamilyPrimary,
                        color: theme.colorScheme.onBackground.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  commentText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: fontFamilyPrimary,
                    color: theme.colorScheme.onBackground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NUEVO WIDGET MEJORADO PARA MOSTRAR ARCHIVOS SUBIDOS
  Widget _buildFilesSection() {
    final theme = Theme.of(context);
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('tasks')
          .doc(widget.taskId)
          .collection('files')
          .orderBy('uploadedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final files = snapshot.data!.docs;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    "Archivos Subidos",
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontFamily: fontFamilyPrimary,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onBackground,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${files.length}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // ✅ BOTÓN PARA DESCARGAR TODOS LOS ARCHIVOS
                  if (files.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: _isDownloadingAll ? null : _downloadAllFiles,
                      icon: _isDownloadingAll
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.download_for_offline, size: 16),
                      label: Text(
                        _isDownloadingAll ? 'En ello...' : 'Todo',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ✅ INDICADOR DE DESCARGA MÚLTIPLE
            if (_isDownloadingAll || _downloadProgress.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.blue.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isDownloadingAll
                                ? 'Descargando todos los archivos...'
                                : 'Descargando ${_downloadProgress.length} archivo(s)...',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontFamily: fontFamilyPrimary,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          if (_downloadProgress.isNotEmpty &&
                              !_isDownloadingAll)
                            Text(
                              _downloadProgress.entries
                                  .map(
                                    (e) =>
                                        '${e.key}: ${(e.value * 100).toInt()}%',
                                  )
                                  .join(', '),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: fontFamilyPrimary,
                                color: Colors.blue.shade600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            ...files.map((fileDoc) {
              final fileData = fileDoc.data() as Map<String, dynamic>;
              final fileName = fileData['name'] ?? 'Archivo';
              final fileUrl = fileData['url'] ?? '';
              final uploadedByName = fileData['uploadedByName'] ?? 'Usuario';
              final fileType = fileData['type'] ?? 'file';
              final timestamp = fileData['uploadedAt'] as Timestamp?;
              final currentUserId = FirebaseAuth.instance.currentUser?.uid;
              final uploadedById = fileData['uploadedBy'] ?? '';
              final fileSize = fileData['size'] as int?;

              // ✅ FORMATEAR TAMAÑO DE ARCHIVO USANDO HELPER
              String formattedSize = _formatFileSize(fileSize);

              String formattedTime = '';
              if (timestamp != null) {
                final uploadDate = timestamp.toDate();
                formattedTime = DateFormat(
                  'dd MMM yyyy HH:mm',
                ).format(uploadDate);
              }

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // ✅ ICONO CON PREVIEW PARA IMÁGENES
                        GestureDetector(
                          onTap: fileType == 'image'
                              ? () => _showImagePreview(fileUrl, fileName)
                              : null,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: fileType == 'image'
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: fileType == 'image'
                                  ? Border.all(
                                      color: Colors.green.withOpacity(0.3),
                                      width: 1,
                                    )
                                  : null,
                            ),
                            child: fileType == 'image'
                                ? Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: CachedNetworkImage(
                                          imageUrl: fileUrl,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Icon(
                                            Icons.image,
                                            color: Colors.green.shade600,
                                            size: 24,
                                          ),
                                          errorWidget: (context, url, error) =>
                                              Icon(
                                                Icons.broken_image,
                                                color: Colors.green.shade600,
                                                size: 24,
                                              ),
                                        ),
                                      ),
                                      // ✅ INDICADOR DE QUE ES CLICKEABLE
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(
                                              0.6,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.zoom_in,
                                            color: Colors.white,
                                            size: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Icon(
                                    Icons.insert_drive_file,
                                    color: Colors.blue.shade600,
                                    size: 24,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // ✅ INFORMACIÓN DEL ARCHIVO MEJORADA
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fileName,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontFamily: fontFamilyPrimary,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onBackground,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),

                              // ✅ FILA DE ETIQUETAS MEJORADA
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: fileType == 'image'
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      fileType == 'image'
                                          ? 'Imagen'
                                          : 'Documento',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontFamily: fontFamilyPrimary,
                                            color: fileType == 'image'
                                                ? Colors.green.shade700
                                                : Colors.blue.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ),
                                  if (formattedSize.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        formattedSize,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              fontFamily: fontFamilyPrimary,
                                              color: Colors.grey.shade700,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ),
                                  if (currentUserId == uploadedById)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Tuyo',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              fontFamily: fontFamilyPrimary,
                                              color: theme.colorScheme.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Subido por $uploadedByName',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontFamily: fontFamilyPrimary,
                                  color: theme.colorScheme.onBackground
                                      .withOpacity(0.7),
                                ),
                              ),
                              if (formattedTime.isNotEmpty)
                                Text(
                                  formattedTime,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontFamily: fontFamilyPrimary,
                                    color: theme.colorScheme.onBackground
                                        .withOpacity(0.5),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ✅ BOTONES DE ACCIÓN
                    Row(
                      children: [
                        // Ver/Previsualizar
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (fileType == 'image') {
                                _showImagePreview(fileUrl, fileName);
                              } else {
                                _downloadFile(fileUrl, fileName);
                              }
                            },
                            icon: Icon(
                              fileType == 'image'
                                  ? Icons.visibility
                                  : Icons.open_in_new,
                              size: 16,
                            ),
                            label: Text(
                              fileType == 'image' ? 'Ver' : 'Abrir',
                              style: const TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary
                                  .withOpacity(0.1),
                              foregroundColor: theme.colorScheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Descargar
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _downloadProgress.containsKey(fileName)
                                ? null
                                : () => _downloadFile(fileUrl, fileName),
                            icon: _downloadProgress.containsKey(fileName)
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      value: _downloadProgress[fileName],
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.green.shade700,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.download, size: 16),
                            label: Text(
                              _downloadProgress.containsKey(fileName)
                                  ? '${(_downloadProgress[fileName]! * 100).toInt()}%'
                                  : '',
                              style: const TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.withOpacity(0.1),
                              foregroundColor: Colors.green.shade700,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),

                        // ✅ SOLO MOSTRAR OPCIONES DE EDICIÓN/ELIMINACIÓN AL PROPIETARIO
                        if (currentUserId == uploadedById) ...[
                          const SizedBox(width: 8),

                          // Reemplazar
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _replaceFile(fileDoc.id, fileName),
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text(
                                '',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.withOpacity(0.1),
                                foregroundColor: Colors.orange.shade700,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Eliminar
                          Container(
                            width: 40,
                            child: ElevatedButton(
                              onPressed: () =>
                                  _deleteFile(fileDoc.id, fileName, fileUrl),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.error
                                    .withOpacity(0.1),
                                foregroundColor: theme.colorScheme.error,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              child: const Icon(Icons.delete, size: 16),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: FutureBuilder<DocumentSnapshot>(
          future: _taskFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Cargando tarea...',
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
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error al cargar la tarea',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontFamily: fontFamilyPrimary,
                        color: theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: fontFamilyPrimary,
                        color: theme.colorScheme.onBackground.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.task_outlined,
                      size: 64,
                      color: theme.colorScheme.onBackground.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tarea no encontrada',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontFamily: fontFamilyPrimary,
                        color: theme.colorScheme.onBackground.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              );
            }

            final taskData = snapshot.data!.data() as Map<String, dynamic>;
            final String taskTitle = taskData['title'] ?? 'Sin Título';
            final String taskDescription =
                taskData['description'] ?? 'Sin descripción.';

            // ✅ USAR LA FUNCIÓN MEJORADA DE MAPEO DE ESTADOS (EN LUGAR DEL firstWhere PROBLEMÁTICO)
            final task_utils.TaskState taskState = _parseTaskState(
              taskData['state'] as String?,
            );

            final String assignedToName =
                taskData['assignedToName'] ?? 'Sin asignar';
            final String? assignedToImageUrl =
                taskData['assignedToImageUrl'] as String?;
            final Timestamp? dueDateTimestamp =
                taskData['dueDate'] as Timestamp?;
            final String priority = _normalizePriority(taskData['priority']);

            String formattedDueDate = dueDateTimestamp != null
                ? DateFormat('dd MMM yyyy').format(dueDateTimestamp.toDate())
                : 'Sin fecha límite';

            return Column(
              children: <Widget>[
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                  child: Row(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: theme.colorScheme.surface.withOpacity(0.5),
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(
                            Icons.arrow_back_ios_new,
                            color: theme.colorScheme.onBackground,
                            size: 20,
                          ),
                          style: IconButton.styleFrom(
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          "Detalles de Tarea",
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontFamily: fontFamilyPrimary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color: theme.colorScheme.onBackground,
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: theme.colorScheme.surface.withOpacity(0.5),
                        ),
                        child: PopupMenuButton<String>(
                          onSelected: (String value) {
                            switch (value) {
                              case 'edit':
                                _showEditTaskDialog(taskData);
                                break;
                              case 'delete':
                                _showDeleteTaskDialog();
                                break;
                            }
                          },
                          icon: Icon(
                            Icons.more_vert,
                            color: theme.colorScheme.onBackground,
                            size: 20,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          itemBuilder: (BuildContext context) => [
                            PopupMenuItem<String>(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit_outlined,
                                    color: theme.colorScheme.primary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Editar',
                                    style: TextStyle(
                                      fontFamily: fontFamilyPrimary,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    color: theme.colorScheme.error,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Eliminar',
                                    style: TextStyle(
                                      fontFamily: fontFamilyPrimary,
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),

                        // Tarjeta principal de la tarea
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.shadow.withOpacity(
                                  0.1,
                                ),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStateColor(
                                        taskState,
                                        theme,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: _getStateColor(
                                              taskState,
                                              theme,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _getStateDisplayName(taskState),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                fontFamily: fontFamilyPrimary,
                                                color: _getStateColor(
                                                  taskState,
                                                  theme,
                                                ),
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                taskTitle,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontFamily: fontFamilyPrimary,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onBackground,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                taskDescription,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontFamily: fontFamilyPrimary,
                                  color: theme.colorScheme.onBackground
                                      .withOpacity(0.8),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Sección de detalles
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            "Detalles",
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontFamily: fontFamilyPrimary,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onBackground,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        _buildDetailItem(
                          context: context,
                          imageUrl: assignedToImageUrl,
                          title: assignedToName,
                          subtitle: "Asignado a",
                        ),
                        _buildDetailItem(
                          context: context,
                          icon: Icons.calendar_today_outlined,
                          title: formattedDueDate,
                          subtitle: "Fecha límite",
                        ),
                        _buildDetailItem(
                          context: context,
                          icon: Icons.flag_outlined,
                          title: priority,
                          subtitle: "Prioridad",
                          statusColor: _getPriorityColor(priority),
                        ),

                        // ✅ SECCIÓN DE ARCHIVOS SUBIDOS
                        TaskFilesSection(
                          communityId: widget.communityId,
                          taskId: widget.taskId,
                        ),

                        const SizedBox(height: 24),

                        // Sección de comentarios
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Comentarios",
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontFamily: fontFamilyPrimary,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onBackground,
                                ),
                              ),
                              IconButton(
                                onPressed: _showAddCommentDialog,
                                icon: Icon(
                                  Icons.add_comment_outlined,
                                  color: theme.colorScheme.primary,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary
                                      .withOpacity(0.1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('communities')
                              .doc(widget.communityId)
                              .collection('tasks')
                              .doc(widget.taskId)
                              .collection('comments')
                              .orderBy('timestamp', descending: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(
                                    'Error al cargar comentarios',
                                    style: TextStyle(
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                ),
                              );
                            }

                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                padding: const EdgeInsets.all(32),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: theme.colorScheme.outline
                                        .withOpacity(0.1),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline,
                                      size: 48,
                                      color: theme.colorScheme.onBackground
                                          .withOpacity(0.3),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Sin comentarios aún',
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            fontFamily: fontFamilyPrimary,
                                            color: theme
                                                .colorScheme
                                                .onBackground
                                                .withOpacity(0.7),
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Sé el primero en comentar',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontFamily: fontFamilyPrimary,
                                            color: theme
                                                .colorScheme
                                                .onBackground
                                                .withOpacity(0.5),
                                          ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final comments = snapshot.data!.docs;
                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: comments.length,
                              itemBuilder: (context, index) {
                                return _buildCommentItem(
                                  context,
                                  comments[index],
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(
                          height: 90,
                        ), // Espacio para los botones flotantes
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),

      // ✅ BOTONES FLOTANTES ACTUALIZADOS
      floatingActionButton: FutureBuilder<DocumentSnapshot>(
        future: _taskFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const SizedBox.shrink();
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final currentState = task_utils.TaskState.values.firstWhere(
            (e) =>
                e.name.toLowerCase() ==
                (data['state'] as String? ?? 'to_do').toLowerCase(),
            orElse: () => task_utils.TaskState.toDo,
          );

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ BOTÓN PARA SUBIR ARCHIVO (solo en estado "En Progreso")
              if (currentState == task_utils.TaskState.doing)
                FloatingActionButton.extended(
                  onPressed: _isUploadingFile ? null : _uploadFile,
                  backgroundColor: Colors.orange.shade600.withOpacity(0.9),
                  foregroundColor: Colors.white,
                  label: _isUploadingFile
                      ? const Text('Subiendo...')
                      : const Text('Subir Archivo'),
                  icon: _isUploadingFile
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.cloud_upload),
                  heroTag: "upload_file",
                ),

              if (currentState == task_utils.TaskState.doing)
                const SizedBox(height: 16),

              // ✅ BOTÓN PARA CAMBIAR ESTADO
              FloatingActionButton.extended(
                onPressed: () => _showChangeStatusDialog(currentState),
                backgroundColor: theme.colorScheme.primary.withOpacity(0.9),
                foregroundColor: theme.colorScheme.onPrimary,
                label: const Text('Cambiar Estado'),
                icon: const Icon(Icons.swap_horiz),
                heroTag: "change_status",
              ),
            ],
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

// ✅ EXTENSIÓN PARA firstWhereOrNull
extension _ListExtension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (T element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
}
