// lib/screen/CommunityChatTabContent.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:classroom_mejorado/theme/app_typography.dart';

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

  @override
  void initState() {
    super.initState();
    // Asegurarse de que el scroll esté al final al iniciar (si hay mensajes)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Función para enviar mensajes
  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión para enviar mensajes'),
        ),
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('messages')
        .add({
          'text': _messageController.text.trim(),
          'senderId': user.uid,
          'senderUser': user.displayName,
          'senderPhotoURL': user.photoURL, // Agregamos la foto del usuario
          'timestamp': FieldValue.serverTimestamp(),
        });

    _messageController.clear();
    _scrollToBottom();
  }

  // Función para desplazar el ListView al final
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // Widget para el avatar del usuario
  Widget _buildUserAvatar(
    String? photoURL,
    String userName,
    ThemeData theme, {
    double size = 32,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.secondary.withOpacity(0.2),
      ),
      child: photoURL != null && photoURL.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(size / 2),
              child: Image.network(
                photoURL,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildDefaultAvatar(userName, theme, size);
                },
              ),
            )
          : _buildDefaultAvatar(userName, theme, size),
    );
  }

  // Widget para el avatar por defecto
  Widget _buildDefaultAvatar(String userName, ThemeData theme, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          userName.isNotEmpty ? userName[0].toUpperCase() : '?',
          style: TextStyle(
            color: theme.colorScheme.secondary,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Widget auxiliar para las burbujas de mensaje
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
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar del usuario (solo para mensajes de otros)
          if (!isMe) ...[
            _buildUserAvatar(senderPhotoURL, senderName, theme),
            const SizedBox(width: 8),
          ],

          // Burbuja del mensaje
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: isMe
                        ? theme.colorScheme.primary.withValues(alpha: 0.4)
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12),
                      topRight: const Radius.circular(12),
                      bottomLeft: isMe
                          ? const Radius.circular(12)
                          : Radius.zero,
                      bottomRight: isMe
                          ? Radius.zero
                          : const Radius.circular(12),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 10,
                  ),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      if (!isMe)
                        Text(
                          senderName.contains('@')
                              ? senderName.split('@')[0]
                              : senderName,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                      if (!isMe) const SizedBox(height: 4),
                      Text(
                        messageText,
                        style: TextStyle(
                          color: isMe
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurface,
                          fontSize: 12,
                        ),
                      ),
                      if (timestamp != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            DateFormat('hh:mm a').format(timestamp.toDate()),
                            style: TextStyle(
                              fontSize: 10,
                              color: isMe
                                  ? theme.colorScheme.onPrimary.withOpacity(0.3)
                                  : theme.colorScheme.onSurface.withOpacity(
                                      0.6,
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

          // Avatar del usuario actual (solo para sus mensajes)
          if (isMe) ...[
            const SizedBox(width: 8),
            _buildUserAvatar(
              currentUser?.photoURL,
              currentUser?.displayName ?? '',
              theme,
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

    return Column(
      children: [
        // Usamos StreamBuilder para escuchar los mensajes de Firestore en tiempo real
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('communities')
                .doc(widget.communityId)
                .collection('messages')
                .orderBy('timestamp', descending: false)
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
                  child: Text(
                    '¡Aún no hay mensajes!',
                    style: TextStyle(
                      color: theme.colorScheme.onBackground.withOpacity(0.7),
                    ),
                  ),
                );
              }

              final messages = snapshot.data!.docs;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scrollToBottom();
              });

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
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

        // Barra de entrada de mensajes
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          color: theme.scaffoldBackgroundColor,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(24.0),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          maxLines: 5, // Máximo 5 líneas
                          minLines: 1, // Mínimo 1 línea
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: 'Mensaje',
                            hintStyle: theme.inputDecorationTheme.hintStyle
                                ?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 14.0,
                            ),
                            fillColor: Colors.transparent,
                            filled: true,
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFamily: fontFamilyPrimary,
                            color: theme.colorScheme.onSurface,
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 4.0, bottom: 4.0),
                        child: IconButton(
                          icon: Icon(
                            Icons.send,
                            color: theme.colorScheme.primary,
                          ),
                          onPressed: _sendMessage,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
