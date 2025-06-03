// lib/Screen/CreateCommunityScreen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:classroom_mejorado/theme/app_typography.dart';

// CommunityPrivacy enum and its extension are removed as per request.

class CreateCommunityScreen extends StatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _customImageUrlController = TextEditingController();

  // _selectedPrivacy is removed as per request.
  bool _isLoading = false;
  bool _useCustomUrl = false; // Nueva variable para alternar entre opciones

  // Lista de avatares predefinidos para las comunidades
  final List<String> _communityAvatars = [
    'https://lh3.googleusercontent.com/aida-public/AB6AXuBpVSBqjPGyXCSt3yWiVBFbpLaxQdaTyDd9bx-yqMX52P2JnirC2AP_ZS_exB3O_aBgc5lf7XWfyXrimUHcH03V6LYKbqsRGpjdH2pNJirc_QP0yZvfgqrhv8foadJ_C2vk8lDcZ4uimqukqSf2prP3m4r97jc9KsMPez6DYIFCnw5IXpp0gdUsgoJlOcLF1s2y0W_9-MEzf6FmG4mmx27tt6z0dKoT7zP24mSRkAxWLmjhiPKO2nbpD4wOaIGqixvsWO48q3M',
    'https://lh3.googleusercontent.com/aida-public/AB6AXuChfRjiApW79uRw-wUlwr12aE3K5ecrJ72jaEAMQdfyxfWUWgp_8SS3bNjX5kvUnMxRplQlAod6pK-m8IBedFstIrDPDOBfq3eIdrWoyEHC-Ca2FW_Xtgy7TphnRkSttS8bTqyrLL3CI1awHaWBULRUty_zxpYh6U9YlmGxFpW20X_TRWEHv_YsxYyyTx8r0LQh56zbCXc9MClQ-y5nw6cmfeZjPEWhlHda8RBe3QDpsrrBn2DyG8fU4bvrtewRi6Ge_yAewsU',
    'https://lh3.googleusercontent.com/aida-public/AB6AXuBFXD8Jqn5TltNCXcqaqregwKKFZqwK2qw0r4izTjWvSzNkcZD2bK34P94WhOKndD8bPDWBYgtVF-nGy9YORfCWBHR1y9B9FUBngOD3QLK1ynpEo8Dp3dqdpgUc0miRJCdYO2R_ARRloyTf82jgzoFFW2GqDDicl4_KwuzexSiT1B1euTdNiMy6m10IzIDPpZFGOjdBdBNEnEs1psujabaN-sJ3h0K-gp-2Keuu5tThGZR3zdb-HBvA_su0KtXDr9n6on-Qctc',
  ];

  int _selectedAvatarIndex = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _customImageUrlController.dispose();
    super.dispose();
  }

  // Función para validar URL de imagen
  bool _isValidImageUrl(String url) {
    if (url.isEmpty) return false;

    // Verificar que sea una URL válida
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return false;

    // Verificar que use http o https
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;

    // Verificar que tenga una extensión de imagen común
    final String lowerPath = uri.path.toLowerCase();
    return lowerPath.endsWith('.jpg') ||
        lowerPath.endsWith('.jpeg') ||
        lowerPath.endsWith('.png') ||
        lowerPath.endsWith('.gif') ||
        lowerPath.endsWith('.webp') ||
        url.contains('googleusercontent.com') || // Para las URLs de ejemplo
        url.contains('imgur.com') ||
        url.contains('unsplash.com') ||
        url.contains('pixabay.com');
  }

  // Obtener la URL de imagen final
  String _getFinalImageUrl() {
    if (_useCustomUrl && _customImageUrlController.text.trim().isNotEmpty) {
      return _customImageUrlController.text.trim();
    }
    return _communityAvatars[_selectedAvatarIndex];
  }

  Future<void> _createCommunity() async {
    if (!_formKey.currentState!.validate()) return;

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
      await FirebaseFirestore.instance.collection('communities').doc(communityId).set({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'imageUrl':
            _getFinalImageUrl(), // Usar la URL final (predefinida o personalizada)
        // 'privacy' field is removed as per request.
        'ownerId': user.uid,
        'createdByName': user.displayName ?? 'Usuario', // Nombre del creador
        'createdAt': FieldValue.serverTimestamp(),
        'memberCount': 1, // Inicialmente solo el creador
        'members': [user.uid], // El creador es automáticamente miembro
        // 'joinCode': null, // Opcional: generar un código de unión aquí si es privada
      });

      // Agregar al usuario como administrador en la subcolección de miembros
      // (Esto es opcional si ya manejas roles basado en 'ownerId')
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .doc(user.uid)
          .set({
            'userId': user.uid,
            'name': user.displayName ?? 'Usuario',
            'email': user.email,
            'role': 'admin', // El creador es administrador
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
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green[600]),
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
            onPressed: _isLoading ? null : _createCommunity,
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

              // Toggle entre opciones predefinidas y URL personalizada
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _useCustomUrl = false;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_useCustomUrl
                                ? theme.colorScheme.primary
                                : Colors.transparent,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Predefinidas',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: fontFamilyPrimary,
                              fontWeight: FontWeight.w600,
                              color: !_useCustomUrl
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurface.withOpacity(
                                      0.7,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _useCustomUrl = true;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _useCustomUrl
                                ? theme.colorScheme.primary
                                : Colors.transparent,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                          ),
                          child: Text(
                            'URL personalizada',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: fontFamilyPrimary,
                              fontWeight: FontWeight.w600,
                              color: _useCustomUrl
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurface.withOpacity(
                                      0.7,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Mostrar opciones predefinidas o campo URL según la selección
              if (!_useCustomUrl) ...[
                // Selector de avatares predefinidos
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(16),
                    itemCount: _communityAvatars.length,
                    itemBuilder: (context, index) {
                      final isSelected = _selectedAvatarIndex == index;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedAvatarIndex = index;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              _communityAvatars[index],
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 80,
                                  height: 80,
                                  color: theme.colorScheme.outline.withOpacity(
                                    0.2,
                                  ),
                                  child: Icon(
                                    Icons.group,
                                    color: theme.colorScheme.primary,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ] else ...[
                // Campo para URL personalizada
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: TextFormField(
                    controller: _customImageUrlController,
                    style: TextStyle(
                      fontFamily: fontFamilyPrimary,
                      fontSize: 16,
                      color: theme.colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      labelText: 'URL de la imagen',
                      labelStyle: TextStyle(
                        fontFamily: fontFamilyPrimary,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                      hintText: 'https://ejemplo.com/imagen.jpg',
                      hintStyle: TextStyle(
                        fontFamily: fontFamilyPrimary,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                      prefixIcon: Icon(
                        Icons.link,
                        color: theme.colorScheme.primary,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(20),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor ingresa una URL de imagen';
                      }
                      if (!_isValidImageUrl(value.trim())) {
                        return 'Por favor ingresa una URL de imagen válida';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      setState(() {}); // Para actualizar la vista previa
                    },
                  ),
                ),

                // Vista previa de la imagen personalizada
                if (_customImageUrlController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vista previa:',
                          style: TextStyle(
                            fontFamily: fontFamilyPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              _customImageUrlController.text.trim(),
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.error.withOpacity(
                                      0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: theme.colorScheme.error
                                          .withOpacity(0.3),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: theme.colorScheme.error,
                                        size: 24,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Error al cargar',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: theme.colorScheme.error,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                );
                              },
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surface,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    );
                                  },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 24),

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
                  onPressed: _isLoading ? null : _createCommunity,
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
