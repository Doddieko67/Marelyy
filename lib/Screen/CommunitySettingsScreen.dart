// lib/screen/CommunitySettingsScreen.dart
import 'package:classroom_mejorado/services/task_service.dart';
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

import 'package:classroom_mejorado/theme/app_typography.dart';
import 'package:classroom_mejorado/services/file_upload_service.dart'; // IMPORTA TU NUEVO SERVICIO

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

  void _leaveCommunity() async {
    // ... (sin cambios en la lógica interna, pero ya usa _isLoading)
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showErrorMessage('Debes iniciar sesión.');
      return;
    }
    final communityDoc = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .get();
    if (!communityDoc.exists) {
      _showErrorMessage('Comunidad no encontrada.');
      return;
    }
    final String? ownerId = communityDoc.get('ownerId');
    final List<String> memberIds = List<String>.from(
      communityDoc.get('members') ?? [],
    );

    if (user.uid == ownerId) {
      if (memberIds.length == 1) {
        final bool? confirmDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.warning, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 8),
                Text(
                  'Salir',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            content: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.errorContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Eres el único miembro y propietario. ¿Deseas eliminarla permanentemente?',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancelar',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Sí, Eliminar'),
              ),
            ],
          ),
        );
        if (confirmDelete == true) _deleteCommunity();
      } else {
        _showAssignNewOwnerAndLeaveDialog();
      }
    } else {
      final bool? confirm = await showDialog<bool>(
        context: context,
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
            '¿Seguro que quieres abandonar esta comunidad?',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancelar',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Abandonar'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        setState(() => _isLoading = true);
        try {
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
        } catch (e) {
          _showErrorMessage('Error al abandonar: $e');
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      }
    }
  }

  // En CommunitySettingsScreen.dart

  Future<void> _deleteCommunity() async {
    final _firestore = FirebaseFirestore.instance;
    final communityId = widget.communityId;
    try {
      // 1. Obtener el documento de la comunidad
      DocumentSnapshot communityDoc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .get();

      if (!communityDoc.exists) {
        print('Comunidad $communityId no encontrada.');
        return;
      }

      // 2. Borrar la imagen de la comunidad (avatar)
      final communityData = communityDoc.data() as Map<String, dynamic>?;
      if (communityData != null && communityData.containsKey('imageUrl')) {
        String? imageUrl = communityData['imageUrl'] as String?;
        if (imageUrl != null && imageUrl.isNotEmpty) {
          print('Borrando imagen de comunidad: $imageUrl');
          bool deleted = await _fileUploadService.deleteFileFromStorageByUrl(
            imageUrl,
          );
          if (deleted) {
            print('Imagen de comunidad borrada exitosamente.');
          } else {
            print(
              'No se pudo borrar la imagen de la comunidad o ya no existía.',
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

      final taskService = TaskService();
      for (DocumentSnapshot taskDoc in tasksSnapshot.docs) {
        print('Borrando tarea ${taskDoc.id} y sus archivos...');
        await taskService.deleteTask(communityId, taskDoc.id);
        print('Tarea ${taskDoc.id} borrada.');
      }
      print('Todas las tareas de la comunidad $communityId borradas.');

      // 4. Borrar la subcolección de miembros (opcional, pero buena práctica)
      print('Borrando miembros de la comunidad $communityId...');
      QuerySnapshot membersSnapshot = await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('members') // Asumiendo que tienes esta subcolección
          .get();

      WriteBatch membersBatch = _firestore.batch();
      for (DocumentSnapshot memberDoc in membersSnapshot.docs) {
        membersBatch.delete(memberDoc.reference);
      }
      await membersBatch.commit();
      print('Miembros de la comunidad $communityId borrados.');

      // 5. Borrar el documento principal de la comunidad
      print('Borrando documento principal de la comunidad $communityId...');
      await _firestore.collection('communities').doc(communityId).delete();
      print('Comunidad $communityId borrada completamente.');
    } catch (e) {
      print('Error al borrar la comunidad $communityId: $e');
      // Podrías lanzar una excepción más específica o manejar el error como prefieras
      throw Exception('No se pudo eliminar la comunidad por completo: $e');
    }
  }

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
                  final bool isCurrentUserOwner =
                      currentUser != null && currentUser.uid == currentOwnerId;
                  final bool canTransferOwnership =
                      isCurrentUserOwner && memberIds.length > 1;

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
                      SliverAppBar(
                        pinned: true,
                        backgroundColor:
                            theme.appBarTheme.backgroundColor ??
                            theme.colorScheme.surface, // Fallback a surface
                        elevation: theme.appBarTheme.elevation ?? 0.5,
                        surfaceTintColor: Colors.transparent,
                        leading: IconButton(
                          icon: Icon(
                            Icons.arrow_back_ios_new,
                            color:
                                theme.appBarTheme.foregroundColor ??
                                theme.colorScheme.onSurface,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: 'Regresar',
                        ),
                        centerTitle: true, // Centrar título
                        title: Text(
                          widget.communityName,
                          style:
                              theme.appBarTheme.titleTextStyle ??
                              TextStyle(
                                fontFamily: fontFamilyPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 20,
                                color: theme.colorScheme.onSurface,
                              ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            // Card para Nombre
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
                            ),
                            // Card para Descripción
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
                            if (canTransferOwnership)
                              _buildSettingCard(
                                context: context,
                                icon: Icons.admin_panel_settings_outlined,
                                title: 'Transferir propiedad',
                                subtitle: 'Asignar nuevo propietario',
                                onTap: _showTransferOwnershipDialog,
                                iconColor: theme.colorScheme.tertiary,
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
                                onTap: _deleteCommunity,
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
                                  if (a == currentOwnerId) return -1;
                                  if (b == currentOwnerId) return 1;
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
                                          final bool isOwner =
                                              memberId == currentOwnerId;
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
                                                  : 'Miembro',
                                              style: TextStyle(
                                                fontFamily: fontFamilyPrimary,
                                                fontSize: 12,
                                                color: isOwner
                                                    ? theme.colorScheme.primary
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
}
