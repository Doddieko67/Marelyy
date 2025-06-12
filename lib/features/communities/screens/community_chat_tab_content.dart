// lib/screen/CommunityChatTabContent.dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:async';

import 'package:classroom_mejorado/core/constants/app_typography.dart';
import 'package:classroom_mejorado/core/services/firebase_notification_service.dart';
import 'package:classroom_mejorado/core/utils/file_utils.dart';

class CommunityChatTabContent extends StatefulWidget {
  final String communityId;

  const CommunityChatTabContent({super.key, required this.communityId});

  @override
  State<CommunityChatTabContent> createState() =>
      _CommunityChatTabContentState();
}

class _CommunityChatTabContentState extends State<CommunityChatTabContent> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Variables para manejo de archivos
  bool _isUploadingFile = false;
  double _uploadProgress = 0.0;
  
  // Variables para controlar el auto-scroll - SIMPLIFICADO
  bool _isAtBottom = true;
  int _lastMessageCount = 0;

  // ✅ Obtener la instancia Singleton del servicio de notificaciones
  final FirebaseNotificationService _notificationService =
      FirebaseNotificationService();

  @override
  void initState() {
    super.initState();
    
    // Listener para detectar scroll manual del usuario
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ✅ Informar al servicio que este chat está AHORA ACTIVO
      _notificationService.setActiveChatCommunity(widget.communityId);

      // Limpiar notificaciones de la bandeja para esta comunidad (tu lógica original)
      _notificationService.clearChatNotifications(widget.communityId);
      _scrollToBottom(force: true); // Forzar scroll inicial al final
    });
  }

  @override
  void dispose() {
    // ✅ Informar al servicio que este chat YA NO ESTÁ ACTIVO
    //     Solo si este es el chat que estaba marcado como activo,
    //     para evitar limpiar el estado si se navega rápidamente a otro chat.
    if (_notificationService.activeChatCommunityId.value ==
        widget.communityId) {
      _notificationService.setActiveChatCommunity(null);
    }

    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) {
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        // Verificar si el widget sigue montado
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes iniciar sesión para enviar mensajes'),
          ),
        );
      }
      return;
    }

    // Obtener nombre de usuario más robusto
    String senderUsername =
        user.displayName ?? user.email?.split('@')[0] ?? 'Usuario Anónimo';
    if (user.displayName == null || user.displayName!.isEmpty) {
      // Intentar obtener de Firestore si el displayName de Auth es nulo/vacío
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists && userDoc.data() != null) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;
          senderUsername =
              userData['name'] ?? userData['displayName'] ?? senderUsername;
        }
      } catch (e) {
        print("Error fetching username for chat message: $e");
      }
    }

    await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('messages')
        .add({
          'text': _messageController.text.trim(),
          'senderId': user.uid,
          'senderUser': senderUsername, // Usar el nombre obtenido
          'senderPhotoURL': user.photoURL,
          'timestamp': FieldValue.serverTimestamp(),
        });

    _messageController.clear();
    _scrollToBottom(force: true); // Forzar scroll al enviar mensaje propio
  }

  // Método para seleccionar y subir imagen
  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      await _uploadFile(File(image.path), 'image');
    }
  }

  // Método para seleccionar y subir archivo
  Future<void> _pickAndUploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    
    if (result != null && result.files.single.path != null) {
      await _uploadFile(File(result.files.single.path!), 'file');
    }
  }

  // Método para subir archivos a Firebase Storage y enviar mensaje
  Future<void> _uploadFile(File file, String fileType) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isUploadingFile = true;
      _uploadProgress = 0.0;
    });

    try {
      // Crear nombre único para el archivo
      String fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      String filePath = 'chat_files/${widget.communityId}/$fileName';
      
      // Subir archivo
      UploadTask uploadTask = FirebaseStorage.instance.ref(filePath).putFile(file);
      
      // Escuchar progreso
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          _uploadProgress = (snapshot.bytesTransferred / snapshot.totalBytes);
        });
      });

      TaskSnapshot snapshot = await uploadTask;
      String downloadURL = await snapshot.ref.getDownloadURL();

      // Obtener información del archivo
      int fileSize = await file.length();
      String originalFileName = file.path.split('/').last;

      // Obtener nombre de usuario
      String senderUsername = user.displayName ?? user.email?.split('@')[0] ?? 'Usuario Anónimo';
      if (user.displayName == null || user.displayName!.isEmpty) {
        try {
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          if (userDoc.exists && userDoc.data() != null) {
            Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
            senderUsername = userData['name'] ?? userData['displayName'] ?? senderUsername;
          }
        } catch (e) {
          print("Error fetching username for file message: $e");
        }
      }

      // Enviar mensaje con información del archivo
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('messages')
          .add({
            'text': fileType == 'image' ? '📷 Imagen compartida' : '📎 Archivo compartido',
            'senderId': user.uid,
            'senderUser': senderUsername,
            'senderPhotoURL': user.photoURL,
            'timestamp': FieldValue.serverTimestamp(),
            'fileType': fileType,
            'fileUrl': downloadURL,
            'fileName': originalFileName,
            'fileSize': fileSize,
            'isFile': true,
          });

      _scrollToBottom(force: true); // Forzar scroll al subir archivo
    } catch (e) {
      print('Error uploading file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir archivo: $e')),
        );
      }
    } finally {
      setState(() {
        _isUploadingFile = false;
        _uploadProgress = 0.0;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      // Detectar si estamos muy cerca del final (solo últimos 50 pixels)
      final isNearBottom = _scrollController.position.maxScrollExtent - 
          _scrollController.position.pixels < 50;
      
      // Solo actualizar si hay un cambio real
      if (_isAtBottom != isNearBottom) {
        _isAtBottom = isNearBottom;
        // No hacer setState aquí para evitar rebuilds innecesarios
      }
    }
  }

  void _scrollToBottom({bool force = false}) {
    // Solo hacer scroll si forzamos o si estamos en el fondo
    if (!force && !_isAtBottom) {
      return;
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.position.hasContentDimensions) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildUserAvatar(
    String? photoURL,
    String userName,
    ThemeData theme, {
    double size = 32,
  }) {
    // Tu implementación de _buildUserAvatar parece correcta.
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.secondary.withOpacity(0.1), // Más sutil
      ),
      child: photoURL != null && photoURL.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(size / 2),
              child: Image.network(
                photoURL,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildDefaultAvatar(userName, theme, size),
                loadingBuilder: (context, child, loadingProgress) {
                  // Placeholder de carga
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
              ),
            )
          : _buildDefaultAvatar(userName, theme, size),
    );
  }

  Widget _buildDefaultAvatar(String userName, ThemeData theme, double size) {
    // Tu implementación de _buildDefaultAvatar parece correcta.
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        // Usar un degradado o un color más vibrante para avatares por defecto
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.7),
            theme.colorScheme.secondary.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          userName.isNotEmpty ? userName[0].toUpperCase() : '?',
          style: TextStyle(
            color: Colors
                .white, // Letra blanca para mejor contraste con el degradado
            fontSize: size * 0.45, // Un poco más grande
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    DocumentSnapshot messageDoc,
    User? currentUser,
  ) {
    final theme = Theme.of(context);
    final data = messageDoc.data() as Map<String, dynamic>;
    final String messageText = data['text'] ?? '';
    final String senderName = data['senderUser'] ?? 'Desconocido';
    final String senderId = data['senderId'] ?? '';
    final String? senderPhotoURL = data['senderPhotoURL'];
    final Timestamp? timestamp = data['timestamp'] as Timestamp?;
    final bool isFile = data['isFile'] ?? false;
    final String? fileType = data['fileType'];
    final String? fileUrl = data['fileUrl'];
    final String? fileName = data['fileName'];
    final int? fileSize = data['fileSize'];

    final bool isMe = currentUser?.uid == senderId;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment
            .end, // Alinea el avatar con la parte inferior del bubble
        children: [
          if (!isMe) ...[
            _buildUserAvatar(senderPhotoURL, senderName, theme, size: 32),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMe) // Mostrar nombre del remitente solo para mensajes de otros
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 10.0,
                      bottom: 2.0,
                    ), // Pequeño padding
                    child: Text(
                      senderName.contains('@')
                          ? senderName.split('@')[0]
                          : senderName,
                      style: TextStyle(
                        fontSize: 11, // Un poco más pequeño
                        fontWeight: FontWeight.w500, // Menos bold
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    color: isMe
                        ? theme.colorScheme.primary
                        : theme
                              .colorScheme
                              .surfaceVariant, // Colores distintivos
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16), // Más redondeado
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(
                        isMe ? 16 : 4,
                      ), // Estilo "cola"
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: [
                      // Sombra sutil
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 3,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 14,
                  ), // Ajustar padding
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ), // Un poco más ancho
                  child: Column(
                    // Usar Column para alinear texto y hora
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize
                        .min, // Para que la columna no ocupe más de lo necesario
                    children: [
                      if (isFile && fileType == 'image' && fileUrl != null)
                        _buildImageMessage(fileUrl!, fileName)
                      else if (isFile && fileType == 'file' && fileUrl != null)
                        _buildFileMessage(fileUrl!, fileName, fileSize, theme, isMe)
                      else
                        Text(
                          messageText,
                          style: TextStyle(
                            color: isMe
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurfaceVariant,
                            fontSize: 15,
                            height: 1.3,
                          ),
                        ),
                      if (timestamp != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 5.0),
                          child: Text(
                            DateFormat('HH:mm').format(
                              timestamp.toDate(),
                            ), // Formato 24h más común
                            style: TextStyle(
                              fontSize: 10,
                              color:
                                  (isMe
                                          ? theme.colorScheme.onPrimary
                                          : theme.colorScheme.onSurfaceVariant)
                                      .withOpacity(0.7),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            _buildUserAvatar(
              currentUser?.photoURL,
              currentUser?.displayName ?? currentUser?.email ?? 'Yo',
              theme,
              size: 32,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;

    return Container(
      color: theme.colorScheme.background, // Fondo general
      child: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('communities')
                  .doc(widget.communityId)
                  .collection('messages')
                  .orderBy(
                    'timestamp',
                    descending: false,
                  ) // `descending: false` para que los nuevos aparezcan abajo
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: theme.colorScheme.primary,
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 60,
                          color: theme.colorScheme.onBackground.withOpacity(
                            0.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '¡Aún no hay mensajes!',
                          style: TextStyle(
                            fontSize: 18,
                            color: theme.colorScheme.onBackground.withOpacity(
                              0.7,
                            ),
                          ),
                        ),
                        Text(
                          'Sé el primero en enviar un mensaje.',
                          style: TextStyle(
                            color: theme.colorScheme.onBackground.withOpacity(
                              0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data!.docs;
                
                // Solo hacer scroll automático para nuevos mensajes si estamos en el fondo
                if (messages.length != _lastMessageCount) {
                  final bool isNewMessage = messages.length > _lastMessageCount;
                  _lastMessageCount = messages.length;
                  
                  // Solo hacer scroll automático si es un mensaje nuevo y estamos en el fondo
                  if (isNewMessage && _isAtBottom) {
                    _scrollToBottom();
                  }
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 4.0,
                  ), // Ajustar padding
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return _buildMessageBubble(
                      context,
                      messages[index],
                      currentUser,
                    );
                  },
                );
              },
            ),
          ),
          Container(
            // Barra de entrada de mensajes
            padding: EdgeInsets.fromLTRB(
              12.0,
              8.0,
              12.0,
              8.0 + MediaQuery.of(context).padding.bottom * 0.5,
            ), // Padding para teclado y notch
            decoration: BoxDecoration(
              // Decoración para la barra
              color: theme.scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(
                  color: theme.dividerColor.withOpacity(0.5),
                  width: 0.5,
                ),
              ),
              // boxShadow: [
              //   BoxShadow(
              //     color: Colors.black.withOpacity(0.05),
              //     blurRadius: 5,
              //     offset: const Offset(0, -2),
              //   )
              // ]
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment
                  .end, // Alinear al final para TextField multilínea
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(
                        0.7,
                      ), // Color de fondo del campo de texto
                      borderRadius: BorderRadius.circular(24.0),
                    ),
                    child: TextField(
                      controller: _messageController,
                      maxLines: 5,
                      minLines: 1,
                      textInputAction: TextInputAction
                          .newline, // O TextInputAction.send si no quieres multilínea fácil
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        hintStyle: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant.withOpacity(
                            0.6,
                          ),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 12.0,
                        ), // Ajustar padding interno
                      ),
                      style: TextStyle(
                        fontFamily: fontFamilyPrimary,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 15,
                      ),
                      // onSubmitted no es tan útil con multilínea, el botón de enviar es mejor
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Botón para adjuntar archivos
                Material(
                  color: theme.colorScheme.secondary,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    onTap: _showAttachmentOptions,
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Icon(
                        Icons.attach_file,
                        color: theme.colorScheme.onSecondary,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  // Para el efecto ripple en el botón de enviar
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    onTap: _sendMessage,
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0), // Padding del botón
                      child: _isUploadingFile
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                value: _uploadProgress,
                                color: theme.colorScheme.onPrimary,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              Icons.send_rounded,
                              color: theme.colorScheme.onPrimary,
                              size: 24,
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
  }

  // Mostrar opciones de adjuntar archivos
  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Seleccionar imagen'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage();
              },
            ),
            ListTile(
              leading: Icon(Icons.attach_file),
              title: Text('Seleccionar archivo'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadFile();
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('Tomar foto'),
              onTap: () {
                Navigator.pop(context);
                _takePicture();
              },
            ),
          ],
        ),
      ),
    );
  }

  // Tomar foto con la cámara
  Future<void> _takePicture() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);
    
    if (photo != null) {
      await _uploadFile(File(photo.path), 'image');
    }
  }

  // Widget para mostrar imagen en el mensaje
  Widget _buildImageMessage(String imageUrl, String? fileName) {
    return GestureDetector(
      onTap: () => _showFullImage(imageUrl, fileName),
      child: Container(
        constraints: BoxConstraints(maxWidth: 200, maxHeight: 200),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 150,
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 150,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, color: Colors.red),
                      Text('Error al cargar imagen'),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // Widget para mostrar archivo en el mensaje
  Widget _buildFileMessage(String fileUrl, String? fileName, int? fileSize, ThemeData theme, bool isMe) {
    String displayName = fileName ?? 'Archivo';
    String sizeText = fileSize != null ? _formatFileSize(fileSize) : '';
    
    return GestureDetector(
      onTap: () => _openFile(fileUrl, fileName),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe 
              ? theme.colorScheme.onPrimary.withOpacity(0.1)
              : theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getFileIcon(displayName),
              color: isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      color: isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (sizeText.isNotEmpty)
                    Text(
                      sizeText,
                      style: TextStyle(
                        color: (isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant)
                            .withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Mostrar imagen en pantalla completa
  void _showFullImage(String imageUrl, String? fileName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Abrir archivo (implementación básica)
  void _openFile(String fileUrl, String? fileName) {
    // Aquí puedes implementar la lógica para abrir archivos
    // Por ahora, copiamos la URL al portapapeles
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Archivo: ${fileName ?? "Sin nombre"}')),
    );
  }

  // Obtener icono según tipo de archivo
  IconData _getFileIcon(String fileName) {
    String extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'zip':
      case 'rar':
        return Icons.archive;
      case 'mp3':
      case 'wav':
        return Icons.audio_file;
      case 'mp4':
      case 'avi':
        return Icons.video_file;
      default:
        return Icons.insert_drive_file;
    }
  }

  // Formatear tamaño de archivo
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
