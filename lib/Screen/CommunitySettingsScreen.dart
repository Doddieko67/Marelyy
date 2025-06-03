// lib/screen/CommunitySettingsScreen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para Clipboard
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart'; // Para generar IDs únicos (opcional, puedes usar otra lógica)
import 'package:intl/intl.dart'; // Para formatear fechas

import 'package:classroom_mejorado/theme/app_typography.dart';

class CommunitySettingsScreen extends StatefulWidget {
  final String communityId;
  final String communityName; // Para mostrar en el título

  const CommunitySettingsScreen({
    super.key,
    required this.communityId,
    required this.communityName,
  });

  @override
  State<CommunitySettingsScreen> createState() =>
      _CommunitySettingsScreenState();
}

class _CommunitySettingsScreenState extends State<CommunitySettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _customImageUrlController;
  final Uuid _uuid = const Uuid(); // Para generar códigos

  // Stream para escuchar los cambios en los datos de la comunidad en tiempo real
  late Stream<DocumentSnapshot> _communityStream;

  // Variables para el manejo de imagen
  bool _useCustomUrl = false;
  int _selectedAvatarIndex = 0;
  bool _isImageExpanded = false;

  // Lista de avatares predefinidos (misma que en CreateCommunityScreen)
  final List<String> _communityAvatars = [
    'https://lh3.googleusercontent.com/aida-public/AB6AXuBpVSBqjPGyXCSt3yWiVBFbpLaxQdaTyDd9bx-yqMX52P2JnirC2AP_ZS_exB3O_aBgc5lf7XWfyXrimUHcH03V6LYKbqsRGpjdH2pNJirc_QP0yZvfgqrhv8foadJ_C2vk8lDcZ4uimqukqSf2prP3m4r97jc9KsMPez6DYIFCnw5IXpp0gdUsgoJlOcLF1s2y0W_9-MEzf6FmG4mmx27tt6z0dKoT7zP24mSRkAxWLmjhiPKO2nbpD4wOaIGqixvsWO48q3M',
    'https://lh3.googleusercontent.com/aida-public/AB6AXuChfRjiApW79uRw-wUlwr12aE3K5ecrJ72jaEAMQdfyxfWUWgp_8SS3bNjX5kvUnMxRplQlAod6pK-m8IBedFstIrDPDOBfq3eIdrWoyEHC-Ca2FW_Xtgy7TphnRkSttS8bTqyrLL3CI1awHaWBULRUty_zxpYh6U9YlmGxFpW20X_TRWEHv_YsxYyyTx8r0LQh56zbCXc9MClQ-y5nw6cmfeZjPEWhlHda8RBe3QDpsrrBn2DyG8fU4bvrtewRi6Ge_yAewsU',
    'https://lh3.googleusercontent.com/aida-public/AB6AXuBFXD8Jqn5TltNCXcqaqregwKKFZqwK2qw0r4izTjWvSzNkcZD2bK34P94WhOKndD8bPDWBYgtVF-nGy9YORfCWBHR1y9B9FUBngOD3QLK1ynpEo8Dp3dqdpgUc0miRJCdYO2R_ARRloyTf82jgzoFFW2GqDDicl4_KwuzexSiT1B1euTdNiMy6m10IzIDPpZFGOjdBdBNEnEs1psujabaN-sJ3h0K-gp-2Keuu5tThGZR3zdb-HBvA_su0KtXDr9n6on-Qctc',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _customImageUrlController = TextEditingController();
    _communityStream = FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .snapshots();

    // Precargar los datos actuales cuando el stream cargue por primera vez
    _communityStream.first.then((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        _nameController.text = data['name'] ?? '';
        _descriptionController.text = data['description'] ?? '';

        // Configurar la imagen actual
        final currentImageUrl = data['imageUrl'] ?? '';
        if (currentImageUrl.isNotEmpty) {
          final predefinedIndex = _communityAvatars.indexOf(currentImageUrl);
          if (predefinedIndex != -1) {
            // Es una imagen predefinida
            setState(() {
              _selectedAvatarIndex = predefinedIndex;
              _useCustomUrl = false;
            });
          } else {
            // Es una URL personalizada
            setState(() {
              _useCustomUrl = true;
              _customImageUrlController.text = currentImageUrl;
            });
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _customImageUrlController.dispose();
    super.dispose();
  }

  // --- Funciones de validación ---
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
        url.contains('pixabay.com');
  }

  String _getFinalImageUrl() {
    if (_useCustomUrl && _customImageUrlController.text.trim().isNotEmpty) {
      return _customImageUrlController.text.trim();
    }
    return _communityAvatars[_selectedAvatarIndex];
  }

  // --- Funciones de Firebase ---

  // Actualizar nombre de la comunidad
  void _updateCommunityName() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El nombre de la comunidad no puede estar vacío'),
        ),
      );
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .update({'name': _nameController.text.trim()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Nombre de la comunidad actualizado!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar el nombre: $e')),
        );
      }
    }
  }

  // Actualizar descripción de la comunidad
  void _updateCommunityDescription() async {
    try {
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .update({'description': _descriptionController.text.trim()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Descripción actualizada!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar la descripción: $e')),
        );
      }
    }
  }

  // Actualizar imagen de la comunidad
  void _updateCommunityImage() async {
    final newImageUrl = _getFinalImageUrl();

    if (_useCustomUrl && !_isValidImageUrl(newImageUrl)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa una URL de imagen válida'),
        ),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .update({'imageUrl': newImageUrl});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Imagen de la comunidad actualizada!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar la imagen: $e')),
        );
      }
    }
  }

  // Generar o refrescar código de unión
  void _generateJoinCode() async {
    String newCode = _uuid.v4().substring(0, 6).toUpperCase();
    try {
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .update({'joinCode': newCode});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nuevo Código de Unión: $newCode')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar el código: $e')),
        );
      }
    }
  }

  // Copiar código al portapapeles
  void _copyJoinCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡Código de unión copiado al portapapeles!'),
      ),
    );
  }

  // Salir de la comunidad
  void _leaveCommunity() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión para abandonar una comunidad'),
        ),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Abandonar Comunidad?'),
        content: const Text(
          '¿Estás seguro de que quieres abandonar esta comunidad? Perderás el acceso a su contenido.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Abandonar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .update({
              'members': FieldValue.arrayRemove([user.uid]),
            });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Has abandonado la comunidad exitosamente!'),
            ),
          );
          Navigator.of(context).pop();
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al abandonar la comunidad: $e')),
          );
        }
      }
    }
  }

  // Eliminar la comunidad
  void _deleteCommunity() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión para eliminar una comunidad'),
        ),
      );
      return;
    }

    final communityDoc = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .get();
    if (!communityDoc.exists || communityDoc.get('ownerId') != user.uid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No eres el propietario de esta comunidad'),
          ),
        );
      }
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿ELIMINAR COMUNIDAD?'),
        content: const Text(
          'ADVERTENCIA: Esta acción es irreversible. Todos los mensajes de chat, tareas y datos de esta comunidad se eliminarán permanentemente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection('messages')
            .get()
            .then((snapshot) {
              for (DocumentSnapshot doc in snapshot.docs) {
                doc.reference.delete();
              }
            });
        await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection('tasks')
            .get()
            .then((snapshot) {
              for (DocumentSnapshot doc in snapshot.docs) {
                doc.reference.delete();
              }
            });
        await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Comunidad eliminada exitosamente!')),
          );
          Navigator.of(context).pop();
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar la comunidad: $e')),
          );
        }
      }
    }
  }

  // --- Widgets Auxiliares de UI ---
  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontFamily: fontFamilyPrimary,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.015 * 18,
          color: theme.colorScheme.onBackground,
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    IconData? icon,
    VoidCallback? onTap,
    Widget? trailingWidget,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (icon != null)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Icon(
                    icon,
                    color: theme.colorScheme.onSurface,
                    size: 24,
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: fontFamilyPrimary,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onBackground,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: fontFamilyPrimary,
                        color: theme.colorScheme.primary,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              if (trailingWidget != null) trailingWidget,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSelector(BuildContext context, ThemeData theme) {
    return Column(
      children: [
        // Header con botón de expandir/contraer
        _buildSettingItem(
          context: context,
          icon: Icons.image,
          title: 'Imagen de la comunidad',
          subtitle: 'Cambiar foto de perfil del grupo',
          trailingWidget: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: _updateCommunityImage,
                icon: Icon(Icons.save, color: theme.colorScheme.primary),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _isImageExpanded = !_isImageExpanded;
                  });
                },
                icon: Icon(
                  _isImageExpanded ? Icons.expand_less : Icons.expand_more,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],
          ),
        ),

        // Contenido expandible
        if (_isImageExpanded) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                // Toggle entre opciones
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
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
                                topLeft: Radius.circular(12),
                                bottomLeft: Radius.circular(12),
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
                                topRight: Radius.circular(12),
                                bottomRight: Radius.circular(12),
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

                // Contenido según la selección
                if (!_useCustomUrl) ...[
                  // Selector de avatares predefinidos
                  Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(12),
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
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _communityAvatars[index],
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 70,
                                    height: 70,
                                    color: theme.colorScheme.outline
                                        .withOpacity(0.2),
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
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: TextField(
                      controller: _customImageUrlController,
                      style: TextStyle(
                        fontFamily: fontFamilyPrimary,
                        fontSize: 14,
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
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      onChanged: (value) {
                        setState(() {});
                      },
                    ),
                  ),

                  // Vista previa de la imagen personalizada
                  if (_customImageUrlController.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text(
                            'Vista previa:',
                            style: TextStyle(
                              fontFamily: fontFamilyPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.7,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _customImageUrlController.text.trim(),
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.error.withOpacity(
                                      0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
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
                                        size: 20,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Error',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: theme.colorScheme.error,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionHeader(context, "General"),

                    // Campo de nombre de la comunidad
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: 'Nombre de la Comunidad',
                          hintStyle: theme.inputDecorationTheme.hintStyle,
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              Icons.save,
                              color: theme.colorScheme.primary,
                            ),
                            onPressed: _updateCommunityName,
                          ),
                        ),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontFamily: fontFamilyPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Campo de descripción
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Descripción de la comunidad',
                          hintStyle: theme.inputDecorationTheme.hintStyle,
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              Icons.save,
                              color: theme.colorScheme.primary,
                            ),
                            onPressed: _updateCommunityDescription,
                          ),
                        ),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontFamily: fontFamilyPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Información de creación
                    StreamBuilder<DocumentSnapshot>(
                      stream: _communityStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final Map<String, dynamic> communityData =
                              snapshot.data!.data() as Map<String, dynamic>;
                          final Timestamp? createdAt =
                              communityData['createdAt'] as Timestamp?;
                          final String createdByName =
                              communityData['createdByName'] ?? 'Desconocido';

                          if (createdAt != null) {
                            final DateTime creationDate = createdAt.toDate();
                            final String formattedDate = DateFormat(
                              'dd/MM/yyyy \'a las\' HH:mm',
                            ).format(creationDate);
                            final Duration timeSince = DateTime.now()
                                .difference(creationDate);

                            String timeAgo;
                            if (timeSince.inDays > 365) {
                              final years = (timeSince.inDays / 365).floor();
                              timeAgo =
                                  'hace ${years} año${years > 1 ? 's' : ''}';
                            } else if (timeSince.inDays > 30) {
                              final months = (timeSince.inDays / 30).floor();
                              timeAgo =
                                  'hace ${months} mes${months > 1 ? 'es' : ''}';
                            } else if (timeSince.inDays > 0) {
                              timeAgo =
                                  'hace ${timeSince.inDays} día${timeSince.inDays > 1 ? 's' : ''}';
                            } else if (timeSince.inHours > 0) {
                              timeAgo =
                                  'hace ${timeSince.inHours} hora${timeSince.inHours > 1 ? 's' : ''}';
                            } else if (timeSince.inMinutes > 0) {
                              timeAgo =
                                  'hace ${timeSince.inMinutes} minuto${timeSince.inMinutes > 1 ? 's' : ''}';
                            } else {
                              timeAgo = 'hace unos momentos';
                            }

                            return _buildSettingItem(
                              context: context,
                              icon: Icons.schedule,
                              title: 'Creada $timeAgo',
                              subtitle: 'El $formattedDate por $createdByName',
                            );
                          }
                        }
                        return const SizedBox.shrink();
                      },
                    ),

                    // Selector de imagen
                    _buildImageSelector(context, theme),

                    _buildSectionHeader(context, "Invitaciones"),
                    // Código de unión
                    StreamBuilder<DocumentSnapshot>(
                      stream: _communityStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return _buildSettingItem(
                            context: context,
                            icon: Icons.error_outline,
                            title: 'Error',
                            subtitle: 'Error al cargar el código de unión',
                          );
                        }
                        if (!snapshot.hasData || !snapshot.data!.exists) {
                          return _buildSettingItem(
                            context: context,
                            icon: Icons.info_outline,
                            title: 'Sin Datos',
                            subtitle: 'Datos de la comunidad no encontrados',
                          );
                        }

                        final Map<String, dynamic> communityData =
                            snapshot.data!.data() as Map<String, dynamic>;
                        final String joinCode =
                            communityData['joinCode'] as String? ?? 'N/D';

                        return _buildSettingItem(
                          context: context,
                          icon: Icons.qr_code,
                          title: joinCode == 'N/D' || joinCode.isEmpty
                              ? 'Generar Código'
                              : joinCode,
                          subtitle: joinCode == 'N/D' || joinCode.isEmpty
                              ? 'Genera uno nuevo para invitar'
                              : 'Comparte este código para invitar',
                          trailingWidget: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => joinCode != 'N/D'
                                    ? _copyJoinCode(joinCode)
                                    : null,
                                icon: Icon(
                                  Icons.copy,
                                  color: theme.colorScheme.secondary,
                                ),
                              ),
                              IconButton(
                                onPressed: _generateJoinCode,
                                icon: Icon(
                                  Icons.refresh,
                                  color: theme.colorScheme.secondary,
                                ),
                              ),
                            ],
                          ),
                          onTap: () => joinCode != 'N/D'
                              ? _copyJoinCode(joinCode)
                              : null,
                        );
                      },
                    ),

                    _buildSectionHeader(context, "Acciones"),
                    // Botón para salir de la comunidad
                    _buildSettingItem(
                      context: context,
                      icon: Icons.exit_to_app,
                      title: 'Abandonar Comunidad',
                      subtitle: 'Salir de esta comunidad',
                      onTap: _leaveCommunity,
                    ),

                    // Botón para eliminar la comunidad (Solo para propietarios)
                    StreamBuilder<DocumentSnapshot>(
                      stream: _communityStream,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || !snapshot.data!.exists) {
                          return const SizedBox.shrink();
                        }
                        final String? ownerId = snapshot.data!.get('ownerId');
                        final currentUserUid =
                            FirebaseAuth.instance.currentUser?.uid;

                        if (ownerId != null && ownerId == currentUserUid) {
                          return _buildSettingItem(
                            context: context,
                            icon: Icons.delete_forever,
                            title: 'Eliminar Comunidad',
                            subtitle:
                                'Eliminar permanentemente esta comunidad y todos sus datos.',
                            onTap: _deleteCommunity,
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),

                    const SizedBox(height: 20),
                    _buildSectionHeader(context, "Miembros"),
                    // Lista de miembros (código existente)
                    StreamBuilder<DocumentSnapshot>(
                      stream: _communityStream,
                      builder: (context, communitySnapshot) {
                        if (communitySnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (communitySnapshot.hasError) {
                          return Center(
                            child: Text('Error: ${communitySnapshot.error}'),
                          );
                        }
                        if (!communitySnapshot.hasData ||
                            !communitySnapshot.data!.exists) {
                          return const Center(
                            child: Text('Comunidad no encontrada.'),
                          );
                        }

                        final Map<String, dynamic> communityData =
                            communitySnapshot.data!.data()
                                as Map<String, dynamic>;
                        final List<String> memberIds = List<String>.from(
                          communityData['members'] ?? [],
                        );
                        final String? ownerId =
                            communityData['ownerId'] as String?;

                        if (memberIds.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'No hay miembros en esta comunidad aún.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontFamily: fontFamilyPrimary,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondary,
                                  ),
                            ),
                          );
                        }

                        return FutureBuilder<List<DocumentSnapshot>>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .where(FieldPath.documentId, whereIn: memberIds)
                              .get()
                              .then((querySnapshot) => querySnapshot.docs),
                          builder: (context, userSnapshot) {
                            if (userSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (userSnapshot.hasError) {
                              return Center(
                                child: Text(
                                  'Error cargando miembros: ${userSnapshot.error}',
                                ),
                              );
                            }
                            if (!userSnapshot.hasData ||
                                userSnapshot.data!.isEmpty) {
                              return const Center(
                                child: Text(
                                  'No se encontraron datos de usuario para los miembros.',
                                ),
                              );
                            }

                            final Map<String, Map<String, dynamic>>
                            userDataMap = {};
                            for (var doc in userSnapshot.data!) {
                              if (doc.exists) {
                                userDataMap[doc.id] =
                                    doc.data() as Map<String, dynamic>;
                              }
                            }

                            memberIds.sort((a, b) {
                              if (a == ownerId) return -1;
                              if (b == ownerId) return 1;
                              final nameA =
                                  userDataMap[a]?['name'] ??
                                  userDataMap[a]?['displayName'] ??
                                  '';
                              final nameB =
                                  userDataMap[b]?['name'] ??
                                  userDataMap[b]?['displayName'] ??
                                  '';
                              return nameA.toLowerCase().compareTo(
                                nameB.toLowerCase(),
                              );
                            });

                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: memberIds.length,
                              itemBuilder: (context, index) {
                                final memberId = memberIds[index];
                                final userData = userDataMap[memberId];
                                final String userName =
                                    userData?['name'] ??
                                    userData?['displayName'] ??
                                    'Usuario Desconocido';
                                final String? userPhotoUrl =
                                    userData?['photoURL'];
                                final bool isOwner = memberId == ownerId;
                                final bool isCurrentUser =
                                    memberId ==
                                    FirebaseAuth.instance.currentUser?.uid;

                                return _buildSettingItem(
                                  context: context,
                                  title:
                                      userName + (isCurrentUser ? ' (Tú)' : ''),
                                  subtitle: isOwner ? 'Propietario' : 'Miembro',
                                  trailingWidget:
                                      userPhotoUrl != null &&
                                          userPhotoUrl.isNotEmpty
                                      ? CircleAvatar(
                                          backgroundImage: NetworkImage(
                                            userPhotoUrl,
                                          ),
                                          radius: 20,
                                        )
                                      : CircleAvatar(
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withOpacity(0.1),
                                          child: Icon(
                                            Icons.person,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                        ),
                                  onTap: () {
                                    // Opcional: Navegar al perfil de usuario
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
