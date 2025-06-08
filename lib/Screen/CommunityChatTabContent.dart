// lib/screen/CommunityChatTabContent.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:classroom_mejorado/theme/app_typography.dart';
import 'package:classroom_mejorado/services/firebase_notification_service.dart'; // Ya lo tienes

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

  // ✅ Obtener la instancia Singleton del servicio de notificaciones
  final FirebaseNotificationService _notificationService =
      FirebaseNotificationService();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ✅ Informar al servicio que este chat está AHORA ACTIVO
      _notificationService.setActiveChatCommunity(widget.communityId);

      // Limpiar notificaciones de la bandeja para esta comunidad (tu lógica original)
      _notificationService.clearChatNotifications(widget.communityId);
      _scrollToBottom(); // Desplazarse al final después de que la UI se construya
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
    _scrollToBottom(); // Llamar después de limpiar y enviar
  }

  void _scrollToBottom() {
    // Añadir un pequeño retraso para dar tiempo a que el ListView se actualice
    // antes de intentar desplazarse.
    Future.delayed(const Duration(milliseconds: 100), () {
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
                      Text(
                        messageText,
                        style: TextStyle(
                          color: isMe
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant,
                          fontSize: 15, // Tamaño de fuente estándar
                          height: 1.3, // Interlineado
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

    return Scaffold(
      // El Scaffold ya estaba, lo cual es bueno
      backgroundColor: theme.colorScheme.background, // Fondo general
      body: Column(
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
                // Llamar a _scrollToBottom después de que el frame se construya y el ListView tenga dimensiones
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

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
                Material(
                  // Para el efecto ripple en el botón de enviar
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    onTap: _sendMessage,
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0), // Padding del botón
                      child: Icon(
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
}
