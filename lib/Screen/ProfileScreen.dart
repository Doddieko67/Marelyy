// lib/screen/ProfileScreen.dart
import 'package:classroom_mejorado/Screen/AuthScreen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:classroom_mejorado/theme/app_typography.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:classroom_mejorado/services/file_upload_service.dart'; // Importa tu servicio

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FileUploadService _fileUploadService =
      FileUploadService(); // Instancia del servicio

  late TextEditingController _nameController;
  late TextEditingController _photoUrlController;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  bool _isEditingName = false;
  bool _isEditingPhoto = false;
  bool _showEmailToOthers = false;
  bool _isUploadingPhoto = false; // Para mostrar loading durante subida
  String _currentPhotoUrl = '';

  // Función para validar URL de imagen (mantenida para el modo manual)
  bool _isValidImageUrl(String url) {
    if (url.isEmpty) return false;

    final Uri? uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return false;

    if (uri.scheme != 'http' && uri.scheme != 'https') return false;

    final String lowerPath = uri.path.toLowerCase();
    return lowerPath.endsWith('.jpg') ||
        lowerPath.endsWith('.jpeg') ||
        lowerPath.endsWith('.png') ||
        lowerPath.endsWith('.gif') ||
        lowerPath.endsWith('.webp') ||
        url.contains('googleusercontent.com') ||
        url.contains('imgur.com') ||
        url.contains('unsplash.com') ||
        url.contains('com');
  }

  // ************ Nueva función para seleccionar y subir imagen ************
  Future<void> _pickAndUploadImage(ImageSource source) async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      _isUploadingPhoto = true;
    });

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedImage = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedImage == null) {
        setState(() {
          _isUploadingPhoto = false;
        });
        return; // Usuario canceló
      }

      final File imageFile = File(pickedImage.path);
      final String fileName =
          '${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Subir imagen usando el servicio
      final String? downloadUrl = await _fileUploadService.uploadFile(
        file: imageFile,
        path: 'profile_pictures', // Ruta específica para fotos de perfil
        fileName: fileName,
      );

      if (downloadUrl != null) {
        await _updateProfilePhotoWithUrl(downloadUrl);
      } else {
        throw Exception('Error al subir la imagen');
      }
    } catch (e) {
      print("Error selecting and uploading image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir la imagen: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  // ************ Función actualizada para actualizar foto con URL ************
  Future<void> _updateProfilePhotoWithUrl(String newPhotoUrl) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // 1. Actualizar la foto en Firebase Authentication
      await user.updatePhotoURL(newPhotoUrl);

      // 2. Actualizar en Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'photoURL': newPhotoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _isEditingPhoto = false;
          _currentPhotoUrl = newPhotoUrl;
          _photoUrlController.text = newPhotoUrl;
        });
        _animationController.reverse();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✓ Foto de perfil actualizada correctamente'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      print("Error updating profile photo: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar la foto: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  // ************ Función para actualizar foto manual (mantenida) ************
  Future<void> _updateProfilePhoto() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final newPhotoUrl = _photoUrlController.text.trim();
    if (newPhotoUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Por favor ingresa una URL de imagen'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      return;
    }

    if (!_isValidImageUrl(newPhotoUrl)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Por favor ingresa una URL de imagen válida'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      return;
    }

    await _updateProfilePhotoWithUrl(newPhotoUrl);
  }

  // ************ Función para restaurar foto original de Google ************
  Future<void> _restoreOriginalPhoto() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Obtener la foto original del proveedor de Google
      String? originalPhotoUrl;

      for (UserInfo userInfo in user.providerData) {
        if (userInfo.providerId == 'google.com') {
          originalPhotoUrl = userInfo.photoURL;
          break;
        }
      }

      if (originalPhotoUrl != null) {
        await _updateProfilePhotoWithUrl(originalPhotoUrl);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No se encontró foto original de Google'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      print("Error restoring original photo: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al restaurar foto: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
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

                    const SizedBox(height: 12),

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

  // ************ Función para cerrar sesión ************
  Future<void> _handleLogout() async {
    try {
      await _auth.signOut();
      await GoogleSignIn().signOut();
      print("User logged out successfully.");

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      print("Error during logout: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar sesión: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  // ************ Función para actualizar el nombre de usuario ************
  Future<void> _updateDisplayName() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('El nombre no puede estar vacío'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      return;
    }

    try {
      await user.updateDisplayName(newName);

      await _firestore.collection('users').doc(user.uid).update({
        'name': newName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _isEditingName = false;
        });
        _animationController.reverse();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✓ Nombre actualizado correctamente'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      print("Error updating display name or Firestore: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  // ************ Función para actualizar la visibilidad del email en Firestore ************
  // ************ Cargar configuración de visibilidad del email ************
  void _loadUserProfileAndSettings() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (mounted) {
        setState(() {
          String? nameFromFirestore;
          bool? showEmailFromFirestore;
          String? photoURLFromFirestore;

          if (userDoc.exists && userDoc.data() != null) {
            final data = userDoc.data()!;
            nameFromFirestore = data['name'] as String?;
            showEmailFromFirestore = data['showEmailToOthers'] as bool?;
            photoURLFromFirestore = data['photoURL'] as String?;
          }

          _nameController.text =
              nameFromFirestore ??
              user.displayName ??
              user.email?.split('@')[0] ??
              'Usuario Desconocido';

          _showEmailToOthers = showEmailFromFirestore ?? false;

          // Cargar la URL de la foto actual
          _currentPhotoUrl = photoURLFromFirestore ?? user.photoURL ?? '';
          _photoUrlController.text = _currentPhotoUrl;

          if (!userDoc.exists ||
              nameFromFirestore == null ||
              photoURLFromFirestore != user.photoURL ||
              showEmailFromFirestore == null) {
            _firestore.collection('users').doc(user.uid).set({
              'name': _nameController.text,
              'email': user.email,
              'photoURL': _currentPhotoUrl,
              'showEmailToOthers': _showEmailToOthers,
              'createdAt':
                  userDoc.exists && userDoc.data()!.containsKey('createdAt')
                  ? userDoc.get('createdAt')
                  : FieldValue.serverTimestamp(),
              'lastSignIn': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        });
      }
    } catch (e) {
      print("Error loading user profile or settings: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar la configuración del perfil: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _startEditing() {
    setState(() {
      _isEditingName = true;
    });
    _animationController.forward();
  }

  void _cancelEditing() {
    setState(() {
      _isEditingName = false;
      _loadUserProfileAndSettings();
    });
    _animationController.reverse();
  }

  void _startEditingPhoto() {
    setState(() {
      _isEditingPhoto = true;
      _photoUrlController.text = _currentPhotoUrl; // Cargar URL actual
    });
  }

  void _cancelEditingPhoto() {
    setState(() {
      _isEditingPhoto = false;
      _photoUrlController.text = _currentPhotoUrl; // Restaurar URL original
    });
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _photoUrlController = TextEditingController();
    _loadUserProfileAndSettings();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _photoUrlController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final double maxContentWidth = screenWidth > 480 ? 480 : screenWidth - 32;

    final User? user = _auth.currentUser;

    String userName = _nameController.text.isNotEmpty
        ? _nameController.text
        : (user?.displayName ?? 'Usuario Desconocido');

    String userEmail = user?.email ?? 'No disponible';

    if (userName.isEmpty && userEmail.isNotEmpty) {
      userName = userEmail.split('@')[0];
      if (userName.isEmpty) userName = 'Usuario Desconocido';
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Header mejorado
              Container(
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                child: Center(
                  child: Text(
                    "Mi Perfil",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontFamily: fontFamilyPrimary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: theme.colorScheme.onBackground,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Tarjeta de perfil mejorada
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(24),
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
                              children: [
                                // Avatar mejorado con funcionalidad de edición
                                _buildEditablePhotoSection(theme),

                                const SizedBox(height: 20),

                                // Nombre editable mejorado
                                _buildEditableNameSection(
                                  theme,
                                  userName,
                                  maxContentWidth,
                                ),

                                const SizedBox(height: 8),

                                // Email
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    userEmail,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontFamily: fontFamilyPrimary,
                                      color: Colors.purpleAccent.shade200,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              _buildSection(context, "Cuenta", [
                _buildSettingsItem(
                  context,
                  icon: Icons.lock_outline,
                  text: "Cambiar contraseña",
                  onTap: () => _handlePasswordReset(user),
                ),
                _buildSettingsItem(
                  context,
                  icon: Icons.logout_rounded,
                  text: "Cerrar sesión",
                  onTap: _handleLogout,
                  isDestructive: true,
                ),
              ]),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditablePhotoSection(ThemeData theme) {
    if (_isEditingPhoto) {
      return Column(
        children: [
          // Vista previa de la nueva imagen
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(64),
              child: _photoUrlController.text.trim().isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: _photoUrlController.text.trim(),
                      width: 128,
                      height: 128,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => _buildDefaultAvatar(theme),
                      errorWidget: (context, url, error) =>
                          _buildDefaultAvatar(theme),
                    )
                  : _buildDefaultAvatar(theme),
            ),
          ),

          const SizedBox(height: 20),

          // Campo para URL de imagen
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: TextField(
              controller: _photoUrlController,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: fontFamilyPrimary,
                color: theme.colorScheme.onBackground,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                hintText: 'https://ejemplo.com/tu-foto.jpg',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: fontFamilyPrimary,
                  color: theme.colorScheme.onBackground.withOpacity(0.5),
                ),
                prefixIcon: Icon(Icons.link, color: theme.colorScheme.primary),
              ),
              onChanged: (value) {
                setState(() {}); // Para actualizar la vista previa
              },
            ),
          ),

          const SizedBox(height: 20),

          // Botones de acción mejorados
          Column(
            children: [
              // Fila de botones principales
              Row(
                children: [
                  // Botón Cancelar
                  Expanded(
                    child: TextButton(
                      onPressed: _cancelEditingPhoto,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: theme.colorScheme.error.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                      ),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Botón Guardar
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _updateProfilePhoto,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Guardar',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Botón restaurar original (separado)
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _restoreOriginalPhoto,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: theme.colorScheme.surface,
                  ),
                  icon: Icon(
                    Icons.restore,
                    size: 18,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  label: Text(
                    'Restaurar foto original de Google',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Vista normal con foto y botón de editar mejorado
    return Column(
      children: [
        // Avatar con overlay de edición y estado de carga
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(64),
                child: _currentPhotoUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: _currentPhotoUrl,
                        width: 128,
                        height: 128,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            _buildDefaultAvatar(theme),
                        errorWidget: (context, url, error) =>
                            _buildDefaultAvatar(theme),
                      )
                    : _buildDefaultAvatar(theme),
              ),
            ),

            // Loading overlay
            if (_isUploadingPhoto)
              Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),

            // Overlay con ícono de cámara (solo si no está cargando)
            if (!_isUploadingPhoto)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.shadow.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        // Botón de cambiar foto más grande y vistoso
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isUploadingPhoto
                ? null
                : _showImageSourceDialog, // Deshabilitado durante carga
            borderRadius: BorderRadius.circular(16),
            child: Opacity(
              opacity: _isUploadingPhoto ? 0.6 : 1.0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isUploadingPhoto
                          ? Icons.hourglass_empty
                          : Icons.edit_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isUploadingPhoto
                          ? 'Subiendo foto...'
                          : 'Cambiar foto de perfil',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        fontFamily: fontFamilyPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultAvatar(ThemeData theme) {
    return Container(
      width: 128,
      height: 128,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person_rounded, size: 64, color: Colors.white),
    );
  }

  Widget _buildEditableNameSection(
    ThemeData theme,
    String userName,
    double maxWidth,
  ) {
    if (_isEditingName) {
      return Column(
        children: [
          Container(
            width: maxWidth * 0.8,
            decoration: BoxDecoration(
              color: theme.colorScheme.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: TextField(
              controller: _nameController,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontFamily: fontFamilyPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 20,
                color: theme.colorScheme.onBackground,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                hintText: 'Tu nombre',
                hintStyle: theme.textTheme.headlineSmall?.copyWith(
                  fontFamily: fontFamilyPrimary,
                  fontWeight: FontWeight.w400,
                  fontSize: 20,
                  color: theme.colorScheme.onBackground.withOpacity(0.5),
                ),
              ),
              autofocus: true,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Botón Cancelar
              Expanded(
                child: TextButton(
                  onPressed: _cancelEditing,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: theme.colorScheme.error.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Botón Guardar
              Expanded(
                child: ElevatedButton(
                  onPressed: _updateDisplayName,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Guardar',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      children: [
        Text(
          userName,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontFamily: fontFamilyPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 24,
            letterSpacing: -0.5,
            color: theme.colorScheme.onBackground,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _startEditing,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Editar nombre',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      fontFamily: fontFamilyPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> items) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontFamily: fontFamilyPrimary,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onBackground,
              ),
            ),
          ),
          Container(
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
            child: Column(children: items),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    bool isSwitch = false,
    bool switchValue = false,
    ValueChanged<bool>? onSwitchChanged,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isSwitch ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? theme.colorScheme.error.withOpacity(0.1)
                      : theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isDestructive
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontFamily: fontFamilyPrimary,
                    color: isDestructive
                        ? theme.colorScheme.error
                        : theme.colorScheme.onBackground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (isSwitch && onSwitchChanged != null)
                Switch.adaptive(
                  value: switchValue,
                  onChanged: onSwitchChanged,
                  activeColor: theme.colorScheme.primary,
                )
              else if (!isSwitch)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: theme.colorScheme.onBackground.withOpacity(0.5),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handlePasswordReset(User? user) {
    if (user != null && user.email != null) {
      FirebaseAuth.instance
          .sendPasswordResetEmail(email: user.email!)
          .then((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('✓ Enlace enviado a tu correo'),
                  backgroundColor: Colors.green.shade600,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }
          })
          .catchError((error) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: ${error.message}'),
                  backgroundColor: Theme.of(context).colorScheme.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }
          });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No se puede cambiar la contraseña'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }
}
