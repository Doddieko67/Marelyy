import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AIHistoryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Guardar un mensaje individual de chat con la IA
  static Future<String> saveAIMessage({
    required String communityId,
    required String content,
    required String messageType, // 'user' o 'ai'
    required String userId,
    required String userName,
    String? userPhotoURL,
    Map<String, dynamic>? taskSuggestion,
    List<Map<String, dynamic>>? multipleTasks,
    Map<String, dynamic>? updateTaskData,
    Map<String, dynamic>? deleteTaskData,
    List<Map<String, dynamic>>? multipleUpdates,
    List<Map<String, dynamic>>? multipleDeletions,
    Map<String, dynamic>? analysisData,
  }) async {
    try {
      final docRef = await _firestore.collection('communities')
          .doc(communityId)
          .collection('ai_chat')
          .add({
        'content': content,
        'messageType': messageType,
        'userId': userId,
        'userName': userName,
        'userPhotoURL': userPhotoURL,
        'timestamp': FieldValue.serverTimestamp(),
        'taskSuggestion': taskSuggestion,
        'multipleTasks': multipleTasks,
        'updateTaskData': updateTaskData,
        'deleteTaskData': deleteTaskData,
        'multipleUpdates': multipleUpdates,
        'multipleDeletions': multipleDeletions,
        'analysisData': analysisData,
        'isPublic': true, // Público para toda la comunidad
      });
      return docRef.id;
    } catch (e) {
      print('Error saving AI message: $e');
      rethrow;
    }
  }

  // Obtener mensajes del chat de IA para una comunidad (en tiempo real)
  static Stream<QuerySnapshot> getAIChatMessages(String communityId) {
    return _firestore.collection('communities')
        .doc(communityId)
        .collection('ai_chat')
        .where('isPublic', isEqualTo: true)
        .orderBy('timestamp', descending: false) // Orden cronológico para chat
        .snapshots();
  }

  // Obtener mensajes del chat de forma estática (para cargar historial)
  static Future<List<Map<String, dynamic>>> getAIChatHistory(
    String communityId, {
    int limit = 100,
  }) async {
    try {
      print('Fetching AI chat history for community: $communityId');
      final snapshot = await _firestore.collection('communities')
          .doc(communityId)
          .collection('ai_chat')
          .where('isPublic', isEqualTo: true)
          .orderBy('timestamp', descending: false) // Orden cronológico
          .limit(limit)
          .get();

      print('Found ${snapshot.docs.length} messages in Firebase');
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting AI chat history: $e');
      return [];
    }
  }

  // Eliminar un mensaje específico (solo el autor o admin)
  static Future<void> deleteMessage({
    required String communityId,
    required String messageId,
  }) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      // Verificar que el usuario es el autor o admin de la comunidad
      final messageDoc = await _firestore.collection('communities')
          .doc(communityId)
          .collection('ai_chat')
          .doc(messageId)
          .get();

      if (!messageDoc.exists) return;

      final messageData = messageDoc.data()!;
      final isAuthor = messageData['userId'] == currentUserId;

      // Verificar si es admin de la comunidad
      final communityDoc = await _firestore.collection('communities')
          .doc(communityId)
          .get();
      final communityData = communityDoc.data();
      final isAdmin = communityData?['admins']?.contains(currentUserId) ?? false;
      final isOwner = communityData?['ownerId'] == currentUserId;

      if (isAuthor || isAdmin || isOwner) {
        await _firestore.collection('communities')
            .doc(communityId)
            .collection('ai_chat')
            .doc(messageId)
            .delete();
      }
    } catch (e) {
      print('Error deleting AI message: $e');
      rethrow;
    }
  }

  // Limpiar todo el historial de chat (solo admins)
  static Future<void> clearChatHistory(String communityId) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      // Verificar que el usuario es admin de la comunidad
      final communityDoc = await _firestore.collection('communities')
          .doc(communityId)
          .get();
      final communityData = communityDoc.data();
      final isAdmin = communityData?['admins']?.contains(currentUserId) ?? false;
      final isOwner = communityData?['ownerId'] == currentUserId;

      if (isAdmin || isOwner) {
        final batch = _firestore.batch();
        final messagesSnapshot = await _firestore.collection('communities')
            .doc(communityId)
            .collection('ai_chat')
            .get();

        for (final doc in messagesSnapshot.docs) {
          batch.delete(doc.reference);
        }

        await batch.commit();
      }
    } catch (e) {
      print('Error clearing chat history: $e');
      rethrow;
    }
  }
}