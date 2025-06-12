import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:classroom_mejorado/features/communities/models/community_model.dart';
import 'package:classroom_mejorado/features/communities/services/community_service.dart';
import 'package:classroom_mejorado/core/constants/app_typography.dart';

class AdminManagementScreen extends StatefulWidget {
  final String communityId;
  final Community community;

  const AdminManagementScreen({
    super.key,
    required this.communityId,
    required this.community,
  });

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  final CommunityService _communityService = CommunityService();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  bool isOwner = false;

  @override
  void initState() {
    super.initState();
    isOwner = widget.community.isOwner(currentUser?.uid ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Gestionar Administradores',
          style: TextStyle(
            fontFamily: fontFamilyPrimary,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onBackground,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.bug_report, color: theme.colorScheme.secondary),
            onPressed: _showAllMembersDebug,
            tooltip: 'Debug: Ver todos los miembros',
          ),
        ],
      ),
      body: Column(
        children: [
          // Información del propietario
          _buildOwnerSection(theme),
          
          // Lista de administradores actuales
          Expanded(
            child: _buildAdminsSection(theme),
          ),
          
          // Sección para promover nuevos admins (solo para owner)
          if (isOwner) _buildPromoteSection(theme),
        ],
      ),
    );
  }

  Widget _buildOwnerSection(ThemeData theme) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.admin_panel_settings,
            color: theme.colorScheme.primary,
            size: 32,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Propietario de la Comunidad',
                  style: TextStyle(
                    fontFamily: fontFamilyPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  widget.community.createdByName,
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Tiene todos los permisos, puede gestionar administradores',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminsSection(ThemeData theme) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(Icons.admin_panel_settings, color: theme.colorScheme.secondary),
                SizedBox(width: 8),
                Text(
                  'Administradores',
                  style: TextStyle(
                    fontFamily: fontFamilyPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onBackground,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('communities')
                  .doc(widget.communityId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                final communityData = snapshot.data!.data() as Map<String, dynamic>;
                final List<String> memberIds = List<String>.from(communityData['members'] ?? []);
                final List<String> adminIds = List<String>.from(communityData['admins'] ?? []);
                final List<String> ownerIds = List<String>.from(communityData['owners'] ?? [communityData['ownerId']]);

                // Filtrar solo los IDs que son admins pero no owners
                final nonOwnerAdminIds = memberIds.where((memberId) => 
                    adminIds.contains(memberId) && !ownerIds.contains(memberId)
                ).toList();

                if (nonOwnerAdminIds.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: theme.colorScheme.onBackground.withOpacity(0.3),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No hay administradores adicionales',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onBackground.withOpacity(0.7),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          isOwner 
                              ? 'Puedes promover miembros a administradores'
                              : 'Solo el propietario puede gestionar administradores',
                          style: TextStyle(
                            color: theme.colorScheme.onBackground.withOpacity(0.5),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                // Obtener datos de usuarios desde la colección users
                return FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .where(FieldPath.documentId, whereIn: nonOwnerAdminIds)
                      .get(),
                  builder: (context, userSnapshot) {
                    if (userSnapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    if (userSnapshot.hasError || !userSnapshot.hasData) {
                      return Center(
                        child: Text('Error al cargar administradores'),
                      );
                    }

                    final adminUsers = userSnapshot.data!.docs.map((doc) {
                      final userData = doc.data() as Map<String, dynamic>;
                      return CommunityMember(
                        userId: doc.id,
                        name: userData['name'] ?? userData['displayName'] ?? 'Usuario',
                        email: userData['email'] ?? '',
                        profileImageUrl: userData['photoURL'],
                        role: 'admin',
                        joinedAt: DateTime.now(),
                      );
                    }).toList();

                    return ListView.builder(
                      itemCount: adminUsers.length,
                      itemBuilder: (context, index) {
                        final admin = adminUsers[index];
                        return _buildAdminCard(admin, theme);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminCard(CommunityMember admin, ThemeData theme) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.secondary,
          child: admin.profileImageUrl != null && admin.profileImageUrl!.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    admin.profileImageUrl!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.person,
                      color: theme.colorScheme.onSecondary,
                    ),
                  ),
                )
              : Icon(
                  Icons.person,
                  color: theme.colorScheme.onSecondary,
                ),
        ),
        title: Text(
          admin.name,
          style: TextStyle(
            fontFamily: fontFamilyPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(admin.email),
            SizedBox(height: 4),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Administrador',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        trailing: isOwner
            ? PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'demote') {
                    _showDemoteDialog(admin);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'demote',
                    child: Row(
                      children: [
                        Icon(Icons.remove_moderator, size: 20, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Quitar admin'),
                      ],
                    ),
                  ),
                ],
              )
            : Icon(Icons.admin_panel_settings, color: theme.colorScheme.secondary),
      ),
    );
  }

  Widget _buildPromoteSection(ThemeData theme) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withOpacity(0.5),
          ),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _showPromoteDialog,
            icon: Icon(Icons.person_add),
            label: Text('Promover Miembro a Admin'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
    );
  }

  void _showPromoteDialog() {
    showDialog(
      context: context,
      builder: (context) => _PromoteMemberDialog(
        communityId: widget.communityId,
        community: widget.community,
        onPromoted: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Miembro promovido a administrador'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  void _showAllMembersDebug() async {
    try {
      // EXACTAMENTE igual que Settings: obtener datos desde la colección 'users'
      final communityDoc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .get();
      
      final communityData = communityDoc.data() as Map<String, dynamic>;
      final List<String> memberIds = List<String>.from(communityData['members'] ?? []);
      final List<String> adminIds = List<String>.from(communityData['admins'] ?? []);
      final List<String> ownerIds = List<String>.from(communityData['owners'] ?? [communityData['ownerId']]);
      
      final userDocs = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: memberIds)
          .get();
      
      final allMembers = userDocs.docs.map((doc) {
        final userData = doc.data();
        final userId = doc.id;
        
        String role = 'member';
        if (ownerIds.contains(userId)) {
          role = 'owner';
        } else if (adminIds.contains(userId)) {
          role = 'admin';
        }
        
        return CommunityMember(
          userId: userId,
          name: userData['name'] ?? userData['displayName'] ?? 'Usuario',
          email: userData['email'] ?? '',
          profileImageUrl: userData['photoURL'],
          role: role,
          joinedAt: DateTime.now(),
        );
      }).toList();
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Debug: Todos los Miembros (${allMembers.length})'),
          content: Container(
            width: double.maxFinite,
            height: 400,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Lista completa de miembros en la comunidad:\n', 
                    style: TextStyle(fontWeight: FontWeight.bold)),
                  ...allMembers.map((member) => Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nombre: ${member.name}', style: TextStyle(fontWeight: FontWeight.w500)),
                          Text('Email: ${member.email}'),
                          Text('Role: ${member.role}', style: TextStyle(
                            color: member.role == 'owner' ? Colors.orange : 
                                   member.role == 'admin' ? Colors.blue : Colors.green,
                            fontWeight: FontWeight.bold)),
                          Text('UserID: ${member.userId}'),
                          if (member.profileImageUrl != null) 
                            Text('Imagen: ${member.profileImageUrl!.isNotEmpty ? "Sí" : "No"}'),
                        ],
                      ),
                    ),
                  )).toList(),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Filtros aplicados:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('• Solo role == "member"'),
                        Text('• Excluye owners: ${ownerIds.join(", ")}'),
                        Text('• Miembros disponibles: ${allMembers.where((m) => m.role == "member").length}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar miembros: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDemoteDialog(CommunityMember admin) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Quitar Administrador'),
        content: Text(
          '¿Estás seguro de que quieres quitar los permisos de administrador a ${admin.name}?\n\nEsta persona seguirá siendo miembro de la comunidad, pero perderá los permisos administrativos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _communityService.demoteFromAdmin(
                widget.communityId,
                admin.userId,
              );
              
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${admin.name} ya no es administrador'),
                    backgroundColor: Colors.orange,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al quitar administrador'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Quitar Admin'),
          ),
        ],
      ),
    );
  }
}

class _PromoteMemberDialog extends StatefulWidget {
  final String communityId;
  final Community community;
  final VoidCallback onPromoted;

  const _PromoteMemberDialog({
    required this.communityId,
    required this.community,
    required this.onPromoted,
  });

  @override
  State<_PromoteMemberDialog> createState() => _PromoteMemberDialogState();
}

class _PromoteMemberDialogState extends State<_PromoteMemberDialog> {
  final CommunityService _communityService = CommunityService();
  List<CommunityMember> availableMembers = [];
  CommunityMember? selectedMember;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAvailableMembers();
  }

  Future<void> _loadAvailableMembers() async {
    try {
      // EXACTAMENTE igual que Settings: obtener memberIds del documento principal
      final communityDoc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .get();
      
      if (!communityDoc.exists) {
        setState(() {
          isLoading = false;
        });
        return;
      }
      
      final communityData = communityDoc.data() as Map<String, dynamic>;
      final List<String> memberIds = List<String>.from(communityData['members'] ?? []);
      final List<String> adminIds = List<String>.from(communityData['admins'] ?? []);
      final List<String> ownerIds = List<String>.from(communityData['owners'] ?? [communityData['ownerId']]);
      
      if (memberIds.isEmpty) {
        setState(() {
          availableMembers = [];
          isLoading = false;
        });
        return;
      }
      
      // EXACTAMENTE igual que Settings: obtener datos desde la colección 'users'
      final userDocs = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: memberIds)
          .get();
      
      // Convertir a CommunityMember y filtrar
      final allMembers = userDocs.docs.map((doc) {
        final userData = doc.data();
        final userId = doc.id;
        
        // Determinar el rol basado en las listas
        String role = 'member';
        if (ownerIds.contains(userId)) {
          role = 'owner';
        } else if (adminIds.contains(userId)) {
          role = 'admin';
        }
        
        return CommunityMember(
          userId: userId,
          name: userData['name'] ?? userData['displayName'] ?? 'Usuario',
          email: userData['email'] ?? '',
          profileImageUrl: userData['photoURL'],
          role: role,
          joinedAt: DateTime.now(), // No tenemos esta info en users, pero no es crítica para el filtro
        );
      }).toList();
      
      // Filtrar solo miembros regulares (no admins ni owners)
      availableMembers = allMembers.where((member) => 
          member.role == 'member'
      ).toList();
      
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text('Promover a Administrador'),
      content: isLoading
          ? SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : availableMembers.isEmpty
              ? Text('No hay miembros disponibles para promover.')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selecciona un miembro para promover a administrador:',
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(height: 16),
                    Container(
                      width: double.maxFinite,
                      height: 200,
                      child: ListView.builder(
                        itemCount: availableMembers.length,
                        itemBuilder: (context, index) {
                          final member = availableMembers[index];
                          final isSelected = selectedMember?.userId == member.userId;
                          
                          return ListTile(
                            selected: isSelected,
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.secondary,
                              child: member.profileImageUrl != null && member.profileImageUrl!.isNotEmpty
                                  ? ClipOval(
                                      child: Image.network(
                                        member.profileImageUrl!,
                                        width: 32,
                                        height: 32,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Icon(
                                          Icons.person,
                                          color: theme.colorScheme.onSecondary,
                                          size: 16,
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      Icons.person,
                                      color: theme.colorScheme.onSecondary,
                                      size: 16,
                                    ),
                            ),
                            title: Text(
                              member.name,
                              style: TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              member.email,
                              style: TextStyle(fontSize: 12),
                            ),
                            trailing: isSelected ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
                            onTap: () {
                              setState(() {
                                selectedMember = isSelected ? null : member;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: selectedMember == null ? null : _promoteSelectedMember,
          child: Text('Promover'),
        ),
      ],
    );
  }

  Future<void> _promoteSelectedMember() async {
    if (selectedMember == null) return;

    Navigator.pop(context);
    
    final success = await _communityService.promoteToAdmin(
      widget.communityId,
      selectedMember!.userId,
    );

    if (success) {
      widget.onPromoted();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al promover a administrador'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}