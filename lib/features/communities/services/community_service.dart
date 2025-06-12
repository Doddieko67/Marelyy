import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:classroom_mejorado/features/communities/models/community_model.dart';
import 'package:classroom_mejorado/features/tasks/models/user_model.dart';

class CommunityService {
  static final CommunityService _instance = CommunityService._internal();
  factory CommunityService() => _instance;
  CommunityService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Obtener todas las comunidades del usuario actual
  Stream<List<Community>> getUserCommunities() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('communities')
        .where('members', arrayContains: user.uid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Community.fromFirestore(doc)).toList();
    });
  }

  // Obtener una comunidad específica
  Future<Community?> getCommunity(String communityId) async {
    try {
      final doc = await _firestore.collection('communities').doc(communityId).get();
      if (doc.exists) {
        return Community.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Error al obtener la comunidad: $e');
    }
  }

  // Obtener stream de una comunidad específica
  Stream<Community?> getCommunityStream(String communityId) {
    return _firestore
        .collection('communities')
        .doc(communityId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return Community.fromFirestore(doc);
      }
      return null;
    });
  }

  // Crear nueva comunidad
  Future<String> createCommunity(Community community) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final docRef = await _firestore.collection('communities').add(community.toFirestore());
      
      // Agregar al creador como administrador en la subcolección de miembros
      await docRef.collection('members').doc(user.uid).set({
        'userId': user.uid,
        'name': user.displayName ?? 'Usuario',
        'email': user.email,
        'role': 'owner',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e) {
      throw Exception('Error al crear la comunidad: $e');
    }
  }

  // Actualizar comunidad
  Future<void> updateCommunity(String communityId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('communities').doc(communityId).update(updates);
    } catch (e) {
      throw Exception('Error al actualizar la comunidad: $e');
    }
  }

  // Eliminar comunidad
  Future<void> deleteCommunity(String communityId) async {
    try {
      // Verificar que el usuario actual es el propietario
      final community = await getCommunity(communityId);
      if (community == null) throw Exception('Comunidad no encontrada');
      
      final user = _auth.currentUser;
      if (user == null || community.ownerId != user.uid) {
        throw Exception('No tienes permisos para eliminar esta comunidad');
      }

      // Eliminar tareas de la comunidad
      final tasksSnapshot = await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('tasks')
          .get();
      
      for (var taskDoc in tasksSnapshot.docs) {
        await taskDoc.reference.delete();
      }

      // Eliminar miembros de la comunidad
      final membersSnapshot = await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .get();
      
      for (var memberDoc in membersSnapshot.docs) {
        await memberDoc.reference.delete();
      }

      // Eliminar mensajes de la comunidad
      final messagesSnapshot = await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('messages')
          .get();
      
      for (var messageDoc in messagesSnapshot.docs) {
        await messageDoc.reference.delete();
      }

      // Finalmente eliminar la comunidad
      await _firestore.collection('communities').doc(communityId).delete();
    } catch (e) {
      throw Exception('Error al eliminar la comunidad: $e');
    }
  }

  // Unirse a una comunidad por código
  Future<void> joinCommunityByCode(String joinCode) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final querySnapshot = await _firestore
          .collection('communities')
          .where('joinCode', isEqualTo: joinCode.toUpperCase())
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('Código de invitación no válido');
      }

      final communityDoc = querySnapshot.docs.first;
      final communityData = communityDoc.data();
      final currentMembers = List<String>.from(communityData['members'] ?? []);

      if (currentMembers.contains(user.uid)) {
        throw Exception('Ya eres miembro de esta comunidad');
      }

      // Agregar usuario a la lista de miembros
      await communityDoc.reference.update({
        'members': FieldValue.arrayUnion([user.uid]),
      });

      // Agregar al usuario en la subcolección de miembros
      await communityDoc.reference.collection('members').doc(user.uid).set({
        'userId': user.uid,
        'name': user.displayName ?? 'Usuario',
        'email': user.email,
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error al unirse a la comunidad: $e');
    }
  }

  // Salir de una comunidad
  Future<void> leaveCommunity(String communityId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final community = await getCommunity(communityId);
      if (community == null) throw Exception('Comunidad no encontrada');

      if (community.ownerId == user.uid) {
        throw Exception('El propietario no puede salir de su propia comunidad');
      }

      // Remover usuario de la lista de miembros
      await _firestore.collection('communities').doc(communityId).update({
        'members': FieldValue.arrayRemove([user.uid]),
      });

      // Remover de la subcolección de miembros
      await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .doc(user.uid)
          .delete();
    } catch (e) {
      throw Exception('Error al salir de la comunidad: $e');
    }
  }

  // Obtener miembros de una comunidad
  Stream<List<CommunityMember>> getCommunityMembers(String communityId) {
    return _firestore
        .collection('communities')
        .doc(communityId)
        .collection('members')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => CommunityMember.fromFirestore(doc)).toList();
    });
  }

  // Obtener estadísticas de una comunidad
  Future<CommunityStats> getCommunityStats(String communityId) async {
    try {
      // Obtener número de miembros
      final community = await getCommunity(communityId);
      final totalMembers = community?.memberCount ?? 0;

      // Obtener estadísticas de tareas
      final tasksSnapshot = await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('tasks')
          .get();

      final totalTasks = tasksSnapshot.docs.length;
      int completedTasks = 0;
      int activeTasks = 0;
      Map<String, int> tasksByStatus = {};

      for (var doc in tasksSnapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? 'toDo';
        
        tasksByStatus[status] = (tasksByStatus[status] ?? 0) + 1;
        
        if (status == 'done' || status == 'completed') {
          completedTasks++;
        } else {
          activeTasks++;
        }
      }

      // Obtener número de mensajes
      final messagesSnapshot = await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('messages')
          .get();

      final messagesCount = messagesSnapshot.docs.length;

      return CommunityStats(
        totalMembers: totalMembers,
        totalTasks: totalTasks,
        completedTasks: completedTasks,
        activeTasks: activeTasks,
        messagesCount: messagesCount,
        tasksByStatus: tasksByStatus,
      );
    } catch (e) {
      throw Exception('Error al obtener estadísticas de la comunidad: $e');
    }
  }

  // Actualizar rol de miembro
  Future<void> updateMemberRole(String communityId, String userId, String newRole) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      // Verificar que el usuario actual es propietario o administrador
      final currentUserMember = await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .doc(user.uid)
          .get();

      if (!currentUserMember.exists) {
        throw Exception('No eres miembro de esta comunidad');
      }

      final currentUserRole = currentUserMember.data()?['role'] ?? 'member';
      if (currentUserRole != 'owner' && currentUserRole != 'admin') {
        throw Exception('No tienes permisos para cambiar roles');
      }

      await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .doc(userId)
          .update({'role': newRole});
    } catch (e) {
      throw Exception('Error al actualizar el rol del miembro: $e');
    }
  }


  // Obtener comunidades recientes (para admin global)
  Future<List<Community>> getRecentCommunities({int limit = 5}) async {
    try {
      final snapshot = await _firestore
          .collection('communities')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => Community.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Error al obtener comunidades recientes: $e');
    }
  }

  // Obtener comunidades más populares (para admin global)
  Future<List<Community>> getTopCommunities({int limit = 5}) async {
    try {
      final snapshot = await _firestore
          .collection('communities')
          .orderBy('memberCount', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => Community.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Error al obtener comunidades populares: $e');
    }
  }

  // Actualizar última visita del usuario a una comunidad
  Future<void> updateLastVisit(String communityId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('lastVisits')
          .doc(communityId)
          .set({
        'timestamp': FieldValue.serverTimestamp(),
        'communityId': communityId,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating last visit: $e');
    }
  }

  // Obtener última visita del usuario
  Stream<Map<String, DateTime>> getUserLastVisits() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value({});

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('lastVisits')
        .snapshots()
        .map((snapshot) {
      Map<String, DateTime> lastVisits = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp != null) {
          lastVisits[doc.id] = timestamp.toDate();
        }
      }
      return lastVisits;
    });
  }

  // ===== MÉTODOS PARA MÚLTIPLES ADMINS =====

  // Promover usuario a administrador
  Future<bool> promoteToAdmin(String communityId, String userId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Verificar que el usuario actual es propietario
      final community = await getCommunity(communityId);
      if (community == null || !community.isOwner(user.uid)) {
        throw Exception('Solo el propietario puede promover administradores');
      }

      // Verificar que el usuario a promover es miembro
      if (!community.isMember(userId)) {
        throw Exception('El usuario debe ser miembro de la comunidad');
      }

      // Agregar a la lista de admins
      await _firestore.collection('communities').doc(communityId).update({
        'admins': FieldValue.arrayUnion([userId])
      });

      // Actualizar rol en la subcolección de miembros
      await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .doc(userId)
          .update({'role': 'admin'});

      return true;
    } catch (e) {
      print('Error promoviendo a admin: $e');
      return false;
    }
  }

  // Degradar administrador a miembro
  Future<bool> demoteFromAdmin(String communityId, String userId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Verificar que el usuario actual es propietario
      final community = await getCommunity(communityId);
      if (community == null || !community.isOwner(user.uid)) {
        throw Exception('Solo el propietario puede degradar administradores');
      }

      // No se puede degradar al propietario
      if (community.isOwner(userId)) {
        throw Exception('No se puede degradar al propietario');
      }

      // Remover de la lista de admins
      await _firestore.collection('communities').doc(communityId).update({
        'admins': FieldValue.arrayRemove([userId])
      });

      // Actualizar rol en la subcolección de miembros
      await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .doc(userId)
          .update({'role': 'member'});

      return true;
    } catch (e) {
      print('Error degradando admin: $e');
      return false;
    }
  }

  // Obtener lista de administradores con información completa
  Stream<List<CommunityMember>> getCommunityAdmins(String communityId) {
    return _firestore
        .collection('communities')
        .doc(communityId)
        .collection('members')
        .where('role', whereIn: ['owner', 'admin'])
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => CommunityMember.fromFirestore(doc)).toList();
    });
  }

  // Verificar si el usuario actual es admin de la comunidad
  Future<bool> isCurrentUserAdmin(String communityId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final community = await getCommunity(communityId);
    return community?.isAdmin(user.uid) ?? false;
  }

  // Obtener todos los IDs de administradores (para notificaciones)
  Future<List<String>> getAdminIds(String communityId) async {
    final community = await getCommunity(communityId);
    return community?.getAllAdminIds() ?? [];
  }

  // Remover miembro (solo propietario y admins)
  Future<bool> removeMember(String communityId, String userIdToRemove) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Verificar que el usuario actual es admin
      final isAdmin = await isCurrentUserAdmin(communityId);
      if (!isAdmin) {
        throw Exception('Solo los administradores pueden remover miembros');
      }

      final community = await getCommunity(communityId);
      if (community == null) return false;

      // No se puede remover al propietario
      if (community.isOwner(userIdToRemove)) {
        throw Exception('No se puede remover al propietario');
      }

      // Remover de la lista de miembros y admins
      await _firestore.collection('communities').doc(communityId).update({
        'members': FieldValue.arrayRemove([userIdToRemove]),
        'admins': FieldValue.arrayRemove([userIdToRemove])
      });

      // Eliminar de la subcolección de miembros
      await _firestore
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .doc(userIdToRemove)
          .delete();

      return true;
    } catch (e) {
      print('Error removiendo miembro: $e');
      return false;
    }
  }
}