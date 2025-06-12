// lib/Screen/CreateCommunityScreen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:classroom_mejorado/core/constants/app_typography.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:classroom_mejorado/core/services/file_upload_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CreateCommunityScreen extends StatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final FileUploadService _fileUploadService = FileUploadService();

  bool _isLoading = false;
  bool _isUploadingImage = false;
  String? _selectedImageUrl; // URL de la imagen seleccionada

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ************ Función para seleccionar y subir imagen ************
  Future<void> _pickAndUploadImage(ImageSource source) async {
    setState(() {
      _isUploadingImage = true;
    });

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedImage = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedImage == null) {
        setState(() {
          _isUploadingImage = false;
        });
        return; // Usuario canceló
      }

      final File imageFile = File(pickedImage.path);

      // Generar nombre único para la imagen
      final String fileName =
          'community_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Subir imagen usando el servicio
      final String? downloadUrl = await _fileUploadService.uploadFile(
        file: imageFile,
        path:
            'community_avatars', // Ruta específica para avatares de comunidades
        fileName: fileName,
      );

      if (downloadUrl != null) {
        setState(() {
          _selectedImageUrl = downloadUrl;
        });

        _showSuccess('✓ Imagen subida correctamente');
      } else {
        throw Exception('Error al subir la imagen');
      }
    } catch (e) {
      print("Error selecting and uploading image: $e");
      _showError('Error al subir la imagen: ${e.toString()}');
    } finally {
      setState(() {
        _isUploadingImage = false;
      });
    }
  }

  // ************ Diálogo para seleccionar fuente de imagen ************
  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Seleccionar imagen',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Botón Cámara
                    _buildImageSourceOption(
                      context,
                      icon: Icons.camera_alt_rounded,
                      title: 'Tomar foto',
                      subtitle: 'Usar la cámara',
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndUploadImage(ImageSource.camera);
                      },
                    ),

                    const SizedBox(height: 12),

                    // Botón Galería
                    _buildImageSourceOption(
                      context,
                      icon: Icons.photo_library_rounded,
                      title: 'Seleccionar de galería',
                      subtitle: 'Elegir una foto existente',
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndUploadImage(ImageSource.gallery);
                      },
                    ),

                    const SizedBox(height: 20),

                    // Botón Cancelar
                    SizedBox(
                      width: double.infinity,
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
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                            fontWeight: FontWeight.w600,
                          ),
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
    );
  }

  Widget _buildImageSourceOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: theme.colorScheme.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ************ Widget para mostrar la imagen seleccionada ************
  Widget _buildImageSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Imagen de la comunidad',
          style: TextStyle(
            fontFamily: fontFamilyPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onBackground,
          ),
        ),
        const SizedBox(height: 12),

        // Contenedor de imagen
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: _selectedImageUrl != null
              ? _buildSelectedImage(theme)
              : _buildImagePlaceholder(theme),
        ),

        const SizedBox(height: 12),

        // Botón para cambiar imagen
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isUploadingImage ? null : _showImageSourceDialog,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(
                color: theme.colorScheme.primary.withOpacity(0.5),
              ),
            ),
            icon: Icon(
              _isUploadingImage
                  ? Icons.hourglass_empty
                  : (_selectedImageUrl != null
                        ? Icons.edit
                        : Icons.add_photo_alternate),
              color: theme.colorScheme.primary,
            ),
            label: Text(
              _isUploadingImage
                  ? 'Subiendo imagen...'
                  : (_selectedImageUrl != null
                        ? 'Cambiar imagen'
                        : 'Seleccionar imagen'),
              style: TextStyle(
                fontFamily: fontFamilyPrimary,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),

        if (_selectedImageUrl == null) ...[
          const SizedBox(height: 8),
          Text(
            'Selecciona una imagen para tu comunidad desde tu galería o cámara',
            style: TextStyle(
              fontFamily: fontFamilyPrimary,
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  // Widget para mostrar la imagen seleccionada
  Widget _buildSelectedImage(ThemeData theme) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CachedNetworkImage(
            imageUrl: _selectedImageUrl!,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: theme.colorScheme.surface,
              child: Center(
                child: CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: theme.colorScheme.error.withOpacity(0.1),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.error,
                    size: 48,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Error al cargar imagen',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Loading overlay
        if (_isUploadingImage)
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 12),
                  Text(
                    'Subiendo imagen...',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // Widget placeholder cuando no hay imagen
  Widget _buildImagePlaceholder(ThemeData theme) {
    if (_isUploadingImage) {
      return Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Subiendo imagen...',
              style: TextStyle(
                fontFamily: fontFamilyPrimary,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.add_photo_alternate_outlined,
            size: 40,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Ninguna imagen seleccionada',
          style: TextStyle(
            fontFamily: fontFamilyPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Toca el botón de abajo para seleccionar',
          style: TextStyle(
            fontFamily: fontFamilyPrimary,
            fontSize: 14,
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Future<void> _createCommunity() async {
    if (!_formKey.currentState!.validate()) return;

    // Validar que se haya seleccionado una imagen
    if (_selectedImageUrl == null) {
      _showError('Por favor selecciona una imagen para la comunidad');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('Debes estar autenticado para crear comunidades');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Generar ID único para la comunidad
      final communityId =
          _nameController.text
              .trim()
              .toLowerCase()
              .replaceAll(
                RegExp(r'[^a-z0-9]'),
                '_',
              ) // Reemplaza no alfanuméricos con _
              .replaceAll(
                RegExp(r'_+'),
                '_',
              ) + // Colapsa múltiples _ a uno solo
          '_${DateTime.now().millisecondsSinceEpoch}'; // Añade timestamp para unicidad

      // Crear la comunidad en Firestore
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .set({
            'name': _nameController.text.trim(),
            'description': _descriptionController.text.trim(),
            'imageUrl': _selectedImageUrl!, // Usar la imagen subida
            'ownerId': user.uid, // Mantener por compatibilidad
            'createdByName':
                user.displayName ?? 'Usuario', // Nombre del creador
            'createdAt': FieldValue.serverTimestamp(),
            'memberCount': 1, // Inicialmente solo el creador
            'members': [user.uid], // El creador es automáticamente miembro
            'admins': [], // Lista de administradores vacía inicialmente
            'owners': [user.uid], // El creador es el primer propietario
          });

      // Agregar al usuario como propietario en la subcolección de miembros
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .doc(user.uid)
          .set({
            'userId': user.uid,
            'name': user.displayName ?? 'Usuario',
            'email': user.email,
            'role': 'owner', // El creador es propietario
            'joinedAt': FieldValue.serverTimestamp(),
          });

      _showSuccess('¡Comunidad creada exitosamente!');
      Navigator.of(context).pop();
    } catch (e) {
      _showError('Error al crear la comunidad: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Crear Comunidad',
          style: TextStyle(
            fontFamily: fontFamilyPrimary,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onBackground,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: theme.colorScheme.onBackground,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton.icon(
            onPressed: (_isLoading || _isUploadingImage)
                ? null
                : _createCommunity,
            icon: _isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : Icon(Icons.check, color: theme.colorScheme.primary),
            label: Text(
              _isLoading ? 'Creando...' : 'Crear',
              style: TextStyle(
                fontFamily: fontFamilyPrimary,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selector de imagen
              _buildImageSelector(theme),

              const SizedBox(height: 32),

              // Nombre de la comunidad
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: TextFormField(
                  controller: _nameController,
                  style: TextStyle(
                    fontFamily: fontFamilyPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Nombre de la comunidad',
                    labelStyle: TextStyle(
                      fontFamily: fontFamilyPrimary,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                    hintText:
                        'ej. Entusiastas de la Tecnología, Club de Lectura...',
                    hintStyle: TextStyle(
                      fontFamily: fontFamilyPrimary,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                    prefixIcon: Icon(
                      Icons.group,
                      color: theme.colorScheme.primary,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(20),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El nombre es obligatorio';
                    }
                    if (value.trim().length < 3) {
                      return 'El nombre debe tener al menos 3 caracteres';
                    }
                    if (value.trim().length > 50) {
                      return 'El nombre no puede exceder 50 caracteres';
                    }
                    return null;
                  },
                  maxLength: 50,
                ),
              ),

              const SizedBox(height: 24),

              // Descripción de la comunidad
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: TextFormField(
                  controller: _descriptionController,
                  style: TextStyle(
                    fontFamily: fontFamilyPrimary,
                    fontSize: 16,
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Descripción (opcional)',
                    labelStyle: TextStyle(
                      fontFamily: fontFamilyPrimary,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                    hintText: 'Describe de qué trata tu comunidad...',
                    hintStyle: TextStyle(
                      fontFamily: fontFamilyPrimary,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                    prefixIcon: Icon(
                      Icons.description,
                      color: theme.colorScheme.primary,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(20),
                  ),
                  maxLines: 3,
                  maxLength: 200,
                ),
              ),

              const SizedBox(height: 32),

              // Botón de crear
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: (_isLoading || _isUploadingImage)
                      ? null
                      : _createCommunity,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    disabledBackgroundColor: theme.colorScheme.outline
                        .withOpacity(0.3),
                  ),
                  child: _isLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Creando comunidad...',
                              style: TextStyle(
                                fontFamily: fontFamilyPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.group_add, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Crear Comunidad',
                              style: TextStyle(
                                fontFamily: fontFamilyPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
