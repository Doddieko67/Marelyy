// lib/widgets/task_detail/task_files_section.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:classroom_mejorado/features/tasks/services/task_service.dart';
import 'package:classroom_mejorado/core/constants/app_typography.dart';
import 'package:classroom_mejorado/core/utils/file_utils.dart'; // Asegúrate que formatFileSize esté aquí
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart'
    as p; // Necesario para obtener la extensión del archivo

class TaskFilesSection extends StatefulWidget {
  final String communityId;
  final String taskId;

  const TaskFilesSection({
    super.key,
    required this.communityId,
    required this.taskId,
  });

  @override
  State<TaskFilesSection> createState() => _TaskFilesSectionState();
}

class _TaskFilesSectionState extends State<TaskFilesSection> {
  final TaskService _taskService = TaskService();
  final Map<String, double> _downloadProgress = {};

  // Lista de extensiones de imagen comunes
  final List<String> _imageExtensions = [
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.bmp',
    '.webp',
    '.heic',
    '.heif',
  ];

  bool _isImageFileByName(String fileName) {
    if (fileName.isEmpty) return false;
    try {
      final extension = p.extension(fileName).toLowerCase();
      return _imageExtensions.contains(extension);
    } catch (e) {
      // Si hay algún error al obtener la extensión, asumimos que no es una imagen.
      print("Error getting file extension for $fileName: $e");
      return false;
    }
  }

  void _downloadFile(String url, String fileName) {
    if (_downloadProgress.containsKey(fileName))
      return; // Evitar múltiples descargas
    setState(() {
      _downloadProgress[fileName] = 0.0;
    });

    _taskService.downloadFile(
      url: url,
      fileName: fileName,
      onProgress: (progress) {
        if (mounted) {
          setState(() {
            _downloadProgress[fileName] = progress;
          });
        }
      },
      onComplete: () {
        if (mounted) {
          setState(() {
            _downloadProgress.remove(fileName);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✓ $fileName descargado y abriendo...')),
          );
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _downloadProgress.remove(fileName);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al descargar $fileName: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  void _deleteFile(String fileId, String fileUrl) {
    // Mostrar diálogo de confirmación
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: const Text(
            '¿Estás seguro de que quieres eliminar este archivo? Esta acción no se puede deshacer.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Eliminar'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _performDelete(fileId, fileUrl);
              },
            ),
          ],
        );
      },
    );
  }

  void _performDelete(String fileId, String fileUrl) {
    _taskService
        .deleteFile(widget.communityId, widget.taskId, fileId, fileUrl)
        .then((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✓ Archivo eliminado.')),
            );
          }
        })
        .catchError((e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al eliminar: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
  }

  void _viewImage(BuildContext context, String imageUrl, String fileName) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  fileName,
                  style: Theme.of(
                    dialogContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: InteractiveViewer(
                    panEnabled: true,
                    boundaryMargin: const EdgeInsets.all(20),
                    minScale: 0.5,
                    maxScale: 4,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => Container(
                        height: 250, // O un tamaño adecuado
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 250, // O un tamaño adecuado
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.broken_image_outlined, size: 50),
                            const SizedBox(height: 8),
                            Text(
                              "No se pudo cargar la imagen",
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
          return const Padding(
            padding: EdgeInsets.all(20.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          // No mostrar nada si no hay archivos, ni siquiera el título.
          // O podrías mostrar un mensaje como "No hay archivos adjuntos."
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
                    "Archivos Adjuntos", // Cambiado de "Archivos Subidos"
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontFamily: fontFamilyPrimary,
                      fontWeight: FontWeight.w600,
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
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...files.map((doc) => _buildFileItem(context, doc)).toList(),
          ],
        );
      },
    );
  }

  Widget _buildFileItem(BuildContext context, DocumentSnapshot fileDoc) {
    final fileData = fileDoc.data() as Map<String, dynamic>;
    final theme = Theme.of(context);
    final String fileName = fileData['name'] as String? ?? 'Archivo Sin Nombre';
    final String fileUrl = fileData['url'] as String;
    final String uploadedByName =
        fileData['uploadedByName'] as String? ?? 'Usuario Desconocido';
    // final String fileTypeFromData = fileData['type'] as String? ?? 'file'; // Podríamos usarlo como fallback
    final Timestamp? timestamp = fileData['uploadedAt'] as Timestamp?;
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final String? uploadedById = fileData['uploadedBy'] as String?;
    final String formattedSize = formatFileSize(fileData['size'] as int? ?? 0);

    String formattedTime = '';
    if (timestamp != null) {
      formattedTime = DateFormat(
        'dd MMM yyyy, HH:mm',
      ).format(timestamp.toDate());
    }

    final bool isActualImage = _isImageFileByName(fileName);
    final bool isDownloading = _downloadProgress.containsKey(fileName);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icono/Preview del archivo
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isActualImage
                      ? Colors
                            .transparent // Dejar que CachedNetworkImage maneje el fondo
                      : theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isActualImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: fileUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Center(
                            child: Icon(
                              Icons.image_outlined,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          errorWidget: (context, url, error) => Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      )
                    : Icon(
                        Icons.insert_drive_file_outlined, // Icono genérico
                        color: theme.colorScheme.primary,
                        size: 30,
                      ),
              ),
              const SizedBox(width: 16),
              // Info del archivo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Subido por $uploadedByName • $formattedSize',
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (formattedTime.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          formattedTime,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color
                                ?.withOpacity(0.7),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Botones de acción
          Row(
            children: [
              // Botón de Descargar (siempre presente)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isDownloading
                      ? null // Deshabilitado mientras descarga
                      : () => _downloadFile(fileUrl, fileName),
                  icon: isDownloading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            value: _downloadProgress[fileName],
                            strokeWidth: 2,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      : Icon(Icons.download_outlined, size: 18),
                  label: Text(
                    isDownloading
                        ? '${(_downloadProgress[fileName]! * 100).toInt()}%'
                        : 'Descargar',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDownloading
                        ? theme.colorScheme.surfaceVariant
                        : theme.colorScheme.primary.withOpacity(0.1),
                    foregroundColor: theme.colorScheme.primary,
                    elevation: 0,
                    disabledBackgroundColor: theme.colorScheme.onSurface
                        .withOpacity(0.05),
                    disabledForegroundColor: theme.colorScheme.onSurface
                        .withOpacity(0.38),
                  ),
                ),
              ),
              // Botón de Previsualizar (solo para imágenes)
              if (isActualImage) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.visibility_outlined,
                    color: Colors.orange[600],
                  ),
                  tooltip: 'Previsualizar imagen',
                  onPressed: () => _viewImage(context, fileUrl, fileName),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondary.withOpacity(
                      0.1,
                    ),
                  ),
                ),
              ],
              // Botón de Eliminar (si el usuario es el que subió el archivo)
              if (currentUserId != null && currentUserId == uploadedById) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                  ),
                  tooltip: 'Eliminar archivo',
                  onPressed: () => _deleteFile(fileDoc.id, fileUrl),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.error.withOpacity(0.1),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
