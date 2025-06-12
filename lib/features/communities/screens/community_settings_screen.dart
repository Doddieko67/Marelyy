// lib/screen/CommunitySettingsScreen.dart
import 'package:classroom_mejorado/features/tasks/services/task_service.dart';
import 'package:classroom_mejorado/core/utils/task_transfer_management.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// NO MÁS 'package:firebase_storage/firebase_storage.dart'; directamente aquí
import 'package:image_picker/image_picker.dart'; // Solo para ImageSource
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:classroom_mejorado/core/constants/app_typography.dart';
import 'package:classroom_mejorado/core/services/file_upload_service.dart'; // IMPORTA TU NUEVO SERVICIO
import 'package:classroom_mejorado/features/admin/screens/admin_management_screen.dart';
import 'package:classroom_mejorado/features/communities/models/community_model.dart';

class CommunitySettingsScreen extends StatefulWidget {
  final String communityId;
  String communityName;

  CommunitySettingsScreen({
    super.key,
    required this.communityId,
    required this.communityName,
  });

  @override
  State<CommunitySettingsScreen> createState() =>
      _CommunitySettingsScreenState();
}

class _CommunitySettingsScreenState extends State<CommunitySettingsScreen>
    with TickerProviderStateMixin {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  final Uuid _uuid = const Uuid();
  final FileUploadService _fileUploadService =
      FileUploadService(); // INSTANCIA DEL SERVICIO

  late Stream<DocumentSnapshot> _communityStream;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool _isLoading = false;
  // File? _pickedImageFile; // Ya no necesitamos manejar el File aquí directamente si el servicio lo hace
  String? _currentNetworkImageUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.communityName);
    _descriptionController = TextEditingController();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _communityStream = FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .snapshots();

    _animationController.forward();

    _communityStream.first.then((snapshot) {
      if (mounted && snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        _nameController.text = data['name'] ?? widget.communityName;
        _descriptionController.text = data['description'] ?? '';
        if (mounted) {
          setState(() {
            _currentNetworkImageUrl = data['imageUrl'] as String?;
            widget.communityName = _nameController.text;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _showSuccessMessage(String message) async {
    // ... (sin cambios)
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.onError,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.onError),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _showErrorMessage(String message) async {
    // ... (sin cambios)
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.error,
                color: Theme.of(context).colorScheme.onError,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onError,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  // MODIFICADO: Usar el servicio para seleccionar y subir
  Future<void> _handleImageSelectionAndUpload(ImageSource source) async {
    if (_isLoading) return;
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final String?
      downloadUrl = await _fileUploadService.pickAndUploadCommunityImage(
        source: source,
        communityId: widget.communityId,
        // puedes pasar imageQuality, maxWidth, maxHeight si los personalizas
      );

      if (downloadUrl != null) {
        // Guardar la nueva URL en Firestore
        await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .update({'imageUrl': downloadUrl});

        if (mounted) {
          setState(() {
            _currentNetworkImageUrl = downloadUrl;
            // _pickedImageFile = null; // El servicio maneja el archivo, no es necesario aquí
          });
        }
        _showSuccessMessage('Imagen de comunidad actualizada.');
      } else {
        // El usuario canceló o hubo un error en la selección/subida manejado por el servicio
        // _showErrorMessage('No se seleccionó ninguna imagen o hubo un error.'); // Opcional, el servicio podría mostrar su propio error
      }
    } catch (e) {
      _showErrorMessage('Error al procesar la imagen: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ELIMINADO: _pickImage y _uploadAndSaveImage (ahora en el servicio o combinados en _handleImageSelectionAndUpload)

  void _updateCommunityName() async {
    // ... (sin cambios)
    if (_nameController.text.trim().isEmpty) {
      _showErrorMessage('El nombre no puede estar vacío.');
      return;
    }
    DocumentSnapshot currentData = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .get();
    String currentFirestoreName = currentData.exists
        ? (currentData.data() as Map<String, dynamic>)['name'] ?? ''
        : '';
    if (_nameController.text.trim() == currentFirestoreName) return;

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .update({'name': _nameController.text.trim()});
      if (mounted) {
        setState(() => widget.communityName = _nameController.text.trim());
      }
      _showSuccessMessage('Nombre actualizado.');
    } catch (e) {
      _showErrorMessage('Error al actualizar nombre: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateCommunityDescription() async {
    // ... (sin cambios)
    DocumentSnapshot currentData = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .get();
    String currentFirestoreDesc = currentData.exists
        ? (currentData.data() as Map<String, dynamic>)['description'] ?? ''
        : '';
    if (_descriptionController.text.trim() == currentFirestoreDesc) return;

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .update({'description': _descriptionController.text.trim()});
      _showSuccessMessage('Descripción actualizada.');
    } catch (e) {
      _showErrorMessage('Error al actualizar descripción: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _generateJoinCode() async {
    // ... (sin cambios)
    setState(() => _isLoading = true);
    try {
      String? newCode = await _generateUniqueJoinCode();
      if (newCode == null) {
        _showErrorMessage('No se pudo generar código.');
        return;
      }
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .update({'joinCode': newCode});
      _showSuccessMessage('Nuevo código: $newCode');
    } catch (e) {
      _showErrorMessage('Error al generar código: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _generateUniqueJoinCode() async {
    // ... (sin cambios)
    const int maxAttempts = 10;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      String candidateCode = _generateRandomCode();
      bool isUnique = await _isCodeUnique(candidateCode);
      if (isUnique) return candidateCode;
    }
    return null;
  }

  String _generateRandomCode() {
    // ... (sin cambios)
    const String chars = 'ABCDEFGHIJKLMNPQRSTUVWXYZ123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    String uuidPart = _uuid
        .v4()
        .replaceAll('-', '')
        .substring(0, 3)
        .toUpperCase();
    String timePart = (random % 1000000).toString().padLeft(6, '0');
    String combined = uuidPart + timePart;
    String result = '';
    for (int i = 0; i < 6; i++) {
      int index =
          (combined.codeUnitAt(i % combined.length) + (random ~/ (i + 1)) + i) %
          chars.length;
      result += chars[index];
    }
    return result.substring(0, 6);
  }

  Future<bool> _isCodeUnique(String code) async {
    // ... (sin cambios)
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('communities')
          .where('joinCode', isEqualTo: code)
          .limit(1)
          .get();
      return querySnapshot.docs.isEmpty;
    } catch (e) {
      print('Error verificando unicidad: $e');
      return false;
    }
  }

  void _copyJoinCode(String code) {
    // ... (sin cambios)
    Clipboard.setData(ClipboardData(text: code));
    _showSuccessMessage('Código copiado.');
  }

  Future<List<DocumentSnapshot>> _getPotentialNewOwners(
    String currentOwnerId,
  ) async {
    // ... (sin cambios)
    final communityDoc = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .get();
    if (!communityDoc.exists) return [];
    final List<String> memberIds = List<String>.from(
      communityDoc.get('members') ?? [],
    );
    final List<String> potentialNewOwnerIds = memberIds
        .where((id) => id != currentOwnerId)
        .toList();
    if (potentialNewOwnerIds.isEmpty) return [];
    try {
      final QuerySnapshot userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: potentialNewOwnerIds)
          .get();
      return userQuery.docs;
    } catch (e) {
      print("Error obteniendo usuarios: $e");
      return [];
    }
  }

  Future<void> _showTransferOwnershipDialog() async {
    // ... (sin cambios en la lógica interna, pero ya usa _isLoading)
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final List<DocumentSnapshot> otherMembers = await _getPotentialNewOwners(
      currentUser.uid,
    );
    if (otherMembers.isEmpty) {
      _showErrorMessage('No hay otros miembros para transferir.');
      return;
    }
    String? selectedNewOwnerId;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Transferir',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
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
                        'Selecciona el miembro al que deseas transferir la propiedad. Seguirás siendo miembro.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...otherMembers.map((doc) {
                      final userData = doc.data() as Map<String, dynamic>;
                      final String userName =
                          userData['name'] ??
                          userData['displayName'] ??
                          'Usuario';
                      final String? userPhotoUrl = userData['photoURL'];
                      return Card(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceVariant.withOpacity(0.5),
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: RadioListTile<String>(
                          title: Text(
                            userName,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          secondary: CircleAvatar(
                            backgroundImage:
                                userPhotoUrl != null && userPhotoUrl.isNotEmpty
                                ? NetworkImage(userPhotoUrl)
                                : null,
                            child: userPhotoUrl == null || userPhotoUrl.isEmpty
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          value: doc.id,
                          groupValue: selectedNewOwnerId,
                          onChanged: (String? value) =>
                              setStateDialog(() => selectedNewOwnerId = value),
                          activeColor: Theme.of(context).colorScheme.primary,
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: selectedNewOwnerId != null
                      ? () => Navigator.of(dialogContext).pop(true)
                      : null,
                  child: const Text('Transferir'),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmed == true && selectedNewOwnerId != null) {
      setState(() => _isLoading = true);
      try {
        await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .update({'ownerId': selectedNewOwnerId});
        if (mounted) {
          final newOwnerDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(selectedNewOwnerId)
              .get();
          final newOwnerName = newOwnerDoc.exists
              ? (newOwnerDoc.data()?['name'] ??
                    newOwnerDoc.data()?['displayName'] ??
                    'Nuevo Propietario')
              : 'Nuevo Propietario';
          _showSuccessMessage('Propiedad transferida a $newOwnerName.');
        }
      } catch (e) {
        _showErrorMessage('Error al transferir: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showAssignNewOwnerAndLeaveDialog() async {
    // ... (sin cambios en la lógica interna, pero ya usa _isLoading)
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final List<DocumentSnapshot> otherMembers = await _getPotentialNewOwners(
      currentUser.uid,
    );
    if (otherMembers.isEmpty) {
      _showErrorMessage('No hay otros miembros para transferir.');
      return;
    }
    String? selectedNewOwnerId;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.exit_to_app,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Abandonar',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.errorContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Para abandonar como propietario, asigna un nuevo propietario:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...otherMembers.map((doc) {
                      final userData = doc.data() as Map<String, dynamic>;
                      final String userName =
                          userData['name'] ??
                          userData['displayName'] ??
                          'Usuario';
                      final String? userPhotoUrl = userData['photoURL'];
                      return Card(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceVariant.withOpacity(0.5),
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: RadioListTile<String>(
                          title: Text(
                            userName,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          secondary: CircleAvatar(
                            backgroundImage:
                                userPhotoUrl != null && userPhotoUrl.isNotEmpty
                                ? NetworkImage(userPhotoUrl)
                                : null,
                            child: userPhotoUrl == null || userPhotoUrl.isEmpty
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          value: doc.id,
                          groupValue: selectedNewOwnerId,
                          onChanged: (String? value) =>
                              setStateDialog(() => selectedNewOwnerId = value),
                          activeColor: Theme.of(context).colorScheme.primary,
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: selectedNewOwnerId != null
                      ? () => Navigator.of(dialogContext).pop(true)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('Asignar y Abandonar'),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmed == true && selectedNewOwnerId != null) {
      setState(() => _isLoading = true);
      try {
        final WriteBatch batch = FirebaseFirestore.instance.batch();
        final communityRef = FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId);
        batch.update(communityRef, {'ownerId': selectedNewOwnerId});
        batch.update(communityRef, {
          'members': FieldValue.arrayRemove([currentUser.uid]),
        });
        await batch.commit();
        if (mounted) {
          _showSuccessMessage('Has abandonado la comunidad.');
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        _showErrorMessage('Error al abandonar: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // void _leaveCommunity() async {
  //   final user = FirebaseAuth.instance.currentUser;
  //   if (user == null) {
  //     _showErrorMessage('Debes iniciar sesión.');
  //     return;
  //   }

  //   setState(() => _isLoading = true);

  //   try {
  //     // 🎯 GESTIONAR TAREAS ANTES DE ABANDONAR
  //     final result = await TaskTransferManager.handleUserTasksBeforeLeaving(
  //       context: context,
  //       communityId: widget.communityId,
  //       showSuccessMessage: _showSuccessMessage,
  //       showErrorMessage: _showErrorMessage,
  //     );

  //     // Si se canceló, no proceder
  //     if (result == TaskTransferResult.cancelled) {
  //       setState(() => _isLoading = false);
  //       return;
  //     }

  //     // ✅ CONTINUAR CON TU LÓGICA ORIGINAL...
  //     final communityDoc = await FirebaseFirestore.instance
  //         .collection('communities')
  //         .doc(widget.communityId)
  //         .get();

  //     final String? ownerId = communityDoc.get('ownerId');
  //     final List<String> memberIds = List<String>.from(
  //       communityDoc.get('members') ?? [],
  //     );

  //     if (user.uid == ownerId) {
  //       if (memberIds.length == 1) {
  //         final bool? confirmDelete = await showDialog<bool>(
  //           context: context,
  //           builder: (context) => AlertDialog(
  //             backgroundColor: Theme.of(context).colorScheme.surface,
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(20),
  //             ),
  //             title: Row(
  //               children: [
  //                 Icon(
  //                   Icons.warning,
  //                   color: Theme.of(context).colorScheme.error,
  //                 ),
  //                 const SizedBox(width: 8),
  //                 Text(
  //                   'Salir',
  //                   style: TextStyle(
  //                     color: Theme.of(context).colorScheme.onSurface,
  //                   ),
  //                 ),
  //               ],
  //             ),
  //             content: Container(
  //               padding: const EdgeInsets.all(12),
  //               decoration: BoxDecoration(
  //                 color: Theme.of(
  //                   context,
  //                 ).colorScheme.errorContainer.withOpacity(0.3),
  //                 borderRadius: BorderRadius.circular(10),
  //               ),
  //               child: Text(
  //                 'Eres el único miembro y propietario. ¿Deseas eliminarla permanentemente?',
  //                 style: TextStyle(
  //                   color: Theme.of(context).colorScheme.onErrorContainer,
  //                 ),
  //               ),
  //             ),
  //             actions: [
  //               TextButton(
  //                 onPressed: () => Navigator.of(context).pop(false),
  //                 child: Text(
  //                   'Cancelar',
  //                   style: TextStyle(
  //                     color: Theme.of(context).colorScheme.primary,
  //                   ),
  //                 ),
  //               ),
  //               FilledButton(
  //                 onPressed: () => Navigator.of(context).pop(true),
  //                 style: FilledButton.styleFrom(
  //                   backgroundColor: Theme.of(context).colorScheme.error,
  //                 ),
  //                 child: const Text('Sí, Eliminar'),
  //               ),
  //             ],
  //           ),
  //         );
  //         if (confirmDelete == true) _deleteCommunity();
  //       } else {
  //         _showAssignNewOwnerAndLeaveDialog();
  //       }
  //     } else {
  //       final bool? confirm = await showDialog<bool>(
  //         context: context,
  //         builder: (context) => AlertDialog(
  //           backgroundColor: Theme.of(context).colorScheme.surface,
  //           shape: RoundedRectangleBorder(
  //             borderRadius: BorderRadius.circular(20),
  //           ),
  //           title: Row(
  //             children: [
  //               Icon(
  //                 Icons.exit_to_app,
  //                 color: Theme.of(context).colorScheme.error,
  //               ),
  //               const SizedBox(width: 8),
  //               Text(
  //                 '¿Abandonar?',
  //                 style: TextStyle(
  //                   color: Theme.of(context).colorScheme.onSurface,
  //                 ),
  //               ),
  //             ],
  //           ),
  //           content: Text(
  //             '¿Seguro que quieres abandonar esta comunidad?',
  //             style: TextStyle(
  //               color: Theme.of(context).colorScheme.onSurfaceVariant,
  //             ),
  //           ),
  //           actions: [
  //             TextButton(
  //               onPressed: () => Navigator.of(context).pop(false),
  //               child: Text(
  //                 'Cancelar',
  //                 style: TextStyle(
  //                   color: Theme.of(context).colorScheme.primary,
  //                 ),
  //               ),
  //             ),
  //             FilledButton(
  //               onPressed: () => Navigator.of(context).pop(true),
  //               style: FilledButton.styleFrom(
  //                 backgroundColor: Theme.of(context).colorScheme.error,
  //               ),
  //               child: const Text('Abandonar'),
  //             ),
  //           ],
  //         ),
  //       );
  //       if (confirm == true) {
  //         setState(() => _isLoading = true);
  //         await FirebaseFirestore.instance
  //             .collection('communities')
  //             .doc(widget.communityId)
  //             .update({
  //               'members': FieldValue.arrayRemove([user.uid]),
  //             });
  //         if (mounted) {
  //           _showSuccessMessage('Has abandonado la comunidad.');
  //           Navigator.of(context).popUntil((route) => route.isFirst);
  //         }
  //       }
  //     }
  //     // ... resto de tu código original
  //   } catch (e) {
  //     _showErrorMessage('Error al abandonar: $e');
  //   } finally {
  //     if (mounted) setState(() => _isLoading = false);
  //   }
  // }

  // En CommunitySettingsScreen.dart

  Future<void> _confirmAndDeleteCommunityWrapper() async {
    // Prevenir múltiples diálogos o acciones si ya está cargando
    if (_isLoading) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // El usuario debe presionar un botón
      builder: (BuildContext dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Confirmar Eliminación',
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 16,
                  ),
                  children: <TextSpan>[
                    const TextSpan(
                      text:
                          '¿Estás absolutamente seguro de que quieres eliminar la comunidad "',
                    ),
                    TextSpan(
                      text: widget.communityName, // Muestra el nombre actual
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: '"?'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.error.withOpacity(0.5),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: theme.colorScheme.onErrorContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Esta acción es irreversible. Todos los datos, tareas y archivos asociados a esta comunidad se eliminarán permanentemente.',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Cancelar',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(false); // Usuario canceló
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              child: const Text('Sí, Eliminar Todo'),
              onPressed: () {
                Navigator.of(dialogContext).pop(true); // Usuario confirmó
              },
            ),
          ],
        );
      },
    );

    // Si el usuario no confirmó, no hacer nada
    if (confirmed != true) {
      if (mounted) {
        // Si venías de _leaveCommunity y el usuario cancela el borrado,
        // es importante resetear _isLoading si lo habías puesto en true.
        setState(() => _isLoading = false);
      }
      return;
    }

    // Si confirmó, proceder con la eliminación
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      // Llamamos a la función que contiene la lógica de borrado real.
      // Esta función ya no necesita su propio try-catch principal,
      // ya que lo manejamos aquí.
      await _deleteCommunityLogic();
      _showSuccessMessage(
        'Comunidad "${widget.communityName}" eliminada exitosamente.',
      );
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      _showErrorMessage('Error al eliminar la comunidad: ${e.toString()}');
      // El error detallado ya se imprime desde _deleteCommunityLogic o aquí
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Esta es tu función original, ahora renombrada y sin el try-catch principal.
  // Los try-catch internos para operaciones específicas (como borrar una tarea)
  // pueden permanecer si quieres que el proceso continúe a pesar de fallos menores.
  Future<void> _deleteCommunityLogic() async {
    final _firestore = FirebaseFirestore.instance;
    final communityId = widget.communityId;
    // El _fileUploadService ya es un miembro de la clase
    final taskService = TaskService();

    print(
      "--- _deleteCommunityLogic INVOCADA para comunidad: $communityId ---",
    );

    // 1. Obtener el documento de la comunidad
    DocumentSnapshot communityDoc = await _firestore
        .collection('communities')
        .doc(communityId)
        .get();

    if (!communityDoc.exists) {
      print('Comunidad $communityId no encontrada durante el borrado.');
      throw Exception(
        'La comunidad que intentas borrar ya no existe.',
      ); // Lanza para que _confirmAndDeleteCommunityWrapper maneje
    }

    // 2. Borrar la imagen de la comunidad (avatar)
    final communityData = communityDoc.data() as Map<String, dynamic>?;
    if (communityData != null && communityData.containsKey('imageUrl')) {
      String? imageUrl = communityData['imageUrl'] as String?;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        print('Borrando imagen de comunidad del storage: $imageUrl');
        try {
          bool deleted = await _fileUploadService.deleteFileFromStorageByUrl(
            imageUrl,
          );
          if (deleted) {
            print('Imagen de comunidad del storage borrada exitosamente.');
          } else {
            print(
              'No se pudo borrar la imagen de comunidad del storage o ya no existía.',
            );
          }
        } catch (e) {
          print(
            "Error borrando imagen de comunidad del storage $imageUrl: $e. Continuando...",
          );
        }
      }
    }

    // 3. Borrar todas las tareas y sus archivos asociados
    print('Borrando tareas de la comunidad $communityId...');
    QuerySnapshot tasksSnapshot = await _firestore
        .collection('communities')
        .doc(communityId)
        .collection('tasks')
        .get();

    if (tasksSnapshot.docs.isNotEmpty) {
      for (DocumentSnapshot taskDoc in tasksSnapshot.docs) {
        print(
          'Borrando tarea ${taskDoc.id} y sus archivos de la comunidad $communityId...',
        );
        try {
          await taskService.deleteTask(communityId, taskDoc.id);
          print('Tarea ${taskDoc.id} borrada exitosamente.');
        } catch (e) {
          print(
            "Error borrando tarea ${taskDoc.id} de la comunidad $communityId: $e. Continuando...",
          );
        }
      }
    } else {
      print("No hay tareas para borrar en la comunidad $communityId.");
    }
    print(
      'Proceso de borrado de tareas para la comunidad $communityId completado.',
    );

    // 4. Borrar la subcolección de miembros
    print('Borrando miembros de la comunidad $communityId...');
    QuerySnapshot membersSnapshot = await _firestore
        .collection('communities')
        .doc(communityId)
        .collection('members')
        .get();

    if (membersSnapshot.docs.isNotEmpty) {
      WriteBatch membersBatch = _firestore.batch();
      for (DocumentSnapshot memberDoc in membersSnapshot.docs) {
        membersBatch.delete(memberDoc.reference);
      }
      await membersBatch.commit();
      print('Miembros de la comunidad $communityId borrados de Firestore.');
    } else {
      print("No hay miembros para borrar en la comunidad $communityId.");
    }

    // 5. Borrar el documento principal de la comunidad
    print(
      'Borrando documento principal de la comunidad $communityId de Firestore...',
    );
    await _firestore.collection('communities').doc(communityId).delete();
    print(
      'Documento principal de la comunidad $communityId borrado de Firestore.',
    );
    print('Comunidad $communityId eliminada completamente.');
  }

  void _leaveCommunity() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showErrorMessage('Debes iniciar sesión.');
      return;
    }

    // No establezcas _isLoading aquí todavía, se hará en las funciones de diálogo
    // o en _confirmAndDeleteCommunityWrapper si se llega a esa rama.

    try {
      // 🎯 GESTIONAR TAREAS ANTES DE ABANDONAR
      // Asumimos que TaskTransferManager.handleUserTasksBeforeLeaving
      // maneja su propio estado de carga y feedback al usuario si es necesario.
      // O, si no lo hace, envuélvelo en un setState(() => _isLoading = true/false);
      // y muestra un diálogo de carga si es una operación larga.
      // Por ahora, lo dejaremos como está, asumiendo que es suficientemente rápido
      // o que maneja su propio feedback.
      final result = await TaskTransferManager.handleUserTasksBeforeLeaving(
        context: context,
        communityId: widget.communityId,
        showSuccessMessage: _showSuccessMessage,
        showErrorMessage: _showErrorMessage,
      );

      // Si se canceló la gestión de tareas, no proceder
      if (result == TaskTransferResult.cancelled) {
        // Si TaskTransferManager no reseteó _isLoading (si lo usó), hazlo aquí.
        // if (mounted) setState(() => _isLoading = false);
        return;
      }

      // ✅ CONTINUAR CON TU LÓGICA ORIGINAL...
      final communityDoc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .get();

      // Si la comunidad ya no existe (podría haber sido eliminada mientras tanto)
      if (!communityDoc.exists) {
        _showErrorMessage("La comunidad ya no existe.");
        if (mounted)
          setState(() => _isLoading = false); // Asegurar reseteo de carga
        return;
      }

      final String? ownerId = communityDoc.get('ownerId');
      final List<String> memberIds = List<String>.from(
        communityDoc.get('members') ?? [],
      );

      if (user.uid == ownerId) {
        if (memberIds.length == 1) {
          // Si es el único miembro y propietario, el flujo es eliminar la comunidad.
          // Ya no llamamos a _deleteCommunity() directamente, sino al wrapper.
          // El wrapper pondrá _isLoading = true.
          await _confirmAndDeleteCommunityWrapper();
        } else {
          // Si es propietario y hay otros miembros, mostrar diálogo para asignar nuevo propietario.
          // Esta función (_showAssignNewOwnerAndLeaveDialog) debe manejar su propio _isLoading.
          if (mounted)
            setState(
              () => _isLoading = true,
            ); // Puede ser necesario antes de mostrar diálogo
          await _showAssignNewOwnerAndLeaveDialog();
          // _showAssignNewOwnerAndLeaveDialog debería resetear _isLoading en su finally
          // o aquí deberías hacerlo si la función no lo hace.
          // if (mounted && !_isLoading) { /* No hacer nada si ya se reseteó */ }
          // else if (mounted) { setState(() => _isLoading = false); }
        }
      } else {
        // Si no es propietario, mostrar diálogo simple de confirmación para abandonar.
        final bool? confirm = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.exit_to_app,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  '¿Abandonar?',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            content: Text(
              '¿Estás seguro de que quieres abandonar la comunidad "${widget.communityName}"?',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancelar',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Sí, Abandonar'),
              ),
            ],
          ),
        );

        if (confirm == true) {
          if (mounted) setState(() => _isLoading = true);
          await FirebaseFirestore.instance
              .collection('communities')
              .doc(widget.communityId)
              .update({
                'members': FieldValue.arrayRemove([user.uid]),
              });
          if (mounted) {
            _showSuccessMessage('Has abandonado la comunidad.');
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        } else {
          // Usuario canceló el abandono, no hay que hacer nada si no se puso _isLoading
        }
      }
    } catch (e) {
      _showErrorMessage('Ocurrió un error inesperado: ${e.toString()}');
    } finally {
      // Asegurarse de que _isLoading se resetee si no se manejó en una rama específica.
      // Esto es un "catch-all" por si alguna ruta no reseteó _isLoading.
      if (mounted && _isLoading) {
        // Solo si todavía está en true
        setState(() => _isLoading = false);
      }
    }
  }

  // ... (resto de tu clase _CommunitySettingsScreenState)
  // Asegúrate de tener _showSuccessMessage, _showErrorMessage, y
  // TaskTransferManager.handleUserTasksBeforeLeaving (o su equivalente) definido.
  // También _showAssignNewOwnerAndLeaveDialog debe existir y manejar su propio estado de carga.

  Widget _buildCommunityImageSelector(ThemeData theme) {
    Widget imageToShow;
    // Ya no mostramos _pickedImageFile directamente, porque se sube al seleccionar
    // Solo mostramos _currentNetworkImageUrl
    if (_currentNetworkImageUrl != null &&
        _currentNetworkImageUrl!.isNotEmpty) {
      imageToShow = CachedNetworkImage(
        imageUrl: _currentNetworkImageUrl!,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: 120,
          height: 120,
          color: theme.colorScheme.surfaceVariant,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: 120,
          height: 120,
          color: theme.colorScheme.errorContainer,
          child: Icon(
            Icons.broken_image_outlined,
            color: theme.colorScheme.onErrorContainer,
            size: 40,
          ),
        ),
      );
    } else {
      imageToShow = Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(60),
          border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
        ),
        child: Icon(
          Icons.group_add_outlined,
          size: 50,
          color: theme.colorScheme.onSecondaryContainer,
        ),
      );
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              "Imagen de la Comunidad",
              style: theme.textTheme.titleMedium?.copyWith(
                fontFamily: fontFamilyPrimary,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(60),
              child: imageToShow,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  icon: Icon(
                    Icons.photo_library_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  label: Text(
                    "Galería",
                    style: TextStyle(color: theme.colorScheme.primary),
                  ),
                  onPressed: _isLoading
                      ? null
                      : () =>
                            _handleImageSelectionAndUpload(ImageSource.gallery),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: theme.colorScheme.primary),
                  ),
                ),
                OutlinedButton.icon(
                  icon: Icon(
                    Icons.camera_alt_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  label: Text(
                    "Cámara",
                    style: TextStyle(color: theme.colorScheme.primary),
                  ),
                  onPressed: _isLoading
                      ? null
                      : () =>
                            _handleImageSelectionAndUpload(ImageSource.camera),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: theme.colorScheme.primary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    IconData? icon,
    VoidCallback? onTap,
    Widget? trailingWidget,
    Color? iconColor,
    Color? titleColor,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDestructive
          ? theme.colorScheme.errorContainer.withOpacity(0.15)
          : theme.colorScheme.surface.withValues(alpha: 0.5),
      child: InkWell(
        onTap: _isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        (iconColor ??
                                (isDestructive
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.primary))
                            .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color:
                        iconColor ??
                        (isDestructive
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontFamily: fontFamilyPrimary,
                        fontWeight: FontWeight.w600,
                        color:
                            titleColor ??
                            (isDestructive
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurface),
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: fontFamilyPrimary,
                          color: isDestructive
                              ? theme.colorScheme.onErrorContainer.withOpacity(
                                  0.8,
                                )
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailingWidget != null) ...[
                const SizedBox(width: 8),
                trailingWidget,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    if (!_isLoading) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Positioned.fill(
      child: Container(
        color: (theme.colorScheme.scrim ?? Colors.black).withOpacity(
          0.35,
        ), // Usar scrim con fallback
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (theme.colorScheme.shadow ?? Colors.black).withOpacity(
                    0.1,
                  ),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ), // Usar shadow con fallback
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  "Procesando...",
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: StreamBuilder<DocumentSnapshot>(
                stream: _communityStream,
                builder: (context, communitySnapshot) {
                  if (communitySnapshot.connectionState ==
                          ConnectionState.waiting &&
                      _currentNetworkImageUrl == null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            strokeWidth: 3,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Cargando configuración...',
                            style: TextStyle(
                              fontFamily: fontFamilyPrimary,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  if (!communitySnapshot.hasData ||
                      !communitySnapshot.data!.exists) {
                    return Center(
                      child: Card(
                        color: theme.colorScheme.surface,
                        margin: const EdgeInsets.all(16),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: theme.colorScheme.error,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Comunidad no encontrada.',
                                style: TextStyle(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ), // onErrorContainer para texto en errorContainer
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  final communityData =
                      communitySnapshot.data!.data() as Map<String, dynamic>;
                  final String? currentOwnerId =
                      communityData['ownerId'] as String?;
                  final List<String> memberIds = List<String>.from(
                    communityData['members'] ?? [],
                  );
                  final currentUser = FirebaseAuth.instance.currentUser;
                  
                  // Verificar si el usuario actual es administrador o propietario
                  final List<String> adminIds = List<String>.from(communityData['admins'] ?? []);
                  final List<String> ownerIds = List<String>.from(communityData['owners'] ?? [currentOwnerId]);
                  final bool isCurrentUserOwner = currentUser != null && ownerIds.contains(currentUser.uid);
                  final bool isCurrentUserAdmin = currentUser != null && 
                      (isCurrentUserOwner || adminIds.contains(currentUser.uid));

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      bool REdibujar = false;
                      if (_nameController.text !=
                          (communityData['name'] ?? widget.communityName)) {
                        _nameController.text =
                            communityData['name'] ?? widget.communityName;
                        widget.communityName = _nameController.text;
                        REdibujar = true;
                      }
                      if (_descriptionController.text !=
                          (communityData['description'] ?? '')) {
                        _descriptionController.text =
                            communityData['description'] ?? '';
                        REdibujar = true;
                      }
                      final newNetworkImageUrl =
                          communityData['imageUrl'] as String?;
                      if (_currentNetworkImageUrl != newNetworkImageUrl) {
                        _currentNetworkImageUrl = newNetworkImageUrl;
                        REdibujar = true;
                      }
                      if (REdibujar && mounted) setState(() {});
                    }
                  });

                  return CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            // Card para Nombre - Solo administradores pueden editar
                            if (isCurrentUserAdmin)
                              Card(
                                elevation: 1,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 6.0,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                color: theme.colorScheme.surface,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    8,
                                  ),
                                  child: TextField(
                                    controller: _nameController,
                                    decoration: InputDecoration(
                                      labelText: 'Nombre Comunidad',
                                      hintStyle:
                                          theme.inputDecorationTheme.hintStyle,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      filled: true,
                                      fillColor:
                                          theme.inputDecorationTheme.fillColor,
                                      suffixIcon: _isLoading
                                          ? const Padding(
                                              padding: EdgeInsets.all(12.0),
                                              child: SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              ),
                                            )
                                          : IconButton(
                                              icon: Icon(
                                                Icons.save_outlined,
                                                color: theme.colorScheme.primary,
                                              ),
                                              onPressed: _updateCommunityName,
                                              tooltip: "Guardar nombre",
                                            ),
                                    ),
                                    style: TextStyle(
                                      fontFamily: fontFamilyPrimary,
                                      fontWeight: FontWeight.w500,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              )
                            else
                              // Mostrar solo lectura para miembros regulares
                              _buildSettingCard(
                                context: context,
                                icon: Icons.badge_outlined,
                                title: communityData['name'] ?? widget.communityName,
                                subtitle: 'Nombre de la comunidad',
                              ),
                            // Card para Descripción - Solo administradores pueden editar
                            if (isCurrentUserAdmin)
                              Card(
                                elevation: 1,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 6.0,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                color: theme.colorScheme.surface,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    8,
                                  ),
                                  child: TextField(
                                    controller: _descriptionController,
                                    maxLines: 3,
                                    decoration: InputDecoration(
                                      labelText: 'Descripción',
                                      hintStyle:
                                          theme.inputDecorationTheme.hintStyle,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      filled: true,
                                      fillColor:
                                          theme.inputDecorationTheme.fillColor,
                                      suffixIcon: _isLoading
                                          ? const Padding(
                                              padding: EdgeInsets.all(12.0),
                                              child: SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              ),
                                            )
                                          : IconButton(
                                              icon: Icon(
                                                Icons.save_outlined,
                                                color: theme.colorScheme.primary,
                                              ),
                                              onPressed:
                                                  _updateCommunityDescription,
                                              tooltip: "Guardar descripción",
                                            ),
                                    ),
                                    style: TextStyle(
                                      fontFamily: fontFamilyPrimary,
                                      fontWeight: FontWeight.w500,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              )
                            else
                              // Mostrar solo lectura para miembros regulares
                              _buildSettingCard(
                                context: context,
                                icon: Icons.description_outlined,
                                title: communityData['description']?.isEmpty != false 
                                    ? 'Sin descripción' 
                                    : communityData['description'],
                                subtitle: 'Descripción de la comunidad',
                              ),
                            Builder(
                              builder: (context) {
                                final Timestamp? createdAt =
                                    communityData['createdAt'] as Timestamp?;
                                final String createdByName =
                                    communityData['createdByName'] ??
                                    'Desconocido';
                                if (createdAt == null)
                                  return const SizedBox.shrink();
                                final String formattedDate = DateFormat(
                                  'dd MMM yyyy, HH:mm',
                                  Localizations.localeOf(context).toString(),
                                ).format(createdAt.toDate());
                                return _buildSettingCard(
                                  context: context,
                                  icon: Icons.history_edu_outlined,
                                  title: 'Creada por $createdByName',
                                  subtitle: formattedDate,
                                  iconColor: theme.colorScheme.secondary,
                                );
                              },
                            ),
                            // Solo administradores pueden cambiar la imagen
                            if (isCurrentUserAdmin)
                              _buildCommunityImageSelector(theme),
                            _buildSettingCard(
                              context: context,
                              icon: Icons.qr_code_scanner_outlined,
                              title:
                                  communityData['joinCode'] as String? ?? 'N/D',
                              subtitle: 'Código para unirse',
                              iconColor: theme.colorScheme.secondary,
                              trailingWidget: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.copy_all_outlined,
                                      color: theme.colorScheme.secondary,
                                    ),
                                    onPressed:
                                        communityData['joinCode'] != null &&
                                            !_isLoading
                                        ? () => _copyJoinCode(
                                            communityData['joinCode'],
                                          )
                                        : null,
                                    tooltip: "Copiar",
                                  ),
                                  // Solo administradores pueden generar nuevo código
                                  if (isCurrentUserAdmin)
                                    IconButton(
                                      icon: Icon(
                                        Icons.refresh_rounded,
                                        color: theme.colorScheme.secondary,
                                      ),
                                      onPressed: _isLoading
                                          ? null
                                          : _generateJoinCode,
                                      tooltip: "Nuevo Código",
                                    ),
                                ],
                              ),
                            ),
                            if (isCurrentUserOwner)
                              _buildSettingCard(
                                context: context,
                                icon: Icons.group_add_outlined,
                                title: 'Gestionar Propietarios',
                                subtitle: 'Compartir propiedad con otros miembros',
                                onTap: () => _navigateToOwnerManagement(context, communityData),
                                iconColor: theme.colorScheme.tertiary,
                              ),
                            if (isCurrentUserOwner)
                              _buildSettingCard(
                                context: context,
                                icon: Icons.people_outline,
                                title: 'Gestionar Administradores',
                                subtitle: 'Promover o degradar administradores',
                                onTap: () => _navigateToAdminManagement(context, communityData),
                                iconColor: theme.colorScheme.secondary,
                              ),
                            if (currentUser != null &&
                                memberIds.contains(currentUser.uid))
                              _buildSettingCard(
                                context: context,
                                icon: Icons.exit_to_app_rounded,
                                title: 'Abandonar Comunidad',
                                subtitle:
                                    isCurrentUserOwner && memberIds.length > 1
                                    ? 'Asignar nuevo propietario primero'
                                    : 'Salir de esta comunidad',
                                onTap: _leaveCommunity,
                                isDestructive: true,
                              ),
                            if (isCurrentUserOwner)
                              _buildSettingCard(
                                context: context,
                                icon: Icons.delete_sweep_outlined,
                                title: 'Eliminar Comunidad',
                                subtitle: 'Acción irreversible',
                                onTap: _confirmAndDeleteCommunityWrapper,
                                isDestructive: true,
                              ),

                            FutureBuilder<List<DocumentSnapshot>>(
                              future: memberIds.isNotEmpty
                                  ? FirebaseFirestore.instance
                                        .collection('users')
                                        .where(
                                          FieldPath.documentId,
                                          whereIn: memberIds,
                                        )
                                        .get()
                                        .then((snap) => snap.docs)
                                  : Future.value([]),
                              builder: (context, userSnapshot) {
                                if (userSnapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Card(
                                    elevation: 1,
                                    color: theme.colorScheme.surface,
                                    margin: const EdgeInsets.all(16),
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        children: [
                                          CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: theme.colorScheme.primary,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Cargando miembros...',
                                            style: TextStyle(
                                              fontFamily: fontFamilyPrimary,
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                                if (userSnapshot.hasError ||
                                    (!userSnapshot.hasData &&
                                        memberIds.isNotEmpty) ||
                                    (userSnapshot.data?.isEmpty ??
                                        true && memberIds.isNotEmpty)) {
                                  return Card(
                                    elevation: 1,
                                    margin: const EdgeInsets.all(16),
                                    color: theme.colorScheme.errorContainer
                                        .withOpacity(0.3),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.error_outline,
                                            color: theme.colorScheme.error,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Error cargando miembros.',
                                              style: TextStyle(
                                                color: theme
                                                    .colorScheme
                                                    .onErrorContainer,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                                if (memberIds.isEmpty) {
                                  return Card(
                                    elevation: 1,
                                    color: theme.colorScheme.surface,
                                    margin: const EdgeInsets.all(16),
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.people_outline,
                                            size: 40,
                                            color: theme.colorScheme.outline,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Aún no hay miembros.',
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  color:
                                                      theme.colorScheme.outline,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                                final Map<String, Map<String, dynamic>>
                                userDataMap = {
                                  for (var doc in userSnapshot.data!)
                                    if (doc.exists)
                                      doc.id:
                                          doc.data() as Map<String, dynamic>,
                                };
                                List<String> sortedMemberIds = List.from(
                                  memberIds,
                                );
                                sortedMemberIds.sort((a, b) {
                                  // Propietarios primero
                                  final aIsOwner = ownerIds.contains(a);
                                  final bIsOwner = ownerIds.contains(b);
                                  if (aIsOwner && !bIsOwner) return -1;
                                  if (!aIsOwner && bIsOwner) return 1;
                                  
                                  // Luego administradores
                                  final aIsAdmin = adminIds.contains(a);
                                  final bIsAdmin = adminIds.contains(b);
                                  if (aIsAdmin && !bIsAdmin) return -1;
                                  if (!aIsAdmin && bIsAdmin) return 1;
                                  
                                  // Finalmente por nombre
                                  final nameA =
                                      userDataMap[a]?['name']
                                          ?.toString()
                                          .toLowerCase() ??
                                      userDataMap[a]?['displayName']
                                          ?.toString()
                                          .toLowerCase() ??
                                      '';
                                  final nameB =
                                      userDataMap[b]?['name']
                                          ?.toString()
                                          .toLowerCase() ??
                                      userDataMap[b]?['displayName']
                                          ?.toString()
                                          .toLowerCase() ??
                                      '';
                                  return nameA.compareTo(nameB);
                                });
                                return Card(
                                  elevation: 1,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  color: theme.colorScheme.surface,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          16,
                                          16,
                                          8,
                                        ),
                                        child: Text(
                                          "Miembros (${sortedMemberIds.length})",
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontFamily: fontFamilyPrimary,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    theme.colorScheme.onSurface,
                                              ),
                                        ),
                                      ),
                                      ListView.separated(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: sortedMemberIds.length,
                                        separatorBuilder: (context, index) =>
                                            Divider(
                                              height: 1,
                                              indent: 72,
                                              color: theme
                                                  .colorScheme
                                                  .outlineVariant
                                                  .withOpacity(0.2),
                                            ),
                                        itemBuilder: (context, index) {
                                          final memberId =
                                              sortedMemberIds[index];
                                          final userData =
                                              userDataMap[memberId];
                                          final String userName =
                                              userData?['name'] ??
                                              userData?['displayName'] ??
                                              'Usuario';
                                          final String? userPhotoUrl =
                                              userData?['photoURL'];
                                          final bool isOwner = ownerIds.contains(memberId);
                                          final bool isAdmin = adminIds.contains(memberId);
                                          final bool isSelf =
                                              memberId == currentUser?.uid;
                                          return ListTile(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 8,
                                                ),
                                            leading: CircleAvatar(
                                              radius: 22,
                                              backgroundImage:
                                                  userPhotoUrl != null &&
                                                      userPhotoUrl.isNotEmpty
                                                  ? CachedNetworkImageProvider(
                                                      userPhotoUrl,
                                                    )
                                                  : null,
                                              backgroundColor: theme
                                                  .colorScheme
                                                  .surfaceVariant,
                                              child:
                                                  (userPhotoUrl == null ||
                                                      userPhotoUrl.isEmpty)
                                                  ? Icon(
                                                      Icons.person_outline,
                                                      color: theme
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                    )
                                                  : null,
                                            ),
                                            title: Text(
                                              '$userName ${isSelf ? "(Tú)" : ""}',
                                              style: TextStyle(
                                                fontFamily: fontFamilyPrimary,
                                                fontWeight: isOwner
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                                color:
                                                    theme.colorScheme.onSurface,
                                              ),
                                            ),
                                            subtitle: Text(
                                              isOwner
                                                  ? 'Propietario'
                                                  : isAdmin
                                                      ? 'Administrador'
                                                      : 'Miembro',
                                              style: TextStyle(
                                                fontFamily: fontFamilyPrimary,
                                                fontSize: 12,
                                                color: isOwner
                                                    ? theme.colorScheme.primary
                                                    : isAdmin
                                                        ? theme.colorScheme.secondary
                                                        : theme
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                              ),
                                            ),
                                            trailing: isOwner
                                                ? Icon(
                                                    Icons.star_rounded,
                                                    color:
                                                        Colors.amber.shade600,
                                                    size: 20,
                                                  )
                                                : isAdmin
                                                    ? Icon(
                                                        Icons.admin_panel_settings,
                                                        color: theme.colorScheme.secondary,
                                                        size: 18,
                                                      )
                                                    : null,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                          ]),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Navegar a la pantalla de gestión de administradores
  void _navigateToAdminManagement(BuildContext context, Map<String, dynamic> communityData) {
    final community = Community(
      id: widget.communityId,
      name: communityData['name'] ?? widget.communityName,
      description: communityData['description'] ?? '',
      imageUrl: communityData['imageUrl'] ?? '',
      ownerId: communityData['ownerId'] ?? '',
      createdByName: communityData['createdByName'] ?? '',
      createdAt: (communityData['createdAt'] as Timestamp?)?.toDate(),
      members: List<String>.from(communityData['members'] ?? []),
      admins: List<String>.from(communityData['admins'] ?? []),
      owners: List<String>.from(communityData['owners'] ?? [communityData['ownerId'] ?? '']),
      memberCount: (communityData['members'] as List<dynamic>?)?.length ?? 0,
      joinCode: communityData['joinCode'],
      privacy: communityData['privacy'] ?? 'public',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminManagementScreen(
          communityId: widget.communityId,
          community: community,
        ),
      ),
    );
  }

  // Navegar a la pantalla de gestión de propietarios
  void _navigateToOwnerManagement(BuildContext context, Map<String, dynamic> communityData) {
    final community = Community(
      id: widget.communityId,
      name: communityData['name'] ?? widget.communityName,
      description: communityData['description'] ?? '',
      imageUrl: communityData['imageUrl'] ?? '',
      ownerId: communityData['ownerId'] ?? '',
      createdByName: communityData['createdByName'] ?? '',
      createdAt: (communityData['createdAt'] as Timestamp?)?.toDate(),
      members: List<String>.from(communityData['members'] ?? []),
      admins: List<String>.from(communityData['admins'] ?? []),
      owners: List<String>.from(communityData['owners'] ?? [communityData['ownerId'] ?? '']),
      memberCount: (communityData['members'] as List<dynamic>?)?.length ?? 0,
      joinCode: communityData['joinCode'],
      privacy: communityData['privacy'] ?? 'public',
    );

    // TODO: Crear OwnerManagementScreen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gestión de propietarios - Próximamente'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
